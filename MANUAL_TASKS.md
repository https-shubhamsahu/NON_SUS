# MANUAL_TASKS.md — what only you can do

Operator checklist. **Not** project guidance — [`AGENTS.md`](./AGENTS.md) remains the single source
of truth for how the code works. This file only lists work that needs a human: a console login, a
credential, a physical device, or a product decision.

Every item below was re-verified against the live project on **2026-07-30**. Where a claim came from
a document rather than a check, it says so.

Legend: 🔴 blocks a real user-facing feature · 🟡 blocks a release step · ⚪ hygiene / optional

---

## Where each task has to be done

Nothing here can be done from the repo alone — each item needs a different console, credential, or
piece of hardware. Grouped by where you have to be, so you can batch a trip to each one.

| Platform | Outstanding | Section |
|---|---|---|
| **Google Cloud console** | Enable the Play Android Developer API on project `694624182770` | §1a 🟡 |
| **Play Console** | Service-account permissions · feature graphic · screenshots · Data Safety · testers | §1a, §2 🟡 |
| **Firebase console** (`no-sus-isagi0011`) | Generate an FCM service-account key → 3 secrets | §3 🔴 |
| **Supabase dashboard** | `send-push` deploy · FCM/burn/integrity secrets · `app_latest_version` · one pending migration | §0c, §1b, §3 🔴 |
| **GitHub** | `GOOGLE_SERVICES_JSON_BASE64` repo secret · merge or close the pushed fix branch | §3, §0b 🔴 |
| **This machine** | Back up the keystore · delete the orphaned one · decide on the working tree | §0b, §4 ⚪🔴 |
| **Physical Android device** | Hot-restart verification of this session's fixes · `migrate_device_id()` · stale-group file access | §5 🟡 |
| **Product decision, no console** | `google_fonts` runtime fetch · stale migration file · Stage 2 attestation | §5b, §6, §7 ⚪ |

---

## 0. 🔴 An entire feature set is built but not shipped

This is the biggest gap. The database half is now done (§0a), but it is still **not** on the Play
Store and **not** committed — it is sitting in your working tree.

`git status` shows ~48 changed/new files implementing:

| Subsystem | Files |
|---|---|
| Notifications (inbox + FCM push + prefs) | `lib/features/notifications/`, `supabase/functions/send-push/`, `android/.../NotificationChannels.kt` |
| Settings screens | `lib/features/settings/` |
| Help centre | `lib/features/help/` |
| Product analytics | `lib/features/analytics/` |
| Onboarding rewrite | `welcome_screen.dart` + `get_started_screen.dart` replacing the deleted 6-step flow |
| Group moderation | `supabase/migrations/20260730112424_group_moderation.sql` |
| Private-group boundary | `supabase/migrations/20260730112222_private_group_boundary.sql` |
| Coach marks / tours | `lib/components/coach_mark.dart`, `tour_providers.dart` |

**State of it:** `flutter analyze` is clean and `flutter test` passes 101/101 with all of this in the
tree (re-verified 2026-07-30 — the count rose from 59 because the same working tree adds six new
test files). So the code is in good shape — it just was never committed.

