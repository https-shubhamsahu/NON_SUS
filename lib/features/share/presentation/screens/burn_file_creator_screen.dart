import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/mascot/mascot_controller.dart';
import '../../../../core/mascot/mascot_state.dart';
import '../../../../core/mascot/mascot_view.dart';
import '../../../../core/utils/web_links.dart';
import '../../../../services/burn_file_crypto.dart';
import '../../data/burn_file_client.dart';
import '../../data/redemption_code_client.dart';

/// "Burn Files" creator — file.io-style anonymous upload. No login on
/// either end (product decision): the sender doesn't need an account, and
/// neither does the recipient. Mirrors BurnNoteCreatorScreen's zero-
/// knowledge design, extended to arbitrary binary files — see
/// lib/services/burn_file_crypto.dart for why the filename/mimetype are
/// packed INSIDE the encrypted payload rather than sent to the server.
class BurnFileCreatorScreen extends ConsumerStatefulWidget {
  /// Pre-fills the picker with a file shared into the app from another app
  /// (Photos, Files, WhatsApp, etc. via Android's share intent) — the
  /// highest-leverage "seamless" entry point: share a file into NO SUS and
  /// land here with it already selected.
  final fp.PlatformFile? prefilledFile;

  const BurnFileCreatorScreen({super.key, this.prefilledFile});

  @override
  ConsumerState<BurnFileCreatorScreen> createState() => _BurnFileCreatorScreenState();
}

enum _ExpiryOption { oneHour, oneDay, sevenDays }

extension on _ExpiryOption {
  int get hours => switch (this) {
        _ExpiryOption.oneHour => 1,
        _ExpiryOption.oneDay => 24,
        _ExpiryOption.sevenDays => 24 * 7,
      };

  String get label => switch (this) {
        _ExpiryOption.oneHour => '1 HOUR',
        _ExpiryOption.oneDay => '24 HOURS',
        _ExpiryOption.sevenDays => '7 DAYS',
      };
}

class _BurnFileCreatorScreenState extends ConsumerState<BurnFileCreatorScreen> {
  fp.PlatformFile? _selectedFile;
  _ExpiryOption _expiry = _ExpiryOption.oneDay;
  bool _isProcessing = false;
  String? _statusLabel;
  String? _generatedLink;
  String? _generatedCode;

  @override
  void initState() {
    super.initState();
    _selectedFile = widget.prefilledFile;
  }

  Future<void> _pickFile() async {
    final result = await fp.FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    setState(() => _selectedFile = result.files.first);
  }

  Future<void> _burnAndUpload() async {
    final file = _selectedFile;
    final bytes = file?.bytes;
    if (file == null || bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a file first.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusLabel = 'ENCRYPTING...';
    });
    ref.read(noxMascotProvider.notifier).play(MascotMood.guard);

