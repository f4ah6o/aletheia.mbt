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
}

///|
pub fn default_options() -> CommandOptions {
  { dry_run: false, explain: false, format: Text }
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
      }
      i = i + 1
    } else if arg == "--explain" {
      options = {
        dry_run: options.dry_run,
        explain: true,
        format: options.format,
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
    "", "Commands:", "  analyze <path>     Analyze MoonBit package or file", "  generate <path>   Collect PBT targets into <module>.pbt.mbt.md",
    "  sync [path]       Sync PBT markdown into per-package tests", "  help              Show this help message",
    "", "Options:", "  --dry-run          Do not write files (generate/sync)", "  --explain          Output detection details",
    "  --format <text|json>  Output format (default: text)", "", "Examples:", "  moon-pbt-gen analyze ./src --explain",
    "  moon-pbt-gen generate ./src --dry-run --format json", "  moon-pbt-gen sync",
  ]
  let mut result = ""
  let mut i = 0
  while i < Array::length(lines) {
    result = result + lines[i] + "\n"
    i = i + 1
  }
  result
}

///|
/// コマンドを実行
pub fn run_command(cmd : Command) -> String {
  match cmd {
    Analyze(path, options) => run_analyze(path, options)
    Generate(path, options) => run_generate(path, options)
    Sync(path, options) => run_sync(path, options)
    Help => help_message()
  }
}

///|
fn run_analyze(path : String, options : CommandOptions) -> String {
  let packages = analyze_packages(path)
  match options.format {
    Text =>
      "Analyzing: " +
      path +
      "\n" +
      format_analysis_text(path, packages, options.explain)
    Json => format_analysis_json(path, packages, options.explain)
  }
}

///|
fn run_generate(path : String, options : CommandOptions) -> String {
  let prefix = "Collecting PBT targets for: " + path + "\n"
  match build_generate_report(path, options) {
    Err(msg) =>
      match options.format {
        Text => prefix + "No MoonBit package found under: " + path + "\n"
        Json =>
          json_object([
            ("ok", json_bool(false)),
            ("command", json_string("generate")),
            ("path", json_string(path)),
            ("error", json_string(msg)),
          ])
      }
    Ok(report) =>
      match options.format {
        Text => prefix + format_generate_text(report, options.explain)
        Json => format_generate_json(report, options.explain)
      }
  }
}

///|
fn run_sync(path : String, options : CommandOptions) -> String {
  match options.format {
    Text =>
      "Syncing PBT markdown: " +
      path +
      "\n" +
      format_sync_text(path, options.dry_run)
    Json => format_sync_json(path, options.dry_run)
  }
}

///|
fn json_object(pairs : Array[(String, String)]) -> String {
  let mut result = "{"
  let mut i = 0
  while i < pairs.length() {
    if i > 0 {
      result = result + ","
    }
    result = result + json_string(pairs[i].0) + ":" + pairs[i].1
    i = i + 1
  }
  result + "}"
}

///|
fn json_array(values : Array[String]) -> String {
  let mut result = "["
  let mut i = 0
  while i < values.length() {
    if i > 0 {
      result = result + ","
    }
    result = result + values[i]
    i = i + 1
  }
  result + "]"
}

///|
fn json_string(value : String) -> String {
  "\"" + json_escape(value) + "\""
}

///|
fn json_bool(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn json_number(value : Int) -> String {
  int_to_string(value)
}

///|
fn json_escape(value : String) -> String {
  let chars = value.to_array()
  let mut result = ""
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    match c {
      '"' => result = result + "\\\""
      '\\' => result = result + "\\\\"
      '\n' => result = result + "\\n"
      '\r' => result = result + "\\r"
      '\t' => result = result + "\\t"
      '\b' => result = result + "\\b"
      '\f' => result = result + "\\f"
      _ =>
        if c.to_int() < 0x20 {
          result = result + "\\u00" + byte_to_hex(c.to_int())
        } else {
          result = result + c.to_string()
        }
    }
    i = i + 1
  }
  result
}

///|
fn byte_to_hex(value : Int) -> String {
  hex_digit(value / 16) + hex_digit(value % 16)
}

///|
fn hex_digit(value : Int) -> String {
  match value {
    0 => "0"
    1 => "1"
    2 => "2"
    3 => "3"
    4 => "4"
    5 => "5"
    6 => "6"
    7 => "7"
    8 => "8"
    9 => "9"
    10 => "a"
    11 => "b"
    12 => "c"
    13 => "d"
    14 => "e"
    _ => "f"
  }
}

///|
/// ソースを解析
fn analyze_packages(path : String) -> Array[PackageAnalysis] {
  let package_dirs = resolve_package_dirs(path)
  let results : Array[PackageAnalysis] = []
  let mut i = 0
  while i < package_dirs.length() {
    let package_dir = package_dirs[i]
    let functions = collect_functions_from_package(package_dir)
    let function_names = function_names_from_meta(functions)
    let roundtrips = @patterns.find_round_trips(function_names)
    let idempotents = @patterns.find_idempotent_functions(function_names)
    let producers = @patterns.find_producer_consumer(function_names)
    let invariants = @patterns.find_invariant_functions(function_names)
    let oracles = @patterns.find_oracle_candidates(function_names)
    Array::push(results, {
      path: package_dir,
      functions,
      roundtrips,
      idempotents,
      producers,
      invariants,
      oracles,
    })
    i = i + 1
  }
  results
}

