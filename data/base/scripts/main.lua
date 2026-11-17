-- SPDX-License-Identifier: MIT
-- Base game entry point: wires engine hooks to the simulation and the view.
-- on_tick is the only place sim state changes; on_render gets a read-only view.
local game = require("sim.game")
local input_setup = require("input_setup")
local view = require("view.render")

function on_init(ctx)
  -- add-wider-dark: every slot gets the defaults so co-op players can join later
  input_setup.setup(4)
  game.init(ctx.state, ctx)
end

function on_tick(dt, cmds, state) game.step(state, cmds, dt) end
function on_event(ev, state) game.on_event(ev, state) end
function on_render(alpha, v, state) view.render(v, state, alpha) end
function on_restore(state) game.rebuild(state) end
