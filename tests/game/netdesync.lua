-- SPDX-License-Identifier: MIT
-- Desync detection (OpenSpec add-home-among-stars): the guest changes its
-- copy of the sim behind the lockstep's back; the next hash comparison must
-- catch it on both machines (tools/net_loopback.cmake -DEXPECT=desync).
local T = saucer.test
T.wait(100)
if saucer.net.status().slot == 2 then T.state().players[1].credits = 999 end
T.wait(400)
error("the desync was not detected")
