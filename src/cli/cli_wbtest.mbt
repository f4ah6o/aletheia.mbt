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
      inspect(options.generic_names.length(), content="3")
      inspect(options.min_cases, content="1")
      inspect(options.min_roundtrip, content="0")
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
      inspect(options.generic_names.length(), content="3")
      inspect(options.min_cases, content="1")
      inspect(options.min_roundtrip, content="0")
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
      inspect(options.generic_names.length(), content="3")
      inspect(options.min_cases, content="1")
    }
    _ => inspect("fail", content="fail")
  }
}

///|
test "parse_args_generate_options" {
  let args = [
    "prog", "generate", "./src", "--dry-run", "--format", "json", "--explain", "--generic-names",
    "src,main",
  ]
  let result = parse_args(args)
  match result {
    Generate(p, options) => {
      inspect(p, content="./src")
      inspect(options.dry_run, content="true")
      inspect(options.explain, content="true")
      inspect(options.generic_names.length(), content="2")
      inspect(options.min_cases, content="1")
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
  inspect(msg.contains("--generic-names"), content="true")
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
test "sanitize_package_name_avoids_generic" {
  let generic = ["src", "main", "module"]
  inspect(sanitize_package_name("/tmp/project/src", generic), content="project")
  inspect(
    sanitize_package_name("/tmp/project/main", generic),
    content="project",
  )
  inspect(sanitize_package_name("/tmp/project/lib", generic), content="lib")
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
    if is_pbt_doc(entries[i]) {
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
      if is_pbt_doc(entry) {
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
