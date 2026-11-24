#!/bin/sh
# Usage: tools/shots/materials.sh BINARY ROOT WORKDIR [LEGACY_BINARY [LEGACY_ROOT]]
# Renders tools/shots/materials.lua (640 x 360) and compares with tests/golden/: the relic reference scene with
# materials full and off, and the legacy scene with materials off. With LEGACY_BINARY (a build from before the
# material system) it first re-renders the legacy reference instead of using the committed one.
BIN=$1; ROOT=$2; WORK=$3; OLD=$4; OLDROOT=${5:-$2}
HERE=$(cd "$(dirname "$0")" && pwd)
GOLD="$ROOT/tests/golden"
mkdir -p "$WORK"; cd "$WORK" || exit 1
run() { SDL_AUDIODRIVER=dummy xvfb-run -a -s "-screen 0 1280x720x24" "$@" --windowed --width 640 --height 360 \
          --script "$HERE/materials.lua" > /dev/null 2>&1; }
run "$BIN" --root "$ROOT" --user-dir "$WORK/ud1" --seed 42 --relic-slice
run "$BIN" --root "$ROOT" --user-dir "$WORK/ud2" --seed 42 --materials off
mv shots_materials/legacy.png shots_materials/legacy_off.png
LEG="$GOLD/legacy_seed42.png"
if [ -n "$OLD" ]; then
  run "$OLD" --root "$OLDROOT" --user-dir "$WORK/ud3" --seed 42
  LEG="$WORK/shots_materials/legacy.png"
fi
fail=0
for n in relic_trunk_full relic_trunk_off relic_core_full relic_core_off; do
  python3 "$HERE/golden_compare.py" "$GOLD/$n.png" "shots_materials/$n.png" || fail=1
done
python3 "$HERE/golden_compare.py" "$LEG" shots_materials/legacy_off.png 0.0 0.0 || fail=1
exit $fail
