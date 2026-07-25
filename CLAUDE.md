# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## → Read `AGENTS.md`

**All guidance for this repository lives in [`AGENTS.md`](./AGENTS.md) at the repo root.** It is the
single source of truth, written for any AI agent. Read it now, before touching anything.

This file is deliberately a pointer and nothing more — the project previously had several documents
each claiming to be authoritative, and they drifted out of sync. Do not add project guidance here;
add it to `AGENTS.md`.

Two things from `AGENTS.md` that are easy to miss and cost the most when skipped:

1. **After every commit, log it** in `AGENTS.md` §11 Change log. A hook adds the mechanical row; you
   add the *why* for anything architectural or contract-touching.
2. **Verification gates:** `flutter analyze` **and** `flutter test` must be clean before you call a
   Flutter task done (`cargo build && cargo test` for `services/fhe-compute/`).
