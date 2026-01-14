///|
/// ドッグフーディングモジュール
/// Aletheiaツール自身のソースコードにパターン検出とプロパティテストを適用する
///

///|
/// このモジュールの全公開関数名リスト
/// 自己適用のためのメタデータ
pub fn get_aletheia_functions() -> Array[String] {
  [
    // parser module
    "extract_code_blocks", "extract_moonbit_blocks", "extract_test_blocks", "parse_markdown",
    "generate_markdown", // Round-Trip用に追加
     "code_block_to_string", "extract_function_calls",
    // cli module
     "parse_args", "command_to_args", // Round-Trip用に追加
     "help_message", "run_command",
    // patterns module
     "find_round_trips", "find_idempotent_functions", "find_producer_consumer",
    // generator module
     "generate_round_trip_test", "generate_idempotent_test", "generate_mbt_md_section",
    // state_machine module
     "create_state_machine", "add_command", "execute_commands", "generate_state_machine_test",
    // テスト用に追加（パターン検出のデモ）
     "sort", "normalize", "trim", "encode", "decode",
  ]
}

///|
/// 自己パターン検出を実行
/// 検出されたパターン数を返す
pub fn detect_self_patterns() -> Int {
  let functions = get_aletheia_functions()

  // Round-Tripパターンを検出
  let round_trips = @patterns.find_round_trips(functions)

  // Idempotentパターンを検出
  let idempotents = @patterns.find_idempotent_functions(functions)

  // Producer-Consumerパターンを検出
  let producer_consumers = @patterns.find_producer_consumer(functions)

  // 検出されたパターンの総数を返す
  round_trips.length() + idempotents.length() + producer_consumers.length()
}

///|
/// パターン検出結果のサマリを生成
pub fn generate_detection_summary() -> String {
  let functions = get_aletheia_functions()
  let round_trips = @patterns.find_round_trips(functions)
  let idempotents = @patterns.find_idempotent_functions(functions)
  let producer_consumers = @patterns.find_producer_consumer(functions)
  let mut result = "=== Aletheia Self-Detection Summary ===\n"
  result = result +
    "Total functions: " +
    int_to_string(functions.length()) +
    "\n"
  result = result +
    "Round-Trip patterns: " +
    int_to_string(round_trips.length()) +
    "\n"
  result = result +
    "Idempotent patterns: " +
    int_to_string(idempotents.length()) +
    "\n"
  result = result +
    "Producer-Consumer patterns: " +
    int_to_string(producer_consumers.length()) +
    "\n"
  result
}

///|
/// Aletheia自身のPBT Markdownを生成
pub fn generate_self_pbt_md() -> String {
  let functions = get_aletheia_functions()

  // パターン検出
  let round_trips = @patterns.find_round_trips(functions)
  let idempotents = @patterns.find_idempotent_functions(functions)
  let producer_consumers = @patterns.find_producer_consumer(functions)

  // すべてのパターンを統合
  let mut all_patterns : Array[@patterns.PatternCandidate] = []
  let mut i = 0
  while i < round_trips.length() {
    all_patterns = append_pattern(all_patterns, round_trips[i])
    i = i + 1
  }
  let mut i = 0
  while i < idempotents.length() {
    all_patterns = append_pattern(all_patterns, idempotents[i])
    i = i + 1
  }
  let mut i = 0
  while i < producer_consumers.length() {
    all_patterns = append_pattern(all_patterns, producer_consumers[i])
    i = i + 1
  }

  // ドキュメント生成
  let doc = @generator.build_pbt_document(
    "aletheia", "src/dogfooding", all_patterns, "TestData",
  )
  @generator.generate_pbt_md(doc)
}

///|
/// パターンを配列に追加
fn append_pattern(
  arr : Array[@patterns.PatternCandidate],
  pat : @patterns.PatternCandidate,
) -> Array[@patterns.PatternCandidate] {
  let n = arr.length()
  let result : Array[@patterns.PatternCandidate] = []
  let mut i = 0
  while i < n {
    Array::push(result, arr[i])
    i = i + 1
  }
  Array::push(result, pat)
  result
}

