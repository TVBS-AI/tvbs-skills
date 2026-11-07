#!/usr/bin/env bash
# Rebuilds skills/html-report/scripts/am.mjs from the pinned upstream commit with upstream.patch applied.
# Needs git, Node.js 20+ and npm. Run from anywhere: plugins/html-report/build/build.sh
# See README.md in this folder for what the patch changes and how to move to a newer upstream commit.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$HERE/../skills/html-report"
UPSTREAM_REPO="https://github.com/doggy8088/answer-me-with-html.git"
UPSTREAM_SHA="$(tr -d '[:space:]' < "$HERE/UPSTREAM_SHA")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "• fetching $UPSTREAM_REPO @ $UPSTREAM_SHA"
git -C "$WORK" init -q
git -C "$WORK" remote add origin "$UPSTREAM_REPO"
git -C "$WORK" fetch -q --depth 1 origin "$UPSTREAM_SHA"
git -C "$WORK" checkout -q FETCH_HEAD

echo "• applying upstream.patch"
git -C "$WORK" apply --whitespace=nowarn "$HERE/upstream.patch"

echo "• installing build dependencies and bundling"
(cd "$WORK" && npm ci --no-audit --no-fund --silent && node scripts/build.mjs)

echo "• running the upstream tests (the patch is expected to fail only the tests in expected-test-failures.txt)"
(cd "$WORK" && npm test > "$WORK/test.log" 2>&1) || true
grep '^not ok' "$WORK/test.log" | sed 's/^not ok [0-9]* - //' | LC_ALL=C sort > "$WORK/failed.txt" || true
LC_ALL=C sort "$HERE/expected-test-failures.txt" > "$WORK/expected.txt"
if ! diff -u "$WORK/expected.txt" "$WORK/failed.txt"; then
  echo "✗ the failing tests differ from expected-test-failures.txt (see the diff above); the bundle was not copied" >&2
  exit 1
fi

echo "• copying the bundle and the licenses into the skill"
mkdir -p "$SKILL/scripts" "$SKILL/licenses"
cp "$WORK/skills/answer-me-with-html/scripts/am.mjs" "$SKILL/scripts/am.mjs"
cp "$WORK/LICENSE" "$SKILL/LICENSE"
cp "$WORK/skills/answer-me-with-html/licenses/OFL-Bangers.txt" "$SKILL/licenses/OFL-Bangers.txt"

echo "✓ built engine $(node "$SKILL/scripts/am.mjs" --version) from $UPSTREAM_SHA"
