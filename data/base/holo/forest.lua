-- SPDX-License-Identifier: MIT
-- Holodeck program: a quiet forest at dusk with a stream and fireflies. Sold
-- by traders, or found as a data core in a city vault (relax).
local function props(ctx)
  local S, rng, out = ctx.size, ctx.rng, {}
  out[#out + 1] = { kind = "plane", at = { 0, 0 }, w = S * 10, d = S * 10, color = { 0.22, 0.34, 0.18 } }
  out[#out + 1] = { kind = "stream", at = { S * 0.45, 0 }, w = 1.6, d = S * 10, yaw = 0.2 }
  local n = 6 + 6 * ctx.detail
  for k = 1, n do
    local a, d = rng:float() * 6.283, S * (0.35 + rng:float() * 0.6)
    local x, z = saucer.math.sin(a) * d, saucer.math.cos(a) * d
    if math.abs(x - S * 0.45) > 1.4 and not (math.abs(x) < 2 and z < -S * 0.4) then
      if k % 3 == 0 then out[#out + 1] = { kind = "tree", at = { x, z }, h = 4 + rng:float() * 3, solid = 0.3 }
      else out[#out + 1] = { kind = "pine", at = { x, z }, h = 5 + rng:float() * 4, solid = 0.3 } end
    end
  end
  -- far ring of pines past the edge of the space
  for k = 0, 15 do
    local a = k * 6.283 / 16
    out[#out + 1] = { kind = "pine", at = { saucer.math.sin(a) * S * 2.2, saucer.math.cos(a) * S * 2.2 }, h = 9 + (k % 3) * 2 }
  end
  for _ = 1, 4 * ctx.detail do
    out[#out + 1] = { kind = "bush", at = { -S * 0.8 + rng:float() * S * 1.6, -S * 0.8 + rng:float() * S * 1.6 }, r = 0.5 }
    out[#out + 1] = { kind = "flower", at = { -S * 0.8 + rng:float() * S * 1.6, -S * 0.8 + rng:float() * S * 1.6 },
                      color = { 1, 0.6 + rng:float() * 0.3, 0.4 } }
  end
  for k = 1, 3 + ctx.detail * 2 do
    out[#out + 1] = { kind = "glyph", at = { -S * 0.7 + rng:float() * S * 1.4, -S * 0.7 + rng:float() * S * 1.4 },
                      y = 1 + rng:float() * 1.5, r = 0.25, color = { 0.9, 1, 0.5, 0.9 } }
  end
  out[#out + 1] = { kind = "log", at = { -0.8, 1.0 }, yaw = 1.2, solid = 0.6 }
  out[#out + 1] = { kind = "lantern", at = { 0.4, 1.8 }, h = 1.2 }
  return out
end

return {
  id = "forest", name = "Quiet Forest", kind = "relax", order = 20, source = "trader",
  desc = "Pines, a stream and fireflies at dusk.",
  look = { sky = { 0.18, 0.22, 0.36 }, fog = { 0.16, 0.2, 0.3 }, density = 0.03, light = { 0.3, 0.7, 0.2 }, ambient = 0.55,
           stars = true },
  props = props,
  spots = function()
    return { { id = "log", at = { -0.4, 0.2 }, radius = 1.3, label = "USE: SIT ON THE MOSSY LOG",
      act = function(api)
        api.buff("calm", 15)
        api.p.holo.relaxed = (api.p.holo.relaxed or 0) + 1
        api.msg("You sit on the log and listen to the stream. Calm for a while.")
        api.fx("bank")
      end } }
  end,
}