///|
priv struct PackageAnalysis {
  path : String
  functions : Array[@ast.FunctionMeta]
  roundtrips : Array[@patterns.PatternCandidate]
  idempotents : Array[@patterns.PatternCandidate]
  producers : Array[@patterns.PatternCandidate]
  invariants : Array[@patterns.PatternCandidate]
  oracles : Array[@patterns.PatternCandidate]
}

///|
fn describe_function_name(
  functions : Array[@ast.FunctionMeta],
  name : String,
) -> String {
  match find_function_meta(functions, name) {
    Some(meta) => name + " " + meta.signature()
    None => name
  }
}

///|
fn function_signature_or_empty(
  functions : Array[@ast.FunctionMeta],
  name : String,
) -> String {
  match find_function_meta(functions, name) {
    Some(meta) => meta.signature()
    None => ""
  }
}

///|
fn describe_pattern(
  functions : Array[@ast.FunctionMeta],
  pattern : @patterns.PatternCandidate,
) -> String {
  match pattern {
    @patterns.RoundTrip(encoder, decoder) =>
      "RoundTrip: " +
      describe_function_name(functions, encoder) +
      " <-> " +
      describe_function_name(functions, decoder)
    @patterns.Idempotent(name) =>
      "Idempotent: " + describe_function_name(functions, name)
    @patterns.ProducerConsumer(producer, consumer) =>
      "ProducerConsumer: " +
      describe_function_name(functions, producer) +
      " -> " +
      describe_function_name(functions, consumer)
    @patterns.Invariant(func, inv_type) =>
      "Invariant: " +
      describe_function_name(functions, func) +
      " (" +
      inv_type +
      ")"
    @patterns.Oracle(implementation, oracle) =>
      "Oracle: " +
      describe_function_name(functions, implementation) +
      " vs " +
      describe_function_name(functions, oracle)
  }
}

///|
fn pattern_to_json(
  functions : Array[@ast.FunctionMeta],
  pattern : @patterns.PatternCandidate,
) -> String {
  match pattern {
    @patterns.RoundTrip(encoder, decoder) =>
      json_object([
        ("kind", json_string("round_trip")),
        ("encoder", json_string(encoder)),
        ("decoder", json_string(decoder)),
        (
          "encoder_signature",
          json_string(function_signature_or_empty(functions, encoder)),
        ),
        (
          "decoder_signature",
          json_string(function_signature_or_empty(functions, decoder)),
        ),
      ])
    @patterns.Idempotent(name) =>
      json_object([
        ("kind", json_string("idempotent")),
        ("name", json_string(name)),
        ("signature", json_string(function_signature_or_empty(functions, name))),
      ])
    @patterns.ProducerConsumer(producer, consumer) =>
      json_object([
        ("kind", json_string("producer_consumer")),
        ("producer", json_string(producer)),
        ("consumer", json_string(consumer)),
        (
          "producer_signature",
          json_string(function_signature_or_empty(functions, producer)),
        ),
        (
          "consumer_signature",
          json_string(function_signature_or_empty(functions, consumer)),
        ),
      ])
    @patterns.Invariant(func, inv_type) =>
      json_object([
        ("kind", json_string("invariant")),
        ("function", json_string(func)),
        ("invariant_type", json_string(inv_type)),
        ("signature", json_string(function_signature_or_empty(functions, func))),
      ])
    @patterns.Oracle(implementation, oracle) =>
      json_object([
        ("kind", json_string("oracle")),
        ("implementation", json_string(implementation)),
        ("oracle", json_string(oracle)),
        (
          "implementation_signature",
          json_string(function_signature_or_empty(functions, implementation)),
        ),
        (
          "oracle_signature",
          json_string(function_signature_or_empty(functions, oracle)),
        ),
      ])
  }
}

