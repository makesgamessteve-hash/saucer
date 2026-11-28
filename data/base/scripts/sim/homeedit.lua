-- SPDX-License-Identifier: MIT
-- Edit mode for the Villa (OpenSpec add-home-layout). Pick up a movable
-- built-in or a placed piece, walk it as a ghost, place or cancel, undo.
-- Docked guests act on the host's house; picked-up bought pieces go to the
-- host store. Same-tick grabs use the shared-loot tie-break. The carry itself
-- lives in p.edit and is not saved.
local avatar = require("sim.avatar")
local layout = require("sim.layout")
local walkgrid = require("sim.walkgrid")
local claims = require("sim.claims")
local fold = require("sim.fold")
local configs = require("sim.config")
local data = require("lib.data")
local M = {}

M.REACH = 1.6
M.PICK_RANGE = 2.2

local queue = {}

function M.reset_queue() queue = {} end

local function decor() return require("sim.decor") end

function M.holding(p) return p.edit and p.edit.hold end

function M.on(p) return p.edit and p.edit.on and true or false end

function M.can_start(state, p)
  local host = layout.house(state, p)
  local ship = host.ship
  if not ship then return false, "no saucer" end
  if not configs.get(ship.size).interior then return false, "unfold the Villa first" end
  if ship.morph then return false, "wait until the fold is finished" end
  if p.mode == "helm" then return false, "leave the helm first" end
  if p.mode ~= "walk" and not p.visiting then return false, "walk the decks first" end
  if not fold.rooms_out(ship) then return false, "unfold the Villa first" end
  return true
end

function M.enter(state, p, ctx)
  local ok, why = M.can_start(state, p)
  if not ok then
    if ctx then ctx.msg(state, p, "Can't edit: " .. why); ctx.fx(state, p, "denied") end
    return false, why
  end
  p.edit = { on = true }
  if ctx then ctx.msg(state, p, "Edit mode. Use picks up a piece, Use places it, H cancels, Minus undoes.") end
  return true
end

function M.leave(state, p, ctx, silent)
  if M.holding(p) then M.cancel(state, p, ctx) end
  p.edit = false
  if ctx and not silent then ctx.msg(state, p, "Left edit mode.") end
  return true
end

function M.toggle(state, p, ctx)
  if M.on(p) then return M.leave(state, p, ctx) end
  return M.enter(state, p, ctx)
end

-- snap helpers
local function snap(x) return math.floor(x / 0.25 + 0.5) * 0.25 end

function M.turn_from_yaw(yaw, fine)
  local step = fine and 1 or 6
  local t = math.floor(yaw / layout.STEP + 0.5)
  return (math.floor((t + step / 2) / step) * step) % 24
end

-- a def-like table for a built-in (size, walk, h, place, name, color, look)
function M.builtin_def(f)
  local w, d = layout.size_of(f)
  return {
    id = f.id, name = f.kind:gsub("^%l", string.upper), size = { w, d }, h = f.h or 1,
    walk = f.solid == false, color = f.color, look = f.kind, kind = f.kind, place = f.place or "floor",
    builtin = true,
  }
end

function M.def_of(hold)
  if hold.typ == "builtin" then
    local f = layout.piece(layout.base(), hold.id)
    return f and M.builtin_def(f)
  end
  return decor().furniture(hold.kind)
end

local function body_of(p) return layout.body(p) end

-- where the ghost would stand in front of the body
function M.spot(state, p, def, fine)
  def = def or M.def_of(M.holding(p))
  local host = layout.house(state, p)
  local L = layout.of(host)
  local body = body_of(p)
  local d = avatar.deck_of(L, body)
  local place = (def and def.place) or "floor"
  local yaw = body.yaw
  local turn = M.turn_from_yaw(yaw, fine)
  local depth = (def and def.size and def.size[2] or 0.8) / 2
  local reach = M.REACH + math.max(0, depth - 0.5)
  local sm = saucer.math
  local x = snap(body.pos[1] + sm.sin(yaw) * reach)
  local z = snap(body.pos[3] + sm.cos(yaw) * reach)
  if place == "wall" then
    x, z, turn = M.snap_wall(L, d, body, def, x, z, turn)
  elseif place == "top" then
    x, z = M.snap_top(L, host, d, x, z)
  elseif place == "ceiling" then
    -- same x,z as floor, hangs from the ceiling
  end
  return d, x, z, turn, place
