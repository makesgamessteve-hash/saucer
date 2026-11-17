# SPDX-License-Identifier: MIT
# add-home-among-stars: run tests/game/modbrowser.lua twice against one fresh
# user dir - the first run switches a mod off, the second starts without it.
# cmake -DHL=<saucer_headless> -DROOT=<repo> -DUSER=<dir> -P tools/mod_browser.cmake
file(REMOVE_RECURSE ${USER})
foreach(phase 1 2)
  execute_process(COMMAND ${HL} --root ${ROOT} --user-dir ${USER} --quiet --seed 42
                          --mods-dir ${ROOT}/tests/fixtures/mods --script tests/game/modbrowser.lua
                  WORKING_DIRECTORY ${ROOT} RESULT_VARIABLE rc OUTPUT_VARIABLE out ERROR_VARIABLE err)
  if(NOT rc EQUAL 0)
    message(FATAL_ERROR "mod browser phase ${phase} failed (${rc}):\n${out}\n${err}")
  endif()
  file(READ ${USER}/mods.txt left)
  string(STRIP "${left}" left)
  if(phase EQUAL 1 AND NOT left STREQUAL "bigger_tractor")
    message(FATAL_ERROR "phase 1 should switch bigger_tractor off, mods.txt has: '${left}'")
  endif()
endforeach()
if(NOT left STREQUAL "")
  message(FATAL_ERROR "mods.txt should be empty again, has: ${left}")
endif()
message(STATUS "mod browser: both phases OK")
