-- SPDX-License-Identifier: MIT
-- Central mystery (concept §5.6): a cause chosen from the universe seed and a
-- chain of three Echoes, Who -> Where -> Key. Each Echo waits in the vault of
-- its host site once the previous one has been decoded at the lab bench.
-- Decoding Who marks the Where site Resonant; decoding Where marks the Key
-- site and reveals the Resonant vault in open space. Carrying the Key to the
-- vault opens it: a unique Curio and a teaser. Modes: on, hints, off (sandbox).
--
-- add-wider-dark (the full mystery): opening the vault is Act I. The signal
-- then continues beyond the fold. Act II: a Witness Echo waits in the next
-- sector of the galaxy's spine; it only translates once someone's
-- Xenoarchive holds a quarter of its civ (the translation gate). Decoding it
-- names the Heart sector and puts the Heart Key in the sector before it.
-- Act III: whoever carries the Heart Key to the core of the Heart site opens
-- the Heart; the players present vote on one of the cause's endings (a tie
-- goes to whoever inserted the Key). The ending changes the universe (see
-- M.effect) and everyone present gets the centerpiece.
local data = require("lib.data")
local M = {}

M.MODES = { "on", "hints", "off" }
M.ROLES = { "who", "where", "key", "witness", "heart_key" }
M.CARRIERS = { who = "glyph tablet", where = "star chart", key = "key fragment", witness = "witness record",
               heart_key = "heart key" }
M.GATE = 25 -- Xenoarchive percent of the Witness civ needed to translate it
M.DEFAULT_ENDINGS = {
  { id = "seal", title = "Seal it", text = "The Heart goes quiet. Sentries everywhere grow drowsy." },
  { id = "restore", title = "Restore it", text = "The {civ} song returns. Their relics are prized again." },
  { id = "take", title = "Take it", text = "You carry the Heart's core away. The dark wakes, restless." },
}
-- what each ending changes in the universe (multipliers other systems read)
M.EFFECTS = {
  seal = { watcher_range = 0.8, snatcher_sense = 0.8 },
  restore = { civ_price = 1.5, request_pay = 1.5 },
  take = { watcher_range = 1.15, centerpiece = 2 },
}
M.TEASER = "The signal continues beyond the fold."

local function fill(text, vars)
  return (text:gsub("{(%w+)}", function(k) return vars[k] or k end))
end

