import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../../../core/mascot/mascot_controller.dart';
import '../../../../core/mascot/mascot_state.dart';
import '../../../../core/mascot/mascot_view.dart';
import '../../../../services/burn_file_crypto.dart';
import '../../data/burn_file_client.dart';

/// Anonymous recipient side of "Burn Files" — no account, no email gate,
/// single tap. Unlike BurnNoteViewerScreen there's no "live viewing
/// session" to protect (no countdown/blur-to-conceal): once the file is
/// fetched, decrypted, and handed to the OS share sheet / browser download,
/// the job is done — the server-side deletion already happened the moment
/// [BurnFileClient.fetch] resolved (see claim_burn_file in
/// supabase/migrations/20260710050000_burn_files.sql).
class BurnFileViewerScreen extends ConsumerStatefulWidget {
  final String fileId;
  final String keyHex;
  final String ivHex;

  const BurnFileViewerScreen({
    super.key,
    required this.fileId,
    required this.keyHex,
    required this.ivHex,
  });

  @override
  ConsumerState<BurnFileViewerScreen> createState() => _BurnFileViewerScreenState();
}

enum _Stage { gate, fetching, delivered, error }

class _BurnFileViewerScreenState extends ConsumerState<BurnFileViewerScreen> {
  _Stage _stage = _Stage.gate;
  String? _errorMessage;
  String? _deliveredFileName;

  Future<void> _downloadAndDecrypt() async {
    setState(() => _stage = _Stage.fetching);
    ref.read(noxMascotProvider.notifier).play(MascotMood.guard);

    try {
      // 1. Atomically claim the file — a second attempt on this same link
      // will always fail from here on, even before the storage bytes are
      // actually swept.
      final signedUrl = await BurnFileClient.instance.fetch(widget.fileId);

      // 2. Pull the encrypted blob and decrypt client-side. The key/IV
      // came from the URL fragment and never touched the server.
      final res = await http.get(Uri.parse(signedUrl));
      if (res.statusCode != 200) {
        throw Exception('Could not download the file.');
      }
      final key = enc.Key(hexToBytes(widget.keyHex));
      final iv = enc.IV(hexToBytes(widget.ivHex));
      final packed = decryptBurnFilePayload(res.bodyBytes, key, iv);
      final payload = unpackBurnFilePayload(packed);

      if (!mounted) return;
      setState(() {
        _deliveredFileName = payload.fileName;
        _stage = _Stage.delivered;
      });
      ref.read(noxMascotProvider.notifier).play(MascotMood.approve);

      // 3. Hand off to the OS share sheet (mobile/desktop) or trigger a
      // browser download (web) — XFile.fromData has a platform-appropriate
      // implementation for both, so this is one code path for every target.
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(payload.bytes, name: payload.fileName, mimeType: payload.mimeType)],
        ),
      );
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
      title: 'NO SUS — Burn File',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: switch (_stage) {
                  _Stage.gate => _buildGate(),
                  _Stage.fetching => _buildFetching(),
                  _Stage.delivered => _buildDelivered(),
                  _Stage.error => _buildError(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGate() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.local_fire_department, size: 56, color: Colors.orangeAccent),
        const SizedBox(height: 24),
        const Text(
          'BURN FILE DETECTED',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        const Text(
          'This is an encrypted, one-time file drop. No account needed. Once you download it, it is permanently deleted from the server.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _downloadAndDecrypt,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('DOWNLOAD FILE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildFetching() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: Colors.orangeAccent),
        SizedBox(height: 20),
        Text(
          'DECRYPTING & DELIVERING...',
          style: TextStyle(fontSize: 10, letterSpacing: 1.0, color: Colors.orangeAccent),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDelivered() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MascotView(
          character: MascotCharacter.nox,
          size: 48,
          fallback: const Icon(Icons.verified_user_outlined, size: 48, color: Colors.green),
        ),
        const SizedBox(height: 20),
        const Text(
          'FILE DELIVERED',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        const SizedBox(height: 12),
        Text(
          _deliveredFileName ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'This file has been permanently deleted from our servers. This link will never work again.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MascotView(
          character: MascotCharacter.nox,
          size: 48,
          fallback: const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
        ),
        const SizedBox(height: 20),
        Text(
          _errorMessage ?? 'THIS LINK HAS EXPIRED OR ALREADY BEEN USED.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.redAccent),
        ),
      ],
    );
  }
}
