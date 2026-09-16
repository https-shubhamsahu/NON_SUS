import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:no_sus/components/secure_viewer/models/watermark_config.dart';
import 'package:no_sus/components/secure_viewer/secure_document_viewer.dart';
import 'package:no_sus/core/providers/theme_provider.dart';
import 'package:no_sus/features/audit/providers/audit_provider.dart';
import 'package:no_sus/features/auth/domain/entities/authenticated_user.dart';
import 'package:no_sus/features/auth/presentation/providers/auth_providers.dart';
import 'package:no_sus/features/groups/domain/models/study_group.dart';
import 'package:no_sus/features/groups/models/group_file.dart';
import 'package:no_sus/features/groups/providers/groups_provider.dart';
import 'package:no_sus/features/groups/screens/group_detail_screen.dart';
import 'package:no_sus/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:no_sus/features/profile/presentation/screens/profile_screen.dart';
import 'package:no_sus/features/profile/providers/profile_provider.dart';
import 'package:no_sus/features/share/presentation/screens/burn_note_creator_screen.dart';
import 'package:no_sus/features/share/presentation/screens/burn_note_viewer_screen.dart';
import 'package:no_sus/theme.dart';

/// Play phone screenshots: ≥1080px per side, aspect ratio ≤ 2:1.
const storePhoneSize = Size(1080, 2160);
const storeCaptureKey = ValueKey<String>('store_screenshot_capture');
const _demoUserId = '00000000-0000-4000-a000-000000000001';
const _demoEmail = 'alex@example.com';

final _phoneScreenshotsDir = Directory(
  'fastlane/metadata/android/en-IN/images/phoneScreenshots',
);

const _demoMembers = <GroupMember>[
  GroupMember(id: _demoUserId, name: 'Alex', initials: 'AL', isAdmin: true),
  GroupMember(
    id: '00000000-0000-4000-a000-000000000002',
    name: 'Jordan',
    initials: 'JO',
  ),
  GroupMember(
    id: '00000000-0000-4000-a000-000000000003',
    name: 'Sam',
    initials: 'SA',
  ),
];

final _demoGroup = StudyGroup(
  id: 'demo-seminar',
  name: 'Week 3 Seminar',
  description: 'Shared reading for this week',
  members: _demoMembers,
  fileCount: 2,
  lastActivity: DateTime.utc(2026, 9, 16, 12),
  inviteCode: 'DEMO01',
);

final _demoFiles = <GroupFile>[
  GroupFile(
    id: 'file-notes',
    name: 'Lecture notes.pdf',
    type: FileType.pdf,
    groupId: 'demo-seminar',
    uploadedBy: _demoUserId,
    ownerId: _demoUserId,
    uploadedAt: DateTime.utc(2026, 9, 15, 9),
    sizeBytes: 245000,
  ),
  GroupFile(
    id: 'file-set',
    name: 'Problem set 2.pdf',
    type: FileType.pdf,
    groupId: 'demo-seminar',
    uploadedBy: '00000000-0000-4000-a000-000000000002',
    ownerId: '00000000-0000-4000-a000-000000000002',
    uploadedAt: DateTime.utc(2026, 9, 14, 16),
    sizeBytes: 128000,
  ),
];

class _DemoGroupsNotifier extends GroupsNotifier {
  @override
  Future<List<StudyGroup>> build() async => [_demoGroup];
}

class _DemoGroupFilesNotifier extends GroupFilesNotifier {
  @override
  Future<Map<String, List<GroupFile>>> build() async => {
        'demo-seminar': _demoFiles,
      };
}

class _DemoAuditLogsNotifier extends AuditLogsNotifier {
  @override
  Future<List<Map<String, String>>> build() async => const [];
}

class _DemoProfileNotifier extends ProfileNotifier {
  @override
  AsyncValue<ProfileData> build() => const AsyncValue.data(
        ProfileData(
          displayName: 'Alex',
          avatarColorStart: 'FF0072FF',
          avatarColorEnd: 'FF00F2FE',
          userType: 'student',
        ),
      );
}

/// Pumps production screens with demo data and writes 24-bit PNGs.
///
/// [onDriverScreenshot] is the Android/iOS `takeScreenshot` path used by
/// `flutter drive`. The VM widget-test path still writes files itself.
Future<void> captureStoreScreenshots(
  WidgetTester tester, {
  Future<void> Function(String name)? onDriverScreenshot,
}) async {
  tester.view.physicalSize = storePhoneSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await _loadScreenshotFonts();

  final prefs = await SharedPreferences.getInstance();

  await _pumpCaptured(tester, prefs: prefs, home: const WelcomeScreen());
  await _snap(tester, '1_welcome', onDriverScreenshot);

  await _pumpCaptured(tester, prefs: prefs, home: const BurnNoteCreatorScreen());
  await tester.enterText(
    find.byType(TextField),
    'The library is booked from 4 to 6. Bring the printed slides.',
  );
  await tester.pump();
  await _snap(tester, '2_burn_note_create', onDriverScreenshot);

  // Dummy id/key/IV — never a real share. The gate is shown; reveal is
  // not tapped, so nothing is fetched from the network.
  await _pumpCaptured(
    tester,
    prefs: prefs,
    wrapInMaterialApp: false,
    home: const BurnNoteViewerScreen(
      noteId: '00000000-0000-4000-a000-0000000000b1',
      keyHex: '0000000000000000000000000000000000000000000000000000000000000000',
      ivHex: '00000000000000000000000000000000',
    ),
  );
  await _snap(tester, '3_burn_note_viewer', onDriverScreenshot);

  await _pumpCaptured(
    tester,
    prefs: prefs,
    extra: _signedInOverrides(),
    home: GroupDetailScreen(group: _demoGroup),
  );
  await _snap(tester, '4_group_documents', onDriverScreenshot);

  await _pumpCaptured(
    tester,
    prefs: prefs,
    home: const _DemoWatermarkedViewer(),
  );
  await _snap(tester, '5_watermarked_viewer', onDriverScreenshot);

  await _pumpCaptured(
    tester,
    prefs: prefs,
    extra: _signedInOverrides(),
    home: const ProfileScreen(),
  );
  await _snap(tester, '6_profile', onDriverScreenshot);
}

