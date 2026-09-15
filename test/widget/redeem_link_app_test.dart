import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/share/presentation/screens/redeem_code_screen.dart';
import 'package:no_sus/main.dart';

void main() {
  // A `#/redeem/<token>` web link boots straight into this app. It used to
  // render RedeemCodeScreen with no MaterialApp above it, which threw on the
  // first frame and left recipients on a blank page.
  testWidgets('a pairing link renders the two-digit code entry', (tester) async {
    await tester.pumpWidget(redeemLinkApp(redeemToken: 'a' * 64));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(RedeemCodeScreen), findsOneWidget);
    expect(find.text('Enter the two-digit code'), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, 2);
  });
}
