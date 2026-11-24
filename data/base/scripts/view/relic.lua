-- SPDX-License-Identifier: MIT
-- add-relic-stations: how a relic looks (design civs-and-relics §2.3, §5, first slice §9). Collision is the
-- ruin's boxes only (sim/relicgen.lua); every skin here sits on or outside a wall's inner face, so nothing drawn
-- narrows a space the saucer flies:
--  * membrane cushions between chrome ribs on the walls and ceilings of the big spaces (inside: dished outward;
--    outside: the station's swollen hide), the breathing hall's cushions on the breathing slot, the plague hall's
--    on the necrotic one
--  * PIERCE, the Vyrr signature: chrome spines grown through the membrane, each ringed by an inflamed wound
--  * amethyst clusters in the Core, the lamps' crystals, the idol's crown; chitin floors
--  * the fold bays' cradles (a chrome ring, four arms, a pad, the Seat's marker ring) and the Seat-lock
--  * the maw: a membrane lip round the entrance and a ring of chrome teeth
-- Meshes are built once per relic (cached by layout hash) and drawn per room, culled against the view.
local vec = require("lib.vec")
local sm = saucer.math
local ruinm = require("sim.ruin")
local matv = require("view.materials")
local M = {}

local S = matv.SLOT
M.RIB = 12            -- m between the chrome ribs along a big space
M.BAND = 14           -- m: side-wall cushions are split into rows about this tall, ceilings into this wide
M.DISH = 2.4          -- m: an inside cushion dishes this far outward (always less than wall + HIDE)
M.HIDE = 3.0          -- m: the outside hide swells this far out from the wall's outer face
M.RIB_OUT = 1.9       -- m: a rib stands this far out from the wall's inner face (it hides the cushion seams)
M.SPINE = 7.0         -- m: a PIERCE spine's length outside the hide
M.NEAR = 700          -- m: rooms nearer than this draw their own mesh; the rest of the relic is one silhouette
M.SEG = 6             -- cushion quads per side
M.SHOW_GHOST = true   -- the ghost Villa for a Seat in a Villa-class space (shot scripts may hide it)

local cache = {}

local function col(id) return matv.base_color(id) end
local C = {}
local function colors()
  if C.membrane then return C end
  C.membrane, C.chrome, C.amethyst = col("membrane"), col("chrome"), col("amethyst")
  C.wound, C.necrotic, C.chitin = col("wound"), col("flesh_necrotic"), col("chitin")
  return C
end

