-- SPDX-License-Identifier: MIT
-- add-alien-cities-2 (design civs-and-relics §4.4): drawing the megacity round a city's core (sim/citymega.lua).
-- Levels of detail by the distance from the eye to a district's box:
--   near (NEAR m)  the district's full mesh and its lit window bands
--   mid (MID m)    the full mesh, every tier of every megaform
--   far (FAR m)    a silhouette: one box per megaform
--   beyond         the horizon band, a ring of far towers round the city (one mesh)
-- Meshes are built ahead of the eye (PREFETCH m) and only while the frame's BUDGET_MS lasts, nearest first; the
-- solids come from the sim's cache, so building them here only does the sim's work early. Nothing here is saved.
local mega = require("sim.citymega")

local M = {}
M.NEAR = 700
M.MID = 4000
M.PREFETCH = 4600
M.FREE = 5200        -- a full mesh this far away is freed (its silhouette is drawn instead)
M.FAR = 40000
M.BAND = { 26000, 50000 }
M.BAND_N = 240
M.FAR_PLANE = 60000  -- the camera's far plane over a megacity (the downtown keeps the usual one)
M.ZONE = 8000        -- m past the footprint where the megacity still owns the far plane and the air
M.BUDGET_MS = 6
M.AIR = 400          -- m off an outer district's block where the city's air and light still hold
M.BAND_GAP = 24      -- m between two window bands

local caches = setmetatable({}, { __mode = "k" })
local function cache(p)
  local c = caches[p]
  if not c then
    c = { full = {}, lights = {}, sil = {}, built = 0 }
    caches[p] = c
  end
  return c
end
M.cache = cache

local function shade(col, f) return { col[1] * f, col[2] * f, col[3] * f } end

-- the colour of a district's stone: the kit's, warmed or cooled by its value
local VALUE_TINT = { knowledge = 1.08, hoarding = 0.92, faith = 1.12, kinship = 0.96, conquest = 0.86, craft = 1.0, harmony = 1.04 }
function M.stone(p, d)
  local base = p.frame.kit.solid_color or { 0.34, 0.38, 0.48 }
  return shade(base, VALUE_TINT[d.value] or 1)
end

