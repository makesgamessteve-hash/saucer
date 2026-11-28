-- SPDX-License-Identifier: MIT
-- A dome that is truly yours (OpenSpec add-home-among-stars, concept §3.3):
--   * Furniture: pieces you own (p.decor.store, kind -> count) are placed from
--     the Home planner in front of you, snapped to a 0.25 m grid and quarter
--     turns; placed pieces (p.decor.placed) are solid for anyone walking the
--     dome, guests included, and can be picked up again.
--   * Display slots: six plinths; Use one to put an identified find from your
--     hold on it (or take it back). Displayed finds leave the hold.
--   * Garden: four beds behind the stairwell; plant an alien seed, water it,
--     and it grows over sim time to a harvest for the kitchen.
--   * Comfort: furniture, displayed finds and growing plants add up to a
--     Comfort score that speeds up Charge regeneration.
-- Everything lives in p.decor (created on first use, so a game that never
-- decorates keeps its old state hashes).
local avatar = require("sim.avatar")
local data = require("lib.data")
local items = require("sim.items")
local clock = require("sim.clock")
local panel = require("sim.panel")
local vec = require("lib.vec")
local M = {}

M.GRID = 0.25
M.REACH = 1.6        -- a new piece lands this far in front of you (to its centre)
M.PICK_RANGE = 2.2   -- Pick up takes the nearest piece within this

function M.defs() return data.load("home/decor.lua") end

local function find(list, id)
  for _, d in ipairs(list) do
    if d.id == id then return d end
  end
  return nil
end
function M.furniture(id) return find(M.defs().furniture, id) end
function M.seed(id) return find(M.defs().seeds, id) end

function M.ensure(p)
  if not p.decor then
    local st = M.defs().start or {}
    p.decor = { store = {}, placed = {}, display = {}, garden = {}, seeds = {}, next_id = 0, visitors = 0 }
    for k, v in pairs(st.furniture or {}) do p.decor.store[k] = v end
    for k, v in pairs(st.seeds or {}) do p.decor.seeds[k] = v end
  end
  return p.decor
end

-- read-only: p.decor, or what it would start as (never stored; panels and
-- the HUD call this, and render must not change the sim)
function M.view(p)
  if p.decor then return p.decor end
  local st = M.defs().start or {}
  local v = { store = {}, placed = {}, display = {}, garden = {}, seeds = {}, next_id = 0, visitors = 0 }
  for k, n in pairs(st.furniture or {}) do v.store[k] = n end
  for k, n in pairs(st.seeds or {}) do v.seeds[k] = n end
  return v
end

-- ---------- furniture ----------
local function snap(x) return math.floor(x / M.GRID + 0.5) * M.GRID end
local function quarter(yaw) return (math.floor(yaw / (math.pi / 2) + 0.5) % 4) end

-- the footprint { x0, z0, x1, z1 } of a piece at (x, z) turned q quarters
function M.footprint(def, x, z, q)
  local w, dd = def.size[1], def.size[2]
  if q % 2 == 1 then w, dd = dd, w end
  return { x - w / 2, z - dd / 2, x + w / 2, z + dd / 2 }
end

function M.foot_of(def, x, z, q, turn)
  if turn then return require("sim.layout").footprint(def.size[1], def.size[2], x, z, turn) end
  return M.footprint(def, x, z, q or 0)
end

local function overlap(a, b, m)
  m = m or 0
  return a[1] < b[3] + m and a[3] > b[1] - m and a[2] < b[4] + m and a[4] > b[2] - m
end

