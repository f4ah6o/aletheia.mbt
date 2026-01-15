///|
/// Markdownパーサー
/// .mbt.mdファイルからコードブロックとメタデータを抽出する
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
/// Markdown AST
pub struct MarkdownAST {
  prose : Array[String]
  code_blocks : Array[CodeBlock]
}

///|
/// 文字列を行単位の配列に分割
fn split_lines(source : String) -> Array[String] {
  source.split("\n").map(fn(s) { s.to_string() }).to_array()
}

///|
/// Markdownからコードブロックを抽出
pub fn extract_code_blocks(markdown : String) -> Array[CodeBlock] {
  let lines = split_lines(markdown)
  let mut in_block = false
  let mut current_lang = ""
  let mut current_content : Array[String] = []
  let mut block_start = 0
  let result : Array[CodeBlock] = []
  let mut line_num = 0
  let n = Array::length(lines)
  while line_num < n {
    let line = lines[line_num]
    if !in_block {
      // コードブロック開始を検出: ```lang
      if line.has_prefix("```") {
        in_block = true
        block_start = line_num
        // 言語を抽出: ```moonbit -> moonbit
        let lang_part = line.split("```").to_array()
        current_lang = if Array::length(lang_part) > 1 {
          lang_part[1].trim().to_string()
        } else {
          ""
        }
        current_content = []
      } else {
        ()
      }
      // コードブロック終了を検出: ```
    } else if line.has_prefix("```") {
      // コードブロックを完了
      let block = {
        lang: current_lang,
        content: current_content.join("\n"),
        line_start: block_start,
        line_end: line_num,
      }
      Array::push(result, block)
      in_block = false
      current_lang = ""
      current_content = []
    } else {
      // コードブロック内の行を追加
      Array::push(current_content, line)
    }
    line_num = line_num + 1
  }
  result
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
  let blocks = extract_code_blocks(markdown)
  let prose_lines = split_lines(markdown)
    .filter(fn(line) {
      let trimmed = line.trim()
      let trimmed_str = trimmed.to_string()
      // コードブロック内でない空行以外のプロセス部分
      String::length(trimmed_str) > 0 && !trimmed.has_prefix("```")
    })
    .map(fn(s) { s.to_string() })
  { prose: prose_lines, code_blocks: blocks }
}

///|
/// MarkdownASTからMarkdown文字列を生成（Round-Trip用逆変換）
pub fn generate_markdown(ast : MarkdownAST) -> String {
  let result : Array[String] = []

  // proseとcode_blocksを組み合わせて再構築
  let mut i = 0
  while i < Array::length(ast.prose) {
    Array::push(result, ast.prose[i])
    i = i + 1
  }
  let mut j = 0
  while j < Array::length(ast.code_blocks) {
    let block = ast.code_blocks[j]
    let lang_tag = if block.lang == "" { "```" } else { "```" + block.lang }
    Array::push(result, lang_tag)
    Array::push(result, block.content)
    Array::push(result, "```")
    j = j + 1
  }
  result.join("\n")
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
  let n = Array::length(lines)
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
  inspect(ast.code_blocks.length(), content="1")
}
