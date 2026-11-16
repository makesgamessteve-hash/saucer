-- SPDX-License-Identifier: MIT
-- Home finds in derelict vaults (OpenSpec add-holodeck-home-life): data cores
-- with holodeck programs, holodeck modules, books and logs, alien
-- ingredients (home/finds.lua, per kit). They are beamed up like loot (each
-- player has their own copy) and ride in the hold, hot until banked. On
-- banking, books go onto the shelf and ingredients into the pantry; data
-- cores wait for the lab bench and modules for the holodeck panel.
local data = require("lib.data")
local M = {}

-- vault quarters not used by the Echo (+x +z) or by the loot slots (centre line)
M.QUARTERS = { { -1, -1 }, { -1, 1 }, { 1, -1 } }

function M.table() return data.load("home/finds.lua") end

-- what a find is called and what it is worth to a trader
function M.item(f)
  local name, value, cat, ident = "Find", 10, "curio", true
  if f.kind == "program" then
    local holo = require("sim.holo")
    local prog = holo.program(f.id)
    name, value, cat, ident = "Data core", 25, "data", false
    f.title = prog and prog.name or f.id
  elseif f.kind == "module" then
    local m = data.load("home/holo_modules.lua")[f.id]
    name, value, cat = m and m.name or f.id, m and m.value or 20, "module"
  elseif f.kind == "book" then
    local b = require("sim.books").def(f.id)
    name, value, cat = b and b.title or f.id, 0, "book"
  elseif f.kind == "ingredient" then
    name, value, cat = string.format("%s crate (%d)", require("sim.kitchen").name(f.id), f.n or 1), 0, "food"
  end
  return { type = "home", home = { kind = f.kind, id = f.id, n = f.n, title = f.title }, name = name, size = 1,
           value = value, category = cat, ident = ident, rarity = "rare" }
end

-- candidates(state, p, site_idx, ruin) -> tractor targets (key "find:<site>:<k>")
function M.candidates(state, p, site_idx, ruin)
  local out = {}
  local site = state.sector.sites[site_idx]
  if not site or not ruin then return out end
  local list = M.table()[site.kit] or {}
  local ruinm = require("sim.ruin")
  local kit = ruinm.kit_of(ruin.kit)
  for _, r in ipairs(ruin.rooms) do
    if r.kind == "vault" then
      local mn, mx = ruinm.room_box(r, kit, site.pos)
      for k, f in ipairs(list) do
        local q = M.QUARTERS[k]
        local key = "find:" .. site_idx .. ":" .. k
        if q and not p.looted[key] then
          local c = { (mn[1] + mx[1]) / 2 + q[1] * (mx[1] - mn[1]) / 4, mn[2] + kit.wall + 0.8,
                      (mn[3] + mx[3]) / 2 + q[2] * (mx[3] - mn[3]) / 4 }
          out[#out + 1] = { key = key, kind = "find", pos = c, room = r.id,
                            item = M.item({ kind = f.kind, id = f.id, n = f.n }) }
        end
      end
    end
  end
  return out
end

-- unpack(state, p, it, ctx) -> true when the item left the hold (books, ingredients)
function M.unpack(state, p, it, ctx)
  local h = it.home
  if not h then return false end
  if h.kind == "book" then
    local books = require("sim.books")
    local new = books.add(p, h.id)
    ctx.msg(state, p, (new and "Shelved: " or "Already on the shelf: ") .. it.name)
    return true
  elseif h.kind == "ingredient" then
    local kitchen = require("sim.kitchen")
    kitchen.stock(p, h.id, h.n or 1)
    ctx.msg(state, p, string.format("Pantry: +%d %s", h.n or 1, kitchen.name(h.id)))
    return true
  end
  return false
end

return M
