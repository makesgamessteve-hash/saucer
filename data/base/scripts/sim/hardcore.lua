-- SPDX-License-Identifier: MIT
-- Hardcore mode (OpenSpec add-home-among-stars, concept §8.4): opt-in for a
-- whole universe, chosen on the wake-up title card before anyone gets up (or
-- with --hardcore). Nothing becomes lethal; the stakes are your cargo:
--   * Fold Retreat loses every hot AND banked item in the hold for good (no
--     cache to come back for); modules, the dome and its displays are kept.
--   * The Lifeline loses what was in your hands for good.
--   * There is no loading from the bed: the save made when you sleep is the
--     only way back in (from the title card).
local M = {}

function M.on(state) return state.hardcore == true end

-- may the universe still switch? (only before anyone got up)
function M.can_choose(state)
  for _, p in ipairs(state.players) do
    if p.mode ~= "wake" then return false end
  end
  return true
end

function M.toggle(state, p, ctx)
  if not M.can_choose(state) then return false end
  state.hardcore = not M.on(state) or nil
  ctx.msg(state, p, M.on(state) and "HARDCORE: a Fold Retreat loses all cargo, the Lifeline loses your hands, no loading."
    or "Standard difficulty")
  return true
end

-- the items a Fold Retreat takes from p
function M.retreat_losses(state, p)
  if not M.on(state) then return require("sim.items").losable(p) end
  local out = {}
  for _, it in ipairs(p.hold) do
    if not it.echo and not it.unique and not (it.home and it.home.kind == "module") then out[#out + 1] = it end
  end
  return out
end

return M
