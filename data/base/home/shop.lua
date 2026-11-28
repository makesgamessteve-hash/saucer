-- SPDX-License-Identifier: MIT
-- What trader stations sell for the home (OpenSpec add-holodeck-home-life):
-- ingredients (n per purchase), holodeck programs (downloaded straight into
-- the library), holodeck upgrade modules (they come as a hold item to
-- install) and books (straight onto the shelf). Prices in credits.
return {
  { kind = "ingredient", id = "noodles", n = 2, price = 6 },
  { kind = "ingredient", id = "eggs", n = 2, price = 8 },
  { kind = "ingredient", id = "tea", n = 2, price = 5 },
  { kind = "program", id = "forest", price = 60 },
  { kind = "module", id = "size", price = 70 },
  { kind = "module", id = "detail", price = 60 },
  { kind = "module", id = "seats", price = 80 },
  { kind = "book", id = "star_cookbook", price = 12 },
  { kind = "book", id = "fold_primer", price = 10 },
  -- add-home-among-stars: furniture and garden seeds (prices in home/decor.lua)
  { kind = "furniture", id = "beanbag" },
  { kind = "furniture", id = "armchair" },
  { kind = "furniture", id = "rug" },
  { kind = "furniture", id = "lamp" },
  { kind = "furniture", id = "bookcase" },
  { kind = "furniture", id = "aquarium" },
  { kind = "furniture", id = "telescope" },
  { kind = "furniture", id = "hammock" },
  { kind = "furniture", id = "crystal" },
  { kind = "furniture", id = "poster" },
  { kind = "furniture", id = "hanging_lamp" },
  { kind = "furniture", id = "figurine" },
  { kind = "seed", id = "glowmoss", n = 2 },
  { kind = "seed", id = "sunvine", n = 2 },
  { kind = "seed", id = "emberleaf", n = 2 },
}
