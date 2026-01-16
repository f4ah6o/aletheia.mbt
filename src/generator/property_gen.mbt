///|
/// PBTコード生成モジュール（Phase 4）
/// パターン候補からプロパティテストコードを生成する
///

///|
/// 生成されたプロパティテスト
pub struct GeneratedTest {
  name : String
  code : String
  description : String
  fence : String
}

///|
/// Round-Tripプロパティテストを生成（frequency + stats by default）
pub fn generate_round_trip_test(
  encoder : String,
  decoder : String,
  type_name : String,
) -> GeneratedTest {
  let test_name = "prop_" + encoder + "_" + decoder + "_roundtrip"

  // Frequency-based generator with edge case emphasis
  let gen_expr = frequency_generator_for_type(type_name)

  // Build classification conditions based on type
  let classify_code = build_classification_for_type(type_name, "x")

  let test_code = "test \"" +
    test_name +
    "\" {\n" +
    "  let gen = " +
    gen_expr +
    "\n" +
    "  let config = @pbt.CheckConfig::new(cases=100, max_size=30, seed=42)\n" +
    "  let result = @pbt.check_with_stats(gen, fn(x : " +
    type_name +
    ") {\n" +
    classify_code +
    "    assert_eq(" +
    decoder +
    "(" +
    encoder +
    "(x)), x)\n" +
    "    (Ok(()), label)\n" +
    "  }, config~)\n" +
    "  match result.stats {\n" +
    "    Some(stats) => println(stats.to_string())\n" +
    "    None => ()\n" +
    "  }\n" +
    "  assert_true(result.passed)\n" +
    "}"
  {
    name: test_name,
    code: test_code,
    description: "Round-trip property: encode then decode should return original value",
    fence: "mbt nocheck",
  }
}

///|
/// Round-Tripプロパティテスト（parse->generate->parse）を生成
fn generate_parse_generate_round_trip_test(
  parser : String,
  generator : String,
) -> GeneratedTest {
  let test_name = "prop_" + parser + "_" + generator + "_roundtrip"
  let test_code = "test \"" +
    test_name +
    "\" {\n  let fixtures = [\n    \"```moonbit\\nfn foo() -> Int { 1 }\\n```\",\n    \"Intro\\n\\n```mbt check\\n test { inspect(1) }\\n```\\nOutro\",\n    \"```mbt nocheck\\nlet x = 1\\n```\\n```moonbit\\nfn bar() -> Int { 2 }\\n```\",\n    \"```\\nfn baz() -> Int { 3 }\\n```\",\n    \"plain text\"\n  ]\n  for markdown in fixtures {\n    let ast = " +
    parser +
    "(markdown)\n    let regenerated = " +
    generator +
    "(ast)\n    let ast2 = " +
    parser +
    "(regenerated)\n    assert_eq(ast.code_blocks.length(), ast2.code_blocks.length())\n    let mut i = 0\n    while i < ast.code_blocks.length() {\n      let block1 = ast.code_blocks[i]\n      let block2 = ast2.code_blocks[i]\n      assert_eq(block1.lang, block2.lang)\n      assert_eq(block1.content, block2.content)\n      i = i + 1\n    }\n  }\n}"
  {
    name: test_name,
    code: test_code,
    description: "Round-trip property: parse -> generate -> parse preserves code block content",
    fence: "mbt check",
  }
}

///|
/// Round-Tripプロパティテスト（parse/generateの正規化）を生成
fn generate_parse_generate_stable_test(
  parser : String,
  generator : String,
) -> GeneratedTest {
  let test_name = "prop_" + parser + "_" + generator + "_roundtrip"
  let test_code = "test \"" +
    test_name +
    "\" {\n  let fixtures = [\n    \"\",\n    \"alpha\",\n    \"alpha\\nbeta\",\n    \"a,b,c\"\n  ]\n  for input in fixtures {\n    let normalized = " +
    generator +
    "(" +
    parser +
    "(input))\n    let normalized2 = " +
    generator +
    "(" +
    parser +
    "(normalized))\n    assert_eq(normalized2, normalized)\n  }\n}"
  {
    name: test_name,
    code: test_code,
    description: "Round-trip property: generate(parse(x)) is stable under re-parsing",
    fence: "mbt nocheck",
  }
}

///|
/// Round-Tripプロパティテスト（parse_args/command_to_args）を生成
fn generate_parse_command_to_round_trip_test(
  parser : String,
  generator : String,
) -> GeneratedTest {
  let test_name = "prop_" + parser + "_" + generator + "_roundtrip"
  let test_code = "test \"" +
    test_name +
    "\" {\n  let fixtures : Array[Array[String]] = [\n    [\"moon-pbt-gen\", \"analyze\", \"./src\"],\n    [\"moon-pbt-gen\", \"analyze\", \"./examples\"],\n    [\"moon-pbt-gen\", \"generate\", \"./src\"],\n    [\"moon-pbt-gen\", \"sync\", \"./src\"],\n    [\"moon-pbt-gen\", \"help\"],\n  ]\n  for args in fixtures {\n    let args2 = " +
    generator +
    "(" +
    parser +
    "(args))\n    assert_eq(args2, args)\n  }\n}"
  {
    name: test_name,
    code: test_code,
    description: "Round-trip property: command_to(parse(args)) keeps args stable",
    fence: "mbt check",
  }
}

