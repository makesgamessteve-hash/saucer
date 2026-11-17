-- run08: on-foot excursions. Do the tutorial derelict's crawlspace, then fold
-- jump out along the spine to a danger-3 sector and step out in derelicts
-- that keep a Warden: crawl, lift Delicates by hand, turn hand-locks or cut
-- the shutter with the cutter, shut grids, grapple across, mind the suit.
local ap = require("sim.autopilot")
local ex = require("sim.excursion")
local game = require("sim.game")
local galaxy = require("sim.galaxy")
local configs = require("sim.config")
local vec = require("lib.vec")
local B, ev, P, S = BOT.B, BOT.ev, BOT.P, BOT.S
local get = P(1)

local function warden_near()
  local site = get().site
  if site == 0 then return nil end
  for k, d in ipairs(game.sentries(site)) do
    local dyn = S().sentries[site] and S().sentries[site][k]
    if d.kind == "warden" and dyn then return dyn, d end
  end
end

local tools = require("sim.tools")
local function excursion(site, use_cutter)
  local t0 = BOT.tick()
  local ruin, origin = game.ruin(site), S().sector.sites[site].pos
  local f = ruin.foot
  if not f then ev(1, "excursion", "site " .. site .. " has no crawlspace") return false end
  BOT.ensure_helm(1)
  ap.resize(B, 1, get, 1)
  local ok = ap.enter(B, 1, get, ruin, origin, f.host)
  if not ok then ev(1, "excursion_fail", "could not fly into the host hall of site " .. site) return false end
  ap.resize(B, 1, get, ex.seat_size())
  local mouth = f.route[1]
  if not ap.fly(B, 1, get, { mouth[1], mouth[2] + 1.3, mouth[3] }, 0.4, 3000) then
    ev(1, "excursion_fail", "could not set the Seat down at the crawlspace") return false
  end
  local suit0 = get().suit
  B.press(1, "size3")
  if get().mode ~= "foot" then ev(1, "excursion_fail", "step out refused: " .. (get().msgs[#get().msgs] or {}).text) return false end
  ap.wait_until(B, 1, function() return get().excursion and get().excursion.coin == "pocket" end, 400)
  local stage = {}
  local function mark(s) stage[#stage + 1] = s .. "@" .. (BOT.tick() - t0) .. "/suit" .. math.floor(get().suit) end
  if ap.ex_path(B, 1, get, { f.route[2], f.route[3], f.route[4] }, 0.3, 2400) then mark("chamber") end
  if BOT.tick() - t0 < 60 * 60 then BOT.shot_once = BOT.shot_once or (BOT.shot("crawl_chamber") or true) end
  for _, d in ipairs(f.delicates or {}) do
    if get().mode == "foot" and ap.ex_to(B, 1, get, d.pos, 0.5, 1500) then B.press(1, "use") mark("delicate") end
  end
  for _, lock in ipairs(use_cutter and {} or f.locks or {}) do
    if get().mode == "foot" and ap.ex_to(B, 1, get, lock.stand, 0.3, 1500) and
        ap.ex_work(B, 1, get, function() return ex.lock_open(S(), site, lock.id) end, 500) then mark("lock") end
  end
  for _, con in ipairs(f.consoles or {}) do
    if get().mode == "foot" and ap.ex_to(B, 1, get, con.stand, 0.3, 1500) and
        ap.ex_work(B, 1, get, function() return ex.grid_down(S(), site) end, 500) then mark("grid") end
  end
  if get().mode == "foot" then
    if ap.ex_path(B, 1, get, { f.route[3], f.route[2], f.route[1] }, 0.3, 2400) then mark("out") end
  end
  -- the cutter: walk up to the strongroom shutter and hold the spike key
  if use_cutter and get().mode == "foot" and f.strong_front and game.shutter_closed(site, 1) then
    local sf = f.strong_front
    ap.ex_to(B, 1, get, sf, 0.4, 2400)
    local sh = f.shutters and f.shutters[1]
    if sh then
      local c = { (sh.min[1] + sh.max[1]) / 2, (sh.min[2] + sh.max[2]) / 2, (sh.min[3] + sh.max[3]) / 2 }
      local b = get().excursion.body
      ap.ex_look(B, 1, get, saucer.math.atan2(c[1] - b.pos[1], c[3] - b.pos[3]), 0, 300)
      ap.ex_to(B, 1, get, c, 2.0, 600)
    end
    ev(1, "cutter_target", tostring(tools.cut_target(S(), get()) and tools.cut_target(S(), get()).kind))
    B.press(1, "spike", 60 * 7)
    if not game.shutter_closed(site, 1) then mark("cutter") end
  end
  -- the grapple (the Shroud key on foot): hook the far wall of the hall
  if get().mode == "foot" then
    local g0 = get().grapples or 0
    local b = get().excursion.body
    ap.ex_look(B, 1, get, b.yaw + saucer.math.pi, 0.15, 300)
    B.press(1, "shroud")
    B.wait(240)
    if (get().grapples or 0) > g0 then mark("grapple") end
  end
  local wd = warden_near()
  if wd then ev(1, "warden", "state " .. tostring(wd.st)) end
  -- deploy and board, facing the open hall
  if get().mode == "foot" then
    local away = { 0, 0, 0 }
    away[f.channel.axis] = -f.channel.sign
    ap.ex_look(B, 1, get, saucer.math.atan2(away[1], away[3]), 0, 300)
    B.press(1, "grow")
    ap.wait_until(B, 1, function() return get().mode == "helm" end, 600)
    if get().mode ~= "helm" then
      ev(1, "excursion_fail", "could not deploy: " .. (get().msgs[#get().msgs] or {}).text)
      -- wait for the suit (the Lifeline) rather than stand there forever
      ap.wait_until(B, 1, function() return get().mode ~= "foot" end, 60 * 300)
    end
  end
  ev(1, "excursion", string.format("site %d ticks %d suit %d->%d lifelines %d hold %d stages %s", site, BOT.tick() - t0,
    math.floor(suit0), math.floor(get().suit), get().lifelines or 0, #get().hold, table.concat(stage, ",")))
  -- back out of the site the way the Seat came in, then dive for the
  -- strongroom (opened by the lock) and the rest of the site
  if get().mode == "helm" and get().site == site then
    local back = {}
    local route = ap.route(ruin, origin, f.host, 2)
    local sp = get().ship.pos
    back[1] = { pos = { sp[1], sp[2] + 4, sp[3] }, tol = 1.0 }
    for i = #route, 1, -1 do back[#back + 1] = { pos = route[i].pos, tol = route[i].tol } end
    if not ap.follow(B, 1, get, back, 2000) then ev(1, "stuck", "leaving after the excursion") BOT.unstick(1) end
    local o = get().ship.pos
    ap.fly(B, 1, get, { o[1], o[2], o[3] - 80 }, 3, 2400)
    if get().site == 0 then ap.resize(B, 1, get, 1) end
  end
  -- the strongroom: lined up at its door, fly in and beam its loot up
  if get().mode == "helm" and not game.shutter_closed(site, 1) and f.strong_front then
    ap.resize(B, 1, get, ex.seat_size())
    local sf = f.strong_front
    local ok2 = BOT.travel(1, { sf[1], sf[2] + 6, sf[3] }, 1, 60 * 120) and ap.fly(B, 1, get, sf, 0.4, 3000)
      and ap.fly(B, 1, get, { f.slot_pos[1], sf[2], f.slot_pos[3] }, 0.4, 3000)
    local got = false
    if ok2 then
      for _, c in ipairs(require("sim.tractor").candidates(S(), get(), site, ruin)) do
        if c.key == site .. ":" .. f.slot then got = ap.beam_up(B, 1, get, c) end
      end
      ap.fly(B, 1, get, sf, 0.6, 3000)
    end
    ev(1, "strongroom", string.format("site %d reached %s beamed %s", site, tostring(ok2), tostring(got)))
    local route = ap.route(ruin, origin, f.host, 2)
    local back = {}
    for i = #route, 1, -1 do back[#back + 1] = { pos = route[i].pos, tol = route[i].tol } end
    ap.follow(B, 1, get, back, 2000)
    local o = get().ship.pos
    ap.fly(B, 1, get, { o[1], o[2], o[3] - 80 }, 3, 2400)
    if get().site == 0 then ap.resize(B, 1, get, 1) end
  end
  BOT.dive(1, site, { seat = true })
  return true
end

BOT.spawn(1, "p1", function()
  ap.wake(B, 1, get)
  ev(1, "career", "excursions")
  excursion(1)
  BOT.lab(1, false)
  BOT.trade_run(1, { fold = true })
  local g = galaxy.generate(S().seed)
  for _, to in ipairs({ g.spine[2], g.spine[3] }) do
    if not BOT.jump(1, to) then ev(1, "fail", "could not reach " .. to) end
  end
  ev(1, "deep", string.format("sector %d danger %d", S().sector_id, g.sectors[S().sector_id].danger))
  local done = {}
  while not B.time_up() do
    local best
    for i = 1, #S().sector.sites do
      local w = false
      for _, d in ipairs(game.sentries(i)) do if d.kind == "warden" then w = true end end
      if not done[i] and game.ruin(i).foot and (not best or (w and not best.w)) then best = { i = i, w = w } end
    end
    if not best then break end
    done[best.i] = true
    ev(1, "excursion_site", string.format("site %d warden %s", best.i, tostring(best.w)))
    excursion(best.i, best.i % 2 == 0)
    BOT.lab(1, false)
    BOT.sleep(1)
  end
  if not B.time_up() then CAREER(1, { name = "excursions-after", sell_at = 6, trade = { fold = true },
    dive = function(s) return { seat = s.guarded } end }) end
  ev(1, "career_end", string.format("credits %d lifelines %d grapples %d", get().credits, get().lifelines or 0, get().grapples or 0))
end)
BOT.run_all()
