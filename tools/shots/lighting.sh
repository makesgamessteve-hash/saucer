#!/bin/sh
# Usage: tools/shots/lighting.sh SAUCER_BIN REPO OUTDIR [ONLY]  -> OUTDIR/*.png (add-realistic-lighting tour)
# SPDX-License-Identifier: MIT
BIN=$1; REPO=$2; OUT=$3; ONLY=$4
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"; cd "$OUT" || exit 1
sed -e "s#^local D = .*#local D = \"./\"#" "$HERE/lighting.lua" > "$OUT/tour.lua"
[ -n "$ONLY" ] && sed -i "s#^local only = nil.*#local only = \"$ONLY\"#" "$OUT/tour.lua"
SDL_AUDIODRIVER=dummy xvfb-run -a -s "-screen 0 1280x720x24" "$BIN" --root "$REPO" --user-dir "$OUT/ud" --seed 42 --windowed \
  --width 1280 --height 720 --frame-stats --script "$OUT/tour.lua" > "$OUT/run.log" 2>&1
echo "exit $?" >> "$OUT/run.log"
