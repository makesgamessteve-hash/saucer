#!/usr/bin/env bash
# Coverage gate (C via gcov/gcovr, Lua via luacov). Fails below 95% lines.
# Usage: tools/coverage.sh [build-dir]   (needs gcc, gcovr, lua5.4 + luacov)
# The Lua pass runs the specs and every game test under luacov in parallel
# (one stats file each, merged afterwards); luacov's line hook makes the sim
# 20-40x slower, so each run gets a hard time limit instead of hanging CI.
# SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")/.."
B=${1:-build/cov}
MIN=${SAUCER_MIN_COVERAGE:-95}
JOBS=${SAUCER_JOBS:-$(nproc 2>/dev/null || echo 2)}
LIMIT=${SAUCER_COV_TIMEOUT:-2400}
cmake -S . -B "$B" -G Ninja -DCMAKE_BUILD_TYPE=Debug -DSAUCER_COVERAGE=ON -DSAUCER_BUILD_GAME=OFF
cmake --build "$B"
find "$B" -name '*.gcda' -delete
rm -rf build/luacov.stats.out build/luacov.report.out build/luacov-parts
mkdir -p build/luacov-parts
(cd "$B" && ctest -j"$JOBS" --output-on-failure)

# Lua: base game scripts exercised by the specs and the game tests.
lua_run() { # name, then saucer_headless arguments
  local name=$1
  shift
  local part=build/luacov-parts/$name
  sed "s#build/luacov.stats.out#$part.stats.out#" .luacov > "$part.luacov"
  local t0=$SECONDS
  if LUACOV_CONFIG="$part.luacov" timeout "$LIMIT" "$B"/saucer_headless --root . --user-dir "$B/test-user-$name" \
      --quiet --coverage "$@" > "$part.log" 2>&1; then
    echo "luacov $name: ok in $((SECONDS - t0)) s"
  else
    echo "luacov $name: FAILED (exit $?) after $((SECONDS - t0)) s"
    cat "$part.log"
    return 1
  fi
}
pids=()
names=()
start() { lua_run "$@" & pids+=($!); names+=("$1"); }
throttle() { while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 1; done; }
# longest first so the slow ones overlap the rest
for s in sentries mystery station excursion holodeck slice derelict3d home trade vertical coop interior fold tractor xr boot; do
  extra=""
  [ "$s" = coop ] && extra="--local-players 2 --viewports 2"
  [ "$s" = mystery ] && extra="--ticks 60000"
  [ "$s" = sentries ] && extra="--ticks 72000"
  [ "$s" = station ] && extra="--ticks 40000"
  [ "$s" = excursion ] && extra="--ticks 40000"
  throttle
  # shellcheck disable=SC2086
  start "$s" --seed 42 $extra --script tests/game/$s.lua
done
throttle
start specs --test-lua tests/lua
fail=0
for i in "${!pids[@]}"; do wait "${pids[$i]}" || { echo "luacov run ${names[$i]} failed"; fail=1; }; done
[ "$fail" = 0 ] || exit 1
lua5.4 tools/luacov_merge.lua build/luacov.stats.out build/luacov-parts/*.stats.out
luacov
lua_total=$(awk '/^Total/ {gsub("%","",$4); print $4}' build/luacov.report.out)
echo "Lua line coverage: ${lua_total}%"
gcovr -r . --filter 'engine/src/core/' --print-summary --fail-under-line "$MIN" "$B"
awk -v t="$lua_total" -v m="$MIN" 'BEGIN { if (t + 0 < m) { print "Lua coverage below " m "%"; exit 1 } }'
echo "coverage gate passed (>= ${MIN}%)"
