-- SPDX-License-Identifier: MIT
-- A holodeck program from a mod: raked gravel, three stones and a bench.
return {
  id = "zen_garden", name = "Zen Garden", kind = "relax", order = 15, source = "starter",
  desc = "Raked gravel and quiet stones.",
  look = { sky = { 0.75, 0.8, 0.85 }, fog = { 0.75, 0.8, 0.85 }, density = 0.02, light = { 0.3, 0.8, 0.4 }, ambient = 0.8 },
  props = function(ctx)
    local S = ctx.size
    return {
      { kind = "plane", at = { 0, 0 }, w = S * 2, d = S * 2, color = { 0.82, 0.8, 0.74 } },
      { kind = "rock", at = { -1.5, 1.5 }, r = 0.8, solid = 0.8 },
      { kind = "rock", at = { 1.8, 0.5 }, r = 0.5 },
      { kind = "rock", at = { 0.4, 2.6 }, r = 0.6 },
      { kind = "bench", at = { 0, -1 }, yaw = 0, solid = 0.5 },
    }
  end,
  spots = function()
    return { { id = "bench", at = { 0, -1.8 }, radius = 1.2, label = "USE: SIT AND BREATHE",
      act = function(api)
        api.buff("calm", 3)
        api.msg("You sit by the raked gravel and breathe.")
      end } }
  end,
}
