-- SPDX-License-Identifier: MIT
-- add-alien-stations: generation benchmark. Builds N trader ports end to end (layout, triangles, the view's
-- meshes) and N walkable interiors with their meshes; time the run against an empty one (MODE = 0):
--   time saucer_headless --root REPO --seed 42 --script REPO/tools/shots/alien_bench.lua
local T = saucer.test
local sh = require("sim.stationhull")
local vhull = require("view.stationhull")
local sg = require("sim.stationgen")
local vst = require("view.station")
local N = 8
local tris, solids, areas = 0, 0, 0
for i = 1, N do
  local L = sh.generate(1000 + i * 37, "port", 3, true)
  for _, t in pairs(vhull.layer_tris(L)) do tris = tris + t end
  solids = solids + #L.solids
  vhull.free_all()
  local I = sg.generate(2000 + i * 41)
  vst.meshes(I)
  areas = areas + #I.areas
end
saucer.log.info(string.format("bench: %d stations, avg tris %d, avg solids %d, avg interior areas %.1f", N, tris // N, solids // N, areas / N))
T.wait(1)
