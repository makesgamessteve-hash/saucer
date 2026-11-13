-- SPDX-License-Identifier: MIT
-- Loads data files (Lua tables) through the VFS so mods can override them.
local M = {}
local cache = {}

function M.load(path)
  local v = cache[path]
  if v ~= nil then return v end
  local src = saucer.vfs.read(path)
  if not src then error("data file not found: " .. path, 2) end
  local fn, err = load(src, "=" .. path)
  if not fn then error(err, 2) end
  v = fn()
  cache[path] = v
  return v
end

function M.clear() cache = {} end

return M
