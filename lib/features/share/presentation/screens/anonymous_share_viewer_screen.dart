import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'package:universal_html/html.dart' as html;
import 'package:google_fonts/google_fonts.dart';

import '../../../../components/secure_viewer/models/viewer_config.dart';
import '../../../../components/secure_viewer/models/watermark_config.dart';
import '../../../../components/secure_viewer/secure_document_viewer.dart';
import '../../data/share_fetch_client.dart';
import '../../data/share_heartbeat_client.dart';
import '../../../../services/web_security_guard.dart';
import '../../domain/entities/share_link.dart';
import '../../../../core/mascot/mascot_controller.dart';
import '../../../../core/mascot/mascot_state.dart';
import '../../../../core/mascot/mascot_view.dart';

/// SecureSend's anonymous recipient view. Deliberately NOT a [ConsumerWidget]
/// and NOT wired to any Supabase session — a share-link recipient may have no
/// NO SUS account at all. Auth for this screen is the link token itself.
///
/// Flow: enter email (the watermark identity + what gets logged) -> resolve
/// the token via the public `share-fetch` function -> fetch bytes from the
/// short-lived signed URL -> render in the SAME secure viewer used in-app.
///
/// HONESTY RULE: this is a browser. Screenshot-blocking is impossible here —
/// protection is watermark-with-identity + blur-until-touch + view logging.
/// Never claim "screenshot-proof" in this screen's copy.
class AnonymousShareViewerScreen extends ConsumerStatefulWidget {
  const AnonymousShareViewerScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<AnonymousShareViewerScreen> createState() =>
      _AnonymousShareViewerScreenState();
}

enum _Stage { appPrompt, emailGate, loading, viewing, error }

