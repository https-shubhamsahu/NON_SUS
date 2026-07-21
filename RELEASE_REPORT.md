# NO SUS — Production Release Report

**Prepared:** 10 July 2026
**App version at time of audit:** 1.1.0+7 · **Package at time of audit:** `io.nosus.app` · **Target/Compile SDK:** 36 (Android 16)
**Scope:** Full production/Play Store readiness audit and remediation ahead of first public release.

> **Update (19 July 2026):** the app id has since been renamed to `foo.nosus.app`
> (reverse-DNS of `app.nosus.foo`, where the Flutter web build now lives — see
> root `CLAUDE.md`'s "App id / custom scheme" note) and the version bumped to
> `1.2.0+9`. Everything below describes findings and fixes as of the original
> audit date and package id; it's a historical record, not a live snapshot —
> read `pubspec.yaml` and `android/app/build.gradle.kts` for current values.

This report documents every issue found during the audit, every fix applied, what's still manual, and a submission checklist. All fixes below were verified with `flutter analyze` (clean), `flutter test` (44/44 passing, 1 skipped — requires live Supabase credentials), and **a real `flutter build appbundle --release`**, whose output AAB was decompiled and its signing certificate fingerprint checked against the new keystore to confirm it isn't debug-signed.

---

## 1. Critical issues found and fixed

### 1.1 Release builds would have failed outright (AAPT2 resource linking error)
**File:** `android/app/src/main/res/drawable/launch_background.xml`, `drawable-v21/launch_background.xml`, `drawable-night/launch_background.xml`
`<item android:drawable="#FFF5F5F3" />` — a bare hex color literal used directly as a layer-list item's `drawable` attribute — is rejected by the AAPT2 resource linker in the current Android Gradle Plugin ("`'#FFF5F5F3' is incompatible with attribute drawable (attr) reference`"). This is exactly the class of bug that "worked" in `flutter analyze`/`flutter test` (neither touches native Android resources) but had never actually been through a real `flutter build appbundle` before this pass — confirmed by running one, which failed with this exact error before the fix. **Fixed** by wrapping each color in a proper `<shape><solid android:color="..."/></shape>`, which AAPT2 accepts. Re-ran the release build afterward — it now succeeds.

### 1.2 Release signing config could silently pick a broken keystore reference
**File:** `android/app/build.gradle.kts`
`key.properties` existed but every value was blank (`storeFile=` with nothing after it). `Properties.getProperty("storeFile")` on that line returns `""` (empty string), not `null` — so the old code's `if (storeFilePath != null)` check passed, set `storeFile = file("")` (a non-null `File` resolving to the project directory, not a real keystore), and the subsequent `releaseConfig.storeFile != null` check in `buildTypes.release` was then *also* true, meaning it would have selected this broken signing config instead of correctly falling back to debug signing. **Fixed**: the check is now `!storeFilePath.isNullOrBlank()`, and the buildType selection now also verifies `releaseConfig.storeFile!!.exists()` before using it.

### 1.3 A keystore existed with no recorded passwords
`android/app/release.keystore` (created 2026-06-21, before this session) had no matching entries in `key.properties` (all blank) — the passwords to actually use it were nowhere in the repo. **Per your explicit confirmation** that this keystore was never uploaded to Play Console, I moved it aside (`android/app/release_orphaned_2026-06-21.keystore`, git-ignored, not deleted — recoverable if you need it) and generated a fresh upload keystore. See §4 for what you need to do with it.

### 1.4 CI/CD was silently building debug-signed release bundles
**File:** `.github/workflows/play-store-release.yml`
The workflow ran `flutter build appbundle --release` directly with no step that ever created `android/key.properties` or decoded a keystore. Combined with issue 1.2's bug, this meant **every CI-triggered build fell back to debug signing** and would have been uploaded to Play Store's internal track that way — a real problem, since Play Store expects a consistent upload-key identity release over release. **Fixed**: added a "Set up release signing" step that decodes a base64 keystore secret and writes `key.properties` from three more secrets, plus a matching cleanup step. **You must add these secrets to the repo before the workflow will produce a properly-signed build** — see §4.

---

## 2. Security & secrets

- **`lib/config/supabase_credentials.dart`** hardcodes the Supabase project URL and a key prefixed `sb_publishable_...`. **Verified this is not a leak** — Supabase's publishable/anon keys are designed to be embedded in client apps; access control is enforced server-side via Row Level Security, not by keeping this key secret. No action needed.
- **Two raw `debugPrint()` calls** bypassed the app's existing `debugLog()` wrapper (`lib/core/utils/debug_logger.dart`, which correctly gates on `kDebugMode`). Unlike `debugLog`, bare `debugPrint` **does** write to logcat in release builds. Fixed in `lib/features/admin/presentation/screens/admin_dashboard_screen.dart` and `lib/features/share/presentation/widgets/share_link_dialog.dart` — both now route through `debugLog()`.
- **`MainActivity.kt`**'s `saveUriToCache()` had a bare `e.printStackTrace()`, which (like the Dart equivalent above) always writes to stderr/logcat regardless of build type. Removed; the exception is already handled by returning `null`.
- **`android/.gitignore`** already correctly ignores `key.properties`, `*.jks`, `*.keystore` — verified via `git check-ignore` that the new keystore, key.properties, and the orphaned-keystore backup are all excluded from version control.
- **Network security**: no `network_security_config.xml` existed. Cleartext traffic is already blocked by default at this app's target SDK, so this wasn't an active hole, but I added an explicit config (`android/app/src/main/res/xml/network_security_config.xml`, referenced from `AndroidManifest.xml`) stating that intent in source rather than leaving it implicit. Deliberately **no certificate pinning** — pinning without a rotation plan reliably breaks the app the day Supabase rotates a cert, which is a worse outcome than the risk it defends against here.

---

## 3. Permissions — principle of least privilege

The manifest declared six permissions; **five had no corresponding code path and were removed**:

| Permission | Verdict | Why |
|---|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE` | **Kept** | Required for Supabase connectivity. |
| `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` | **Removed** | All three `FilePicker.pickFiles()` call sites (`upload_modal.dart`, `profile_screen.dart`, `burn_file_creator_screen.dart`) use `withData: true`, which reads bytes via Android's Storage Access Framework through a `content://` URI — this never touches these permissions on any supported API level. |
| `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO` | **Removed** | Same reasoning — SAF-based picking doesn't need them, and there's no `permission_handler` dependency or any code that would request them. |
| `POST_NOTIFICATIONS` | **Removed** | The app has no system notifications. `_showNotificationBanner` in `main.dart` is a `ScaffoldMessenger` `SnackBar` — in-app UI, not an OS notification. This permission was pure dead weight and would have shown up unexplained in Play Console's permissions declaration form. |

No runtime permission request flow needed to be built, because after this cleanup **the app requests zero dangerous permissions** — the ideal outcome for least-privilege and for Play Store's Data Safety review.

---

## 4. Signing & Play App Signing readiness — action required

I generated a new upload keystore locally: `android/app/upload-keystore.jks`, alias `nosus-upload`, RSA 2048, 10,000-day validity. Verified it works by running an actual `flutter build appbundle --release` and confirming the output AAB's signing certificate fingerprint (`9B:4C:A0:36:EA:E2:43:47:0E:C4:FF:7D:61:05:C2:AB:73:D5:68:36:0C:7D:29:7C:67:9E:A9:30:36:56:F1:AF`) matches the new keystore exactly — the release build is genuinely release-signed, not falling back to debug.

**The passwords are written to `android/key.properties` (git-ignored) — I did not print them in this chat, and a sandboxed action to base64-export the keystore to a scratchpad file was blocked by the environment's own safety classifier as unauthorized credential materialization. That block was correct; do these steps yourself:**

1. **Back up `android/app/upload-keystore.jks` and `android/key.properties` immediately** — copy both somewhere outside this repo (password manager attachment, encrypted drive, etc.). If you lose this keystore, you cannot publish an update to this app under this signing identity again without going through Google's account-recovery process for Play App Signing.
2. **Set up CI signing** — the workflow (`.github/workflows/play-store-release.yml`) now expects four repo secrets it doesn't yet have:
   - `ANDROID_KEYSTORE_BASE64` — run `base64 -w0 android/app/upload-keystore.jks` yourself locally and paste the output as this secret's value.
   - `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD` — both equal to `storePassword` in your local `key.properties` (PKCS12 keystores require the store and key passwords to match; `keytool` enforced this at generation time).
   - `ANDROID_KEY_ALIAS` — `nosus-upload`.
   Add these under the repo's Settings → Secrets and variables → Actions.
3. **First upload to Play Console**: when you create the app listing, Play App Signing will ask you to upload this same keystore's certificate (or the AAB itself, from which it extracts the cert) — this is normal, one-time setup for the "upload key."
4. **The orphaned keystore** (`android/app/release_orphaned_2026-06-21.keystore`) is still on disk, git-ignored. Delete it once you've confirmed you don't need it, or keep it — your call.

---

## 5. Modern Android SplashScreen API

**Files:** `android/app/build.gradle.kts`, `values/styles.xml`, `values-night/styles.xml`, `MainActivity.kt`

Previously the app relied only on a pre-Android-12 `windowBackground` drawable. Added `androidx.core:core-splashscreen:1.0.1` and converted `LaunchTheme` in both light and dark `styles.xml` to extend `Theme.SplashScreen` with `windowSplashScreenBackground` (brand colors `#F5F5F3` light / `#0D0D0D` dark) and `windowSplashScreenAnimatedIcon` (the existing launcher icon), with `postSplashScreenTheme` handing off to the existing `NormalTheme`. Called `installSplashScreen()` as the first line of `MainActivity.onCreate()`, before `super.onCreate()`, as required. This gives correct, consistent behavior on API 31+ (real platform SplashScreen) and on older APIs (via the compat shim using the same theme attributes) — eliminating the old inconsistency between "whatever `windowBackground` happened to show" and the real platform splash. This native splash is intentionally brief and handed off quickly to `lib/screens/splash_screen.dart`'s `VideoSplashScreen`, which is the actual 3.2s branded boot animation and was already well-built — not touched.

---

## 6. Flutter Web branded loading screen

**File:** `web/index.html`

Previously: a blank white page until `flutter_bootstrap.js` finished loading — the exact "white flash" you asked to eliminate. Added an inline (zero extra HTTP request) loading overlay that:
- Paints on the very first frame, before any script runs.
- Uses the same black/white/grey palette and `#0A0A0A`/`#FAFAFA` colors as `VideoSplashScreen`, switching automatically via `prefers-color-scheme` so it matches whichever theme the user's OS/browser reports — verified in both modes via a live preview (see screenshots taken during this session).
- Subtle "paper texture" via a layered CSS `repeating-linear-gradient` grid (no image download).
- A pixel-inspired animated block-pulse loader and a VT323 (already-loaded pixel font) "NO SUS" wordmark.
- Removes itself via the `flutter-first-frame` event Flutter Web dispatches on real first paint, with a 12-second timeout fallback so a missed event can never leave it stuck on screen.
- **Bug caught and fixed during verification**: the first version had light-mode text/block color overrides declared *before* the dark-mode base rules in the stylesheet, so equal-specificity cascade let the later dark rules win regardless of the media query — light mode rendered near-invisible text. Fixed by consolidating all light-mode overrides into one block placed last in the stylesheet. Re-verified both themes render correctly and the removal transition fires correctly (tested by manually dispatching the `flutter-first-frame` event).

---

## 7. Play Store content & compliance

Found already in solid shape from a prior session — verified rather than rebuilt:
- **Privacy Policy** (`web/privacy.html`) and **Terms of Service** (`web/terms.html`) are real, hosted, publicly-accessible pages (served via GitHub Pages / nosus.foo), not just in-app text — satisfies Play Console's Data Safety requirement for a public URL.
- **Account deletion compliance**: both an in-app flow (Profile → Danger Zone → Delete User Account, `profile_screen.dart`) and a web-based request path (`web/account-deletion.html`) exist, satisfying Play's account-deletion policy (in-app **and** externally-discoverable deletion, since not everyone can access the app to delete in-app).
- **Updated** `privacy.html` to mention the Burn Files feature (previously only described Burn Notes) and to disclose the device-integrity/root-detection security signal collection added in a prior hardening pass — this data wasn't previously mentioned and Data Safety disclosures should match what the app actually collects.
- **App icon / adaptive icon**: confirmed fully generated — `mipmap-anydpi-v26/launcher_icon.xml` correctly references background/foreground/monochrome layers, all density buckets present (`mdpi` through `xxxhdpi`). `flutter_launcher_icons` config in `pubspec.yaml` is consistent with what's on disk.
- **Versioning**: `pubspec.yaml`'s `version: 1.1.0+7` is the single source of truth — `build.gradle.kts` correctly derives `versionCode`/`versionName` from it (`flutter.versionCode`/`flutter.versionName`), not a separately-hardcoded value. **You must bump this** before your next real Play Console upload if 1.1.0+7 was ever previously submitted (even the earlier debug-signed CI runs count, if any actually reached Play Console).
- **`targetSdkVersion`/`compileSdkVersion`**: confirmed as `36` by reading the installed Flutter SDK's own Gradle defaults directly (not assumed) — comfortably meets Play Store's current minimum target SDK requirement.

---

## 8. Dead code, dependencies, debug artifacts

- **TODO/FIXME/HACK comments**: zero found anywhere in `lib/`.
- **`debugPrint`/`print` outside the safe wrapper**: only the two instances fixed in §2 — otherwise clean.
- **Unused pubspec dependencies**: checked every dependency in `pubspec.yaml` against actual `import` usage in `lib/` — all 19 production dependencies are used at least once. Nothing to remove.
- **`assets/icon/founder_avatar.jpeg`**: not referenced anywhere in code or `pubspec.yaml`'s asset list, and not part of the app bundle either way (not in a declared runtime-assets folder). Flagging rather than deleting — I don't have context on whether this is intentionally-kept personal/reference material.

---

## 9. Accessibility — audited, largest remaining gap

- **Text scaling**: no `textScaleFactor`/`TextScaler` override found anywhere — the app respects the OS/user font-size setting by default, which is the correct, accessible behavior. No action needed.
- **Contrast**: the app's light/dark palettes (`NoSusTheme`) use near-black-on-near-white and near-white-on-near-black text, which comfortably clears WCAG AA at the sizes used. Secondary/subtle text (`lTextSecondary #666666` on `#F5F5F3`, `dTextSecondary #999999` on `#0D0D0D`) is in the acceptable range for body text but worth a manual spot-check on the smallest label sizes (9-10px) used in a few badge/chip components.
- **Semantics**: explicit `Semantics()` widgets appear in only 5 files out of 135+. This app makes heavy use of `GestureDetector`-wrapped custom containers as buttons throughout (rather than `ElevatedButton`/`InkWell`/`TextButton`), which do **not** get automatic screen-reader semantics (a screen reader won't announce them as tappable, won't read a label) and have no guaranteed minimum touch-target size. This is systemic — it appears in nearly every custom card/button across `groups_screen.dart`, `group_detail_screen.dart`, `workspace_tab.dart`, `vault_tab.dart`, and others.
  - **Why I didn't attempt a sweeping fix**: converting dozens of `GestureDetector`s across the app to properly-labeled, correctly-sized semantic buttons is a large, cross-cutting change that needs visual/screen-reader verification per screen to avoid regressions — doing it blind in a single pass risks introducing new bugs in a task whose explicit priority is stability. This is the single most valuable next accessibility investment; I'd recommend tackling it screen-by-screen with TalkBack/VoiceOver testing rather than as a batch find-and-replace.
  - **Touch targets**: several small icon-only tap targets (e.g., dismiss/close icons at 16-20px) are below Android's 48dp recommended minimum. Same recommendation as above — fix alongside the Semantics pass since both need the same widget-level changes.

---

## 10. Known upstream issue (not fixable in this repo)

The release build emits this warning (does not fail the build today, but Flutter says it will in a future version):

```
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP):
device_info_plus, file_picker, package_info_plus, passkeys_android, rive_common,
screen_protector, share_plus, ua_client_hints
```

This is a plugin-ecosystem migration (Flutter's move to "Built-in Kotlin") that depends on each plugin's maintainers shipping an update — not something fixable from this app's code. **Action for later**: periodically run `flutter pub outdated` and upgrade these packages; if this warning becomes a hard build failure in a future Flutter version, you'll need updated versions of whichever plugins haven't migrated yet.

---

## 11. Recommended but not done (scope/risk judgment calls)

- **`google_fonts` runtime fetching**: the app uses `google_fonts` without `GoogleFonts.config.allowRuntimeFetching = false`, so on a cold cache it fetches Inter/Outfit font files from Google's font CDN at runtime rather than bundling them as local assets. This is extremely common practice and not something Play Store's Data Safety flow requires disclosing, but it does mean first-launch-while-offline can show a fallback system font briefly, and it's a network call to a third party the app's own privacy policy otherwise avoids ("we do not use third-party advertising or tracking SDKs"). Proper fix is bundling the actual `.ttf` files as local Flutter assets — I didn't do this myself since it requires sourcing real font binaries, which isn't something to fetch blind from an arbitrary source. Recommended as a follow-up if startup reliability on flaky connections matters to you.
- **Accessibility Semantics/touch-target sweep** — see §9.

---

## 12. Play Store submission checklist

- [x] `targetSdkVersion` meets current Play Store minimum (36)
- [x] Release build produces a correctly-signed AAB (verified via cert fingerprint match)
- [x] Minification + resource shrinking enabled (`isMinifyEnabled`/`isShrinkResources = true`), ProGuard rules present and cover Flutter engine, plugin channels, Supabase/Ktor/OkHttp, Gson/Kotlin serialization
- [x] Manifest declares only permissions the app actually uses
- [x] `android:allowBackup="false"` (already set — avoids leaking sensitive local data via auto-backup)
- [x] `android:exported` correctly set on the one exported activity (required for API 31+)
- [x] Modern SplashScreen API implemented, no launch flicker
- [x] Web loading screen replaces blank white page, matches brand, no white flash
- [x] Privacy Policy — hosted, public URL, accurate to current data collection
- [x] Terms of Service — hosted, public URL
- [x] Account deletion — in-app AND web-accessible path
- [x] App icon + adaptive icon (background/foreground/monochrome) generated and wired up
- [ ] **You must do**: back up the new upload keystore + `key.properties` outside this repo (§4) — can't be verified from the repo either way; assume still outstanding unless you've done it
- [x] Add the four GitHub Actions secrets for CI signing (§4) — confirmed present on the repo (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, plus `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`), set 11 July 2026
- [x] `pubspec.yaml`'s `version:` has been bumped since this audit — now `1.2.0+9`
- [x] Feature graphic (1024×500) — now present at `store_listing/feature_graphic_1024x500.png` (verified exactly 1024×500px); still needs uploading in Play Console
- [ ] **Manual, can't verify from here**: screenshots for phone/tablet listing — capture from a real device or emulator per Play Console's current size requirements
- [x] Data Safety questionnaire answers drafted — `store_listing/data_safety_answers.md` maps every Play data-safety row to source-of-truth in §2/§7 below; still needs to be manually entered into the Play Console questionnaire itself
- [ ] **Manual, can't verify from here**: Internal Testing track — add tester emails in Play Console and confirm the CI-uploaded build installs and runs correctly on a real device before promoting further
- [ ] **Recommended, not done**: accessibility Semantics/touch-target pass (§9)
- [ ] **Recommended, not done**: bundle Inter/Outfit fonts as local assets instead of runtime-fetching (§11)

---

## Files changed in this pass

**Android**: `build.gradle.kts`, `AndroidManifest.xml`, `MainActivity.kt`, `values/styles.xml`, `values-night/styles.xml`, `drawable/launch_background.xml`, `drawable-v21/launch_background.xml`, `drawable-night/launch_background.xml`, new `xml/network_security_config.xml`, new `upload-keystore.jks` + `key.properties` (git-ignored, not committed)

**Web**: `web/index.html` (branded loading screen), `web/privacy.html` (content accuracy)

**Dart**: `admin_dashboard_screen.dart`, `share_link_dialog.dart` (debug-log hygiene)

**CI/CD**: `.github/workflows/play-store-release.yml` (release signing)

**Dev tooling**: `.claude/launch.json` (added a static-serve config used to visually verify the web loading screen during this pass)
