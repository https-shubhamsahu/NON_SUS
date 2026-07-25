# Archived documents — historical snapshots, NOT instructions

**Nothing in this directory is current.** Do not act on it. The single source of truth for this
repository is [`AGENTS.md`](../../AGENTS.md) at the repo root.

These files are kept only because they record how the project got here. Each of them was written as
a handover document at a different point in time, and each drifted. Two of them open by declaring
themselves "the authoritative single source of truth" — that claim is void, which is why they were
moved here.

| File | What it was | Why it's stale |
|---|---|---|
| `ANALYZE_RESULT.md` | "Permanent AI Handover Document" | Declares itself the single source of truth; never kept in sync |
| `PROJECT_HANDOVER.md` | "Single Source of Truth" handover | Also declares itself authoritative. Describes the product as **"NO SUS is now SecureSend"** — a superseded framing. Its "Known Bugs" table lists bugs its own changelog says were fixed (e.g. theme-reset-on-restart, fixed by the synchronous `SharedPreferences` bootstrap now in `lib/main.dart`). Its M0–M10 roadmap is for the **shelved** Sealed product |
| `INTEGRATION_REPORT.md` | Whole-stack integration pass, 11 July 2026 | Claims no authority itself, but treats the two docs above as its sources, so it inherits their staleness. Accurate as a point-in-time report |

If you find something here that is genuinely still true and useful, move it into `AGENTS.md` rather
than citing this directory.
