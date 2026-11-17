-- run06: home-life focus. Holodeck, cooking, reading, TV, decorating and the
-- garden between short dives; the dome is the point of the session.
local ap = require("sim.autopilot")
local holo = require("sim.holo")
local decor = require("sim.decor")
local buffs = require("sim.buffs")
local B, ev, P, S = BOT.B, BOT.ev, BOT.P, BOT.S
local get = P(1)
local function close() if get().panel then ap.pick(B, 1, get, "Close") end end
local function timed(name, f)
  local t0 = BOT.tick()
  local ok = f()
  ev(1, "home", string.format("%s ok %s ticks %d", name, tostring(ok), BOT.tick() - t0))
  return ok
end
local function exit_holo()
  if not get().holo_run then return end
  local sc = holo.scene(S(), get(), get().holo_run)
  if get().holo_run.craft then B.press(1, "use") return end
  local a = holo.arch(sc.size)
  ap.holo_walk(B, 1, get, a[1], a[2] + 0.4)
  B.press(1, "use")
end
local function holodeck(prog, act)
  return timed("holodeck " .. prog, function()
    if not BOT.station(1, "holodeck") then return false end
    if not BOT.pick_enabled(1, "Run " .. prog) then close() return false end
    local ok = act and act() or true
    BOT.B.wait(600)
    exit_holo()
    return ok
  end)
end
local function cook()
  return timed("cook", function()
    if not BOT.station(1, "kitchen") then return false end
    local ok = BOT.pick_enabled(1, "Cook ")
    if ok then ap.wait_until(B, 1, function() return not get().cooking end, 900) end
    close()
    return ok
  end)
end
local function read()
  return timed("read", function()
    if not BOT.station(1, "books") then return false end
    local ok = BOT.pick_enabled(1, "Read ")
    for _ = 1, 12 do if get().reading then B.wait(240) B.press(1, "use") end end
    close()
    return ok
  end)
end
local function tv()
  return timed("tv", function()
    if not BOT.station(1, "tv") then return false end
    local ok = BOT.pick_enabled(1, "Watch")
    if ok then B.wait(60 * 30) ap.hold(B, 1, { move_z = 1 }) B.wait(2) end
    close()
    return ok
  end)
end
local function decorate()
  return timed("decorate", function()
    local n = 0
    if BOT.station(1, "planner") then
      for _ = 1, 3 do if BOT.pick_enabled(1, "Place ") then n = n + 1 ap.look(B, 1, get, get().body.yaw + 1.2, 0) B.press(1, "use") end end
      close()
    end
    if BOT.station(1, "display1") then if BOT.pick_enabled(1, "Display ") then n = n + 1 end close() end
    if BOT.station(1, "garden") then
      if BOT.pick_enabled(1, "Harvest ") then n = n + 1 end
      if BOT.pick_enabled(1, "Plant ") then n = n + 1 end
      for _ = 1, 3 do if BOT.pick_enabled(1, "Water ") then n = n + 1 end end
      BOT.dump_panel(1, "garden_after")
      close()
    end
    ev(1, "comfort", string.format("%d %s", decor.comfort(S(), get()), decor.level(S(), get())))
    return n > 0
  end)
end

BOT.spawn(1, "p1", function()
  ap.wake(B, 1, get)
  ev(1, "career", "home-life")
  holodeck("Sunset Beach", function() return ap.holo_walk(B, 1, get, 0.6, 0.2) and (B.press(1, "use") or true) end)
  timed("holo course", function()
    if not BOT.station(1, "holodeck") then return false end
    if not BOT.pick_enabled(1, "Run Seat Flight Course") then close() return false end
    local ok = ap.holo_course(B, 1, get)
    if get().holo_run then B.press(1, "use") end
    return ok
  end)
  cook()
  read()
  tv()
  BOT.shot("home_tv_or_kitchen")
  local cycle = 0
  while not B.time_up() do
    cycle = cycle + 1
    local list = BOT.site_order(1)
    if #list > 0 then BOT.dive(1, list[1].i, { seat = list[1].guarded }) end
    BOT.lab(1, true)
    holodeck("Derelict Replay")
    if cycle % 2 == 1 then holodeck("Resonant Memory") end
    BOT.trade_run(1, { keep = function(it) return it.ident and it.category == "curio" and (it.tier or 1) >= 2 end,
      buy = { { name = "noodles", min = 20 }, { name = "lamp", min = 80 }, { name = "armchair", min = 150 },
              { name = "aquarium", min = 250 }, { name = "2 Glowmoss", min = 40 }, { name = "2 Sunvine", min = 60 },
              { name = "holo program", min = 100 }, { name = "Holo emitter", min = 120 } } })
    if get().holo then
      timed("install", function()
        if not BOT.station(1, "holodeck") then return false end
        local ok = BOT.pick_enabled(1, "Install ")
        close()
        return ok
      end)
    end
    decorate()
    if cycle == 2 then BOT.shot("decorated_dome") end
    cook()
    read()
    if cycle % 2 == 0 then tv() end
    BOT.sleep(1)
    if #list == 0 and cycle > 6 then break end
  end
  ev(1, "career_end", string.format("credits %d comfort %d meals %d holo runs %d", get().credits,
    decor.comfort(S(), get()), get().meals or 0, get().holo and get().holo.runs or 0))
end)
BOT.run_all()
