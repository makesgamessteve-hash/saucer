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
  engine/src/core/sx_mod.c engine/src/core/sx_phys.c engine/src/core/sx_procgen.c
  engine/src/core/sx_render.c engine/src/core/sx_replay.c engine/src/core/sx_rng.c
  engine/src/core/sx_script.c engine/src/core/sx_ser.c engine/src/core/sx_touch.c
  engine/src/core/sx_vfs.c engine/src/core/sx_xr.c)
add_library(saucer_core STATIC ${CORE_SOURCES})
add_library(saucer_stb STATIC engine/src/core/sx_stb.c)
target_include_directories(saucer_stb PUBLIC third_party/stb)
target_include_directories(saucer_core PUBLIC engine/src/core third_party/stb)
target_link_libraries(saucer_core PUBLIC saucer_lua saucer_stb)
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

# ---- Game binary (SDL3 + OpenGL 3.3 / WebGL2) ----
if(SAUCER_BUILD_GAME)
  if(EMSCRIPTEN)
    add_executable(saucer engine/src/platform/sx_sdl_main.c engine/src/platform/sx_gl.c engine/src/platform/sx_audio.c)
    target_link_libraries(saucer PRIVATE saucer_core)
    target_compile_options(saucer PRIVATE -sUSE_SDL=3)
    target_link_options(saucer PRIVATE -sUSE_SDL=3 -sMAX_WEBGL_VERSION=2 -sMIN_WEBGL_VERSION=2
      -sALLOW_MEMORY_GROWTH=1 -sFORCE_FILESYSTEM=1 -sEXPORTED_RUNTIME_METHODS=FS,callMain,ccall
      -sEXPORTED_FUNCTIONS=_main,_saucer_xr_set_available,_saucer_xr_begin,_saucer_xr_end,_saucer_xr_frame,_saucer_xr_set_view,_saucer_xr_set_head,_saucer_xr_set_control,_malloc,_free
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
if(SAUCER_BUILD_TESTS AND NOT EMSCRIPTEN)
  enable_testing()
  file(GLOB C_TESTS tests/c/test_*.c)
  add_executable(saucer_tests tests/c/test_main.c ${C_TESTS})
  target_link_libraries(saucer_tests PRIVATE saucer_core)
  target_compile_definitions(saucer_tests PRIVATE SAUCER_SOURCE_DIR="${CMAKE_SOURCE_DIR}")
  add_test(NAME c_unit COMMAND saucer_tests WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  add_test(NAME lua_unit COMMAND saucer_headless --root . --test-lua tests/lua --quiet WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  file(GLOB GAME_TESTS tests/game/*.lua)
  foreach(t ${GAME_TESTS})
    get_filename_component(name ${t} NAME_WE)
    add_test(NAME game_${name} COMMAND saucer_headless --root . --seed 42 --script ${t} --quiet WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  endforeach()
  file(GLOB REPLAYS tests/replays/*.srep)
  foreach(r ${REPLAYS})
    get_filename_component(name ${r} NAME_WE)
    add_test(NAME replay_${name} COMMAND saucer_headless --root . --play ${r} --quiet WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME replay_${name}_restore COMMAND saucer_headless --root . --play ${r} --restore-every-tick --quiet WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  endforeach()
endif()
