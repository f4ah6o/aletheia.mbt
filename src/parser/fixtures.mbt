///|
/// Parser test fixtures for self-application PBT
/// Provides reusable markdown fixtures for property-based testing
///

///|
/// All markdown fixtures for parser testing
/// Combined from multiple test suites:
/// - parse_markdown_generate_markdown_roundtrip fixtures
/// - extract_code_blocks_deterministic fixtures
/// - generate_markdown_preserves_structure fixtures
pub fn all_markdown_fixtures() -> Array[String] {
  [
    // From prop_parse_markdown_generate_markdown_roundtrip
    "```moonbit\nfn foo() -> Int { 1 }\n```",
    "Intro\n\n```mbt check\n test { inspect(1) }\n```\nOutro",
    "```mbt nocheck\nlet x = 1\n```\n```moonbit\nfn bar() -> Int { 2 }\n```",
    "```\nfn baz() -> Int { 3 }\n```",
    "plain text",
    // From prop_extract_code_blocks_deterministic
    "",
    "plain text without code blocks",
    "```mbt\ntest {}\n```",
    "# Heading\n\n```moonbit check\nfn foo() {}\n```\n\nMore text",
    "```python\nprint('hello')\n```\n\n```mbt nocheck\nlet x = 1\n```",
    // From prop_generate_markdown_preserves_structure
    "# Title\n\nSome text.\n\n```mbt\nfn foo() {}\n```",
    "```moonbit\nlet x = 1\n```\n\n```mbt check\ntest {}\n```",
  ]
}

///|
/// Round-trip fixtures for parse_markdown -> generate_markdown cycle
pub fn roundtrip_markdown_fixtures() -> Array[String] {
  [
    "```moonbit\nfn foo() -> Int { 1 }\n```",
    "Intro\n\n```mbt check\n test { inspect(1) }\n```\nOutro",
    "```mbt nocheck\nlet x = 1\n```\n```moonbit\nfn bar() -> Int { 2 }\n```",
    "```\nfn baz() -> Int { 3 }\n```",
    "plain text",
  ]
}

///|
/// Deterministic fixtures for extract_code_blocks testing
pub fn deterministic_markdown_fixtures() -> Array[String] {
  [
    "",
    "plain text without code blocks",
    "```mbt\ntest {}\n```",
    "# Heading\n\n```moonbit check\nfn foo() {}\n```\n\nMore text",
    "```python\nprint('hello')\n```\n\n```mbt nocheck\nlet x = 1\n```",
  ]
}

///|
/// Structure-preserving fixtures for markdown generation testing
pub fn structure_markdown_fixtures() -> Array[String] {
  [
    "# Title\n\nSome text.\n\n```mbt\nfn foo() {}\n```",
    "```moonbit\nlet x = 1\n```\n\n```mbt check\ntest {}\n```",
  ]
}
