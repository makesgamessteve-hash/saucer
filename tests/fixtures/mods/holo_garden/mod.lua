-- Example holodeck mod: a data-only mod that adds a program. Dropping a file
-- into holo/ is all it takes; no entry script and no engine change.
return {
  id = "holo_garden", name = "Holo Zen Garden", version = "1.0.0", api = 1,
  description = "A calm holodeck program: raked sand, stones and koi.",
  depends = { "base >=0.1.0" },
  license_code = "MIT", license_assets = "CC-BY-4.0",
}
