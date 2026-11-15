-- SPDX-License-Identifier: MIT
-- Central mystery (concept §5.6): a cause chosen from the universe seed and a
-- chain of three Echoes hidden in vaults. Modes: on, hints, off (sandbox).
local data = require("lib.data")
local M = {}

M.MODES = { "on", "hints", "off" }

local function fill(text, vars)
  return (text:gsub("{(%w+)}", function(k) return vars[k] or k end))
end

function M.generate(universe_seed, mode, nsites)
  local causes, names, civs = data.load("mystery/causes.lua"), data.load("mystery/names.lua"), data.load("civs/civs.lua")
  local rng = saucer.rng.new(saucer.seed_child(universe_seed, "mystery", 0))
  local cause = rng:pick(causes)
  local vars = { civ = rng:pick(civs).name, object = rng:pick(names.objects), place = rng:pick(names.places) }
  local m = { mode = mode or "on", cause = cause.id, title = cause.title, echoes = {}, solved = false, found = 0 }
  for i, text in ipairs(cause.echoes) do
    m.echoes[i] = { site = ((i - 1) % nsites) + 1, text = fill(text, vars), found_by = 0 }
  end
  return m
end

function M.active(m) return m.mode ~= "off" end

-- echo index placed at a site, if the chain has one there and it is unfound
function M.echo_at(m, site)
  if not M.active(m) then return nil end
  for i, e in ipairs(m.echoes) do
    if e.site == site and e.found_by == 0 then return i end
  end
  return nil
end

-- record an Echo; returns true when the chain completes
function M.found(m, idx, player)
  local e = m.echoes[idx]
  if not e or e.found_by ~= 0 then return false end
  e.found_by = player
  m.found = m.found + 1
  if m.found >= #m.echoes then m.solved = true end
  return m.solved
end

-- what a save keeps: the mode and who found which Echo (the text regenerates)
function M.progress(m)
  local out = { mode = m.mode, found = m.found, solved = m.solved, echoes = {} }
  for i, e in ipairs(m.echoes) do out.echoes[i] = { found_by = e.found_by, decoded = e.decoded or false } end
  return out
end

function M.restore(m, prog)
  if not prog then return m end
  m.mode, m.found, m.solved = prog.mode or m.mode, prog.found or 0, prog.solved or false
  for i, e in ipairs(m.echoes) do
    local pe = prog.echoes and prog.echoes[i]
    if pe then e.found_by, e.decoded = pe.found_by, pe.decoded end
  end
  return m
end

function M.next_mode(mode)
  for i, x in ipairs(M.MODES) do
    if x == mode then return M.MODES[i % #M.MODES + 1] end
  end
  return "on"
end

-- the hint line shown in "hints" mode
function M.hint(m)
  if m.mode ~= "hints" or m.solved then return nil end
  for _, e in ipairs(m.echoes) do
    if e.found_by == 0 then return "An Echo hums near site " .. e.site end
  end
  return nil
end

return M
