-- SPDX-License-Identifier: MIT
-- add-civ-dungeons: dump top-down maps of relics in every archetype (rooms as boxes) for tools/maps/relic_maps.py.
--   mkdir /tmp/m && cp tools/maps/relic_maps_spec.lua tests/lua/runner.lua /tmp/m/
--   SAUCER_MAPS_OUT=maps.txt saucer_headless --root . --test-lua /tmp/m && python3 tools/maps/relic_maps.py maps.txt maps.png
-- relic-room-shapes: a shaped hall also dumps its free floor (runs on a 2 m grid) and its contour, so the map draws
-- the shape. SAUCER_MAPS_MASSING=ring (and SAUCER_MAPS_SEEDS=1,2,3,...) dumps one archetype at several seeds instead:
-- the same species' stations side by side.
local civs = require("sim.civs")
local gen = require("sim.relicgen")
local ruinm = require("sim.ruin")
local relic = require("sim.relic")
local shapes = require("sim.relicshape")
describe("relic maps", function()
  it("dumps", function()
    local out = io.open(os.getenv("SAUCER_MAPS_OUT") or "relic_maps.txt", "w")
    local kit = ruinm.kit_of("relic")
    local base = civs.universe(42)[3]
    local list = {}
    local one = os.getenv("SAUCER_MAPS_MASSING")
    if one then
      for sd in (os.getenv("SAUCER_MAPS_SEEDS") or "42,43,44,45,46,47"):gmatch("-?%d+") do
        list[#list + 1] = { one .. " seed " .. sd, setmetatable({ id = "map_" .. one, massing = one }, { __index = base }),
                            tonumber(sd) }
      end
    else
      list[1] = { "vyrr (warren)", relic.civ(), 42 }
      for _, m in ipairs({ "organism", "lattice", "shell", "ring", "helix", "hive", "cluster", "spine" }) do
        list[#list + 1] = { m, setmetatable({ id = "map_" .. m, massing = m }, { __index = base }), 42 }
      end
    end
    for _, e in ipairs(list) do
      local r = gen.generate(e[3], kit, e[2], { 0, 0, 0 })
      out:write(string.format("relic %s rooms=%d halls=%d levels=%d chambers=%d\n", e[1], #r.rooms, #r.relic.halls,
        r.relic.levels, #r.relic.chambers))
      local main = {}
      for _, id in ipairs(r.relic.route or {}) do main[id] = true end
      for _, rm in ipairs(r.rooms) do
        local mn, mx = ruinm.room_box(rm, kit, { 0, 0, 0 })
        out:write(string.format("%s %d %.0f %.0f %.0f %.0f %.0f %.0f\n", rm.kind, main[rm.id] and 1 or 0, mn[1], mn[2], mn[3],
          mx[1], mx[2], mx[3]))
        local s = rm.shape
        if s then
          local st, c = shapes.STEP, kit.cell
          for z = s.z0 + st / 2, s.z1, st do
            local x, run = s.x0 + st / 2, nil
            while x < s.x1 do
              local f = shapes.free(s, x, z)
              if f and not run then run = x end
              if not f and run then
                out:write(string.format("run %.1f %.1f %.1f %.1f\n", (run - st / 2) * c, (z - st / 2) * c, (x - st / 2) * c, (z + st / 2) * c))
                run = nil
              end
              x = x + st
            end
            if run then
              out:write(string.format("run %.1f %.1f %.1f %.1f\n", (run - st / 2) * c, (z - st / 2) * c, s.x1 * c, (z + st / 2) * c))
            end
          end
          for _, g in ipairs(shapes.contour(s)) do
            out:write(string.format("seg %.1f %.1f %.1f %.1f\n", g[1] * c, g[2] * c, g[3] * c, g[4] * c))
          end
        end
      end
    end
    out:close()
  end)
end)
