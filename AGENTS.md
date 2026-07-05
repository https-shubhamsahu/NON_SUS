# NO SUS — AI Agent Instructions

> ⚠️ **Secondary document.** The authoritative source of truth is
> [PROJECT_HANDOVER.md](PROJECT_HANDOVER.md). The product is mid-pivot to **Sealed** (a
> reciprocity-gated intent graph). The build commands, architecture patterns, and conventions
> below remain valid; the *product framing* (study groups) is being retired.

**NO SUS** is a secure document-sharing workspace for study groups, built with Flutter, Supabase, and cryptographic audit logging. This guide helps AI agents understand architecture, conventions, and requirements for productive development.

## Quick Start

### Build & Test Commands
```powershell
# Get dependencies
flutter pub get

# Analyze code for issues
flutter analyze

# Run tests
flutter test

# Run app (requires .env file with SUPABASE_URL and SUPABASE_ANON_KEY)
flutter run --dart-define-from-file=.env
```

### Environment Setup
Create `.env` in project root:
```ini
SUPABASE_URL=https://<your-project-ref>.supabase.co
SUPABASE_ANON_KEY=<your-anon-key>
```

## Project Architecture

### Tech Stack
- **Framework**: Flutter + Dart 3.12.1+
- **State Management**: Riverpod 3.x
- **Backend**: Supabase (PostgreSQL + Auth + Storage + Edge Functions)
- **Key Libraries**: pdfrx (PDF rendering), screen_protector (Android OS-level screenshot blocking), flutter_animate, google_fonts

### Core Architecture Pattern

The codebase uses a **hybrid architecture**:

#### **Clean Architecture (Modular DDD)** — for `auth`, `groups`, and `files`
- **Domain**: Business logic entities and interfaces (e.g., `Group`, `GroupRepository`)
- **Data**: Repository implementations, Supabase clients, and models
- **Presentation**: Riverpod state providers and UI widgets
- **Pattern**: Features follow `feature/domain`, `feature/data`, `feature/presentation` structure

#### **Direct Service Calls** — for all other features (`notes`, `focus`, `onboarding`, `profile`, `vault`, `workspace`, `audit`)
- Riverpod providers query global singleton helper services:
  - `SupabaseService` — shared API client for profiles, notes, Google Drive proxy
  - `AuditService` — cryptographically chained audit ledger with SHA-256 hash chains
  - `FocusService` — study minutes tracker and database syncer
  - `ScreenshotGuardService` — Android platform channel controllers for screen protection
- Services are injected via Riverpod providers in `lib/core/providers/`

### Folder Structure

```
lib/
├── main.dart                       # App shell, navigation, entry point
├── theme.dart                      # Material 3 monochrome theme tokens
├── screens/
│   └── splash_screen.dart         # Animated CRT pixel splash
├── config/
│   └── supabase_credentials.dart  # .env loader
├── core/
│   ├── constants/                 # Magic strings, mock data
│   ├── providers/                 # Persistent theme provider
│   ├── supabase/                  # Supabase client bootstrap & injection
│   └── utils/                     # Production-gated logging
├── services/                      # Global singleton helpers
├── components/                    # Reusable UI: floating nav, document viewer, charts
└── features/                      # auth, groups, files (Clean Arch); notes, focus, etc. (service-based)

supabase/
├── migrations/                    # SQL schemas, RLS policies, RPCs
└── functions/drive-proxy/         # Google Drive Service Account Edge Function
```

## Core Concepts

### Database Schema
7 tables: `profiles` (user metadata), `study_groups`, `study_group_members`, `secure_files`, `audit_logs` (chained), `focus_logs`, `user_notes`.

**Key Security**:
- All tables have **Row Level Security (RLS)** policies enforced
- Audit logs use **RPC-only insertion** (`log_group_event`) and SHA-256 hash chains
- Database security definer functions prevent RLS recursion: `is_group_member()`, `is_group_admin()`

### Authentication
- Email-Password, Magic Link, Phone OTP flows
- Deep links captured via `AppLinks` on `io.supabase.nosus://login-callback`

### Storage
- **Supabase Storage** (private `secure-files` bucket, Cloudflare R2 backend in prod)
- **Google Drive Proxy** — Deno Edge Function at `/functions/v1/drive-proxy` for OAuth2 Service Account auth

### Security Features
- **OS-level Android screenshot blocking** (native `FLAG_SECURE` window flag)
- **Visual watermarks** — diagonal repeating email stamps on documents
- **Touch-to-reveal blurring** — document obscuration with pointer hold detection
- **Audit chain integrity** — every audit log record contains SHA-256(`actor_id + event_type + created_at + previous_hash`)

