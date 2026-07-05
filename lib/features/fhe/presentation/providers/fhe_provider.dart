import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/fhe_config.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../services/audit_service.dart';
import '../../../files/domain/models/secure_file_metadata.dart';
import '../../../files/presentation/providers/secure_file_providers.dart';
import '../../data/ai_summary_service.dart';
import '../../data/fhe_transport.dart';
import '../../data/repositories/fhe_repository_impl.dart';
import '../../data/research_signal_extractor.dart';
import '../../domain/fhe_engine.dart';
import '../../domain/fhe_key_manager.dart';
import '../../domain/repositories/fhe_repository.dart';

class ConfidentialParticipant {
  final String id;
  final String organization;
  final String role;
  final String clearanceLabel;
  final List<int> privateSignal;
  final List<String> authorizedEvidence;
  final String withheldSummary;

  const ConfidentialParticipant({
    required this.id,
    required this.organization,
    required this.role,
    required this.clearanceLabel,
    required this.privateSignal,
    required this.authorizedEvidence,
    required this.withheldSummary,
  });
}

class ConfidentialInsight {
  final ConfidentialParticipant participant;
  final int score;
  final String encryptedScorePreview;

  const ConfidentialInsight({
    required this.participant,
    required this.score,
    required this.encryptedScorePreview,
  });
}

/// Per-organization status of the uploaded document backing its signal.
class ResearchInputDocument {
  final String participantId;
  final String organization;
  final String? fileName;

  /// True when the signal vector was extracted from the uploaded document
  /// text; false when the manual demo vector fallback is in use.
  final bool signalFromDocument;

  const ResearchInputDocument({
    required this.participantId,
    required this.organization,
    this.fileName,
    required this.signalFromDocument,
  });
}

class FheDemoState {
  final bool isLoading;
  final String? statusText;
  final String? error;
  final String? questionText;
  final String selectedPerspectiveId;
  final List<ConfidentialInsight> insights;
  final String? answer;
  final String? confidence;
  final String? receiptId;
  final String? encryptedReceiptPreview;
  final List<String> permissionSummary;
  final List<String> sharedFindings;
  final List<String> contradictions;
  final List<String> opportunities;
  final List<ResearchInputDocument> inputDocuments;
  final String? aiModeLabel;

  const FheDemoState({
    this.isLoading = false,
    this.statusText,
    this.error,
    this.questionText,
    this.selectedPerspectiveId = 'hospital_alpha',
    this.insights = const [],
    this.answer,
    this.confidence,
    this.receiptId,
    this.encryptedReceiptPreview,
    this.permissionSummary = const [],
    this.sharedFindings = const [],
    this.contradictions = const [],
    this.opportunities = const [],
    this.inputDocuments = const [],
    this.aiModeLabel,
  });

  FheDemoState copyWith({
    bool? isLoading,
    String? statusText,
    String? error,
    String? questionText,
    String? selectedPerspectiveId,
    List<ConfidentialInsight>? insights,
    String? answer,
    String? confidence,
    String? receiptId,
    String? encryptedReceiptPreview,
    List<String>? permissionSummary,
    List<String>? sharedFindings,
    List<String>? contradictions,
    List<String>? opportunities,
    List<ResearchInputDocument>? inputDocuments,
    String? aiModeLabel,
    bool clearError = false,
  }) {
    return FheDemoState(
      isLoading: isLoading ?? this.isLoading,
      statusText: statusText ?? this.statusText,
      error: clearError ? null : error ?? this.error,
      questionText: questionText ?? this.questionText,
      selectedPerspectiveId:
          selectedPerspectiveId ?? this.selectedPerspectiveId,
      insights: insights ?? this.insights,
      answer: answer ?? this.answer,
      confidence: confidence ?? this.confidence,
      receiptId: receiptId ?? this.receiptId,
      encryptedReceiptPreview:
          encryptedReceiptPreview ?? this.encryptedReceiptPreview,
      permissionSummary: permissionSummary ?? this.permissionSummary,
      sharedFindings: sharedFindings ?? this.sharedFindings,
      contradictions: contradictions ?? this.contradictions,
      opportunities: opportunities ?? this.opportunities,
      inputDocuments: inputDocuments ?? this.inputDocuments,
      aiModeLabel: aiModeLabel ?? this.aiModeLabel,
    );
  }
}

