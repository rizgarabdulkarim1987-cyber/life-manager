import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/db/app_database.dart';
import '../../finance/data/buckets_repository.dart';
import '../../finance/data/debts_repository.dart';
import '../../finance/data/rates_repository.dart';
import '../../finance/data/transactions_repository.dart';
import '../domain/proposal.dart';
import 'capture_repository.dart';

/// What the owner decided for one proposal in Capture Review.
sealed class CommitItem {
  const CommitItem();
}

/// [allocation]: base-currency amounts per bucket id, for an income.
class MoneyCommit extends CommitItem {
  const MoneyCommit(this.p, this.allocation);

  final MoneyProposal p;
  final Map<int, int>? allocation;
}

class TransferCommit extends CommitItem {
  const TransferCommit(this.p);

  final TransferProposal p;
}

/// [debtId]: the debt a repayment belongs to; null records a new debt from a principal.
class DebtCommit extends CommitItem {
  const DebtCommit(this.p, this.debtId);

  final DebtProposal p;
  final int? debtId;
}

class EditCommit extends CommitItem {
  const EditCommit(this.p);

  final EditProposal p;
}

class DeleteCommit extends CommitItem {
  const DeleteCommit(this.p);

  final DeleteProposal p;
}

/// Not saved now: moved to a new pending capture so nothing is lost (Decision 3).
class KeepInInbox extends CommitItem {
  const KeepInInbox(this.p);

  final Proposal p;
}

/// The capture was already saved or discarded, so nothing was written.
class CaptureAlreadyHandled implements Exception {
  const CaptureAlreadyHandled();
}

/// Rows one commit wrote, kept on the capture so Undo can remove them.
class _UndoLog {
  final transactions = <int>[];
  final debts = <int>[];
  final closedDebts = <int>[];

  /// Rows as they were before an edit or delete, with their bucket allocations.
  final restore = <Map<String, Object?>>[];

  bool get isEmpty => transactions.isEmpty && debts.isEmpty && closedDebts.isEmpty && restore.isEmpty;

  String encode() => jsonEncode({'tx': transactions, 'debts': debts, 'closed': closedDebts, 'restore': restore});

  static _UndoLog decode(String s) {
    final j = jsonDecode(s) as Map<String, Object?>;
    List<int> ints(String k) => [for (final v in (j[k] as List? ?? const [])) v as int];
    return _UndoLog()
      ..transactions.addAll(ints('tx'))
      ..debts.addAll(ints('debts'))
      ..closedDebts.addAll(ints('closed'))
      ..restore.addAll([for (final r in (j['restore'] as List? ?? const [])) (r as Map).cast<String, Object?>()]);
  }
}

class CaptureCommitter {
  CaptureCommitter(this._db)
    : _tx = TransactionsRepository(_db),
      _debts = DebtsRepository(_db),
      _buckets = BucketsRepository(_db, RatesRepository(_db)),
      _captures = CaptureRepository(_db);

  final AppDatabase _db;
  final TransactionsRepository _tx;
  final DebtsRepository _debts;
  final BucketsRepository _buckets;
  final CaptureRepository _captures;

  /// Writes every item and marks the capture done in one transaction: all of it or none.
  Future<void> commit(int captureId, List<CommitItem> items) async {
    for (final item in items) {
      _checkComplete(item);
    }
    final capture = await _captures.get(captureId);
    if (capture == null) throw ArgumentError.value(captureId, 'captureId', 'unknown capture');
    await _db.transaction(() async {
      // First, so a second Save (or a Save after Discard) writes nothing and the whole thing rolls back.
      if (!await _captures.markDoneIfPending(captureId)) throw const CaptureAlreadyHandled();
      final log = _UndoLog();
      for (final item in items) {
        await _write(captureId, item, log);
      }
      if (!log.isEmpty) {
        await (_db.update(
          _db.captures,
        )..where((c) => c.id.equals(captureId))).write(CapturesCompanion(undoJson: Value(log.encode())));
      }
      final kept = [for (final i in items.whereType<KeepInInbox>()) i.p];
      if (kept.isNotEmpty) await _captures.createKept(capture.transcript, kept, by: capture.parsedBy);
    });
  }

  void _checkComplete(CommitItem item) {
    switch (item) {
      case MoneyCommit(:final p):
        if (p.amountMinor == null || p.accountId == null) throw ArgumentError('the amount and account are needed');
      case TransferCommit(:final p):
        if (p.amountMinor == null || p.fromAccountId == null || p.toAccountId == null) {
          throw ArgumentError('the amount and both accounts are needed');
        }
      case DebtCommit(:final p, :final debtId):
        if (p.amountMinor == null || p.accountId == null) throw ArgumentError('the amount and account are needed');
        if (debtId == null && (p.leg != 'principal' || p.direction == null || (p.counterparty ?? '').trim().isEmpty)) {
          throw ArgumentError('a new debt needs its direction, counterparty and principal');
        }
        if (debtId != null && p.leg != 'repayment') throw ArgumentError('only repayments go on an existing debt');
      case EditCommit(:final p):
        if (p.txId == null || p.changesNothing) throw ArgumentError('an edit needs its entry and a change');
      case DeleteCommit(:final p):
        if (p.txId == null) throw ArgumentError('a delete needs its entry');
      case KeepInInbox():
        break;
    }
  }

