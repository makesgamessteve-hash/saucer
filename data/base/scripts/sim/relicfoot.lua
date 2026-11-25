-- SPDX-License-Identifier: MIT
-- add-relic-locks (plan phase 9): short on-foot pockets inside a relic, and its mix of Seat-locks and a hand-lock.
-- On the first rebuild of a relic (derived from the ruin and the seed, never saved; the ruin is rewritten once):
--  * pockets: 1-3 by the builders' body scale (POCKETS), each off a Seat chamber -- never the main route, a hall or
--    the heart -- through a door-less side: a 1 m crawlspace 8-28 m long (a 4 m tube lined to a 1 x 1 m channel, the
--    saucer cannot follow) to an 8 x 4 x 8 m room with standing room. The Seat chamber's floor is the ledge you step
--    out on. Each room holds one thing (ROLES): the hand-lock, a Delicate find, the sentry-grid console or a lore niche
--  * locks: one Seat chamber holding at most HAND_SHARE of the relic's value is sealed by a shutter that the
--    hand-lock opens; one or two more chambers get Seat-locks (with the reliquary's that makes 60-75% Seat-locks).
--    Snatcher nests are never sealed, and at most one pocket opens off a guarded chamber
-- The rest of the excursion (stepping out, the suit, the Lifeline, carrying, deploying) is sim/excursion.lua's, so
-- ruin.foot here has its shape: shutters, locks, consoles, delicates, plus niches and the list of pockets.
local ruinm = require("sim.ruin")
local M = {}

M.POCKETS = { tiny = 3, human = 2, large = 2, giant = 1, colossal = 1 }
M.CRAWL = { 2, 7 }          -- cells of crawlspace (8-28 m)
M.ROOM = { 2, 1, 2 }        -- the pocket's room (8 x 4 x 8 m)
M.PAD_BIG = 6               -- cells a pocket keeps from a Villa-class space (its hide lobes swell outside it)
M.PAD = 1                   -- cells it keeps from any other room
M.HAND_SHARE = 0.15         -- the most of the relic's value the hand-lock may seal
M.SEAT_LOCKS = { 1, 2 }     -- Seat-locks added to chambers (the reliquary's is the first)
M.MAX_GUARDED = 1
M.CHANNEL = { 1.0, 1.0 }
M.SIDES = { { name = "+z", axis = 3, sign = 1 }, { name = "+x", axis = 1, sign = 1 }, { name = "-x", axis = 1, sign = -1 },
            { name = "-z", axis = 3, sign = -1 } }

local function shuffle(rng, t)
  for k = #t, 2, -1 do
    local j = rng:int(1, k)
    t[k], t[j] = t[j], t[k]
  end
  return t
end

function M.count(civ)
  local a = civ and civ.axes or {}
  return M.POCKETS[a.body_scale or ""] or 2
end

-- an occupancy test over the ruin's rooms (padded), in the shape ruin.fit wants (grid:free)
local function occupancy(ruin, extra)
  local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
  for _, r in ipairs(ruin.rooms) do
    for k = 1, 3 do
      lo[k], hi[k] = math.min(lo[k], r.cell[k]), math.max(hi[k], r.cell[k] + r.size[k])
    end
  end
  local g = { boxes = {}, lo = lo, hi = hi }
  function g.add(_, r, pad, skip)
    g.boxes[#g.boxes + 1] = { c = r.cell, s = r.size, pad = pad, id = r.id, skip = skip }
  end
  for _, r in ipairs(ruin.rooms) do g:add(r, r.class >= 4 and M.PAD_BIG or M.PAD) end
  for _, r in ipairs(extra or {}) do g:add(r, M.PAD) end
  g.ignore = {}
  function g.free(_, x, y, z, w, h, d)
    local c, s = { x, y, z }, { w, h, d }
    for k = 1, 3 do
      if c[k] < lo[k] or c[k] + s[k] > hi[k] then return false end
    end
    for _, b in ipairs(g.boxes) do
      if not g.ignore[b.id] then
        local hit = true
        for k = 1, 3 do
          local p = k == 2 and 0 or b.pad
          if c[k] + s[k] <= b.c[k] - p or b.c[k] + b.s[k] + p <= c[k] then hit = false break end
        end
        if hit then return false end
      end
    end
    return true
  end
  return g
end

-- the door into a chamber from its parent (the passage it hangs off) -> door, its index
local function way_in(ruin, q)
  for i, d in ipairs(ruin.doors) do
    if (d.b == q.id and d.a == q.parent) or (d.a == q.id and d.b == q.parent) then return d, i end
  end
  return nil
end

-- the sealing box in a chamber's doorway and the point 2 m outside it (a Seat-lock's socket)
function M.seal_box(ruin, q, d, kit, origin)
  local l = ruinm.lateral(d.axis)
  local w, h = kit.doors[d.class][1], kit.doors[d.class][2]
  local mn, mx = ruinm.room_box(q, kit, origin)
  local p = ruin.rooms[q.parent]
  local out = p.cell[d.axis] < q.cell[d.axis] and -1 or 1        -- from the chamber toward its parent
  local plane = out < 0 and mn[d.axis] or mx[d.axis]
  local c = { 0, 0, 0 }
  c[l] = origin[l] + (d.lo + d.hi) / 2 * kit.cell
  c[2] = origin[2] + d.vlo * kit.cell + kit.wall + h / 2
  local lo, hi = {}, {}
  lo[l], hi[l] = c[l] - w / 2 - 0.1, c[l] + w / 2 + 0.1
  lo[2], hi[2] = c[2] - h / 2 - 0.1, c[2] + h / 2 + 0.1
  lo[d.axis], hi[d.axis] = plane - kit.wall - 0.25, plane + kit.wall + 0.25
  local socket = { c[1], c[2], c[3] }
  socket[d.axis] = plane + out * 2.0
  return { lo, hi }, socket, out
end

local function try_pocket(rng, ruin, kit, origin, occ, host, next_id)
  for _, s in ipairs(shuffle(rng, { M.SIDES[1], M.SIDES[2], M.SIDES[3], M.SIDES[4] })) do
    if not (host.faces and host.faces[s.name]) then
      local len = rng:int(M.CRAWL[1], M.CRAWL[2])
      local size = s.axis == 1 and { len, 1, 1 } or { 1, 1, len }
      local C = { id = next_id, class = 0, kind = "crawl", parent = host.id, size = size, cell = { 0, 0, 0 }, inclass = 0,
                  faces = {} }
      occ.ignore[host.id] = true
      local cc, cdoor = ruinm.fit(occ, host, C, s, kit, { 0, 0, 0 })
      occ.ignore[host.id] = nil
      if cc then
        C.cell = cc
        local K = { id = next_id + 1, class = 0, kind = "pocket", parent = C.id, size = { M.ROOM[1], M.ROOM[2], M.ROOM[3] },
                    cell = { 0, 0, 0 }, inclass = 0, faces = {} }
        occ:add(C, 0)
        occ.ignore[C.id] = true
        local kc, kdoor = ruinm.fit(occ, C, K, s, kit, { 0, 0, 0 })
        occ.ignore[C.id] = nil
        table.remove(occ.boxes)
        if kc then
          K.cell = kc
          host.faces = host.faces or {}
          host.faces[s.name] = true
          return C, K, cdoor, kdoor, s
        end
      end
    end
  end
  return nil
end

-- the walk in, the channel and the room's spots of one pocket
local function lay_out(C, K, s, kit, origin)
  local _, ch = require("sim.footgen").liner(C, s.axis, kit, origin, { crawl = M.CHANNEL })
  local cmn, cmx = ruinm.room_box(C, kit, origin)
  local kmn, kmx = ruinm.room_box(K, kit, origin)
  local t = kit.wall
  local ca, cs = s.axis, s.sign
  local cl = ruinm.lateral(ca)
  local kc = { (kmn[1] + kmx[1]) / 2, (kmn[2] + kmx[2]) / 2, (kmn[3] + kmx[3]) / 2 }
  local floor = kmn[2] + t
  local function at(along, lat, y)
    local q = { 0, y, 0 }
    q[ca] = kc[ca] + cs * along
    q[cl] = kc[cl] + lat
    return q
  end
  local function tube(a)
    local q = { 0, cmn[2] + t, 0 }
    q[ca] = a
    q[cl] = ch.mid
    return q
  end
  local mouth = cs > 0 and cmn[ca] or cmx[ca]
  local inner = cs > 0 and cmx[ca] or cmn[ca]
  local route = { tube(mouth - cs * 2.5), tube(mouth + cs * 0.9), tube(inner - cs * 0.9), at(0, 0, floor) }
  local half_a = (kmx[ca] - kmn[ca]) / 2 - t
  local half_l = (kmx[cl] - kmn[cl]) / 2 - t
  local face = saucer.math.atan2(ca == 1 and cs or 0, ca == 3 and cs or 0)
  return {
    route = route, crawl = { cmn, cmx }, room = { kmn, kmx },
    channel = { w = M.CHANNEL[1], h = M.CHANNEL[2], axis = ca, sign = cs, mid = ch.mid },
    spot = { pos = at(half_a - 0.15, 0, floor + 1.25), stand = at(half_a - 1.1, 0, floor), yaw = face },
    side = { pos = at(half_a - 0.4, half_l - 0.4, floor + 0.55), stand = at(half_a - 1.5, half_l - 1.2, floor), yaw = face },
    corner = at(-half_a + 1.0, -half_l + 1.0, floor + 0.35),
    length = math.abs(inner - mouth) + half_a * 2,
  }
end

local function lore_text(seed, site, civ, k)
  local ok, line = pcall(function() return require("sim.civs").lore(seed, site.civ, k) end)
  if ok and type(line) == "string" and site.civ and not site.relic_civ then return line end
  local name = civ and (civ.exonym or civ.name) or "the builders"
  return string.format("Glyphs cut at knee height, worn smooth by hands: %s wrote here, and nobody has read it since.", name)
end

-- a copy of a generated relic this module may rewrite (the generator's memoized ruin stays as generated): its own
-- rooms (and their faces), doors, walls, slots, debris and lock list
local function copy_list(t)
  local o = {}
  for i, v in ipairs(t or {}) do o[i] = v end
  return o
end
function M.copy(r)
  local c = {}
  for k, v in pairs(r) do c[k] = v end
  c.rooms = {}
  for i, rm in ipairs(r.rooms) do
    local q = {}
    for k, v in pairs(rm) do q[k] = v end
    q.faces = {}
    for k, v in pairs(rm.faces or {}) do q.faces[k] = v end
    c.rooms[i] = q
  end
  c.doors, c.walls, c.slots, c.debris = copy_list(r.doors), copy_list(r.walls), copy_list(r.slots), copy_list(r.debris)
  c.relic = {}
  for k, v in pairs(r.relic) do c.relic[k] = v end
  c.relic.locks = copy_list(r.relic.locks)
  return c
end

-- the relic as the game plays it: the generated ruin with its pockets and locks (one per generated ruin)
local derived = setmetatable({}, { __mode = "k" })
function M.derive(site, ruin, civ, seed)
  if not (ruin and ruin.relic) then return ruin end
  local d = derived[ruin]
  if d then return d end
  d = M.apply(site, M.copy(ruin), civ, seed)
  derived[ruin] = d
  return d
end

-- apply(site, ruin, civ, seed) -> ruin (once per ruin; rewrites it: pass a copy)
function M.apply(site, ruin, civ, seed)
  if not (ruin and ruin.relic) or ruin.relic.foot_done then return ruin end
  ruin.relic.foot_done = true
  local kit = ruinm.kit_of(ruin.kit)
  local origin = ruin.origin
  local rng = saucer.rng.new(saucer.seed_child(site.seed or 1, "relic_foot", 0))
  local relicloot = require("sim.relicloot")
  -- who guards what: the Snatchers' nests (sim/relicsentry.lua takes the longest branches)
  local nests = {}
  if not site.relic_civ then
    local rs = require("sim.relicsentry")
    for k, br in ipairs(rs.branches(ruin)) do if k <= rs.SNATCHERS then nests[br.chamber.id] = true end end
  end
  -- every chamber's value
  local value, total = {}, 0
  for _, s in ipairs(ruin.slots) do
    local v = relicloot.value(s)
    total = total + v
    value[s.room] = (value[s.room] or 0) + v
  end
  local chambers = {}
  for _, r in ipairs(ruin.rooms) do
    if r.kind == "chamber" and r.parent and way_in(ruin, r) then chambers[#chambers + 1] = r end
  end
  shuffle(rng, chambers)
  local used = {}
  -- the hand-lock's chamber: the richest under HAND_SHARE (never a nest)
  local gated
  for _, q in ipairs(chambers) do
    local v = value[q.id] or 0
    if not nests[q.id] and v > 0 and v <= total * M.HAND_SHARE and (not gated or v > (value[gated.id] or 0)) then gated = q end
  end
  if gated then used[gated.id] = true end
  -- more Seat-locks: on chambers with finds first, then (to keep 60% or more Seat-locks) on empty ones
  local want = rng:int(M.SEAT_LOCKS[1], M.SEAT_LOCKS[2])
  local order = {}
  for _, q in ipairs(chambers) do if (value[q.id] or 0) > 0 then order[#order + 1] = q end end
  for _, q in ipairs(chambers) do if (value[q.id] or 0) <= 0 then order[#order + 1] = q end end
  for _, q in ipairs(order) do
    if want <= 0 then break end
    if not used[q.id] and not nests[q.id] then
      local d, di = way_in(ruin, q)
      local bx, socket = M.seal_box(ruin, q, d, kit, origin)
      ruin.relic.locks[#ruin.relic.locks + 1] = { id = #ruin.relic.locks + 1, kind = "seat", door = di, room = q.id, box = bx,
                                                  socket = socket, chamber = true }
      used[q.id] = true
      want = want - 1
    end
  end
  -- the pockets
  local occ = occupancy(ruin)
  local n = M.count(civ)
  local pockets, frooms, fdoors, guarded = {}, {}, {}, 0
  local next_id = #ruin.rooms + 1
  local hosts = {}
  for _, q in ipairs(chambers) do if not used[q.id] then hosts[#hosts + 1] = q end end
  for _, q in ipairs(hosts) do
    if #pockets >= n then break end
    if not nests[q.id] or guarded < M.MAX_GUARDED then
      local C, K, cdoor, kdoor, s = try_pocket(rng, ruin, kit, origin, occ, q, next_id)
      if C then
        occ:add(C, M.PAD)
        occ:add(K, M.PAD)
        frooms[#frooms + 1], frooms[#frooms + 2] = C, K
        cdoor.foot, kdoor.foot = true, true
        fdoors[#fdoors + 1], fdoors[#fdoors + 2] = cdoor, kdoor
        local pk = lay_out(C, K, s, kit, origin)
        pk.id, pk.host, pk.crawl_room, pk.pocket_room, pk.guarded = #pockets + 1, q.id, C.id, K.id, nests[q.id] or false
        if nests[q.id] then guarded = guarded + 1 end
        pockets[#pockets + 1] = pk
        next_id = next_id + 2
      end
    end
  end
  -- what each holds: the hand-lock first (when a chamber is sealed), then the rest in a seeded order
  local roles = shuffle(rng, { "delicate", "console", "lore" })
  if gated then table.insert(roles, 1, "lock") end
  local foot = { host = pockets[1] and pockets[1].host or nil, rooms = frooms, doors = fdoors, walls = {}, shutters = {},
                 locks = {}, consoles = {}, delicates = {}, niches = {}, pockets = pockets, areas = {} }
  for k, pk in ipairs(pockets) do
    pk.role = roles[(k - 1) % #roles + 1]
    if pk.role == "lock" then
      foot.locks[#foot.locks + 1] = { id = 1, kind = "lock", opens = 1, pos = pk.spot.pos, stand = pk.spot.stand, yaw = pk.spot.yaw,
                                      pocket = k }
    elseif pk.role == "console" then
      foot.consoles[#foot.consoles + 1] = { id = #foot.consoles + 1, kind = "console", pos = pk.side.pos, stand = pk.side.stand,
                                            yaw = pk.side.yaw, pocket = k }
    elseif pk.role == "delicate" then
      foot.delicates[#foot.delicates + 1] = { id = #foot.delicates + 1, pos = pk.corner,
                                              seed = saucer.seed_child(site.seed or 1, "relic_delicate", k), pocket = k }
    else
      foot.niches[#foot.niches + 1] = { id = #foot.niches + 1, pos = pk.spot.pos, text = lore_text(seed, site, civ, k), pocket = k }
    end
    foot.areas[#foot.areas + 1] = { kind = "crawl", box = pk.crawl }
    foot.areas[#foot.areas + 1] = { kind = "pocket", box = pk.room }
  end
  if gated and foot.locks[1] then
    local d = way_in(ruin, gated)
    local bx, _, out = M.seal_box(ruin, gated, d, kit, origin)
    foot.shutters[1] = { id = 1, min = bx[1], max = bx[2], axis = d.axis, sign = out, room = gated.id }
    foot.gated = gated.id
    local gmn, gmx = ruinm.room_box(gated, kit, origin)
    foot.areas[#foot.areas + 1] = { kind = "strong", box = { gmn, gmx } }
  elseif gated then
    gated = nil
  end
  -- the first pocket fills the single-pocket fields the excursion's HUD and props read
  local p1 = pockets[1]
  if p1 then
    foot.route, foot.crawl, foot.channel, foot.chamber = p1.route, p1.crawl, p1.channel, p1.room
    foot.strong = foot.shutters[1] and { foot.shutters[1].min, foot.shutters[1].max } or p1.room
  end
  -- into the ruin: the rooms and doors, the host chambers' walls cut for the crawlspace mouths, the pockets' walls
  if #pockets > 0 then
    local hosts_cut = {}
    for _, pk in ipairs(pockets) do hosts_cut[pk.host] = true end
    for _, r in ipairs(frooms) do ruin.rooms[#ruin.rooms + 1] = r end
    for _, d in ipairs(fdoors) do ruin.doors[#ruin.doors + 1] = d end
    local keep = {}
    for _, b in ipairs(ruin.walls) do if not hosts_cut[b.room] then keep[#keep + 1] = b end end
    local cut = {}
    for _, r in ipairs(ruin.rooms) do if hosts_cut[r.id] then cut[#cut + 1] = r end end
    for _, b in ipairs(ruinm.walls(cut, ruin.doors, kit, origin)) do keep[#keep + 1] = b end
    for _, b in ipairs(ruinm.walls(frooms, ruin.doors, kit, origin)) do keep[#keep + 1] = b end
    for _, pk in ipairs(pockets) do
      local C = ruin.rooms[pk.crawl_room]
      local liner = require("sim.footgen").liner(C, pk.channel.axis, kit, origin, { crawl = M.CHANNEL })
      for _, b in ipairs(liner) do
        b.room = C.id
        keep[#keep + 1] = b
      end
    end
    ruin.walls = keep
    ruin.foot = foot
  end
  ruin.relic.pocket_list = pockets
  return ruin
end

return M
