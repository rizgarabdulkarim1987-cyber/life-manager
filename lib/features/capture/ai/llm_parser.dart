import 'dart:convert';

import '../../../core/logging/app_logger.dart';
import '../domain/intent_validator.dart';
import '../domain/lexicon.dart';
import '../domain/proposal.dart';
import '../rules/rule_parser.dart';
import 'ai_payload.dart';
import 'groq_client.dart';

/// Asks Groq for the intents and checks the answer; anything wrong falls back
/// to the offline [RuleParser], so a capture is never lost to the network.
class LlmParser implements IntentParser {
  LlmParser(this._client, this._model, this._fallback);

  final GroqClient _client;
  final String Function() _model;
  final RuleParser _fallback;

  /// `ai` or `rules`, for the capture's `parsedBy`.
  String lastParsedBy = 'rules';

  @override
  Future<List<Proposal>> parse(String transcript, Lexicon lex, DateTime now) async {
    try {
      final content = await _client.chatJson(
        model: _model(),
        system: kParseSystemPrompt,
        user: jsonEncode(buildParsePayload(transcript, lex, now)),
      );
      final out = validateIntents(jsonDecode(content), lex, now);
      lastParsedBy = 'ai';
      return out;
    } on Exception catch (e) {
      if (e is! GroqError && e is! FormatException && e is! InvalidAiOutput) rethrow;
      AppLogger.warn('online parse failed, using rules', e);
      lastParsedBy = 'rules';
      return _fallback.parse(transcript, lex, now);
    }
  }
}
