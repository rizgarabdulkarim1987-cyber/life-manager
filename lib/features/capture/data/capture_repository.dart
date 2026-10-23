import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../domain/proposal.dart';

/// An error's runtime type name (`SocketException`, `TimeoutException`), never its message.
final _typeName = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$<>, ]{0,79}$');

class CaptureRepository {
  CaptureRepository(this._db);

  final AppDatabase _db;

  DateTime get _now => DateTime.now().toUtc();

  Future<int> createVoice(Uint8List wav) => _db
      .into(_db.captures)
      .insert(
        CapturesCompanion.insert(
          source: 'voice',
          status: 'pending',
          audio: Value(wav),
          createdAt: _now,
          updatedAt: _now,
        ),
      );

  Future<int> createImage(Uint8List jpeg) => _db
      .into(_db.captures)
      .insert(
        CapturesCompanion.insert(
          source: 'image',
          status: 'pending',
          image: Value(jpeg),
          createdAt: _now,
          updatedAt: _now,
        ),
      );

  Future<int> createText(String text) => _db
      .into(_db.captures)
      .insert(
        CapturesCompanion.insert(
          source: 'text',
          status: 'pending',
          transcript: Value(text),
          createdAt: _now,
          updatedAt: _now,
        ),
      );

  /// A pending text capture holding proposals the owner kept for later (Decision 3).
  Future<int> createKept(String? transcript, List<Proposal> proposals, {String? by}) => _db
      .into(_db.captures)
      .insert(
        CapturesCompanion.insert(
          source: 'text',
          status: 'pending',
          transcript: Value(transcript),
          parsedJson: Value(encodeProposals(proposals)),
          parsedBy: Value(by),
          createdAt: _now,
          updatedAt: _now,
        ),
      );

  Future<void> _write(int id, CapturesCompanion c) =>
      (_db.update(_db.captures)..where((x) => x.id.equals(id))).write(c.copyWith(updatedAt: Value(_now)));

  Future<void> setTranscript(int id, String t) => _write(id, CapturesCompanion(transcript: Value(t)));

  /// [by] is `ai` or `rules`.
  Future<void> setParsed(int id, List<Proposal> p, {required String by}) => _write(
    id,
    CapturesCompanion(parsedJson: Value(encodeProposals(p)), parsedBy: Value(by), failureType: const Value(null)),
  );

  Future<void> setFailure(int id, String errorType) {
    if (!_typeName.hasMatch(errorType)) throw ArgumentError('pass the error type name only');
    return _write(id, CapturesCompanion(failureType: Value(errorType)));
  }

  Future<void> markDone(int id) =>
      _write(id, const CapturesCompanion(status: Value('done'), audio: Value(null), image: Value(null)));

  /// Marks a pending capture done; false when it was already handled (done, discarded or gone).
  Future<bool> markDoneIfPending(int id) async {
    final n = await (_db.update(_db.captures)..where((x) => x.id.equals(id) & x.status.equals('pending'))).write(
      CapturesCompanion(
        status: const Value('done'),
        audio: const Value(null),
        image: const Value(null),
        updatedAt: Value(_now),
      ),
    );
    return n > 0;
  }

  Future<void> discard(int id) =>
      _write(id, const CapturesCompanion(status: Value('discarded'), audio: Value(null), image: Value(null)));

  SimpleSelectStatement<$CapturesTable, Capture> _pending() =>
      _db.select(_db.captures)..where((c) => c.status.equals('pending'));

  Stream<List<Capture>> watchPending() =>
      (_pending()..orderBy([(c) => OrderingTerm.desc(c.createdAt), (c) => OrderingTerm.desc(c.id)])).watch();

