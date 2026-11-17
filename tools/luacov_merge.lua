-- SPDX-License-Identifier: MIT
-- Merge luacov stats files: lua5.4 tools/luacov_merge.lua OUT IN1 IN2 ...
local stats = require("luacov.stats")
local out = assert(arg[1], "usage: luacov_merge.lua OUT IN...")
local all = {}
for i = 2, #arg do
  local d = stats.load(arg[i])
  assert(d, "cannot read " .. arg[i])
  for name, f in pairs(d) do
    local m = all[name]
    if not m then
      m = { max = 0, max_hits = 0 }
      all[name] = m
    end
    if f.max > m.max then m.max = f.max end
    for l = 1, f.max do
      local h = f[l]
      if h and h > 0 then
        m[l] = (m[l] or 0) + h
        if m[l] > m.max_hits then m.max_hits = m[l] end
      end
    end
  end
end
stats.save(out, all)
