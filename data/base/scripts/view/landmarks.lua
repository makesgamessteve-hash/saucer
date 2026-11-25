-- SPDX-License-Identifier: MIT
-- add-civ-dungeons §3.2: a landmark in every big hall -- a strange, slowly moving thing hanging in mid-air that the
-- builders left there, in their own shapes (the civ's primitives) and materials. Render only, like the phenomena:
-- placed from the ruin's rooms (no draw from the generator's stream, so layouts and replays are unchanged), posed as
-- a function of the clock, never collides, never hurts, and fills no more than a small ball in the hall's upper middle,
-- under its ceiling lamp. The kinds:
--   orrery    a sphere with moons going round it on tilted orbits        (sphere, blob builders)
--   stack     slabs floating one over another, each turning its own way   (box, wedge)
--   spindle   a hanging vase spinning, with hoops sliding up and down it  (cyl, lathe)
--   halo      a ring of hoops rolling round an empty centre                (torus)
--   bloom     a crown of shards opening and closing like a flower         (shard)
local ruinm = require("sim.ruin")
local matv = require("view.materials")
local sm = saucer.math
local M = {}

M.KINDS = { "orrery", "stack", "spindle", "halo", "bloom" }
M.OF = { sphere = "orrery", blob = "orrery", box = "stack", wedge = "stack", cyl = "spindle", lathe = "spindle",
         torus = "halo", shard = "bloom" }
M.BIG = 0.75        -- a hall is big if its footprint is at least this share of the largest hall's
M.SIZE = 8          -- m: the largest landmark's scale (its parts stay inside 1.5 x this of its centre)
M.REACH = 1.5       -- the parts' reach, in scales
M.CLEAR = 4         -- m kept free between the landmark's ball and the floor, the walls and the ceiling lamp

local function h01(seed, k) return ((seed * 7919 + k * 104729) % 1000) / 1000 end

