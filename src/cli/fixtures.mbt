///|
/// CLI test fixtures for self-application PBT
/// Provides reusable command array fixtures for property-based testing
///

///|
/// All valid command fixtures for CLI testing
pub fn all_command_fixtures() -> Array[Array[String]] {
  [
    // Basic commands
    ["moon-pbt-gen", "analyze", "./src"],
    ["moon-pbt-gen", "generate", "./src"],
    ["moon-pbt-gen", "sync", "src/aletheia.pbt.md"],
    ["moon-pbt-gen", "help"],
    // With options
    ["moon-pbt-gen", "analyze", "./src", "--dry-run"],
    ["moon-pbt-gen", "analyze", "./src", "--explain"],
    ["moon-pbt-gen", "analyze", "./src", "--format", "json"],
    ["moon-pbt-gen", "generate", "./src", "--dry-run", "--explain"],
    ["moon-pbt-gen", "generate", "./src", "--format", "json"],
    ["moon-pbt-gen", "generate", "./src", "--generic-names", "src,main"],
    ["moon-pbt-gen", "sync", "src/aletheia.pbt.md", "--dry-run"],
    // Multiple options combined
    [
      "moon-pbt-gen", "analyze", "./src", "--dry-run", "--explain", "--format", "json",
    ],
  ]
}

///|
/// Invalid command fixtures for error handling testing
pub fn invalid_command_fixtures() -> Array[Array[String]] {
  [
    [],
    ["moon-pbt-gen"],
    ["moon-pbt-gen", "unknown"],
    ["moon-pbt-gen", "analyze"], // missing path
    ["moon-pbt-gen", "generate"], // missing path
    ["moon-pbt-gen", "analyze", "./src", "--unknown-flag"],
    ["moon-pbt-gen", "analyze", "./src", "--format"], // missing format value
    ["moon-pbt-gen", "analyze", "./src", "--format", "invalid"],
    ["moon-pbt-gen", "generate", "./src", "--generic-names"], // missing list
  ]
}
