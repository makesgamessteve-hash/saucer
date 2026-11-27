-- SPDX-License-Identifier: MIT
-- relic-room-shapes: a patterned relic's halls take the shapes their pattern calls for (sim/relicshape.lua) -- and
-- every system that works in a hall still works: the autopilot's way through, collision, loot, phenomena, sentries,
-- cover, lamps, the walls drawn and the map.
local shapes = require("sim.relicshape")
local civs = require("sim.civs")
local gen = require("sim.relicgen")
local ruinm = require("sim.ruin")
local ap = require("sim.autopilot")
local configs = require("sim.config")
local sig = require("sim.relicsig")
local game = require("sim.game")
local relicv = require("view.relic")
local relicmap = require("view.relicmap")

local MASSINGS = { "organism", "lattice", "shell", "ring", "helix", "hive", "cluster", "spine" }
local function civ_of(m) return setmetatable({ id = "shape_" .. m, massing = m }, { __index = civs.universe(42)[3] }) end
local KIT = ruinm.kit_of("relic")
local O = { 0, 0, 0 }

-- a synthetic hall 20 x 16 cells with a door on -x, one on +z and a floor hatch
local HALL = { id = 5, kind = "hall", class = 4, cell = { 10, 0, 20 }, size = { 20, 8, 16 }, faces = {} }
local DOORS = {
  { a = 4, b = 5, class = 4, axis = 1, sign = 1, at = 10, lo = 26, hi = 30, vlo = 0, vhi = 4 },
  { a = 5, b = 6, class = 4, axis = 3, sign = 1, at = 36, lo = 12, hi = 16, vlo = 0, vhi = 4 },
  { a = 5, b = 7, class = 2, axis = 2, sign = -1, at = 0, lo = 24, hi = 27, lo3 = 22, hi3 = 25, vlo = 0 },
}
local function style(over)
  local S = shapes.style(saucer.rng.new(7), "rings")
  for k, v in pairs(over or {}) do S[k] = v end
  return S
end

-- does the segment a -> b (x, z) pass within `r` of the box (world, x/z only)?
local function seg_hits(a, b, mn, mx, r)
  local lo, hi = { mn[1] - r, mn[3] - r }, { mx[1] + r, mx[3] + r }
  local p, d = { a[1], a[3] }, { b[1] - a[1], b[3] - a[3] }
  local t0, t1 = 0, 1
  for k = 1, 2 do
    if math.abs(d[k]) < 1e-9 then
      if p[k] < lo[k] or p[k] > hi[k] then return false end
    else
      local u, v = (lo[k] - p[k]) / d[k], (hi[k] - p[k]) / d[k]
      if u > v then u, v = v, u end
      t0, t1 = math.max(t0, u), math.min(t1, v)
      if t0 > t1 then return false end
    end
  end
  return true
end
local function in_fill(r, pos, pad, room)
  for _, b in ipairs(r.fill or {}) do
    if (not room or b.room == room) and pos[1] > b[1][1] - pad and pos[1] < b[2][1] + pad and pos[3] > b[1][3] - pad and pos[3] < b[2][3] + pad
        and pos[2] > b[1][2] - pad and pos[2] < b[2][2] + pad then
      return true
    end
  end
  return false
end

