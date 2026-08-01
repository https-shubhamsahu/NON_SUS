import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sealed (the FHE-adjacent "reciprocity-gated share network") is removed from
/// the product surface pending a separate redesign.
///
/// What was removed was not a placeholder: `_SealedTeaserCard` sat in the first
/// slot of the Workspace tab, ran a scripted ASCII "simulation", then collected
/// a star rating, checkbox answers and free-text feedback — and discarded all of
/// it on `Navigator.pop`, while telling the user "Verification submitted to the
/// secure ledger."
///
/// The underlying research is deliberately kept (`lib/features/sealed/`,
/// `lib/features/fhe/`, `services/fhe-compute/`, the shelved edge functions),
/// gated behind `FheConfig` flags that default to false. This test guards the
/// boundary: the code may exist, but nothing in the shipped navigation may
/// reach it.
void main() {
  final libDir = Directory('lib');

  List<File> dartFilesUnder(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) return const [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  test('no user-facing screen reaches the Sealed or FHE demo surfaces', () {
    // Files belonging to the shelved subsystems themselves are allowed to
    // reference their own screens; nothing else may.
    final offenders = <String>[];

    for (final file in dartFilesUnder('lib')) {
      final normalised = file.path.replaceAll(r'\', '/');
      final isShelvedSubsystem =
          normalised.contains('lib/features/sealed/') ||
          normalised.contains('lib/features/fhe/');
      if (isShelvedSubsystem) continue;

      final source = file.readAsStringSync();
      for (final symbol in ['SealedHomeScreen', 'FheDemoScreen']) {
        if (source.contains(symbol)) {
          offenders.add('$normalised references $symbol');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Sealed/FHE screens must stay unrouted:\n${offenders.join('\n')}',
    );
  });

  test('the Workspace tab no longer ships the Sealed teaser', () {
    final workspace = File(
      'lib/features/workspace/presentation/pages/workspace_tab.dart',
    );
    expect(workspace.existsSync(), isTrue);

    final source = workspace.readAsStringSync();
    expect(source.contains('_SealedTeaserCard'), isFalse);
    expect(source.contains('_SealedDemoSheet'), isFalse);
    expect(
      source.contains('SEALED PROTOCOL'),
      isFalse,
      reason: 'the Sealed marketing copy must not survive the removal',
    );
    expect(
      source.contains('RECIPROCITY-GATED'),
      isFalse,
      reason: 'the Sealed marketing copy must not survive the removal',
    );
  });

  test('no shipped screen claims to submit data it discards', () {
    // The exact string the fake demo showed after throwing the survey away.
    for (final file in dartFilesUnder('lib')) {
      expect(
        file.readAsStringSync().contains('submitted to the secure ledger'),
        isFalse,
        reason: '${file.path} still contains the discarded-survey copy',
      );
    }
  });

  test('the shelved research is kept, not deleted', () {
    // Removal is from the product surface, not from the repo — the brief was
    // explicit that the underlying work should survive for a later redesign.
    expect(Directory('lib/features/sealed').existsSync(), isTrue);
    expect(Directory('lib/features/fhe').existsSync(), isTrue);
    expect(libDir.existsSync(), isTrue);
  });
}
