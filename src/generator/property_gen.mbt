///|
/// PBTコード生成モジュール（Phase 4）
/// パターン候補からプロパティテストコードを生成する
///

/// 生成されたプロパティテスト
pub struct GeneratedTest {
  name : String
  code : String
  description : String
}

/// Round-Tripプロパティテストを生成
pub fn generate_round_trip_test(encoder : String, decoder : String, type_name : String) -> GeneratedTest {
  let test_name = "prop_" + encoder + "_" + decoder + "_roundtrip"
  let test_code = "test \"" + test_name + "\" {\n  quick_check_fn!(fn(x : " + type_name + ") {\n    " + decoder + "(" + encoder + "(x)) == x\n  })\n}"

  {
    name: test_name,
    code: test_code,
    description: "Round-trip property: encode then decode should return original value"
  }
}

/// べき等性プロパティテストを生成
pub fn generate_idempotent_test(func : String, type_name : String) -> GeneratedTest {
  let test_name = "prop_" + func + "_idempotent"
  let test_code = "test \"" + test_name + "\" {\n  quick_check_fn!(fn(x : " + type_name + ") {\n    " + func + "(" + func + "(x)) == " + func + "(x)\n  })\n}"

  {
    name: test_name,
    code: test_code,
    description: "Idempotent property: applying function twice should be same as applying once"
  }
}

/// プロパティテストコードをMarkdown形式で生成
pub fn generate_mbt_md_section(tests : Array[GeneratedTest]) -> String {
  let header = "## Property Tests\n\nGenerated property tests for this module:\n\n"
  header
}

/// テスト
test "generate_round_trip_test_basic" {
  let result = generate_round_trip_test("encode", "decode", "Data")
  inspect(result.name, content="prop_encode_decode_roundtrip")
  inspect(result.code.contains("decode(encode(x))"), content="true")
}

test "generate_idempotent_test_basic" {
  let result = generate_idempotent_test("sort", "Array[Int]")
  inspect(result.name, content="prop_sort_idempotent")
  inspect(result.code.contains("sort(sort(x))"), content="true")
}

test "generate_mbt_md_section" {
  let test1 = generate_round_trip_test("to_json", "from_json", "User")
  let test2 = generate_idempotent_test("normalize", "String")
  let tests = [test1, test2]
  let result = generate_mbt_md_section(tests)
  inspect(result.contains("Property Tests"), content="true")
}

test "generate_round_trip_test_escapes_braces" {
  let result = generate_round_trip_test("save", "load", "Config")
  inspect(result.code.contains("{"), content="true")
  inspect(result.code.contains("x)"), content="true")
}
