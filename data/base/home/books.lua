-- SPDX-License-Identifier: MIT
-- Books and logs for the living room bookshelf (OpenSpec
-- add-holodeck-home-life). kind = "lore" (atmosphere) or "clue" (reading it
-- the first time points at something real: `clue` = "echo" names the site
-- where the next Echo waits, "sentries" counts the guards at a site).
-- Pages may use {civ}, {object}, {place} (the mystery's names) and {site}
-- (filled when the clue is read). Lines are short: the page is 8x8 text.
-- Echo transcripts and holodeck memories are added by the sim as they happen.
return {
  { id = "manual", title = "Villa Owner's Manual", kind = "lore", starter = true, pages = {
    { "Congratulations on your Villa!", "", "The dome deck holds the helm,", "the kitchen, the living room",
      "and the lab. The lower deck:", "bedroom, bathroom, engine room", "and the Holodeck." },
    { "Folding", "", "Press Q to fold the Villa into", "the Seat around you. The rooms",
      "pack themselves away. Press E", "to unfold where there is room." },
    { "The Holodeck", "", "Use the panel by its arch.", "Programs come as data cores", "(decode them at the lab bench)",
      "or from traders. Emitter, detail", "and guest modules upgrade it." },
  } },
  { id = "velari_log", title = "Velari captain's log", kind = "clue", clue = "echo", pages = {
    { "Day 212. The {object} sings", "again. Nobody sleeps.", "", "The {civ} archivists say it",
      "remembers the {place}." },
    { "Day 213. We left part of it", "behind. Whatever hums out", "there, it waits at site {site}.", "",
      "Bring a lab. Bring patience." },
  } },
  { id = "station_log", title = "Station keeper's log", kind = "clue", clue = "sentries", pages = {
    { "The Watchers came online on", "their own. They only see what", "is in front of them.", "",
      "A Jammer pulse blinds them", "for twelve seconds." },
    { "I counted {count} guards at", "site {site} before I left.", "", "Keep the hold light in there." },
  } },
  { id = "oquun_hymns", title = "Oquun spore hymns", kind = "lore", pages = {
    { "We drift, we bloom, we drift.", "The city is a garden", "and the garden is a song.", "",
      "(the margins are full of", "tiny, careful spirals)" },
  } },
  { id = "star_cookbook", title = "Cooking Under the Stars", kind = "lore", pages = {
    { "Ember spice wakes the eyes:", "fold it into noodles.", "", "Sunfruit and eggs make an",
      "omelette that steadies the", "hands - and the hull." },
    { "Glowcaps from the station", "groves: a stew for long", "nights on watch." },
  } },
  { id = "fold_primer", title = "A Short History of Folding", kind = "lore", pages = {
    { "The first fold drives were", "found, not built. Nobody knows", "who left them in the dark.", "",
      "Every fold costs Charge.", "Every unfold needs room." },
  } },
}
