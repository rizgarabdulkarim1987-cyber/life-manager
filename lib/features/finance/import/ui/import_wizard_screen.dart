import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_format.dart';
import '../../../../core/text/digits.dart';
import '../../../../core/theme/tokens.dart';
import '../../../settings/workspaces_screen.dart' show kWorkspaceColors;
import '../../data/categories_repository.dart';
import '../../data/finance_providers.dart';
import '../../data/workspaces_repository.dart';
import '../../ui/ui_format.dart';
import '../../ui/widgets/amount_field.dart';
import '../../ui/widgets/money_text.dart';
import '../../ui/widgets/panel.dart';
import '../csv_reader.dart';
import '../import_mapping.dart';
import '../import_service.dart';
import '../sheet.dart';
import '../xlsx_reader.dart';

/// Written on the adjustment that sets an account to its real balance.
const kImportAdjustmentNote = 'تسوية بعد الاستيراد';

typedef PickedImportFile = ({String name, Uint8List bytes});

/// Where import files come from: the Android system picker.
abstract interface class ImportFiles {
  Future<PickedImportFile?> pick();
}

class FilePickerImportFiles implements ImportFiles {
  const FilePickerImportFiles();

  @override
  Future<PickedImportFile?> pick() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['xlsx', 'csv']);
    if (files.isEmpty) return null;
    return (name: files.first.name, bytes: await files.first.readAsBytes());
  }
}

final importFilesProvider = Provider<ImportFiles>((ref) => const FilePickerImportFiles());

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(ref.watch(appDatabaseProvider), ref.watch(transactionsRepositoryProvider)),
);

final importBatchesProvider = StreamProvider<List<ImportBatche>>(
  (ref) => ref.watch(importServiceProvider).watchBatches(),
);

/// Header words, in Arabic, English and Kurdish, that name each column.
const _guesses = <String, List<String>>{
  'date': ['تاريخ', 'date', 'بەروار', 'يوم', 'day'],
  'income': ['وارد', 'income', 'credit', 'دخل', 'داهات', 'deposit'],
  'expense': ['صادر', 'expense', 'debit', 'مصروف', 'مصاريف', 'خەرجی', 'withdrawal'],
  'amount': ['مبلغ', 'amount', 'بڕ', 'قيمة', 'value', 'sum', 'total'],
  'type': ['نوع', 'type', 'جۆر', 'kind'],
  'currency': ['عملة', 'currency', 'دراو'],
  'category': ['فئة', 'category', 'پۆل', 'تصنيف', 'بند'],
  'workspace': ['مساحة', 'workspace', 'شوێن', 'project', 'مشروع'],
  'account': ['حساب', 'account', 'هەژمار'],
  'description': ['وصف', 'description', 'وەسف', 'ملاحظة', 'note', 'تفاصيل', 'details', 'memo', 'بەیان'],
};

/// Column index per role, guessed from the header names. Each column is used once.
Map<String, int> guessColumns(List<String> headers) {
  final out = <String, int>{};
  final used = <int>{};
  for (final e in _guesses.entries) {
    for (var i = 0; i < headers.length; i++) {
      if (used.contains(i)) continue;
      final h = normalizeForMatch(headers[i]);
      if (h.isEmpty) continue;
      if (e.value.any((w) => h.contains(normalizeForMatch(w)))) {
        out[e.key] = i;
        used.add(i);
        break;
      }
    }
  }
  return out;
}

/// income / expense / skip for a raw type value, when the word is clear.
String? guessType(String raw) {
  final v = normalizeForMatch(raw.trim());
  bool any(List<String> ws) => ws.any((w) => v.contains(normalizeForMatch(w)));
  if (any(const ['وارد', 'دخل', 'income', 'credit', 'deposit', 'داهات', 'قبض'])) return 'income';
  if (any(const ['صادر', 'صرف', 'مصروف', 'expense', 'debit', 'withdraw', 'خەرجی', 'دفع'])) return 'expense';
  if (any(const ['تحويل', 'transfer', 'گواستنەوە'])) return 'skip';
  return null;
}

