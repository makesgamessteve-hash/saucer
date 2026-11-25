-- SPDX-License-Identifier: MIT
-- Per-viewport rendering. Gets a read-only state; must not mutate it.
-- The camera is the player's own eyes: on foot under the dome, or seated at
-- the helm with the interior around them. A chase view is a toggle away.
local assets = require("view.assets")
local kit = require("lib.meshkit")
local hud = require("view.hud")
local configs = require("sim.config")
local vec = require("lib.vec")
local game = require("sim.game")
local tractor = require("sim.tractor")
local shipm = require("sim.ship")
local avatar = require("sim.avatar")
local fold = require("sim.fold")
local panelm = require("sim.panel")
local sm = saucer.math
local ruinm = require("sim.ruin")
local megav = require("view.citymega") -- add-alien-cities-2
local cities = require("sim.cities")
local M = {}

-- add-presentation-packaging: sounds live in view/audio.lua (kept here for mods)
local sound = require("view.audio")
local xrv = require("view.xr")
local lightsv = require("view.lights")
M.SOUNDS = sound.SOUNDS

-- milestone 3: sentry state lights (Dormant green, Alert yellow, Locked red,
-- Disabled blue), Watcher cones while a Scanner pulse lasts, stun bolts,
-- Snatcher nests and the Resonant vault once Echo II reveals it
M.STATE_TINT = {
  dormant = { 0.3, 0.9, 0.5, 0.7 }, alert = { 1, 0.85, 0.2, 0.95 }, locked = { 1, 0.25, 0.2, 1 },
  latched = { 1, 0.25, 0.2, 1 }, flee = { 1, 0.55, 0.2, 0.9 }, disabled = { 0.35, 0.5, 1, 0.8 },
  -- add-wider-dark
  chase = { 1, 0.55, 0.15, 1 }, clamped = { 1, 0.2, 0.2, 1 }, sealed = { 1, 0.2, 0.2, 1 }, rest = { 0.6, 0.6, 0.7, 0.8 },
  off = { 0.25, 0.25, 0.3, 0.5 }, decoyed = { 0.4, 0.9, 1, 0.9 },
  patrol = { 0.9, 0.85, 0.3, 0.9 }, hunt = { 1, 0.15, 0.1, 1 },
}

-- add-strategic-sentries: a turret's pool of light on its hall's floor: where the lower half of
-- its cone meets the floor (5 x 2 glow points), so its sweep reads from anywhere in the hall
M.CONE_YAWS = { -0.8, -0.4, 0, 0.4, 0.8 }
M.CONE_PITCHES = { 1.0, 0.5 }
function M.floor_cone(v, A, def, dyn, wpos, pitch, t, tint)
  local sentry = require("sim.sentry")
  local half = t.watcher.half_angle
  local reach = def.light and t.watcher.light.range or t.watcher.range
  local n = 0
  local col = { tint[1], tint[2], tint[3], 0.35 }
  for _, ky in ipairs(M.CONE_YAWS) do
    for _, kp in ipairs(M.CONE_PITCHES) do
      local d = sentry.dir_of(dyn.yaw + ky * half, pitch - kp * half)
      if d[2] < -0.05 then
        local k = (def.floor + 0.3 - wpos[2]) / d[2]
        if k > 0 and k <= reach then
          v:billboard(A.tex.glow or A.tex.beam, vec.add(wpos, vec.scale(d, k)), 3.0, { palette = A.pal.base, tint = col })
          n = n + 1
        end
      end
    end
  end
  return n
end

M.SENTRY_LIGHT_DIST = 140 -- add-realistic-lighting: a Watcher nearer than this lights the floor for real
M.SENTRY_DIST = 700 -- add-cities-2 slice 5: a sentry farther than this from the eye is not drawn (a city holds hundreds)
function M.draw_sentries(v, A, state, p)
  local sentry = require("sim.sentry")
  local eye = p.ship.pos
  local scanned = (p.scan_until or 0) > state.tick
  local t = sentry.tune()
  for site, list in pairs(state.sentries or {}) do
    for i, def in ipairs(game.sentries(site)) do
      local dyn = list[i]
      local at = dyn and (dyn.pos or def.pos)
      if dyn and vec.dist(at, eye) <= M.SENTRY_DIST then
        local tint = M.STATE_TINT[dyn.st] or M.STATE_TINT.dormant
        local show = scanned and p.site == site
        if def.kind == "watcher" and def.roam and (state.locks or {})[site .. ":power" .. tostring(def.district)] then
          -- add-cities-2: a patrol is gone once its district's grid is back
        elseif def.kind == "watcher" then
          -- add-mesh-builder: the base hangs still, the head turns to dyn.yaw and the eye tilts to its pitch
          local pitch = dyn.pitch or def.pitch
          local wpos, byaw = dyn.pos or def.pos, dyn.base or def.yaw
          kit.draw(v, assets.rig(A, "watcher", {}, def.glyph or 1), { pos = wpos, yaw = byaw },
                   { head = { yaw = dyn.yaw - byaw }, eye = { pitch = pitch } })
          local f = sentry.dir_of(dyn.yaw, pitch)
          v:billboard(A.tex.beam, vec.add(wpos, vec.scale(f, 1.9)), 1.0, { palette = A.pal.base, tint = tint })
          -- add-strategic-sentries: the light it throws on the floor (where it is looking now)
          if p.site == site and def.floor and dyn.st ~= "off" and dyn.st ~= "disabled" then
            M.floor_cone(v, A, def, dyn, wpos, pitch, t, tint)
            -- add-realistic-lighting: and the eye is a real spotlight (the near ones)
            if vec.dist(wpos, eye) < M.SENTRY_LIGHT_DIST then
              lightsv.sentry_spot(v, vec.add(wpos, vec.scale(f, 2.0)), f, tint,
                                  def.light and t.watcher.light.range or t.watcher.range, t.watcher.half_angle)
            end
          end
          if show and def.cell and dyn.st ~= "off" then
            v:billboard(A.tex.glow or A.tex.beam, def.cell, 1.6, { palette = A.pal.base, tint = { 0.3, 1, 0.9, 0.9 } })
          end
          if show then
            for _, da in ipairs({ -t.watcher.half_angle, 0, t.watcher.half_angle }) do
              local d = sentry.dir_of(dyn.yaw + da, pitch)
              for k = 1, 12 do
                v:billboard(A.tex.beam, vec.add(wpos, vec.scale(d, k * t.watcher.range / 12)), 0.7,
                  { palette = A.pal.base, tint = { tint[1], tint[2], tint[3], 0.45 } })
              end
            end
          end
        elseif def.kind == "spotter" then
          -- add-strategic-sentries: the Spotter drone, its eye light the colour of its state
          local pos = dyn.pos or def.pos
          v:mesh(A.decoy, { pos = pos, yaw = dyn.yaw or 0, scale = 3 })
          local f = sentry.dir_of(dyn.yaw or 0, dyn.pitch or -0.35)
          v:billboard(A.tex.glow or A.tex.beam, vec.add(pos, vec.scale(f, 0.8)), show and 2.0 or 1.2,
            { palette = A.pal.base, tint = dyn.st == "dormant" and { 0.35, 0.6, 1, 0.9 } or tint })
          if show and t.stealth then
            local S = t.stealth.spotter
            for _, da in ipairs({ -S.half_angle, 0, S.half_angle }) do
              local d = sentry.dir_of((dyn.yaw or 0) + da, dyn.pitch or -0.35)
              for k = 1, 8 do
                v:billboard(A.tex.beam, vec.add(pos, vec.scale(d, k * S.range / 8)), 0.6,
                  { palette = A.pal.base, tint = { 0.35, 0.6, 1, 0.4 } })
              end
            end
          end
        elseif def.kind == "clamp" then
          -- add-wider-dark: the Clamp, its claws spinning up when it gives chase
          local pos = dyn.pos or def.pos
          local spin = (dyn.st == "chase" or dyn.st == "clamped") and state.tick * 0.2 or state.tick * 0.02
          v:mesh(A.clamp, { pos = pos, yaw = spin })
          v:billboard(A.tex.beam, { pos[1], pos[2] + 1.6, pos[3] }, show and 1.6 or 0.8,
            { palette = A.pal.base, tint = tint })
        elseif def.kind == "warden" then
          -- add-home-among-stars: the Warden, its eye ring turning fast when it hunts
          local pos = dyn.pos or def.pos
          local spin = dyn.st == "hunt" and state.tick * 0.15 or state.tick * 0.015
          v:mesh(A.warden, { pos = pos, yaw = spin })
          v:billboard(A.tex.beam, { pos[1], pos[2] + 2.6, pos[3] }, show and 2.2 or 1.2,
            { palette = A.pal.base, tint = tint })
        elseif def.kind == "lockdown" then
          v:mesh(A.lockdown, { pos = def.pos, yaw = state.tick * 0.01 })
          v:billboard(A.tex.beam, { def.pos[1], def.pos[2] + 1.1, def.pos[3] }, show and 1.4 or 0.7,
            { palette = A.pal.base, tint = tint })
          -- sealed doors: a glowing slab across each
          for _, bi in ipairs(dyn.sealed or {}) do
            local b = def.boxes[bi]
            if b then v:mesh(A.seal, { pos = b[1], scale = vec.sub(b[2], b[1]), ghost = true }) end
          end
        else
          local pos = dyn.pos or def.pos
          -- the pincers open while it hunts, the sensor stalk sweeps
          local hunting = dyn.st == "chase" or dyn.st == "latched" or dyn.st == "hunt"
          kit.draw(v, assets.rig(A, "snatcher", {}, def.glyph or 1), { pos = pos, yaw = state.tick * 0.05 },
                   { claws = { pitch = hunting and -0.45 or 0 }, eye = { yaw = sm.sin(state.tick * 0.1) * 0.7 } })
          v:billboard(A.tex.beam, { pos[1], pos[2] + 0.55, pos[3] }, show and 1.4 or 0.5,
            { palette = A.pal.base, tint = tint })
          if def.nest then v:mesh(A.nest, { pos = def.nest }) end
        end
      end
    end
  end
  for _, b in ipairs(state.bolts or {}) do
    v:billboard(A.tex.beam, b.pos, 0.9, { palette = A.pal.base, tint = { 0.5, 0.8, 1, 1 } })
  end
  -- add-strategic-sentries: a Scanner pulse marks the guarded finds (amber, pulsing)
  if (p.scan_until or 0) > state.tick and (p.site or 0) ~= 0 then
    for _, s in ipairs(require("sim.stealth").guarded(game.ruin(p.site), p, p.site)) do
      local k = 1 + 0.3 * math.sin(state.tick * 0.2)
      v:billboard(A.tex.glow or A.tex.beam, { s.pos[1], s.pos[2] + 2, s.pos[3] }, 2.4 * k,
        { palette = A.pal.base, tint = { 1, 0.7, 0.2, 0.9 } })
    end
  end
  -- add-wider-dark: thrown decoys blink, gifts tumble, the Heart's core beats
  for _, d in ipairs(state.decoys or {}) do
    v:mesh(A.decoy, { pos = d.pos, yaw = state.tick * 0.15 })
    if state.tick % 20 < 10 then
      v:billboard(A.tex.glow or A.tex.beam, d.pos, 2.2, { palette = A.pal.base, tint = { 0.4, 0.9, 1, 0.8 } })
    end
  end
  for _, gft in ipairs(state.gifts or {}) do
    v:mesh(A.gift, { pos = gft.pos, yaw = state.tick * 0.03, pitch = 0.3 })
    if gft.to == 0 or gft.to == p.index then
      v:billboard(A.tex.glow or A.tex.beam, gft.pos, 2.0, { palette = A.pal.base, tint = { 1, 0.6, 0.85, 0.7 } })
    end
  end
  local heart = require("sim.heart")
  local hm = state.mystery
  if hm and hm.heart_sector and (state.sector_id or 1) == hm.heart_sector then
    local core = heart.core(state)
    if core then
      local beat = 1 + 0.12 * math.sin(state.tick * (hm.heart_open and 0.25 or 0.08))
      v:mesh(A.heart_core, { pos = core, yaw = state.tick * 0.01, scale = beat })
      v:billboard(A.tex.glow or A.tex.beam, core, hm.heart_open and 10 or 6,
        { palette = A.pal.base, tint = hm.ending and { 0.6, 1, 0.8, 0.8 } or { 1, 0.4, 0.6, 0.8 } })
    end
  end
  local m = state.mystery
  if m and m.vault_revealed and state.vault then
    v:mesh(m.vault_open and A.vault_open or A.vault, { pos = state.vault.pos, yaw = 0.4 })
  end
