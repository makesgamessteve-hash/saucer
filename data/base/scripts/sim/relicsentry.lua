-- SPDX-License-Identifier: MIT
-- add-relic-stations §6.4 (plan phase 8): sentries inside a relic in normal play, placed from its layout (derived,
-- never saved, like every sentry layout):
--  * Watchers hang in the halls: every third hall along the warren (never the maw's hall, so the way in is calm),
--    at most WATCHERS of them
--  * Snatchers prefer the warrens: each guards one Seat branch (the passages off a hall down to its chamber), its nest
--    in the chamber; at most SNATCHERS, the longest branches first; the locked reliquary's branch is never one
--  * Spotters drift round the junctions: the halls with the most doors, at most SPOTTERS, each on a square round its
--    hall's middle
-- The heart hall keeps no sentry: it is the place to stand and look. They wear the civ's glyph like any sentry.
local vec = require("lib.vec")
local ruinm = require("sim.ruin")
local M = {}

M.WATCHERS = 8
M.WATCHER_EVERY = 3
M.SNATCHERS = 4
M.SPOTTERS = 2
M.SPOTTER_SQUARE = 18 -- m half-side of a Spotter's beat round its junction
M.SPOTTER_LIFT = 10   -- m over the hall's floor

-- how many doors touch each room
local function door_count(ruin)
  local n = {}
  for _, d in ipairs(ruin.doors) do
    n[d.a] = (n[d.a] or 0) + 1
    n[d.b] = (n[d.b] or 0) + 1
  end
  return n
end

-- the Seat branches: a passage whose parent is a hall, down to the chamber at its end -> { first, rooms, chamber }
function M.branches(ruin)
  local kids = {}
  for _, r in ipairs(ruin.rooms) do
    if r.parent then
      kids[r.parent] = kids[r.parent] or {}
      table.insert(kids[r.parent], r)
    end
  end
  local out = {}
  for _, r in ipairs(ruin.rooms) do
    local p = r.parent and ruin.rooms[r.parent]
    if r.kind == "passage" and p and p.kind == "hall" then
      local list, q, chamber, guard = { r }, r, nil, 0
      while q and guard < 32 do
        guard = guard + 1
        local nxt
        for _, k in ipairs(kids[q.id] or {}) do
          if k.kind == "chamber" or k.kind == "reliquary" then chamber = k end
          if k.kind == "passage" and not nxt then nxt = k end
        end
        if chamber then break end
        q = nxt
        if q then list[#list + 1] = q end
      end
      if chamber and chamber.kind == "chamber" then out[#out + 1] = { first = r, rooms = list, chamber = chamber } end
    end
  end
  table.sort(out, function(a, b)
    if #a.rooms ~= #b.rooms then return #a.rooms > #b.rooms end
    return a.first.id < b.first.id
  end)
  return out
end

local function snatcher(out, site, ruin, kit, br, civ)
  local first, deepest = br.first, br.chamber
  local mn, mx = ruinm.room_box(first, kit, site.pos)
  local dmn, dmx = ruinm.room_box(deepest, kit, site.pos)
  local len = { mx[1] - mn[1], mx[2] - mn[2], mx[3] - mn[3] }
  local along = 1
  for k = 2, 3 do if len[k] > len[along] then along = k end end
  local floor = mn[2] + kit.wall
  local cx, cz = (mn[1] + mx[1]) / 2, (mn[3] + mx[3]) / 2
  local cy = along == 2 and (mn[2] + mx[2]) / 2 or floor + 1.0
  local a, b = { cx, cy, cz }, { cx, cy, cz }
  local half = math.max(len[along] / 2 - 1.5, 0.5)
  a[along], b[along] = a[along] - half, b[along] + half
  local lo, hi = { mn[1], mn[2], mn[3] }, { mx[1], mx[2], mx[3] }
  for _, q in ipairs(br.rooms) do
    local qmn, qmx = ruinm.room_box(q, kit, site.pos)
    for k = 1, 3 do
      lo[k], hi[k] = math.min(lo[k], qmn[k]), math.max(hi[k], qmx[k])
    end
  end
  for k = 1, 3 do
    lo[k], hi[k] = math.min(lo[k], dmn[k]) - 2, math.max(hi[k], dmx[k]) + 2
  end
  out[#out + 1] = { id = #out + 1, kind = "snatcher", site = site.id, room = first.id, pos = { cx, cy, cz },
                    patrol = { a, b }, nest = { (dmn[1] + dmx[1]) / 2, dmn[2] + kit.wall + 0.6, (dmn[3] + dmx[3]) / 2 },
                    nest_room = deepest.id, leash = { lo, hi }, glyph = civ and civ.glyph or nil, relic = true }
end

local function spotter(out, site, kit, hall, t)
  local S = t.stealth and t.stealth.spotter
  local mn, mx = ruinm.room_box(hall, kit, site.pos)
  local c = { (mn[1] + mx[1]) / 2, mn[2] + kit.wall + M.SPOTTER_LIFT, (mn[3] + mx[3]) / 2 }
  local h = math.min(M.SPOTTER_SQUARE, (mx[1] - mn[1]) / 2 - 4, (mx[3] - mn[3]) / 2 - 4)
  local pts = { { c[1] - h, c[2], c[3] - h }, { c[1] + h, c[2], c[3] - h }, { c[1] + h, c[2], c[3] + h },
                { c[1] - h, c[2], c[3] + h }, { c[1] - h, c[2], c[3] - h } }
  out[#out + 1] = { id = #out + 1, kind = "spotter", site = site.id, room = hall.id, pos = vec.copy(pts[1]), route = pts,
                    len = 8 * h, speed = S and S.speed or 4, phase = ((site.id + hall.id) * 0.618) % 1, relic = true }
end

function M.layout(out, site, ruin, kit, t, band, civ, watcher_in)
  local R = ruin.relic
  local halls = {}
  for _, id in ipairs(R.halls or {}) do halls[#halls + 1] = ruin.rooms[id] end
  -- Watchers: every third hall after the maw's
  local nw = 0
  for k, r in ipairs(halls) do
    if k > 1 and k % M.WATCHER_EVERY == 0 and nw < M.WATCHERS then
      local before = #out
      watcher_in(out, site, ruin, kit, r, band, civ)
      if #out > before then
        out[#out].relic = true
        nw = nw + 1
      end
    end
  end
  -- Snatchers: the longest Seat branches
  for k, br in ipairs(M.branches(ruin)) do
    if k > M.SNATCHERS then break end
    snatcher(out, site, ruin, kit, br, civ)
  end
  -- Spotters: the busiest junction halls (not the maw's hall, not one with a Watcher)
  if t.stealth and t.stealth.spotter then
    local doors, watched = door_count(ruin), {}
    for _, d in ipairs(out) do if d.kind == "watcher" then watched[d.room] = true end end
    local junctions = {}
    for k, r in ipairs(halls) do
      if k > 1 and not watched[r.id] then junctions[#junctions + 1] = r end
    end
    table.sort(junctions, function(a, b)
      local da, db = doors[a.id] or 0, doors[b.id] or 0
      if da ~= db then return da > db end
      return a.id < b.id
    end)
    for k = 1, math.min(M.SPOTTERS, #junctions) do spotter(out, site, kit, junctions[k], t) end
  end
  return out
end

return M
