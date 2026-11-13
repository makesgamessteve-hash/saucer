-- SPDX-License-Identifier: MIT
return {
  prefixes = {
    { id = "resonant", name = "Resonant", stat = "shield_regen", min = 15, max = 30 },
    { id = "humming",  name = "Humming",  stat = "charge_regen", min = 5,  max = 15 },
    { id = "lucid",    name = "Lucid",    stat = "scan_range",   min = 10, max = 25 },
  },
  suffixes = {
    { id = "ten_suns", name = "of Ten Suns", stat = "max_charge", min = 10, max = 20 },
    { id = "stillness",name = "of Stillness",stat = "turn",       min = 5,  max = 12 },
  },
  quirks = {
    { id = "unstable", name = "Unstable" },
    { id = "loud",     name = "Loud" },
    { id = "bonded",   name = "Bonded" },
  },
}