-- can `def` stand at (x, z) on deck d turned q quarters (or opts.turn in 15°
-- steps)? -> ok, why. opts.layout, opts.skip_id (a built-in), opts.skip_placed
-- and opts.place are used by edit mode.
function M.can_place(p, def, d, x, z, q, body, opts)
  opts = opts or {}
  local layout = require("sim.layout")
  local L = opts.layout or layout.of(p)
  local turn = opts.turn
  if not turn and type(q) == "number" and q >= 4 then turn = q end
  local fp = M.foot_of(def, x, z, q, turn)
  local place = opts.place or def.place or "floor"
  local deck = L.decks[d]
  if not deck or d > 2 then return false, "not on this deck" end
  local R = deck.radius - 0.35
  for _, c in ipairs({ { fp[1], fp[2] }, { fp[1], fp[4] }, { fp[3], fp[2] }, { fp[3], fp[4] } }) do
    if c[1] * c[1] + c[2] * c[2] > R * R then return false, "too close to the hull" end
  end
  local floorish = place == "floor"
  if floorish then
    for _, f in ipairs(L.furniture) do
      if f.id and opts.skip_id and f.id == opts.skip_id then
        -- the piece being moved
      elseif f.deck == d and f.box and (f.solid ~= false or f.kind == "rug") and not (def.walk and f.kind == "rug") then
        if overlap(fp, f.box, def.walk and -0.01 or 0.05) and not (def.walk and f.solid == false) then
          return false, "something is in the way"
        end
      elseif f.deck == d and f.circle then
        local c = f.circle
        local cx, cz = vec.clamp(c[1], fp[1], fp[3]), vec.clamp(c[2], fp[2], fp[4])
        if (cx - c[1]) ^ 2 + (cz - c[2]) ^ 2 < (c[3] + 0.1) ^ 2 then return false, "something is in the way" end
      end
    end
    for _, k in ipairs(L.keep_clear or {}) do
      if k.deck == d and overlap(fp, k.box) then return false, "keep the way clear" end
    end
    for _, door in ipairs(L.doors or {}) do
      if door.deck == d and overlap(fp, door.box, 0.8) then return false, "keep the door clear" end
    end
    for _, st in ipairs(L.stations or {}) do
      if st.deck == d then
        local cx, cz = vec.clamp(st.pos[1], fp[1], fp[3]), vec.clamp(st.pos[3], fp[2], fp[4])
        if (cx - st.pos[1]) ^ 2 + (cz - st.pos[3]) ^ 2 < 0.55 ^ 2 then return false, "it would block a station" end
      end
    end
  end
  local D = M.view(p)
  for _, o in ipairs(D.placed) do
    if opts.skip_placed and o.id == opts.skip_placed then
      -- the piece being moved
    else
      local od = M.furniture(o.kind)
      local ot = o.turn
      if o.deck == d and od and overlap(fp, M.foot_of(od, o.x, o.z, o.q, ot), 0.02) and not (def.walk or od.walk) then
        local same = (place == "floor" and (od.place or "floor") == "floor")
          or (place ~= "floor" and (od.place or "floor") == place)
        if same then return false, "another piece is there" end
      end
    end
  end
  if body and not def.walk and floorish then
    local cx, cz = vec.clamp(body.pos[1], fp[1], fp[3]), vec.clamp(body.pos[3], fp[2], fp[4])
    if (cx - body.pos[1]) ^ 2 + (cz - body.pos[3]) ^ 2 < (L.body_radius + 0.05) ^ 2 then return false, "you are in the way" end
  end
  return true
end

-- where a piece would go in front of the body -> deck, x, z, q
function M.spot(body, def)
  local L = avatar.layout()
  local d = avatar.deck_of(L, body)
  local depth = def.size[2] / 2
  local reach = M.REACH + math.max(0, depth - 0.5)
  local x = snap(body.pos[1] + saucer.math.sin(body.yaw) * reach)
  local z = snap(body.pos[3] + saucer.math.cos(body.yaw) * reach)
  return d, x, z, quarter(body.yaw)
end

