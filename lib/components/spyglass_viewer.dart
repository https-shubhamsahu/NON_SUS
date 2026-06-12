import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../services/secure_enclave.dart';
import '../features/files/presentation/providers/secure_file_providers.dart';
import 'secure_viewer/models/watermark_config.dart';
import 'secure_viewer/models/viewer_config.dart';
import 'secure_viewer/secure_document_viewer.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/profile/providers/profile_provider.dart';

// ─── Demo user session (replace with real auth data) ─────────────────────────

const _demoEmail = 'student@nosus.app';

/// The full-screen secure document viewer page.
///
/// Integrates [SecureEnclave] to load, decrypt in-memory, and purge volatile
/// buffer segments upon exiting the document to enforce Zero-Trust memory parameters.
class SpyglassViewer extends ConsumerStatefulWidget {
  final String? fileId;
  final String? email;
  final String? phone;
  final String? documentTitle;
  final String? documentCategory;

  const SpyglassViewer({
    super.key,
    this.fileId,
    this.email,
    this.phone,
    this.documentTitle,
    this.documentCategory,
  });

  @override
  ConsumerState<SpyglassViewer> createState() => _SpyglassViewerState();
}

class _SpyglassViewerState extends ConsumerState<SpyglassViewer> {
  final String _sessionTimestamp = _buildTimestamp();
  bool _isLoading = true;
  String _decryptedContent = '';
  double _streamProgress = 0.0;
  String _loadingStatus = 'Requesting secure proxy...';
  bool _isPdf = false;
  bool _isImage = false;

