#!/bin/sh
# SPDX-License-Identifier: MIT
# One fun-audit episode: tools/funaudit/run.sh PERSONA SEED LIMIT_TICKS OUTDIR
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
PERSONA=$1; SEED=$2; LIMIT=$3; OUT=$4
BUILD=${BUILD:-$ROOT/build/game}
mkdir -p "$OUT"
NAME="${PERSONA}_s${SEED}"
SCRIPT="$OUT/$NAME.lua"
DELAY=0; [ "$PERSONA" = "human" ] && DELAY=14
{
  echo "CFG = { run = \"$NAME\", persona = \"$PERSONA\", seed = $SEED, limit = $LIMIT, delay = $DELAY, shots = \"${SHOTS_DIR:-$OUT/}\", jam = true, shot_ticks = { ${SHOT_TICKS:-} } }"
  echo "BOT = (function()"; cat "$ROOT/tools/playtest/bot.lua"; echo "end)()"
  echo "CAREER = (function()"; cat "$ROOT/tools/playtest/career.lua"; echo "end)()"
  cat "$HERE/fun.lua"
} > "$SCRIPT"
UD="$OUT/user-$NAME"; rm -rf "$UD"
T0=$(date +%s.%N)
"$BUILD/saucer_headless" --root "$ROOT" --user-dir "$UD" --seed "$SEED" --script "$SCRIPT" --ticks $((LIMIT + 36000)) > "$OUT/$NAME.log" 2>&1 || RC=$?
T1=$(date +%s.%N)
echo "PTTIME $(awk "BEGIN{print $T1 - $T0}") s exit ${RC:-0}" >> "$OUT/$NAME.log"
rm -rf "$UD"