///|
fn format_analysis_text(
  path : String,
  packages : Array[PackageAnalysis],
  explain : Bool,
) -> String {
  if packages.length() == 0 {
    return "No MoonBit package found under: " + path + "\n"
  }
  let mut result = ""
  let mut i = 0
  while i < packages.length() {
    let pkg = packages[i]
    let function_names = function_names_from_meta(pkg.functions)
    if i > 0 {
      result = result + "\n"
    }
    result = result + "=== Analysis Result for " + pkg.path + " ===\n"
    result = result +
      "Functions found: " +
      int_to_string(function_names.length()) +
      "\n"
    result = result +
      "Round-Trip patterns: " +
      int_to_string(pkg.roundtrips.length()) +
      "\n"
    result = result +
      "Idempotent patterns: " +
      int_to_string(pkg.idempotents.length()) +
      "\n"
    result = result +
      "Producer-Consumer patterns: " +
      int_to_string(pkg.producers.length()) +
      "\n"
    result = result +
      "Invariant patterns: " +
      int_to_string(pkg.invariants.length()) +
      "\n"
    result = result +
      "Oracle patterns: " +
      int_to_string(pkg.oracles.length()) +
      "\n"
    if explain {
      result = result + "Functions:\n"
      if pkg.functions.length() == 0 {
        result = result + "  (none)\n"
      } else {
        let mut j = 0
        while j < pkg.functions.length() {
          let func = pkg.functions[j]
          result = result + "  - " + func.name + " " + func.signature() + "\n"
          j = j + 1
        }
      }
      result = result + "Round-Trip details:\n"
      if pkg.roundtrips.length() == 0 {
        result = result + "  (none)\n"
      } else {
        let mut j = 0
        while j < pkg.roundtrips.length() {
          match pkg.roundtrips[j] {
            @patterns.RoundTrip(encoder, decoder) =>
              result = result +
                "  - " +
                describe_function_name(pkg.functions, encoder) +
                " <-> " +
                describe_function_name(pkg.functions, decoder) +
                "\n"
            _ => ()
          }
          j = j + 1
        }
      }
      result = result + "Idempotent details:\n"
      if pkg.idempotents.length() == 0 {
        result = result + "  (none)\n"
      } else {
        let mut j = 0
        while j < pkg.idempotents.length() {
          match pkg.idempotents[j] {
            @patterns.Idempotent(name) =>
              result = result +
                "  - " +
                describe_function_name(pkg.functions, name) +
                "\n"
            _ => ()
          }
          j = j + 1
        }
      }
      result = result + "Producer-Consumer details:\n"
      if pkg.producers.length() == 0 {
        result = result + "  (none)\n"
      } else {
        let mut j = 0
        while j < pkg.producers.length() {
          match pkg.producers[j] {
            @patterns.ProducerConsumer(producer, consumer) =>
              result = result +
                "  - " +
                describe_function_name(pkg.functions, producer) +
                " -> " +
                describe_function_name(pkg.functions, consumer) +
                "\n"
            _ => ()
          }
          j = j + 1
        }
      }
      result = result + "Invariant details:\n"
      if pkg.invariants.length() == 0 {
        result = result + "  (none)\n"
      } else {
        let mut j = 0
        while j < pkg.invariants.length() {
          match pkg.invariants[j] {
            @patterns.Invariant(func, inv_type) =>
              result = result +
                "  - " +
                describe_function_name(pkg.functions, func) +
                " (" +
                inv_type +
                ")\n"
            _ => ()
          }
          j = j + 1
        }
      }
      result = result + "Oracle details:\n"
      if pkg.oracles.length() == 0 {
        result = result + "  (none)\n"
      } else {
        let mut j = 0
        while j < pkg.oracles.length() {
          match pkg.oracles[j] {
            @patterns.Oracle(implementation, oracle) =>
              result = result +
                "  - " +
                describe_function_name(pkg.functions, implementation) +
                " vs " +
                describe_function_name(pkg.functions, oracle) +
                "\n"
            _ => ()
          }
          j = j + 1
        }
      }
    }
    i = i + 1
  }
  result
}

///|
fn format_analysis_json(
  path : String,
  packages : Array[PackageAnalysis],
  explain : Bool,
) -> String {
  if packages.length() == 0 {
    return json_object([
      ("ok", json_bool(false)),
      ("command", json_string("analyze")),
      ("path", json_string(path)),
      ("error", json_string("No MoonBit package found under: " + path)),
    ])
  }
  let package_jsons : Array[String] = []
  let mut i = 0
  while i < packages.length() {
    let pkg = packages[i]
    let pairs : Array[(String, String)] = [
      ("path", json_string(pkg.path)),
      ("function_count", json_number(pkg.functions.length())),
      ("round_trip_count", json_number(pkg.roundtrips.length())),
      ("idempotent_count", json_number(pkg.idempotents.length())),
      ("producer_consumer_count", json_number(pkg.producers.length())),
      ("invariant_count", json_number(pkg.invariants.length())),
      ("oracle_count", json_number(pkg.oracles.length())),
    ]
    if explain {
      let functions_json : Array[String] = []
      let mut j = 0
      while j < pkg.functions.length() {
        let func = pkg.functions[j]
        Array::push(
          functions_json,
          json_object([
            ("name", json_string(func.name)),
            ("signature", json_string(func.signature())),
          ]),
        )
        j = j + 1
      }
      let roundtrip_json : Array[String] = []
      let mut j = 0
      while j < pkg.roundtrips.length() {
        let pat = pkg.roundtrips[j]
        Array::push(roundtrip_json, pattern_to_json(pkg.functions, pat))
        j = j + 1
      }
      let idempotent_json : Array[String] = []
      let mut j = 0
      while j < pkg.idempotents.length() {
        let pat = pkg.idempotents[j]
        Array::push(idempotent_json, pattern_to_json(pkg.functions, pat))
        j = j + 1
      }
      let producer_json : Array[String] = []
      let mut j = 0
      while j < pkg.producers.length() {
        let pat = pkg.producers[j]
        Array::push(producer_json, pattern_to_json(pkg.functions, pat))
        j = j + 1
      }
      let invariant_json : Array[String] = []
      let mut j = 0
      while j < pkg.invariants.length() {
        let pat = pkg.invariants[j]
        Array::push(invariant_json, pattern_to_json(pkg.functions, pat))
        j = j + 1
      }
      let oracle_json : Array[String] = []
      let mut j = 0
      while j < pkg.oracles.length() {
        let pat = pkg.oracles[j]
        Array::push(oracle_json, pattern_to_json(pkg.functions, pat))
        j = j + 1
      }
      Array::push(pairs, ("functions", json_array(functions_json)))
      Array::push(pairs, ("round_trips", json_array(roundtrip_json)))
      Array::push(pairs, ("idempotents", json_array(idempotent_json)))
      Array::push(pairs, ("producer_consumers", json_array(producer_json)))
      Array::push(pairs, ("invariants", json_array(invariant_json)))
      Array::push(pairs, ("oracles", json_array(oracle_json)))
    }
    Array::push(package_jsons, json_object(pairs))
    i = i + 1
  }
  json_object([
    ("ok", json_bool(true)),
    ("command", json_string("analyze")),
    ("path", json_string(path)),
    ("packages", json_array(package_jsons)),
  ])
}

