import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/share/presentation/screens/burn_note_creator_screen.dart';

void main() {
  String? clipboard;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return clipboard == null ? null : <String, dynamic>{'text': clipboard};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: BurnNoteCreatorScreen())),
    );
    await tester.pump();
  }

  testWidgets('Paste puts the clipboard into the note', (tester) async {
    clipboard = 'secret from clipboard';
    await pump(tester);
    await tester.tap(find.text('Paste'));
    await tester.pump();
    expect(find.text('secret from clipboard'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
  });

  testWidgets('Paste trims to the note limit', (tester) async {
    clipboard = 'x' * (kBurnNoteMaxChars + 10);
    await pump(tester);
    await tester.tap(find.text('Paste'));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.length, kBurnNoteMaxChars);
    expect(kBurnNoteMaxChars, 50000);
  });
}