end

function M.camera(p, xr)
  local ship = p.ship
  -- add-on-foot-excursions: the chase view on foot hangs behind your shoulder
  if p.cam == "chase" and not xr and p.mode == "foot" and p.excursion then return require("view.excursion").chase(p) end
  if p.cam == "chase" and not xr then
    local c = configs.get(ship.size)
    local R, H = c.diameter / 2, c.height
    local f = vec.fwd(ship.yaw)
    local back = R * 2.2 + 6
    if p.beam_console or p.tractor then
      -- watching the beam: hang back at belly height and look down past the hull
      return { pos = { ship.pos[1] - f[1] * back, ship.pos[2] + 1, ship.pos[3] - f[3] * back },
               yaw = ship.yaw, pitch = -0.3, fov = 70, near = 0.1, far = 4000 }
    end
    return { pos = { ship.pos[1] - f[1] * back, ship.pos[2] + H * 1.2 + 3, ship.pos[3] - f[3] * back },
             yaw = ship.yaw, pitch = ship.pitch - 0.22, fov = 70, near = 0.1, far = 4000 }
  end
  local eye, yaw, pitch = game.viewpoint(p)
  local roll = M.bank_of(ship, xr)
  if roll ~= 0 then
    -- the interior is locked to the saucer frame: the eye leans with the bank
    local rel = avatar.rot(-ship.yaw, vec.sub(eye, ship.pos))
    eye = vec.add(ship.pos, M.rot3(ship.yaw, roll, rel))
  end
  return { pos = eye, yaw = yaw, pitch = pitch, roll = roll, fov = 75, near = 0.05, far = 4000 }
end

-- the bank (roll) a saucer is drawn with. Never in XR (the headset owns the
-- horizon) and never mid-fold (the pose there is about the pilot's eye).
function M.bank_of(ship, xr)
  if xr or ship.morph then return 0 end
  return ship.bank or 0
end

-- hull-local -> world rotation: roll about the hull's forward axis, then yaw
function M.rot3(yaw, roll, v)
  if roll == 0 then return avatar.rot(yaw, v) end
  local c, s = sm.cos(roll), sm.sin(roll)
  return avatar.rot(yaw, { v[1] * c - v[2] * s, v[1] * s + v[2] * c, v[3] })
end

-- Where to draw a saucer this frame. A fold to the Seat happens in two
-- beats (milestone 2): first the rooms pack away one by one while the hull
-- holds its size (sim/fold.lua), then the hull shrinks about the player's eye.
-- Unfolding plays it backwards: the hull grows first, then the rooms unpack.
-- -> { size, pos, yaw, scale, fold, ipos, iscale, ht }
local function hull_t(ship, t)
  local m = ship.morph
  local a, b = configs.get(m.from).interior, configs.get(ship.size).interior
  if a and not b then return math.max(0, (t - fold.ROOM_PHASE) / (1 - fold.ROOM_PHASE)) end
  if b and not a then return math.min(1, t / fold.ROOM_PHASE) end
  return t
end
M.hull_t = hull_t

function M.pose(ship, xr)
  if not ship.morph then
    return { size = ship.size, pos = ship.pos, yaw = ship.yaw, roll = M.bank_of(ship, xr), scale = 1, fold = 1,
             ipos = ship.pos, iscale = 1, ht = 1 }
  end
  local m = ship.morph
  local t = hull_t(ship, shipm.progress(ship))
  local da, db = configs.get(m.from).diameter, configs.get(ship.size).diameter
  local d = da + (db - da) * t
  local size, base, base_yaw, k
  if t < 0.5 then size, base, base_yaw, k = m.from, m.pos, m.yaw, d / da
  else size, base, base_yaw, k = ship.size, ship.pos, ship.yaw, d / db end
  local yaw = m.yaw + sm.wrap(ship.yaw - m.yaw) * t
  local shrinking = ship.size > m.from
  local f = shrinking and math.max(0, 1 - 2 * t) or math.max(0, 2 * t - 1)
  local e = m.eye
  local rel = avatar.rot(yaw - base_yaw, vec.sub(base, e))
  return {
    size = size, yaw = yaw, roll = 0, scale = k, fold = f, ht = t,
    pos = vec.add(e, vec.scale(rel, k)),
    ipos = vec.add(e, vec.scale(rel, k * f)), iscale = k * f,
  }
end

-- kept for mods: visual hull scale relative to the drawn config
function M.morph_scale(ship) return M.pose(ship).scale end

function M.audio(state, p, first)
  local n = sound.update(state, p, first ~= false and p.index == 1)
  -- add-wider-dark: the civilizations' music (the first player's view leads)
  if first ~= false and p.index == 1 then n = n + require("view.music").update(state, p) end
  return n
end

-- hull-local point -> world, for a drawn pose
local function at(d, lp)
  local w = M.rot3(d.yaw, d.roll or 0, { lp[1] * d.scale, lp[2] * d.scale, lp[3] * d.scale })
  return { d.pos[1] + w[1], d.pos[2] + w[2], d.pos[3] + w[3] }
end
M.at = at

-- a glowing block on a console: hull-local centre and size
local function blip(v, A, d, lp, size, color)
  v:mesh(A.unit, { pos = at(d, lp), yaw = d.yaw, roll = d.roll, scale = { size[1] * d.scale, size[2] * d.scale, size[3] * d.scale },
                   tint = color })
end
M.blip = blip

M.RADAR_RANGE = 2400
M.RADAR_RADIUS = 0.42   -- disc radius on the desk (m)
M.RADAR_LIFT = 0.20     -- the disc floats this high over the desk
M.RADAR_HEIGHT = 0.20   -- stalks reach at most this far above/below the disc

-- a contact's spot on the 3D radar (desk-local offsets from the disc centre):
-- x/z by bearing and range, y by elevation, exaggerated x4 so a few hundred
-- meters above or below you still reads at a glance
function M.radar_point(ship, pos, range)
  local rel = avatar.rot(-ship.yaw, vec.sub(pos, ship.pos))
  local k = M.RADAR_RADIUS / (range or M.RADAR_RANGE)
  local x, z = rel[1] * k, rel[3] * k
  local r = sm.sqrt(x * x + z * z)
  if r > M.RADAR_RADIUS then x, z = x * M.RADAR_RADIUS / r, z * M.RADAR_RADIUS / r end
  local y = vec.clamp(rel[2] * k * 4, -M.RADAR_HEIGHT, M.RADAR_HEIGHT)
  return { x, y, z }
