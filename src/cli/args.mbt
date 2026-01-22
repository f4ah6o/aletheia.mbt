///|
/// CLIモジュール（Phase 5）
/// コマンドラインツールmoon-pbt-genのエントリポイント
///

///|
/// コマンド種類
pub enum Command {
  Analyze(String, CommandOptions) // パスを解析
  Generate(String, CommandOptions) // テストを生成
  Sync(String, CommandOptions) // PBT markdownを同期
  Help
}

///|
/// 出力フォーマット
pub enum OutputFormat {
  Text
  Json
}

///|
/// CLIオプション
pub struct CommandOptions {
  dry_run : Bool
  explain : Bool
  format : OutputFormat
  generic_names : Array[String]
  min_cases : Int
  min_roundtrip : Int
  min_idempotent : Int
  min_pipeline : Int
  min_invariant : Int
  min_oracle : Int
}

///|
pub fn default_options() -> CommandOptions {
  {
    dry_run: false,
    explain: false,
    format: Text,
    generic_names: default_generic_names(),
    min_cases: default_min_cases(),
    min_roundtrip: default_min_roundtrip(),
    min_idempotent: default_min_idempotent(),
    min_pipeline: default_min_pipeline(),
    min_invariant: default_min_invariant(),
    min_oracle: default_min_oracle(),
  }
}

///|
fn default_generic_names() -> Array[String] {
  match read_pbt_generic_names_from_mod() {
    Some(names) => names
    None => ["src", "main", "module"]
  }
}