///|
/// べき等性プロパティテストを生成（frequency + stats by default）
pub fn generate_idempotent_test(
  func : String,
  type_name : String,
) -> GeneratedTest {
  let test_name = "prop_" + func + "_idempotent"

  // Frequency-based generator with edge case emphasis
  let gen_expr = frequency_generator_for_type(type_name)

  // Build classification conditions based on type
  let classify_code = build_classification_for_type(type_name, "x")

  let test_code = "test \"" +
    test_name +
    "\" {\n" +
    "  let gen = " +
    gen_expr +
    "\n" +
    "  let config = @pbt.CheckConfig::new(cases=100, max_size=30, seed=42)\n" +
    "  let result = @pbt.check_with_stats(gen, fn(x : " +
    type_name +
    ") {\n" +
    classify_code +
    "    assert_eq(" +
    func +
    "(" +
    func +
    "(x)), " +
    func +
    "(x))\n" +
    "    (Ok(()), label)\n" +
    "  }, config~)\n" +
    "  match result.stats {\n" +
    "    Some(stats) => println(stats.to_string())\n" +
    "    None => ()\n" +
    "  }\n" +
    "  assert_true(result.passed)\n" +
    "}"
  {
    name: test_name,
    code: test_code,
    description: "Idempotent property: applying function twice should be same as applying once",
    fence: "mbt nocheck",
  }
}

///|
/// プロパティテストコードをMarkdown形式で生成
pub fn generate_mbt_md_section(input_tests : Array[GeneratedTest]) -> String {
  if input_tests.length() == 0 {
    "## Property Tests\n\nNo property tests generated.\n"
  } else {
    let mut result = "## Property Tests\n\n"
    let mut i = 0
    while i < input_tests.length() {
      let t = input_tests[i]
      result = result + "### " + t.name + "\n\n"
      result = result + t.description + "\n\n"
      result = result + "```" + t.fence + "\n" + t.code + "\n```\n\n"
      i = i + 1
    }
    result
  }
}

///|
/// PBTパターンの種類
pub enum PatternKind {
  RoundTrip
  Idempotent
  ProducerConsumer
  Invariant
  Oracle
}

///|
/// 検出されたパターン情報
pub struct DetectedPattern {
  kind : PatternKind
  functions : Array[String]
  type_info : String
}

///|
/// PBT Markdownドキュメント全体
pub struct PbtDocument {
  module_name : String
  source_file : String
  patterns : Array[DetectedPattern]
  test_cases : Array[GeneratedTest]
  generated_at : String
}

///|
fn is_parse_generate_pair(encoder : String, decoder : String) -> Bool {
  encoder.has_prefix("parse_") && decoder.has_prefix("generate_")
}

///|
fn is_parse_command_to_pair(encoder : String, decoder : String) -> Bool {
  encoder.has_prefix("parse_") && decoder.has_prefix("command_to_")
}

///|
/// PatternCandidate から GeneratedTest を生成
pub fn pattern_to_test(
  pattern : @patterns.PatternCandidate,
  type_name : String,
) -> GeneratedTest {
  match pattern {
    @patterns.RoundTrip(encoder, decoder) =>
      if encoder == "parse_markdown" && decoder == "generate_markdown" {
        generate_parse_generate_round_trip_test(encoder, decoder)
      } else if is_parse_command_to_pair(encoder, decoder) {
        generate_parse_command_to_round_trip_test(encoder, decoder)
      } else if is_parse_generate_pair(encoder, decoder) {
        generate_parse_generate_stable_test(encoder, decoder)
      } else {
        generate_round_trip_test(encoder, decoder, type_name)
      }
    @patterns.Idempotent(func) => generate_idempotent_test(func, type_name)
    @patterns.ProducerConsumer(producer, consumer) =>
      generate_producer_consumer_test(producer, consumer, type_name)
    @patterns.Invariant(func, inv_type) =>
      generate_invariant_test(func, inv_type, type_name)
    @patterns.Oracle(implementation, oracle) =>
      generate_oracle_test(implementation, oracle, type_name)
  }
}

///|
/// Producer-Consumerプロパティテストを生成
pub fn generate_producer_consumer_test(
  producer : String,
  consumer : String,
  type_name : String,
) -> GeneratedTest {
  let test_name = "prop_" + producer + "_" + consumer + "_pipeline"

  // QuickCheckジェネレータ式を取得
  let gen_expr = generator_expression_for_type(type_name)
  let test_code = "test \"" +
    test_name +
    "\" {\n" +
    "  let gen = " +
    gen_expr +
    "\n" +
    "  let config = @pbt.CheckConfig::new(cases=100, max_size=30, seed=42)\n" +
    "  let result = @pbt.check(gen, fn(x : " +
    type_name +
    ") {\n" +
    "    let _ = " +
    consumer +
    "(" +
    producer +
    "(x))\n" +
    "    Ok(())\n" +
    "  }, config~)\n" +
    "  assert_true(result.passed)\n" +
    "}"
  {
    name: test_name,
    code: test_code,
    description: "Pipeline property: producer output is valid consumer input",
    fence: "mbt nocheck",
  }
}

///|
/// 不変条件プロパティテストを生成
pub fn generate_invariant_test(
  func : String,
  inv_type : String,
  type_name : String,
) -> GeneratedTest {
  let test_name = "prop_" + func + "_invariant_" + inv_type.to_lower()
  let (assertion, description) = match inv_type {
    "LengthPreserving" =>
      (
        "assert_eq(" + func + "(x).length(), x.length())",
        "Invariant property: " + func + " preserves length",
      )
    "LengthDecreasing" =>
      (
        "assert_true(" + func + "(x).length() <= x.length())",
        "Invariant property: " + func + " does not increase length",
      )
    "LengthIncreasing" =>
      (
        "assert_true(" + func + "(x).length() >= x.length())",
        "Invariant property: " + func + " does not decrease length",
      )
    "OrderPreserving" =>
      (
        "// Order of elements is preserved by " + func,
        "Invariant property: " + func + " preserves element order",
      )
    "ContentPreserving" =>
      (
        "assert_eq(" +
        func +
        "(x).iter().fold(init=0, fn(acc, e) { acc + e.hash() }), x.iter().fold(init=0, fn(acc, e) { acc + e.hash() }))",
        "Invariant property: " + func + " preserves content (same elements)",
      )
    _ =>
      (
        "// TODO: Define invariant for " + inv_type,
        "Invariant property: " + func + " maintains " + inv_type,
      )
  }

  // QuickCheckジェネレータ式を取得
  let gen_expr = generator_expression_for_type(type_name)
  let test_code = "test \"" +
    test_name +
    "\" {\n" +
    "  let gen = " +
    gen_expr +
    "\n" +
    "  let config = @pbt.CheckConfig::new(cases=100, max_size=30, seed=42)\n" +
    "  let result = @pbt.check(gen, fn(x : " +
    type_name +
    ") {\n" +
    "    " +
    assertion +
    "\n" +
    "    Ok(())\n" +
    "  }, config~)\n" +
    "  assert_true(result.passed)\n" +
    "}"
  { name: test_name, code: test_code, description, fence: "mbt nocheck" }
}

