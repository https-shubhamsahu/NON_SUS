import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/main.dart';

// These lock the two shared-into-the-wild URL contracts. Links people have
// already sent must keep parsing forever — a regression here is a silent
// production outage for every link in flight.
void main() {
  const keyHex =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; // 64
  const ivHex = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'; // 32
  const noteId = '01234567-89ab-cdef-0123-456789abcdef';

  group('extractBurnNoteToken', () {
    test('parses the production GitHub Pages link format', () {
      final uri = Uri.parse(
        'https://https-shubhamsahu.github.io/NON_SUS/#/burn/$noteId?k=$keyHex&v=$ivHex',
      );
      final token = extractBurnNoteToken(uri);
      expect(token, isNotNull);
      expect(token!.id, noteId);
      expect(token.keyHex, keyHex);
      expect(token.ivHex, ivHex);
    });

    test('parses with a cache-buster query before the fragment', () {
      final uri = Uri.parse(
        'https://host/NON_SUS/?cb=1234#/burn/$noteId?k=$keyHex&v=$ivHex',
      );
      expect(extractBurnNoteToken(uri), isNotNull);
    });

    test('parses the legacy double-hash format', () {
      final uri =
          Uri.parse('https://host/#/burn/$noteId%23$keyHex.$ivHex');
      final token = extractBurnNoteToken(uri);
      expect(token, isNotNull);
      expect(token!.id, noteId);
    });

    test('rejects wrong-length keys', () {
      final uri = Uri.parse(
        'https://host/#/burn/$noteId?k=deadbeef&v=$ivHex',
      );
      expect(extractBurnNoteToken(uri), isNull);
    });

    test('returns null on ordinary app URLs', () {
      expect(extractBurnNoteToken(Uri.parse('https://host/NON_SUS/')), isNull);
      expect(extractBurnNoteToken(Uri.parse('file:///')), isNull);
    });
  });

  group('extractShareToken', () {
    test('parses token from hash fragment', () {
      expect(
        extractShareToken(Uri.parse('https://host/NON_SUS/?cb=1#/v/abc123')),
        'abc123',
      );
    });

    test('parses token from path', () {
      expect(extractShareToken(Uri.parse('https://host/v/tok9')), 'tok9');
    });

    test('returns null when absent', () {
      expect(extractShareToken(Uri.parse('https://host/NON_SUS/')), isNull);
    });
  });
}
