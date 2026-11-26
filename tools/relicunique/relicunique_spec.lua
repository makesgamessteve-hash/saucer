-- SPDX-License-Identifier: MIT
-- relic-room-shapes: dump the layout signatures (sim/relicsig.lua) of many relics of one species, for
-- tools/relicunique/relicunique.py (pairwise distances in bulk; tests/lua/relicunique_spec.lua checks fewer in-game).
--   mkdir /tmp/u && cp tools/relicunique/relicunique_spec.lua tests/lua/runner.lua /tmp/u/
--   SAUCER_UNIQUE_MASSING=ring SAUCER_UNIQUE_SEEDS=300 SAUCER_UNIQUE_OUT=ring.txt saucer_headless --root . --test-lua /tmp/u
--   python3 tools/relicunique/relicunique.py ring.txt [more.txt ...]
-- SAUCER_UNIQUE_CHAIN=1 draws them as stations of one species in one universe: each kept unlike all the ones before
-- it (relicgen.unlike, as sim/sector.lua's siblings do in play) -- the guarantee, at a few hundred stations.
local civs = require("sim.civs")
local gen = require("sim.relicgen")
local ruinm = require("sim.ruin")
local sig = require("sim.relicsig")
describe("relic signatures", function()
  it("dumps", function()
    local m = os.getenv("SAUCER_UNIQUE_MASSING") or "ring"
    local n = tonumber(os.getenv("SAUCER_UNIQUE_SEEDS") or "20")
    local out = io.open(os.getenv("SAUCER_UNIQUE_OUT") or "relic_sigs.txt", "w")
    local kit = ruinm.kit_of("relic")
    local base = civs.universe(42)[3]
    local civ = setmetatable({ id = "uniq_" .. m, massing = m }, { __index = base })
    out:write(string.format("species %s N %d PX %d\n", m, sig.N, sig.PX))
    local chain = os.getenv("SAUCER_UNIQUE_CHAIN") == "1"
    local before, tries, worst = {}, 0, 1
    for s = 1, n do
      local seed = saucer.seed_child(9001, m, s)
      local r
      if chain then
        local d, a
        r, d, a = gen.unlike(seed, kit, civ, { 0, 0, 0 }, before)
        before[#before + 1] = { sig = sig.signature(r) }   -- (only its signature: a few hundred ruins are heavy)
        tries, worst = tries + a, math.min(worst, d)
      else
        r = gen.generate(seed, kit, civ, { 0, 0, 0 })
      end
      local g = sig.signature(r)
      local idx = {}
      for k in pairs(g.set) do idx[#idx + 1] = k end
      table.sort(idx)
      out:write(string.format("relic %d %s\n", seed, table.concat(idx, " ")))
    end
    if chain then out:write(string.format("# chain extra tries %d, nearest kept %.3f\n", tries, worst)) end
    out:close()
  end)
end)
