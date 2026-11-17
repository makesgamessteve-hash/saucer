-- SPDX-License-Identifier: MIT
-- Civilization trait tables (concept §5.3, add-wider-dark). sim/civs.lua
-- draws every generated civ from these with its own child seed, so a mod can
-- add names, bodies, shapes or scales by overriding this file.
return {
  count = 8, -- civs per universe (the two hand-tuned ones included)
  onsets = { "Ka", "Vo", "Ther", "Ul", "Sy", "Mo", "Ixa", "Re", "Dra", "Phe", "Qa", "Zun", "Ne", "Os", "Tal" },
  middles = { "", "", "ri", "la", "mo", "the", "va", "sk", "un", "ae" },
  codas = { "n", "th", "ri", "x", "sh", "ar", "ii", "on", "el", "um" },
  bodies = { "human", "tiny", "giant" },
  shapes = {
    angular = { kits = { "starship", "station", "city" }, palette = "velari" },
    organic = { kits = { "hive", "city", "starship" }, palette = "oquun" },
    crystalline = { kits = { "city", "hive", "station" }, palette = "velari" },
    modular = { kits = { "station", "starship", "hive" }, palette = "oquun" },
  },
  domains = { "optics", "gravitics", "bio", "fold" },
  fates = { "flight", "plague", "war of silence", "ascension", "sleep", "schism" },
  temperaments = { "mercantile", "reclusive", "curious", "ceremonial", "proud" },
  -- how a civ's sites are entered and how often they size-lock their ducts
  entrances = { { { 3, 3 }, { 2, 2 } }, { { 3, 1 }, { 2, 3 } }, { { 2, 2 }, { 3, 3 } } },
  size_lock = { 35, 80 },
  -- tints multiply the kit textures of the civ's sites
  tints = { { 1.0, 0.86, 0.78 }, { 0.8, 0.95, 1.0 }, { 0.9, 1.0, 0.82 }, { 1.0, 0.9, 1.0 }, { 0.85, 0.85, 1.0 },
            { 1.0, 1.0, 0.8 } },
  -- procedural music (view/music.lua): a scale, a root and a tempo per civ
  scales = { "dorian", "pentatonic", "phrygian", "lydian", "whole", "minor" },
  voices = { "pluck", "bell", "pad" },
  tempo = { 56, 104 },
}
