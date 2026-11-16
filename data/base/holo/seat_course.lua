-- SPDX-License-Identifier: MIT
-- Holodeck program: Seat flight training. You sit in a simulated Seat and
-- fly through a ring course; the holodeck compresses the course into the
-- space it has (scale). The first clear pays a small training bonus.
local function gates(ctx)
  local S = ctx.size
  local out = {}
  local pts = { { 0, 0.45, -0.35 }, { 0.5, 0.6, 0.0 }, { 0.55, 0.3, 0.55 }, { 0, 0.85, 0.75 }, { -0.55, 0.5, 0.45 },
                { -0.6, 0.2, -0.1 }, { -0.2, 0.7, -0.6 } }
  for _, q in ipairs(pts) do out[#out + 1] = { q[1] * S, 1.2 + q[2] * S, q[3] * S, r = 1.6 } end
  return out
end

return {
  id = "seat_course", name = "Seat Flight Course", kind = "training", order = 30, source = "starter", mode = "fly",
  scale = 2,
  desc = "Fly a simulated Seat through seven rings against the clock.",
  look = { sky = { 0.03, 0.03, 0.06 }, fog = { 0.03, 0.03, 0.06 }, density = 0.004, light = { 0.3, 0.8, 0.4 }, ambient = 0.8,
           stars = true },
  gates = gates,
  props = function(ctx)
    local out = { { kind = "plane", at = { 0, 0 }, w = ctx.size * 2, d = ctx.size * 2, color = { 0.05, 0.05, 0.08 } } }
    for i, g in ipairs(gates(ctx)) do
      local nxt = gates(ctx)[i + 1] or g
      out[#out + 1] = { kind = "ring", at = { g[1], g[3] }, y = g[2], r = g.r, yaw = saucer.math.atan2(nxt[1] - g[1], nxt[3] - g[3]) }
    end
    return out
  end,
  finish = function(api, seconds, first)
    if first then
      api.credit(25)
      api.msg("Training bonus: 25 c. Your best time is saved on the holodeck.")
    end
  end,
}
