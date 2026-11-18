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
local M = {}

-- add-presentation-packaging: sounds live in view/audio.lua (kept here for mods)
local sound = require("view.audio")
local xrv = require("view.xr")
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

function M.draw_sentries(v, A, state, p)
  local sentry = require("sim.sentry")
  local scanned = (p.scan_until or 0) > state.tick
  local t = sentry.tune()
  for site, list in pairs(state.sentries or {}) do
    for i, def in ipairs(game.sentries(site)) do
      local dyn = list[i]
      if dyn then
        local tint = M.STATE_TINT[dyn.st] or M.STATE_TINT.dormant
        local show = scanned and p.site == site
        if def.kind == "watcher" then
          -- add-mesh-builder: the base hangs still, the head turns to dyn.yaw and the eye tilts to its pitch
          local pitch = dyn.pitch or def.pitch
          kit.draw(v, assets.rig(A, "watcher", {}, def.glyph or 1), { pos = def.pos, yaw = def.yaw },
                   { head = { yaw = dyn.yaw - def.yaw }, eye = { pitch = pitch } })
          local f = sentry.dir_of(dyn.yaw, pitch)
          v:billboard(A.tex.beam, vec.add(def.pos, vec.scale(f, 1.9)), 1.0, { palette = A.pal.base, tint = tint })
          if show then
            for _, da in ipairs({ -t.watcher.half_angle, 0, t.watcher.half_angle }) do
              local d = sentry.dir_of(dyn.yaw + da, pitch)
              for k = 1, 12 do
                v:billboard(A.tex.beam, vec.add(def.pos, vec.scale(d, k * t.watcher.range / 12)), 0.7,
                  { palette = A.pal.base, tint = { tint[1], tint[2], tint[3], 0.45 } })
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
function M.radar_point(ship, pos)
  local rel = avatar.rot(-ship.yaw, vec.sub(pos, ship.pos))
  local k = M.RADAR_RADIUS / M.RADAR_RANGE
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
  out[#out + 1] = { pos = state.sector.trader.pos, color = { 0.35, 1, 0.45, 1 } }
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
  for _, tg in ipairs(M.radar_targets(state, o)) do
    local q = M.radar_point(ship, tg.pos)
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
      { ship.charge / all.max_charge, { 0.4, 0.9, 1, 1 } },
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
      local open = o.doors and o.doors[i] or 0
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
  if o.mode == "foot" then return end
  local d = M.pose(o.ship, xr)
  local c = configs.get(d.size)
  local m = A.saucer[d.size]
  v:mesh(m.hull, { pos = d.pos, yaw = d.yaw, roll = d.roll, scale = d.scale, tex = A.tex.hull, palette = A.pal.base })
  M.thruster_glow(v, A, o, d, c)
  local far = not own_eyes and cam and vec.dist(cam.pos, d.pos) > M.SAUCER_LOD
  if c.interior and far then
    v:mesh(A.glass, { pos = d.pos, yaw = d.yaw, roll = d.roll, scale = d.scale, ghost = true, tint = { 0.55, 0.8, 1, 0.3 } })
  elseif c.interior then
    M.rooms(v, A, o, d, state)
    if not o.ship.morph then M.draw_hatch(v, A, o, d) end
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
M.DETAIL_BUILDS = 6   -- at most this many detail meshes are built per frame (no hitches)
M.LOD_DIST = 1100     -- beyond this a site is drawn as its coarse silhouette
M.CULL_DIST = 3200    -- beyond this (fog) nothing of a site is drawn
M.VIEW_HALF = 1.15    -- radians: half of the widest view angle plus slack
M.stats = { chunks = 0, culled = 0, lod = 0 }

-- is a sphere (centre c, radius r) possibly visible from camera cam?
function M.visible(cam, c, r, xr)
  local d = vec.sub(c, cam.pos)
  local dist = vec.len(d)
  if dist - r > M.CULL_DIST then return false end
  if xr or dist <= r then return true end
  local f = vec.aim(cam.yaw, cam.pitch)
  local cosang = vec.dot(d, f) / dist
  local slack = sm.atan2(r, sm.sqrt(dist * dist - r * r))
  return cosang >= sm.cos(math.min(3.14159, M.VIEW_HALF + slack))
end

function M.draw_ruins(v, A, state, cam, xr)
  local st = { chunks = 0, culled = 0, lod = 0, detail = 0, built = 0 }
  local function draw_detail(set, ch)
    if vec.dist(ch.center, cam.pos) - ch.radius > M.DETAIL_DIST then return end
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
  for i, site in ipairs(state.sector.sites) do
    local r = game.ruin(i)
    if r then
      local set = assets.ruin_chunks(r, site.pos)
      local tex = assets.kit_texture(A, set.kit)
      local ftex = assets.floor_texture(A, set.kit)
      local lod = set.lod
      local far = vec.dist(lod.center, cam.pos) - lod.radius > M.LOD_DIST
      if far then
        if M.visible(cam, lod.center, lod.radius, xr) then
          v:mesh(lod.mesh, { tex = tex, palette = A.pal.base })
          st.lod = st.lod + 1
        else
          st.culled = st.culled + #set.chunks
        end
      else
        for _, ch in ipairs(set.chunks) do
          if M.visible(cam, ch.center, ch.radius, xr) then
            v:mesh(ch.mesh, { tex = tex, palette = A.pal.base })
            if ch.floor then v:mesh(ch.floor, { tex = ftex or tex, palette = ftex and A.pal.kits or A.pal.base }) end
            st.chunks = st.chunks + 1
            draw_detail(set, ch)
          else
            st.culled = st.culled + 1
          end
        end
        if set.links and M.visible(cam, set.links.center, set.links.radius, xr) then draw_detail(set, set.links) end
      end
    end
  end
  M.stats = st
  return st
end

function M.render(v, state, alpha)
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
  local cam = xrv.adjust(v, M.camera(p, v.xr))
  v:camera(cam)
  v:fog({ color = { 0.02, 0.02, 0.06 }, density = M.FOG, clear = { 0.0, 0.0, 0.025 }, light = { 0.35, 0.8, 0.45 },
          ambient = 0.55 })
  v:mesh(A.stars, { pos = cam.pos, sky = true })
  M.sky(v, A, cam.pos)
  -- derelicts, in chunks: culled against the view, far sites as one silhouette
  M.draw_ruins(v, A, state, cam, v.xr)
  v:mesh(A.station, { pos = state.sector.trader.pos, yaw = state.tick * 0.002 })
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
      if cand.echo or cand.kind == "curio" then
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