**Consequence:** tag `v1.3.0` points at commit `6015dc3`, which contains **none** of it. The APK
attached to [the v1.3.0 release](https://github.com/https-shubhamsahu/NON_SUS/releases/tag/v1.3.0)
is the *old* app. If you install it expecting notifications or settings, they will not be there.

### 0a. ✅ The migrations are applied — 2026-07-30

Applied to project `rxfnazmusofikwaggntb` in order, each returning success:

```
20260730112222_private_group_boundary
20260730112308_analytics_events
20260730112424_group_moderation
20260730112523_notifications
20260730115330_enable_realtime_notifications
20260730162359_enable_realtime_user_risk_state   ← added 2026-07-30, see §0d
```

The local files were **renamed from their original `20260727*` names to these versions** so that
filenames match `supabase_migrations.schema_migrations` exactly and `supabase db push` is a no-op.
Their bodies are unchanged apart from comment trimming in the copy that was executed.

Verified after the fact, as a real signed-in non-member of a private group:

| Check | Result |
|---|---|
| Groups visible | only the two the account belongs to |
| Private group's `invite_code` | blocked |
| Private group's files | 0 rows |
| Self-insert into that group | `42501: new row violates row-level security policy` |

Security advisor: no new ERROR-level findings. One new WARN it did raise is fixed by
`20260730120000_revoke_internal_function_execute.sql`, which is **written but not applied** — see
§0c.

### 0b. Decide what to do with the working tree

Still your call. **A small slice has now been committed and pushed** — branch
`fix/runtime-errors-from-logcat`, two commits, `main` untouched:

```
7cda72f  fix(audit): stop logging group events for groups the user has left
6f61e02  fix: four runtime errors caught via logcat/VM-service monitoring
```

Those carry **only** runtime bug fixes found by monitoring the app on device (deep-link OAuth race,
setState-during-build, a Riverpod life-cycle assert, a uuid placeholder, and the audit membership
gate), staged hunk-by-hunk so none of the unshipped feature work rode along. Merge or close it
independently of the decision below.

Two of those fixes **could not** be committed and exist only on disk: the `ListTile`/`Material` ink
fixes in `profile_screen.dart` and `settings_section.dart`. They sit inside code that only exists in
the uncommitted tree (`_GroupRow` has no counterpart in `HEAD`; `settings_section.dart` is untracked
entirely). They ship when the feature work ships — there is no way to split them out first.

The bulk remains: **47 tracked changes, 34 untracked files.**

- **Ship it** → commit, bump to `1.4.0`, tag, let CI build. (The migrations are already applied.)
- **Park it** → `git stash` or a WIP branch so `main` stops carrying an unshipped diff.

### 0c. ⬜ One follow-up migration is pending

`supabase/migrations/20260730120000_revoke_internal_function_execute.sql` revokes the default
PUBLIC execute grant from the two new trigger functions (PostgREST otherwise lists them at
`/rest/v1/rpc/`), and from `group_member_label` / `is_group_banned`, which are only ever called from
inside SECURITY DEFINER bodies. Calling a trigger function through the API always fails anyway, so
nothing is exploitable — this is linter hygiene and least privilege, not an incident.

```bash
supabase db push
```

⚠️ Before you run that, know what else `db push` will pick up. Two local filenames do **not** match
the versions recorded in `supabase_migrations.schema_migrations`, so push treats them as new:

| Local file | Ledger version | What push does |
|---|---|---|
| `20260730130000_enable_realtime_notifications.sql` | recorded as `20260730115330` | re-runs it — **safe**, the body is a guarded `DO` block that swallows `duplicate_object`, but it writes a second ledger row for the same change |
| `20260707030000_restore_community_rpcs.sql` | recorded as `20260706223526` | re-runs it — safe (`CREATE OR REPLACE`), but see §7, its premise is wrong |

Neither breaks anything. Rename them to match the ledger if you want push to be a true no-op.

### 0d. ✅ Realtime for `user_risk_state` — applied 2026-07-30

`SupabaseService.watchMyRiskState()` failed for **every** account with
`RealtimeSubscribeException(status: channelError)` — observed live on device for two different users.
Cause: `public.user_risk_state` was never added to the `supabase_realtime` publication. There are
explicit `enable_realtime_*` migrations for `share_view_events` and `notifications`; the equivalent
for this table was never written.

Applied as `20260730162359_enable_realtime_user_risk_state` and verified after the fact: in the
publication ✓, `replica_identity = f` ✓, RLS still enabled ✓. `REPLICA IDENTITY FULL` is needed so
the client's `user_id=eq.<uuid>` filter still matches on DELETE — with the default identity a delete
carries only the primary key and the filter drops it.

Nothing further to do here; the fix is server-side and took effect immediately, independent of any
app build. The migration file is on the pushed branch (§0b), so the file and the ledger only agree
once that branch merges.

---

## 1. 🟡 Release pipeline

### 1a. Enable the Google Play Android Developer API

The `v1.3.0` run built and published the GitHub release fine, then failed the last step with:

> Google Play Android Developer API has not been used in project **694624182770** before or it is
> disabled.

This failed identically on 17 July, so it is a standing gap, not a flake.

1. Open <https://console.developers.google.com/apis/api/androidpublisher.googleapis.com/overview?project=694624182770>
2. **Enable**
3. Wait a few minutes for propagation
4. Confirm the service account behind `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` is invited in
   **Play Console → Users and permissions** with *Release to testing tracks* on `foo.nosus.app`
5. Re-run the workflow via **Actions → Play Store Release → Run workflow** — `workflow_dispatch` is
   wired, so **no new tag is needed**

### 1b. Bump `app_latest_version` — only when you mean it

`public.remote_configs` currently holds `app_latest_version = "1.2.0"` (last touched 2026-07-17).
Raising it to `1.3.0` makes every existing install show the update banner immediately. Deliberately
left alone — it is a user-facing announcement, not a build step.

```sql
update public.remote_configs
   set config_value = '"1.3.0"'::jsonb, updated_at = now()
 where config_key = 'app_latest_version';
```

Do this **after** the build is actually downloadable, or you point users at something that isn't
there. If you ship §0 as `1.4.0`, skip `1.3.0` and set that instead.

---

## 2. 🟡 Play Console listing

Drafted in `store_listing/`, never uploaded. Still outstanding per `AGENTS.md` §9 (documented, not
independently verifiable from here):

- Feature graphic — `store_listing/feature_graphic_1024x500.png` is ready to upload
- Phone + tablet screenshots (`assets/screenshots/` has raw material)
- Data Safety questionnaire — answers drafted in `store_listing/data_safety_answers.md`
- Internal Testing testers list

⚠️ If you ship §0, **Data Safety changes**. `analytics_events` is the first thing in NO SUS that
collects data for the team rather than the user; its own migration header says the answers move.
Re-read `data_safety_answers.md` before submitting — an inaccurate Data Safety answer is a policy
violation, not a paperwork slip.

### 2a. ✅ Android App Links wired — 2026-07-30, verification is on you

Play Console → Protected with Play → App signing shows the app signing key **in use**, and the
Digital Asset Links snippet on that page gave the fingerprint below. Recorded here so it stops
living in a screenshot:

```
package_name  foo.nosus.app
SHA-256       3D:6F:46:90:3C:38:D0:05:E2:68:58:AC:F0:CD:2C:EC:BB:23:5A:89:24:6C:96:BD:B8:A8:D1:A9:E5:27:49:6F
```

⚠️ This is the **app signing key**, and it was changed on 30 Jul 2026 (the old one shows under
"Previous app signing keys", both at 0% install base, so nothing had shipped under either). If you
ever press **Change key** again, this fingerprint goes stale and every App Link stops verifying
until `web/.well-known/assetlinks.json` is updated and redeployed.

What now ships in the repo:

- `web/.well-known/assetlinks.json` — Flutter copies `web/` verbatim into `build/web`, and the
  existing `web/.nojekyll` is what stops GitHub Pages from dropping a dot-directory
- `AndroidManifest.xml` — an `android:autoVerify="true"` filter for `https://app.nosus.foo`
- `lib/main.dart` — `_routeIncomingWebLink()`, which routes burn notes, burn files, multi-file
  burns and share tokens arriving as https links

**Why that last one was mandatory, not polish.** An intent filter cannot match a URL fragment, and
*every* link this app mints is fragment-shaped at path `/` — `/#/burn/<id>?k=…`, `/#/burnfile/<id>`,
`/#/burnfiles/<ids>`, `/?cb=…#/v/<token>`, `/#/join/<code>`. So the filter is unavoidably host-wide:
once installed, the app intercepts every `app.nosus.foo` link. Before this change the native
listener understood only invites and the `foo.nosus.app://v` scheme, so a burn link would have been
swallowed — recipient lands on the home screen, single-use link looks broken, and there is no
browser fallback because the system already chose the app.

**Verify after the first release build lands on a device:**

```bash
adb shell pm get-app-links foo.nosus.app          # expect: app.nosus.foo → verified
curl -sI https://app.nosus.foo/.well-known/assetlinks.json   # expect: 200, application/json
```

Verification only happens against the **installed** signing key, so a locally-built debug APK will
report `verified: false` — that is expected, not a bug. It needs a Play-signed build, which makes
this dependent on §1a.

**Known limitation, deliberately not fixed:** legacy links to the bare `nosus.foo` root still open
in a browser even with the app installed. The landing page's forwarding shim redirects them to
`app.nosus.foo` client-side, and Android does not re-evaluate App Links across a JS redirect. The
only fix would be claiming `nosus.foo` too — which would make the app swallow the marketing site,
the privacy policy and the Play listing's own links. Not worth it; legacy links keep working in the
browser, which is where they already worked.

---

## 3. 🔴/🟡 Secrets and config that are not set

| What | Where | Effect while unset |
|---|---|---|
| `BURN_FILES_IP_SALT` | Supabase project secrets | 🟡 Burn-file per-IP rate limiting degrades |
| `FCM_SERVICE_ACCOUNT_EMAIL`, `FCM_PRIVATE_KEY`, `FCM_PROJECT_ID`, `PUSH_SWEEP_SECRET` | Supabase secrets, for `send-push` | 🔴 no push at all |
| ~~`android/app/google-services.json`~~ | ✅ **added 2026-07-30** — project `no-sus-isagi0011`, `package_name` verified as `foo.nosus.app` | — |
| `GOOGLE_SERVICES_JSON_BASE64` | GitHub repo secret (new) | 🔴 release builds ship without push — the file is git-ignored, so CI has no other way to get it |
| `PLAY_INTEGRITY_SERVICE_ACCOUNT_EMAIL`, `PLAY_INTEGRITY_PRIVATE_KEY` | Supabase secrets | ⚪ Play Integrity stays scaffolded |
| `SENTRY_DSN` | CI secret + `.env` | ⚪ crash reporting stays off by default |

**On push specifically:** `send-push` is **not deployed** — confirmed against the live project, which
runs 11 edge functions, none of them `send-push`. Turning push on needs five things; as of
2026-07-30 the first is done:

1. ✅ Firebase project + `android/app/google-services.json` — `no-sus-isagi0011`, package verified
2. ⬜ `GOOGLE_SERVICES_JSON_BASE64` repo secret, so CI builds get the file too:
   `base64 -w0 android/app/google-services.json` → GitHub → Settings → Secrets → Actions
3. ⬜ The FCM secrets above. Generate them in **Firebase console → Project settings → Service
   accounts → Generate new private key**; the JSON it downloads has `client_email` →
   `FCM_SERVICE_ACCOUNT_EMAIL` and `private_key` → `FCM_PRIVATE_KEY` (keep the `\n` escapes intact).
   `FCM_PROJECT_ID` is **`no-sus-isagi0011`** — the project id, not the number. Invent
   `PUSH_SWEEP_SECRET` yourself; it is the shared secret guarding the function's public endpoint.
4. ⬜ `supabase functions deploy send-push --no-verify-jwt`
5. ✅ Migration `20260730112523_notifications.sql` applied (see §0a)

Do **not** reuse `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` for step 3 — different project, different scope.

Good news: `PushService.initialize()` catches the missing-Firebase case and sets `_available =
false`, and the inbox reads Postgres directly. So the notification feature **works without push** —
push is the optimisation, not the delivery mechanism. You can ship §0 before doing any of this.

**On Play Integrity:** do **not** reuse `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` — that account has
publishing scope, not Integrity API scope. It needs its own, same convention as `drive-proxy`'s
`GD_SERVICE_ACCOUNT_EMAIL`. Also set `PlayIntegrityManager.kt`'s `cloudProjectNumber` (currently `0`,
fails fast on purpose) and flip `AppIntegrityConfig.enabled`. Read that class's doc comment first.

