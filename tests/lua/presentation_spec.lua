-- SPDX-License-Identifier: MIT
-- add-presentation-packaging: XR comfort (snap turns, seated/standing spaces,
-- vignette, hands and wrist panel), the audio director, the art pass helpers
-- and the touch overlay.
local game = require("sim.game")
local comfort = require("sim.comfort")
local xrv = require("view.xr")
local sound = require("view.audio")
local assets = require("view.assets")
local render = require("view.render")
local hud = require("view.hud")

local function fake_view(opts)
  local v = { calls = {}, width = 480, height = 270, player = 1, index = 1, xr = false, meshes = {} }
  for k, x in pairs(opts or {}) do v[k] = x end
  for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "text", "image", "vignette" }) do
    v[m] = function(self, a, b, c)
      self.calls[m] = (self.calls[m] or 0) + 1
      if m == "mesh" then self.meshes[#self.meshes + 1] = b end
      if m == "vignette" then self.last_vignette = a end
      if m == "text" then return #c * 8 end
    end
  end
  return v
end

local function cmd(pressed, turn)
  local set = {}
  for _, n in ipairs(pressed or {}) do set[n] = true end
  return { axis = function(_, n) return n == "turn" and (turn or 0) or 0 end,
           pressed = function(_, n) return set[n] or false end, held = function() return false end }
end

local function new_state()
  local st = {}
  game.init(st, { seed = 42, players = 1 })
  local avatar = require("sim.avatar")
  local p = st.players[1]
  p.mode, p.panel = "walk", false
  p.body = avatar.new(avatar.layout(), { -2.0, 0.6, -1.0 }, 0)
  return st
end

local function xr_off() saucer.test.xr({ available = 0, session = 0, head_pos = { 0, 0, 0 }, hands = {} }) end

describe("snap turning", function()
  it("turns by a fixed 30 degrees per snap press, smooth turning still works", function()
    expect(comfort.snap(cmd())).to_be(0)
    expect(comfort.snap(cmd({ "snap_left" }))).to_be_near(math.rad(30), 1e-9)
    expect(comfort.snap(cmd({ "snap_right" }))).to_be_near(-math.rad(30), 1e-9)
    expect(comfort.snap(cmd({ "snap_left", "snap_right" }))).to_be(0)
    expect(comfort.yaw(0, cmd({ "snap_left" }), 2, 0.1)).to_be_near(math.rad(30), 1e-6)
    expect(comfort.yaw(0, cmd(nil, 1), 2, 0.1)).to_be_near(-0.2, 1e-6)
  end)
  it("binds the snap actions to the engine's derived xr controls", function()
    local b = require("lib.data").load("input/default.lua")
    expect(b.buttons.snap_left[1]).to_be("xr:snap_l")
    expect(b.button_order[#b.button_order]).to_be("snap_right")
  end)
end)

describe("xr comfort view", function()
  it("lowers the cockpit to the floor only in standing sessions", function()
    local v = fake_view({ xr = true })
    saucer.test.xr({ available = 1, session = 2 })
    expect(xrv.space(v)).to_be("standing")
    local c = xrv.adjust(v, { pos = { 1, 5, 2 }, yaw = 0 })
    expect(c.pos[2]).to_be_near(5 - xrv.STAND_EYE, 1e-9)
    saucer.test.xr({ session = 1 })
    expect(xrv.space(v)).to_be("seated")
    expect(xrv.adjust(v, { pos = { 1, 5, 2 }, yaw = 0 }).pos[2]).to_be(5)
    expect(xrv.space(fake_view())).to_be(nil)
    xr_off()
  end)
  it("closes the vignette in while moving, not for snaps or cuts", function()
    xrv.reset()
    expect(xrv.motion(7, { pos = { 0, 0, 0 }, yaw = 0 }, 0.5)).to_be(0)
    local k = xrv.motion(7, { pos = { 0, 0, 0.5 }, yaw = 0 }, 0.5)
    expect(k).to_be_greater(0)
    expect(k).to_be_less(0.5 + 1e-9)
    local k2 = xrv.motion(7, { pos = { 0, 0, 1.0 }, yaw = 0 }, 0.5)
    expect(k2).to_be_greater(k)
    xrv.reset()
    xrv.motion(8, { pos = { 0, 0, 0 }, yaw = 0 }, 1)
    expect(xrv.motion(8, { pos = { 0, 0, 0 }, yaw = math.rad(30) }, 1)).to_be(0)   -- snap turn
    expect(xrv.motion(8, { pos = { 100, 0, 0 }, yaw = math.rad(30) }, 1)).to_be(0) -- teleport / fold
    expect(xrv.motion(8, { pos = { 100, 0, 0 }, yaw = math.rad(32) }, 1)).to_be_greater(0) -- smooth turn
    xrv.reset()
  end)
  it("draws tracked hands and a wrist panel with charge, hold and beam lock", function()
    local st = new_state()
    local p = st.players[1]
    local bars = xrv.wrist(p, { ok = true })
    expect(#bars).to_be(3)
    expect(bars[3][1]).to_be(1)
    expect(xrv.wrist(p, nil)[3][1]).to_be(0)
    local A = assets.init()
    saucer.test.xr({ available = 1, session = 2, head_pos = { 0, 1.6, 0 },
                     hands = { { pose = { -0.2, 1.1, 0.3, 0, 0, 1 } }, { pose = { 0.2, 1.1, 0.3, 0, 0, 1 } } } })
    local hs = saucer.xr.hands()
    expect(#hs).to_be(2)
    expect(hs[1].hand).to_be("left")
    expect(hs[2].pos[1]).to_be_near(0.2, 1e-6)
    local hp, hf = saucer.xr.head()
    expect(hp[2]).to_be_near(1.6, 1e-6)
    expect(hf[3]).to_be_truthy()
    local v = fake_view({ xr = true })
    local cam = { pos = { 10, 0, 0 }, yaw = 0 }
    local n = xrv.hands(v, A, cam, p, { ok = true })
    expect(n).to_be(6)
    expect(v.calls.mesh).to_be(6)
    expect(v.meshes[1].pos[1]).to_be_near(10 - 0.2 - 0.025, 1e-4)
    xr_off()
    expect(#saucer.xr.hands()).to_be(0)
    expect(saucer.xr.head()).to_be(nil)
  end)
  it("overlays hands and the vignette only in XR views", function()
    local st = new_state()
    local p = st.players[1]
    local A = assets.init()
    expect(xrv.overlay(fake_view(), A, { pos = { 0, 0, 0 }, yaw = 0 }, p, nil)).to_be(0)
    saucer.test.xr({ available = 1, session = 1, hands = {} })
    xrv.reset()
    local v = fake_view({ xr = true, index = 3 })
    xrv.overlay(v, A, { pos = { 0, 0, 0 }, yaw = 0 }, p, nil)
    xrv.overlay(v, A, { pos = { 0, 0, 0.6 }, yaw = 0 }, p, nil)
    expect(v.calls.vignette).to_be(1)
    expect(v.last_vignette).to_be_greater(0)
    saucer.xr.set_comfort({ vignette = 0 })
    local w = fake_view({ xr = true, index = 3 })
    xrv.overlay(w, A, { pos = { 0, 0, 1.2 }, yaw = 0 }, p, nil)
    expect(w.calls.vignette).to_be(nil)
    saucer.xr.set_comfort({ vignette = 0.5 })
    xrv.reset()
    xr_off()
  end)
  it("exposes comfort settings as a client option", function()
    local c = saucer.xr.comfort()
    expect(c.snap).to_be(true)
    expect(c.snap_turn).to_be(30)
    saucer.xr.set_comfort({ snap = false, vignette = 3, snap_turn = 45 })
    c = saucer.xr.comfort()
    expect(c.snap).to_be(false)
    expect(c.vignette).to_be(1)
    expect(c.snap_turn).to_be(45)
    saucer.xr.set_comfort({ vignette = -1 })
    expect(saucer.xr.comfort().vignette).to_be(0)
    saucer.xr.set_comfort({ snap = true, vignette = 0.5, snap_turn = 30 })
    expect(saucer.xr.comfort().snap).to_be(true)
  end)
  it("renders XR frames in the saucer, the station and the holodeck without the HUD", function()
    local st = new_state()
    saucer.test.xr({ available = 1, session = 2, hands = { { pose = { 0, 1, 0.3, 0, 0, 1 } } } })
    local v = fake_view({ xr = true })
    render.render(v, saucer.util.readonly(st), 1)
    expect(v.calls.text).to_be(nil)
    expect(v.calls.mesh).to_be_greater(4)
    xr_off()
  end)
end)

describe("audio director", function()
  it("sets loop levels from what the player is doing", function()
    local st = new_state()
    local p = st.players[1]
    local lv = sound.levels(st, p)
    expect(lv.engine).to_be_near(0.18, 1e-6)
    p.mode = "helm"
    p.ship.vel = { 40, 0, 0 }
    p.tractor = { key = "x" }
    p.site = 1
    lv = sound.levels(st, p)
    expect(lv.engine).to_be_near(0.65, 1e-6)
    expect(lv.beam).to_be(0.5)
    expect(lv.derelict).to_be(0.35)
    p.holo_run = { id = "x" }
    expect(sound.levels(st, p).holo).to_be(0.5)
    p.mode = "foot"
    expect(sound.levels(st, p).station).to_be(0.55)
  end)
  it("starts, fades, updates and stops loops by handle", function()
    sound.reset()
    saucer.test.audio_flush()
    local before = saucer.test.audio_loops()
    expect(sound.loops({ engine = 0.5 })).to_be(1)
    expect(saucer.test.audio_loops()).to_be(before + 1)
    expect(sound.live.engine.handle).to_be_truthy()
    local sets = 0
    for _ = 1, 30 do
      saucer.test.audio_flush()
      sets = sets + sound.loops({ engine = 0.5 })
    end
    expect(sets).to_be_greater(0)
    expect(sound.live.engine.level).to_be_greater(0.3)
    for _ = 1, 200 do
      saucer.test.audio_flush()
      sound.loops({ engine = 0 })
    end
    expect(sound.live.engine).to_be(nil)
    expect(saucer.test.audio_loops()).to_be(before)
    sound.loops({ beam = 1 })
    sound.reset()
    expect(sound.live.beam).to_be(nil)
  end)
  it("hears doors, panel clicks and the pocket coin as events", function()
    sound.reset()
    local st = new_state()
    local p = st.players[1]
    p.doors = { 0, 1 }
    p.panel = { kind = "trade", sel = 1 }
    expect(#sound.events(st, p)).to_be(0)
    p.doors = { 0.2, 0.5 }
    p.panel = { kind = "trade", sel = 2 }
    p.station = { coin = "pocket" }
    local ev = sound.events(st, p)
    expect(#ev).to_be(4)
    expect(sound.update(st, p, true)).to_be_greater(0)
    expect(sound.play("nope")).to_be(nil)
    p.fx = { { tick = st.tick + 1, sound = "door" }, { tick = st.tick + 1, sound = "unknown" } }
    expect(sound.fx(st, p)).to_be(1)
    sound.reset()
  end)
end)

describe("art pass helpers", function()
  it("splits recipe parts by material", function()
    local base, mats = assets.split_mats({ parts = {
      { kind = "box", min = { 0, 0, 0 }, max = { 1, 1, 1 }, color = { 1, 1, 1 } },
      { kind = "box", min = { 0, 0, 0 }, max = { 1, 1, 1 }, color = { 1, 1, 1 }, mat = "wood", uv = 1 },
      { kind = "box", min = { 0, 0, 0 }, max = { 1, 1, 1 }, color = { 1, 1, 1 }, mat = "metal", uv = 1 } } })
    expect(base).to_be_truthy()
    expect(#mats).to_be(2)
    expect(mats[1].mat).to_be("wood")
  end)
  it("loads the art textures and palettes, and draws the sky backdrops", function()
    local A = assets.init()
    for _, name in ipairs(assets.ART_TEXTURES) do expect(A.tex[name]).to_be_truthy() end
    expect(A.pal.sprites).to_be_truthy()
    local v = fake_view()
    render.sky(v, A, { 0, 0, 0 })
    expect(v.calls.billboard).to_be(#render.SKY)
  end)
  it("draws the title emblem on the title panel", function()
    local st = {}
    game.init(st, { seed = 42, players = 1 })
    local p = st.players[1]
    expect(p.panel and p.panel.kind).to_be("title")
    local v = fake_view()
    hud.draw(v, saucer.util.readonly(st), p, nil)
    expect(v.calls.image or 0).to_be_greater(0)
  end)
end)

describe("touch overlay", function()
  it("labels widgets, lights held ones and shows the floating stick", function()
    saucer.test.touch("down", 41, 0.12, 0.7)
    saucer.test.touch("move", 41, 0.3, 0.5)
    local lay = saucer.input.touch_layout()
    expect(lay.stick).to_be_truthy()
    local held = 0
    for _, w in ipairs(lay) do if w.held then held = held + 1 end end
    expect(held).to_be(1)
    local v = fake_view()
    expect(hud.touch(v)).to_be(#lay)
    saucer.test.touch("up", 41)
    expect(saucer.input.touch_layout().stick).to_be(nil)
    expect(hud.TOUCH_LABEL.tractor).to_be("BEAM")
  end)
end)
