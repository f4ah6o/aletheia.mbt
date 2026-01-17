///|
test "prop_parse_markdown_generate_markdown_roundtrip" {
  let fixtures = @parser.roundtrip_markdown_fixtures()
  for markdown in fixtures {
    let blocks1 = extract_code_blocks(markdown)
    let ast = parse_markdown(markdown)
    let regenerated = generate_markdown(ast)
    let blocks2 = extract_code_blocks(regenerated)
    assert_eq(blocks1.length(), blocks2.length())
    let mut i = 0
    while i < blocks1.length() {
      let block1 = blocks1[i]
      let block2 = blocks2[i]
      assert_eq(block1.lang, block2.lang)
      assert_eq(block1.content, block2.content)
      i = i + 1
    }
  }
}

///|
test "prop_extract_code_blocks_deterministic" {
  let fixtures = @parser.deterministic_markdown_fixtures()
  for markdown in fixtures {
    let blocks1 = extract_code_blocks(markdown)
    let blocks2 = extract_code_blocks(markdown)
    assert_eq(blocks1.length(), blocks2.length())
    let mut i = 0
    while i < blocks1.length() {
      assert_eq(blocks1[i].lang, blocks2[i].lang)
      assert_eq(blocks1[i].content, blocks2[i].content)
      i = i + 1
    }
  }
}

///|
test "prop_generate_markdown_preserves_structure" {
  let fixtures = @parser.structure_markdown_fixtures()
  for markdown in fixtures {
    let blocks1 = @parser.extract_code_blocks(markdown)
    let ast = @parser.parse_markdown(markdown)
    let regenerated = @parser.generate_markdown(ast)
    let blocks2 = @parser.extract_code_blocks(regenerated)
    // Code block count should be preserved
    assert_eq(blocks1.length(), blocks2.length())
  }
}
