import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/go_config.dart';
import '../../core/crypto/nosus_seal.dart';
import '../config/presentation/providers/config_provider.dart';
import 'drive_saved_store.dart';
import 'go_link.dart';
import 'go_session.dart';
import 'go_transit.dart';
import 'go_widgets.dart';
import 'google_drive_access.dart';

/// Phone side of a borrowed computer. The Google token never leaves here.
class GoApproveScreen extends ConsumerStatefulWidget {
  final GoPairing pairing;

  const GoApproveScreen({super.key, required this.pairing});

  @override
  ConsumerState<GoApproveScreen> createState() => _GoApproveScreenState();
}

enum _Step { connecting, match, review, live, ended, blocked }

class _GoApproveScreenState extends ConsumerState<GoApproveScreen> {
  final _link = GoLink();
  final _client = http.Client();
  late final DriveSavedStore _store = DriveSavedStore(
    client: _client,
    token: () => GoogleDriveAccess.instance.accessToken(),
  );
  late final GoMachine _machine;

  _Step _step = _Step.connecting;
  String _message = 'Connecting…';
  String _device = 'Computer (unverified)';
  List<int> _choices = const [];
  int _wrong = 0;
  String? _email;
  List<SavedItem> _items = const [];
  final Set<String> _picked = {};
  bool _whole = false;
  bool _allowSend = false;
  int _minutes = 15;
  int _maxMinutes = 60;
  int _idleSec = 600;
  int _fileMax = 25 * 1024 * 1024;
  GoGrant? _grant;
  Timer? _retry;
  Timer? _expiry;
  Map<String, dynamic>? _grantWire;
  bool _ended = false;
  bool _lockMissing = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final phone = generateGoKeyPair();
    _machine = GoMachine.phone(
      sidB64: widget.pairing.sid,
      deskPublic: widget.pairing.deskPublic,
      phonePrivate: phone.privateKey,
      phonePublic: phone.publicKey,
    );
    unawaited(_start());
  }

  @override
  void dispose() {
    _retry?.cancel();
    _expiry?.cancel();
    if (!_ended) unawaited(_finish(send: true));
    _client.close();
    super.dispose();
  }

  Future<void> _start() async {
    final user = Supabase.instance.client.auth.currentUser;
    final enabled = user != null &&
        ref.read(featureFlagProvider('nosus_address_enabled'));
    if (!enabled) {
      setState(() {
        _step = _Step.blocked;
        _message = user == null
            ? 'Sign in to NO SUS, then scan again.'
            : 'Saved isn’t turned on for this account.';
      });
      return;
    }
    final config = ref.read(remoteConfigServiceProvider);
    _minutes = config.getConfigValue<int>('go_session_default_min', 15);
    _maxMinutes = config.getConfigValue<int>('go_session_max_min', 60);
    _idleSec = config.getConfigValue<int>('go_idle_min', 10) * 60;
    _fileMax = config.getConfigValue<int>('go_file_max_bytes', _fileMax);
    if (_minutes > _maxMinutes) _minutes = _maxMinutes;
    try {
      await Supabase.instance.client.rpc('go_session_claim', params: {
        'p_sid': widget.pairing.sid,
        'p_minutes': _minutes,
      });
      await _link.join(widget.pairing.sid, _onWire);
      await _link.send(_machine.helloWire());
      _email = await GoogleDriveAccess.instance.savedEmail();
      final real = _machine.matchCode ?? 0;
      if (!mounted) return;
      setState(() {
        _step = _Step.match;
        _choices = matchChoices(real, Random.secure());
        _message = 'Match the code on the computer in front of you.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.blocked;
        _message = 'This code expired, or it isn’t yours. Refresh the computer and scan again.';
      });
    }
  }

  Future<void> _onWire(Map<String, dynamic> wire) async {
    final incoming = _machine.receive(wire);
    if (_machine.aborted) {
      await _finish(send: false);
      if (mounted) {
        setState(() {
          _step = _Step.blocked;
          _message = 'This session stopped. Refresh the computer and scan again.';
        });
      }
      return;
    }
    for (final again in incoming.resend) {
      await _link.send(again);
    }
    final event = incoming.event;
    if (event == null) return;
    final kind = event['t'];
    if (kind == 'welcome') {
      final dev = event['dev'];
      if (dev is String && dev.isNotEmpty && mounted) {
        setState(() => _device = '$dev (unverified)');
      }
    } else if (kind == 'ack') {
      _retry?.cancel();
      _grantWire = null;
      _armExpiry();
      if (mounted) setState(() => _step = _Step.live);
      await _sendList();
    } else if (kind == 'want') {
      final id = event['id'];
      if (id is String) await _pushFile(id);
    } else if (kind == 'msg') {
      await _takeMessage(event);
    } else if (kind == 'item') {
      await _takeFile(event);
    } else if (kind == 'end') {
      await _finish(send: false);
      if (mounted) {
        setState(() {
          _step = _Step.ended;
          _message = 'Session ended. This computer can’t request anything else.';
        });
      }
    }
  }

  Future<void> _sendList() async {
    final grant = _grant;
    if (grant == null || _machine.keys == null) return;
    // ponytail: one broadcast, first 50 items, message text clipped.
    // A changes feed if Saved outgrows a single payload.
    final visible = _items.where((item) => item.nosusId.isNotEmpty && (grant.whole || grant.ids.contains(item.nosusId))).take(50);
    final payload = [
      for (final item in visible)
        {
          'id': item.nosusId,
          'name': item.name,
          'mime': item.mime,
          'size': item.size,
          'src': item.src,
          if (item.isMessage && item.text != null)
            'text': item.text!.length > 500 ? item.text!.substring(0, 500) : item.text,
        },
    ];
    await _link.send(_machine.sendEvent({'t': 'list', 'items': payload}));
  }

  void _armExpiry() {
    final grant = _grant;
    if (grant == null) return;
    final left = grant.exp - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _expiry?.cancel();
    _expiry = Timer(Duration(seconds: left > 0 ? left : 1), () {
      unawaited(_finish(send: true));
    });
  }

  Future<void> _review() async {
    setState(() {
      _step = _Step.review;
      _message = 'Choose what this computer can receive.';
    });
    if (!GoConfig.isConfigured) return;
    try {
      final folders = await _store.ensureFolders();
      final items = await _store.listTimeline(folders);
      if (mounted) setState(() => _items = items);
    } on DriveFailure catch (e) {
      if (mounted) setState(() => _message = e.message);
    }
  }

  Future<void> _approve({bool skipLock = false}) async {
    if (_sending) return;
    if (!_whole && _picked.isEmpty) {
      setState(() => _message = 'Pick at least one item, or choose the whole Saved chat.');
      return;
    }
    if (!skipLock) {
      final biometric = await _deviceLock();
      if (!biometric) {
        if (mounted) {
          setState(() {
            _lockMissing = true;
            _message = 'This device has no lock, or it was cancelled. Approve only if this is the computer in front of you.';
          });
        }
        return;
      }
    }
    _sending = true;
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + _minutes * 60;
    final event = {
      't': 'grant',
      'scope': _whole ? 'all' : 'items',
      'ids': _picked.toList(),
      'mode': _allowSend ? 'both' : 'receive',
      'exp': exp,
      'idle': _idleSec,
    };
    final grant = parseGrant(event);
    if (grant == null) return;
    try {
      await Supabase.instance.client.rpc('go_session_extend', params: {
        'p_sid': widget.pairing.sid,
        'p_minutes': _minutes,
      });
    } catch (_) {
      // The claim already set a length. Extend is best-effort.
    }
    _grant = grant;
    final wire = _machine.sendEvent(event);
    _grantWire = wire;
    await _link.send(wire);
    var tries = 0;
    _retry?.cancel();
    _retry = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_grantWire == null || tries++ >= 14) {
        timer.cancel();
        if (mounted && _step != _Step.live) {
          setState(() => _message = 'The computer didn’t answer. Check that the code is still on screen.');
        }
        return;
      }
      await _link.send(_grantWire!);
    });
    if (mounted) setState(() => _message = 'Waiting for the computer…');
  }

  Future<bool> _deviceLock() async {
    try {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      if (!supported) return false;
      return auth.authenticate(
        localizedReason: 'Approve this computer',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _none() async {
    await _finish(send: true);
    if (mounted) {
      setState(() {
        _step = _Step.ended;
        _message = 'Nothing was shared.';
      });
    }
  }

  void _wrongCode() {
    _wrong++;
    if (_wrong >= 2) {
      unawaited(_none());
      return;
    }
    setState(() => _message = 'That wasn’t the code on the computer.');
  }

  Future<void> _pushFile(String id) async {
    final grant = _grant;
    if (grant == null || !grant.canPull(id)) return;
    SavedItem? item;
    for (final candidate in _items) {
      if (candidate.nosusId == id) item = candidate;
    }
    if (item == null || item.isMessage) return;
    if (item.size > _fileMax) return;
    try {
      final bytes = await _store.download(item.driveId);
      final transit = await GoTransit.upload(bytes);
      final wire = _machine.sendEvent({
        't': 'item',
        'id': id,
        'fileId': transit.fileId,
        'key': transit.key,
        'nonce': transit.nonce,
        'name': item.name,
        'mime': item.mime,
        'size': bytes.length,
      });
      final seq = wire['seq'];
      if (seq is int) _machine.remember(seq, wire);
      await _link.send(wire);
    } catch (_) {}
  }

  Future<void> _takeMessage(Map<String, dynamic> event) async {
    final grant = _grant;
    if (grant == null || !grant.allowsComputerSend) return;
    final text = event['text'];
    final id = event['id'];
    if (text is! String || id is! String) return;
    try {
      final folders = await _store.ensureFolders();
      await _store.putMessage(
        messagesFolderId: folders.messages,
        nosusId: id,
        text: text,
        src: 'computer',
      );
      final wire = _machine.sendEvent({'t': 'saw', 'id': id});
      await _link.send(wire);
    } on DriveFailure {
      // The computer keeps "Couldn't save" until a retry, which dedupes on id.
    }
  }

  Future<void> _takeFile(Map<String, dynamic> event) async {
    final grant = _grant;
    if (grant == null || !grant.allowsComputerSend) return;
    final id = event['id'];
    final fileId = event['fileId'];
    final key = event['key'];
    final nonce = event['nonce'];
    final name = event['name'];
    final mime = event['mime'];
    if (id is! String || fileId is! String || key is! String || nonce is! String) return;
    try {
      final bytes = await GoTransit.download(fileId: fileId, key: key, nonce: nonce);
      if (bytes.length > _fileMax) return;
      final folders = await _store.ensureFolders();
      await _store.putFile(
        savedFolderId: folders.saved,
        nosusId: id,
        name: name is String ? name : 'file',
        mime: mime is String ? mime : 'application/octet-stream',
        bytes: bytes,
        src: 'computer',
      );
      await _link.send(_machine.sendEvent({'t': 'saw', 'id': id}));
    } catch (_) {}
  }

  Future<void> _finish({required bool send}) async {
    if (_ended) return;
    _ended = true;
    _retry?.cancel();
    _expiry?.cancel();
    if (send && _machine.keys != null && !_machine.aborted) {
      try {
        await _link.send(_machine.sendEvent({'t': 'end'}));
      } catch (_) {}
    }
    try {
      await Supabase.instance.client.rpc('go_session_end', params: {
        'p_sid': widget.pairing.sid,
      });
    } catch (_) {}
    await _link.leave();
  }

  Future<void> _endNow() async {
    await _finish(send: true);
    if (mounted) {
      setState(() {
        _step = _Step.ended;
        _message = 'Session ended. Anything already sent may still be on that computer.';
      });
    }
  }

  String get _scopeLabel {
    final count = _whole ? 'Whole Saved chat' : '${_picked.length} items';
    final send = _allowSend ? 'receive and send' : 'receive only';
    return '$count · $send';
  }

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: const Text('Open on computer')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(_message, style: TextStyle(color: fg, fontSize: 16, height: 1.4)),
          const SizedBox(height: 8),
          Text(_device, style: TextStyle(color: fg.withValues(alpha: 0.7))),
          const SizedBox(height: 24),
          if (_step == _Step.match)
            MatchChoices(
              choices: _choices,
              onPick: (code) {
                if (code == _machine.matchCode) {
                  unawaited(_review());
                } else {
                  _wrongCode();
                }
              },
              onNone: () => unawaited(_none()),
            ),
          if (_step == _Step.review) ...[
            Text(_email ?? 'Google account not connected', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_email == null)
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () async {
                    final email = await GoogleDriveAccess.instance.connect();
                    if (mounted) setState(() => _email = email);
                    await _review();
                  },
                  child: const Text('Connect Google Drive'),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Whole Saved chat'),
              subtitle: const Text('Off means only the items you tick.'),
              value: _whole,
              onChanged: (v) => setState(() => _whole = v),
            ),
            if (!_whole)
              for (final item in _items.where((it) => it.nosusId.isNotEmpty))
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _picked.contains(item.nosusId),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _picked.add(item.nosusId);
                    } else {
                      _picked.remove(item.nosusId);
                    }
                  }),
                  title: Text(item.isMessage ? (item.text ?? item.name) : item.name),
                ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final minutes in [5, 15, 60])
                  if (minutes <= _maxMinutes)
                    ChoiceChip(
                      label: Text('$minutes min'),
                      selected: _minutes == minutes,
                      onSelected: (_) => setState(() => _minutes = minutes),
                    ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Let this computer send into Saved'),
              value: _allowSend,
              onChanged: (v) => setState(() => _allowSend = v),
            ),
            const SizedBox(height: 8),
            Text(
              'This computer will only receive what you approve. Anything it downloads or prints may stay there. Your Google password is not typed on it.',
              style: TextStyle(color: fg.withValues(alpha: 0.8), height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () => _approve(),
                child: const Text('Approve with device lock'),
              ),
            ),
            if (_lockMissing) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => _approve(skipLock: true),
                  child: const Text('Approve without device lock'),
                ),
              ),
            ],
          ],
          if (_step == _Step.live) ...[
            Text(_scopeLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('$_minutes min from approval. End session stops anything further.'),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton(
                onPressed: _endNow,
                child: const Text('End session'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
