-- SPDX-License-Identifier: MIT
local data = require("lib.data")
local M = {}

function M.setup(players)
  local def = data.load("input/default.lua")
  for _, name in ipairs(def.axis_order) do saucer.input.define_action(name, "axis") end
  for _, name in ipairs(def.button_order) do saucer.input.define_action(name, "button") end
  local bad = 0
  for p = 1, players do
    for _, name in ipairs(def.axis_order) do
      for _, b in ipairs(def.axes[name]) do
        if not saucer.input.bind(p, name, b) then bad = bad + 1 end
      end
    end
    for _, name in ipairs(def.button_order) do
      for _, b in ipairs(def.buttons[name]) do
        if not saucer.input.bind(p, name, b) then bad = bad + 1 end
      end
    end
  end
  if bad > 0 then saucer.log.warn(bad .. " default bindings were rejected") end
  return bad
end

return M