  Future<Capture?> get(int id) => (_db.select(_db.captures)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<int> pendingCount() async {
    final n = _db.captures.id.count();
    final q = _db.selectOnly(_db.captures)
      ..addColumns([n])
      ..where(_db.captures.status.equals('pending'));
    return (await q.getSingle()).read(n) ?? 0;
  }
}

// Stable JSON for `parsedJson`: fixed key order, nulls left out.

String? _date(DateTime? d) => d?.toIso8601String();
DateTime? _parse(Object? s) => s is String ? DateTime.parse(s) : null;

Map<String, Object?> _clean(Map<String, Object?> m) => {
  for (final e in m.entries)
    if (e.value != null) e.key: e.value,
};

Map<String, Object?> _toJson(Proposal p) => _clean(switch (p) {
  MoneyProposal() => {
    'kind': 'money',
    'type': p.type.name,
    'confidence': p.confidence,
    'amountMinor': p.amountMinor,
    'currency': p.currency,
    'accountId': p.accountId,
    'workspaceId': p.workspaceId,
    'categoryId': p.categoryId,
    'occurredAt': _date(p.occurredAt),
    'description': p.description,
    'bucketTag': p.bucketTag,
    'newCategoryName': p.newCategoryName,
    'newAccountName': p.newAccountName,
  },
  TransferProposal() => {
    'kind': 'transfer',
    'confidence': p.confidence,
    'fromAccountId': p.fromAccountId,
    'toAccountId': p.toAccountId,
    'amountMinor': p.amountMinor,
    'toAmountMinor': p.toAmountMinor,
    'rateE6': p.rateE6,
    'transferKind': p.transferKind,
    'occurredAt': _date(p.occurredAt),
  },
  DebtProposal() => {
    'kind': 'debt',
    'confidence': p.confidence,
    'counterparty': p.counterparty,
    'direction': p.direction,
    'leg': p.leg,
    'amountMinor': p.amountMinor,
    'currency': p.currency,
    'accountId': p.accountId,
    'occurredAt': _date(p.occurredAt),
  },
  TaskProposal() => {
    'kind': 'task',
    'confidence': p.confidence,
    'title': p.title,
    'due': _date(p.due),
    'workspaceId': p.workspaceId,
    'taskKind': p.kind,
    'place': p.place,
    'hasTime': p.hasTime,
  },
  ProjectIdeaProposal() => {'kind': 'project_idea', 'title': p.title, 'description': p.description},
  NoteProposal() => {'kind': 'note', 'text': p.text, 'workspaceId': p.workspaceId},
  EditProposal() => {
    'kind': 'edit',
    'confidence': p.confidence,
    'target': p.target,
    'txId': p.txId,
    'newAmountMinor': p.newAmountMinor,
    'newCategoryId': p.newCategoryId,
    'newDescription': p.newDescription,
  },
  DeleteProposal() => {'kind': 'delete', 'confidence': p.confidence, 'target': p.target, 'txId': p.txId},
});

Proposal _fromJson(Map<String, Object?> j) {
  int? i(String k) => j[k] as int?;
  String? s(String k) => j[k] as String?;
  return switch (j['kind']) {
    'money' => MoneyProposal(
      type: IntentType.values.byName(s('type')!),
      confidence: i('confidence')!,
      amountMinor: i('amountMinor'),
      currency: s('currency'),
      accountId: i('accountId'),
      workspaceId: i('workspaceId'),
      categoryId: i('categoryId'),
      occurredAt: _parse(j['occurredAt']),
      description: s('description'),
      bucketTag: s('bucketTag'),
      newCategoryName: s('newCategoryName'),
      newAccountName: s('newAccountName'),
    ),
    'transfer' => TransferProposal(
      confidence: i('confidence')!,
      fromAccountId: i('fromAccountId'),
      toAccountId: i('toAccountId'),
      amountMinor: i('amountMinor'),
      toAmountMinor: i('toAmountMinor'),
      rateE6: i('rateE6'),
      transferKind: s('transferKind'),
      occurredAt: _parse(j['occurredAt']),
    ),
    'debt' => DebtProposal(
      confidence: i('confidence')!,
      counterparty: s('counterparty'),
      direction: s('direction'),
      leg: s('leg'),
      amountMinor: i('amountMinor'),
      currency: s('currency'),
      accountId: i('accountId'),
      occurredAt: _parse(j['occurredAt']),
    ),
    'task' => TaskProposal(
      title: s('title')!,
      confidence: i('confidence')!,
      due: _parse(j['due']),
      workspaceId: i('workspaceId'),
      kind: s('taskKind') ?? 'task',
      place: s('place'),
      hasTime: j['hasTime'] == true,
    ),
    'project_idea' => ProjectIdeaProposal(title: s('title')!, description: s('description')),
    'note' => NoteProposal(text: s('text')!, workspaceId: i('workspaceId')),
    'edit' => EditProposal(
      confidence: i('confidence')!,
      target: s('target') ?? kTargetLast,
      txId: i('txId'),
      newAmountMinor: i('newAmountMinor'),
      newCategoryId: i('newCategoryId'),
      newDescription: s('newDescription'),
    ),
    'delete' => DeleteProposal(confidence: i('confidence')!, target: s('target') ?? kTargetLast, txId: i('txId')),
    _ => throw const FormatException('unknown proposal kind'),
  };
}

String encodeProposals(List<Proposal> ps) => jsonEncode([for (final p in ps) _toJson(p)]);

List<Proposal> decodeProposals(String json) => [
  for (final j in jsonDecode(json) as List) _fromJson((j as Map).cast<String, Object?>()),
];
