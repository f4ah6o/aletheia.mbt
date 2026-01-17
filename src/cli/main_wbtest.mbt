///|
test "filter_internal_functions_excludes_helpers" {
  let names = [
    "generated_block_start", "generated_block_end", "parse_markdown", "generate_markdown",
  ]
  let filtered = filter_internal_functions(names)
  // Only parse_markdown and generate_markdown should remain
  inspect(filtered.length(), content="2")
}

///|
test "is_internal_function_detects_exact_matches" {
  assert_eq(is_internal_function("generated_block_start"), true)
  assert_eq(is_internal_function("generated_block_end"), true)
  assert_eq(is_internal_function("parse_markdown"), false)
}

///|
test "is_internal_function_detects_prefix_matches" {
  assert_eq(is_internal_function("wrap_generated_foo"), true)
  assert_eq(is_internal_function("append_generated_bar"), true)
  assert_eq(is_internal_function("merge_generated_baz"), true)
  assert_eq(is_internal_function("filter_patterns_test"), true)
  assert_eq(is_internal_function("build_type"), true)
  assert_eq(is_internal_function("normal_function"), false)
}
