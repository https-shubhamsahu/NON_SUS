import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/intelligence/data/local_document_intelligence.dart';
import 'package:no_sus/main.dart';

void main() {
  test('extractRedeemToken parses pairing links and ignores other routes', () {
    expect(
      extractRedeemToken(Uri.parse('https://app.nosus.foo/#/r/0123456789abcdef0123456789abcdef')),
      '0123456789abcdef0123456789abcdef',
    );
    expect(extractRedeemToken(Uri.parse('https://app.nosus.foo/#/burn/abc')), isNull);
    expect(extractRedeemToken(Uri.parse('https://app.nosus.foo/#/r/short')), isNull);
  });

  test('local intelligence summarizes without a model', () async {
    const intel = LocalDocumentIntelligence();
    final result = await intel.inspect(
      title: 'sensitive-share.pdf',
      mimeType: 'application/pdf',
      plainText: 'NO SUS watermarks every view. Recipients do not need an account. The sender sees who opened the file.',
    );
    expect(intel.providerLabel, 'On-device');
    expect(result.summary, isNotEmpty);
    expect(result.highlights, isNotEmpty);
  });
}
