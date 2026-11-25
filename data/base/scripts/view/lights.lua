-- SPDX-License-Identifier: MIT
-- add-realistic-lighting: what lights a view. Render only (nothing here touches the sim).
--   * Space is dark: a tiny ambient keeps silhouettes readable, everything else comes from lights.
--   * Outside, the system's star is the light: one sun per sector (its colour and direction a pure
--     function of the seed and the sector), casting shadows. Inside a derelict's room, a hangar bay or
--     a station there is no sun: only the placed lamps, coloured by the place (stations warm and white,
--     alien places colourful), each a point light with inverse-square falloff.
--   * Your saucer: cabin lamps per Villa room, two headlights and an all-round flood (sim/lights.lua
--     switches them). Every light goes to the engine's light list (view:light); it keeps the 16 that
--     matter most at the eye and gives the strongest casters the shadow maps.
local game = require("sim.game")
local ruinm = require("sim.ruin")
local configs = require("sim.config")
local avatar = require("sim.avatar")
local vec = require("lib.vec")
local sm = saucer.math
local M = {}

M.AMBIENT_SPACE = { 0.035, 0.035, 0.05 } -- starlight and the nebulae: silhouettes, nothing more
M.AMBIENT_INSIDE = { 0.018, 0.018, 0.024 }
M.EXPOSURE = 1.0
M.SUN = 2.8               -- the star's irradiance on a face turned to it
M.ROOM_LUX = 0.25         -- a room lamp gives about this much at half its reach (dim: space is dark)
M.NEAR = 170              -- room lamps nearer the eye than this are offered to the engine
M.CELL = 96               -- lamp bucket size (m)
-- add-lighting-mood: the dark between the lamps, and light you can see in the air
M.POOL_LUX = 0.55         -- a room's lamp pool: this much at its centre-ish (intensity = POOL_LUX * reach^2)
M.CITY_LUX = 1.6          -- a city's pools are this much brighter
M.DARK_ROOMS = 3          -- one room in this many has no lamp at all (hash of site and room)
M.LAMP_SCALE = 0.6        -- every placed lamp (rooms, bays, stations, sentries): one global dimmer
M.HAZE = 0.02             -- how much the air scatters (beams and halos); per light it is haze * HAZE
M.HAZE_LAMP = 0.3         -- a placed lamp's halo
M.HAZE_HEAD, M.HAZE_FLOOD, M.HAZE_SENTRY = 1.0, 0.12, 0.6

-- the kinds of star, by how common they are in the game's sectors
M.STARS = {
  { kind = "yellow", color = { 1.0, 0.93, 0.80 }, k = 1.0 },
  { kind = "white", color = { 0.92, 0.95, 1.0 }, k = 1.1 },
  { kind = "orange", color = { 1.0, 0.74, 0.50 }, k = 0.9 },
  { kind = "blue", color = { 0.75, 0.85, 1.0 }, k = 1.25 },
  { kind = "red", color = { 1.0, 0.52, 0.40 }, k = 0.75 },
}

local function hash(a, b, c)
  local h = (a * 73856093 ~ b * 19349663 ~ (c or 0) * 83492791) & 0x7fffffff
  h = ((h ~ (h >> 13)) * 1274126177) & 0x7fffffff
  return h ~ (h >> 16)
end
M.hash = hash