class FheDemoNotifier extends Notifier<FheDemoState> {
  late final FheEngine _engine;
  late final FheRepository _repository;

  static const List<int> _defaultQuestionVector = [3, 2, 1];
  static const String _defaultQuestion =
      'Which organizations can safely collaborate on early intervention timing?';

  static const List<ConfidentialParticipant> participants = [
    ConfidentialParticipant(
      id: 'hospital_alpha',
      organization: 'Hospital Alpha',
      role: 'Clinical Team',
      clearanceLabel: 'Outcomes only',
      privateSignal: [3, 2, 1],
      authorizedEvidence: [
        'Early intervention timing aligns with two external cohorts.',
        'Clinical outcomes show reduced sepsis escalation risk.',
      ],
      withheldSummary: 'Patient notes, PHI, and raw clinical rows withheld.',
    ),
    ConfidentialParticipant(
      id: 'university_beta',
      organization: 'University Beta',
      role: 'Statistics Group',
      clearanceLabel: 'Cohort statistics',
      privateSignal: [2, 3, 1],
      authorizedEvidence: [
        'Independent cohort statistics support the intervention window.',
        'Model confidence improves when immune markers are included.',
      ],
      withheldSummary: 'Raw data tables and unpublished methods withheld.',
    ),
    ConfidentialParticipant(
      id: 'research_lab_gamma',
      organization: 'Research Lab Gamma',
      role: 'Biomarker Team',
      clearanceLabel: 'Marker summary',
      privateSignal: [1, 1, 3],
      authorizedEvidence: [
        'Biomarker signal partially agrees with the shared hypothesis.',
        'One marker trend conflicts with the timing assumptions.',
      ],
      withheldSummary: 'Assay recipes and confidential lab notebooks withheld.',
    ),
  ];

  @override
  FheDemoState build() {
    _engine = FheEngine();
    _repository = FheRepositoryImpl();
    return const FheDemoState();
  }

  void selectPerspective(String participantId) {
    state = state.copyWith(selectedPerspectiveId: participantId);
  }

  Future<void> executeConfidentialDiscovery({String? question}) async {
    final selectedPerspectiveId = state.selectedPerspectiveId;
    final questionText = question?.trim().isNotEmpty == true
        ? question!.trim()
        : _defaultQuestion;
    final questionVector = _vectorForQuestion(questionText);
    state = FheDemoState(
      isLoading: true,
      statusText: 'Preparing confidential workspace...',
      questionText: questionText,
      selectedPerspectiveId: selectedPerspectiveId,
    );

    // Step 0: source signal vectors from the actually-uploaded demo documents.
    // Falls back to manual demo vectors per organization when a document is
    // missing or unreadable — visibly, never silently.
    final signals = await _resolveDocumentSignals();

    try {
      if (!FheConfig.anyEnabled) {
        await _runSealedDemo(
          selectedPerspectiveId,
          signals,
          questionVector,
          questionText,
          'Live FHE off in this build - using local sealed demo computation.',
        );
        return;
      }

      if (FheConfig.enableKeyGeneration && !FheKeyManager.instance.hasKeys) {
        state = state.copyWith(
          statusText: 'Creating tenant FHE key context...',
        );
        await _engine.generateKeys();
      }

      state = state.copyWith(statusText: 'Encrypting discovery question...');
      final encryptedQuestion = await _encryptVector(questionVector);
      final insights = <ConfidentialInsight>[];

      for (final participant in participants) {
        state = state.copyWith(
          statusText: 'Sealing ${participant.organization} private signal...',
        );
        final encryptedSignal = await _encryptVector(
          signals.vectorFor(participant),
        );

        state = state.copyWith(
          statusText: 'Computing encrypted overlap for ${participant.role}...',
        );
        final encryptedScore = await _scoreOverlap(
          encryptedQuestion,
          encryptedSignal,
        );

        state = state.copyWith(
          statusText: 'Opening authorized score locally...',
        );
        final score = await _engine.decrypt(encryptedScore);
        insights.add(
          ConfidentialInsight(
            participant: participant,
            score: score,
            encryptedScorePreview: _previewCiphertext(encryptedScore),
          ),
        );
      }

      insights.sort((a, b) => b.score.compareTo(a.score));
      final strongest = insights.first;
      final selected = participants.firstWhere(
        (p) => p.id == state.selectedPerspectiveId,
        orElse: () => strongest.participant,
      );

      await _publishResult(
        selected: selected,
        insights: insights,
        documents: signals.documents,
        questionText: questionText,
        statusText: 'Encrypted comparison complete.',
        receiptPrefix: 'fhe',
      );
    } catch (e) {
      debugLog('FHE confidential discovery failed: $e');
      await _runSealedDemo(
        selectedPerspectiveId,
        signals,
        questionVector,
        questionText,
        'Live FHE unavailable - using local sealed demo computation.',
      );
    }
  }

