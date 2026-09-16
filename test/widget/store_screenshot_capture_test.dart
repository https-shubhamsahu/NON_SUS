import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/store_screenshot_harness.dart';

/// VM fallback used when no Android emulator is attached.
/// Same widgets and demo data as the integration_test drive target.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('write Play Store phone screenshots from live widgets', (
    tester,
  ) async {
    await captureStoreScreenshots(tester);
  });
}
