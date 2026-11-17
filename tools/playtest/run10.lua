-- run10: network co-op, two processes on loopback (--host / --join). Both
-- processes run this same script on the same lockstep state; each one's
-- inputs only reach its own slot, so both bots run everywhere and agree.
local ap = require("sim.autopilot")
BOT.ev(0, "net", string.format("slot %d delay %d", BOT.NET and BOT.NET.slot or -1, BOT.DELAY))
for i = 1, 2 do
  BOT.spawn(i, "p" .. i, function()
    local get = BOT.P(i)
    ap.wait_until(BOT.B, i, function() return #BOT.S().players >= 2 end, 600)
    BOT.B.wait(10 * i)
    for _ = 1, 40 do
      if get().mode ~= "wake" then break end
      BOT.B.press(i, "use")
      BOT.B.wait(2)
    end
    CAREER(i, { name = i == 1 and "net-host" or "net-guest", mystery = i == 1, sell_at = 6, sleep_every = 6,
      max_danger = 3, trade = { fold = true }, follower = i == 2,
      pick = i == 2 and function(l) table.sort(l, function(a, b) return a.d > b.d end) return l end or nil, dive = function(s) return { seat = s.guarded } end })
  end)
end
BOT.run_all()
local st = saucer.net.status()
print(string.format("PTNET slot %d state %s checks %d rtt %d tick %d", st.slot, tostring(st.state), st.checks or -1,
  st.rtt or -1, BOT.S().tick))
