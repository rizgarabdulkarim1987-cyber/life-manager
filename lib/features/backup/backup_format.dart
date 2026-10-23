import 'dart:convert';
import 'dart:typed_data';

import '../../core/crypto/aead.dart';
import '../../core/crypto/kdf.dart';
import '../../core/crypto/random.dart';
import '../../core/security/sensitive.dart';

const kBackupFormatVersion = 1;
const kBackupExtension = 'plmbackup';

const _magic = [0x50, 0x4C, 0x4D, 0x42]; // "PLMB"
const _prefixLength = 4 + 2 + 4; // magic, formatVersion u16, headerLength u32
const _maxHeaderLength = 16 * 1024;
const _saltLength = 16;
const _nonceLength = 12;
const _tagLength = 16;

/// Bad magic, truncated input, or an unreadable header.
class BackupFormatException implements Exception {
  const BackupFormatException(this.reason);
  final String reason;
  @override
  String toString() => 'BackupFormatException: $reason';
}

class BackupTooNewException implements Exception {
  const BackupTooNewException(this.found, this.supported);
  final int found;
  final int supported;
  @override
  String toString() => 'BackupTooNewException: version $found, supported $supported';
}

/// GCM cannot tell a wrong password from a tampered file.
class BackupWrongPasswordException implements Exception {
  const BackupWrongPasswordException();
  @override
  String toString() => 'BackupWrongPasswordException: wrong password or damaged file';
}

class BackupHeader {
  const BackupHeader({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAtUtc,
    required this.kdf,
    required this.salt,
    required this.nonce,
  });

  final int formatVersion;
  final int schemaVersion;
  final String appVersion;
  final DateTime createdAtUtc;
  final KdfParams kdf;
  final Uint8List salt;
  final Uint8List nonce;

  Map<String, Object> toJson() => {
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'kdf': kdf.toJson(),
    'salt': base64Encode(salt),
    'nonce': base64Encode(nonce),
  };
}

/// `.plmbackup` layout (big-endian): "PLMB", formatVersion u16, headerLength u32,
/// header JSON (UTF-8), then AES-256-GCM ciphertext+tag. Every byte before the
/// ciphertext is the AAD, so the header can't be altered undetected.
class BackupCodec {
  BackupCodec(this._kdf, this._aead);

  final Kdf _kdf;
  final Aead _aead;

  Future<Uint8List> encode({
    required Uint8List payload,
    required Sensitive<String> password,
    required int schemaVersion,
    required String appVersion,
    required KdfParams kdf,
    DateTime? now,
  }) async {
    final header = BackupHeader(
      formatVersion: kBackupFormatVersion,
      schemaVersion: schemaVersion,
      appVersion: appVersion,
      createdAtUtc: (now ?? DateTime.now()).toUtc(),
      kdf: kdf,
      salt: secureRandomBytes(_saltLength),
      nonce: secureRandomBytes(_nonceLength),
    );
    final json = utf8.encode(jsonEncode(header.toJson()));
    final prefix = BytesBuilder(copy: false)
      ..add(_magic)
      ..add((ByteData(2)..setUint16(0, kBackupFormatVersion)).buffer.asUint8List())
      ..add((ByteData(4)..setUint32(0, json.length)).buffer.asUint8List())
      ..add(json);
    final aad = prefix.toBytes();

    final key = await _deriveKey(password, header);
    try {
      final box = await _aead.seal(payload, key, aad: aad, nonce: header.nonce);
      return (BytesBuilder(copy: false)
            ..add(aad)
            ..add(box.cipherText))
          .toBytes();
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  BackupHeader readHeader(Uint8List file) => _parse(file).$1;

  Future<(BackupHeader, Uint8List)> decode(Uint8List file, Sensitive<String> password) async {
    final (header, bodyOffset) = _parse(file);
    final body = Uint8List.sublistView(file, bodyOffset);
    if (body.length < _tagLength) throw const BackupFormatException('truncated body');

    final key = await _deriveKey(password, header);
    try {
      final plain = await _aead.open(
        SealedBox(header.nonce, body),
        key,
        aad: Uint8List.sublistView(file, 0, bodyOffset),
      );
      return (header, plain);
    } on AeadAuthException {
      throw const BackupWrongPasswordException();
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  Future<Uint8List> _deriveKey(Sensitive<String> password, BackupHeader h) =>
      _kdf.derive(password: Uint8List.fromList(utf8.encode(password.value)), salt: h.salt, params: h.kdf);

  (BackupHeader, int) _parse(Uint8List file) {
    if (file.length < _prefixLength) throw const BackupFormatException('truncated');
    for (var i = 0; i < _magic.length; i++) {
      if (file[i] != _magic[i]) throw const BackupFormatException('bad magic');
    }
    final view = ByteData.sublistView(file);
    final formatVersion = view.getUint16(4);
    if (formatVersion > kBackupFormatVersion) throw BackupTooNewException(formatVersion, kBackupFormatVersion);
    if (formatVersion == 0) throw const BackupFormatException('bad version');

    final headerLength = view.getUint32(6);
    if (headerLength > _maxHeaderLength || _prefixLength + headerLength > file.length) {
      throw const BackupFormatException('bad header length');
    }
    final bodyOffset = _prefixLength + headerLength;

    try {
      final j = jsonDecode(utf8.decode(Uint8List.sublistView(file, _prefixLength, bodyOffset))) as Map<String, dynamic>;
      final header = BackupHeader(
        formatVersion: formatVersion,
        schemaVersion: j['schemaVersion'] as int,
        appVersion: j['appVersion'] as String,
        createdAtUtc: DateTime.parse(j['createdAtUtc'] as String).toUtc(),
        kdf: KdfParams.fromJson((j['kdf'] as Map).cast<String, Object?>()),
        salt: base64Decode(j['salt'] as String),
        nonce: base64Decode(j['nonce'] as String),
      );
      if (header.salt.length != _saltLength || header.nonce.length != _nonceLength) {
        throw const BackupFormatException('bad salt or nonce');
      }
      _checkKdf(header.kdf);
      return (header, bodyOffset);
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      // FormatException, TypeError from casts, etc. Never echo header content.
      throw const BackupFormatException('bad header');
    }
  }

  /// A hostile header must not make the phone allocate gigabytes or spin for minutes.
  static void _checkKdf(KdfParams p) {
    final ok =
        p.memoryKiB >= 8 * p.parallelism &&
        p.memoryKiB <= 1024 * 1024 &&
        p.iterations >= 1 &&
        p.iterations <= 10 &&
        p.parallelism >= 1 &&
        p.parallelism <= 8;
    if (!ok) throw const BackupFormatException('kdf parameters out of range');
  }
}