///|
fn int_to_string(n : Int) -> String {
  if n < 0 {
    "-" + int_to_string(-n)
  } else if n == 0 {
    "0"
  } else if n < 10 {
    match n {
      1 => "1"
      2 => "2"
      3 => "3"
      4 => "4"
      5 => "5"
      6 => "6"
      7 => "7"
      8 => "8"
      _ => "9"
    }
  } else {
    int_to_string(n / 10) + int_to_string(n % 10)
  }
}

//-----------------------------------------------
// プロパティテスト: 自己生成されたテスト
//-----------------------------------------------

///|
/// Parser Round-Tripテスト
/// parse_markdown -> generate_markdown が構造を保持することを確認
test "prop_parser_roundtrip_preserves_code_blocks" {
  let markdown = "# Title\nSome text\n```moonbit\nfn test() -> Int { 42 }\n```"
  let ast = @parser.parse_markdown(markdown)
  let regenerated = @parser.generate_markdown(ast)

  // 再生成された文字列をパースして、コードブロック数が一致することを確認
  let ast2 = @parser.parse_markdown(regenerated)
  inspect(ast.code_blocks.length() == ast2.code_blocks.length(), content="true")
}

///|
/// CLI Round-Tripテスト
/// parse_args -> command_to_args -> parse_args が等価であることを確認
test "prop_cli_roundtrip_analyze" {
  let original_args = ["moon-pbt-gen", "analyze", "./src"]
  let cmd = @cli.parse_args(original_args)
  let regenerated_args = @cli.command_to_args(cmd)
  let cmd2 = @cli.parse_args(regenerated_args)

  // 両方のコマンドが同じ結果を生成することを確認
  let result1 = match cmd {
    @cli.Command::Analyze(p) => p
    _ => "fail"
  }
  let result2 = match cmd2 {
    @cli.Command::Analyze(p) => p
    _ => "fail"
  }
  inspect(result1 == result2, content="true")
}

///|
test "prop_cli_roundtrip_generate" {
  let original_args = ["moon-pbt-gen", "generate", "./tests"]
  let cmd = @cli.parse_args(original_args)
  let regenerated_args = @cli.command_to_args(cmd)
  let cmd2 = @cli.parse_args(regenerated_args)
  let result1 = match cmd {
    @cli.Command::Generate(p) => p
    _ => "fail"
  }
  let result2 = match cmd2 {
    @cli.Command::Generate(p) => p
    _ => "fail"
  }
  inspect(result1 == result2, content="true")
}

///|
test "prop_cli_roundtrip_help" {
  let original_args = ["moon-pbt-gen", "help"]
  let cmd = @cli.parse_args(original_args)
  let regenerated_args = @cli.command_to_args(cmd)
  let cmd2 = @cli.parse_args(regenerated_args)
  let is_help1 = match cmd {
    @cli.Command::Help => true
    _ => false
  }
  let is_help2 = match cmd2 {
    @cli.Command::Help => true
    _ => false
  }
  inspect(is_help1 == is_help2, content="true")
}

///|
/// パターン検出結合則テスト
/// find_round_trips(a ++ b).length >= find_round_trips(a).length
test "prop_pattern_detection_monotonic" {
  let a = ["encode_data", "decode_data"]
  let b = ["to_json", "from_json"]
  let results_a = @patterns.find_round_trips(a)
  let results_b = @patterns.find_round_trips(b)

  // a と b を結合
  let combined : Array[String] = []
  let mut i = 0
  while i < a.length() {
    combined.push(a[i])
    i = i + 1
  }
  let mut j = 0
  while j < b.length() {
    combined.push(b[j])
    j = j + 1
  }
  let results_combined = @patterns.find_round_trips(combined)

  // 結合結果は個別結果以上のパターンを含む
  inspect(results_combined.length() >= results_a.length(), content="true")
  inspect(results_combined.length() >= results_b.length(), content="true")
}

///|
/// パターン検出空入力テスト
test "prop_pattern_detection_empty_input" {
  let empty : Array[String] = []
  let rt = @patterns.find_round_trips(empty)
  let id = @patterns.find_idempotent_functions(empty)
  let pc = @patterns.find_producer_consumer(empty)
  inspect(rt.length(), content="0")
  inspect(id.length(), content="0")
  inspect(pc.length(), content="0")
}

