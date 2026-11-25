-- SPDX-License-Identifier: MIT
-- add-design-language (design civs-and-relics §2): the tables sim/language.lua turns a civ's trait axes into its
-- design language with. Every table is keyed by an axis value; weights are integers. Mods may override the file.
return {
  -- §2.1 massing: the social structure's archetypes get most of the weight, the rest a little
  massings = { "ring", "spine", "cluster", "hive", "shell", "lattice", "helix", "organism" },
  -- §2.2 primitives by biology (weights)
  primitives = {
    bilateral = { box = 3, wedge = 3, cyl = 2, sphere = 1, torus = 1, lathe = 1, blob = 0, shard = 1 },
    radial = { box = 0, wedge = 1, cyl = 2, sphere = 2, torus = 3, lathe = 3, blob = 1, shard = 1 },
    serpentine = { box = 0, wedge = 1, cyl = 3, sphere = 1, torus = 2, lathe = 2, blob = 3, shard = 0 },
    colonial = { box = 0, wedge = 0, cyl = 1, sphere = 3, torus = 1, lathe = 1, blob = 3, shard = 1 },
    sessile_pairs = { box = 1, wedge = 1, cyl = 2, sphere = 2, torus = 1, lathe = 2, blob = 2, shard = 1 },
    lithic = { box = 3, wedge = 2, cyl = 1, sphere = 0, torus = 0, lathe = 1, blob = 0, shard = 3 },
    energy_lattice = { box = 1, wedge = 1, cyl = 2, sphere = 2, torus = 2, lathe = 0, blob = 0, shard = 3 },
  },
  -- symmetry mode by biology (radial picks n from radial_n)
  symmetry = { bilateral = "bilateral", radial = "radial", serpentine = "none", colonial = "fractal",
               sessile_pairs = "bilateral", lithic = "bilateral", energy_lattice = "fractal" },
  radial_n = { 3, 5, 7 },
  aperture = { bilateral = { "arch", "slot" }, radial = { "iris", "lens" }, serpentine = { "valve", "maw" },
               colonial = { "maw", "hex" }, sessile_pairs = { "valve", "iris" }, lithic = { "slot", "arch" },
               energy_lattice = { "hex", "lens" } },
  edge = { knowledge = { "hard", "chamfer" }, hoarding = { "chamfer", "fluted" }, faith = { "fluted", "round" },
           kinship = { "round" }, harmony = { "round", "fluted" }, conquest = { "serrated", "hard" },
           craft = { "chamfer", "fluted" } },
  -- how organic the skins are by tech focus (0..1, the biology adds organic_bio)
  organic = { optics = 0.1, gravitics = 0.15, bio = 0.7, fold = 0.25, resonance = 0.3, lithics = 0.05 },
  organic_bio = { serpentine = 0.2, colonial = 0.2, sessile_pairs = 0.15, lithic = -0.1, energy_lattice = -0.1 },
  -- §2.3.2 material bias: kind weights by tech focus, plus favourite materials by tech, values and biology
  kinds = {
    optics = { metal = 2, crystal = 3, organic = 0, stone = 1 }, gravitics = { metal = 4, crystal = 1, organic = 0, stone = 1 },
    bio = { metal = 1, crystal = 1, organic = 4, stone = 0 }, fold = { metal = 4, crystal = 1, organic = 1, stone = 1 },
    resonance = { metal = 1, crystal = 4, organic = 1, stone = 1 }, lithics = { metal = 1, crystal = 3, organic = 0, stone = 3 },
  },
  favour = {
    optics = { "silver", "quartz", "prism" }, gravitics = { "chrome", "black_chrome", "titanium_blue" },
    bio = { "membrane", "skin", "chitin", "vein" }, fold = { "chrome", "titanium_blue", "obsidian" },
    resonance = { "rose_quartz", "quartz", "nacre" }, lithics = { "basalt", "obsidian", "marble_white" },
    hoarding = { "gold" }, faith = { "gold", "marble_white" }, craft = { "bronze_ox" }, conquest = { "black_chrome" },
    kinship = { "coral", "nacre" }, harmony = { "nacre", "rose_quartz" }, knowledge = { "silver", "enamel_white" },
    colonial = { "coral", "amber" }, lithic = { "basalt", "obsidian" },
  },
  -- §2.3.3 the odd-pair table: guest <-> host, weight x100, and the rule that builds it
  odd_pairs = {
    { "chrome", "skin", 100, "PIERCE" }, { "gold", "quartz", 100, "INLAY" }, { "mercury", "membrane", 80, "FLOW" },
    { "silver", "chitin", 80, "INLAY" }, { "black_chrome", "nacre", 70, "PLATE" }, { "rose_gold", "coral", 60, "CRUST" },
    { "obsidian", "vein", 60, "PIERCE" }, { "amber", "iron_rust", 50, "ENCASE" }, { "chrome", "membrane", 90, "PIERCE" },
    { "gold", "skin", 60, "PLATE" }, { "silver", "amethyst", 60, "ENCASE" }, { "amethyst", "black_chrome", 50, "CRUST" },
  },
  -- the ring each rule draws where guest meets host
  ring = { PIERCE = "wound", INLAY = "vein", FLOW = "mercury", PLATE = "chitin", CRUST = "quartz", ENCASE = "amber" },
  -- §2.3.4 decay materials by fate
  decay = { plague = { "flesh_necrotic", "iron_rust" }, ["war of silence"] = { "iron_rust", "obsidian" },
            ascension = { "quartz", "rose_quartz" }, sleep = { "basalt", "flesh_necrotic" },
            flight = { "iron_rust", "basalt" }, schism = { "iron_rust", "flesh_necrotic" } },
  -- §2.5 the light model by senses: model, lamp count scale, intensity scale, haze, and its tint family
  light = {
    sight = { model = "chromatic", lamps = 1.0, k = 1.0, haze = 0.2, pools = 0.6 },
    echo = { model = "ripple", lamps = 0.35, k = 0.25, haze = 0.05, pools = 0.1 },
    chemical = { model = "fogbank", lamps = 0.8, k = 0.7, haze = 0.6, pools = 0.4 },
    field = { model = "arc", lamps = 0.7, k = 0.9, haze = 0.15, pools = 0.3, key = { 0.6, 0.8, 1.0 } },
    tidal = { model = "orbit", lamps = 0.5, k = 0.8, haze = 0.25, pools = 0.3, orbs = 4 },
    touch = { model = "dark", lamps = 0.1, k = 0.12, haze = 0.0, pools = 0.0 },
  },
  max_lights = 16,
  -- §2.6 glyphs by senses
  glyphs = { sight = { "branching_script", "stacked_bars" }, echo = { "radial_rings" }, chemical = { "chem_blobs" },
             field = { "dot_matrix", "stacked_bars" }, tidal = { "radial_rings", "branching_script" },
             touch = { "relief_braille" } },
  carrier = { sight = "emissive_inlay", echo = "relief", chemical = "emissive_inlay", field = "holo", tidal = "crystal_etch",
              touch = "relief" },
  -- §2.7 sound: drone by the dominant material's kind, room tone by the massing
  drone = { metal = "chime", crystal = "glass", organic = "breath", stone = "stone", enamel = "glass" },
  room_tone = { ring = "wide", spine = "nave", cluster = "warren", hive = "buzz", shell = "choral", lattice = "dry",
                helix = "swirl", organism = "gut" },
}