function M.place(state, p, kind, ctx)
  local host = require("sim.layout").house(state, p)
  local D = M.ensure(host)
  local def = M.furniture(kind)
  if not def or (D.store[kind] or 0) < 1 then return false, "none in storage" end
  if p.mode ~= "walk" and not p.visiting then return false, "walk your own dome" end
  local body = require("sim.layout").body(p)
  local d, x, z, q = M.spot(body, def)
  local ok, why = M.can_place(host, def, d, x, z, q, body)
  if not ok then
    if ctx then
      ctx.msg(state, p, "Can't place the " .. def.name:lower() .. " here: " .. why)
      ctx.fx(state, p, "denied")
    end
    return false, why
  end
  D.next_id = D.next_id + 1
  D.placed[#D.placed + 1] = { id = D.next_id, kind = kind, deck = d, x = x, z = z, q = q }
  D.store[kind] = D.store[kind] - 1
  if D.store[kind] <= 0 then D.store[kind] = nil end
  if ctx then
    ctx.msg(state, p, string.format("Placed the %s. Comfort %d (%s)", def.name:lower(), M.comfort(state, p), M.level(state, p)))
    ctx.fx(state, p, "bank")
  end
  return true
end

-- the placed piece nearest the body on its deck (within PICK_RANGE)
function M.nearest(p)
  local D = M.view(p)
  local L = require("sim.layout").of(p)
  local body = require("sim.layout").body(p)
  if not body then return nil end
  local d = avatar.deck_of(L, body)
  local best, bd
  for i, o in ipairs(D.placed) do
    if o.deck == d then
      local dd = (o.x - body.pos[1]) ^ 2 + (o.z - body.pos[3]) ^ 2
      if dd <= M.PICK_RANGE ^ 2 and (not bd or dd < bd) then best, bd = i, dd end
    end
  end
  return best
end

function M.pick_up(state, p, ctx)
  local D = M.ensure(p)
  local i = M.nearest(p)
  if not i then return false end
  local o = table.remove(D.placed, i)
  D.store[o.kind] = (D.store[o.kind] or 0) + 1
  if ctx then ctx.msg(state, p, "Packed away the " .. M.furniture(o.kind).name:lower()) end
  return true
end

-- placed furniture as extra solids for walking ({ deck =, box = })
function M.solids(p)
  local out = {}
  if not p.decor then return out end
  for _, o in ipairs(p.decor.placed) do
    local def = M.furniture(o.kind)
    if def and not def.walk then out[#out + 1] = { deck = o.deck, box = M.footprint(def, o.x, o.z, o.q) } end
  end
  return out
end

function M.buy_furniture(p, id)
  local D = M.ensure(p)
  D.store[id] = (D.store[id] or 0) + 1
end

function M.buy_seeds(p, id, n)
  local D = M.ensure(p)
  D.seeds[id] = (D.seeds[id] or 0) + (n or 1)
end

-- ---------- display slots ----------
function M.displayable(it)
  return it and not it.echo and it.ident and not (it.home and it.home.kind == "program") and true or false
end

function M.show(state, p, slot, uid, ctx)
  local host = require("sim.layout").house(state, p)
  local D = M.ensure(host)
  local L = require("sim.layout").of(host)
  if not L.display[slot] or D.display[slot] then return false end
  local it = items.find(p, uid)
  if not M.displayable(it) then return false end
  items.remove(p, uid)
  it.hot = false
  D.display[slot] = it
  if ctx then
    ctx.msg(state, p, string.format("On display: %s. Comfort %d (%s)", items.label(it), M.comfort(state, host), M.level(state, host)))
    ctx.fx(state, p, "bank")
  end
  return true
end

function M.unshow(state, p, slot, ctx)
  local host = require("sim.layout").house(state, p)
  local D = M.ensure(host)
  local it = D.display[slot]
  if not it then return false end
  if #host.hold >= require("sim.upgrades").hold_slots(host) then
    if ctx then ctx.msg(state, p, "The hold is full") end
    return false
  end
  D.display[slot] = nil
  host.hold[#host.hold + 1] = it
  if ctx then ctx.msg(state, p, "Took " .. items.label(it) .. " back into the hold") end
  return true
end

function M.display_count(p)
  local n = 0
  for _, it in pairs(p.decor and p.decor.display or {}) do if it then n = n + 1 end end
  return n
end

-- ---------- garden ----------
-- growth so far, counting the watered time since the bed was last updated
function M.growth(state, bed)
  local def = M.seed(bed.seed)
  local now = clock.minutes(state)
  local to = math.min(now, (bed.watered or -1e9) + M.defs().water_minutes)
  local g = (bed.growth or 0) + math.max(0, to - (bed.last or now))
  return math.min(def and def.minutes or 30, g)
end

function M.stage(state, bed)
  if not bed or not bed.seed then return 0 end
  local def = M.seed(bed.seed)
  local n = #M.defs().stages
  local f = M.growth(state, bed) / (def and def.minutes or 30)
  return math.min(n, 1 + math.floor(f * (n - 1) + 1e-9))
end

function M.plant(state, p, bed_i, seed, ctx)
  local host = require("sim.layout").house(state, p)
  local D = M.ensure(host)
  local L = require("sim.layout").of(host)
  if not L.garden[bed_i] or D.garden[bed_i] then return false end
  if (D.seeds[seed] or 0) < 1 then return false end
  D.seeds[seed] = D.seeds[seed] - 1
  if D.seeds[seed] <= 0 then D.seeds[seed] = nil end
  D.garden[bed_i] = { seed = seed, growth = 0, watered = clock.minutes(state), last = clock.minutes(state) }
  if ctx then ctx.msg(state, p, "Planted " .. M.seed(seed).name .. ". Water it now and then.") end
  return true
end

function M.water(state, p, bed_i, ctx)
  local host = require("sim.layout").house(state, p)
  local bed = M.ensure(host).garden[bed_i]
  if not bed then return false end
  M.grow(state, host)
  bed.watered = clock.minutes(state)
  if ctx then ctx.msg(state, p, "You water the " .. M.seed(bed.seed).name:lower() .. ".") end
  return true
end

function M.harvest(state, p, bed_i, ctx)
  local host = require("sim.layout").house(state, p)
  local bed = M.ensure(host).garden[bed_i]
  M.grow(state, host)
  if not bed or M.stage(state, bed) < #M.defs().stages then return false end
  local def = M.seed(bed.seed)
  require("sim.kitchen").stock(host, def.harvest, 1)
  bed.growth = 0
  bed.harvests = (bed.harvests or 0) + 1
  if ctx then
    ctx.msg(state, p, string.format("Harvested %s: 1 %s for the kitchen", def.name, require("sim.kitchen").name(def.harvest)))
    ctx.fx(state, p, "bank")
  end
  return true
end

-- plants grow while watered (watering lasts water_minutes); brought up to
-- date whenever the garden is used (growth is a pure function of the clock)
function M.grow(state, p)
  if not p.decor then return end
  local now = clock.minutes(state)
  for _, bed in pairs(p.decor.garden) do
    if bed then
      bed.growth = M.growth(state, bed)
      bed.last = now
    end
  end
end

-- ---------- Comfort ----------
function M.comfort(state, p)
  if not p.decor then return 0 end
  local D = p.decor
  local defs = M.defs()
  local total, seen = 0, {}
  local function add(kind, v)
    local n = seen[kind] or 0
    seen[kind] = n + 1
    total = total + v / (2 ^ n)
  end
  for _, o in ipairs(D.placed) do
    local def = M.furniture(o.kind)
    if def then add("f:" .. o.kind, def.comfort) end
  end
  for _, it in pairs(D.display) do
    if it then
      local v = it.category == "curio" and defs.display.curio or defs.display.other
      add("d:" .. tostring(it.type or it.name), v)
    end
  end
  for _, bed in pairs(D.garden) do
    if bed then
      local def = M.seed(bed.seed)
      local st = M.stage(state, bed)
      add("g:" .. bed.seed, (def and def.comfort or 1) * (st >= 3 and 1 or 0.5))
    end
  end
  return math.floor(total + 1e-6)
end

function M.level(state, p)
  local c = M.comfort(state, p)
  local name = M.defs().levels[1].name
  for _, l in ipairs(M.defs().levels) do
    if c >= l.at then name = l.name end
  end
  return name
end

-- Charge regeneration factor from Comfort
function M.regen_factor(state, p)
  if not p.decor then return 1 end
  local d = M.defs()
  return 1 + math.min(d.regen_cap, M.comfort(state, p) * d.regen_per_point)
end

-- ---------- a guest admiring the host's dome ----------
function M.admire(state, guest, host, slot, ctx)
  local it = host.decor and host.decor.display[slot]
  if not it then return false end
  guest.admired = guest.admired or {}
  guest.admired[#guest.admired + 1] = { host = host.index, slot = slot, name = items.label(it) }
  ctx.msg(state, guest, string.format("P%d's display: %s", host.index, items.label(it)))
  ctx.msg(state, host, string.format("P%d admires your %s", guest.index, items.label(it)))
  return true
end

-- ---------- panels ----------
local function close_row() return { text = "Close", act = function(_, pl) panel.close(pl) end } end

function M.planner_rows(state, p, ctx)
  local host = require("sim.layout").house(state, p)
  local homeedit = require("sim.homeedit")
  local D = M.view(host)
  local rows = { { text = string.format("Comfort %d - %s (Charge x%.2f)", M.comfort(state, host), M.level(state, host),
    M.regen_factor(state, host)), enabled = false } }
  if homeedit.on(p) then
    rows[#rows + 1] = { text = "Leave edit mode", act = function(st, pl)
      homeedit.leave(st, pl, ctx); panel.close(pl)
    end }
    if homeedit.holding(p) then
      rows[#rows + 1] = { text = "Cancel this move", act = function(st, pl) homeedit.cancel(st, pl, ctx) end }
    end
  else
    rows[#rows + 1] = { text = "Enter edit mode", act = function(st, pl)
      if homeedit.enter(st, pl, ctx) then panel.close(pl) end
    end }
  end
  rows[#rows + 1] = { text = "Undo last change", act = function(st, pl) homeedit.undo(st, pl, ctx) end }
  for _, def in ipairs(M.defs().furniture) do
    local n = D.store[def.id] or 0
    if n > 0 then
      local kind = def.id
      rows[#rows + 1] = { text = string.format("Place %s (%d)", def.name, n), act = function(st, pl)
        if homeedit.start_store(st, pl, kind, ctx) then panel.close(pl) end
      end }
    end
  end
  local i = M.nearest(host)
  if i then
    rows[#rows + 1] = { text = "Pack away the " .. M.furniture(D.placed[i].kind).name:lower(),
      act = function(st, pl)
        -- pack into the host store (never the guest's)
        local body_p = pl
        -- nearest is on host; pick_up uses p, so run it as if on the host
        M.pick_up(st, host, ctx)
      end }
  end
  rows[#rows + 1] = { text = string.format("Placed: %d pieces, %d on display, %d beds planted", #D.placed,
    M.display_count(p), (function() local n = 0 for _ in pairs(D.garden) do n = n + 1 end return n end)()), enabled = false }
  rows[#rows + 1] = close_row()
  return rows
end

function M.display_rows(state, p, ctx)
  local host = require("sim.layout").house(state, p)
  local L = require("sim.layout").of(host)
  local body = require("sim.layout").body(p)
  local st = body and avatar.station(L, body)
  local slot = (p.panel and p.panel.slot) or (st and st.slot) or 1
  local D = M.view(host)
  local rows = {}
  if D.display[slot] then
    rows[#rows + 1] = { text = "On display: " .. items.label(D.display[slot]), enabled = false }
    rows[#rows + 1] = { text = "Take it back", act = function(s2, pl) M.unshow(s2, pl, slot, ctx) end }
  else
    for _, it in ipairs(p.hold) do
      if M.displayable(it) then
        local uid = it.uid
        rows[#rows + 1] = { text = "Display " .. items.label(it), act = function(s2, pl)
          if M.show(s2, pl, slot, uid, ctx) then panel.close(pl) end
        end }
      end
    end
    if #rows == 0 then rows[1] = { text = "Nothing identified in your hold to display", enabled = false } end
  end
  rows[#rows + 1] = close_row()
  return rows
end

function M.garden_rows(state, p, ctx)
  local host = require("sim.layout").house(state, p)
  local D = M.view(host)
  local L = require("sim.layout").of(host)
  local stages = M.defs().stages
  local rows = {}
  for i = 1, #L.garden do
    local bed = D.garden[i]
    local bi = i
    if bed then
      local def = M.seed(bed.seed)
      local st = M.stage(state, bed)
      local dry = clock.minutes(state) > (bed.watered or -1e9) + M.defs().water_minutes
      rows[#rows + 1] = { text = string.format("Bed %d: %s, %s%s", i, def.name, stages[st], dry and " (dry)" or ""),
        enabled = false }
      if st >= #stages then
        rows[#rows + 1] = { text = string.format("Harvest bed %d", i), act = function(s2, pl) M.harvest(s2, pl, bi, ctx) end }
      else
        rows[#rows + 1] = { text = string.format("Water bed %d", i), act = function(s2, pl) M.water(s2, pl, bi, ctx) end }
      end
    else
      local any = false
      for _, sd in ipairs(M.defs().seeds) do
        if (D.seeds[sd.id] or 0) > 0 then
          any = true
          local sid = sd.id
          rows[#rows + 1] = { text = string.format("Plant %s in bed %d (%d)", sd.name, i, D.seeds[sd.id]),
            act = function(s2, pl) M.plant(s2, pl, bi, sid, ctx) end }
        end
      end
      if not any then rows[#rows + 1] = { text = string.format("Bed %d: empty (buy seeds at a trader)", i), enabled = false } end
    end
  end
  rows[#rows + 1] = close_row()
  return rows
end

function M.register(home, ctx)
  home.USE.planner = function(state, p) M.ensure(require("sim.layout").house(state, p)); panel.open(p, "planner") end
  home.USE.display = function(state, p, st) M.ensure(require("sim.layout").house(state, p)); panel.open(p, "display"); p.panel.slot = st.slot end
  home.USE.garden = function(state, p) M.ensure(require("sim.layout").house(state, p)); panel.open(p, "garden") end
  panel.register("planner", { title = "HOME PLANNER", rows = function(s, p) return M.planner_rows(s, p, ctx) end })
  panel.register("display", { title = "DISPLAY SLOT", rows = function(s, p) return M.display_rows(s, p, ctx) end })
  panel.register("garden", { title = "GARDEN", rows = function(s, p) return M.garden_rows(s, p, ctx) end })
end

return M
