-- SPDX-License-Identifier: MIT
-- add-civ-roster (design §1.3): the generated history's tuning. sim/civroster.lua reads it; a mod may override it.
return {
  beats = { 5, 7 },             -- beats per civ: emergence, expansion, contacts, golden age, catastrophe, afterlife
  span_kyr = { 40, 260 },       -- how long a civ was active (thousands of years)
  stations = { 3, 9 },          -- stations a civ builds in its expansion
  -- the weight of each relation between two civs whose eras overlap, plus per-temperament and per-value nudges
  relations = { trade = 3, war = 2, alliance = 2, tutelage = 1, conquest = 1, ignorance = 2 },
  temperament = { proud = { war = 2, conquest = 2 }, mercantile = { trade = 3 }, ceremonial = { alliance = 1 },
                  curious = { tutelage = 1, trade = 1 }, reclusive = { ignorance = 3 } },
  value = { conquest = { war = 2, conquest = 3 }, harmony = { tutelage = 2, alliance = 1 }, hoarding = { trade = 1 },
            knowledge = { tutelage = 1 } },
  wing_share = { 0.10, 0.25 },  -- the share of a conquered civ's relics that carry a wing in the conqueror's language
  -- scanner lore lines (template + vocab)
  ages = { "First Chorus", "Second Chorus", "Long Quiet", "Bright Turning", "Hollow Age", "Third Tide", "Ember Reign" },
  lore = {
    "Built in the %s, sealed when the %s %s.",
    "The %s raised it in the %s; it stood until they %s.",
    "A %s work of the %s: abandoned in their %s.",
  },
  fate_verb = { flight = "fled", plague = "sickened", ["war of silence"] = "fell silent", ascension = "ascended",
                sleep = "slept", schism = "split" },
}
