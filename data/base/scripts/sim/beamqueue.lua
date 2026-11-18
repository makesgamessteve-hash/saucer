-- SPDX-License-Identifier: MIT
-- The Tractor Room target queue (OpenSpec add-tractor-beam, gameplay gaps). Press the
-- beam key on a find that is not in lock yet and it joins a short queue; whenever a queued
-- find comes into lock and whoever is there may pull it (the console in the Tractor Room for
-- any size, the helm for what the relay lifts), the beam takes it by itself. So an L or XL
-- find can be lined up from the helm and the console, then left to the beam. Plain data in
-- p.beam_queue = { site = n, keys = { "<candidate key>", ... } }; transient (never saved) and
-- dropped when the site changes or the saucer folds.
local tractor = require("sim.tractor")
local M = {}

M.MAX = 4

function M.keys(p)
  local q = p.beam_queue
  return q and q.keys or {}
end

function M.clear(p) p.beam_queue = nil end

function M.has(p, key)
  for _, k in ipairs(M.keys(p)) do if k == key then return true end end
  return false
end

-- a queue belongs to one site; a different site (or a fold) throws it away
function M.sync(p)
  local q = p.beam_queue
  if q and (q.site ~= p.site or p.ship.morph) then p.beam_queue = nil end
end

-- toggle(p, key, name) -> "added", "removed" or "full" (the name is what the HUD shows)
function M.toggle(p, key, name)
  M.sync(p)
  local q = p.beam_queue
  if q then
    for i, k in ipairs(q.keys) do
      if k == key then
        table.remove(q.keys, i)
        if #q.keys == 0 then p.beam_queue = nil end
        return "removed"
      end
    end
    if #q.keys >= M.MAX then return "full" end
  else
    q = { site = p.site, keys = {}, names = {} }
    p.beam_queue = q
  end
  q.keys[#q.keys + 1] = key
  q.names[key] = name or key
  return "added"
end

function M.remove(p, key)
  local q = p.beam_queue
  if not q then return end
  for i, k in ipairs(q.keys) do
    if k == key then table.remove(q.keys, i) break end
  end
  if #q.keys == 0 then p.beam_queue = nil end
end

-- next(state, p, ruin, heading, may) -> cand, info for the first queued find that is in lock
-- and that `may(cand)` lets this seat pull; queued finds that are gone are dropped.
function M.next(state, p, ruin, heading, may)
  M.sync(p)
  local q = p.beam_queue
  if not q then return nil end
  local i = 1
  while q.keys[i] do
    local cand = tractor.by_key(state, p, p.site, ruin, q.keys[i])
    if not cand then
      table.remove(q.keys, i)
    else
      local st, info = tractor.check(p.ship, cand, heading)
      if st == "lock" and may(cand) then return cand, info end
      i = i + 1
    end
  end
  if #q.keys == 0 then p.beam_queue = nil end
  return nil
end

-- the HUD line: "BEAM QUEUE 2: Hull Plate, Unknown Velari Module T1"
function M.line(p)
  local names = {}
  for _, k in ipairs(M.keys(p)) do names[#names + 1] = p.beam_queue.names[k] or k end
  if #names == 0 then return nil end
  return string.format("BEAM QUEUE %d: %s", #names, table.concat(names, ", "))
end

return M
