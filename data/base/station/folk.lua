-- SPDX-License-Identifier: MIT
-- The people of a trader station (OpenSpec add-pocket-station-visits). Mods
-- may override or extend this file.
--   species: how station folk look (meshes/npc.lua builds one mesh per entry)
--   vendors: market stall keepers. buys = item categories they pay a bonus
--            for (any other sellable item at `other`); sells = home shop
--            kinds (home/shop.lua) they stock; services = charge / repair.
--   drinks:  the bar's menu; a drink gives a small buff (home/buffs.lua)
--   chatter: what bar patrons and passers-by say when you talk to them
--   thief:   the pickpocket (speeds are multiples of your walking speed)
return {
  species = {
    { id = "human",   skin = { 0.95, 0.8, 0.65 }, suit = { 0.3, 0.45, 0.7 }, head = "round", tall = 1.0 },
    { id = "velari",  skin = { 0.55, 0.85, 0.9 }, suit = { 0.75, 0.7, 0.55 }, head = "dome", tall = 1.12 },
    { id = "oquun",   skin = { 0.6, 0.75, 0.4 },  suit = { 0.5, 0.3, 0.45 },  head = "stalk", tall = 0.9 },
    { id = "brann",   skin = { 0.75, 0.5, 0.4 },  suit = { 0.35, 0.5, 0.35 }, head = "wide", tall = 1.2 },
    { id = "lumen",   skin = { 0.85, 0.85, 1.0 }, suit = { 0.9, 0.9, 0.95 },  head = "dome", tall = 0.95, glow = true },
    { id = "hooded",  skin = { 0.2, 0.18, 0.25 }, suit = { 0.22, 0.16, 0.3 }, head = "hood", tall = 0.98, thief = true },
  },
  vendors = {
    { id = "scrap", name = "Scrap dealer", species = "brann", color = { 0.95, 0.55, 0.2 },
      buys = { material = 1.25, module = 1.2 }, other = 0.95, always = true },
    { id = "curio", name = "Curio broker", species = "velari", color = { 0.6, 0.4, 0.95 },
      buys = { curio = 1.25, tool = 1.2 }, other = 0.9 },
    { id = "grocer", name = "Grocer", species = "oquun", color = { 0.4, 0.85, 0.35 }, sells = { ingredient = true } },
    { id = "archive", name = "Archivist", species = "lumen", color = { 0.35, 0.7, 1.0 }, sells = { book = true, program = true } },
    { id = "outfit", name = "Holo outfitter", species = "human", color = { 1.0, 0.8, 0.3 }, sells = { module = true } },
    { id = "chandler", name = "Chandler", species = "brann", color = { 0.3, 0.9, 0.85 }, services = true, always = true },
  },
  drinks = {
    { id = "nebula_tea", name = "Nebula tea", price = 4, buff = "calm", minutes = 6 },
    { id = "spark_fizz", name = "Spark fizz", price = 6, buff = "keen", minutes = 6 },
    { id = "hull_stout", name = "Hull-plate stout", price = 8, buff = "steady", minutes = 8 },
  },
  chatter = {
    "They say the Velari folded whole cities into seeds.",
    "Watch your pockets on the concourse. Hooded types work the crowd.",
    "Shrink your saucer too small and you lose it down the back of a sofa.",
    "The Resonant hum? I hear it every night from the far hangar.",
    "A trader paid triple for a Fold Shard last week. Triple!",
    "Snatchers never take what you've banked. Get home first.",
    "My cousin flies a one-seat car through derelict vents. Mad.",
    "If someone grabs your coin, run them down. They tire before you.",
  },
  thief = {
    after = 20,         -- seconds on foot before the pickpocket starts working the crowd
    notice = 14,        -- meters: he starts stalking you from this far
    stalk = 1.15,       -- his speed while sneaking up (x your walking speed)
    reach = 0.9,        -- meters: close enough to lift the coin
    spot_dist = 7,      -- meters: facing him within spot_angle this close spooks him
    spot_angle = 0.45,
    cooldown = 30,      -- seconds he keeps away after being spotted
    flee = 1.35,        -- his running speed (x your walking speed; you sprint at 1.7)
    catch = 1.3,        -- meters: close enough to grab him
    head_start = 1.5,   -- seconds after the lift when he darts off at `burst` and cannot be grabbed
    burst = 2.0,
    escape = 35,        -- seconds of running before he gets away to the fence
    fence_min = 40,     -- the bartender's price to buy your saucer back (credits) ...
    fence_frac = 0.2,   -- ... or this share of the hold's sale value, whichever is more
  },
}