///|
/// オラクルプロパティテストを生成
pub fn generate_oracle_test(
  implementation : String,
  oracle : String,
  type_name : String,
) -> GeneratedTest {
  let test_name = "prop_" + implementation + "_vs_" + oracle + "_oracle"

  // QuickCheckジェネレータ式を取得
  let gen_expr = generator_expression_for_type(type_name)
  let test_code = "test \"" +
    test_name +
    "\" {\n" +
    "  let gen = " +
    gen_expr +
    "\n" +
    "  let config = @pbt.CheckConfig::new(cases=100, max_size=30, seed=42)\n" +
    "  let result = @pbt.check(gen, fn(x : " +
    type_name +
    ") {\n" +
    "    assert_eq(" +
    implementation +
    "(x), " +
    oracle +
    "(x))\n" +
    "    Ok(())\n" +
    "  }, config~)\n" +
    "  assert_true(result.passed)\n" +
    "}"
  {
    name: test_name,
    code: test_code,
    description: "Oracle property: " +
    implementation +
    " should produce the same result as " +
    oracle,
    fence: "mbt nocheck",
  }
}

///|
/// エッジケーステストを生成
pub fn generate_edge_case_tests(
  func_name : String,
  type_name : String,
) -> GeneratedTest {
  let edge_cases = edge_cases_for_type(type_name)
  let test_name = func_name + "_edge_cases"
  let mut test_code = "test \"" + test_name + "\" {\n"
  let mut i = 0
  while i < edge_cases.length() {
    let edge_case = edge_cases[i]
    test_code = test_code +
      "  // " +
      edge_case.description +
      "\n" +
      "  let x_" +
      int_to_string(i) +
      " : " +
      type_name +
      " = " +
      edge_case.value_expr +
      "\n"

    // 関数を実行して結果を検証（基本チェック）
    test_code = test_code +
      "  let result_" +
      int_to_string(i) +
      " = " +
      func_name +
      "(x_" +
      int_to_string(i) +
      ")\n"
    i = i + 1
  }
  test_code = test_code + "  // Edge cases handled successfully\n" + "}"
  {
    name: test_name,
    code: test_code,
    description: "Edge case tests for " + func_name,
    fence: "mbt nocheck",
  }
}

///|
/// 頻度分布付きジェネレータテンプレートを生成
pub fn generate_frequency_generator_template(
  type_name : String,
  distribution : Array[(Int, String)],
) -> String {
  let mut result = "fn gen_" +
    type_name.to_lower() +
    "() -> @pbt.Gen[" +
    type_name +
    "] {\n"
  result = result + "  @pbt.frequency([\n"
  let mut i = 0
  while i < distribution.length() {
    let (weight, variant) = distribution[i]
    result = result +
      "    (" +
      weight.to_string() +
      ", @pbt.Gen::constant(" +
      variant +
      "))"
    if i < distribution.length() - 1 {
      result = result + ","
    }
    result = result + "\n"
    i = i + 1
  }
  result = result + "  ])\n}"
  result
}

///|
/// 統計付きテストを生成
pub fn generate_test_with_stats(
  test_name : String,
  gen_code : String,
  property_code : String,
  classifications : Array[(String, String)],
) -> GeneratedTest {
  let mut classify_code = ""
  let mut i = 0
  while i < classifications.length() {
    let (label, condition) = classifications[i]
    if i == 0 {
      classify_code = "    let label = if " +
        condition +
        " { Some(\"" +
        label +
        "\") }"
    } else {
      classify_code = classify_code +
        " else if " +
        condition +
        " { Some(\"" +
        label +
        "\") }"
    }
    i = i + 1
  }
  if classifications.length() > 0 {
    classify_code = classify_code + " else { None }\n"
  }
  let test_code = "test \"" +
    test_name +
    "\" {\n  let gen = " +
    gen_code +
    "\n  let result = @pbt.check_with_stats(gen, fn(x) {\n" +
    classify_code +
    "    " +
    property_code +
    "\n    (Ok(()), label)\n  })\n  match result.stats {\n    Some(stats) => println(stats.to_string())\n    None => ()\n  }\n  assert_true(result.passed)\n}"
  {
    name: test_name,
    code: test_code,
    description: "Property test with statistical classification",
    fence: "mbt nocheck",
  }
}