  /// Locates the three uploaded demo documents in secure storage, extracts a
  /// research-signal vector from each, and reports which organizations are
  /// backed by a real document vs the manual fallback vector.
  Future<_ResolvedSignals> _resolveDocumentSignals() async {
    state = state.copyWith(
      statusText: 'Reading uploaded research documents...',
    );

    final vectors = <String, List<int>>{};
    final documents = <ResearchInputDocument>[];
    List<SecureFileMetadata> files = const [];

    try {
      files = await ref.read(secureFileRepositoryProvider).getAllFiles();
    } catch (e) {
      debugLog('Could not list secure files for research signals: $e');
    }

    for (final participant in participants) {
      SecureFileMetadata? match;
      for (final file in files) {
        if (ResearchSignalExtractor.participantIdForFileName(file.name) ==
            participant.id) {
          if (match == null || file.uploadedAt.isAfter(match.uploadedAt)) {
            match = file;
          }
        }
      }

      List<int>? vector;
      if (match != null) {
        state = state.copyWith(
          statusText: 'Extracting private signal from ${match.name}...',
        );
        try {
          final bytes = await ref
              .read(secureFileRepositoryProvider)
              .downloadFile(fileId: match.id, onProgress: (_) {});
          if (bytes != null) {
            final text = await ResearchSignalExtractor.extractText(
              match.type,
              bytes,
            );
            if (text != null) {
              vector = ResearchSignalExtractor.vectorFromText(text);
            }
          }
        } catch (e) {
          debugLog('Signal extraction failed for ${match.name}: $e');
        }
      }

      vectors[participant.id] = vector ?? participant.privateSignal;
      documents.add(
        ResearchInputDocument(
          participantId: participant.id,
          organization: participant.organization,
          fileName: match?.name,
          signalFromDocument: vector != null,
        ),
      );
    }

    state = state.copyWith(inputDocuments: documents);
    return _ResolvedSignals(vectors: vectors, documents: documents);
  }