class _AnonymousShareViewerScreenState
    extends ConsumerState<AnonymousShareViewerScreen> {
  _Stage _stage = _Stage.emailGate;
  final _emailController = TextEditingController();
  String? _errorMessage;
  ShareFetchResult? _result;
  Uint8List? _bytes;
  Timer? _heartbeatTimer;
  final _webGuard = WebSecurityGuard();
  // Broadcasts to SecureDocumentViewer's blur layer whenever WebSecurityGuard
  // reports a signal that suggests active inspection or capture. This can't
  // detect an actual OS screenshot — no browser API exposes that — but
  // DevTools opening or repeated tab-hiding are the closest real proxies,
  // and blurring immediately on them is a genuine reactive deterrent rather
  // than a claim of prevention.
  final _concealSignal = StreamController<void>.broadcast();

  static const _concealTriggers = {
    'devtools_detected',
    'visibility_hidden_repeated',
    'automation_detected',
  };

  @override
  void initState() {
    super.initState();
    // Default to appPrompt on mobile web, else skip straight to emailGate
    final isMobileWeb = kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    _stage = isMobileWeb ? _Stage.appPrompt : _Stage.emailGate;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _stopHeartbeat(close: true);
    _webGuard.detach();
    _concealSignal.close();
    super.dispose();
  }

  void _startHeartbeat(String eventId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      ShareHeartbeatClient.instance.sendHeartbeat(eventId);
    });
  }

  void _stopHeartbeat({bool close = false}) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final eventId = _result?.viewEventId;
    if (eventId != null && close) {
      ShareHeartbeatClient.instance.sendHeartbeat(eventId, close: true);
    }
  }

  void _openInApp() {
    if (!kIsWeb) return;
    
    final token = widget.token;
    final fallbackUrl = 'https://github.com/https-shubhamsahu/NON_SUS/releases/latest/download/nosus.apk';
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      final intentUrl = 'intent://v/$token#Intent;'
          'scheme=foo.nosus.app;'
          'package=foo.nosus.app;'
          'S.browser_fallback_url=${Uri.encodeComponent(fallbackUrl)};'
          'end';
      html.window.location.href = intentUrl;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final appUrl = 'foo.nosus.app://v/$token';
      html.window.location.href = appUrl;
      
      Timer(const Duration(seconds: 2), () {
        html.window.location.href = fallbackUrl;
      });
    }
  }

  void _downloadApk() {
    if (kIsWeb) {
      html.window.location.href = 'https://github.com/https-shubhamsahu/NON_SUS/releases/latest/download/nosus.apk';
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Enter a valid email to continue.');
      return;
    }

    setState(() {
      _stage = _Stage.loading;
      _errorMessage = null;
    });
    ref.read(noxMascotProvider.notifier).play(MascotMood.verify);

    try {
      final result = await ShareFetchClient.instance.fetch(
        token: widget.token,
        viewerEmail: email,
      );
      final bytesRes = await http.get(Uri.parse(result.signedUrl));
      if (bytesRes.statusCode != 200) {
        throw Exception('Could not download the document.');
      }
      if (!mounted) return;
      setState(() {
        _result = result;
        _bytes = bytesRes.bodyBytes;
        _stage = _Stage.viewing;
      });
      ref.read(noxMascotProvider.notifier).play(MascotMood.approve);
      if (result.viewEventId != null) {
        _startHeartbeat(result.viewEventId!);
      }
      // Deterrent layer for this viewing session — see WebSecurityGuard's
      // honesty-rule docs: this reduces casual leak paths and reports
      // devtools/visibility signals, it does not prevent screenshots.
      _webGuard.attach((eventType) {
        final eventId = _result?.viewEventId;
        if (eventId != null) {
          ShareHeartbeatClient.instance.sendHeartbeat(eventId, eventType: eventType);
        }
        if (_concealTriggers.contains(eventType)) {
          _concealSignal.add(null);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
      ref.read(noxMascotProvider.notifier).play(MascotMood.alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NO SUS — Secure Document',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: switch (_stage) {
            _Stage.appPrompt => _buildAppPrompt(),
            _Stage.emailGate => _buildEmailGate(),
            _Stage.loading => _buildLoading(),
            _Stage.error => _buildError(),
            _Stage.viewing => _buildViewer(),
          },
        ),
      ),
    );
  }

  Widget _buildAppPrompt() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security_outlined, size: 54, color: Colors.white70),
              const SizedBox(height: 24),
              Text(
                'NO SUS // SECURE GATEWAY',
                style: GoogleFonts.vt323(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You received a secure document. Open it in the NO SUS app for maximum security & active screenshot protection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openInApp,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(
                    'OPEN IN APP',
                    style: GoogleFonts.vt323(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _downloadApk,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54, width: 1.2),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.download, size: 16),
                  label: Text(
                    'DOWNLOAD APK',
                    style: GoogleFonts.vt323(fontSize: 18, letterSpacing: 1.0),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.white12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: GoogleFonts.vt323(fontSize: 14, color: Colors.white38),
                    ),
                  ),
                  const Expanded(child: Divider(color: Colors.white12)),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _stage = _Stage.emailGate;
                  });
                },
                child: Text(
                  'CONTINUE IN BROWSER',
                  style: GoogleFonts.vt323(
                    fontSize: 16,
                    color: Colors.grey,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailGate() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MascotView(
                character: MascotCharacter.nox,
                size: 36,
                fallback: Icon(Icons.lock_outline, size: 36, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Text(
                'RECIPROCITY VERIFICATION',
                style: GoogleFonts.vt323(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This document is encrypted and watermarked. Your access log will contain your verified identity. Enter your email to authenticate:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.vt323(fontSize: 18, color: Colors.white),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'you@example.com',
                  hintStyle: const TextStyle(color: Colors.white30, fontFamily: 'monospace', fontSize: 13),
                  errorText: _errorMessage,
                  errorStyle: GoogleFonts.vt323(color: Colors.redAccent, fontSize: 14),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _submit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'VIEW DOCUMENT',
                    style: GoogleFonts.vt323(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'DECRYPTING SECURE LEDGER...',
            style: GoogleFonts.vt323(fontSize: 16, letterSpacing: 1.0, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotView(
              character: MascotCharacter.nox,
              size: 40,
              fallback: Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'ACCESS DENIED OR EXPIRED.',
              textAlign: TextAlign.center,
              style: GoogleFonts.vt323(fontSize: 16, color: Colors.redAccent, letterSpacing: 1.0),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => setState(() {
                _stage = _Stage.emailGate;
                _errorMessage = null;
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38, width: 1.2),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'TRY AGAIN',
                style: GoogleFonts.vt323(fontSize: 16, letterSpacing: 1.0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewer() {
    final result = _result!;
    final bytes = _bytes!;
    final email = _emailController.text.trim();

    final watermarkConfig = WatermarkConfig(
      name: email,
      role: 'RECIPIENT',
      email: email,
      timestamp: DateTime.now().toIso8601String(),
    );

    Widget child;
    switch (result.fileType.toLowerCase()) {
      case 'pdf':
        child = PdfViewer.data(
          bytes,
          sourceName: result.fileName,
          // No text selection in the protected viewer (copy leak + pdfrx
          // 2.4.4 selection painter crash on textless pages).
          params: const PdfViewerParams(
            textSelectionParams: PdfTextSelectionParams(enabled: false),
          ),
        );
        break;
      case 'image':
      case 'scan':
        child = InteractiveViewer(child: Center(child: Image.memory(bytes)));
        break;
      default:
        child = const Center(
          child: Text(
            'This file type cannot be previewed in the browser.',
            style: TextStyle(fontSize: 13),
          ),
        );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.black,
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 14, color: Colors.white54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.fileName,
                  style: GoogleFonts.vt323(fontSize: 14, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${result.watermarkEnforced ? "WATERMARKED" : "NO WATERMARK"} · VIEW LOGGED',
                style: GoogleFonts.vt323(fontSize: 11, color: Colors.white54, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        Expanded(
          child: SecureDocumentViewer(
            watermarkConfig: watermarkConfig,
            viewerConfig: const ViewerConfig(),
            touchToRevealEnabled: result.blurEnforced,
            watermarkEnabled: result.watermarkEnforced,
            forceConcealSignal: _concealSignal.stream,
            child: child,
          ),
        ),
      ],
    );
  }
}
