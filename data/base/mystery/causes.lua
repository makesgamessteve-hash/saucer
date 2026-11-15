-- SPDX-License-Identifier: MIT
-- Mystery cause templates (concept §5.6). {civ} {object} {place} get filled
-- from the universe seed. MVP: a 3-Echo chain, Who -> Where -> Key, that
-- opens a Resonant vault in open space. `curio` names the unique reward.
return {
  {
    id = "silence",
    title = "The Silence",
    echoes = {
      "Echo I: The {civ} stopped answering on the same night, every ship at once.",
      "Echo II: They were building a {object} near {place}. It was meant to listen.",
      "Echo III: It heard something. The Resonant vault holds what it recorded.",
    },
    curio = "Listening Shard",
  },
  {
    id = "exodus",
    title = "The Empty Fleet",
    echoes = {
      "Echo I: The {civ} left their ships intact, engines warm, holds full.",
      "Echo II: A {object} was found at {place}, pointing out of the galaxy.",
      "Echo III: The way they went is sealed inside the Resonant vault.",
    },
    curio = "Fleet Compass",
  },
}