String columnLetter(int i) {
  var n = i + 1;
  var s = '';
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

/// "Create new" in a value-map dropdown.
const _create = -1;

class ImportWizardScreen extends ConsumerStatefulWidget {
  const ImportWizardScreen({super.key});

  @override
  ConsumerState<ImportWizardScreen> createState() => _ImportWizardScreenState();
}

class _ImportWizardScreenState extends ConsumerState<ImportWizardScreen> {
  static const _steps = 6;
  int _step = 0;

  // Step 1
  String? _fileName;
  List<Sheet> _sheets = const [];
  int _sheet = 0;
  int _header = 0;
  String? _fileError;

  // Step 2
  int? _dateCol, _amountCol, _incomeCol, _expenseCol, _typeCol, _currencyCol;
  int? _categoryCol, _workspaceCol, _accountCol, _descriptionCol;
  DateOrder _dateOrder = DateOrder.dayFirst;
  AmountMode _amountMode = AmountMode.signed;

  // Step 3
  String _currency = 'IQD';
  int? _workspace;
  final _accountFor = <String, int?>{};

  // Step 4: raw value → choice.
  final _types = <String, String?>{};
  final _categories = <String, int?>{};
  final _workspaces = <String, int?>{};
  final _accounts = <String, int?>{};

  // Step 5
  List<ImportRow> _preview = const [];
  Set<String> _existing = const {};
  bool _skipDuplicates = true;
  bool _busy = false;

  // Step 6
  List<int> _touched = const [];
  int? _batchId;
  final _computed = <int, Money>{};
  final _actual = <int, int?>{};

  Sheet get _current => _sheets[_sheet];

  List<String> get _headers => [for (final c in _current.rows[_header]) cellText(c).trim()];

  int get _columnCount => _current.rows.skip(_header).take(50).fold<int>(0, (m, r) => r.length > m ? r.length : m);

  // ---- step 1 ----

  Future<void> _pickFile() async {
    final l = context.l10n;
    final picked = await ref.read(importFilesProvider).pick();
    if (picked == null) return;
    try {
      final sheets = picked.name.toLowerCase().endsWith('.csv') ? readCsv(picked.bytes) : readXlsx(picked.bytes);
      setState(() {
        _fileName = picked.name;
        _sheets = sheets.where((s) => s.rows.isNotEmpty).toList();
        _fileError = _sheets.isEmpty ? l.impUnreadable : null;
        _sheet = 0;
        _selectSheet(0);
      });
    } on ImportTooLarge {
      setState(() => _fileError = l.impTooLarge);
    } on ImportFormatException {
      setState(() => _fileError = l.impUnreadable);
    } catch (e) {
      AppLogger.error('import read failed', e.runtimeType);
      setState(() => _fileError = l.impUnreadable);
    }
  }

  void _selectSheet(int i) {
    _sheet = i;
    if (_sheets.isEmpty) return;
    final firstFilled = _current.rows.indexWhere((r) => r.any((c) => c is! EmptyCell));
    _header = firstFilled < 0 ? 0 : firstFilled;
    _applyGuesses();
  }

  void _applyGuesses() {
    final g = guessColumns(_headers);
    _dateCol = g['date'];
    _incomeCol = g['income'];
    _expenseCol = g['expense'];
    _amountCol = g['amount'];
    _typeCol = g['type'];
    _currencyCol = g['currency'];
    _categoryCol = g['category'];
    _workspaceCol = g['workspace'];
    _accountCol = g['account'];
    _descriptionCol = g['description'];
    _amountMode = _amountCol == null && _incomeCol != null && _expenseCol != null
        ? AmountMode.splitColumns
        : _typeCol != null
        ? AmountMode.typeColumn
        : AmountMode.signed;
  }

  // ---- shared planning ----

  ColumnMapping get _mapping => ColumnMapping(
    dateCol: _dateCol ?? 0,
    dateOrder: _dateOrder,
    amountMode: _amountMode,
    amountCol: _amountMode == AmountMode.splitColumns ? null : _amountCol,
    incomeCol: _amountMode == AmountMode.splitColumns ? _incomeCol : null,
    expenseCol: _amountMode == AmountMode.splitColumns ? _expenseCol : null,
    typeCol: _amountMode == AmountMode.typeColumn ? _typeCol : null,
    currencyCol: _currencyCol,
    categoryCol: _categoryCol,
    workspaceCol: _workspaceCol,
    accountCol: _accountCol,
    descriptionCol: _descriptionCol,
  );

  bool get _columnsReady =>
      _dateCol != null &&
      switch (_amountMode) {
        AmountMode.signed => _amountCol != null,
        AmountMode.typeColumn => _amountCol != null && _typeCol != null,
        AmountMode.splitColumns => _incomeCol != null && _expenseCol != null,
      };

  List<String> _distinct(int? col) {
    if (col == null) return const [];
    final out = <String>{};
    for (final r in _current.rows.skip(_header + 1)) {
      final v = col < r.length ? cellText(r[col]).trim() : '';
      if (v.isNotEmpty) out.add(v);
      if (out.length >= 200) break;
    }
    return out.toList();
  }

  Set<String> get _usedCurrencies => {
    _currency,
    for (final v in _distinct(_currencyCol))
      if (kCurrencyExponents.containsKey(v.toUpperCase())) v.toUpperCase(),
  };

  /// Plans with real ids, or with stand-in negative ids for "create new" items
  /// (preview) — [created] maps each such raw value to the id to use.
  List<ImportRow> _plan({
    required Map<String, int> createdCategories,
    required Map<String, int> createdWorkspaces,
    required Map<String, int> createdAccounts,
    required Map<String, int> extraAccounts,
  }) {
    int? pick(Map<String, int?> choices, Map<String, int> created, String raw) =>
        choices[raw] == _create ? created[raw] : choices[raw];
    final defaults = ImportDefaults(
      currency: _currency,
      workspaceId: _workspace!,
      accountByWorkspaceCurrency: {
        for (final e in _accountFor.entries)
          if (e.value != null) e.key: e.value!,
        ...extraAccounts,
      },
    );
    final maps = ValueMaps(
      typeValues: {
        for (final e in _types.entries)
          if (e.value != null) e.key: e.value!,
      },
      categories: {for (final raw in _categories.keys) raw: pick(_categories, createdCategories, raw)},
      workspaces: {for (final raw in _workspaces.keys) raw: pick(_workspaces, createdWorkspaces, raw)},
      accounts: {for (final raw in _accounts.keys) raw: pick(_accounts, createdAccounts, raw)},
    );
    return planImport(_current, _header, _mapping, defaults, maps, existingKeys: _existing);
  }

  (Map<String, int>, Map<String, int>, Map<String, int>, Map<String, int>) _standIns() {
    var next = -1;
    final cats = {
      for (final e in _categories.entries)
        if (e.value == _create) e.key: next--,
    };
    final ws = {
      for (final e in _workspaces.entries)
        if (e.value == _create) e.key: next--,
    };
    final acc = {
      for (final e in _accounts.entries)
        if (e.value == _create) e.key: next--,
    };
    final extra = {
      for (final id in ws.values)
        for (final c in _usedCurrencies) '$id:$c': next--,
    };
    return (cats, ws, acc, extra);
  }

  Future<void> _buildPreview() async {
    final (c, w, a, x) = _standIns();
    _existing = const {};
    final first = _plan(createdCategories: c, createdWorkspaces: w, createdAccounts: a, extraAccounts: x);
    final dates = first.where((r) => r.problem == null).map((r) => r.occurredAt).toList()..sort();
    if (dates.isNotEmpty) {
      _existing = await ref.read(importServiceProvider).existingKeys(dates.first, dates.last);
    }
    if (!mounted) return;
    setState(() => _preview = _plan(createdCategories: c, createdWorkspaces: w, createdAccounts: a, extraAccounts: x));
  }

  // ---- import ----

  Future<void> _commit() async {
    setState(() => _busy = true);
    final db = ref.read(appDatabaseProvider);
    final cats = ref.read(categoriesRepositoryProvider);
    final wss = ref.read(workspacesRepositoryProvider);
    final accs = ref.read(accountsRepositoryProvider);
    final svc = ref.read(importServiceProvider);
    try {
      final rows = await db.transaction(() async {
        // Kind of a new category: what most of its rows turned out to be.
        final kinds = <String, int>{};
        if (_categoryCol != null) {
          for (final r in _preview.where((r) => r.problem == null)) {
            final row = _current.rows[r.sourceRow - 1];
            final raw = _categoryCol! < row.length ? cellText(row[_categoryCol!]).trim() : '';
            kinds[raw] = (kinds[raw] ?? 0) + (r.type == 'income' ? 1 : -1);
          }
        }
        final createdCats = <String, int>{
          for (final e in _categories.entries)
            if (e.value == _create)
              e.key: await cats.create(kind: (kinds[e.key] ?? -1) > 0 ? 'income' : 'expense', name: e.key),
        };
        final createdWs = <String, int>{};
        final extra = <String, int>{};
        var colour = 0;
        for (final e in _workspaces.entries.where((e) => e.value == _create)) {
          final id = await wss.create(
            name: e.key,
            iconKey: 'folder',
            colorArgb: kWorkspaceColors[colour++ % kWorkspaceColors.length],
          );
          createdWs[e.key] = id;
          for (final c in _usedCurrencies) {
            extra['$id:$c'] = await accs.create(workspaceId: id, name: '${e.key} · $c', kind: 'cash', currencyCode: c);
          }
        }
        final createdAcc = <String, int>{
          for (final e in _accounts.entries)
            if (e.value == _create)
              e.key: await accs.create(workspaceId: _workspace!, name: e.key, kind: 'cash', currencyCode: _currency),
        };
        final planned = _plan(
          createdCategories: createdCats,
          createdWorkspaces: createdWs,
          createdAccounts: createdAcc,
          extraAccounts: extra,
        );
        _batchId = await svc.commit(_fileName!, planned, skipDuplicates: _skipDuplicates);
        return planned;
      });
      final touched = {
        for (final r in rows)
          if (r.problem == null && !(_skipDuplicates && r.duplicate)) r.accountId,
      }.toList();
      for (final id in touched) {
        _computed[id] = await accs.balanceOf(id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.impImported(rows.where((r) => r.problem == null).length))));
      setState(() {
        _touched = touched;
        _step = 5;
      });
    } catch (e) {
      AppLogger.error('import commit failed', e.runtimeType);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveBalances() async {
    final tx = ref.read(transactionsRepositoryProvider);
    // Tagged with the batch, so undoing the import removes these too.
    try {
      await ref.read(appDatabaseProvider).transaction(() async {
        for (final id in _touched) {
          final actual = _actual[id];
          final computed = _computed[id];
          if (actual == null || computed == null || actual == computed.minor) continue;
          await tx.addSimple(
            type: 'adjustment',
            accountId: id,
            amountMinor: actual - computed.minor,
            occurredAt: DateTime.now().toUtc(),
            description: kImportAdjustmentNote,
            importBatchId: _batchId,
          );
        }
      });
    } on Exception catch (e) {
      AppLogger.error('import balances failed', e.runtimeType);
      return;
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  // ---- navigation ----

  bool get _canNext => switch (_step) {
    0 => _sheets.isNotEmpty,
    1 => _columnsReady,
    2 => _workspace != null,
    _ => true,
  };

  Future<void> _next() async {
    if (_step == 1) _prepareDefaults();
    if (_step == 2) _prepareValues();
    setState(() => _step++);
    if (_step == 4) await _buildPreview();
  }

  void _prepareDefaults() {
    final workspaces = ref.read(workspacesProvider).value ?? const <Workspace>[];
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    _workspace ??= workspaces.firstOrNull?.id;
    for (final w in workspaces) {
      for (final c in _usedCurrencies) {
        _accountFor.putIfAbsent(
          '${w.id}:$c',
          () => accounts.where((a) => a.workspaceId == w.id && a.currencyCode == c).firstOrNull?.id,
        );
      }
    }
  }

  void _prepareValues() {
    final l = context.l10n;
    final workspaces = ref.read(workspacesProvider).value ?? const <Workspace>[];
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    final categories = ref.read(categoriesProvider).value ?? const <Category>[];
    for (final raw in _distinct(_amountMode == AmountMode.typeColumn ? _typeCol : null)) {
      _types.putIfAbsent(raw, () => guessType(raw));
    }
    for (final raw in _distinct(_categoryCol)) {
      final n = normalizeForMatch(raw);
      _categories.putIfAbsent(
        raw,
        () => categories
            .where(
              (c) => normalizeForMatch(categoryLabel(c, l)) == n || extraKeywords(c).map(normalizeForMatch).contains(n),
            )
            .firstOrNull
            ?.id,
      );
    }
    for (final raw in _distinct(_workspaceCol)) {
      final n = normalizeForMatch(raw);
      _workspaces.putIfAbsent(
        raw,
        () => workspaces
            .where((w) => normalizeForMatch(w.name) == n || workspaceAliases(w).map(normalizeForMatch).contains(n))
            .firstOrNull
            ?.id,
      );
    }
    for (final raw in _distinct(_accountCol)) {
      final n = normalizeForMatch(raw);
      _accounts.putIfAbsent(raw, () => accounts.where((a) => normalizeForMatch(a.name) == n).firstOrNull?.id);
    }
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    // Watched here so the lists are live when a later step reads them.
    ref.watch(workspacesProvider);
    ref.watch(accountsProvider);
    ref.watch(categoriesProvider);
    final titles = [
      l.impStepFile,
      l.impStepColumns,
      l.impStepDefaults,
      l.impStepValues,
      l.impStepPreview,
      l.impStepOpening,
    ];
    final body = switch (_step) {
      0 => _fileStep(),
      1 => _columnsStep(),
      2 => _defaultsStep(),
      3 => _valuesStep(),
      4 => _previewStep(),
      _ => _openingStep(),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l.impTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l.impStepOf(_step + 1, _steps)} · ${titles[_step]}',
                  style: text.labelMedium?.copyWith(color: k.textMuted),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / _steps,
                    minHeight: 4,
                    backgroundColor: k.surfaceHigh,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: KeyedSubtree(key: ValueKey('wizard-step-$_step'), child: body),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (_step > 0 && _step < 5)
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('wizard-back'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _busy ? null : () => setState(() => _step--),
                    child: Text(l.impBack),
                  ),
                ),
              if (_step > 0 && _step < 5) const SizedBox(width: 12),
              Expanded(flex: 2, child: _primaryButton()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryButton() {
    final l = context.l10n;
    final style = FilledButton.styleFrom(minimumSize: const Size.fromHeight(52));
    if (_step == 4) {
      final ready = _preview.where((r) => r.problem == null && !(_skipDuplicates && r.duplicate)).length;
      return FilledButton(
        key: const ValueKey('import-commit'),
        style: style,
        onPressed: _busy || ready == 0 ? null : _commit,
        child: Text(l.impImport(ready)),
      );
    }
    if (_step == 5) {
      return FilledButton(
        key: const ValueKey('opening-save'),
        style: style,
        onPressed: _saveBalances,
        child: Text(_actual.values.any((v) => v != null) ? l.impSaveBalances : l.impDone),
      );
    }
    return FilledButton(
      key: const ValueKey('wizard-next'),
      style: style,
      onPressed: _canNext ? _next : null,
      child: Text(l.impNext),
    );
  }

  Widget _list(List<Widget> children) =>
      ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: children);

  Widget _hint(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(s, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.tokens.textMuted)),
  );

  Widget _fileStep() {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    return _list([
      _hint(l.impPickHint),
      if (_fileName != null)
        Panel(
          child: Row(
            children: [
              Icon(Icons.description_outlined, color: k.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_fileName!, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyLarge),
              ),
            ],
          ),
        ),
      FilledButton.tonalIcon(
        key: const ValueKey('import-pick'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: _pickFile,
        icon: const Icon(Icons.upload_file_rounded),
        label: Text(_fileName == null ? l.impPick : l.impPickAnother),
      ),
      if (_fileError != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(_fileError!, style: text.bodyMedium?.copyWith(color: k.danger)),
        ),
      if (_sheets.length > 1) ...[
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: const ValueKey('import-sheet'),
          initialValue: _sheet,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.impSheet),
          items: [
            for (final (i, s) in _sheets.indexed)
              DropdownMenuItem(value: i, child: Text(s.name.isEmpty ? '${i + 1}' : s.name)),
          ],
          onChanged: (v) => setState(() => _selectSheet(v ?? 0)),
        ),
      ],
      if (_sheets.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(l.impHeaderRow, style: text.titleSmall),
        const SizedBox(height: 6),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < _current.rows.length && i < 10; i++)
                ListTile(
                  key: ValueKey('header-row-$i'),
                  selected: _header == i,
                  leading: Icon(_header == i ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                  title: Text(l.impRowN(i + 1), style: text.labelMedium),
                  subtitle: Text(
                    _current.rows[i].map(cellText).where((s) => s.trim().isNotEmpty).take(4).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => setState(() {
                    _header = i;
                    _applyGuesses();
                  }),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 24),
      const _PastImports(),
    ]);
  }

  Widget _columnPicker(String key, String label, int? value, ValueChanged<int?> onChanged) {
    final l = context.l10n;
    final headers = _headers;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        key: ValueKey(key),
        initialValue: value ?? -1,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem(value: -1, child: Text(l.impNone)),
          for (var i = 0; i < _columnCount; i++)
            DropdownMenuItem(
              value: i,
              child: Text(
                i < headers.length && headers[i].isNotEmpty
                    ? '${headers[i]} (${columnLetter(i)})'
                    : l.impColumnLetter(columnLetter(i)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) => setState(() => onChanged(v == null || v < 0 ? null : v)),
      ),
    );
  }

  Widget _columnsStep() {
    final l = context.l10n;
    final k = context.tokens;
    return _list([
      _columnPicker('col-date', l.impColDate, _dateCol, (v) => _dateCol = v),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<DateOrder>(
          key: const ValueKey('date-order'),
          initialValue: _dateOrder,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.impDateOrder),
          items: [
            DropdownMenuItem(value: DateOrder.dayFirst, child: Text(l.impDayFirst)),
            DropdownMenuItem(value: DateOrder.monthFirst, child: Text(l.impMonthFirst)),
            DropdownMenuItem(value: DateOrder.iso, child: Text(l.impYearFirst)),
          ],
          onChanged: (v) => setState(() => _dateOrder = v ?? _dateOrder),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<AmountMode>(
          key: const ValueKey('amount-mode'),
          initialValue: _amountMode,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.impAmountMode),
          items: [
            DropdownMenuItem(value: AmountMode.signed, child: Text(l.impSigned)),
            DropdownMenuItem(value: AmountMode.typeColumn, child: Text(l.impTypeColumn)),
            DropdownMenuItem(value: AmountMode.splitColumns, child: Text(l.impSplit)),
          ],
          onChanged: (v) => setState(() => _amountMode = v ?? _amountMode),
        ),
      ),
      if (_amountMode != AmountMode.splitColumns)
        _columnPicker('col-amount', l.impColAmount, _amountCol, (v) => _amountCol = v),
      if (_amountMode == AmountMode.typeColumn) _columnPicker('col-type', l.impColType, _typeCol, (v) => _typeCol = v),
      if (_amountMode == AmountMode.splitColumns) ...[
        _columnPicker('col-income', l.impColIncome, _incomeCol, (v) => _incomeCol = v),
        _columnPicker('col-expense', l.impColExpense, _expenseCol, (v) => _expenseCol = v),
      ],
      const Divider(height: 24),
      _columnPicker('col-description', l.impColDescription, _descriptionCol, (v) => _descriptionCol = v),
      _columnPicker('col-category', l.impColCategory, _categoryCol, (v) => _categoryCol = v),
      _columnPicker('col-currency', l.impColCurrency, _currencyCol, (v) => _currencyCol = v),
      _columnPicker('col-workspace', l.impColWorkspace, _workspaceCol, (v) => _workspaceCol = v),
      _columnPicker('col-account', l.impColAccount, _accountCol, (v) => _accountCol = v),
      if (!_columnsReady)
        Text(l.impNeedDateAmount, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: k.warning)),
    ]);
  }

  Widget _defaultsStep() {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final workspaces = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    String wsName(int id) => workspaces.where((w) => w.id == id).firstOrNull?.name ?? '';
    return _list([
      _hint(l.impDefaultsHint),
      SegmentedButton<String>(
        key: const ValueKey('default-currency'),
        segments: const [
          ButtonSegment(value: 'IQD', label: Text('IQD')),
          ButtonSegment(value: 'USD', label: Text('USD')),
        ],
        selected: {_currency},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() {
          _currency = s.first;
          _prepareDefaults();
        }),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<int>(
        key: const ValueKey('default-workspace'),
        initialValue: _workspace,
        isExpanded: true,
        decoration: InputDecoration(labelText: l.impColWorkspace),
        items: [for (final w in workspaces) DropdownMenuItem(value: w.id, child: Text(w.name))],
        onChanged: (v) => setState(() => _workspace = v),
      ),
      const SizedBox(height: 20),
      Text(l.impColAccount, style: text.titleSmall),
      const SizedBox(height: 8),
      for (final w in workspaces)
        for (final c in _usedCurrencies)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<int>(
              key: ValueKey('default-account-${w.id}-$c'),
              initialValue: _accountFor['${w.id}:$c'],
              isExpanded: true,
              decoration: InputDecoration(labelText: '${wsName(w.id)} · $c'),
              items: [
                for (final a in accounts.where((a) => a.workspaceId == w.id && a.currencyCode == c))
                  DropdownMenuItem(
                    value: a.id,
                    child: Text(shortAccountName(a.name, w.name), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _accountFor['${w.id}:$c'] = v),
            ),
          ),
    ]);
  }

  Widget _valueRows<T>(
    String section,
    String keyPrefix,
    Map<String, T?> choices,
    List<DropdownMenuItem<T?>> Function() items,
  ) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(section, style: text.titleSmall),
        ),
        for (final (i, raw) in choices.keys.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(raw, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<T?>(
                    key: ValueKey('value-$keyPrefix-$i'),
                    initialValue: choices[raw],
                    isExpanded: true,
                    items: items(),
                    onChanged: (v) => setState(() => choices[raw] = v),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _valuesStep() {
    final l = context.l10n;
    final workspaces = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    String wsName(int id) => workspaces.where((w) => w.id == id).firstOrNull?.name ?? '';
    if (_types.isEmpty && _categories.isEmpty && _workspaces.isEmpty && _accounts.isEmpty) {
      return _list([_hint(l.impNoValues)]);
    }
    DropdownMenuItem<T?> item<T>(T? v, String label) => DropdownMenuItem<T?>(
      value: v,
      child: Text(label, overflow: TextOverflow.ellipsis),
    );
    return _list([
      if (_types.isNotEmpty)
        _valueRows<String>(
          l.impColType,
          'type',
          _types,
          () => [
            item<String>(null, '—'),
            item('income', l.typeIncome),
            item('expense', l.typeExpense),
            item('skip', l.impSkipRow),
          ],
        ),
      if (_categories.isNotEmpty)
        _valueRows<int>(
          l.impColCategory,
          'category',
          _categories,
          () => [
            item<int>(null, l.impLeaveEmpty),
            item(_create, l.impCreateNew),
            for (final c in categories) item(c.id, categoryLabel(c, l)),
          ],
        ),
      if (_workspaces.isNotEmpty)
        _valueRows<int>(
          l.impColWorkspace,
          'workspace',
          _workspaces,
          () => [
            item<int>(null, l.impUseDefault),
            item(_create, l.impCreateNew),
            for (final w in workspaces) item(w.id, w.name),
          ],
        ),
      if (_accounts.isNotEmpty)
        _valueRows<int>(
          l.impColAccount,
          'account',
          _accounts,
          () => [
            item<int>(null, l.impUseDefault),
            item(_create, l.impCreateNew),
            for (final a in accounts)
              item(a.id, '${shortAccountName(a.name, wsName(a.workspaceId))} · ${wsName(a.workspaceId)}'),
          ],
        ),
    ]);
  }

  Widget _previewStep() {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final ready = _preview.where((r) => r.problem == null && !r.duplicate).length;
    final dups = _preview.where((r) => r.problem == null && r.duplicate).length;
    final problems = _preview.where((r) => r.problem != null).length;
    String currencyOf(int accountId) => accounts.where((a) => a.id == accountId).firstOrNull?.currencyCode ?? _currency;
    String problemText(String p) => switch (p) {
      'date' => l.impProblemDate,
      'amount' => l.impProblemAmount,
      'type' => l.impProblemType,
      _ => l.impProblemAccount,
    };
    Widget stat(String key, String label, int n, Color color) => Expanded(
      child: Panel(
        key: ValueKey(key),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$n',
              style: text.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(label, maxLines: 2, style: text.bodySmall?.copyWith(color: k.textMuted)),
          ],
        ),
      ),
    );
    return _list([
      Row(
        children: [
          stat('count-ready', l.impReady, ready, k.text),
          const SizedBox(width: 8),
          stat('count-duplicate', l.impDuplicates, dups, dups > 0 ? k.warning : k.text),
          const SizedBox(width: 8),
          stat('count-problem', l.impProblems, problems, problems > 0 ? k.danger : k.text),
        ],
      ),
      SwitchListTile(
        key: const ValueKey('skip-duplicates'),
        contentPadding: EdgeInsets.zero,
        title: Text(l.impSkipDuplicates),
        value: _skipDuplicates,
        onChanged: (v) => setState(() => _skipDuplicates = v),
      ),
      const SizedBox(height: 8),
      Text(l.impFirstRows(_preview.length < 20 ? _preview.length : 20), style: text.titleSmall),
      const SizedBox(height: 6),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final r in _preview.take(20))
              ListTile(
                dense: true,
                leading: Text('${r.sourceRow}', style: text.labelSmall?.copyWith(color: k.textMuted)),
                minLeadingWidth: 24,
                title: Text(
                  r.problem != null
                      ? problemText(r.problem!)
                      : [formatDate(context, r.occurredAt), if (r.description != null) r.description!].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: r.problem != null ? k.danger : null),
                ),
                subtitle: r.duplicate && r.problem == null
                    ? Text(l.impDuplicateTag, style: TextStyle(color: k.warning))
                    : null,
                trailing: r.problem != null
                    ? null
                    : MoneyText(
                        Money(r.type == 'income' ? r.amountMinor : -r.amountMinor, currencyOf(r.accountId)),
                        signed: true,
                      ),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _openingStep() {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final workspaces = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    return _list([
      _hint(l.impOpeningHint),
      for (final id in _touched)
        Builder(
          builder: (context) {
            final a = accounts.where((a) => a.id == id).firstOrNull;
            final computed = _computed[id];
            if (a == null || computed == null) return const SizedBox.shrink();
            final ws = workspaces.where((w) => w.id == a.workspaceId).firstOrNull?.name ?? '';
            return Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${shortAccountName(a.name, ws)} · $ws', style: text.titleSmall?.copyWith(color: k.text)),
                  const SizedBox(height: 4),
                  Text(
                    l.impComputed(formatMoney(computed, localeCode: langOf(context))),
                    style: text.bodySmall?.copyWith(color: k.textMuted),
                  ),
                  const SizedBox(height: 10),
                  AmountField(
                    fieldKey: ValueKey('actual-$id'),
                    currency: a.currencyCode,
                    label: l.impActual,
                    onMinor: (v) => setState(() => _actual[id] = v),
                  ),
                ],
              ),
            );
          },
        ),
    ]);
  }
}

/// Earlier imports with Undo.
class _PastImports extends ConsumerWidget {
  const _PastImports();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final batches = ref.watch(importBatchesProvider).value ?? const <ImportBatche>[];
    if (batches.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.impPastImports, style: text.titleSmall),
        const SizedBox(height: 6),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final b in batches)
                ListTile(
                  leading: Icon(Icons.history_rounded, color: k.textMuted),
                  title: Text(b.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(l.impBatchLine(b.rowCount, formatDate(context, b.createdAt.toLocal()))),
                  trailing: b.undoneAt != null
                      ? Text(l.impUndone, style: text.labelMedium?.copyWith(color: k.textMuted))
                      : TextButton(
                          key: ValueKey('undo-batch-${b.id}'),
                          onPressed: () => _undo(context, ref, b),
                          child: Text(l.impUndo),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _undo(BuildContext context, WidgetRef ref, ImportBatche b) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.impUndoConfirm(b.rowCount, b.fileName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(
            key: const ValueKey('undo-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.impUndo),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(importServiceProvider).undo(b.id);
  }
}
