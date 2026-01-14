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
}

///|
/// Round-Tripプロパティテストを生成
pub fn generate_round_trip_test(
  encoder : String,
  decoder : String,
  type_name : String,
) -> GeneratedTest {
  let test_name = "prop_" + encoder + "_" + decoder + "_roundtrip"
  let test_code = "test \"" +
    test_name +
    "\" {\n  let gen : @pbt.Gen[" +
    type_name +
    "] = @pbt.Gen::arbitrary()\n  @pbt.assert_check(\"" +
    test_name +
    "\", gen, fn(x : " +
    type_name +
    ") {\n    if " +
    decoder +
    "(" +
    encoder +
    "(x)) == x {\n      Ok(())\n    } else {\n      Err(\"roundtrip mismatch\")\n    }\n  })\n}"
  {
    name: test_name,
    code: test_code,
    description: "Round-trip property: encode then decode should return original value",
  }
}

///|
/// べき等性プロパティテストを生成
pub fn generate_idempotent_test(
  func : String,
  type_name : String,
) -> GeneratedTest {
  let test_name = "prop_" + func + "_idempotent"
  let test_code = "test \"" +
    test_name +
    "\" {\n  let gen : @pbt.Gen[" +
    type_name +
    "] = @pbt.Gen::arbitrary()\n  @pbt.assert_check(\"" +
    test_name +
    "\", gen, fn(x : " +
    type_name +
    ") {\n    if " +
    func +
    "(" +
    func +
    "(x)) == " +
    func +
    "(x) {\n      Ok(())\n    } else {\n      Err(\"idempotent mismatch\")\n    }\n  })\n}"
  {
    name: test_name,
    code: test_code,
    description: "Idempotent property: applying function twice should be same as applying once",
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
      result = result + "```moonbit test\n" + t.code + "\n```\n\n"
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
/// PatternCandidate から GeneratedTest を生成
pub fn pattern_to_test(
  pattern : @patterns.PatternCandidate,
  type_name : String,
) -> GeneratedTest {
  match pattern {
    @patterns.RoundTrip(encoder, decoder) =>
      generate_round_trip_test(encoder, decoder, type_name)
    @patterns.Idempotent(func) => generate_idempotent_test(func, type_name)
    @patterns.ProducerConsumer(producer, consumer) =>
      generate_producer_consumer_test(producer, consumer, type_name)
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
  let test_code = "test \"" +
    test_name +
    "\" {\n  let gen : @pbt.Gen[" +
    type_name +
    "] = @pbt.Gen::arbitrary()\n  @pbt.assert_check(\"" +
    test_name +
    "\", gen, fn(x : " +
    type_name +
    ") {\n    let produced = " +
    producer +
    "(x)\n    let _ = " +
    consumer +
    "(produced)\n    Ok(())\n  })\n}"
  {
    name: test_name,
    code: test_code,
    description: "Pipeline property: producer output is valid consumer input",
  }
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
  }
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
  let mut test_cases : Array[GeneratedTest] = []
  let mut detected : Array[DetectedPattern] = []
  let mut i = 0
  while i < patterns.length() {
    let pattern = patterns[i]
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
/// PbtDocument から完全なMarkdown文字列を生成
pub fn generate_pbt_md(doc : PbtDocument) -> String {
  let mut result = "# Property-Based Tests for " + doc.module_name + "\n\n"
  result = result + "> Auto-generated by Aletheia - MoonBit PBT Tool\n\n"
  result = result + "## Overview\n\n"
  result = result + "- **Source**: `" + doc.source_file + "`\n"
  result = result + "- **Generated**: " + doc.generated_at + "\n"
  result = result +
    "- **Patterns Detected**: " +
    doc.patterns.length().to_string() +
    "\n"
  result = result + "- **Runtime**: import `f4ah6o/aletheia/pbt` as `@pbt`\n\n"

  // パターン別にセクションを生成
  let roundtrips = filter_by_name_suffix(doc.test_cases, "roundtrip")
  let idempotents = filter_by_name_suffix(doc.test_cases, "idempotent")
  let pipelines = filter_by_name_suffix(doc.test_cases, "pipeline")
  if roundtrips.length() > 0 {
    result = result + "## Round-Trip Properties\n\n"
    let mut i = 0
    while i < roundtrips.length() {
      let t = roundtrips[i]
      result = result + "### " + t.name + "\n\n"
      result = result + t.description + "\n\n"
      result = result + "```moonbit test\n" + t.code + "\n```\n\n"
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
      result = result + "```moonbit test\n" + t.code + "\n```\n\n"
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
      result = result + "```moonbit test\n" + t.code + "\n```\n\n"
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
  result = result +
    "## Notes\n\n" +
    "- Property definitions are intentionally omitted. Define them in a separate process.\n"
  result
}

///|
/// テスト
test "generate_round_trip_test_basic" {
  let result = generate_round_trip_test("encode", "decode", "Data")
  inspect(result.name, content="prop_encode_decode_roundtrip")
  inspect(result.code.contains("decode(encode(x))"), content="true")
}

///|
test "generate_idempotent_test_basic" {
  let result = generate_idempotent_test("sort", "Array[Int]")
  inspect(result.name, content="prop_sort_idempotent")
  inspect(result.code.contains("sort(sort(x))"), content="true")
}

///|
test "generate_mbt_md_section" {
  let test1 = generate_round_trip_test("to_json", "from_json", "User")
  let test2 = generate_idempotent_test("normalize", "String")
  let input_tests = [test1, test2]
  let result = generate_mbt_md_section(input_tests)
  inspect(result.contains("Property Tests"), content="true")
}

///|
test "generate_round_trip_test_escapes_braces" {
  let result = generate_round_trip_test("save", "load", "Config")
  inspect(result.code.contains("{"), content="true")
  inspect(result.code.contains("x)"), content="true")
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
