import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../../../core/utils/debug_logger.dart';
import '../../files/domain/models/secure_file_metadata.dart';

/// Deterministic extractor that turns uploaded demo documents into small
/// research-signal vectors. No NLP pipeline: it first looks for the explicit
/// `Private research signal used for demo:` block (high/medium/low → 3/2/1)
/// and falls back to keyword counting. Raw document text never leaves this
/// extractor — only the derived 3-int vector is used downstream.
class ResearchSignalExtractor {
  ResearchSignalExtractor._();

  /// Maps an uploaded file name onto a demo participant, or null if the file
  /// is not one of the three demo documents.
  static String? participantIdForFileName(String fileName) {
    final name = fileName.toLowerCase();
    if (name.contains('hospital') && name.contains('alpha')) {
      return 'hospital_alpha';
    }
    if (name.contains('university') && name.contains('beta')) {
      return 'university_beta';
    }
    if ((name.contains('research') || name.contains('lab')) &&
        name.contains('gamma')) {
      return 'research_lab_gamma';
    }
    return null;
  }

  /// Extracts plain text from uploaded document bytes.
  /// Returns null when no text could be recovered (never throws).
  static Future<String?> extractText(
    SecureFileType type,
    Uint8List bytes,
  ) async {
    final looksLikePdf = bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;

    if (looksLikePdf || type == SecureFileType.pdf) {
      try {
        // Idempotent: returns immediately when the viewer already ran it.
        await pdfrxFlutterInitialize();
        final document = await PdfDocument.openData(bytes);
        final buffer = StringBuffer();
        try {
          for (final page in document.pages) {
            final pageText = await page.loadText();
            if (pageText != null) buffer.writeln(pageText.fullText);
          }
        } finally {
          await document.dispose();
        }
        final text = buffer.toString().trim();
        return text.isEmpty ? null : text;
      } catch (e) {
        debugLog('Research signal PDF extraction failed: $e');
        return null;
      }
    }

    try {
      final text = utf8.decode(bytes).trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  /// Derives the 3-dim signal vector from document text, or null when the
  /// text carries no recognizable research signal.
  static List<int>? vectorFromText(String text) {
    final explicit = _parseExplicitSignalBlock(text);
    if (explicit != null) return explicit;
    return _keywordVector(text);
  }

  /// Primary path: the demo documents declare their signal directly, e.g.
  ///   immune response timing: high
  ///   cohort outcome agreement: medium
  ///   biomarker novelty: low
  static List<int>? _parseExplicitSignalBlock(String text) {
    final lower = text.toLowerCase();
    final timing = _levelAfter(lower, 'immune response timing');
    final cohort = _levelAfter(lower, 'cohort outcome agreement');
    final biomarker = _levelAfter(lower, 'biomarker novelty');
    if (timing == null || cohort == null || biomarker == null) return null;
    return [timing, cohort, biomarker];
  }

  static int? _levelAfter(String lowerText, String label) {
    final match =
        RegExp('$label\\s*:\\s*(high|medium|low)').firstMatch(lowerText);
    switch (match?.group(1)) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
    }
    return null;
  }

  /// Fallback path: keyword counting mapped into 1–3 buckets per dimension.
  static List<int>? _keywordVector(String text) {
    final lower = text.toLowerCase();

    int countOf(List<String> keywords) {
      var total = 0;
      for (final keyword in keywords) {
        total += RegExp(RegExp.escape(keyword)).allMatches(lower).length;
      }
      return total;
    }

    final timingHits = countOf(
      ['timing', '4-8 hour', 'intervention', 'immune-response', 'immune response'],
    );
    final cohortHits = countOf(
      ['cohort', 'statistic', 'outcome', 'model confidence'],
    );
    final biomarkerHits = countOf(
      ['biomarker', 'assay', 'lab', 'marker peak'],
    );

    if (timingHits == 0 && cohortHits == 0 && biomarkerHits == 0) return null;

    int bucket(int hits) {
      if (hits >= 5) return 3;
      if (hits >= 2) return 2;
      return 1;
    }

    return [bucket(timingHits), bucket(cohortHits), bucket(biomarkerHits)];
  }
}
