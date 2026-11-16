-- SPDX-License-Identifier: MIT
-- Holodeck program: a warm beach at sunset. A starter program (relax).
-- Lie back in the deck chair to unwind: Calm for ten minutes.
local function props(ctx)
  local S, rng, out = ctx.size, ctx.rng, {}
  out[#out + 1] = { kind = "plane", at = { 0, -S * 2 }, w = S * 8, d = S * 6, color = { 0.86, 0.76, 0.55 } }
  out[#out + 1] = { kind = "water", at = { 0, S * 4.2 }, w = S * 40, d = S * 6, color = { 0.12, 0.42, 0.62 } }
  out[#out + 1] = { kind = "plane", at = { 0, S * 1.12 }, w = S * 8, d = 0.5, y = 0.01, color = { 0.95, 0.95, 0.92 } }
  out[#out + 1] = { kind = "sun", at = { 0, S * 30 }, y = S * 2.2, r = S * 4, color = { 1, 0.7, 0.35, 1 } }
  -- palms along the dunes, more of them with a better detail lattice
  local n = 3 + 3 * ctx.detail
  for k = 1, n do
    local x = -S * 0.85 + (k - 1) * (1.7 * S) / math.max(1, n - 1) + rng:float() * 0.8 - 0.4
    local z = -S * 0.55 + rng:float() * S * 0.5
    if math.abs(x) > 1.6 or z > -S * 0.1 then
      out[#out + 1] = { kind = "palm", at = { x, z }, h = 4 + rng:float() * 2, yaw = rng:float() * 6.28, lean = 0.2 + rng:float() * 0.15,
                        spin = rng:float(), solid = 0.35 }
    end
  end
  for _ = 1, 2 + 2 * ctx.detail do
    out[#out + 1] = { kind = "rock", at = { -S * 0.9 + rng:float() * S * 1.8, S * 0.55 + rng:float() * S * 0.35 },
                      r = 0.4 + rng:float() * 0.6 }
  end
  out[#out + 1] = { kind = "umbrella", at = { 1.6, 0.6 }, color = { 0.95, 0.4, 0.3 }, solid = 0.1 }
  out[#out + 1] = { kind = "deckchair", at = { 0.6, 0.9 }, yaw = 3.1416, color = { 0.2, 0.55, 0.85 }, solid = 0.4 }
  out[#out + 1] = { kind = "towel", at = { 2.6, 1.0 }, yaw = 0.3 }
  if ctx.detail >= 2 then out[#out + 1] = { kind = "deckchair", at = { 2.2, 2.0 }, yaw = 2.8, color = { 0.9, 0.8, 0.3 }, solid = 0.4 } end
  return out
end

return {
  id = "beach", name = "Sunset Beach", kind = "relax", order = 10, source = "starter",
  desc = "Warm sand, slow waves and a deck chair facing the sun.",
  look = { sky = { 0.98, 0.62, 0.42 }, fog = { 0.98, 0.66, 0.46 }, density = 0.012, light = { -0.2, 0.5, 0.8 }, ambient = 0.7 },
  props = props,
  spots = function()
    return { { id = "chair", at = { 0.6, 0.2 }, radius = 1.3, label = "USE: LIE BACK IN THE DECK CHAIR",
      act = function(api)
        api.buff("calm", 10)
        api.p.holo.relaxed = (api.p.holo.relaxed or 0) + 1
        api.msg("You lie back and listen to the waves. Calm: Scanner and Jammer recharge faster.")
        api.fx("bank")
      end } }
  end,
}
