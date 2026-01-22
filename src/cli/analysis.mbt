///|
/// ソースを解析
fn analyze_packages(path : String) -> Array[PackageAnalysis] {
  let package_dirs = resolve_package_dirs(path)
  let results : Array[PackageAnalysis] = []
  let mut i = 0
  while i < package_dirs.length() {
    let package_dir = package_dirs[i]
    let functions = collect_functions_from_package(package_dir)
    let function_names = function_names_from_meta_sorted(functions)
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