///|
/// 反例ログセクションを生成（enhanced with detailed debugging guidance）
pub fn generate_counterexample_section() -> String {
  "## Counterexample Logging\n\n" +
  "When a property test fails, the following information is logged:\n\n" +
  "### Failed Test Information\n" +
  "- **Original value**: The first value that caused the failure\n" +
  "- **Shrunk value**: The minimal value that still causes the failure (if shrinking is enabled)\n" +
  "- **Test case index**: Which test case failed (e.g., 42/100)\n" +
  "- **Random seed**: Seed for reproduction\n" +
  "- **Shrink count**: Number of shrinking steps performed\n\n" +
  "### Reproduction Command\n" +
  "To reproduce a failure, use the same seed:\n\n" +
  "```mbt nocheck\n" +
  "let config = @pbt.CheckConfig::new(\n" +
  "  cases=100,\n" +
  "  max_size=30,\n" +
  "  seed=<RECORD_SEED_HERE>,\n" +
  "  shrink_limit=100\n" +
  ")\n" +
  "@pbt.check(gen, property, config~)\n" +
  "```\n\n" +
  generate_counterexample_analysis_template() +
  "\n"
}

///|
/// Generate counterexample analysis template for debugging
pub fn generate_counterexample_analysis_template() -> String {
  "### Shrinking Analysis Template\n\n" +
  "Use this template to document your counterexample analysis:\n\n" +
  "```markdown\n" +
  "| Shrunk Value | Property Check | Notes |\n" +
  "|--------------|----------------|-------|\n" +
  "| ...          | ...            | ...   |\n" +
  "```\n\n" +
  "### Debugging Checklist\n\n" +
  "- [ ] Record the original failing value\n" +
  "- [ ] Record the shrunk minimal counterexample\n" +
  "- [ ] Note the test case index and random seed\n" +
  "- [ ] Identify which edge case triggered the failure\n" +
  "- [ ] Verify the bug exists with the shrunk value\n" +
  "- [ ] Add regression test using the minimal counterexample\n" +
  "- [ ] Consider if additional edge cases need testing\n"
}

///|
/// Build classification code for statistical analysis based on type
pub fn build_classification_for_type(type_name : String, var_name : String) -> String {
  match type_name {
    "Int" =>
      "    let label = if " +
      var_name +
      " == 0 {\n" +
      "      Some(\"zero\")\n" +
      "    } else if " +
      var_name +
      " == 1 || " +
      var_name +
      " == -1 {\n" +
      "      Some(\"unit\")\n" +
      "    } else if " +
      var_name +
      " > 1000 || " +
      var_name +
      " < -1000 {\n" +
      "      Some(\"large\")\n" +
      "    } else {\n" +
      "      Some(\"normal\")\n" +
      "    }\n"
    "String" =>
      "    let label = if " +
      var_name +
      ".length() == 0 {\n" +
      "      Some(\"empty\")\n" +
      "    } else if " +
      var_name +
      ".length() == 1 {\n" +
      "      Some(\"single_char\")\n" +
      "    } else if " +
      var_name +
      ".length() > 100 {\n" +
      "      Some(\"long\")\n" +
      "    } else {\n" +
      "      Some(\"normal\")\n" +
      "    }\n"
    _ =>
      // Generic classification for container types
      if type_name.has_prefix("Array[") || type_name.has_prefix("List[") {
        "    let label = if " +
        var_name +
        ".length() == 0 {\n" +
        "      Some(\"empty\")\n" +
        "    } else if " +
        var_name +
        ".length() == 1 {\n" +
        "      Some(\"single_element\")\n" +
        "    } else {\n" +
        "      Some(\"normal\")\n" +
        "    }\n"
      } else if type_name.has_prefix("Option[") {
        "    let label = match " +
        var_name +
        " {\n" +
        "      None => Some(\"none\")\n" +
        "      Some(_) => Some(\"some\")\n" +
        "    }\n"
      } else {
        // Default classification
        "    let label : Option[String] = Some(\"default\")\n"
      }
  }
}

///|
/// Generate Shrink trait implementation template（enhanced with per-type examples）
pub fn generate_shrink_template(type_name : String) -> String {
  "## Shrink Trait Implementation\n\n" +
  "For type `" +
  type_name +
  "`, implement custom shrinking to improve counterexample minimization.\n\n" +
  generate_shrink_examples() +
  "\n" +
  "### Template for " +
  type_name +
  "\n\n" +
  "```mbt nocheck\n" +
  "pub impl Shrink for " +
  type_name +
  " with shrink(self) -> Iter[" +
  type_name +
  "] {\n" +
  "  // Strategy: remove elements, simplify values, reduce ranges\n" +
  "  let mut shrunk : Array[" +
  type_name +
  "] = []\n" +
  "\n" +
  "  // 1. Try empty/smaller variants\n" +
  "  // 2. Try simplifying individual fields\n" +
  "  // 3. Try boundary values\n" +
  "\n" +
  "  shrunk.to_iter()\n" +
  "}\n" +
  "```\n"
}

