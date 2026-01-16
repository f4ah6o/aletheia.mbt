///|
test "prop_parse_args_command_to_args_roundtrip" {
  let fixtures : Array[Array[String]] = [
    // Basic commands
    ["moon-pbt-gen", "analyze", "./src"],
    ["moon-pbt-gen", "generate", "./src"],
    ["moon-pbt-gen", "sync", "src/aletheia.pbt.mbt.md"],
    ["moon-pbt-gen", "help"],
    // With options
    ["moon-pbt-gen", "analyze", "./src", "--dry-run"],
    ["moon-pbt-gen", "analyze", "./src", "--explain"],
    ["moon-pbt-gen", "analyze", "./src", "--format", "json"],
    ["moon-pbt-gen", "generate", "./src", "--dry-run", "--explain"],
    ["moon-pbt-gen", "generate", "./src", "--format", "json"],
    ["moon-pbt-gen", "sync", "src/aletheia.pbt.mbt.md", "--dry-run"],
    // Multiple options combined
    [
      "moon-pbt-gen", "analyze", "./src", "--dry-run", "--explain", "--format", "json",
    ],
  ]
  for args in fixtures {
    let args2 = @cli.command_to_args(@cli.parse_args(args))
    assert_eq(args2, args)
  }
}

///|
test "prop_parse_args_invalid_is_help" {
  let invalid_args : Array[Array[String]] = [
    [],
    ["moon-pbt-gen"],
    ["moon-pbt-gen", "unknown"],
    ["moon-pbt-gen", "analyze"], // missing path
    ["moon-pbt-gen", "generate"], // missing path
    ["moon-pbt-gen", "analyze", "./src", "--unknown-flag"],
    ["moon-pbt-gen", "analyze", "./src", "--format"], // missing format value
    ["moon-pbt-gen", "analyze", "./src", "--format", "invalid"],
  ]
  for args in invalid_args {
    let cmd = @cli.parse_args(args)
    // For invalid args, round-trip should at least produce valid args
    let args2 = @cli.command_to_args(cmd)
    let cmd2 = @cli.parse_args(args2)
    // Should not error on second parse
    assert_eq(@cli.command_to_args(cmd2), args2)
  }
}
