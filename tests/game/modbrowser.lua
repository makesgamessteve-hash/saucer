-- SPDX-License-Identifier: MIT
-- add-home-among-stars: the mod browser. Run twice with --mods-dir
-- tests/fixtures/mods and one fresh user dir (tools/mod_browser.cmake):
-- the first run switches Bigger Tractor off from the title card, the second
-- starts without it and switches it back on.
local T = saucer.test
local panel = require("sim.panel")
local config = require("sim.config")
local function P() return T.state().players[1] end
local function by_id()
  local r = {}
  for _, m in ipairs(saucer.mods.available()) do r[m.id] = m end
  return r
end
local function pick(prefix)
  for _ = 1, 40 do
    local p = P()
    T.assert(p.panel, "a panel is open for " .. prefix)
    local want = panel.find(T.state(), p, prefix)
    T.assert(want, "row " .. prefix .. " in " .. tostring(p.panel.kind))
    if p.panel.sel == want then
      T.press(1, "use")
      T.wait(2)
      return
    end
    T.axis(1, "move_z", -1, 1, true)
    T.wait(1)
    T.axis(1, "move_z", 0, 1, true)
    T.wait(1)
  end
  T.assert(false, "could not reach " .. prefix)
end

local m = by_id()
T.assert(m.base and m.base.loaded, "the base game is listed")
T.assert(m.bad_api and not m.bad_api.loaded and m.bad_api.status:find("API"), "a broken mod shows why")
T.assert(m.holo_garden.description:find("holodeck"), "descriptions come from mod.lua")
T.wait(5)
T.assert(P().panel and P().panel.kind == "title", "the title card")
pick("Mod browser")
T.assert(P().panel.kind == "mods", "the browser opens from the title card")
local rows = panel.rows(T.state(), P())
T.assert(rows[1].enabled == false and rows[1].text:find("next start"), "it says when changes apply")
if not m.bigger_tractor.off then
  -- first run: loaded, switch it off for the next start
  T.assert(m.bigger_tractor.loaded and config.get(2).tractor_range == 30, "Bigger Tractor is on")
  pick("[on] Bigger Tractor")
  local now = by_id().bigger_tractor
  T.assert(now.off and now.loaded, "off from the next start, still loaded now")
  T.assert(P().msgs[#P().msgs].text:find("off from the next start"), "the browser says so")
  T.assert(panel.find(T.state(), P(), "[on->off] Bigger Tractor"), "the row shows the pending change")

else
  -- second run: started without it; switch it back on
  T.assert(not m.bigger_tractor.loaded and m.bigger_tractor.status == "switched off", "it stayed off")
  T.assert(config.get(2).tractor_range ~= 30, "the base tractor is back")
  T.assert(m.holo_garden.loaded, "the other mods still load")
  pick("[off] Bigger Tractor")
  T.assert(not by_id().bigger_tractor.off, "on again from the next start")
  T.assert(panel.find(T.state(), P(), "[off->on] Bigger Tractor"), "pending on")
  T.assert(not panel.rows(T.state(), P())[2].enabled or panel.rows(T.state(), P())[2].text:find("base"),
    "the base game cannot be switched off")

end
pick("Close")
T.assert(not P().panel, "closed")
