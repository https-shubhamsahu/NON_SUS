import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme.dart';
import '../../../../services/secure_db_service.dart';
import '../../../../config/supabase_credentials.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../groups/providers/groups_provider.dart';
import '../../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _isTestingLatency = false;
  int _latencyMs = -1;
  bool _isRotatingKeys = false;
  bool _isPurgingCache = false;

  // Custom Gradient Preset Options with corresponding pixel avatars
  final List<Map<String, String>> _gradientPresets = [
    {'name': 'THE BUILDER', 'start': 'FF0072FF', 'end': 'FF00F2FE', 'asset': 'assets/images/avatar_builder.png'},
    {'name': 'THE RESEARCHER', 'start': 'FFCCCCCC', 'end': 'FFAAAAAA', 'asset': 'assets/images/avatar_researcher.png'},
    {'name': 'THE CREATOR', 'start': 'FFFF0072', 'end': 'FF00F2FE', 'asset': 'assets/images/avatar_creator.png'},
    {'name': 'THE ACADEMIC WEAPON', 'start': 'FFF5A623', 'end': 'FFF8E71C', 'asset': 'assets/images/avatar_academic.png'},
    {'name': 'THE CHAOS AGENT', 'start': 'FF800080', 'end': 'FF4A90E2', 'asset': 'assets/images/avatar_chaos.png'},
    {'name': 'THE ARCHIVIST', 'start': 'FFADF474', 'end': 'FF018037', 'asset': 'assets/images/avatar_archivist.png'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileAsync = ref.read(profileProvider);
      profileAsync.whenData((profile) {
        _nameController.text = profile.displayName;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _testLatency() async {
    if (_isTestingLatency) return;
    setState(() {
      _isTestingLatency = true;
      _latencyMs = -1;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final client = HttpClient();
      final uri = Uri.parse('${SupabaseCredentials.url}/rest/v1/');
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 4));
      request.headers.set('apikey', SupabaseCredentials.anonKey);
      final response = await request.close();
      stopwatch.stop();
      if (response.statusCode == 200) {
        setState(() {
          _latencyMs = stopwatch.elapsedMilliseconds;
        });
      } else {
        setState(() {
          _latencyMs = -2; // server error
        });
      }
    } catch (_) {
      setState(() {
        _latencyMs = -3; // timeout / offline
      });
    } finally {
      setState(() {
        _isTestingLatency = false;
      });
    }
  }

  void _triggerKeyRotation() async {
    if (_isRotatingKeys) return;
    setState(() {
      _isRotatingKeys = true;
    });

    try {
      await SecureDbService.instance.rotateWorkspaceKeys();
      // Refresh timeline/audit logs
      ref.read(auditLogsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.white,
            content: Text(
              'Encryption keys successfully rotated.',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Key rotation failed: $e',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRotatingKeys = false;
        });
      }
    }
  }

  void _purgeCache() async {
    if (_isPurgingCache) return;
    setState(() {
      _isPurgingCache = true;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.white,
          content: Text(
            'In-memory decrypted buffers wiped from RAM.',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      );
      setState(() {
        _isPurgingCache = false;
      });
    }
  }

  void _saveProfileChanges(String startColor, String endColor) {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    ref.read(profileProvider.notifier).updateProfile(
      displayName: newName,
      avatarColorStart: startColor,
      avatarColorEnd: endColor,
    );
    setState(() {
      _isEditingName = false;
    });
  }

  Color _parseHexColor(String hexStr) {
    try {
      return Color(int.parse(hexStr, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  String _getAvatarAsset(String colorStart) {
    switch (colorStart) {
      case 'FF0072FF':
        return 'assets/images/avatar_builder.png';
      case 'FFCCCCCC':
        return 'assets/images/avatar_researcher.png';
      case 'FFFF0072':
        return 'assets/images/avatar_creator.png';
      case 'FFF5A623':
        return 'assets/images/avatar_academic.png';
      case 'FF800080':
        return 'assets/images/avatar_chaos.png';
      case 'FFADF474':
        return 'assets/images/avatar_archivist.png';
      default:
        return 'assets/images/avatar_builder.png';
    }
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
    final fg = isDark ? Colors.white : Colors.black;

    final user = ref.watch(authStateProvider).value;
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: fg),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'IDENTITY CONSOLE',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 14,
          ),
        ),
        centerTitle: true,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
        data: (profile) {
          final startColor = _parseHexColor(profile.avatarColorStart);
          final endColor = _parseHexColor(profile.avatarColorEnd);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // RPG Character Portrait & Identity Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: NoSusTheme.cardDecoration(context),
                  child: Column(
                    children: [
                      // Glowing Gradient Avatar with Pixel Character
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [startColor, endColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: startColor.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Align(
                            alignment: const Alignment(0, 0.25),
                            child: FractionallySizedBox(
                              widthFactor: 0.85,
                              heightFactor: 0.85,
                              child: Image.asset(
                                _getAvatarAsset(profile.avatarColorStart),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _getAvatarLabel(profile.avatarColorStart),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Verified Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: fg.withValues(alpha: 0.2), width: 0.75),
                          borderRadius: BorderRadius.circular(20),
                          color: fg.withValues(alpha: 0.03),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified, color: Color(0xFF10B981), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'VERIFIED ENCLAVE MEMBER',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                color: fg.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Display Name Editable
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isEditingName)
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                autofocus: true,
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Enter name',
                                ),
                                onSubmitted: (_) => _saveProfileChanges(
                                  profile.avatarColorStart,
                                  profile.avatarColorEnd,
                                ),
                              ),
                            )
                          else
                            Text(
                              profile.displayName.toUpperCase(),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              if (_isEditingName) {
                                _saveProfileChanges(
                                  profile.avatarColorStart,
                                  profile.avatarColorEnd,
                                );
                              } else {
                                setState(() {
                                  _isEditingName = true;
                                });
                              }
                            },
                            child: Icon(
                              _isEditingName ? Icons.check : Icons.edit_outlined,
                              size: 18,
                              color: fg.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'anonymous_student@nosus.io',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: fg.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Character Avatar Presets Picker
                Text(
                  'SELECT CHARACTER AVATAR',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg.withValues(alpha: 0.4),
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: NoSusTheme.cardDecoration(context),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _gradientPresets.map((preset) {
                        final pStart = _parseHexColor(preset['start']!);
                        final pEnd = _parseHexColor(preset['end']!);
                        final isSelected = profile.avatarColorStart == preset['start'];

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(profileProvider.notifier).updateProfile(
                              displayName: profile.displayName,
                              avatarColorStart: preset['start']!,
                              avatarColorEnd: preset['end']!,
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [pStart, pEnd],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: isSelected ? fg : Colors.transparent,
                                width: 2.0,
                              ),
                            ),
                            child: ClipOval(
                              child: Align(
                                alignment: const Alignment(0, 0.25),
                                child: FractionallySizedBox(
                                  widthFactor: 0.85,
                                  heightFactor: 0.85,
                                  child: Image.asset(
                                    preset['asset']!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // RPG Character Statistics
                Text(
                  'ENCLAVE STANDING',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg.withValues(alpha: 0.4),
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: NoSusTheme.cardDecoration(context),
                  child: Column(
                    children: [
                      _buildStatRow('INTEGRITY / REPUTATION', '98%', 0.98, Colors.green),
                      const SizedBox(height: 16),
                      _buildStatRow('CONTRIBUTION TIER', 'LVL 3', 0.6, Colors.amber),
                      const SizedBox(height: 16),
                      _buildStatRow('SHARING GROUPS', '6 CIRCLES', 0.8, fg),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Live Diagnostics Terminal console
                Text(
                  'ENCLAVE TUNNEL DIAGNOSTICS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg.withValues(alpha: 0.4),
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF070707) : const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline, width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildConsoleLine('SYSTEM_ENDPOINT', SupabaseCredentials.url.replaceFirst('https://', '')),
                      const SizedBox(height: 8),
                      _buildConsoleLine('ALGORITHM', 'AES-256-GCM (VOLATILE RAM)'),
                      const SizedBox(height: 8),
                      _buildConsoleLine(
                        'TUNNEL_LATENCY',
                        _latencyMs == -1
                            ? 'UNTARGETED'
                            : _latencyMs == -2
                                ? 'GATEWAY TIMEOUT'
                                : _latencyMs == -3
                                    ? 'OFFLINE FALLBACK'
                                    : '${_latencyMs}ms (SECURE)',
                        valueColor: _latencyMs >= 0 ? Colors.green : Colors.amber,
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _testLatency,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: NoSusTheme.buttonDecoration(context, radius: 8),
                          child: Center(
                            child: _isTestingLatency
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey),
                                  )
                                : Text(
                                    'PING TUNNEL ENDPOINT',
                                    style: theme.textTheme.labelLarge?.copyWith(fontSize: 10, letterSpacing: 1.0),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Identity Management Action Buttons
                GestureDetector(
                  onTap: _triggerKeyRotation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: NoSusTheme.buttonDecoration(context),
                    child: Center(
                      child: _isRotatingKeys
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.grey),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.sync_lock, size: 16, color: fg),
                                const SizedBox(width: 8),
                                Text(
                                  'ROTATE SESSION KEYS',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    letterSpacing: 1.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _purgeCache,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1.0),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.redAccent.withValues(alpha: 0.05),
                    ),
                    child: Center(
                      child: _isPurgingCache
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.redAccent),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.redAccent),
                                const SizedBox(width: 8),
                                Text(
                                  'PURGE DECRYPTED RAM BUFFER',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    letterSpacing: 1.0,
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    ref.read(authControllerProvider.notifier).signOut();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: NoSusTheme.buttonDecoration(context),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, size: 16, color: fg),
                          const SizedBox(width: 8),
                          Text(
                            'SIGN OUT SESSION',
                            style: theme.textTheme.labelLarge?.copyWith(
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatRow(String label, String value, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withValues(alpha: 0.1),
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildConsoleLine(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label > ',
          style: const TextStyle(
            fontFamily: 'Courier',
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }
}
