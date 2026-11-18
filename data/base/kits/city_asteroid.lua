-- SPDX-License-Identifier: MIT
-- Asteroid city kit (OpenSpec add-cities): a hollow rock, carved. A shell of rock slabs with a mouth in
-- front of the spaceport, two tiers of lots inside joined by shafts, a spin-gravity drum at the heart,
-- tunnels between the halls. The whole rock tumbles slowly in the sky.
return {
  id = "city_asteroid",
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
  grid = { 528, 130, 528 },
  city = {
    body = "asteroid", name = "Asteroid city", lots = { 8, 8 }, lot = 32, street = 24, margin = 40, approach = 40,
    ground = 40, under = { 0, 1 }, tower = { 12, 22, 12, 24 }, mix = { 10, 55, 20, 15 }, tiers = { 0, 40 },
    shell = 14, drum = { 32, 32, 32 }, gravity = 0, spin = 0.0015,
    env = { fog = { 0.10, 0.06, 0.04 }, clear = { 0.03, 0.02, 0.02 }, density = 0.5, light = { 1.0, 0.7, 0.5 }, ambient = 0.45 },
  },
  color = { 0.74, 0.62, 0.52 }, uv = 0.125, solid_color = { 0.32, 0.25, 0.20 }, window_color = { 1.0, 0.7, 0.35 },
  floor_color = { 0.66, 0.56, 0.48 },
}
