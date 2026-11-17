-- SPDX-License-Identifier: MIT
-- add-home-among-stars: the in-game mod browser. Lists every folder in mods/
-- (and the base game), shows whether each is loaded and why not, and switches
-- folders on or off for the next start (<user-dir>/mods.txt). The mod set is
-- part of the state hash, so nothing changes until the game starts again.
local panel = require("sim.panel")

local M = {}

local function available()
  local mods = saucer.mods and saucer.mods.available
  return mods and mods() or {}
end

local function label(m)
  local mark
  if m.id == "base" then mark = "[base]"
  elseif m.off then mark = m.loaded and "[on->off]" or "[off]"
  else mark = m.loaded and "[on]" or "[off->on]" end
  local why = ""
  if not m.loaded and not m.off and m.status ~= "switched off" then why = " - " .. m.status end
  return string.format("%s %s %s%s", mark, m.name, m.version, why)
end

-- the rows; pure (reads the mod folders, never the sim)
function M.rows(state, p, ctx)
  local rows = { { text = "Changes apply on the next start", enabled = false } }
  for _, m in ipairs(available()) do
    rows[#rows + 1] = {
      text = label(m),
      hint = m.description ~= "" and m.description or nil,
      enabled = m.id ~= "base",
      act = function(st, q)
        local on = m.off
        saucer.mods.set_enabled(m.id, on, q.index)
        ctx.msg(st, q, string.format("%s will be %s from the next start", m.name, on and "on" or "off"))
      end,
    }
  end
  rows[#rows + 1] = { text = "Close", act = function(_, q) panel.close(q) end }
  return rows
end

function M.register(ctx)
  panel.register("mods", { title = "MOD BROWSER", rows = function(state, p) return M.rows(state, p, ctx) end })
end

return M
