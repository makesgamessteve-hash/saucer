-- SPDX-License-Identifier: MIT
-- add-material-system: the material library (design civs-and-relics §2.3.1). Every record has a kind (metal,
-- crystal, organic, stone, enamel), a palette ramp (lo = the dark end, hi = the bright end, linear RGB) and the
-- kind's render parameters. Civs pick materials by id (civs/relic_slice.lua); mods may add records. The renderer
-- (view/materials.lua) turns a record into one of the eight per-view material slots of the shader:
--   metal:   reflect 0-1 (share of the matcap reflection), spec (Blinn exponent 8-96), f0 (fresnel), rough,
--            brushed 0-1 (the highlight stretched across the brushing), ripple 0-0.3 (a liquid metal's moving normal)
--   crystal: refract 0-1 (fake refraction through the matcap), emit 0-1, fresnel (rim tint = rim), pulse (Hz),
--            sparkle 0-1 (facets that catch the light and twinkle; off in lite)
--   organic: wrap 0-1, sss (subsurface tint), wobble { amp m, period s, scale m }, pulse (vein Hz), wet 0-1, emit
--   stone / enamel: spec, rough (shaded as a dull metal)
return {
  -- metals
  chrome = { kind = "metal", lo = { 0.03, 0.035, 0.05 }, hi = { 0.92, 0.96, 1.0 }, reflect = 0.92, spec = 72, f0 = 0.55,
             rough = 0.1 },
  black_chrome = { kind = "metal", lo = { 0.01, 0.01, 0.015 }, hi = { 0.45, 0.48, 0.55 }, reflect = 0.85, spec = 64, f0 = 0.4,
                   rough = 0.15 },
  gold = { kind = "metal", lo = { 0.12, 0.06, 0.01 }, hi = { 1.0, 0.86, 0.45 }, reflect = 0.85, spec = 48, f0 = 0.6, rough = 0.2 },
  rose_gold = { kind = "metal", lo = { 0.12, 0.04, 0.03 }, hi = { 1.0, 0.75, 0.68 }, reflect = 0.8, spec = 40, f0 = 0.5,
                rough = 0.25 },
  silver = { kind = "metal", lo = { 0.05, 0.05, 0.06 }, hi = { 0.95, 0.95, 0.97 }, reflect = 0.88, spec = 56, f0 = 0.6,
             rough = 0.15, brushed = 0.5 },
  mercury = { kind = "metal", lo = { 0.04, 0.04, 0.05 }, hi = { 0.85, 0.88, 0.92 }, reflect = 0.95, spec = 96, f0 = 0.7,
              rough = 0.0, ripple = 0.14 },
  bronze_ox = { kind = "metal", lo = { 0.05, 0.08, 0.06 }, hi = { 0.45, 0.72, 0.6 }, reflect = 0.35, spec = 16, f0 = 0.2,
                rough = 0.6, brushed = 0.3 },
  iron_rust = { kind = "metal", lo = { 0.06, 0.02, 0.01 }, hi = { 0.62, 0.3, 0.12 }, reflect = 0.15, spec = 8, f0 = 0.08,
                rough = 0.85 },
  titanium_blue = { kind = "metal", lo = { 0.03, 0.04, 0.1 }, hi = { 0.5, 0.65, 1.0 }, reflect = 0.75, spec = 40, f0 = 0.45,
                    rough = 0.3, brushed = 0.7 },
  -- crystals
  amethyst = { kind = "crystal", lo = { 0.10, 0.02, 0.18 }, hi = { 0.85, 0.5, 1.0 }, refract = 0.75, emit = 0.55,
               rim = { 0.75, 0.55, 1.0 }, spec = 80, f0 = 0.12, pulse = 0.25, facets = true },
  quartz = { kind = "crystal", lo = { 0.12, 0.13, 0.15 }, hi = { 0.95, 0.97, 1.0 }, refract = 0.8, emit = 0.15,
             rim = { 0.9, 0.95, 1.0 }, spec = 96, f0 = 0.1, facets = true, sparkle = 0.6 },
  rose_quartz = { kind = "crystal", lo = { 0.18, 0.06, 0.08 }, hi = { 1.0, 0.75, 0.8 }, refract = 0.7, emit = 0.25,
                  rim = { 1.0, 0.7, 0.8 }, spec = 80, f0 = 0.1, facets = true, sparkle = 0.5 },
  obsidian = { kind = "crystal", lo = { 0.01, 0.01, 0.02 }, hi = { 0.3, 0.3, 0.38 }, refract = 0.3, emit = 0.0,
               rim = { 0.5, 0.5, 0.7 }, spec = 96, f0 = 0.08, facets = true, sparkle = 0.3 },
  amber = { kind = "crystal", lo = { 0.2, 0.07, 0.0 }, hi = { 1.0, 0.7, 0.2 }, refract = 0.6, emit = 0.3,
            rim = { 1.0, 0.75, 0.3 }, spec = 40, f0 = 0.06 },
  -- organics
  membrane = { kind = "organic", lo = { 0.16, 0.05, 0.08 }, hi = { 0.75, 0.42, 0.5 }, wrap = 0.55,
               sss = { 0.85, 0.22, 0.32 }, wobble = { 0.18, 5.0, 9.0 }, pulse = 0.9, wet = 0.6, emit = 0.55 },
  skin = { kind = "organic", lo = { 0.2, 0.1, 0.07 }, hi = { 0.85, 0.6, 0.48 }, wrap = 0.4, sss = { 0.8, 0.3, 0.2 },
           wobble = { 0.08, 6.0, 10.0 }, pulse = 0.0, wet = 0.2, emit = 0.0 },
  vein = { kind = "organic", lo = { 0.12, 0.02, 0.05 }, hi = { 0.7, 0.15, 0.3 }, wrap = 0.5, sss = { 1.0, 0.2, 0.35 },
           wobble = { 0.05, 1.2, 3.0 }, pulse = 1.2, wet = 0.8, emit = 0.8 },
  flesh_necrotic = { kind = "organic", lo = { 0.06, 0.08, 0.05 }, hi = { 0.42, 0.5, 0.36 }, wrap = 0.35,
                     sss = { 0.35, 0.5, 0.25 }, wobble = { 0.04, 14.0, 4.0 }, pulse = 0.0, wet = 0.3, emit = 0.0 },
  -- the inflamed ring where a guest pierces a host (PIERCE): an organic with a hot rim and a fast pulse
  wound = { kind = "organic", lo = { 0.25, 0.03, 0.04 }, hi = { 1.0, 0.35, 0.25 }, wrap = 0.6, sss = { 1.0, 0.3, 0.15 },
            wobble = { 0.06, 2.0, 2.0 }, pulse = 1.6, wet = 0.9, emit = 0.9 },
  chitin = { kind = "organic", lo = { 0.05, 0.04, 0.03 }, hi = { 0.5, 0.42, 0.3 }, wrap = 0.15, sss = { 0.3, 0.2, 0.1 },
             wobble = { 0.0, 8.0, 8.0 }, pulse = 0.0, wet = 0.9, emit = 0.0 },
  nacre = { kind = "organic", lo = { 0.3, 0.3, 0.35 }, hi = { 0.95, 0.92, 1.0 }, wrap = 0.3, sss = { 0.6, 0.8, 1.0 },
            wobble = { 0.0, 8.0, 8.0 }, pulse = 0.0, wet = 1.0, emit = 0.0 },
  coral = { kind = "organic", lo = { 0.25, 0.08, 0.06 }, hi = { 1.0, 0.55, 0.45 }, wrap = 0.4, sss = { 1.0, 0.45, 0.3 },
            wobble = { 0.03, 9.0, 6.0 }, pulse = 0.0, wet = 0.3, emit = 0.0 },
  -- stone / enamel
  basalt = { kind = "stone", lo = { 0.03, 0.03, 0.035 }, hi = { 0.35, 0.34, 0.36 }, spec = 8, rough = 0.9 },
  marble_white = { kind = "stone", lo = { 0.3, 0.3, 0.32 }, hi = { 0.96, 0.95, 0.93 }, spec = 24, rough = 0.5 },
  ceramic = { kind = "enamel", lo = { 0.2, 0.2, 0.22 }, hi = { 0.9, 0.9, 0.92 }, spec = 48, rough = 0.3 },
  enamel_white = { kind = "enamel", lo = { 0.25, 0.25, 0.27 }, hi = { 1.0, 1.0, 1.0 }, spec = 56, rough = 0.2 },
}
