-- SPDX-License-Identifier: MIT
-- On-foot features of a derelict (OpenSpec add-on-foot-excursions, concept
-- §4 and §5.4). Off one great hall the generator digs:
--   * a crawlspace: a 1 m tube (F class: on foot only, crouched) leading to
--   * a chamber with standing room, where a hand-lock (a valve coupling) and
--     a grid console wait, with a Delicate find the beam would crush, and
--   * a strongroom next to the same hall, its Seat-sized door sealed by a
--     shutter until the hand-lock is turned.
-- Placement uses the ruin's own cell grid (so nothing overlaps the rooms) and
-- a child rng, so the rooms, doors, slots and solids of the layout are the
-- same as without it. Deterministic per seed; derived data, never saved.
local M = {}

M.DEFAULT = { crawl_len = { 2, 3 }, crawl = { 1.0, 1.0 }, chamber = { 2, 1, 2 }, strong = { 3, 1, 3 } }
M.ID0 = 1000 -- foot rooms get ids from here, clear of the layout's own
M.TRIES = 4  -- lateral offsets tried per face for the crawlspace

function M.tune(kit) return kit.foot or M.DEFAULT end

local function shuffle(rng, t)
  for k = #t, 2, -1 do
    local j = rng:int(1, k)
    t[k], t[j] = t[j], t[k]
  end
  return t
end

local function cells_overlap(a, b)
  for k = 1, 3 do
    if a.cell[k] + a.size[k] <= b.cell[k] or b.cell[k] + b.size[k] <= a.cell[k] then return false end
  end
  return true
end

local function room(id, class, kind, size, parent)
  return { id = id, class = class, kind = kind, parent = parent, size = { size[1], size[2], size[3] },
           cell = { 0, 0, 0 }, inclass = class, faces = {} }
end

