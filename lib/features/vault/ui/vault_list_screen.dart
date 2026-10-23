import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../data/vault_items_repository.dart';
import '../data/vault_providers.dart';
import '../vault_session.dart';
import 'generator_sheet.dart';
import 'vault_ui_common.dart';

/// The open vault: search, filter and sort over plain fields only (spec §9.2).
class VaultListScreen extends ConsumerStatefulWidget {
  const VaultListScreen({super.key});

  @override
  ConsumerState<VaultListScreen> createState() => _VaultListScreenState();
}

enum _Menu { generator, import, settings }

class _VaultListScreenState extends ConsumerState<VaultListScreen> {
  final _search = TextEditingController();
  VaultQuery _q = const VaultQuery();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _menu(_Menu m) => switch (m) {
    _Menu.generator => showGeneratorSheet(context),
    _Menu.import => context.push('/vault/import'),
    _Menu.settings => context.push('/vault/settings'),
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final items = ref.watch(vaultItemsProvider(_q));
    final list = items.value ?? const <VaultItem>[];
    final filtering = _q.text.trim().isNotEmpty || _q.category != null || _q.favoritesOnly;

    Widget chip(Key key, String label, bool selected, VoidCallback onTap, {IconData? icon}) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: FilterChip(
        key: key,
        avatar: icon == null ? null : Icon(icon, size: 18),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navVault),
        actions: [
          IconButton(
            key: const ValueKey('vault-add'),
            tooltip: l.vltAdd,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/vault/new'),
          ),
          IconButton(
            key: const ValueKey('vault-lock'),
            tooltip: l.vltLock,
            icon: const Icon(Icons.lock_outline_rounded),
            onPressed: () => ref.read(vaultSessionProvider.notifier).lock(),
          ),
          PopupMenuButton<_Menu>(
            key: const ValueKey('vault-menu'),
            tooltip: l.vltMore,
            onSelected: _menu,
            itemBuilder: (_) => [
              PopupMenuItem(
                key: const ValueKey('vault-menu-generator'),
                value: _Menu.generator,
                child: Text(l.vltGenerator),
              ),
              PopupMenuItem(key: const ValueKey('vault-menu-import'), value: _Menu.import, child: Text(l.vltImport)),
              PopupMenuItem(
                key: const ValueKey('vault-menu-settings'),
                value: _Menu.settings,
                child: Text(l.vltSettings),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('vault-search'),
                    controller: _search,
                    autocorrect: false,
                    enableIMEPersonalizedLearning: false,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l.vltSearch,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                _search.clear();
                                _q = _q.copyWith(text: '');
                              }),
                            ),
                    ),
                    onChanged: (v) => setState(() => _q = _q.copyWith(text: v)),
                  ),
                ),
                PopupMenuButton<VaultSort>(
                  key: const ValueKey('vault-sort'),
                  tooltip: l.vltSort,
                  icon: const Icon(Icons.sort_rounded),
                  initialValue: _q.sort,
                  onSelected: (s) => setState(() => _q = _q.copyWith(sort: s)),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: VaultSort.title, child: Text(l.vltSortTitle)),
                    PopupMenuItem(value: VaultSort.updated, child: Text(l.vltSortUpdated)),
                    PopupMenuItem(value: VaultSort.created, child: Text(l.vltSortCreated)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                chip(
                  const ValueKey('vault-filter-all'),
                  l.vltAll,
                  _q.category == null && !_q.favoritesOnly,
                  () => setState(() => _q = _q.copyWith(category: () => null, favoritesOnly: false)),
                ),
                chip(
                  const ValueKey('vault-filter-fav'),
                  l.vltFavorites,
                  _q.favoritesOnly,
                  () => setState(() => _q = _q.copyWith(favoritesOnly: !_q.favoritesOnly)),
                  icon: Icons.star_outline_rounded,
                ),
                for (final c in kVaultCategories)
                  chip(
                    ValueKey('vault-filter-$c'),
                    vaultCategoryLabel(l, c),
                    _q.category == c,
                    () => setState(() => _q = _q.copyWith(category: () => _q.category == c ? null : c)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: items.isLoading && !items.hasValue
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                ? _Empty(filtering: filtering)
                : ListView.separated(
                    key: const ValueKey('vault-list'),
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 112),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => Divider(color: k.border, height: 1, indent: 72, endIndent: 20),
                    itemBuilder: (context, i) => _ItemTile(list[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile(this.item);

  final VaultItem item;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final subtitle = item.username ?? item.email ?? item.url;
    return InkWell(
      key: ValueKey('vault-item-${item.id}'),
      onTap: () => context.push('/vault/item/${item.id}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: k.surfaceHigh, borderRadius: BorderRadius.circular(10)),
                child: Icon(vaultCategoryIcon(item.category), size: 20, color: k.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyLarge?.copyWith(color: k.text),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: text.bodySmall?.copyWith(color: k.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.favorite) ...[const SizedBox(width: 8), Icon(Icons.star_rounded, size: 20, color: k.warning)],
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filtering});

  final bool filtering;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight - 64),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(filtering ? Icons.search_off_rounded : Icons.key_outlined, size: 40, color: k.textMuted),
              const SizedBox(height: 12),
              Text(
                filtering ? l.vltNoMatches : l.vltEmpty,
                key: const ValueKey('vault-empty'),
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: k.text),
              ),
              if (!filtering) ...[
                const SizedBox(height: 8),
                Text(
                  l.vltEmptyBody,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: k.textMuted),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('vault-empty-add'),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l.vltAdd),
                      onPressed: () => context.push('/vault/new'),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.content_paste_rounded),
                      label: Text(l.vltImport),
                      onPressed: () => context.push('/vault/import'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