///|
/// ファイル内容を読み込み
fn read_file_content(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ => ""
  }
}

///|
/// ディレクトリ一覧を安全に取得
fn read_dir_entries(path : String) -> Array[String] {
  @fs.read_dir(path) catch {
    _ => []
  }
}

///|
/// パスがディレクトリか判定
fn is_dir(path : String) -> Bool {
  @fs.is_dir(path) catch {
    _ => false
  }
}

///|
/// パスがファイルか判定
fn is_file(path : String) -> Bool {
  @fs.is_file(path) catch {
    _ => false
  }
}

///|
/// パスを結合
fn join_path(base : String, name : String) -> String {
  let entry_path = @path.Path(name)
  if entry_path.is_absolute() {
    name
  } else {
    @path.Path(base).join(entry_path).to_string()
  }
}

///|
fn extract_module_name_from_mod(content : String) -> String? {
  let key = "\"name\""
  match content.find(key) {
    None => None
    Some(pos) => {
      let chars = content.to_array()
      let mut i = pos + key.length()
      while i < chars.length() && chars[i].is_whitespace() {
        i = i + 1
      }
      if i >= chars.length() || chars[i] != ':' {
        return None
      }
      i = i + 1
      while i < chars.length() && chars[i].is_whitespace() {
        i = i + 1
      }
      if i >= chars.length() || chars[i] != '"' {
        return None
      }
      i = i + 1
      let mut value = ""
      while i < chars.length() && chars[i] != '"' {
        value = value + chars[i].to_string()
        i = i + 1
      }
      Some(value)
    }
  }
}

///|
fn module_short_name(name : String) -> String {
  let parts = name.split("/").to_array()
  if parts.length() == 0 {
    name
  } else {
    parts[parts.length() - 1].to_string()
  }
}

///|
fn extract_module_name() -> String {
  let content = read_file_content("moon.mod.json")
  match extract_module_name_from_mod(content) {
    None => "module"
    Some(name) => module_short_name(name)
  }
}

///|
fn output_path_for_pbt(path : String, module_name : String) -> String {
  let dir = if is_dir(path) {
    path
  } else {
    @path.Path(path).dirname().to_string()
  }
  let filename = module_name + ".pbt.mbt.md"
  @path.Path(dir).join(@path.Path(filename)).to_string()
}

///|
/// 親ディレクトリを取得
fn path_dirname(path : String) -> String {
  @path.Path(path).dirname().to_string()
}

///|
/// パッケージディレクトリか判定
fn has_moon_pkg(path : String) -> Bool {
  @fs.path_exists(join_path(path, "moon.pkg.json"))
}

///|
/// 除外対象ディレクトリか判定
fn should_skip_dir(name : String) -> Bool {
  name == ".git" ||
  name == ".moon" ||
  name == ".mooncakes" ||
  name == ".moonagent" ||
  name == "_build" ||
  name == "target" ||
  name == "node_modules"
}

///|
/// 近傍のパッケージディレクトリを探索
fn find_package_dir(start : String) -> String? {
  let mut current = start
  while true {
    if has_moon_pkg(current) {
      return Some(current)
    }
    let parent = path_dirname(current)
    if parent == current {
      break
    }
    current = parent
  }
  None
}

///|
/// 入力パスからパッケージディレクトリを解決
fn resolve_package_dirs(path : String) -> Array[String] {
  if is_file(path) {
    match find_package_dir(path_dirname(path)) {
      Some(dir) => [dir]
      None => []
    }
  } else if is_dir(path) {
    if has_moon_pkg(path) {
      [path]
    } else {
      collect_package_dirs(path)
    }
  } else {
    []
  }
}

