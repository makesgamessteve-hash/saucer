-- SPDX-License-Identifier: MIT
-- In-world menus (milestone 2): the wake-up title, the bed, the lab bench and
-- the trade terminal open a small list. Only plain data lives in the state
-- (kind, selected row, last stick value); rows are rebuilt from the state
-- every tick by the panel kind's rows() function, so snapshots, saves and
-- replays never hold functions. Navigation works on every device: up/down on
-- the move stick (W/S, gamepad, touch stick, XR stick) and Use to pick.
local M = {}

M.kinds = {}
M.EDGE = 0.5

-- register(kind, { title = string|function(state, p), rows = function(state, p) -> list })
-- a row is { text =, act = function(state, p, row) end, enabled = true|false, hint = }
function M.register(kind, def) M.kinds[kind] = def end

function M.open(p, kind, ctx)
  p.panel = { kind = kind, sel = 1, axis = 0, ctx = ctx }
end

function M.close(p) p.panel = false end

function M.rows(state, p)
  local pn = p.panel
  if not pn then return {} end
  local def = M.kinds[pn.kind]
  if not def then return {} end
  return def.rows(state, p)
end

function M.title(state, p)
  local def = p.panel and M.kinds[p.panel.kind]
  if not def then return "" end
  if type(def.title) == "function" then return def.title(state, p) end
  return def.title or p.panel.kind
end

-- step(state, p, cmd) -> true while a panel is open (it eats the input)
function M.step(state, p, cmd)
  local pn = p.panel
  if not pn then return false end
  local rows = M.rows(state, p)
  if #rows == 0 then
    M.close(p)
    return false
  end
  local a = cmd:axis("move_z")
  if a > M.EDGE and pn.axis <= M.EDGE then pn.sel = pn.sel - 1 end
  if a < -M.EDGE and pn.axis >= -M.EDGE then pn.sel = pn.sel + 1 end
  pn.axis = a
  if pn.sel < 1 then pn.sel = #rows end
  if pn.sel > #rows then pn.sel = 1 end
  if cmd:pressed("use") then
    local row = rows[pn.sel]
    if row.enabled == false then
      return true, "disabled", row
    end
    row.act(state, p, row)
    return true, "picked", row
  end
  return true
end

-- select the first row whose text starts with `prefix` (scripted runs)
function M.find(state, p, prefix)
  for i, r in ipairs(M.rows(state, p)) do
    if r.text:sub(1, #prefix) == prefix then return i end
  end
  return nil
end

return M
