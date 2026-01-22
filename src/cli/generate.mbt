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
  let function_names = function_names_from_meta_sorted(functions)

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
  let content = @generator.generate_pbt_targets_md(doc, true)
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
fn format_generate_reports_text(
  reports : Array[GenerateReport],
  explain : Bool,
) -> String {
  let mut result = ""
  let mut i = 0
  while i < reports.length() {
    let report = reports[i]
    if i > 0 {
      result = result + "\n"
    }
    result = result + format_generate_text(report, explain)
    i = i + 1
  }
  result
}

///|
fn format_generate_reports_json(
  reports : Array[GenerateReport],
  explain : Bool,
) -> String {
  let reports_json : Array[String] = []
  let mut i = 0
  while i < reports.length() {
    Array::push(reports_json, format_generate_json(reports[i], explain))
    i = i + 1
  }
  json_object([
    ("ok", json_bool(true)),
    ("command", json_string("generate")),
    ("reports", json_array(reports_json)),
  ])
}

///|
/// テストを生成
#warnings("-unused_value")
fn generate_tests(path : String) -> String {
  match build_generate_report(path, default_options()) {
    Err(_) => "No MoonBit package found under: " + path + "\n"
    Ok(report) => format_generate_text(report, false)
  }
}

///|
/// パッケージ単位のレポート生成
fn build_per_package_reports(
  path : String,
  options : CommandOptions,
) -> Result[Array[GenerateReport], String] {
  let package_dirs = resolve_package_dirs(path)
  if package_dirs.length() == 0 {
    return Err("No MoonBit package found under: " + path)
  }
  let reports : Array[GenerateReport] = []
  let mut i = 0
  while i < package_dirs.length() {
    let pkg_dir = package_dirs[i]

    // パッケージ単位で関数を収集
    let functions = collect_functions_from_package(pkg_dir)
    let function_names = function_names_from_meta_sorted(functions)

    // パッケージ単位でパターン検出
    let roundtrips = @patterns.find_round_trips(function_names)
    let idempotents = @patterns.find_idempotent_functions(function_names)
    let producers = @patterns.find_producer_consumer(function_names)
    let invariants = @patterns.find_invariant_functions(function_names)
    let oracles = @patterns.find_oracle_candidates(function_names)

    // パターンを統合
    let mut all_patterns : Array[@patterns.PatternCandidate] = []
    let mut j = 0
    while j < roundtrips.length() {
      all_patterns = append_pattern(all_patterns, roundtrips[j])
      j = j + 1
    }
    let mut j = 0
    while j < idempotents.length() {
      all_patterns = append_pattern(all_patterns, idempotents[j])
      j = j + 1
    }
    let mut j = 0
    while j < producers.length() {
      all_patterns = append_pattern(all_patterns, producers[j])
      j = j + 1
    }
    let mut j = 0
    while j < invariants.length() {
      all_patterns = append_pattern(all_patterns, invariants[j])
      j = j + 1
    }
    let mut j = 0
    while j < oracles.length() {
      all_patterns = append_pattern(all_patterns, oracles[j])
      j = j + 1
    }

    // パッケージ単位でArbitrary実装を収集
    let known_impls = collect_arbitrary_impls_from_package(pkg_dir)
    let default_type = infer_default_type(functions, all_patterns, known_impls)

    // パッケージ名を抽出
    let module_name = extract_module_name_from_package(pkg_dir)

    // ドキュメントを生成
    let doc = @generator.build_pbt_document(
      module_name, pkg_dir, all_patterns, default_type,
    )
    let content = @generator.generate_pbt_targets_md(doc, true)
    let output_path = output_path_for_pbt(pkg_dir, module_name)
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
    Array::push(reports, {
      path: pkg_dir,
      module_name,
      output_path,
      packages_scanned: 1,
      patterns_detected: all_patterns.length(),
      default_type,
      patterns: all_patterns,
      functions,
      dry_run: options.dry_run,
      write_error,
    })
    i = i + 1
  }
  Ok(reports)
}
