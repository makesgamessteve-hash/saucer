-- SPDX-License-Identifier: MIT
-- vary-relic-room-plans: hall-centre plans for styled relics. Each civ massing archetype places halls in its own
-- overall shape -- a spiral, nested rings, spherical shells, a conical helix, a Sierpinski gasket, an H-tree, a
-- diamond lattice or a recursive spine -- around or toward the heart, instead of filling a rectangular lattice.
-- The slice's Vyrr keep the kit's warren (no pattern). Pure: a function of (rng, dungeon table, grid).
local M = {}

local function atan2(y, x)
  if x > 0 then return math.atan(y / x) end
  if x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi) end
  if y > 0 then return math.pi / 2 end
  if y < 0 then return -math.pi / 2 end
  return 0
end

local function hypot(x, z) return math.sqrt(x * x + z * z) end
local function rnd(v) return math.floor(v + 0.5) end

-- cells from the heart's centre to a hall's centre along a cardinal, so the hall's box stays clear of the
-- heart's box and its gap. A circular ring must use ring_radius (the diagonal) so 45-degree halls stay out too.
function M.clearance(D)
  local H = D.heart
  local hw = 0
  for _, w in ipairs(D.hall_w) do hw = math.max(hw, w) end
  return math.max(H[1], H[3]) // 2 + (D.heart_gap or 16) + hw // 2
end
function M.ring_radius(D)
  return math.floor(M.clearance(D) * 1.42 + 0.5)
end
function M.outside_heart(x, z, D, heart)
  local need = M.clearance(D)
  return math.abs(x - heart.cx) >= need or math.abs(z - heart.cz) >= need
end

local function level_y(D, l) return D.origin[2] + l * D.level_h end

-- a hall record at cell centre (x, z) on level l
local function hall(x, z, l, D, extra)
  local h = { x = rnd(x), z = rnd(z), y = level_y(D, l), l = l }
  if extra then for k, v in pairs(extra) do h[k] = v end end
  return h
end

local function too_close(a, b, min)
  return hypot(a.x - b.x, a.z - b.z) < min and a.l == b.l
end

local function far_enough(halls, x, z, l, min)
  for _, h in ipairs(halls) do
    if h.l == l and hypot(h.x - x, h.z - z) < min then return false end
  end
  return true
end

-- index of the hall nearest to (x, z) on level l (any level if l is nil)
local function nearest(halls, x, z, l)
  local best, bd = 1, math.huge
  for i, h in ipairs(halls) do
    if l == nil or h.l == l then
      local d = hypot(h.x - x, h.z - z)
      if d < bd then best, bd = i, d end
    end
  end
  return best, bd
end