///|
/// 配下のパッケージディレクトリを再帰的に収集
fn collect_package_dirs(root : String) -> Array[String] {
  let result : Array[String] = []
  let entries = read_dir_entries(root)
  let mut i = 0
  while i < entries.length() {
    let entry = entries[i]
    if should_skip_dir(entry) {
      i = i + 1
      continue
    }
    let path = join_path(root, entry)
    if is_dir(path) {
      if has_moon_pkg(path) {
        Array::push(result, path)
      }
      let nested = collect_package_dirs(path)
      let _ = push_strings(result, nested)

    }
    i = i + 1
  }
  result
}

///|
/// パッケージから公開関数メタデータを収集
fn collect_functions_from_package(
  package_dir : String,
) -> Array[@ast.FunctionMeta] {
  let result : Array[@ast.FunctionMeta] = []
  let entries = read_dir_entries(package_dir)
  let mut i = 0
  while i < entries.length() {
    let entry = entries[i]
    let path = join_path(package_dir, entry)
    if is_file(path) {
      if entry.has_suffix(".mbt.md") {
        if !is_pbt_doc(entry) {
          let functions = collect_functions_from_markdown(path)
          let _ = push_functions(result, functions)

        }
      } else if entry.has_suffix(".mbt") {
        let functions = collect_functions_from_file(path)
        let _ = push_functions(result, functions)

      } else {
        ()
      }
    }
    i = i + 1
  }
  result
}

///|
/// MoonBitソースファイルから関数メタデータを抽出
fn collect_functions_from_file(path : String) -> Array[@ast.FunctionMeta] {
  let source = read_file_content(path)
  @analyzer.extract_public_functions(source, path)
}

///|
/// MarkdownからMoonBitコードブロックを抽出して解析
fn collect_functions_from_markdown(path : String) -> Array[@ast.FunctionMeta] {
  let markdown = read_file_content(path)
  let blocks = @parser.extract_moonbit_blocks(markdown)
  let result : Array[@ast.FunctionMeta] = []
  let mut i = 0
  while i < blocks.length() {
    let functions = @analyzer.extract_public_functions(blocks[i].content, path)
    let _ = push_functions(result, functions)
    i = i + 1
  }
  result
}

///|
fn collect_arbitrary_impls_from_package(
  package_dir : String,
) -> Array[@ast.ArbitraryImpl] {
  let result : Array[@ast.ArbitraryImpl] = []
  let entries = read_dir_entries(package_dir)
  let mut i = 0
  while i < entries.length() {
    let entry = entries[i]
    let path = join_path(package_dir, entry)
    if is_file(path) {
      if entry.has_suffix(".mbt.md") {
        if !is_pbt_doc(entry) {
          let impls = collect_arbitrary_impls_from_markdown(path)
          let _ = push_arbitrary_impls(result, impls)

        }
      } else if entry.has_suffix(".mbt") {
        let impls = collect_arbitrary_impls_from_file(path)
        let _ = push_arbitrary_impls(result, impls)

      } else {
        ()
      }
    }
    i = i + 1
  }
  result
}

///|
fn collect_arbitrary_impls_from_file(
  path : String,
) -> Array[@ast.ArbitraryImpl] {
  let source = read_file_content(path)
  @analyzer.detect_arbitrary_impls(source)
}

///|
fn collect_arbitrary_impls_from_markdown(
  path : String,
) -> Array[@ast.ArbitraryImpl] {
  let markdown = read_file_content(path)
  let blocks = @parser.extract_moonbit_blocks(markdown)
  let result : Array[@ast.ArbitraryImpl] = []
  let mut i = 0
  while i < blocks.length() {
    let impls = @analyzer.detect_arbitrary_impls(blocks[i].content)
    let _ = push_arbitrary_impls(result, impls)
    i = i + 1
  }
  result
}

///|
fn collect_functions_from_packages(
  package_dirs : Array[String],
) -> Array[@ast.FunctionMeta] {
  let result : Array[@ast.FunctionMeta] = []
  let mut i = 0
  while i < package_dirs.length() {
    let functions = collect_functions_from_package(package_dirs[i])
    let _ = push_functions(result, functions)
    i = i + 1
  }
  result
}

///|
fn collect_arbitrary_impls_from_packages(
  package_dirs : Array[String],
) -> Array[@ast.ArbitraryImpl] {
  let result : Array[@ast.ArbitraryImpl] = []
  let mut i = 0
  while i < package_dirs.length() {
    let impls = collect_arbitrary_impls_from_package(package_dirs[i])
    let _ = push_arbitrary_impls(result, impls)
    i = i + 1
  }
  result
}

///|
/// 文字列配列の末尾に要素を追加
fn push_strings(target : Array[String], items : Array[String]) -> Array[String] {
  let mut i = 0
  while i < items.length() {
    Array::push(target, items[i])
    i = i + 1
  }
  target
}

///|
/// 関数メタデータ配列の末尾に要素を追加
fn push_functions(
  target : Array[@ast.FunctionMeta],
  items : Array[@ast.FunctionMeta],
) -> Array[@ast.FunctionMeta] {
  let mut i = 0
  while i < items.length() {
    Array::push(target, items[i])
    i = i + 1
  }
  target
}

