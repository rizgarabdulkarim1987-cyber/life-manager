import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../ai/ai_config.dart';
import '../camera/receipt_camera.dart';
import '../chat/conversation.dart';
import '../speech/recorder.dart';
import 'capture_sheet.dart';
import 'chat_sheet.dart';

/// The box on every tab where the owner writes or speaks (redesign §9.1).
/// Hold the mic to talk and release to send; a tap starts and a second tap sends.
class Composer extends ConsumerStatefulWidget {
  const Composer({super.key, this.large = false, this.inSheet = false});

  /// Home's roomier version.
  final bool large;

  /// Inside the chat sheet: sending stays there instead of opening it.
  final bool inSheet;

  @override
  ConsumerState<Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<Composer> {
  final _text = TextEditingController();
  late final AudioRecorderPort _rec = ref.read(audioRecorderProvider);
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  bool _starting = false;
  bool _held = false;
  bool _releasedEarly = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_recording) unawaited(_rec.cancel());
    _text.dispose();
    super.dispose();
  }

  Conversation get _chat => ref.read(conversationProvider.notifier);

  void _openChat() {
    if (!widget.inSheet) unawaited(openChatSheet(context));
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    await askCaptureConsents(context, const [AiFeature.parse]);
    if (!mounted) return;
    _text.clear();
    _openChat();
    await _chat.send(t);
  }

  Future<void> _scan() async {
    await askCaptureConsents(context, const [AiFeature.receipt]);
    if (!mounted) return;
    final Uint8List? jpeg;
    try {
      jpeg = await ref.read(receiptCameraProvider).take();
    } on Exception catch (e) {
      AppLogger.warn('receipt camera failed', e);
      return;
    }
    if (jpeg == null || !mounted) return;
    _openChat();
    await _chat.sendImage(jpeg);
  }

  Future<void> _start() async {
    if (_recording || _starting) return;
    _starting = true;
    try {
      await askCaptureConsents(context, const [AiFeature.voice, AiFeature.parse]);
      if (!mounted || !await _rec.ensurePermission()) return;
      await _rec.start();
      if (!mounted) return;
      _elapsed = Duration.zero;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed += const Duration(seconds: 1));
        if (_elapsed >= kMaxRecording) _stop();
      });
      setState(() => _recording = true);
    } finally {
      _starting = false;
    }
    // Let go while the recorder was still starting: send what there is.
    if (_releasedEarly) {
      _releasedEarly = false;
      await _stop();
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _ticker?.cancel();
    setState(() => _recording = false);
    try {
      final wav = await _rec.stop();
      if (!mounted) return;
      _openChat();
      await _chat.sendVoice(wav);
    } on Exception catch (e) {
      // The capture row is written before anything else, so nothing is lost.
      AppLogger.warn('voice capture failed', e);
    }
  }

  void _tapMic() => _recording ? _stop() : _start();

  void _holdStart() {
    _held = true;
    _start();
  }

  void _holdEnd() {
    if (!_held) return;
    _held = false;
    if (_starting) {
      _releasedEarly = true;
    } else {
      _stop();
    }
  }

  String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final hasText = _text.text.trim().isNotEmpty;
    final height = widget.large ? 64.0 : 52.0;

    final field = _recording
        ? Row(
            key: const ValueKey('composer-recording'),
            children: [
              Icon(Icons.fiber_manual_record_rounded, size: 14, color: k.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.capListening, style: text.bodyLarge?.copyWith(color: k.textMuted)),
              ),
              Text(_clock(_elapsed), style: text.labelLarge?.copyWith(color: k.textMuted)),
            ],
          )
        : TextField(
            key: const ValueKey('composer-field'),
            controller: _text,
            minLines: 1,
            maxLines: widget.large ? 4 : 3,
            maxLength: 2000,
            textInputAction: TextInputAction.newline,
            style: widget.large ? text.titleMedium : text.bodyLarge,
            decoration: InputDecoration(
              hintText: l.composerHint,
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          );

    final mic = Semantics(
      button: true,
      label: l.composerMic,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('composer-mic'),
        onTap: _tapMic,
        onLongPressStart: (_) => _holdStart(),
        onLongPressEnd: (_) => _holdEnd(),
        onLongPressCancel: _holdEnd,
        child: AnimatedContainer(
          duration: reduceMotion(context) ? Duration.zero : kDurationBase,
          curve: kEaseOut,
          width: height - 8,
          height: height - 8,
          decoration: BoxDecoration(color: _recording ? k.danger : k.accent, shape: BoxShape.circle),
          child: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded, color: k.onAccent, size: 24),
        ),
      ),
    );

    final send = IconButton.filled(
      key: const ValueKey('composer-send'),
      tooltip: l.composerSend,
      onPressed: _send,
      style: IconButton.styleFrom(
        backgroundColor: k.accent,
        foregroundColor: k.onAccent,
        fixedSize: Size.square(height - 8),
      ),
      icon: const Icon(Icons.arrow_upward_rounded),
    );

    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsetsDirectional.only(start: 18, end: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: k.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(padding: const EdgeInsets.only(bottom: 2), child: field),
          ),
          if (!_recording && !hasText)
            IconButton(
              key: const ValueKey('composer-camera'),
              tooltip: l.composerCamera,
              onPressed: _scan,
              icon: Icon(Icons.photo_camera_outlined, color: k.textMuted),
            ),
          const SizedBox(width: 6),
          if (hasText && !_recording) send else mic,
        ],
      ),
    );
  }
}
