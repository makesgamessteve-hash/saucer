-- SPDX-License-Identifier: MIT
-- add-mobile-touch-ux: the touch HUD at the eight reference screens. The
-- engine fits the controls (tests/c/test_core.c checks sizes, gaps, the safe
-- area and the HUD keep-outs); here the HUD itself must keep its text and
-- panels off the controls, put the log in the clear column, and show the
-- pressed, active, cooldown and unavailable states.
local game = require("sim.game")
local hud = require("view.hud")
local avatar = require("sim.avatar")

local SIZES = { { 320, 568 }, { 568, 320 }, { 360, 640 }, { 640, 360 }, { 390, 844 }, { 844, 390 },
                { 768, 1024 }, { 1024, 768 } }

-- a view that records where every text and rect went, and whether it was a
-- touch control's own drawing
local function rec_view(w, h)
  local v = { width = w, height = h, player = 1, index = 1, xr = false, texts = {}, rects = {}, in_touch = false }
  function v:text(x, y, t, col, scale)
    local s = scale or 1
    self.texts[#self.texts + 1] = { x, y, #t * 8 * s, 8 * s, t, touch = self.in_touch }
    return #t * 8 * s
  end
  function v:rect(x, y, ww, hh, col)
    self.rects[#self.rects + 1] = { x, y, ww, hh, touch = self.in_touch }
  end
  for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "image", "vignette" }) do v[m] = function() end end
  return v
end

local function overlap(a, b)
  return a[1] < b[1] + b[3] - 0.01 and b[1] < a[1] + a[3] - 0.01 and a[2] < b[2] + b[4] - 0.01 and b[2] < a[2] + a[4] - 0.01
end