///|
fn push_arbitrary_impls(
  target : Array[@ast.ArbitraryImpl],
  items : Array[@ast.ArbitraryImpl],
) -> Array[@ast.ArbitraryImpl] {
  let mut i = 0
  while i < items.length() {
    Array::push(target, items[i])
    i = i + 1
  }
  target
}

///|
/// PBTドキュメントのファイル名判定
fn is_pbt_doc(name : String) -> Bool {
  name.has_suffix(".pbt.mbt.md")
}

///|
fn function_names_from_meta(
  functions : Array[@ast.FunctionMeta],
) -> Array[String] {
  let result : Array[String] = []
  let mut i = 0
  while i < functions.length() {
    Array::push(result, functions[i].name)
    i = i + 1
  }
  result
}

///|
fn find_function_meta(
  functions : Array[@ast.FunctionMeta],
  name : String,
) -> @ast.FunctionMeta? {
  let mut i = 0
  while i < functions.length() {
    if functions[i].name == name {
      return Some(functions[i])
    }
    i = i + 1
  }
  None
}

///|
fn infer_default_type(
  functions : Array[@ast.FunctionMeta],
  patterns : Array[@patterns.PatternCandidate],
  known_impls : Array[@ast.ArbitraryImpl],
) -> String {
  let mut i = 0
  while i < patterns.length() {
    let type_name = match patterns[i] {
      @patterns.RoundTrip(encoder, _) =>
        match find_function_meta(functions, encoder) {
          Some(func) => type_name_from_function(func)
          None => None
        }
      @patterns.Idempotent(func_name) =>
        match find_function_meta(functions, func_name) {
          Some(func) => type_name_from_function(func)
          None => None
        }
      @patterns.ProducerConsumer(producer, _) =>
        match find_function_meta(functions, producer) {
          Some(func) => type_name_from_function(func)
          None => None
        }
      @patterns.Invariant(func, _) =>
        match find_function_meta(functions, func) {
          Some(func) => type_name_from_function(func)
          None => None
        }
      @patterns.Oracle(implementation, _) =>
        match find_function_meta(functions, implementation) {
          Some(func) => type_name_from_function(func)
          None => None
        }
    }
    match type_name {
      Some(t) =>
        match @analyzer.check_type_testability(t, known_impls) {
          @ast.Testable => return t
          _ => ()
        }
      None => ()
    }
    i = i + 1
  }
  "String"
}

///|
fn type_name_from_function(func : @ast.FunctionMeta) -> String? {
  if func.args.length() > 0 {
    let arg_type = func.args[0].type_.simple_name()
    if arg_type != "Unit" {
      return Some(arg_type)
    }
  }
  let ret_type = func.return_type.simple_name()
  if ret_type != "Unit" {
    Some(ret_type)
  } else {
    None
  }
}

///|
priv struct GenerateReport {
  path : String
  module_name : String
  output_path : String
  packages_scanned : Int
  patterns_detected : Int
  default_type : String
  patterns : Array[@patterns.PatternCandidate]
  functions : Array[@ast.FunctionMeta]
  dry_run : Bool
  write_error : String?
}

///|
fn build_generate_report(
  path : String,
  options : CommandOptions,
) -> Result[GenerateReport, String] {
  let package_dirs = resolve_package_dirs(path)
  if package_dirs.length() == 0 {
    return Err("No MoonBit package found under: " + path)
  }
  let functions = collect_functions_from_packages(package_dirs)
  let function_names = function_names_from_meta(functions)

  // パターン検出
  let roundtrips = @patterns.find_round_trips(function_names)
  let idempotents = @patterns.find_idempotent_functions(function_names)
  let producers = @patterns.find_producer_consumer(function_names)
  let invariants = @patterns.find_invariant_functions(function_names)
  let oracles = @patterns.find_oracle_candidates(function_names)

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
  let mut i = 0
  while i < invariants.length() {
    all_patterns = append_pattern(all_patterns, invariants[i])
    i = i + 1
  }
  let mut i = 0
  while i < oracles.length() {
    all_patterns = append_pattern(all_patterns, oracles[i])
    i = i + 1
  }
  let known_impls = collect_arbitrary_impls_from_packages(package_dirs)
  let default_type = infer_default_type(functions, all_patterns, known_impls)
  let module_name = extract_module_name()
  let doc = @generator.build_pbt_document(
    module_name, path, all_patterns, default_type,
  )
  let content = @generator.generate_pbt_targets_md(doc)
  let output_path = output_path_for_pbt(path, module_name)
  let mut write_error : String? = None
  if !options.dry_run {
    let merged = @generator.merge_generated_markdown(
      read_file_content(output_path),
      content,
    )
    let error : String? = try {
      @fs.write_string_to_file(output_path, merged)
      None
    } catch {
      err => Some("\{err}")
    }
    write_error = error
  }
  Ok({
    path,
    module_name,
    output_path,
    packages_scanned: package_dirs.length(),
    patterns_detected: all_patterns.length(),
    default_type,
    patterns: all_patterns,
    functions,
    dry_run: options.dry_run,
    write_error,
  })
}

