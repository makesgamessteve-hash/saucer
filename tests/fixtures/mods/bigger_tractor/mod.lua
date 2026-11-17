-- Example content mod: overrides a data file and listens to events.
return {
  id = "bigger_tractor", name = "Bigger Tractor", version = "1.0.0", api = 1,
  description = "A longer tractor beam for the size-2 saucer (a data override).",
  depends = { "base >=0.1.0" }, entry = "scripts/main.lua",
  license_code = "MIT", license_assets = "CC-BY-4.0",
}