function M.generate(universe_seed, mode, nsites, galaxy)
  local causes, names, civs = data.load("mystery/causes.lua"), data.load("mystery/names.lua"), data.load("civs/civs.lua")
  local rng = saucer.rng.new(saucer.seed_child(universe_seed, "mystery", 0))
  local cause = rng:pick(causes)
  local vars = { civ = rng:pick(civs).name, object = rng:pick(names.objects), place = rng:pick(names.places) }
  local m = { mode = mode or "on", cause = cause.id, title = cause.title, echoes = {}, solved = false, found = 0,
              vars = vars, -- add-holodeck-home-life: books and holodeck memories use the names
              curio = cause.curio or ("Resonant " .. vars.object), vault_revealed = false, vault_open = false }
  for i, text in ipairs(cause.echoes) do
    local role = M.ROLES[i] or "key"
    m.echoes[i] = { site = ((i - 1) % nsites) + 1, text = fill(text, vars), found_by = 0, decoded = false,
                    role = role, carrier = M.CARRIERS[role], sector = 1 }
  end
  -- add-wider-dark: Acts II and III follow the galaxy's spine (own child seed,
  -- so Act I above is exactly what it always was)
  m.act, m.votes, m.heart_open, m.last_key_by, m.ending = 1, {}, false, 0, false
  m.endings = {}
  for i, e in ipairs(cause.endings or M.DEFAULT_ENDINGS) do
    m.endings[i] = { id = e.id, title = e.title, text = fill(e.text, vars) }
  end
  if galaxy and #galaxy.spine >= 4 then
    local r2 = saucer.rng.new(saucer.seed_child(universe_seed, "mystery", 1))
    local s2, s3 = galaxy.spine[2], galaxy.spine[3]
    m.heart_sector = galaxy.spine[#galaxy.spine]
    local w = cause.witness or "Witness: the {civ} who watched it wrote it down. The Heart beats in the far dark."
    local k = cause.heart_key or "The Heart Key: it was cut to fit one lock, at the core of the Heart."
    m.echoes[#m.echoes + 1] = { site = r2:int(1, 3), sector = s2, text = fill(w, vars), found_by = 0,
      decoded = false, role = "witness", carrier = M.CARRIERS.witness, gate = M.GATE }
    m.echoes[#m.echoes + 1] = { site = r2:int(1, 3), sector = s3, text = fill(k, vars), found_by = 0,
      decoded = false, role = "heart_key", carrier = M.CARRIERS.heart_key }
  end
  return m
end

function M.index_of(m, role)
  for i, e in ipairs(m.echoes) do if e.role == role then return i end end
  return nil
end

function M.active(m) return m.mode ~= "off" end

-- is Echo i ready to be found (its predecessor decoded)?
function M.unlocked(m, i)
  if not M.active(m) then return false end
  local e = m.echoes[i]
  -- add-wider-dark: the Witness waits until the vault has been opened
  if e and e.role == "witness" then return m.vault_open or false end
  return i == 1 or (m.echoes[i - 1] and m.echoes[i - 1].decoded) or false
end

-- echo index placed at a site of sector sid (default home), if the chain has
-- one there that can be found now
function M.echo_at(m, site, sid)
  if not M.active(m) then return nil end
  for i, e in ipairs(m.echoes) do
    if e.site == site and (e.sector or 1) == (sid or 1) and e.found_by == 0 and M.unlocked(m, i) then return i end
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
  return e ~= nil and e.role ~= "key" and e.role ~= "heart_key" and not e.decoded
end

-- decode an Echo at the lab bench -> its text
function M.decode(m, idx)
  local e = m.echoes[idx]
  if not M.decodable(m, idx) then return nil end
  e.decoded = true
  if e.role == "where" then m.vault_revealed = true end
  if e.role == "witness" then m.act = 3 end
  return e.text
end

-- sites with a Resonant marker: hosts of Echoes that are unlocked but not
-- found yet, in sector sid (default home)
function M.resonant_sites(m, sid)
  local out = {}
  if not M.active(m) then return out end
  for i, e in ipairs(m.echoes) do
    if i > 1 and e.found_by == 0 and M.unlocked(m, i) and (e.sector or 1) == (sid or 1) then out[#out + 1] = e.site end
  end
  return out
end

-- add-wider-dark: sectors the sector map marks Resonant (an Echo waits there,
-- or the Heart once the Witness has named it)
function M.resonant_sectors(m)
  local out = {}
  if not M.active(m) then return out end
  for i, e in ipairs(m.echoes) do
    if e.found_by == 0 and M.unlocked(m, i) then out[e.sector or 1] = true end
  end
  if m.heart_sector and m.act >= 3 and not m.ending then out[m.heart_sector] = true end
  return out
end

-- the Witness's translation gate: any present player's Xenoarchive at GATE% of its civ
function M.gate_civ(m, idx) return m.echoes[idx] and m.echoes[idx].gate_civ or nil end

-- the Heart Key opens the Heart: voting starts
function M.open_heart(m, by)
  if m.heart_open or m.act < 3 then return false end
  m.heart_open, m.last_key_by, m.votes = true, by, {}
  return true
end

function M.vote(m, player, ending_id)
  if not m.heart_open or m.ending then return false end
  for _, e in ipairs(m.endings) do
    if e.id == ending_id then
      m.votes[tostring(player)] = ending_id
      return true
    end
  end
  return false
end

-- tally the votes of the players present -> ending id (nil until all voted)
function M.tally(m, present)
  if #present == 0 then return nil end
  local count = {}
  for _, pi in ipairs(present) do
    local v = m.votes[tostring(pi)]
    if not v then return nil end
    count[v] = (count[v] or 0) + 1
  end
  local best, bn, tie = nil, -1, false
  for _, e in ipairs(m.endings) do
    local n = count[e.id] or 0
    if n > bn then best, bn, tie = e.id, n, false elseif n == bn and n > 0 then tie = true end
  end
  if tie then
    -- a tie goes to whoever inserted the Key, if they voted for a tied ending
    local kv = m.votes[tostring(m.last_key_by)]
    if kv and count[kv] == bn then return kv end
  end
  return best
end

function M.ending_of(m, id)
  for _, e in ipairs(m.endings) do if e.id == id then return e end end
  return nil
end

function M.finish(m, id)
  if m.ending then return false end
  m.ending = id
  m.act = 4
  return true
end

-- a universe-state multiplier from the chosen ending (1 when none applies)
function M.effect(m, key)
  local fx = m and m.ending and M.EFFECTS[m.ending]
  return fx and fx[key] or 1
end

-- the centerpiece everyone present at the Heart gets
function M.centerpiece(m)
  return { type = "heart_centerpiece", name = "Heart of the " .. m.vars.object, size = 1,
           value = 400 * M.effect(m, "centerpiece"), rarity = "relic", category = "curio", ident = true, unique = true }
end

-- the Key opens the vault: the chain is solved
function M.open_vault(m)
  if m.vault_open or not m.vault_revealed then return false end
  m.vault_open = true
  m.solved = true
  if m.act < 2 then m.act = 2 end
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
                vault_open = m.vault_open, echoes = {}, act = m.act, heart_open = m.heart_open,
                last_key_by = m.last_key_by, ending = m.ending, votes = {} }
  for k, v in pairs(m.votes or {}) do out.votes[k] = v end
  for i, e in ipairs(m.echoes) do out.echoes[i] = { found_by = e.found_by, decoded = e.decoded or false } end
  return out
end

function M.restore(m, prog)
  if not prog then return m end
  m.mode, m.found, m.solved = prog.mode or m.mode, prog.found or 0, prog.solved or false
  m.vault_revealed, m.vault_open = prog.vault_revealed or false, prog.vault_open or false
  m.act, m.heart_open, m.last_key_by = prog.act or m.act, prog.heart_open or false, prog.last_key_by or 0
  m.ending = prog.ending or false
  m.votes = {}
  for k, v in pairs(prog.votes or {}) do m.votes[k] = v end
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
  if m.mode ~= "hints" or m.ending then return nil end
  for i, e in ipairs(m.echoes) do
    if not M.unlocked(m, i) and e.found_by == 0 then break end
    if e.found_by == 0 then
      if (e.sector or 1) ~= 1 then return string.format("An Echo hums near site %d of sector %d", e.site, e.sector) end
      return "An Echo hums near site " .. e.site
    end
    if M.decodable(m, i) then return "Decode Echo " .. i .. " at your lab bench" end
    if e.role == "key" and not m.vault_open then return "Carry the Key to the Resonant vault" end
  end
  if m.heart_open then return "Vote on an ending at the Heart's core" end
  if m.act >= 3 then return "Carry the Heart Key to the core of the Heart" end
  if m.vault_open then return nil end
  return "Carry the Key to the Resonant vault"
end

return M
