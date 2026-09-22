import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// The user's own Drive, scope drive.file. Only folders and files this app
/// created are visible. Text is one small file per message.
///
/// ponytail: each refresh downloads every message body. Move to a stored
/// changes token if a Saved folder gets large enough that this is slow.
class DriveFailure implements Exception {
  final String code;
  final String message;
  const DriveFailure(this.code, this.message);

  @override
  String toString() => message;
}

class SavedItem {
  final String driveId;
  final String nosusId;
  final String name;
  final String mime;
  final int size;
  final String src;
  final DateTime created;
  final bool isMessage;
  final String? text;

  const SavedItem({
    required this.driveId,
    required this.nosusId,
    required this.name,
    required this.mime,
    required this.size,
    required this.src,
    required this.created,
    required this.isMessage,
    this.text,
  });

  SavedItem withText(String? value) => SavedItem(
        driveId: driveId,
        nosusId: nosusId,
        name: name,
        mime: mime,
        size: size,
        src: src,
        created: created,
        isMessage: isMessage,
        text: value,
      );
}

class DriveFolders {
  final String root;
  final String saved;
  final String messages;
  const DriveFolders({
    required this.root,
    required this.saved,
    required this.messages,
  });
}

class DriveSavedStore {
  DriveSavedStore({required this.client, required this.token});

  final http.Client client;
  final Future<String> Function() token;

  static const markerRoot = 'nosus_root';
  static const markerSaved = 'nosus_saved';
  static const markerMessages = 'nosus_messages';

  Future<DriveFolders> ensureFolders() async {
    final root = await _folder(
      name: 'NO SUS',
      parent: 'root',
      marker: markerRoot,
    );
    final saved = await _folder(
      name: 'Saved',
      parent: root,
      marker: markerSaved,
    );
    final messages = await _folder(
      name: 'Messages',
      parent: saved,
      marker: markerMessages,
    );
    return DriveFolders(root: root, saved: saved, messages: messages);
  }

  Future<List<SavedItem>> listTimeline(DriveFolders folders) async {
    final saved = await _list("'${folders.saved}' in parents and trashed = false");
    final messages = await _list(
      "'${folders.messages}' in parents and trashed = false",
    );
    final items = <SavedItem>[];
    for (final file in saved) {
      if (file.driveId == folders.messages || file.mime.contains('folder')) {
        continue;
      }
      items.add(file);
    }
    for (final message in messages) {
      if (message.mime.contains('folder')) continue;
      String? text;
      try {
        text = utf8.decode(await download(message.driveId));
      } catch (_) {
        text = null;
      }
      items.add(message.withText(text));
    }
    items.sort((a, b) => a.created.compareTo(b.created));
    return items;
  }

  Future<SavedItem> putMessage({
    required String messagesFolderId,
    required String nosusId,
    required String text,
    required String src,
  }) async {
    _id(nosusId);
    final existing = await _find(nosusId);
    if (existing != null) return existing.withText(text);
    final bytes = Uint8List.fromList(utf8.encode(text));
    return _upload(
      parent: messagesFolderId,
      name: '$nosusId.md',
      mime: 'text/markdown',
      bytes: bytes,
      nosusId: nosusId,
      kind: 'msg',
      src: src,
    );
  }

  Future<SavedItem> putFile({
    required String savedFolderId,
    required String nosusId,
    required String name,
    required String mime,
    required Uint8List bytes,
    required String src,
  }) async {
    _id(nosusId);
    final existing = await _find(nosusId);
    if (existing != null) return existing;
    return _upload(
      parent: savedFolderId,
      name: name,
      mime: mime,
      bytes: bytes,
      nosusId: nosusId,
      kind: 'file',
      src: src,
    );
  }

  Future<Uint8List> download(String driveId) async {
    final res = await _send(
      'GET',
      Uri.https('www.googleapis.com', '/drive/v3/files/$driveId', {'alt': 'media'}),
    );
    return res.bodyBytes;
  }

  Future<String> _folder({
    required String name,
    required String parent,
    required String marker,
  }) async {
    final found = await _list(
      "appProperties has { key='nosus_marker' and value='$marker' } and trashed = false",
      orderBy: 'createdTime',
    );
    if (found.isNotEmpty) return found.first.driveId;
    final created = await _json('POST', Uri.https('www.googleapis.com', '/drive/v3/files'), {
      'name': name,
      'mimeType': 'application/vnd.google-apps.folder',
      'parents': [parent],
      'appProperties': {'nosus_marker': marker},
    });
    return created['id'] as String;
  }

