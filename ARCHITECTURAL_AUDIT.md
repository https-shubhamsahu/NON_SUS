# NO SUS — Complete Architectural Audit

**Date**: 2026-06-16
**Project**: `no_sus` v1.0.0+1
**SDK**: Dart ^3.12.1 / Flutter

---

## 1. Project Identity

- **Name**: NO SUS (`no_sus`)
- **Version**: 1.0.0+1
- **SDK**: Dart ^3.12.1, Flutter
- **Description**: Encrypted document-sharing workspace for students with secure viewer, watermarking, and audit logging.

## 2. Directory Structure

```
no_sus/
├── lib/
│   ├── main.dart                    # Entry point
│   ├── theme.dart                   # Material 3 theme (light/dark)
│   ├── screens/
│   │   └── splash_screen.dart
│   ├── config/
│   │   └── supabase_credentials.dart  # dart-define env reader
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart
│   │   │   └── mock_documents.dart
│   │   ├── providers/
│   │   │   └── theme_provider.dart
│   │   └── supabase/
│   │       ├── supabase_bootstrap.dart
│   │       └── supabase_providers.dart
│   ├── services/
│   │   ├── supabase_service.dart        # 16KB central Supabase client
│   │   ├── secure_db_service.dart        # 33KB repository hub
│   │   ├── secure_enclave.dart
│   │   ├── secure_key_store.dart
│   │   ├── cryptography_service.dart
│   │   ├── screenshot_guard.dart
│   │   ├── zero_trust_gateway.dart
│   │   ├── audit_service.dart
│   │   ├── focus_service.dart
│   │   └── app_preferences_service.dart
│   ├── components/
│   │   ├── floating_nav.dart
│   │   ├── spyglass_viewer.dart
│   │   ├── study_chart.dart
│   │   └── secure_viewer/
│   │       ├── secure_document_viewer.dart
│   │       ├── watermark_overlay.dart
│   │       ├── blur_reveal_layer.dart
│   │       ├── painters/watermark_painter.dart
│   │       └── models/
│   │           ├── viewer_config.dart
│   │           └── watermark_config.dart
│   └── features/
│       ├── auth/        (Clean Architecture)
│       ├── groups/      (Clean Architecture)
│       ├── files/       (Clean Architecture)
│       ├── onboarding/  (provider-based)
│       ├── profile/     (provider-based)
│       ├── workspace/   (direct service calls)
│       ├── vault/       (direct service calls)
│       ├── audit/       (provider + service)
│       ├── focus/       (provider + service)
│       └── notes/       (provider + service)
├── test/                (15 test files)
├── supabase/
│   ├── migrations/      (5 migrations)
│   ├── functions/       (1 Deno edge function)
│   └── config.toml
├── assets/
│   ├── images/          (6 avatar PNGs)
│   └── videos/          (splash_intro.mp4 — unused)
├── .env
└── pubspec.yaml
```

## 3. Architecture Score: **6.5/10**

**Mixed — not consistently applied.**

- **Auth, Groups, Files**: Clean Architecture (domain → data → presentation). Each has entities, use cases, repository interfaces, Supabase + mock implementations.
- **Workspace, Vault, Audit, Focus, Notes, Profile, Onboarding**: Direct service calls with Riverpod providers. No use cases, no repository interfaces.
- **Service layer confusion**: `SecureDbService` (33KB) is a monolithic hub duplicating responsibilities of `AuditService`, `FocusService`, `AppPreferencesService`. These singletons co-exist but overlap in capability. `SecureDbService` is NOT a true service layer — it's a giant God class routing Supabase/mock calls.

## 4. State Management: **8/10**

**Riverpod exclusively** — clean, consistent.

- `Notifier`, `AsyncNotifier`, `StreamProvider`, `Provider`, `NotifierProvider` patterns used.
- All providers are scoped correctly with proper `ref.onDispose`.
- One concern: `authRepositoryProvider` is read directly in `WorkspaceTab.initState()` instead of watching `authStateProvider`.

## 5. Authentication: **7/10**

- Email/password, phone OTP, Google OAuth, GitHub OAuth — all wired.
- `auth_gate.dart` handles guest mode, role selection, onboarding → auth → main flow.
- Supabase Auth integration is fully configured in `config.toml`.
- Auth providers are mocked for tests.
- **Issue**: No refresh token rotation handling. No token persistence error recovery.

## 6. Security — Encryption: **9/10**

