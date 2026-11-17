-- run02: a careful explorer. The Seat in guarded sites (Watchers ignore it),
-- identifies everything and waits for the bench before selling, sleeps
-- often, stays at danger 2 or below.
BOT.spawn(1, "p1", function()
  local get = BOT.P(1)
  require("sim.autopilot").wake(BOT.B, 1, get)
  CAREER(1, { name = "careful-explorer", mystery = true, sell_at = 8, sleep_every = 3, max_danger = 2,
    trade = { fold = true, buy = { { name = "Glowmoss", min = 200 } } },
    dive = function(s) return { seat = s.guarded } end,
    after_trip = function(pl, n)
      if n == 2 then BOT.shot("explorer_after_two_dives") end
    end })
end)
BOT.run_all()
