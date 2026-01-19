///|
test "prop_parse_args_command_to_args_roundtrip" {
  let fixtures = @cli.all_command_fixtures()
  for args in fixtures {
    let args2 = @cli.command_to_args(@cli.parse_args(args))
    assert_eq(args2, args)
  }
}

///|
test "prop_parse_args_invalid_is_help" {
  let invalid_args = @cli.invalid_command_fixtures()
  for args in invalid_args {
    let cmd = @cli.parse_args(args)
    // For invalid args, round-trip should at least produce valid args
    let args2 = @cli.command_to_args(cmd)
    let cmd2 = @cli.parse_args(args2)
    // Should not error on second parse
    assert_eq(@cli.command_to_args(cmd2), args2)
  }
}
