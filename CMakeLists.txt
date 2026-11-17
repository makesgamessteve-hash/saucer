# SPDX-License-Identifier: MIT
cmake_minimum_required(VERSION 3.20)
project(saucer VERSION 0.1.0 LANGUAGES C)

option(SAUCER_BUILD_GAME "Build the SDL3/OpenGL game binary" ON)
option(SAUCER_BUILD_TESTS "Build unit tests" ON)
option(SAUCER_COVERAGE "Instrument engine core for gcov" OFF)
option(SAUCER_FETCH_SDL "Fetch and build SDL3 from source if not found" ON)
option(SAUCER_SANITIZE "Build with ASan/UBSan" OFF)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

# Determinism: no fast-math, no FMA contraction.
if(MSVC)
  add_compile_options(/fp:precise /W3 /D_CRT_SECURE_NO_WARNINGS)
else()
  add_compile_options(-ffp-contract=off -fno-fast-math)
endif()
if(SAUCER_SANITIZE AND NOT MSVC)
  add_compile_options(-fsanitize=address,undefined -fno-omit-frame-pointer)
  add_link_options(-fsanitize=address,undefined)
endif()

# ---- Lua 5.4 (vendored, with the fixed-seed determinism patch) ----
file(GLOB LUA_SOURCES third_party/lua/*.c)
add_library(saucer_lua STATIC ${LUA_SOURCES})
target_include_directories(saucer_lua PUBLIC third_party/lua)
if(UNIX AND NOT EMSCRIPTEN)
  target_compile_definitions(saucer_lua PRIVATE LUA_USE_POSIX)
endif()
if(UNIX)
  target_link_libraries(saucer_lua PUBLIC m)
endif()

# ---- Engine core (pure C, no SDL: everything that is unit tested) ----
set(CORE_SOURCES
  engine/src/core/sx_engine.c engine/src/core/sx_fs.c engine/src/core/sx_input.c
  engine/src/core/sx_log.c engine/src/core/sx_math.c engine/src/core/sx_mesh.c
  engine/src/core/sx_net.c engine/src/core/sx_net_udp.c
  engine/src/core/sx_mod.c engine/src/core/sx_phys.c engine/src/core/sx_procgen.c
  engine/src/core/sx_render.c engine/src/core/sx_replay.c engine/src/core/sx_rng.c
  engine/src/core/sx_script.c engine/src/core/sx_ser.c engine/src/core/sx_touch.c
  engine/src/core/sx_vfs.c engine/src/core/sx_xr.c)
add_library(saucer_core STATIC ${CORE_SOURCES})
add_library(saucer_stb STATIC engine/src/core/sx_stb.c)
target_include_directories(saucer_stb PUBLIC third_party/stb)
target_include_directories(saucer_core PUBLIC engine/src/core third_party/stb)
target_link_libraries(saucer_core PUBLIC saucer_lua saucer_stb)
if(WIN32)
  target_link_libraries(saucer_core PUBLIC ws2_32)
endif()
if(NOT MSVC)
  target_compile_options(saucer_core PRIVATE -Wall -Wextra -Wno-unused-parameter)
endif()
if(SAUCER_COVERAGE)
  target_compile_options(saucer_core PRIVATE --coverage -O0 -g)
  target_link_options(saucer_core PUBLIC --coverage)
endif()

# ---- Headless binary (no SDL) ----
add_executable(saucer_headless engine/src/main_headless.c)
target_link_libraries(saucer_headless PRIVATE saucer_core)
if(EMSCRIPTEN)
  # Node test runner: real filesystem access to the repo, exit code passthrough.
  target_link_options(saucer_headless PRIVATE -sNODERAWFS=1 -sEXIT_RUNTIME=1 -sALLOW_MEMORY_GROWTH=1 -sSTACK_SIZE=1048576)
endif()

# ---- Game binary (SDL3 + OpenGL 3.3 / WebGL2) ----
if(SAUCER_BUILD_GAME)
  if(EMSCRIPTEN)
    add_executable(saucer engine/src/platform/sx_sdl_main.c engine/src/platform/sx_gl.c engine/src/platform/sx_audio.c)
    target_link_libraries(saucer PRIVATE saucer_core)
    target_compile_options(saucer PRIVATE -sUSE_SDL=3)
    target_link_options(saucer PRIVATE -sUSE_SDL=3 -sMAX_WEBGL_VERSION=2 -sMIN_WEBGL_VERSION=2
      -sALLOW_MEMORY_GROWTH=1 -sFORCE_FILESYSTEM=1 -sINVOKE_RUN=0 -sSTACK_SIZE=1048576 -sEXPORTED_RUNTIME_METHODS=FS,callMain,ccall
      -sEXPORTED_FUNCTIONS=_main,_saucer_xr_set_available,_saucer_xr_begin,_saucer_xr_end,_saucer_xr_frame,_saucer_xr_set_view,_saucer_xr_set_head,_saucer_xr_set_control,_saucer_xr_set_hand,_malloc,_free
      --js-library ${CMAKE_SOURCE_DIR}/web/saucer_xr.js
      --shell-file ${CMAKE_SOURCE_DIR}/web/shell.html)
    set_target_properties(saucer PROPERTIES SUFFIX ".html")
  else()
    find_package(SDL3 CONFIG QUIET)
    if(NOT SDL3_FOUND AND SAUCER_FETCH_SDL)
      include(FetchContent)
      set(SDL_SHARED OFF CACHE BOOL "" FORCE)
      set(SDL_STATIC ON CACHE BOOL "" FORCE)
      set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
      FetchContent_Declare(SDL3 GIT_REPOSITORY https://github.com/libsdl-org/SDL.git GIT_TAG release-3.2.10 GIT_SHALLOW TRUE)
      FetchContent_MakeAvailable(SDL3)
    endif()
    add_executable(saucer engine/src/platform/sx_sdl_main.c engine/src/platform/sx_gl.c engine/src/platform/sx_audio.c)
    target_link_libraries(saucer PRIVATE saucer_core SDL3::SDL3)
    if(NOT MSVC)
      target_compile_options(saucer PRIVATE -Wall -Wextra -Wno-unused-parameter)
    endif()
    if(WIN32)
      set_target_properties(saucer PROPERTIES WIN32_EXECUTABLE OFF)
    endif()
  endif()
  # Assets live beside the binary, never inside it: copy data/ next to the executable.
  add_custom_command(TARGET saucer POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/data $<TARGET_FILE_DIR:saucer>/data
    COMMAND ${CMAKE_COMMAND} -E make_directory $<TARGET_FILE_DIR:saucer>/mods
    COMMAND ${CMAKE_COMMAND} -DROOT=$<TARGET_FILE_DIR:saucer> -P ${CMAKE_SOURCE_DIR}/tools/make_index.cmake
    COMMENT "Copying data/ beside the binary")
endif()

# ---- Tests ----
if(SAUCER_BUILD_TESTS)
  enable_testing()
  file(GLOB C_TESTS tests/c/test_*.c)
  add_executable(saucer_tests tests/c/test_main.c ${C_TESTS})
  target_link_libraries(saucer_tests PRIVATE saucer_core)
  target_compile_definitions(saucer_tests PRIVATE SAUCER_SOURCE_DIR="${CMAKE_SOURCE_DIR}")
  if(EMSCRIPTEN)
    # runs under node (CMAKE_CROSSCOMPILING_EMULATOR) against the real repo files
    target_link_options(saucer_tests PRIVATE -sNODERAWFS=1 -sEXIT_RUNTIME=1 -sALLOW_MEMORY_GROWTH=1 -sSTACK_SIZE=1048576)
  endif()
  add_test(NAME c_unit COMMAND saucer_tests WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  set(USERDIR ${CMAKE_BINARY_DIR}/test-user)
  set(HL saucer_headless --root ${CMAKE_SOURCE_DIR} --user-dir ${USERDIR} --quiet)
  add_test(NAME lua_unit COMMAND ${HL} --test-lua tests/lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_boot COMMAND ${HL} --seed 42 --script tests/game/boot.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_slice COMMAND ${HL} --seed 42 --script tests/game/slice.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_slice_seed7 COMMAND ${HL} --seed 7 --script tests/game/slice.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_slice_restore_every_tick COMMAND ${HL} --seed 42 --script tests/game/slice.lua --restore-every-tick
           WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_interior COMMAND ${HL} --seed 42 --script tests/game/interior.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_fold COMMAND ${HL} --seed 42 --script tests/game/fold.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_tractor COMMAND ${HL} --seed 42 --script tests/game/tractor.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  # the home test saves and loads: give each run its own user dir so parallel ctest runs cannot race
  add_test(NAME game_home COMMAND saucer_headless --root ${CMAKE_SOURCE_DIR} --user-dir ${USERDIR}-home --quiet
           --seed 42 --script tests/game/home.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_home_restore_every_tick COMMAND saucer_headless --root ${CMAKE_SOURCE_DIR}
           --user-dir ${USERDIR}-home-ret --quiet --seed 42 --script tests/game/home.lua --restore-every-tick
           WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  # milestone 3: identify + trade, a sentry encounter, the mystery chain (trade and mystery save and load)
  add_test(NAME game_trade COMMAND saucer_headless --root ${CMAKE_SOURCE_DIR} --user-dir ${USERDIR}-trade --quiet
           --seed 42 --script tests/game/trade.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_sentries COMMAND ${HL} --seed 42 --ticks 72000 --script tests/game/sentries.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_mystery COMMAND saucer_headless --root ${CMAKE_SOURCE_DIR} --user-dir ${USERDIR}-mystery --quiet
           --seed 42 --ticks 60000 --script tests/game/mystery.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  # milestone 4: holodeck programs, an upgrade, cooking, the bookshelf and the TV (saves at the trader)
  add_test(NAME game_holodeck COMMAND saucer_headless --root ${CMAKE_SOURCE_DIR} --user-dir ${USERDIR}-holo --quiet
           --seed 42 --script tests/game/holodeck.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  # milestone 5: pocket the saucer at a station, walk it, trade on foot, chase the pickpocket, unfold in a hangar
  add_test(NAME game_station COMMAND saucer_headless --root ${CMAKE_SOURCE_DIR} --user-dir ${USERDIR}-station --quiet
           --seed 42 --ticks 40000 --script tests/game/station.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_station_restore_every_tick COMMAND saucer_headless --root ${CMAKE_SOURCE_DIR}
           --user-dir ${USERDIR}-station-ret --quiet --seed 42 --ticks 40000 --script tests/game/station.lua
           --restore-every-tick WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_station_seed7 COMMAND saucer_headless --root ${CMAKE_SOURCE_DIR} --user-dir ${USERDIR}-station7
           --quiet --seed 7 --ticks 40000 --script tests/game/station.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  # milestone 7: step out in a derelict, crawl, turn a hand-lock, shut the grid, fail with the Lifeline, recover the cache
  add_test(NAME game_excursion COMMAND saucer_headless --root ${CMAKE_SOURCE_DIR} --user-dir ${USERDIR}-excursion --quiet
           --seed 42 --ticks 40000 --script tests/game/excursion.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_excursion_restore_every_tick COMMAND saucer_headless --root ${CMAKE_SOURCE_DIR}
           --user-dir ${USERDIR}-excursion-ret --quiet --seed 42 --ticks 40000 --script tests/game/excursion.lua
           --restore-every-tick WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_excursion_seed7 COMMAND saucer_headless --root ${CMAKE_SOURCE_DIR} --user-dir ${USERDIR}-excursion7
           --quiet --seed 7 --ticks 40000 --script tests/game/excursion.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  # milestone 8: four local players, party fold jumps, the multi-sector mystery to an ending
  add_test(NAME game_widerdark COMMAND ${HL} --seed 42 --coop --viewports 4 --ticks 90000 --script tests/game/widerdark.lua
           WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  # the inputs-only co-op session behind tests/replays/coop_seed42.srep
  add_test(NAME game_coop_replay COMMAND ${HL} --seed 42 --coop --viewports 4 --script tests/game/coop_replay.lua
           WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  # true 3D flight: vertical flight and a multi-level derelict traversal
  add_test(NAME game_vertical COMMAND ${HL} --seed 42 --script tests/game/vertical.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_derelict3d COMMAND ${HL} --seed 42 --script tests/game/derelict3d.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_derelict3d_seed7 COMMAND ${HL} --seed 7 --script tests/game/derelict3d.lua
           WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_xr COMMAND ${HL} --seed 42 --script tests/game/xr.lua WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_coop COMMAND ${HL} --seed 42 --local-players 2 --viewports 2 --script tests/game/coop.lua
           WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME game_mods COMMAND ${HL} --seed 42 --mods-dir tests/fixtures/mods --script tests/game/mods.lua
           WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  # milestone 9: the mod browser switches a mod off for the next start, and on again
  add_test(NAME game_mod_browser COMMAND ${CMAKE_COMMAND} -DHL=$<TARGET_FILE:saucer_headless> -DROOT=${CMAKE_SOURCE_DIR}
           -DUSER=${USERDIR}-modbrowser -P ${CMAKE_SOURCE_DIR}/tools/mod_browser.cmake
           WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  # milestone 9: two machines on loopback (a host and an XR guest) play one universe in
  # lockstep, decorate a dome and visit it; a deliberate desync must be caught
  if(NOT EMSCRIPTEN)
    set(NETL ${CMAKE_COMMAND} -DHL=$<TARGET_FILE:saucer_headless> -DROOT=${CMAKE_SOURCE_DIR})
    add_test(NAME game_netplay COMMAND ${NETL} -DUSER=${USERDIR}-net -DPORT=47831 -DSCRIPT=tests/game/netplay.lua
             -P ${CMAKE_SOURCE_DIR}/tools/net_loopback.cmake WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME game_netplay_seed7 COMMAND ${NETL} -DUSER=${USERDIR}-net7 -DPORT=47832 -DSEED=7 -DDELAY=5
             -DSCRIPT=tests/game/netplay.lua -P ${CMAKE_SOURCE_DIR}/tools/net_loopback.cmake
             WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME game_net_desync COMMAND ${NETL} -DUSER=${USERDIR}-netd -DPORT=47833 -DSCRIPT=tests/game/netdesync.lua
             -DEXPECT=desync -P ${CMAKE_SOURCE_DIR}/tools/net_loopback.cmake WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  endif()
  add_test(NAME headless_run COMMAND ${HL} --seed 1 --ticks 600 --test WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  file(GLOB REPLAYS tests/replays/*.srep)
  foreach(r ${REPLAYS})
    get_filename_component(name ${r} NAME_WE)
    add_test(NAME replay_${name} COMMAND ${HL} --play ${r} WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  endforeach()
  # no test may hang CI: a game test that never reaches its end fails after this many seconds
  # (generous: ASan, coverage and --restore-every-tick builds are many times slower)
  set(SAUCER_TEST_TIMEOUT 1800 CACHE STRING "per-test CTest timeout in seconds")
  get_property(SAUCER_TESTS DIRECTORY PROPERTY TESTS)
  set_tests_properties(${SAUCER_TESTS} PROPERTIES TIMEOUT ${SAUCER_TEST_TIMEOUT})
endif()
