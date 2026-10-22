import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/finance_seed.dart' show kDefaultCategoryKeywords;
import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/theme/tokens.dart';
import '../finance/data/categories_repository.dart';
import '../finance/data/finance_providers.dart';
import 'settings_section.dart';
import 'word_chips.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];

    Widget tile(Category c) {
      final words = (kDefaultCategoryKeywords[c.systemKey] ?? const []).length + extraKeywords(c).length;
      return ListTile(
        key: ValueKey('category-${c.id}'),
        leading: Icon(Icons.circle, size: 12, color: Color(c.colorArgb)),
        minLeadingWidth: 12,
        title: Text(categoryLabel(c, l), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: words == 0
            ? null
            : Text(
                [...extraKeywords(c), ...?kDefaultCategoryKeywords[c.systemKey]].take(4).join('، '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: k.textMuted),
              ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => showCategorySheet(context, editing: c),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.setCategories),
        actions: [
          IconButton(
            key: const ValueKey('add-category'),
            tooltip: l.setAddCategory,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showCategorySheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SettingsSection(
            title: l.setExpenseCategories,
            children: [for (final c in all.where((c) => c.kind == 'expense')) tile(c)],
          ),
          SettingsSection(
            title: l.setIncomeCategories,
            children: [for (final c in all.where((c) => c.kind == 'income')) tile(c)],
          ),
        ],
      ),
    );
  }
}

Future<void> showCategorySheet(BuildContext context, {Category? editing}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _CategorySheet(editing: editing),
);

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({this.editing});

  final Category? editing;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final TextEditingController _name;
  late List<String> _words;
  String _kind = 'expense';
  String _original = '';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _words = widget.editing == null ? [] : extraKeywords(widget.editing!);
    _kind = widget.editing?.kind ?? 'expense';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.editing != null && _original.isEmpty) {
      _original = categoryLabel(widget.editing!, context.l10n);
      _name.text = _original;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(categoriesRepositoryProvider);
    final name = _name.text.trim();
    final c = widget.editing;
    final id = c?.id ?? await repo.create(kind: _kind, name: name);
    if (c != null && name != _original) await repo.rename(id, name);
    if (c == null ? _words.isNotEmpty : _words.join(',') != c.extraKeywords) await repo.setExtraKeywords(id, _words);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _archive() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.setArchiveCategory(_original)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(
            key: const ValueKey('archive-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.archive),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(categoriesRepositoryProvider).archive(widget.editing!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = widget.editing;
    final builtIn = kDefaultCategoryKeywords[c?.systemKey] ?? const <String>[];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c == null ? l.setAddCategory : l.setEditCategory, style: text.titleLarge),
              const SizedBox(height: 16),
              if (c == null) ...[
                SegmentedButton<String>(
                  key: const ValueKey('category-kind'),
                  segments: [
                    ButtonSegment(value: 'expense', label: Text(l.setExpenseCategories)),
                    ButtonSegment(value: 'income', label: Text(l.setIncomeCategories)),
                  ],
                  selected: {_kind},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                key: const ValueKey('category-name'),
                controller: _name,
                maxLength: 80,
                decoration: InputDecoration(labelText: l.finAccountName),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              Text(l.setKeywords, style: text.titleSmall?.copyWith(color: k.text)),
              const SizedBox(height: 10),
              WordChips(
                words: _words,
                fixed: builtIn,
                fixedLabel: l.setBuiltInWords,
                wordsLabel: l.setYourWords,
                inputLabel: l.setAddWord,
                inputKey: const ValueKey('keyword-input'),
                addKey: const ValueKey('keyword-add'),
                onChanged: (w) => setState(() => _words = w),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('category-save'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _name.text.trim().isEmpty ? null : _save,
                child: Text(l.save),
              ),
              if (c != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const ValueKey('category-archive'),
                  style: TextButton.styleFrom(foregroundColor: k.danger, minimumSize: const Size.fromHeight(48)),
                  onPressed: _archive,
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  label: Text(l.archive),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
