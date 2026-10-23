import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../ai/ai_config.dart';
import '../ai/consent.dart';
import '../capture_pipeline.dart';
import '../speech/recorder.dart';

/// Asks for each undecided [features] that could go online right now (online
/// AI on and a key saved). Nothing is asked when everything stays on the phone.
Future<void> askCaptureConsents(BuildContext context, List<AiFeature> features) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final s = await container.read(settingsProvider.future);
  if (!s.aiOnlineEnabled || await container.read(groqKeyStoreProvider).read() == null) return;
  for (final f in features) {
    if (!context.mounted) return;
    await ensureConsent(context, f);
  }
}

/// Mic button tap: consent first (once), then record.
Future<void> startVoiceCapture(BuildContext context) async {
  await askCaptureConsents(context, const [AiFeature.voice, AiFeature.parse]);
  if (!context.mounted) return;
  final outcome = await showModalBottomSheet<CaptureOutcome>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    builder: (_) => const CaptureVoiceSheet(),
  );
  if (outcome != null && context.mounted) showCaptureOutcome(context, outcome);
}

/// Mic button long-press: type instead, or jump to a manual form.
Future<void> startTextCapture(BuildContext context) async {
  final outcome = await showModalBottomSheet<CaptureOutcome>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const CaptureTextSheet(),
  );
  if (outcome != null && context.mounted) showCaptureOutcome(context, outcome);
}

String inboxReason(AppLocalizations l, String key) => switch (key) {
  'noSpeechEngine' => l.capReason_noSpeechEngine,
  'noSpeechOnlineOff' => l.capReason_noSpeechOnlineOff,
  'noSpeechNoKey' => l.capReason_noSpeechNoKey,
  'noSpeechNotAsked' => l.capReason_noSpeechNotAsked,
  'noSpeechDeclined' => l.capReason_noSpeechDeclined,
  'noSpeechOffline' => l.capReason_noSpeechOffline,
  'sttFailed' => l.capReason_sttFailed,
  'empty' => l.capReason_empty,
  _ => l.capReason_lowConfidence,
};

void showCaptureOutcome(BuildContext context, CaptureOutcome outcome) {
  final router = GoRouter.of(context);
  final path = '/capture/${outcome.captureId}';
  switch (outcome) {
    case ReadyForReview():
      router.push(path);
    case SavedToInbox(:final reasonKey):
      final l = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const ValueKey('cap-inbox-snack'),
          content: Text('${l.capSavedToInbox}. ${inboxReason(l, reasonKey)}'),
          action: SnackBarAction(label: l.capOpen, onPressed: () => router.push(path)),
        ),
      );
  }
}

enum _Phase { starting, denied, recording, processing }

class CaptureVoiceSheet extends ConsumerStatefulWidget {
  const CaptureVoiceSheet({super.key});

  @override
  ConsumerState<CaptureVoiceSheet> createState() => _CaptureVoiceSheetState();
}

class _CaptureVoiceSheetState extends ConsumerState<CaptureVoiceSheet> {
  static const _bars = 28;

