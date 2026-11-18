-- SPDX-License-Identifier: MIT
-- Saucer modules (OpenSpec add-items-identification-tractor 1.2, gameplay gaps). A Module item
-- (a Coil, a Fold Shard) installs into one of M.SLOTS saucer slots at the lab bench. Installed
-- modules live in p.modules (plain data, saved with the player; nil until the first install, so a
-- saucer that never fits one is unchanged). Effects reach the ship through ship.mods / drain / loud
-- (see sim/ship.lua), refreshed here whenever a module goes in, comes out or is identified:
--   * an IDENTIFIED module's affixes apply (shield regen, Charge regen, max Charge, scan reach, turn);
--   * a module's QUIRK applies at once, identified or not (concept 5.5): Unstable drains Charge, Loud
--     is heard from farther, Bonded cannot be taken out again; the HUD says "Unknown effect" until
--     the lab bench has identified the module.
local items = require("sim.items")
local M = {}

M.SLOTS = 2
M.DRAIN = 0.8 -- Charge per second per Unstable module

function M.list(p) return p.modules or {} end

function M.find(p, uid)
  for i, it in ipairs(p.modules or {}) do
    if it.uid == uid then return it, i end
  end
  return nil
end

-- is this item one a saucer can take?
function M.installable(it)
  return it ~= nil and it.category == "module" and not it.echo and not it.unique and not it.home
end

-- the unidentified modules in the saucer (their effects are a surprise)
function M.unknown(p)
  for _, it in ipairs(p.modules or {}) do
    if not it.ident then return true end
  end
  return false
end

-- recompute ship.mods / ship.drain / ship.loud from what is installed
function M.refresh(p)
  local mods, drain, loud = {}, 0, 0
  for _, it in ipairs(p.modules or {}) do
    if it.ident then
      for _, a in ipairs(it.affixes or {}) do mods[a.stat] = (mods[a.stat] or 0) + a.value end
    end
    if it.quirk == "unstable" then drain = drain + M.DRAIN end
    if it.quirk == "loud" then loud = loud + 1 end
  end
  p.ship.mods = next(mods) and mods or nil
  p.ship.drain = drain > 0 and drain or nil
  p.ship.loud = loud > 0 and loud or nil
end

-- install(state, p, uid, ctx) -> ok, why ("gone", "not a module", "full")
function M.install(state, p, uid, ctx)
  local it, i = items.find(p, uid)
  if not it then return false, "gone" end
  if not M.installable(it) then return false, "not a module" end
  p.modules = p.modules or {}
  if #p.modules >= M.SLOTS then return false, "full" end
  table.remove(p.hold, i)
  it.hot = false -- fitted to the hull: a Snatcher or a Fold Retreat cannot take it
  p.modules[#p.modules + 1] = it
  M.refresh(p)
  if ctx then
    if it.ident then
      ctx.msg(state, p, "Installed " .. it.name .. M.effects(it))
    else
      ctx.msg(state, p, "Installed " .. items.label(it) .. ": Unknown effect" .. (it.quirk and " - something is wrong with it" or ""))
    end
    ctx.fx(state, p, "grow")
  end
  return true
end

-- remove(state, p, uid, ctx, hold_slots) -> ok, why ("gone", "bonded", "hold full")
function M.remove(state, p, uid, ctx)
  local it, i = M.find(p, uid)
  if not it then return false, "gone" end
  if it.quirk == "bonded" then
    it.ident = true -- trying to pull it out shows what it is
    M.refresh(p)
    return false, "bonded"
  end
  if #p.hold >= require("sim.upgrades").hold_slots(p) then return false, "hold full" end
  table.remove(p.modules, i)
  if #p.modules == 0 then p.modules = nil end
  p.hold[#p.hold + 1] = it
  M.refresh(p)
  if ctx then ctx.msg(state, p, "Removed " .. items.label(it) .. " from the saucer") end
  return true
end

-- "(+20% shield regen, -0.8 CHG/s)" for a known module
local STAT = { shield_regen = "shield regen", charge_regen = "Charge regen", scan_range = "scan reach",
               max_charge = "max Charge", turn = "turn rate" }
function M.effects(it)
  local parts = {}
  for _, a in ipairs(it.affixes or {}) do parts[#parts + 1] = string.format("+%d%% %s", a.value, STAT[a.stat] or a.stat) end
  if it.quirk then parts[#parts + 1] = it.quirk end
  if #parts == 0 then return "" end
  return " (" .. table.concat(parts, ", ") .. ")"
end

-- the HUD line: nil when nothing is installed
function M.line(p)
  local list = p.modules
  if not list or #list == 0 then return nil end
  if M.unknown(p) then return string.format("MOD %d/%d UNKNOWN EFFECT", #list, M.SLOTS) end
  return string.format("MOD %d/%d", #list, M.SLOTS)
end

return M
