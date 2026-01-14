///|
/// Markdownパーサー
/// .mbt.mdファイルからコードブロックとメタデータを抽出する
///

/// Markdownコードブロック
pub struct CodeBlock {
  lang : String
  content : String
  line_start : Int
  line_end : Int
}

/// Markdown AST
pub struct MarkdownAST {
  prose : Array[String]
  code_blocks : Array[CodeBlock]
}

/// 文字列を行単位の配列に分割
fn split_lines(source : String) -> Array[String] {
  source.split("\n").map(fn(s) { s.to_string() }).to_array()
}

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
    } else {
      // コードブロック終了を検出: ```
      if line.has_prefix("```") {
        // コードブロックを完了
        let block = {
          lang: current_lang,
          content: current_content.join("\n"),
          line_start: block_start,
          line_end: line_num
        }
        Array::push(result, block)
        in_block = false
        current_lang = ""
        current_content = []
      } else {
        // コードブロック内の行を追加
        Array::push(current_content, line)
      }
    }

    line_num = line_num + 1
  }

  result
}

/// MoonBitコードブロックのみを抽出
pub fn extract_moonbit_blocks(markdown : String) -> Array[CodeBlock] {
  let all_blocks = extract_code_blocks(markdown)
  all_blocks.filter(fn(b) {
    let lang = b.lang
    lang == "moonbit" || lang == "mbt" || lang == ""
  })
}

/// テスト用コードブロックを抽出（mbt test, mbt check）
pub fn extract_test_blocks(markdown : String) -> Array[CodeBlock] {
  let all_blocks = extract_code_blocks(markdown)
  all_blocks.filter(fn(b) {
    let content = b.content
    // 内容に test が含まれるかチェック
    content.contains("test ") || content.contains("test\"") || b.lang.contains("test")
  })
}

/// MarkdownをパースしてASTを構築
pub fn parse_markdown(markdown : String) -> MarkdownAST {
  let blocks = extract_code_blocks(markdown)
  let prose_lines = split_lines(markdown).filter(fn(line) {
    let trimmed = line.trim()
    let trimmed_str = trimmed.to_string()
    // コードブロック内でない空行以外のプロセス部分
    String::length(trimmed_str) > 0 && !trimmed.has_prefix("```")
  }).map(fn(s) { s.to_string() })

  { prose: prose_lines, code_blocks: blocks }
}

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
    if String::length(trimmed_str) > 0 && !trimmed.has_prefix("//") && !trimmed.has_prefix("pub") && !trimmed.has_prefix("priv") {
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

/// テスト
test "extract_code_blocks_empty" {
  let markdown = ""
  let blocks = extract_code_blocks(markdown)
  inspect(blocks.length(), content="0")
}

test "extract_code_blocks_simple" {
  let markdown = "```moonbit\npub fn add(a : Int, b : Int) -> Int {\n  a + b\n}\n```"
  let blocks = extract_code_blocks(markdown)
  inspect(blocks.length(), content="1")
  inspect(blocks[0].lang, content="moonbit")
}

test "extract_moonbit_blocks_filters" {
  let markdown = "```moonbit\nfn foo() -> Int { 1 }\n```\n```javascript\nfunction bar() { return 2; }\n```"
  let blocks = extract_moonbit_blocks(markdown)
  inspect(blocks.length(), content="1")
}

test "parse_markdown_ast" {
  let markdown = "# Title\nSome text\n```moonbit\nfn test() -> Int { 42 }\n```"
  let ast = parse_markdown(markdown)
  inspect(ast.code_blocks.length(), content="1")
}
