import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/crypto/device_keys.dart';
import '../../../core/crypto/nosus_seal.dart';
import '../../../theme.dart';
import '../../config/presentation/providers/config_provider.dart';
import 'drop_manifest.dart';
import 'drop_repository.dart';
import 'inbox_screen.dart';

/// "Your address": the handle people send to, and the door that decides
/// whether anything can arrive. Closed by default.
class AddressScreen extends ConsumerStatefulWidget {
  const AddressScreen({super.key});

  @override
  ConsumerState<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends ConsumerState<AddressScreen> {
  final _repo = DropRepository();
  final _handleField = TextEditingController();
  final _codeField = TextEditingController();

  String? _handle;
  bool _editing = false;
  String? _handleError;
  DoorStatus _door = const DoorStatus();
  DeviceKeyKind? _kind;
  String? _keyProblem;
  String? _check;
  int _blocks = 0;
  bool _busy = true;
  String? _banner;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    // Re-render so "open until" flips to closed on time.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _handleField.dispose();
    _codeField.dispose();
    super.dispose();
  }

  Future<String?> _registerKey() async {
    try {
      final id = await DeviceKeys.instance.ensureRegistered();
      _keyProblem = id == null ? 'Sign in to set up this phone’s key.' : null;
      return id;
    } catch (_) {
      _keyProblem = 'This phone’s key couldn’t be set up.';
      return null;
    }
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    await _registerKey();
    try {
      _kind = await DeviceKeys.instance.kind();
    } catch (_) {
      _kind = null;
    }
    try {
      final results = await Future.wait([
        _repo.myHandle(),
        _repo.door(),
        _repo.liveDeviceKeys(),
        _repo.blockCount(),
      ]);
      final keys = results[2] as List<Uint8List>;
      if (!mounted) return;
      setState(() {
        _handle = results[0] as String?;
        _editing = _handle == null;
        _door = results[1] as DoorStatus;
        _check = keys.isEmpty ? null : safetyCode(keys);
        _blocks = results[3] as int;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _banner = 'Couldn’t load your address. Pull to try again.';
      });
    }
  }

