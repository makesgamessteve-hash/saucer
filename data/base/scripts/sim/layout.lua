-- SPDX-License-Identifier: MIT
-- Per-saucer interior layout (OpenSpec add-home-layout). The base table in
-- saucer/interior.lua is shared. When a player has moved a built-in, of(p)
-- returns a shallow copy with a new furniture (and maybe stations) array.
-- p.home is created on first use so a game that never edits keeps its hashes
-- (apart from the VERSION 25 field itself).
local data = require("lib.data")
local M = {}

M.STEP = math.pi / 12   -- 15°
M.UNDO_MAX = 20

local cache = {}

function M.base() return data.load("saucer/interior.lua") end

function M.reset_cache() cache = {} end

function M.house(state, p)
  if p.visiting and state and state.players[p.visiting] then return state.players[p.visiting] end
  return p
end

function M.body(p) return p.vbody or p.body end

function M.ensure(p)
  if not p.home then
    p.home = { layout = nil, plan = nil, pots = nil, pantry2 = nil, annex = nil, pets = nil, undo = nil }
  end
  return p.home
end

function M.view(p)
  if p.home then return p.home end
  return { layout = nil, plan = nil, pots = nil, pantry2 = nil, annex = nil, pets = nil, undo = nil }
end

function M.has_moves(p)
  -- use rev, not next(moved): next() is raw and misses the read-only proxies
  -- on_render wraps state in, so a next() check would always look empty.
  local lay = p and p.home and p.home.layout
  return lay and (lay.rev or 0) > 0 and true or false
end