///|
fn format_generate_text(report : GenerateReport, explain : Bool) -> String {
  let mut result = if report.dry_run {
    "=== PBT Targets Collected (dry-run) ===\n"
  } else {
    "=== PBT Targets Collected ===\n"
  }
  result = result + "Module: " + report.module_name + "\n"
  result = result + "Output: " + report.output_path + "\n"
  result = result +
    "Packages scanned: " +
    int_to_string(report.packages_scanned) +
    "\n"
  result = result +
    "Patterns detected: " +
    int_to_string(report.patterns_detected) +
    "\n"
  if report.dry_run {
    result = result + "Dry run: true\n"
  }
  if report.write_error is Some(msg) {
    result = result + "Write error: " + msg + "\n"
  }
  if explain {
    result = result + "Default type: " + report.default_type + "\n"
    result = result + "Patterns:\n"
    if report.patterns.length() == 0 {
      result = result + "  (none)\n"
    } else {
      let mut i = 0
      while i < report.patterns.length() {
        result = result +
          "  - " +
          describe_pattern(report.functions, report.patterns[i]) +
          "\n"
        i = i + 1
      }
    }
  }
  result
}

///|
fn format_generate_json(report : GenerateReport, explain : Bool) -> String {
  let ok = report.write_error is None
  let pairs : Array[(String, String)] = [
    ("ok", json_bool(ok)),
    ("command", json_string("generate")),
    ("path", json_string(report.path)),
    ("module", json_string(report.module_name)),
    ("output", json_string(report.output_path)),
    ("packages_scanned", json_number(report.packages_scanned)),
    ("patterns_detected", json_number(report.patterns_detected)),
    ("dry_run", json_bool(report.dry_run)),
  ]
  if report.write_error is Some(msg) {
    Array::push(pairs, ("write_error", json_string(msg)))
  }
  if explain {
    Array::push(pairs, ("default_type", json_string(report.default_type)))
    let patterns_json : Array[String] = []
    let mut i = 0
    while i < report.patterns.length() {
      Array::push(
        patterns_json,
        pattern_to_json(report.functions, report.patterns[i]),
      )
      i = i + 1
    }
    Array::push(pairs, ("patterns", json_array(patterns_json)))
  }
  json_object(pairs)
}

///|
/// テストを生成
fn generate_tests(path : String) -> String {
  match build_generate_report(path, default_options()) {
    Err(_) => "No MoonBit package found under: " + path + "\n"
    Ok(report) => format_generate_text(report, false)
  }
}

///|
/// PBT markdownを同期
fn format_sync_text(markdown_path : String, dry_run : Bool) -> String {
  if dry_run {
    match @pbt_sync.check_sync(markdown_path) {
      Err(errors) => {
        let mut output = "=== PBT Sync (dry-run) Failed ===\n"
        output = output + errors.join("\n") + "\n"
        output
      }
      Ok(_) => {
        let mut output = "=== PBT Sync (dry-run) ===\n"
        output = output + "Markdown: " + markdown_path + "\n"
        output = output + "Status: up to date\n"
        output
      }
    }
  } else {
    sync_targets(markdown_path)
  }
}

///|
fn format_sync_json(markdown_path : String, dry_run : Bool) -> String {
  if dry_run {
    match @pbt_sync.check_sync(markdown_path) {
      Err(errors) =>
        json_object([
          ("ok", json_bool(false)),
          ("command", json_string("sync")),
          ("path", json_string(markdown_path)),
          ("dry_run", json_bool(true)),
          ("errors", json_array(errors.map(json_string))),
        ])
      Ok(_) =>
        json_object([
          ("ok", json_bool(true)),
          ("command", json_string("sync")),
          ("path", json_string(markdown_path)),
          ("dry_run", json_bool(true)),
          ("status", json_string("up_to_date")),
        ])
    }
  } else {
    match @pbt_sync.sync(markdown_path) {
      Err(errors) =>
        json_object([
          ("ok", json_bool(false)),
          ("command", json_string("sync")),
          ("path", json_string(markdown_path)),
          ("dry_run", json_bool(false)),
          ("errors", json_array(errors.map(json_string))),
        ])
      Ok(report) =>
        json_object([
          ("ok", json_bool(true)),
          ("command", json_string("sync")),
          ("path", json_string(markdown_path)),
          ("dry_run", json_bool(false)),
          ("written", json_array(report.written.map(json_string))),
          ("removed", json_array(report.removed.map(json_string))),
          ("unchanged", json_array(report.unchanged.map(json_string))),
        ])
    }
  }
}

