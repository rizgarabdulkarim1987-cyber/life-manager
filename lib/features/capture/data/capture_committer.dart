import '../../../core/db/app_database.dart';
import '../../finance/data/buckets_repository.dart';
import '../../finance/data/debts_repository.dart';
import '../../finance/data/rates_repository.dart';
import '../../finance/data/transactions_repository.dart';
import '../../tasks/data/tasks_repository.dart';
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

/// A task from a capture: saved into Tasks with the capture's id.
class TaskCommit extends CommitItem {
  const TaskCommit(this.p);

  final TaskProposal p;
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

class CaptureCommitter {
  CaptureCommitter(this._db)
    : _tx = TransactionsRepository(_db),
      _debts = DebtsRepository(_db),
      _buckets = BucketsRepository(_db, RatesRepository(_db)),
      _captures = CaptureRepository(_db),
      _tasks = TasksRepository(_db);

  final AppDatabase _db;
  final TransactionsRepository _tx;
  final DebtsRepository _debts;
  final BucketsRepository _buckets;
  final CaptureRepository _captures;
  final TasksRepository _tasks;

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
      for (final item in items) {
        await _write(captureId, item);
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
      case TaskCommit(:final p):
        if (p.title.trim().isEmpty) throw ArgumentError('a task needs a title');
      case KeepInInbox():
        break;
    }
  }

  Future<void> _write(int captureId, CommitItem item) async {
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
        if (p.type == IntentType.income && allocation != null && allocation.isNotEmpty) {
          await _buckets.allocate(id, allocation);
        }
      case TransferCommit(:final p):
        await _tx.addTransfer(
          fromAccountId: p.fromAccountId!,
          toAccountId: p.toAccountId!,
          amountMinor: p.amountMinor!,
          occurredAt: (p.occurredAt ?? now).toUtc(),
          toAmountMinor: p.toAmountMinor,
          rateE6: p.rateE6,
          transferKind: p.transferKind ?? 'transfer',
          captureId: captureId,
        );
      case DebtCommit(:final p, :final debtId):
        final at = (p.occurredAt ?? now).toUtc();
        if (debtId != null) {
          await _debts.recordRepayment(
            debtId: debtId,
            accountId: p.accountId!,
            amountMinor: p.amountMinor!,
            occurredAt: at,
          );
        } else {
          final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(p.accountId!))).getSingle();
          await _debts.create(
            direction: p.direction!,
            counterparty: p.counterparty!,
            workspaceId: account.workspaceId,
            principalMinor: p.amountMinor!,
            currencyCode: account.currencyCode,
            startDate: at,
            recordPrincipalFromAccountId: account.id,
          );
        }
      case TaskCommit(:final p):
        final due = p.due;
        await _tasks.create(
          TaskInput(
            title: p.title,
            dueAt: due,
            dueAllDay: due != null && due.hour == 0 && due.minute == 0,
            workspaceId: p.workspaceId,
            captureId: captureId,
          ),
        );
      case KeepInInbox():
        break;
    }
  }
}
