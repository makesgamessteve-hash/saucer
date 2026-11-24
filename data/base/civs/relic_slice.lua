-- SPDX-License-Identifier: MIT
-- add-relic-stations, first slice (design civs-and-relics §9): the one hard-seeded civ, the Vyrr. Roster generation
-- is not part of the slice; this record already has the final schema's language and material table, plus the
-- fields every other civ record has (sim/civs.lua), so the Xenoarchive, music and item labels treat it like any civ.
-- Membrane is dominant, chrome the accent, amethyst rare; the signature is chrome grown through flesh (PIERCE).
return {
  id = "vyrr", name = "Vyrr", exonym = "the Vyrr", body = "human", shape = "organic", palette = "oquun",
  domains = { "bio", "gravitics" }, fate = "plague", temperament = "ceremonial", era = "ancient",
  entrance = { { 3, 3 }, { 2, 2 } }, size_lock = 60,
  tint = { 1.0, 0.9, 0.95 }, kits = { "relic" },
  music = { scale = "phrygian", root = 4, tempo = 58, voice = "pad" }, glyph = 613,
  language = {
    massing = { spine = 1.0 },            -- the slice builds only the spine archetype
    edges = "round", rhythm = "ribbed",   -- ribs every hall: the chrome spines and their wound rings sit on them
    senses = "sight",                     -- lit by vein pulse and amethyst glow, dimly
    lamp_colors = { { 0.78, 0.42, 1.0 }, { 1.0, 0.36, 0.46 }, { 0.45, 0.85, 1.0 } },
  },
  materials = {
    dominant = { id = "membrane", share = { 0.55, 0.70 } },
    accent = { id = "chrome", share = { 0.20, 0.35 } },
    rare = { id = "amethyst", share = { 0.03, 0.10 } },
    signature = { rule = "PIERCE", guest = "chrome", host = "membrane", ring = "wound" },
    decay = { "flesh_necrotic", "iron_rust" },
  },
  -- the matcap the chrome reflects: the civ's own lamps (view space: x right, y up, z toward the eye) and intensity
  matcap = { { 0.55, 0.65, 0.55, 1.15 }, { -0.7, 0.25, 0.45, 0.55 }, { 0.1, -0.8, 0.4, 0.35 } },
}
