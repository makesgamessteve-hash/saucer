-- SPDX-License-Identifier: MIT
-- Plot skeletons (OpenSpec add-run-story). The run seed picks one; each has
-- 4-6 beats. A beat has a carrier (log, mural or archive record: where it
-- is read), a `where` (home sector, a body city, a far spine sector, or the
-- Heart) and text variants. The last beat is the finale: nothing to find, it
-- is told when the Heart is resolved, one text per ending. A beat whose id is
-- "reveal" is the one a twist replaces. `causes` limits a skeleton to mystery
-- causes (absent: all). Templates: {a} {b} (civ names), {a_epithet}
-- {a_craft} {a_home} {a_fate} (vocab.lua), {object} {place} {echo} (from the
-- mystery), {betrayer} {betrayed}. Each beat that is not the finale ends with
-- a lead pointing at the next beat's place, from `leads`.
return {
  leads = {
    heart = {
      "Every thread ends at the Heart: {next_loc}.",
      "All of it points at the Heart, {next_loc}.",
    },
    log = {
      "A wreck log at {next_loc} carries on.",
      "The last line of a wreck log gives a bearing: {next_loc}.",
    },
    mural = {
      "A mural at {next_loc} shows what came next.",
      "The painter's trail leads to {next_loc}.",
    },
    archive = {
      "The records go on in the archive at {next_loc}.",
      "A filing mark sends you to the archive at {next_loc}.",
    },
  },
  skeletons = {
    {
      id = "vanished", title = "The Night {a} Went Quiet",
      beats = {
        { id = "hook", carrier = "log", where = "home", text = {
          "Wreck log, last entry: the {a} crew went to the night shift and the night shift never ended. Every hatch is sealed from the inside, and nothing is missing but them.",
          "Hauler's log, {a} registry: 'Third day of silence on every channel. The {a_craft} blame the {object}. Nobody else is answering, either.'",
        } },
        { id = "trail", carrier = "mural", where = "home", text = {
          "A {a_home} mural shows the {a} {a_epithet} walking toward one light, tools left where they stood. The light is drawn as the {object}.",
          "The mural stops half painted. One panel shows the {a} at work, the next shows empty benches, and between them a single word in their script: {place}.",
        } },
        { id = "ledger", carrier = "archive", where = "city", text = {
          "Archive record: the {a} census ends mid-count, on one night, in every district at once. The clerks blamed {a_fate}. The numbers do not agree.",
          "Archive record: an unsigned order took every {a} off the rolls on the same night, with a note: 'they asked us to stop counting.'",
        } },
        { id = "reveal", carrier = "log", where = "far", text = {
          "Log of the last {a} warden: 'They were not taken. They heard {echo} and went, all of them, in one night, and I stayed to keep the lights on.'",
          "Log, final page: the {a} heard {echo} from the {object} at {place}. By dawn the cities were empty and the doors were left open for a return.",
        } },
        { id = "finale", carrier = "heart", where = "heart", text = {
          seal = "You seal the Heart. The {a} stay wherever they went, and the quiet is kept. Their cities will go dark one window at a time.",
          restore = "You let the Heart sing. Far away a night shift of {a} finally ends, and the lights come on in a city you may never see.",
          take = "You carry its core away. The {a} will not answer now. The silence is yours to keep, and to explain.",
        } },
      },
    },
    {
      id = "war", title = "The War That Left No Winner",
      beats = {
        { id = "hook", carrier = "log", where = "home", text = {
          "Wreck log: 'Orders from the {a} fleet: hold the line against {b}. The line is held. There is no one left to tell us to stop.'",
          "Gunner's log, {a} fleet: 'We fought {b} for nine years. On the tenth, both sides went quiet at the same hour. I still do not know who fired last.'",
        } },
        { id = "front", carrier = "mural", where = "home", text = {
          "A {a_home} mural shows {a} and {b} ships burning in the same sky. The painter gave both fleets the same hands.",
          "Two columns of ships meet in the mural, {a} on the left and {b} on the right, and the painter ran out of wall for the survivors.",
        } },
        { id = "terms", carrier = "archive", where = "city", text = {
          "Archive record: the treaty of {place} was signed by both sides on the last night. It has one clause: 'Whatever wakes at the {object} is ours together.'",
          "Archive record: {b} envoys were guests in a city of the {a} on the night it fell. Their names are on the guest rolls and nowhere after.",
        } },
        { id = "betrayal", carrier = "log", where = "far", text = {
          "Log: {betrayer} broke the truce first. {betrayed} found the proof in a dead courier's hold: {echo}, recorded at {place}, and a sealed order to open the {object}.",
          "Officer's log, {betrayed} fleet: 'It was {betrayer} who opened the {object}. They wanted an end to the war. They got one.'",
        } },
        { id = "reveal", carrier = "mural", where = "far", text = {
          "The last mural: both civilisations drawn as one figure, kneeling before the {object}. Under it the old script says the war was fed on purpose, to wake {echo}.",
          "The final mural shows {a} and {b} laying down their arms at the {object}. {echo} had asked them to, and both obeyed too late.",
        } },
        { id = "finale", carrier = "heart", where = "heart", text = {
          seal = "You seal the Heart. The war ends a second time, and this time nobody wakes to restart it.",
          restore = "You let the Heart sing. The voices of {a} and {b} rise together, for the first time in ten thousand years.",
          take = "You carry the core away. The war's last weapon sits in your hold, and you are the only one left who knows what it was for.",
        } },
      },
    },
    {
      id = "signal", title = "The Call That Brought {a} Home",
      beats = {
        { id = "hook", carrier = "log", where = "home", text = {
          "Wreck log: 'Every {a} ship turned at once. No order was given. We were not asked, we were called.' The log ends at a heading, not a word.",
          "Navigator's log, {a} registry: 'The signal is in my teeth. All hulls point to {place}. Tell my family I did not choose this.'",
        } },
        { id = "source", carrier = "archive", where = "city", text = {
          "Archive record: the {a} traced the signal for a century and called it {echo}. The source was never found inside their space.",
          "Archive record: the call repeats every night. The {a} {a_craft} built the {object} only to listen to it.",
        } },
        { id = "reveal", carrier = "mural", where = "far", text = {
          "The mural shows the call as a thread of light and every {a} ship hanging on it like a bead. At its end is a door, and the door is the Heart.",
          "A mural of the {object} hearing the call. Below it the {a} are small figures walking home along the thread.",
        } },
        { id = "finale", carrier = "heart", where = "heart", text = {
          seal = "You seal the Heart. The call stops, and every ship still drifting finally gets to choose where to go.",
          restore = "You let it sing. The call answers itself, and somewhere the {a} lights come on to welcome whoever hears it.",
          take = "You carry the core away. The call goes on in your hold, softly, and the saucer begins to turn toward home, wherever that is.",
        } },
      },
    },
    {
      id = "builders", title = "The Hands That Built Your Saucer",
      beats = {
        { id = "hook", carrier = "mural", where = "home", text = {
          "A mural shows your own saucer, drawn long before you flew it. The {a} {a_epithet} stand around it, one hand each on the hull.",
          "Your saucer's keel carries the same mark as this mural: a builders' sign of the {a}, scratched into the bay a thousand years ago.",
        } },
        { id = "maker", carrier = "log", where = "home", text = {
          "Wreck log: 'The Villa class was our last commission, a home for someone not yet born. The {a_craft} insisted on the dome.'",
          "Builders' log: 'We built it to cross the dark. If it is ever found, let the finder be kind.'",
        } },
        { id = "ledger", carrier = "archive", where = "city", text = {
          "Archive record: the Villa plans were filed under 'for the returning'. The {a} sent a copy to {place}, to wait.",
          "Archive record: a list of every Villa hull ever built, and one unnamed owner. The owner field is blank.",
        } },
        { id = "reveal", carrier = "log", where = "far", text = {
          "Builders' log: the saucer was built to carry one of them home, someone who left before the silence. They hid the way inside {echo}.",
          "The final log: the saucer was never a ship, it was a key. The {object} opens only for a hull of its own making.",
        } },
        { id = "finale", carrier = "heart", where = "heart", text = {
          seal = "You seal the Heart with the hands that built your saucer. The {a} would have understood.",
          restore = "You let it sing. The saucer hums back, every deck, as if it has been waiting for a voice.",
          take = "You take the core. The saucer accepts it quietly, and it fits as though it was always meant to.",
        } },
      },
    },
    {
      id = "sleepers", title = "The Sleep of the {a}",
      beats = {
        { id = "hook", carrier = "log", where = "home", text = {
          "Wreck log: 'Lights low, hatches sealed, the {a} are asleep by order of the {a_craft}. Do not wake them. The sentries will remember.'",
          "Log: 'Day one of the sleep. Everyone is calm. The Watchers have their orders: keep the halls quiet until {place} says otherwise.'",
        } },
        { id = "ward", carrier = "mural", where = "home", text = {
          "A mural of rows upon rows of {a} sleepers, each in a {a_home} niche. Above them one lamp is drawn, always lit, and the lamp is the {object}.",
          "The mural counts the sleepers in the old script and stops at a number nobody finished writing. Below it, a lullaby, drawn as a wave.",
        } },
        { id = "ledger", carrier = "archive", where = "city", text = {
          "Archive record: the {a} sleep was meant to last one season. The wake date is smudged out. The note says: 'wait for {echo}.'",
          "Archive record: every {a} bed in the district is marked 'occupied'. The last clerk wrote 'good night' in the margin.",
        } },
        { id = "reveal", carrier = "log", where = "far", text = {
          "Log of the sleep-warden: 'They are not gone. They sleep in the Heart. If you read this, someone is close, and I am afraid of what you will choose.'",
          "Log: the {a} did not die. They sleep, and {echo} is the lullaby that keeps them under.",
        } },
        { id = "finale", carrier = "heart", where = "heart", text = {
          seal = "You seal the Heart. The sleep deepens, and the {a} dream on, safe from you and from whatever was coming.",
          restore = "You let it sing. Far below, the sleepers begin to stir, and the first thing they see is your saucer's light.",
          take = "You take the core. The sleepers fall quiet for good, and you carry the hollow where they used to dream.",
        } },
      },
    },
  },
}
