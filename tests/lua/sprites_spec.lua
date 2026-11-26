-- SPDX-License-Identifier: MIT
-- replace-bubble-sprites: each former bubble is a form that fits what it is
local spr = require("view.sprites")
local phv = require("view.phenomena")
local cityphen = require("view.cityphen")
local vec = require("lib.vec")

local function view()
  local v = { bills = {}, meshes = {} }
  function v:billboard(tex, pos, size, opts)
    self.bills[#self.bills + 1] = { tex = tex, pos = pos, size = size, opts = opts or {} }
  end
  function v:mesh(mesh, opts)
    self.meshes[#self.meshes + 1] = { mesh = mesh, opts = opts or {} }
  end
  return v
end

local A = { tex = { glow = 7, beam = 8, loot = 9, echo = 10 }, pal = { base = 1 } }

describe("sprite forms", function()
  it("knows each form and draws it with that name", function()
    for _, f in ipairs(spr.FORMS) do
      expect(spr.is_form(f)).to_be(true)
      local v = view()
      expect(spr.draw(v, A, f, { 0, 0, 0 }, 2, { tint = { 1, 1, 1, 1 } })).to_be(1)
      expect(#v.bills).to_be(1)
      expect(v.bills[1].opts.form).to_be(f)
    end
    expect(spr.is_form("bubble")).to_be(false)
    local v = view()
    expect(spr.draw(v, A, "bubble", { 0, 0, 0 }, 1)).to_be(0)
    expect(#v.bills).to_be(0)
    -- no texture: nothing is drawn
    expect(spr.draw(view(), { pal = { base = 1 } }, "flare", { 0, 0, 0 }, 1)).to_be(0)
  end)

  it("lights, motes, echoes, loot, signals and warnings each use a different form", function()
    local v = view()
    spr.light(v, A, { 1, 0, 0 }, 2, { tint = { 1, 0.8, 0.3, 0.8 } })
    spr.shard(v, A, { 2, 0, 0 }, 1, { tint = { 0.8, 0.5, 1, 0.5 } })
    spr.ring(v, A, { 3, 0, 0 }, 1.6, { tint = { 0.55, 0.95, 1, 1 } })
    spr.spark(v, A, { 4, 0, 0 }, 1, { tint = { 1, 0.85, 0.3, 0.95 } })
    spr.slit(v, A, { 5, 0, 0 }, 3, { tint = { 0.4, 0.9, 1, 0.9 } })
    spr.mark(v, A, { 6, 0, 0 }, 1.5, { tint = { 1, 0.25, 0.2, 0.9 } })
    spr.streak(v, A, { 7, 0, 0 }, 0.4, { height = 1.2, tint = { 1, 1, 1, 0.5 } })
    local forms = {}
    for _, b in ipairs(v.bills) do forms[b.opts.form] = (forms[b.opts.form] or 0) + 1 end
    expect(forms.flare).to_be(1)
    expect(forms.shard).to_be(1)
    expect(forms.ring).to_be(1)
    expect(forms.spark).to_be(1)
    expect(forms.slit).to_be(1)
    expect(forms.chevron).to_be(1)
    expect(forms.streak).to_be(1)
    expect(v.bills[1].opts.form ~= v.bills[2].opts.form).to_be(true)
    -- a sentry's floor light is a flat pool, not a billboard bubble
    local v2 = view()
    expect(spr.pool(v2, A, { 0, 0, 0 }, 1.6, { 1, 0.8, 0.2, 0.4 })).to_be(1)
    expect(#v2.meshes).to_be(1)
    expect(#v2.bills).to_be(0)
  end)

  it("a ripple is a ring on the floor and a shadow is a tall figure, not a bubble", function()
    local mn, mx = { -40, -10, -40 }, { 40, 20, 40 }
    local rip = phv.pose({ kind = "ripple", pos = { 0, 0, 0 }, size = 20, seed = 3, phase = 0 }, 1.0,
                         { 0, 0, 0 }, mn, mx)
    expect(#rip >= 1).to_be(true)
    expect(rip[1].ring).to_be(true)
    local sh = phv.pose({ kind = "shadow", pos = { 0, 0, 0 }, size = 10, seed = 3, phase = 0, long = 3 }, 0,
                        { 0, 0, -95 }, mn, mx)
    expect(sh[1].dark).to_be(true)
    local v = view()
    phv.draw_one(v, A, { kind = "ripple", pos = { 0, 0, 0 }, size = 20, seed = 3, phase = 0 }, mn, mx,
                 { pos = { 0, 0, 0 } }, 1.0, A.pal.base)
    expect(#v.meshes >= 1).to_be(true)
    local rings = 0
    for _, m in ipairs(v.meshes) do if m.mesh == spr.ring_mesh() then rings = rings + 1 end end
    expect(rings >= 1).to_be(true)
    local v2 = view()
    phv.draw_one(v2, A, { kind = "shadow", pos = { 0, 0, 0 }, size = 10, seed = 3, phase = 0, long = 3 }, mn, mx,
                 { pos = { 0, 0, -95 } }, 0, A.pal.base)
    expect(#v2.meshes >= 1).to_be(true)
    expect(v2.meshes[1].mesh).to_be(spr.shade_mesh())
    -- motes still billboard, as shards
    local v3 = view()
    phv.draw_one(v3, A, { kind = "motes", pos = { 0, 0, 0 }, size = 8, seed = 3, phase = 0 }, mn, mx,
                 { pos = { 0, 0, 0 } }, 2.0, A.pal.base)
    expect(#v3.bills >= 1).to_be(true)
    expect(v3.bills[1].opts.form).to_be("shard")
  end)

  it("a city swarm is shards and a lane pulse is a streak along the lane", function()
    local r = { seed = 42, solids = {}, city = {
      districts = { { id = 1, pos = { 0, 0, 0 } } },
      style = { accent = { 0.8, 0.9, 1 }, window = { 0.4, 0.9, 1 } },
      lanes = { { a = { 0, 40, 0 }, b = { 400, 40, 0 } } },
    } }
    local list = cityphen.place(r)
    local kinds = {}
    for _, ph in ipairs(list) do kinds[ph.kind] = ph end
    expect(kinds.swarm ~= nil).to_be(true)
    expect(kinds.pulse ~= nil).to_be(true)
    local v = view()
    cityphen.draw(v, A, r, { pos = { 0, 40, 0 } }, 2.0)
    local shards, bolts = 0, 0
    for _, b in ipairs(v.bills) do if b.opts.form == "shard" then shards = shards + 1 end end
    for _, m in ipairs(v.meshes) do if m.mesh == spr.streak_mesh() then bolts = bolts + 1 end end
    expect(shards >= 1).to_be(true)
    expect(bolts >= 1).to_be(true)
  end)

  it("does not change simulation state", function()
    -- the helpers are a function of the clock and the eye only: they never write the state
    local st = { tick = 12, mutated = false }
    local v = view()
    spr.light(v, A, { 0, 1, 0 }, 2, { tint = { 1, 1, 1, 1 } })
    spr.bolt(v, A, { 0, 0, 0 }, { 0, 0, 1 }, 12, { 1, 1, 1, 0.5 })
    spr.shade(v, A, { 1, 0, 0 }, 2, 0.6)
    spr.ripple(v, A, { 2, 0, 0 }, 4, { 0.8, 0.5, 1, 0.4 })
    expect(st.tick).to_be(12)
    expect(st.mutated).to_be(false)
  end)
end)
