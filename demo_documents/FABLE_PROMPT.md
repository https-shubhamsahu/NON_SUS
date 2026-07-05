# Fable Prompt - Make NO SUS Work With Real Demo Documents

You are helping finish NO SUS for a hackathon demo. Prioritize one working workflow over broad features.

## Goal

Make NO SUS demonstrate confidential research collaboration using real uploaded documents.

The story:
Three organizations upload confidential research documents:
- Hospital Alpha
- University Beta
- Research Lab Gamma

They enter a shared collaboration workspace and click `Compare Research`.

The app must show:
- the uploaded documents were used as inputs
- raw document text is not shown to other organizations
- private research signals are compared
- FHE computes overlap/similarity over protected vectors
- AI receives only safe derived results
- output includes shared findings, similarity score, contradictions, AI summary, and collaboration opportunities
- the Trust Timeline records the workflow

## Keep / Delete

Keep:
- existing Flutter visual identity
- existing Supabase Auth
- existing group and upload flow
- existing FHE screen and provider structure
- existing Rust FHE service and Supabase Edge Function proxy
- existing Trust Timeline / Audit UI

Delete or hide from the primary demo path:
- leftover placeholder labels
- old participant names
- generic "labs experimental" wording
- fake-looking text that suggests documents are not used
- any unrelated dashboard clutter that distracts from `Upload -> Compare Research -> AI Insight`

Do not refactor the whole app. Do not redesign architecture. Do not remove working features outside the demo path.

## Required Demo Workflow

1. User signs in.
2. User creates or opens a collaboration workspace.
3. User uploads these three real files from `demo_documents/`:
   - `hospital-alpha-clinical-summary.pdf`
   - `university-beta-cohort-study.pdf`
   - `research-lab-gamma-biomarker-report.pdf`
4. The upload flow stores files using the existing secure file repository.
5. The app associates the three uploaded files with:
   - Hospital Alpha
   - University Beta
   - Research Lab Gamma
6. User clicks `Compare Research`.
7. The app extracts a safe research signal from each uploaded document.
8. The FHE workflow compares those signals.
9. The app builds a restricted AI context from only derived results.
10. The AI summary is generated from the restricted context.
11. The Trust Timeline records `Compare Research completed`.

## Document Signal Extraction

For this demo, do not build a complex NLP pipeline.

Implement a deterministic extractor that reads text from uploaded demo documents and maps keywords into a small vector:

Vector dimensions:
1. immune response timing
2. cohort outcome agreement
3. biomarker novelty

Expected vectors:
- Hospital Alpha: `[3, 2, 1]`
- University Beta: `[2, 3, 1]`
- Research Lab Gamma: `[1, 1, 3]`

Extraction can be keyword-based:
- timing / 4-8 hour / intervention / immune-response -> timing score
- cohort / statistics / outcomes / model confidence -> cohort score
- biomarker / assay / lab / marker peak -> biomarker score

If text extraction fails, show a clear unavailable state and allow manual demo vectors only as fallback. Do not crash.

## FHE Behavior

Use the existing FHE architecture:

Flutter app
-> FHE provider
-> FHE transport / repository
-> Supabase `fhe-proxy` Edge Function
-> Rust `fhe-compute` service
-> TFHE-rs computation
-> result back to Flutter

The FHE operation should compare the uploaded document vectors against the shared research question vector:

`[3, 2, 1]`

Use the existing similarity / dot-product path. Display encrypted score previews, not raw internal ciphertext.

If the FHE service is unavailable, degrade gracefully with a visible status:
`Live FHE unavailable - using local sealed demo computation`

## AI Behavior

Do not send raw documents to AI.

AI input must be only:
- top similarity score
- organization names
- derived shared findings
- derived contradictions
- derived collaboration opportunities
- permission summary saying raw documents were withheld

For demo stability, support two modes:
1. If `AI_PROVIDER` and `AI_API_KEY` are configured, call the cloud AI provider.
2. If not configured, generate deterministic AI-style summary locally from the restricted context.

The UI should be honest:
- Live cloud AI: `AI summary generated from restricted context`
- Local deterministic mode: `AI summary simulated from restricted context`

## Expected Output For Sample Documents

Similarity:
- Hospital Alpha: high
- University Beta: high
- Research Lab Gamma: exploratory / partial

Shared findings:
- Hospital Alpha and University Beta strongly agree on early intervention timing.
- All organizations discuss immune-response signals.
- Research Lab Gamma adds biomarker evidence without exposing lab notebooks.

Contradictions:
- Research Lab Gamma's biomarker peak appears later than the 4-8 hour clinical window.
- University Beta confidence drops when the Gamma-only marker is weighted too heavily.

Collaboration opportunities:
- Run a joint validation study around early intervention timing.
- Exchange only approved aggregate biomarker summaries.
- Prepare an AI briefing from safe derived findings, not raw documents.

## Acceptance Criteria

- App does not crash if upload, FHE, or AI fails.
- User can upload the three provided PDFs.
- `Compare Research` clearly references the uploaded documents.
- Raw document text is not shown in the AI summary.
- FHE status/loading states are visible.
- AI summary section is visible.
- Trust Timeline receives a `Compare Research completed` event.
- `flutter analyze` passes.
- Release APK builds.

## Judge Explanation

Say:
`Upload is the input. FHE comparison is the product. AI is only the explanation layer after privacy enforcement.`