## Development Rules ✅

### DO
- **Use Clean Architecture for new features**: Implement Domain, Data, Presentation layers
- **Never bypass repositories**: Access data only through defined Repository interfaces
- **Always enable RLS**: Every new table must have Row Level Security
- **Centralize services**: No duplicate database clients; use singleton services
- **Reuse providers**: Use code generation and `ref.onDispose` for dependency scoping
- **Use theme tokens**: Leverage `NoSusTheme` typography and colors
- **Load configs from `.env`**: Never hardcode secrets or API keys

### NEVER
- **Duplicate code**: No replicated database queries or UI layouts
- **Duplicate migrations**: Use incremental, idempotent migration files
- **Duplicate providers**: One provider per model, scoped appropriately
- **Create v2/v3 files**: Keep single, updated versions
- **Leave dead code**: Remove unused imports, methods, and assets
- **Hardcode secrets**: All configuration must come from `.env`

## Common Patterns

### Riverpod Provider (Service-based Feature)
```dart
// Example: notes feature using SupabaseService singleton
final notesProvider = FutureProvider<List<Note>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  return supabase.rpc('get_notes').then(...);
});
```

### Repository Pattern (Clean Architecture Feature)
```dart
// Domain: interface
abstract class GroupRepository {
  Future<Group> fetchGroup(String id);
}

// Data: implementation
class GroupRepositoryImpl implements GroupRepository {
  final SupabaseClient _supabase;
  @override
  Future<Group> fetchGroup(String id) => _supabase.from('study_groups').select().eq('id', id);
}

// Presentation: provider
final groupProvider = FutureProvider<Group>((ref) {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.fetchGroup(ref.watch(selectedGroupIdProvider));
});
```

### Audit Logging
```dart
// Always use AuditService.log() for critical events
final auditService = ref.read(auditServiceProvider);
await auditService.log(
  eventType: 'file_download',
  metadata: {'file_id': fileId, 'group_id': groupId},
);
```

## Key Files

| File | Purpose |
|------|---------|
| [lib/theme.dart](lib/theme.dart) | Material 3 monochrome color tokens and typography |
| [lib/services/supabase_service.dart](lib/services/supabase_service.dart) | Shared Supabase API client wrapper |
| [lib/services/audit_service.dart](lib/services/audit_service.dart) | Cryptographic audit ledger with hash chain validation |
| [lib/components/spyglass_viewer.dart](lib/components/spyglass_viewer.dart) | Touch-reveal document viewer with watermarks |
| [lib/features/auth](lib/features/auth) | **Clean Architecture**: Authentication (domain, data, presentation) |
| [lib/features/groups](lib/features/groups) | **Clean Architecture**: Study group management |
| [lib/features/files](lib/features/files) | **Clean Architecture**: Secure file uploads and downloads |
| [supabase/migrations](supabase/migrations) | SQL schemas, RLS policies, cryptographic triggers |

## Known Limitations & Tech Debt

- **Cosmetic encryption badges**: "SECURED" badges are visual only; no real E2E encryption yet
- **Weak invite codes**: Simple modulo sequence; brute-force feasible (upgrade planned)
- **Theme reset on rebuild**: SharedPreferences bootstrap timing issue on app restart
- **Phone OTP**: No resend timer or rate-limit warnings
- **Android scroll physics**: iOS bouncing enforced on Android (visual inconsistency)
- **Dead feedback submissions**: Profile feedback returns success but no API wired
- **Local notification state**: Notification preferences stored in temp memory only

## Roadmap Features

- Confidential database computing (Intel SGX/AWS Nitro Enclaves)
- True AES-256-GCM client-side encryption with secure device storage
- FIDO2 hardware security key support

## Testing

- **Unit & Widget tests** in `test/` using `mocktail` for mocking
- Run `flutter test` before commits
- Focus on Riverpod provider logic and widget state transitions

## Code Style

- Follow Dart conventions (camelCase variables, PascalCase classes)
- Use `const` constructors for widgets and models
- Avoid bare exception catches; specify exception types
- Use `final` instead of `var` for better readability
- Follow folder structure: domain → data → presentation for Clean Arch features

## When to Ask for Clarification

- **Architecture decision**: Clean Architecture or Direct Service Call?
- **Database mutation**: Should it trigger an audit log?
- **New feature**: What security controls are required (RLS, watermark, screenshot blocking)?
- **Storage**: Supabase or Google Drive proxy?
- **State scope**: Global (singleton) or scoped (Riverpod)?