---

## 4. ⚪ Local machine hygiene

### 4a. Back up the signing identity — do this today

```
android/app/upload-keystore.jks     ← present on disk, git-ignored
android/key.properties              ← present on disk, git-ignored
```

Both confirmed present today. **If you lose these you cannot ever update `foo.nosus.app` again** —
Google will not re-issue an upload key for an existing listing without a reset request, and the app
identity is tied to it. Copy both to somewhere off this machine (password manager, encrypted drive).
The base64 of the `.jks` is also in the `ANDROID_KEYSTORE_BASE64` repo secret, which is a copy, not
a backup — you cannot read a GitHub secret back out.

### 4b. Delete the orphaned keystore

`android/app/release_orphaned_2026-06-21.keystore` — on disk, git-ignored, believed unused. Confirm
it is not the signer of anything you have published, then delete. Don't delete it on my say-so.

---

## 5. 🟡 Needs a physical Android device

### 5a. Hot-restart to verify this session's fixes — 5 minutes

Every Dart fix in §0b was verified by `flutter analyze` + `flutter test` only. The device
(OnePlus CPH2487) is still running the binary built before them, so **nothing is confirmed at
runtime**. Hot *restart*, not reload — a Riverpod `Notifier.build()` does not re-run on a plain
reload, and two of the fixes live there.

