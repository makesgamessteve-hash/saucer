-- SPDX-License-Identifier: MIT
-- add-wider-dark: the sector map, drawn beside the map panel's rows and in
-- the spare quarter of a three-player split screen. Read only.
local galaxy = require("sim.galaxy")
local mystery = require("sim.mystery")
local M = {}

local WHITE, DIM, GREEN, AMBER, CYAN, PINK = { 1, 1, 1, 1 }, { 0.55, 0.6, 0.7, 1 }, { 0.4, 1, 0.5, 1 },
  { 1, 0.8, 0.3, 1 }, { 0.4, 0.9, 1, 1 }, { 1, 0.45, 0.65, 1 }
local DANGER = { { 0.35, 0.8, 0.5, 1 }, { 1, 0.75, 0.3, 1 }, { 1, 0.35, 0.3, 1 } }
M.PCOL = { { 0.4, 0.9, 1, 1 }, { 1, 0.6, 0.3, 1 }, { 0.6, 1, 0.4, 1 }, { 1, 0.5, 0.9, 1 } }

-- screen positions of every sector inside the box (x, y, w, h)
function M.layout(g, x, y, w, h)
  local mn, mx = { math.huge, math.huge }, { -math.huge, -math.huge }
  for _, s in ipairs(g.sectors) do
    mn[1], mn[2] = math.min(mn[1], s.pos[1]), math.min(mn[2], s.pos[3])
    mx[1], mx[2] = math.max(mx[1], s.pos[1]), math.max(mx[2], s.pos[3])
  end
  local sx = (w - 16) / math.max(1, mx[1] - mn[1])
  local sy = (h - 16) / math.max(1, mx[2] - mn[2])
  local out = {}
  for _, s in ipairs(g.sectors) do
    out[s.id] = { x + 8 + (s.pos[1] - mn[1]) * sx, y + 8 + (s.pos[3] - mn[2]) * sy }
  end
  return out
end

-- a dotted link between two screen points
local function link(v, a, b, col)
  local n = math.max(2, math.floor(math.max(math.abs(b[1] - a[1]), math.abs(b[2] - a[2])) / 3))
  for k = 0, n do
    local t = k / n
    v:rect(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, 1, 1, col)
  end
end

-- draw(v, state, x, y, w, h, viewer): nodes, links, tags and the party
function M.draw(v, state, x, y, w, h, viewer)
  local g = galaxy.generate(state.seed)
  local cur = state.sector_id or 1
  local res = mystery.resonant_sectors(state.mystery)
  local pos = M.layout(g, x, y + 10, w, h - 20)
  v:rect(x, y, w, h, { 0, 0.02, 0.07, 0.85 })
  v:text(x + 4, y + 2, "SECTOR MAP", AMBER)
  for _, s in ipairs(g.sectors) do
    for _, l in ipairs(s.links) do
      if l > s.id then link(v, pos[s.id], pos[l], { 0.35, 0.4, 0.55, 1 }) end
    end
  end
  local j = state.jump
  if j then link(v, pos[cur], pos[j.to], state.tick % 20 < 10 and CYAN or WHITE) end
  local core = viewer and galaxy.core(viewer) or galaxy.core({})
  for _, s in ipairs(g.sectors) do
    local p = pos[s.id]
    local col = DANGER[math.min(3, s.danger)]
    local hops = galaxy.hops(state.seed, cur, s.id)
    if s.id ~= cur and hops > core.hops then col = { col[1] * 0.45, col[2] * 0.45, col[3] * 0.45, 1 } end
    local r = s.id == cur and 4 or 3
    v:rect(p[1] - r, p[2] - r, r * 2, r * 2, col)
    if res[s.id] and state.tick % 40 < 28 then
      v:rect(p[1] - r - 2, p[2] - r - 2, r * 2 + 4, 1, s.heart and PINK or AMBER)
      v:rect(p[1] - r - 2, p[2] + r + 1, r * 2 + 4, 1, s.heart and PINK or AMBER)
    end
    local label = s.name
    if w < 200 then label = s.name:sub(1, 8) end
    v:text(p[1] + 6, p[2] - 4, label, s.id == cur and GREEN or (s.heart and PINK or DIM))
  end
  -- the party: one dot per saucer at the current sector
  for i, _ in ipairs(state.players) do
    local p = pos[cur]
    v:rect(p[1] - 6 + (i - 1) * 4, p[2] + 6, 3, 3, M.PCOL[i] or WHITE)
  end
end

-- the spare split-screen quarter: the map, the party and how to join
function M.spare(v, state)
  local W, H = v.width, v.height
  M.draw(v, state, 0, 0, W, H - 34, nil)
  local y = H - 32
  for i, p in ipairs(state.players) do
    local where = p.site ~= 0 and ("site " .. p.site) or (p.docked and "docked" or "open space")
    v:text(4, y, string.format("P%d %s CHG %d", i, where, p.ship.charge // 1), M.PCOL[i] or WHITE)
    y = y + 8
  end
  if #state.players < 4 then v:text(4, H - 9, "JOIN: gamepad A / F2 split keys", DIM) end
end

return M
