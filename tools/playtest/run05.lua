-- run05: Hardcore (started with --hardcore). Middle-of-the-road play: the
-- Villa where it fits, banks often (sells at 4), jams Watchers.
BOT.spawn(1, "p1", function()
  local get = BOT.P(1)
  BOT.B.wait(20)
  BOT.ev(1, "hardcore", tostring(BOT.S().hardcore))
  BOT.shot("hardcore_title")
  require("sim.autopilot").wake(BOT.B, 1, get)
  CAREER(1, { name = "hardcore", mystery = true, sell_at = 4, sleep_every = 4, max_danger = 3,
    trade = { fold = true } })
end)
BOT.run_all()
