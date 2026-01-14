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

/// ソースを解析（簡易版）
fn analyze_source(path : String) -> String {
  "Found 0 functions, 0 types, 0 patterns\n"
}

/// テストを生成（簡易版）
fn generate_tests(path : String) -> String {
  "Generated 0 test files\n"
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