-- iterate moved under both real tables and read-only render proxies
function M.each_moved(moved)
  local ids = {}
  if moved then
    for id in pairs(moved) do ids[#ids + 1] = id end
    table.sort(ids)
  end
  local i = 0
  return function()
    i = i + 1
    local id = ids[i]
    if not id then return nil end
    return id, moved[id]
  end
end

function M.rev(p)
  if not M.has_moves(p) then return 0 end
  return p.home.layout.rev or 1
end

function M.movable(f)
  return f and f.id and not f.fixed and true or false
end

function M.piece(L, id)
  for _, f in ipairs(L.furniture or {}) do
    if f.id == id then return f end
  end
  return nil
end

function M.centre(f)
  if f.circle then return f.circle[1], f.circle[2] end
  local b = f.box
  return (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
end

function M.size_of(f)
  if f.circle then
    local r = f.circle[3] * 2
    return r, r
  end
  local b = f.box
  return b[3] - b[1], b[4] - b[2]
end

-- axis-aligned box of a w x d piece at (x, z) with turn in 15° steps
function M.footprint(w, d, x, z, turn)
  turn = turn or 0
  local q = turn % 24
  if q % 6 == 0 then
    if (q / 6) % 2 == 1 then w, d = d, w end
    return { x - w / 2, z - d / 2, x + w / 2, z + d / 2 }
  end
  local a = q * M.STEP
  local sm = saucer.math
  local c, s = math.abs(sm.cos(a)), math.abs(sm.sin(a))
  local hw, hd = (w * c + d * s) / 2, (w * s + d * c) / 2
  return { x - hw, z - hd, x + hw, z + hd }
end

function M.yaw(turn) return (turn or 0) * M.STEP end

function M.quarter_to_turn(q) return ((q or 0) % 4) * 6 end

local function copy_vec(v)
  if not v then return nil end
  local n = {}
  for i, x in ipairs(v) do n[i] = x end
  return n
end

local function copy_piece(f)
  local n = {}
  for k, v in pairs(f) do
    if k == "box" or k == "color" or k == "circle" then n[k] = copy_vec(v) else n[k] = v end
  end
  return n
end

local function apply_one(f, rec)
  f.deck = rec.deck or f.deck
  local w, d = M.size_of(f)
  -- size_of on an already-rotated piece would swap; store rest size
  w, d = rec.w or w, rec.d or d
  local fp = M.footprint(w, d, rec.x, rec.z, rec.turn)
  if f.box then f.box = fp end
  if f.circle then f.circle = { rec.x, rec.z, f.circle[3] } end
  f.turn = rec.turn
  f.moved = true
end

local function follow_stations(L)
  for _, f in ipairs(L.furniture) do
    if f.station and f.moved then
      local cx, cz = M.centre(f)
      for _, st in ipairs(L.stations or {}) do
        if st.id == f.station or st.kind == f.station then
          st.pos = { cx, L.decks[f.deck].floor, cz }
          st.deck = f.deck
        end
      end
      if L.nav and L.nav.nodes and L.nav.nodes[f.station] then
        local n = L.nav.nodes[f.station]
        L.nav.nodes[f.station] = { cx, L.decks[f.deck].floor, cz }
        n = n -- keep
      end
    end
  end
end

function M.resolve_moved(moved)
  -- do not use next(moved): it is raw and misses read-only render proxies
  if not moved then return M.base() end
  local B = M.base()
  local L = {}
  for k, v in pairs(B) do L[k] = v end
  L.furniture = {}
  for i, f in ipairs(B.furniture) do L.furniture[i] = copy_piece(f) end
  if B.stations then
    L.stations = {}
    for i, st in ipairs(B.stations) do
      local s = {}
      for k, v in pairs(st) do s[k] = v end
      if st.pos then s.pos = copy_vec(st.pos) end
      L.stations[i] = s
    end
  end
  if B.nav then
    L.nav = { links = B.nav.links, nodes = {} }
    for name, n in saucer.util.sorted_pairs(B.nav.nodes) do
      L.nav.nodes[name] = copy_vec(n)
    end
  end
  for id, mv in M.each_moved(moved) do
    local f = M.piece(L, id)
    if f then
      local bf = M.piece(B, id)
      local w, d = M.size_of(bf)
      local rec = { deck = mv.deck, x = mv.x, z = mv.z, turn = mv.turn, w = mv.w or w, d = mv.d or d }
      apply_one(f, rec)
    end
  end
  follow_stations(L)
  return L
end

function M.of(p)
  if not M.has_moves(p) then return M.base() end
  local rec = p.home.layout
  local key = p
  local hit = cache[key]
  if hit and hit.rev == rec.rev and hit.moved == rec.moved then return hit.L end
  local L = M.resolve_moved(rec.moved)
  L.rev = rec.rev or 1
  cache[key] = { rev = rec.rev, moved = rec.moved, L = L }
  return L
end

-- a layout with one extra or replacement move, without writing p.home
function M.preview(p, id, rec)
  local moved = {}
  if M.has_moves(p) then
    for k, v in M.each_moved(p.home.layout.moved) do
      moved[k] = v
    end
  end
  if rec then moved[id] = rec else moved[id] = nil end
  return M.resolve_moved(moved)
end

function M.bump(p)
  local h = M.ensure(p)
  h.layout = h.layout or { moved = {}, rev = 0 }
  h.layout.rev = (h.layout.rev or 0) + 1
  cache[p] = nil
  return h.layout.rev
end

-- record a built-in move (or clear it when rec is nil, restoring the default)
function M.set_move(p, id, rec)
  local h = M.ensure(p)
  h.layout = h.layout or { moved = {}, rev = 0 }
  if rec then
    h.layout.moved[id] = { deck = rec.deck, x = rec.x, z = rec.z, turn = rec.turn or 0, w = rec.w, d = rec.d }
  else
    h.layout.moved[id] = nil
    if not next(h.layout.moved) then
      h.layout = nil
      cache[p] = nil
      return 0
    end
  end
  return M.bump(p)
end

function M.record(p)
  local h = p.home and p.home.layout
  if not h then return nil end
  return h.moved and h.moved
end

function M.push_undo(p, ev)
  local h = M.ensure(p)
  h.undo = h.undo or {}
  h.undo[#h.undo + 1] = ev
  while #h.undo > M.UNDO_MAX do table.remove(h.undo, 1) end
end

function M.pop_undo(p)
  local h = p.home
  if not h or not h.undo or #h.undo == 0 then return nil end
  return table.remove(h.undo)
end

-- default pose of a built-in (from the base table)
function M.home_pose(id)
  local f = M.piece(M.base(), id)
  if not f then return nil end
  local x, z = M.centre(f)
  local w, d = M.size_of(f)
  return { deck = f.deck, x = x, z = z, turn = f.turn or 0, w = w, d = d }
end

-- camera seat for the sofa (follows a moved piece); other seats stay put
function M.seat(p, name)
  local L = M.of(p)
  local s = L[name]
  if not s then return nil end
  if name ~= "sofa" then return s end
  local f = M.piece(L, "sofa")
  if not f or not f.box then return s end
  local cx, cz = M.centre(f)
  local dx, dz = cx - (-7.5), cz - (-0.25)
  local yaw = (s.yaw or 0) + M.yaw(f.turn or 0)
  return { eye = { s.eye[1] + dx, s.eye[2], s.eye[3] + dz }, yaw = yaw, pitch = s.pitch }
end

return M
