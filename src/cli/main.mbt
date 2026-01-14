///|
/// CLIモジュール（Phase 5）
/// コマンドラインツールmoon-pbt-genのエントリポイント
///

///|
/// コマンド種類
pub enum Command {
  Analyze(String) // パスを解析
  Generate(String) // テストを生成
  Help
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

///|
/// コマンドを引数配列に変換（Round-Trip用逆変換）
pub fn command_to_args(cmd : Command) -> Array[String] {
  match cmd {
    Analyze(path) => ["moon-pbt-gen", "analyze", path]
    Generate(path) => ["moon-pbt-gen", "generate", path]
    Help => ["moon-pbt-gen", "help"]
  }
}

///|
/// ヘルプメッセージを生成
pub fn help_message() -> String {
  let lines = [
    "moon-pbt-gen - Property-Based Testing code generator", "", "Usage:", "  moon-pbt-gen <command> [arguments]",
    "", "Commands:", "  analyze <path>     Analyze MoonBit source files", "  generate <path>   Collect PBT targets into <module>.pbt.mbt.md",
    "  help              Show this help message", "", "Examples:", "  moon-pbt-gen analyze ./src",
    "  moon-pbt-gen generate ./src",
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
    Analyze(path) => "Analyzing: " + path + "\n" + analyze_source(path)
    Generate(path) =>
      "Collecting PBT targets for: " + path + "\n" + generate_tests(path)
    Help => help_message()
  }
}

///|
/// ソースを解析
fn analyze_source(path : String) -> String {
  // 対象ファイルを収集して関数名を抽出
  let files = collect_source_files(path)
  let functions = extract_function_names_from_files(files)
  let roundtrips = @patterns.find_round_trips(functions)
  let idempotents = @patterns.find_idempotent_functions(functions)
  let producers = @patterns.find_producer_consumer(functions)
  let mut result = "=== Analysis Result for " + path + " ===\n"
  result = result + "Files scanned: " + int_to_string(files.length()) + "\n"
  result = result +
    "Functions found: " +
    int_to_string(functions.length()) +
    "\n"
  result = result +
    "Round-Trip patterns: " +
    int_to_string(roundtrips.length()) +
    "\n"
  result = result +
    "Idempotent patterns: " +
    int_to_string(idempotents.length()) +
    "\n"
  result = result +
    "Producer-Consumer patterns: " +
    int_to_string(producers.length()) +
    "\n"
  result
}

///|
/// ファイル内容を読み込み
fn read_file_content(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ => ""
  }
}

///|
/// ディレクトリ配下の .mbt ファイルを収集
fn collect_source_files(path : String) -> Array[String] {
  let result : Array[String] = []
  if is_dir(path) {
    if should_skip_dir(path) {
      return result
    }
    let entries = read_dir_entries(path)
    let mut i = 0
    while i < entries.length() {
      let child = join_path(path, entries[i])
      if is_dir(child) {
        result.append(collect_source_files(child))
      } else if is_file(child) && is_mbt_file(child) {
        Array::push(result, child)
      }
      i = i + 1
    }
    result
  } else if is_file(path) && is_mbt_file(path) {
    [path]
  } else {
    result
  }
}

///|
fn extract_function_names_from_files(files : Array[String]) -> Array[String] {
  let result : Array[String] = []
  let mut i = 0
  while i < files.length() {
    let source = read_file_content(files[i])
    let names = @analyzer.extract_function_names(source)
    result.append(names)
    i = i + 1
  }
  result
}

///|
fn read_dir_entries(path : String) -> Array[String] {
  @fs.read_dir(path) catch {
    _ => []
  }
}

///|
fn is_dir(path : String) -> Bool {
  @fs.is_dir(path) catch {
    _ => false
  }
}

///|
fn is_file(path : String) -> Bool {
  @fs.is_file(path) catch {
    _ => false
  }
}

///|
fn should_skip_dir(path : String) -> Bool {
  let name = @path.Path(path).basename().to_string()
  name == ".git" ||
  name == "_build" ||
  name == "target" ||
  name == ".mooncakes" ||
  name == ".moonagent"
}

///|
fn is_mbt_file(path : String) -> Bool {
  path.has_suffix(".mbt")
}

///|
fn join_path(base : String, entry : String) -> String {
  let entry_path = @path.Path(entry)
  if entry_path.is_absolute() {
    entry
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
/// テストを生成
fn generate_tests(path : String) -> String {
  // 対象ファイルを収集して関数名を抽出
  let files = collect_source_files(path)
  let functions = extract_function_names_from_files(files)

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
  let module_name = extract_module_name()
  let doc = @generator.build_pbt_document(
    module_name, path, all_patterns, "TestData",
  )
  let content = @generator.generate_pbt_targets_md(doc)
  let output_path = output_path_for_pbt(path, module_name)
  let write_error : String? = try {
    @fs.write_string_to_file(output_path, content)
    None
  } catch {
    err => Some("\{err}")
  }
  let mut result = "=== PBT Targets Collected ===\n"
  result = result + "Module: " + module_name + "\n"
  result = result + "Output: " + output_path + "\n"
  result = result + "Files scanned: " + int_to_string(files.length()) + "\n"
  result = result +
    "Patterns detected: " +
    int_to_string(all_patterns.length()) +
    "\n"
  if write_error is Some(msg) {
    result = result + "Write error: " + msg + "\n"
  }
  result
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
    Analyze(p) => inspect(p, content="./src")
    _ => inspect("fail", content="fail")
  }
}

///|
test "parse_args_generate" {
  let args = ["prog", "generate", "./src"]
  let result = parse_args(args)
  match result {
    Generate(p) => inspect(p, content="./src")
    _ => inspect("fail", content="fail")
  }
}

///|
test "run_command_analyze" {
  let cmd = Analyze("./src")
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
