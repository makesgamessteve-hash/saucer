#!/usr/bin/env bash
# Coverage gate (C via gcov/gcovr, Lua via luacov). Fails below 95% lines.
# Usage: tools/coverage.sh [build-dir]   (needs gcc, gcovr, lua5.4 + luacov)
# C coverage comes from the whole ctest run (C unit tests, specs, game tests and
# replays). Lua coverage comes ONLY from the unit specs (tests/lua): each spec
# file runs under luacov on its own (one stats file each, merged afterwards), so
# the shards run in parallel and the slowest single file sets the pace. The game
# tests and replays still run, but unhooked, in ctest: luacov's line hook makes
# the sim 20-40x slower, so tracing whole scenarios took about two hours.
# SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")/.."
B=${1:-build/cov}
MIN=${SAUCER_MIN_COVERAGE:-95}
JOBS=${SAUCER_JOBS:-$(nproc 2>/dev/null || echo 2)}
# hard limit for one spec file under luacov, so a hung spec fails instead of hanging CI
LIMIT=${SAUCER_COV_TIMEOUT:-1800}
cmake -S . -B "$B" -G Ninja -DCMAKE_BUILD_TYPE=Debug -DSAUCER_COVERAGE=ON -DSAUCER_BUILD_GAME=OFF
cmake --build "$B"
find "$B" -name '*.gcda' -delete
rm -rf build/luacov.stats.out build/luacov.report.out build/luacov-parts
mkdir -p build/luacov-parts
(cd "$B" && ctest -j"$JOBS" --output-on-failure)

# Lua: base game scripts exercised by the unit specs alone (one luacov run per spec file).
lua_run() { # spec file name (tests/lua/NAME_spec.lua)
  local name=$1
  local part=build/luacov-parts/$name
  sed "s#build/luacov.stats.out#$part.stats.out#" .luacov > "$part.luacov"
  local t0=$SECONDS
  if LUACOV_CONFIG="$part.luacov" timeout "$LIMIT" "$B"/saucer_headless --root . --user-dir "$B/test-user-$name" \
      --quiet --coverage --test-lua tests/lua --filter "$name" > "$part.log" 2>&1; then
    echo "luacov $name: ok in $((SECONDS - t0)) s"
  else
    echo "luacov $name: FAILED (exit $?) after $((SECONDS - t0)) s"
    cat "$part.log"
    return 1
  fi
}
pids=()
names=()
throttle() { while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 1; done; }
# the biggest specs first so the slow ones overlap the rest
for f in $(ls -S tests/lua/*_spec.lua); do
  s=$(basename "$f")
  # --filter is a substring match on the file name: refuse a name another spec file contains
  [ "$(ls tests/lua | grep -c -F "$s")" = 1 ] || { echo "spec file name $s is a substring of another spec file"; exit 1; }
  throttle
  lua_run "$s" & pids+=($!); names+=("$s")
done
fail=0
for i in "${!pids[@]}"; do wait "${pids[$i]}" || { echo "luacov run ${names[$i]} failed"; fail=1; }; done
[ "$fail" = 0 ] || exit 1
lua5.4 tools/luacov_merge.lua build/luacov.stats.out build/luacov-parts/*.stats.out
luacov
lua_total=$(awk '/^Total/ {gsub("%","",$4); print $4}' build/luacov.report.out)
echo "Lua line coverage (unit specs only): ${lua_total}%"
gcovr -r . --filter 'engine/src/core/' --print-summary --fail-under-line "$MIN" "$B"
awk -v t="$lua_total" -v m="$MIN" 'BEGIN { if (t + 0 < m) { print "Lua coverage below " m "%"; exit 1 } }'
echo "coverage gate passed (>= ${MIN}%)"
