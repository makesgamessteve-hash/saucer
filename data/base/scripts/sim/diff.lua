-- SPDX-License-Identifier: MIT
-- Table diffs for saves (spec save-system, "Seed plus diffs"): diff(base, cur)
-- is nil when cur equals base, else a small patch holding only what changed;
-- patch(base, p) rebuilds cur from base. Keyed tables merge key by key;
-- sequences (arrays) and plain values are replaced whole. Patches are plain
-- data (nested {v=}, {d=, x=} nodes) so saucer.save can store them.
local M = {}

local function copy(v)
  if type(v) ~= "table" then return v end
  local r = {}
  for k, x in pairs(v) do r[k] = copy(x) end
  return r
end
M.copy = copy

local function is_array(t) return t[1] ~= nil end

function M.equal(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do if not M.equal(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

function M.diff(base, cur)
  if M.equal(base, cur) then return nil end
  if type(base) ~= "table" or type(cur) ~= "table" or is_array(base) or is_array(cur) then return { v = copy(cur) } end
  local d, x = {}, {}
  for k, v in pairs(cur) do
    local sub = M.diff(base[k], v)
    if sub then d[k] = sub end
  end
  for k in pairs(base) do
    if cur[k] == nil then x[#x + 1] = k end
  end
  table.sort(x, function(a, b) return tostring(a) < tostring(b) end)
  local node = {}
  if next(d) then node.d = d end
  if #x > 0 then node.x = x end
  return node
end

function M.patch(base, p)
  if p == nil then return copy(base) end
  if p.v ~= nil then return copy(p.v) end
  local out = type(base) == "table" and copy(base) or {}
  for k, sub in pairs(p.d or {}) do out[k] = M.patch(out[k], sub) end
  for _, k in ipairs(p.x or {}) do out[k] = nil end
  return out
end

-- number of values a patch carries (for size comparisons in tests and logs)
function M.size(p)
  if type(p) ~= "table" then return 1 end
  local n = 0
  for _, v in pairs(p) do n = n + M.size(v) end
  return n
end

return M