-- the kind for one hall: a weighted pick over the civ's primitives (sorted, so the pick is stable)
function M.kind(civ, seed)
  local prims = civ and civ.language and civ.language.primitives
  if not prims then return M.KINDS[seed % #M.KINDS + 1] end
  local keys, total = {}, 0
  for k, w in pairs(prims) do
    if M.OF[k] and w > 0 then keys[#keys + 1] = k total = total + w end
  end
  if total == 0 then return M.KINDS[seed % #M.KINDS + 1] end
  table.sort(keys)
  local x = h01(seed, 3) * total
  for _, k in ipairs(keys) do
    x = x - prims[k]
    if x < 0 then return M.OF[k] end
  end
  return M.OF[keys[#keys]]
end

-- the landmarks of a relic: -> { { room, pos, size, kind, seed } ... }, one per big hall
function M.place(ruin, civ)
  local kit = ruinm.kit_of(ruin.kit)
  local halls, best = {}, 0
  for _, r in ipairs(ruin.rooms) do
    if r.kind == "hall" then
      local mn, mx = ruinm.room_box(r, kit, ruin.origin)
      local foot = (mx[1] - mn[1]) * (mx[3] - mn[3])
      halls[#halls + 1] = { r = r, mn = mn, mx = mx, foot = foot }
      best = math.max(best, foot)
    end
  end
  local out = {}
  for _, h in ipairs(halls) do
    if h.foot >= best * M.BIG then
      local mn, mx = h.mn, h.mx
      local w = math.min(mx[1] - mn[1], mx[3] - mn[3]) - 2 * kit.wall
      local lamp = mx[2] - 8                       -- the hall's ceiling lamp (view/relic.lua M.lamps)
      local floor = mn[2] + kit.wall
      local s = math.min(M.SIZE, (w / 2 - M.CLEAR) / M.REACH, (lamp - floor - 2 * M.CLEAR) / (2 * M.REACH) * 0.9)
      if s >= 1 then
        local seed = (ruin.seed or 0) % 100003 * 31 + h.r.id
        local y = lamp - M.CLEAR - M.REACH * s
        out[#out + 1] = { room = h.r.id, pos = { (mn[1] + mx[1]) / 2, y, (mn[3] + mx[3]) / 2 }, size = s,
                          kind = M.kind(civ, seed), seed = seed }
      end
    end
  end
  return out
end

-- the parts of one landmark at time t: -> { { mesh, pos, size, yaw, pitch, roll } ... } (pure; within REACH x size)
function M.pose(lm, t)
  local p, s, sd, k = lm.pos, lm.size, lm.seed, lm.kind
  local out = {}
  local function add(mesh, x, y, z, size, yaw, pitch, roll)
    out[#out + 1] = { mesh = mesh, pos = { p[1] + x, p[2] + y, p[3] + z }, size = size, yaw = yaw or 0, pitch = pitch or 0,
                      roll = roll or 0 }
  end
  if k == "orrery" then
    add("core", 0, 0.05 * s * sm.sin(t * 0.4), 0, s * 0.45, t * 0.05)
    for i = 1, 5 do
      local r = s * (0.65 + 0.12 * i)
      local a = t * 0.5 / i + h01(sd, i) * sm.tau
      local tilt = (h01(sd, i + 9) - 0.5) * 1.2
      add("moon", sm.cos(a) * r, sm.sin(a) * r * sm.sin(tilt), sm.sin(a) * r * sm.cos(tilt), s * (0.06 + 0.03 * (i % 2)))
    end
  elseif k == "stack" then
    for i = 0, 4 do
      local dir = i % 2 == 0 and 1 or -1
      add("slab", 0, s * (-0.8 + 0.4 * i) + 0.06 * s * sm.sin(t * 0.3 + i), 0, s * (1 - 0.13 * i),
          dir * t * 0.12 * (1 + 0.25 * i) + h01(sd, i) * sm.tau)
    end
  elseif k == "spindle" then
    add("vase", 0, 0, 0, s, t * 0.3)
    for i = 0, 2 do
      local q = (t * 0.06 + i / 3 + h01(sd, 1)) % 1
      local y = -0.9 + 1.8 * q
      add("hoop", 0, s * y, 0, s * (0.35 + 0.35 * (1 - math.abs(y))), -t * 0.2)
    end
  elseif k == "halo" then
    for i = 0, 5 do
      local a = i / 6 * sm.tau + t * 0.08
      add("hoop", sm.cos(a) * s * 0.75, 0.1 * s * sm.sin(t * 0.5 + i), sm.sin(a) * s * 0.75, s * 0.4, -a, math.pi / 2, t * 0.7)
    end
    add("moon", 0, 0, 0, s * 0.12)
  else -- bloom
    local open = 0.25 + 0.85 * (0.5 + 0.5 * sm.sin(t * 0.3 + h01(sd, 2) * sm.tau))
    for i = 0, 7 do
      local a = i / 8 * sm.tau + t * 0.04
      add("shard", 0, -0.6 * s, 0, s * (1.1 + 0.2 * (i % 2)), a, 0, open)
    end
    add("moon", 0, -0.55 * s, 0, s * 0.18)
  end
  return out
end

-- the unit meshes of a civ's landmarks (dominant body, accent metal, rare glow)
local cache = {}
function M.meshes(civ)
  local cc = require("view.relic").colors(civ)
  local key = civ and civ.id or "vyrr"
  if cache[key] then return cache[key] end
  local S = matv.SLOT
  local ms = {}
  ms.core = saucer.mesh.build({ parts = {
    { kind = "sphere", c = { 0, 0, 0 }, r = 1, h = 1, seg = 18, rings = 10, color = cc.membrane, mat = S.dominant },
    { kind = "ring", c = { 0, -0.05, 0 }, rin = 1.05, r = 1.25, h = 0.1, seg = 32, color = cc.chrome, mat = S.accent } } })
  ms.moon = saucer.mesh.build({ parts = {
    { kind = "sphere", c = { 0, 0, 0 }, r = 1, h = 1, seg = 10, rings = 6, color = cc.amethyst, mat = S.rare, emissive = 0.8 } } })
  ms.slab = saucer.mesh.build({ parts = {
    { kind = "box", min = { -0.9, -0.1, -0.5 }, max = { 0.9, 0.1, 0.5 }, color = cc.chrome, mat = S.accent },
    { kind = "box", min = { -0.7, 0.1, -0.08 }, max = { 0.7, 0.13, 0.08 }, color = cc.amethyst, mat = S.rare, emissive = 0.7 } } })
  ms.vase = saucer.mesh.build({ parts = {
    { kind = "lathe", c = { 0, -1, 0 }, points = { 0.05, 0, 0.45, 0.25, 0.6, 0.7, 0.3, 1.1, 0.2, 1.5, 0.35, 1.85, 0.05, 2 },
      seg = 16, color = cc.membrane, mat = S.dominant } } })
  ms.hoop = saucer.mesh.build({ parts = {
    { kind = "ring", c = { 0, -0.04, 0 }, rin = 0.86, r = 1, h = 0.08, seg = 36, color = cc.chrome, mat = S.accent } } })
  ms.shard = saucer.mesh.build({ parts = {
    { kind = "cone", c = { 0, 0, 0 }, r = 0.12, r1 = 0, h = 1, seg = 5, color = cc.amethyst, mat = S.rare, emissive = 0.4 } } })
  cache[key] = ms
  return ms
end

-- draw the landmarks of the halls in `show` (place once per relic) -> how many drew
local placed = setmetatable({}, { __mode = "k" })   -- ruin -> { civ id, landmarks } (the ruin stays untouched)
function M.draw(v, ruin, civ, show, t, opts)
  local key = civ and civ.id or "vyrr"
  local pl = placed[ruin]
  if not pl or pl.civ ~= key then
    pl = { civ = key, list = M.place(ruin, civ) }
    placed[ruin] = pl
  end
  local ms = M.meshes(civ)
  local n = 0
  for _, lm in ipairs(pl.list) do
    if show[lm.room] then
      for _, o in ipairs(M.pose(lm, t)) do
        v:mesh(ms[o.mesh], { pos = o.pos, scale = o.size, yaw = o.yaw, pitch = o.pitch, roll = o.roll, palette = opts.palette })
      end
      n = n + 1
    end
  end
  return n
end

-- forget the placed landmarks and meshes (a restyle)
function M.forget()
  placed = setmetatable({}, { __mode = "k" })
  cache = {}
end

return M