///|
fn sync_targets(markdown_path : String) -> String {
  let result = @pbt_sync.sync(markdown_path)
  match result {
    Err(errors) => {
      let mut output = "=== PBT Sync Failed ===\n"
      output = output + errors.join("\n") + "\n"
      output
    }
    Ok(report) => {
      let mut output = "=== PBT Sync ===\n"
      output = output + "Markdown: " + markdown_path + "\n"
      output = output +
        "Written: " +
        int_to_string(report.written.length()) +
        "\n"
      output = output +
        "Removed: " +
        int_to_string(report.removed.length()) +
        "\n"
      output = output +
        "Unchanged: " +
        int_to_string(report.unchanged.length()) +
        "\n"
      output
    }
  }
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

///|
/// テスト
test "parse_args_help" {
  let args = ["prog", "help"]
  let result = parse_args(args)
  match result {
    Help => inspect("ok", content="ok")
    _ => inspect("fail", content="fail")
  }
}

///|
test "parse_args_analyze" {
  let args = ["prog", "analyze", "./src"]
  let result = parse_args(args)
  match result {
    Analyze(p, options) => {
      inspect(p, content="./src")
      inspect(options.dry_run, content="false")
      inspect(options.explain, content="false")
    }
    _ => inspect("fail", content="fail")
  }
}

///|
test "parse_args_generate" {
  let args = ["prog", "generate", "./src"]
  let result = parse_args(args)
  match result {
    Generate(p, options) => {
      inspect(p, content="./src")
      inspect(options.dry_run, content="false")
      inspect(options.explain, content="false")
    }
    _ => inspect("fail", content="fail")
  }
}

///|
test "parse_args_sync_default" {
  let args = ["prog", "sync"]
  let result = parse_args(args)
  let expected = @pbt_sync.default_pbt_markdown_path()
  match result {
    Sync(p, options) => {
      inspect(p, content=expected)
      inspect(options.dry_run, content="false")
      inspect(options.explain, content="false")
    }
    _ => inspect("fail", content="fail")
  }
}

///|
test "parse_args_generate_options" {
  let args = [
    "prog", "generate", "./src", "--dry-run", "--format", "json", "--explain",
  ]
  let result = parse_args(args)
  match result {
    Generate(p, options) => {
      inspect(p, content="./src")
      inspect(options.dry_run, content="true")
      inspect(options.explain, content="true")
      match options.format {
        Json => inspect("json", content="json")
        _ => inspect("fail", content="json")
      }
    }
    _ => inspect("fail", content="fail")
  }
}

///|
test "run_command_analyze" {
  let cmd = Analyze("./src", default_options())
  let result = run_command(cmd)
  inspect(result.contains("Analyzing"), content="true")
}

///|
test "run_command_help" {
  let cmd = Help
  let result = run_command(cmd)
  inspect(result.contains("moon-pbt-gen"), content="true")
}

///|
test "help_message_contains_commands" {
  let msg = help_message()
  inspect(msg.contains("analyze"), content="true")
  inspect(msg.contains("generate"), content="true")
  inspect(msg.contains("sync"), content="true")
  inspect(msg.contains("--dry-run"), content="true")
  inspect(msg.contains("--format"), content="true")
}

///|
test "extract_module_name_from_mod" {
  let content = "{\n  \"name\": \"org/sample\",\n  \"version\": \"0.1.0\"\n}"
  match extract_module_name_from_mod(content) {
    Some(name) => inspect(name, content="org/sample")
    None => inspect("none", content="some")
  }
}

///|
test "module_short_name" {
  inspect(module_short_name("org/sample"), content="sample")
}

///|
test "generate_tests_creates_pbt_file" {
  let test_dir = "/tmp/aletheia_pbt_pkg"
  let pkg_path = join_path(test_dir, "moon.pkg.json")
  let source_path = join_path(test_dir, "sample.mbt")
  let test_source = "pub fn encode(x : Int) -> String { \"test\" }\npub fn decode(s : String) -> Int { 0 }"

  // テスト用ディレクトリを準備
  try {
    @fs.remove_file(source_path)
    @fs.remove_file(pkg_path)
    @fs.remove_dir(test_dir)
  } catch {
    _ => ()
  }
  @fs.create_dir(test_dir) catch {
    _ => ()
  }
  @fs.write_string_to_file(pkg_path, "{}") catch {
    _ => ()
  }
  @fs.write_string_to_file(source_path, test_source) catch {
    _ => ()
  }

  // generate_testsを実行
  let result = generate_tests(test_dir)

  // 結果検証
  inspect(result.contains("PBT Targets Collected"), content="true")
  let entries = read_dir_entries(test_dir)
  let mut has_pbt = false
  let mut i = 0
  while i < entries.length() {
    if entries[i].has_suffix(".pbt.mbt.md") {
      has_pbt = true
    }
    i = i + 1
  }
  inspect(has_pbt, content="true")

  // クリーンアップ
  try {
    let entries = read_dir_entries(test_dir)
    let mut i = 0
    while i < entries.length() {
      let entry = entries[i]
      if entry.has_suffix(".pbt.mbt.md") {
        @fs.remove_file(join_path(test_dir, entry))
      }
      i = i + 1
    }
    @fs.remove_file(source_path)
    @fs.remove_file(pkg_path)
    @fs.remove_dir(test_dir)
  } catch {
    _ => ()
  }
}
