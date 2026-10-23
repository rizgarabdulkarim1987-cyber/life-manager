import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/crypto/kdf.dart';
import '../../../core/crypto/random.dart';
import '../../../core/db/app_database.dart';
import '../../../core/security/sensitive.dart';
import '../../../core/text/digits.dart';
import '../crypto/key_wrap.dart';
import '../crypto/recovery_key.dart';
import '../crypto/vault_errors.dart';
import '../crypto/vault_kdf.dart';
import '../crypto/vault_key.dart';
import 'unlock_throttle.dart';

/// Plan Decision 6: no composition rules, just length (counted after digit normalization).
const kMinMasterPasswordLength = 10;

bool masterPasswordLongEnough(String pw) => normalizeDigits(pw).runes.length >= kMinMasterPasswordLength;

String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// A vault built in memory but not yet written: the owner still has to type
/// the recovery key back (spec §9.1). [discard] wipes it if they leave.
final class PendingVault {
  PendingVault._(this.vaultKey, this.recoveryKey, this._vaultId, this._password, this._recovery, this._check);

  final VaultKey vaultKey;
  final RecoveryKey recoveryKey;
  final String _vaultId;
  final WrappedKey _password;
  final WrappedKey _recovery;
  final Uint8List _check;

  void discard() {
    vaultKey.destroy();
    recoveryKey.destroy();
  }

  @override
  String toString() => 'PendingVault(‹redacted›)';
}

/// Owns the vault's key hierarchy (spec §9.1): sets it up, unlocks it with the
/// master password or the recovery key, and re-wraps the vault key when either
/// changes. Every unlock path checks the throttle first and the key check last.
class VaultKeyService {
  VaultKeyService({
    required this._db,
    required this._wrapper,
    required this._throttle,
    required this._kdf,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final KeyWrapper _wrapper;
  final UnlockThrottle _throttle;
  final Kdf _kdf;
  final DateTime Function() _now;

  Future<VaultMetaRow?> _meta() => _db.select(_db.vaultMeta).getSingleOrNull();

  Future<bool> isSetUp() async => await _meta() != null;

  Future<String> vaultId() async {
    final m = await _meta();
    if (m == null) throw StateError('vault not set up');
    return m.vaultId;
  }

  void _checkPassword(Sensitive<String> pw) {
    if (!masterPasswordLongEnough(pw.value)) throw ArgumentError('master password too short');
  }

  /// Builds a new vault in memory; nothing is written until [commitSetUp].
  Future<PendingVault> prepareSetUp(Sensitive<String> masterPassword, {KdfParams? params}) async {
    if (await isSetUp()) throw StateError('vault already set up');
    _checkPassword(masterPassword);
    final p = params ?? await calibrateVaultKdf(_kdf);
    final vdk = generateVaultKey();
    final recovery = RecoveryKey.generate();
    final vaultId = _hex(secureRandomBytes(16));
    return PendingVault._(
      vdk,
      recovery,
      vaultId,
      await _wrapper.wrapWithPassword(vdk, masterPassword, vaultId, p),
      await _wrapper.wrapWithRecovery(vdk, recovery, vaultId),
      await _wrapper.makeCheck(vdk, vaultId),
    );
  }

  /// Writes the vault in one transaction, after the recovery key was confirmed.
  Future<void> commitSetUp(PendingVault v) => _db.transaction(() async {
    if (await isSetUp()) throw StateError('vault already set up');
    final now = _now().toUtc();
    await _db
        .into(_db.vaultMeta)
        .insert(VaultMetaCompanion.insert(vaultId: v._vaultId, checkBlob: v._check, createdAt: now));
    await _insertWrap(v._password, now);
    await _insertWrap(v._recovery, now);
  });

  Future<void> _insertWrap(WrappedKey w, DateTime now) => _db
      .into(_db.vaultKeyWraps)
      .insert(
        VaultKeyWrapsCompanion.insert(
          kind: w.kind,
          kdfJson: Value(w.kdf == null ? null : jsonEncode(w.kdf!.toJson())),
          salt: w.salt,
          sealedKey: w.blob,
          createdAt: now,
        ),
      );

  Future<void> _replaceWrap(WrappedKey w) => _db.transaction(() async {
    await (_db.delete(_db.vaultKeyWraps)..where((r) => r.kind.equals(w.kind))).go();
    await _insertWrap(w, _now().toUtc());
  });

  Future<WrappedKey> _wrap(String kind) async {
    final r = await (_db.select(_db.vaultKeyWraps)..where((w) => w.kind.equals(kind))).getSingleOrNull();
    if (r == null) {
      if (!await isSetUp()) throw StateError('vault not set up');
      throw const VaultCorrupt();
    }
    final KdfParams? kdf;
    try {
      kdf = r.kdfJson == null ? null : KdfParams.fromJson((jsonDecode(r.kdfJson!) as Map).cast<String, Object?>());
    } catch (_) {
      throw const VaultCorrupt();
    }
    return WrappedKey(kind: r.kind, kdf: kdf, salt: r.salt, blob: r.sealedKey);
  }

  Future<void> _guard() async {
    final blocked = await _throttle.blockedFor();
    if (blocked != null) throw VaultLockedOut(blocked);
  }

  Future<Never> _failed() async {
    final r = await _throttle.recordFailure();
    final lockedFor = r.lockedFor;
    if (lockedFor != null) throw VaultLockedOut(lockedFor);
    throw VaultWrongSecret(r.attemptsLeft);
  }

  /// Accepts [vdk] only if it opens this vault's key check; otherwise wipes it.
  Future<VaultKey> _verified(VaultKey vdk, VaultMetaRow meta) async {
    if (await _wrapper.verifyCheck(vdk, meta.vaultId, meta.checkBlob)) return vdk;
    vdk.destroy();
    throw const VaultCorrupt();
  }

  Future<VaultKey> unlockWithPassword(Sensitive<String> password) async {
    final meta = await _meta();
    if (meta == null) throw StateError('vault not set up');
    await _guard();
    final wrap = await _wrap('password');
    final VaultKey vdk;
    try {
      vdk = await _wrapper.unwrapWithPassword(wrap, password, meta.vaultId);
    } on VaultWrongSecret {
      return _failed();
    }
    final ok = await _verified(vdk, meta);
    await _throttle.reset();
    return ok;
  }

  Future<VaultKey> unlockWithRecovery(String typed) async {
    final meta = await _meta();
    if (meta == null) throw StateError('vault not set up');
    await _guard();
    final r = RecoveryKey.parse(typed);
    if (r == null) return _failed();
    final wrap = await _wrap('recovery');
    final VaultKey vdk;
    try {
      vdk = await _wrapper.unwrapWithRecovery(wrap, r, meta.vaultId);
    } on VaultWrongSecret {
      return _failed();
    } finally {
      r.destroy();
    }
    final ok = await _verified(vdk, meta);
    await _throttle.reset();
    return ok;
  }

  /// Re-wraps the vault key under a new master password. Items are untouched.
  Future<void> changeMasterPassword(VaultKey vdk, Sensitive<String> next, {KdfParams? params}) async {
    _checkPassword(next);
    final p = params ?? await calibrateVaultKdf(_kdf);
    await _replaceWrap(await _wrapper.wrapWithPassword(vdk, next, await vaultId(), p));
  }

  /// Replaces the recovery wrap; the old recovery key stops working. Call only
  /// after the owner typed [next] back.
  Future<void> replaceRecoveryKey(VaultKey vdk, RecoveryKey next) async {
    await _replaceWrap(await _wrapper.wrapWithRecovery(vdk, next, await vaultId()));
  }
}
