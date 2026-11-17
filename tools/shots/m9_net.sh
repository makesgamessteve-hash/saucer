#!/bin/sh
# SPDX-License-Identifier: MIT
# Two saucer windows side by side, a host and a guest on loopback (milestone 9).
# Needs an X display, xdotool and ffmpeg:  tools/shots/m9_net.sh BUILD/saucer REPO OUT.png
set -e
BIN=$1; ROOT=$2; OUT=$3
W=800; H=450
common="--root $ROOT --windowed --width $W --height $H --script $ROOT/tools/shots/m9_net.lua --net-delay 3"
rm -rf /tmp/saucer-netshot && mkdir -p /tmp/saucer-netshot
"$BIN" --user-dir /tmp/saucer-netshot/host --seed 42 --host 47851 $common > /tmp/saucer-netshot/host.log 2>&1 &
HP=$!
sleep 1
"$BIN" --user-dir /tmp/saucer-netshot/guest --join 127.0.0.1:47851 $common > /tmp/saucer-netshot/guest.log 2>&1 &
GP=$!
for _ in $(seq 1 240); do
  if grep -q "SHOT READY" /tmp/saucer-netshot/host.log && grep -q "SHOT READY" /tmp/saucer-netshot/guest.log; then break; fi
  sleep 1
done
for pair in "$HP 0" "$GP $((W + 10))"; do
  set -- $pair
  wid=$(xdotool search --sync --pid "$1" | tail -1)
  xdotool windowmove "$wid" "$2" 0
done
sleep 2
ffmpeg -loglevel error -y -f x11grab -video_size $((2 * W + 10))x$((H + 40)) -i "$DISPLAY+0,0" -frames:v 1 "$OUT"
kill $HP $GP 2>/dev/null || true
grep -h "SHOT READY" /tmp/saucer-netshot/host.log /tmp/saucer-netshot/guest.log