- **AES-256-GCM** via `cryptography` package — correct algorithm choice.
- Keys stored in `SecureKeyStore` using `flutter_secure_storage` (Android Keystore / iOS Keychain). Keys are **never** sent to Supabase. The fix migration correctly drops `encryption_key_base64` and `encryption_iv_base64` columns.
- `CryptographyService.encryptBytes`/`decryptBytes` tested and validated.

## 7. Security — Key Management: **7.5/10**

- **Strength**: E2E encryption model is correct. Keys live on-device only. Key rotation is supported via `SecureDbService.rotateWorkspaceKeys()`.
- **Weakness**: `SecureEnclave.purge()` uses `fillRange(0, length, 0)` which the code itself acknowledges does NOT actually clear memory in Dart's managed heap. The in-memory buffer can survive in GC'd memory.
- `deleteAll()` on sign-out correctly scopes to `nosus_key_*`/`nosus_iv_*` prefixes.
- **Issue**: If user uploads file on Device A, they cannot decrypt it on Device B (no key sync). This is by design but needs to be documented as a UX limitation.

## 8. Security — Screen Protection: **7/10**

- `ScreenshotGuard` uses `MethodChannel('co.nosus.app/security')` for FLAG_SECURE.
- Only Android is implemented (iOS Screen recording detection is missing).
- Watermark overlay on all document viewing is correct (repeating diagonal text).
- Blur-reveal layer with touch-to-reveal is well-implemented with animation controller.
- **Issue**: The `ScreenshotGuard` navigator key is separate from `MaterialApp`'s navigatorKey — potential inconsistency.

## 9. Security — Zero-Trust Gateway: **5/10**

- **Critical**: Hardcoded `static const String key = "NOSUS_SECRET_DRM_KEY_2026"` — this is NOT secret.
- Simulated MongoDB Atlas endpoints — not calling any actual backend.
- Access control is evaluated client-side, which is trivially bypassed.
- The comment says "NOTE: This is a simulation" — acceptable if understood as placeholder, but dangerous if deployed.

## 10. Database Schema & RLS: **6.5/10**

5 migrations, but **migration ordering is wrong**:

| File | Purpose |
|------|---------|
| `20260611000000_phase_1_schema.sql` | Original schema with correct RLS |
| `20260612000000_secure_files_rls.sql` | secure_files RLS |
| `20260613000000_storage_setup.sql` | Storage bucket + RLS |
| `20260614000000_fix_rls_policies.sql` | Replace "Allow all" with scoped policies |
| `20260614000001_missing_tables_migration.sql` | Create ALL tables with "Allow all" policies + realtime |

**Critical ordering bug**: `fix_rls` (14/00:00:00) runs BEFORE `missing_tables` (14/00:00:01). Since `missing_tables` re-creates tables with `IF NOT EXISTS` and adds "Allow all" policies, **the fix migration's policies get overwritten by the later migration's "Allow all" policies**. Each `DO $$ BEGIN IF NOT EXISTS...` block in `fix_rls` checks for policy existence — when `missing_tables` runs second, it creates `profiles`, `study_groups`, etc. with "Allow all". The fix policies already exist on any tables that existed before, but the new "Allow all" ones take precedence for newly created tables.

**Storage RLS gap**: In `fix_rls` migration, storage policies only check `auth.role() = 'authenticated'` — they do NOT verify group membership. Any authenticated user can download/delete any file in the `secure-files` bucket. The earlier migration `20260613000000_storage_setup.sql` had correct group-membership checks, but `fix_rls` replaces them with weaker checks.

**Referential integrity risk**: Storage objects are named by `secure_files.id` (text field). The migration uses `f.id = storage.objects.name` for file lookup — this joins a text field to an object name with no foreign key constraint. If a file ID changes or the object name mismatches, RLS policies silently fail open (no rows returned, access denied).

## 11. API / Data Layer: **7/10**

- `SupabaseService` (16KB) is well-structured with Supabase client wrapper, mock fallback, DNS reachability check.
- `SecureDbService` (33KB) acts as offline-first data hub routing to Supabase or mock pools.
- **Issue**: `SecureDbService` is a God class — handles groups, files, audit logs, user notes, preferences, key rotation. Should be split by domain.
- Mock data (`MockGroupsData`, `MockDocuments`) exists but **mock groups data returns empty lists** — no demo data on first launch without Supabase.

## 12. UI / UX: **8/10**

