-- SPDX-License-Identifier: MIT
-- add-alien-cities-2 (design civs-and-relics §4.4): drawing the megacity round a city's core (sim/citymega.lua).
-- Levels of detail by the distance from the eye to a district's box:
--   near (NEAR m)  the district's full mesh (every tier of every megaform) and its lit window bands
--   far (FAR m)    a silhouette: one box per megaform
--   beyond         the horizon band, a ring of far towers round the city (one mesh)
-- Meshes are built ahead of the eye (PREFETCH m) and only while the frame's BUDGET_MS lasts, nearest first; the
-- solids come from the sim's cache, so building them here only does the sim's work early. Nothing here is saved.
local mega = require("sim.citymega")
local spr = require("view.sprites")

local M = {}
M.NEAR = 4000
M.MID = 4000
M.PREFETCH = 4600
M.FREE = 5200        -- a full mesh this far away is freed (its silhouette is drawn instead)
M.FAR = 40000
M.BAND = { 26000, 50000 }
M.BAND_N = 240
M.FAR_PLANE = 60000  -- the camera's far plane over a megacity (the downtown keeps the usual one)
M.ZONE = 8000        -- m past the footprint where the megacity still owns the far plane and the air
M.BUDGET_MS = (saucer.engine and saucer.engine.platform == "web") and 4 or 6   -- ms of mesh building a frame
M.BAND_GAP = 24      -- m between two window bands
M.SIL_GAP = 150      -- m between two lit bands of a silhouette
M.SIL_GLOW = 0.18    -- a silhouette's own faint light (the far city never goes black)

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
  local sol = mega.solids(p, d)
  for n, b in ipairs(sol) do
    parts[#parts + 1] = { kind = "box", min = b[1], max = b[2], color = n <= (sol.found or 1) and shade(col, 0.6) or shade(col, 0.9 + (n % 3) * 0.06), uv = uv }
  end
  return parts
end

-- lit window bands round every tier (a little proud of the face so they never fight it)
function M.light_parts(p, d)
  local win = p.style.window or { 1, 0.85, 0.5 }
  local acc0 = p.style.accent or { 0.8, 0.9, 1.0 }
  local parts = {}
  local sol = mega.solids(p, d)
  for n, b in ipairs(sol) do
    if n >= (sol.transit or math.huge) then
      -- a rail or a pylon: the rail's lit underside, a lamp ring near a pylon's top
      local tall = b[2][2] - b[1][2] > 10
      if tall then
        parts[#parts + 1] = { kind = "box", min = { b[1][1] - 0.4, b[2][2] - 8, b[1][3] - 0.4 }, max = { b[2][1] + 0.4, b[2][2] - 6, b[2][3] + 0.4 }, color = acc0, emissive = 1 }
      else
        parts[#parts + 1] = { kind = "box", min = { b[1][1] + 0.5, b[1][2] - 0.3, b[1][3] + 0.5 }, max = { b[2][1] - 0.5, b[1][2], b[2][3] - 0.5 }, color = acc0, emissive = 1 }
      end
    elseif n > (sol.found or 1) then
      local y = b[1][2] + 10
      while y + 3 < b[2][2] do
        parts[#parts + 1] = { kind = "box", min = { b[1][1] - 0.6, y, b[1][3] - 0.6 }, max = { b[2][1] + 0.6, y + 2.5, b[2][3] + 0.6 },
                              color = win, emissive = 1 }
        y = y + M.BAND_GAP
      end
    end
  end
  -- the warren: a lit strip down the middle of every space's ceiling, a glowing line along its floor, a lit collar
  -- where the shaft comes down
  local w = d.warren
  if w then
    for _, r in ipairs(w.spaces) do
      local cx, cz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
      local along_x = r[3] - r[1] >= r[4] - r[2]
      local hx, hz = along_x and (r[3] - r[1]) / 2 - 4 or 3, along_x and 3 or (r[4] - r[2]) / 2 - 4
      parts[#parts + 1] = { kind = "box", min = { cx - hx, w.y1 - 0.5, cz - hz }, max = { cx + hx, w.y1 - 0.1, cz + hz }, color = win, emissive = 1 }
      local fx, fz = along_x and hx or 0.8, along_x and 0.8 or hz
      parts[#parts + 1] = { kind = "box", min = { cx - fx, w.y0, cz - fz }, max = { cx + fx, w.y0 + 0.3, cz + fz }, color = acc0, emissive = 1 }
    end
    local sh = w.shaft
    for _, r in ipairs({ { sh[1], sh[2], sh[3], sh[2] + 1.5 }, { sh[1], sh[4] - 1.5, sh[3], sh[4] }, { sh[1], sh[2], sh[1] + 1.5, sh[4] }, { sh[3] - 1.5, sh[2], sh[3], sh[4] } }) do
      parts[#parts + 1] = { kind = "box", min = { r[1], w.y1 - 3, r[2] }, max = { r[3], w.y1 - 0.1, r[4] }, color = acc0, emissive = 1 }
    end
  end
  -- the fold bays: a lit rim round each pad and a glowing plate on its cradle
  local acc = p.style.accent or { 0.8, 0.9, 1.0 }
  for _, b in ipairs(mega.bays(p, d)) do
    local x0, z0, x1, z1, y = b.lo[1], b.lo[3], b.hi[1], b.hi[3], b.lo[2]
    for _, r in ipairs({ { x0, z0, x1, z0 + 1.5 }, { x0, z1 - 1.5, x1, z1 }, { x0, z0, x0 + 1.5, z1 }, { x1 - 1.5, z0, x1, z1 } }) do
      parts[#parts + 1] = { kind = "box", min = { r[1], y, r[2] }, max = { r[3], y + 0.3, r[4] }, color = acc, emissive = 1 }
    end
    local c, cs = b.cradle, mega.CRADLE[1] / 2 - 2
    parts[#parts + 1] = { kind = "box", min = { c[1] - cs, c[2], c[3] - cs }, max = { c[1] + cs, c[2] + 0.3, c[3] + cs }, color = win, emissive = 1 }
  end
  return parts
end

-- the silhouette: a foundation and one box per megaform
function M.sil_parts(p, d)
  local col, y = M.stone(p, d), p.frame.y
  local b = d.cell
  local parts = { { kind = "box", min = { b[1], y - 6, b[2] }, max = { b[3], y, b[4] }, color = shade(col, 0.6) } }
  local win = p.style.window or { 1, 0.85, 0.5 }
  local glow = shade(win, 0.8)
  for _, o in ipairs(d.organs) do
    local x0, z0, x1, z1 = o.x0 + o.w * 0.1, o.z0 + o.w2 * 0.1, o.x0 + o.w * 0.9, o.z0 + o.w2 * 0.9
    parts[#parts + 1] = { kind = "box", min = { x0, y, z0 }, max = { x1, y + o.h, z1 }, color = col, emissive = M.SIL_GLOW }
    -- a few broad lit bands, so the far city still reads at night
    for yy = y + 60, y + o.h - 30, M.SIL_GAP do
      parts[#parts + 1] = { kind = "box", min = { x0 - 1, yy, z0 - 1 }, max = { x1 + 1, yy + 30, z1 + 1 }, color = glow, emissive = 1 }
    end
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
M.ORGAN_DRAW = 2000  -- m: an organ hall's machine is drawn this near

-- an organ's machine (a function of the clock) -> pose { pos, scale, yaw, rings = { {scale, yaw, pitch, roll}... },
-- core = { pos, size }, glow }. A wide halo almost fills the hall and rocks gently; inside it a second ring stands up
-- and rolls over, and a third spins fast round a pulsing, bobbing core. Every ring stays inside its hall.
M.ORGAN_TILT = 0.18   -- rad, the halo's rocking
function M.organ_pose(d, t)
  local og = d.organ
  local h = og.hall
  local ph = (d.k * 0.73) % 6.283
  local half = og.h / 2 - 6
  local side = math.min(h[4] - h[1], h[6] - h[3]) / 2 - 18
  local r1 = math.max(8, math.min(side, half / math.sin(M.ORGAN_TILT)))
  local r2 = math.min(r1 * 0.62, half)
  local r3 = r2 * 0.45
  local c = og.centre
  local yaw = t * 0.21 + ph
  local pulse = 0.5 + 0.5 * math.sin(t * 1.3 + ph)
  local core = 6 + 4 * pulse
  local bob = math.min(r3 * 0.3, half - core) * math.sin(t * 0.4 + ph)
  return { pos = c, scale = r1, yaw = yaw,
           rings = { { scale = r1, yaw = yaw, pitch = M.ORGAN_TILT * math.sin(t * 0.13 + ph), roll = 0 },
                     { scale = r2, yaw = -yaw * 1.7, pitch = 1.2 + 0.3 * math.sin(t * 0.29 + ph), roll = t * 0.37 },
                     { scale = r3, yaw = t * 1.1 + ph, pitch = 0.4 * math.sin(t * 0.7), roll = t * 0.9 } },
           core = { pos = { c[1], c[2] + bob, c[3] }, size = core }, glow = r2 * (0.8 + 0.4 * pulse), pulse = pulse }
end

-- the sanctum at the far end of an organ's warren: a cluster of glowing stones circling a dim heart, swelling and
-- shrinking as if breathing, never touching the floor or the ceiling (a function of the clock)
-- -> { heart = {pos, size}, stones = { {pos, size, yaw} }, breath }
M.STONES = 7
function M.sanctum_pose(d, t)
  local w = d.warren
  local c = w.sanctum
  local ph = (d.k * 1.31) % 6.283
  local breath = 0.5 + 0.5 * math.sin(t * 0.45 + ph)
  local R = c.size * (0.22 + 0.08 * breath)
  local stones = {}
  for i = 1, M.STONES do
    local a = t * (0.12 + 0.02 * i) + i * 6.283 / M.STONES + ph
    local y = c[2] + 9 * math.sin(t * 0.3 + i * 1.7)
    stones[i] = { pos = { c[1] + math.sin(a) * R, y, c[3] + math.cos(a) * R }, size = 3 + 2 * breath + (i % 3), yaw = a * 2 }
  end
  return { heart = { pos = { c[1], c[2], c[3] }, size = 6 + 5 * breath }, stones = stones, breath = breath }
end

-- the warren's lamps: one under the middle of each space's ceiling (two down a long corridor), coloured by the city,
-- the sanctum's breathing with its heart. Offered when the eye is near and low (the engine keeps those that matter).
M.WARREN_LAMPS = 700     -- m from the district
M.WARREN_LAMP_Y = 80     -- m above the street: higher than this the eye cannot see down the shaft
M.WARREN_LUX = 0.2
function M.warren_lamps(v, p, d, t)
  local w = d.warren
  local win = p.style.window or { 1, 0.85, 0.5 }
  local acc = p.style.accent or { 0.8, 0.9, 1.0 }
  local lights = require("view.lights")
  local n = 0
  local y = w.y1 - 3
  for _, r in ipairs(w.spaces) do
    local sx, sz = r[3] - r[1], r[4] - r[2]
    local long = math.max(sx, sz)
    local k = long > 140 and 2 or 1
    for i = 1, k do
      local f = (i - 0.5) / k
      local x = sx >= sz and r[1] + sx * f or (r[1] + r[3]) / 2
      local z = sx >= sz and (r[2] + r[4]) / 2 or r[2] + sz * f
      local reach = math.min(long / k, math.min(sx, sz)) * 0.9 + 30
      local col, k2 = win, 1
      if r[5] == "sanctum" then col, k2 = acc, 0.6 + 0.8 * M.sanctum_pose(d, t).breath end
      lights.lamp(v, { kind = "point", pos = { x, y, z }, color = col, intensity = M.WARREN_LUX * k2 * reach * reach, range = reach })
      n = n + 1
    end
  end
  return n
end

-- add-alien-cities-5: mag-trains high over the avenues on a district's west and north sides, end to end and back
-- (a function of the clock, render only), each a string of dark cars with a lit keel
-- -> { cars = { {pos, size} }, dir }
M.TRAIN_DRAW = 3000
M.TRAIN_SPEED = 55     -- m/s
M.TRAIN_CARS = 6
M.TRAIN_CAR = { 8, 7, 32 }  -- m, a car's width, height and length
M.TRAIN_Y = { mega.RAIL_Y[1] + mega.TRAIN_CLEAR, mega.RAIL_Y[2] + mega.TRAIN_CLEAR } -- m above the street, a car's middle
function M.train_pose(p, d, k, t)
  local c = d.cell
  local len = k == 1 and (c[4] - c[2]) or (c[3] - c[1])
  local run = 2 * len
  local u = (t * M.TRAIN_SPEED + d.k * 613 + k * 1777) % run
  local dir = 1
  if u > len then u, dir = run - u, -1 end
  local y = p.frame.y + M.TRAIN_Y[k]
  local cars = {}
  local L = M.TRAIN_CAR[3] + 3
  for n = 0, M.TRAIN_CARS - 1 do
    local a = math.max(0, math.min(len, u - dir * n * L))
    local pos = k == 1 and { c[1], y, c[2] + a } or { c[1] + a, y, c[2] }
    local size = k == 1 and { M.TRAIN_CAR[1], M.TRAIN_CAR[2], M.TRAIN_CAR[3] } or { M.TRAIN_CAR[3], M.TRAIN_CAR[2], M.TRAIN_CAR[1] }
    cars[#cars + 1] = { pos = pos, size = size }
  end
  return { cars = cars, dir = dir }
end

-- the drifters: tall glowing slabs that glide down the avenues on a district's east and south sides, turning and
-- bobbing, never touching anything, each with a halo and two small followers (a function of the clock)
-- -> pose { pos, size, yaw, glow, trail = { {pos, size}... } }
M.DRIFT_DRAW = 3500
M.DRIFT_SPEED = 9     -- m/s
M.DRIFT_SIZE = { 16, 84, 6 }
M.DRIFT_OFF = 22      -- m off the avenue's midline (the rails' pylons stand on it)
function M.drift_pose(p, d, k, t)
  local c = d.cell
  local len = k == 1 and (c[4] - c[2]) or (c[3] - c[1])
  local function at(tt)
    local u = (tt * M.DRIFT_SPEED + d.k * 397 + k * 911) % (2 * len)
    if u > len then u = 2 * len - u end
    local y = p.frame.y + 110 + 50 * math.sin(tt * 0.17 + d.k + k)
    return k == 1 and { c[3] - M.DRIFT_OFF, y, c[2] + u } or { c[1] + u, y, c[4] - M.DRIFT_OFF }
  end
  local trail = {}
  for i = 1, 2 do trail[i] = { pos = at(t - i * 4), size = 6 - i * 1.5 } end
  return { pos = at(t), size = M.DRIFT_SIZE, yaw = t * 0.11 + d.k * 0.5 + k, glow = 70, trail = trail }
end

function M.draw(v, A, p, cam, tex, visible, budget, t)
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
      if dist <= M.DRIFT_DRAW then
        local win = p.style.window or { 1, 0.85, 0.5 }
        local tint = { win[1], win[2], win[3], 1 }
        local box = require("view.assets").unit_box(true)
        for kk = 1, 2 do
          local o = M.drift_pose(p, d, kk, t or 0)
          v:mesh(box, { pos = o.pos, scale = o.size, yaw = o.yaw, palette = A.pal.base, tint = tint })
          for _, f in ipairs(o.trail) do
            v:mesh(box, { pos = f.pos, scale = { f.size, f.size, f.size }, yaw = -o.yaw, palette = A.pal.base, tint = tint })
          end
          spr.light(v, A, o.pos, o.glow, { tint = { win[1], win[2], win[3], 0.45 } })
          st.drifters = (st.drifters or 0) + 1
        end
      end
      if dist <= M.TRAIN_DRAW then
        local acc = p.style.accent or { 0.8, 0.9, 1.0 }
        local dark, glow = require("view.assets").unit_box(false), require("view.assets").unit_box(true)
        for kk = 1, 2 do
          for _, car in ipairs(M.train_pose(p, d, kk, t or 0).cars) do
            v:mesh(dark, { pos = car.pos, scale = car.size, tex = tex, palette = A.pal.base, tint = { 0.55, 0.58, 0.66, 1 } })
            local z = car.size
            v:mesh(glow, { pos = { car.pos[1], car.pos[2] - z[2] / 2 - 0.4, car.pos[3] }, scale = { z[1] * 0.9, 0.8, z[3] * 0.9 },
                           palette = A.pal.base, tint = { acc[1], acc[2], acc[3], 1 } })
          end
          st.trains = (st.trains or 0) + 1
        end
      end
      if d.organ and dist <= M.ORGAN_DRAW then
        local o = M.organ_pose(d, t or 0)
        local acc = p.style.accent or { 0.8, 0.9, 1.0 }
        local win = p.style.window or acc
        local ring = require("view.cityphen").ring_mesh()
        for i, r in ipairs(o.rings) do
          local col = i == 2 and win or acc
          v:mesh(ring, { pos = o.pos, scale = r.scale, yaw = r.yaw, pitch = r.pitch, roll = r.roll,
                         palette = A.pal.base, tint = { col[1], col[2], col[3], 1 } })
        end
        local cs = o.core.size
        v:mesh(require("view.assets").unit_box(true), { pos = o.core.pos, scale = { cs, cs, cs }, yaw = o.yaw * 2, pitch = o.yaw,
                                                        palette = A.pal.base, tint = { win[1], win[2], win[3], 1 } })
        spr.light(v, A, o.core.pos, o.glow, { tint = { acc[1], acc[2], acc[3], 0.35 + 0.3 * o.pulse } })
        st.organs = (st.organs or 0) + 1
        if d.warren and cam.pos[2] < d.y + M.WARREN_LAMP_Y and dist <= M.WARREN_LAMPS then
          st.lamps = (st.lamps or 0) + M.warren_lamps(v, p, d, t or 0)
          -- the strange things going on down there (as in the builders' relics)
          local w = d.warren
          local phv = require("view.phenomena")
          for _, ph in ipairs(w.phenomena or {}) do
            local r = w.spaces[ph.space]
            phv.draw_one(v, A, ph, { r[1], w.y0, r[2] }, { r[3], w.y1, r[4] }, cam, t or 0, A.pal.base)
            st.phenomena = (st.phenomena or 0) + 1
          end
        end
        if d.warren then
          local sp = M.sanctum_pose(d, t or 0)
          local box = require("view.assets").unit_box(true)
          for _, o2 in ipairs(sp.stones) do
            local z = o2.size
            v:mesh(box, { pos = o2.pos, scale = { z, z, z }, yaw = o2.yaw, palette = A.pal.base, tint = { acc[1], acc[2], acc[3], 1 } })
          end
          local hz = sp.heart.size
          v:mesh(box, { pos = sp.heart.pos, scale = { hz, hz, hz }, yaw = -o.yaw, palette = A.pal.base, tint = { win[1] * 0.5, win[2] * 0.5, win[3] * 0.5, 1 } })
          spr.light(v, A, sp.heart.pos, hz * 4, { tint = { win[1], win[2], win[3], 0.25 + 0.3 * sp.breath } })
          st.sanctums = (st.sanctums or 0) + 1
        end
      end
    elseif c.sil[k] then
      v:mesh(c.sil[k], { palette = A.pal.base })
      st.sil = st.sil + 1
    end
  end
  if not c.band then c.band = saucer.mesh.build({ parts = M.band_parts(p) }) end
  v:mesh(c.band, { palette = A.pal.base })
  st.band = 1
  return st
end

-- the far plane for a camera at pos: the megacity's when pos is over one (in_city(pos) -> plan or nil)
function M.far_plane(cam, in_city)
  if in_city(cam.pos) then cam.far = math.max(cam.far or 0, M.FAR_PLANE) end
  return cam
end

return M