///|
fn is_default_generic_names(names : Array[String]) -> Bool {
  let defaults = default_generic_names()
  if names.length() != defaults.length() {
    return false
  }
  let mut i = 0
  while i < names.length() {
    if names[i] != defaults[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn default_min_cases() -> Int {
  match read_pbt_min_cases_from_mod() {
    Some(v) => v
    None => 1
  }
}

///|
fn default_min_roundtrip() -> Int {
  match read_pbt_min_roundtrip_from_mod() {
    Some(v) => v
    None => 0
  }
}

///|
fn default_min_idempotent() -> Int {
  match read_pbt_min_idempotent_from_mod() {
    Some(v) => v
    None => 0
  }
}

///|
fn default_min_pipeline() -> Int {
  match read_pbt_min_pipeline_from_mod() {
    Some(v) => v
    None => 0
  }
}

///|
fn default_min_invariant() -> Int {
  match read_pbt_min_invariant_from_mod() {
    Some(v) => v
    None => 0
  }
}

///|
fn default_min_oracle() -> Int {
  match read_pbt_min_oracle_from_mod() {
    Some(v) => v
    None => 0
  }
}

///|
/// コマンドライン引数をパース
pub fn parse_args(args : Array[String]) -> Command {
  if Array::length(args) < 2 {
    Help
  } else {
    let cmd = args[1]
    if cmd == "analyze" || cmd == "a" {
      if Array::length(args) >= 3 {
        match parse_options(args, 3) {
          Some(options) => Analyze(args[2], options)
          None => Help
        }
      } else {
        Help
      }
    } else if cmd == "generate" || cmd == "g" {
      if Array::length(args) >= 3 {
        match parse_options(args, 3) {
          Some(options) => Generate(args[2], options)
          None => Help
        }
      } else {
        Help
      }
    } else if cmd == "sync" || cmd == "s" {
      let mut path = @pbt_sync.default_pbt_markdown_path()
      let mut option_start = 2
      if Array::length(args) >= 3 && !is_flag(args[2]) {
        path = args[2]
        option_start = 3
      }
      match parse_options(args, option_start) {
        Some(options) => Sync(path, options)
        None => Help
      }
    } else {
      Help
    }
  }
}

///|
fn is_flag(arg : String) -> Bool {
  arg.has_prefix("-")
}

///|
fn parse_output_format(value : String) -> OutputFormat? {
  if value == "text" {
    Some(Text)
  } else if value == "json" {
    Some(Json)
  } else {
    None
  }
}

///|
fn parse_options(args : Array[String], start : Int) -> CommandOptions? {
  let mut options = default_options()
  let mut i = start
  while i < args.length() {
    let arg = args[i]
    if arg == "--dry-run" {
      options = {
        dry_run: true,
        explain: options.explain,
        format: options.format,
        generic_names: options.generic_names,
        min_cases: options.min_cases,
        min_roundtrip: options.min_roundtrip,
        min_idempotent: options.min_idempotent,
        min_pipeline: options.min_pipeline,
        min_invariant: options.min_invariant,
        min_oracle: options.min_oracle,
      }
      i = i + 1
    } else if arg == "--explain" {
      options = {
        dry_run: options.dry_run,
        explain: true,
        format: options.format,
        generic_names: options.generic_names,
        min_cases: options.min_cases,
        min_roundtrip: options.min_roundtrip,
        min_idempotent: options.min_idempotent,
        min_pipeline: options.min_pipeline,
        min_invariant: options.min_invariant,
        min_oracle: options.min_oracle,
      }
      i = i + 1
    } else if arg == "--format" {
      if i + 1 >= args.length() {
        return None
      }
      match parse_output_format(args[i + 1]) {
        Some(fmt) => {
          options = {
            dry_run: options.dry_run,
            explain: options.explain,
            format: fmt,
            generic_names: options.generic_names,
            min_cases: options.min_cases,
            min_roundtrip: options.min_roundtrip,
            min_idempotent: options.min_idempotent,
            min_pipeline: options.min_pipeline,
            min_invariant: options.min_invariant,
            min_oracle: options.min_oracle,
          }
          i = i + 2
        }
        None => return None
      }
    } else if arg.has_prefix("--format=") {
      let parts = arg.split("=").to_array()
      if parts.length() < 2 {
        return None
      }
      let value = parts[1].to_string()
      match parse_output_format(value) {
        Some(fmt) => {
          options = {
            dry_run: options.dry_run,
            explain: options.explain,
            format: fmt,
            generic_names: options.generic_names,
            min_cases: options.min_cases,
            min_roundtrip: options.min_roundtrip,
            min_idempotent: options.min_idempotent,
            min_pipeline: options.min_pipeline,
            min_invariant: options.min_invariant,
            min_oracle: options.min_oracle,
          }
          i = i + 1
        }
        None => return None
      }
    } else if arg == "--generic-names" {
      if i + 1 >= args.length() {
        return None
      }
      match parse_generic_names(args[i + 1]) {
        Some(names) => {
          options = {
            dry_run: options.dry_run,
            explain: options.explain,
            format: options.format,
            generic_names: names,
            min_cases: options.min_cases,
            min_roundtrip: options.min_roundtrip,
            min_idempotent: options.min_idempotent,
            min_pipeline: options.min_pipeline,
            min_invariant: options.min_invariant,
            min_oracle: options.min_oracle,
          }
          i = i + 2
        }
        None => return None
      }
    } else if arg.has_prefix("--generic-names=") {
      let parts = arg.split("=").to_array()
      if parts.length() < 2 {
        return None
      }
      let value = parts[1].to_string()
      match parse_generic_names(value) {
        Some(names) => {
          options = {
            dry_run: options.dry_run,
            explain: options.explain,
            format: options.format,
            generic_names: names,
            min_cases: options.min_cases,
            min_roundtrip: options.min_roundtrip,
            min_idempotent: options.min_idempotent,
            min_pipeline: options.min_pipeline,
            min_invariant: options.min_invariant,
            min_oracle: options.min_oracle,
          }
          i = i + 1
        }
        None => return None
      }
    } else {
      return None
    }
  }
  Some(options)
}

///|
fn append_option_args(
  args : Array[String],
  options : CommandOptions,
) -> Array[String] {
  let result : Array[String] = []
  let mut i = 0
  while i < args.length() {
    Array::push(result, args[i])
    i = i + 1
  }
  if options.dry_run {
    Array::push(result, "--dry-run")
  }
  if options.explain {
    Array::push(result, "--explain")
  }
  match options.format {
    Text => ()
    Json => {
      Array::push(result, "--format")
      Array::push(result, "json")
    }
  }
  if !is_default_generic_names(options.generic_names) {
    Array::push(result, "--generic-names")
    Array::push(result, options.generic_names.join(","))
  }
  result
}

///|
/// コマンドを引数配列に変換（Round-Trip用逆変換）
pub fn command_to_args(cmd : Command) -> Array[String] {
  match cmd {
    Analyze(path, options) =>
      append_option_args(["moon-pbt-gen", "analyze", path], options)
    Generate(path, options) =>
      append_option_args(["moon-pbt-gen", "generate", path], options)
    Sync(path, options) =>
      append_option_args(["moon-pbt-gen", "sync", path], options)
    Help => ["moon-pbt-gen", "help"]
  }
}

///|
/// ヘルプメッセージを生成
pub fn help_message() -> String {
  let lines = [
    "moon-pbt-gen - Property-Based Testing code generator", "", "Usage:", "  moon-pbt-gen <command> [arguments] [options]",
    "", "Commands:", "  analyze <path>     Analyze MoonBit package or file", "  generate <path>   Collect PBT targets into <module>.pbt.md",
    "  sync [path]       Sync PBT markdown into per-package tests", "  help              Show this help message",
    "", "Options:", "  --dry-run          Do not write files (generate/sync)", "  --explain          Output detection details",
    "  --format <text|json>  Output format (default: text)", "  --generic-names <list>  Comma-separated generic package names (default: src,main,module)",
    "  (config) moon.mod.json: pbt_generic_names, pbt_min_cases, pbt_min_roundtrip,",
    "           pbt_min_idempotent, pbt_min_pipeline, pbt_min_invariant, pbt_min_oracle",
    "", "Examples:", "  moon-pbt-gen analyze ./src --explain", "  moon-pbt-gen generate ./src --dry-run --format json",
    "  moon-pbt-gen sync",
  ]
  let mut result = ""
  let mut i = 0
  while i < Array::length(lines) {
    result = result + lines[i] + "\n"
    i = i + 1
  }
  result
}