-- big halls that can host the features: the entrance first (you meet it
-- first), then the others in a seeded order; never shafts
function M.hosts(rng, rooms, kit)
  local big = kit.big or 4
  local first, rest = {}, {}
  for _, r in ipairs(rooms) do
    if r.class >= big and r.kind ~= "shaft" then
      if r.kind == "entrance" then first[#first + 1] = r else rest[#rest + 1] = r end
    end
  end
  shuffle(rng, rest)
  for _, r in ipairs(rest) do first[#first + 1] = r end
  return first
end

-- would a door of `class` through `door` be blocked by a crate in the hall?
-- (the hole, pushed 3 m into the host)
function M.crate_blocks(door, h, kit, origin, debris)
  local ruinm = require("sim.ruin")
  local mn, mx = ruinm.room_box(h, kit, origin)
  local a, l = door.axis, ruinm.lateral(door.axis)
  local w, hh = kit.doors[door.class][1], kit.doors[door.class][2]
  local c = origin[l] + (door.lo + door.hi) / 2 * kit.cell
  local bottom = origin[2] + door.vlo * kit.cell + kit.wall
  local plane = door.sign > 0 and mx[a] or mn[a]
  local lo, hi = {}, {}
  lo[a], hi[a] = math.min(plane, plane - door.sign * 3), math.max(plane, plane - door.sign * 3)
  lo[l], hi[l] = c - w / 2 - 0.5, c + w / 2 + 0.5
  lo[2], hi[2] = bottom, bottom + hh
  for _, b in ipairs(debris or {}) do
    if b.room == h.id and b[1][1] < hi[1] and b[2][1] > lo[1] and b[1][2] < hi[2] and b[2][2] > lo[2]
        and b[1][3] < hi[3] and b[2][3] > lo[3] then
      return true
    end
  end
  return false
end

local function lateral_offsets(rng, h, r, axis)
  local ruinm = require("sim.ruin")
  local l = ruinm.lateral(axis)
  local q = math.max(0, (h.size[l] - r.size[l]) // 2 - 1)
  local out = {}
  for i = 1, M.TRIES do
    local off = { 0, 0, 0 }
    off[l] = i == 1 and 0 or rng:int(-q, q)
    out[i] = off
  end
  return out
end

-- try to fit strongroom, crawlspace and chamber off host h -> placement or nil
function M.place(rng, grid, h, kit, F, origin, debris)
  local ruinm = require("sim.ruin")
  local sides = shuffle(rng, { 1, 2, 3, 4 })
  for _, si in ipairs(sides) do
    local ds = ruinm.DIRS[si]
    local S = room(M.ID0 + 1, 1, "strong", F.strong, h.id)
    for _, soff in ipairs(lateral_offsets(rng, h, S, ds.axis)) do
      local sc, sdoor = ruinm.fit(grid, h, S, ds, kit, soff)
      if sc and not M.crate_blocks(sdoor, h, kit, origin, debris) then
        S.cell = sc
        for _, ci in ipairs(sides) do
          local dc = ruinm.DIRS[ci]
          local len = rng:int(F.crawl_len[1], F.crawl_len[2])
          local size = dc.axis == 1 and { len, 1, 1 } or { 1, 1, len }
          local C = room(M.ID0 + 2, 0, "crawl", size, h.id)
          for _, off in ipairs(lateral_offsets(rng, h, C, dc.axis)) do
            local cc, cdoor = ruinm.fit(grid, h, C, dc, kit, off)
            if cc and not M.crate_blocks(cdoor, h, kit, origin, debris) then
              C.cell = cc
              local K = room(M.ID0 + 3, 0, "chamber", F.chamber, C.id)
              local kc, kdoor = ruinm.fit(grid, C, K, dc, kit, { 0, 0, 0 })
              if kc then
                K.cell = kc
                if not cells_overlap(S, C) and not cells_overlap(S, K) then
                  return { strong = S, crawl = C, chamber = K, doors = { sdoor, cdoor, kdoor }, sdir = ds, cdir = dc }
                end
              end
            end
          end
        end
      end
    end
  end
  return nil
end

local function center(mn, mx) return { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 } end

-- the inside of the crawl tube: fillers that leave a crawl[1] x crawl[2]
-- channel along the floor -> boxes
function M.liner(C, axis, kit, origin, F)
  local ruinm = require("sim.ruin")
  local mn, mx = ruinm.room_box(C, kit, origin)
  local t = kit.wall
  local l = ruinm.lateral(axis)
  local floor = mn[2] + t
  local cw, ch = F.crawl[1], F.crawl[2]
  local mid = (mn[l] + mx[l]) / 2
  local a0, a1 = mn[axis] + t, mx[axis] - t
  local out = {}
  local function box(l0, l1, y0, y1)
    local bmn, bmx = {}, {}
    bmn[axis], bmx[axis] = a0, a1
    bmn[l], bmx[l] = l0, l1
    bmn[2], bmx[2] = y0, y1
    out[#out + 1] = { bmn, bmx }
  end
  box(mn[l] + t, mx[l] - t, floor + ch, mx[2] - t)        -- the low ceiling
  box(mn[l] + t, mid - cw / 2, floor, floor + ch)         -- left of the channel
  box(mid + cw / 2, mx[l] - t, floor, floor + ch)         -- right of the channel
  return out, { lo = { 0, floor, 0 }, mid = mid, a0 = mn[axis], a1 = mx[axis] }
end

-- generate(seed, kit, rooms, doors, grid, origin, debris) -> foot table or nil
function M.generate(seed, kit, rooms, doors, grid, origin, debris)
  if not grid then return nil end
  local ruinm = require("sim.ruin")
  local F = M.tune(kit)
  local rng = saucer.rng.new(saucer.seed_child(seed, "foot"))
  local pl
  local host
  for _, h in ipairs(M.hosts(rng, rooms, kit)) do
    pl = M.place(rng, grid, h, kit, F, origin, debris)
    if pl then
      host = h
      break
    end
  end
  if not pl then return nil end
  local S, C, K = pl.strong, pl.crawl, pl.chamber
  grid:place(S.cell[1], S.cell[2], S.cell[3], S.size[1], S.size[2], S.size[3], 8801)
  grid:place(C.cell[1], C.cell[2], C.cell[3], C.size[1], C.size[2], C.size[3], 8802)
  grid:place(K.cell[1], K.cell[2], K.cell[3], K.size[1], K.size[2], K.size[3], 8803)
  local t = kit.wall
  local frooms = { S, C, K }
  for i, d in ipairs(pl.doors) do d.foot = i end
  -- walls of the three rooms (holes where the foot doors are), drawn and
  -- collided as part of the host hall
  local all_doors = {}
  for _, d in ipairs(doors) do all_doors[#all_doors + 1] = d end
  for _, d in ipairs(pl.doors) do all_doors[#all_doors + 1] = d end
  local walls = ruinm.walls(frooms, all_doors, kit, origin)
  local liner, ch = M.liner(C, pl.cdir.axis, kit, origin, F)
  for _, b in ipairs(liner) do walls[#walls + 1] = b end
  for _, b in ipairs(walls) do b.room = host.id end
  -- the shutter over the strongroom's door, straddling both walls
  local sd = pl.doors[1]
  local hmn, hmx = ruinm.room_box(host, kit, origin)
  local a = sd.axis
  local l = ruinm.lateral(a)
  local w, hh = kit.doors[1][1], kit.doors[1][2]
  local plane = sd.sign > 0 and hmx[a] or hmn[a]
  local lc = origin[l] + (sd.lo + sd.hi) / 2 * kit.cell
  local bottom = origin[2] + sd.vlo * kit.cell + t
  local smn, smx = {}, {}
  smn[a], smx[a] = plane - t, plane + t
  smn[l], smx[l] = lc - w / 2, lc + w / 2
  smn[2], smx[2] = bottom, bottom + hh
  local shutter = { id = 1, min = smn, max = smx, axis = a, sign = sd.sign }
  -- the chamber: hand-lock on the far wall, grid console beside it, the
  -- Delicate find in a corner
  local kmn, kmx = ruinm.room_box(K, kit, origin)
  local kc = center(kmn, kmx)
  local floor = kmn[2] + t
  local ca, cs = pl.cdir.axis, pl.cdir.sign
  local cl = ruinm.lateral(ca)
  local function at(along, lat, y)
    local q = { 0, y, 0 }
    q[ca] = kc[ca] + cs * along
    q[cl] = kc[cl] + lat
    return q
  end
  local half_a = (kmx[ca] - kmn[ca]) / 2 - t
  local half_l = (kmx[cl] - kmn[cl]) / 2 - t
  local face = saucer.math.atan2(ca == 1 and cs or 0, ca == 3 and cs or 0) -- facing the far wall
  local lock = { id = 1, kind = "lock", opens = 1, pos = at(half_a - 0.15, 0, floor + 1.25), stand = at(half_a - 1.1, 0, floor),
                 yaw = face }
  local console = { id = 1, kind = "console", pos = at(half_a - 0.4, half_l - 0.4, floor + 0.55),
                    stand = at(half_a - 1.5, half_l - 1.2, floor), yaw = face }
  local delicate = { id = 1, pos = at(-half_a + 1.0, -half_l + 1.0, floor + 0.35),
                     seed = saucer.seed_child(seed, "delicate", 1) }
  -- the walk in: a step out in the hall, the tube's two ends, the chamber
  local cmn, cmx = ruinm.room_box(C, kit, origin)
  local function tube(along_world)
    local q = { 0, cmn[2] + t, 0 }
    q[ca] = along_world
    q[cl] = ch.mid
    return q
  end
  local mouth = cs > 0 and cmn[ca] or cmx[ca]
  local inner = cs > 0 and cmx[ca] or cmn[ca]
  local route = { tube(mouth - cs * 2.5), tube(mouth + cs * 0.9), tube(inner - cs * 0.9), at(0, 0, floor) }
  route[1][2] = hmn[2] + t
  -- the strongroom's loot slot (the Seat's mini beam can lift class 1)
  local smn2, smx2 = ruinm.room_box(S, kit, origin)
  local slot_pos = { (smn2[1] + smx2[1]) / 2, smn2[2] + t + 1.0, (smn2[3] + smx2[3]) / 2 }
  -- the hall floor in front of the strongroom door, for the Seat to line up
  local sfront = { lc, bottom + 1.2, lc }
  sfront[a] = plane - sd.sign * 6
  sfront[l] = lc
  local crawl_box = { cmn, cmx }
  return {
    host = host.id, rooms = frooms, doors = pl.doors, walls = walls, shutters = { shutter },
    locks = { lock }, consoles = { console }, delicates = { delicate }, route = route,
    crawl = crawl_box, channel = { w = F.crawl[1], h = F.crawl[2], axis = ca, sign = cs, mid = ch.mid },
    chamber = { kmn, kmx }, strong = { smn2, smx2 }, strong_front = sfront, slot_pos = slot_pos,
  }
end

return M