///|
/// Generate shrink trait examples for common types
pub fn generate_shrink_examples() -> String {
  "### Shrink Strategy Examples\n\n" +
  "#### Int/Int64 Shrink Example\n" +
  "```mbt nocheck\n" +
  "pub impl Shrink for Int with shrink(self) -> Iter[Int] {\n" +
  "  let mut shrunk : Array[Int] = []\n" +
  "  // Try boundary values\n" +
  "  if self != 0 { Array::push(shrunk, 0) }\n" +
  "  if self != 1 { Array::push(shrunk, 1) }\n" +
  "  if self != -1 { Array::push(shrunk, -1) }\n" +
  "  // Try halving\n" +
  "  if self > 1 { Array::push(shrunk, self / 2) }\n" +
  "  if self < -1 { Array::push(shrunk, self / 2) }\n" +
  "  shrunk.to_iter()\n" +
  "}\n" +
  "```\n\n" +
  "#### String Shrink Example\n" +
  "```mbt nocheck\n" +
  "pub impl Shrink for String with shrink(self) -> Iter[String] {\n" +
  "  let mut shrunk : Array[String] = []\n" +
  "  // Try empty\n" +
  "  if self.length() > 0 { Array::push(shrunk, \"\") }\n" +
  "  // Try removing characters\n" +
  "  if self.length() > 1 {\n" +
  "    Array::push(shrunk, substring_range(self, 0, self.length() - 1))\n" +
  "    Array::push(shrunk, substring_range(self, 1, self.length()))\n" +
  "  }\n" +
  "  // Try single character\n" +
  "  if self.length() > 1 {\n" +
  "    Array::push(shrunk, self[0].to_string())\n" +
  "  }\n" +
  "  shrunk.to_iter()\n" +
  "}\n" +
  "```\n\n" +
  "#### Array[T] Shrink Example\n" +
  "```mbt nocheck\n" +
  "pub impl Shrink[T] for Array[T] with shrink(self) -> Iter[Array[T]] {\n" +
  "  let mut shrunk : Array[Array[T]] = []\n" +
  "  // Try empty\n" +
  "  if self.length() > 0 { Array::push(shrunk, []) }\n" +
  "  // Try removing elements\n" +
  "  let mut i = 0\n" +
  "  while i < self.length() {\n" +
  "    let mut smaller : Array[T] = []\n" +
  "    let mut j = 0\n" +
  "    while j < self.length() {\n" +
  "      if j != i { Array::push(smaller, self[j]) }\n" +
  "      j = j + 1\n" +
  "    }\n" +
  "    Array::push(shrunk, smaller)\n" +
  "    i = i + 1\n" +
  "  }\n" +
  "  // Try smaller subsets (first half, second half)\n" +
  "  if self.length() > 2 {\n" +
  "    let half = self.length() / 2\n" +
  "    let mut first_half : Array[T] = []\n" +
  "    let mut j = 0\n" +
  "    while j < half {\n" +
  "      Array::push(first_half, self[j])\n" +
  "      j = j + 1\n" +
  "    }\n" +
  "    Array::push(shrunk, first_half)\n" +
  "  }\n" +
  "  shrunk.to_iter()\n" +
  "}\n" +
  "```\n\n" +
  "### Shrink Tips\n\n" +
  "- **Start simple**: Try empty/zero values first\n" +
  "- **Remove elements**: Drop elements from arrays/strings\n" +
  "- **Simplify values**: Replace with smaller numbers, shorter strings\n" +
  "- **Boundary values**: Try 0, 1, -1 for numbers; empty for collections\n" +
  "- **Order matters**: Generate shrunk values from simplest to most complex\n"
}

///|
fn string_to_lower(s : String) -> String {
  let chars = s.to_array()
  let mut result = ""
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    let code = c.to_int()
    if code >= 65 && code <= 90 {
      // A-Z -> a-z
      result = result + Char::from_int(code + 32).to_string()
    } else {
      result = result + c.to_string()
    }
    i = i + 1
  }
  result
}

///|
fn String::to_lower(self : String) -> String {
  string_to_lower(self)
}

///|
/// PatternCandidate を DetectedPattern に変換
fn pattern_to_detected(pattern : @patterns.PatternCandidate) -> DetectedPattern {
  match pattern {
    @patterns.RoundTrip(encoder, decoder) =>
      { kind: RoundTrip, functions: [encoder, decoder], type_info: "T" }
    @patterns.Idempotent(func) =>
      { kind: Idempotent, functions: [func], type_info: "T" }
    @patterns.ProducerConsumer(producer, consumer) =>
      {
        kind: ProducerConsumer,
        functions: [producer, consumer],
        type_info: "T",
      }
    @patterns.Invariant(func, inv_type) =>
      { kind: Invariant, functions: [func, inv_type], type_info: "T" }
    @patterns.Oracle(implementation, oracle) =>
      { kind: Oracle, functions: [implementation, oracle], type_info: "T" }
  }
}

///|
fn pattern_sort_key(pattern : @patterns.PatternCandidate) -> String {
  match pattern {
    @patterns.RoundTrip(encoder, decoder) =>
      "1_round_trip:" + encoder + ":" + decoder
    @patterns.Idempotent(func) => "2_idempotent:" + func
    @patterns.ProducerConsumer(producer, consumer) =>
      "3_producer_consumer:" + producer + ":" + consumer
    @patterns.Invariant(func, inv_type) =>
      "4_invariant:" + func + ":" + inv_type
    @patterns.Oracle(implementation, oracle) =>
      "5_oracle:" + implementation + ":" + oracle
  }
}

///|
fn sort_patterns(
  patterns : Array[@patterns.PatternCandidate],
) -> Array[@patterns.PatternCandidate] {
  let result : Array[@patterns.PatternCandidate] = []
  let mut i = 0
  while i < patterns.length() {
    Array::push(result, patterns[i])
    i = i + 1
  }
  result.sort_by((a, b) => String::compare(
    pattern_sort_key(a),
    pattern_sort_key(b),
  ))
  result
}

///|
/// 配列の末尾に要素を追加（再帰的）
fn append_test(
  arr : Array[GeneratedTest],
  elem : GeneratedTest,
) -> Array[GeneratedTest] {
  let n = arr.length()
  let result : Array[GeneratedTest] = []
  let mut i = 0
  while i < n {
    Array::push(result, arr[i])
    i = i + 1
  }
  Array::push(result, elem)
  result
}

///|
/// 配列の末尾に要素を追加（再帰的）
fn append_detected(
  arr : Array[DetectedPattern],
  elem : DetectedPattern,
) -> Array[DetectedPattern] {
  let n = arr.length()
  let result : Array[DetectedPattern] = []
  let mut i = 0
  while i < n {
    Array::push(result, arr[i])
    i = i + 1
  }
  Array::push(result, elem)
  result
}

///|
/// 配列から条件に合う要素をフィルタリング
fn filter_by_name_suffix(
  input_tests : Array[GeneratedTest],
  suffix : String,
) -> Array[GeneratedTest] {
  let mut result : Array[GeneratedTest] = []
  let mut i = 0
  while i < input_tests.length() {
    let t = input_tests[i]
    if t.name.contains(suffix) {
      result = append_test(result, t)
    } else {
      ()
    }
    i = i + 1
  }
  result
}

