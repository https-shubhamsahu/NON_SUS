# Original User Request

## Initial Request — 2026-07-05T16:28:40+05:30

<USER_REQUEST>
# Teamwork Project Prompt — Draft

> Status: Launched
> Goal: Craft prompt → get user approval → delegate to teamwork_preview

Sealed: a privacy-first, reciprocity-gated intent graph built with Flutter, Supabase, and Rust TFHE-rs where intents are revealed only if mutual. The milestone is to build the core logic for the Seal flow (M1) and Matcher edge function (M2) without UI.

Working directory: C:\Users\shubh\_Active_Projects\NO_SUS\no_sus
Integrity mode: development

## Requirements

### R1. Seal Flow Logic (M1)
Implement the core logic for the Seal flow in Flutter (domain, data, presentation layers via Riverpod). This includes handling the state for assigning an arena, encrypting the user's intent choice using `FheTransport`, and persisting the seal to Supabase. No UI implementation is required.

### R2. Pact Matcher Edge Function (M2)
Implement the `pact-matcher` edge function in Supabase. On invocation for a new seal, it should locate any counter-seals, evaluate the FHE predicate via `pact_evaluate` through `fhe-proxy`, decrypt the result, and insert a row into the `matches` table if the evaluation is true.

### R3. Additive Architecture
You must strictly adhere to the additive FHE architecture. Rely on the existing `FheTransport` and `fhe-proxy` bridge. Do not modify the FHE Rust microservice or the legacy document storage system.

## Acceptance Criteria

### Verification Tests
- [ ] A Dart unit test suite exists and passes, demonstrating that a seal intent correctly generates an FHE ciphertext and calls the repository insert method.
- [ ] A local Deno test script exists and passes, verifying that the `pact-matcher` edge function processes inputs, correctly sequences the `pact_evaluate` and `decrypt` API calls, and inserts a match on a `true` decryption.

### Implementation Constraints
- [ ] The `sealed` feature uses Riverpod and Clean Architecture (domain, data, presentation) for the frontend logic.
- [ ] The `pact-matcher` edge function is written in TypeScript for Deno and is structured to handle Supabase Webhooks or direct invocations cleanly.
- [ ] Existing `secure_files` logic and Rust TFHE-rs engine code remain untouched.

---
*Next: when approved → delegate via invoke_subagent (see Delegation Protocol)*
</USER_REQUEST>
