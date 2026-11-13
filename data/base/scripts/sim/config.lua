-- SPDX-License-Identifier: MIT
-- Access to saucer size configurations (data/base/saucer/configs.lua).
local data = require("lib.data")
local M = {}

function M.all() return data.load("saucer/configs.lua") end
function M.get(i) return M.all()[i] end
function M.count() return #M.all() end
function M.by_id(id)
  for i, c in ipairs(M.all()) do
    if c.id == id then return i, c end
  end
  return nil
end

return M
