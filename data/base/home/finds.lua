-- SPDX-License-Identifier: MIT
-- Home finds (OpenSpec add-holodeck-home-life): what waits in a derelict's
-- vault besides its loot, per kit. Each player gets their own copy. kind =
-- "program" (a data core: decode it at the lab bench to add the holodeck
-- program `id`), "module" (a holodeck upgrade, installed at its panel),
-- "book" (shelved when you bank it) or "ingredient" (`n` go to the pantry
-- when you bank them). Up to three per vault. Mods may override this file.
return {
  starship = {
    { kind = "program", id = "memory" },
    { kind = "book", id = "velari_log" },
    { kind = "ingredient", id = "velari_spice", n = 3 },
  },
  station = {
    { kind = "module", id = "detail" },
    { kind = "book", id = "station_log" },
    { kind = "ingredient", id = "glowcap", n = 2 },
  },
  city = {
    { kind = "program", id = "forest" },
    { kind = "ingredient", id = "sunfruit", n = 3 },
    { kind = "book", id = "oquun_hymns" },
  },
}
