-- SPDX-License-Identifier: MIT
-- Defines the base actions and binds the defaults for every local player.
-- Idempotent: actions/bindings that already exist are left alone.
local data = require("lib.data")
local M = {}

local function bind_all(p, list, existing)
  local bad = 0
  for _, name in ipairs(list.order) do
    if #(existing[name] or {}) == 0 then
      for _, b in ipairs(list.map[name]) do
        if not saucer.input.bind(p, name, b) then bad = bad + 1 end
      end
    end
  end
  return bad
end

function M.setup(players)
  local def = data.load("input/default.lua")
  for _, name in ipairs(def.axis_order) do saucer.input.define_action(name, "axis") end
  for _, name in ipairs(def.button_order) do saucer.input.define_action(name, "button") end
  local bad = 0
  for p = 1, players do
    local existing = saucer.input.bindings(p)
    bad = bad + bind_all(p, { order = def.axis_order, map = def.axes }, existing)
    bad = bad + bind_all(p, { order = def.button_order, map = def.buttons }, existing)
  end
  if bad > 0 then saucer.log.warn(bad .. " default bindings were rejected") end
  return bad
end

return M
