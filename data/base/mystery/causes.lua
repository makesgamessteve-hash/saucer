-- SPDX-License-Identifier: MIT
-- Mystery cause templates (concept §5.6). {civ} {object} {place} get filled
-- from the universe seed. MVP: a 3-Echo chain, Who -> Where -> Key, that
-- opens a Resonant vault in open space. `curio` names the unique reward.
-- add-wider-dark: `witness` and `heart_key` are the Echoes of Acts II and
-- III in far sectors, `endings` the choices at the Heart (2-3 of them).
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
    witness = "Echo IV: A {civ} keeper saw the {object} turn toward the dark between sectors. It is still listening, in the Heart.",
    heart_key = "Echo V: The Heart Key. Whoever carries it to the Heart's core decides what the {object} hears next.",
    endings = {
      { id = "seal", title = "Seal the ear", text = "The {object} is sealed. The sentries everywhere grow drowsy." },
      { id = "restore", title = "Let it sing", text = "The {object} sings again and the {civ} relics are prized." },
      { id = "take", title = "Take the shard", text = "You carry its heart away. The dark wakes, restless." },
    },
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
    witness = "Echo IV: The last {civ} pilot logged the fleet folding into one place: a Heart, far down the drift.",
    heart_key = "Echo V: The Heart Key. The fleet left the door locked behind them; this opens it.",
    endings = {
      { id = "seal", title = "Close the door", text = "The way stays shut. The sentries everywhere grow drowsy." },
      { id = "restore", title = "Call them home", text = "The {civ} signal answers. Their relics are prized again." },
      { id = "take", title = "Take the compass", text = "You keep the way for yourself. The dark wakes, restless." },
    },
  },
}