  Future<void> _claim() async {
    final raw = _handleField.text;
    final problem = AddressHandle.problem(AddressHandle.normalize(raw));
    if (problem != null) {
      setState(() => _handleError = problem);
      return;
    }
    setState(() {
      _handleError = null;
      _busy = true;
    });
    try {
      final handle = await _repo.claimHandle(raw);
      if (!mounted) return;
      setState(() {
        _handle = handle;
        _editing = false;
        _busy = false;
      });
    } on DropFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _handleError = e.message;
        _busy = false;
      });
    }
  }

  Future<void> _setDoor(int minutes) async {
    final code = _codeField.text.trim();
    if (minutes > 0) {
      if (code.isNotEmpty && !RegExp(r'^[0-9]{4,8}$').hasMatch(code)) {
        setState(() => _banner = 'A door code is 4 to 8 digits.');
        return;
      }
      // A door with no key on this phone would take files nobody can open.
      final keyId = await _registerKey();
      if (keyId == null) {
        setState(() => _banner = _keyProblem ?? 'This phone’s key isn’t set up, so the door stays closed.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _banner = null;
    });
    try {
      final door = await _repo.setDoor(minutes, code: minutes > 0 ? code : null);
      final keys = await _repo.liveDeviceKeys();
      if (!mounted) return;
      setState(() {
        _door = door;
        _check = keys.isEmpty ? null : safetyCode(keys);
        _busy = false;
      });
    } on DropFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _banner = e.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _banner = 'Couldn’t change the door. Try again.';
        _busy = false;
      });
    }
  }

  String _linkText(String handle) {
    final live = ref.read(remoteConfigServiceProvider).getConfigValue<bool>('address_subdomain_live', false);
    return live ? 'https://${AddressHandle.subdomain(handle)}' : AddressHandle.link(handle).toString();
  }

  String _until(DateTime t) {
    final local = t.toLocal();
    final left = local.difference(DateTime.now());
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (left.inMinutes < 60) return 'Open for ${left.inMinutes + 1} more min';
    return 'Open until $hh:$mm';
  }

  String _keyText(DeviceKeyKind? kind) {
    switch (kind) {
      case DeviceKeyKind.keystore:
        return 'This phone’s private key was made inside Android Keystore and can’t be copied out of it.';
      case DeviceKeyKind.software:
        return 'This Android version can’t do this inside Keystore, so the private key is a software key, '
            'stored encrypted with a Keystore key.';
      case DeviceKeyKind.web:
        return 'In a browser the private key sits in this browser’s storage. A phone is safer.';
      case null:
        return 'Key status unknown.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    final subtle = fg.withValues(alpha: 0.62);
    final handle = _handle;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your address'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InboxScreen()),
            ),
            icon: const Icon(Icons.inbox_outlined),
            label: const Text('Inbox'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Share your NO SUS address, not your phone number. People can send you a file '
              'without an account while your door is open. Nothing reaches your Drive until you accept it.',
              style: TextStyle(color: fg, fontSize: 15, height: 1.4),
            ),
            if (_banner != null) ...[
              const SizedBox(height: NoSusTheme.s12),
              Text(_banner!, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
            ],
            if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),

            // ── Address ────────────────────────────────────────────────
            const _Section(title: 'Address'),
            if (handle != null && !_editing) ...[
              SelectableText(_linkText(handle), style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: NoSusTheme.s8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _linkText(handle)));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied')));
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(text: 'Send me a file: ${_linkText(handle)}'),
                    ),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _editing = true;
                      _handleField.text = handle;
                    }),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ] else ...[
              TextField(
                controller: _handleField,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 20,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-@]'))],
                decoration: InputDecoration(
                  labelText: 'Pick an address',
                  prefixText: 'nosus.foo/to?h=',
                  errorText: _handleError,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _claim(),
              ),
              Text(
                'If you change it later, the old one stays yours for 30 days so nobody else picks it up.',
                style: TextStyle(color: subtle, fontSize: 13),
              ),
              const SizedBox(height: NoSusTheme.s8),
              Row(
                children: [
                  FilledButton(onPressed: _busy ? null : _claim, child: const Text('Save address')),
                  if (handle != null) ...[
                    const SizedBox(width: 8),
                    TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
                  ],
                ],
              ),
            ],

            // ── Door ───────────────────────────────────────────────────
            const _Section(title: 'Door'),
            Text(
              _door.isOpen
                  ? '${_until(_door.openUntil!)}${_door.hasCode ? ' · door code on' : ''}'
                  : 'Closed. Nobody can send you anything.',
              style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: NoSusTheme.s8),
            TextField(
              controller: _codeField,
              keyboardType: TextInputType.number,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Door code (optional, 4–8 digits)',
                helperText: 'Set before opening. Senders must type it. 20 wrong tries close the door.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: NoSusTheme.s8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy || handle == null ? null : () => _setDoor(0),
                  child: const Text('Close'),
                ),
                for (final (label, minutes) in const [('Open 10 min', 10), ('Open 1 h', 60), ('Open 24 h', 1440)])
                  FilledButton.tonal(
                    onPressed: _busy || handle == null ? null : () => _setDoor(minutes),
                    child: Text(label),
                  ),
              ],
            ),
            if (handle == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Pick an address first.', style: TextStyle(color: subtle)),
              ),

            // ── What's protected ───────────────────────────────────────
            const _Section(title: 'What our server sees'),
            Text(
              'The sealed file, its size, when it arrived, and a hashed form of the sender’s network address '
              '(for rate limits and blocks). The file name, the sender’s name, and their note are sealed to your '
              'devices. Unaccepted files are deleted after 24 hours.',
              style: TextStyle(color: fg, fontSize: 14, height: 1.4),
            ),
            if (_check != null) ...[
              const SizedBox(height: NoSusTheme.s12),
              Text('Door check', style: TextStyle(color: subtle, fontSize: 13)),
              SelectableText(
                _check!,
                style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 2),
              ),
              Text(
                'A sender sees this code on your page. If theirs is different, the keys they got are not yours. '
                'It changes when you add or remove a device.',
                style: TextStyle(color: subtle, fontSize: 13, height: 1.4),
              ),
            ],

            // ── This phone ─────────────────────────────────────────────
            const _Section(title: 'This phone'),
            Text(_keyProblem ?? _keyText(_kind), style: TextStyle(color: fg, fontSize: 14, height: 1.4)),

            if (_blocks > 0) ...[
              const _Section(title: 'Blocked'),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$_blocks blocked ${_blocks == 1 ? 'network' : 'networks'}. Blocks go by network, '
                      'so they’re a speed bump, not a guarantee.',
                      style: TextStyle(color: fg, fontSize: 14, height: 1.4),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _repo.clearBlocks();
                      if (mounted) setState(() => _blocks = 0);
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: NoSusTheme.s24, bottom: NoSusTheme.s8),
      child: Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
