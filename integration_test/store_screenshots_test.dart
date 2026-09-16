import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/store_screenshot_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('capture Play Store phone screenshots from live widgets', (
    tester,
  ) async {
    await captureStoreScreenshots(
      tester,
      onDriverScreenshot: (name) async {
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        await binding.takeScreenshot(name);
      },
    );
  });
}
