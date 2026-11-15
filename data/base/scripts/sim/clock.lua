-- SPDX-License-Identifier: MIT
-- Sim time in minutes: ticks at 60 Hz plus time skipped by sleeping. Saved
-- as the world key `clock`.
local M = {}

M.TICKS_PER_MINUTE = 3600

function M.new() return { skipped = 0 } end

function M.minutes(state)
  local skipped = state.clock and state.clock.skipped or 0
  return state.tick / M.TICKS_PER_MINUTE + skipped
end

function M.skip(state, minutes)
  state.clock = state.clock or M.new()
  state.clock.skipped = state.clock.skipped + minutes
end

return M
