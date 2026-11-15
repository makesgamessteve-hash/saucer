-- SPDX-License-Identifier: MIT
-- Central mystery (concept §5.6): a cause chosen from the universe seed and a
-- chain of three Echoes, Who -> Where -> Key. Each Echo waits in the vault of
-- its host site once the previous one has been decoded at the lab bench.
-- Decoding Who marks the Where site Resonant; decoding Where marks the Key
-- site and reveals the Resonant vault in open space. Carrying the Key to the
-- vault opens it: a unique Curio and a teaser. Modes: on, hints, off (sandbox).
local data = require("lib.data")
local M = {}

M.MODES = { "on", "hints", "off" }
M.ROLES = { "who", "where", "key" }
M.CARRIERS = { who = "glyph tablet", where = "star chart", key = "key fragment" }
M.TEASER = "The signal continues beyond the fold."

local function fill(text, vars)
  return (text:gsub("{(%w+)}", function(k) return vars[k] or k end))
end

function M.generate(universe_seed, mode, nsites)
  local causes, names, civs = data.load("mystery/causes.lua"), data.load("mystery/names.lua"), data.load("civs/civs.lua")
  local rng = saucer.rng.new(saucer.seed_child(universe_seed, "mystery", 0))
  local cause = rng:pick(causes)
  local vars = { civ = rng:pick(civs).name, object = rng:pick(names.objects), place = rng:pick(names.places) }
  local m = { mode = mode or "on", cause = cause.id, title = cause.title, echoes = {}, solved = false, found = 0,
              curio = cause.curio or ("Resonant " .. vars.object), vault_revealed = false, vault_open = false }
  for i, text in ipairs(cause.echoes) do
    local role = M.ROLES[i] or "key"
    m.echoes[i] = { site = ((i - 1) % nsites) + 1, text = fill(text, vars), found_by = 0, decoded = false,
                    role = role, carrier = M.CARRIERS[role] }
  end
  return m
end

function M.active(m) return m.mode ~= "off" end

-- is Echo i ready to be found (its predecessor decoded)?
function M.unlocked(m, i)
  if not M.active(m) then return false end
  return i == 1 or (m.echoes[i - 1] and m.echoes[i - 1].decoded) or false
end

-- echo index placed at a site, if the chain has one there that can be found now
function M.echo_at(m, site)
  if not M.active(m) then return nil end
  for i, e in ipairs(m.echoes) do
    if e.site == site and e.found_by == 0 and M.unlocked(m, i) then return i end
  end
  return nil
end

-- record an Echo; returns true when every Echo has been found
function M.found(m, idx, player)
  local e = m.echoes[idx]
  if not e or e.found_by ~= 0 then return false end
  e.found_by = player
  m.found = m.found + 1
  return m.found >= #m.echoes
end

-- the hold item an Echo becomes (never sold, never lost)
function M.item(m, idx)
  local e = m.echoes[idx]
  return { type = "echo", echo = idx, size = 1, value = 0, rarity = "relic", category = "echo", ident = true,
           name = string.format("Echo %s: %s", ({ "I", "II", "III", "IV", "V" })[idx] or idx, e.carrier) }
end

function M.decodable(m, idx)
  local e = m.echoes[idx]
  return e ~= nil and e.role ~= "key" and not e.decoded
end

-- decode an Echo at the lab bench -> its text
function M.decode(m, idx)
  local e = m.echoes[idx]
  if not M.decodable(m, idx) then return nil end
  e.decoded = true
  if e.role == "where" then m.vault_revealed = true end
  return e.text
end

-- sites with a Resonant marker: hosts of Echoes that are unlocked but not found yet
function M.resonant_sites(m)
  local out = {}
  if not M.active(m) then return out end
  for i, e in ipairs(m.echoes) do
    if i > 1 and e.found_by == 0 and M.unlocked(m, i) then out[#out + 1] = e.site end
  end
  return out
end

-- the Key opens the vault: the chain is solved
function M.open_vault(m)
  if m.vault_open or not m.vault_revealed then return false end
  m.vault_open = true
  m.solved = true
  return true
end

-- the unique Curio inside the vault
function M.curio(m)
  return { type = "resonant_curio", name = m.curio, size = 1, value = 0, rarity = "relic", category = "curio",
           ident = true, unique = true }
end

-- what a save keeps: the mode and who found and decoded which Echo (the text regenerates)
function M.progress(m)
  local out = { mode = m.mode, found = m.found, solved = m.solved, vault_revealed = m.vault_revealed,
                vault_open = m.vault_open, echoes = {} }
  for i, e in ipairs(m.echoes) do out.echoes[i] = { found_by = e.found_by, decoded = e.decoded or false } end
  return out
end

function M.restore(m, prog)
  if not prog then return m end
  m.mode, m.found, m.solved = prog.mode or m.mode, prog.found or 0, prog.solved or false
  m.vault_revealed, m.vault_open = prog.vault_revealed or false, prog.vault_open or false
  for i, e in ipairs(m.echoes) do
    local pe = prog.echoes and prog.echoes[i]
    if pe then e.found_by, e.decoded = pe.found_by, pe.decoded or false end
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
  for i, e in ipairs(m.echoes) do
    if e.found_by == 0 then
      return "An Echo hums near site " .. e.site
    end
    if M.decodable(m, i) then return "Decode Echo " .. i .. " at your lab bench" end
  end
  return "Carry the Key to the Resonant vault"
end

return M
