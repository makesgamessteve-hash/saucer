-- run03: a greedy loot-runner. The Villa everywhere it fits (Seat only for
-- ducts), never identifies, sells in bulk, leaves home after the tutorial
-- derelict and pushes for the most dangerous sector in range.
local done_home = false
BOT.spawn(1, "p1", function()
  local get = BOT.P(1)
  require("sim.autopilot").wake(BOT.B, 1, get)
  CAREER(1, { name = "greedy-runner", mystery = false, sell_at = 9, prefer_danger = true, identify = false,
    trade = { fold = true },
    -- greedy, but learns: after two Fold Retreats the Seat goes into guarded sites
    dive = function(s)
      return { seat = s.guarded and (BOT.P(1)().retreats or 0) >= 2 }
    end,
    pick = function(list)
      if BOT.S().sector_id == 1 and done_home then return {} end
      -- richest guarded site first
      table.sort(list, function(a, b)
        if a.guarded ~= b.guarded then return a.guarded end
        return a.d < b.d
      end)
      return list
    end,
    after_trip = function(pl, n)
      if BOT.S().sector_id == 1 then done_home = true end
      if n == 3 then BOT.shot("greedy_trip3") end
    end })
end)
BOT.run_all()
