-- SPDX-License-Identifier: MIT
-- Mesh recipe toolkit (concept §11.8). A recipe is { parts = {...} } where each
-- part is a primitive understood by saucer.mesh.build: box, wedge, cylinder,
-- cone, sphere, hemisphere, ring, lathe, extrude. Operations here combine and
-- transform part lists; everything is deterministic so mesh hashes are stable.
local data = require("lib.data")
local sm = saucer.math
local M = {}

local function copy(t)
  local r = {}
  for k, v in pairs(t) do
    if type(v) == "table" then r[k] = copy(v) else r[k] = v end
  end
  return r
end
M.copy = copy

function M.part(kind, t)
  local p = copy(t or {})
  p.kind = kind
  return p
end

function M.merge(...)
  local out = {}
  for _, list in ipairs({ ... }) do
    for _, p in ipairs(list) do out[#out + 1] = p end
  end
  return out
end

-- transform(parts, {pos=, yaw=, scale=}) -> new parts (yaw-only parent rotation)
function M.transform(parts, xf)
  local out = {}
  local yaw = xf.yaw or 0
  local s = xf.scale or 1
  local o = xf.pos or { 0, 0, 0 }
  local c, sn = sm.cos(yaw), sm.sin(yaw)
  for _, src in ipairs(parts) do
    local p = copy(src)
    local pp = p.pos or { 0, 0, 0 }
    local x, y, z = pp[1] * s, pp[2] * s, pp[3] * s
    p.pos = { x * c + z * sn + o[1], y + o[2], -x * sn + z * c + o[3] }
    p.yaw = (p.yaw or 0) + yaw
    if s ~= 1 then
      local sc = p.scale or { 1, 1, 1 }
      p.scale = { sc[1] * s, sc[2] * s, sc[3] * s }
    end
    out[#out + 1] = p
  end
  return out
end

-- mirror(parts, "x"|"z") -> originals plus mirrored copies
function M.mirror(parts, axis)
  local out = M.merge(parts)
  local i = axis == "z" and 3 or 1
  for _, src in ipairs(parts) do
    local p = copy(src)
    p.pos = p.pos or { 0, 0, 0 }
    p.pos[i] = -p.pos[i]
    p.yaw = -(p.yaw or 0)
    out[#out + 1] = p
  end
  return out
end

function M.radial_array(parts, n, phase)
  local out = {}
  for k = 0, n - 1 do
    out = M.merge(out, M.transform(parts, { yaw = (phase or 0) + sm.tau * k / n }))
  end
  return out
end

function M.linear_array(parts, n, step)
  local out = {}
  for k = 0, n - 1 do
    out = M.merge(out, M.transform(parts, { pos = { step[1] * k, step[2] * k, step[3] * k } }))
  end
  return out
end


-- a small parked craft as mesh parts: fuselage, canopy, swept wings, engine glow and a fin; the nose points
-- along +x turned by yaw about y, at (x, y, z) (y = the belly), scale s (1 = about 8 m long)
function M.ship(x, y, z, yaw, s, col, acc)
  local cs, sn = sm.cos(yaw), sm.sin(yaw)
  local out = {}
  local function b(x0, y0, z0, x1, y1, z1, color, emi, wy)
    local mx, my, mz = (x0 + x1) / 2 * s, (y0 + y1) / 2 * s, (z0 + z1) / 2 * s
    local hx, hy, hz = (x1 - x0) / 2 * s, (y1 - y0) / 2 * s, (z1 - z0) / 2 * s
    out[#out + 1] = { kind = "box", min = { -hx, -hy, -hz }, max = { hx, hy, hz }, color = color, emissive = emi,
                      yaw = yaw + (wy or 0), pos = { x + mx * cs + mz * sn, y + my, z - mx * sn + mz * cs } }
  end
  local dark = { col[1] * 0.8, col[2] * 0.8, col[3] * 0.8 }
  b(-4, 0, -1.2, 4, 1.8, 1.2, col)
  b(2.5, 1.7, -0.7, 4, 2.3, 0.7, { 0.5, 0.85, 1.0 }, 0.8)
  b(-3, 0.7, -4.2, 0.5, 1.1, -1.1, dark, nil, -0.35)
  b(-3, 0.7, 1.1, 0.5, 1.1, 4.2, dark, nil, 0.35)
  b(-4.2, 0.4, -0.9, -4, 1.4, 0.9, acc, 1)
  b(-0.5, 1.8, -0.15, 0.5, 2.5, 0.15, acc)
  return out
end

-- ---------------------------------------------------------------------------
-- Recipes, rigs, collision and the build budget (OpenSpec add-mesh-builder).
-- A recipe table is { parts = {...} } and may also declare
--   nodes     = { name = { pivot = {x, y, z}, parent = "other"?, axis = "yaw"|"pitch"|"roll" } }
--               (parts with `node = "name"` belong to that node; a node's parent turns about
--               the vertical axis only, so a head can yaw while its eye pitches)
--   collision = { {shape = "sphere"|"box"|"cylinder", ...} }  (see lib/volume.lua)
--   budget    = { tris = n }          (else data/base/meshes/budgets.lua, else M.HERO)
-- ---------------------------------------------------------------------------
M.HERO = { tris = 3000, ms = 5, ms_web = 20 } -- a hero mesh: 3k triangles, 5 ms (20 ms on the web)
M.strict = false      -- true (tests, tools): an over-budget mesh is an error; false: a magenta box stands in
M.violations = {}     -- { id =, what = "tris"|"ms", value =, limit = } for every budget that was exceeded

local function load_recipe_fn(id)
  local fn = data.load("meshes/" .. id .. ".lua")
  if type(fn) ~= "function" and not (type(fn) == "table" and getmetatable(fn) and getmetatable(fn).__call) then
    error("mesh recipe " .. id .. " is not callable")
  end
  return fn
end

-- recipe(id, params, seed) -> recipe table from data/base/meshes/<id>.lua
function M.recipe(id, params, seed)
  local fn = load_recipe_fn(id)
  local r = fn(params or {}, saucer.rng.new(seed or 1))
  if type(r) ~= "table" or type(r.parts) ~= "table" then error("mesh recipe " .. id .. " returned no parts") end
  return r
end

-- the budget of a recipe: its own `budget`, else the id's entry in meshes/budgets.lua, else a hero mesh's
function M.budget(id, recipe)
  local b = (recipe and recipe.budget) or data.load("meshes/budgets.lua")[id] or {}
  return { tris = b.tris or M.HERO.tris, ms = b.ms or M.HERO.ms, ms_web = b.ms_web or M.HERO.ms_web }
end

-- is the build time within the limit for this platform? (the limit is a desktop one unless `web`)
function M.time_ok(ms, budget, web)
  return ms <= (web and budget.ms_web or budget.ms)
end

local function web_build() return saucer.engine.platform == "web" end

local function violate(id, what, value, limit)
  M.violations[#M.violations + 1] = { id = id, what = what, value = value, limit = limit }
  local msg = string.format("mesh %s over budget: %s %.4g > %.4g", id, what, value, limit)
  if M.strict and what == "tris" then error(msg, 3) end
  saucer.log.warn(msg)
end

-- the stand-in for a mesh over its triangle budget: a magenta box of the same size
local function fallback(info)
  local mn, mx = info.min, info.max
  return saucer.mesh.build({ parts = { { kind = "box", min = { mn[1], mn[2], mn[3] }, max = { mx[1], mx[2], mx[3] },
                                         color = { 1, 0, 1 } } } })
end

-- check one build against the budget -> the mesh id to use (the fallback when over triangles)
local function enforce(id, mesh, ms, budget)
  local info = saucer.mesh.info(mesh)
  local over = info.triangles > budget.tris
  if over then
    violate(id, "tris", info.triangles, budget.tris)
    local fb = fallback(info)
    saucer.mesh.free(mesh)
    mesh = fb
  end
  if not M.time_ok(ms, budget, web_build()) then violate(id, "ms", ms, web_build() and budget.ms_web or budget.ms) end
  return mesh, { triangles = info.triangles, vertices = info.vertices, ms = ms, over = over }
end

-- build(id, params, seed) -> mesh id, hash, stats { triangles, vertices, ms, over }
function M.build(id, params, seed)
  local r = M.recipe(id, params, seed)
  local budget = M.budget(id, r)
  local mesh, hash, ms = saucer.mesh.build(r)
  local stats
  mesh, stats = enforce(id, mesh, ms, budget)
  return mesh, hash, stats
end

-- the parts of a recipe split by node: { [""] = base parts, name = parts built about the node's pivot }
local function split(r)
  local groups, order = { [""] = {} }, {}
  for _, p in ipairs(r.parts) do
    local n = p.node or ""
    if n ~= "" and not (r.nodes and r.nodes[n]) then error("mesh part names unknown node " .. n) end
    if not groups[n] then groups[n] = {}; order[#order + 1] = n end
    local q = copy(p)
    q.node = nil
    if n ~= "" then
      local pv = r.nodes[n].pivot
      local pp = q.pos or { 0, 0, 0 }
      q.pos = { pp[1] - pv[1], pp[2] - pv[2], pp[3] - pv[3] }
    end
    local g = groups[n]
    g[#g + 1] = q
  end
  table.sort(order)
  return groups, order
end

local function check_nodes(r)
  for n, d in pairs(r.nodes or {}) do
    if type(d.pivot) ~= "table" or #d.pivot ~= 3 then error("node " .. n .. " has no pivot") end
    if d.parent then
      local pd = r.nodes[d.parent]
      if not pd then error("node " .. n .. " has unknown parent " .. d.parent) end
      if pd.axis ~= "yaw" then error("node " .. n .. ": a parent node must turn about the vertical axis (yaw)") end
    end
  end
end

-- rig(id, params, seed) -> { id, base = mesh id | nil, hash, nodes = { name = { mesh, pivot, parent, axis } },
--   order = parents first, collision, stats, budget }
-- The budget covers the whole rig: base and every node together.
function M.rig(id, params, seed)
  local r = M.recipe(id, params, seed)
  check_nodes(r)
  local volume = require("lib.volume")
  local ok, why = volume.check(r.collision)
  if not ok then error("mesh " .. id .. ": " .. why) end
  local groups, names = split(r)
  local budget = M.budget(id, r)
  local rig = { id = id, nodes = {}, order = {}, collision = r.collision or {}, budget = budget }
  local tris, verts, ms, meshes = 0, 0, 0, {}
  local function make(parts)
    local mesh, hash, t = saucer.mesh.build({ parts = parts })
    local info = saucer.mesh.info(mesh)
    tris, verts, ms = tris + info.triangles, verts + info.vertices, ms + t
    meshes[#meshes + 1] = mesh
    return mesh, hash
  end
  if #groups[""] > 0 then rig.base, rig.hash = make(groups[""]) end
  for _, n in ipairs(names) do
    local d = r.nodes[n]
    local mesh, hash = make(groups[n])
    rig.nodes[n] = { mesh = mesh, hash = hash, pivot = d.pivot, parent = d.parent, axis = d.axis or "yaw" }
  end
  -- parents first, so a child's pose can be placed from its parent's
  local seen = {}
  local function add(n)
    if seen[n] then return end
    seen[n] = true
    if rig.nodes[n] then
      if rig.nodes[n].parent then add(rig.nodes[n].parent) end
      rig.order[#rig.order + 1] = n
    end
  end
  for _, n in ipairs(names) do add(n) end
  rig.stats = { triangles = tris, vertices = verts, ms = ms, over = false }
  if tris > budget.tris then
    violate(id, "tris", tris, budget.tris)
    -- over budget: one magenta box over the rig's bounds stands in, and the nodes stay put
    local mn, mx
    for _, m in ipairs(meshes) do
      local info = saucer.mesh.info(m)
      if not mn then mn, mx = { info.min[1], info.min[2], info.min[3] }, { info.max[1], info.max[2], info.max[3] }
      else
        for k = 1, 3 do
          mn[k] = math.min(mn[k], info.min[k])
          mx[k] = math.max(mx[k], info.max[k])
        end
      end
      saucer.mesh.free(m)
    end
    rig.base = fallback({ min = mn, max = mx })
    rig.nodes, rig.order = {}, {}
    rig.stats.over = true
  end
  if not M.time_ok(ms, budget, web_build()) then violate(id, "ms", ms, web_build() and budget.ms_web or budget.ms) end
  return rig
end

-- the collision volumes of a recipe, without building any mesh (the sim may call this) -> list
local vol_cache = {}
-- a stable text key of a params table (sorted keys, nested tables)
local function param_key(t)
  if type(t) ~= "table" then return tostring(t) end
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = tostring(k) end
  table.sort(keys)
  local out = {}
  for _, k in ipairs(keys) do out[#out + 1] = k .. "=" .. param_key(t[k] ~= nil and t[k] or t[tonumber(k)]) end
  return "{" .. table.concat(out, ",") .. "}"
end
local plain = {} -- id -> seed -> volumes, for the usual call without params (the sim asks every tick)
function M.volumes(id, params, seed)
  local byseed = params == nil or next(params) == nil
  if byseed then
    local row = plain[id]
    local hit = row and row[seed or 1]
    if hit then return hit end
  end
  local key = id .. "|" .. tostring(seed or 1) .. "|" .. param_key(params or {})
  local v = vol_cache[key]
  if not v then
    v = M.recipe(id, params, seed).collision or {}
    vol_cache[key] = v
  end
  if byseed then
    plain[id] = plain[id] or {}
    plain[id][seed or 1] = v
  end
  return v
end

local function ry(yaw, x, y, z)
  local c, s = sm.cos(yaw), sm.sin(yaw)
  return x * c + z * s, y, -x * s + z * c
end

-- where a node sits in the world under a pose: { pos, yaw, pitch, roll }. xf = { pos, yaw, scale? };
-- pose = { [node] = { yaw =, pitch =, roll = } } (radians). A child inherits its parent's yaw.
function M.node_pose(rig, name, xf, pose)
  local n = rig.nodes[name]
  if not n then error("rig " .. rig.id .. " has no node " .. tostring(name)) end
  local sc = xf.scale or 1
  local ang = (pose and pose[name]) or {}
  local px, py, pz, yaw
  if n.parent then
    local pp = M.node_pose(rig, n.parent, xf, pose)
    local pv = rig.nodes[n.parent].pivot
    local dx, dy, dz = ry(pp.yaw, (n.pivot[1] - pv[1]) * sc, (n.pivot[2] - pv[2]) * sc, (n.pivot[3] - pv[3]) * sc)
    px, py, pz, yaw = pp.pos[1] + dx, pp.pos[2] + dy, pp.pos[3] + dz, pp.yaw
  else
    local o = xf.pos or { 0, 0, 0 }
    local dx, dy, dz = ry(xf.yaw or 0, n.pivot[1] * sc, n.pivot[2] * sc, n.pivot[3] * sc)
    px, py, pz, yaw = o[1] + dx, o[2] + dy, o[3] + dz, xf.yaw or 0
  end
  return { pos = { px, py, pz }, yaw = yaw + (ang.yaw or 0), pitch = ang.pitch or 0, roll = ang.roll or 0 }
end

-- draw a rig into a view: the base and every node under its pose. opts (tint, tex...) go to every mesh.
function M.draw(v, rig, xf, pose, opts)
  local sc = xf.scale
  local pos, yaw = xf.pos, xf.yaw or 0
  local n = 0
  if rig.base then
    local o = { pos = pos, yaw = yaw, scale = sc }
    if opts then for k, val in pairs(opts) do o[k] = val end end
    v:mesh(rig.base, o)
    n = 1
  end
  for _, name in ipairs(rig.order) do
    local o = M.node_pose(rig, name, xf, pose)
    o.scale = sc
    if opts then for k, val in pairs(opts) do o[k] = val end end
    v:mesh(rig.nodes[name].mesh, o)
    n = n + 1
  end
  return n
end

return M