local function state_for(mode)
  local st = {}
  game.init(st, { seed = 42, players = 1 })
  local p = st.players[1]
  p.panel = false
  if mode == "walk" then
    p.mode = "walk"
    p.body = avatar.new(avatar.layout(), { -2.0, 0.6, -1.0 }, 0)
  else
    p.mode = "helm"
  end
  st.tick = 10
  -- a full log: long lines that wrap, an urgent one
  for i = 1, 6 do
    p.msgs[#p.msgs + 1] = { text = "Salvage report " .. i .. ": a long line about the hold and the beam", tick = 5 }
  end
  p.msgs[#p.msgs + 1] = { text = "Hull breach! Get clear", tick = 6 }
  return st, p
end

local function with_touch(fn)
  local dm, real = saucer.input.device_mode, hud.touch
  saucer.input.device_mode = function() return "touch" end
  local ok, err = pcall(fn)
  saucer.input.device_mode = dm
  hud.touch = real
  saucer.test.touch_metrics({ w = 640, h = 360 }) -- back to the headless layout
  if not ok then error(err, 0) end
end

describe("touch HUD layout", function()
  for _, mode in ipairs({ "walk", "helm" }) do
    for _, sz in ipairs(SIZES) do
      it(string.format("keeps the %s HUD off the controls at %dx%d", mode, sz[1], sz[2]), function()
        with_touch(function()
          local hw, hh = saucer.test.touch_metrics({ w = sz[1], h = sz[2] })
          expect(hw >= 200 and hh >= 200).to_be(true)
          local v = rec_view(hw, hh)
          local real = hud.touch
          hud.touch = function(...)
            v.in_touch = true
            local n = real(...)
            v.in_touch = false
            return n
          end
          local st, p = state_for(mode)
          hud.draw(v, saucer.util.readonly(st), p, nil)
          local lay = saucer.input.touch_layout()
          local ctl = hud.touch_rects(v, lay)
          expect(#ctl).to_be(#lay - 1) -- every control but the look area
          local drew_touch, logged = false, 0
          for _, t in ipairs(v.texts) do
            if t.touch then drew_touch = true
            else
              for _, c in ipairs(ctl) do
                if overlap(t, c) then error(string.format("text %q at %d,%d over %s", t[5], t[1], t[2], c[5])) end
              end
              local m = lay.msg
              if math.abs(t[1] - (m.x * hw + 4)) < 0.01 and t[2] >= m.y * hh - 0.01 then -- a log line
                logged = logged + 1
                -- the log sits in the clear column
                expect(t[1] + t[3] <= (m.x + m.w) * hw + 0.01 and t[2] + t[4] <= (m.y + m.h) * hh + 0.01).to_be(true)
              end
            end
          end
          for _, r in ipairs(v.rects) do
            if not r.touch and r[3] < hw and r[4] < hh then
              for _, c in ipairs(ctl) do
                if overlap(r, c) then error(string.format("rect at %d,%d %dx%d over %s", r[1], r[2], r[3], r[4], c[5])) end
              end
            end
          end
          expect(drew_touch).to_be(true)
          expect(logged).to_be_greater(1)
        end)
      end)
    end
  end
end)

describe("touch context hint", function()
  for _, sz in ipairs(SIZES) do
    it(string.format("stacks over the log in the clear column at %dx%d", sz[1], sz[2]), function()
      with_touch(function()
        local hw, hh = saucer.test.touch_metrics({ w = sz[1], h = sz[2] })
        local v = rec_view(hw, hh)
        local st, p = state_for("walk")
        p.msgs = { { text = "one", tick = 5 } }
        st.tick = 10
        hud.draw(v, saucer.util.readonly(st), p, nil)
        local m = saucer.input.touch_layout().msg
        local col = {}
        for _, t in ipairs(v.texts) do
          if math.abs(t[1] - (m.x * hw + 4)) < 0.01 and t[2] >= m.y * hh - 0.01 then col[#col + 1] = t end
        end
        expect(#col).to_be_greater(1) -- the log line and at least one hint line
        for i, a in ipairs(col) do
          expect(a[2] + a[4] <= (m.y + m.h) * hh + 0.01).to_be(true)
          for j = i + 1, #col do expect(overlap(a, col[j])).to_be(false) end
          -- nothing else (the centred Use prompt, the status) reads under it
          for _, b in ipairs(v.texts) do
            if b ~= a and not b.touch and b[1] ~= a[1] then expect(overlap(a, b)).to_be(false) end
          end
        end
      end)
    end)
  end
end)

describe("touch HUD feedback", function()
  it("shows cooldowns, an unavailable decoy, an active beam and the altitude", function()
    local st, p = state_for("helm")
    st.tick = 100
    p.scan_ready, p.jam_ready, p.decoys, p.tractor = 100 + 150, 0, 0, { t = 1, total = 10 }
    local s = hud.touch_state("scan", st, p)
    expect(s.secs).to_be(3)
    expect(s.cool > 0 and s.cool <= 1).to_be(true)
    expect(hud.touch_state("jam", st, p)).to_be(nil)
    p.jam_ready = 160
    expect(hud.touch_state("jam", st, p).secs).to_be(1)
    expect(hud.touch_state("decoy", st, p).off).to_be(true)
    expect(hud.touch_state("tractor", st, p).on).to_be(true)
    expect(hud.touch_state("use", st, p)).to_be(nil)
    expect(hud.touch_state("use")).to_be(nil)
    local v = rec_view(480, 270)
    v.in_touch = true
    local lay = saucer.input.touch_layout()
    expect(hud.touch(v, st, p)).to_be(#lay - 1) -- the resting ring counts for the stick
    local seen = {}
    for _, t in ipairs(v.texts) do seen[t[5]] = true end
    expect(seen["3S"]).to_be(true)  -- the scanner's seconds left
    expect(seen.MOVE).to_be(true)   -- the stick's resting ring
    expect(seen[tostring(math.floor(p.ship.pos[2]))]).to_be(true) -- the lift reads the altitude
  end)
  it("lights a pressed button and nudges its label", function()
    local use
    for _, w in ipairs(saucer.input.touch_layout()) do if w.name == "use" then use = w end end
    saucer.test.touch("down", 61, use.x + use.w / 2, use.y + use.h / 2)
    local v = rec_view(480, 270)
    hud.touch(v)
    local lay = saucer.input.touch_layout()
    for _, w in ipairs(lay) do if w.name == "use" then expect(w.held).to_be(true) end end
    saucer.test.touch("up", 61)
    local function label_y(vv) -- the label proper is drawn after its shadow
      local y
      for _, t in ipairs(vv.texts) do if t[5] == "USE" then y = t[2] end end
      return y
    end
    local v2 = rec_view(480, 270)
    hud.touch(v2)
    expect(label_y(v)).to_be(label_y(v2) + 1)
  end)
  it("keeps centred text between the controls on its row", function()
    with_touch(function()
      local hw, hh = saucer.test.touch_metrics({ w = 568, h = 320 })
      local v = rec_view(hw, hh)
      hud.clip = hud.touch_rects(v, saucer.input.touch_layout())
      local long = string.rep("X", 80)
      local y = 0
      for _, r in ipairs(hud.clip) do if r[5] == "use" then y = r[2] + 2 end end
      local w = hud.ct(v, y, long, { 1, 1, 1, 1 })
      local t = v.texts[#v.texts]
      expect(w < #long * 8).to_be(true)
      for _, c in ipairs(hud.clip) do expect(overlap(t, c)).to_be(false) end
      hud.clip = nil
      expect(hud.ct(v, y, long, { 1, 1, 1, 1 })).to_be((hw - 4) // 8 * 8) -- no touch: the whole width
    end)
  end)
  it("draws rings as rows", function()
    local v = rec_view(100, 100)
    expect(hud.ring(v, 50, 50, 10, { 1, 1, 1, 1 })).to_be(42)
    expect(hud.ring(v, 50, 50, 10, { 1, 1, 1, 1 }, true)).to_be(21)
  end)
end)

describe("touch HUD panels", function()
  for _, sz in ipairs(SIZES) do
    it(string.format("moves the title card clear of the controls at %dx%d", sz[1], sz[2]), function()
      with_touch(function()
        local hw, hh = saucer.test.touch_metrics({ w = sz[1], h = sz[2] })
        local v = rec_view(hw, hh)
        local real = hud.touch
        hud.touch = function(...)
          v.in_touch = true
          local n = real(...)
          v.in_touch = false
          return n
        end
        local st = {}
        game.init(st, { seed = 42, players = 1 })
        local p = st.players[1]
        expect(p.panel.kind).to_be("title")
        hud.draw(v, saucer.util.readonly(st), p, nil)
        local ctl = hud.touch_rects(v, saucer.input.touch_layout())
        local rows = 0
        for _, t in ipairs(v.texts) do
          if not t.touch then
            for _, c in ipairs(ctl) do
              if overlap(t, c) then error(string.format("text %q at %d,%d over %s", t[5], t[1], t[2], c[5])) end
            end
            if t[5]:find("Get up", 1, true) then rows = rows + 1 end
          end
        end
        for _, r in ipairs(v.rects) do
          if not r.touch then
            for _, c in ipairs(ctl) do
              if overlap(r, c) then error(string.format("rect at %d,%d over %s", r[1], r[2], c[5])) end
            end
          end
        end
        expect(rows).to_be(1)
        expect(hud.clip).to_be(nil)
      end)
    end)
    it(string.format("shows every title menu entry and the nav in full at %dx%d", sz[1], sz[2]), function()
      with_touch(function()
        local hw, hh = saucer.test.touch_metrics({ w = sz[1], h = sz[2] })
        local v = rec_view(hw, hh)
        local st = {}
        game.init(st, { seed = 42, players = 1 })
        local p = st.players[1]
        local rs = require("sim.panel").rows(st, p)
        expect(#rs).to_be_greater(3)
        for i = 1, #rs + 1 do -- every entry selected in turn
          v.texts = {}
          p.panel.sel = math.min(i, #rs)
          hud.draw(v, saucer.util.readonly(st), p, nil)
          local all = {}
          for _, t in ipairs(v.texts) do
            -- nothing runs off the screen
            if t[1] < -0.01 or t[1] + t[3] > hw + 0.01 then error(string.format("text %q off screen", t[5])) end
            all[#all + 1] = t[5]
          end
          local joined = " " .. table.concat(all, " "):gsub(">", " "):gsub("%s+", " ") .. " "
          for _, r in ipairs(rs) do
            local want = " " .. r.text:gsub("%s+", " ") .. " "
            if not joined:find(want, 1, true) then error(string.format("menu entry %q cut off", r.text)) end
          end
          expect(joined:find(" USE: PICK ", 1, true) ~= nil).to_be(true)
          expect(joined:find(" STICK UP/DOWN ", 1, true) ~= nil).to_be(true)
        end
      end)
    end)
  end
  it("wraps a long menu row and splits a narrow centred line", function()
    local ls, n = hud.panel_lines({ { text = "Load saved game" }, { text = "Get up" } }, 12)
    expect(n).to_be(3)
    expect(ls[1][1]).to_be("Load saved")
    expect(ls[1][2]).to_be("game")
    local v = rec_view(200, 100)
    hud.clip = { { 0, 40, 30, 20, "map" }, { 170, 40, 30, 20, "up" } }
    expect(hud.ct_parts(v, 45, "STICK UP/DOWN  USE: PICK", { 1, 1, 1, 1 })).to_be(2)
    expect(v.texts[1][5]).to_be("STICK UP/DOWN")
    expect(v.texts[2][5]).to_be("USE: PICK")
    hud.clip = nil
    v.texts = {}
    expect(hud.ct_parts(v, 45, "STICK UP/DOWN  USE: PICK", { 1, 1, 1, 1 })).to_be(1)
    expect(v.texts[1][5]).to_be("STICK UP/DOWN  USE: PICK")
  end)
  it("places boxes clear of the controls, or gives up", function()
    local v = rec_view(100, 100)
    hud.clip = { { 40, 40, 20, 20, "use" } }
    expect(hud.hits(45, 45, 2, 2)).to_be(true)
    local x, y = hud.place(v, 30, 30, 35, 35)
    expect(x ~= nil and not hud.hits(x, y, 30, 30)).to_be(true)
    expect(hud.place(v, 99, 99, 0, 0)).to_be(nil)
    hud.clip = nil
    expect(hud.hits(45, 45, 2, 2)).to_be(false)
  end)
end)