Watch for these to stop appearing. They are **not** visible in logcat: Android Studio launches the
app with `--dart-define=flutter.inspector.structuredErrors=true`, which routes framework exceptions
to the Dart VM service `Extension` stream instead of stdout. A clean `flutter logs` proves nothing —
attach to the VM service, or use DevTools.

| Should disappear | Was |
|---|---|
| `A RenderFlex overflowed by 18 pixels on the right` | `main.dart:692` header |
| `ListTile background color or ink splashes may be invisible` ×4 | profile + settings cards |
| `setState() or markNeedsBuild() called during build` | `main.dart` listeners |
| `Cannot use Ref or modify other providers inside life-cycles` | share notification notifier |
| `Error recovering session from deep link: flow_state_not_found` | on sign-in |
| `Not a member of the study group (P0001)` | on opening a stale-group document |
| `watchMyRiskState error: RealtimeSubscribeException` | already fixed server-side (§0d) |

### 5b. 🔴 Stale group files stay readable offline — needs a decision

Found while tracing the audit-log failures, and it outlives them. You can open
`NO_SUS_pitchdeck_compressed` even though it belongs to group `g_1783512809611` ("kaam25") and
**neither** test account is a member. Confirmed against the live database.

The server is behaving correctly — RLS on `secure_files` is `is_group_member(group_id)`, so those
rows are not being served. The content is coming from `RecentlySavedItem`, persisted in
SharedPreferences with both `localPath` and `destinationId`, and never revalidated against current
membership. Leaving a group does not invalidate what is already on the device.

