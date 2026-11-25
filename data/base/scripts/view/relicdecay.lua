-- SPDX-License-Identifier: MIT
-- add-relic-stations (plan phase 8): a relic in normal play looks as old as its builders are dead. Its civ's fate
-- and era decide how many of its lamps are dead (view/relic.lua M.lamps asks M.dead) and how much fallen stuff lies
-- in its halls: heaps of slabs and shards against the walls, never in front of a door or over a floor opening, never
-- in a hall's middle, so the route through it stays as clear as the sim's boxes say (render only: nothing here is
-- solid, nothing in the state is read or written; the ruin is untouched).
local ruinm = require("sim.ruin")
local M = {}

-- per fate: the share of lamps dead, heaps per hall, whether shards of crust grow on the heaps
M.FATE = {
  ["war of silence"] = { dead = 0.45, heaps = 5 },
  plague = { dead = 0.35, heaps = 3, crust = true },
  schism = { dead = 0.3, heaps = 4 },
  flight = { dead = 0.25, heaps = 2 },
  sleep = { dead = 0.12, heaps = 1 },
  ascension = { dead = 0, heaps = 0, crust = true },
}
M.ERA = { primordial = 1.6, ancient = 1.3, old = 1, recent = 0.6 }   -- older relics: more down, more dead
M.WALL_BAND = { 3, 9 }   -- m in from the wall's inner face a heap's centre sits
M.DOOR_CLEAR = 10        -- m kept clear on each side of a door (and round a floor opening)
M.SIZE = { 1.6, 4.5 }    -- a heap's scale (m)

local function fate_of(civ)
  local a = civ and civ.axes or {}
  return M.FATE[(civ and civ.fate) or a.fate] or M.FATE.flight, M.ERA[a.era or (civ and civ.era)] or 1
end

-- the share of the relic's lamps that are dead (0..0.8)
function M.dead(civ)
  local f, e = fate_of(civ)
  return math.min(0.8, f.dead * e)
end

-- true when lamp number n (the lamp list's running count) is dead
function M.lamp_dead(civ, n)
  local d = M.dead(civ)
  return d > 0 and ((n * 37 + 11) % 100) < math.floor(d * 100 + 0.5)
end

-- true when lateral position u on the face is within the clearance of a hole
local function near_hole(u, holes)
  for _, h in ipairs(holes) do
    if u > h[1] - M.DOOR_CLEAR and u < h[2] + M.DOOR_CLEAR then return true end
  end
  return false
end

-- the heaps of `ruin` (world positions) -> { { room, pos, size, yaw, kind } ... }
function M.place(ruin, civ, origin)
  origin = origin or ruin.origin
  local kit = ruinm.kit_of(ruin.kit)
  local f, e = fate_of(civ)
  local per = math.floor(f.heaps * e + 0.5)
  local out = {}
  if per <= 0 then return out end
  local rng = saucer.rng.new(saucer.seed_child(ruin.seed or 1, "relic_decay", 0))
  local sides = { { 1, -1 }, { 1, 1 }, { 3, -1 }, { 3, 1 } }
  for _, r in ipairs(ruin.rooms) do
    if r.kind == "hall" or r.kind == "trunk" then
      local mn, mx = ruinm.room_box(r, kit, origin)
      local floor_holes = ruinm.face_holes(r, ruin.doors, ruin.rooms, kit, origin, 2, -1)
      local n = r.kind == "trunk" and math.max(1, per // 2) or per
      for _ = 1, n * 3 do   -- a few tries a heap; a hall with doors everywhere gets fewer
        if n <= 0 then break end
        local s = sides[rng:int(1, 4)]
        local axis, sign = s[1], s[2]
        local l = ruinm.lateral(axis)
        local holes = ruinm.face_holes(r, ruin.doors, ruin.rooms, kit, origin, axis, sign)
        local u = mn[l] + kit.wall + (mx[l] - mn[l] - 2 * kit.wall) * (0.08 + 0.84 * rng:float())
        local inset = M.WALL_BAND[1] + (M.WALL_BAND[2] - M.WALL_BAND[1]) * rng:float()
        local a = sign < 0 and (mn[axis] + kit.wall + inset) or (mx[axis] - kit.wall - inset)
        local pos = { 0, mn[2] + kit.wall, 0 }
        pos[axis], pos[l] = a, u
        local clear = not near_hole(u, holes)
        for _, h in ipairs(floor_holes) do
          if pos[1] > h[1] - M.DOOR_CLEAR and pos[1] < h[2] + M.DOOR_CLEAR and pos[3] > h[3] - M.DOOR_CLEAR
             and pos[3] < h[4] + M.DOOR_CLEAR then clear = false end
        end
        if clear then
          local size = M.SIZE[1] + (M.SIZE[2] - M.SIZE[1]) * rng:float()
          out[#out + 1] = { room = r.id, pos = pos, size = size, yaw = rng:float() * 6.2832,
                            kind = (f.crust and rng:float() < 0.5) and "crust" or "heap" }
          n = n - 1
        end
      end
    end
  end
  return out
end

local meshes = {}
function M.meshes(civ)
  local key = civ and civ.id or "vyrr"
  if meshes[key] then return meshes[key] end
  local cc = require("view.relic").colors(civ)
  local S = require("view.materials").SLOT
  local ms = {}
  ms.heap = saucer.mesh.build({ parts = {
    { kind = "box", min = { -0.9, 0, -0.5 }, max = { 0.7, 0.35, 0.6 }, color = cc.chrome, mat = S.decay },
    { kind = "box", min = { -0.3, 0.3, -0.7 }, max = { 0.9, 0.55, 0.1 }, color = cc.membrane, mat = S.decay },
    { kind = "box", min = { -0.6, 0, 0.5 }, max = { 0.1, 0.9, 0.62 }, color = cc.chrome, mat = S.accent } } })
  ms.crust = saucer.mesh.build({ parts = {
    { kind = "box", min = { -0.8, 0, -0.6 }, max = { 0.8, 0.3, 0.6 }, color = cc.membrane, mat = S.decay },
    { kind = "cone", c = { 0.2, 0.25, 0.1 }, r = 0.22, r1 = 0, h = 1.1, seg = 5, color = cc.amethyst, mat = S.rare, emissive = 0.3 },
    { kind = "cone", c = { -0.4, 0.25, -0.2 }, r = 0.16, r1 = 0, h = 0.7, seg = 5, color = cc.amethyst, mat = S.rare, emissive = 0.3 } } })
  meshes[key] = ms
  return ms
end

local placed = setmetatable({}, { __mode = "k" })   -- ruin -> { civ id, heaps }
function M.forget() placed = setmetatable({}, { __mode = "k" }) meshes = {} end

-- draw the heaps in the rooms in `show` -> how many drew
function M.draw(v, ruin, civ, show, opts)
  local key = civ and civ.id or "vyrr"
  local pl = placed[ruin]
  if not pl or pl.civ ~= key then
    pl = { civ = key, list = M.place(ruin, civ) }
    placed[ruin] = pl
  end
  local ms = M.meshes(civ)
  local n = 0
  for _, h in ipairs(pl.list) do
    if show[h.room] then
      v:mesh(ms[h.kind], { pos = h.pos, scale = h.size, yaw = h.yaw, palette = opts.palette })
      n = n + 1
    end
  end
  return n
end

return M