  late final AudioRecorderPort _rec = ref.read(audioRecorderProvider);
  StreamSubscription<double>? _levelSub;
  Timer? _ticker;
  _Phase _phase = _Phase.starting;
  Duration _elapsed = Duration.zero;
  final List<double> _levels = List.filled(_bars, 0, growable: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    if (!await _rec.ensurePermission()) {
      if (mounted) setState(() => _phase = _Phase.denied);
      return;
    }
    await _rec.start();
    if (!mounted) return;
    _levelSub = _rec.level.listen((v) {
      if (!mounted) return;
      setState(() {
        _levels.removeAt(0);
        _levels.add(v);
      });
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed >= kMaxRecording) _stop();
    });
    setState(() => _phase = _Phase.recording);
  }

  void _quiet() {
    _ticker?.cancel();
    _levelSub?.cancel();
  }

  Future<void> _stop() async {
    if (_phase != _Phase.recording) return;
    _quiet();
    setState(() => _phase = _Phase.processing);
    CaptureOutcome? outcome;
    try {
      final wav = await _rec.stop();
      outcome = await ref.read(capturePipelineProvider).fromVoice(wav);
    } on Exception catch (e) {
      // The capture row was written first; whatever happened, it waits in the Inbox.
      AppLogger.warn('voice capture failed', e);
    }
    if (mounted) Navigator.of(context).pop(outcome);
  }

  Future<void> _cancel() async {
    _quiet();
    await _rec.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _quiet();
    super.dispose();
  }

  String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    ref.watch(audioRecorderProvider);
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final still = reduceMotion(context);

    final Widget body = switch (_phase) {
      _Phase.denied => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_off_rounded, size: 40, color: k.warning),
          const SizedBox(height: 12),
          Text(l.capMicDenied, textAlign: TextAlign.center, style: text.bodyLarge),
          const SizedBox(height: 20),
          OutlinedButton(
            key: const ValueKey('cap-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
        ],
      ),
      _Phase.processing => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          SizedBox.square(dimension: 36, child: CircularProgressIndicator(strokeWidth: 3, color: k.accent)),
          const SizedBox(height: 16),
          Text(l.capProcessing, style: text.titleMedium),
          const SizedBox(height: 8),
        ],
      ),
      _ => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.capListening, style: text.titleLarge),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: still
                // Reduced motion: a steady recording dot instead of a moving meter.
                ? Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(color: k.danger, shape: BoxShape.circle),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final v in _levels)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: AnimatedContainer(
                            duration: kDurationFast,
                            curve: Curves.linear,
                            width: 4,
                            height: 6 + v * 50,
                            decoration: BoxDecoration(
                              color: k.accent.withValues(alpha: 0.35 + v * 0.65),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            '${_clock(_elapsed)} / ${_clock(kMaxRecording)}',
            key: const ValueKey('cap-elapsed'),
            textDirection: TextDirection.ltr,
            style: text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 4),
          Text(l.capCapHint, style: text.bodySmall?.copyWith(color: k.textMuted)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('cap-cancel'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _cancel,
                  child: Text(l.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('cap-stop'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _phase == _Phase.recording ? _stop : null,
                  icon: const Icon(Icons.stop_rounded),
                  label: Text(l.capStop),
                ),
              ),
            ],
          ),
        ],
      ),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_phase == _Phase.recording || _phase == _Phase.starting) _cancel();
        if (_phase == _Phase.denied) Navigator.of(context).pop();
      },
      child: SafeArea(
        key: const ValueKey('cap-voice-sheet'),
        child: Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), child: body),
      ),
    );
  }
}

class CaptureTextSheet extends ConsumerStatefulWidget {
  const CaptureTextSheet({super.key});

  @override
  ConsumerState<CaptureTextSheet> createState() => _CaptureTextSheetState();
}

class _CaptureTextSheetState extends ConsumerState<CaptureTextSheet> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    await askCaptureConsents(context, const [AiFeature.parse]);
    CaptureOutcome? outcome;
    try {
      outcome = await ref.read(capturePipelineProvider).fromText(_text.text);
    } on Exception catch (e) {
      AppLogger.warn('text capture failed', e);
    }
    if (mounted) Navigator.of(context).pop(outcome);
  }

  void _manual(String location) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    Widget soon(String key, IconData icon, String label, int phase) => Tooltip(
      message: l.comingInPhase(phase),
      child: ActionChip(key: ValueKey(key), avatar: Icon(icon, size: 18), label: Text(label), onPressed: null),
    );
    return Padding(
      key: const ValueKey('cap-text-sheet'),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('cap-text-field'),
                controller: _text,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                enabled: !_busy,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(hintText: l.capTypeHint),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('cap-send'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _busy || _text.text.trim().isEmpty ? null : _send,
                icon: _busy
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: k.onAccent),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(l.capSend),
              ),
              const SizedBox(height: 20),
              Text(l.capManual, style: text.labelLarge?.copyWith(color: k.textMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    key: const ValueKey('cap-manual-expense'),
                    avatar: const Icon(Icons.south_west_rounded, size: 18),
                    label: Text(l.typeExpense),
                    onPressed: _busy ? null : () => _manual('/finance/tx/new?type=expense'),
                  ),
                  ActionChip(
                    key: const ValueKey('cap-manual-income'),
                    avatar: const Icon(Icons.north_east_rounded, size: 18),
                    label: Text(l.typeIncome),
                    onPressed: _busy ? null : () => _manual('/finance/tx/new?type=income'),
                  ),
                  ActionChip(
                    key: const ValueKey('cap-manual-transfer'),
                    avatar: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: Text(l.typeTransfer),
                    onPressed: _busy ? null : () => _manual('/finance/transfer/new'),
                  ),
                  soon('cap-manual-task', Icons.task_alt_outlined, l.navTasks, 4),
                  soon('cap-manual-vault', Icons.shield_outlined, l.capVaultItem, 3),
                  soon('cap-manual-note', Icons.sticky_note_2_outlined, l.capNote, 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
