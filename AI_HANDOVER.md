# NO SUS Overview

* **Description**: NO SUS is a secure document-sharing workspace designed for student study groups.
* **Target Users**: Students and study cohorts sharing lecture notes, review sheets, and study materials securely.
* **Core Philosophy**: Absolute accountability through immutable logs and anti-leak screen controls.

# Current Production Architecture

The application is built in Flutter using a hybrid layout:
- **Modular Clean Architecture**: Used by `auth`, `groups`, and `files` modules to separate business domains from external frameworks.
- **Direct Service Singletons**: Features like `notes`, `focus`, and `onboarding` directly query global singletons (`SupabaseService`, `AuditService`, `FocusService`) wrapped in simple Riverpod state providers.

# Repository Structure

```
no_sus/
├── lib/
│   ├── services/       # Core singleton helper classes
│   ├── components/     # Document rendering and nav controls
│   └── features/       # Modular application components
├── supabase/
│   ├── migrations/    # Database SQL schemas & RLS
│   └── functions/     # Google Drive Service Account Edge Function
└── test/              # Code verification tests
```

# Current Database Schema

The PostgreSQL schema on Supabase consists of 7 tables:
- **`profiles`**: User metadata mapped 1:1 to Supabase Auth UUIDs.
- **`study_groups`**: Group namespaces with unique invite codes.
- **`study_group_members`**: Membership links with `is_admin` parameters.
- **`secure_files`**: Document metadata references (owner, uploader, sizes).
- **`audit_logs`**: Immutable sequentially chained activity ledger.
- **`focus_logs`**: Track daily student study minutes.
- **`user_notes`**: Private user scratchpads.

### Row Level Security (RLS) & RPCs
- **RLS Policies**: Implemented on all tables. Database queries verify permissions via security definer helper functions (`is_group_member`, `is_group_admin`) to avoid policy recursion.
- **Audit Ledger RPC**: Client-side inserts on `audit_logs` are blocked. Logs can only be appended using the `log_group_event` RPC. Tamper status is validated using `verify_audit_chain()`.

# Authentication Flow

Authentication is managed via Supabase Auth:
- **Flows**: Email-Password, Magic Link, and Phone OTP.
- **Deep Links**: Supported using `AppLinks` on `io.supabase.nosus://login-callback` to capture authentication session returns from external mobile browsers.

# Storage Architecture

- **Supabase Storage**: Files are stored in a private `secure-files` bucket. Access to files is verified by checking that the user is a member of the study group associated with the document metadata.
- **Cloudflare R2**: Used in production as an S3-compatible backend for Supabase Storage.
- **Google Drive Proxy**: To avoid expired access tokens, Google Drive files are proxied through a Deno Edge Function at `/functions/v1/drive-proxy`. The function authorizes requests using the Supabase client `anonKey` and performs OAuth2 Service Account authentication with Google Workspace.

# Current Security Model

- **OS-level Screen Protection**: Android screenshots and screen sharing are blocked via native window flags (`FLAG_SECURE`). Screen capture events trigger warnings. No OS screen protection is implemented for iOS.
- **Visual Stamping**: Diagonal repeating watermarks showing user email parameters are rendered over document canvases.
- **Visual Obscuration**: A touch-reveal blur layer obscures document content unless the user holds down their pointer on the screen.
- **Audit Chain Integrity**: Every audit log record contains an `entry_hash` computed as `SHA-256(actor_id + event_type + created_at + previous_hash)`.

# Current Features

- **Auth Portal**: Login and sign-up with email verification.
- **Workspace Navigation**: Custom 5-tab floating bottom navigation bar.
- **Study Groups**: Create and join groups using invite codes.
- **File Management**: Upload, pin, download, and delete PDFs/images.
- **Google Drive Linking**: Add Google Drive files to study groups.
- **Secure Reader**: Touch-to-reveal blurred document viewer with watermarks.
- **Notepad**: Local autosaving scratchpad.
- **Focus Timer**: Track study session stopwatch counts.
- **Audit Views**: Interactive screen showing group access trails.

# Known Bugs

- **Theme Reset on Rebuild**: Persistent theme parameters reset on app restarts if the SharedPreferences bootstrap executes late.
- **Phone OTP Timer Lack**: Phone OTP interface lacks resend timers or rate-limit warnings.
- **Android Scroll Physics**: Bouncing iOS scroll physics are enforced on Android devices, causing visual platform inconsistency.
- **Onboarding Step Skipping**: Tapping skip on the first onboarding page redirects straight to the last page, bypassing identity creation steps.