///|
/// 検出パターンを種類ごとに抽出
fn filter_patterns_by_kind(
  patterns : Array[DetectedPattern],
  kind : PatternKind,
) -> Array[DetectedPattern] {
  let mut result : Array[DetectedPattern] = []
  let mut i = 0
  while i < patterns.length() {
    let pattern = patterns[i]
    let matches = match kind {
      RoundTrip => pattern.kind is RoundTrip
      Idempotent => pattern.kind is Idempotent
      ProducerConsumer => pattern.kind is ProducerConsumer
      Invariant => pattern.kind is Invariant
      Oracle => pattern.kind is Oracle
    }
    if matches {
      result = append_detected(result, pattern)
    }
    i = i + 1
  }
  result
}

///|
/// PBTドキュメント全体を組み立てる
pub fn build_pbt_document(
  module_name : String,
  source_file : String,
  patterns : Array[@patterns.PatternCandidate],
  default_type : String,
) -> PbtDocument {
  let sorted = sort_patterns(patterns)
  let mut test_cases : Array[GeneratedTest] = []
  let mut detected : Array[DetectedPattern] = []
  let mut i = 0
  while i < sorted.length() {
    let pattern = sorted[i]
    let t = pattern_to_test(pattern, default_type)
    let detected_pattern = pattern_to_detected(pattern)
    test_cases = append_test(test_cases, t)
    detected = append_detected(detected, detected_pattern)
    i = i + 1
  }
  {
    module_name,
    source_file,
    patterns: detected,
    test_cases,
    generated_at: "2026-01-14",
  }
}

///|
/// PbtDocument から完全なMarkdown文字列を生成（enhanced with new sections）
pub fn generate_pbt_md(doc : PbtDocument) -> String {
  let mut result = "# Property-Based Tests for " + doc.module_name + "\n\n"
  result = result + "> Auto-generated by Aletheia - MoonBit PBT Tool\n\n"
  result = result + "## Overview\n\n"
  result = result + "- **Source**: `" + doc.source_file + "`\n"
  result = result + "- **Generated**: " + doc.generated_at + "\n"
  result = result +
    "- **Patterns Detected**: " +
    doc.patterns.length().to_string() +
    "\n\n"

  // NEW: Add counterexample section at the beginning
  result = result + generate_counterexample_section()

  // NEW: Add shrink template section
  result = result + "\n" + generate_shrink_template("T")

  // パターン別にセクションを生成
  let roundtrips = filter_by_name_suffix(doc.test_cases, "roundtrip")
  let idempotents = filter_by_name_suffix(doc.test_cases, "idempotent")
  let pipelines = filter_by_name_suffix(doc.test_cases, "pipeline")
  let invariants = filter_by_name_suffix(doc.test_cases, "invariant")
  let oracles = filter_by_name_suffix(doc.test_cases, "oracle")
  if roundtrips.length() > 0 {
    result = result + "## Round-Trip Properties\n\n"
    let mut i = 0
    while i < roundtrips.length() {
      let t = roundtrips[i]
      result = result + "### " + t.name + "\n\n"
      result = result + t.description + "\n\n"
      result = result + "```" + t.fence + "\n" + t.code + "\n```\n\n"
      i = i + 1
    }
  }
  if idempotents.length() > 0 {
    result = result + "## Idempotent Properties\n\n"
    let mut i = 0
    while i < idempotents.length() {
      let t = idempotents[i]
      result = result + "### " + t.name + "\n\n"
      result = result + t.description + "\n\n"
      result = result + "```" + t.fence + "\n" + t.code + "\n```\n\n"
      i = i + 1
    }
  }
  if pipelines.length() > 0 {
    result = result + "## Producer-Consumer Properties\n\n"
    let mut i = 0
    while i < pipelines.length() {
      let t = pipelines[i]
      result = result + "### " + t.name + "\n\n"
      result = result + t.description + "\n\n"
      result = result + "```" + t.fence + "\n" + t.code + "\n```\n\n"
      i = i + 1
    }
  }
  if invariants.length() > 0 {
    result = result + "## Invariant Properties\n\n"
    let mut i = 0
    while i < invariants.length() {
      let t = invariants[i]
      result = result + "### " + t.name + "\n\n"
      result = result + t.description + "\n\n"
      result = result + "```" + t.fence + "\n" + t.code + "\n```\n\n"
      i = i + 1
    }
  }
  if oracles.length() > 0 {
    result = result + "## Oracle Properties\n\n"
    let mut i = 0
    while i < oracles.length() {
      let t = oracles[i]
      result = result + "### " + t.name + "\n\n"
      result = result + t.description + "\n\n"
      result = result + "```" + t.fence + "\n" + t.code + "\n```\n\n"
      i = i + 1
    }
  }
  result
}

