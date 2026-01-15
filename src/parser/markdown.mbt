///|
/// Markdownパーサー
/// .mbt.mdファイルからコードブロックとメタデータを抽出する
/// mizchi/markdown.mbt を使用
///

///|
/// Markdownコードブロック
pub struct CodeBlock {
  lang : String
  content : String
  line_start : Int
  line_end : Int
}

///|
/// Markdown AST（mizchi/markdownのDocumentのラッパー）
pub struct MarkdownAST {
  document : @markdown.Document
}

///|
/// Blockノードからコードブロックを抽出
fn extract_fenced_code(block : @markdown.Block, line_offset : Int) -> Array[CodeBlock] {
  match block {
    @markdown.Block::FencedCode(info~, code~, ..) => {
      // 行番号を計算（簡易的にオフセットから推定）
      let line_start = line_offset
      let line_end = line_offset + code.split("\n").to_array().length()
      [{
        lang: info,
        content: code,
        line_start,
        line_end,
      }]
    }
    @markdown.Block::Blockquote(children~, ..) =>
      extract_code_blocks_from_array(children, line_offset)
    @markdown.Block::BulletList(items~, ..) =>
      extract_code_from_list_items(items, line_offset)
    @markdown.Block::OrderedList(items~, ..) =>
      extract_code_from_list_items(items, line_offset)
    @markdown.Block::Table(..) =>
      [] // テーブルはスキップ
    @markdown.Block::IndentedCode(code~, ..) => {
      // インデントされたコードブロックも抽出
      let line_start = line_offset
      let line_end = line_offset + code.split("\n").to_array().length()
      [{
        lang: "",
        content: code,
        line_start,
        line_end,
      }]
    }
    _ => []
  }
}

///|
/// ListItemからコードブロックを抽出
fn extract_code_from_list_items(
  items : Array[@markdown.ListItem],
  line_offset : Int,
) -> Array[CodeBlock] {
  let result : Array[CodeBlock] = []
  let mut offset = line_offset
  let mut i = 0
  while i < items.length() {
    let item = items[i]
    let blocks = extract_code_blocks_from_array(item.children, offset)
    let mut j = 0
    while j < blocks.length() {
      Array::push(result, blocks[j])
      j = j + 1
    }
    offset = offset + 1
    i = i + 1
  }
  result
}

///|
/// Block配列からコードブロックを再帰的に抽出
fn extract_code_blocks_from_array(
  blocks : Array[@markdown.Block],
  line_offset : Int,
) -> Array[CodeBlock] {
  let result : Array[CodeBlock] = []
  let mut offset = line_offset
  let mut i = 0
  while i < blocks.length() {
    let blocks_from_block = extract_fenced_code(blocks[i], offset)
    let mut j = 0
    while j < blocks_from_block.length() {
      Array::push(result, blocks_from_block[j])
      j = j + 1
    }
    offset = offset + 1
    i = i + 1
  }
  result
}

///|
/// Markdownからコードブロックを抽出
pub fn extract_code_blocks(markdown : String) -> Array[CodeBlock] {
  let result = @markdown.parse(markdown)
  extract_code_blocks_from_array(result.document.children, 1)
}

///|
/// MoonBitコードブロックのみを抽出
pub fn extract_moonbit_blocks(markdown : String) -> Array[CodeBlock] {
  let all_blocks = extract_code_blocks(markdown)
  all_blocks.filter(fn(b) { is_moonbit_lang(b.lang) })
}

///|
/// テスト用コードブロックを抽出（mbt test, mbt check）
pub fn extract_test_blocks(markdown : String) -> Array[CodeBlock] {
  let all_blocks = extract_code_blocks(markdown)
  all_blocks.filter(fn(b) {
    let content = b.content
    // 内容に test が含まれるかチェック
    content.contains("test ") ||
    content.contains("test\"") ||
    is_test_lang(b.lang)
  })
}

///|
/// MoonBit系の言語タグかどうか判定
fn is_moonbit_lang(lang : String) -> Bool {
  let trimmed = lang.trim().to_string()
  trimmed == "" ||
  trimmed == "moonbit" ||
  trimmed == "mbt" ||
  trimmed.has_prefix("moonbit ") ||
  trimmed.has_prefix("mbt ")
}

///|
/// テスト実行対象の言語タグかどうか判定
fn is_test_lang(lang : String) -> Bool {
  let trimmed = lang.trim().to_string()
  trimmed.contains("test") || trimmed.contains("check")
}

///|
/// MarkdownをパースしてASTを構築
pub fn parse_markdown(markdown : String) -> MarkdownAST {
  let result = @markdown.parse(markdown)
  { document: result.document }
}

///|
/// MarkdownASTからMarkdown文字列を生成（Round-Trip用逆変換）
pub fn generate_markdown(ast : MarkdownAST) -> String {
  @markdown.serialize(ast.document)
}

///|
/// CodeBlockを文字列に変換
pub fn code_block_to_string(block : CodeBlock) -> String {
  let lang_tag = if block.lang == "" { "```" } else { "```" + block.lang }
  lang_tag + "\n" + block.content + "\n```"
}

///|
/// コードブロックから関数呼び出しを抽出（簡易版）
pub fn extract_function_calls(block : CodeBlock) -> Array[String] {
  let content = block.content
  let result : Array[String] = []

  // 簡単な正規表現風のマッチング
  let lines = split_lines(content)
  let mut i = 0
  let n = lines.length()
  while i < n {
    let line = lines[i]
    // 関数呼び出しパターンを検出
    let trimmed = line.trim()
    let trimmed_str = trimmed.to_string()
    if String::length(trimmed_str) > 0 &&
      !trimmed.has_prefix("//") &&
      !trimmed.has_prefix("pub") &&
      !trimmed.has_prefix("priv") {
      // 括弧を含む行を関数呼び出しの候補とする
      if line.contains("(") && line.contains(")") {
        // シンプルな実装: 行全体を追加
        Array::push(result, line)
      } else {
        ()
      }
    } else {
      ()
    }
    i = i + 1
  }
  result
}

///|
/// 文字列を行単位の配列に分割
fn split_lines(source : String) -> Array[String] {
  source.split("\n").map(fn(s) { s.to_string() }).to_array()
}

///|
/// テスト
test "extract_code_blocks_empty" {
  let markdown = ""
  let blocks = extract_code_blocks(markdown)
  inspect(blocks.length(), content="0")
}

///|
test "extract_code_blocks_simple" {
  let markdown = "```moonbit\npub fn add(a : Int, b : Int) -> Int {\n  a + b\n}\n```"
  let blocks = extract_code_blocks(markdown)
  inspect(blocks.length(), content="1")
  inspect(blocks[0].lang, content="moonbit")
}

///|
test "extract_moonbit_blocks_filters" {
  let markdown = "```moonbit\nfn foo() -> Int { 1 }\n```\n```mbt check\nfn bar() -> Int { 2 }\n```\n```javascript\nfunction baz() { return 3; }\n```"
  let blocks = extract_moonbit_blocks(markdown)
  inspect(blocks.length(), content="2")
}

///|
test "extract_test_blocks_accepts_check_lang" {
  let markdown = "```mbt check\nlet x = 1\n```"
  let blocks = extract_test_blocks(markdown)
  inspect(blocks.length(), content="1")
}

///|
test "parse_markdown_ast" {
  let markdown = "# Title\nSome text\n```moonbit\nfn test() -> Int { 42 }\n```"
  let ast = parse_markdown(markdown)
  inspect(ast.document.children.length(), content="3")
}