# Technical Debt

- **Cosmetic Encryption Badges**: "SECURED" badges and "Tap to Decrypt" text are cosmetic. Real end-to-end client-side encryption is not currently implemented in the code.
- **Dead Feedback Submissions**: Profile screen feedback submissions return success snackbars but are not wired to any API endpoint or database table.
- **Weak Invite Codes**: Invite codes follow a simple modulo integer sequence, making brute-force guessing feasible.
- **Local Notification States**: Notification preferences in profiles are saved in temporary local memory states only.

# Future Roadmap

- **Confidential Database Computing**: Intel SGX/AWS Nitro Enclave support to secure PostgreSQL data.
- **Confidential Key Stores**: True AES-256-GCM client-side encryption with device storage managed by `flutter_secure_storage`.
- **FIDO2 Hardware Keys**: Support for hardware biometric security keys.

# Critical Files

- `lib/services/screenshot_guard.dart`: Manages native platform channels.
- `lib/components/secure_viewer/`: Renders watermarks and touch-reveal overlays.
- `supabase/migrations/`: Database schemas, RLS rules, and cryptographic triggers.

# Development Rules

- **Use Clean Architecture for new features**: Implement Domain, Data, and Presentation layers for new features.
- **Never bypass repositories**: Access data layers only through defined Repository interfaces.
- **Never bypass RLS**: Ensure every new table has Row Level Security enabled.
- **Never duplicate services**: Centralize database and API clients in shared service classes.
- **Never duplicate providers**: Reuse Riverpod providers and scope dependencies using code generation or ref.onDispose.
- **Remove dead code**: Clean up unused imports, dead methods, and obsolete assets.
- **Never hardcode secrets**: Load all configurations from `.env` files.
- **Reuse existing widgets**: Utilize typography tokens and colors from `NoSusTheme`.

# Never Do

- **Duplicate code**: Do not replicate database queries or UI layouts.
- **Duplicate migrations**: Do not write overlapping migrations; use incremental, idempotent files.
- **Duplicate providers**: Avoid creating redundant state providers for the same model.
- **v2/v3 files**: Keep single, updated version files; do not create suffix-versioned files.
- **Dead code**: Do not leave commented-out blocks or unused helper methods.
- **Unused assets**: Remove screenshots or files not referenced in documentation.

# Required Environment Variables

- `SUPABASE_URL`: Active Supabase URL.
- `SUPABASE_ANON_KEY`: Target project anon key.

# Build Commands

```powershell
# Setup dependencies
flutter pub get

# Static analysis checks
flutter analyze

# Execute test suite
flutter test

# Build release APK
flutter build apk --release --dart-define-from-file=.env

# Build Android App Bundle
flutter build appbundle --release --dart-define-from-file=.env
```

# Manual Verification Checklist

- [ ] **Google Login**: Validate Google login redirects and callbacks.
- [ ] **Deep Links**: Open `io.supabase.nosus://login-callback` via CLI to recover session state.
- [ ] **Supabase Auth**: Complete Email-Password signup and OTP phone validation flows.
- [ ] **R2 Upload**: Upload documents to the private bucket and confirm storage path RLS rules block external access.
- [ ] **R2 Delete**: Confirm deletion requests successfully remove files from the storage bucket.
- [ ] **Google Drive Proxy**: Link a Drive document, verify download streams work, and test Edge Function delete API triggers.
- [ ] **File Upload**: Check that files are uploaded securely and trigger audit log events.
- [ ] **File Delete**: Confirm files can be deleted by owners and group admins.
- [ ] **Watermark**: Open documents and check that user email watermarks render diagonals.
- [ ] **Group Creation**: Create new groups and verify invite code formatting.
- [ ] **Notes Autosave**: Edit the notepad, navigate away immediately, and check that notes sync to database on dispose.
- [ ] **Notifications**: Confirm notification toggles update UI states.
- [ ] **Theme Persistence**: Verify light/dark settings persist across application restarts.
- [ ] **flutter analyze**: Confirm static analysis returns zero issues.
- [ ] **flutter test**: Ensure all test suites pass.
- [ ] **Release Build**: Confirm release builds build and launch without exceptions.
