///|
test "prop_parse_markdown_generate_markdown_roundtrip" {
  let fixtures = [
    "```moonbit\nfn foo() -> Int { 1 }\n```",
    "Intro\n\n```mbt check\n test { inspect(1) }\n```\nOutro",
    "```mbt nocheck\nlet x = 1\n```\n```moonbit\nfn bar() -> Int { 2 }\n```",
    "```\nfn baz() -> Int { 3 }\n```",
    "plain text",
  ]
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
  let fixtures = [
    "",
    "plain text without code blocks",
    "```mbt\ntest {}\n```",
    "# Heading\n\n```moonbit check\nfn foo() {}\n```\n\nMore text",
    "```python\nprint('hello')\n```\n\n```mbt nocheck\nlet x = 1\n```",
  ]
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
  let fixtures = [
    "# Title\n\nSome text.\n\n```mbt\nfn foo() {}\n```",
    "```moonbit\nlet x = 1\n```\n\n```mbt check\ntest {}\n```",
  ]
  for markdown in fixtures {
    let blocks1 = @parser.extract_code_blocks(markdown)
    let ast = @parser.parse_markdown(markdown)
    let regenerated = @parser.generate_markdown(ast)
    let blocks2 = @parser.extract_code_blocks(regenerated)
    // Code block count should be preserved
    assert_eq(blocks1.length(), blocks2.length())
  }
}
