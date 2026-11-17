-- run07: pocket saucer and station visits. After each dive: dock, pocket
-- the Villa, walk the concourse, sell at a stall, drink at the bar, deal with
-- the pickpocket, leave by the far hangar.
local ap = require("sim.autopilot")
local visit = require("sim.visit")
local sg = require("sim.stationgen")
local items = require("sim.items")
local B, ev, P, S = BOT.B, BOT.ev, BOT.P, BOT.S
local get = P(1)
local function close() if get().panel then ap.pick(B, 1, get, "Close") end end

local function station_visit(n)
  local t0 = BOT.tick()
  BOT.ensure_helm(1)
  local _, tp = (function()
    local list = S().sector.traders or { S().sector.trader }
    return 1, list[1].pos
  end)()
  if not get().docked then ap.travel(B, 1, get, { tp[1] + 50, tp[2], tp[3] + 50 }, 6, 60 * 240) end
  if not get().docked then ev(1, "fail", "not docked for a visit") return end
  B.press(1, "size3")
  if get().mode ~= "foot" then ev(1, "fail", "could not pocket: " .. (get().msgs[#get().msgs] or {}).text) return end
  ap.wait_until(B, 1, function() return get().station and get().station.coin == "pocket" end, 900)
  local L = visit.layout(S(), get())
  ev(1, "visit", string.format("in %s, coin %s", visit.area(S(), get()).name, get().station.coin))
  local scrap, chandler
  for _, s in ipairs(L.stalls) do
    if s.vendor == "scrap" then scrap = s end
    if s.vendor == "chandler" then chandler = s end
  end
  local tw = BOT.tick()
  local sold, c0 = 0, get().credits
  if scrap and ap.foot_use(B, 1, get, scrap.spot) then
    BOT.dump_panel(1, "stall")
    for _ = 1, 12 do
      local any = false
      for _, it in ipairs(get().hold) do
        if not any and visit.vendor_offer(S(), get(), visit.vendor_def("scrap"), it) then
          any = ap.pick(B, 1, get, "Sell " .. items.label(it))
          if any then sold = sold + 1 end
        end
      end
      if not any then break end
    end
    close()
  end
  ev(1, "visit_market", string.format("walk+sell %d ticks sold %d for %d c", BOT.tick() - tw, sold, get().credits - c0))
  if n == 1 then BOT.shot("station_market") end
  if chandler and ap.foot_use(B, 1, get, chandler.spot) then BOT.pick_enabled(1, "Top up") close() end
  if ap.foot_use(B, 1, get, L.bar.spot) then
    BOT.dump_panel(1, "bar")
    BOT.pick_enabled(1, "Nebula tea")
    BOT.pick_enabled(1, "Ask about rumours")
    close()
  end
  -- wander to the far hangar, coin in the pocket (the pickpocket's chance)
  local far = sg.hangars(L)[2] or sg.hangars(L)[1]
  local tf = BOT.tick()
  local ok = ap.foot_to(B, 1, get, far.pad[1], far.pad[2] + 3, 0.6, 6000)
  if get().station and get().station.coin == "thief" then
    ev(1, "pickpocket", "stolen")
    local caught = ap.chase(B, 1, get)
    ev(1, "chase", "caught " .. tostring(caught))
    ok = ap.foot_to(B, 1, get, far.pad[1], far.pad[2] + 3, 0.6, 6000)
  end
  ev(1, "visit_walk", string.format("to far hangar %d ticks ok %s", BOT.tick() - tf, tostring(ok)))
  B.press(1, "size1")
  ap.wait_until(B, 1, function() return get().mode == "helm" end, 600)
  ev(1, "visit_end", string.format("visit %d ticks mode %s credits %d", BOT.tick() - t0, get().mode, get().credits))
  if get().mode ~= "helm" then
    ev(1, "softlock?", "still on foot after unfolding in the far hangar: " .. (get().msgs[#get().msgs] or {}).text)
    -- try the arrival hangar
    local h = sg.hangars(L)[1]
    ap.foot_to(B, 1, get, h.pad[1], h.pad[2] + 3, 0.6, 6000)
    B.press(1, "size1")
    ap.wait_until(B, 1, function() return get().mode == "helm" end, 600)
  end
end

BOT.spawn(1, "p1", function()
  ap.wake(B, 1, get)
  ev(1, "career", "station-visits")
  local n = 0
  while not B.time_up() do
    local list = BOT.site_order(1)
    if #list == 0 then break end
    BOT.dive(1, list[1].i, { seat = list[1].guarded })
    n = n + 1
    station_visit(n)
    BOT.lab(1, false)
    BOT.trade_run(1, { fold = true })
    if n % 3 == 0 then BOT.sleep(1) end
  end
  if not B.time_up() then CAREER(1, { name = "station-visits-after", sell_at = 6, trade = { fold = true },
    after_trip = function() station_visit(99) end }) end
  ev(1, "career_end", string.format("credits %d sold_on_foot %d", get().credits, get().sold_on_foot or 0))
end)
BOT.run_all()
