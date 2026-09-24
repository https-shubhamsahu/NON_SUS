import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/core/crypto/nosus_seal.dart';
import 'package:no_sus/features/auth/presentation/providers/auth_providers.dart';
import 'package:no_sus/features/groups/domain/models/study_group.dart';
import 'package:no_sus/features/groups/drops/group_drops_providers.dart';
import 'package:no_sus/features/groups/drops/group_drops_tab.dart';
import 'package:no_sus/features/groups/drops/group_keys.dart';

import '../unit/group_keys_test.dart' show FakeApi, FakeRelay, PairDevice;

void main() {
  testWidgets('offline: honest banner, disabled composer, safety codes in the sheet', (tester) async {
    // Tall enough that the whole info sheet is built.
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final relay = FakeRelay();
    final a1 = generateGoKeyPair();
    final a2 = generateGoKeyPair();
    final b = generateGoKeyPair();
    relay.members['g1'] = {'alice', 'bob'};
    for (final (id, user, pair) in [('d1', 'alice', a1), ('d2', 'alice', a2), ('d3', 'bob', b)]) {
      relay.devices[id] = MemberDeviceKey(deviceKeyId: id, userId: user, publicKey: pair.publicKey, kind: 'keystore');
    }
    final service = GroupKeyService(api: FakeApi(relay, 'alice'), device: PairDevice('d1', a1));

    final group = StudyGroup(
      id: 'g1',
      name: 'Physics',
      description: '',
      members: const [
        GroupMember(id: 'alice', name: 'Alice', initials: 'AL'),
        GroupMember(id: 'bob', name: 'Bob', initials: 'BO'),
      ],
      fileCount: 0,
      lastActivity: DateTime(2026, 9, 24),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          groupKeyServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(home: Scaffold(body: GroupDropsTab(group: group))),
      ),
    );
    await tester.pump();

    expect(
      find.text('End-to-end encrypted. NO SUS relays messages and deletes them after 30 days; files after 7 days.'),
      findsOneWidget,
    );
    expect(find.text('Group drops need a connection to NO SUS.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

    await tester.tap(find.byTooltip('Encryption and safety codes'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Compare with the other person in person'), findsOneWidget);
    expect(find.text(safetyCode([a1.publicKey, a2.publicKey, b.publicKey])), findsOneWidget);
    expect(find.text(safetyCode([a1.publicKey, a2.publicKey])), findsOneWidget);
    expect(find.text(safetyCode([b.publicKey])), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.textContaining('zero-knowledge'), findsNothing);
  });
}