end

function M.snap_wall(L, d, body, def, x, z, turn)
  local best, bd, bt
  local sm = saucer.math
  local lookx, lookz = sm.sin(body.yaw), sm.cos(body.yaw)
  for _, f in ipairs(L.furniture) do
    if f.deck == d and f.box and (f.kind == "wall" or (f.h or 0) >= 1.2) then
      local b = f.box
      local faces = {
        { x = b[1], z0 = b[2], z1 = b[4], axis = "x", dir = -1, midz = (b[2] + b[4]) / 2 },
        { x = b[3], z0 = b[2], z1 = b[4], axis = "x", dir = 1, midz = (b[2] + b[4]) / 2 },
        { z = b[2], x0 = b[1], x1 = b[3], axis = "z", dir = -1, midx = (b[1] + b[3]) / 2 },
        { z = b[4], x0 = b[1], x1 = b[3], axis = "z", dir = 1, midx = (b[1] + b[3]) / 2 },
      }
      for _, fc in ipairs(faces) do
        local px, pz, nx, nz
        if fc.axis == "x" then
          pz = snap(math.max(fc.z0, math.min(fc.z1, z)))
          px = fc.x + fc.dir * ((def.size[2] or 0.08) / 2)
          nx, nz = fc.dir, 0
        else
          px = snap(math.max(fc.x0, math.min(fc.x1, x)))
          pz = fc.z + fc.dir * ((def.size[2] or 0.08) / 2)
          nx, nz = 0, fc.dir
        end
        local dd = (px - body.pos[1]) ^ 2 + (pz - body.pos[3]) ^ 2
        local face = nx * lookx + nz * lookz
        if dd < (M.PICK_RANGE + 1) ^ 2 and face >= -0.2 and (not bd or dd < bd) then
          best, bd = { px, pz }, dd
          -- face outward: yaw along the normal
          bt = M.turn_from_yaw(saucer.math.atan2(nx, nz), false)
        end
      end
    end
  end
  if best then return best[1], best[2], bt or turn end
  return x, z, turn
end

function M.snap_top(L, host, d, x, z)
  local function consider(box, h)
    if h and h >= 0.35 and h < 2.0 and x >= box[1] and x <= box[3] and z >= box[2] and z <= box[4] then
      return true
    end
  end
  for _, f in ipairs(L.furniture) do
    if f.deck == d and f.box and f.solid ~= false and consider(f.box, f.h) then
      return snap(x), snap(z)
    end
  end
  for _, o in ipairs((host.decor and host.decor.placed) or {}) do
    if o.deck == d then
      local def = decor().furniture(o.kind)
      if def and not def.walk and def.place ~= "wall" and def.place ~= "ceiling" and def.place ~= "top" then
        local fp = decor().footprint(def, o.x, o.z, o.q or layout.quarter_to_turn(o.turn) / 6)
        -- footprint uses q quarters; if turn is stored use it
        if o.turn then fp = layout.footprint(def.size[1], def.size[2], o.x, o.z, o.turn) end
        if consider(fp, def.h) then return snap(x), snap(z) end
      end
    end
  end
  return snap(x), snap(z)
end

function M.top_ok(L, host, d, x, z, def)
  local function consider(box, h)
    return h and h >= 0.35 and h < 2.0 and x >= box[1] and x <= box[3] and z >= box[2] and z <= box[4]
  end
  for _, f in ipairs(L.furniture) do
    if f.deck == d and f.box and f.solid ~= false and consider(f.box, f.h) then return true end
  end
  for _, o in ipairs((host.decor and host.decor.placed) or {}) do
    if o.deck == d then
      local od = decor().furniture(o.kind)
      if od and not od.walk and od.place ~= "wall" and od.place ~= "ceiling" and od.place ~= "top" then
        local fp = layout.footprint(od.size[1], od.size[2], o.x, o.z, o.turn or layout.quarter_to_turn(o.q or 0))
        if consider(fp, od.h) then return true end
      end
    end
  end
  return false
