import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Host-side driver for `flutter drive` store-screenshot capture.
///
/// Writes PNGs next to Fastlane Play metadata. The test also rasterizes
/// the Flutter surface itself so a Windows `flutter test` run still
/// produces images when no Android driver is attached.
Future<void> main() {
  return integrationDriver(
    onScreenshot: (String name, List<int> image, [Map<String, Object?>? args]) async {
      final file = File(
        'fastlane/metadata/android/en-IN/images/phoneScreenshots/$name.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(image);
      return true;
    },
  );
}
