-- SPDX-License-Identifier: MIT
-- The base game is itself a mod: everything it does goes through the same
-- saucer.* API that user mods in mods/<id>/ get.
return {
  id = "base",
  name = "Saucer",
  version = "0.1.0",
  api = 1,
  depends = {},
  load_after = {},
  entry = "scripts/main.lua",
  license_code = "MIT",
  license_assets = "CC-BY-4.0, LicenseRef-xAI-Output",
  licenses = { code = "MIT", assets = { "CC-BY-4.0", "LicenseRef-xAI-Output" } },
}
