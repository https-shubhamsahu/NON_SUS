import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'package:universal_html/html.dart' as html;

import '../../../../components/secure_viewer/models/viewer_config.dart';
import '../../../../components/secure_viewer/models/watermark_config.dart';
import '../../../../components/secure_viewer/secure_document_viewer.dart';
import '../../data/share_fetch_client.dart';
import '../../data/share_heartbeat_client.dart';
import '../../domain/entities/share_link.dart';

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
class AnonymousShareViewerScreen extends StatefulWidget {
  const AnonymousShareViewerScreen({super.key, required this.token});

  final String token;

  @override
  State<AnonymousShareViewerScreen> createState() =>
      _AnonymousShareViewerScreenState();
}

enum _Stage { appPrompt, emailGate, loading, viewing, error }

class _AnonymousShareViewerScreenState
    extends State<AnonymousShareViewerScreen> {
  _Stage _stage = _Stage.emailGate;
  final _emailController = TextEditingController();
  String? _errorMessage;
  ShareFetchResult? _result;
  Uint8List? _bytes;
  Timer? _heartbeatTimer;

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
          'scheme=io.nosus.app;'
          'package=io.nosus.app;'
          'S.browser_fallback_url=${Uri.encodeComponent(fallbackUrl)};'
          'end';
      html.window.location.href = intentUrl;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final appUrl = 'io.nosus.app://v/$token';
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
      if (result.viewEventId != null) {
        _startHeartbeat(result.viewEventId!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
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
              const Icon(Icons.security, size: 48, color: Colors.blueAccent),
              const SizedBox(height: 24),
              const Text(
                'NO SUS',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              const Text(
                'You received a secure document. Open it in the NO SUS app for maximum security.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openInApp,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('OPEN IN APP'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _downloadApk,
                  icon: const Icon(Icons.download),
                  label: const Text('DOWNLOAD APK'),
                ),
              ),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: TextStyle(fontSize: 10, color: Colors.white38)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _stage = _Stage.emailGate;
                  });
                },
                child: const Text('CONTINUE IN BROWSER', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
              const Icon(Icons.lock_outline, size: 32),
              const SizedBox(height: 16),
              const Text('Secure Document',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'This document is watermarked with your email and every '
                'view is logged. Enter your email to continue.',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'you@example.com',
                  errorText: _errorMessage,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('VIEW DOCUMENT'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 1.5)),
          SizedBox(height: 16),
          Text('Preparing secure view…', style: TextStyle(fontSize: 12)),
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
            const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'This link could not be opened.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => setState(() {
                _stage = _Stage.emailGate;
                _errorMessage = null;
              }),
              child: const Text('TRY AGAIN'),
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
    switch (result.fileType) {
      case 'pdf':
        child = PdfViewer.data(bytes, sourceName: result.fileName);
        break;
      case 'image':
      case 'scan':
        child = InteractiveViewer(child: Center(child: Image.memory(bytes)));
        break;
      default:
        child = Center(
          child: Text(
            'This file type cannot be previewed in the browser.',
            style: const TextStyle(fontSize: 13),
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
                child: Text(result.fileName,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(
                '${result.watermarkEnforced ? "WATERMARKED" : "NO WATERMARK"} · VIEW LOGGED',
                style: const TextStyle(fontSize: 9, color: Colors.white38, letterSpacing: 0.5),
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
            child: child,
          ),
        ),
      ],
    );

  }
}
