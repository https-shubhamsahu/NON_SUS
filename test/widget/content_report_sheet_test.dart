import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/components/content_report_sheet.dart';

void main() {
  testWidgets('report sheet lists reasons and stays disabled until one is chosen',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ContentReportSheet(
            targetKind: 'file',
            targetId: 'file-1',
            groupId: 'group-1',
          ),
        ),
      ),
    );

    expect(find.text('REPORT'), findsOneWidget);
    expect(find.text('Harassment'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.tap(find.text('Harassment'));
    await tester.pump();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
