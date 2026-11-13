# Writes data/index.json listing every file under ROOT/data so the web build
# can fetch the folder tree over HTTP (no preloaded bundle).
# SPDX-License-Identifier: MIT
file(GLOB_RECURSE files RELATIVE ${ROOT} ${ROOT}/data/*)
list(SORT files)
set(json "[\n")
set(first TRUE)
foreach(f ${files})
  if(f STREQUAL "data/index.json")
    continue()
  endif()
  if(NOT first)
    string(APPEND json ",\n")
  endif()
  set(first FALSE)
  string(APPEND json "  \"${f}\"")
endforeach()
string(APPEND json "\n]\n")
file(WRITE ${ROOT}/data/index.json "${json}")
