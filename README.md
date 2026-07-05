# NO SUS

> ⚠️ **This document is secondary and partly out of date.** The authoritative, current source of
> truth is [PROJECT_HANDOVER.md](PROJECT_HANDOVER.md). The project is mid-pivot from the
> research-collaboration framing below to **Sealed** (a reciprocity-gated intent graph on the same
> stack). Read the handover first.

**NO SUS** is a privacy-first research collaboration workspace where organizations can compare confidential documents, discover overlap, find contradictions, and generate AI-assisted collaboration insights without exposing their raw documents to each other.

The core idea is simple:

```text
Upload confidential documents
  -> derive private research signals
  -> compare encrypted signals with FHE
  -> give AI only safe derived results
  -> record the workflow in a trust ledger
```

NO SUS is built for situations where multiple teams need to collaborate, but the documents are too sensitive to share directly.

## Demo Story

Three organizations have confidential research:

- **Hospital Alpha**: clinical outcomes around early sepsis-risk intervention
- **University Beta**: statistical cohort research
- **Research Lab Gamma**: biomarker research with a timing contradiction

They enter a shared collaboration workspace and run **Compare Research**.

NO SUS does not reveal one organization's source document to another. Instead, it returns only:

- shared findings
- similarity / overlap score
- contradictions
- AI summary
- collaboration opportunities
- trust timeline event

The key demo line:

> Upload is the input. FHE comparison is the product. AI is only the explanation layer after privacy enforcement.

## Why This Matters

Normal collaboration tools force a bad tradeoff:

- share documents and risk exposing confidential information, or
- keep documents private and lose collaboration value.

NO SUS creates a third path:

> collaborate on the meaning of private documents without exposing the documents themselves.

This is useful for research teams, hospitals, universities, labs, enterprise security teams, legal review, and any setting where organizations need joint intelligence from sensitive material.

## Architecture

```text
Flutter App
  -> Supabase Auth
  -> Supabase Postgres metadata + RLS
  -> Private document storage
  -> Supabase Edge Function FHE proxy
  -> Rust FHE Compute Service
  -> TFHE-rs encrypted computation
  -> restricted AI context
  -> AI summary / deterministic fallback
  -> Trust Timeline audit event
```

### Frontend

- **Flutter** mobile app
- Riverpod state management
- Secure workspace, groups, upload flow, and Compare Research demo
- Demo-ready workflow for uploaded research documents

### Backend

- **Supabase Auth** for identity
- **Supabase Postgres** for metadata, groups, files, jobs, and audit records
- **Row Level Security** so users only access authorized rows
- **Supabase Edge Functions** as security gates between the app and backend services

### Compute

- **Rust FHE compute service**
- **TFHE-rs** for homomorphic encrypted computation
- FHE is used for computation, not file storage

### Trust Layer

- Cryptographic audit ledger with chained hashes
- Trust Timeline records important workflow actions
- Smart-contract ready design: future on-chain anchoring can publish ledger root hashes without exposing private data

## How Data Is Stored

NO SUS separates file bytes from metadata.

### File Bytes

Documents are stored in private storage. The app can use Supabase Storage and also includes architecture for proxy-backed or multi-cloud storage.

### Metadata

Supabase Postgres stores metadata such as:

- file id
- owner id
- group id
- storage path
- file type
- size
- security status
- audit references

The database does not need to expose another organization's raw document contents to produce collaboration intelligence.

## Encryption Model

NO SUS uses different protection layers for different jobs:

- **TLS** protects network transport
- **Supabase Auth + RLS** protects access to database rows
- **Private storage** protects uploaded document bytes
- **AES-style storage encryption** protects documents at rest
- **FHE** protects computation over private signals
- **Hash-chained audit logs** protect trust history

Important distinction:

> AES protects storage. FHE protects computation.

FHE is not used to store whole PDFs. FHE is used when the system needs to compare private research signals without revealing those signals to the server or other organizations.

## How FHE Works In NO SUS

Each uploaded research document maps to a small private research signal.

For the demo documents, the signal dimensions are:

1. immune-response timing
2. cohort outcome agreement
3. biomarker novelty

Example demo vectors:

- Hospital Alpha: `[3, 2, 1]`
- University Beta: `[2, 3, 1]`
- Research Lab Gamma: `[1, 1, 3]`

The Compare Research flow compares these protected vectors against the shared research question. The FHE service can compute similarity-style scores while preserving the privacy boundary.

The app displays only safe results:

- encrypted score preview
- similarity score
- shared findings
- contradictions
- collaboration opportunities

## How AI Works

The AI layer does not read raw confidential documents.

The AI receives only a restricted context after the privacy pipeline has already run:

```text
safe similarity result
shared findings
contradiction labels
permission summary
collaboration opportunities
```

In the demo build, the AI insight layer can be deterministic for reliability. In production, the same restricted context can be sent to a hosted AI service, private enterprise model, or local LLM.

The privacy boundary is before AI:

> NO SUS uses AI after privacy enforcement, not before it.

## Real Document Demo Files

The repository includes synthetic demo documents in `demo_documents/`.

Recommended upload order:

1. `hospital-alpha-clinical-summary.pdf`
2. `university-beta-cohort-study.pdf`
3. `research-lab-gamma-biomarker-report.pdf`

Expected outcome:

- Hospital Alpha and University Beta show strongest overlap
- Research Lab Gamma contributes the key contradiction
- AI summary discusses only derived findings, not raw document text

## Smart Contract Readiness

The current trust layer is a cryptographic audit ledger stored in the backend.

The smart contract extension is **on-chain audit anchoring**:

- do not store documents on-chain
- do not store user data on-chain
- do not store AI summaries on-chain
- only store a ledger root hash, workspace hash, timestamp, and event count

This proves the audit ledger existed at a certain time and was not modified later, while keeping private research data off-chain.

## Tech Stack

- Flutter
- Dart
- Riverpod
- Supabase Auth
- Supabase Postgres
- Supabase Edge Functions
- Row Level Security
- Rust
- TFHE-rs
- Deno

## Local Setup

Create `.env` in the project root:

```ini
SUPABASE_URL=https://<your-project-ref>.supabase.co
SUPABASE_ANON_KEY=<your-anon-key>
```

Install dependencies:

```powershell
flutter pub get
```

Run static analysis:

```powershell
flutter analyze
```

Run the app:

```powershell
flutter run --dart-define-from-file=.env
```

Build Android release APK:

```powershell
flutter build apk --release --dart-define-from-file=.env
```

## Rust FHE Service

```powershell
cd services/fhe-compute
cargo check
cargo run
```

## Supabase Functions

FHE proxy:

```powershell
supabase functions deploy fhe-proxy
```

Storage router, optional:

```powershell
supabase functions deploy storage-router
```

## Demo Script

1. Sign in to NO SUS.
2. Open or create a collaboration workspace.
3. Upload the three demo research PDFs.
4. Go to **Workspace**.
5. Open **Compare Research**.
6. Run the comparison.
7. Show encrypted overlap scores.
8. Show shared findings, contradictions, and collaboration opportunities.
9. Explain that AI only receives safe derived results.
10. Open the Trust Timeline and show the recorded event.

## One-Sentence Pitch

NO SUS lets organizations collaborate on confidential research without exposing the raw documents, by combining private storage, encrypted computation, AI over restricted context, and a cryptographic trust ledger.