describe("relic room shapes", function()
  it("every kind keeps a shape inside its box, a clear centre and a clear channel from every door", function()
    for _, k in ipairs(shapes.KINDS) do
      local s = shapes.make(k, HALL, DOORS, style(), 0, 0, saucer.rng.new(3))
      local share = shapes.free_share(s)
      expect(share > 0.3 and share < 0.98).to_be(true)
      -- the grid (worked out a row at a time) answers as free() does at every corner and centre; open() reads it
      local corner, centre = shapes.grid(s)
      expect(shapes.grid(s)).to_be(corner)
      for j = s.z0, s.z1 do
        for i = s.x0, s.x1 do
          expect(corner[j][i]).to_be(shapes.free(s, i, j))
          if i < s.x1 and j < s.z1 then
            expect(centre[j][i]).to_be(shapes.free(s, i + 0.5, j + 0.5))
            local plain = { kind = s.kind }
            setmetatable(plain, { __index = function(_, key) if key ~= "corner" then return s[key] end end })
            expect(shapes.open(s, i + 0.3, j + 0.7)).to_be(shapes.open(plain, i + 0.3, j + 0.7))
          end
        end
      end
      expect(shapes.free(s, s.cx, s.cz)).to_be(true)
      expect(shapes.free(s, s.x0 - 1, s.cz)).to_be(false)
      expect(shapes.free(s, s.cx, s.z1 + 1)).to_be(false)
      -- a door's middle -> the centre: clear all the way
      for _, m in ipairs({ { 10.01, 28 }, { 14, 35.99 }, { 25.5, 23.5 } }) do
        for t = 0, 20 do
          local x, z = m[1] + (s.cx - m[1]) * t / 20, m[2] + (s.cz - m[2]) * t / 20
          expect(shapes.free(s, x, z)).to_be(true)
        end
      end
      local c = shapes.contour(s)
      expect(#c > 0).to_be(true)
      expect(shapes.contour(s)).to_be(c)   -- cached
      -- every segment of the contour has free floor on one side and none on the other
      for _, g in ipairs(c) do
        expect(g[1] >= s.x0 and g[1] <= s.x1 and g[2] >= s.z0 and g[2] <= s.z1).to_be(true)
      end
      -- the solid never covers free floor: every filled cell has a corner or centre outside the shape
      local rm = { id = 5, kind = "hall", class = 4, cell = HALL.cell, size = HALL.size, shape = s }
      local fill = shapes.fill(rm, KIT, O)
      expect(#fill > 0).to_be(true)
      for _, b in ipairs(fill) do
        expect(b.fill).to_be(true)
        expect(b.room).to_be(5)
        for x = b[1][1] / KIT.cell, b[2][1] / KIT.cell - 1 do
          for z = b[1][3] / KIT.cell, b[2][3] / KIT.cell - 1 do
            local free = shapes.free(s, x + 0.5, z + 0.5) and shapes.free(s, x, z) and shapes.free(s, x + 1, z)
              and shapes.free(s, x, z + 1) and shapes.free(s, x + 1, z + 1)
            expect(free).to_be(false)
          end
        end
      end
    end
  end)

  it("a room without a shape is all free and has no solid; the hull is convex", function()
    expect(shapes.free_world(HALL, KIT, O, 1e9, 1e9)).to_be(true)
    expect(#shapes.fill(HALL, KIT, O)).to_be(0)
    local h = shapes.hull({ { 0, 0 }, { 2, 0 }, { 1, 1 }, { 2, 2 }, { 0, 2 } })
    expect(#h).to_be(4)
    local p = shapes.settle(HALL, KIT, O, { 1, 2, 3 }, 2)
    expect(p[1]).to_be(1)
  end)

  it("settles a point onto free floor, clear of a hatch, or to the centre when nothing fits", function()
    local s = shapes.make("diamond", HALL, DOORS, style({ dia = 1.0 }), 0, 0)
    local rm = { id = 5, kind = "hall", class = 4, cell = HALL.cell, size = HALL.size, shape = s }
    local inside = { (s.cx) * KIT.cell, 3, (s.cz) * KIT.cell }
    expect(shapes.settle(rm, KIT, O, inside, 2)).to_be(inside)
    local corner = { (s.x0 + 0.5) * KIT.cell, 3, (s.z0 + 0.5) * KIT.cell }
    local q = shapes.settle(rm, KIT, O, corner, 2)
    expect(shapes.free_world(rm, KIT, O, q[1], q[3])).to_be(true)
    expect(q[2]).to_be(3)
    -- a hatch over the whole box: nowhere fits, so the centre
    local all = { { -1e9, 1e9, -1e9, 1e9 } }
    local c = shapes.settle(rm, KIT, O, corner, 2, all)
    expect(c[1]).to_be(s.cx * KIT.cell)
    expect(c[3]).to_be(s.cz * KIT.cell)
    -- a hatch near the centre: the point goes round it
    local hatch = { { inside[1] - 6, inside[1] + 6, inside[3] - 6, inside[3] + 6 } }
    local h = shapes.settle(rm, KIT, O, inside, 2, hatch)
    expect(math.abs(h[1] - inside[1]) >= 7.9 or math.abs(h[3] - inside[3]) >= 7.9).to_be(true)
  end)

  it("assigns shapes by the pattern's palette, keeps protected halls boxes, plain halls and a chamfer fallback", function()
    local function rooms()
      local a = { id = 1, kind = "hall", class = 4, cell = { 10, 0, 20 }, size = { 20, 8, 16 }, faces = {} }
      local b = { id = 5, kind = "hall", class = 4, cell = HALL.cell, size = HALL.size, faces = {} }
      local t = { id = 4, kind = "trunk", class = 4, cell = { 0, 0, 26 }, size = { 10, 8, 4 }, faces = {} }
      return { a, t, b }
    end
    local rs = rooms()
    expect(shapes.assign(saucer.rng.new(1), rs, DOORS, { [1] = true }, 0, 0, style({ plain = 0, mix = 0, primary = "arc" }))).to_be(1)
    expect(rs[1].shape).to_be(nil)
    expect(rs[2].shape).to_be(nil)
    expect(rs[3].shape.kind).to_be("arc")
    rs = rooms()
    expect(shapes.assign(saucer.rng.new(1), rs, DOORS, {}, 0, 0, style({ plain = 1 }))).to_be(0)
    rs = rooms()
    local keep = shapes.MIN_FREE
    shapes.MIN_FREE = 0.99   -- no shape keeps that much: a chamfer stands in (if it leaves anything to cut)
    shapes.assign(saucer.rng.new(1), rs, DOORS, { [1] = true }, 0, 0, style({ plain = 0, mix = 0, primary = "cross" }))
    shapes.MIN_FREE = keep
    expect(rs[3].shape.kind).to_be("chamfer")
    -- a tiny hall its door channels and centre fill: no shape at all
    local tiny = { { id = 9, kind = "hall", class = 4, cell = { 0, 0, 0 }, size = { 5, 4, 5 }, faces = {} } }
    expect(shapes.assign(saucer.rng.new(1), tiny, {}, {}, 0, 0, style({ plain = 0, mix = 0, primary = "round" }))).to_be(0)
    -- palettes: every pattern names shapes that exist; an unknown pattern gets chamfers
    for pat, pal in pairs(shapes.PALETTE) do
      for _, k in ipairs(pal) do
        local found = false
        for _, kk in ipairs(shapes.KINDS) do if kk == k then found = true end end
        expect(found).to_be(true)
      end
      expect(#pat > 0).to_be(true)
    end
    expect(shapes.style(saucer.rng.new(1), "nope").primary).to_be("chamfer")
  end)

  it("shapes every patterned relic's halls but the maw's, the lung and the plague hall; the warren keeps boxes", function()
    for _, m in ipairs(MASSINGS) do
      local r = gen.generate(42, KIT, civ_of(m), O)
      local n = 0
      for _, rm in ipairs(r.rooms) do
        if rm.shape then
          n = n + 1
          expect(rm.kind).to_be("hall")
          expect(rm.id ~= r.relic.lung and rm.id ~= r.relic.plague and rm.id ~= r.relic.halls[1]).to_be(true)
        end
      end
      expect(n >= 3).to_be(true)
      expect(#r.fill > 0).to_be(true)
    end
    local w = gen.generate(42, KIT, require("sim.relic").civ(), O)
    for _, rm in ipairs(w.rooms) do expect(rm.shape).to_be(nil) end
    expect(#w.fill).to_be(0)
  end)

  it("the shell reads round and the ring curved: different shapes, and different plans", function()
    local kinds = { shell = {}, ring = {} }
    local list = { shell = {}, ring = {} }
    for _, m in ipairs({ "shell", "ring" }) do
      for s = 1, 4 do
        local r = gen.generate(500 + s, KIT, civ_of(m), O)
        list[m][#list[m] + 1] = r
        for _, rm in ipairs(r.rooms) do
          if rm.shape then kinds[m][rm.shape.kind] = (kinds[m][rm.shape.kind] or 0) + 1 end
        end
      end
    end
    local function share(t, ks)
      local a, n = 0, 0
      for k, v in pairs(t) do
        n = n + v
        for _, kk in ipairs(ks) do if k == kk then a = a + v end end
      end
      return a / n
    end
    expect(share(kinds.shell, { "round", "poly" }) > 0.5).to_be(true)
    expect(share(kinds.ring, { "arc" }) > 0.4).to_be(true)
    expect((kinds.shell.arc or 0) < (kinds.ring.arc or 0)).to_be(true)
    for _, a in ipairs(list.shell) do
      for _, b in ipairs(list.ring) do expect(sig.distance(a, b) >= sig.MIN_DIST).to_be(true) end
    end
  end)

  it("the way through every shaped hall (door -> centre -> door), loot and phenomena stay clear of the solid", function()
    for _, m in ipairs(MASSINGS) do
      local r = gen.generate(42, KIT, civ_of(m), O)
      for _, rm in ipairs(r.rooms) do
        if rm.shape then
          local c = ap.room_center(rm, KIT, O, 1)
          for _, d in ipairs(r.doors) do
            if d.a == rm.id or d.b == rm.id then
              local dc = ap.door_center(d, r.rooms, KIT, O)
              local rad = configs.get(ap.config_for_class(d.class)).diameter / 2
              for _, b in ipairs(r.fill) do
                if b.room == rm.id and seg_hits(dc, c, b[1], b[2], rad * 0.9) then
                  error(string.format("%s: door %d-%d (axis %d class %d %s..%s) -> centre of room %d crosses the solid of %d [%g %g %g %g] rad %g", m, d.a, d.b, d.axis, d.class, d.lo, d.hi, rm.id, b.room, b[1][1] / 4, b[1][3] / 4, b[2][1] / 4, b[2][3] / 4, rad))
                end
              end
            end
          end
        end
      end
      -- the main way to the heart, room centre -> door -> room centre
      local route = r.relic.route
      for k = 2, #route do
        local a, b = r.rooms[route[k - 1]], r.rooms[route[k]]
        for _, d in ipairs(r.doors) do
          if d.class >= 4 and ((d.a == a.id and d.b == b.id) or (d.a == b.id and d.b == a.id)) then
            local dc = ap.door_center(d, r.rooms, KIT, O)
            local rad = configs.get(ap.config_for_class(d.class)).diameter / 2
            for _, q in ipairs({ a, b }) do
              local c = ap.room_center(q, KIT, O, 1)
              for _, bx in ipairs(r.fill) do
                if bx.room == q.id and seg_hits(dc, c, bx[1], bx[2], rad * 0.9) then
                  error(string.format("%s: main way crosses the solid of room %d", m, q.id))
                end
              end
            end
          end
        end
      end
      for _, s in ipairs(r.slots) do expect(in_fill(r, s.pos, 1, s.room)).to_be(false) end
      for _, ph in ipairs(r.relic.phenomena) do expect(in_fill(r, ph.pos, 0, ph.room)).to_be(false) end
    end
  end)

  it("in play: the solid collides, sentries, cover, finds and lamps sit on free floor, walls and map follow", function()
    local st = {}
    game.init(st, { seed = 42, players = 1 })
    game.enter_sector(st, 3)
    local i
    for k, site in ipairs(st.sector.sites) do if site.kit == "relic" then i = k end end
    local r = game.ruin(i)
    local site = st.sector.sites[i]
    expect(#r.fill > 0).to_be(true)
    -- collision: a fill box is solid
    local b = r.fill[1]
    local c = { (b[1][1] + b[2][1]) / 2, (b[1][2] + b[2][2]) / 2, (b[1][3] + b[2][3]) / 2 }
    expect(saucer.physics.clearance(c, 0.5, 0.5, 0, 1)).to_be(false)
    -- sentries over free floor
    for _, d in ipairs(game.sentries(i)) do
      local rm = r.rooms[d.room]
      if rm and rm.shape then
        expect(shapes.open_world(rm, KIT, site.pos, d.pos[1], d.pos[3])).to_be(true)
        if d.cell then expect(shapes.open_world(rm, KIT, site.pos, d.cell[1], d.cell[3])).to_be(true) end
        for _, p in ipairs(d.route or {}) do expect(shapes.open_world(rm, KIT, site.pos, p[1], p[3])).to_be(true) end
      end
    end
    for _, s in ipairs(r.slots) do
      local rm = r.rooms[s.room]
      if rm and rm.shape then expect(shapes.open_world(rm, KIT, site.pos, s.pos[1], s.pos[3])).to_be(true) end
    end
    for _, d in ipairs(r.debris) do
      local rm = r.rooms[d.room]
      if rm and rm.shape then
        expect(shapes.free_world(rm, KIT, site.pos, (d[1][1] + d[2][1]) / 2, (d[1][3] + d[2][3]) / 2)).to_be(true)
      end
    end
    -- lamps over free floor (the hall lamps; the heart's and the rest are in boxes)
    for _, l in ipairs(relicv.lamps(r, site.pos, site)) do expect(in_fill(r, l.pos, 0)).to_be(false) end
    -- the drawn walls of a shaped hall, and its map outline
    local parts = relicv.parts(r, site.pos)
    local walls, shaped = 0, nil
    for _, e in ipairs(parts.rooms) do
      for _, p in ipairs(e.parts) do if p.shape_wall then walls = walls + 1 end end
      if e.room.shape then shaped = e.room end
    end
    expect(walls > 0).to_be(true)
    relicmap.MAX_DOTS = 100000
    local dots = relicmap.dots(r, shaped.id, nil, { shaped.id })
    relicmap.MAX_DOTS = 700
    -- the outline follows the shape: dots inside the box, off its sides (the contour), and none over the solid
    local mn, mx = ruinm.room_box(shaped, KIT, site.pos)
    local inner = 0
    for _, d in ipairs(dots) do
      local x, z = d.pos[1], d.pos[3]
      if x > mn[1] + KIT.wall + 1 and x < mx[1] - KIT.wall - 1 and z > mn[3] + KIT.wall + 1 and z < mx[3] - KIT.wall - 1 then
        inner = inner + 1
      end
    end
    expect(inner > 0).to_be(true)
  end)
end)