  Future<SavedItem?> _find(String nosusId) async {
    final found = await _list(
      "appProperties has { key='nosus_id' and value='$nosusId' } and trashed = false",
    );
    if (found.isEmpty) return null;
    return found.first;
  }

  Future<SavedItem> _upload({
    required String parent,
    required String name,
    required String mime,
    required Uint8List bytes,
    required String nosusId,
    required String kind,
    required String src,
  }) async {
    const boundary = 'nosus_go_boundary';
    final meta = jsonEncode({
      'name': name,
      'mimeType': mime,
      'parents': [parent],
      'appProperties': {
        'nosus_id': nosusId,
        'nosus_kind': kind,
        'nosus_src': src,
      },
    });
    final head = utf8.encode(
      '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$meta\r\n'
      '--$boundary\r\nContent-Type: $mime\r\n\r\n',
    );
    final tail = utf8.encode('\r\n--$boundary--');
    final body = Uint8List(head.length + bytes.length + tail.length)
      ..setRange(0, head.length, head)
      ..setRange(head.length, head.length + bytes.length, bytes)
      ..setRange(head.length + bytes.length, head.length + bytes.length + tail.length, tail);
    final res = await _send(
      'POST',
      Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
        'uploadType': 'multipart',
      }),
      body: body,
      headers: {'Content-Type': 'multipart/related; boundary=$boundary'},
    );
    final created = jsonDecode(res.body) as Map<String, dynamic>;
    return SavedItem(
      driveId: created['id'] as String,
      nosusId: nosusId,
      name: name,
      mime: mime,
      size: bytes.length,
      src: src,
      created: DateTime.now().toUtc(),
      isMessage: kind == 'msg',
      text: kind == 'msg' ? utf8.decode(bytes) : null,
    );
  }

  Future<List<SavedItem>> _list(String query, {String? orderBy}) async {
    final params = {
      'q': query,
      'fields': 'files(id,name,mimeType,size,createdTime,appProperties)',
      'pageSize': '100',
      'spaces': 'drive',
      'orderBy': ?orderBy,
    };
    final decoded = await _json(
      'GET',
      Uri.https('www.googleapis.com', '/drive/v3/files', params),
      null,
    );
    final files = decoded['files'];
    if (files is! List) return const [];
    return [
      for (final raw in files)
        if (raw is Map) _item(Map<String, dynamic>.from(raw)),
    ];
  }

  SavedItem _item(Map<String, dynamic> raw) {
    final props = raw['appProperties'];
    final map = props is Map ? Map<String, dynamic>.from(props) : const <String, dynamic>{};
    final created = DateTime.tryParse(raw['createdTime'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return SavedItem(
      driveId: raw['id'] as String? ?? '',
      nosusId: map['nosus_id'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      mime: raw['mimeType'] as String? ?? '',
      size: int.tryParse('${raw['size'] ?? 0}') ?? 0,
      src: map['nosus_src'] as String? ?? 'phone',
      created: created,
      isMessage: map['nosus_kind'] == 'msg',
    );
  }

  Future<Map<String, dynamic>> _json(String method, Uri uri, Map<String, dynamic>? body) async {
    final res = await _send(
      method,
      uri,
      body: body == null ? null : Uint8List.fromList(utf8.encode(jsonEncode(body))),
      headers: body == null ? null : {'Content-Type': 'application/json'},
    );
    if (res.body.isEmpty) return const {};
    final decoded = jsonDecode(res.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return const {};
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Uint8List? body,
    Map<String, String>? headers,
  }) async {
    final access = await token();
    final request = http.Request(method, uri)
      ..headers['Authorization'] = 'Bearer $access'
      ..headers.addAll(headers ?? const {});
    if (body != null) request.bodyBytes = body;
    final streamed = await client.send(request);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    var reason = '';
    try {
      final decoded = jsonDecode(res.body);
      final errors = decoded is Map ? decoded['error'] : null;
      final list = errors is Map ? errors['errors'] : null;
      if (list is List && list.isNotEmpty && list.first is Map) {
        reason = (list.first as Map)['reason'] as String? ?? '';
      }
    } catch (_) {}
    if (reason == 'storageQuotaExceeded') {
      throw const DriveFailure('full', 'Google Drive is full.');
    }
    if (res.statusCode == 401) {
      throw const DriveFailure('auth', 'Google access expired. Connect Drive again.');
    }
    throw DriveFailure('http', 'Drive request failed (${res.statusCode}).');
  }
}

void _id(String id) {
  if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id)) {
    throw ArgumentError.value(id, 'nosusId');
  }
}
