#!/bin/sh
# Usage: tools/shots/cities.sh REPO WORKDIR  -> WORKDIR/shots_cities/{planet,moon,asteroid}_*.png
REPO=$1; WORK=$2
mkdir -p "$WORK/shots_cities"
cd "$WORK" || exit 1
for b in planet moon asteroid; do
  sed "s/^local BODY = .*/local BODY = \"$b\"/" "$REPO/tools/shots/cities.lua" > "$WORK/cities_$b.lua"
  xvfb-run -a "$REPO/build/game/saucer" --root "$REPO" --user-dir "$WORK/ud_$b" --seed 42 --windowed --width 1280 --height 720 \
    --script "$WORK/cities_$b.lua" > "$WORK/cities_$b.log" 2>&1
done
