import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../theme.dart';
import '../controllers/auth_controller.dart';
import '../providers/auth_providers.dart';


class AuthScreen extends ConsumerStatefulWidget {
  final String? pendingInviteCode;

  const AuthScreen({super.key, this.pendingInviteCode});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isPhoneAuth = false;
  bool _otpSent = false;
  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    if (widget.pendingInviteCode != null) {
      _savePendingInvite(widget.pendingInviteCode!);
    }
  }

  void _startResendTimer() {
    setState(() {
      _resendCooldown = 60;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown == 0) {
        timer.cancel();
      } else {
        setState(() {
          _resendCooldown--;
        });
      }
    });
  }

  Future<void> _savePendingInvite(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_invite_code', code);
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    if (_isPhoneAuth) {
      final phone = _phoneController.text.trim();
      if (!_otpSent) {
        if (phone.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Phone number is required.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        if (!phone.startsWith('+')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Phone number must start with country code (e.g. +1 or +91).'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        if (phone.length < 8) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Please enter a valid phone number.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        ref.read(authControllerProvider.notifier).signInWithPhone(phone).then((_) {
          if (mounted) {
            final controllerState = ref.read(authControllerProvider);
            if (!controllerState.hasError) {
              setState(() => _otpSent = true);
              _startResendTimer();
            }
          }
        });
      } else {
        final otp = _otpController.text.trim();
        ref.read(authControllerProvider.notifier).verifyPhoneOtp(phone, otp);
      }
    } else {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isSignUp) {
        ref.read(authControllerProvider.notifier).signUp(email, password);
      } else {
        ref.read(authControllerProvider.notifier).signIn(email, password);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark ? NoSusTheme.dTextSecondary : NoSusTheme.lTextSecondary;

    final authState = ref.watch(authControllerProvider);

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      if (next is AsyncData<void> && previous is AsyncLoading<void>) {
        if (_isSignUp) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF10B981),
              content: Text(
                'Registration successful! Please check your email for a confirmation link.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
          if (mounted) {
            setState(() {
              _isSignUp = false;
              _passwordController.clear();
            });
          }
        }
      }
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(
                error.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '').replaceAll('AuthException: ', ''),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      );
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: theme.platform == TargetPlatform.android
                ? const ClampingScrollPhysics()
                : const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(NoSusTheme.s24),
            // Sign-in card width on desktop/web instead of a full-bleed form.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Branding Header
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'NO SUS',
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: NoSusTheme.s8),
                        Text(
                          'SILENT SECURITY WORKSPACE',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 10,
                            color: fg.withValues(alpha: 0.5),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
                  const SizedBox(height: NoSusTheme.s48),

                  // Auth Card Container
                  Container(
                    padding: const EdgeInsets.all(NoSusTheme.s24),
                    decoration: NoSusTheme.cardDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPhoneAuth
                              ? (_otpSent ? 'VERIFY OTP' : 'PHONE AUTHENTICATION')
                              : (_isSignUp ? 'CREATE ACCOUNT' : 'AUTHENTICATE'),
                          style: TextStyle(
                            color: subtle,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: NoSusTheme.s16),

                        if (_isPhoneAuth) ...[
                          if (!_otpSent) ...[
                            // Phone Number Field
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              cursorColor: fg,
                              style: TextStyle(color: fg, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'PHONE NUMBER',
                                hintText: '+1234567890',
                                hintStyle: TextStyle(color: fg.withValues(alpha: 0.3)),
                                labelStyle: TextStyle(color: subtle, fontSize: 10, letterSpacing: 1.0),
                                floatingLabelStyle: TextStyle(color: fg, fontSize: 11, letterSpacing: 1.0),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: fg.withValues(alpha: 0.15)),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: fg),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Phone number is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: NoSusTheme.s32),
                            // Send OTP Button
                            GestureDetector(
                              onTap: authState.isLoading ? null : _submit,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                decoration: BoxDecoration(
                                  color: fg,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: authState.isLoading
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: isDark ? Colors.black : Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'SEND OTP',
                                          style: TextStyle(
                                            color: isDark ? Colors.black : Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ] else ...[
                            // Disabled Phone Number field
                            TextFormField(
                              controller: _phoneController,
                              enabled: false,
                              style: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'PHONE NUMBER',
                                labelStyle: TextStyle(color: subtle, fontSize: 10, letterSpacing: 1.0),
                                floatingLabelStyle: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 11, letterSpacing: 1.0),
                                disabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: fg.withValues(alpha: 0.15)),
                                ),
                              ),
                            ),
                            const SizedBox(height: NoSusTheme.s16),
                            // OTP Verification Field
                            TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              cursorColor: fg,
                              style: TextStyle(color: fg, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'VERIFICATION CODE',
                                labelStyle: TextStyle(color: subtle, fontSize: 10, letterSpacing: 1.0),
                                floatingLabelStyle: TextStyle(color: fg, fontSize: 11, letterSpacing: 1.0),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: fg.withValues(alpha: 0.15)),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: fg),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Verification code is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: NoSusTheme.s32),
                            // Verify OTP Button
                            GestureDetector(
                              onTap: authState.isLoading ? null : _submit,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                decoration: BoxDecoration(
                                  color: fg,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: authState.isLoading
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: isDark ? Colors.black : Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'VERIFY OTP',
                                          style: TextStyle(
                                            color: isDark ? Colors.black : Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: _resendCooldown > 0
                                    ? null
                                    : () {
                                        final phone = _phoneController.text.trim();
                                        ref.read(authControllerProvider.notifier).signInWithPhone(phone);
                                        _startResendTimer();
                                      },
                                child: Text(
                                  _resendCooldown > 0
                                      ? 'RESEND CODE IN ${_resendCooldown}S'
                                      : 'RESEND CODE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                    color: _resendCooldown > 0
                                        ? fg.withValues(alpha: 0.3)
                                        : fg.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: TextButton(
                                onPressed: () => setState(() {
                                  _otpSent = false;
                                  _resendCooldown = 0;
                                  _resendTimer?.cancel();
                                }),
                                child: Text(
                                  'CHANGE NUMBER',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                    color: fg.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: () => setState(() {
                                _isPhoneAuth = false;
                                _otpSent = false;
                              }),
                              child: Text(
                                'USE EMAIL / PASSWORD',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: fg.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            cursorColor: fg,
                            style: TextStyle(color: fg, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'EMAIL ADDRESS',
                              labelStyle: TextStyle(color: subtle, fontSize: 10, letterSpacing: 1.0),
                              floatingLabelStyle: TextStyle(color: fg, fontSize: 11, letterSpacing: 1.0),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: fg.withValues(alpha: 0.15)),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: fg),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!value.contains('@')) {
                                return 'Invalid email format';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: NoSusTheme.s16),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            cursorColor: fg,
                            style: TextStyle(color: fg, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'PASSWORD',
                              labelStyle: TextStyle(color: subtle, fontSize: 10, letterSpacing: 1.0),
                              floatingLabelStyle: TextStyle(color: fg, fontSize: 11, letterSpacing: 1.0),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: fg.withValues(alpha: 0.15)),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: fg),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 18,
                                  color: subtle,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                  return 'Password is required';
                              }
                              if (value.length < 6) {
                                return 'Must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          if (!_isSignUp) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: fg.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: NoSusTheme.s32),

                          // Action Button
                          GestureDetector(
                            onTap: authState.isLoading ? null : _submit,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: fg,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: authState.isLoading
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: isDark ? Colors.black : Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _isSignUp ? 'REGISTER' : 'ENTER WORKSPACE',
                                        style: TextStyle(
                                          color: isDark ? Colors.black : Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          const SizedBox(height: NoSusTheme.s24),
                          Row(
                            children: [
                              Expanded(child: Divider(color: fg.withValues(alpha: 0.1))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR CONTINUE WITH',
                                  style: TextStyle(
                                    color: subtle,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: fg.withValues(alpha: 0.1))),
                            ],
                          ),
                          const SizedBox(height: NoSusTheme.s24),

                          // OAuth Buttons Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildOAuthIconButton(
                                  icon: Icons.g_mobiledata,
                                  label: 'GOOGLE',
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    ref.read(authControllerProvider.notifier).signInWithGoogle();
                                  },
                                  fg: fg,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildOAuthIconButton(
                                  icon: Icons.code,
                                  label: 'GITHUB',
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    ref.read(authControllerProvider.notifier).signInWithGitHub();
                                  },
                                  fg: fg,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildOAuthIconButton(
                            icon: Icons.phone_android,
                            label: 'CONTINUE WITH PHONE',
                            onPressed: () {
                              setState(() {
                                _isPhoneAuth = true;
                              });
                            },
                            fg: fg,
                          ),

                        ],
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: NoSusTheme.s24),

                  // Switch between Sign In / Sign Up
                  Center(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: fg,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSignUp = !_isSignUp;
                        });
                      },
                      child: Text(
                        _isSignUp
                            ? 'ALREADY REGISTERED? SIGN IN'
                            : 'NEW TO WORKSPACE? SIGN UP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: fg.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 350.ms, duration: 300.ms),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    bool isSending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('RESET PASSWORD',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: emailCtrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address',
              hintText: 'you@example.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),
            FilledButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) return;
                      setDialogState(() => isSending = true);
                      // Same outcome shown regardless of success/failure — never
                      // reveal whether an account exists for this email.
                      try {
                        await ref.read(authRepositoryProvider).requestPasswordReset(email);
                      } catch (_) {
                        // intentionally swallowed, see above
                      }
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'If an account exists for that email, a reset link has been sent.',
                            ),
                          ),
                        );
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('SEND LINK', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOAuthIconButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color fg,
    bool enabled = true,
  }) {
    final displayFg = enabled ? fg : fg.withValues(alpha: 0.35);
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: displayFg.withValues(alpha: 0.15), width: 0.75),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: displayFg),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: displayFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