- Custom `FloatingNav` with 5 tabs (Workspace, Vault, Study Desk, Audit Log, Groups) — unique, attractive design.
- Smooth animations via `flutter_animate` throughout.
- Material 3 theming is comprehensive (light/dark, custom colors, Inter + Outfit fonts).
- Auth screen is well-designed with tab switching, OAuth buttons, phone OTP, validation.
- No skeleton/loading states for async operations in several screens.
- Splash screen uses animated paint — `splash_intro.mp4` asset exists but is unused.

## 13. Navigation: **7/10**

- Tab navigation: Custom `FloatingNav` (not Material `BottomNavigationBar`).
- Screen navigation: `Navigator.of(context).push` for detail screens (group detail, join group, settings, spyglass viewer).
- Splash → main: `pushReplacement`.
- **Issue**: No named routes / `GoRouter`. No deep link support. No `Navigator 2.0` or declarative routing.

## 14. Offline / Mock Fallback: **7.5/10**

- **Strength**: Every data operation checks `SupabaseService.instance.isReachable` and falls back gracefully. This is consistently applied across all services.
- **Strength**: `AppPreferencesService` uses `SharedPreferences` for persistence even offline.
- **Weakness**: Mock data pools are empty for groups/files — fallback mode shows "no data" which is confusing.
- **Weakness**: In-memory mock state is lost on app restart.

## 15. Error Handling: **6/10**

- SnackBars used for user-visible errors (key rotation, auth failures).
- Try/catch in services with `debugPrint` logging.
- **Missing**: No centralized error handling. No error boundary widgets. No graceful degradation beyond the offline fallback.
- Stream subscriptions in `AuditService` have `onError` but `cancelOnError: true` means the first error kills the stream permanently.
- The `_debounceTimer` in `UserNoteNotifier` is never cancelled if the provider is disposed during debounce — potential memory leak (timer keeps ref to provider).

## 16. Testing: **6/10**

| Test File | Type | Coverage |
|-----------|------|----------|
| `widget_test.dart` | Smoke | App shell builds |
| `auth_providers_test.dart` (2 files) | Unit + Integration | Auth use cases, fake repo |
| `onboarding_providers_test.dart` | Unit | Onboarding + SecureDbService |
| `onboarding_auth_flow_test.dart` | Widget | Role selection → auth gate |
| `groups_provider_test.dart` | Unit | Search query |
| `groups_screen_test.dart` | Widget | Groups screen rendering |
| `auth_screen_test.dart` | Widget | Auth screen + validation |
| `upload_provider_test.dart` | Unit | Upload state machine |
| `secure_file_repository_test.dart` | Integration | Mock repo upload/download |
| `secure_enclave_test.dart` | Unit | Enclave lifecycle |
| `cryptography_service_test.dart` | Unit | Encrypt/decrypt + key gen |
| `app_constants_test.dart` | Unit | Constants correctness |
| `db_test.dart` | Integration | Supabase connectivity (diagnostic) |
| `supabase_service_test.dart` | Integration | Drive proxy (skipped) |

**Missing**:
- Vault tab widget test
- Workspace tab widget test
- Audit tab widget test
- Spyglass/secure viewer widget test
- Supabase repository implementations (never tested against live DB)
- Groups screen with loaded data (uses mock data but not within the test file)
- `SecureDbService` unit tests

**Testing approach**: Uses `mocktail` for mocking. Riverpod's `ProviderContainer.overrides` is used correctly. No `flutter_lints` violations in test code.

## 17. Dependencies: **7/10**

| Package | Version | Purpose | Status |
|---------|---------|---------|--------|
| `google_fonts` | ^8.1.0 | Inter + Outfit fonts | ✓ |
| `flutter_animate` | ^4.5.2 | UI animations | ✓ |
| `flutter_riverpod` | ^3.3.1 | State management | ✓ |
| `supabase_flutter` | ^2.6.0 | Backend | ✓ |
| `cryptography` | ^2.7.0 | AES-256-GCM | ✓ |
| `flutter_secure_storage` | ^9.2.4 | Key storage | ✓ |
| `pdfrx` | ^2.4.4 | PDF rendering | ✓ |
| `screen_protector` | ^1.5.2 | FLAG_SECURE | Android only |
| `file_picker` | ^11.0.2 | File selection | ✓ |
| `video_player` | ^2.8.2 | Splash video (unused) | ? |
| `smooth_page_indicator` | ^2.0.1 | Onboarding pages | ✓ |

**No dependency conflicts detected.** All packages are recent.

## 18. Edge Functions: **8/10**

