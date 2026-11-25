-- SPDX-License-Identifier: MIT
-- Planet city kit (OpenSpec add-cities): a horizon-wide megacity built from the sim/citygen.lua plan: a
-- 12 x 12 grid of lots (3 km square) in 16 districts, spires up to 400 m, three undercity levels linked by
-- tunnels under the streets. Strong gravity: hovering in the open air costs Charge. 
return {
  id = "city_planet",
  style = "city",
  cell = 4.0,
  wall = 0.5,
  big = 4,
  rooms = {
    [1] = { 1, 1, 4 },
    [4] = { 20, 7, 20 },     -- hall: 80 x 28 x 80 m
  },
  wing = { 36, 7, 12 },
  shaft = { 9, 34, 9 },
  chamber = { 3, 1, 3 },
  doors = {
    [0] = { 1.0, 1.0 },
    [1] = { 2.6, 2.1 },
    [4] = { 34.0, 20.0 },
  },
  texture = "city",
  debris = 1,
  links = false,
  grid = { 2064, 170, 1392 },  -- 8.3 x 0.68 x 5.6 km: the 12 x 12 core plus a skyline ring of twelve lots
  city = {
    body = "planet", name = "Planet city", lots = { 12, 12 }, ring = 12, horizon = true, lifts = true, rails = { rows = { 4, 8, 11 }, height = 8 }, undercity = "flooded", storm = true, lot = 32, street = 24, margin = 24, approach = 24,
    ground = 60, under = { 2, 3 }, tower = { 14, 30, 24, 100 }, mix = { 35, 35, 15, 15 }, tiers = { 0 },
    gravity = 1.2,  -- Charge per second to hover in the open air of the city
    env = { fog = { 0.30, 0.34, 0.42 }, clear = { 0.22, 0.26, 0.34 }, density = 1.0, light = { 0.7, 0.72, 0.8 }, ambient = 0.7, night = true },
  },
  color = { 0.78, 0.82, 0.90 }, uv = 0.125, solid_color = { 0.34, 0.38, 0.48 }, window_color = { 1.0, 0.82, 0.45 },
  floor_color = { 0.7, 0.72, 0.78 },
}
