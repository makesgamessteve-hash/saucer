-- SPDX-License-Identifier: MIT
-- MVP: two hand-tuned civilization trait sets (concept §5.3).
return {
  { id = "velari", name = "Velari", body = "human", shape = "angular", palette = "velari",
    domains = { "gravitics", "fold" }, fate = "flight", temperament = "mercantile",
    entrance = { { 3, 3 }, { 2, 2 } }, size_lock = 45 },
  { id = "oquun", name = "Oquun", body = "tiny", shape = "organic", palette = "oquun",
    domains = { "bio", "optics" }, fate = "plague", temperament = "reclusive",
    entrance = { { 3, 1 }, { 2, 3 } }, size_lock = 70 },
}
