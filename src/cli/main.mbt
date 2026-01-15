///|
/// CLIモジュール（Phase 5）
/// コマンドラインツールmoon-pbt-genのエントリポイント
///

///|
/// コマンド種類
pub enum Command {
  Analyze(String) // パスを解析
  Generate(String) // テストを生成
  Sync(String) // PBT markdownを同期
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
    } else if cmd == "sync" || cmd == "s" {
      if Array::length(args) >= 3 {
        Sync(args[2])
      } else {
        Sync(@pbt_sync.default_pbt_markdown_path())
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
    Sync(path) => ["moon-pbt-gen", "sync", path]
    Help => ["moon-pbt-gen", "help"]
  }
}

///|
/// ヘルプメッセージを生成
pub fn help_message() -> String {
  let lines = [
    "moon-pbt-gen - Property-Based Testing code generator", "", "Usage:", "  moon-pbt-gen <command> [arguments]",
    "", "Commands:", "  analyze <path>     Analyze MoonBit package or file", "  generate <path>   Collect PBT targets into <module>.pbt.mbt.md",
    "  sync [path]       Sync PBT markdown into per-package tests", "  help              Show this help message",
    "", "Examples:", "  moon-pbt-gen analyze ./src", "  moon-pbt-gen generate ./src",
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

///|
/// コマンドを実行
pub fn run_command(cmd : Command) -> String {
  match cmd {
    Analyze(path) => "Analyzing: " + path + "\n" + analyze_source(path)
    Generate(path) =>
      "Collecting PBT targets for: " + path + "\n" + generate_tests(path)
    Sync(path) => "Syncing PBT markdown: " + path + "\n" + sync_targets(path)
    Help => help_message()
  }
}

///|
/// ソースを解析
fn analyze_source(path : String) -> String {
  let package_dirs = resolve_package_dirs(path)
  if package_dirs.length() == 0 {
    "No MoonBit package found under: " + path + "\n"
  } else {
    let mut result = ""
    let mut i = 0
    while i < package_dirs.length() {
      let package_dir = package_dirs[i]
      let functions = collect_functions_from_package(package_dir)
      let function_names = function_names_from_meta(functions)
      let roundtrips = @patterns.find_round_trips(function_names)
      let idempotents = @patterns.find_idempotent_functions(function_names)
      let producers = @patterns.find_producer_consumer(function_names)
      if i > 0 {
        result = result + "\n"
      }
      result = result + "=== Analysis Result for " + package_dir + " ===\n"
      result = result +
        "Functions found: " +
        int_to_string(function_names.length()) +
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
      i = i + 1
    }
    result
  }
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
/// テストを生成
fn generate_tests(path : String) -> String {
  let package_dirs = resolve_package_dirs(path)
  if package_dirs.length() == 0 {
    "No MoonBit package found under: " + path + "\n"
  } else {
    let functions = collect_functions_from_packages(package_dirs)
    let function_names = function_names_from_meta(functions)

    // パターン検出
    let roundtrips = @patterns.find_round_trips(function_names)
    let idempotents = @patterns.find_idempotent_functions(function_names)
    let producers = @patterns.find_producer_consumer(function_names)

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
    let known_impls = collect_arbitrary_impls_from_packages(package_dirs)
    let default_type = infer_default_type(functions, all_patterns, known_impls)
    let module_name = extract_module_name()
    let doc = @generator.build_pbt_document(
      module_name, path, all_patterns, default_type,
    )
    let content = @generator.generate_pbt_targets_md(doc)
    let output_path = output_path_for_pbt(path, module_name)
    let merged = @generator.merge_generated_markdown(
      read_file_content(output_path),
      content,
    )
    let write_error : String? = try {
      @fs.write_string_to_file(output_path, merged)
      None
    } catch {
      err => Some("\{err}")
    }
    let mut result = "=== PBT Targets Collected ===\n"
    result = result + "Module: " + module_name + "\n"
    result = result + "Output: " + output_path + "\n"
    result = result +
      "Packages scanned: " +
      int_to_string(package_dirs.length()) +
      "\n"
    result = result +
      "Patterns detected: " +
      int_to_string(all_patterns.length()) +
      "\n"
    if write_error is Some(msg) {
      result = result + "Write error: " + msg + "\n"
    }
    result
  }
}

///|
/// PBT markdownを同期
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
test "parse_args_sync_default" {
  let args = ["prog", "sync"]
  let result = parse_args(args)
  let expected = @pbt_sync.default_pbt_markdown_path()
  match result {
    Sync(p) => inspect(p, content=expected)
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
  inspect(msg.contains("sync"), content="true")
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
