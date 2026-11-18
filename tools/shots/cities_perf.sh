#!/bin/sh
# Usage: tools/shots/cities_perf.sh REPO WORKDIR  -> prints seconds per 900 frames for the baseline and each body city
REPO=$1; WORK=$2
mkdir -p "$WORK"; cd "$WORK" || exit 1
for b in none planet moon asteroid; do
  sed "s/^local BODY = .*/local BODY = \"$b\"/" "$REPO/tools/shots/cities_perf.lua" > "$WORK/perf_$b.lua"
  s=$(date +%s.%N)
  xvfb-run -a "$REPO/build/game/saucer" --root "$REPO" --user-dir "$WORK/ud_perf_$b" --seed 42 --windowed --width 1280 --height 720 \
    --script "$WORK/perf_$b.lua" > "$WORK/perf_$b.log" 2>&1
  e=$(date +%s.%N)
  echo "$b: $(awk "BEGIN{printf \"%.1f\", $e - $s}") s  $(grep 'perf ' "$WORK/perf_$b.log" | sed 's/.*perf //')"
done
