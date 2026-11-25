-- SPDX-License-Identifier: MIT
-- add-relic-stations (plan phase 8): a relic found in normal play spreads its loot so the halls carry most of the
-- value and the warrens (the Seat chambers and the reliquary) hold a quarter to two fifths of it, in fewer, richer
-- finds (a warren find pays relic.WARREN_VALUE x a hall find of the same roll). Generated relics put a find in only
-- some halls and one or two in every chamber, which left the warrens with three quarters of the value or more.
-- On the first rebuild of a far-sector relic (site.relic) the ruin's slots are rewritten once:
--  * every hall but the maw's gets HALL_FINDS finds (in different quarters, clear of the floor's openings)
--  * every chamber keeps at most one find; the reliquary keeps its three
--  * chamber finds are then dropped, in a seeded order, while the warren share is over SHARE[2] and dropping
--    one more would not take it under SHARE[1]
-- The share is measured on the record-0 rolls (each player's rolls differ, the spread does not); the heart's idol
-- is a fixed prize outside it. Slot ids are renumbered in order, so p.looted keys stay a function of the seed.
-- The relic slice (site.relic_civ) is left as generated.
local ruinm = require("sim.ruin")
local loot = require("sim.loot")
local M = {}

M.HALL_FINDS = 2
M.SHARE = { 0.25, 0.40 }
M.HOLE_PAD = 2

local function clear_of(holes, x0, x1, z0, z1, pad)
  for _, h in ipairs(holes) do
    if x0 < h[2] + pad and x1 > h[1] - pad and z0 < h[4] + pad and z1 > h[3] - pad then return false end
  end
  return true
end

-- the record-0 value of slot s (what the share is measured on)
function M.value(s)
  local relic = require("sim.relic")
  local iseed = loot.instance_seed(s.seed, 0)
  local v = s.xl and relic.idol_item(s, iseed).value or loot.roll(iseed, s.max_size, s.tier).value
  if s.warren then v = relic.warren_value(v) end
  return v * (s.premium or 1)
end

-- the warren share of the slots' value (the idol left out) -> share, warren value, hall value
function M.share(slots)
  local w, h = 0, 0
  for _, s in ipairs(slots) do
    if not s.xl then
      if s.warren then w = w + M.value(s) else h = h + M.value(s) end
    end
  end
  return (w + h) > 0 and w / (w + h) or 0, w, h
end

function M.apply(site, ruin)
  if not (site.relic and ruin and ruin.relic) or site.relic_civ or ruin.relic.play_loot then return ruin end
  local kit = ruinm.kit_of(ruin.kit)
  local origin = ruin.origin
  local rng = saucer.rng.new(saucer.seed_child(site.seed, "relic_loot", 0))
  local rooms = {}
  for _, r in ipairs(ruin.rooms) do rooms[r.id] = r end
  local maw_hall = ruin.relic.halls[1]
  -- what each hall already holds, and each chamber
  local per = {}
  local kept = {}
  for _, s in ipairs(ruin.slots) do
    local r = rooms[s.room]
    if s.warren and r and r.kind == "chamber" then
      if not per[s.room] then per[s.room] = 1 kept[#kept + 1] = s end
    else
      if r and r.kind == "hall" then per[s.room] = (per[s.room] or 0) + 1 end
      kept[#kept + 1] = s
    end
  end
  -- the halls' finds
  local sizes = kit.loot.hall_size
  for hi, hid in ipairs(ruin.relic.halls) do
    local h = rooms[hid]
    if h and hid ~= maw_hall then
      local mn, mx = ruinm.room_box(h, kit, origin)
      local holes = ruinm.face_holes(h, ruin.doors, ruin.rooms, kit, origin, 2, -1)
      local used = {}
      local quarters = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }
      local start = rng:int(1, #quarters)
      for k = 0, #quarters - 1 do
        if (per[hid] or 0) >= M.HALL_FINDS then break end
        local q = quarters[(start + k - 1) % #quarters + 1]
        local x = (mn[1] + mx[1]) / 2 + q[1] * (mx[1] - mn[1]) / 4
        local z = (mn[3] + mx[3]) / 2 + q[2] * (mx[3] - mn[3]) / 4
        if not used[q] and clear_of(holes, x - 3, x + 3, z - 3, z + 3, M.HOLE_PAD) then
          used[q] = true
          kept[#kept + 1] = { room = hid, pos = { x, mn[2] + kit.wall + 1.5, z }, max_size = sizes[(hi % #sizes) + 1],
                              tier = 2, hall = h.hall, seed = saucer.seed_child(site.seed, "relic_hall_find", #kept + 1) }
          per[hid] = (per[hid] or 0) + 1
        end
      end
    end
  end
  -- thin the chambers' finds down to the share
  local chamber = {}
  for _, s in ipairs(kept) do
    if s.warren and rooms[s.room] and rooms[s.room].kind == "chamber" then chamber[#chamber + 1] = s end
  end
  for k = #chamber, 2, -1 do   -- a seeded drop order
    local j = rng:int(1, k)
    chamber[k], chamber[j] = chamber[j], chamber[k]
  end
  -- the poorest go first (the seeded order breaks ties), so the warren finds left are the rich ones
  local val, pos = {}, {}
  for k, s in ipairs(chamber) do val[s], pos[s] = M.value(s), k end
  table.sort(chamber, function(a, b) if val[a] ~= val[b] then return val[a] < val[b] end return pos[a] < pos[b] end)
  local share, w, h = M.share(kept)
  local drop = {}
  for _, s in ipairs(chamber) do
    if share <= M.SHARE[2] then break end
    local v = M.value(s)
    local next_share = (w - v) / math.max(1, (w - v) + h)
    if next_share < M.SHARE[1] then break end
    drop[s], w, share = true, w - v, next_share
  end
  local out = {}
  for _, s in ipairs(kept) do
    if not drop[s] then
      s.id = #out + 1
      out[#out + 1] = s
    end
  end
  ruin.slots = out
  ruin.relic.play_loot = true
  return ruin
end

return M
