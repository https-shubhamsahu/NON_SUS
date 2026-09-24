import 'dart:convert';
import 'dart:typed_data';

import '../../../core/crypto/nosus_seal.dart';

// Group drops wire format. Pure functions, no I/O.
//
//   group key box  = sealBox(device public, 'group-key:<group>:<epoch>', key32)
//   message body   = b64url(sealWithKey(groupKey, utf8(json), aad))
//     aad          = utf8('nosus-group/1:<group>:<epoch>:<message id>')
//     json         = {"v":1, "t":text?, "f":{"n","m","s","k"}?}
//   attachment     = sealWithKey(fileKey, bytes,
//                      utf8('nosus-group-file/1:<group>:<message id>'))
//
// The AAD binds a body to its group, epoch and row id, so the relay cannot
// move a ciphertext to another group, key epoch or message.

const int groupDropsMaxFileBytes = 25 * 1024 * 1024;
const int groupDropsMaxTextChars = 4000;
const int _maxNameChars = 255;

String groupKeyContext(String groupId, int epoch) => 'group-key:$groupId:$epoch';

Uint8List groupMessageAad(String groupId, int epoch, String messageId) =>
    Uint8List.fromList(utf8.encode('nosus-group/1:$groupId:$epoch:$messageId'));

Uint8List groupFileAad(String groupId, String messageId) =>
    Uint8List.fromList(utf8.encode('nosus-group-file/1:$groupId:$messageId'));

String groupAttachmentPath(String groupId, String messageId) => '$groupId/$messageId';

final RegExp _mime = RegExp(r'^[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]{0,63}/[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]{0,63}$');

class DropFileRef {
  final String name;
  final String mime;
  final int size;
  final Uint8List key;

  const DropFileRef({
    required this.name,
    required this.mime,
    required this.size,
    required this.key,
  });

  bool get isImage =>
      mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/webp' || mime == 'image/gif';

  Map<String, dynamic> toJson() => {'n': name, 'm': mime, 's': size, 'k': b64url(key)};
}

/// The decrypted content of one message.
class DropPayload {
  final String? text;
  final DropFileRef? file;

  const DropPayload({this.text, this.file});

  Map<String, dynamic> toJson() => {
        'v': 1,
        if (text != null) 't': text,
        if (file != null) 'f': file!.toJson(),
      };

  /// Strict: unknown keys, wrong types, oversize fields and a missing body
  /// all throw [FormatException]. Whatever a member's client sent is data.
  static DropPayload fromJson(Object? decoded) {
    if (decoded is! Map) throw const FormatException('payload');
    for (final key in decoded.keys) {
      if (key != 'v' && key != 't' && key != 'f') {
        throw const FormatException('payload key');
      }
    }
    if (decoded['v'] != 1) throw const FormatException('payload version');

    String? text;
    final t = decoded['t'];
    if (t != null) {
      if (t is! String || t.isEmpty || t.length > groupDropsMaxTextChars) {
        throw const FormatException('payload text');
      }
      text = t;
    }

    DropFileRef? file;
    final f = decoded['f'];
    if (f != null) {
      if (f is! Map || f.length != 4) throw const FormatException('payload file');
      final n = f['n'];
      final m = f['m'];
      final s = f['s'];
      final k = f['k'];
      if (n is! String || n.trim().isEmpty || n.length > _maxNameChars) {
        throw const FormatException('payload file name');
      }
      if (m is! String || !_mime.hasMatch(m)) {
        throw const FormatException('payload file type');
      }
      if (s is! int || s < 0 || s > groupDropsMaxFileBytes) {
        throw const FormatException('payload file size');
      }
      if (k is! String || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(k)) {
        throw const FormatException('payload file key');
      }
      final key = b64urlDecode(k);
      if (key.length != 32) throw const FormatException('payload file key');
      file = DropFileRef(name: n, mime: m, size: s, key: key);
    }

    if (text == null && file == null) throw const FormatException('payload empty');
    return DropPayload(text: text, file: file);
  }
}

String sealDropMessage({
  required Uint8List groupKey,
  required String groupId,
  required int epoch,
  required String messageId,
  required DropPayload payload,
}) {
  final plain = Uint8List.fromList(utf8.encode(jsonEncode(payload.toJson())));
  return b64url(sealWithKey(groupKey, plain, groupMessageAad(groupId, epoch, messageId)));
}

DropPayload openDropMessage({
  required Uint8List groupKey,
  required String groupId,
  required int epoch,
  required String messageId,
  required String body,
}) {
  final plain = openWithKey(
    groupKey,
    b64urlDecode(body),
    groupMessageAad(groupId, epoch, messageId),
  );
  return DropPayload.fromJson(jsonDecode(utf8.decode(plain)));
}

Uint8List sealDropFile({
  required Uint8List fileKey,
  required String groupId,
  required String messageId,
  required Uint8List bytes,
}) =>
    sealWithKey(fileKey, bytes, groupFileAad(groupId, messageId));

Uint8List openDropFile({
  required Uint8List fileKey,
  required String groupId,
  required String messageId,
  required Uint8List sealed,
}) =>
    openWithKey(fileKey, sealed, groupFileAad(groupId, messageId));

/// A file name safe to hand to the share sheet or Drive.
String safeDropFileName(String name) {
  final base = name.split(RegExp(r'[/\\]')).last.replaceAll(RegExp(r'[\x00-\x1f]'), '').trim();
  if (base.isEmpty || base == '.' || base == '..') return 'file';
  return base.length > 120 ? base.substring(base.length - 120) : base;
}
