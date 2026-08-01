# Play Console → App content → Data safety — answer sheet

Derived from the actual codebase + privacy audit (see RELEASE_REPORT.md §2/§7
and web/privacy.html). Answer the questionnaire exactly as below; every row
here traces to a real code path, so the declaration can survive a Play review
against the app's observed behavior.

## Overview questions

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** (collects; does not share) |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (all traffic is HTTPS/TLS to Supabase; cleartext is blocked by network security config) |
| Do you provide a way for users to request that their data is deleted? | **Yes** — in-app (Profile → Settings → Danger Zone → Delete account) and web (`https://nosus.foo/account-deletion.html`) |

"Sharing" per Play's definition means transfer to a third party. Supabase is a
service provider processing data on your behalf → that is **not** "sharing".
Answer **No** to sharing for every data type.

## Data types to declare as COLLECTED

| Play data type | Collected? | Shared? | Processed ephemerally? | Required or optional? | Purpose(s) to tick |
|---|---|---|---|---|---|
| Personal info → **Email address** | Yes | No | No | Required | App functionality, Account management |
| Personal info → **Name** (display name) | Yes | No | No | Required | App functionality, Account management |
| Photos and videos → **Photos** (optional avatar upload) | Yes | No | No | Optional | App functionality |
| Files and docs (documents users upload to groups) | Yes | No | No | Optional | App functionality |
| App activity → **App interactions** (audit ledger: file opens, shares, membership changes, screenshot attempts; plus the activation-funnel analytics described below) | Yes | No | No | Required | App functionality, Analytics, Fraud prevention, security and compliance |
| Device or other IDs (device identifier in the device-integrity ledger; FCM push token when the user enables notifications) | Yes | No | No | Required | App functionality, Fraud prevention, security and compliance |

### Product analytics — added 2026-07-27, **this is a change to the declaration**

`public.analytics_events` (migration `20260727010000_analytics_events.sql`) plus
`lib/features/analytics/data/analytics_service.dart` record a fixed set of
activation-funnel events: app opened, welcome surface viewed, guest tool opened,
auth wall hit, signup/sign-in started and completed, onboarding
started/skipped/completed, group create/join started and completed, first
document uploaded and first document viewed, notification permission
prompted/granted/denied, tour steps, help topics opened.

This is why **Analytics** is now ticked as a purpose under App interactions.
Points a reviewer may ask about, all enforced by the schema rather than by
client discipline:

- The event name is CHECK-constrained against an allowlist in the migration. A
  new event requires a migration, not a client change.
- `properties` is constrained to a JSON object of at most 2KB and is sanitised
  client-side to primitives only. **No document names, group names, file
  contents, invite codes or share tokens are recorded** — there is no code path
  that could put one there.
- Rows are attributable to a user only when signed in; pre-auth funnel events
  are written with a null `user_id` (enforced by separate RLS policies for the
  `authenticated` and `anon` roles, so an anonymous caller cannot forge
  attribution to someone else).
- Clients are write-only. There is no SELECT policy for ordinary users; reads
  are admin-only. Deleting an account sets `user_id` to null rather than
  blocking the delete.
- No advertising or cross-app identifiers are involved, and nothing is shared
  with a third party.

Device push tokens (`public.device_tokens`, migration
`20260727030000_notifications.sql`) are declared under **Device or other IDs**
below — they exist solely to deliver notifications to the user's own device and
are deleted on sign-out.

## Data types to declare as NOT collected

Location (any), Contacts, Calendar, SMS/Call logs, Audio, Health & fitness,
Financial info, Browsing history, Search history, Installed apps, Messages
(burn notes are end-to-end encrypted ciphertext — the server cannot read
them; the decryption key never leaves the URL fragment. Declaring "Messages —
collected" would be wrong since the content is cryptographically unreadable
by the service; the stored object is opaque ciphertext).

**Crash logs / Diagnostics — currently NOT collected, but the SDK is now in
the codebase (disabled).** `sentry_flutter` was added in the production-
hardening pass and is wired into `FlutterError.onError` / the async error
zone, but stays fully inert — `lib/config/crash_reporting_config.dart`'s
`SENTRY_DSN` is empty in every build until someone deliberately sets it via
`--dart-define`/CI secret. **If you ever set `SENTRY_DSN` and rebuild, this
answer flips to "Yes, collected"** (crash logs / diagnostics, purpose: app
functionality / analytics, shared with Sentry as a service provider) — update
this file and the live Play Console questionnaire together with that change,
not after the fact.

**Measure (measure.sh) — same status, but a wider blast radius than Sentry.**
`measure_flutter` is in the codebase and wired into the `main.dart` bootstrap,
inert until both `MEASURE_API_KEY` and `MEASURE_API_URL` are set (Android only;
there is no web implementation). Enabling it flips the same Crash logs /
Diagnostics answer to "Yes, collected", shared with measure.sh as a service
provider. Three things to settle **before** flipping it, because they are not
answerable from app code:

- **Screenshot-on-crash is a server-side setting.** The SDK's
  `crash_take_screenshot` lives in its server-driven dynamic config and
  defaults to **on**; no app-side config exposes it. It must be turned off in
  the Measure dashboard. Left on, a crash inside a burn-note/burn-file viewer
  or `SpyglassViewer` can upload decrypted document content — which would make
  "the server cannot see it" false and contradicts
  `PROJECT_CONSTITUTION.md` §2.3. `FLAG_SECURE` blanks the `PixelCopy` capture
  path on API 26+ but **not** the Canvas fallback used on older devices, so it
  is mitigation, not a guarantee.
- **If screenshots stay on, this also becomes a "Photos" / in-app content
  declaration**, not just diagnostics.
- **Interaction tracking is deliberately not wired.** `main.dart` does not use
  `MeasureWidget` or `MsrNavigatorObserver`, so no click/scroll/screen-view
  timeline is collected. `ClickData` carries `label` / `semanticLabel`, which
  in this app are note titles, group names and filenames — adding either
  wrapper would start shipping user content as event metadata and change these
  answers again.

If a reviewer questions burn notes/files: content is AES-256 encrypted
client-side; key material travels only in the URL fragment, which browsers
never transmit to the server. Storage holds ciphertext only, deleted on first
read or expiry.

## Security practices section

| Question | Answer |
|---|---|
| Data encrypted in transit | Yes |
| Users can request data deletion | Yes |
| Committed to Play Families policy | No (not a kids' app) |
| Independent security review | No (don't claim one) |

## Ads declaration

**No ads.** The app contains no advertising SDK.
