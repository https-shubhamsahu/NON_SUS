// ignore_for_file: avoid_print
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/services/supabase_service.dart';

void main() {
  // We need to initialize the widget binding for network requests inside Flutter tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Supabase Edge Function Drive Proxy Integration Tests',
    () {
      setUpAll(() async {
        await SupabaseService.instance.initialize();
      });

      test('Upload, Download, and Delete flow via Drive Proxy', () async {
        expect(
          SupabaseService.instance.isConfigured,
          isTrue,
          reason: 'Supabase credentials should be configured',
        );

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final testFileName = 'test_integration_$timestamp';
        final testData = Uint8List.fromList([
          104,
          101,
          108,
          108,
          111,
          32,
          119,
          111,
          114,
          108,
          100,
        ]);

        print('Uploading test encrypted bytes to Google Drive via proxy...');
        final gDriveId = await SupabaseService.instance.uploadStorageFile(
          testFileName,
          testData,
        );
        expect(
          gDriveId,
          isNotNull,
          reason: 'Upload should return a valid Google Drive file ID',
        );

        final downloadedData = await SupabaseService.instance
            .downloadStorageFile(gDriveId!);
        expect(downloadedData, equals(testData));

        await SupabaseService.instance.deleteFile(gDriveId);
      });
    },
    skip: 'Requires a device integration harness and live Drive credentials.',
  );
}
