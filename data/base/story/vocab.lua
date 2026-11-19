-- SPDX-License-Identifier: MIT
-- Story vocabulary (OpenSpec add-run-story): the words a civilisation's traits
-- turn into when a run's story talks about it. sim/story.lua fills the
-- templates of skeletons.lua and twists.lua with these plus the civs' names,
-- so two civilisations never sound alike. Mods may override this file.
return {
  -- temperament -> what the civ's people were
  epithet = { mercantile = "merchants", reclusive = "recluses", curious = "tinkerers", ceremonial = "ritual-keepers",
              proud = "high houses" },
  -- domain (first one of the civ) -> its crafts-people
  craft = { optics = "lens-wrights", gravitics = "weight-sculptors", bio = "grow-masters", fold = "path-wrights" },
  -- shape -> a building of theirs (singular, used as an adjective: "a {home} mural")
  home = { angular = "blade-tower", organic = "grown-hall", crystalline = "glass-spire", modular = "ring-station" },
  body = { human = "person-sized", tiny = "hand-sized", giant = "towering" },
  -- fate -> what the civ's own records blame ("the records blame {fate}")
  fate = { flight = "a flight to the stars", plague = "a plague", ["war of silence"] = "the war of silence",
           ascension = "an ascension", sleep = "a long sleep", schism = "a schism" },
  -- what the Echo really is (each run picks one)
  echo = {
    { id = "farewell", text = "a farewell" },
    { id = "warning", text = "a warning" },
    { id = "lullaby", text = "a lullaby" },
    { id = "map", text = "a map home" },
    { id = "confession", text = "a confession" },
    { id = "invitation", text = "an invitation" },
  },
  -- carriers: what a clue is called on the beam indicator and in the codex
  carriers = {
    log = { name = "Wreck log", noun = "a wreck log" },
    mural = { name = "Mural", noun = "a mural" },
    archive = { name = "Archive record", noun = "an archive record" },
    heart = { name = "The Heart", noun = "the Heart" },
  },
  -- sites by kit, for place names
  kits = { starship = "wreck", station = "station", city = "city", hive = "hive" },
  bodies = { planet = "planet", moon = "moon", asteroid = "asteroid" },
  guardians = "the Watchers",
}
