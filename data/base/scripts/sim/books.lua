-- SPDX-License-Identifier: MIT
-- The living room bookshelf (OpenSpec add-holodeck-home-life). p.shelf is a
-- list of { id, read } (saved): books from home/books.lua, plus entries the
-- sim adds as they happen ("echo:<i>" transcripts when an Echo is decoded,
-- "memory" when a holodeck memory is replayed). Reading opens a page view
-- (p.reading, transient): Use turns the page, walking away closes the book.
-- The first read of a clue points at something real (see home/books.lua).
local data = require("lib.data")
local M = {}

M.WIDTH = 30 -- characters per page line

function M.catalog() return data.load("home/books.lua") end

function M.def(id)
  for _, b in ipairs(M.catalog()) do
    if b.id == id then return b end
  end
  return nil
end

function M.ensure(p)
  if not p.shelf then
    p.shelf = {}
    for _, b in ipairs(M.catalog()) do
      if b.starter then p.shelf[#p.shelf + 1] = { id = b.id, read = false } end
    end
  end
  return p.shelf
end

function M.has(p, id)
  for _, e in ipairs(M.ensure(p)) do
    if e.id == id then return e end
  end
  return nil
end

-- add(p, id) -> true when it was new
function M.add(p, id)
  if M.has(p, id) then return false end
  local s = M.ensure(p)
  s[#s + 1] = { id = id, read = false }
  return true
end

-- word-wrap text into lines of at most width characters
function M.wrap(text, width)
  width = width or M.WIDTH
  local lines, cur = {}, ""
  for word in text:gmatch("%S+") do
    if #cur == 0 then cur = word
    elseif #cur + 1 + #word <= width then cur = cur .. " " .. word
    else
      lines[#lines + 1] = cur
      cur = word
    end
  end
  if #cur > 0 then lines[#lines + 1] = cur end
  return lines
end

-- the site a clue points at right now, and what is there
local function next_echo_site(m)
  local mystery = require("sim.mystery")
  for i, e in ipairs(m.echoes) do
    if e.found_by == 0 and mystery.unlocked(m, i) then return e.site end
  end
  for _, e in ipairs(m.echoes) do
    if e.found_by == 0 then return e.site end
  end
  return m.echoes[#m.echoes] and m.echoes[#m.echoes].site or 1
end
M.next_echo_site = next_echo_site

local function guarded_site(state)
  local game = require("sim.game")
  local best, bn = 1, -1
  for i = 1, #state.sector.sites do
    local n = #game.sentries(i)
    if n > bn then best, bn = i, n end
  end
  return best, math.max(bn, 0)
end

function M.vars(state, b)
  local m = state.mystery
  local v = m.vars or {}
  local out = { civ = v.civ or "Velari", object = v.object or "relic", place = v.place or "the garden" }
  if b and b.clue == "sentries" then
    out.site, out.count = guarded_site(state)
  else
    out.site = next_echo_site(m)
  end
  return out
end

local function fill(line, vars)
  return (line:gsub("{(%w+)}", function(k) return vars[k] ~= nil and tostring(vars[k]) or k end))
end

-- resolve a shelf id to { title, kind, pages = { {lines}... }, clue }
function M.resolve(state, id)
  local echo = id:match("^echo:(%d+)$")
  if echo then
    local e = state.mystery.echoes[tonumber(echo)]
    local num = ({ "I", "II", "III", "IV", "V" })[tonumber(echo)] or echo
    local lines = e and M.wrap(e.decoded and e.text or "(not decoded yet)") or { "(silent)" }
    table.insert(lines, 1, "")
    table.insert(lines, 1, "Decoded at the lab bench:")
    return { title = "Echo " .. num .. " transcript", kind = "clue", pages = { lines } }
  end
  -- add-wider-dark: a Xenoarchive lore page (25% of a civ's catalog)
  local lore = id:match("^lore:(.+)$")
  if lore then
    local c = require("sim.civs").by_id(state.seed, lore)
    local text = c and string.format("The %s were %s builders of %s shape. They prized %s and %s, kept a %s temper, and their story ended in %s.",
      c.name, c.body, c.shape, c.domains[1], c.domains[2], c.temperament, c.fate) or "(an unknown hand)"
    local lines = M.wrap(text)
    table.insert(lines, 1, "")
    table.insert(lines, 1, "From your Xenoarchive:")
    return { title = (c and c.name or lore) .. " lore page", kind = "lore", pages = { lines } }
  end
  if id == "ending" then
    local m = state.mystery
    local e = m.ending and require("sim.mystery").ending_of(m, m.ending)
    local lines = M.wrap(e and (e.title .. ". " .. e.text) or "(the Heart is still beating)")
    table.insert(lines, 1, "")
    table.insert(lines, 1, "What we chose at the Heart:")
    return { title = "The Heart", kind = "clue", pages = { lines } }
  end
  if id == "memory" then
    local v = M.vars(state)
    local text = string.format("The %s remember %s. Their %s still sings: its next voice waits at site %d.",
      v.civ, v.place, v.object, v.site)
    local lines = M.wrap(text)
    table.insert(lines, 1, "")
    table.insert(lines, 1, "Recorded on the holodeck:")
    return { title = "Memory of " .. v.place, kind = "clue", pages = { lines } }
  end
  local b = M.def(id)
  if not b then return { title = id, kind = "lore", pages = { { "(the pages are blank)" } } } end
  local vars = M.vars(state, b)
  local pages = {}
  for i, pg in ipairs(b.pages) do
    pages[i] = {}
    for j, line in ipairs(pg) do pages[i][j] = fill(line, vars) end
  end
  return { title = b.title, kind = b.kind, pages = pages, clue = b.clue }
end

-- open(state, p, id, ctx): start reading; a clue's first read leaves a lead
function M.open(state, p, id, ctx)
  local e = M.has(p, id)
  if not e then return false end
  local r = M.resolve(state, id)
  p.panel = false
  p.reading = { id = id, page = 1 }
  if not e.read then
    e.read = true
    p.books_read = (p.books_read or 0) + 1
    if r.clue then
      local v = M.vars(state, M.def(id))
      p.leads = p.leads or {}
      p.leads[tostring(v.site)] = true
      ctx.msg(state, p, string.format("A lead: the %s points at site %d. It is marked on your radar.", r.title, v.site))
      ctx.fx(state, p, "echo")
    end
  end
  return true
end

-- Use turns the page; past the last page the book closes
function M.turn(state, p)
  local rd = p.reading
  if not rd then return false end
  local r = M.resolve(state, rd.id)
  rd.page = rd.page + 1
  if rd.page > #r.pages then p.reading = false end
  return true
end

function M.close(p) p.reading = false end

-- bookshelf panel rows: newest first, unread marked
function M.rows(state, p, ctx)
  local rows = {}
  local s = M.ensure(p)
  for i = #s, 1, -1 do
    local e = s[i]
    local r = M.resolve(state, e.id)
    local id = e.id
    rows[#rows + 1] = { text = string.format("Read %s%s%s", r.title, r.kind == "clue" and " (clue)" or "",
      e.read and "" or " *"), act = function(st, pl) M.open(st, pl, id, ctx) end }
  end
  rows[#rows + 1] = { text = "Close", act = function(_, pl) pl.panel = false end }
  return rows
end

return M
