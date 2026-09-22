import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/address/go_widgets.dart';

void main() {
  testWidgets('approval offers the codes and none of these', (tester) async {
    int? picked;
    var none = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchChoices(
            choices: const [7, 42, 8],
            onPick: (code) => picked = code,
            onNone: () => none = true,
          ),
        ),
      ),
    );
    expect(find.text('07'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    await tester.tap(find.text('None of these'));
    expect(none, isTrue);
    await tester.tap(find.text('07'));
    expect(picked, 7);
  });

  testWidgets('a saved line says where it came from and whether it saved', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SavedLine(
            text: 'notes.pdf · 12 KB',
            detail: 'From computer',
            status: 'Saved to Drive',
          ),
        ),
      ),
    );
    expect(find.text('notes.pdf · 12 KB'), findsOneWidget);
    expect(find.text('From computer'), findsOneWidget);
    expect(find.text('Saved to Drive'), findsOneWidget);
  });
}
