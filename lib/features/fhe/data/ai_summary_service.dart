import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/utils/debug_logger.dart';

/// The ONLY data the AI layer is allowed to see. Built exclusively from
/// derived results — never raw document text, private vectors, or ciphertext.
class RestrictedAiContext {
  final String question;
  final String topOrganization;
  final int topScore;

  /// Organization name → qualitative similarity ("high" / "exploratory"...).
  final Map<String, String> similarityByOrganization;
  final List<String> sharedFindings;
  final List<String> contradictions;
  final List<String> opportunities;
  final List<String> permissionSummary;

  const RestrictedAiContext({
    required this.question,
    required this.topOrganization,
    required this.topScore,
    required this.similarityByOrganization,
    required this.sharedFindings,
    required this.contradictions,
    required this.opportunities,
    required this.permissionSummary,
  });

  String toPromptBlock() {
    final similarity = similarityByOrganization.entries
        .map((e) => '- ${e.key}: ${e.value}')
        .join('\n');
    return '''
User question:
$question
Top similarity score: $topScore (strongest partner: $topOrganization)
Similarity by organization:
$similarity
Shared findings:
${sharedFindings.map((f) => '- $f').join('\n')}
Contradictions:
${contradictions.map((c) => '- $c').join('\n')}
Collaboration opportunities:
${opportunities.map((o) => '- $o').join('\n')}
Permission summary:
${permissionSummary.map((p) => '- $p').join('\n')}''';
  }
}

class AiSummaryResult {
  final String text;

  /// True when a cloud AI provider produced the text; false when the summary
  /// was deterministically generated on-device.
  final bool isLive;

  const AiSummaryResult({required this.text, required this.isLive});

  String get modeLabel => isLive
      ? 'AI summary generated from restricted context'
      : 'AI summary simulated from restricted context';
}

/// Generates the collaboration summary from the restricted context only.
///
/// Cloud mode activates when both `AI_PROVIDER` and `AI_API_KEY` are supplied
/// via --dart-define (`openrouter`, `openai`, or a full custom endpoint URL).
/// Any configuration gap or network failure degrades to the deterministic
/// local mode — the demo never crashes because of the AI layer.
class AiSummaryService {
  AiSummaryService._();

  static const String _provider = String.fromEnvironment('AI_PROVIDER');
  static const String _apiKey = String.fromEnvironment('AI_API_KEY');
  static const String _model = String.fromEnvironment(
    'AI_MODEL',
    defaultValue: 'meta-llama/llama-3.3-70b-instruct:free',
  );

  static bool get isConfigured => _provider.isNotEmpty && _apiKey.isNotEmpty;

  static Future<AiSummaryResult> summarize(RestrictedAiContext context) async {
    if (isConfigured) {
      try {
        final live = await _summarizeWithCloud(context);
        if (live != null && live.trim().isNotEmpty) {
          return AiSummaryResult(text: live.trim(), isLive: true);
        }
      } catch (e) {
        debugLog('Cloud AI summary failed, using local mode: $e');
      }
    }
    return AiSummaryResult(text: _localSummary(context), isLive: false);
  }

  static Uri? _endpoint() {
    switch (_provider.toLowerCase()) {
      case 'openrouter':
        return Uri.parse('https://openrouter.ai/api/v1/chat/completions');
      case 'openai':
        return Uri.parse('https://api.openai.com/v1/chat/completions');
      default:
        // Allow a full custom OpenAI-compatible endpoint as the provider value.
        if (_provider.startsWith('http')) return Uri.tryParse(_provider);
        return null;
    }
  }

  static Future<String?> _summarizeWithCloud(
    RestrictedAiContext context,
  ) async {
    final endpoint = _endpoint();
    if (endpoint == null) return null;

    final response = await http
        .post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'model': _model,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You summarize confidential research collaboration results. '
                    'You only receive derived, privacy-safe findings — raw '
                    'documents were withheld by design. Write one short '
                    'professional paragraph (max 4 sentences) for research '
                    'partners. Do not invent data beyond the given context.',
              },
              {'role': 'user', 'content': context.toPromptBlock()},
            ],
            'max_tokens': 220,
            'temperature': 0.2,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugLog('Cloud AI summary rejected: HTTP ${response.statusCode}');
      return null;
    }
    final decoded = jsonDecode(response.body);
    final choices = decoded is Map ? decoded['choices'] : null;
    if (choices is List && choices.isNotEmpty) {
      final message = choices.first['message'];
      if (message is Map && message['content'] is String) {
        return message['content'] as String;
      }
    }
    return null;
  }

  static String _localSummary(RestrictedAiContext context) {
    final strongPartners = context.similarityByOrganization.entries
        .where((e) => e.value == 'High')
        .map((e) => e.key)
        .join(' and ');
    final lead = strongPartners.isEmpty
        ? context.topOrganization
        : strongPartners;
    final contradiction = context.contradictions.isNotEmpty
        ? ' One tension to resolve: ${context.contradictions.first}'
        : '';
    final nextStep = context.opportunities.isNotEmpty
        ? ' Recommended next step: ${context.opportunities.first}'
        : '';
    return 'Encrypted comparison shows $lead hold the strongest private '
        'overlap (top score ${context.topScore}) on the shared research '
        'question "${context.question}".$contradiction$nextStep Raw documents stayed sealed with '
        'their owners; this briefing was assembled only from derived, '
        'authorized findings.';
  }
}