-- the full mesh's parts of district d
function M.full_parts(p, d)
  local col, uv = M.stone(p, d), p.frame.kit.uv or 0.125
  local parts = {}
  for n, b in ipairs(mega.solids(p, d)) do
    parts[#parts + 1] = { kind = "box", min = b[1], max = b[2], color = n == 1 and shade(col, 0.6) or shade(col, 0.9 + (n % 3) * 0.06), uv = uv }
  end
  return parts
end

-- lit window bands round every tier (a little proud of the face so they never fight it)
function M.light_parts(p, d)
  local win = p.style.window or { 1, 0.85, 0.5 }
  local parts = {}
  for n, b in ipairs(mega.solids(p, d)) do
    if n > 1 then
      local y = b[1][2] + 10
      while y + 3 < b[2][2] do
        parts[#parts + 1] = { kind = "box", min = { b[1][1] - 0.6, y, b[1][3] - 0.6 }, max = { b[2][1] + 0.6, y + 2.5, b[2][3] + 0.6 },
                              color = win, emissive = 1 }
        y = y + M.BAND_GAP
      end
    end
  end
  return parts
end

-- the silhouette: a foundation and one box per megaform
function M.sil_parts(p, d)
  local col, y = M.stone(p, d), p.frame.y
  local b = d.box
  local parts = { { kind = "box", min = { b[1], y - 6, b[2] }, max = { b[3], y, b[4] }, color = shade(col, 0.6) } }
  for _, o in ipairs(d.organs) do
    parts[#parts + 1] = { kind = "box", min = { o.x0 + o.w * 0.1, y, o.z0 + o.w2 * 0.1 }, max = { o.x0 + o.w * 0.9, y + o.h, o.z0 + o.w2 * 0.9 },
                          color = col }
  end
  return parts
end

-- the horizon band: far towers in a ring round the city's centre
function M.band_parts(p)
  local rng = saucer.rng.new(saucer.seed_child(p.seed, "megaband", 0))
  local col = shade(p.frame.kit.solid_color or { 0.34, 0.38, 0.48 }, 0.8)
  local win = p.style.window or { 1, 0.85, 0.5 }
  local parts = {}
  for n = 1, M.BAND_N do
    local a = (n + rng:float()) / M.BAND_N * saucer.math.tau
    local rr = rng:int(M.BAND[1], M.BAND[2])
    local w, h = rng:int(200, 900), rng:int(300, 1800)
    local x, z = p.frame.cx + saucer.math.sin(a) * rr, p.frame.cz + saucer.math.cos(a) * rr
    local y0 = p.frame.y
    parts[#parts + 1] = { kind = "box", min = { x - w / 2, y0, z - w / 2 }, max = { x + w / 2, y0 + h, z + w / 2 }, color = col }
    if rng:int(1, 100) <= 45 then
      parts[#parts + 1] = { kind = "box", min = { x - w / 2 - 2, y0 + h * 0.7, z - w / 2 - 2 }, max = { x + w / 2 + 2, y0 + h * 0.7 + 12, z + w / 2 + 2 },
                            color = win, emissive = 1 }
    end
  end
  return parts
end

-- distance from pos to district d's block (its box from the street to its top)
function M.dist(p, d, pos)
  local dist = mega.rect_dist(d.box, pos[1], pos[3])
  local y0, y1 = p.frame.y, p.frame.y + d.top
  local dy = math.max(y0 - pos[2], 0, pos[2] - y1)
  return math.sqrt(dist * dist + dy * dy)
end

local function now_ms() return saucer.time and saucer.time.wall_ms and saucer.time.wall_ms() or 0 end

-- one frame of plan p: build what the budget allows, free what is far, draw by level. visible(c, r) culls.
-- -> stats { full, lights, sil, band, built, culled, freed }
function M.draw(v, A, p, cam, tex, visible, budget)
  local c = cache(p)
  local st = { full = 0, lights = 0, sil = 0, band = 0, built = 0, culled = 0, freed = 0 }
  local t0, limit = now_ms(), budget or M.BUDGET_MS
  local function room() return now_ms() - t0 < limit end
  local order = {}
  for k, d in ipairs(p.districts) do order[#order + 1] = { k = k, d = d, dist = M.dist(p, d, cam.pos) } end
  table.sort(order, function(a, b) if a.dist ~= b.dist then return a.dist < b.dist end return a.k < b.k end)
  for _, e in ipairs(order) do
    local k, d, dist = e.k, e.d, e.dist
    -- free what has fallen far behind
    if c.full[k] and dist > M.FREE then
      saucer.mesh.free(c.full[k])
      c.full[k] = nil
      st.freed = st.freed + 1
    end
    if c.lights[k] and dist > M.NEAR + 300 then
      saucer.mesh.free(c.lights[k])
      c.lights[k] = nil
      st.freed = st.freed + 1
    end
    -- build ahead, nearest first, while the budget lasts
    if dist <= M.PREFETCH and not c.full[k] and room() then
      c.full[k] = saucer.mesh.build({ parts = M.full_parts(p, d) })
      st.built, c.built = st.built + 1, c.built + 1
    end
    if dist <= M.NEAR and not c.lights[k] and room() then
      c.lights[k] = saucer.mesh.build({ parts = M.light_parts(p, d) })
      st.built, c.built = st.built + 1, c.built + 1
    end
    if dist <= M.FAR and not c.sil[k] and (room() or st.built == 0) then
      c.sil[k] = saucer.mesh.build({ parts = M.sil_parts(p, d) })
      st.built, c.built = st.built + 1, c.built + 1
    end
    local b = d.box
    local cx, cz = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
    local hw = math.sqrt((b[3] - b[1]) ^ 2 + (b[4] - b[2]) ^ 2 + d.top * d.top) / 2
    if dist > M.FAR then
      -- past the silhouettes: the band stands in
    elseif not visible({ cx, p.frame.y + d.top / 2, cz }, hw) then
      st.culled = st.culled + 1
    elseif dist <= M.MID and c.full[k] then
      v:mesh(c.full[k], { tex = tex, palette = A.pal.base })
      st.full = st.full + 1
      if dist <= M.NEAR and c.lights[k] then
        v:mesh(c.lights[k], { palette = A.pal.base })
        st.lights = st.lights + 1
      end
    elseif c.sil[k] then
      v:mesh(c.sil[k], { tex = tex, palette = A.pal.base })
      st.sil = st.sil + 1
    end
  end
  if not c.band then c.band = saucer.mesh.build({ parts = M.band_parts(p) }) end
  v:mesh(c.band, { tex = tex, palette = A.pal.base })
  st.band = 1
  return st
end

-- the far plane for a camera at pos: the megacity's when pos is over one (in_city(pos) -> plan or nil)
function M.far_plane(cam, in_city)
  if in_city(cam.pos) then cam.far = math.max(cam.far or 0, M.FAR_PLANE) end
  return cam
end

return M