local function box(list, mn, mx, color, mat, emissive)
  list[#list + 1] = { kind = "box", min = mn, max = mx, color = color, mat = mat, emissive = emissive }
  return list[#list]
end

-- a cushion: corner c, edges u and v (normal = u x v), bulge h along it
local function patch(list, c, u, v, h, color, mat, seg)
  list[#list + 1] = { kind = "patch", c = c, u = u, v = v, h = h, seg = seg or M.SEG, rings = seg or M.SEG,
                      color = color, mat = mat }
  return list[#list]
end
-- a skin part (cushion, rib, band, door frame): the spec checks none of them reaches into a flyable space
local function skin(part) part.skin = true return part end

-- orientation (roll, pitch) that turns a part's +y onto a world axis direction
local ORIENT = {
  ["+x"] = { roll = -math.pi / 2, pitch = 0 }, ["-x"] = { roll = math.pi / 2, pitch = 0 },
  ["+y"] = { roll = 0, pitch = 0 }, ["-y"] = { roll = math.pi, pitch = 0 },
  ["+z"] = { roll = 0, pitch = math.pi / 2 }, ["-z"] = { roll = 0, pitch = -math.pi / 2 },
}
M.ORIENT = ORIENT

local function oriented(list, part, dir, pos)
  local o = ORIENT[dir]
  part.roll, part.pitch, part.pos = o.roll, o.pitch, pos
  list[#list + 1] = part
end

-- PIERCE: a chrome spine through the cushion at `at` along `dir` (outward), its wound ring on the skin, a stub
-- inside that stops short of the wall's inner face
local function pierce(list, at, dir, inner_at, cc)
  oriented(list, { kind = "cone", c = { 0, 0, 0 }, r = 0.9, r1 = 0.05, h = M.SPINE + M.HIDE + 1, seg = 6, color = cc.chrome,
                   mat = S.accent }, dir, at)
  oriented(list, { kind = "ring", c = { 0, -0.15, 0 }, rin = 0.85, r = 1.9, h = 0.3, seg = 12, color = cc.wound,
                   mat = S.ring }, dir, inner_at)
  local back = dir:sub(1, 1) == "+" and "-" .. dir:sub(2) or "+" .. dir:sub(2)
  oriented(list, { kind = "cone", c = { 0, 0, 0 }, r = 0.7, r1 = 0.1, h = M.DISH - 0.3, seg = 6, color = cc.chrome, mat = S.accent },
    back, inner_at)
end

local function face_of(b, mn, mx, t)
  for a = 1, 3 do
    if math.abs((b[2][a] - b[1][a]) - t) < 1e-6 then
      if math.abs(b[1][a] - mn[a]) < 1e-6 then return a, -1 end
      if math.abs(b[2][a] - mx[a]) < 1e-6 then return a, 1 end
    end
  end
  return nil
end

-- the skin of one big space: cushions on hole-less side walls and the ceiling, ribs, spines; flat membrane
-- (with chrome door frames) on faces with doors; chitin floors
local function big_room(parts, ext, ruin, r, kit, origin, walls, cc, skin_mat, skin_col)
  local mn, mx = ruinm.room_box(r, kit, origin)
  local t = kit.wall
  local imn, imx = { mn[1] + t, mn[2] + t, mn[3] + t }, { mx[1] - t, mx[2] - t, mx[3] - t }
  -- rib stations along z (both ends too)
  local len = imx[3] - imn[3]
  local nr = math.max(1, math.floor(len / M.RIB + 0.5))
  local zs = {}
  for k = 0, nr do zs[#zs + 1] = imn[3] + len * k / nr end
  local h = imx[2] - imn[2]
  local rows = math.max(1, math.floor(h / M.BAND + 0.5))
  local w = imx[1] - imn[1]
  local cols = math.max(1, math.floor(w / M.BAND + 0.5))
  local n = 0
  for _, side in ipairs({ -1, 1 }) do
    local f = side < 0 and "-x" or "+x"
    local x_in = side < 0 and imn[1] or imx[1]
    local x_out = side < 0 and mn[1] or mx[1]
    if not r.faces[f] then
      for k = 1, nr do
        local z0, z1 = zs[k], zs[k + 1]
        for j = 1, rows do
          local y0, y1 = imn[2] + h * (j - 1) / rows, imn[2] + h * j / rows
          n = n + 1
          -- inside: normal into the room, dished outward
          local u, v = { 0, 0, z1 - z0 }, { 0, y1 - y0, 0 }
          if side < 0 then u, v = v, u end
          skin(patch(parts, { x_in, y0, z0 }, u, v, -M.DISH, skin_col, skin_mat))
          -- outside: normal out, swollen
          skin(patch(ext, { x_out, y0, z0 }, v, u, M.HIDE, cc.membrane, S.dominant))
          if (k + j) % 2 == 0 then
            local zc, yc = (z0 + z1) / 2, (y0 + y1) / 2
            pierce(ext, { x_out + side * M.HIDE * 0.5, yc, zc }, f, { x_in + side * M.DISH, yc, zc }, cc)
          end
        end
        -- the horizontal chrome bands between rows
        for j = 1, rows - 1 do
          local y = imn[2] + h * j / rows
          local a, b = math.min(x_in, x_in + side * M.RIB_OUT), math.max(x_in, x_in + side * M.RIB_OUT)
          skin(box(ext, { a, y - 0.4, z0 }, { b, y + 0.4, z1 }, cc.chrome, S.accent))
        end
      end
    end
    -- ribs on this side, floor to ceiling (on a face with a door they stay inside the wall: a passage may be behind)
    local ro = r.faces[f] and t or M.RIB_OUT
    for _, z in ipairs(zs) do
      local a, b = math.min(x_in, x_in + side * ro), math.max(x_in, x_in + side * ro)
      skin(box(ext, { a, imn[2], z - 0.6 }, { b, imx[2] + M.RIB_OUT, z + 0.6 }, cc.chrome, S.accent))
    end
  end
  -- the ceiling
  for k = 1, nr do
    local z0, z1 = zs[k], zs[k + 1]
    for j = 1, cols do
      local x0, x1 = imn[1] + w * (j - 1) / cols, imn[1] + w * j / cols
      skin(patch(parts, { x0, imx[2], z0 }, { x1 - x0, 0, 0 }, { 0, 0, z1 - z0 }, -M.DISH, skin_col, skin_mat))
      skin(patch(ext, { x0, mx[2], z0 }, { 0, 0, z1 - z0 }, { x1 - x0, 0, 0 }, M.HIDE, cc.membrane, S.dominant))
      if (k + j) % 3 == 0 then
        local xc, zc = (x0 + x1) / 2, (z0 + z1) / 2
        pierce(ext, { xc, mx[2] + M.HIDE * 0.5, zc }, "+y", { xc, imx[2] + M.DISH, zc }, cc)
      end
    end
    for j = 1, cols - 1 do
      local x = imn[1] + w * j / cols
      skin(box(ext, { x - 0.4, imx[2], z0 }, { x + 0.4, imx[2] + M.RIB_OUT, z1 }, cc.chrome, S.accent))
    end
  end
  for _, z in ipairs(zs) do
    skin(box(ext, { imn[1] - M.RIB_OUT, imx[2], z - 0.6 }, { imx[1] + M.RIB_OUT, imx[2] + M.RIB_OUT, z + 0.6 }, cc.chrome,
      S.accent))
  end
  -- the walls the boxes keep: floors (chitin), faces with doors (membrane, flat), the hole-less ends
  for _, b in ipairs(walls) do
    local a, sgn = face_of(b, mn, mx, t)
    if a == 2 and sgn < 0 then
      box(parts, b[1], b[2], cc.chitin, S.floor)
    elseif a == 3 or (a == 1 and r.faces[sgn < 0 and "-x" or "+x"]) then
      box(parts, b[1], b[2], skin_col, skin_mat)
    end
  end
  -- chrome frames round this room's door holes on its z faces (PIERCE rims: a wound line inside the chrome)
  for _, d in ipairs(ruin.doors) do
    if (d.a == r.id or d.b == r.id or (d.a == 0 and r.id == 1)) and d.axis == 3 then
      local dw, dh = kit.doors[d.class][1], kit.doors[d.class][2]
      local cx = origin[1] + (d.lo + d.hi) / 2 * kit.cell
      local y0 = origin[2] + d.vlo * kit.cell + kit.wall
      local z = d.a == 0 and mn[3] or (d.at and origin[3] + d.at * kit.cell) or mn[3]
      if math.abs(z - mn[3]) < 0.01 or math.abs(z - mx[3]) < 0.01 then
        local fr = 1.6
        -- inside the wall slab only (a door's two walls together are 2 x wall thick), proud of the membrane
        local z0, z1 = z - t, z + t
        skin(box(ext, { cx - dw / 2 - fr, y0 - 0.01, z0 }, { cx - dw / 2, y0 + dh + fr, z1 }, cc.chrome, S.accent))
        skin(box(ext, { cx + dw / 2, y0 - 0.01, z0 }, { cx + dw / 2 + fr, y0 + dh + fr, z1 }, cc.chrome, S.accent))
        skin(box(ext, { cx - dw / 2, y0 + dh, z0 }, { cx + dw / 2, y0 + dh + fr, z1 }, cc.chrome, S.accent))
        skin(box(ext, { cx - dw / 2 - fr - 0.5, y0, z0 }, { cx - dw / 2 - fr, y0 + dh + fr + 0.5, z1 }, cc.wound, S.ring))
        skin(box(ext, { cx + dw / 2 + fr, y0, z0 }, { cx + dw / 2 + fr + 0.5, y0 + dh + fr + 0.5, z1 }, cc.wound, S.ring))
        skin(box(ext, { cx - dw / 2 - fr, y0 + dh + fr, z0 }, { cx + dw / 2 + fr, y0 + dh + fr + 0.5, z1 }, cc.wound, S.ring))
      end
    end
  end
  return n
end

-- a small space (the Seat's passages, the reliquary): flat membrane walls, chitin floor, chrome rings every 8 m
local function small_room(parts, ruin, r, kit, origin, walls, cc)
  local mn, mx = ruinm.room_box(r, kit, origin)
  local t = kit.wall
  for _, b in ipairs(walls) do
    local a, sgn = face_of(b, mn, mx, t)
    if a == 2 and sgn < 0 then box(parts, b[1], b[2], cc.chitin, S.floor)
    else box(parts, b[1], b[2], cc.membrane, S.dominant) end
  end
  local long = (mx[1] - mn[1]) > (mx[3] - mn[3]) and 1 or 3
  local len = mx[long] - mn[long]
  if r.kind == "passage" and len >= 12 then
    for k = 1, math.floor(len / 8) do
      local at = mn[long] + k * 8 - 4
      local a0, a1 = {}, {}
      for q = 1, 3 do a0[q], a1[q] = mn[q] - 0.3, mx[q] + 0.3 end
      a0[long], a1[long] = at - 0.4, at + 0.4
      -- a ring of four bars just outside the passage's walls
      local o = long == 1 and 3 or 1
      local b0, b1 = { a0[1], a0[2], a0[3] }, { a1[1], mn[2] + t, a1[3] }
      box(parts, b0, b1, cc.chrome, S.accent)
      b0, b1 = { a0[1], mx[2] - t, a0[3] }, { a1[1], a1[2], a1[3] }
      box(parts, b0, b1, cc.chrome, S.accent)
      b0, b1 = { a0[1], a0[2], a0[3] }, { a1[1], a1[2], a1[3] }
      b1[o] = mn[o] + t
      box(parts, b0, b1, cc.chrome, S.accent)
      b0, b1 = { a0[1], a0[2], a0[3] }, { a1[1], a1[2], a1[3] }
      b0[o] = mx[o] - t
      box(parts, b0, b1, cc.chrome, S.accent)
    end
  elseif r.kind == "reliquary" then
    -- amethyst in the corners, low
    for _, q in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
      local x = q[1] == 0 and mn[1] + t + 0.8 or mx[1] - t - 0.8
      local z = q[2] == 0 and mn[3] + t + 0.8 or mx[3] - t - 0.8
      for k = 0, 2 do
        parts[#parts + 1] = { kind = "cone", c = { 0, 0, 0 }, pos = { x + (k - 1) * 0.35, mn[2] + t, z }, r = 0.35, r1 = 0.02,
                              h = 1.6 + k * 0.5, seg = 6, roll = (k - 1) * 0.25, color = cc.amethyst, mat = S.rare,
                              emissive = 0.15 }
      end
    end
  end
end

-- a crystal cluster at `at` (on a floor): n faceted cones, deterministic from `h`
local function cluster(list, at, n, scale, h, cc, up)
  for k = 1, n do
    local hh = (h * 7919 + k * 104729) % 1000 / 1000
    local a = k / n * sm.tau + hh
    local rr = scale * (0.3 + 0.5 * hh)
    local len = scale * (1.4 + 2.2 * ((h + k * 31) % 17) / 17)
    list[#list + 1] = { kind = "cone", c = { 0, 0, 0 }, pos = { at[1] + sm.cos(a) * rr, at[2], at[3] + sm.sin(a) * rr },
                        r = scale * 0.32, r1 = 0.02, h = len, seg = 6, roll = (up or 0) + sm.cos(a) * 0.35,
                        pitch = sm.sin(a) * 0.35, yaw = a, color = cc.amethyst, mat = S.rare, emissive = 0.2 }
  end
end

-- the Core: amethyst along its walls and the idol's plinth
local function core_room(parts, r, kit, origin, slot, cc)
  local mn, mx = ruinm.room_box(r, kit, origin)
  local t = kit.wall
  local f = mn[2] + t
  local k = 0
  for _, x in ipairs({ mn[1] + t + 6, mx[1] - t - 6 }) do
    for z = mn[3] + 16, mx[3] - 16, 22 do
      k = k + 1
      cluster(parts, { x, f, z }, 6 + k % 3, 3.2 + (k % 4) * 0.8, k, cc)
    end
  end
  for x = mn[1] + 26, mx[1] - 26, 26 do
    k = k + 1
    cluster(parts, { x, f, mx[3] - t - 6 }, 7, 4.5, k, cc)
  end
  if slot then
    local p = slot.pos
    parts[#parts + 1] = { kind = "cylinder", c = { p[1], f, p[3] }, r = 3.2, h = 0.9, seg = 16, color = cc.chrome, mat = S.accent }
    parts[#parts + 1] = { kind = "ring", c = { p[1], f + 0.9, p[3] }, rin = 2.4, r = 3.4, h = 0.25, seg = 16, color = cc.wound,
                          mat = S.ring }
    cluster(parts, { p[1], f, p[3] }, 8, 1.1, 99, cc)
  end
end

-- the fold bay's cradle: a chrome ring on the floor, four arms, a membrane pad, the Seat's marker ring
local function cradle(parts, b, cc)
  local c = b.cradle
  local half = (b.hi[1] - b.lo[1]) / 2
  parts[#parts + 1] = { kind = "ring", c = { c[1], c[2], c[3] }, rin = half - 3.5, r = half - 1.5, h = 0.8, seg = 32,
                        color = cc.chrome, mat = S.accent }
  patch(parts, { c[1] - 8, c[2] + 0.02, c[3] - 8 }, { 0, 0, 16 }, { 16, 0, 0 }, 1.0, cc.membrane, S.dominant, 6)
  for k = 0, 3 do
    local a = k * math.pi / 2 + math.pi / 4
    local x, z = c[1] + sm.cos(a) * (half - 2.5), c[3] + sm.sin(a) * (half - 2.5)
    parts[#parts + 1] = { kind = "box", min = { -0.7, 0, -0.7 }, max = { 0.7, 9, 0.7 }, pos = { x, c[2], z }, yaw = -a,
                          roll = 0.35, color = cc.chrome, mat = S.accent }
    parts[#parts + 1] = { kind = "cone", c = { 0, 0, 0 }, pos = { x, c[2], z }, r = 1.4, r1 = 0.9, h = 1.2, seg = 8,
                          color = cc.wound, mat = S.ring }
  end
  oriented(parts, { kind = "ring", c = { 0, 0, 0 }, rin = 1.1, r = 1.5, h = 0.2, seg = 16, color = cc.amethyst, mat = S.rare,
                    emissive = 0.8 }, "+y", b.marker)
end

-- the maw: a swollen membrane lip round the entrance and a ring of chrome teeth
local function maw(ext, ruin, r, kit, origin, cc)
  local mn, mx = ruinm.room_box(r, kit, origin)
  local d = ruin.doors[1]
  local dw, dh = kit.doors[d.class][1], kit.doors[d.class][2]
  local cx = origin[1] + (d.lo + d.hi) / 2 * kit.cell
  local y0 = origin[2] + d.vlo * kit.cell + kit.wall
  local z = mn[3]
  local l, rr, top = cx - dw / 2, cx + dw / 2, y0 + dh
  -- the lip: four swollen cushions on the outside of the -z face, round the hole
  patch(ext, { mn[1] - 4, mn[2] - 3, z }, { 0, mx[2] - mn[2] + 6, 0 }, { l - mn[1] + 4, 0, 0 }, 8.0, cc.membrane, S.dominant, 10)
  patch(ext, { rr, mn[2] - 3, z }, { 0, mx[2] - mn[2] + 6, 0 }, { mx[1] - rr + 4, 0, 0 }, 8.0, cc.membrane, S.dominant, 10)
  patch(ext, { l, top, z }, { 0, mx[2] - top + 3, 0 }, { rr - l, 0, 0 }, 6.0, cc.membrane, S.dominant, 10)
  patch(ext, { l, mn[2] - 3, z }, { 0, y0 - mn[2] + 3, 0 }, { rr - l, 0, 0 }, 3.0, cc.membrane, S.dominant, 10)
  -- teeth: chrome cones on the rim, pointing out of the maw, each in its wound
  local function tooth(x, y, len)
    oriented(ext, { kind = "cone", c = { 0, 0, 0 }, r = 1.1, r1 = 0.05, h = len, seg = 6, color = cc.chrome, mat = S.accent },
      "-z", { x, y, z - 0.5 })
    oriented(ext, { kind = "ring", c = { 0, 0, 0 }, rin = 1.0, r = 1.8, h = 0.4, seg = 10, color = cc.wound, mat = S.ring },
      "-z", { x, y, z - 0.6 })
  end
  for x = l + 2, rr - 2, 4 do
    tooth(x, top + 1.6, 5 + (x * 7 % 3))
    tooth(x, y0 - 1.6, 3)
  end
  for y = y0 + 2, top - 1, 4 do
    tooth(l - 1.6, y, 5 + (y * 5 % 3))
    tooth(rr + 1.6, y, 5 + (y * 5 % 3))
  end
end

-- the parts of one relic (before they become meshes): { rooms = { { room =, parts = }, ... }, ext = parts, cushions }
function M.parts(ruin, origin)
  local kit = ruinm.kit_of(ruin.kit)
  local cc = colors()
  local by_room = {}
  for _, b in ipairs(ruin.walls) do
    local l = by_room[b.room or 1] or {}
    by_room[b.room or 1] = l
    l[#l + 1] = b
  end
  local idol
  for _, s in ipairs(ruin.slots) do if s.idol then idol = s end end
  local out = { rooms = {}, ext = {}, cushions = 0 }
  local ext = out.ext
  local plague, lung = ruin.relic.plague, ruin.relic.lung
  for _, r in ipairs(ruin.rooms) do
    local parts = {}
    if r.class >= 4 then
      local mat, c = S.dominant, cc.membrane
      if r.id == lung then mat = S.lung elseif r.id == plague then mat, c = S.decay, cc.necrotic end
      out.cushions = out.cushions + big_room(parts, ext, ruin, r, kit, origin, by_room[r.id] or {}, cc, mat, c)
      if r.kind == "core" then core_room(parts, r, kit, origin, idol, cc) end
      if r.kind == "maw" then maw(ext, ruin, r, kit, origin, cc) end
    else
      small_room(parts, ruin, r, kit, origin, by_room[r.id] or {}, cc)
    end
    for _, b in ipairs(ruin.relic.bays) do if b.room == r.id then cradle(parts, b, cc) end end
    out.rooms[#out.rooms + 1] = { room = r, parts = parts }
  end
  return out
end

-- the meshes of one relic: per room { mesh, center, radius } plus the outside hide (one mesh) -> set
function M.meshes(ruin, origin)
  local hit = cache[ruin.hash]
  if hit then return hit end
  local kit = ruinm.kit_of(ruin.kit)
  local all = M.parts(ruin, origin)
  local set = { rooms = {}, ext = nil, cushions = all.cushions, triangles = 0 }
  for _, e in ipairs(all.rooms) do
    local r, parts = e.room, e.parts
    local mn, mx = ruinm.room_box(r, kit, origin)
    local id = saucer.mesh.build({ parts = parts })
    local info = saucer.mesh.info(id)
    set.triangles = set.triangles + (info and info.triangles or 0)
    set.rooms[#set.rooms + 1] = { id = r.id, mesh = id, center = vec.scale(vec.add(mn, mx), 0.5),
                                  radius = vec.dist(mn, mx) / 2 + 8, kind = r.kind }
  end
  set.ext = saucer.mesh.build({ parts = all.ext })
  local info = saucer.mesh.info(set.ext)
  set.triangles = set.triangles + (info and info.triangles or 0)
  local lo, hi = ruinm.bounds(ruin, origin, 0)
  set.center = vec.scale(vec.add(lo, hi), 0.5)
  set.radius = vec.dist(lo, hi) / 2 + 20
  cache[ruin.hash] = set
  return set
end

-- the idol mesh (shared): a chrome body grown round an amethyst core, a crown of crystal
function M.idol_mesh()
  if cache.idol then return cache.idol end
  local cc = colors()
  local parts = {
    { kind = "lathe", c = { 0, -2.4, 0 }, points = { 1.4, 0, 1.0, 0.6, 0.55, 1.4, 0.9, 2.4, 1.3, 3.2, 0.7, 4.0, 0.2, 4.6 },
      seg = 14, color = cc.chrome, mat = S.accent },
    { kind = "ring", c = { 0, -0.2, 0 }, rin = 0.8, r = 1.25, h = 0.35, seg = 14, color = cc.wound, mat = S.ring },
  }
  for k = 0, 4 do
    local a = k / 5 * sm.tau
    parts[#parts + 1] = { kind = "cone", c = { 0, 0, 0 }, pos = { sm.cos(a) * 0.5, 1.6, sm.sin(a) * 0.5 }, r = 0.35, r1 = 0.02,
                          h = 1.9 + (k % 2) * 0.6, seg = 6, yaw = a, roll = 0.35, color = cc.amethyst, mat = S.rare,
                          emissive = 0.3 }
  end
  parts[#parts + 1] = { kind = "cone", c = { 0, 1.6, 0 }, r = 0.45, r1 = 0.02, h = 2.8, seg = 6, color = cc.amethyst, mat = S.rare,
                        emissive = 0.4 }
  cache.idol = saucer.mesh.build({ parts = parts })
  return cache.idol
end

-- the ghost Villa: two glowing rings (the rim and the dome's foot) and four struts, white (tinted when drawn)
function M.ghost_mesh()
  if cache.ghost then return cache.ghost end
  local rr, hh = require("sim.ship").dims_of(1)
  local w = { 1, 1, 1 }
  local parts = {
    { kind = "ring", c = { 0, -0.2, 0 }, rin = rr - 0.35, r = rr, h = 0.4, seg = 40, color = w, emissive = 1 },
    { kind = "ring", c = { 0, hh * 0.4, 0 }, rin = rr * 0.45 - 0.3, r = rr * 0.45, h = 0.3, seg = 28, color = w, emissive = 1 },
  }
  for k = 0, 3 do
    local a = k * math.pi / 2
    parts[#parts + 1] = { kind = "box", min = { -0.12, 0, -0.12 }, max = { 0.12, hh * 0.45, 0.12 },
                          pos = { sm.cos(a) * rr * 0.7, -0.1, sm.sin(a) * rr * 0.7 }, color = w, emissive = 1 }
  end
  cache.ghost = saucer.mesh.build({ parts = parts })
  return cache.ghost
end

-- the idol where its slot (or the beam) holds it
function M.idol(v, A, pos, spin, k, tick)
  v:mesh(M.idol_mesh(), { pos = pos, yaw = spin * 0.5, scale = k, palette = A.pal.base })
  local pulse = 0.7 + 0.3 * sm.sin(tick * 0.05)
  v:billboard(A.tex.glow, { pos[1], pos[2] + 1.2 * k, pos[3] }, 7 * k, { palette = A.pal.base,
              tint = { 0.75, 0.45, 1.0, 0.45 * pulse } })
end

-- the relic's lamps: the civ's colours, pools along the big spaces, one over each cradle, the Core's crystals
function M.lamps(ruin, origin, site)
  local kit = ruinm.kit_of(ruin.kit)
  local civ = require("sim.civs").by_id(nil, ruin.relic.civ_id) or require("sim.relic").civ()
  local pal = civ.language.lamp_colors
  local lux = require("view.lights").POOL_LUX
  local out = {}
  local function add(pos, color, reach, k, fixture)
    out[#out + 1] = { pos = pos, color = color, range = reach, intensity = lux * reach * reach * (k or 1), fixture = fixture }
  end
  for i, r in ipairs(ruin.rooms) do
    local mn, mx = ruinm.room_box(r, kit, origin)
    local cx, cz = (mn[1] + mx[1]) / 2, (mn[3] + mx[3]) / 2
    local f = mn[2] + kit.wall
    if r.kind == "hall" then
      local c = r.id == ruin.relic.plague and { 0.55, 0.9, 0.45 } or pal[(i % #pal) + 1]
      for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
        add({ cx + q[1] * 28, f + 10, cz + q[2] * 28 }, c, 44, r.id == ruin.relic.plague and 0.6 or 1)
      end
      add({ cx, mx[2] - 8, cz }, pal[1], 46, 0.9)
    elseif r.kind == "trunk" then
      add({ cx, f + 8, mn[3] + 40 }, pal[2], 34)
      add({ cx, f + 8, mx[3] - 40 }, pal[3], 34)
    elseif r.kind == "core" then
      for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
        add({ cx + q[1] * 40, f + 14, cz + q[2] * 40 }, pal[(q[1] + q[2]) % 3 + 2] or pal[1], 56)
      end
      add({ cx, f + 14, cz + 16 }, { 0.85, 0.55, 1.0 }, 40, 1.4)
    elseif r.kind == "maw" then
      add({ cx, f + 10, cz }, pal[2], 40)
    elseif r.kind == "reliquary" then
      add({ cx, mx[2] - kit.wall - 0.6, cz }, pal[1], 12, 1.3, true)
    elseif r.kind == "passage" then
      add({ cx, mx[2] - kit.wall - 0.4, cz }, pal[3], 16, 0.9, true)
    end
  end
  for _, b in ipairs(ruin.relic.bays) do add({ b.marker[1], b.marker[2] + 2, b.marker[3] }, pal[1], 18, 0.8) end
  return out
end

-- the materials of the relic nearest the eye go on the view (one civ per view in the slice)
function M.near_relic(state, eye)
  local game = require("sim.game")
  for i, site in ipairs(state.sector.sites) do
    local r = site.kit == "relic" and game.ruin(i)
    if r and r.relic then
      local set = M.meshes(r, site.pos)
      if vec.dist(set.center, eye) - set.radius < 2400 then return i, r, site, set end
    end
  end
  return nil
end

-- draw every relic near the eye; -> stats { rooms, culled }
function M.draw(v, A, state, cam, xr, time)
  local render = require("view.render")
  local st = { rooms = 0, culled = 0 }
  local i, r, site, set = M.near_relic(state, cam.pos)
  if not i then return st end
  local civ = require("sim.civs").of(state, site)
  matv.apply(v, civ, time)
  local opts = { palette = A.pal.base }
  if render.visible(cam, set.center, set.radius, xr) then v:mesh(set.ext, opts) end
  for _, rm in ipairs(set.rooms) do
    if vec.dist(rm.center, cam.pos) - rm.radius < M.NEAR and render.visible(cam, rm.center, rm.radius, xr) then
      v:mesh(rm.mesh, opts)
      st.rooms = st.rooms + 1
    else
      st.culled = st.culled + 1
    end
  end
  -- Seat-locks: the shutter while closed, the socket's glow (brighter while the Seat turns it)
  local relic = require("sim.relic")
  local p = state.players[v.player or 1]
  for _, l in ipairs(r.relic.locks) do
    if not relic.lock_open(state, i, l.id) then
      local b = l.box
      v:mesh(A.unit, { pos = vec.scale(vec.add(b[1], b[2]), 0.5), scale = vec.sub(b[2], b[1]), tint = { 0.7, 0.72, 0.8, 1 } })
      local turn = p and p.relic_turn or 0
      v:billboard(A.tex.glow, l.socket, 1.2 + turn, { palette = A.pal.base,
                  tint = { 0.8, 0.5, 1.0, 0.6 + 0.4 * math.min(1, turn / relic.LOCK_TIME) } })
    end
  end
  -- the ghost Villa: where a Seat would grow, green if it fits, red if not
  if p and M.SHOW_GHOST then
    local gpos, fits = relic.ghost(state, p)
    if gpos then
      local tint = fits and { 0.35, 1, 0.55, 0.85 } or { 1, 0.3, 0.25, 0.85 }
      v:mesh(M.ghost_mesh(), { pos = gpos, yaw = p.ship.yaw, tint = tint })
    end
  end
  return st
end

return M
