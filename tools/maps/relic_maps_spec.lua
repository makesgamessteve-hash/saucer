-- SPDX-License-Identifier: MIT
-- add-civ-dungeons: dump top-down maps of relics in every archetype (rooms as boxes) for tools/maps/relic_maps.py.
--   mkdir /tmp/m && cp tools/maps/relic_maps_spec.lua tests/lua/runner.lua /tmp/m/
--   SAUCER_MAPS_OUT=maps.txt saucer_headless --root . --test-lua /tmp/m && python3 tools/maps/relic_maps.py maps.txt maps.png
local civs = require("sim.civs")
local gen = require("sim.relicgen")
local ruinm = require("sim.ruin")
local relic = require("sim.relic")
describe("relic maps", function()
  it("dumps", function()
    local out = io.open(os.getenv("SAUCER_MAPS_OUT") or "relic_maps.txt", "w")
    local kit = ruinm.kit_of("relic")
    local base = civs.universe(42)[3]
    local list = { { "vyrr (warren)", relic.civ() } }
    for _, m in ipairs({ "organism", "lattice", "shell", "ring", "helix", "hive", "cluster", "spine" }) do
      list[#list + 1] = { m, setmetatable({ id = "map_" .. m, massing = m }, { __index = base }) }
    end
    for _, e in ipairs(list) do
      local r = gen.generate(42, kit, e[2], { 0, 0, 0 })
      out:write(string.format("relic %s rooms=%d halls=%d levels=%d chambers=%d\n", e[1], #r.rooms, #r.relic.halls,
        r.relic.levels, #r.relic.chambers))
      local main = {}
      for _, id in ipairs(r.relic.route or {}) do main[id] = true end
      for _, rm in ipairs(r.rooms) do
        local mn, mx = ruinm.room_box(rm, kit, { 0, 0, 0 })
        out:write(string.format("%s %d %.0f %.0f %.0f %.0f %.0f %.0f\n", rm.kind, main[rm.id] and 1 or 0, mn[1], mn[2], mn[3],
          mx[1], mx[2], mx[3]))
      end
    end
    out:close()
  end)
end)
