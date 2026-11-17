-- run09: local split-screen co-op (--local-players 2 --viewports 2). P1
-- follows the mystery, P2 loots; both play at once in their own saucers.
-- Party fold jumps need both: whoever is free agrees to a proposal.
local galaxy = require("sim.galaxy")
local ap = require("sim.autopilot")
BOT.coop = true
for i = 1, 2 do
  BOT.spawn(i, "p" .. i, function()
    local get = BOT.P(i)
    BOT.B.wait(5 + i * 3)
    if i == 2 and #BOT.S().players < 2 then BOT.B.press(2, "use") end
    BOT.B.wait(5)
    ap.wake(BOT.B, i, get)
    if i == 1 then BOT.B.wait(30) BOT.shot("coop_start") end
    CAREER(i, { name = i == 1 and "coop-mystery" or "coop-looter", mystery = i == 1, sell_at = 6, sleep_every = 5,
      max_danger = 3, trade = { fold = true }, follower = i == 2,
      -- P2 starts at the far end of the sector so the two Villas do not queue at one hangar door
      pick = i == 2 and function(l) table.sort(l, function(a, b) return a.d > b.d end) return l end or nil,
      dive = function(s) return { seat = (i == 1) and s.guarded } end,
      after_trip = function(pl, n) if pl == 1 and n == 4 then BOT.shot("coop_trip4") end end })
  end)
end
BOT.run_all()