///|
/// PbtDocument からターゲット一覧Markdownを生成
pub fn generate_pbt_targets_md(doc : PbtDocument) -> String {
  let mut result = "# Property-Based Test Targets for " +
    doc.module_name +
    "\n\n"
  result = result + "> Auto-generated by Aletheia - MoonBit PBT Tool\n\n"
  result = result + "## Overview\n\n"
  result = result + "- **Source**: `" + doc.source_file + "`\n"
  result = result + "- **Generated**: " + doc.generated_at + "\n"
  result = result +
    "- **Patterns Detected**: " +
    doc.patterns.length().to_string() +
    "\n\n"
  let roundtrips = filter_patterns_by_kind(doc.patterns, RoundTrip)
  let idempotents = filter_patterns_by_kind(doc.patterns, Idempotent)
  let pipelines = filter_patterns_by_kind(doc.patterns, ProducerConsumer)
  let invariants = filter_patterns_by_kind(doc.patterns, Invariant)
  let oracles = filter_patterns_by_kind(doc.patterns, Oracle)
  if roundtrips.length() > 0 {
    result = result + "## Round-Trip Targets\n\n"
    let mut i = 0
    while i < roundtrips.length() {
      let p = roundtrips[i]
      if p.functions.length() >= 2 {
        result = result +
          "- `" +
          p.functions[0] +
          "` <-> `" +
          p.functions[1] +
          "`\n"
      }
      i = i + 1
    }
    result = result + "\n"
  }
  if idempotents.length() > 0 {
    result = result + "## Idempotent Targets\n\n"
    let mut i = 0
    while i < idempotents.length() {
      let p = idempotents[i]
      if p.functions.length() >= 1 {
        result = result + "- `" + p.functions[0] + "`\n"
      }
      i = i + 1
    }
    result = result + "\n"
  }
  if pipelines.length() > 0 {
    result = result + "## Producer-Consumer Targets\n\n"
    let mut i = 0
    while i < pipelines.length() {
      let p = pipelines[i]
      if p.functions.length() >= 2 {
        result = result +
          "- `" +
          p.functions[0] +
          "` -> `" +
          p.functions[1] +
          "`\n"
      }
      i = i + 1
    }
    result = result + "\n"
  }
  if invariants.length() > 0 {
    result = result + "## Invariant Targets\n\n"
    let mut i = 0
    while i < invariants.length() {
      let p = invariants[i]
      if p.functions.length() >= 2 {
        result = result +
          "- `" +
          p.functions[0] +
          "` (" +
          p.functions[1] +
          ")\n"
      }
      i = i + 1
    }
    result = result + "\n"
  }
  if oracles.length() > 0 {
    result = result + "## Oracle Targets\n\n"
    let mut i = 0
    while i < oracles.length() {
      let p = oracles[i]
      if p.functions.length() >= 2 {
        result = result +
          "- `" +
          p.functions[0] +
          "` vs `" +
          p.functions[1] +
          "`\n"
      }
      i = i + 1
    }
    result = result + "\n"
  }
  result = result +
    "## Notes\n\n" +
    "- Property definitions are intentionally omitted. Define them in a separate process.\n"
  result.trim_end().to_string()
}

///|
pub fn generated_block_start() -> String {
  "<!-- aletheia:begin -->"
}

///|
pub fn generated_block_end() -> String {
  "<!-- aletheia:end -->"
}

///|
pub fn wrap_generated_block(content : String) -> String {
  let trimmed = content.trim_end().to_string()
  let mut result = generated_block_start() + "\n"
  if trimmed != "" {
    result = result + trimmed + "\n"
  }
  result = result + generated_block_end() + "\n"
  result
}

///|
fn wrap_generated_block_with_suffix(
  content : String,
  suffix : String,
) -> String {
  let trimmed = content.trim_end().to_string()
  let mut result = generated_block_start() + "\n"
  if trimmed != "" {
    result = result + trimmed + "\n"
  }
  result = result + generated_block_end()
  if suffix.has_prefix("\n") {
    result
  } else {
    result + "\n"
  }
}

///|
pub fn merge_generated_markdown(
  existing : String,
  generated : String,
) -> String {
  let start_marker = generated_block_start()
  let end_marker = generated_block_end()
  match existing.find(start_marker) {
    None => wrap_generated_block(generated)
    Some(start_idx) => {
      let start_len = start_marker.length()
      let end_len = end_marker.length()
      let search_start = start_idx + start_len
      let remainder = slice_string(existing, search_start, existing.length())
      match remainder.find(end_marker) {
        None => wrap_generated_block(generated)
        Some(rel_end) => {
          let end_idx = search_start + rel_end
          let prefix = slice_string(existing, 0, start_idx)
          let suffix = slice_string(
            existing,
            end_idx + end_len,
            existing.length(),
          )
          prefix + wrap_generated_block_with_suffix(generated, suffix) + suffix
        }
      }
    }
  }
}

