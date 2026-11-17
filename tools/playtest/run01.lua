-- run01: a new player who follows the main mystery and loots on the way
BOT.spawn(1, "p1", function()
  local get = BOT.P(1)
  BOT.B.wait(30)
  BOT.shot("title")
  require("sim.autopilot").wake(BOT.B, 1, get)
  CAREER(1, { name = "mystery-first", mystery = true, sell_at = 6, sleep_every = 4, max_danger = 3,
    trade = { fold = true }, dive = function(s) return { seat = s.guarded } end })
end)
BOT.run_all()