## References

- [Flutter Documentation](https://flutter.dev)
- [Riverpod Documentation](https://riverpod.dev)
- [Supabase Documentation](https://supabase.com/docs)
- [README.md](README.md) — Project overview and features
- [AI_HANDOVER.md](AI_HANDOVER.md) — Detailed architecture, database schema, known bugs

---

**Last Updated**: 2025 | **Flutter Version**: 3.12.1+ | **Dart Version**: 3.12.1+

## Imported Claude Cowork project instructions

# NO SUS FHE Master Architecture & Implementation Prompt

You are acting as a Principal Cryptography Engineer, Principal Software Architect, Staff Flutter Engineer, Staff Rust Engineer, Security Architect, AI Systems Engineer, and Enterprise Infrastructure Engineer.

Your responsibility is to design and implement a production-grade Fully Homomorphic Encryption (FHE) subsystem for an existing application called **NO SUS**.

This is **not** a prototype or research project. Every decision must be production-oriented, maintainable, scalable, secure, and extensible.

## Project Background

NO SUS is an existing production Flutter application built on Supabase.

Current production functionality already exists and works correctly.

Existing features include:

* Secure file storage
* AES-based encryption
* User authentication
* File sharing
* Watermarking
* Secure document viewing
* Study groups
* Event ledger / audit architecture
* Edge Functions
* Row-Level Security (RLS)

These production systems are considered stable.

The FHE project must **never** replace or modify these existing systems during development.

Instead, it must be built as a completely isolated subsystem that can later be integrated behind feature flags.

## Core Principle

AES remains responsible for storage encryption.

FHE is used only for encrypted computation.

Do not redesign the existing encryption architecture.

Instead, extend it.

Think of the system like this:

Document Storage
→ AES

Document Viewing
→ Existing System

Document Sharing
→ Existing System

Homomorphic Computation
→ TFHE-rs

The goal is to add encrypted computation without disrupting existing production behavior.

## Long-Term Product Vision

NO SUS is evolving from a secure document platform into a privacy-first forensic document intelligence platform.

Future enterprise capabilities include:

* Private AI Memory
* Selective Truth
* Encrypted policy evaluation
* Privacy-preserving AI
* Secure enterprise collaboration
* Leak attribution
* Forensic audit trails
* Device-bound cryptography
* Enterprise security

The FHE subsystem is one foundational component of this larger vision.

## Chosen FHE Library

Use **TFHE-rs** by Zama as the primary FHE engine.

Reasons:

* Rust-native
* Memory-safe
* Production-ready
* Active development
* Excellent Boolean computation
* Suitable for policy evaluation
* Suitable for encrypted comparisons
* Easy microservice deployment
* Future WebAssembly compatibility
* Better integration with a Flutter + Supabase architecture than large C++ libraries

Design the system so that another backend (e.g., OpenFHE) can be added later without changing application code.

## High-Level Architecture

Flutter App

↓

Feature Flag Layer

↓

Cryptography SDK

↓

Supabase Edge Function

↓

Rust FHE Microservice

↓

TFHE-rs Engine

↓

Encrypted Result

↓

Flutter

The Flutter application must never directly interact with TFHE internals.

## Clean Architecture

The system must follow strict dependency inversion.

Flutter depends only on abstractions.

Rust depends on interfaces.

TFHE is hidden behind an engine abstraction.

No application code outside the FHE module should know which cryptographic backend is being used.

## Rust Microservice

Implement an isolated microservice.

Suggested structure:

services/fhe-compute/

Cargo.toml

Dockerfile

src/

config/

middleware/

models/

keys/

crypto/

compute/

services/

api/

Modules inside compute:

* arithmetic
* comparison
* mux
* similarity
* serialization
* validation
* benchmarks

Each module must have isolated tests.

## Security Philosophy

Security takes priority over convenience.

Every computation must be validated before execution.

Never trust client input.

Never expose secret keys.

Never log plaintext.

Never log ciphertext.

Never log evaluation keys.

Every operation must have validation, limits, authentication, authorization, and audit events.

## Key Management

Support:

* ClientKey
* ServerKey
* CompactPublicKey
* Evaluation Keys
* Rotation
* Revocation
* Expiration
* Zeroization
* Device binding

Private keys must never be stored in Supabase.

Supabase stores only metadata.

Support future multi-device synchronization.

## Compute Model

Never execute expensive homomorphic operations synchronously.

Every compute request becomes a job.

Workflow:

Client

↓

Create Job

↓

Queue

↓

Worker

↓

TFHE Compute

↓

Persist Result

↓

Realtime Notification

↓

Client Fetches Result

Implement:

* Job queue
* Retry policy
* Cancellation
* Timeouts
* Dead-letter queue
* Fair scheduling
* Priority queue
* Capacity limits

## Compute Budget

Every job receives limits.

Limit:

* Additions
* Multiplications
* Comparisons
* MUX operations
* Circuit depth
* Execution time
* Memory usage
* Ciphertext size

Terminate jobs exceeding limits.

## Validation Layer

Before every computation validate:

* Ciphertext integrity
* Parameter compatibility
* Serialization
* Version
* Evaluation keys
* Payload size
* JWT
* Tenant
* Replay protection

Reject invalid requests immediately.

## Replay Protection

Every compute request includes:

* Nonce
* Request ID
* Timestamp
* JWT
* Signature

Prevent replay attacks using:

* Nonce cache
* Timestamp validation
* Expiration windows

## Parameter Versioning

Every ciphertext contains:

* Parameter version
* TFHE-rs version
* Serialization version
* Protocol version

Reject incompatible versions.

Support future migrations.

## Multi-Tenant Isolation

Every tenant must have isolated:

* Evaluation keys
* Cache
* Queue
* Metrics
* Worker context

Cross-tenant computation must be impossible.

## Memory Protection

Protect all sensitive memory.

Support:

* mlock on Linux
* VirtualLock on Windows
* Secure zeroization
* Read-only key storage
* Memory limits
* Secret wiping

Never persist sensitive key material.

## Observability

Expose only aggregate metrics.

Metrics include:

* Queue length
* Worker count
* CPU
* RAM
* Compute latency
* Encryption latency
* Failure rate
* Success rate

Never expose:

* User IDs
* Ciphertext
* Key fingerprints
* Plaintext
* Secret metadata

## Event Ledger

Every operation creates an append-only event.

Examples:

* fhe_key_generated
* fhe_key_rotated
* fhe_compute_started
* fhe_compute_completed
* fhe_compute_failed
* fhe_budget_exceeded
* fhe_job_cancelled
* fhe_replay_detected

Integrate with the existing NO SUS event ledger.

## Docker Security

Run as non-root.

Enable:

* Read-only filesystem
* tmpfs
* seccomp
* AppArmor
* No new privileges
* Resource limits
* Health checks
* Graceful shutdown

## Benchmarking

Benchmark:

* Key generation
* Encryption
* Decryption
* Addition
* Multiplication
* Comparison
* MUX
* Serialization
* Memory
* CPU
* Ciphertext size

Use Criterion.

Generate reproducible reports.

## Production Quality

Before any integration:

Complete:

* Validation suite
* Unit tests
* Integration tests
* Property tests
* Fuzz testing
* Load testing
* Stress testing
* Security audit
* Penetration testing
* Disaster recovery testing

## Feature Flags

Everything remains disabled by default.

Use separate flags:

* enableKeyGeneration
* enablePrivateMemory
* enablePolicyEngine
* enableHomomorphicSearch
* enableBenchmarks
* enableSelectiveTruth

Never use one global FHE flag.

## Future Product Features

### Feature 1: Private AI Memory

Users store encrypted memories.

The server performs encrypted similarity computations.

The AI never receives unrestricted plaintext.

Only authorized memories are decrypted.

### Feature 2: Selective Truth

Selective Truth is implemented internally as an **Encrypted Policy Engine**.

Instead of exposing entire documents to an LLM:

Question

↓

Encrypted Policy Evaluation

↓

Determine Allowed Content

↓

Decrypt Only Authorized Sections

↓

Construct AI Context

↓

LLM Response

The LLM must never receive unauthorized information.

## Development Philosophy

Never break production.

Never modify existing AES storage.

Never modify existing upload flow.

Never modify existing download flow.

Never modify existing sharing.

Never modify existing document viewing.

Never modify existing authentication.

Never modify existing Supabase architecture except by adding isolated FHE tables and services.

Every new capability must be additive.

## Final Objective

Build a production-grade, enterprise-ready FHE platform that enables privacy-preserving computation inside NO SUS while preserving all existing functionality.

The architecture must be modular, cryptographically sound, highly testable, horizontally scalable, secure by default, and flexible enough to support future privacy-preserving AI features, enterprise collaboration, and forensic document intelligence without requiring major architectural redesign.


make that fhe feature in this directory only and at the end integrate everything in the app to make it work seemlessly

also i have zero many to spend so suggest me big brain trick to get lots and lots of clould storage
