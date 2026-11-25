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
M.RIB = 12            -- m between the chrome ribs along a big space (a ribbed language; panelled: M.RIB_PANEL)
M.BAND = 14           -- m: side-wall cushions are split into rows about this tall, ceilings into this wide
M.DISH = 2.4          -- m: an inside cushion dishes this far outward (always less than wall + HIDE)
M.HIDE = 3.0          -- m: the outside hide swells this far out from the wall's outer face
M.RIB_OUT = 1.9       -- m: a rib stands this far out from the wall's inner face (it hides the cushion seams)
M.SPINE = 7.0         -- m: a PIERCE spine's length outside the hide
M.NEAR = 300          -- m: outside the relic, rooms nearer than this draw in full; the rest as flesh blobs
M.SEG = 4             -- cushion quads per side (inside cushions; 4 keeps the relic inside the web triangle cap)
M.SHOW_GHOST = true   -- the ghost Villa for a Seat in a Villa-class space (shot scripts may hide it)

local cache = {}

local function col(id) return matv.base_color(id) end
-- add-design-language: the parts take their colours from the civ that built the relic (the slice: the Vyrr), and the
-- civ's signature rule decides what grows where a Vyrr spine grows (PIERCE, CRUST, PLATE, INLAY, ENCASE, FLOW)
M.STYLE = nil         -- a civ record that overrides every relic's builder (render only: shot scripts, the style row)
function M.civ_of(ruin)
  if M.STYLE then return M.STYLE end
  local civs = require("sim.civs")
  return (ruin and ruin.relic and civs.by_id(nil, ruin.relic.civ_id)) or civs.vyrr()
end
-- set_style(civ or nil): restyle every relic (frees the cached meshes and lamps)
function M.set_style(civ)
  M.STYLE = civ
  for k, set in pairs(cache) do
    if type(set) == "table" and set.rooms and set.ruin then
      for i in ipairs(set.rooms) do M.release(set, i) end
      cache[k] = nil
    end
  end
  require("view.lights").forget()
end
local C = {}
local function colors(civ)
  civ = civ or require("sim.civs").vyrr()
  if C[civ.id] then return C[civ.id] end
  local m = civ.materials
  local lang = civ.language or {}
  local c = {}
  c.membrane, c.chrome, c.amethyst = col(m.dominant.id), col(m.accent.id), col(m.rare.id)
  c.wound = col(m.signature and m.signature.ring or "wound")
  c.necrotic, c.chitin = col(m.decay and m.decay[1] or "flesh_necrotic"), col("chitin")
  c.rule = m.signature and m.signature.rule or "PIERCE"
  c.rib = (lang.rhythm == "panelled") and M.RIB_PANEL or M.RIB
  C[civ.id] = c
  return c
end
M.colors = colors
M.RIB_PANEL = 20      -- m between ribs for a panelled (not ribbed) language

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
  local rule = cc.rule or "PIERCE"
  -- the ring where guest meets host, on the inside cushion (every rule has one)
  oriented(list, { kind = "ring", c = { 0, -0.15, 0 }, rin = 0.85, r = 1.9, h = 0.3, seg = 8, color = cc.wound,
                   mat = S.ring }, dir, inner_at)
  if rule == "PIERCE" then
    oriented(list, { kind = "cone", c = { 0, 0, 0 }, r = 0.9, r1 = 0.05, h = M.SPINE + M.HIDE + 1, seg = 6, color = cc.chrome,
                     mat = S.accent }, dir, at)
    local back = dir:sub(1, 1) == "+" and "-" .. dir:sub(2) or "+" .. dir:sub(2)
    oriented(list, { kind = "cone", c = { 0, 0, 0 }, r = 0.7, r1 = 0.1, h = M.DISH - 0.3, seg = 6, color = cc.chrome,
                     mat = S.accent }, back, inner_at)
  elseif rule == "CRUST" then -- a bloom of guest crystals on the hide
    for k = 0, 2 do
      oriented(list, { kind = "cone", c = { (k - 1) * 1.3, 0, (k % 2) * 1.1 - 0.5 }, r = 1.1 - k * 0.2, r1 = 0.05,
                       h = 3.2 + k * 1.4, seg = 5, roll = (k - 1) * 0.35, color = cc.chrome, mat = S.accent }, dir, at)
    end
  elseif rule == "PLATE" then -- a guest plate lying on the hide, a hexagon riding the skin
    oriented(list, { kind = "cylinder", c = { 0, -0.2, 0 }, r = 3.4, h = 0.7, seg = 6, color = cc.chrome, mat = S.accent },
      dir, at)
  elseif rule == "ENCASE" then -- a guest knot sealed in a dome of the host's crystal
    oriented(list, { kind = "sphere", c = { 0, 1.4, 0 }, r = 2.2, h = 2.2, seg = 8, rings = 5, color = cc.amethyst,
                     mat = S.rare, emissive = 0.15 }, dir, at)
    oriented(list, { kind = "cone", c = { 0, 0, 0 }, r = 0.8, r1 = 0.2, h = 2.0, seg = 5, color = cc.chrome, mat = S.accent },
      dir, at)
  else -- INLAY and FLOW: a flat guest disc set into the hide, a vein ring round it
    oriented(list, { kind = "ring", c = { 0, 0.05, 0 }, rin = 0.0, r = rule == "FLOW" and 4.2 or 2.8, h = 0.25, seg = 10,
                     color = cc.chrome, mat = S.accent }, dir, at)
    oriented(list, { kind = "ring", c = { 0, 0.12, 0 }, rin = 2.9, r = 3.4, h = 0.2, seg = 10, color = cc.wound,
                     mat = S.ring }, dir, at)
  end
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

