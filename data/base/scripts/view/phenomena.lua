-- SPDX-License-Identifier: MIT
-- add-relic-dungeons: the relic's phenomena -- strange, harmless things going on that nobody explains. Placed by
-- sim/relicgen.lua (deterministic, from the civ's list); drawn here as a function of the clock and the eye only, so
-- they never touch the state, never collide and never hurt:
--   motes       glowing spores rising in a slow column, fading at the top
--   orbit       chrome shards circling an empty point in mid-air
--   eye         an amethyst orb that turns to watch the saucer and dims as it comes close
--   procession  lights walking the ceiling from one end of a corridor to the other, one after another
--   breath      a membrane sac on a wall swelling and emptying
--   ripple      rings of light spreading over the floor from one spot, now and then
--   shadow      a dark shape standing at one end of a hall, gone when the saucer gets near
--   chimes      crystal strands hanging from the ceiling, swaying though nothing moves the air
local vec = require("lib.vec")
local sm = saucer.math
local matv = require("view.materials")
local M = {}

M.FADE = 60          -- m: a shadow is gone when the eye is this close; an eye dims inside twice this
local cache = {}

local function col(id) return matv.base_color(id) end

-- the shared meshes (built once): a shard, an orb with its iris, a sac, a crystal strand
local function meshes()
  if cache.shard then return cache end
  local S = matv.SLOT
  local chrome, amethyst, membrane, wound = col("chrome"), col("amethyst"), col("membrane"), col("wound")
  cache.shard = saucer.mesh.build({ parts = {
    { kind = "cone", c = { 0, -0.5, 0 }, r = 0.18, r1 = 0.0, h = 1.0, seg = 5, color = chrome, mat = S.accent },
    { kind = "cone", c = { 0, -0.5, 0 }, r = 0.18, r1 = 0.0, h = 0.4, seg = 5, roll = math.pi, color = chrome, mat = S.accent } } })
  cache.orb = saucer.mesh.build({ parts = {
    { kind = "sphere", c = { 0, 0, 0 }, r = 1.0, h = 1.0, seg = 16, rings = 8, color = amethyst, mat = S.rare, emissive = 0.4 },
    { kind = "ring", c = { 0, 0, 0 }, rin = 0.25, r = 0.5, h = 0.06, seg = 16, pos = { 0, 0, 0.98 }, pitch = math.pi / 2,
      color = wound, mat = S.ring, emissive = 0.8 } } })
  cache.sac = saucer.mesh.build({ parts = {
    { kind = "hemisphere", c = { 0, 0, 0 }, r = 1.0, h = 1.0, seg = 14, rings = 6, color = membrane, mat = S.dominant } } })
  cache.strand = saucer.mesh.build({ parts = {
    { kind = "cylinder", c = { 0, -1.0, 0 }, r = 0.03, h = 1.0, seg = 4, color = chrome, mat = S.accent },
    { kind = "cone", c = { 0, -1.35, 0 }, r = 0.12, r1 = 0.0, h = 0.35, seg = 6, roll = math.pi, color = amethyst, mat = S.rare,
      emissive = 0.5 } } })
  return cache
end
M.meshes = meshes

local function h01(seed, k) return ((seed * 7919 + k * 104729) % 1000) / 1000 end

-- the sub-objects of one phenomenon at time t, for the eye at `eye`: -> list of { mesh = name | nil (a glow), pos,
-- size, yaw, pitch, roll, alpha }. Pure: the tests check it never leaves the room and needs nothing but (t, eye).
function M.pose(ph, t, eye, room_min, room_max)
  local out = {}
  local p, s, sd = ph.pos, ph.size, ph.seed
  local k = ph.kind
  if k == "motes" then
    local top = room_max[2] - 2
    for i = 1, 14 do
      local rise = (t * (1.2 + h01(sd, i)) + h01(sd, i + 40) * (top - p[2] + 6)) % (top - room_min[2] - 1)
      local a = h01(sd, i + 80) * sm.tau + t * 0.2
      local rr = s * 0.4 * h01(sd, i + 120)
      out[#out + 1] = { pos = { p[1] + sm.cos(a) * rr, room_min[2] + 1 + rise, p[3] + sm.sin(a) * rr }, size = 0.9 + h01(sd, i) * 0.8,
                        alpha = 0.5 * (1 - rise / (top - room_min[2])) }
    end
  elseif k == "orbit" then
    for i = 1, 9 do
      local a = i / 9 * sm.tau + t * (0.25 + 0.1 * h01(sd, i)) * (i % 2 == 0 and 1 or -1)
      local rr = s * (0.35 + 0.25 * h01(sd, i + 9))
      local tilt = 0.4 * sm.sin(ph.phase + i)
      out[#out + 1] = { mesh = "shard", pos = { p[1] + sm.cos(a) * rr, p[2] + sm.sin(a) * rr * tilt, p[3] + sm.sin(a) * rr },
                        size = 1.5 + 2 * h01(sd, i + 18), yaw = -a, roll = 0.6 * sm.sin(t + i), pitch = 0 }
    end
    out[#out + 1] = { pos = p, size = s * 0.25, alpha = 0.15 + 0.1 * sm.sin(t * 0.7 + ph.phase) }
  elseif k == "eye" then
    local d = vec.dist(eye, p)
    local look = vec.sub(eye, p)
    local yaw = sm.atan2(look[1], look[3])
    local pitch = -sm.atan2(look[2], math.sqrt(look[1] ^ 2 + look[3] ^ 2))
    local near = math.max(0.15, math.min(1, (d - M.FADE) / M.FADE))
    out[#out + 1] = { mesh = "orb", pos = p, size = math.max(2.5, s * 0.15), yaw = yaw, pitch = pitch, roll = 0, alpha = near }
    out[#out + 1] = { pos = p, size = math.max(2.5, s * 0.15) * 3, alpha = 0.35 * near }
  elseif k == "procession" then
    local long = ph.long or 3
    local y = room_max[2] - 3
    local len = room_max[long] - room_min[long] - 8
    for i = 0, 4 do
      local q = ((t * 6 + i * len / 5) % len)
      local pos = { p[1], y, p[3] }
      pos[long] = room_min[long] + 4 + q
      out[#out + 1] = { pos = pos, size = 3.5, alpha = 0.55 * sm.sin(math.pi * q / len) }
    end
  elseif k == "breath" then
    local b = 0.5 + 0.5 * sm.sin(t * 0.45 + ph.phase)
    local r = math.max(3, s * 0.2) * (0.6 + 0.5 * b)
    local nrm = { 0, 0, 0 }
    for a = 1, 3, 2 do
      if math.abs(p[a] - room_min[a]) < 1 then nrm[a] = 1 elseif math.abs(p[a] - room_max[a]) < 1 then nrm[a] = -1 end
    end
    local pitch, roll = 0, 0
    if nrm[1] ~= 0 then roll = -nrm[1] * math.pi / 2 elseif nrm[3] ~= 0 then pitch = nrm[3] * math.pi / 2 end
    out[#out + 1] = { mesh = "sac", pos = p, size = r, yaw = 0, pitch = pitch, roll = roll }
  elseif k == "ripple" then
    local period = 7 + 4 * h01(sd, 1)
    for i = 0, 2 do
      local q = ((t + i * period / 3) % period) / period
      out[#out + 1] = { ring = true, pos = { p[1], room_min[2] + 0.6, p[3] }, size = s * (0.2 + 1.6 * q), alpha = 0.45 * (1 - q) }
    end
  elseif k == "shadow" then
    local long = ph.long or 3
    local far = { p[1], room_min[2] + 0.5 + s * 0.6, p[3] }
    far[long] = sd % 2 == 0 and room_min[long] + 6 or room_max[long] - 6
    local d = vec.dist(eye, far)
    local a = math.max(0, math.min(1, (d - M.FADE) / (M.FADE * 2)))
    out[#out + 1] = { dark = true, pos = far, size = s * 1.2, alpha = 0.7 * a }
  elseif k == "chimes" then
    local top = room_max[2] - 0.5
    for i = 1, 7 do
      local a = i / 7 * sm.tau + h01(sd, i)
      local rr = s * 0.3 * h01(sd, i + 7)
      local len = 4 + 8 * h01(sd, i + 14)
      out[#out + 1] = { mesh = "strand", pos = { p[1] + sm.cos(a) * rr, top, p[3] + sm.sin(a) * rr }, size = len,
                        yaw = a, pitch = 0.12 * sm.sin(t * 0.6 + i), roll = 0.12 * sm.cos(t * 0.5 + i * 1.7) }
    end
  end
  return out
end

-- draw one phenomenon in the room mn..mx (add-alien-cities-6: the megacity's warrens use this too)
function M.draw_one(v, A, ph, mn, mx, cam, t, palette)
  local ms = meshes()
  for _, o in ipairs(M.pose(ph, t, cam.pos, mn, mx)) do
    if o.mesh then
      v:mesh(ms[o.mesh], { pos = o.pos, scale = o.size, yaw = o.yaw or 0, pitch = o.pitch or 0, roll = o.roll or 0,
                           palette = palette })
    elseif o.dark then
      v:billboard(A.tex.glow, o.pos, o.size, { palette = palette, tint = { 0.02, 0.0, 0.03, o.alpha } })
    else
      v:billboard(A.tex.glow, o.pos, o.size, { palette = palette, tint = { 0.8, 0.5, 1.0, o.alpha or 0.5 } })
    end
  end
end

-- draw the phenomena of the rooms in `show` -> how many drew
function M.draw(v, A, ruin, show, cam, t, opts)
  local kit = require("sim.ruin").kit_of(ruin.kit)
  local n = 0
  for _, ph in ipairs(ruin.relic.phenomena or {}) do
    if show[ph.room] then
      local mn, mx = require("sim.ruin").room_box(ruin.rooms[ph.room], kit, ruin.origin)
      M.draw_one(v, A, ph, mn, mx, cam, t, opts.palette)
      n = n + 1
    end
  end
  return n
end

return M