The commit in §0b only silences the resulting audit-log noise. It does **not** stop the file opening.
Given `private_group_boundary` landed the same day, decide whether that is acceptable: for a product
that claims group-scoped access, "you keep what you already opened" is a defensible cache policy or a
real leak, depending on the promise you intend to make. Say which and it gets built.

### 5c. `migrate_device_id()` has never run for real

The hardware-backed device id is verified on real hardware (OnePlus CPH2487, `backing=tee`, id stable
across force-stop). What is **not** verified is the database half: all `user_known_devices` rows are
still 36-char legacy UUIDs, because the test device was never signed in.

**To exercise it:** sign in on an Android device that already has a legacy device id, launch, then:

```sql
select device_id, first_seen_at, last_seen_at
  from public.user_known_devices
 where user_id = '<your uuid>';
```

Expect the row's `device_id` to become a 64-char hex SHA-256 **while `first_seen_at` stays
unchanged** — that carry-across is the whole point of the migration, and it is what stops the ledger
filling with false `multiple_device_access` findings.

Also confirm **no new row** appeared in `device_integrity_events`. That table is deliberately left
alone (its `entry_hash` is computed by a BEFORE INSERT trigger, so an UPDATE would silently break
`verify_device_integrity_chain()`).

### 5d. Stage 2 attestation is a decision, not a task

Server-side verification of the attestation certificate chain — the thing that would actually
*prove* the id came from hardware instead of trusting the client — is scoped but deliberately not
built. It needs a physical device to test (emulators attest with Google's known-compromised debug
key). It needs **no** Google Cloud project, so unlike Play Integrity nothing external blocks it.
Say the word and it gets built.

---

## 6. ⚪ Open code item you may want to weigh in on

**`google_fonts` fetches Inter/Outfit from Google's CDN at runtime.** Verified today: no
`allowRuntimeFetching = false` anywhere in `lib/`, no font binaries under `assets/`. First launch on
a cold or blocked network therefore falls back to a system font, and it is a third-party network
call at startup — which sits awkwardly next to a zero-knowledge product's claims.

Fix is bundling the real `.ttf` files and setting `allowRuntimeFetching = false`. It costs roughly
1–2 MB of APK. Left undone because that trade-off is a product call — say which way you want it.

---

## 7. ⚪ A migration file in this repo is lying — decide how to fix it

`supabase/migrations/20260707030000_restore_community_rpcs.sql` opens with:

> These two functions exist in the repo's baseline.sql but were never applied to the live project …
> downstream audit events logged against that group are rejected with "Not a member of the study
> group".

**That is no longer true, and it cost real time.** Checked against the live project on 2026-07-30:
both `join_public_group_by_name` and `ensure_community_exists` exist, an equivalent migration is in
the ledger as `20260706223526`, and both test accounts *are* members of "Global Community" (13
members). The header sends you down a dead end — the actual cause of that error is §5b.

`AGENTS.md` §0.5 says migrations are never edited after they land, which is why this is your call
rather than something already done:

- **Amend the comment only** — no DDL change, arguably outside the spirit of the rule but harmless
- **Leave it and rely on the pointer** — `AGENTS.md` §11 now carries a warning under `7cda72f`
- **Delete the file** — it duplicates what the ledger already has

---

## Quick triage

If you only do three things:

1. **Back up the keystore** (§4a) — irreversible if you lose it
2. **Decide on the working tree** (§0) — everything else downstream depends on it
3. **Enable the Play API** (§1a) — one click, unblocks automated releases

Cheapest useful thing after those: **hot-restart and watch the VM service** (§5a). Five minutes, and
it converts eight "analyze-and-tests-pass" fixes into eight actually-verified ones.
