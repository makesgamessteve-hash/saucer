-- SPDX-License-Identifier: MIT
-- Holodeck program: replay of a derelict you explored. The site stands on a
-- plinth as a hologram; a little saucer flies your recorded route through it
-- and green motes mark where you beamed something up (replay).
local function visited(p)
  local out = {}
  for i = 1, 16 do
    local t = p.trails and p.trails[tostring(i)]
    if t and #t.pts > 0 then out[#out + 1] = i end
  end
  return out
end

return {
  id = "replay", name = "Derelict Replay", kind = "replay", order = 40, source = "starter",
  desc = "Walk around a hologram of a derelict you explored and watch your route.",
  look = { sky = { 0.02, 0.03, 0.05 }, fog = { 0.02, 0.03, 0.05 }, density = 0.01, light = { 0.3, 0.8, 0.4 }, ambient = 0.7 },
  needs = function(state, p)
    if #visited(p) == 0 then return false, "explore a derelict first" end
    return true
  end,
  options = function(state, p)
    local out = {}
    for _, i in ipairs(visited(p)) do
      out[#out + 1] = { label = string.format("site %d (%s)", i, state.sector.sites[i].kit), arg = i }
    end
    return out
  end,
  props = function(ctx)
    local S = ctx.size
    return {
      { kind = "plane", at = { 0, 0 }, w = S * 2, d = S * 2, color = { 0.04, 0.05, 0.07 } },
      { kind = "plinth", at = { 0, 0.5 }, r = math.min(2.6, S * 0.4), h = 0.9, solid = math.min(2.6, S * 0.4) },
      { kind = "ruin_model", site = ctx.arg, at = { 0, 0.5 }, y = 0.95, fit = math.min(8, S * 1.1) },
    }
  end,
  spots = function(ctx)
    return { { id = "plinth", at = { 0, -math.min(2.6, ctx.size * 0.4) - 0.2 }, radius = 1.2, label = "USE: READ THE REPLAY LOG",
      act = function(api)
        local site = api.run.arg
        local t = api.p.trails[tostring(site)]
        local d = 0
        for i = 2, #t.pts do
          local a, b = t.pts[i - 1], t.pts[i]
          d = d + math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
        end
        api.msg(string.format("Replay of site %d: %d m flown inside, %d things beamed up.", site, math.floor(d), #t.marks))
        api.p.holo.replays = (api.p.holo.replays or 0) + 1
      end } }
  end,
}
