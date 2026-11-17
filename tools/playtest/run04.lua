-- run04: sandbox / endless. Mystery switched off on the title card if it
-- offers that; loot, trade, wander every sector the Fold Core reaches.
BOT.spawn(1, "p1", function()
  local get = BOT.P(1)
  BOT.B.wait(10)
  BOT.B.press(1, "mystery_mode")
  BOT.B.wait(5)
  BOT.ev(1, "mystery_mode", tostring(BOT.S().mystery.mode))
  require("sim.autopilot").wake(BOT.B, 1, get)
  CAREER(1, { name = "sandbox", mystery = false, sell_at = 7, sleep_every = 5,
    trade = { fold = true, buy = { { name = "armchair", min = 300 }, { name = "rug", min = 200 } } },
    after_trip = function(pl, n) if n == 6 then BOT.shot("sandbox_trip6") end end })
end)
BOT.run_all()
