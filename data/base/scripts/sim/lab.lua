-- SPDX-License-Identifier: MIT
-- The lab bench (concept §6.2): identify items in 30 s x tier of sim time
-- for a little Charge, and decode Echoes. Jobs queue up and run while the
-- saucer is the Villa (the bench folds away in the Seat), even while you fly.
local data = require("lib.data")
local configs = require("sim.config")
local items = require("sim.items")
local mystery = require("sim.mystery")
local M = {}

local function econ() return data.load("economy/economy.lua") end

function M.new() return { queue = {} } end

function M.is_core(it) return it.home ~= nil and it.home.kind == "program" and not it.ident end

local function queued(p, uid)
  for _, j in ipairs(p.lab.queue) do if j.uid == uid then return true end end
  return false
end
M.queued = queued

-- enqueue(p, uid) -> ok, reason
function M.enqueue(state, p, uid)
  p.lab = p.lab or M.new()
  local it = items.find(p, uid)
  if not it then return false, "gone" end
  if queued(p, uid) then return false, "queued" end
  if it.echo then
    if not mystery.decodable(state.mystery, it.echo) then return false, "nothing to decode" end
    local s = econ().decode_seconds
    p.lab.queue[#p.lab.queue + 1] = { uid = uid, kind = "decode", left = s, total = s }
    return true
  end
  -- add-holodeck-home-life: a data core decodes into a holodeck program
  if M.is_core(it) then
    local s = econ().decode_seconds
    p.lab.queue[#p.lab.queue + 1] = { uid = uid, kind = "core", left = s, total = s }
    return true
  end
  if it.ident or it.unique then return false, "already identified" end
  local cost = econ().identify_charge
  if p.ship.charge < cost then return false, "charge" end
  p.ship.charge = p.ship.charge - cost
  local s = econ().identify_seconds * (it.tier or 1)
  p.lab.queue[#p.lab.queue + 1] = { uid = uid, kind = "identify", left = s, total = s }
  return true
end

-- runs only while the bench exists (Villa, not reconfiguring)
function M.running(p)
  return configs.get(p.ship.size).interior and not p.ship.morph
end

-- step(state, p, dt, ctx) -> the finished job (or nil)
function M.step(state, p, dt, ctx)
  local lab = p.lab
  if not lab or #lab.queue == 0 or not M.running(p) then return nil end
  local job = lab.queue[1]
  job.left = job.left - dt
  if job.left > 1e-9 then return nil end
  table.remove(lab.queue, 1)
  local it = items.find(p, job.uid)
  if not it then return nil end
  if job.kind == "core" then
    local holo = require("sim.holo")
    local id = it.home.id
    local new = holo.unlock(p, id)
    items.remove(p, it.uid)
    local pr = holo.program(id)
    ctx.msg(state, p, string.format("Decoded the data core: holodeck program %s%s", pr and pr.name or id,
      new and " is in your library" or " (you already had it)"))
    ctx.fx(state, p, "echo")
  elseif job.kind == "identify" then
    it.ident = true
    local q = it.quirk and (" (quirk: " .. it.quirk .. ")") or ""
    ctx.msg(state, p, "Identified: " .. it.name .. q)
    ctx.fx(state, p, "bank")
  else
    local text = mystery.decode(state.mystery, it.echo)
    if text then require("sim.books").add(p, "echo:" .. it.echo) end
    ctx.msg(state, p, text or "The Echo is silent")
    local res = mystery.resonant_sites(state.mystery)
    if #res > 0 then ctx.msg(state, p, "A Resonant signal: site " .. res[#res] .. " is marked on your radar") end
    if state.mystery.vault_revealed and it.echo and state.mystery.echoes[it.echo].role == "where" then
      ctx.msg(state, p, "The star chart shows the Resonant vault in open space")
    end
    ctx.fx(state, p, "echo")
  end
  job.done = true
  return job
end

-- panel rows for the lab bench
function M.rows(state, p, ctx)
  local rows = {}
  local lab = p.lab or M.new()
  for k, j in ipairs(lab.queue) do
    local it = items.find(p, j.uid)
    local name = it and items.label(it) or "?"
    local pct = math.floor((1 - j.left / j.total) * 100)
    rows[#rows + 1] = { text = string.format("%s %s %d%%%s", j.kind == "identify" and "Identifying" or "Decoding", name,
      pct, k == 1 and not M.running(p) and " (paused)" or ""), enabled = false }
  end
  for _, it in ipairs(p.hold) do
    if not queued(p, it.uid) then
      local uid = it.uid
      if M.is_core(it) then
        rows[#rows + 1] = { text = "Decode " .. items.label(it) .. string.format(" (%ds)", econ().decode_seconds),
          act = function(st, pl) M.pick(st, pl, uid, ctx) end }
      elseif it.home then
        -- modules wait for the holodeck panel; nothing to do here
      elseif it.echo and mystery.decodable(state.mystery, it.echo) then
        rows[#rows + 1] = { text = "Decode " .. it.name .. string.format(" (%ds)", econ().decode_seconds),
          act = function(st, pl) M.pick(st, pl, uid, ctx) end }
      elseif not it.ident and not it.unique and not it.echo then
        rows[#rows + 1] = { text = string.format("Identify %s (%ds, %d CHG)", items.label(it),
          econ().identify_seconds * (it.tier or 1), econ().identify_charge),
          act = function(st, pl) M.pick(st, pl, uid, ctx) end }
      end
    end
  end
  if #rows == 0 then rows[1] = { text = "Nothing to identify or decode", enabled = false } end
  rows[#rows + 1] = { text = "Close", act = function(_, pl) pl.panel = false end }
  return rows
end

function M.pick(state, p, uid, ctx)
  local ok, why = M.enqueue(state, p, uid)
  if ok then
    local it = items.find(p, uid)
    ctx.msg(state, p, ((it.echo or M.is_core(it)) and "Decoding " or "Identifying ") .. items.label(it) .. " at the lab bench")
  else
    ctx.msg(state, p, why == "charge" and "Not enough Charge to run the lab" or ("Lab: " .. why))
    ctx.fx(state, p, "denied")
  end
  return ok
end

return M
