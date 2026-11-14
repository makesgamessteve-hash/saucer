#!/usr/bin/env bash
# Coverage gate (C via gcov/gcovr, Lua via luacov). Fails below 95% lines.
# Usage: tools/coverage.sh [build-dir]   (needs gcc, gcovr, lua5.4 + luacov)
# SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")/.."
B=${1:-build/cov}
MIN=${SAUCER_MIN_COVERAGE:-95}
cmake -S . -B "$B" -G Ninja -DCMAKE_BUILD_TYPE=Debug -DSAUCER_COVERAGE=ON -DSAUCER_BUILD_GAME=OFF
cmake --build "$B"
find "$B" -name '*.gcda' -delete
rm -f build/luacov.stats.out build/luacov.report.out
(cd "$B" && ctest --output-on-failure)
# Lua: base game scripts exercised by the specs and the game tests.
"$B"/saucer_headless --root . --user-dir "$B/test-user" --quiet --coverage --test-lua tests/lua
for s in boot slice interior coop; do
  extra=""
  [ "$s" = coop ] && extra="--local-players 2 --viewports 2"
  "$B"/saucer_headless --root . --user-dir "$B/test-user" --quiet --coverage --seed 42 $extra --script tests/game/$s.lua
done
luacov
lua_total=$(awk '/^Total/ {gsub("%","",$4); print $4}' build/luacov.report.out)
echo "Lua line coverage: ${lua_total}%"
gcovr -r . --filter 'engine/src/core/' --print-summary --fail-under-line "$MIN" "$B"
awk -v t="$lua_total" -v m="$MIN" 'BEGIN { if (t + 0 < m) { print "Lua coverage below " m "%"; exit 1 } }'
echo "coverage gate passed (>= ${MIN}%)"
