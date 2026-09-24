import 'dart:convert';
import 'dart:typed_data';

import '../../../core/crypto/nosus_seal.dart';

// Drop wire format. Mirrors homepage/src/lib/dropApi.ts; the vectors in
// test/unit/drop_manifest_test.dart and homepage/scripts/drop-api.test.cjs
// lock the two together.
//
//   envelope = sealBox(device key, context "drop:<drop id>", utf8(manifest))
//   manifest = {"v":1,"k":<b64url file key>,"n":name,"m":mime,"s":size,
//               "from":sender,"note":note}
//   file     = sealWithKey(file key, bytes, aad "nosus-drop-file/1:<drop id>")

const int dropFromMax = 40;
const int dropNoteMax = 280;
const int dropNameMax = 200;
const int dropMaxPlainBytes = 25 * 1024 * 1024;

String dropContext(String dropId) => 'drop:$dropId';

Uint8List dropFileAad(String dropId) =>
    Uint8List.fromList(utf8.encode('nosus-drop-file/1:$dropId'));

class DropManifest {
  final Uint8List fileKey;
  final String name;
  final String mime;
  final int size;
  final String from;
  final String note;

  const DropManifest({
    required this.fileKey,
    required this.name,
    required this.mime,
    required this.size,
    required this.from,
    required this.note,
  });

  /// Throws [FormatException] for anything but a well-formed v1 manifest.
  /// Everything here was written by a stranger's browser.
  factory DropManifest.parse(Uint8List plain) {
    final Object? raw;
    try {
      raw = jsonDecode(utf8.decode(plain));
    } catch (_) {
      throw const FormatException('manifest');
    }
    if (raw is! Map) throw const FormatException('manifest');
    if (raw['v'] != 1) throw const FormatException('manifest version');
    final k = raw['k'];
    Uint8List key;
    try {
      key = k is String ? b64urlDecode(k) : Uint8List(0);
    } catch (_) {
      key = Uint8List(0);
    }
    if (key.length != 32) throw const FormatException('manifest key');
    final n = raw['n'];
    if (n is! String || n.isEmpty || n.runes.length > dropNameMax) {
      throw const FormatException('manifest name');
    }
    final m = raw['m'];
    if (m is! String || m.length > 100) throw const FormatException('manifest type');
    final s = raw['s'];
    if (s is! int || s < 0 || s > dropMaxPlainBytes * 2) {
      throw const FormatException('manifest size');
    }
    final from = raw['from'];
    if (from is! String || from.isEmpty || from.runes.length > dropFromMax) {
      throw const FormatException('manifest from');
    }
    final note = raw['note'] ?? '';
    if (note is! String || note.runes.length > dropNoteMax) {
      throw const FormatException('manifest note');
    }
    return DropManifest(fileKey: key, name: n, mime: m, size: s, from: from, note: note);
  }

  Map<String, Object> toJson() => {
        'v': 1,
        'k': b64url(fileKey),
        'n': name,
        'm': mime,
        's': size,
        'from': from,
        'note': note,
      };

  /// A file name safe to hand to Drive or the share sheet.
  String get safeName {
    final cleaned = name
        .replaceAll(RegExp(r'[\x00-\x1f\x7f/\\]'), '_')
        .replaceAll(RegExp(r'^\.+'), '')
        .trim();
    return cleaned.isEmpty ? 'file' : cleaned;
  }

  /// The sender's type string, only if it is a plain type/subtype. It goes
  /// into a multipart header, so anything else becomes octet-stream.
  String get safeMime {
    final lower = mime.toLowerCase().trim();
    return RegExp(r'^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$').hasMatch(lower)
        ? lower
        : 'application/octet-stream';
  }

  bool get looksLikeImage => const {
        'image/jpeg',
        'image/png',
        'image/webp',
        'image/gif',
      }.contains(safeMime);
}

/// Opens the file ciphertext of a drop with the key from its manifest.
/// Top-level so it can run in an isolate via compute().
Uint8List openDropFile(({Uint8List key, String dropId, Uint8List box, int size}) args) {
  final plain = openWithKey(args.key, args.box, dropFileAad(args.dropId));
  if (plain.length != args.size) throw const FormatException('size mismatch');
  return plain;
}

/// NO SUS address handles. Same rules as address_handle_valid() in
/// supabase/migrations/20260924110000_nosus_drop.sql.
class AddressHandle {
  AddressHandle._();

  static const reserved = {
    'app', 'www', 'api', 'go', 'to', 'admin', 'support', 'help', 'mail',
    'nosus', 'no-sus', 'root', 'static', 'assets', 'burn', 'redeem', 'join',
    'status', 'blog', 'docs', 'login', 'signup', 'settings',
  };

  static final _shape = RegExp(r'^[a-z0-9](?:[a-z0-9-]{2,18}[a-z0-9])$');

  static String normalize(String raw) =>
      raw.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');

  static bool isValid(String handle) => problem(handle) == null;

  /// Null when [handle] (already normalized) can be claimed; otherwise a
  /// short reason for the person typing it.
  static String? problem(String handle) {
    if (handle.length < 4) return 'At least 4 characters.';
    if (handle.length > 20) return 'At most 20 characters.';
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(handle)) {
      return 'Use a–z, 0–9, and hyphens.';
    }
    if (handle.startsWith('-') || handle.endsWith('-')) {
      return 'Can’t start or end with a hyphen.';
    }
    if (handle.contains('--')) return 'No double hyphens.';
    if (!_shape.hasMatch(handle)) return 'Use a–z, 0–9, and hyphens.';
    if (reserved.contains(handle)) return 'That one is reserved.';
    return null;
  }

  static Uri link(String handle) =>
      Uri.https('nosus.foo', '/to', {'h': handle});

  static String shortLink(String handle) => 'nosus.foo/to?h=$handle';

  static String subdomain(String handle) => '$handle.nosus.foo';
}