  /// Takes back everything [commit] wrote for this capture, in one
  /// transaction, and marks it discarded. A second call does nothing.
  Future<void> undo(int captureId) => _db.transaction(() async {
    final c = await _captures.get(captureId);
    if (c == null || c.status != 'done') return;
    final log = c.undoJson == null ? _UndoLog() : _UndoLog.decode(c.undoJson!);
    if (log.transactions.isNotEmpty) {
      await (_db.delete(_db.transactions)..where((t) => t.id.isIn(log.transactions))).go();
    }
    if (log.debts.isNotEmpty) {
      await (_db.delete(_db.transactions)..where((t) => t.debtId.isIn(log.debts))).go();
      await (_db.delete(_db.debts)..where((d) => d.id.isIn(log.debts))).go();
    }
    for (final r in log.restore.reversed) {
      final old = Transaction.fromJson((r['tx']! as Map).cast<String, Object?>());
      final allocations = [
        for (final a in r['allocations']! as List) BucketAllocation.fromJson((a as Map).cast<String, Object?>()),
      ];
      await (_db.delete(_db.transactions)..where((t) => t.id.equals(old.id))).go();
      await _tx.restore(old, allocations);
    }
    if (log.closedDebts.isNotEmpty) {
      await (_db.update(
        _db.debts,
      )..where((d) => d.id.isIn(log.closedDebts))).write(const DebtsCompanion(closedAt: Value(null)));
    }
    await (_db.update(_db.captures)..where((x) => x.id.equals(captureId))).write(
      CapturesCompanion(
        status: const Value('discarded'),
        undoJson: const Value(null),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  });

  Future<void> _write(int captureId, CommitItem item, _UndoLog log) async {
    final now = DateTime.now();
    switch (item) {
      case MoneyCommit(:final p, :final allocation):
        final id = await _tx.addSimple(
          type: p.type == IntentType.income ? 'income' : 'expense',
          accountId: p.accountId!,
          amountMinor: p.amountMinor!,
          occurredAt: (p.occurredAt ?? now).toUtc(),
          categoryId: p.categoryId,
          description: p.description,
          bucketTag: p.type == IntentType.expense ? p.bucketTag : null,
          captureId: captureId,
        );
        log.transactions.add(id);
        if (p.type == IntentType.income && allocation != null && allocation.isNotEmpty) {
          await _buckets.allocate(id, allocation);
        }
      case TransferCommit(:final p):
        final id = await _tx.addTransfer(
          fromAccountId: p.fromAccountId!,
          toAccountId: p.toAccountId!,
          amountMinor: p.amountMinor!,
          occurredAt: (p.occurredAt ?? now).toUtc(),
          toAmountMinor: p.toAmountMinor,
          rateE6: p.rateE6,
          transferKind: p.transferKind ?? 'transfer',
          captureId: captureId,
        );
        log.transactions.add(id);
      case DebtCommit(:final p, :final debtId):
        final at = (p.occurredAt ?? now).toUtc();
        if (debtId != null) {
          final wasOpen =
              (await (_db.select(_db.debts)..where((d) => d.id.equals(debtId))).getSingle()).closedAt == null;
          log.transactions.add(
            await _debts.recordRepayment(
              debtId: debtId,
              accountId: p.accountId!,
              amountMinor: p.amountMinor!,
              occurredAt: at,
            ),
          );
          final closed =
              (await (_db.select(_db.debts)..where((d) => d.id.equals(debtId))).getSingle()).closedAt != null;
          if (wasOpen && closed) log.closedDebts.add(debtId);
        } else {
          final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(p.accountId!))).getSingle();
          final newDebt = await _debts.create(
            direction: p.direction!,
            counterparty: p.counterparty!,
            workspaceId: account.workspaceId,
            principalMinor: p.amountMinor!,
            currencyCode: account.currencyCode,
            startDate: at,
            recordPrincipalFromAccountId: account.id,
          );
          log.debts.add(newDebt);
        }
      case EditCommit(:final p):
        await _remember(p.txId!, log);
        await _tx.update(
          p.txId!,
          TransactionsCompanion(
            amountMinor: p.newAmountMinor == null ? const Value.absent() : Value(p.newAmountMinor!),
            categoryId: p.newCategoryId == null ? const Value.absent() : Value(p.newCategoryId),
            description: p.newDescription == null ? const Value.absent() : Value(p.newDescription),
          ),
          clearAllocations: true,
        );
      case DeleteCommit(:final p):
        await _remember(p.txId!, log);
        await _tx.delete(p.txId!);
      case KeepInInbox():
        break;
    }
  }

  Future<void> _remember(int txId, _UndoLog log) async {
    final old = await _tx.get(txId);
    if (old == null) throw StateError('transaction not found');
    final allocations = await (_db.select(_db.bucketAllocations)..where((a) => a.transactionId.equals(txId))).get();
    log.restore.add({
      'tx': old.toJson(),
      'allocations': [for (final a in allocations) a.toJson()],
    });
  }
}
