import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/app_database.dart';
import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/logging/app_logger.dart';
import '../../core/security/sensitive.dart';
import '../../core/theme/tokens.dart';
import '../capture/ai/ai_config.dart';
import '../capture/ai/groq_client.dart';
import '../capture/ui/consent_sheet.dart';
import 'settings_section.dart';

class AiSettingsScreen extends ConsumerWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    return Scaffold(
      key: const ValueKey('ai-settings'),
      appBar: AppBar(title: Text(l.setAi)),
      body: settings == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                SettingsSection(
                  title: l.setAi,
                  children: [
                    SwitchListTile(
                      key: const ValueKey('ai-online'),
                      secondary: const Icon(Icons.cloud_outlined),
                      title: Text(l.aiOnline),
                      subtitle: Text(l.aiOnlineHint),
                      value: settings.aiOnlineEnabled,
                      onChanged: (v) => ref.read(settingsRepositoryProvider).setAiOnlineEnabled(v),
                    ),
                  ],
                ),
                SettingsSection(title: l.aiKey, children: const [_KeyEditor()]),
                SettingsSection(
                  title: l.aiConsents,
                  children: [
                    _ConsentRow(feature: AiFeature.voice, state: settings.aiVoiceConsent),
                    Divider(height: 1, color: context.tokens.border),
                    _ConsentRow(feature: AiFeature.parse, state: settings.aiParseConsent),
                  ],
                ),
                SettingsSection(
                  title: l.aiModels,
                  children: [_Models(settings: settings)],
                ),
                SettingsSection(
                  title: l.aiOfflineModel,
                  children: [
                    ListTile(
                      key: const ValueKey('whisper-section'),
                      leading: const Icon(Icons.graphic_eq_rounded),
                      title: Text(l.aiOfflineModel),
                      subtitle: Text(l.aiOfflineModelHint),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _KeyEditor extends ConsumerStatefulWidget {
  const _KeyEditor();

  @override
  ConsumerState<_KeyEditor> createState() => _KeyEditorState();
}

enum _TestResult { ok, unauthorized, offline, busy, other }

class _KeyEditorState extends ConsumerState<_KeyEditor> {
  final _field = TextEditingController();
  String? _last4;
  bool _loaded = false;
  bool _testing = false;
  _TestResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final key = await ref.read(groqKeyStoreProvider).read();
    if (!mounted) return;
    setState(() {
      final v = key?.value;
      _last4 = v?.substring(v.length < 4 ? 0 : v.length - 4);
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final v = _field.text.trim();
    if (v.isEmpty) return;
    await ref.read(groqKeyStoreProvider).write(Sensitive(v));
    ref.invalidate(groqKeySavedProvider);
    _field.clear();
    _result = null;
    if (mounted) FocusScope.of(context).unfocus();
    await _load();
  }

  Future<void> _clear() async {
    await ref.read(groqKeyStoreProvider).clear();
    ref.invalidate(groqKeySavedProvider);
    _result = null;
    await _load();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text?.trim();
    if (t != null && t.isNotEmpty) setState(() => _field.text = t);
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    final model = ref.read(settingsProvider).value?.groqLlmModel ?? 'llama-3.3-70b-versatile';
    _TestResult r;
    try {
      await ref
          .read(groqClientProvider)
          .chatJson(model: model, system: 'Reply with the JSON object {"ok":true}.', user: 'ping');
      r = _TestResult.ok;
    } on GroqError catch (e) {
      AppLogger.warn('groq key test failed', e);
      r = switch (e) {
        GroqUnauthorized() => _TestResult.unauthorized,
        GroqNetworkError() => _TestResult.offline,
        GroqRateLimited() => _TestResult.busy,
        GroqServerError() || GroqBadResponse() => _TestResult.other,
      };
    }
    if (mounted) {
      setState(() {
        _testing = false;
        _result = r;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    if (!_loaded) return const SizedBox(height: 56);
    final last4 = _last4;
    final result = _result;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (last4 == null) ...[
            TextField(
              key: const ValueKey('groq-key-field'),
              controller: _field,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                labelText: l.aiKey,
                suffixIcon: IconButton(
                  key: const ValueKey('groq-key-paste'),
                  tooltip: l.aiKeyPaste,
                  icon: const Icon(Icons.content_paste_rounded),
                  onPressed: _paste,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            Text(l.aiKeyHint, style: text.bodySmall?.copyWith(color: k.textMuted)),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('groq-key-save'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _field.text.trim().isEmpty ? null : _save,
              child: Text(l.aiKeySave),
            ),
          ] else ...[
            Row(
              children: [
                Icon(Icons.key_rounded, color: k.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.aiKeySaved(last4),
                    key: const ValueKey('groq-key-saved'),
                    style: text.bodyLarge?.copyWith(color: k.text, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
                TextButton(key: const ValueKey('groq-key-clear'), onPressed: _clear, child: Text(l.aiKeyRemove)),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('groq-test'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_tethering_rounded, size: 18),
              label: Text(l.aiTest),
            ),
            if (result != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  switch (result) {
                    _TestResult.ok => l.aiTestOk,
                    _TestResult.unauthorized => l.aiTestUnauthorized,
                    _TestResult.offline => l.aiTestOffline,
                    _TestResult.busy => l.aiTestBusy,
                    _TestResult.other => l.aiTestOther,
                  },
                  key: const ValueKey('groq-test-result'),
                  style: text.bodyMedium?.copyWith(color: result == _TestResult.ok ? k.success : k.warning),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ConsentRow extends ConsumerWidget {
  const _ConsentRow({required this.feature, required this.state});

  final AiFeature feature;
  final String? state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final id = feature.name;
    final (label, color) = switch (state) {
      'granted' => (l.aiConsentGranted, k.success),
      'declined' => (l.aiConsentDeclined, k.warning),
      _ => (l.aiConsentUnset, k.textMuted),
    };
    return Padding(
      key: ValueKey('consent-$id'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  feature == AiFeature.voice ? l.aiConsentVoiceTitle : l.aiConsentParseTitle,
                  style: text.titleSmall?.copyWith(color: k.text),
                ),
              ),
              Text(
                label,
                key: ValueKey('consent-state-$id'),
                style: text.labelLarge?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(consentText(context, feature), style: text.bodySmall?.copyWith(color: k.textMuted)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: ValueKey('consent-reset-$id'),
              onPressed: state == null ? null : () => ref.read(settingsRepositoryProvider).setConsent(feature, null),
              child: Text(l.aiConsentReset),
            ),
          ),
        ],
      ),
    );
  }
}

class _Models extends ConsumerStatefulWidget {
  const _Models({required this.settings});

  final AppSetting settings;

  @override
  ConsumerState<_Models> createState() => _ModelsState();
}

class _ModelsState extends ConsumerState<_Models> {
  late final _stt = TextEditingController(text: widget.settings.groqSttModel);
  late final _llm = TextEditingController(text: widget.settings.groqLlmModel);

  @override
  void dispose() {
    _stt.dispose();
    _llm.dispose();
    super.dispose();
  }

  bool get _valid => _stt.text.trim().isNotEmpty && _llm.text.trim().isNotEmpty;

  Future<void> _save() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(settingsRepositoryProvider).setGroqModels(stt: _stt.text, llm: _llm.text);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    messenger.showSnackBar(SnackBar(content: Text(l.aiModelsSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    InputDecoration deco(String label) => InputDecoration(labelText: label);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('stt-model'),
            controller: _stt,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            maxLength: 100,
            decoration: deco(l.aiSttModel),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('llm-model'),
            controller: _llm,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            maxLength: 100,
            decoration: deco(l.aiLlmModel),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey('models-save'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _valid ? _save : null,
            child: Text(l.aiModelsSave),
          ),
        ],
      ),
    );
  }
}
