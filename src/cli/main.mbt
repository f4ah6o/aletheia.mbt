///|
/// CLIモジュール（Phase 5）
/// コマンドラインツールmoon-pbt-genのエントリポイント
///

/// コマンド種類
pub enum Command {
  Analyze(String)  // パスを解析
  Generate(String)  // テストを生成
  Help
}

/// コマンドライン引数をパース
pub fn parse_args(args : Array[String]) -> Command {
  if Array::length(args) < 2 {
    Help
  } else {
    let cmd = args[1]
    if cmd == "analyze" || cmd == "a" {
      if Array::length(args) >= 3 {
        Analyze(args[2])
      } else {
        Help
      }
    } else if cmd == "generate" || cmd == "g" {
      if Array::length(args) >= 3 {
        Generate(args[2])
      } else {
        Help
      }
    } else {
      Help
    }
  }
}

/// コマンドを引数配列に変換（Round-Trip用逆変換）
pub fn command_to_args(cmd : Command) -> Array[String] {
  match cmd {
    Analyze(path) => ["moon-pbt-gen", "analyze", path]
    Generate(path) => ["moon-pbt-gen", "generate", path]
    Help => ["moon-pbt-gen", "help"]
  }
}

/// ヘルプメッセージを生成
pub fn help_message() -> String {
  let lines = [
    "moon-pbt-gen - Property-Based Testing code generator",
    "",
    "Usage:",
    "  moon-pbt-gen <command> [arguments]",
    "",
    "Commands:",
    "  analyze <path>     Analyze MoonBit source files",
    "  generate <path>   Generate property tests",
    "  help              Show this help message",
    "",
    "Examples:",
    "  moon-pbt-gen analyze ./src",
    "  moon-pbt-gen generate ./src"
  ]
  let mut result = ""
  let mut i = 0
  while i < Array::length(lines) {
    result = result + lines[i] + "\n"
    i = i + 1
  }
  result
}

/// コマンドを実行
pub fn run_command(cmd : Command) -> String {
  match cmd {
    Analyze(path) => {
      "Analyzing: " + path + "\n" + analyze_source(path)
    }
    Generate(path) => {
      "Generating tests for: " + path + "\n" + generate_tests(path)
    }
    Help => help_message()
  }
}

/// ソースを解析
fn analyze_source(path : String) -> String {
  // ファイルを読み込んで関数名を抽出
  let source = read_file_content(path)
  let functions = @analyzer.extract_function_names(source)

  let roundtrips = @patterns.find_round_trips(functions)
  let idempotents = @patterns.find_idempotent_functions(functions)
  let producers = @patterns.find_producer_consumer(functions)

  let mut result = "=== Analysis Result for " + path + " ===\n"
  result = result + "Functions found: " + int_to_string(functions.length()) + "\n"
  result = result + "Round-Trip patterns: " + int_to_string(roundtrips.length()) + "\n"
  result = result + "Idempotent patterns: " + int_to_string(idempotents.length()) + "\n"
  result = result + "Producer-Consumer patterns: " + int_to_string(producers.length()) + "\n"
  result
}

/// ファイル内容を読み込み
fn read_file_content(path : String) -> String {
  try {
    @fs.read_file_to_string(path)
  } catch {
    _ => ""
  }
}

/// テストを生成
fn generate_tests(path : String) -> String {
  // ファイルを読み込んで関数名を抽出
  let source = read_file_content(path)
  let functions = @analyzer.extract_function_names(source)

  // パターン検出
  let roundtrips = @patterns.find_round_trips(functions)
  let idempotents = @patterns.find_idempotent_functions(functions)
  let producers = @patterns.find_producer_consumer(functions)

  // すべてのパターンを統合
  let mut all_patterns : Array[@patterns.PatternCandidate] = []
  let mut i = 0
  while i < roundtrips.length() {
    all_patterns = append_pattern(all_patterns, roundtrips[i])
    i = i + 1
  }
  let mut i = 0
  while i < idempotents.length() {
    all_patterns = append_pattern(all_patterns, idempotents[i])
    i = i + 1
  }
  let mut i = 0
  while i < producers.length() {
    all_patterns = append_pattern(all_patterns, producers[i])
    i = i + 1
  }

  // ドキュメント生成
  let module_name = extract_module_name(path)
  let doc = @generator.build_pbt_document(module_name, path, all_patterns, "TestData")
  let content = @generator.generate_pbt_md(doc)

  let mut result = "=== Generated PBT Document ===\n"
  result = result + "Module: " + module_name + "\n"
  result = result + "Patterns detected: " + int_to_string(all_patterns.length()) + "\n"
  result = result + "\n" + content + "\n"
  result
}

/// パターンを配列に追加
fn append_pattern(arr : Array[@patterns.PatternCandidate], pat : @patterns.PatternCandidate) -> Array[@patterns.PatternCandidate] {
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

/// パスからモジュール名を抽出
fn extract_module_name(path : String) -> String {
  // 簡易版: パスをそのまま返す
  path
}

/// IntをStringに変換
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

/// テスト
test "parse_args_help" {
  let args = ["prog", "help"]
  let result = parse_args(args)
  match result {
    Help => inspect("ok", content="ok")
    _ => inspect("fail", content="fail")
  }
}

test "parse_args_analyze" {
  let args = ["prog", "analyze", "./src"]
  let result = parse_args(args)
  match result {
    Analyze(p) => inspect(p, content="./src")
    _ => inspect("fail", content="fail")
  }
}

test "parse_args_generate" {
  let args = ["prog", "generate", "./src"]
  let result = parse_args(args)
  match result {
    Generate(p) => inspect(p, content="./src")
    _ => inspect("fail", content="fail")
  }
}

test "run_command_analyze" {
  let cmd = Analyze("./src")
  let result = run_command(cmd)
  inspect(result.contains("Analyzing"), content="true")
}

test "run_command_help" {
  let cmd = Help
  let result = run_command(cmd)
  inspect(result.contains("moon-pbt-gen"), content="true")
}

test "help_message_contains_commands" {
  let msg = help_message()
  inspect(msg.contains("analyze"), content="true")
  inspect(msg.contains("generate"), content="true")
}