-- outside lobes over one face of a big space: the face's corner c0, its long axis A (unit, length la) and its
-- other axis B (length lb), its outward normal `out`; `inner(pa, pb)` is the matching point on the inside cushion
-- (where a spine's stub and wound sit). Each lobe bulges M.LOBE x its short side (at most M.LOBE_MAX) and carries
-- one to three PIERCE spines; `h` seeds the variation.
M.LOBE = 0.26
M.LOBE_MAX = 16
M.LOBE_SEG = 8
local function cross(a, b) return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] } end
local function lobes(ext, c0, A, la, B, lb, out, dir, inner, h, cc, skip)
  -- lobes about 64 m across, bigger on the heart's huge faces (at most about four by four on a face)
  local tile = math.max(64, math.sqrt(la * lb) / 4)
  local nb = math.max(1, math.floor(lb / tile + 0.5))
  local sb = lb / nb
  local na = math.max(1, math.floor(la / (sb * 1.15) + 0.5))
  local sa = la / na
  local swap = vec.dot(cross(A, B), out) < 0
  local n = 0
  for i = 1, na do
    for j = 1, nb do
      n = n + 1
      local hh = (h * 7919 + n * 104729) % 1000 / 1000
      local bulge = math.min(M.LOBE_MAX, math.min(sa, sb) * M.LOBE) * (0.75 + 0.5 * hh)
      local pa, pb = sa * (i - 1), sb * (j - 1)
      if skip and skip(pa, pb, sa, sb) then goto next end
      do
      local c = vec.add(c0, vec.add(vec.scale(A, pa), vec.scale(B, pb)))
      local u, v = vec.scale(A, sa), vec.scale(B, sb)
      if swap then u, v = v, u end
      skin(patch(ext, c, u, v, bulge, cc.membrane, S.dominant, M.LOBE_SEG)).lobe = true
      for k = 1, 1 + (n + h) % 3 do
        local fa = 0.25 + 0.5 * ((hh * 3 + k * 0.37) % 1)
        local fb = 0.25 + 0.5 * ((hh * 5 + k * 0.61) % 1)
        local rise = bulge * sm.sin(math.pi * fa) * sm.sin(math.pi * fb) * 0.7
        local o = vec.add(c0, vec.add(vec.scale(A, pa + fa * sa), vec.scale(B, pb + fb * sb)))
        pierce(ext, vec.add(o, vec.scale(out, rise)), dir, inner(pa + fa * sa, pb + fb * sb), cc)
      end
      end
      ::next::
    end
  end
  return n
end