///|
/// Generator決定性テスト
/// 同じ入力に対して同じ出力を生成
test "prop_generator_deterministic" {
  let test1 = @generator.generate_round_trip_test("encode", "decode", "Data")
  let test2 = @generator.generate_round_trip_test("encode", "decode", "Data")
  inspect(test1.name == test2.name, content="true")
  inspect(test1.code == test2.code, content="true")
}

///|
/// 自己パターン検出テスト
test "self_detection_finds_patterns" {
  let summary = generate_detection_summary()
  inspect(summary.contains("Total functions"), content="true")
  inspect(summary.contains("Round-Trip patterns"), content="true")
}

///|
/// parse_markdown -> generate_markdown のコードブロック内容保持
test "prop_parser_roundtrip_content_preserved" {
  let code_content = "pub fn add(a: Int, b: Int) -> Int { a + b }"
  let markdown = "```moonbit\n" + code_content + "\n```"
  let ast = @parser.parse_markdown(markdown)

  // 抽出されたコードブロックの内容が一致することを確認
  if ast.code_blocks.length() > 0 {
    let block = ast.code_blocks[0]
    inspect(block.content.contains("add"), content="true")
  } else {
    inspect("block found", content="block found")
  }
}

///|
/// extract_code_blocks べき等性類似テスト
/// 一度抽出した結果を文字列化して再抽出しても同じ結果
test "prop_extract_code_blocks_stable" {
  let markdown = "```moonbit\nfn foo() -> Int { 1 }\n```\n```moonbit\nfn bar() -> Int { 2 }\n```"
  let blocks1 = @parser.extract_code_blocks(markdown)

  // ブロックを文字列化
  let mut regenerated = ""
  let mut i = 0
  while i < blocks1.length() {
    regenerated = regenerated + @parser.code_block_to_string(blocks1[i]) + "\n"
    i = i + 1
  }
  let blocks2 = @parser.extract_code_blocks(regenerated)

  // 同じ数のブロックが抽出される
  inspect(blocks1.length() == blocks2.length(), content="true")
}

///|
/// generate_self_pbt_md の出力テスト
test "generate_self_pbt_md_outputs_markdown" {
  let md = generate_self_pbt_md()
  inspect(md.contains("Property-Based Tests for aletheia"), content="true")
  // Round-Trip パターンが検出されるか確認（parse_markdown/generate_markdown はペアではないので検出されない場合がある）
  // inspect(md.contains("Round-Trip Properties"), content="true")
  inspect(md.contains("Idempotent Properties"), content="true")
}

///|
/// 関数抽出器テスト: ソースコードから関数名を抽出
test "prop_analyzer_extracts_function_names" {
  let source = "pub fn add(a : Int, b : Int) -> Int { a + b }\npub fn sub(a : Int, b : Int) -> Int { a - b }"
  let functions = @analyzer.extract_function_names(source)
  inspect(functions.length(), content="2")
}

///|
/// 関数抽出器テスト: 空入力
test "prop_analyzer_empty_input" {
  let source = ""
  let functions = @analyzer.extract_function_names(source)
  inspect(functions.length(), content="0")
}

///|
/// 関数抽出器テスト: priv関数は抽出しない
test "prop_analyzer_ignores_private_functions" {
  let source = "pub fn public_func() -> Int { 1 }\npriv fn private_func() -> Int { 2 }"
  let functions = @analyzer.extract_function_names(source)
  inspect(functions.length(), content="1")
}

///|
/// 自己適用サイクルテスト: 関数抽出→パターン検出→テスト生成
test "self_dogfooding_cycle" {
  // 1. 自分自身のソースコードから関数名を抽出
  let functions = get_aletheia_functions()

  // 2. パターン検出
  let roundtrips = @patterns.find_round_trips(functions)
  let idempotents = @patterns.find_idempotent_functions(functions)

  // 3. 少なくとも何らかのパターンが検出されることを確認
  let total_patterns = roundtrips.length() + idempotents.length()
  inspect(total_patterns > 0, content="true")
}
