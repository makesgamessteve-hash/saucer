-- SPDX-License-Identifier: MIT
-- add-wider-dark: procedural music. Render-side only (reads the state, never
-- writes it). Each civilization has a scale, a root, a tempo and a voice
-- (data/base/civs); this plays short phrases in them from four code-made
-- notes (tools/artpipe/artpipe.py), pitched with saucer.audio.play's pitch.
-- Stems: "space" (sparse pad over the sector's first civ), "site" (the site
-- civ's voice over a bass line) and "alert" (a faster pulse when a sentry
-- is on you). Phrases come from a hash of the civ, the bar and the beat, so
-- the same place always sounds the same.
local civs = require("sim.civs")
local M = {}

local S = "authored/sounds/"
M.NOTES = { pluck = S .. "note_pluck.wav", bell = S .. "note_bell.wav", pad = S .. "note_pad.wav", bass = S .. "note_bass.wav" }
M.SCALES = {
  dorian = { 0, 2, 3, 5, 7, 9, 10 }, pentatonic = { 0, 2, 4, 7, 9 }, phrygian = { 0, 1, 3, 5, 7, 8, 10 },
  lydian = { 0, 2, 4, 6, 7, 9, 11 }, whole = { 0, 2, 4, 6, 8, 10 }, minor = { 0, 2, 3, 5, 7, 8, 10 },
}
M.VOLUME = 0.22
M.enabled = true

local last = {} -- per player: the last beat index played

-- deterministic 0..1 from integers
local function hash(a, b, c)
  local h = (a * 73856093 ~ b * 19349663 ~ c * 83492791) & 0x7fffffff
  h = (h ~ (h >> 13)) * 1274126177 & 0x7fffffff
  return (h % 10007) / 10007
end
M.hash = hash

-- semitones -> playback rate
function M.ratio(semi) return 2 ^ (semi / 12) end

-- which stem fits this player right now, and the civ it speaks in
function M.stem(state, p)
  local sector = state.sector
  local civ
  if (p.site or 0) ~= 0 and sector and sector.sites[p.site] then
    civ = civs.of(state, sector.sites[p.site])
    local alarm = require("view.hud").alarm(state, p)
    if alarm then return "alert", civ end
    return "site", civ
  end
  local g = require("sim.galaxy").sector(state.seed, state.sector_id or 1)
  civ = g and civs.get(state.seed, g.civs[1]) or nil
  return "space", civ
end

-- the notes to play on beat n of a stem -> list of { file, pitch, volume }
function M.notes(stem, civ, n)
  local mu = civ and civ.music or { scale = "pentatonic", root = 0, tempo = 72, voice = "pad" }
  local scale = M.SCALES[mu.scale] or M.SCALES.pentatonic
  local cid = civ and #civ.id or 1
  local bar, beat = n // 8, n % 8
  local out = {}
  local function deg(k, oct)
    local i = math.floor(k) % #scale
    return M.ratio(mu.root + scale[i + 1] + 12 * (oct or 0) - 12)
  end
  if stem == "space" then
    -- a slow pad chord on the bar, a lone high note now and then
    if beat == 0 then
      local d = math.floor(hash(cid, bar, 1) * #scale)
      out[#out + 1] = { M.NOTES.pad, deg(d), 0.7 }
      out[#out + 1] = { M.NOTES.pad, deg(d + 2), 0.5 }
    elseif hash(cid, bar, beat) > 0.82 then
      out[#out + 1] = { M.NOTES[mu.voice] or M.NOTES.bell, deg(hash(cid, bar, beat + 9) * 7, 1), 0.35 }
    end
  elseif stem == "site" then
    if beat % 4 == 0 then out[#out + 1] = { M.NOTES.bass, deg(hash(cid, bar, 2) * 3) * 2, 0.7 } end
    if hash(cid, bar * 8 + beat, 3) > 0.45 then
      out[#out + 1] = { M.NOTES[mu.voice] or M.NOTES.pluck, deg(hash(cid, bar, beat) * 7), 0.55 }
    end
  else -- alert: a pulse on every beat, a dissonant flick on the off beats
    out[#out + 1] = { M.NOTES.bass, deg(0) * 2, 0.8 }
    if beat % 2 == 1 then out[#out + 1] = { M.NOTES.pluck, deg(1, 1) * M.ratio(1), 0.5 } end
  end
  return out
end

-- the beat clock: tempo in beats a minute (alert runs at double time)
function M.beat(state, stem, civ)
  local tempo = civ and civ.music and civ.music.tempo or 72
  if stem == "alert" then tempo = tempo * 2 end
  return (state.tick * tempo) // (60 * 60) -- ticks are 1/60 s
end

-- once per frame for a player's own view -> notes queued
function M.update(state, p)
  if not M.enabled or p.mode == "wake" or p.holo_run then return 0 end
  local stem, civ = M.stem(state, p)
  local n = M.beat(state, stem, civ)
  local key = p.index
  if last[key] == n then return 0 end
  local first = last[key] == nil
  last[key] = n
  if first then return 0 end
  local played = 0
  for _, note in ipairs(M.notes(stem, civ, n)) do
    saucer.audio.play(note[1], { volume = M.VOLUME * note[3], pitch = note[2] })
    played = played + 1
  end
  return played
end

function M.reset() for k in pairs(last) do last[k] = nil end end

return M
