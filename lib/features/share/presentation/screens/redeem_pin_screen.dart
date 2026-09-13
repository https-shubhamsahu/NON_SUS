import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme.dart';
import '../../data/redemption_code_client.dart';
import 'burn_file_viewer_screen.dart';
import 'burn_note_viewer_screen.dart';

/// Recipient confirmation after opening `/#/r/<token>`.
///
/// The unguessable [accessToken] is the authorization secret. The two-digit
/// pin is only a pairing check so a forwarded link is not enough by itself.
class RedeemPinScreen extends StatefulWidget {
  final String accessToken;

  const RedeemPinScreen({super.key, required this.accessToken});

  @override
  State<RedeemPinScreen> createState() => _RedeemPinScreenState();
}

class _RedeemPinScreenState extends State<RedeemPinScreen> {
  final _pinController = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit(String pin) async {
    if (_loading || pin.length != 2) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await RedemptionCodeClient.instance.redeem(
        token: widget.accessToken,
        pin: pin,
      );
      if (!mounted) return;
      final viewer = result.targetKind == 'file'
          ? BurnFileViewerScreen(
              files: [(
                id: result.targetId,
                keyHex: result.keyHex,
                ivHex: result.ivHex,
              )],
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
      _pinController.clear();
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark ? NoSusTheme.dTextSecondary : NoSusTheme.lTextSecondary;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(NoSusTheme.s24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'NO SUS',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Enter the 2-digit code',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The sender read this out after sharing the link.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: subtle),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _pinController,
                      focusNode: _focus,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      enabled: !_loading,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 12,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••',
                        errorText: _error,
                        errorMaxLines: 3,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(NoSusTheme.r16),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) {
                        if (_error != null) setState(() => _error = null);
                        if (value.length == 2) _submit(value);
                      },
                    ),
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