  static String _buildTimestamp() {
    final now = DateTime.now();
    return '${now.year}-${_pad(now.month)}-${_pad(now.day)} '
        '${_pad(now.hour)}:${_pad(now.minute)} IST';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
    ));

    _loadSecureEnclavePayload();
  }

  @override
  void dispose() {
    // Purge the memory buffer immediately when leaving the viewer
    SecureEnclave.purge();
    super.dispose();
  }

  Future<void> _loadSecureEnclavePayload() async {
    Uint8List? plainBytes;

    if (widget.fileId != null) {
      setState(() {
        _loadingStatus = 'Connecting to secure repository...';
      });
      
      final streamedBytes = await ref.read(secureFileRepositoryProvider).downloadAndDecryptFile(
        fileId: widget.fileId!,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _streamProgress = progress;
              _loadingStatus = 'Downloading and decrypting: ${(progress * 100).toStringAsFixed(0)}%';
            });
          }
        },
      );

      if (streamedBytes != null) {
        if (mounted) {
          setState(() {
            _loadingStatus = 'Decrypting inside RAM enclave...';
          });
        }
        // Simulate enclave registration processing time
        await Future.delayed(const Duration(milliseconds: 300));
        SecureEnclave.registerDecryptedBuffer(streamedBytes);
        plainBytes = streamedBytes;
      }
    }

    // Fallback if streaming failed or no fileId was provided
    if (plainBytes == null) {
      final rawText = _getDocumentText();
      const mockKey = "NOSUS_SECRET_DRM_KEY_2026";
      final encryptedBase64 = SecureEnclave.encryptMockData(rawText, mockKey);
      plainBytes = await SecureEnclave.loadDocument(encryptedBase64, mockKey);
    }

    // Detect PDF by magic bytes %PDF
    bool isPdfFile = false;
    if (plainBytes.length >= 4 &&
        plainBytes[0] == 0x25 && // %
        plainBytes[1] == 0x50 && // P
        plainBytes[2] == 0x44 && // D
        plainBytes[3] == 0x46) { // F
      isPdfFile = true;
    } else if (widget.documentCategory == 'PDF') {
      isPdfFile = true;
    }

    // Detect Image by magic bytes or category
    bool isImageFile = false;
    if (plainBytes.length >= 3 &&
        plainBytes[0] == 0xFF &&
        plainBytes[1] == 0xD8 &&
        plainBytes[2] == 0xFF) { // JPEG
      isImageFile = true;
    } else if (plainBytes.length >= 4 &&
        plainBytes[0] == 0x89 &&
        plainBytes[1] == 0x50 &&
        plainBytes[2] == 0x4E &&
        plainBytes[3] == 0x47) { // PNG
      isImageFile = true;
    } else if (widget.documentCategory == 'IMAGE' || widget.documentCategory == 'SCAN') {
      isImageFile = true;
    }

    String decoded = '';
    if (!isPdfFile && !isImageFile) {
      try {
        decoded = utf8.decode(plainBytes);
      } catch (_) {
        decoded = '[SECURED DOCUMENT PREVIEW]\nThis document is a binary PDF/media asset loaded securely inside the RAM enclave.';
      }
    }

    if (mounted) {
      setState(() {
        _isPdf = isPdfFile;
        _isImage = isImageFile;
        _decryptedContent = decoded;
        _isLoading = false;
      });
    }
  }

  String _getDocumentText() {
    final title = widget.documentTitle;
    if (title != null) {
      if (title.contains('Zero-Knowledge')) {
        return '''Public-Key Cryptography / Introduction to Zero-Knowledge Proofs
A Zero-Knowledge Proof (ZKP) allows a prover to convince a verifier that a statement is true without revealing any information beyond the validity of the statement itself.

Key ZKP Properties
1. Completeness: If the statement is true, an honest verifier will be convinced by an honest prover.
2. Soundness: If the statement is false, no cheating prover can convince an honest verifier (except with tiny probability).
3. Zero-Knowledge: If the statement is true, no verifier learns anything other than this fact.

Applications in Privacy-Preserving Computations
ZKPs are crucial in decentralized identity, anonymous transactions, and secure rollup chains. By verifying computations off-chain and only committing proofs on-chain, we achieve both high throughput and extreme privacy bounds.''';
      } else if (title.contains('AES-256-GCM')) {
        return '''Galois Counter Mode (GCM) / AES-256-GCM Hardware Performance
Advanced Encryption Standard (AES) with Galois/Counter Mode (GCM) provides both confidentiality and data integrity.

Hardware Acceleration
Modern CPUs provide instructions (like Intel's AES-NI or ARMv8 Cryptography extensions) that execute rounds of AES in hardware. This mitigates cache-timing side-channel attacks by executing lookup tables in constant time.

Galois Multiplier
GCM utilizes universal hashing over a binary Galois field (GF(2^128)) for authentication. The PCLMULQDQ instruction performs carry-less multiplication of two 64-bit values, accelerating the Ghash calculation significantly.''';
      } else if (title.contains('System Architecture')) {
        return '''Secure Enclave Infrastructure / System Architecture & Isolation
Secure study enclaves rely on ring-0 isolation boundaries to ensure workspace integrity.

Microkernel Principles
To minimize the Trusted Computing Base (TCB), all non-essential OS services (such as drivers and filesystems) are executed in user space rather than kernel space.

Memory Protection
Intel SGX or AMD SEV isolate memory regions by hardware-encrypting RAM pages. Any unauthorized access from higher privilege rings triggers a processor exception, preventing memory inspection from rootkits or compromised hypervisors.''';
      }
    }

    return '''Asymmetric Key Cryptography / Advanced Cryptography
Public-Key Infrastructure uses a mathematically linked key pair: a public key that anyone may use to encrypt data, and a private key held exclusively by the recipient to decrypt it.

Key Exchange — Diffie-Hellman
The Diffie-Hellman key exchange allows two parties to establish a shared secret over an insecure channel without prior communication.

Digital Signatures
A digital signature provides authentication, integrity, and non-repudiation. RSA-PSS is the recommended padding scheme for RSA signatures. ECDSA with SHA-256 is preferred for compact signatures.''';
  }

  String _getAvatarLabel(String colorStart) {
    switch (colorStart) {
      case 'FF0072FF':
        return 'THE BUILDER';
      case 'FFCCCCCC':
        return 'THE RESEARCHER';
      case 'FFFF0072':
        return 'THE CREATOR';
      case 'FFF5A623':
        return 'THE ACADEMIC WEAPON';
      case 'FF800080':
        return 'THE CHAOS AGENT';
      case 'FFADF474':
        return 'THE ARCHIVIST';
      default:
        return 'THE BUILDER';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? NoSusTheme.dBackground : NoSusTheme.lBackground;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;

    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(profileProvider);

    final String userEmail = authState.value?.email ?? widget.email ?? _demoEmail;
    final String displayName = profileAsync.maybeWhen(
      data: (p) => p.displayName,
      orElse: () => userEmail.contains('@') ? userEmail.split('@').first : 'Guest Scholar',
    );
    final String startColor = profileAsync.maybeWhen(
      data: (p) => p.avatarColorStart,
      orElse: () => 'FF0072FF',
    );
    final String role = _getAvatarLabel(startColor);

    final watermarkConfig = WatermarkConfig(
      name: displayName.toUpperCase(),
      role: role,
      email: userEmail,
      timestamp: _sessionTimestamp,
      opacity: 0.075,
      fontSize: 10.5,
      tileSpacingX: 195.0,
      tileSpacingY: 95.0,
      angleDegrees: -28.0,
    );

    const viewerConfig = ViewerConfig(
      maxBlurSigma: 22.0,
      revealDuration: Duration(milliseconds: 115),
      concealDuration: Duration(milliseconds: 210),
      revealCurve: Curves.easeOut,
      concealCurve: Curves.easeIn,
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: fg, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.documentTitle ?? 'Study Notes',
              style: TextStyle(
                color: fg,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            if (widget.documentCategory != null)
              Text(
                widget.documentCategory!,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: fg.withValues(alpha: 0.18), width: 0.75),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 11, color: fg.withValues(alpha: 0.5)),
                const SizedBox(width: 5),
                Text(
                  'SECURE',
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            color: fg.withValues(alpha: 0.1),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _loadingStatus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        color: fg.withValues(alpha: 0.5),
                      ),
                    ),
                    if (widget.fileId != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _streamProgress,
                          backgroundColor: fg.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(fg.withValues(alpha: 0.6)),
                          minHeight: 2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : SecureDocumentViewer(
              watermarkConfig: watermarkConfig,
              viewerConfig: viewerConfig,
              showHint: true,
              child: _isPdf
                  ? SfPdfViewer.memory(
                      SecureEnclave.activeBuffer!,
                      enableDoubleTapZooming: true,
                    )
                  : _isImage
                      ? InteractiveViewer(
                          child: Center(
                            child: Image.memory(
                              SecureEnclave.activeBuffer!,
                            ),
                          ),
                        )
                      : _DocumentContent(
                          isDark: isDark,
                          fg: fg,
                          bg: bg,
                          text: _decryptedContent,
                        ),
            ),
    );
  }
}

