# NO SUS — Silent Security Workspace

Encrypted document-sharing workspace for students. Share notes, solutions, and research within private groups — with screenshot protection, dynamic watermarking, audit trails, and a secure blur-to-reveal viewer.

## Features

- **Encrypted File Sharing** — Client-side encryption before upload, stored securely in Supabase Storage
- **Private Study Groups** — Invite-only groups with role-based access and activity tracking
- **Secure Document Viewer** — Blur-to-reveal with touch interaction, dynamic user watermarking, and screenshot blocking (FLAG_SECURE + detection callback)
- **Audit Logging** — Every file access event is recorded and visible in real-time via Supabase Realtime
- **Key Rotation** — Rotate workspace encryption keys on demand
- **Focus Tracking** — Daily study focus minutes logged per user
- **Private Notes** — Encrypted secure pad per user
- **Dark/Light Theme** — Monochrome black-and-white aesthetic with Google Fonts (Inter + Outfit)
- **Offline Fallback** — Works with mock data when Supabase is unavailable (ideal for development)
- **Cross-Platform** — Android, iOS, Web, Windows, macOS, Linux

## Screenshots

*(Add screenshots here)*

## Quick Start

### Prerequisites

- Flutter SDK ^3.12.1
- Dart SDK ^3.12.1
- A Supabase project (free tier works) — optional, app runs in mock mode without it

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USER/no_sus.git
cd no_sus

# 2. Install dependencies
flutter pub get

# 3. Run in mock mode (no Supabase needed)
flutter run --dart-define=SUPABASE_URL= --dart-define=SUPABASE_ANON_KEY=

# 4. Or run with your Supabase project
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## Supabase Setup

1. Create a project at [supabase.com](https://supabase.com)
2. Run the migrations in `supabase/migrations/`:
   ```bash
   supabase migration up
   ```
3. The migrations create these tables:
   - `profiles` — User profiles with avatar color preferences
   - `study_groups` — Group metadata with security levels
   - `study_group_members` — Membership junction table
   - `secure_files` — File metadata with encryption keys and IVs
   - `audit_logs` — Security event trail
   - `user_notes` — Private user notes
   - `focus_logs` — Daily focus minutes tracking
4. Enable authentication providers in your Supabase dashboard:
   - **Google** — Configure OAuth client ID
   - **GitHub** — Configure OAuth client ID
   - **Phone** — Configure Twilio or use test OTPs in local dev

### Android OAuth Setup

The app expects the custom scheme `io.supabase.nosus://login-callback/` for OAuth redirects. This is already registered in `android/app/src/main/AndroidManifest.xml`. If your Supabase project uses a different URL scheme, update the `redirectTo` parameter in `lib/features/auth/data/services/supabase_auth_service.dart`.

## Environment Configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `SUPABASE_URL` | Only for live mode | Supabase project URL |
| `SUPABASE_ANON_KEY` | Only for live mode | Supabase publishable anon key |

Set via `--dart-define` when running, or copy `.env.example` to `.env`.

## Architecture

```text
Widget → Riverpod Provider → Repository Interface
                             → SupabaseRepository → SupabaseClient
                             → MockRepository (offline fallback)
```

The app uses a **feature-based architecture** with clean separation of `data/domain/presentation` layers. Riverpod handles dependency injection and reactive state management. The repository pattern provides testability and seamless offline fallback.

Key layers:
- **`lib/features/`** — Feature modules (auth, groups, files, onboarding, profile)
- **`lib/core/`** — Cross-cutting concerns (Supabase client injection)
- **`lib/services/`** — Backend services and utilities
- **`lib/components/`** — Shared UI components (secure viewer, navigation, charts)
- **`lib/config/`** — App configuration via environment variables

### ⚠️ Security Note

The current `CryptographyService` implements a stream cipher (XOR) labeled as "AES-256-GCM emulation." This is **not real AES-GCM**. It provides no authenticated encryption and no integrity verification. Do not use this for actual sensitive data without replacing it with a proper implementation (e.g., `pointcastle` or `cryptography` package).

## Development

```bash
# Run with mock data (no Supabase needed)
flutter run --dart-define=SUPABASE_URL= --dart-define=SUPABASE_ANON_KEY=

# Run with live Supabase
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-key

# Run tests
flutter test

# Analyze code
dart analyze

# Check for outdated dependencies
flutter pub outdated
```

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── theme.dart                         # Design system (NoSusTheme)
├── config/
│   └── supabase_credentials.dart      # Supabase env var config
├── core/supabase/
│   ├── supabase_bootstrap.dart        # SDK initialization
│   └── supabase_providers.dart        # Riverpod client provider
├── services/
│   ├── cryptography_service.dart      # Encryption utilities
│   ├── screenshot_guard.dart          # Screenshot blocking
│   ├── secure_db_service.dart         # Repository router
│   ├── supabase_service.dart          # Supabase operations
│   └── ...
├── components/
│   ├── floating_nav.dart              # Bottom navigation
│   ├── spyglass_viewer.dart           # Full-screen secure viewer
│   ├── study_chart.dart               # Focus chart
│   └── secure_viewer/                 # Blur-reveal + watermark
├── features/
│   ├── auth/                          # Authentication
│   ├── groups/                        # Study groups
│   ├── files/                         # Secure file management
│   ├── onboarding/                    # 6-step onboarding
│   └── profile/                       # User profile
└── screens/
    └── splash_screen.dart             # CRT pixel-art splash
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Commit your changes (`git commit -m 'feat: add my feature'`)
4. Push to the branch (`git push origin feat/my-feature`)
5. Open a Pull Request

## License

MIT License — see [LICENSE](LICENSE) for details.