end
-- radar targets for a player: { pos, color }
function M.radar_targets(state, p)
  local out = {}
  for _, s in ipairs(state.sector.sites) do
    out[#out + 1] = { pos = hud.site_center(state, s), color = s.id == p.site and { 1, 0.75, 0.3, 1 } or { 0.9, 0.95, 1, 1 } }
  end
  for _, tr in ipairs(state.sector.traders or { state.sector.trader }) do
    out[#out + 1] = { pos = tr.pos, color = { 0.35, 1, 0.45, 1 } }
  end
  for _, t in ipairs(M.extra_radar) do
    for _, x in ipairs(t(state, p)) do out[#out + 1] = x end
  end
  return out
end
M.extra_radar = {} -- functions(state, p) -> list of { pos, color }

-- milestone 3: Resonant sites and the vault (violet), your caches (orange),
-- and sentries while a Scanner pulse lasts (coloured by state)
local VIOLET, ORANGE = { 0.8, 0.5, 1, 1 }, { 1, 0.6, 0.2, 1 }
M.extra_radar[#M.extra_radar + 1] = function(state, p)
  local out = {}
  local mystery = require("sim.mystery")
  local m = state.mystery
  if m then
    for _, i in ipairs(mystery.resonant_sites(m)) do
      local s = state.sector.sites[i]
      if s then
        local c = hud.site_center(state, s)
        out[#out + 1] = { pos = { c[1], c[2] + 30, c[3] }, color = VIOLET }
      end
    end
    if m.vault_revealed and state.vault then out[#out + 1] = { pos = state.vault.pos, color = VIOLET } end
  end
  for _, c in ipairs(state.caches or {}) do
    if c.owner == p.record_index then out[#out + 1] = { pos = c.pos, color = ORANGE } end
  end
  if (p.scan_until or 0) > state.tick then
    for site, list in pairs(state.sentries or {}) do
      for i, def in ipairs(game.sentries(site)) do
        local dyn = list[i]
        if dyn then out[#out + 1] = { pos = dyn.pos or def.pos, color = M.STATE_TINT[dyn.st] or M.STATE_TINT.dormant } end
      end
    end
  end
  return out
end

-- add-holodeck-home-life: leads from clues (books, holodeck memories), teal
local TEAL = { 0.3, 1, 0.85, 1 }
M.extra_radar[#M.extra_radar + 1] = function(state, p)
  local out = {}
  for _, k in ipairs(saucer.util.sorted_keys(p.leads or {})) do
    local s = state.sector.sites[tonumber(k)]
    if s then
      local c = hud.site_center(state, s)
      out[#out + 1] = { pos = { c[1], c[2] - 30, c[3] }, color = TEAL }
    end
  end
  return out
end

-- add-holodeck-home-life: the TV picture (a test card while off, a channel's
-- colours and moving shapes while someone watches), a steaming pot on the
-- stove while cooking, and a holo shimmer in the arch while a program runs.
-- Render-only. -> number of draws
-- add-home-among-stars: the owner's furniture, displayed finds and garden,
-- drawn in their dome (guests from docked saucers see the same). Meshes are
-- built once per kind. Render-only. -> number of draws
local decor_meshes = {}
local function decor_mesh(key, recipe)
  local m = decor_meshes[key]
  if not m then
    m = saucer.mesh.build(recipe())
    decor_meshes[key] = m
  end
  return m
end
M.CATEGORY_TINT = { curio = { 1, 0.75, 0.3, 1 }, tool = { 0.4, 0.9, 1, 1 }, material = { 0.7, 0.75, 0.8, 1 },
                    module = { 0.5, 1, 0.6, 1 } }
function M.decor(v, A, o, d, state)
  local D = o.decor
  if not D then return 0 end
  local decor = require("sim.decor")
  local fm = require("lib.data").load("meshes/furniture.lua")
  local L = avatar.layout()
  local n = 0
  for _, pc in ipairs(D.placed) do
    local def = decor.furniture(pc.kind)
    if def then
      local m = decor_mesh("f:" .. pc.kind, function() return fm.furniture(def) end)
      v:mesh(m, { pos = at(d, { pc.x, L.decks[pc.deck].floor, pc.z }), yaw = d.yaw + pc.q * math.pi / 2, roll = d.roll,
                  scale = d.scale })
      n = n + 1
    end
  end
  for slot, it in pairs(D.display) do
    local s = L.display[slot]
    if it and s then
      local m = decor_mesh("trophy", fm.trophy)
      v:mesh(m, { pos = at(d, { s.at[1], L.decks[1].floor + s.top, s.at[2] }), yaw = d.yaw + (state and state.tick or 0) * 0.01,
                  roll = d.roll, scale = d.scale * (0.8 + 0.2 * (it.size or 1)), tint = M.CATEGORY_TINT[it.category] or { 1, 1, 1, 1 } })
      n = n + 1
    end
  end
  for i, bed in pairs(D.garden) do
    local b = L.garden[i] and L.garden[i].box
    local seed = bed and decor.seed(bed.seed)
    if b and seed then
      local st = decor.stage(state, bed)
      local m = decor_mesh("p:" .. bed.seed .. st, function() return fm.plant(seed, st) end)
      v:mesh(m, { pos = at(d, { (b[1] + b[3]) / 2, L.decks[1].floor + 0.52, (b[2] + b[4]) / 2 }), yaw = d.yaw, roll = d.roll,
                  scale = d.scale })
      n = n + 1
    end
  end
  return n
end

M.TV_COLORS = { trader_wave = { 0.3, 0.8, 1.0 }, static_noir = { 0.75, 0.75, 0.8 }, sky_garden = { 0.5, 1.0, 0.5 } }
function M.home_parts(v, A, o, d, tick)
  local L = avatar.layout()
  local n = 0
  local T = L.tv
  if T then
    local col = { 0.08, 0.1, 0.14 }
    if o.tv then col = M.TV_COLORS[o.tv.ch] or { 0.9, 0.6, 0.3 } end
    local c = T.screen
    local k = o.tv and 1 or 0.35
    v:mesh(A.unit, { pos = at(d, { c[1] - 0.06, c[2], c[3] }), yaw = d.yaw, roll = d.roll,
                     scale = { 0.01 * d.scale, T.h * d.scale, T.w * d.scale }, tint = { col[1] * k, col[2] * k, col[3] * k, 1 } })
    n = n + 1
    if o.tv then
      -- a few drifting shapes: a horizon bar, a sun, a scrolling ticker
      local t = (tick % 600) / 600
      v:mesh(A.unit, { pos = at(d, { c[1] - 0.07, c[2] - T.h * 0.12, c[3] }), yaw = d.yaw, roll = d.roll,
                       scale = { 0.01 * d.scale, T.h * 0.3 * d.scale, T.w * 0.96 * d.scale },
                       tint = { col[1] * 0.45, col[2] * 0.45, col[3] * 0.45, 1 } })
      v:mesh(A.unit, { pos = at(d, { c[1] - 0.075, c[2] + T.h * 0.2, c[3] + T.w * (0.35 - 0.7 * t) }), yaw = d.yaw,
                       roll = d.roll, scale = { 0.01 * d.scale, T.h * 0.22 * d.scale, T.h * 0.22 * d.scale },
                       tint = { 1, 0.9, 0.6, 1 } })
      v:mesh(A.unit, { pos = at(d, { c[1] - 0.075, c[2] - T.h * 0.42, c[3] }), yaw = d.yaw, roll = d.roll,
                       scale = { 0.01 * d.scale, T.h * 0.08 * d.scale, T.w * 0.96 * d.scale }, tint = { 0.05, 0.05, 0.08, 1 } })
      for j = 0, 4 do
        local z = c[3] + T.w * (0.45 - ((t * 2 + j * 0.2) % 1) * 0.9)
        v:mesh(A.unit, { pos = at(d, { c[1] - 0.08, c[2] - T.h * 0.42, z }), yaw = d.yaw, roll = d.roll,
                         scale = { 0.01 * d.scale, T.h * 0.03 * d.scale, T.w * 0.1 * d.scale }, tint = { 1, 1, 1, 1 } })
      end
      n = n + 5
    end
  end
  -- add-run-story: a small hologram turns over the holotable
  local H = L.holotable
  if H then
    local pulse = 0.7 + 0.3 * sm.sin(tick * 0.04)
    local y = L.decks[1].floor + H.y
    v:billboard(A.tex.glow, at(d, { H.x, y, H.z }), 1.1 * d.scale, { palette = A.pal.base, tint = { 0.4, 0.9, 1.0, 0.5 * pulse } })
    v:mesh(A.unit, { pos = at(d, { H.x, y, H.z }), yaw = d.yaw + tick * 0.03, roll = d.roll,
                     scale = { 0.22 * d.scale, 0.32 * d.scale, 0.22 * d.scale }, tint = { 0.5, 1.0, 1.0, 1 } })
    n = n + 2
  end
  local S = L.stove
  if S and o.cooking then
    local pot = S.pot
    v:mesh(A.unit, { pos = at(d, { pot[1], pot[2] + 0.12, pot[3] }), yaw = d.yaw, roll = d.roll,
                     scale = { 0.34 * d.scale, 0.24 * d.scale, 0.34 * d.scale }, tint = { 0.55, 0.57, 0.62, 1 } })
    for j = 0, 5 do
      local f = ((tick + j * 17) % 90) / 90
      v:billboard(A.tex.glow, at(d, { pot[1] + 0.08 * sm.sin(j * 1.7 + f * 4), pot[2] + 0.3 + f * 0.9,
                                       pot[3] + 0.08 * sm.cos(j * 2.3) }), (0.18 + f * 0.35) * d.scale,
                  { palette = A.pal.base, tint = { 1, 1, 1, 0.55 * (1 - f) } })
    end
    n = n + 7
  end
  local H = L.holodeck
  if H and o.holo_run then
    local y = L.decks[2].floor
    v:mesh(A.unit, { pos = at(d, { H.x, y + 1.2, (H.z0 + H.z1) / 2 }), yaw = d.yaw, roll = d.roll,
                     scale = { 0.02 * d.scale, 2.3 * d.scale, (H.z1 - H.z0) * d.scale }, ghost = true,
                     tint = { 1, 0.8, 0.3, 0.35 + 0.15 * sm.sin(tick * 0.1) } })
    n = n + 1
  end
  return n
end

-- live helm readouts (milestone 2): a radar on the desk, Charge/hull/shield
-- bars on the left wing screen, hold slots and the size ladder on the right
function M.console(v, A, state, o, d)
  local L = avatar.layout()
  local ship = o.ship
  local all = configs.all()
  local desk, lw, rw
  for _, f in ipairs(L.furniture) do
    if f.kind == "helm_desk" then desk = f end
    if f.kind == "helm_wing" and f.side < 0 then lw = f end
    if f.kind == "helm_wing" and f.side > 0 then rw = f end
  end
  if not desk then return 0 end
  local fl = L.decks[1].floor
  local cx, cz = (desk.box[1] + desk.box[3]) / 2, (desk.box[2] + desk.box[4]) / 2
  local top = fl + desk.h + 0.02
  local n = 0
  -- true 3D radar: a holographic disc floating over the desk. Each contact
  -- sits on a stalk above or below the disc by its (exaggerated) elevation.
  local base = top + M.RADAR_LIFT
  blip(v, A, d, { cx, base, cz }, { 0.03, 0.02, 0.03 }, { 1, 1, 1, 1 })
  for k = 0, 15 do
    local a = k * sm.tau / 16
    blip(v, A, d, { cx + sm.sin(a) * (M.RADAR_RADIUS + 0.01), base, cz + sm.cos(a) * (M.RADAR_RADIUS + 0.01) }, { 0.012, 0.004, 0.012 }, { 0.3, 0.6, 0.8, 1 })
  end
  -- add-civ-dungeons: inside a relic the radar closes in and outlines the rooms the saucer has been in
  local relicmap = require("view.relicmap")
  local ruin, here, rsite = relicmap.inside(state, o)
  local range = ruin and relicmap.RANGE or nil
  if ruin then
    relicmap.note(ruin, here)
    local remembered = rsite and require("sim.relic").rooms_seen(state, rsite) or nil
    for _, dot in ipairs(relicmap.dots(ruin, here, ship.pos, remembered)) do
      local q = M.radar_point(ship, dot.pos, range)
      blip(v, A, d, { cx + q[1], base + q[2], cz + q[3] }, { 0.012, 0.006, 0.012 }, dot.color)
      n = n + 1
    end
  end
  for _, tg in ipairs(M.radar_targets(state, o)) do
    local q = M.radar_point(ship, tg.pos, range)
    blip(v, A, d, { cx + q[1], base + q[2], cz + q[3] }, { 0.07, 0.05, 0.07 }, tg.color)
    local h = math.abs(q[2])
    if h > 0.004 then
      blip(v, A, d, { cx + q[1], base + q[2] / 2, cz + q[3] }, { 0.016, h, 0.016 },
        { tg.color[1] * 0.6, tg.color[2] * 0.6, tg.color[3] * 0.6, 1 })
    end
    n = n + 1
  end
  local function wing_face(w)
    return w.side < 0 and w.box[3] + 0.02 or w.box[1] - 0.02
  end
  if lw then
    local x = wing_face(lw)
    local y0, y1 = fl + lw.h * 0.6, fl + lw.h * 0.95
    local vals = {
      { ship.charge / require("sim.ship").max_charge(ship), { 0.4, 0.9, 1, 1 } },
      { (ship.hull or 100) / 100, { 0.4, 1, 0.5, 1 } },
      { (ship.shield or 100) / 100, { 0.5, 0.6, 1, 1 } },
    }
    for i, bar in ipairs(vals) do
      local z = lw.box[2] + 0.15 + (i - 1) * 0.28
      local h = math.max(0.01, (y1 - y0) * vec.clamp(bar[1], 0, 1))
      blip(v, A, d, { x, y0 + h / 2, z }, { 0.012, h, 0.16 }, bar[1] < 0.3 and { 1, 0.35, 0.3, 1 } or bar[2])
      n = n + 1
    end
  end
  if rw then
    local x = wing_face(rw)
    local y0 = fl + rw.h * 0.62
    for i = 1, require("sim.upgrades").hold_slots(o) do
      local it = o.hold[i]
      local col = { 0.12, 0.14, 0.18, 1 }
      if it then col = it.hot and { 1, 0.7, 0.25, 1 } or { 0.4, 1, 0.5, 1 } end
      local row, colm = (i - 1) // 4, (i - 1) % 4
      blip(v, A, d, { x, y0 + row * 0.07, rw.box[2] + 0.2 + colm * 0.16 }, { 0.012, 0.05, 0.1 }, col)
      n = n + 1
    end
    for i = 1, configs.count() do
      local on = i == ship.size
      blip(v, A, d, { x, y0 + 0.24, rw.box[2] + 0.2 + (i - 1) * 0.16 }, { 0.012, 0.04, 0.12 },
           on and { 0.4, 1, 0.5, 1 } or { 0.2, 0.22, 0.28, 1 })
    end
  end
  return n
end

-- add-tractor-beam ---------------------------------------------------------
-- The belly beam: a see-through cone from the emitter down the hull's (banked)
-- down axis, brighter while it pulls, with motes rising up it; the target
-- marked by a ring (green = lock), long scrap with its axis and the keel line;
-- the item itself rising and shrinking into the hatch; the hatch iris; and
-- the Tractor Room's live readouts. All render-side, read from the sim state.
M.BEAM_TINT = {
  idle = { 0.4, 0.85, 1, 0.08 }, lock = { 0.4, 1, 0.6, 0.18 }, pull = { 0.55, 1, 0.9, 0.28 },
  core = { 0.85, 1, 1, 0.3 }, mote = { 0.6, 1, 0.9, 0.85 },
}
M.STATUS_TINT = {
  lock = { 0.4, 1, 0.5, 1 }, big = { 1, 0.3, 0.25, 1 }, blocked = { 1, 0.3, 0.25, 1 },
}
function M.status_tint(st) return M.STATUS_TINT[st] or { 1, 0.75, 0.25, 1 } end

-- does this player watch their beam right now (beam console, or in the Seat)?
function M.beam_view(p)
  if p.beam_console then return true end
  return p.mode == "helm" and not tractor.beam_of(p.ship).console
end

-- the heading a player reads the beam in (the console faces inward)
function M.beam_heading(p)
  local _, yaw = game.viewpoint(p)
  return yaw
end

local function tan(a) return sm.sin(a) / sm.cos(a) end

-- the cone (and, while pulling, its core and rising motes) -> meshes + sprites drawn
function M.draw_beam(v, A, o, scan, tick)
  local ship = o.ship
  if ship.morph then return 0 end
  local b = tractor.beam_of(ship)
  local e, a = tractor.frame(ship)
  local len, tint
  if o.tractor then
    len = math.max(1.5, vec.dot(vec.sub(o.tractor.from, e), a) + 1.0)
    tint = M.BEAM_TINT.pull
  elseif scan then
    len = vec.clamp(scan.info.depth + 1.5, b.min + 1, b.range)
    tint = scan.status == "lock" and M.BEAM_TINT.lock or M.BEAM_TINT.idle
  else
    len, tint = b.range, M.BEAM_TINT.idle
  end
  local r = len * tan(b.half_angle)
  local roll = ship.bank or 0
  v:mesh(A.beam_cone, { pos = e, yaw = ship.yaw, roll = roll, scale = { r, len, r }, ghost = true, tint = tint })
  local n = 1
  if o.tractor then
    v:mesh(A.beam_cone, { pos = e, yaw = ship.yaw, roll = roll, scale = { r * 0.3, len, r * 0.3 }, ghost = true,
                          tint = M.BEAM_TINT.core })
    n = n + 1
    local f, rt = vec.fwd(ship.yaw), vec.right(ship.yaw)
    for k = 0, 17 do
      local ph = (tick * 0.025 + k / 18) % 1
      local dd = len * (1 - ph)
      local ang = k * 2.39996 + tick * 0.06
      local rr = dd * tan(b.half_angle) * 0.7 * (((k * 37) % 10) / 10)
      local side = vec.add(vec.scale(rt, sm.cos(ang) * rr), vec.scale(f, sm.sin(ang) * rr))
      local q = vec.add(vec.add(e, vec.scale(a, dd)), side)
      v:billboard(A.tex.beam, q, 0.25 + 0.3 * (1 - ph), { palette = A.pal.base, tint = M.BEAM_TINT.mote })
      n = n + 1
    end
  end
  return n
end

-- the target marker: a ring of sprites round it, long scrap's axis and the keel line
function M.draw_target(v, A, o, scan)
  if not scan or o.tractor then return 0 end
  local c, tint = scan.cand, M.status_tint(scan.status)
  local R = 0.9 + c.item.size * 0.45
  local n = 0
  for k = 0, 11 do
    local a = k * sm.tau / 12
    v:billboard(A.tex.beam, { c.pos[1] + sm.sin(a) * R, c.pos[2] - 0.4, c.pos[3] + sm.cos(a) * R }, 0.35,
                { palette = A.pal.base, tint = tint })
    n = n + 1
  end
  if c.axis then
    local fa, fk = vec.fwd(c.axis), vec.fwd(o.ship.yaw)
    for k = -4, 4 do
      v:billboard(A.tex.beam, vec.add(c.pos, vec.scale(fa, k * 0.9)), 0.3, { palette = A.pal.base, tint = { 1, 0.75, 0.25, 1 } })
      v:billboard(A.tex.beam, vec.add({ c.pos[1], c.pos[2] + 0.3, c.pos[3] }, vec.scale(fk, k * 0.9)), 0.22,
                  { palette = A.pal.base, tint = { 0.4, 0.9, 1, 0.9 } })
      n = n + 2
    end
  end
  return n
end

-- the hatch iris in the belly (opens while the beam pulls) and the floor window
function M.draw_hatch(v, A, o, d)
  local L = avatar.layout()
  local T = L.tractor
  if not T or not A.iris_leaf then return 0 end
  local open = o.hatch or 0
  local y = (tractor.beam_of(o.ship).emitter or { 0, -5.75, 0 })[2] - 0.02
  -- each leaf retracts into the rim: its inner edge slides out, its outer edge stays put
  local s = type(d.scale) == "number" and d.scale or 1
  local k_len = math.max(0.02, 1 - open)
  for k = 0, 5 do
    local a = k * sm.tau / 6
    local lp = { sm.sin(a) * open * T.hatch, y, sm.cos(a) * open * T.hatch }
    v:mesh(A.iris_leaf, { pos = at(d, lp), yaw = d.yaw + a, roll = d.roll, scale = { s, s, s * k_len } })
  end
  v:mesh(A.belly_glass, { pos = d.pos, yaw = d.yaw, roll = d.roll, scale = d.scale, ghost = true, tint = { 0.6, 0.9, 1, 0.22 } })
  return 7
end

-- the Tractor Room's readouts: the scope on the starboard arm (cone at the
-- target's depth, the target's offset as a dot), the pull bar on the port arm
-- and a lit cubby on the hold racks for every hold slot in use
function M.beam_console(v, A, state, o, d)
  local L = avatar.layout()
  local fl = L.decks[3] and L.decks[3].floor
  if not fl then return 0 end
  local arm_l, arm_r
  local racks = {}
  for _, f in ipairs(L.furniture) do
    if f.kind == "beam_arm" then if f.side > 0 then arm_l = f else arm_r = f end end
    if f.kind == "hold_rack" then racks[#racks + 1] = f end
  end
  local n = 0
  local scan = o.index and state.players[o.index] == o and M.last_scan[o.index] or nil
  if arm_l then
    local b = arm_l.box
    local cx, cz, top = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2, fl + arm_l.h + 0.02
    local col = scan and M.status_tint(scan.status) or { 0.3, 0.6, 0.8, 1 }
    for k = 0, 11 do
      local a = k * sm.tau / 12
      blip(v, A, d, { cx + sm.sin(a) * 0.12, top, cz + sm.cos(a) * 0.12 }, { 0.015, 0.006, 0.015 }, col)
      n = n + 1
    end
    if scan then
      local info = scan.info
      local lim = math.max(0.5, info.max_lateral)
      local rel = avatar.rot(-o.ship.yaw, info.off)
      local x, z = vec.clamp(rel[1] / lim, -1.4, 1.4) * 0.12, vec.clamp(rel[3] / lim, -1.4, 1.4) * 0.12
      blip(v, A, d, { cx + x, top + 0.01, cz + z }, { 0.03, 0.01, 0.03 }, col)
      n = n + 1
    end
  end
  if arm_r and o.tractor then
    local b = arm_r.box
    local f = vec.clamp(o.tractor.t / o.tractor.total, 0, 1)
    local w = (b[3] - b[1] - 0.16) * f
    blip(v, A, d, { b[1] + 0.08 + w / 2, fl + arm_r.h + 0.02, (b[2] + b[4]) / 2 }, { math.max(0.01, w), 0.006, 0.05 },
         { 1, 0.75, 0.3, 1 })
    n = n + 1
  end
  local all = configs.all()
  for i = 1, require("sim.upgrades").hold_slots(o) do
    local it = o.hold[i]
    local rack = racks[(i - 1) // 6 + 1]
    if it and rack then
      local j = (i - 1) % 6
      local b = rack.box
      local x = b[1] + ((j % 3) + 0.5) * (b[3] - b[1]) / 3
      local y = fl + 0.35 + (j // 3) * 0.6
      blip(v, A, d, { x, y, (b[2] + b[4]) / 2 }, { 0.5, 0.3, 0.3 }, it.hot and { 1, 0.7, 0.25, 1 } or { 0.4, 1, 0.5, 1 })
      n = n + 1
    end
  end
  return n
end
M.last_scan = {}

-- the Villa's rooms, each folding on its own (sim/fold.lua) plus the doors
function M.rooms(v, A, o, d, state)
  local L = avatar.layout()
  local ship = o.ship
  local amounts = fold.amounts(ship, L)
  local eye = ship.morph and fold.eye_local(ship) or { 0, 0, 0 }
  local drawn = 0
  for _, g in ipairs(fold.groups(L)) do
    local a = amounts[g.id] or 0
    local m = A.groups[g.id]
    if a < 1 and m then
      local lp, sc = fold.transform(g, a, { eye[1], g.anchor[2], eye[3] })
      local opts = { pos = at(d, lp), yaw = d.yaw, roll = d.roll, scale = { sc[1] * d.scale, sc[2] * d.scale, sc[3] * d.scale } }
      v:mesh(m, opts)
      for _, mm in ipairs(A.group_mats and A.group_mats[g.id] or {}) do
        v:mesh(mm.mesh, { pos = opts.pos, yaw = opts.yaw, roll = opts.roll, scale = opts.scale,
                          tex = A.tex["mat_" .. mm.mat], palette = A.pal.interior })
      end
      if a > 0 then
        -- fold-space shimmer around a room while it packs
        v:mesh(m, { pos = opts.pos, yaw = d.yaw, roll = d.roll, scale = { opts.scale[1] * 1.04, opts.scale[2] * 1.04 + 0.02,
                    opts.scale[3] * 1.04 }, ghost = true, tint = { 0.4, 1, 0.9, 0.6 } })
      end
      drawn = drawn + 1
    end
  end
  if not ship.morph then
    for i, door in ipairs(L.doors or {}) do
      local open = require("sim.home").door_ease(o.doors and o.doors[i] or 0)
      local b = door.box
      local w = b[3] - b[1]
      local side = (b[1] + b[3]) > 0 and 1 or -1
      if A.doors[i] then v:mesh(A.doors[i], { pos = at(d, { open * w * side * 0.95, 0, 0 }), yaw = d.yaw, roll = d.roll,
                                     scale = d.scale }) end
    end
    if state then M.console(v, A, state, o, d) end
    if state and (amounts["3:Tractor room"] or 0) == 0 then M.beam_console(v, A, state, o, d) end
    if (amounts["2:Engine room"] or 0) == 0 then M.engine_parts(v, A, d, state and state.tick or 0) end
    M.home_parts(v, A, o, d, state and state.tick or 0)
    if state and (amounts["1:Living room"] or 0) == 0 then M.decor(v, A, o, d, state) end
  end
  return drawn
end

-- add-detail-pass: the engine's moving parts. Two rotor rings spin opposite
-- ways round the core and two pistons pump beside it. Render-only: driven by
-- the tick, never stored. -> number of meshes drawn
function M.engine_parts(v, A, d, tick)
  local L = avatar.layout()
  local e
  for _, f in ipairs(L.furniture) do
    if f.kind == "engine" then e = f end
  end
  if not e or not A.engine_rotor then return 0 end
  local fl = L.decks[e.deck].floor
  local spin = (tick % 7200) * 0.06
  local n = 0
  for i, h in ipairs({ 0.95, 2.35 }) do
    v:mesh(A.engine_rotor, { pos = at(d, { e.circle[1], fl + h, e.circle[2] }), yaw = d.yaw + (i == 1 and spin or -spin * 1.3),
                             roll = d.roll, scale = d.scale })
    n = n + 1
  end
  for k = 0, 1 do
    local bob = 0.22 * sm.sin((tick % 7200) * 0.15 + k * sm.pi)
    local x = e.circle[1] + (k == 0 and -1.55 or 1.55)
    v:mesh(A.piston, { pos = at(d, { x, fl + 0.9 + bob, e.circle[2] }), yaw = d.yaw, roll = d.roll, scale = d.scale })
    n = n + 1
  end
  return n
end

-- add-detail-pass: thruster glow sprites, brighter the faster the saucer moves
M.SAUCER_LOD = 260 -- other players' saucers beyond this skip their rooms and props
function M.thruster_glow(v, A, o, d, c)
  local T = A.thrusters
  if not T then return 0 end
  local vel = o.ship.vel or { 0, 0, 0 }
  local speed = vec.len(vel)
  local k = math.min(1, speed / 25)
  local n = 0
  local tint = { 0.8, 0.95, 1, 0.6 + 0.4 * k }
  if c.id == "villa" then
    local lift = math.min(1, math.max(0, vel[2] / 10))
    for _, t in ipairs(T.belly) do
      local lp = { sm.sin(t[2]) * t[1], T.belly_y - 0.25, sm.cos(t[2]) * t[1] }
      v:billboard(A.tex.glow, at(d, lp), (1.1 + 1.6 * math.max(k * 0.5, lift)) * d.scale, { palette = A.pal.base, tint = tint })
      n = n + 1
    end
    for _, tip in ipairs(T.rear) do
      v:billboard(A.tex.glow, at(d, { tip[1], tip[2], tip[3] - 0.3 - k * 0.8 }), (0.9 + 1.5 * k) * d.scale,
                  { palette = A.pal.base, tint = tint })
      n = n + 1
    end
  elseif c.id == "seat" then
    v:billboard(A.tex.glow, at(d, { 0, -0.35, -1.1 - k * 0.2 }), (0.35 + 0.6 * k) * d.scale, { palette = A.pal.base, tint = tint })
    n = n + 1
  end
  return n
end

local function draw_saucer(v, A, o, own_eyes, state, xr, cam)
  -- add-pocket-station-visits: a pocketed saucer is a coin inside a station
  -- (add-dock-land-eva: a Villa standing on its gear outside is drawn)
  if o.mode == "foot" and not (o.excursion and o.excursion.coin == "stand") then return end
  local d = M.pose(o.ship, xr)
  local c = configs.get(d.size)
  local m = A.saucer[d.size]
  -- add-realistic-lighting: the hull is tagged with its owner, so the saucer's own lights shine through it
  v:mesh(m.hull, { pos = d.pos, yaw = d.yaw, roll = d.roll, scale = d.scale, tex = A.tex.hull, palette = A.pal.base,
                   owner = lightsv.owner_of(o) })
  lightsv.saucer(v, o, d, at, cam and cam.pos or d.pos)
  M.thruster_glow(v, A, o, d, c)
  local far = not own_eyes and cam and vec.dist(cam.pos, d.pos) > M.SAUCER_LOD
  if c.interior and far then
    v:mesh(A.glass, { pos = d.pos, yaw = d.yaw, roll = d.roll, scale = d.scale, ghost = true, tint = { 0.55, 0.8, 1, 0.3 } })
  elseif c.interior then
    M.rooms(v, A, o, d, state)
    if not o.ship.morph then M.draw_hatch(v, A, o, d) end
    if not o.ship.morph then require("view.gear").draw(v, A, o, d) end
    if v.player == o.index and o.mode == "helm" and not o.berth and not o.ship.morph then require("view.gear").markers(v, A, state, o) end
    v:mesh(A.glass, { pos = d.pos, yaw = d.yaw, roll = d.roll, scale = d.scale, ghost = true, tint = { 0.55, 0.8, 1, 0.3 } })
    if o.mode == "walk" and not own_eyes and not o.ship.morph then
      local L = avatar.layout()
      local w = at(d, o.body.pos)
      v:mesh(A.person, { pos = w, yaw = o.ship.yaw + o.body.yaw })
    end
    -- add-wider-dark: guests from docked saucers walking this dome
    if not o.ship.morph then
      for _, g in ipairs(state.players) do
        if g.visiting == o.index and g.vbody and g.index ~= v.player then
          v:mesh(A.person, { pos = at(d, g.vbody.pos), yaw = o.ship.yaw + g.vbody.yaw })
        end
      end
    end
  else
    v:mesh(m.dome, { pos = d.pos, yaw = d.yaw, roll = d.roll, scale = d.scale, ghost = true, tint = { 0.55, 0.8, 1, 0.3 } })
  end
  if o.ghost > 0 and o.ghost_size then
    v:mesh(A.saucer[o.ghost_size].hull, { pos = o.ghost_pos or o.ship.pos, yaw = o.ship.yaw, ghost = true,
                                          tint = { 1, 0.2, 0.2, 0.5 } })
  end
end

-- add-presentation-packaging: the sky backdrop. Two nebulae, a ringed gas
-- giant and a far galaxy, all Grok Imagine sprites that ride with the eye so
-- they never get closer. -> number of sprites drawn
M.SKY = {
  { tex = "nebula", pal = "base", at = { 700, 160, 520 }, size = 900, tint = { 0.8, 0.7, 1, 0.9 } },
  { tex = "nebula_b", pal = "sky", at = { -820, -120, -300 }, size = 760, tint = { 1, 0.9, 0.85, 0.85 } },
  { tex = "planet", pal = "sky", at = { -380, 260, 760 }, size = 210, tint = { 1, 1, 1, 1 } },
  { tex = "galaxy", pal = "sky", at = { 860, -260, -420 }, size = 260, tint = { 0.9, 0.9, 1, 0.8 } },
}
function M.sky(v, A, eye)
  local n = 0
  for _, s in ipairs(M.SKY) do
    local tex = A.tex[s.tex]
    if tex then
      v:billboard(tex, { eye[1] + s.at[1], eye[2] + s.at[2], eye[3] + s.at[3] }, s.size,
                  { palette = A.pal[s.pal] or A.pal.base, tint = s.tint })
      n = n + 1
    end
  end
  return n
end

M.FOG = 0.0009
M.DETAIL_DIST = 480   -- add-detail-pass: chunks nearer than this also draw their detail mesh
M.OUTER_NEAR = 260   -- a skyline district shows its windows inside this range (add-cities-2)
M.DETAIL_BUILDS = 2   -- at most this many detail meshes are built per frame (no hitches)
M.CITY_DETAIL_DIST = 110 -- a city's rooms are many: only the nearest get their detail pass
M.GATE_DIST = 420
M.CITY_NEAR = 340     -- add-cities: a district nearer than this draws its chunks, else one coarse mesh
M.LOD_DIST = 1100     -- beyond this a site is drawn as its coarse silhouette
M.CULL_DIST = 2400    -- beyond this (fog) nothing of a site is drawn
M.VIEW_HALF = 1.15    -- radians: half of the widest view angle plus slack
M.stats = { chunks = 0, culled = 0, lod = 0 }

-- is a sphere (centre c, radius r) possibly visible from camera cam?
function M.visible(cam, c, r, xr)
  local dist = vec.len(vec.sub(c, cam.pos))
  if dist - r > M.CULL_DIST then return false end
  return M.in_view(cam, c, r, xr)
end
-- add-alien-cities-2: inside the view cone, at any distance
function M.in_view(cam, c, r, xr)
  local d = vec.sub(c, cam.pos)
  local dist = vec.len(d)
  if xr or dist <= r then return true end
  local f = vec.aim(cam.yaw, cam.pitch)
  local cosang = vec.dot(d, f) / dist
  local slack = sm.atan2(r, sm.sqrt(dist * dist - r * r))
  return cosang >= sm.cos(math.min(3.14159, M.VIEW_HALF + slack))
end

-- add-cities: inside a body city the air, the light and the clock belong to the body. A planet has
-- a day (CITY_DAY seconds) that fades its fog and sky; a moon sits in earthlight; an asteroid is dark
-- rock lit by its own lamps. Render only: a pure function of the tick. -> a fog table (+ .day) or nil
M.CITY_DAY = 360
-- the lightning of a storm of intensity sk: a function of the tick (0 .. 1, sharp then fading)
function M.flash(state, sk)
  if sk < 0.25 then return 0 end
  local slot = state.tick // 50
  local h = ((slot * 2654435761) >> 7) % 6
  if h ~= 0 then return 0 end
  local t = state.tick % 50
  if t > 10 then return 0 end
  return (1 - t / 10) * (t % 4 < 3 and 1 or 0.5)
end

function M.city_env(state, p)
  if not p then return nil end
  local r = p.site ~= 0 and game.ruin(p.site) or nil
  -- add-alien-cities-2: over an outer district the city's air and light hold too
  if p.site == 0 then
    local _, mr, mp = game.mega_city_at(state, p.ship.pos, 0)
    if mp and require("sim.citymega").near_district(mp, p.ship.pos, megav.AIR) then r = mr end
  end
  if not (r and r.city) then return nil end
  local e = ruinm.kit_of(r.kit).city.env
  if not e then return nil end
  local day = 1
  if e.night then day = 0.5 + 0.5 * sm.sin(state.tick / 60 / M.CITY_DAY * sm.tau) end
  -- add-cities-2: a storm darkens and thickens the air, and lightning flashes it white
  local sk = cities.storm(r, state.tick)
  local dim = 1 - 0.4 * sk
  local flash = M.flash(state, sk)
  local k = (0.18 + 0.82 * day) * dim
  local function mix(c, f) return { math.min(1, c[1] * f + flash * 0.7), math.min(1, c[2] * f + flash * 0.7), math.min(1, c[3] * f + flash * 0.75) } end
  return { color = mix(e.fog, k), density = M.FOG * e.density * (1 + 1.2 * sk), clear = mix(e.clear, k),
           light = mix(e.light, (0.45 + 0.55 * day) * dim + flash), ambient = e.ambient * (0.6 + 0.4 * day) * dim + flash * 0.5,
           day = e.night and day or 0, storm = sk, flash = flash }
end

-- add-cities-2: mag-rail trains and lift cabins. Pure functions of the tick (nothing is simulated, nothing
-- is stored): a train runs its line end to end and back in TRAIN_PERIOD seconds, a cabin rides its shaft
-- up and down. Only those within TRANSIT_DIST of the camera are drawn.
M.TRANSIT_DIST = 700
M.TRAIN_SPEED = 38
M.TRAIN_CARS = 5
function M.train_pos(line, n, tick)
  -- -> distance along the line (a..b) of train n's head, and its direction (+1/-1)
  local len = line.b - line.a
  local run = len * 2
  local u = (tick / 60 * M.TRAIN_SPEED / 4 + n * len * 0.9 + line.c * 3) % run  -- (cells)
  if u < len then return line.a + u, 1 end
  return line.b - (u - len), -1
end
function M.lift_y(lift, tick)
  local t = (tick / 60 / 36 + lift.phase) % 1
  local tri = t < 0.5 and t * 2 or (1 - t) * 2
  return lift.y0 + 4 + (lift.y1 - lift.y0 - 14) * tri
end
function M.draw_transit(v, A, state, cam, r, st)
  local acc = r.city.style.accent
  local dark, glow = assets.unit_box(false), assets.unit_box(true)
  for _, line in ipairs(r.city.rails or {}) do
    for n = 0, 1 do
      local head, dir = M.train_pos(line, n, state.tick)
      for c = 0, M.TRAIN_CARS - 1 do
        local ux = head - dir * c * 11 / 4 -- cells
        local pos = line.axis == 1 and { r.origin[1] + ux * 4, r.origin[2] + line.y * 4 + 3.3, r.origin[3] + line.c * 4 }
                                    or { r.origin[1] + line.c * 4, r.origin[2] + line.y * 4 + 3.3, r.origin[3] + ux * 4 }
        if vec.dist(pos, cam.pos) < M.TRANSIT_DIST then
          local sc = line.axis == 1 and { 9.5, 3.4, 3.6 } or { 3.6, 3.4, 9.5 }
          v:mesh(dark, { pos = pos, scale = sc, tex = A.tex.hull, palette = A.pal.base, tint = { 0.55, 0.58, 0.66, 1 } })
          local ss = line.axis == 1 and { 9.0, 0.7, 3.8 } or { 3.8, 0.7, 9.0 }
          v:mesh(glow, { pos = { pos[1], pos[2] + 0.4, pos[3] }, scale = ss, palette = A.pal.base, tint = { acc[1], acc[2], acc[3], 1 } })
          if c == 0 then
            local hs = line.axis == 1 and { 0.6, 0.9, 2.2 } or { 2.2, 0.9, 0.6 }
            local hp = line.axis == 1 and { pos[1] + dir * 4.9, pos[2] - 0.3, pos[3] } or { pos[1], pos[2] - 0.3, pos[3] + dir * 4.9 }
            v:mesh(glow, { pos = hp, scale = hs, palette = A.pal.base, tint = { 1, 1, 0.9, 1 } })
          end
          st.trains = (st.trains or 0) + 1
        end
      end
    end
  end
  for _, lift in ipairs(r.city.lifts or {}) do
    local pos = { lift.pos[1], M.lift_y(lift, state.tick), lift.pos[3] }
    if vec.dist(pos, cam.pos) < M.TRANSIT_DIST then
      v:mesh(dark, { pos = pos, scale = { 8, 6, 8 }, tex = A.tex.hull, palette = A.pal.base, tint = { 0.6, 0.62, 0.7, 1 } })
      v:mesh(glow, { pos = { pos[1], pos[2] + 0.5, pos[3] }, scale = { 8.3, 1, 8.3 }, palette = A.pal.base, tint = { acc[1], acc[2], acc[3], 1 } })
      st.lifts = (st.lifts or 0) + 1
    end
  end
end

function M.draw_ruins(v, A, state, cam, xr)
  local st = { chunks = 0, culled = 0, lod = 0, detail = 0, built = 0, outer_built = 0 }
  local function draw_detail(set, ch)
    if vec.dist(ch.center, cam.pos) - ch.radius > (set.ruin.city and M.CITY_DETAIL_DIST or M.DETAIL_DIST) then return end
    for _, g in ipairs(ch.glyphs or {}) do
      assets.decal(v, A, A.tex.glyphs, A.pal.sprites, g.c, g.yaw, g.w, g.w, { 0.8, 1, 1, 1 })
      st.glyphs = (st.glyphs or 0) + 1
    end
    if ch.detail == nil then
      if st.built >= M.DETAIL_BUILDS then return end
      st.built = st.built + 1
    end
    local m = assets.chunk_detail(set, ch)
    if m then
      v:mesh(m, { palette = A.pal.base })
      st.detail = st.detail + 1
    end
  end
  -- add-relic-stations: relics draw their own skins (view/relic.lua)
  local rs = require("view.relic").draw(v, A, state, cam, xr, (state.tick + (M.alpha or 0)) / 60)
  st.relic_rooms, st.relic_culled = rs.rooms, rs.culled
  for i, site in ipairs(state.sector.sites) do
    local r = game.ruin(i)
    if r and not r.relic then
      local set = assets.ruin_chunks(r, site.pos)
      local tex = assets.kit_texture(A, set.kit)
      local ftex = assets.floor_texture(A, set.kit)
      local lod = set.lod
      -- (a city's far skyline is now its megacity: view/citymega.lua)
      if set.horizon and not r.city then v:mesh(set.horizon.mesh, { tex = tex, palette = A.pal.base }) end
      local far = vec.dist(lod.center, cam.pos) - lod.radius > M.LOD_DIST
      if far then
        if M.visible(cam, lod.center, lod.radius, xr) then
          v:mesh(lod.mesh, { tex = tex, palette = A.pal.base })
          st.lod = st.lod + 1
        else
          st.culled = st.culled + #set.chunks
        end
      else
        -- add-cities: districts farther than CITY_NEAR are one coarse mesh each
        local dnear = {}
        if set.districts then
          for d, dm in pairs(set.districts) do
            local dx = math.max(dm.mn[1] - cam.pos[1], 0, cam.pos[1] - dm.mx[1])
            local dy = math.max(dm.mn[2] - cam.pos[2], 0, cam.pos[2] - dm.mx[2])
            local dz = math.max(dm.mn[3] - cam.pos[3], 0, cam.pos[3] - dm.mx[3])
            local d2 = dx * dx + dy * dy + dz * dz
            if dm.outer and d2 < M.OUTER_NEAR * M.OUTER_NEAR and M.visible(cam, dm.center, dm.radius, xr) then
              -- a skyline district close by: its windows and lights (one build per frame)
              local nr = dm.near
              if not nr and st.outer_built < 1 then
                nr = assets.outer_detail(set, d)
                st.outer_built = st.outer_built + 1
              end
              if nr then
                v:mesh(nr.mesh, { tex = tex, palette = A.pal.base })
                if nr.lights then v:mesh(nr.lights, { palette = A.pal.base }) st.lit = (st.lit or 0) + 1 end
                st.lod = st.lod + 1
              else
                v:mesh(dm.mesh, { tex = tex, palette = A.pal.base })
                st.lod = st.lod + 1
              end
            elseif not dm.outer and d2 < M.CITY_NEAR * M.CITY_NEAR then
              dnear[d] = true
            elseif M.visible(cam, dm.center, dm.radius, xr) then
              v:mesh(dm.mesh, { tex = tex, palette = A.pal.base })
              st.lod = st.lod + 1
              local lk = dm.glow and cities.light(state, i, r, d) or 0
              if lk > 0 then v:mesh(dm.glow, { palette = A.pal.base, tint = { lk, lk, lk, 1 } }) end
            end
          end
        end
        for _, ch in ipairs(set.chunks) do
          if ch.district and set.districts and not dnear[ch.district] then
            st.culled = st.culled + 1
          elseif ch.fall and state.tick >= ch.fall then
            -- add-cities-2: a sky-bridge that tore loose: it drops, then it is gone
            local dy = cities.fall_drop(ch.fall, state.tick)
            if dy and M.visible(cam, { ch.center[1], ch.center[2] - dy, ch.center[3] }, ch.radius, xr) then
              v:mesh(ch.mesh, { tex = tex, palette = A.pal.base, pos = { 0, -dy, 0 } })
              st.falling = (st.falling or 0) + 1
            end
          elseif M.visible(cam, ch.center, ch.radius, xr) then
            v:mesh(ch.mesh, { tex = tex, palette = A.pal.base })
            -- add-cities: the lights of a lit district (built the first time they are wanted)
            if r.city and (ch.light_parts or ch.lights) then
              local lk = cities.light_at(state, i, r, ch.district, ch.center)
              if lk > 0 and (ch.lights ~= nil or st.built < M.DETAIL_BUILDS) then
                if ch.lights == nil then st.built = st.built + 1 end
                local lm = assets.chunk_lights(ch)
                if lm then
                  v:mesh(lm, { palette = A.pal.base, tint = { lk, lk, lk, 1 } })
                  st.lit = (st.lit or 0) + 1
                end
              end
            end
            if ch.floor then v:mesh(ch.floor, { tex = ftex or tex, palette = ftex and A.pal.kits or A.pal.base }) end
            st.chunks = st.chunks + 1
            draw_detail(set, ch)
          else
            st.culled = st.culled + 1
          end
        end
        if set.links and M.visible(cam, set.links.center, set.links.radius, xr) then draw_detail(set, set.links) end
        -- add-cities: a light pillar over each landmark district, dim while it is dark
        for d, b in pairs(set.beacons or {}) do
          if M.visible(cam, b.center, b.radius, xr) then
            local lk = 0.3 + 0.7 * cities.light(state, i, r, d)
            v:mesh(b.mesh, { palette = A.pal.base, tint = { lk, lk, lk, 1 } })
            st.beacons = (st.beacons or 0) + 1
          end
        end
        if r.city then M.draw_transit(v, A, state, cam, r, st) end
        -- add-alien-cities: swarms over the avenues, machines on the towers, pulses down the sky lanes
        if r.city then st.city_phen = (st.city_phen or 0) + require("view.cityphen").draw(v, A, r, cam, (state.tick + (M.alpha or 0)) / 60) end
        -- add-cities: the gates of dark districts, a shutter in each shut door
        if r.city then
          for id, g in pairs(game.gates(i)) do
            local b = r.city.gates[id].box
            local c = { (b[1][1] + b[2][1]) / 2, (b[1][2] + b[2][2]) / 2, (b[1][3] + b[2][3]) / 2 }
            if vec.dist(c, cam.pos) < M.GATE_DIST then
              v:mesh(A.foot.shutter, { pos = c, scale = { b[2][1] - b[1][1], b[2][2] - b[1][2], b[2][3] - b[1][3] },
                                       tex = A.tex.hull, palette = A.pal.base, tint = { 1, 0.45, 0.35, 1 } })
              st.gates = (st.gates or 0) + 1
            end
          end
        end
      end
    end
  end
  -- add-alien-cities-2: the megacity round every city the eye is over (view/citymega.lua)
  for i, site in ipairs(state.sector.sites) do
    local r = site.city and game.ruin(i)
    if r and r.city and game.mega_city_at(state, cam.pos, megav.ZONE) == i then
      local p = game.mega_plan(state, i)
      st.mega = megav.draw(v, A, p, cam, assets.kit_texture(A, p.frame.kit), function(c, rr) return M.in_view(cam, c, rr, xr) end)
    end
  end
  M.stats = st
  return st
end

function M.render(v, state, alpha)
  M.alpha = alpha
  local p = state.players[v.player]
  if not p then
    -- add-wider-dark: the spare quarter of a three-player split shows the map
    if v.player == 0 and not v.xr then require("view.map").spare(v, state) end
    return
  end
  local A = assets.init()
  if p.mode == "foot" and p.station then
    -- add-pocket-station-visits: on foot you see the station's inside
    local stv = require("view.station")
    stv.render(v, state, p)
    if v.xr then xrv.overlay(v, A, stv.cam, p, nil, state) else hud.draw(v, state, p, nil) end
    if v.index == v.player then M.audio(state, p) end
    return
  end
  if p.holo_run then
    -- add-holodeck-home-life: inside a program you only see the simulation
    local hv = require("view.holo")
    hv.render(v, state, p)
    if v.xr and hv.cam then xrv.overlay(v, A, hv.cam, p, nil, state) elseif not v.xr then hud.draw(v, state, p, nil) end
    if v.index == v.player then M.audio(state, p) end
    return
  end
  -- add-fun-fixes: hitstop and camera trauma on a hit (view only, none in XR)
  local cam = xrv.adjust(v, require("view.juice").camera(M.camera(p, v.xr), p, state.tick, v.xr))
  -- add-alien-cities-2: over a megacity the far plane reaches its horizon band
  megav.far_plane(cam, function(pos) return game.mega_city_at(state, pos, megav.ZONE) end)
  v:camera(cam)
  local cenv = M.city_env(state, p)
  v:fog(cenv or { color = { 0.02, 0.02, 0.06 }, density = M.FOG, clear = { 0.0, 0.0, 0.025 }, light = { 0.35, 0.8, 0.45 },
          ambient = 0.55 })
  -- add-realistic-lighting: the star outside, the lamps of every place near the eye (view/lights.lua)
  local lit = lightsv.begin(v, state, p, cam, cenv)
  if not (cenv and cenv.day > 0.55) then v:mesh(A.stars, { pos = cam.pos, sky = true }) end
  if not (cenv and cenv.day > 0.55) then M.sky(v, A, cam.pos) end
  if not lit.inside then lightsv.sky(v, A, cam.pos, lit.star) end
  lightsv.site_lamps(v, A, state, cam.pos)
  lightsv.bays(v, state, cam.pos, state.tick)
  -- derelicts, in chunks: culled against the view, far sites as one silhouette
  M.draw_ruins(v, A, state, cam, v.xr)
  -- add-huge-stations: every trader's station, a kilometre-scale megastructure (view/stationhull.lua)
  require("view.stationhull").draw(v, A, state, cam, state.tick + (alpha or 0))
  require("view.dock").draw(v, A, state, cam)
  M.draw_sentries(v, A, state, p)
  -- add-on-foot-excursions: shutters, hand-locks, grid consoles, Delicate finds
  local exv = require("view.excursion")
  exv.props(v, A, state, p, cam)
  local on_foot = p.mode == "foot" and p.excursion
  -- what this player's beam sees (the HUD, the beam console and the cone use it); none on foot
  local scan = not on_foot and tractor.scan(state, p, p.site, p.site ~= 0 and game.ruin(p.site) or nil, M.beam_heading(p)) or nil
  M.last_scan[p.index] = scan
  -- this player's loot instances, Echoes, nests, caches and the vault's Curio
  local spin = (state.tick % 360) * sm.tau / 360
  do
    local ruin = p.site ~= 0 and game.ruin(p.site) or nil
    for _, cand in ipairs(tractor.candidates(state, p, p.site, ruin)) do
      local s = 0.6 + cand.item.size * 0.35
      local pos, k = cand.pos, 1
      if p.tractor and p.tractor.key == cand.key then
        pos, k = tractor.pull_pose(p.ship, p.tractor)
        -- a glow round the item riding the beam, so it reads as it shrinks
        v:billboard(A.tex.beam, pos, (0.6 + cand.item.size * 0.35) * k * 1.8, { palette = A.pal.base,
                    tint = { 0.8, 1, 0.9, 0.55 } })
      end
      if cand.kind == "coupling" then
        -- add-cities: a district's power coupling, a tall glowing pylon head
        local pulse = 0.65 + 0.35 * sm.sin(state.tick * 0.07)
        v:mesh(A.foot.lock, { pos = { pos[1], pos[2] - 1.2, pos[3] }, yaw = spin, scale = 2.4 * k, palette = A.pal.base })
        v:billboard(A.tex.glow, pos, 7 * k, { palette = A.pal.base, tint = { 1, 0.7, 0.2, 0.9 * pulse } })
      elseif cand.kind == "story" then
        -- add-run-story: a clue of the run's story, tinted by what it is (log amber, mural violet, record teal)
        local pulse = 0.7 + 0.3 * sm.sin(state.tick * 0.05)
        local tint = cand.carrier == "mural" and { 0.85, 0.5, 1.0 } or (cand.carrier == "archive" and { 0.4, 1.0, 0.9 } or { 1.0, 0.8, 0.35 })
        v:billboard(A.tex.glow, pos, 6 * k, { palette = A.pal.base, tint = { tint[1], tint[2], tint[3], 0.55 * pulse } })
        v:billboard(A.tex.echo, pos, 2.0 * k, { palette = A.pal.base, tint = { tint[1], tint[2], tint[3], 1 } })
      elseif cand.item and cand.item.xl then
        -- add-relic-stations: the relic's XL idol
        require("view.relic").idol(v, A, pos, spin, k, state.tick)
      elseif cand.echo or cand.kind == "curio" or cand.kind == "clue" then
        v:billboard(A.tex.echo, pos, (cand.kind == "curio" and 2.4 or 1.6) * k, { palette = A.pal.base })
      else
        v:billboard(A.tex.loot, pos, s * k, { palette = A.pal.base })
        -- long scrap lies still along its own axis, stretched; the rest slowly turns
        local sc = s * 0.6 * k
        v:mesh(A.cache_mesh, { pos = { pos[1], pos[2] - s * k * 0.7, pos[3] }, yaw = cand.axis or spin,
                               scale = cand.axis and { sc * 0.7, sc * 0.8, sc * 2.4 } or sc })
      end
    end
  end
  -- saucers (and, through their domes, the people in them)
  for j, o in ipairs(state.players) do
    draw_saucer(v, A, o, j == v.player and (p.cam ~= "chase" or v.xr), state, v.xr, cam)
  end
  -- on foot: your hand and coin (or your body, in the chase view), the others on foot
  if on_foot then
    if p.cam == "chase" and not v.xr then
      local b = p.excursion.body
      v:mesh(A.person, { pos = b.pos, yaw = b.yaw, scale = b.crouch and { 1, 0.5, 1 } or nil })
    end
    exv.own(v, A, state, p, cam)
  end
  exv.others(v, A, state, p)
  -- the belly beams: everyone's while it pulls, your own while you watch it
  for _, o in ipairs(state.players) do
    if o == p then
      if p.tractor or M.beam_view(p) then M.draw_beam(v, A, p, scan, state.tick) end
      if M.beam_view(p) or p.mode == "helm" then M.draw_target(v, A, p, scan) end
    elseif o.tractor then
      M.draw_beam(v, A, o, nil, state.tick)
    end
  end
  if v.xr then xrv.overlay(v, A, cam, p, scan, state) else hud.draw(v, state, p, scan) end
  if v.index == v.player then M.audio(state, p) end
end

return M