local function link(edges, linked, a, b)
  if a == b or not a or not b then return end
  local k = math.min(a, b) .. ":" .. math.max(a, b)
  if linked[k] then return end
  linked[k] = true
  edges[#edges + 1] = { a, b }
end

-- the heart sits in the middle of the grid, on the lowest floor
local function heart_at(D, grid)
  local H = D.heart
  local cx, cz = grid[1] // 2, grid[3] // 2
  return {
    cx = cx, cz = cz, y = D.origin[2],
    origin = { cx - H[1] // 2, D.origin[2], cz - H[3] // 2 },
    size = H,
  }
end

-- margin a hall centre must keep from the grid edge (Seat branches + the maw)
local function margin(D)
  local hw = 0
  for _, w in ipairs(D.hall_w) do hw = math.max(hw, w) end
  -- only the maw and a little wall need to fit; Seat branches that would leave the grid simply aren't placed
  return hw // 2 + (D.maw[3] or 10) + 4
end

local function in_grid(x, z, D, grid)
  local m = margin(D)
  return x >= m and z >= m and x <= grid[1] - m and z <= grid[3] - m
end
local function ok_at(halls, x, z, l, D, grid, heart, min)
  return in_grid(x, z, D, grid) and M.outside_heart(x, z, D, heart) and far_enough(halls, x, z, l, min)
end

-- connect each hall to its nearest neighbour (and a second if loops) so the graph is linked; then a main way
-- from start to the first entry, preferring already-placed edges and filling gaps with nearest hops
local function stitch(halls, edges, linked, start, entries, D, rng)
  local min = (D.pitch or 40) * 0.85
  -- nearest-neighbour tree
  local seen = { [start] = true }
  local guard = 0
  while true do
    guard = guard + 1
    if guard > 4000 then break end
    local best_a, best_b, bd = nil, nil, math.huge
    for i = 1, #halls do
      if seen[i] then
        for j = 1, #halls do
          if not seen[j] then
            local d = hypot(halls[i].x - halls[j].x, halls[i].z - halls[j].z) + math.abs(halls[i].l - halls[j].l) * (D.level_h or 18)
            -- prefer same-level or stacked (same xz) connections
            if halls[i].l ~= halls[j].l and hypot(halls[i].x - halls[j].x, halls[i].z - halls[j].z) > min * 0.5 then
              d = d + 80
            end
            if d < bd then best_a, best_b, bd = i, j, d end
          end
        end
      end
    end
    if not best_b then break end
    seen[best_b] = true
    link(edges, linked, best_a, best_b)
  end
  -- loops
  local loops = D.loops or 0
  if loops > 0 then
    for i = 1, #halls do
      local cands = {}
      for j = i + 1, #halls do
        local d = hypot(halls[i].x - halls[j].x, halls[i].z - halls[j].z)
        local stacked = halls[i].l ~= halls[j].l and d < min * 0.6
        local near = halls[i].l == halls[j].l and d < min * 1.8
        if stacked or near then cands[#cands + 1] = j end
      end
      for _, j in ipairs(cands) do
        if rng:float() < loops then link(edges, linked, i, j) end
      end
    end
  end
end

local function pick_start(halls, heart)
  local best, bd = 1, -1
  local top = 0
  for _, h in ipairs(halls) do if h.l > top then top = h.l end end
  for i, h in ipairs(halls) do
    if h.l == top then
      local d = hypot(h.x - heart.cx, h.z - heart.cz)
      if d > bd then best, bd = i, d end
    end
  end
  return best
end

-- halls on the lowest level nearest the heart, on cardinal approaches, become entries
local function pick_entries(halls, heart, n)
  n = n or 4
  local low = {}
  for i, h in ipairs(halls) do if h.l == 0 then low[#low + 1] = i end end
  table.sort(low, function(a, b)
    return hypot(halls[a].x - heart.cx, halls[a].z - heart.cz) < hypot(halls[b].x - heart.cx, halls[b].z - heart.cz)
  end)
  local out, used = {}, {}
  -- prefer one per cardinal quadrant
  local quads = { {}, {}, {}, {} }
  for _, i in ipairs(low) do
    local dx, dz = halls[i].x - heart.cx, halls[i].z - heart.cz
    local q = (dz >= 0 and 0 or 2) + (dx >= 0 and 0 or 1)
    if dx * dx > dz * dz then q = (dx >= 0 and 1 or 3) end
    quads[q + 1][#quads[q + 1] + 1] = i
  end
  for q = 1, 4 do
    if #out < n and quads[q][1] then
      out[#out + 1] = quads[q][1]
      used[quads[q][1]] = true
    end
  end
  for _, i in ipairs(low) do
    if #out >= n then break end
    if not used[i] then out[#out + 1] = i end
  end
  return out
end

-- make sure four cardinal halls sit just outside the heart on level 0, so a straight trunk can reach it
local function ensure_cardinals(halls, heart, D, grid)
  local pitch = D._gpitch or D.pitch or 40
  local r0 = math.max(2, math.ceil(M.clearance(D) / pitch))
  for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
    local x, z = heart.cx + d[1] * r0 * pitch, heart.cz + d[2] * r0 * pitch
    if ok_at(halls, x, z, 0, D, grid, heart, pitch * 0.7) then
      halls[#halls + 1] = hall(x, z, 0, D, { entry = true, inner = true })
    end
  end
end

local function finish(halls, edges, linked, start, heart, entries, D, rng, grid)
  local n0 = #halls
  ensure_cardinals(halls, heart, D, grid)
  -- 4-link any newly added cardinal to a hall a pitch away on the same level
  local pitch = D._gpitch or D.pitch or 40
  for i = n0 + 1, #halls do
    for j = 1, n0 do
      if halls[i].l == halls[j].l then
        local d = hypot(halls[i].x - halls[j].x, halls[i].z - halls[j].z)
        if d <= pitch * 1.15 and d >= pitch * 0.7 then
          link(edges, linked, i, j)
        end
      end
    end
  end
  entries = pick_entries(halls, heart, 4)
  if not start or not halls[start] then start = pick_start(halls, heart) end
  for _, i in ipairs(entries) do halls[i].entry = true end
  halls[start].main = true
  return { halls = halls, edges = edges, start = start, heart = heart, entries = entries }
end

-- pick the start hall: on the highest level, farthest from the heart (room for the maw)

------------------------------------------------------------------------
-- patterns
------------------------------------------------------------------------


-- place halls at integer (i, j, l) on a pitch grid centred on the heart, 4-connect neighbours and
-- stacks, then hand the plan to finish() for any leftover links. This is the same grammar the diamond
-- lattice already used successfully, so trunks and shafts stay axis-aligned.
local function key(i, j, l) return (l * 128 + j + 64) * 128 + (i + 64) end

local function grid_plan(rng, D, grid, heart, cells, extras)
  local pitch = D._gpitch or D.pitch or 40
  local halls, edges, linked, at = {}, {}, {}, {}
  for _, c in ipairs(cells) do
    local i, j, l = c[1], c[2], c[3]
    local x, z = heart.cx + i * pitch, heart.cz + j * pitch
    if not at[key(i, j, l)] and ok_at(halls, x, z, l, D, grid, heart, pitch * 0.8) then
      halls[#halls + 1] = hall(x, z, l, D, c[4])
      at[key(i, j, l)] = #halls
    end
  end
  local function join(i, j, l, i2, j2, l2)
    local a, b = at[key(i, j, l)], at[key(i2, j2, l2)]
    if a and b then link(edges, linked, a, b) end
  end
  for _, c in ipairs(cells) do
    local i, j, l = c[1], c[2], c[3]
    join(i, j, l, i + 1, j, l)
    join(i, j, l, i, j + 1, l)
    if l > 0 then join(i, j, l, i, j, l - 1) end
  end
  for _, e in ipairs(extras or {}) do
    join(e[1], e[2], e[3], e[4], e[5], e[6])
  end
  if #halls < 8 then return nil end
  local start = pick_start(halls, heart)
  -- keep only the 4-connected (and stacked) component of the start hall, so layout never has to
  -- bridge a gap with a long leftover corridor
  local adj = {}
  for _, e in ipairs(edges) do
    adj[e[1]] = adj[e[1]] or {}
    adj[e[2]] = adj[e[2]] or {}
    adj[e[1]][#adj[e[1]] + 1] = e[2]
    adj[e[2]][#adj[e[2]] + 1] = e[1]
  end
  local keep = { [start] = true }
  local q, qi = { start }, 1
  while qi <= #q do
    local i = q[qi]; qi = qi + 1
    for _, j in ipairs(adj[i] or {}) do
      if not keep[j] then keep[j] = true; q[#q + 1] = j end
    end
  end
  if #q < 8 then return nil end
  -- cap the component so Villa spaces stay in the 40-80 budget
  local cap = 26
  local levels_seen = {}
  for _, i in ipairs(q) do levels_seen[halls[i].l] = true end
  local nlev = 0
  for _ in pairs(levels_seen) do nlev = nlev + 1 end
  if #q > cap and nlev >= 3 then
    local kept, have = {}, {}
    for _, i in ipairs(q) do
      local l = halls[i].l
      if not have[l] then have[l], kept[#kept + 1] = true, i end
    end
    for _, i in ipairs(q) do
      if #kept >= cap then break end
      local already = false
      for _, k in ipairs(kept) do if k == i then already = true break end end
      if not already then kept[#kept + 1] = i end
    end
    q = kept
  end
  keep = {}
  for _, i in ipairs(q) do keep[i] = true end
  if #q < #halls then
    local map, nh, ne = {}, {}, {}
    for i, h in ipairs(halls) do
      if keep[i] then map[i] = #nh + 1; nh[#nh + 1] = h end
    end
    for _, e in ipairs(edges) do
      if map[e[1]] and map[e[2]] then ne[#ne + 1] = { map[e[1]], map[e[2]] } end
    end
    halls, edges, start = nh, ne, map[start]
  end
  local entries = pick_entries(halls, heart, 4)
  return finish(halls, edges, linked, start, heart, entries, D, rng, grid)
end

local function every_cell(rmin, rmax, levels, keep)
  local cells = {}
  for l = 0, levels - 1 do
    for i = -rmax, rmax do
      for j = -rmax, rmax do
        if keep(i, j, l) then cells[#cells + 1] = { i, j, l } end
      end
    end
  end
  return cells
end

function M.rings(rng, D, grid)
  local heart = heart_at(D, grid)
  -- a 4-connected octagon (16 cells) on the mid level, inner cardinals on every level
  local r = 3
  local mid = math.min(1, D.levels - 1)
  local oct = {
    { r, 0 }, { r, 1 }, { 1, r }, { 0, r }, { -1, r }, { -r, 1 }, { -r, 0 }, { -r, -1 },
    { -1, -r }, { 0, -r }, { 1, -r }, { r, -1 },
  }
  -- fill the 4-steps of a rounded square of radius r
  local cells = {}
  for l = 0, D.levels - 1 do
    for _, d in ipairs({ { r, 0 }, { -r, 0 }, { 0, r }, { 0, -r } }) do
      cells[#cells + 1] = { d[1], d[2], l }
    end
    if l == mid then
      -- the four sides AND corners of the square ring, so it is 4-connected
      for s = -r, r do
        cells[#cells + 1] = { s, r, l }
        cells[#cells + 1] = { s, -r, l }
        cells[#cells + 1] = { r, s, l }
        cells[#cells + 1] = { -r, s, l }
      end
    end
  end
  return grid_plan(rng, D, grid, heart, cells)
end

function M.shells(rng, D, grid)
  local heart = heart_at(D, grid)
  local r0 = 3
  local mid = math.min(1, D.levels - 1)
  local cells = {}
  for l = 0, D.levels - 1 do
    -- stacked cardinals at r0 on every level (shafts)
    for _, d in ipairs({ { r0, 0 }, { -r0, 0 }, { 0, r0 }, { 0, -r0 } }) do
      cells[#cells + 1] = { d[1], d[2], l }
    end
    local r = (l == mid) and r0 or (r0 - 1)
    for s = -r, r do
      cells[#cells + 1] = { s, r, l }
      cells[#cells + 1] = { s, -r, l }
      cells[#cells + 1] = { r, s, l }
      cells[#cells + 1] = { -r, s, l }
    end
    -- a 4-step spoke from the stacked r0 cardinal to the smaller ring's cardinal
    if r < r0 then
      cells[#cells + 1] = { r, 0, l }
      cells[#cells + 1] = { -r, 0, l }
      cells[#cells + 1] = { 0, r, l }
      cells[#cells + 1] = { 0, -r, l }
    end
  end
  return grid_plan(rng, D, grid, heart, cells)
end

function M.helix(rng, D, grid)
  local heart = heart_at(D, grid)
  local r0 = 3
  local levels = math.max(5, D.levels)
  local sign = rng:int(0, 1) * 2 - 1
  local function ring_path(r)
    local p = {}
    for s = 0, r - 1 do p[#p + 1] = { r, s } end
    for s = r, 1 - r, -1 do p[#p + 1] = { s, r } end
    for s = r - 1, 1 - r, -1 do p[#p + 1] = { -r, s } end
    for s = -r, r - 1 do p[#p + 1] = { s, -r } end
    for s = 1 - r, -1 do p[#p + 1] = { r, s } end
    return p
  end
  local path = ring_path(r0)
  if sign < 0 then
    local q = {}
    for i = #path, 1, -1 do q[#q + 1] = path[i] end
    path = q
  end
  local cells = {}
  local per = math.max(2, math.floor(#path / levels))
  local last_l = 0
  for idx, c in ipairs(path) do
    local l = math.min(levels - 1, math.floor((idx - 1) / per))
    if l ~= last_l then
      -- stack at this footprint so a shaft can carry the climb
      cells[#cells + 1] = { c[1], c[2], last_l, { main = true } }
      last_l = l
    end
    cells[#cells + 1] = { c[1], c[2], l, { main = true } }
  end
  for _, d in ipairs({ { r0, 0 }, { -r0, 0 }, { 0, r0 }, { 0, -r0 } }) do
    cells[#cells + 1] = { d[1], d[2], 0, { entry = true } }
  end
  local D2 = {}
  for k, v in pairs(D) do D2[k] = v end
  D2.levels = levels
  return grid_plan(rng, D2, grid, heart, cells)
end

function M.spiral(rng, D, grid)
  local heart = heart_at(D, grid)
  local r0 = math.max(3, math.ceil(M.ring_radius(D) / (D.pitch or 40)))
  local rmax = r0 + 2
  local sign = rng:int(0, 1) * 2 - 1
  local cells = {}
  -- square spiral, 4-connected by construction, from the outer south inward to r0
  local i, j = 0, rmax
  local di, dj = sign, 0
  local steps, leg, maxleg, turns, last_l = 0, 0, 1, 0, D.levels - 1
  while steps < rmax * 8 + 4 do
    if hypot(i, j) + 0.05 < r0 then break end
    local l = math.max(0, D.levels - 1 - math.floor(steps / 8))
    if l ~= last_l then
      cells[#cells + 1] = { i, j, last_l, { main = true, gullet = true } }
      cells[#cells + 1] = { i, j, l, { main = true, gullet = true } }
      last_l = l
    else
      cells[#cells + 1] = { i, j, l, { main = true, gullet = true } }
    end
    i, j = i + di, j + dj
    steps = steps + 1
    leg = leg + 1
    if leg >= maxleg then
      leg = 0
      di, dj = -dj * sign, di * sign
      turns = turns + 1
      if turns % 2 == 0 then maxleg = maxleg + 1 end
    end
  end
  -- a few 1-cell organ branches, 4-connected
  local n = #cells
  for k = 3, n - 2, 4 do
    if rng:int(1, 2) == 1 then
      local c = cells[k]
      local side = (k % 2 == 0) and 1 or -1
      cells[#cells + 1] = { c[1] + side, c[2], c[3] }
    end
  end
  -- inner cardinals on level 0
  for _, d in ipairs({ { r0, 0 }, { -r0, 0 }, { 0, r0 }, { 0, -r0 } }) do
    cells[#cells + 1] = { d[1], d[2], 0, { entry = true } }
  end
  return grid_plan(rng, D, grid, heart, cells)
end

function M.diamond(rng, D, grid)
  local heart = heart_at(D, grid)
  local R0 = M.clearance(D)
  local pitch = math.max(D.pitch or 40, R0)
  local mid = math.min(1, D.levels - 1)
  -- 4 inner cardinals on every level, the manhattan-2 diamond only on the mid level (8 cells, 4-linked
  -- through the inner cardinals). About 4 * levels + 8 halls, well inside the Villa-space budget.
  local cells = every_cell(1, 2, D.levels, function(i, j, l)
    local man = math.abs(i) + math.abs(j)
    if man == 1 and (i == 0 or j == 0) then return true end
    if man == 2 and l == mid then return true end
    return false
  end)
  local D2 = {}
  for k, v in pairs(D) do D2[k] = v end
  D2._gpitch = pitch
  return grid_plan(rng, D2, grid, heart, cells)
end

function M.sierpinski(rng, D, grid)
  local heart = heart_at(D, grid)
  local pitch = math.max(32, math.min(D.pitch or 40, 36))
  local n = 8
  local i0, j0 = 5.5, 5.5
  local rot = rng:int(0, 3)
  local mid = math.min(1, D.levels - 1)
  local cells = {}
  for l = 0, D.levels - 1 do
    for i = 0, n - 1 do
      for j = 0, n - 1 do
        if (i & j) == 0 then
          local keep = (l == mid) or (i == 0 and j == 0) or (i == 0 and j == n - 1) or (i == n - 1 and j == 0)
          if keep then
            local x, z = i - i0, j - j0
            if rot == 1 then x, z = -z, x
            elseif rot == 2 then x, z = -x, -z
            elseif rot == 3 then x, z = z, -x end
            cells[#cells + 1] = { rnd(x), rnd(z), l }
          end
        end
      end
    end
  end
  local D2 = {}
  for k, v in pairs(D) do D2[k] = v end
  D2._gpitch = pitch
  return grid_plan(rng, D2, grid, heart, cells)
end

function M.htree(rng, D, grid)
  local heart = heart_at(D, grid)
  local r0 = math.max(2, math.ceil(M.clearance(D) / (D.pitch or 40)))
  local depth = rng:int(0, 2) == 0 and 3 or 2
  local mid = math.min(1, D.levels - 1)
  local cells = {}
  local function put(i, j, l)
    if math.abs(i) < r0 and math.abs(j) < r0 then return end
    cells[#cells + 1] = { i, j, l }
  end
  for l = 0, D.levels - 1 do
    put(r0, 0, l); put(-r0, 0, l); put(0, r0, l); put(0, -r0, l)
  end
  local function bar(i, j, di, dj, len, dep, l)
    if dep < 0 or len < 1 then return end
    for s = 1, len do put(i + di * s, j + dj * s, l) end
    if dep > 0 then
      local ti, tj = i + di * len, j + dj * len
      bar(ti, tj, -dj, di, math.max(1, len // 2), dep - 1, l)
      bar(ti, tj, dj, -di, math.max(1, len // 2), dep - 1, l)
    end
  end
  local arm = (depth >= 3) and 3 or 2
  for l = 0, D.levels - 1 do
    local dep = (l == mid) and depth or 1
    bar(r0, 0, 1, 0, arm, dep, l)
    bar(-r0, 0, -1, 0, arm, dep, l)
    bar(0, r0, 0, 1, arm, dep, l)
    bar(0, -r0, 0, -1, arm, dep, l)
  end
  return grid_plan(rng, D, grid, heart, cells)
end

function M.spine(rng, D, grid)
  local heart = heart_at(D, grid)
  local r0 = math.max(2, math.ceil(M.clearance(D) / (D.pitch or 40)))
  local half = rng:int(4, 6)
  local mid = math.min(1, D.levels - 1)
  local sign = rng:int(0, 1) * 2 - 1
  local cells = {}
  local function put(i, j, l, extra)
    if math.abs(i) < r0 and math.abs(j) < r0 then return end
    cells[#cells + 1] = { i, j, l, extra }
  end
  for l = 0, D.levels - 1 do
    local n = (l == mid) and half or math.max(3, half - 1)
    for s = -n, n do
      if s ~= 0 then
        local jj = (s > 0 and 1 or -1) * (r0 + math.abs(s) - 1)
        local ii = sign * ((math.abs(s) % 3 == 2) and 1 or 0)
        put(ii, jj, l, { main = true, gullet = true })
      end
    end
    local dep = (l == mid) and 2 or 1
    for s = -n, n do
      if s ~= 0 and (math.abs(s) % 2 == 0 or l == mid) then
        local jj = (s > 0 and 1 or -1) * (r0 + math.abs(s) - 1)
        local side = (s % 2 == 0) and 1 or -1
        for w = 1, dep + 1 do
          put(side * w, jj, l)
        end
        if dep > 1 then
          put(side * (dep + 1), jj + 1, l)
          put(side * (dep + 1), jj - 1, l)
        end
      end
    end
  end
  return grid_plan(rng, D, grid, heart, cells)
end

M.PATTERNS = {
  rings = M.rings,
  shells = M.shells,
  helix = M.helix,
  spiral = M.spiral,
  diamond = M.diamond,
  sierpinski = M.sierpinski,
  htree = M.htree,
  spine = M.spine,
}

-- plan(rng, D, grid) -> { halls, edges, start, heart, entries } or nil, why
function M.plan(rng, D, grid)
  local name = D.pattern
  local fn = name and M.PATTERNS[name]
  if not fn then return nil, "no pattern" end
  local p = fn(rng, D, grid)
  if not p or #p.halls < 8 then return nil, "too few halls" end
  if not p.start or not p.entries or #p.entries == 0 then return nil, "no way to the heart" end
  p.pattern = name
  return p
end

return M
