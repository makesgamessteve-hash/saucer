-- SPDX-License-Identifier: MIT
-- touch-look-speed: a touch look drag turns by an angle (radians on the
-- aim_yaw / aim_pitch axes), not a turn rate; its sensitivity is a comfort
-- setting saved in comfort.txt.
local game = require("sim.game")
local comfort = require("sim.comfort")
local panel = require("sim.panel")
local flight = require("sim.flight")
local avatar = require("sim.avatar")
local shipm = require("sim.ship")

local function cmd(axes) return saucer.input.command({ axes = axes }) end
local function free(s, d) return { s.pos[1] + d[1], s.pos[2] + d[2], s.pos[3] + d[3] }, 0 end
local function row(rows, prefix)
  for _, r in ipairs(rows) do if r.text:sub(1, #prefix) == prefix then return r end end
end

describe("touch look angles", function()
  it("binds the touch look to the angle axes, not the turn rate", function()
    local b = saucer.input.bindings(1)
    expect(table.concat(b.aim_yaw, " ")).to_contain("touch:look_x")
    expect(table.concat(b.aim_pitch, " ")).to_contain("touch:look_y")
    expect(table.concat(b.turn, " "):find("touch:", 1, true)).to_be(nil)
    expect(table.concat(b.look, " "):find("touch:", 1, true)).to_be(nil)
  end)

  it("turns and pitches by exactly the angle, whatever the turn rate", function()
    local a = math.rad(10) / comfort.AIM_RANGE
    local c = cmd({ aim_yaw = a, aim_pitch = -a })
    expect(math.abs(comfort.aim_yaw(c) - math.rad(10))).to_be_less(1e-3)
    expect(math.abs(comfort.yaw(1, c, 0.1, 1 / 60) - (1 - math.rad(10)))).to_be_less(1e-3)
    expect(math.abs(comfort.yaw(1, c, 5, 1 / 60) - (1 - math.rad(10)))).to_be_less(1e-3)
    expect(math.abs(comfort.pitch(0, c, 2, 1 / 60, 1) + math.rad(10))).to_be_less(1e-3)
    expect(comfort.pitch(0.95, cmd({ aim_pitch = 1 }), 2, 1 / 60, 1)).to_be(1)
    expect(comfort.pitch(-0.95, cmd({ aim_pitch = -1 }), 2, 1 / 60, 1)).to_be(-1)
    expect(math.abs(comfort.pitch(0.2, cmd({ look = 1 }), 2, 0.1, 1) - 0.4)).to_be_less(1e-3)
  end)

  it("on foot, at the helm (banking like a turn) and at the beam console", function()
    local a = math.rad(20) / comfort.AIM_RANGE
    local body = { pos = { 0, 0, 0 }, yaw = 0, pitch = 0 }
    avatar.step(body, { aim_yaw = math.rad(20), aim_pitch = math.rad(5) }, 1 / 60)
    expect(math.abs(body.yaw + math.rad(20))).to_be_less(1e-6)
    expect(math.abs(body.pitch - math.rad(5))).to_be_less(1e-6)
    local s = shipm.new({ 0, 0, 0 }, 0, 1)
    flight.step(s, cmd({ aim_yaw = a }), 1 / 60, free)
    expect(math.abs(s.yaw + math.rad(20))).to_be_less(1e-3)
    expect(math.abs(s.bank)).to_be_greater(0)
    local t = shipm.new({ 0, 0, 0 }, 0, 1)
    flight.trim(t, { aim_yaw = math.rad(20) }, 0, 1 / 60, free)
    expect(math.abs(t.yaw + math.rad(20) * flight.TRIM_AIM)).to_be_less(1e-6)
  end)
end)

describe("touch look speed setting", function()
  it("is a stepped slider in the comfort settings, kept to 0.5x..2x, and saved", function()
    local saved = saucer.xr.comfort().look_sens
    local st = {}
    game.init(st, { seed = 42, players = 1 })
    local p = st.players[1]
    saucer.xr.set_comfort({ look_sens = 1 })
    comfort.open(p)
    expect(row(panel.rows(st, p), "Touch look speed").text).to_be("Touch look speed: 1.00x [###----]")
    local seen = {}
    for _ = 1, 5 do
      row(panel.rows(st, p), "Touch look speed").act(st, p)
      seen[#seen + 1] = saucer.xr.comfort().look_sens
    end
    expect(seen).to_equal({ 1.25, 1.5, 1.75, 2.0, 0.5 })
    expect(row(panel.rows(st, p), "Touch look speed").text).to_be("Touch look speed: 0.50x [#------]")
    saucer.xr.set_comfort({ look_sens = 7 })
    expect(saucer.xr.comfort().look_sens).to_be(2)
    saucer.xr.set_comfort({ look_sens = 0.1 })
    expect(saucer.xr.comfort().look_sens).to_be(0.5)
    expect(comfort.look_sens_text(2)).to_be("2.00x [#######]")
    saucer.xr.set_comfort({ look_sens = saved })
    saucer.xr.save_comfort()
  end)
end)
