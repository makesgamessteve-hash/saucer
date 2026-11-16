-- SPDX-License-Identifier: MIT
-- The galley (OpenSpec add-holodeck-home-life): ingredients from traders and
-- from alien derelicts, recipes that need them, and the buffs a meal gives
-- (buff id -> sim minutes, see home/buffs.lua). The pantry starts with
-- `starter`. Cooking takes `cook_seconds` at the stove. Mods may override it.
return {
  cook_seconds = 3,
  starter = { noodles = 2, tea = 2 },
  ingredients = {
    { id = "noodles",      name = "Station noodles",    origin = "trader" },
    { id = "tea",          name = "Leaf tea",           origin = "trader" },
    { id = "eggs",         name = "Hydro eggs",         origin = "trader" },
    { id = "velari_spice", name = "Velari ember spice", origin = "alien" },
    { id = "sunfruit",     name = "Oquun sunfruit",     origin = "alien" },
    { id = "glowcap",      name = "Glowcap mushrooms",  origin = "alien" },
  },
  recipes = {
    { id = "snack", name = "Quick snack", needs = {}, buffs = { fed = 5 },
      text = "You cook a quick meal. Well fed: Charge recharges faster for a while." },
    { id = "tea", name = "Pot of leaf tea", needs = { tea = 1 }, buffs = { calm = 5 },
      text = "A pot of leaf tea, watching the stars. Calm: Scanner and Jammer recharge faster." },
    { id = "spiced_noodles", name = "Ember-spiced noodles", needs = { noodles = 1, velari_spice = 1 },
      buffs = { fed = 10, keen = 10 },
      text = "Station noodles with Velari ember spice. Well fed and keen: Scanner pulses last longer." },
    { id = "sunfruit_omelette", name = "Sunfruit omelette", needs = { eggs = 1, sunfruit = 1 },
      buffs = { fed = 10, steady = 10 },
      text = "A sunfruit omelette. Well fed and steady: the hull mends twice as fast." },
    { id = "glowcap_stew", name = "Glowcap stew", needs = { noodles = 1, glowcap = 1 }, buffs = { keen = 8, calm = 8 },
      text = "A bowl of glowing stew. Keen and calm." },
  },
}
