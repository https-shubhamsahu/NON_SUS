#!/usr/bin/env bash
# Appends any new git commits to the "## 11. Change log" section of AGENTS.md.
#
# Wired as a PostToolUse hook on Bash|PowerShell in .claude/settings.json. It does not
# parse the tool command — it simply compares HEAD against a stored marker, so it catches
# a commit however it was made (agent, hook, IDE, or you at a terminal).
#
# Entries are inserted directly after the <!-- CHANGELOG:INSERT --> marker, newest first.
# Note: the entry describing commit N necessarily lands in working-tree state after N, so
# it rides along in commit N+1. That is expected.
#
# Never blocks work: any failure exits 0 silently.

set -uo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$ROOT" || exit 0

DOC="$ROOT/AGENTS.md"
MARKER_FILE="$ROOT/.claude/.changelog-head"
INSERT_MARKER='<!-- CHANGELOG:INSERT -->'

[ -f "$DOC" ] || exit 0
grep -qF "$INSERT_MARKER" "$DOC" || exit 0

HEAD_SHA=$(git rev-parse HEAD 2>/dev/null) || exit 0

# First run: record where we are, log nothing retroactively.
if [ ! -f "$MARKER_FILE" ]; then
  printf '%s\n' "$HEAD_SHA" > "$MARKER_FILE"
  exit 0
fi

LAST_SHA=$(tr -d '[:space:]' < "$MARKER_FILE")
[ "$LAST_SHA" = "$HEAD_SHA" ] && exit 0

# If the old marker is no longer a valid object (rebase, reset, fresh clone), resync quietly.
if ! git cat-file -e "${LAST_SHA}^{commit}" 2>/dev/null; then
  printf '%s\n' "$HEAD_SHA" > "$MARKER_FILE"
  exit 0
fi

TMP_NEW=$(mktemp) || exit 0
TMP_DOC=$(mktemp) || { rm -f "$TMP_NEW"; exit 0; }
trap 'rm -f "$TMP_NEW" "$TMP_DOC"' EXIT

# Newest first. Skip merge commits — they add noise, not decisions.
git log --no-merges --date=short --format='- **%ad** · `%h` · %s' "${LAST_SHA}..${HEAD_SHA}" \
  > "$TMP_NEW" 2>/dev/null

if [ ! -s "$TMP_NEW" ]; then
  printf '%s\n' "$HEAD_SHA" > "$MARKER_FILE"
  exit 0
fi

awk -v insert_file="$TMP_NEW" -v marker="$INSERT_MARKER" '
  { print }
  index($0, marker) && !done {
    print ""
    while ((getline line < insert_file) > 0) print line
    close(insert_file)
    done = 1
  }
' "$DOC" > "$TMP_DOC" || exit 0

[ -s "$TMP_DOC" ] || exit 0
cat "$TMP_DOC" > "$DOC" || exit 0
printf '%s\n' "$HEAD_SHA" > "$MARKER_FILE"

COUNT=$(wc -l < "$TMP_NEW" | tr -d ' ')
printf '{"systemMessage":"Logged %s commit(s) to AGENTS.md change log — add the \\"why\\" if the change was architectural."}\n' "$COUNT"
exit 0
