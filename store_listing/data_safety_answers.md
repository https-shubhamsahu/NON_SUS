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
| Do you provide a way for users to request that their data is deleted? | **Yes** — in-app (Profile → Danger Zone → Delete User Account) and web (`https://nosus.foo/account-deletion.html`) |

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
| App activity → **App interactions** (audit ledger: file opens, shares, membership changes, screenshot attempts) | Yes | No | No | Required | App functionality, Fraud prevention, security and compliance |
| Device or other IDs (device identifier in the device-integrity ledger) | Yes | No | No | Required | Fraud prevention, security and compliance |

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
