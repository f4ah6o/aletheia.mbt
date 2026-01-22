///|
/// パッケージから公開関数メタデータを収集
fn collect_functions_from_package(
  package_dir : String,
) -> Array[@ast.FunctionMeta] {
  let result : Array[@ast.FunctionMeta] = []
  let entries = read_dir_entries(package_dir)
  entries.sort_by((a, b) => String::compare(a, b))
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
  entries.sort_by((a, b) => String::compare(a, b))
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
/// PBTドキュメントのファイル名判定
fn is_pbt_doc(name : String) -> Bool {
  name.has_suffix(".pbt.md") || name.has_suffix(".pbt.mbt.md")
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
/// 関数名をアルファベット順にソートして返す（安定した出力のため）
fn function_names_from_meta_sorted(
  functions : Array[@ast.FunctionMeta],
) -> Array[String] {
  let names = function_names_from_meta(functions)
  names.sort_by((a, b) => String::compare(a, b))
  filter_internal_functions(names)
}

///|
/// 内部ヘルパー関数を除外した関数名リストを返す
fn filter_internal_functions(function_names : Array[String]) -> Array[String] {
  let result : Array[String] = []
  let mut i = 0
  while i < function_names.length() {
    let name = function_names[i]
    if !is_internal_function(name) {
      Array::push(result, name)
    }
    i = i + 1
  }
  result
}

///|
/// 内部ヘルパー関数かどうかを判定
fn is_internal_function(name : String) -> Bool {
  // 完全一致で除外する関数名
  let exact_excludes = ["generated_block_start", "generated_block_end"]
  let mut i = 0
  while i < exact_excludes.length() {
    if name == exact_excludes[i] {
      return true
    }
    i = i + 1
  }

  // プレフィックスで除外するパターン
  let prefix_excludes = [
    "wrap_generated_", "append_generated_", "merge_generated_", "filter_patterns_",
    "build_",
  ]
  let mut j = 0
  while j < prefix_excludes.length() {
    if name.has_prefix(prefix_excludes[j]) {
      return true
    }
    j = j + 1
  }
  false
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
      @patterns.ProducerConsumer(producer, consumer) =>
        // For producer-consumer, prefer consumer's input type if available
        // This handles cases like "new" -> "consume_str" where we need String
        match find_function_meta(functions, consumer) {
          Some(func) =>
            if func.args.length() > 1 {
              // Method like consume_str(self, s) -> use second arg type
              let arg_type = func.args[1].type_.simple_name()
              if arg_type != "Unit" && arg_type != "Self" {
                Some(arg_type)
              } else {
                // Fallback to producer's type
                match find_function_meta(functions, producer) {
                  Some(p) => type_name_from_function(p)
                  None => None
                }
              }
            } else if func.args.length() > 0 {
              // Regular function, use first arg type
              let arg_type = func.args[0].type_.simple_name()
              if arg_type != "Unit" && arg_type != "Self" {
                Some(arg_type)
              } else {
                // Fallback to producer's type
                match find_function_meta(functions, producer) {
                  Some(p) => type_name_from_function(p)
                  None => None
                }
              }
            } else {
              // No args, use producer's type
              match find_function_meta(functions, producer) {
                Some(p) => type_name_from_function(p)
                None => None
              }
            }
          None =>
            // Consumer not found, try producer
            match find_function_meta(functions, producer) {
              Some(func) => type_name_from_function(func)
              None => None
            }
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