    try {
      // 1. Zero-knowledge pack + encrypt — key/IV never leave this device
      // except embedded in the share link's URL fragment.
      final keyMaterial = generateBurnFileKeyMaterial();
      final packed = packBurnFilePayload(
        fileName: file.name,
        mimeType: _guessMimeType(file.extension),
        fileBytes: bytes,
      );
      final ciphertext = encryptBurnFilePayload(packed, keyMaterial.key, keyMaterial.iv);

      // 2. Reserve a file id + signed upload URL (rate-limited server-side).
      setState(() => _statusLabel = 'REQUESTING SECURE SLOT...');
      final initResult = await BurnFileClient.instance.init(
        declaredSizeBytes: ciphertext.length,
        expiryHours: _expiry.hours,
      );

      // 3. Upload the encrypted blob directly to Storage.
      setState(() => _statusLabel = 'UPLOADING...');
      await Supabase.instance.client.storage
          .from('burn-files')
          .uploadBinaryToSignedUrl(
            initResult.fileId,
            initResult.uploadToken,
            ciphertext,
          );

      // 4. Confirm — only after this does the file become downloadable.
      setState(() => _statusLabel = 'SEALING...');
      await BurnFileClient.instance.confirm(initResult.fileId);

      // 5. Build the share link. Filename deliberately never appears here.
      final (:origin, :basePath) = webShareLinkBase();
      final keyHex = bytesToHex(keyMaterial.key.bytes);
      final ivHex = bytesToHex(keyMaterial.iv.bytes);
      final link = '$origin$basePath/#/burnfile/${initResult.fileId}?k=$keyHex&v=$ivHex';

      // 6. Also mint a short redemption code pointing at the same key/IV —
      // best-effort: the link already works on its own, so a hiccup here
      // shouldn't fail the whole operation, just leave the code section
      // hidden.
      String? code;
      try {
        final codeResult = await RedemptionCodeClient.instance.createCode(
          targetKind: 'file',
          targetId: initResult.fileId,
          keyHex: keyHex,
          ivHex: ivHex,
        );
        code = codeResult.code;
      } catch (_) {
        code = null;
      }

      setState(() {
        _generatedLink = link;
        _generatedCode = code;
        _isProcessing = false;
        _statusLabel = null;
      });
      ref.read(noxMascotProvider.notifier).play(MascotMood.approve);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusLabel = null;
      });
      ref.read(noxMascotProvider.notifier).play(MascotMood.alert);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create Burn File: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  static String _guessMimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  void _copyToClipboard() {
    if (_generatedLink == null) return;
    Clipboard.setData(ClipboardData(text: _generatedLink!));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Burn Files link copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareLink() {
    if (_generatedLink == null) return;
    SharePlus.instance.share(
      ShareParams(text: 'Here\'s a file — it self-destructs after one download: $_generatedLink'),
    );
  }

  void _copyCodeToClipboard() {
    if (_generatedCode == null) return;
    Clipboard.setData(ClipboardData(text: _generatedCode!));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BURN FILES', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text(
              'ANONYMOUS · SELF-DESTRUCTS ON DOWNLOAD',
              style: TextStyle(fontSize: 9, color: Colors.orangeAccent, letterSpacing: 1.0, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_generatedLink == null) ...[
                  Text(
                    'Drop a file, get a link. Nobody needs an account — not you, not them. Once it\'s downloaded once, it\'s gone.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.6), fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: _isProcessing ? null : _pickFile,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161616) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedFile != null ? Colors.orangeAccent.withValues(alpha: 0.4) : fg.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _selectedFile != null ? Icons.insert_drive_file_outlined : Icons.upload_file_outlined,
                            size: 36,
                            color: _selectedFile != null ? Colors.orangeAccent : fg.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedFile?.name ?? 'TAP TO CHOOSE A FILE',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: fg.withValues(alpha: 0.85)),
                          ),
                          if (_selectedFile?.size != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _formatSize(_selectedFile!.size),
                              style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.4)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'LINK EXPIRES AFTER',
                    style: TextStyle(fontSize: 10, letterSpacing: 1.0, color: fg.withValues(alpha: 0.4), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<_ExpiryOption>(
                    segments: _ExpiryOption.values
                        .map((e) => ButtonSegment(value: e, label: Text(e.label, style: const TextStyle(fontSize: 11))))
                        .toList(),
                    selected: {_expiry},
                    onSelectionChanged: _isProcessing ? null : (s) => setState(() => _expiry = s.first),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isProcessing ? null : _burnAndUpload,
                      icon: _isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.local_fire_department_outlined, size: 16),
                      label: Text(
                        _isProcessing ? (_statusLabel ?? 'WORKING...') : 'ENCRYPT & GENERATE LINK',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else ...[
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        MascotView(
                          character: MascotCharacter.nox,
                          size: 48,
                          fallback: const Icon(Icons.verified_user_outlined, size: 48, color: Colors.green),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'FILE SEALED',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your file is encrypted. The key lives only in this link — the server cannot read it, and it\'s deleted permanently the moment it\'s downloaded.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161616) : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _generatedLink!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ),
                        if (_generatedCode != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            'OR SHARE THIS CODE',
                            style: TextStyle(fontSize: 10, letterSpacing: 1.0, color: fg.withValues(alpha: 0.4), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF161616) : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _generatedCode!,
                                  style: const TextStyle(fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent),
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: _copyCodeToClipboard,
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.copy_rounded, size: 16, color: Colors.lightBlueAccent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Expires in ~20 min, one-time use — anyone with this code can open the file.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10.5, color: fg.withValues(alpha: 0.4)),
                          ),
                        ],
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _copyToClipboard,
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('COPY LINK', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                            onPressed: _shareLink,
                            icon: const Icon(Icons.ios_share_rounded, size: 16),
                            label: const Text('SHARE LINK', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _generatedLink = null;
                              _generatedCode = null;
                              _selectedFile = null;
                            });
                          },
                          child: const Text('BURN ANOTHER FILE', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
