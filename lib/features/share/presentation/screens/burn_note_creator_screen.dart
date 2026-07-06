import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encrypt/encrypt.dart' as enc;

String _bytesToHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

class BurnNoteCreatorScreen extends StatefulWidget {
  const BurnNoteCreatorScreen({super.key});

  @override
  State<BurnNoteCreatorScreen> createState() => _BurnNoteCreatorScreenState();
}

class _BurnNoteCreatorScreenState extends State<BurnNoteCreatorScreen> {
  final _textController = TextEditingController();
  bool _isGenerating = false;
  String? _generatedLink;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _generateLink() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a secret note first.')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // 1. Generate 256-bit AES Key and 128-bit IV
      final key = enc.Key.fromSecureRandom(32);
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key));

      // 2. Encrypt plaintext note
      final encrypted = encrypter.encrypt(text, iv: iv);
      final ciphertext = encrypted.base64;

      // 3. Upload to Supabase database (Server only gets UUID and ciphertext)
      final response = await Supabase.instance.client
          .from('burn_notes')
          .insert({
            'ciphertext': ciphertext,
          })
          .select('id')
          .single();

      final noteId = response['id'] as String;

      // 4. Construct URL with key and iv in the hash fragment (Zero-Knowledge)
      final origin = kIsWeb ? Uri.base.origin : 'https://https-shubhamsahu.github.io/NON_SUS';
      final keyHex = _bytesToHex(key.bytes);
      final ivHex = _bytesToHex(iv.bytes);
      final link = '$origin/#/burn/$noteId#$keyHex.$ivHex';

      setState(() {
        _generatedLink = link;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate link: $e')),
      );
    }
  }

  void _copyToClipboard() {
    if (_generatedLink == null) return;
    Clipboard.setData(ClipboardData(text: _generatedLink!));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Secret link copied to clipboard! Share it in your Story.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareLink() {
    if (_generatedLink == null) return;
    SharePlus.instance.share(
      ShareParams(text: 'Read my self-destructing secret note: $_generatedLink'),
    );
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
            Text(
              'BURN NOTES',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              'ZERO-KNOWLEDGE SELF-DESTRUCTS',
              style: TextStyle(
                fontSize: 9,
                color: Colors.orangeAccent,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_generatedLink == null) ...[
                Text(
                  'Write a secret message to share. The recipient can only view it once before it burns.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161616) : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: fg.withValues(alpha: 0.12)),
                    ),
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Type your secret message here...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isGenerating ? null : _generateLink,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.lock_outline, size: 16),
                    label: Text(
                      _isGenerating ? 'ENCRYPTING...' : 'ENCRYPT & GENERATE LINK',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ] else ...[
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      const Icon(Icons.verified_user_outlined, size: 48, color: Colors.green),
                      const SizedBox(height: 16),
                      const Text(
                        'SECRET NOTE SEALED',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your note is encrypted. The key is embedded in the link fragment. The server cannot read it, and it will be deleted permanently once opened.',
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
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
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
                            _textController.clear();
                          });
                        },
                        child: const Text('CREATE ANOTHER NOTE', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