// ─── Demo Document Content ────────────────────────────────────────────────────

class _DocumentContent extends StatelessWidget {
  final bool isDark;
  final Color fg;
  final Color bg;
  final String text;

  const _DocumentContent({
    required this.isDark,
    required this.fg,
    required this.bg,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = fg.withValues(alpha: 0.08);
    final subtleColor = fg.withValues(alpha: 0.45);
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    final paragraphs = text.split('\n\n');

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DocHeader(
            subject: 'SECURE MEMORY ENCLAVE',
            chapter: paragraphs.isNotEmpty ? paragraphs.first.split('\n').first : 'Decrypted Segment',
            date: 'TEMPORARY VOLATILE BUFFER',
            fg: fg,
            subtleColor: subtleColor,
          ),
          const SizedBox(height: 28),
          Divider(color: dividerColor, thickness: 0.5),
          const SizedBox(height: 28),
          for (final p in paragraphs) ...[
            if (p.trim().isNotEmpty) ...[
              _renderParagraph(p, cardBg, dividerColor),
              const SizedBox(height: 24),
            ],
          ],
          const SizedBox(height: 40),
          Center(
            child: Text(
              '— MEMORY ENCLAVE CLEARED ON EXIT —',
              style: TextStyle(
                color: subtleColor,
                fontSize: 10,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _renderParagraph(String p, Color cardBg, Color dividerColor) {
    final lines = p.split('\n');
    final title = lines.first;
    final body = lines.skip(1).join('\n');

    if (body.isEmpty) {
      return Text(
        title,
        style: TextStyle(
          color: fg.withValues(alpha: 0.8),
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.75,
        ),
      );
    }

    return _Section(
      title: title,
      body: body,
      fg: fg,
      subtleColor: fg.withValues(alpha: 0.45),
      cardBg: cardBg,
      dividerColor: dividerColor,
    );
  }
}

// ─── Document sub-widgets ─────────────────────────────────────────────────────

class _DocHeader extends StatelessWidget {
  final String subject;
  final String chapter;
  final String date;
  final Color fg;
  final Color subtleColor;

  const _DocHeader({
    required this.subject,
    required this.chapter,
    required this.date,
    required this.fg,
    required this.subtleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subject.toUpperCase(),
          style: TextStyle(
            color: subtleColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          chapter,
          style: TextStyle(
            color: fg,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          date,
          style: TextStyle(
            color: subtleColor,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  final Color fg;
  final Color subtleColor;
  final Color cardBg;
  final Color dividerColor;

  const _Section({
    required this.title,
    required this.body,
    required this.fg,
    required this.subtleColor,
    required this.cardBg,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: fg,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: TextStyle(
            color: fg.withValues(alpha: 0.75),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.75,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}