///|
fn slice_string(source : String, start : Int, end : Int) -> String {
  String::unsafe_substring(source, start~, end~)
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
test "generate_round_trip_test_basic" {
  let result = generate_round_trip_test("encode", "decode", "Data")
  inspect(result.name, content="prop_encode_decode_roundtrip")
  inspect(result.code.contains("decode(encode(x))"), content="true")
  inspect(result.code.contains("@pbt.check"), content="true")
  inspect(result.code.contains("@pbt.Gen::arbitrary()"), content="true")
  inspect(result.fence, content="mbt nocheck")
}

///|
test "generate_idempotent_test_basic" {
  let result = generate_idempotent_test("sort", "Array[Int]")
  inspect(result.name, content="prop_sort_idempotent")
  inspect(result.code.contains("sort(sort(x))"), content="true")
  inspect(result.code.contains("@pbt.check"), content="true")
  inspect(result.code.contains("@pbt.Gen::array_of"), content="true")
  inspect(result.fence, content="mbt nocheck")
}

///|
test "generate_mbt_md_section" {
  let test1 = generate_round_trip_test("to_json", "from_json", "User")
  let test2 = generate_idempotent_test("normalize", "String")
  let input_tests = [test1, test2]
  let result = generate_mbt_md_section(input_tests)
  inspect(result.contains("Property Tests"), content="true")
  inspect(result.contains("```mbt nocheck"), content="true")
}

///|
test "generate_mbt_md_section_respects_fence" {
  let custom = {
    name: "custom",
    code: "test { assert_true(true) }",
    description: "custom fence",
    fence: "mbt check",
  }
  let result = generate_mbt_md_section([custom])
  inspect(result.contains("```mbt check"), content="true")
}

///|
test "wrap_generated_block_has_markers" {
  let wrapped = wrap_generated_block("hello")
  inspect(wrapped.contains(generated_block_start()), content="true")
  inspect(wrapped.contains(generated_block_end()), content="true")
}

///|
test "merge_generated_markdown_preserves_outside" {
  let existing = "intro\n" +
    generated_block_start() +
    "\nOLD_BLOCK\n" +
    generated_block_end() +
    "\noutro\n"
  let merged = merge_generated_markdown(existing, "NEW_BLOCK")
  inspect(merged.contains("intro"), content="true")
  inspect(merged.contains("outro"), content="true")
  inspect(merged.contains("OLD_BLOCK"), content="false")
  inspect(merged.contains("NEW_BLOCK"), content="true")
}

///|
test "merge_generated_markdown_is_stable_with_suffix" {
  let existing = wrap_generated_block("BLOCK") + "\n\n"
  let merged1 = merge_generated_markdown(existing, "BLOCK")
  let merged2 = merge_generated_markdown(merged1, "BLOCK")
  inspect(merged1 == merged2, content="true")
}

///|
test "generate_round_trip_test_escapes_braces" {
  let result = generate_round_trip_test("save", "load", "Config")
  inspect(result.code.contains("{"), content="true")
  inspect(result.code.contains("x)"), content="true")
}

///|
test "pattern_to_test_parse_generate_roundtrip" {
  let result = pattern_to_test(
    @patterns.make_round_trip("parse_markdown", "generate_markdown"),
    "String",
  )
  inspect(result.fence, content="mbt check")
  inspect(result.code.contains("parse_markdown"), content="true")
  inspect(result.code.contains("generate_markdown"), content="true")
}

///|
test "pattern_to_test_parse_command_to_roundtrip" {
  let result = pattern_to_test(
    @patterns.make_round_trip("parse_args", "command_to_args"),
    "Array[String]",
  )
  inspect(result.fence, content="mbt check")
  inspect(result.code.contains("parse_args"), content="true")
  inspect(result.code.contains("command_to_args"), content="true")
}

///|
test "pattern_to_test_generic_parse_generate_roundtrip" {
  let result = pattern_to_test(
    @patterns.make_round_trip("parse_config", "generate_config"),
    "String",
  )
  inspect(result.fence, content="mbt nocheck")
  inspect(result.code.contains("parse_config"), content="true")
  inspect(result.code.contains("generate_config"), content="true")
  inspect(result.code.contains("normalized2"), content="true")
}

///|
test "pattern_to_test_generic_parse_command_to_roundtrip" {
  let result = pattern_to_test(
    @patterns.make_round_trip("parse_flags", "command_to_flags"),
    "Array[String]",
  )
  inspect(result.fence, content="mbt check")
  inspect(result.code.contains("parse_flags"), content="true")
  inspect(result.code.contains("command_to_flags"), content="true")
}

///|
test "generate_pbt_targets_md" {
  let names = ["encode_data", "decode_data", "normalize"]
  let roundtrips = @patterns.find_round_trips(names)
  let idempotents = @patterns.find_idempotent_functions(names)
  let patterns : Array[@patterns.PatternCandidate] = []
  let mut i = 0
  while i < roundtrips.length() {
    Array::push(patterns, roundtrips[i])
    i = i + 1
  }
  let mut i = 0
  while i < idempotents.length() {
    Array::push(patterns, idempotents[i])
    i = i + 1
  }
  let doc = build_pbt_document("sample", "src", patterns, "T")
  let md = generate_pbt_targets_md(doc)
  inspect(md.contains("Round-Trip Targets"), content="true")
  inspect(md.contains("normalize"), content="true")
}

///|
test "generate_is_deterministic" {
  // 同じ入力で複数回生成しても結果が同一であることを検証
  let names = ["parse_foo", "generate_foo", "normalize"]
  let patterns = @patterns.find_round_trips(names)
  let doc1 = build_pbt_document("test_module", "src", patterns, "String")
  let doc2 = build_pbt_document("test_module", "src", patterns, "String")
  let md1 = generate_pbt_targets_md(doc1)
  let md2 = generate_pbt_targets_md(doc2)
  inspect(md1 == md2, content="true")
}

///|
test "merge_preserves_manual_edits" {
  // マーカー外の編集が保持されることを検証
  let existing = "Manual intro\n" +
    generated_block_start() +
    "\nOLD\n" +
    generated_block_end() +
    "\nManual outro"
  let generated = "NEW"
  let merged = merge_generated_markdown(existing, generated)
  inspect(merged.contains("Manual intro"), content="true")
  inspect(merged.contains("Manual outro"), content="true")
  inspect(merged.contains("NEW"), content="true")
  inspect(merged.contains("OLD"), content="false")
}

///|
test "merge_without_markers_creates_markers" {
  // マーカーがないファイルの場合、新しいマーカーが作成されることを検証
  let existing = "Manual content without markers"
  let generated = "GENERATED"
  let merged = merge_generated_markdown(existing, generated)
  inspect(merged.contains(generated_block_start()), content="true")
  inspect(merged.contains(generated_block_end()), content="true")
  inspect(merged.contains("GENERATED"), content="true")
  inspect(merged.contains("Manual content without markers"), content="false")
}

///|
test "merge_with_unbalanced_markers_replaces_all" {
  // 不整合なマーカーの場合、全体が置換されることを検証
  let existing = generated_block_start() + "\nOLD\n" + generated_block_end()
  let merged1 = merge_generated_markdown(existing, "NEW1")
  let merged2 = merge_generated_markdown(merged1, "NEW2")
  inspect(merged1.contains("NEW1"), content="true")
  inspect(merged2.contains("NEW2"), content="true")
  inspect(merged2.contains("NEW1"), content="false")
}
