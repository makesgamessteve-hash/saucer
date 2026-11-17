-- SPDX-License-Identifier: MIT
-- The two hand-tuned civilizations every universe starts with (concept §5.3).
-- add-wider-dark: the rest of a universe's civs come from the trait generator
-- (civs/traits.lua, sim/civs.lua). The extra fields drive the look (tint),
-- the kits their sites use and the procedural music of their sites.
return {
  { id = "velari", name = "Velari", body = "human", shape = "angular", palette = "velari",
    domains = { "gravitics", "fold" }, fate = "flight", temperament = "mercantile",
    entrance = { { 3, 3 }, { 2, 2 } }, size_lock = 45,
    tint = { 1.0, 1.0, 1.0 }, kits = { "starship", "station", "city" },
    music = { scale = "dorian", root = 2, tempo = 84, voice = "pluck" }, glyph = 11 },
  { id = "oquun", name = "Oquun", body = "tiny", shape = "organic", palette = "oquun",
    domains = { "bio", "optics" }, fate = "plague", temperament = "reclusive",
    entrance = { { 3, 1 }, { 2, 3 } }, size_lock = 70,
    tint = { 0.92, 1.0, 0.9 }, kits = { "hive", "station", "starship" },
    music = { scale = "pentatonic", root = 7, tempo = 66, voice = "bell" }, glyph = 29 },
}
