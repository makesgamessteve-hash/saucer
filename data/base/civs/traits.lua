-- SPDX-License-Identifier: MIT
-- Civilization trait tables (concept §5.3, add-wider-dark). sim/civs.lua
-- draws every generated civ from these with its own child seed, so a mod can
-- add names, bodies, shapes or scales by overriding this file.
return {
  count = 8, -- civs per universe (the two hand-tuned ones included); add-civ-roster: roster_size wins when set
  -- add-civ-roster (design §1): the roster size (clamped to roster_min..roster_max) and eight trait axes. The legacy
  -- fields below stay as they were drawn; every axis is drawn *consistent* with them (sim/civroster.lua), so the old
  -- fields are a function of the axes and old universes keep their sites, kits and music.
  roster_size = 8, roster_min = 6, roster_max = 10,
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
  axes = {
    -- body scale: the legacy body is its image (tiny -> tiny, human/large -> human, giant/colossal -> giant)
    body_scale = { tiny = { body = "tiny", w = 2 }, human = { body = "human", w = 3 }, large = { body = "human", w = 2 },
                   giant = { body = "giant", w = 2 }, colossal = { body = "giant", w = 1 } },
    biology = { bilateral = 3, radial = 2, serpentine = 2, colonial = 2, sessile_pairs = 1, lithic = 1, energy_lattice = 1 },
    senses = { sight = 3, echo = 2, chemical = 2, field = 2, tidal = 1, touch = 1 },
    -- social structure: picks the massing archetype of its relics
    -- (and, with values, the legacy temperament: a civ's temperament is one its values or its social structure allow)
    social = { hive = { massing = { "hive", "cluster" }, temper = { "reclusive", "ceremonial" }, w = 2 },
               caste = { massing = { "spine" }, temper = { "proud", "ceremonial" }, w = 2 },
               council = { massing = { "cluster", "spine" }, temper = { "mercantile", "curious" }, w = 2 },
               nomad = { massing = { "ring", "helix" }, temper = { "mercantile", "curious", "reclusive" }, w = 2 },
               gestalt = { massing = { "shell" }, temper = { "ceremonial", "curious" }, w = 1 },
               solitary = { massing = { "cluster" }, temper = { "proud", "reclusive" }, w = 1 } },
    -- tech focus: a civ's first legacy domain is its tech focus when it is one of these (resonance and lithics are new)
    tech = { optics = 2, gravitics = 2, bio = 2, fold = 2, resonance = 1, lithics = 1 },
    -- values, weighted per legacy temperament (the temperament is a function of values and social structure)
    values = { knowledge = { "curious", "reclusive" }, hoarding = { "mercantile", "proud" }, faith = { "ceremonial" },
               kinship = { "reclusive", "mercantile" }, harmony = { "ceremonial", "curious" }, conquest = { "proud" },
               craft = { "mercantile", "curious" } },
    era = { primordial = 1, ancient = 2, old = 3, recent = 2 },
  },
  -- the era's span on the history's 1 Myr axis (thousands of years before now: from, to)
  era_kyr = { primordial = { 1000, 600 }, ancient = { 700, 250 }, old = { 300, 40 }, recent = { 60, 2 } },
  -- diversity (design §1.1): at least this many massing archetypes and body scales per roster, at most this many shared
  -- axis values between two civs, and how many tries before the deterministic swap
  diversity = { massings = 3, scales = 2, shared = 3, tries = 16 },
  -- endonym phonology by sense (design §1.4): onsets, middles, codas
  phonology = {
    sight = { { "Ae", "Ly", "Vi", "So", "Ira" }, { "", "li", "ra", "e" }, { "n", "s", "ra", "el" } },
    echo = { { "Tk", "Qq", "K'", "Tak", "Ikk" }, { "'", "ek", "tt", "a" }, { "k", "tt", "q", "'ik" } },
    chemical = { { "Aa", "Lu", "Ree", "Oo", "Shaa" }, { "la", "ru", "aa", "lo" }, { "l", "r", "aal", "uu" } },
    field = { { "Mm", "Nn", "Hum", "Unn", "Om" }, { "u", "nu", "o", "a" }, { "un", "mm", "nn", "om" } },
    tidal = { { "Sa", "Ma", "Ru", "Lo", "Wa" }, { "-an", "a", "u", "o" }, { "u", "an", "-u", "ul" } },
    touch = { { "Gh", "Kh", "Dur", "Bra", "Oz" }, { "a", "ru", "gh", "o" }, { "az", "gh", "ur", "k" } },
  },
  -- exonyms (design §1.4): a trader nickname from the dominant trait and a signature word
  exonym = {
    first = { echo = "Bell", chemical = "Scent", field = "Hum", tidal = "Tide", touch = "Stone", sight = "Glass",
              hive = "Swarm", caste = "Spire", council = "Circle", nomad = "Drift", gestalt = "Choir", solitary = "Keep" },
    second = { optics = "Lens", gravitics = "Weight", bio = "Grown", fold = "Folded", resonance = "Singers",
               lithics = "Carvers" },
    third = { tiny = "Mites", human = "Folk", large = "Striders", giant = "Titans", colossal = "Mountains" },
  },
  -- station names (design §1.4): <function word> of <glyph word>
  station_words = { "Reliquary", "Brood-Spine", "Choir-Hall", "Vault", "Seedhouse", "Archive", "Bastion", "Lantern",
                    "Cradle", "Orrery" },
}
