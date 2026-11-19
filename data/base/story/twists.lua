-- SPDX-License-Identifier: MIT
-- Story twists (OpenSpec add-run-story): a run swaps in at most one. A twist
-- replaces the text of the skeleton's "reveal" beat (one variant per run) and
-- adds a line to the end of the story. `skeletons` lists the skeletons it fits
-- (absent: all). {a} {b} {betrayer} {betrayed} {object} {place} {echo} and the
-- trait words of vocab.lua are filled from the run.
return {
  {
    id = "caretakers",
    title = "The Watchers were caretakers",
    skeletons = { "vanished", "signal", "sleepers", "builders" },
    reveal = {
      "The Watchers were never guards. The {a} built them as caretakers, to tend the empty halls until someone came back. They strike at strangers only because nobody told them anyone would come.",
      "A caretaker's order, never rescinded: 'Keep the halls. Keep the lights. If a stranger comes, be afraid for them.' The Watchers have been afraid for ten thousand years.",
    },
    coda = "Somewhere a Watcher dims its eye as you pass.",
  },
  {
    id = "betrayal",
    title = "A quiet betrayal",
    skeletons = { "vanished", "signal", "sleepers", "builders" },
    reveal = {
      "{betrayer} sold the silence to {betrayed} and the {object} was the price. The {a} records blame {a_fate}. The {b} records blame nobody, which is how the truth was kept.",
      "It was {betrayer} who opened the {object} at {place}, and {betrayed} who paid for it. Both wrote the same lie afterwards: {a_fate}.",
    },
    coda = "You wonder who is left to forgive.",
  },
  {
    id = "chosen",
    title = "They chose to go",
    skeletons = { "vanished", "signal", "sleepers" },
    reveal = {
      "Nothing took them. The {a} voted, in every district, to go, and told the Watchers to keep the doors for them. The silence is a decision, kept for ten thousand years.",
      "The last vote of the {a}, preserved: all for, none against. They went with {echo} in their ears and left the lights on out of manners.",
    },
    coda = "Their doors are still unlocked.",
  },
  {
    id = "mirror",
    title = "The enemy was a mirror",
    skeletons = { "war", "vanished" },
    reveal = {
      "{b} never answered, because {b} was never there. The war was the {a} fighting the voice of their own {object}, and the enemy was their reflection.",
      "The {b} fleet in every record carries the {a} registry, reversed. They fought themselves for nine years and called it {b}.",
    },
    coda = "You catch your own reflection in a dark panel, and look away.",
  },
  {
    id = "voice",
    title = "The Echo was meant for you",
    reveal = {
      "The Echo was never meant for the {a}. It was recorded to be heard by a visitor from far away, and you are the first to come.",
      "The Echo is {echo}, and it is not about the {a} at all. It waits, patiently, for a saucer, and it was written for whoever is flying one.",
    },
    coda = "The Heart hums your name, or something near it.",
  },
  {
    id = "sleepers",
    title = "They sleep in the Heart",
    skeletons = { "vanished", "war", "signal", "builders" },
    reveal = {
      "They are not dead. They are inside the Heart, asleep, every one of them, and the {object} is their door.",
      "The {a} did not vanish: they moved in. The Heart is full, and quiet, and it breathes when nobody is listening.",
    },
    coda = "You feel, very faintly, someone breathing in the dark.",
  },
}
