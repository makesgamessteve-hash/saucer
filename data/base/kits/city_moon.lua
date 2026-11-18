-- SPDX-License-Identifier: MIT
-- Moon city kit (OpenSpec add-cities): domes in a crater and terraced canyon-wall districts, low gravity,
-- no air, earthlight. 9 x 9 lots (2.1 km), a crater floor in the middle with a great dome.
return {
  id = "city_moon",
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
  grid = { 552, 130, 552 },
  city = {
    body = "moon", name = "Moon city", lots = { 9, 9 }, lot = 32, street = 24, margin = 24, approach = 24,
    ground = 40, under = { 1, 2 }, tower = { 12, 24, 16, 40 }, mix = { 15, 40, 25, 20 }, tiers = { 0 },
    terrace = 7, crater = 2, gravity = 0.16,
    env = { fog = { 0.0, 0.0, 0.0 }, clear = { 0.0, 0.0, 0.01 }, density = 0.0, light = { 0.95, 0.95, 1.0 }, ambient = 0.35, earthlight = true },
  },
  color = { 0.62, 0.64, 0.70 }, uv = 0.125, solid_color = { 0.30, 0.31, 0.36 }, window_color = { 0.8, 0.9, 1.0 },
  floor_color = { 0.55, 0.56, 0.6 },
}