end

-- extra solids for reachability: placed furniture (except the one we are moving)
local function extras(host, skip_placed_id)
  local out = {}
  if host.decor then
    for _, o in ipairs(host.decor.placed) do
      if o.id ~= skip_placed_id then
        local def = decor().furniture(o.kind)
        if def and not def.walk and (def.place or "floor") == "floor" then
          local t = o.turn or layout.quarter_to_turn(o.q or 0)
          out[#out + 1] = { deck = o.deck, box = layout.footprint(def.size[1], def.size[2], o.x, o.z, t) }
        end
      end
    end
  end
  return out
end

function M.can_place(state, p, def, d, x, z, turn, skip)
  local host = layout.house(state, p)
  local L = layout.of(host)
  local body = body_of(p)
  local place = (def and def.place) or "floor"
  if place == "top" and not M.top_ok(L, host, d, x, z, def) then
    return false, "needs a table or a shelf"
  end
  -- temporarily apply a built-in move to test collision and reach
  local fake = def
  if def.builtin and def.id then
    -- test on a copied resolved layout by writing a trial move
  end
  local ok, why = decor().can_place(host, def, d, x, z, turn, body, {
    layout = L, skip_id = skip and skip.builtin, skip_placed = skip and skip.placed,
    place = place,
  })
  if not ok then return false, why end
  if not def.walk and place == "floor" then
    local w, dd = def.size[1], def.size[2]
    local fp = layout.footprint(w, dd, x, z, turn)
    local ex = extras(host, skip and skip.placed)
    local trial = L
    if def.builtin and def.id then
      trial = layout.preview(host, def.id, { deck = d, x = x, z = z, turn = turn, w = def.size[1], d = def.size[2] })
      ok, why = walkgrid.stations_ok(trial, ex)
    else
      ex[#ex + 1] = { deck = d, box = fp }
      ok, why = walkgrid.stations_ok(L, ex)
    end
    if not ok then return false, why or "keep the way clear" end
  end
  return true
end

-- The trial set_move in can_place messes with undo? No, it doesn't push undo.
-- But bump increments rev twice - messy for mesh rebuild mid-ghost. Better:
-- can_place for built-ins should use a temporary overlay without writing p.home.
-- I'll add layout.trial(p, id, rec) later if tests show flicker. For now,
-- I'll add a non-mutating trial in walkgrid by injecting an extra solid plus
-- removing the old built-in... removing is harder because L already has the
-- piece at the old spot. For moving, we need L without the old box + new box.

-- FIX: layout.overlay(p, id, rec) returns a layout without writing. I'll add
-- that and use it below if I have time. For can_place I'll implement
-- layout.try_of in a follow-up patch if needed. For now, write/restore is OK
-- if we don't bump twice unnecessarily.

function M.nearest(state, p)
  local host = layout.house(state, p)
  local L = layout.of(host)
  local body = body_of(p)
  if not body then return nil end
  local d = avatar.deck_of(L, body)
  local best, bd, kind
  for _, f in ipairs(L.furniture) do
    if layout.movable(f) and f.deck == d then
      local cx, cz = layout.centre(f)
      local dd = (cx - body.pos[1]) ^ 2 + (cz - body.pos[3]) ^ 2
      if dd <= M.PICK_RANGE ^ 2 and (not bd or dd < bd) then
        best, bd, kind = f.id, dd, "builtin"
      end
    end
  end
  if host.decor then
    for _, o in ipairs(host.decor.placed) do
      if o.deck == d then
        local dd = (o.x - body.pos[1]) ^ 2 + (o.z - body.pos[3]) ^ 2
        if dd <= M.PICK_RANGE ^ 2 and (not bd or dd < bd) then
          best, bd, kind = o.id, dd, "placed"
        end
      end
    end
  end
  if not best then return nil end
  return { typ = kind, id = best }
end

function M.queue(act) queue[#queue + 1] = act end

function M.pick_now(state, p, ctx, target)
  local host = layout.house(state, p)
  if target.typ == "builtin" then
    local L = layout.of(host)
    local f = layout.piece(L, target.id)
    if not f then return false, "gone" end
    local x, z = layout.centre(f)
    local pose = { deck = f.deck, x = x, z = z, turn = f.turn or 0, w = select(1, layout.size_of(layout.piece(layout.base(), target.id) or f)),
                   d = select(2, layout.size_of(layout.piece(layout.base(), target.id) or f)) }
    -- hide it at a parking spot? keep it in layout until placed, but then it
    -- blocks the ghost. Park by removing (set a far flag). We store from=pose
    -- and temporarily move it out of the world via a hidden move? Simpler:
    -- leave it in place until placed, and can_place skips this id.
    p.edit = p.edit or { on = true }
    p.edit.hold = { typ = "builtin", id = target.id, from = pose, kind = f.kind, turn = pose.turn }
    if ctx then ctx.msg(state, p, "Picked up the " .. f.kind:gsub("_", " ") .. ". Walk it into place, Use to set it down.") end
    return true
  end
  -- placed bought piece: remove from host.placed into the carry (not the store yet)
  local D = decor().ensure(host)
  local idx
  for i, o in ipairs(D.placed) do if o.id == target.id then idx = i end end
  if not idx then return false, "gone" end
  local o = table.remove(D.placed, idx)
  p.edit = p.edit or { on = true }
  p.edit.hold = { typ = "placed", id = o.id, kind = o.kind, from = { deck = o.deck, x = o.x, z = o.z, turn = o.turn or layout.quarter_to_turn(o.q or 0) },
                  turn = o.turn or layout.quarter_to_turn(o.q or 0) }
  if ctx then ctx.msg(state, p, "Picked up the " .. decor().furniture(o.kind).name:lower() .. ".") end
  return true
end

function M.start_store(state, p, kind, ctx)
  local host = layout.house(state, p)
  local D = decor().ensure(host)
  if (D.store[kind] or 0) < 1 then return false, "none in storage" end
  local def = decor().furniture(kind)
  if not def then return false, "unknown" end
  D.store[kind] = D.store[kind] - 1
  if D.store[kind] <= 0 then D.store[kind] = nil end
  p.edit = p.edit or { on = true }
  p.edit.on = true
  p.edit.hold = { typ = "store", kind = kind, turn = 0 }
  if ctx then ctx.msg(state, p, "Placing a " .. def.name:lower() .. ". Walk it into place, Use to set it down.") end
  return true
end

function M.cancel(state, p, ctx)
  local hold = M.holding(p)
  if not hold then return false end
  local host = layout.house(state, p)
  if hold.typ == "placed" and hold.from then
    local D = decor().ensure(host)
    D.placed[#D.placed + 1] = { id = hold.id, kind = hold.kind, deck = hold.from.deck, x = hold.from.x, z = hold.from.z,
                                q = math.floor((hold.from.turn or 0) / 6) % 4, turn = hold.from.turn }
  elseif hold.typ == "store" then
    local D = decor().ensure(host)
    D.store[hold.kind] = (D.store[hold.kind] or 0) + 1
  end
  -- builtin stays where it was (we never hid it)
  p.edit.hold = nil
  if ctx then ctx.msg(state, p, "Put it back.") end
  return true
end

function M.place_now(state, p, ctx, d, x, z, turn)
  local hold = M.holding(p)
  if not hold then return false, "nothing in hand" end
  local def = M.def_of(hold)
  if not def then return false, "unknown" end
  local host = layout.house(state, p)
  local skip = { builtin = hold.typ == "builtin" and hold.id, placed = hold.typ == "placed" and hold.id }
  local ok, why = M.can_place(state, p, def, d, x, z, turn, skip)
  if not ok then
    if ctx then ctx.msg(state, p, "Can't place it here: " .. why); ctx.fx(state, p, "denied") end
    return false, why
  end
  if hold.typ == "builtin" then
    local from = hold.from
    layout.set_move(host, hold.id, { deck = d, x = x, z = z, turn = turn, w = def.size[1], d = def.size[2] })
    layout.push_undo(host, { typ = "move", id = hold.id, from = from, to = { deck = d, x = x, z = z, turn = turn, w = def.size[1], d = def.size[2] } })
    if ctx then ctx.msg(state, p, "Placed the " .. hold.kind:gsub("_", " ") .. ".") end
  else
    local D = decor().ensure(host)
    local id = hold.id
    if hold.typ == "store" then
      D.next_id = (D.next_id or 0) + 1
      id = D.next_id
    end
    D.placed[#D.placed + 1] = { id = id, kind = hold.kind, deck = d, x = x, z = z,
                                q = math.floor(turn / 6) % 4, turn = turn }
    layout.push_undo(host, { typ = "place", kind = hold.kind, id = id, from = hold.from,
                             to = { deck = d, x = x, z = z, turn = turn }, was_store = hold.typ == "store" })
    if ctx then
      ctx.msg(state, p, "Placed the " .. (decor().furniture(hold.kind).name or hold.kind):lower() .. ".")
    end
  end
  p.edit.hold = nil
  if ctx then ctx.fx(state, p, "bank") end
  return true
end

-- pack a carried bought piece into the host store (built-ins cannot be packed)
function M.pack(state, p, ctx)
  local hold = M.holding(p)
  if not hold then return false, "nothing in hand" end
  if hold.typ == "builtin" then
    if ctx then ctx.msg(state, p, "Built-in furniture stays in the Villa."); ctx.fx(state, p, "denied") end
    return false, "builtin"
  end
  local host = layout.house(state, p)
  local D = decor().ensure(host)
  D.store[hold.kind] = (D.store[hold.kind] or 0) + 1
  layout.push_undo(host, { typ = "pack", kind = hold.kind, from = hold.from, id = hold.id })
  p.edit.hold = nil
  if ctx then ctx.msg(state, p, "Packed it into storage."); ctx.fx(state, p, "bank") end
  return true
end

function M.undo(state, p, ctx)
  local host = layout.house(state, p)
  if M.holding(p) then
    M.cancel(state, p, ctx)
    return true
  end
  local ev = layout.pop_undo(host)
  if not ev then
    if ctx then ctx.msg(state, p, "Nothing to undo.") end
    return false
  end
  if ev.typ == "move" then
    local from = ev.from
    local home = layout.home_pose(ev.id)
    if from and home and from.x == home.x and from.z == home.z and from.deck == home.deck and (from.turn or 0) == (home.turn or 0) then
      layout.set_move(host, ev.id, nil)
    else
      layout.set_move(host, ev.id, from)
    end
    if ctx then ctx.msg(state, p, "Undid the move.") end
  elseif ev.typ == "place" then
    local D = decor().ensure(host)
    for i, o in ipairs(D.placed) do
      if o.id == ev.id then table.remove(D.placed, i) break end
    end
    if ev.was_store then
      D.store[ev.kind] = (D.store[ev.kind] or 0) + 1
    elseif ev.from then
      D.placed[#D.placed + 1] = { id = ev.id, kind = ev.kind, deck = ev.from.deck, x = ev.from.x, z = ev.from.z,
                                  q = math.floor((ev.from.turn or 0) / 6) % 4, turn = ev.from.turn }
    end
    if ctx then ctx.msg(state, p, "Undid the placement.") end
  elseif ev.typ == "pack" then
    local D = decor().ensure(host)
    D.store[ev.kind] = (D.store[ev.kind] or 0) - 1
    if (D.store[ev.kind] or 0) <= 0 then D.store[ev.kind] = nil end
    if ev.from then
      D.placed[#D.placed + 1] = { id = ev.id, kind = ev.kind, deck = ev.from.deck, x = ev.from.x, z = ev.from.z,
                                  q = math.floor((ev.from.turn or 0) / 6) % 4, turn = ev.from.turn }
    else
      D.store[ev.kind] = (D.store[ev.kind] or 0) + 1
    end
    if ctx then ctx.msg(state, p, "Undid the packing.") end
  end
  return true
end

-- put a carry back before a save (p.edit is not saved)
function M.stow_for_save(state, p)
  if M.holding(p) then M.cancel(state, p, nil) end
  p.edit = nil
end

function M.ghost(state, p, fine)
  local hold = M.holding(p)
  if not hold then return nil end
  local def = M.def_of(hold)
  if not def then return nil end
  local d, x, z, turn, place = M.spot(state, p, def, fine)
  local ok, why = M.can_place(state, p, def, d, x, z, turn, { builtin = hold.typ == "builtin" and hold.id, placed = hold.typ == "placed" and hold.id })
  return { def = def, deck = d, x = x, z = z, turn = turn, place = place, ok = ok, why = why, hold = hold }
end

-- collect Use/edit intents this tick; applied in M.resolve after every player has stepped
function M.step(state, p, cmd, ctx)
  if cmd:pressed("edit") then
    M.toggle(state, p, ctx)
  end
  if cmd:pressed("undo") then
    M.undo(state, p, ctx)
  end
  if not M.on(p) then return false end
  if M.holding(p) and cmd:pressed("menu") then
    M.cancel(state, p, ctx)
    return true
  end
  if cmd:pressed("use") then
    local fine = cmd:held("boost")
    if M.holding(p) then
      local def = M.def_of(M.holding(p))
      local d, x, z, turn = M.spot(state, p, def, fine)
      M.queue({ typ = "place", p = p, d = d, x = x, z = z, turn = turn })
    else
      local t = M.nearest(state, p)
      if t then
        M.queue({ typ = "pick", p = p, target = t })
      else
        return false
      end
    end
    return true
  end
  return false
end

function M.resolve(state, ctx)
  if #queue == 0 then return end
  local acts = queue
  queue = {}
  -- group picks by target key
  local picks = {}
  local places = {}
  for _, a in ipairs(acts) do
    if a.typ == "pick" then
      local k = a.target.typ .. ":" .. tostring(a.target.id)
      picks[k] = picks[k] or { target = a.target, who = {} }
      picks[k].who[#picks[k].who + 1] = a.p
    elseif a.typ == "place" then
      places[#places + 1] = a
    end
  end
  local n = #state.players
  local keys = {}
  for k in pairs(picks) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local g = picks[k]
    local winner = #g.who == 1 and g.who[1] or claims.winner(g.who, state.tick, n)
    for _, pl in ipairs(g.who) do
      if pl == winner then
        if M.on(pl) and not M.holding(pl) then M.pick_now(state, pl, ctx, g.target) end
      elseif ctx then
        ctx.msg(state, pl, "Someone else got there first.")
        ctx.fx(state, pl, "denied")
      end
    end
  end
  -- places: if two people aim at the same footprint, tie-break
  table.sort(places, function(a, b) return a.p.index < b.p.index end)
  local taken = {}
  for _, a in ipairs(places) do
    local key = string.format("%d:%.2f:%.2f", a.d, a.x, a.z)
    if taken[key] then
      local both = { taken[key].p, a.p }
      local w = claims.winner(both, state.tick, n)
      if w ~= a.p then
        if ctx then ctx.msg(state, a.p, "That spot was taken."); ctx.fx(state, a.p, "denied") end
      else
        -- first one already placed; should not happen if we only mark after success
        if ctx then ctx.msg(state, a.p, "That spot was taken."); ctx.fx(state, a.p, "denied") end
      end
    else
      if M.holding(a.p) then
        local ok = M.place_now(state, a.p, ctx, a.d, a.x, a.z, a.turn)
        if ok then taken[key] = a end
      end
    end
  end
end

-- ship systems a guest may not use
M.HOST_ONLY = { lab = true, trade = true, hatch = true, tractor = true, bed = true }

function M.guest_may(kind)
  return not M.HOST_ONLY[kind]
end

return M
