///|
test "prop_generate_round_trip_test_is_deterministic" {
  let t1 = generate_round_trip_test("encode", "decode", "Data")
  let t2 = generate_round_trip_test("encode", "decode", "Data")
  inspect(t1.name == t2.name, content="true")
  inspect(t1.code == t2.code, content="true")
  inspect(t1.fence == t2.fence, content="true")
}

///|
test "prop_pattern_to_test_respects_fences" {
  let markdown = pattern_to_test(
    @patterns.make_round_trip("parse_markdown", "generate_markdown"),
    "String",
  )
  inspect(markdown.fence, content="mbt check")
  let args = pattern_to_test(
    @patterns.make_round_trip("parse_args", "command_to_args"),
    "Array[String]",
  )
  inspect(args.fence, content="mbt check")
  let generic = pattern_to_test(
    @patterns.make_round_trip("parse_config", "generate_config"),
    "String",
  )
  inspect(generic.fence, content="mbt nocheck")
}

///|
test "prop_generate_pbt_md_includes_sections" {
  let patterns : Array[@patterns.PatternCandidate] = [
    @patterns.make_round_trip("parse_markdown", "generate_markdown"),
    @patterns.make_idempotent("normalize"),
  ]
  let doc = build_pbt_document(
    "generator", "./src/generator", patterns, "String",
  )
  let md = generate_pbt_md(doc)
  inspect(md.contains("## Round-Trip Properties"), content="true")
  inspect(md.contains("## Idempotent Properties"), content="true")
  inspect(
    md.contains("prop_parse_markdown_generate_markdown_roundtrip"),
    content="true",
  )
}

///|
test "prop_generate_pbt_targets_md_lists_roundtrip" {
  let patterns : Array[@patterns.PatternCandidate] = [
    @patterns.make_round_trip("parse_args", "command_to_args"),
  ]
  let doc = build_pbt_document(
    "generator", "./src/generator", patterns, "String",
  )
  let md = generate_pbt_targets_md(doc)
  inspect(md.contains("## Round-Trip Targets"), content="true")
  inspect(md.contains("`parse_args` <-> `command_to_args`"), content="true")
}
