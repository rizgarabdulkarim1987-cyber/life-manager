import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../finance/ui/widgets/panel.dart';
import '../data/projects_providers.dart';

String projectStatusLabel(AppLocalizations l, String status) => switch (status) {
  'planning' => l.projectStatusPlanning,
  'active' => l.projectStatusActive,
  'done' => l.projectStatusDone,
  'dropped' => l.projectStatusDropped,
  _ => l.projectStatusIdea,
};

/// The Projects tab: every project with its status and how many steps are done.
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final projects = ref.watch(projectsProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navProjects),
        actions: [
          IconButton(
            key: const ValueKey('projects-add'),
            tooltip: l.projectNew,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: projects == null
          ? const SizedBox.shrink()
          : projects.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l.projectsEmpty,
                  key: const ValueKey('projects-empty'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: k.textMuted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [for (final p in projects) _ProjectCard(p)],
            ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final name = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.projectNew),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('project-name'),
              controller: name,
              autofocus: true,
              decoration: InputDecoration(labelText: l.projectNameLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('project-desc'),
              controller: desc,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(labelText: l.projectDescLabel),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
            key: const ValueKey('project-create'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.save),
          ),
        ],
      ),
    );
    final title = name.text.trim();
    final text = desc.text;
    name.dispose();
    desc.dispose();
    if (ok != true || title.isEmpty || !context.mounted) return;
    final id = await ref.read(projectsRepositoryProvider).create(title: title, description: text);
    if (context.mounted) context.push('/projects/$id');
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard(this.p);

  final Project p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final steps = ref.watch(projectStepsProvider(p.id)).value ?? const [];
    final done = steps.where((s) => s.done).length;
    return Panel(
      key: ValueKey('project-${p.id}'),
      onTap: () => context.push('/projects/${p.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(color: k.text),
                ),
              ),
              const SizedBox(width: 8),
              Text(projectStatusLabel(l, p.status), style: text.bodySmall?.copyWith(color: k.textMuted)),
            ],
          ),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: done / steps.length, minHeight: 6),
            ),
            const SizedBox(height: 6),
            Text(l.projectProgress(done, steps.length), style: text.bodySmall?.copyWith(color: k.textMuted)),
          ],
        ],
      ),
    );
  }
}