Single Deno edge function: `drive-proxy` (254 lines).
- Google Drive Service Account JWT auth → OAuth2 token exchange.
- Routes: POST /upload, GET /download, DELETE /delete, GET /info.
- Multipart upload with metadata + file body.
- **Strength**: JWT verification for incoming requests, service account never exposed to client.
- **Weakness**: Falls back to `supabaseAnonKey` match for authorization — this means anyone with the anon key can use the proxy. Acceptable for public anon key (it's meant to be public) but adds risk.

## 19. Infrastructure / CI-CD: **3/10**

- No CI/CD pipeline configured.
- No Dockerfile or container definition for the Flutter app.
- No GitHub Actions, no deployment scripts.
- `config.toml` is properly configured for local Supabase development.
- `supabase/.temp/` files indicate linked remote project.

## 20. Overall Scores

| Category | Score | Notes |
|----------|-------|-------|
| Architecture Consistency | 6.5 | Mixed Clean Architecture + God class services |
| State Management | 8.0 | Clean Riverpod usage |
| Security (Encryption) | 9.0 | AES-256-GCM, E2E key model |
| Security (Key Mgmt) | 7.5 | flutter_secure_storage correct, purge is no-op |
| Security (Screen) | 7.0 | Android FLAG_SECURE, watermark, blur-reveal |
| Security (Zero-Trust) | 5.0 | Simulated, hardcoded key, client-side eval |
| Database / RLS | 6.5 | Migration ordering bug, storage RLS gap |
| API / Data Layer | 7.0 | God class issue, empty mock data |
| UI / UX | 8.0 | Polished design, missing skeletons |
| Navigation | 7.0 | No deep links, no GoRouter |
| Offline Fallback | 7.5 | Consistently applied, empty mocks |
| Error Handling | 6.0 | No centralized handling, cancelOnError:true issue |
| Testing | 6.0 | 15 tests, missing widget/integration coverage |
| Dependencies | 7.0 | All current, `video_player` unused |
| Edge Functions | 8.0 | Solid Deno drive-proxy |
| CI/CD / Infrastructure | 3.0 | None |
| **Overall** | **6.7** | Solid foundation but needs cleanup |

---

## Critical Issues (Fix Immediately)

1. **Migration ordering bug**: `20260614000000_fix_rls` runs before `20260614000001_missing_tables`. The "missing tables" migration re-creates tables with "Allow all" policies that overwrite the fixed policies. Fix: rename the "fix" migration to `20260614000002_fix_rls_policies`.

2. **Storage RLS gap**: `fix_rls` replaces storage policies with `auth.role() = 'authenticated'` only — no group membership verification. Fix: restore the membership-checking policies from `20260613000000_storage_setup.sql`.

3. **SecureEnclave.purge() is a no-op**: `fillRange(0, length, 0)` does NOT clear Dart heap memory. For a security app, this is a concern. Consider `dart:ffi` with `calloc` for sensitive buffers, or document as best-effort.

## Important Issues (Fix Soon)

4. **Mock data is empty**: `MockGroupsData` returns empty `groups` and `files` maps. New users see a blank app in offline mode. Populate with realistic demo data.

5. **`SecureDbService` is a God class** (33KB): Split into domain-specific services (groups service, files service, audit service, etc.) to align with the Clean Architecture pattern used by auth/groups/files.

6. **`ZeroTrustGateway`** with hardcoded `NOSUS_SECRET_DRM_KEY_2026` key and client-side access enforcement. Remove or clearly mark as demo placeholder.

7. **Timer leak** in `UserNoteNotifier`: The `_debounceTimer` is not cancelled on provider disposal. Add `ref.onDispose(() => _debounceTimer?.cancel())`.

8. **`cancelOnError: true`** in `AuditService` kills the Supabase audit stream on first error. Remove this flag.

## Nice-to-Have Improvements

9. Add named routing (GoRouter) for deep link support.

10. Add iOS screen recording detection (`UIScreen.isCaptured`).

11. Add widget tests for Vault, Workspace, and Audit tabs.

12. Add skeleton/loading states to async screens.

13. Add CI/CD pipeline (GitHub Actions for test + build).

14. Replace `video_player` dependency (currently unused) or remove it.

15. Add pagination for file listing (currently loads all files at once).

16. Add key sync mechanism (or document the cross-device limitation).

17. Add `flutter_lints` checks to CI.

---

*Generated by opencode architectural audit — 2026-06-16*
