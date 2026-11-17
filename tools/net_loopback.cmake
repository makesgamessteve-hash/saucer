# SPDX-License-Identifier: MIT
# add-home-among-stars: run a host and a guest saucer_headless on loopback at
# the same time (execute_process runs a COMMAND pipeline concurrently) and
# check that both finished, agreed on every compared state hash and ended on
# the same final hash.
#   cmake -DHL=<saucer_headless> -DROOT=<repo> -DUSER=<dir> -DPORT=<udp port>
#         -DSCRIPT=<game test> [-DSEED=42] [-DDELAY=3] [-DEXTRA="--a;--b"]
#         [-DEXPECT=desync] -P tools/net_loopback.cmake
if(NOT SEED)
  set(SEED 42)
endif()
if(NOT DELAY)
  set(DELAY 3)
endif()
set(common --root ${ROOT} --quiet --script ${SCRIPT} --net-delay ${DELAY} ${EXTRA})
execute_process(
  COMMAND ${HL} --user-dir ${USER}-host --seed ${SEED} --host ${PORT} ${common}
  COMMAND ${HL} --user-dir ${USER}-guest --join 127.0.0.1:${PORT} ${common}
  RESULTS_VARIABLE results
  OUTPUT_VARIABLE out
  ERROR_VARIABLE err
  TIMEOUT 1500)
message("${out}")
message("${err}")
string(REGEX MATCHALL "net slot [0-9]+ ticks [0-9]+ final_hash [0-9a-f]+ checks [0-9]+" lines "${err}")
list(LENGTH lines nl)
if(EXPECT STREQUAL "desync")
  string(REGEX MATCHALL "DESYNC at tick" ds "${err}")
  list(LENGTH ds nd)
  if(nd LESS 1)
    message(FATAL_ERROR "expected a desync to be detected (results ${results})")
  endif()
  message("desync detected as expected (results ${results})")
  return()
endif()
if(NOT results STREQUAL "0;0")
  message(FATAL_ERROR "host/guest exit codes: ${results}")
endif()
if(NOT nl EQUAL 2)
  message(FATAL_ERROR "expected two net summaries, got ${nl}")
endif()
list(GET lines 0 a)
list(GET lines 1 b)
string(REGEX REPLACE ".*final_hash ([0-9a-f]+).*" "\\1" ha "${a}")
string(REGEX REPLACE ".*final_hash ([0-9a-f]+).*" "\\1" hb "${b}")
string(REGEX REPLACE ".*ticks ([0-9]+).*" "\\1" ta "${a}")
string(REGEX REPLACE ".*ticks ([0-9]+).*" "\\1" tb "${b}")
string(REGEX REPLACE ".*checks ([0-9]+)" "\\1" ca "${a}")
if(NOT ha STREQUAL hb OR NOT ta STREQUAL tb)
  message(FATAL_ERROR "the two machines ended apart: ${a} / ${b}")
endif()
if(ca LESS 10)
  message(FATAL_ERROR "too few hash comparisons (${ca})")
endif()
message("net loopback OK: tick ${ta}, hash ${ha}, ${ca} hash checks")
