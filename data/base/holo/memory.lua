-- SPDX-License-Identifier: MIT
-- Holodeck program: a recreated alien place, decoded from a data core found
-- in the tutorial derelict's vault (recreation). Touching the memory at its
-- heart replays what the builders saw: it points at the site where the
-- mystery's next Echo waits, and the transcript goes onto your bookshelf.
local function civ_color(ctx)
  local v = ctx.state.mystery.vars or {}
  if v.civ == "Oquun" then return { 0.45, 0.75, 0.4 }, { 0.9, 1, 0.5 } end
  return { 0.42, 0.45, 0.62 }, { 0.4, 1, 0.9 }
end

return {
  id = "memory", name = "Resonant Memory", kind = "recreation", order = 50, source = "loot",
  desc = "A place the builders remembered, rebuilt from a data core.",
  look = { sky = { 0.2, 0.12, 0.3 }, fog = { 0.24, 0.14, 0.32 }, density = 0.025, light = { 0.2, 0.9, 0.3 }, ambient = 0.6,
           stars = true },
  props = function(ctx)
    local S, rng = ctx.size, ctx.rng
    local stone, glow = civ_color(ctx)
    local out = { { kind = "plane", at = { 0, 0 }, w = S * 8, d = S * 8, color = { 0.18, 0.16, 0.22 } },
                  { kind = "plane", at = { 0, 0 }, w = S * 1.2, d = S * 1.2, y = 0.02, color = { 0.28, 0.26, 0.34 } } }
    local n = 6 + 2 * ctx.detail
    for k = 0, n - 1 do
      local a = (k + 0.5) * 6.2832 / n
      out[#out + 1] = { kind = "pillar", at = { saucer.math.sin(a) * S * 0.7, saucer.math.cos(a) * S * 0.7 }, h = 3 + (k % 2) * 1.5, r = 0.35,
                        color = stone, glow = glow, solid = 0.4 }
    end
    for k = 0, 11 do
      local a = k * 6.2832 / 12 + 0.2
      out[#out + 1] = { kind = "tower", at = { saucer.math.sin(a) * S * 3, saucer.math.cos(a) * S * 3 }, h = 14 + rng:float() * 16, w = 3,
                        color = stone, glow = glow }
    end
    for _ = 1, 3 * ctx.detail do
      out[#out + 1] = { kind = "crystal", at = { -S * 0.6 + rng:float() * S * 1.2, -S * 0.6 + rng:float() * S * 1.2 },
                        h = 0.6 + rng:float(), color = glow, yaw = rng:float() * 6.28 }
    end
    out[#out + 1] = { kind = "obelisk", at = { 0, 0.8 }, h = 4.5, color = { 0.14, 0.14, 0.2 }, glow = glow, solid = 0.9 }
    out[#out + 1] = { kind = "glyph", at = { 0, 0.8 }, y = 5.8, r = 0.9, color = { glow[1], glow[2], glow[3], 0.9 } }
    return out
  end,
  spots = function()
    return { { id = "memory", at = { 0, -0.7 }, radius = 1.2, label = "USE: TOUCH THE MEMORY",
      act = function(api)
        local m = api.state.mystery
        if m.mode == "off" then
          api.msg("The memory is quiet. (Sandbox mode: no mystery.)")
          return
        end
        local site = require("sim.books").next_echo_site(m)
        api.lead(site)
        local new = api.shelve("memory")
        local v = m.vars or {}
        api.msg(string.format("The %s remember the %s: the next voice of the %s waits at site %d.", v.civ or "builders",
          v.place or "garden", v.object or "relic", site))
        if new then api.msg("The memory's transcript is on your bookshelf.") end
        api.p.holo.memories = (api.p.holo.memories or 0) + 1
        api.fx("echo")
      end } }
  end,
}
