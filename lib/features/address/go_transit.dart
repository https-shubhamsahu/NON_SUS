import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/crypto/nosus_seal.dart';
import '../share/data/burn_file_client.dart';

/// Burn Files is only the pipe. The bytes are sealed with a key that travels
/// inside the Go session, so storage never sees the file.
class GoTransit {
  GoTransit._();

  static Future<({String fileId, String key, String nonce})> upload(Uint8List plain) async {
    final key = randomBytes(32);
    final nonce = randomBytes(12);
    final box = sealBytes(key, nonce, plain);
    final init = await BurnFileClient.instance.init(
      declaredSizeBytes: box.length,
      expiryHours: 1,
    );
    await Supabase.instance.client.storage.from('burn-files').uploadBinaryToSignedUrl(
          init.fileId,
          init.uploadToken,
          box,
        );
    await BurnFileClient.instance.confirm(init.fileId);
    return (fileId: init.fileId, key: b64url(key), nonce: b64url(nonce));
  }

  static Future<Uint8List> download({
    required String fileId,
    required String key,
    required String nonce,
  }) async {
    final url = await BurnFileClient.instance.fetch(fileId);
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('Could not download this file.');
    }
    return openBytes(b64urlDecode(key), b64urlDecode(nonce), res.bodyBytes);
  }
}
