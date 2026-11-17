-- SPDX-License-Identifier: MIT
-- The career loop shared by the playtest styles: pick a site, dive, bank,
-- identify, trade, sleep now and then, fold on when a sector is picked clean.
-- BOT is tools/playtest/bot.lua (run.sh puts both into one script).
local ap = require("sim.autopilot")
local galaxy = require("sim.galaxy")
local items = require("sim.items")
local game = require("sim.game")

local function career(pl, pol)
  local get = BOT.P(pl)
  local S, ev = BOT.S, BOT.ev
  local trips, since_sleep = 0, 0
  local visited = { [1] = true }
  ev(pl, "career", pol.name)
  while not BOT.B.time_up() do
    if BOT.agree_if_asked(pl) then visited[S().sector_id] = true end
    -- co-op twin vault: the partner holds an anchor open (before anything long)
    if #S().players > 1 and not pol.follower and BOT.twin_take(pl) then ev(pl, "twin", "taken") end
    if pol.mystery then BOT.mystery_step(pl) end
    if BOT.B.time_up() then break end
    local list = BOT.site_order(pl)
    if pol.pick then list = pol.pick(list) end
    if #list == 0 and pol.follower then
      -- co-op follower: wait for the partner to propose the next fold jump
      local tw = BOT.tick()
      if not pol.twin_tried or pol.twin_tried ~= S().sector_id then
        pol.twin_tried = S().sector_id
        BOT.twin_hold(pl)
      end
      if not get().ready_fold then BOT.ready_fold(pl, true) end
      BOT.B.wait(60 * 5)
      pol.waited = (pol.waited or 0) + (BOT.tick() - tw)
      if (pol.waited // 3600) ~= ((pol.waited - 300) // 3600) then ev(pl, "waiting_partner", string.format("%d ticks so far", pol.waited)) end
    elseif #list == 0 then
      -- this sector is picked clean: fold on to the nearest unvisited sector in range
      local g = galaxy.generate(S().seed)
      local cur = S().sector_id
      local best
      for _, s in ipairs(g.sectors) do
        if not visited[s.id] and galaxy.hops(S().seed, cur, s.id) <= galaxy.core(get()).hops
            and (not pol.max_danger or s.danger <= pol.max_danger) then
          if not best or (pol.prefer_danger and s.danger > best.danger) or (not pol.prefer_danger and s.danger < best.danger) then best = s end
        end
      end
      if not best then
        -- go back through visited ones (dead end)
        for _, s in ipairs(g.sectors) do
          if s.id ~= cur and galaxy.hops(S().seed, cur, s.id) <= galaxy.core(get()).hops then best = best or s end
        end
        ev(pl, "dead_end", "no unvisited sector in range of the Fold Core")
        if pol.stop_when_clean then break end
      end
      if not best then break end
      if #get().hold > 0 then
        BOT.lab(pl, false)
        BOT.trade_run(pl, pol.trade)
      end
      if BOT.jump(pl, best.id) then visited[S().sector_id] = true
      elseif #S().players == 1 then break end
    else
      local site = list[1]
      local opts = pol.dive and pol.dive(site) or {}
      local t0 = BOT.tick()
      local got = BOT.dive(pl, site.i, opts)
      trips = trips + 1
      since_sleep = since_sleep + 1
      if got == 0 then
        -- avoid looping on a site the bot cannot finish
        pol.skip = pol.skip or {}
        local key = S().sector_id .. ":" .. site.i
        pol.skip[key] = (pol.skip[key] or 0) + 1
        if pol.skip[key] >= 2 then
          ev(pl, "give_up_site", key)
          local old = pol.pick
          pol.pick = function(l)
            local out = {}
            for _, s in ipairs(old and old(l) or l) do
              if not pol.skip[S().sector_id .. ":" .. s.i] or pol.skip[S().sector_id .. ":" .. s.i] < 2 then out[#out + 1] = s end
            end
            return out
          end
        end
      end
      local loot = 0
      for _, it in ipairs(get().hold) do if items.sellable(it) then loot = loot + 1 end end
      -- a sensible player patches the hull after a Fold Retreat
      local hurt = get().ship.hull < 60
      if hurt then ev(pl, "repair_trip", string.format("hull %.0f", get().ship.hull)) end
      if loot >= (pol.sell_at or 6) or #BOT.site_order(pl) == 0 or hurt then
        if pol.identify ~= false then BOT.lab(pl, false) end
        BOT.trade_run(pl, pol.trade)
      end
      if pol.sleep_every and since_sleep >= pol.sleep_every then
        BOT.sleep(pl)
        since_sleep = 0
      end
      if #S().players > 1 and not pol.follower and BOT.twin_take(pl) then ev(pl, "twin", "taken") end
      if pol.after_trip then pol.after_trip(pl, trips) end
    end
  end
  ev(pl, "career_end", string.format("trips %d credits %d banked %d tier %d sector %d", trips, get().credits,
    get().banked_value, get().fold_tier or 1, S().sector_id))
end
return career
