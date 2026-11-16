-- SPDX-License-Identifier: MIT
-- Holodeck upgrade modules (OpenSpec add-holodeck-home-life). Each installed
-- module raises its track one level: size = half the width of the simulated
-- space in meters, detail = how densely programs fill it, seats = how many
-- people can share one running program (co-op guests). Mods may add levels.
return {
  size   = { name = "Holo emitter array",    what = "space",  levels = { 6, 10, 15 }, value = 35 },
  detail = { name = "Holo detail lattice",   what = "detail", levels = { 1, 2, 3 }, value = 30 },
  seats  = { name = "Guest pattern buffer",  what = "guests", levels = { 1, 2, 4 }, value = 40 },
}
