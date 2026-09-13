import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme.dart';
import '../../data/redemption_code_client.dart';
import '../../../../core/utils/web_links.dart';
import 'burn_file_viewer_screen.dart';
import 'burn_note_viewer_screen.dart';
import 'redeem_pin_screen.dart';

/// In-app redeem. New shares use a link (`/#/r/<token>`) plus a 2-digit pin.
/// Legacy 8-character codes still redeem here.
class RedeemCodeScreen extends StatefulWidget {
  const RedeemCodeScreen({super.key});

  @override
  State<RedeemCodeScreen> createState() => _RedeemCodeScreenState();
}

class _RedeemCodeScreenState extends State<RedeemCodeScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  String? _tokenFrom(String raw) {
    final trimmed = raw.trim();
    final rMatch = RegExp(r'[#/]r/([a-fA-F0-9]{32})').firstMatch(trimmed);
    if (rMatch != null) return rMatch.group(1)!.toLowerCase();
    if (RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(trimmed)) {
      return trimmed.toLowerCase();
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    final raw = _input.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Paste the link, or enter a legacy code.');
      return;
    }

    final token = _tokenFrom(raw);
    if (token != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RedeemPinScreen(accessToken: token)),
      );
      return;
    }

    // Legacy 8-character codes, or a burn URL the user pasted by mistake.
    if (raw.contains('/burn')) {
      setState(() => _error = 'That looks like a full share link — open it directly.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await RedemptionCodeClient.instance.redeem(code: raw);
      if (!mounted) return;
      final viewer = result.targetKind == 'file'
          ? BurnFileViewerScreen(
              files: [(id: result.targetId, keyHex: result.keyHex, ivHex: result.ivHex)],
            )
          : BurnNoteViewerScreen(
              noteId: result.targetId,
              keyHex: result.keyHex,
              ivHex: result.ivHex,
            );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => viewer),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtle = isDark ? NoSusTheme.dTextSecondary : NoSusTheme.lTextSecondary;
    final (:origin, :basePath) = webShareLinkBase();

    return Scaffold(
      appBar: AppBar(title: const Text('Open a share')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(
                parent: NoSusTheme.getScrollPhysics(context),
              ),
              padding: const EdgeInsets.all(NoSusTheme.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Got a link and a 2-digit code?', style: theme.textTheme.titleLarge),
                  const SizedBox(height: NoSusTheme.s8),
                  Text(
                    'Paste the link you were sent. You will type the 2-digit code on the next screen. Older 8-character codes still work here.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: subtle),
                  ),
                  const SizedBox(height: NoSusTheme.s32),
                  TextField(
                    controller: _input,
                    focusNode: _focus,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    style: theme.textTheme.titleMedium,
                    decoration: InputDecoration(
                      hintText: '$origin$basePath/#/r/…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(NoSusTheme.r12),
                      ),
                      errorText: _error,
                      errorMaxLines: 3,
                    ),
                    onSubmitted: (_) => _submit(),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                  const SizedBox(height: NoSusTheme.s24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            )
                          : const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
