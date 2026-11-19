-- SPDX-License-Identifier: MIT
-- The story of a run (OpenSpec add-run-story). The universe seed picks one
-- plot skeleton (story/skeletons.lua) with 4-6 beats, fills it from the run's
-- own generated parts (the civilisation of the central mystery, a second
-- civilisation, the mystery's object and place, what the Echo really is, who
-- betrayed whom, an optional twist from story/twists.lua) and binds every
-- beat to a real place: a wreck log or mural in a derelict hall of the home
-- sector or a far one, or an archive record in a body city (readable only
-- once the district's grid is back). Each beat's text ends with a lead to the
-- next beat's place, so the clues chain; the last beat is the finale, told
-- when the Heart is resolved, one text per ending.
--
-- The story sits beside the central mystery, not instead of it: its cast
-- (civ, object, place) is the mystery's, the finale is the mystery's ending,
-- and it is off with the mystery ("off": the endless sandbox). Nothing here
-- is needed to finish the game.
--
-- Everything generated is a pure function of the universe seed (own child
-- seed, no clock, no player input), so co-op peers agree and a save keeps
-- only progress (M.progress / M.restore). Text comes from templates and the
-- civs' trait words (story/vocab.lua); there is no runtime generator beyond
-- that.
local data = require("lib.data")
local M = {}

M.MODES = { "on", "off" }

local function fill(text, vars)
  return (text:gsub("{([%w_]+)}", function(k) return vars[k] ~= nil and tostring(vars[k]) or ("{" .. k .. "}") end))
end
M.fill = fill

function M.vocab() return data.load("story/vocab.lua") end
function M.skeletons() return data.load("story/skeletons.lua") end
function M.twists() return data.load("story/twists.lua") end

-- a civ's trait words as template variables: prefix "a" or "b"
local function civ_vars(vars, prefix, civ, V)
  vars[prefix] = civ.name
  vars[prefix .. "_epithet"] = V.epithet[civ.temperament] or civ.temperament
  vars[prefix .. "_craft"] = V.craft[civ.domains and civ.domains[1] or "fold"] or "builders"
  vars[prefix .. "_home"] = V.home[civ.shape] or civ.shape
  vars[prefix .. "_fate"] = V.fate[civ.fate] or civ.fate
  vars[prefix .. "_body"] = V.body[civ.body] or civ.body
end

local function pick_by(list, pred)
  local out = {}
  for _, x in ipairs(list) do if pred(x) then out[#out + 1] = x end end
  return out
end

-- where a place is called in prose
local function loc_label(V, civ, sec_name, site, sid)
  if site.city then
    local body = (site.kit or ""):gsub("^city_", "")
    return string.format("the %s %s city in %s", civ.name, V.bodies[body] or body, sec_name)
  end
  if site.heart then return "the Heart, site " .. site.id end
  return string.format("the %s %s at site %d in %s", civ.name, V.kits[site.kit] or site.kit, site.id, sec_name)
end

-- generate(universe_seed, mystery, galaxy) -> the story table (nil without a mystery)
function M.generate(seed, m, galaxy)
  if not m then return nil end
  local civs, sectorm = require("sim.civs"), require("sim.sector")
  local V, S, TW = M.vocab(), M.skeletons(), M.twists()
  local rng = saucer.rng.new(saucer.seed_child(seed, "story", 0))
  local universe = civs.universe(seed)
  local vars = { object = m.vars.object, place = m.vars.place, guardians = V.guardians }

  -- skeleton: any that fits the mystery's cause
  local fits = pick_by(S.skeletons, function(sk)
    if not sk.causes then return true end
    for _, c in ipairs(sk.causes) do if c == m.cause then return true end end
    return false
  end)
  if #fits == 0 then fits = S.skeletons end
  local sk = rng:pick(fits)

  -- cast: A is the mystery's civilisation, B another one
  local ai = 1
  for i, c in ipairs(universe) do if c.name == m.vars.civ then ai = i break end end
  local bi = rng:int(1, #universe - 1)
  if bi >= ai then bi = bi + 1 end
  civ_vars(vars, "a", universe[ai], V)
  civ_vars(vars, "b", universe[bi], V)
  local echo = rng:pick(V.echo)
  vars.echo = echo.text
  local a_betrays = rng:int(1, 2) == 1
  vars.betrayer, vars.betrayed = a_betrays and vars.a or vars.b, a_betrays and vars.b or vars.a

  -- twist: most runs have one that fits the skeleton
  local twist = false
  if rng:int(1, 100) <= 80 then
    local ok = pick_by(TW, function(t)
      if not t.skeletons then return true end
      for _, id in ipairs(t.skeletons) do if id == sk.id then return true end end
      return false
    end)
    if #ok > 0 then twist = rng:pick(ok) end
  end

  -- places: the sectors beats can live in
  local spine = galaxy and galaxy.spine or { 1 }
  local far1, far2 = spine[2], spine[3]
  local secs = {}
  local function sector_of(sid)
    if not secs[sid] then
      local info = galaxy and galaxy.sectors[sid]
      secs[sid] = { sec = sectorm.generate(seed, sid, sid ~= 1 and info or nil), name = info and info.name or "Home Drift" }
    end
    return secs[sid]
  end
  local used = {}
  local function take(sid, site)
    used[sid .. ":" .. site] = true
    return site
  end
  local function pick_site(sid, prefer_home_first)
    local sec = sector_of(sid).sec
    if prefer_home_first and not used[sid .. ":1"] then return take(sid, 1) end
    local cands = pick_by(sec.sites, function(s) return not s.city and not s.heart and not used[sid .. ":" .. s.id] end)
    if #cands == 0 then cands = pick_by(sec.sites, function(s) return not s.city and not s.heart end) end
    if #cands == 0 then cands = sec.sites end
    local pref = pick_by(cands, function(s) return s.civ == ai or s.civ == bi end)
    return take(sid, rng:pick(#pref > 0 and pref or cands).id)
  end

  local nfar = 0
  for _, b in ipairs(sk.beats) do if b.where == "far" then nfar = nfar + 1 end end
  local far_seen = 0
  local city_sid
  if galaxy and far1 and far2 then
    local want = {}
    for _, sid in ipairs({ far1, far2 }) do if sectorm.city_of(seed, sid) then want[#want + 1] = sid end end
    if #want > 0 then city_sid = rng:pick(want) end
  end

  local beats = {}
  for n, b in ipairs(sk.beats) do
    local sid, site
    if b.where == "heart" then
      sid = galaxy and galaxy.heart or 1
      site = 1
    elseif b.where == "city" and city_sid then
      sid = city_sid
      local sec = sector_of(sid).sec
      for _, s in ipairs(sec.sites) do if s.city then site = s.id end end
    else
      far_seen = b.where == "far" and far_seen + 1 or far_seen
      if b.where == "far" and far1 and far2 then
        sid = (nfar >= 2 and far_seen >= 2) and far2 or far1
      else
        sid = 1
      end
      site = pick_site(sid, b.where == "home")
    end
    local sd = sector_of(sid)
    local st = sd.sec.sites[site]
    beats[n] = { id = b.id, n = n, carrier = b.carrier, where = b.where, sector = sid, site = site, civ = st.civ, kit = st.kit,
                 slot = rng:int(1, 3), salt = rng:int(1, 1000000), loc = loc_label(V, civs.get(seed, st.civ), sd.name, st, sid),
                 found_by = 0, tick = 0 }
    -- a city beat that could not be placed in a city falls back to a derelict
    if b.where == "city" and not city_sid then beats[n].carrier = "log" end
  end

  -- texts
  local function pick_text(list) return rng:pick(list) end
  for n, b in ipairs(sk.beats) do
    local out = beats[n]
    local nxt = beats[n + 1]
    local v = setmetatable({}, { __index = vars })
    if b.id == "finale" then
      out.finale = {}
      for _, e in ipairs({ "seal", "restore", "take" }) do out.finale[e] = fill(b.text[e], v) end
      out.text = fill(b.text.seal, v)
      if twist then out.coda = fill(twist.coda, v) end
    else
      local list = b.text
      if twist and b.id == "reveal" then
        list = twist.reveal
        out.twisted = true
      end
      out.text = fill(pick_text(list), v)
      v.next_loc, v.next_carrier = nxt.loc, V.carriers[nxt.carrier].noun
      local lead_set = nxt.id == "finale" and S.leads.heart or S.leads[nxt.carrier]
      out.lead = fill(pick_text(lead_set or { "The trail goes on at {next_loc}." }), v)
    end
  end

  local names = {}
  for k, x in pairs(vars) do names[k] = x end
  return { skeleton = sk.id, title = fill(sk.title, vars), cause = m.cause, a = ai, b = bi, twist = twist and twist.id or false,
           twist_title = twist and twist.title or false, echo = echo.id, betrayer = vars.betrayer, betrayed = vars.betrayed,
           vars = names, mode = "on", beats = beats, done = false, ending = false }
end

-- ---------------------------------------------------------------- reading it

function M.clue_count(s) return s and (#s.beats - 1) or 0 end
function M.finale(s) return s and s.beats[#s.beats] or nil end

-- is the story running? (it follows the mystery: "off" is the sandbox)
function M.active(state)
  local s = state.story
  return s ~= nil and s.mode ~= "off" and require("sim.mystery").active(state.mystery)
end

-- clue beat i can be found once the one before it has been (the first at once)
function M.unlocked(s, i)
  if not s or i < 1 or i > M.clue_count(s) then return false end
  return i == 1 or s.beats[i - 1].found_by ~= 0
end

-- the first clue not yet found (nil when they all are)
function M.next_clue(s)
  for i = 1, M.clue_count(s) do
    if s.beats[i].found_by == 0 then return i end
  end
  return nil
end

function M.found_count(s)
  local n = 0
  for i = 1, M.clue_count(s) do if s.beats[i].found_by ~= 0 then n = n + 1 end end
  return n
end

-- the whole text of beat i: its body and the lead to the next place
function M.full_text(s, i)
  local b = s.beats[i]
  if not b then return "" end
  if b.lead then return b.text .. " " .. b.lead end
  return b.text
end

-- the finale for an ending id (a twist adds its coda)
function M.finale_text(s, ending_id)
  local f = M.finale(s)
  local t = f.finale[ending_id] or f.text
  if f.coda then t = t .. " " .. f.coda end
  return t
end

-- ---------------------------------------------------------------- saving

-- what a save keeps: the mode, who found each beat and when (the text regenerates)
function M.progress(s)
  if not s then return nil end
  local out = { mode = s.mode, done = s.done, ending = s.ending, beats = {} }
  for i, b in ipairs(s.beats) do out.beats[i] = { found_by = b.found_by, tick = b.tick } end
  return out
end

function M.restore(s, prog)
  if not s or not prog then return s end
  s.mode, s.done, s.ending = prog.mode or s.mode, prog.done or false, prog.ending or false
  for i, b in ipairs(s.beats) do
    local pb = prog.beats and prog.beats[i]
    if pb then b.found_by, b.tick = pb.found_by or 0, pb.tick or 0 end
  end
  return s
end

return M
