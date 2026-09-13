import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../../../config/supabase_credentials.dart';
import '../../../services/redemption_envelope.dart';
import '../../../services/burn_file_crypto.dart' show bytesToHex;
import 'package:encrypt/encrypt.dart' as enc;

class RedemptionCodeClient {
  RedemptionCodeClient._();
  static final RedemptionCodeClient instance = RedemptionCodeClient._();

  static final Uri _createEndpoint = Uri.parse(
    '${SupabaseCredentials.url}/functions/v1/create-redemption-code',
  );
  static final Uri _redeemEndpoint = Uri.parse(
    '${SupabaseCredentials.url}/functions/v1/redeem-code',
  );

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'apikey': SupabaseCredentials.anonKey,
  };

  /// Mints a pairing record. [pin] is the two-digit confirmation; [token]
  /// is the unguessable secret that belongs in `/#/r/<token>`.
  Future<({String token, String pin, DateTime expiresAt})> createCode({
    required String targetKind,
    required String targetId,
    required String keyHex,
    required String ivHex,
  }) async {
    final token = bytesToHex(
      Uint8List.fromList(enc.Key.fromSecureRandom(16).bytes),
    );
    final pin = (enc.IV.fromSecureRandom(1).bytes.first % 100)
        .toString()
        .padLeft(2, '0');
    final envelope = RedemptionEnvelope.seal(
      token: token,
      pin: pin,
      keyHex: keyHex,
      contentIvHex: ivHex,
    );
    final res = await http.post(
      _createEndpoint,
      headers: _headers,
      body: jsonEncode({
        'target_kind': targetKind,
        'target_id': targetId,
        'token_hash': RedemptionEnvelope.tokenHash(token),
        'pin_hash': RedemptionEnvelope.pinHash(token, pin),
        'key_material_ciphertext': envelope.ciphertextHex,
        'key_material_iv_hex': envelope.ivHex,
      }),
    );
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(
        decoded['error'] as String? ?? 'Could not create a code.',
      );
    }
    return (
      token: token,
      pin: pin,
      expiresAt: DateTime.parse(decoded['expires_at'] as String),
    );
  }

  /// [token]+[pin] is the current path. [code] is the legacy 8-character path.
  Future<({String targetKind, String targetId, String keyHex, String ivHex})>
  redeem({String? code, String? token, String? pin}) async {
    final body = <String, String>{};
    if (token != null && pin != null) {
      body['token'] = token;
      body['pin'] = pin;
    } else if (code != null) {
      body['code'] = code;
    } else {
      throw Exception(
        'Open the link you were sent, then enter the 2-digit code.',
      );
    }

    final res = await http.post(
      _redeemEndpoint,
      headers: _headers,
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(
        decoded['error'] as String? ?? 'That code could not be redeemed.',
      );
    }
    final isEnvelope =
        decoded['key_material_ciphertext'] is String &&
        decoded['key_material_iv_hex'] is String;
    final material = isEnvelope
        ? RedemptionEnvelope.open(
            token: token!,
            pin: pin!,
            ciphertextHex: decoded['key_material_ciphertext'] as String,
            envelopeIvHex: decoded['key_material_iv_hex'] as String,
          )
        : (
            keyHex: decoded['key_hex'] as String,
            ivHex: decoded['iv_hex'] as String,
          );
    return (
      targetKind: decoded['target_kind'] as String,
      targetId: decoded['target_id'] as String,
      keyHex: material.keyHex,
      ivHex: material.ivHex,
    );
  }
}