List _signedInOverrides() {
  return [
    authStateProvider.overrideWith(
      (ref) => Stream<AuthenticatedUser?>.value(
        const AuthenticatedUser(id: _demoUserId, email: _demoEmail),
      ),
    ),
    groupsProvider.overrideWith(_DemoGroupsNotifier.new),
    groupFilesProvider.overrideWith(_DemoGroupFilesNotifier.new),
    auditLogsProvider.overrideWith(_DemoAuditLogsNotifier.new),
    profileProvider.overrideWith(_DemoProfileNotifier.new),
  ];
}

Future<void> _pumpCaptured(
  WidgetTester tester, {
  required SharedPreferences prefs,
  required Widget home,
  List extra = const [],
  bool wrapInMaterialApp = true,
}) async {
  final captured = RepaintBoundary(key: storeCaptureKey, child: home);
  final base = NoSusTheme.darkTheme;
  final child = wrapInMaterialApp
      ? MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: base.copyWith(
            textTheme: base.textTheme.apply(fontFamily: 'Inter'),
            primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Inter'),
          ),
          builder: (context, appChild) {
            return DefaultTextStyle.merge(
              style: const TextStyle(fontFamily: 'Inter'),
              child: appChild!,
            );
          },
          home: captured,
        )
      : captured;

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...extra,
      ],
      child: child,
    ),
  );
  await tester.pump();
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
  } catch (_) {
    await tester.pump(const Duration(milliseconds: 900));
  }
}

bool _fontsLoaded = false;

Future<void> _loadScreenshotFonts() async {
  if (_fontsLoaded) return;
  Future<void> loadFamily(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(rootBundle.load(file));
    }
    await loader.load();
  }

  await loadFamily('Inter', [
    'assets/google_fonts/Inter-Regular.ttf',
    'assets/google_fonts/Inter-Medium.ttf',
    'assets/google_fonts/Inter-SemiBold.ttf',
    'assets/google_fonts/Inter-Bold.ttf',
  ]);
  // Material default family in ThemeData.dark() is Roboto. Widget tests
  // otherwise substitute Ahem (every glyph is a square), which would ship
  // unreadable Play screenshots.
  await loadFamily('Roboto', [
    'assets/google_fonts/Inter-Regular.ttf',
    'assets/google_fonts/Inter-Medium.ttf',
    'assets/google_fonts/Inter-SemiBold.ttf',
    'assets/google_fonts/Inter-Bold.ttf',
  ]);
  await loadFamily('sans-serif', [
    'assets/google_fonts/Inter-Regular.ttf',
    'assets/google_fonts/Inter-Medium.ttf',
    'assets/google_fonts/Inter-SemiBold.ttf',
    'assets/google_fonts/Inter-Bold.ttf',
  ]);
  await loadFamily('Outfit', [
    'assets/google_fonts/Outfit-Regular.ttf',
    'assets/google_fonts/Outfit-SemiBold.ttf',
    'assets/google_fonts/Outfit-Bold.ttf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final materialIcons = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (materialIcons.existsSync()) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(
        Future.value(ByteData.sublistView(materialIcons.readAsBytesSync())),
      );
      await loader.load();
    }
  }
  _fontsLoaded = true;
}

Future<void> _snap(
  WidgetTester tester,
  String name,
  Future<void> Function(String name)? onDriverScreenshot,
) async {
  if (onDriverScreenshot != null) {
    try {
      await onDriverScreenshot(name);
    } catch (_) {
      // Android/iOS flutter-drive only.
    }
  }

  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(storeCaptureKey),
    );
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to rasterize $name');
    }
    final decoded = img.decodePng(byteData.buffer.asUint8List());
    if (decoded == null) {
      throw StateError('Failed to decode raster for $name');
    }
    final rgb = decoded.convert(numChannels: 3);
    await _phoneScreenshotsDir.create(recursive: true);
    await File('${_phoneScreenshotsDir.path}/$name.png').writeAsBytes(
      img.encodePng(rgb),
    );
  });
}

/// Production [SecureDocumentViewer] chrome matching SpyglassViewer, with
/// demo copy only — no real documents, emails, or share keys.
class _DemoWatermarkedViewer extends StatelessWidget {
  const _DemoWatermarkedViewer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    const title = 'Week 3 reading notes';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: fg, size: 20),
          onPressed: () {},
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: fg,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'NOTE',
              style: TextStyle(
                color: fg.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: fg.withValues(alpha: 0.18), width: 0.75),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 11, color: fg.withValues(alpha: 0.5)),
                const SizedBox(width: 5),
                Text(
                  'SECURE',
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SecureDocumentViewer(
        watermarkConfig: const WatermarkConfig(
          name: 'ALEX',
          role: 'SECURE MEMBER',
          email: _demoEmail,
          timestamp: '2026-09-17 12:00 IST',
        ),
        touchToRevealEnabled: false,
        watermarkEnabled: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Text(
            'Week 3 reading notes\n\n'
            '1. Bring one printed copy to the seminar.\n'
            '2. Mark the paragraph you want to discuss.\n'
            '3. Do not forward this file — open it here so the watermark '
            'ties the view to you.\n\n'
            'This is demo text for the store listing. It is not a real '
            'assignment and contains no student work.',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ),
      ),
    );
  }
}
