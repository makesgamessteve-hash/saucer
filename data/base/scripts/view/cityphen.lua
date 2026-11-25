-- SPDX-License-Identifier: MIT
-- add-alien-cities (plan phase 10, design civs-and-relics §4.3): the city's strange, harmless goings-on, the relic
-- phenomena (view/phenomena.lua) scaled up to a city. Placed from the city's plan (a pure function of the ruin) and
-- drawn as a function of the clock and the eye only: they never touch the state, never collide and never hurt.
--   swarm    a cloud of motes wheeling over a district's avenue, parting round the saucer
--   machine  a ring and two arms cycling on a district's tallest tower, turning for no reason anyone knows
--   pulse    lights running along a sky lane from one district to the next, one after another
local vec = require("lib.vec")
local sm = saucer.math
local M = {}

M.SWARM_MOTES = 18
M.SWARM_HEIGHT = 48     -- m over the district's ground
M.SWARM_RADIUS = 70     -- m: the loop it wheels round
M.PART = 22             -- m: motes keep this far from the eye
M.PULSES = 4            -- per lane at a time
M.PULSE_SPEED = 90      -- m/s
M.SWARM_DIST, M.MACHINE_DIST, M.PULSE_DIST = 900, 2500, 3500

local function h01(seed, k) return ((seed * 7919 + k * 104729) % 1000) / 1000 end

-- the phenomena of a city ruin (cached per ruin): -> list
local placed = setmetatable({}, { __mode = "k" })
function M.place(ruin)
  local c = placed[ruin]
  if c then return c end
  c = {}
  local city = ruin.city
  local tall = {}
  for _, s in ipairs(ruin.solids or {}) do
    if s.kind == "tower" and s.apex and not s.outer then
      local t = tall[s.district]
      if not t or s[2][2] > t[2][2] then tall[s.district] = s end
    end
  end
  for _, d in ipairs(city.districts or {}) do
    local seed = (ruin.seed or 1) % 100000 + d.id * 131
    c[#c + 1] = { kind = "swarm", pos = { d.pos[1], d.pos[2] + M.SWARM_HEIGHT, d.pos[3] }, seed = seed, district = d.id }
    local s = tall[d.id]
    if s then
      c[#c + 1] = { kind = "machine", pos = { (s[1][1] + s[2][1]) / 2, s[2][2] + 6, (s[1][3] + s[2][3]) / 2 },
                    size = math.max(8, math.min(s[2][1] - s[1][1], s[2][3] - s[1][3]) * 0.6), seed = seed + 7, district = d.id }
    end
  end
  for i, l in ipairs(city.lanes or {}) do
    c[#c + 1] = { kind = "pulse", a = l.a, b = l.b, seed = (ruin.seed or 1) % 100000 + i * 17, lane = i }
  end
  placed[ruin] = c
  return c
end

-- the parts of one phenomenon at time t for the eye at `eye`: -> list of { pos, size, alpha, ring, yaw, pitch }
function M.pose(ph, t, eye)
  local out = {}
  local sd = ph.seed
  if ph.kind == "swarm" then
    local p = ph.pos
    for i = 1, M.SWARM_MOTES do
      local a = h01(sd, i) * sm.tau + t * (0.12 + 0.08 * h01(sd, i + 20))
      local r = M.SWARM_RADIUS * (0.5 + 0.5 * h01(sd, i + 40))
      local q = { p[1] + sm.cos(a) * r, p[2] + 10 * sm.sin(t * 0.3 + i), p[3] + sm.sin(a * 2) * r * 0.5 }
      local d = vec.sub(q, eye)
      local dl = vec.len(d)
      if dl < M.PART then   -- part round the saucer
        if dl < 1e-3 then d, dl = { 0, 1, 0 }, 1 end
        q = vec.add(eye, vec.scale(d, M.PART / dl))
      end
      out[#out + 1] = { pos = q, size = 2.2 + 1.5 * h01(sd, i + 60), alpha = 0.55 }
    end
  elseif ph.kind == "machine" then
    local p, s = ph.pos, ph.size
    local cyc = (t / (9 + 6 * h01(sd, 1))) % 1        -- a cycle: rise, turn, fall, rest
    local lift = cyc < 0.25 and cyc * 4 or cyc < 0.5 and 1 or cyc < 0.75 and (0.75 - cyc) * 4 or 0
    local yaw = t * 0.4 + sd
    out[#out + 1] = { ring = true, pos = { p[1], p[2] + lift * s * 0.5, p[3] }, size = s, yaw = yaw, pitch = 0.3 * lift, alpha = 0.8 }
    for k = 0, 1 do
      local a = yaw * (k == 0 and 1 or -1.3) + k * math.pi
      out[#out + 1] = { pos = { p[1] + sm.cos(a) * s * 0.7, p[2] + s * 0.3 * lift, p[3] + sm.sin(a) * s * 0.7 }, size = 3.5,
                        alpha = 0.4 + 0.5 * lift }
    end
  elseif ph.kind == "pulse" then
    local len = vec.dist(ph.a, ph.b)
    if len > 1 then
      for i = 0, M.PULSES - 1 do
        local q = ((t * M.PULSE_SPEED + i * len / M.PULSES + h01(sd, i) * 40) % len) / len
        out[#out + 1] = { pos = vec.add(ph.a, vec.scale(vec.sub(ph.b, ph.a), q)),
                          size = 6, alpha = 0.7 * sm.sin(math.pi * q) }
      end
    end
  end
  return out
end

local function near(ph, eye)
  if ph.kind == "pulse" then
    local mid = vec.scale(vec.add(ph.a, ph.b), 0.5)
    return vec.dist(mid, eye) < M.PULSE_DIST + vec.dist(ph.a, ph.b) / 2
  end
  return vec.dist(ph.pos, eye) < (ph.kind == "swarm" and M.SWARM_DIST or M.MACHINE_DIST)
end
M.near = near

-- the machine's ring (built once)
local ring
function M.ring_mesh()
  if not ring then
    local matv = require("view.materials")
    ring = saucer.mesh.build({ parts = {
      { kind = "ring", c = { 0, 0, 0 }, rin = 0.86, r = 1.0, h = 0.08, seg = 24, color = matv.base_color("chrome"), mat = matv.SLOT.accent,
        emissive = 0.6 } } })
  end
  return ring
end

-- draw the phenomena of city ruin r -> how many drew
function M.draw(v, A, r, cam, t)
  local ring_mesh = M.ring_mesh()
  local acc = r.city.style and r.city.style.accent or { 0.8, 0.9, 1.0 }
  local win = r.city.style and r.city.style.window or acc
  local n = 0
  for _, ph in ipairs(M.place(r)) do
    if near(ph, cam.pos) then
      for _, o in ipairs(M.pose(ph, t, cam.pos)) do
        if o.ring then
          v:mesh(ring_mesh, { pos = o.pos, scale = o.size, yaw = o.yaw, pitch = o.pitch, roll = 0, palette = A.pal.base,
                              tint = { acc[1], acc[2], acc[3], 1 } })
        else
          local c = ph.kind == "pulse" and win or acc
          v:billboard(A.tex.glow, o.pos, o.size, { palette = A.pal.base, tint = { c[1], c[2], c[3], o.alpha or 0.5 } })
        end
      end
      n = n + 1
    end
  end
  return n
end

return M