-- the doors of room r on face (axis, sign): -> list of { door, rect } with rect the hole in that face's (u, v)
-- plane (side faces: lateral, y; floors and ceilings: x, z), as sim/ruin.lua cuts them
local function face_doors(ruin, r, kit, origin, axis, sign)
  local out = {}
  for _, d in ipairs(ruin.doors) do
    local mine = (d.a == r.id and d.axis == axis and d.sign == sign) or (d.b == r.id and d.axis == axis and d.sign == -sign)
      or (d.a == 0 and r.id == 1 and axis == 3 and sign < 0)
    if mine then
      local w, h = kit.doors[d.class][1], kit.doors[d.class][2]
      local rect
      if axis == 2 then
        local cx = origin[1] + (d.lo + d.hi) / 2 * kit.cell
        local cz = origin[3] + (d.lo3 + d.hi3) / 2 * kit.cell
        rect = { cx - w / 2, cx + w / 2, cz - w / 2, cz + w / 2 }
      else
        local l = axis == 1 and 3 or 1
        local c = origin[l] + (d.lo + d.hi) / 2 * kit.cell
        local y0 = origin[2] + d.vlo * kit.cell + kit.wall
        rect = { c - w / 2, c + w / 2, y0, y0 + h }
      end
      out[#out + 1] = { door = d, rect = rect }
    end
  end
  return out
end
M.face_doors = face_doors

local function hits(list, u0, u1, v0, v1, pad)
  for _, e in ipairs(list) do
    local h = e.rect
    if u0 < h[2] + pad and u1 > h[1] - pad and v0 < h[4] + pad and v1 > h[3] - pad then return true end
  end
  return false
end

-- the parts of the wall boxes on face (axis, sign) inside the face rectangle [u0,u1] x [v0,v1] (flat membrane where a
-- cushion gives way to a Seat port or a shaft)
local function clip_walls(parts, walls, mn, mx, t, axis, sign, u0, u1, v0, v1, color, mat)
  local pu, pv = axis == 2 and 1 or (axis == 1 and 3 or 1), axis == 2 and 3 or 2
  for _, b in ipairs(walls) do
    local a, sg = face_of(b, mn, mx, t)
    if a == axis and sg == sign then
      local lo, hi = { b[1][1], b[1][2], b[1][3] }, { b[2][1], b[2][2], b[2][3] }
      lo[pu], hi[pu] = math.max(lo[pu], u0), math.min(hi[pu], u1)
      lo[pv], hi[pv] = math.max(lo[pv], v0), math.min(hi[pv], v1)
      if hi[pu] > lo[pu] and hi[pv] > lo[pv] then box(parts, lo, hi, color, mat) end
    end
  end
end

-- a chrome frame (and its wound line) round a hole on face (axis, sign): rect in the face's (u, v), the wall slab
-- from w0 to w1 along the axis
local function frame(ext, axis, rect, w0, w1, fr, cc)
  local pu, pv = axis == 2 and 1 or (axis == 1 and 3 or 1), axis == 2 and 3 or 2
  local function put(u0, u1, v0, v1, color, mat)
    local lo, hi = {}, {}
    lo[axis], hi[axis] = w0, w1
    lo[pu], hi[pu], lo[pv], hi[pv] = u0, u1, v0, v1
    skin(box(ext, lo, hi, color, mat))
  end
  local u0, u1, v0, v1 = rect[1], rect[2], rect[3], rect[4]
  local bottom = axis == 2 and v0 - fr or v0 - 0.01
  put(u0 - fr, u0, bottom, v1 + fr, cc.chrome, S.accent)
  put(u1, u1 + fr, bottom, v1 + fr, cc.chrome, S.accent)
  put(u0, u1, v1, v1 + fr, cc.chrome, S.accent)
  if axis == 2 then put(u0, u1, v0 - fr, v0, cc.chrome, S.accent) end
  local wl = fr * 0.3
  put(u0 - fr - wl, u0 - fr, bottom, v1 + fr + wl, cc.wound, S.ring)
  put(u1 + fr, u1 + fr + wl, bottom, v1 + fr + wl, cc.wound, S.ring)
  put(u0 - fr, u1 + fr, v1 + fr, v1 + fr + wl, cc.wound, S.ring)
end

-- the skin of one big space: dished cushions between chrome ribs on every side without a Villa door and on the
-- ceiling (giving way to Seat ports and shafts), chitin floors, flat membrane with chrome frames where Villa doors
-- open, and outside the swollen hide in lobes with PIERCE spines. Ribs run across the room's long axis.
local SIDES = { { 1, -1, "-x" }, { 1, 1, "+x" }, { 3, -1, "-z" }, { 3, 1, "+z" } }
local function big_room(parts, ext, ruin, r, kit, origin, walls, cc, skin_mat, skin_col)
  local mn, mx = ruinm.room_box(r, kit, origin)
  local t = kit.wall
  local imn, imx = { mn[1] + t, mn[2] + t, mn[3] + t }, { mx[1] - t, mx[2] - t, mx[3] - t }
  local a = r.axis or ((mx[1] - mn[1]) > (mx[3] - mn[3]) and 1 or 3)
  local b = a == 1 and 3 or 1
  local h = imx[2] - imn[2]
  -- the heart's cushions are bigger: ribs and bands grow with the room (at most 24 bays along, 6 rows up)
  local rows = math.max(1, math.floor(h / math.max(M.BAND, h / 6) + 0.5))
  local n = 0
  -- the rib stations along the long axis (both ends too)
  local len = imx[a] - imn[a]
  local rib = math.max(cc.rib or M.RIB, len / 24)
  local nr = math.max(1, math.floor(len / rib + 0.5))
  local stations = {}
  for k = 0, nr do stations[#stations + 1] = imn[a] + len * k / nr end
  local fd = {}
  for _, f in ipairs(SIDES) do fd[f[3]] = face_doors(ruin, r, kit, origin, f[1], f[2]) end
  local up = face_doors(ruin, r, kit, origin, 2, 1)
  local function villa(list)
    for _, e in ipairs(list) do if e.door.class >= 4 then return true end end
    return false
  end
  -- ribs and bands stand proud of the ceiling and the sides; where a space joins on (a shaft above, a Villa door's
  -- neighbour) they stay inside the wall instead
  local over_up = #up > 0 and t or M.RIB_OUT
  local function over_side(ax, sg) return villa(fd[(sg < 0 and "-" or "+") .. (ax == 1 and "x" or "z")]) and t or M.RIB_OUT end
  local function at(ax, av, bx, bv, y)
    local p = { 0, y, 0 }
    p[ax], p[bx] = av, bv
    return p
  end
  for _, f in ipairs(SIDES) do
    local ax, sg, name = f[1], f[2], f[3]
    local hz = ax == 1 and 3 or 1
    local x_in = sg < 0 and imn[ax] or imx[ax]
    local doors_here = fd[name]
    local cushions = not villa(doors_here)
    -- tiles along the face: rib stations on long sides, about RIB wide on the ends
    local cuts = {}
    if hz == a then cuts = stations else
      local w = imx[hz] - imn[hz]
      local nc = math.max(1, math.floor(w / math.max(cc.rib or M.RIB, w / 24) + 0.5))
      for k = 0, nc do cuts[#cuts + 1] = imn[hz] + w * k / nc end
    end
    local inward = { 0, 0, 0 }
    inward[ax] = -sg
    if cushions then
      for k = 1, #cuts - 1 do
        local u0, u1 = cuts[k], cuts[k + 1]
        for j = 1, rows do
          local y0, y1 = imn[2] + h * (j - 1) / rows, imn[2] + h * j / rows
          if hits(doors_here, u0, u1, y0, y1, 0.6) then
            -- a Seat port: flat wall (with the hole) in this tile instead of a cushion
            clip_walls(parts, walls, mn, mx, t, ax, sg, u0, u1, y0, y1, skin_col, skin_mat)
          else
            n = n + 1
            local u, v = at(hz, u1 - u0, ax, 0, 0), { 0, y1 - y0, 0 }
            if vec.dot(cross(u, v), inward) < 0 then u, v = v, u end
            skin(patch(parts, at(hz, u0, ax, x_in, y0), u, v, -M.DISH, skin_col, skin_mat))
          end
        end
        for j = 1, rows - 1 do
          local y = imn[2] + h * j / rows
          if not hits(doors_here, u0, u1, y - 0.4, y + 0.4, 0.6) then
            local p0, p1 = at(hz, u0, ax, math.min(x_in, x_in + sg * M.RIB_OUT), y - 0.4),
              at(hz, u1, ax, math.max(x_in, x_in + sg * M.RIB_OUT), y + 0.4)
            skin(box(ext, p0, p1, cc.chrome, S.accent))
          end
        end
      end
    else
      for _, bx in ipairs(walls) do
        local fa, fs = face_of(bx, mn, mx, t)
        if fa == ax and fs == sg then box(parts, bx[1], bx[2], skin_col, skin_mat) end
      end
    end
    -- ribs, floor to ceiling, on the long sides (on a face with doors they stay inside the wall)
    if hz == a then
      local ro = cushions and M.RIB_OUT or t
      for _, z in ipairs(stations) do
        if not hits(doors_here, z - 0.6, z + 0.6, imn[2], imx[2], 0.6) then
          skin(box(ext, at(hz, z - 0.6, ax, math.min(x_in, x_in + sg * ro), imn[2]),
            at(hz, z + 0.6, ax, math.max(x_in, x_in + sg * ro), imx[2] + over_up), cc.chrome, S.accent))
        end
      end
    end
    -- frames round every door on this face
    local w0, w1 = sg < 0 and mn[ax] or mx[ax] - t, sg < 0 and mn[ax] + t or mx[ax]
    for _, e in ipairs(doors_here) do
      if e.door.class >= 4 then
        frame(ext, ax, e.rect, sg < 0 and mn[ax] - t or mx[ax] - t, sg < 0 and mn[ax] + t or mx[ax] + t, 1.6, cc)
      else
        frame(ext, ax, e.rect, w0, w1, 0.35, cc)
      end
    end
  end
  -- the ceiling: tiles RIB long by BAND across, giving way to a shaft's hole (flat membrane round it)
  local w = imx[b] - imn[b]
  local cols = math.max(1, math.floor(w / math.max(M.BAND, w / 18) + 0.5))
  for k = 1, nr do
    local s0, s1 = stations[k], stations[k + 1]
    for j = 1, cols do
      local c0, c1 = imn[b] + w * (j - 1) / cols, imn[b] + w * j / cols
      local x0, x1, z0, z1 = c0, c1, s0, s1
      if a == 1 then x0, x1, z0, z1 = s0, s1, c0, c1 end
      if hits(up, x0, x1, z0, z1, 0.6) then
        clip_walls(parts, walls, mn, mx, t, 2, 1, x0, x1, z0, z1, skin_col, skin_mat)
      else
        skin(patch(parts, { x0, imx[2], z0 }, { x1 - x0, 0, 0 }, { 0, 0, z1 - z0 }, -M.DISH, skin_col, skin_mat))
      end
    end
    for j = 1, cols - 1 do
      local c = imn[b] + w * j / cols
      local p0, p1 = at(b, c - 0.4, a, s0, imx[2]), at(b, c + 0.4, a, s1, imx[2] + over_up)
      if not hits(up, math.min(p0[1], p1[1]), math.max(p0[1], p1[1]), math.min(p0[3], p1[3]), math.max(p0[3], p1[3]), 0.6) then
        skin(box(ext, p0, p1, cc.chrome, S.accent))
      end
    end
  end
  for _, z in ipairs(stations) do
    local p0, p1 = at(a, z - 0.6, b, imn[b] - over_side(b, -1), imx[2]), at(a, z + 0.6, b, imx[b] + over_side(b, 1), imx[2] + over_up)
    if not hits(up, math.min(p0[1], p1[1]), math.max(p0[1], p1[1]), math.min(p0[3], p1[3]), math.max(p0[3], p1[3]), 0.6) then
      skin(box(ext, p0, p1, cc.chrome, S.accent))
    end
  end
  for _, e in ipairs(up) do frame(ext, 2, e.rect, mx[2] - t, mx[2] + t, 1.6, cc) end
  -- floors (chitin; a shaft's hole has its frame)
  for _, bx in ipairs(walls) do
    local fa, fs = face_of(bx, mn, mx, t)
    if fa == 2 and fs < 0 then box(parts, bx[1], bx[2], cc.chitin, S.floor) end
  end
  for _, e in ipairs(face_doors(ruin, r, kit, origin, 2, -1)) do frame(ext, 2, e.rect, mn[2] - t, mn[2] + t, 1.6, cc) end
  -- outside: the hide swells into lobes with PIERCE spines over every side without a door and the roof; round a
  -- Villa door, shoulders of hide either side of and above the neighbour that joins on; never over a Seat port or a
  -- shaft (the Seat's passage and the shaft run out through there)
  for _, f in ipairs(SIDES) do
    local ax, sg, name = f[1], f[2], f[3]
    local hz = ax == 1 and 3 or 1
    local xo = sg < 0 and mn[ax] or mx[ax]
    local xi = (sg < 0 and imn[ax] or imx[ax]) + sg * M.DISH
    local out = { 0, 0, 0 }
    out[ax] = sg
    local H = { 0, 0, 0 }
    H[hz] = 1
    local hs = r.id * 13 + ax * 2 + (sg > 0 and 1 or 0)
    local doors_here = fd[name]
    local function strip(u0, u1, y0, y1, seed)
      if u1 - u0 < 8 or y1 - y0 < 8 then return end
      lobes(ext, at(hz, u0, ax, xo, y0), H, u1 - u0, { 0, 1, 0 }, y1 - y0, out, name,
        function(pa, pb) return at(hz, u0 + pa, ax, xi, y0 + pb) end, seed, cc,
        function(pa, pb, sa, sb) return hits(doors_here, u0 + pa, u0 + pa + sa, y0 + pb, y0 + pb + sb, 3) end)
    end
    if not (r.kind == "entrance" and name == "-z") then
      if not villa(doors_here) then
        strip(mn[hz], mx[hz], mn[2], mx[2], hs)
      else
        -- the neighbours flush against this face: shoulders between and beside them, and above each
        local nbs = {}
        for _, o in ipairs(ruin.rooms) do
          if o ~= r and o.class >= 4 then
            local omn, omx = ruinm.room_box(o, kit, origin)
            local touch = sg > 0 and omn[ax] or omx[ax]
            if math.abs(touch - xo) < 0.01 and omn[hz] < mx[hz] and omx[hz] > mn[hz] and omn[2] < mx[2] and omx[2] > mn[2] then
              nbs[#nbs + 1] = { omn, omx }
            end
          end
        end
        table.sort(nbs, function(p1, p2) return p1[1][hz] < p2[1][hz] end)
        local gap = 4
        local u = mn[hz]
        for k, nb in ipairs(nbs) do
          strip(u, nb[1][hz] - gap, mn[2], mx[2], hs + 3 * k)
          strip(math.max(mn[hz], nb[1][hz] - gap), math.min(mx[hz], nb[2][hz] + gap), nb[2][2] + gap, mx[2], hs + 3 * k + 1)
          u = nb[2][hz] + gap
        end
        strip(u, mx[hz], mn[2], mx[2], hs + 2)
      end
    end
  end
  do
    local function roof(x0, x1, z0, z1, seed)
      if x1 - x0 < 8 or z1 - z0 < 8 then return end
      lobes(ext, { x0, mx[2], z0 }, { 0, 0, 1 }, z1 - z0, { 1, 0, 0 }, x1 - x0, { 0, 1, 0 }, "+y",
        function(pa, pb) return { x0 + pb, imx[2] + M.DISH, z0 + pa } end, seed, cc)
    end
    local hs = r.id * 13 + 7
    if #up == 0 then
      roof(mn[1], mx[1], mn[3], mx[3], hs)
    else
      -- round the shaft that rises from here
      local q = up[1].rect
      local g = 6
      roof(mn[1], q[1] - g, mn[3], mx[3], hs)
      roof(q[2] + g, mx[1], mn[3], mx[3], hs + 1)
      roof(math.max(mn[1], q[1] - g), math.min(mx[1], q[2] + g), mn[3], q[3] - g, hs + 2)
      roof(math.max(mn[1], q[1] - g), math.min(mx[1], q[2] + g), q[4] + g, mx[3], hs + 3)
    end
  end
  return n
end

-- a small space (the Seat's passages, the reliquary, the Seat chambers): flat membrane walls, chitin floor, chrome
-- rings every 8 m along a passage; a chamber is one of three: crystal corners, a knot of chrome spines grown out of
-- its back wall, or glowing vein lines on its walls
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
  elseif r.kind == "chamber" and r.id % 3 == 1 then
    -- a knot of chrome spines out of the ceiling's corner, each in its wound
    local c = { mx[1] - t - 1.2, mx[2] - t, mx[3] - t - 1.2 }
    for k = 0, 4 do
      local a = k / 5 * sm.tau
      parts[#parts + 1] = { kind = "cone", c = { 0, 0, 0 }, pos = c, r = 0.25, r1 = 0.02, h = 2.2 + (k % 3) * 0.6, seg = 6,
                            roll = math.pi - 0.5 * sm.cos(a), pitch = 0.5 * sm.sin(a), color = cc.chrome, mat = S.accent }
    end
    parts[#parts + 1] = { kind = "ring", c = { c[1], c[2] - 0.05, c[3] }, rin = 0.3, r = 0.9, h = 0.1, seg = 10, color = cc.wound,
                          mat = S.ring }
  elseif r.kind == "chamber" and r.id % 3 == 2 then
    -- vein lines glowing low along the walls
    for _, z in ipairs({ mn[3] + t + 0.05, mx[3] - t - 0.15 }) do
      box(parts, { mn[1] + t + 0.5, mn[2] + t + 0.9, z }, { mx[1] - t - 0.5, mn[2] + t + 1.0, z + 0.1 }, cc.amethyst, S.rare, 0.9)
      box(parts, { mn[1] + t + 1.5, mn[2] + t + 2.2, z }, { mx[1] - t - 1.5, mn[2] + t + 2.28, z + 0.1 }, cc.amethyst, S.rare, 0.6)
    end
  elseif r.kind == "reliquary" or r.kind == "chamber" then
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
local function core_room(parts, r, kit, origin, slot, cc, engine)
  local mn, mx = ruinm.room_box(r, kit, origin)
  local t = kit.wall
  local f = mn[2] + t
  local k = 0
  local step = math.max(22, (mx[3] - mn[3]) / 18)
  for _, x in ipairs({ mn[1] + t + 6, mx[1] - t - 6 }) do
    for z = mn[3] + 16, mx[3] - 16, step do
      k = k + 1
      cluster(parts, { x, f, z }, 6 + k % 3, 3.2 + (k % 4) * 0.8, k, cc)
    end
  end
  for x = mn[1] + 26, mx[1] - 26, math.max(26, (mx[1] - mn[1]) / 14) do
    k = k + 1
    cluster(parts, { x, f, mx[3] - t - 6 }, 7, 4.5, k, cc)
  end
  if engine then M.engine_parts(parts, engine, f, mx[2] - t, cc) end
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
  -- the valve: eight swollen membrane petals round the opening, bulging out of the face like a sphincter's lips
  local yc, rx, ry = y0 + dh / 2, dw / 2 + 1.5, dh / 2 + 1.5
  for k = 0, 7 do
    local a = k / 8 * sm.tau + 0.2
    local ca, sa = sm.cos(a), sm.sin(a)
    local base = { cx + ca * rx, yc + sa * ry, z - 0.2 }
    local tang, rad = { -sa * 13, ca * 13, 0 }, { ca * 15, sa * 15, 0 }
    skin(patch(ext, vec.sub(base, vec.scale(tang, 0.5)), tang, rad, 7.0 + (k % 3), cc.membrane, S.dominant, 6)).petal = true
  end
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

-- the heart's engine, the still part (view/relic draws its turning rings each frame): a chrome spindle grown floor to
-- ceiling inside the engine column's box, wound rings round its waist, an amethyst heart at mid-height, a ring of
-- chrome roots spreading over the floor and a crown of ribs under the ceiling
function M.engine_parts(parts, e, f, top, cc)
  local c = { (e[1][1] + e[2][1]) / 2, f, (e[1][3] + e[2][3]) / 2 }
  local R = math.min(e[2][1] - e[1][1], e[2][3] - e[1][3]) / 2
  local H = top - f
  local pts = {}
  local prof = { 0.55, 0.0, 0.35, 0.08, 0.22, 0.2, 0.3, 0.35, 0.16, 0.5, 0.3, 0.65, 0.22, 0.8, 0.38, 0.92, 0.5, 1.0 }
  for i = 1, #prof, 2 do pts[#pts + 1] = R * prof[i]; pts[#pts + 1] = H * prof[i + 1] end
  parts[#parts + 1] = { kind = "lathe", c = c, points = pts, seg = 24, color = cc.chrome, mat = S.accent }
  for _, y in ipairs({ 0.2, 0.5, 0.8 }) do
    parts[#parts + 1] = { kind = "ring", c = { c[1], f + H * y - 1, c[3] }, rin = R * 0.25, r = R * 0.42, h = 2.0, seg = 24,
                          color = cc.wound, mat = S.ring }
  end
  parts[#parts + 1] = { kind = "sphere", c = { c[1], f + H * 0.42, c[3] }, r = R * 0.34, h = R * 0.34, seg = 16, rings = 10, color = cc.amethyst,
                        mat = S.rare, emissive = 0.6 }
  for k = 0, 11 do
    local a = k / 12 * sm.tau
    local reach = R * (2.2 + 0.6 * ((k * 7) % 3))
    parts[#parts + 1] = { kind = "box", min = { -1.2, 0, 0 }, max = { 1.2, 1.6, reach }, pos = { c[1], f, c[3] }, yaw = a,
                          color = cc.chrome, mat = S.accent }
    parts[#parts + 1] = { kind = "box", min = { -0.25, 1.6, 0 }, max = { 0.25, 1.7, reach }, pos = { c[1], f, c[3] }, yaw = a,
                          color = cc.amethyst, mat = S.rare, emissive = 1 }
  end
end

-- the engine's turning rings (shared meshes, drawn about the spindle each frame): three gyroscope hoops
function M.engine_rings()
  if cache.rings then return cache.rings end
  local cc = colors()
  cache.rings = {}
  for k = 1, 3 do
    local parts = { { kind = "ring", c = { 0, -0.6, 0 }, rin = 0.92, r = 1.0, h = 0.04 + 0.02 * k, seg = 48, color = cc.chrome,
                      mat = S.accent } }
    for q = 0, 5 do
      local a = q / 6 * sm.tau
      parts[#parts + 1] = { kind = "sphere", c = { sm.cos(a) * 0.96, -0.58, sm.sin(a) * 0.96 }, r = 0.035, h = 0.035, seg = 8, rings = 6,
                            color = cc.amethyst, mat = S.rare, emissive = 1 }
    end
    cache.rings[k] = saucer.mesh.build({ parts = parts })
  end
  return cache.rings
end

-- the far hull: each far room as a few swollen flesh lobes along its length (built once per room, in world units: the
-- flesh's wobble is in metres, so a scaled unit mesh would shred), so the relic reads as grown, not as boxes, from a
-- distance (fix-glow: the old grey hull boxes read boxy)
M.BLOB_SEG = 10
-- the lobes of one far room -> { { c, r, h } ... }: one to four along the long axis, each a little larger than its share
-- of the box so they merge, with a smaller swelling on alternate sides
function M.blobs(rm)
  local d = vec.sub(rm.max, rm.min)
  local long = d[1] >= d[3] and 1 or 3
  local short = d[4 - long]
  local n = math.max(1, math.min(4, math.floor(d[long] / short + 0.5)))
  local out = {}
  for k = 1, n do
    local c = { rm.center[1], rm.center[2], rm.center[3] }
    c[long] = rm.min[long] + d[long] * (k - 0.5) / n
    local r = math.max(short, d[long] / n) * 0.62
    out[#out + 1] = { c = c, r = r, h = d[2] * 0.6 }
    local s = { c[1], c[2] + d[2] * 0.22, c[3] }
    s[4 - long] = c[4 - long] + ((k + (rm.id or 0)) % 2 == 0 and 1 or -1) * short * 0.3
    out[#out + 1] = { c = s, r = r * 0.55, h = d[2] * 0.4 }
  end
  return out
end

function M.blob(rm)
  if rm.far then return rm.far end
  local cc = colors(M.civ_of(nil))
  local parts = {}
  for _, b in ipairs(M.blobs(rm)) do
    parts[#parts + 1] = { kind = "sphere", c = b.c, r = b.r, h = b.h, seg = M.BLOB_SEG, rings = 6, color = cc.membrane,
                          mat = S.dominant }
  end
  rm.far = saucer.mesh.build({ parts = parts })
  return rm.far
end

-- the parts of one room (inside and outside skins, its cradles; the maw's valve; the heart's decor and engine)
local function room_parts(ruin, origin, r, ctx)
  local kit, cc = ctx.kit, ctx.cc
  local parts, ext = {}, {}
  local walls = ctx.by_room[r.id] or {}
  local n = 0
  if r.class >= 4 then
    local mat, c = S.dominant, cc.membrane
    if r.id == ruin.relic.lung then mat = S.lung elseif r.id == ruin.relic.plague then mat, c = S.decay, cc.necrotic end
    n = big_room(parts, ext, ruin, r, kit, origin, walls, cc, mat, c)
    if r.kind == "core" then
      local engine
      for _, sd in ipairs(ruin.solids or {}) do if sd.kind == "engine" and sd.room == r.id then engine = sd end end
      core_room(parts, r, kit, origin, ctx.idol, cc, engine)
    end
    if r.kind == "entrance" then maw(ext, ruin, r, kit, origin, cc) end
  else
    small_room(parts, ruin, r, kit, origin, walls, cc)
  end
  for _, b in ipairs(ruin.relic.bays) do if b.room == r.id then cradle(parts, b, cc) end end
  return parts, ext, n
end

local function context(ruin, civ)
  local kit = ruinm.kit_of(ruin.kit)
  local by_room = {}
  for _, b in ipairs(ruin.walls) do
    local l = by_room[b.room or 1] or {}
    by_room[b.room or 1] = l
    l[#l + 1] = b
  end
  local idol
  for _, s in ipairs(ruin.slots) do if s.idol then idol = s end end
  return { kit = kit, cc = colors(civ or M.civ_of(ruin)), by_room = by_room, idol = idol }
end

-- the parts of one relic (before they become meshes): { rooms = { { room =, parts =, ext = }, ... }, ext = every
-- room's outside skins, cushions }
function M.parts(ruin, origin, civ)
  local ctx = context(ruin, civ)
  local out = { rooms = {}, ext = {}, cushions = 0 }
  for _, r in ipairs(ruin.rooms) do
    local parts, ext, n = room_parts(ruin, origin, r, ctx)
    out.cushions = out.cushions + n
    for _, e in ipairs(ext) do out.ext[#out.ext + 1] = e end
    out.rooms[#out.rooms + 1] = { room = r, parts = parts, ext = ext }
  end
  return out
end

-- the meshes of one relic -> set { rooms = { { id, center, radius, kind, mesh (built when first near) } }, links (the
-- room graph through every door), built (triangles now built), triangles (the most built at once) }. Room meshes are
-- built lazily as the eye comes within KEEP doors of them and freed beyond it, so a relic of a hundred rooms never
-- holds more than the warren round the eye.
M.HOPS = 2            -- doors from the eye's room to the rooms drawn (the heart and its trunks: always, from inside it)
M.KEEP = 3            -- doors from the eye's room within which built room meshes are kept
M.BUILDS = 4          -- room meshes built per frame at most (nearest first; the rest follow on the next frames)
function M.meshes(ruin, origin)
  local civ = M.civ_of(ruin)
  local ck = tostring(ruin.hash) .. ":" .. civ.id
  local hit = cache[ck]
  if hit then return hit end
  local kit = ruinm.kit_of(ruin.kit)
  local set = { rooms = {}, links = {}, built = 0, triangles = 0, ruin = ruin, origin = origin, civ = civ }
  for i, r in ipairs(ruin.rooms) do
    local mn, mx = ruinm.room_box(r, kit, origin)
    set.rooms[i] = { id = r.id, center = vec.scale(vec.add(mn, mx), 0.5), radius = vec.dist(mn, mx) / 2 + 22, kind = r.kind,
                     min = mn, max = mx, villa = r.class >= 4 }
    set.links[i] = {}
  end
  for _, d in ipairs(ruin.doors) do
    if d.a > 0 then
      set.links[d.a][#set.links[d.a] + 1] = d.b
      set.links[d.b][#set.links[d.b] + 1] = d.a
    end
  end
  local lo, hi = ruinm.bounds(ruin, origin, 0)
  set.center = vec.scale(vec.add(lo, hi), 0.5)
  set.radius = vec.dist(lo, hi) / 2 + 20
  cache[ck] = set
  return set
end

-- build one room's mesh now (if it is not built) -> its triangles
function M.ensure(set, i)
  local rm = set.rooms[i]
  if rm.mesh then return rm.tris end
  set.ctx = set.ctx or context(set.ruin, set.civ)
  local parts, ext = room_parts(set.ruin, set.origin, set.ruin.rooms[i], set.ctx)
  for _, e in ipairs(ext) do parts[#parts + 1] = e end
  rm.mesh = saucer.mesh.build({ parts = parts })
  local info = saucer.mesh.info(rm.mesh)
  rm.tris = info and info.triangles or 0
  set.built = set.built + rm.tris
  if set.built > set.triangles then set.triangles = set.built end
  return rm.tris
end

function M.release(set, i)
  local rm = set.rooms[i]
  if not rm.mesh then return end
  saucer.mesh.free(rm.mesh)
  set.built = set.built - rm.tris
  rm.mesh, rm.tris = nil, nil
end

-- the rooms within `hops` doors of room i -> { [index] = doors away }
function M.around(set, i, hops)
  local seen, frontier = { [i] = 0 }, { i }
  for h = 1, hops do
    local nxt = {}
    for _, a in ipairs(frontier) do
      for _, b in ipairs(set.links[a]) do
        if not seen[b] then
          seen[b] = h
          nxt[#nxt + 1] = b
        end
      end
    end
    frontier = nxt
  end
  return seen
end

-- the rooms the eye may see from room i: HOPS doors through the Villa spaces (Seat spaces only one door on, from a
-- Seat space or its hall), and from inside the heart every trunk into it
function M.visible(set, i)
  local out = M.around(set, i, M.HOPS)
  for j, h in pairs(out) do
    if not set.rooms[j].villa and h > 1 and set.rooms[i].villa then out[j] = nil end
  end
  if set.rooms[i].kind == "core" then
    for _, j in ipairs(set.links[i]) do out[j] = 1 end
  end
  return out
end

-- the room index the eye is in (or nil outside the relic)
local function room_index(set, eye)
  for i, rm in ipairs(set.rooms) do
    local mn, mx = rm.min, rm.max
    if eye[1] >= mn[1] and eye[1] <= mx[1] and eye[2] >= mn[2] and eye[2] <= mx[2] and eye[3] >= mn[3] and eye[3] <= mx[3] then
      return i
    end
  end
  return nil
end
M.room_index = room_index

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

-- the relic's lamps: the civ's colours, pools along the big spaces, one over each cradle, the heart's crystals and
-- engine, a glow in every Seat chamber
function M.lamps(ruin, origin, site)
  local kit = ruinm.kit_of(ruin.kit)
  local civ = M.civ_of(ruin)
  local pal = civ.language.lamp_colors
  local lux = require("view.lights").POOL_LUX
  -- add-design-language §2.5: the civ's light model (from its senses) thins and dims the lamps; the Core always
  -- keeps its glow, and an echo civ's lamps ripple (view/lights reads `ripple`), a tidal civ's orbit
  local lm = civ.language.light or { model = "chromatic", lamps = 1, k = 1 }
  local out, n = {}, 0
  local function add(pos, color, reach, k, fixture, keep)
    n = n + 1
    if not keep and (n * 61) % 100 >= math.floor((lm.lamps or 1) * 100 + 0.5) then return end
    out[#out + 1] = { pos = pos, color = color, range = reach, intensity = lux * reach * reach * (k or 1) * (lm.k or 1),
                      fixture = fixture, model = lm.model, phase = n }
  end
  for i, r in ipairs(ruin.rooms) do
    local mn, mx = ruinm.room_box(r, kit, origin)
    local cx, cz = (mn[1] + mx[1]) / 2, (mn[3] + mx[3]) / 2
    local f = mn[2] + kit.wall
    local long = (mx[1] - mn[1]) > (mx[3] - mn[3]) and 1 or 3
    if r.kind == "hall" then
      local c = r.id == ruin.relic.plague and { 0.55, 0.9, 0.45 } or pal[(i % #pal) + 1]
      local q4 = (mx[1] - mn[1]) / 4
      local z4 = (mx[3] - mn[3]) / 4
      for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
        add({ cx + q[1] * q4, f + 6, cz + q[2] * z4 }, c, math.max(24, q4 * 1.4))
      end
      add({ cx, mx[2] - 8, cz }, pal[1], math.max(30, q4 * 2), 0.9)
    elseif r.kind == "trunk" then
      local a = { cx, f + 8, cz }
      local b = { cx, f + 8, cz }
      a[long], b[long] = mn[long] + 20, mx[long] - 20
      add(a, pal[2], 34)
      add(b, pal[3], 34)
    elseif r.kind == "shaft" then
      add({ cx, (mn[2] + mx[2]) / 2, cz }, pal[(i % #pal) + 1], 30)
    elseif r.kind == "core" then
      local qx, qz = (mx[1] - mn[1]) / 4, (mx[3] - mn[3]) / 4
      for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
        add({ cx + q[1] * qx, f + 14, cz + q[2] * qz }, pal[(q[1] + q[2]) % 3 + 2] or pal[1], 110)
      end
      add({ cx, f + (mx[2] - mn[2]) * 0.42, cz }, civ.language.core_color or pal[1], 160, 1.6, nil, true)
      for _, s in ipairs(ruin.slots) do
        if s.idol then add({ s.pos[1], s.pos[2] + 10, s.pos[3] }, civ.language.core_color or pal[1], 40, 1.4, nil, true) end
      end
    elseif r.kind == "entrance" then
      add({ cx, f + 10, cz }, pal[2], 40)
    elseif r.kind == "reliquary" or r.kind == "chamber" then
      add({ cx, mx[2] - kit.wall - 0.6, cz }, pal[(i % #pal) + 1], 12, 1.3, true)
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

-- the heart's engine turning: three hoops about the spindle on their own tilted axes (render-only: a function of the
-- clock, nothing in the state moves)
function M.engine(v, A, ruin, time, opts)
  for _, sd in ipairs(ruin.solids or {}) do
    if sd.kind == "engine" then
      local c = vec.scale(vec.add(sd[1], sd[2]), 0.5)
      local R = math.min(sd[2][1] - sd[1][1], sd[2][3] - sd[1][3]) / 2
      local H = sd[2][2] - sd[1][2]
      local rings = M.engine_rings()
      for k = 1, 3 do
        local rr = R * (1.05 - 0.12 * k)
        v:mesh(rings[k], { pos = { c[1], sd[1][2] + H * (0.3 + 0.12 * k), c[3] }, scale = rr, palette = opts.palette,
                           yaw = time * (0.05 + 0.03 * k) * (k % 2 == 0 and -1 or 1),
                           pitch = 0.35 * sm.sin(time * 0.07 * k + k), roll = 0.25 * k * sm.cos(time * 0.05 + k) })
      end
      local pulse = 0.6 + 0.4 * sm.sin(time * 0.9)
      v:billboard(A.tex.glow, { c[1], sd[1][2] + H * 0.42, c[3] }, R * (1.6 + 0.3 * pulse), { palette = opts.palette,
                  tint = { 0.85, 0.5, 1.0, 0.35 + 0.25 * pulse } })
      return true
    end
  end
  return false
end

-- draw the relic near the eye; -> stats { rooms, culled, built, tris }. Inside the relic only the rooms a few doors
-- from the eye's room draw (and are kept built); outside it the rooms near the eye draw in full and the rest as
-- flesh blobs (M.blobs).
function M.draw(v, A, state, cam, xr, time)
  local render = require("view.render")
  local st = { rooms = 0, culled = 0, built = 0, tris = 0 }
  local i, r, site, set = M.near_relic(state, cam.pos)
  if not i then return st end
  local civ = require("sim.civs").of(state, site)
  matv.apply(v, civ, time)
  local opts = { palette = A.pal.base }
  local here = room_index(set, cam.pos)
  local show, keep
  if here then
    show, keep = M.visible(set, here), M.around(set, here, M.KEEP)
  else
    show, keep = {}, {}
    for j, rm in ipairs(set.rooms) do
      if vec.dist(rm.center, cam.pos) - rm.radius < M.NEAR then show[j], keep[j] = 0, 0 end
    end
  end
  -- build what is missing, nearest first, a few a frame
  local want = {}
  for j in pairs(show) do if not set.rooms[j].mesh then want[#want + 1] = j end end
  table.sort(want, function(x, y) if show[x] ~= show[y] then return show[x] < show[y] end return x < y end)
  for k = 1, math.min(#want, M.BUILDS) do M.ensure(set, want[k]) end
  for j, rm in ipairs(set.rooms) do
    if show[j] and rm.mesh and render.visible(cam, rm.center, rm.radius, xr) then
      v:mesh(rm.mesh, opts)
      st.rooms = st.rooms + 1
      st.tris = st.tris + rm.tris
    else
      if not keep[j] then M.release(set, j) end
      st.culled = st.culled + 1
      if not here and rm.villa and render.visible(cam, rm.center, rm.radius, xr) then
        v:mesh(M.blob(rm), opts)
        st.blobs = (st.blobs or 0) + 1
      end
    end
  end
  st.built = set.built
  -- the heart's engine turns; the phenomena in the rooms drawn
  local core = set.rooms[r.relic.core]
  if show[r.relic.core] and render.visible(cam, core.center, core.radius, xr) then M.engine(v, A, r, time, opts) end
  st.phenomena = require("view.phenomena").draw(v, A, r, show, cam, time, opts)
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
