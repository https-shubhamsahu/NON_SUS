import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/screens/splash_screen.dart';

void main() {
  testWidgets('presents an accessible compact loading layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 440));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(nextScreen: SizedBox()),
      ),
    );
    await tester.pump();

    expect(find.text('NO SUS'), findsOneWidget);
    expect(find.text('Preparing your workspace'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Preparing NO SUS workspace',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('moves to the next screen without a long artificial delay',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(nextScreen: Text('Workspace ready')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump();

    expect(find.text('Workspace ready'), findsOneWidget);
  });
}
