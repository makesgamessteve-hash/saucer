-- SPDX-License-Identifier: MIT
-- relic-room-shapes: a relic's layout signature and the distance between two relics, so no two relics of the same
-- species look alike (design: every relic of a civ is a variation, never a copy). The signature is the room plan seen
-- from above -- every space's walkable footprint (room shapes included), all levels together -- rasterized on a
-- PX-metre grid centred on the heart. distance(a, b) is 1 - IoU of the two footprints, minimised over the eight
-- turns and mirrors of the square, so a relic that is only another relic turned or mirrored still counts as alike.
local ruinm = require("sim.ruin")
local shape = require("sim.relicshape")
local M = {}

M.PX = 16          -- metres per signature pixel
M.N = 128          -- pixels per side (2 km)
M.MIN_DIST = 0.30  -- two relics of one species must differ by at least this much (tests/lua/relicunique_spec.lua)

-- signature(ruin) -> { set = { [index] = true }, n = count, cx, cz }
function M.signature(r)
  if r.sig then return r.sig end
  local kit = ruinm.kit_of(r.kit)
  local o = r.origin or { 0, 0, 0 }
  local core = r.rooms[r.relic.core]
  local hmn, hmx = ruinm.room_box(core, kit, o)
  local cx, cz = (hmn[1] + hmx[1]) / 2, (hmn[3] + hmx[3]) / 2
  local P, N = M.PX, M.N
  local h = N // 2
  local set, n = {}, 0
  for _, rm in ipairs(r.rooms) do
    local mn, mx = ruinm.room_box(rm, kit, o)
    local i0 = math.floor((mn[1] - cx) / P) + h
    local i1 = math.floor((mx[1] - cx) / P) + h
    local j0 = math.floor((mn[3] - cz) / P) + h
    local j1 = math.floor((mx[3] - cz) / P) + h
    for i = math.max(0, i0), math.min(N - 1, i1) do
      for j = math.max(0, j0), math.min(N - 1, j1) do
        local x, z = cx + (i - h + 0.5) * P, cz + (j - h + 0.5) * P
        if x >= mn[1] and x <= mx[1] and z >= mn[3] and z <= mx[3] and shape.free_world(rm, kit, o, x, z) then
          local k = j * N + i
          if not set[k] then set[k], n = true, n + 1 end
        end
      end
    end
  end
  r.sig = { set = set, n = n }
  return r.sig
end

-- the eight symmetries of the square about the signature's centre pixel
local function sym(t, i, j, N)
  local h = N // 2
  local x, y = i - h, j - h
  if t >= 4 then x = -x end
  local q = t % 4
  if q == 1 then x, y = -y, x elseif q == 2 then x, y = -x, -y elseif q == 3 then x, y = y, -x end
  x, y = x + h, y + h
  if x < 0 or y < 0 or x >= N or y >= N then return nil end
  return y * N + x
end

-- distance(a, b) -> 0 (identical up to a turn or mirror) .. 1 (nothing in common)
function M.distance(a, b)
  local sa, sb = M.signature(a), M.signature(b)
  if sa.n + sb.n == 0 then return 0 end
  local N = M.N
  local best = 1
  for t = 0, 7 do
    local inter = 0
    for k in pairs(sb.set) do
      local m = sym(t, k % N, k // N, N)
      if m and sa.set[m] then inter = inter + 1 end
    end
    local d = 1 - inter / (sa.n + sb.n - inter)
    if d < best then best = d end
  end
  return best
end

-- min_pairwise(list) -> smallest distance between any two relics of the list, and the pair
function M.min_pairwise(list)
  local best, bi, bj = 1, nil, nil
  for i = 1, #list do
    for j = i + 1, #list do
      local d = M.distance(list[i], list[j])
      if d < best then best, bi, bj = d, i, j end
    end
  end
  return best, bi, bj
end

return M