-- the sector's star: -> { kind, color, intensity, dir (unit, toward the star) }
local stars = {}
function M.star(seed, sid)
  local key = tostring(seed) .. ":" .. tostring(sid)
  local s = stars[key]
  if s then return s end
  local h = hash(math.floor(seed) & 0x7fffffff, math.floor(sid), 7)
  local def = M.STARS[h % #M.STARS + 1]
  local yaw = ((h >> 4) % 3600) / 3600 * sm.tau
  local el = 0.22 + ((h >> 16) % 1000) / 1000 * 0.6
  local ce = sm.cos(el)
  s = { kind = def.kind, color = def.color, intensity = M.SUN * def.k,
        dir = { ce * sm.sin(yaw), sm.sin(el), ce * sm.cos(yaw) } }
  stars[key] = s
  return s
end

-- the colours a place's lamps come in
M.PALETTES = {
  starship = { { 0.75, 0.9, 1.0 }, { 0.35, 0.95, 1.0 }, { 1.0, 0.28, 0.2 }, { 1.0, 0.72, 0.35 } },
  station = { { 1.0, 0.88, 0.72 }, { 1.0, 0.95, 0.88 }, { 0.88, 0.94, 1.0 }, { 1.0, 0.8, 0.6 } },
  hive = { { 0.5, 1.0, 0.4 }, { 1.0, 0.6, 0.15 }, { 0.75, 0.4, 1.0 }, { 0.3, 1.0, 0.75 } },
  alien = { { 1.0, 0.35, 0.8 }, { 0.3, 0.9, 1.0 }, { 1.0, 0.75, 0.3 }, { 0.6, 0.45, 1.0 }, { 0.4, 1.0, 0.55 } },
  trader = { { 1.0, 0.9, 0.78 }, { 1.0, 0.97, 0.92 }, { 1.0, 0.82, 0.62 } },
}
function M.palette(ruin)
  if ruin.city then
    local st = ruin.city.style or {}
    local out = { st.window or { 1, 0.85, 0.5 }, st.accent or { 0.4, 0.9, 1 } }
    for _, c in ipairs(M.PALETTES.alien) do out[#out + 1] = c end
    return out
  end
  return M.PALETTES[ruin.kit] or M.PALETTES.alien
end

local floor = math.floor
local function bucket_key(x, y, z) return floor(x / M.CELL) .. "," .. floor(y / M.CELL) .. "," .. floor(z / M.CELL) end

-- a derelict's (or a city's) lamps: per room one to three (a city: four) low pools along its long side,
-- the reach a share of the room's length, the colour from the place's palette. Cached per ruin, bucketed.
local lamps_of = setmetatable({}, { __mode = "k" })
-- forget every cached lamp list (view/relic.set_style restyles the relics)
function M.forget() lamps_of = setmetatable({}, { __mode = "k" }) end
function M.room_lamps(ruin, origin, site)
  local c = lamps_of[ruin]
  if c then return c end
  local kit = ruinm.kit_of(ruin.kit)
  local pal = M.palette(ruin)
  local list, buckets = {}, {}
  -- add-relic-stations: a relic's lamps come from view/relic.lua
  if ruin.relic then list = require("view.relic").lamps(ruin, origin, site) end
  for i, r in ipairs(ruin.relic and {} or ruin.rooms) do
    local mn, mx = ruinm.room_box(r, kit, origin)
    local sx, sy, sz = mx[1] - mn[1], mx[2] - mn[2], mx[3] - mn[3]
    local long = sx > sz and 1 or 3
    -- add-lighting-mood: pools of light low in the room with darkness between them, not a ceiling flood;
    -- some rooms stay dark. 1-3 pools along the long axis, each lighting about a third of the room.
    -- (a city's streets and halls are lived in: every room has its pools, a little brighter and more of them)
    local dark = not ruin.city and hash(site, i, 99) % M.DARK_ROOMS == 0 and #ruin.rooms > 1
    local n = math.max(1, math.min(ruin.city and 4 or 3, math.ceil(math.max(sx, sz) / (ruin.city and 24 or 34))))
    local reach = math.max(7, math.min(17, math.max(sx, sz) / n * 0.5))
    for k = 1, dark and 0 or n do
      local h = hash(site, i, k)
      local side = long == 1 and 3 or 1
      local pos = { (mn[1] + mx[1]) / 2, mn[2] + math.min(3.5, sy * 0.35), (mn[3] + mx[3]) / 2 }
      pos[long] = mn[long] + (mx[long] - mn[long]) * (k - 0.5) / n
      -- against a wall, alternating sides: a lamp you can see, a pool on the floor beside it
      local sgn = (k + h) % 2 == 0 and -1 or 1
      pos[side] = (sgn < 0 and mn[side] + 1.2) or (mx[side] - 1.2)
      if mx[side] - mn[side] < 8 then pos[side] = (mn[side] + mx[side]) / 2 end
      list[#list + 1] = { pos = pos, color = pal[h % #pal + 1], range = reach, district = r.district,
                          intensity = M.POOL_LUX * (ruin.city and M.CITY_LUX or 1) * reach * reach }
    end
  end
  for _, lamp in ipairs(list) do
    local key = bucket_key(lamp.pos[1], lamp.pos[2], lamp.pos[3])
    local b = buckets[key]
    if not b then b = {} buckets[key] = b end
    b[#b + 1] = lamp
  end
  c = { list = list, buckets = buckets }
  lamps_of[ruin] = c
  return c
end

-- the lamps near p: -> a list (unsorted) from the buckets round it
function M.near(c, p, r)
  local out = {}
  local s = M.CELL
  local x0, x1 = floor((p[1] - r) / s), floor((p[1] + r) / s)
  local y0, y1 = floor((p[2] - r) / s), floor((p[2] + r) / s)
  local z0, z1 = floor((p[3] - r) / s), floor((p[3] + r) / s)
  for x = x0, x1 do
    for y = y0, y1 do
      for z = z0, z1 do
        local b = c.buckets[x .. "," .. y .. "," .. z]
        if b then
          for _, l in ipairs(b) do
            local dx, dy, dz = l.pos[1] - p[1], l.pos[2] - p[2], l.pos[3] - p[3]
            local lim = r + l.range
            if dx * dx + dy * dy + dz * dz < lim * lim then out[#out + 1] = l end
          end
        end
      end
    end
  end
  return out
end

-- inside a site's room? -> the site index or nil (cities: their halls; the streets are outside)
function M.inside_site(state, pos)
  for i, site in ipairs(state.sector.sites) do
    local r = game.ruin(i)
    if r and ruinm.room_at(r, site.pos, pos) then return i end
  end
  return nil
end

-- inside a hangar bay of a trader station? -> the bay or nil
function M.inside_bay(state, pos)
  local dock = require("sim.dock")
  for i = 1, dock.count(state) do
    local b = dock.bay(state, i)
    if pos[1] >= b.lo[1] and pos[1] <= b.hi[1] and pos[2] >= b.lo[2] - 1 and pos[2] <= b.hi[2]
        and pos[3] >= b.lo[3] and pos[3] <= b.hi[3] then
      return b
    end
  end
  return nil
end

-- every light goes through here. A placed lamp (no owner) is dimmed by LAMP_SCALE; each light's glow in the
-- air is its haze (lamps: HAZE_LAMP) times HAZE (add-lighting-mood)
local function add(v, l)
  if not v.light then return end
  if l.kind ~= "sun" then
    if not l.owner and not l.cabin then
      l.intensity = (l.intensity or 1) * M.LAMP_SCALE
      l.haze = l.haze or M.HAZE_LAMP
    end
    l.haze = (l.haze or 0) * M.HAZE
  end
  v:light(l)
end

-- a placed lamp from elsewhere in the view (add-alien-cities-5: the warrens' lamps)
function M.lamp(v, l) add(v, l) end

-- the bay's lamps: a 3 x 2 grid of warm-white ceiling floods and the pad's green and red beacons
function M.bay_lamps(v, b, tick)
  local h = b.hi[2] - b.floor
  local n = 0
  for ix = 0, 2 do
    for iz = 0, 1 do
      local x = b.lo[1] + (b.hi[1] - b.lo[1]) * (ix + 0.5) / 3
      local z = b.lo[3] + (b.hi[3] - b.lo[3]) * (iz + 0.5) / 2
      local c = M.PALETTES.trader[(ix + iz) % 3 + 1]
      add(v, { kind = "point", pos = { x, b.hi[2] - 1.5, z }, color = c, intensity = 0.6 * h * h, range = h * 2.2,
               shadow = true })
      n = n + 1
    end
  end
  local blink = (tick // 30) % 2 == 0 and 1 or 0.35
  add(v, { kind = "point", pos = { b.pad[1] + 9, b.floor + 0.6, b.pad[3] }, color = { 0.2, 1, 0.35 },
           intensity = 30 * blink, range = 16 })
  add(v, { kind = "point", pos = { b.pad[1] - 9, b.floor + 0.6, b.pad[3] }, color = { 1, 0.2, 0.15 },
           intensity = 30 * (1.35 - blink), range = 16 })
  return n + 2
end

-- a station's walkable inside (view/station.lua): ceiling lamps every ~11 m in every area. add-alien-stations:
-- the alien wing's lamps come in its family's colours (data/base/station/hull.lua), hung lower in the chambers,
-- and tall shafts get a ring of lamps every ~12 m up their walls
M.STATION_KIND = { bar = { { 1.0, 0.6, 0.35 }, { 1.0, 0.45, 0.7 } }, hangar = { { 0.92, 0.96, 1.0 } } }
M.SHAFT_STEP = 12
function M.station_family_lamps(L)
  local ok, fam = pcall(require("sim.stationhull").family, L.family)
  return ok and fam.lamps or M.PALETTES.alien
end
function M.station_lamps(v, L, eye)
  local n = 0
  local fam = M.station_family_lamps(L)
  for ai, a in ipairs(L.areas) do
    local b = a.box
    local sx, sz = b[3] - b[1], b[4] - b[2]
    -- (the wing's lamps are sparser, and only the one nearest each chamber's middle casts shadows)
    local step = a.wing and 15 or 11
    local nx, nz = math.max(1, math.floor(sx / step + 0.5)), math.max(1, math.floor(sz / step + 0.5))
    local h = a.h or 6
    local pal = (a.wing and fam) or M.STATION_KIND[a.kind] or M.PALETTES.trader
    local tall = h > 20
    local y = tall and 6 or (a.wing and math.min(h - 0.5, 7.5) or h - 0.5)
    local lh = tall and 7 or h
    for ix = 0, nx - 1 do
      for iz = 0, nz - 1 do
        local x, z = b[1] + sx * (ix + 0.5) / nx, b[2] + sz * (iz + 0.5) / nz
        local dx, dz = x - eye[1], z - eye[3]
        if dx * dx + dz * dz < 70 * 70 then
          local reach = math.max(lh * 2.4, 14)
          add(v, { kind = "point", pos = { x, y, z }, color = pal[(ai + ix + iz) % #pal + 1],
                   intensity = 1.2 * (reach * 0.45) ^ 2, range = reach,
                   shadow = not a.wing or (ix == (nx - 1) // 2 and iz == (nz - 1) // 2) })
          n = n + 1
        end
      end
    end
    -- up a shaft: lamps on the walls' middles every SHAFT_STEP meters
    if tall then
      local cx, cz = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
      local dx, dz = cx - eye[1], cz - eye[3]
      if dx * dx + dz * dz < 70 * 70 then
        local k = 0
        for yy = 6 + M.SHAFT_STEP, h - 2, M.SHAFT_STEP do
          k = k + 1
          local side = k % 4
          local px = side == 0 and b[1] + 1 or (side == 1 and b[3] - 1 or cx)
          local pz = side == 2 and b[2] + 1 or (side == 3 and b[4] - 1 or cz)
          add(v, { kind = "point", pos = { px, yy, pz }, color = pal[(k + ai) % #pal + 1], intensity = 1.2 * (16 * 0.45) ^ 2 * 1.4,
                   range = 16 * 1.2, shadow = false })
          n = n + 1
        end
      end
    end
  end
  return n
end

-- the light a Watcher's eye throws where it looks (its pool on the floor)
function M.sentry_spot(v, pos, dir, tint, reach, half)
  add(v, { kind = "spot", pos = pos, dir = dir, color = { tint[1], tint[2], tint[3] }, intensity = 0.3 * reach * reach,
           haze = M.HAZE_SENTRY,
           range = reach * 1.15, inner = math.deg(half) * 0.6, outer = math.deg(half) * 1.05 })
end

-- the saucer's own lights, for its drawn pose d (view/render.lua draw_saucer). owner tags the hull meshes,
-- so its own lights pass through it. -> number of lights
M.HEAD = { villa = { x = 3.2, y = -0.6, z = 12.6, intensity = 2600, range = 150 },
           seat = { x = 0.35, y = -0.2, z = 0.95, intensity = 700, range = 70 } }
M.HEAD_INNER, M.HEAD_OUTER, M.HEAD_DIP = 11, 21, 0.1
M.FLOOD = { villa = { y = -7.0, intensity = 1600, range = 115 }, seat = { y = -1.2, intensity = 260, range = 45 } }
M.CABIN_NEAR = 60
M.CABIN_COLORS = { Helm = { 0.82, 0.9, 1.0 }, Holodeck = { 0.7, 0.8, 1.0 }, ["Engine room"] = { 1.0, 0.78, 0.5 },
                   ["Tractor room"] = { 0.6, 1.0, 0.85 } }
M.CABIN_WARM = { 1.0, 0.86, 0.66 }
function M.owner_of(o) return 1000 + o.index end
function M.saucer(v, o, d, at, eye)
  local l = o.lights
  if not l then return 0 end
  local c = configs.get(d.size)
  local n = 0
  local own = M.owner_of(o)
  local hd = M.HEAD[c.id]
  if l.head and hd then
    local pitch = (o.ship.pitch or 0) - M.HEAD_DIP
    local cp = sm.cos(pitch)
    local f = avatar.rot(d.yaw, { 0, sm.sin(pitch), cp })
    for _, side in ipairs({ -1, 1 }) do
      add(v, { kind = "spot", pos = at(d, { hd.x * side, hd.y, hd.z }), dir = f, color = { 1.0, 0.95, 0.86 },
               intensity = hd.intensity * d.scale, range = hd.range, inner = M.HEAD_INNER, outer = M.HEAD_OUTER,
               shadow = true, owner = own, priority = 1.5, haze = M.HAZE_HEAD })
      n = n + 1
    end
  end
  local fl = M.FLOOD[c.id]
  if l.flood and fl then
    add(v, { kind = "point", pos = at(d, { 0, fl.y, 0 }), color = { 0.86, 0.93, 1.0 }, intensity = fl.intensity * d.scale,
             range = fl.range, shadow = true, owner = own, priority = 1.5, haze = M.HAZE_FLOOD })
    n = n + 1
  end
  if l.cabin and c.interior and not o.ship.morph and vec.dist(eye, d.pos) < M.CABIN_NEAR then
    local L = avatar.layout()
    for _, r in ipairs(L.rooms) do
      if r.name ~= "Stairs" then
        local deck = L.decks[r.deck]
        local b = r.box
        local sx, sz = b[3] - b[1], b[4] - b[2]
        local hgt = math.min(deck.ceiling - deck.floor, 3.4)
        local reach = sm.sqrt(sx * sx + sz * sz) * 0.75 + 3
        local y = deck.floor + hgt - 0.35
        add(v, { kind = "point", pos = at(d, { (b[1] + b[3]) / 2, y, (b[2] + b[4]) / 2 }),
                 color = M.CABIN_COLORS[r.name] or M.CABIN_WARM, intensity = 1.2 * (reach * 0.4) ^ 2, range = reach,
                 shadow = true, cabin = true })
        n = n + 1
      end
    end
  end
  return n
end

-- the frame's base: exposure, ambient and (outside) the star. cenv: the city's air (view/render.lua
-- city_env) or nil. -> { inside = site index | "bay" | nil, star }
function M.begin(v, state, p, cam, cenv)
  local star = M.star(state.seed or 0, state.sector_id or 1)
  local site = M.inside_site(state, cam.pos)
  local bay = not site and M.inside_bay(state, cam.pos) or nil
  local inside = site or (bay and "bay") or nil
  if v.lighting then
    v:lighting({ ambient = inside and M.AMBIENT_INSIDE or M.AMBIENT_SPACE, exposure = M.EXPOSURE })
  end
  if not inside then
    local k = 1
    if cenv and cenv.day then k = (cenv.day > 0 and (0.15 + 0.85 * cenv.day) or 1) * (1 - 0.5 * (cenv.storm or 0)) end
    add(v, { kind = "sun", dir = star.dir, color = star.color, intensity = star.intensity * k, shadow = true })
  end
  return { inside = inside, bay = bay, star = star }
end

-- the star itself in the sky (a glow far off along its direction)
function M.sky(v, A, eye, star)
  if not A.tex.glow then return 0 end
  local d = star.dir
  v:billboard(A.tex.glow, { eye[1] + d[1] * 1800, eye[2] + d[2] * 1800, eye[3] + d[3] * 1800 }, 260,
              { palette = A.pal.base, tint = { star.color[1], star.color[2], star.color[3], 0.85 }, sky = true })
  v:billboard(A.tex.glow, { eye[1] + d[1] * 1800, eye[2] + d[2] * 1800, eye[3] + d[3] * 1800 }, 90,
              { palette = A.pal.base, tint = { 1, 1, 1, 1 }, sky = true })
  return 2
end

-- add-design-language §2.5: a relic lamp's light model in motion (render only, a function of the clock):
-- ripple (echo) sweeps along the lamps like sonar, orbit (tidal) circles its post, arc (field) flickers
M.ORBIT = 6.0 -- m: an orbiting lamp's circle
function M.animate(l, t, k)
  local ph = l.phase or 0
  if l.model == "ripple" then
    local s = math.max(0, math.sin(t * 1.6 - ph * 0.7))
    return k * (0.15 + 0.85 * s * s * s * s), l.pos
  elseif l.model == "orbit" then
    local a = t * 0.35 + ph
    return k, { l.pos[1] + M.ORBIT * math.cos(a), l.pos[2] + 1.5 * math.sin(a * 0.5), l.pos[3] + M.ORBIT * math.sin(a) }
  elseif l.model == "arc" then
    return k * (((math.floor(t * 11) * 7 + ph * 13) % 5 == 0) and 0.35 or 1.0), l.pos
  end
  return k, l.pos
end

-- every site's lamps near the eye (a city's dark districts stay dark until their grid is back)
M.GLOW_NEAR = 120 -- lamps nearer than this also show their glow (the light has a visible source)
function M.site_lamps(v, A, state, eye)
  local cities = require("sim.cities")
  local glow = A and A.tex.glow
  local n = 0
  for i, site in ipairs(state.sector.sites) do
    local r = game.ruin(i)
    if r then
      local c = M.room_lamps(r, site.pos, i)
      for _, l in ipairs(M.near(c, eye, M.NEAR)) do
        local k = 1
        if r.city and l.district then k = cities.light(state, i, r, l.district) end
        if k > 0 then
          local kk = r.city and (0.15 + 0.85 * k) or 1
          local pos = l.pos
          if l.model and l.model ~= "chromatic" then kk, pos = M.animate(l, (state.tick or 0) / 60, kk) end
          add(v, { kind = "point", pos = pos, color = l.color, intensity = l.intensity * kk, range = l.range,
                   shadow = not l.fixture })
          n = n + 1
          if glow and vec.dist(l.pos, eye) < M.GLOW_NEAR then
            v:billboard(glow, l.pos, l.fixture and 1.4 or 2.6, { palette = A.pal.base,
                        tint = { l.color[1], l.color[2], l.color[3], 0.8 * kk } })
          end
        end
      end
    end
  end
  return n
end

-- the hangar bays near the eye
function M.bays(v, state, eye, tick)
  local dock = require("sim.dock")
  local n = 0
  for i = 1, dock.count(state) do
    local b = dock.bay(state, i)
    local c = { (b.lo[1] + b.hi[1]) / 2, (b.lo[2] + b.hi[2]) / 2, (b.lo[3] + b.hi[3]) / 2 }
    if vec.dist(c, eye) < 260 then n = n + M.bay_lamps(v, b, tick) end
  end
  return n
end

return M
