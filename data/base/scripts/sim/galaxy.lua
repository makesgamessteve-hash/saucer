-- SPDX-License-Identifier: MIT
-- Multiple sectors and Fold Core jumps (concept §3.4, §3.6, §5.1; OpenSpec
-- add-wider-dark). The galaxy is a pure function of the universe seed: a
-- spine of linked sectors from home to the Heart sector plus side branches,
-- each with 2-3 civs from the universe list. Only the current sector id, the
-- world state of sectors you left (state.visited) and each player's per
-- sector loot memory (p.away) are kept in the state.
--
-- A jump is a party vote (state.jump): whoever opens the sector map and
-- picks a reachable sector proposes it; every other player agrees on their
-- own map. When everyone has agreed and every saucer is ready (Villa size,
-- outside any site, not on foot, not reshaping, enough Charge) the Fold Core
-- spools for a few seconds and the whole party arrives in the new sector in
-- formation. Anyone can cancel.
local data = require("lib.data")
local vec = require("lib.vec")
local M = {}

function M.tune() return data.load("galaxy/galaxy.lua") end

local memo = {}
-- generate(seed) -> { sectors = { { id, name, pos, links, civs, danger, depth, heart } }, heart = id, spine = {ids} }
function M.generate(seed)
  local key = tostring(seed)
  if memo[key] then return memo[key] end
  local T = M.tune()
  local civs = require("sim.civs")
  local ncivs = #civs.universe(seed)
  local rng = saucer.rng.new(saucer.seed_child(seed, "galaxy", 0))
  local sectors = {}
  local function link(a, b)
    a.links[#a.links + 1] = b.id
    b.links[#b.links + 1] = a.id
  end
  local used = {}
  local function name()
    for _ = 1, 20 do
      local n = rng:pick(T.prefixes) .. " " .. rng:pick(T.names)
      if not used[n] then
        used[n] = true
        return n
      end
    end
    return "Sector " .. (#sectors + 1)
  end
  sectors[1] = { id = 1, name = "Home Drift", pos = { 0, 0, 0 }, links = {}, civs = { 1, 2 }, danger = 1, depth = 0 }
  used["Home Drift"] = true
  for i = 2, T.sectors do
    local parent = i <= T.spine and sectors[i - 1] or sectors[rng:int(1, T.spine - 1)]
    local a = rng:float() * saucer.math.tau
    local d = rng:int(T.hop[1], T.hop[2])
    -- the spine heads outward (+x); branches fan out round their parent
    if i <= T.spine then a = (rng:float() - 0.5) * 1.2 end
    local pos = { parent.pos[1] + saucer.math.cos(a) * d, parent.pos[2] + rng:int(-3, 3),
                  parent.pos[3] + saucer.math.sin(a) * d }
    for k = 1, 3 do pos[k] = math.floor(pos[k] * 10 + 0.5) / 10 end
    local cl = {}
    local nc = rng:int(T.civs_per_sector[1], T.civs_per_sector[2])
    -- a civ can appear in neighbouring sectors: the first civ is inherited
    cl[1] = parent.civs[#parent.civs]
    for _ = 2, nc do
      local c = rng:int(1, ncivs)
      local dup = false
      for _, x in ipairs(cl) do if x == c then dup = true end end
      if not dup then cl[#cl + 1] = c end
    end
    local s = { id = i, name = name(), pos = pos, links = {}, civs = cl, depth = parent.depth + 1 }
    s.danger = math.min(3, 1 + s.depth // 1)
    sectors[i] = s
    link(parent, s)
  end
  local g = { sectors = sectors, heart = T.spine, spine = {} }
  for i = 1, T.spine do g.spine[i] = i end
  sectors[T.spine].heart = true
  sectors[T.spine].name = "The Heart"
  memo[key] = g
  return g
end

function M.sector(seed, id) return M.generate(seed).sectors[id] end

-- hops(seed, a, b) -> number of links between two sectors (breadth first)
function M.hops(seed, a, b)
  if a == b then return 0 end
  local g = M.generate(seed)
  local dist, queue, head = { [a] = 0 }, { a }, 1
  while queue[head] do
    local cur = queue[head]
    head = head + 1
    for _, n in ipairs(g.sectors[cur].links) do
      if not dist[n] then
        dist[n] = dist[cur] + 1
        if n == b then return dist[n] end
        queue[#queue + 1] = n
      end
    end
  end
  return math.huge
end

function M.core(p) return M.tune().core[p.fold_tier or 1] or M.tune().core[1] end

-- can the party's Fold Core reach sector `to` from here? (the proposer's tier)
function M.in_range(state, p, to)
  return M.hops(state.seed, state.sector_id or 1, to) <= M.core(p).hops
end

-- is this saucer ready to fold? -> ok, reason
function M.ready(state, p)
  local ship = p.ship
  if p.mode == "foot" then return false, "on foot" end
  if ship.size ~= 1 then return false, "not at Villa size" end
  if ship.morph then return false, "reshaping" end
  if p.site ~= 0 then return false, "inside a site" end
  if p.holo_run then return false, "in the holodeck" end
  if ship.charge < M.core(p).charge then return false, "low Charge" end
  return true
end

-- propose(state, p, to) -> ok, reason
function M.propose(state, p, to, ctx)
  local g = M.generate(state.seed)
  if not g.sectors[to] then return false, "no such sector" end
  if to == (state.sector_id or 1) then return false, "already here" end
  if state.jump then return false, "a jump is already proposed" end
  if not M.in_range(state, p, to) then return false, "out of Fold Core range" end
  state.jump = { to = to, by = p.index, yes = { [tostring(p.index)] = true }, spool = -1 }
  for _, o in ipairs(state.players) do
    if o == p then
      ctx.msg(state, o, "Fold jump to " .. g.sectors[to].name .. " proposed")
    else
      ctx.msg(state, o, string.format("P%d proposes a fold jump to %s: open your map (Tab) to agree", p.index,
        g.sectors[to].name))
    end
    ctx.fx(state, o, "scan")
  end
  return true
end

function M.agree(state, p, ctx)
  local j = state.jump
  if not j then return false end
  j.yes[tostring(p.index)] = true
  ctx.msg(state, p, "You agreed to the fold jump")
  return true
end

function M.cancel(state, p, ctx)
  if not state.jump then return false end
  state.jump = nil
  for _, o in ipairs(state.players) do
    ctx.msg(state, o, p and string.format("P%d called off the fold jump", p.index) or "The fold jump was called off")
    ctx.fx(state, o, "denied")
  end
  return true
end

-- everyone said yes?
function M.agreed(state)
  local j = state.jump
  if not j then return false end
  for _, o in ipairs(state.players) do
    if not j.yes[tostring(o.index)] then return false end
  end
  return true
end

-- step(state, dt, ctx, enter): runs once per tick for the whole party
function M.step(state, dt, ctx, enter)
  local j = state.jump
  if not j then return end
  if not M.agreed(state) then return end
  local all = true
  for _, o in ipairs(state.players) do
    local ok, why = M.ready(state, o)
    if not ok then
      all = false
      if state.tick % 180 == 0 then ctx.msg(state, o, "Fold jump waiting: you are " .. why) end
    end
  end
  if not all then
    j.spool = -1
    return
  end
  if j.spool < 0 then
    j.spool = M.tune().spool
    for _, o in ipairs(state.players) do
      ctx.msg(state, o, "Fold Core spooling...")
      ctx.fx(state, o, "grow")
    end
  end
  j.spool = j.spool - dt
  if j.spool <= 1e-9 then
    state.jump = nil
    enter(state, j.to)
  end
end

-- per-sector world state that stays behind when the party jumps away
M.WORLD = { "traders", "nests", "caches", "vault", "locks", "grids", "lockdowns", "decoys", "gifts" }
-- per-player memory of a sector
M.AWAY = { "looted", "trails" }

local function copy(v)
  if type(v) ~= "table" then return v end
  local r = {}
  for k, x in pairs(v) do r[k] = copy(x) end
  return r
end

-- leave the current sector: stash what must stay (state.visited, p.away)
function M.stash(state)
  local cur = tostring(state.sector_id or 1)
  state.visited = state.visited or {}
  local w = {}
  for _, k in ipairs(M.WORLD) do w[k] = state[k] end
  state.visited[cur] = w
  for _, p in ipairs(state.players) do
    p.away = p.away or {}
    local a = {}
    for _, k in ipairs(M.AWAY) do a[k] = p[k] or {} end
    p.away[cur] = a
  end
end

-- arrive in sector `to`: what was stashed comes back, or a fresh start
function M.unstash(state, to, fresh)
  local key = tostring(to)
  local w = state.visited and state.visited[key]
  for _, k in ipairs(M.WORLD) do state[k] = w and w[k] or fresh[k] end
  if state.visited then state.visited[key] = nil end
  for _, p in ipairs(state.players) do
    local a = p.away and p.away[key]
    for _, k in ipairs(M.AWAY) do p[k] = a and a[k] or {} end
    if p.away then p.away[key] = nil end
  end
end

-- formation slots round the arrival point, facing the trader
function M.formation(sector, i, n)
  local sp = M.tune().arrival_spacing
  local a = sector.arrival
  return { a[1] + (i - 1 - (n - 1) / 2) * sp, a[2], a[3] }
end

function M.copy(v) return copy(v) end

-- the sector map panel: where you are, the jump being voted on, every
-- sector (reachable ones can be picked), the party and the Xenoarchive
function M.rows(state, p, ctx)
  local g = M.generate(state.seed)
  local cur = state.sector_id or 1
  local civs = require("sim.civs")
  local m = state.mystery
  local res = require("sim.mystery").resonant_sectors(m)
  local core = M.core(p)
  local here = g.sectors[cur]
  local rows = { { text = string.format("Here: %s (danger %d)  Fold Core T%d: %d hop%s, %d CHG", here.name, here.danger,
    p.fold_tier or 1, core.hops, core.hops == 1 and "" or "s", core.charge), enabled = false } }
  local j = state.jump
  if j then
    local name = g.sectors[j.to].name
    if not j.yes[tostring(p.index)] then
      rows[#rows + 1] = { text = string.format("Agree: P%d's fold jump to %s", j.by, name),
        act = function(st, pl) M.agree(st, pl, ctx) pl.panel = false end }
    else
      local n, total = 0, #state.players
      for _ in pairs(j.yes) do n = n + 1 end
      rows[#rows + 1] = { text = string.format("Jump to %s: %d/%d agreed%s", name, n, total,
        j.spool >= 0 and string.format(", spooling %.1f s", j.spool) or ""), enabled = false }
    end
    rows[#rows + 1] = { text = "Call off the jump", act = function(st, pl) M.cancel(st, pl, ctx) end }
  end
  for _, s in ipairs(g.sectors) do
    local hops = M.hops(state.seed, cur, s.id)
    local tags = {}
    if s.id == cur then tags[#tags + 1] = "HERE" end
    if res[s.id] then tags[#tags + 1] = s.heart and "HEART" or "RESONANT" end
    if state.visited and state.visited[tostring(s.id)] then tags[#tags + 1] = "visited" end
    local names = {}
    for _, ci in ipairs(s.civs) do names[#names + 1] = civs.get(state.seed, ci).name end
    local ok = s.id ~= cur and not j and hops <= core.hops
    local id = s.id
    rows[#rows + 1] = { text = string.format("%-14s d%d %dh %s %s", s.name, s.danger, hops, table.concat(names, "/"),
      table.concat(tags, " ")), enabled = ok, sector = id, act = function(st, pl)
        local okp, why = M.propose(st, pl, id, ctx)
        if not okp then
          ctx.msg(st, pl, "Fold Core: " .. why)
          ctx.fx(st, pl, "denied")
        end
        pl.panel = false
      end }
  end
  -- add-wider-dark: inside the open Heart, the vote comes first
  if require("sim.heart").can_vote(state, p) then
    table.insert(rows, 2, { text = "Vote on an ending at the Heart", act = function(_, pl) require("sim.panel").open(pl, "heart") end })
  end
  rows[#rows + 1] = { text = "Party: docking, visits, gifts", act = function(_, pl) require("sim.panel").open(pl, "party") end }
  rows[#rows + 1] = { text = "Xenoarchive", act = function(_, pl) require("sim.panel").open(pl, "archive") end }
  rows[#rows + 1] = { text = "Close", act = function(_, pl) pl.panel = false end }
  return rows
end
function M.dist(a, b) return vec.dist(a, b) end

return M
