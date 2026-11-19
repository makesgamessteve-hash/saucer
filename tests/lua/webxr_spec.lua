-- SPDX-License-Identifier: MIT
-- OpenSpec add-webxr-cockpit, group "WebXR": constant player scale, hand
-- tracking gestures, the comfort settings panel and haptics. There is no
-- headset in CI: poses are mocked through saucer.test.xr. (A pass with a
-- physical headset stays a manual check; see docs/ROADMAP.md.)
local game = require("sim.game")
local shipm = require("sim.ship")
local configs = require("sim.config")
local comfort = require("sim.comfort")
local panel = require("sim.panel")
local avatar = require("sim.avatar")
local render = require("view.render")
local xrv = require("view.xr")
local assets = require("view.assets")
local vec = require("lib.vec")

local function fake_view(opts)
  local v = { calls = {}, width = 480, height = 270, player = 1, index = 1, xr = true, meshes = {}, texts = {} }
  for k, x in pairs(opts or {}) do v[k] = x end
  for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "text", "image", "vignette" }) do
    v[m] = function(self, a, b, c)
      self.calls[m] = (self.calls[m] or 0) + 1
      if m == "mesh" then self.meshes[#self.meshes + 1] = b end
      if m == "text" then self.texts[#self.texts + 1] = c return #c * 8 end
    end
  end
  return v
end

local function new_state(n)
  local st = {}
  game.init(st, { seed = 42, players = n or 1 })
  return st
end
local function xr_off() saucer.test.xr({ available = 0, session = 0, head_pos = { 0, 0, 0 }, hands = {}, joints = { left = false, right = false } }) end
local function texts(p)
  local t = {}
  for _, m in ipairs(p.msgs) do t[#t + 1] = m.text end
  return table.concat(t, "|")
end
local function row(rows, prefix)
  for _, r in ipairs(rows) do if r.text:sub(1, #prefix) == prefix then return r end end
end
local function flyable()
  local out = {}
  for i, c in ipairs(configs.all()) do if not c.pocket then out[#out + 1] = i end end
  return out
end

describe("player scale is constant (webxr)", function()
  it("shrink in VR: the pilot's eye (head height) is unchanged for every pair of sizes", function()
    local sizes = flyable()
    expect(#sizes).to_be_greater(1)
    for _, from in ipairs(sizes) do
      for _, to in ipairs(sizes) do
        if from ~= to then
          local s = shipm.new({ 10, 20, 30 }, 0.7, from)
          local eye = shipm.eye_world(s.pos, s.yaw, from)
          expect(shipm.request(s, to, function() return false end, eye, s.yaw)).to_be(true)
          -- the hull folds about the eye over the whole transition: the eye point never moves
          for k = 0, 20 do
            s.t_left = s.morph.total * (1 - k / 20)
            local d = render.pose(s, true)
            local w = render.at(d, configs.get(d.size).pilot_eye)
            expect(vec.len(vec.sub(w, eye))).to_be_less(1e-6)
            expect(d.roll).to_be(0) -- the headset owns the horizon
          end
          expect(vec.len(vec.sub(shipm.eye_world(s.pos, s.yaw, s.size), eye))).to_be_less(1e-6)
        end
      end
    end
  end)
  it("the XR camera of a pilot keeps its eye across the size change, never banks or scales", function()
    local st = new_state()
    local p = st.players[1]
    p.mode, p.panel = "helm", false
    p.ship = shipm.new({ 0, 0, 0 }, 0.3, 1)
    p.ship.bank = 0.4
    local c0 = render.camera(p, true)
    expect(c0.roll).to_be(0)
    expect(c0.scale).to_be(nil)
    local eye = shipm.eye_world(p.ship.pos, p.ship.yaw, 1)
    expect(vec.len(vec.sub(c0.pos, eye))).to_be_less(1e-9)
    shipm.request(p.ship, 2, function() return false end, eye, p.ship.yaw)
    p.ship.bank = 0.4
    local c1 = render.camera(p, true)
    expect(vec.len(vec.sub(c1.pos, c0.pos))).to_be_less(1e-6)
    expect(c1.roll).to_be(0)
    -- the flat-screen camera does bank, so the XR rule is a real difference
    expect(render.bank_of(p.ship, false)).to_be(0) -- mid-fold: no bank either way
  end)
  it("a standing session lowers every size's camera by the same eye height", function()
    local st = new_state()
    local p = st.players[1]
    p.mode = "helm"
    saucer.test.xr({ available = 1, session = 2 })
    local v = fake_view()
    for _, size in ipairs(flyable()) do
      p.ship = shipm.new({ 5, 7, 9 }, 1.1, size)
      local base = render.camera(p, true)
      local cam = xrv.adjust(v, render.camera(p, true))
      expect(base.pos[2] - cam.pos[2]).to_be_near(xrv.STAND_EYE, 1e-9)
      expect(cam.pos[1]).to_be(base.pos[1])
    end
    saucer.test.xr({ session = 1 })
    local seated = xrv.adjust(v, render.camera(p, true))
    expect(seated.pos[2]).to_be(render.camera(p, true).pos[2])
    xr_off()
  end)
  it("headset eye views compose rigidly (see the C test xr_scale_is_constant_across_cockpits)", function()
    saucer.test.xr({ available = 1, session = 1, mock_views = true, ipd = 0.064 })
    local p = saucer.xr.session()
    expect(p).to_be("seated")
    xr_off()
  end)
end)

describe("hand tracking (webxr)", function()
  local function hand(ox, oy, oz)
    return { wrist = { ox, oy, oz }, thumb = { ox - 0.04, oy, oz + 0.09 }, index = { ox - 0.02, oy, oz + 0.17 },
             middle = { ox, oy, oz + 0.18 }, ring = { ox + 0.02, oy, oz + 0.17 }, pinky = { ox + 0.04, oy, oz + 0.15 } }
  end
  it("reports tracked hands and the size lever to scripts and draws the handle (gestures: see game_xr_hands)", function()
    local st = new_state()
    saucer.test.xr({ available = 1, session = 2, head_pos = { 0, 1.6, 0 }, head_fwd = { 0, 0, 1 },
                     joints = { left = hand(-0.3, 1.2, 0.3), right = hand(0.3, 1.2, 0.3) } })
    local hs = saucer.xr.hands()
    expect(#hs).to_be(2)
    expect(hs[1].hand).to_be("left")
    expect(hs[1].tracked).to_be(true)
    expect(hs[2].pos[1]).to_be_near(0.3, 1e-6)
    expect(hs[2].fwd[3]).to_be_greater(0.9) -- toward the middle finger
    local pos, held = saucer.xr.lever()
    expect(pos[2]).to_be_near(1.6 - 0.30, 1e-5)
    expect(held).to_be(false)
    local v = fake_view({ index = 2 })
    local A = assets.init()
    expect(xrv.lever(v, A, { pos = { 0, 0, 0 }, yaw = 0 })).to_be(2)
    expect(v.calls.mesh).to_be(2)
    -- losing a hand drops it from the list
    saucer.test.xr({ joints = { left = false } })
    expect(#saucer.xr.hands()).to_be(1)
    xr_off()
    expect(#saucer.xr.hands()).to_be(0)
    expect(saucer.xr.lever()).to_be(nil)
    expect(xrv.lever(fake_view(), A, { pos = { 0, 0, 0 }, yaw = 0 })).to_be(0)
    expect(st.players[1].mode).to_be("wake")
  end)
end)

describe("comfort options (webxr)", function()
  local ctx = game.ctx
  local saved
  local function open(st, p)
    p.mode, p.panel = "walk", false
    panel.open(p, "bed")
    return panel.rows(st, p)
  end
  before_each(function() saved = saucer.xr.comfort() end)
  local function restore()
    saucer.xr.set_comfort({ snap = saved.snap, snap_turn = saved.snap_turn, vignette = saved.vignette, mode = saved.mode,
                            look_sens = saved.look_sens })
    saucer.xr.save_comfort()
  end

  it("the settings panel is reachable from the bed and the title card, in or out of XR", function()
    local st = new_state()
    local p = st.players[1]
    local rows = open(st, p)
    expect(row(rows, "Comfort settings")).to_be_truthy()
    row(rows, "Comfort settings").act(st, p)
    expect(p.panel.kind).to_be("comfort")
    expect(p.panel.back).to_be("bed")
    expect(panel.title(st, p)).to_be("COMFORT SETTINGS")
    row(panel.rows(st, p), "Back").act(st, p)
    expect(p.panel.kind).to_be("bed")
    p.mode = "wake"
    panel.open(p, "title")
    expect(row(panel.rows(st, p), "Comfort settings")).to_be_truthy()
    row(panel.rows(st, p), "Comfort settings").act(st, p)
    expect(p.panel.back).to_be("title")
    comfort.open({ panel = false, index = 1 }) -- from no panel at all: Back closes
    local q = { panel = false, index = 1 }
    comfort.open(q)
    expect(q.panel.back).to_be(nil)
    row(panel.rows(st, q), "Back").act(st, q)
    expect(q.panel).to_be(false)
    -- in the headset the same panel is drawn, big and head-locked
    saucer.test.xr({ available = 1, session = 2 })
    xrv.reset()
    local v = fake_view({ width = 1440, height = 1440 })
    local n = xrv.panel(v, st, p)
    expect(n).to_be(6)
    expect(v.calls.rect).to_be_greater(1)
    local seen = table.concat(v.texts, "|")
    expect(seen).to_contain("COMFORT SETTINGS")
    expect(seen).to_contain("Turning:")
    expect(xrv.stats.panels).to_be(1)
    xrv.overlay(v, assets.init(), { pos = { 0, 0, 0 }, yaw = 0 }, p, nil, st)
    expect(xrv.stats.panels).to_be(2)
    q.panel = false
    expect(xrv.panel(v, st, q)).to_be(0)
    xr_off()
    restore()
  end)
  it("the XR menu scrolls long lists around the selection", function()
    local st = new_state()
    local p = st.players[1]
    panel.register("long_test", { title = "LONG", rows = function()
      local r = {}
      for i = 1, 14 do r[i] = { text = "row " .. i, act = function() end } end
      return r
    end })
    panel.open(p, "long_test")
    p.panel.sel = 12
    local v = fake_view({ width = 720, height = 720 })
    expect(xrv.panel(v, st, p)).to_be(9)
    expect(table.concat(v.texts, "|")).to_contain("row 12")
    panel.kinds.long_test = nil
  end)
  it("snap or smooth turning, the angle, the vignette and the seated mode can be changed and persist", function()
    local st = new_state()
    local p = st.players[1]
    saucer.xr.set_comfort({ snap = true, snap_turn = 30, vignette = 0.5, mode = "standing" })
    comfort.open(p)
    local function act(prefix)
      row(panel.rows(st, p), prefix).act(st, p)
    end
    act("Turning")
    expect(saucer.xr.comfort().snap).to_be(false)
    expect(row(panel.rows(st, p), "Turning").text).to_be("Turning: smooth")
    expect(row(panel.rows(st, p), "Snap angle").enabled).to_be(false)
    act("Turning")
    expect(saucer.xr.comfort().snap).to_be(true)
    local seen = {}
    for _ = 1, 4 do act("Snap angle") seen[#seen + 1] = saucer.xr.comfort().snap_turn end
    expect(seen).to_equal({ 45, 60, 15, 30 })
    seen = {}
    for _ = 1, 4 do act("Vignette") seen[#seen + 1] = row(panel.rows(st, p), "Vignette").text end
    expect(seen).to_equal({ "Vignette: High", "Vignette: Off", "Vignette: Low", "Vignette: Medium" })
    act("VR mode")
    expect(saucer.xr.comfort().mode).to_be("seated")
    expect(row(panel.rows(st, p), "VR mode").text).to_be("VR mode: seated")
    expect(texts(p)).to_contain("Comfort setting changed")
    -- written to <user-dir>/comfort.txt by every change
    local rec = saucer.xr.comfort()
    expect(rec.mode).to_be("seated")
    expect(comfort.vignette_name(0.8)).to_be("High")
    expect(comfort.vignette_name(0.4)).to_be("Medium")
    expect(comfort.vignette_name(0.6)).to_be("Medium")
    expect(comfort.vignette_name(0.99)).to_be("Custom")
    saucer.xr.set_comfort({ vignette = 0.33 })
    expect(row(panel.rows(st, p), "Vignette").text).to_be("Vignette: Low")
    saucer.xr.set_comfort({ vignette = 0.6 })
    act("Vignette") -- an in-between value steps to the first preset
    expect(saucer.xr.comfort().vignette).to_be(0)
    restore()
  end)
  it("the saved snap angle rides in the command: 15, 30, 45 and 60 degrees", function()
    local function cmd(held)
      local h = {}
      for _, n in ipairs(held) do h[n] = true end
      return { pressed = function(_, n) return n == "snap_left" end, held = function(_, n) return h[n] or false end,
               axis = function() return 0 end }
    end
    expect(comfort.snap(cmd({}))).to_be_near(math.rad(30), 1e-9)
    expect(comfort.snap(cmd({ "snap_a" }))).to_be_near(math.rad(45), 1e-9)
    expect(comfort.snap(cmd({ "snap_b" }))).to_be_near(math.rad(60), 1e-9)
    expect(comfort.snap(cmd({ "snap_a", "snap_b" }))).to_be_near(math.rad(15), 1e-9)
    local b = require("sim.comfort")
    expect(#b.ANGLES).to_be(4)
  end)
  it("comfort settings are a local choice: another player's menu cannot change this machine", function()
    saucer.xr.set_comfort({ snap = true })
    expect(saucer.xr.set_comfort({ snap = false }, 1)).to_be(true)
    expect(saucer.xr.comfort().snap).to_be(false)
    expect(saucer.xr.save_comfort(1)).to_be(true)
    restore()
  end)
  it("never shakes or rolls the camera and gives controllers a haptic pulse on a fold and on a hull hit", function()
    local st = new_state()
    local p = st.players[1]
    p.mode = "helm"
    saucer.test.xr({ available = 1, session = 1 })
    xrv.reset()
    local base = select(1, saucer.test.xr_haptics())
    local v1, v2 = fake_view({ index = 1 }), fake_view({ index = 2 })
    local A = assets.init()
    local cam = { pos = { 0, 0, 0 }, yaw = 0 }
    local function frame()
      xrv.overlay(v1, A, cam, p, nil, st)
      xrv.overlay(v2, A, cam, p, nil, st)
    end
    frame()
    expect(select(1, saucer.test.xr_haptics())).to_be(base)
    -- the fold starts: one pulse, however many frames and eyes
    p.ship.morph = { from = 1 }
    frame()
    frame()
    expect(select(1, saucer.test.xr_haptics())).to_be(base + 1)
    local _, l, r = saucer.test.xr_haptics()
    expect(l).to_be_near(0.6, 1e-6)
    expect(r).to_be_near(0.6, 1e-6)
    p.ship.morph = false
    frame()
    -- debris strikes the hull: a stronger pulse
    p.ship.since_hit = 0
    frame()
    p.ship.since_hit = 0.016
    frame()
    expect(select(1, saucer.test.xr_haptics())).to_be(base + 2)
    expect(xrv.stats.pulses).to_be(2)
    _, l = saucer.test.xr_haptics()
    expect(l).to_be(1)
    -- the camera in XR is the plain eye: no shake, no roll, whatever the hull took
    p.shake, p.ship.bank = 3, 0.5
    local c = render.camera(p, true)
    expect(c.roll).to_be(0)
    -- outside a session haptics are ignored
    xr_off()
    local total = select(1, saucer.test.xr_haptics())
    saucer.xr.haptic("left", 1, 10)
    expect(select(1, saucer.test.xr_haptics())).to_be(total)
    saucer.test.xr({ session = 1 })
    saucer.xr.haptic("left", 1, 10)
    saucer.xr.haptic("right")
    expect(select(1, saucer.test.xr_haptics())).to_be(total + 2)
    xr_off()
  end)
end)