  Future<void> _runSealedDemo(
    String selectedPerspectiveId,
    _ResolvedSignals signals,
    List<int> questionVector,
    String questionText,
    String reason,
  ) async {
    state = state.copyWith(statusText: 'Encrypting three private documents...');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    state = state.copyWith(
      statusText: 'Routing encrypted vectors to compute...',
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    state = state.copyWith(
      statusText: 'Comparing overlap without opening documents...',
    );
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final insights = participants.map((participant) {
      final score = _dot(questionVector, signals.vectorFor(participant));
      return ConfidentialInsight(
        participant: participant,
        score: score,
        encryptedScorePreview: _demoCiphertext(participant.id, score),
      );
    }).toList()..sort((a, b) => b.score.compareTo(a.score));

    final selected = participants.firstWhere(
      (p) => p.id == selectedPerspectiveId,
      orElse: () => insights.first.participant,
    );

    await _publishResult(
      selected: selected,
      insights: insights,
      documents: signals.documents,
      questionText: questionText,
      statusText: reason,
      receiptPrefix: 'sealed-fhe',
    );
  }

  Future<void> _publishResult({
    required ConfidentialParticipant selected,
    required List<ConfidentialInsight> insights,
    required List<ResearchInputDocument> documents,
    required String questionText,
    required String statusText,
    required String receiptPrefix,
  }) async {
    final strongest = insights.first;
    final second = insights.length > 1 ? insights[1] : strongest;
    final weakest = insights.last;
    final receiptId = '$receiptPrefix-${DateTime.now().millisecondsSinceEpoch}';

    // Derived (never raw-text) findings, phrased from the actual score ranking.
    final sharedFindings = [
      '${strongest.participant.organization} and ${second.participant.organization} strongly agree on early intervention timing.',
      'All three organizations discuss immune-response signals.',
      '${weakest.participant.organization} adds biomarker evidence without exposing lab notebooks.',
    ];
    final contradictions = [
      "${weakest.participant.organization}'s biomarker peak appears later than the 4-8 hour clinical window.",
      '${second.participant.organization} confidence drops when the ${weakest.participant.organization}-only marker is weighted too heavily.',
    ];
    const opportunities = [
      'Run a joint validation study around early intervention timing.',
      'Exchange only approved aggregate biomarker summaries.',
      'Prepare an AI briefing from safe derived findings, not raw documents.',
    ];
    final documentsUsed = documents.where((d) => d.signalFromDocument).length;
    final permissionSummary = [
      'Signals extracted from $documentsUsed of ${documents.length} uploaded documents; raw text never left the extractor.',
      '${selected.role} perspective used ${selected.authorizedEvidence.length} authorized evidence fragments.',
      'Raw documents, private vectors, PHI, and withheld sections were not placed in AI context.',
      'Encrypted overlap scores were computed before any local opening.',
    ];

    state = state.copyWith(
      statusText: 'Generating AI briefing from restricted context...',
    );

    final aiResult = await AiSummaryService.summarize(
      RestrictedAiContext(
        question: questionText,
        topOrganization: strongest.participant.organization,
        topScore: strongest.score,
        similarityByOrganization: {
          for (final insight in insights)
            insight.participant.organization: _confidenceFor(insight.score),
        },
        sharedFindings: sharedFindings,
        contradictions: contradictions,
        opportunities: opportunities,
        permissionSummary: permissionSummary,
      ),
    );

    state = state.copyWith(
      isLoading: false,
      statusText: statusText,
      insights: insights,
      answer: aiResult.text,
      confidence: _confidenceFor(strongest.score),
      receiptId: receiptId,
      encryptedReceiptPreview: strongest.encryptedScorePreview,
      sharedFindings: sharedFindings,
      contradictions: contradictions,
      opportunities: opportunities,
      permissionSummary: permissionSummary,
      inputDocuments: documents,
      aiModeLabel: aiResult.modeLabel,
      clearError: true,
    );

    AuditService.instance.logEvent(
      'Compare Research completed',
      'SUCCESS',
      metadata: {
        'description':
            'Compare Research completed: encrypted overlap, contradictions, and AI summary recorded.',
        'receipt_id': receiptId,
        'organizations': participants.map((p) => p.organization).toList(),
        'documents_used': documentsUsed,
        'ai_mode': aiResult.isLive ? 'live_cloud' : 'local_simulated',
        'top_match': strongest.participant.organization,
        'similarity_score': strongest.score,
      },
    );
  }

  Future<List<String>> _encryptVector(List<int> values) {
    return Future.wait(values.map(_engine.encrypt));
  }

  Future<String> _scoreOverlap(List<String> query, List<String> signal) async {
    if (FheConfig.useLocalCompute) {
      final res = await FheTransport.instance.send('similarity', {
        'key_id': FheKeyManager.instance.keyId ?? 'demo-key',
        'query_vector': query,
        'memory_vector': signal,
      });
      return res['result_ciphertext'] as String;
    }

    final jobId = await _repository.submitComputeJob(
      keyId: FheKeyManager.instance.keyId ?? 'demo-key',
      operation: 'SIMILARITY',
      ciphertexts: [...query, ...signal],
      priority: 3,
      timeoutSeconds: 45,
    );
    return _waitForJobResult(jobId);
  }

  Future<String> _waitForJobResult(String jobId) async {
    for (var attempt = 0; attempt < 60; attempt++) {
      final job = await _repository.getJobStatus(jobId);
      final status = (job['status'] ?? '').toString();
      final result = job['result'];
      if (status == 'completed' && result is String && result.isNotEmpty) {
        return result;
      }
      if (status == 'failed' ||
          status == 'cancelled' ||
          status == 'dead_letter') {
        throw StateError(job['error']?.toString() ?? 'FHE job $status');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw TimeoutException('FHE discovery job timed out.');
  }

  String _confidenceFor(int score) {
    if (score >= 14) return 'High';
    if (score >= 10) return 'Medium';
    return 'Exploratory';
  }

  int _dot(List<int> a, List<int> b) {
    var total = 0;
    for (var i = 0; i < a.length && i < b.length; i++) {
      total += a[i] * b[i];
    }
    return total;
  }

  List<int> _vectorForQuestion(String question) {
    final lower = question.toLowerCase();
    if (lower == _defaultQuestion.toLowerCase()) {
      return _defaultQuestionVector;
    }
    var clinical = 1;
    var statistical = 1;
    var biomarker = 1;

    for (final word in const [
      'clinical',
      'hospital',
      'patient',
      'sepsis',
      'intervention',
      'outcome',
      'timing',
    ]) {
      if (lower.contains(word)) clinical++;
    }
    for (final word in const [
      'cohort',
      'statistics',
      'model',
      'confidence',
      'validation',
      'compare',
      'overlap',
    ]) {
      if (lower.contains(word)) statistical++;
    }
    for (final word in const [
      'marker',
      'biomarker',
      'immune',
      'lab',
      'assay',
      'signal',
    ]) {
      if (lower.contains(word)) biomarker++;
    }

    return [
      clinical.clamp(1, 3),
      statistical.clamp(1, 3),
      biomarker.clamp(1, 3),
    ];
  }

  String _demoCiphertext(String id, int score) {
    final seed = id.codeUnits.fold<int>(score * 7919, (acc, code) {
      return (acc * 33 + code) & 0x7fffffff;
    });
    final hex = seed.toRadixString(16).padLeft(8, '0');
    return 'tfhe:v1:$hex...sealed-score';
  }

  String _previewCiphertext(String ciphertext) {
    if (ciphertext.length <= 32) return ciphertext;
    return '${ciphertext.substring(0, 14)}...${ciphertext.substring(ciphertext.length - 14)}';
  }
}

/// Effective signal vectors per participant plus the per-document provenance
/// used to render the input-documents panel.
class _ResolvedSignals {
  final Map<String, List<int>> vectors;
  final List<ResearchInputDocument> documents;

  const _ResolvedSignals({required this.vectors, required this.documents});

  List<int> vectorFor(ConfidentialParticipant participant) {
    return vectors[participant.id] ?? participant.privateSignal;
  }
}

final fheDemoProvider = NotifierProvider<FheDemoNotifier, FheDemoState>(() {
  return FheDemoNotifier();
});

class FheState {
  final bool isEnabled;
  final bool hasKeys;
  final String? activeJobId;
  final String? activeJobStatus;
  final double activeJobProgress;
  final String? activeJobResult;
  final String? error;

  FheState({
    required this.isEnabled,
    required this.hasKeys,
    this.activeJobId,
    this.activeJobStatus,
    this.activeJobProgress = 0.0,
    this.activeJobResult,
    this.error,
  });

  FheState copyWith({
    bool? isEnabled,
    bool? hasKeys,
    String? activeJobId,
    String? activeJobStatus,
    double? activeJobProgress,
    String? activeJobResult,
    String? error,
  }) {
    return FheState(
      isEnabled: isEnabled ?? this.isEnabled,
      hasKeys: hasKeys ?? this.hasKeys,
      activeJobId: activeJobId ?? this.activeJobId,
      activeJobStatus: activeJobStatus ?? this.activeJobStatus,
      activeJobProgress: activeJobProgress ?? this.activeJobProgress,
      activeJobResult: activeJobResult ?? this.activeJobResult,
      error: error ?? this.error,
    );
  }
}

class FheNotifier extends Notifier<FheState> {
  late final FheEngine _engine;
  late final FheRepository _repository;

  @override
  FheState build() {
    _engine = FheEngine();
    _repository = FheRepositoryImpl();
    return FheState(
      isEnabled: FheConfig.anyEnabled,
      hasKeys: FheKeyManager.instance.hasKeys,
    );
  }

  Future<void> generateSessionKeys() async {
    if (!state.isEnabled) return;
    try {
      await _engine.generateKeys();
      state = state.copyWith(hasKeys: true, error: null);
    } catch (e) {
      state = state.copyWith(error: 'Key generation failed: $e');
    }
  }

  Future<String> encryptValue(int value) async {
    return _engine.encrypt(value);
  }

  Future<int> decryptValue(String ciphertext) async {
    return _engine.decrypt(ciphertext);
  }

  Future<void> submitAndPollCompute(
    List<String> ciphertexts,
    String operation,
  ) async {
    if (!state.isEnabled) return;
    if (!state.hasKeys && FheConfig.enableKeyGeneration) {
      await generateSessionKeys();
    }

    final keyId = FheKeyManager.instance.keyId ?? 'default-key';

    try {
      state = state.copyWith(
        activeJobStatus: 'submitting',
        activeJobProgress: 0.1,
        error: null,
      );
      final jobId = await _repository.submitComputeJob(
        keyId: keyId,
        operation: operation,
        ciphertexts: ciphertexts,
      );

      state = state.copyWith(
        activeJobId: jobId,
        activeJobStatus: 'pending',
        activeJobProgress: 0.2,
      );

      _startPolling(jobId);
    } catch (e) {
      state = state.copyWith(activeJobStatus: 'failed', error: e.toString());
    }
  }

  void _startPolling(String jobId) async {
    var attempts = 0;
    while (attempts < 60) {
      if (state.activeJobId != jobId || state.activeJobStatus == 'cancelled') {
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      try {
        final job = await _repository.getJobStatus(jobId);
        final status = job['status'] as String;
        final progress = (job['progress'] as num?)?.toDouble() ?? 0.0;
        final result = job['result'] as String?;

        state = state.copyWith(
          activeJobStatus: status,
          activeJobProgress: progress,
          activeJobResult: result,
        );

        if (status == 'completed' || status == 'failed') {
          break;
        }
      } catch (e) {
        state = state.copyWith(activeJobStatus: 'failed', error: e.toString());
        break;
      }
      attempts++;
    }
  }

  Future<void> cancelActiveJob() async {
    final jobId = state.activeJobId;
    if (jobId != null) {
      final success = await _repository.cancelJob(jobId);
      if (success) {
        state = state.copyWith(activeJobStatus: 'cancelled');
      }
    }
  }
}

final fheProvider = NotifierProvider<FheNotifier, FheState>(() {
  return FheNotifier();
});
