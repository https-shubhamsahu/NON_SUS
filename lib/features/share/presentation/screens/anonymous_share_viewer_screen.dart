import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';

import '../../../../components/secure_viewer/models/viewer_config.dart';
import '../../../../components/secure_viewer/models/watermark_config.dart';
import '../../../../components/secure_viewer/secure_document_viewer.dart';
import '../../data/share_fetch_client.dart';
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

enum _Stage { emailGate, loading, viewing, error }

class _AnonymousShareViewerScreenState
    extends State<AnonymousShareViewerScreen> {
  _Stage _stage = _Stage.emailGate;
  final _emailController = TextEditingController();
  String? _errorMessage;
  ShareFetchResult? _result;
  Uint8List? _bytes;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
            _Stage.emailGate => _buildEmailGate(),
            _Stage.loading => _buildLoading(),
            _Stage.error => _buildError(),
            _Stage.viewing => _buildViewer(),
          },
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
