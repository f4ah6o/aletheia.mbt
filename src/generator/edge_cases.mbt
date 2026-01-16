///|
/// エッジケース生成モジュール（Phase 2.2）
/// 型に応じたエッジケースを自動生成する
///

///|
/// エッジケース定義
pub struct EdgeCase {
  value_expr : String
  description : String
}

///|
/// Frequency distribution entry
pub struct FrequencyEntry {
  weight : Int
  generator_expr : String
}

///|
/// 型に応じたエッジケースを生成
pub fn edge_cases_for_type(type_name : String) -> Array[EdgeCase] {
  match type_name {
    "Int" => int_edge_cases()
    "Int64" => int64_edge_cases()
    "UInt" => uint_edge_cases()
    "UInt64" => uint64_edge_cases()
    "Float" => float_edge_cases()
    "Double" => double_edge_cases()
    "Bool" => bool_edge_cases()
    "Char" => char_edge_cases()
    "String" => string_edge_cases()
    "Byte" => byte_edge_cases()
    "Array[Int]" => array_int_edge_cases()
    "Array[String]" => array_string_edge_cases()
    "Array[Bool]" => array_bool_edge_cases()
    "List[Int]" => list_int_edge_cases()
    "List[String]" => list_string_edge_cases()
    "Option[Int]" => option_int_edge_cases()
    "Option[String]" => option_string_edge_cases()
    _ => []
  }
}

///|
/// Int型のエッジケース
fn int_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "0", description: "zero" },
    { value_expr: "1", description: "one" },
    { value_expr: "-1", description: "negative_one" },
    { value_expr: "1000", description: "large_positive" },
    { value_expr: "-1000", description: "large_negative" },
    { value_expr: "2147483647", description: "max_int" },
    { value_expr: "-2147483648", description: "min_int" },
  ]
}

///|
/// Int64型のエッジケース
fn int64_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "0L", description: "zero" },
    { value_expr: "1L", description: "one" },
    { value_expr: "-1L", description: "negative_one" },
    { value_expr: "1000L", description: "large_positive" },
    { value_expr: "-1000L", description: "large_negative" },
    { value_expr: "9223372036854775807L", description: "max_int64" },
    { value_expr: "-9223372036854775808L", description: "min_int64" },
  ]
}

///|
/// UInt型のエッジケース
fn uint_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "0u", description: "zero" },
    { value_expr: "1u", description: "one" },
    { value_expr: "1000u", description: "large_positive" },
    { value_expr: "4294967295u", description: "max_uint" },
  ]
}

///|
/// UInt64型のエッジケース
fn uint64_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "0UL", description: "zero" },
    { value_expr: "1UL", description: "one" },
    { value_expr: "1000UL", description: "large_positive" },
    { value_expr: "18446744073709551615UL", description: "max_uint64" },
  ]
}

///|
/// Float型のエッジケース
fn float_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "0.0", description: "zero" },
    { value_expr: "1.0", description: "one" },
    { value_expr: "-1.0", description: "negative_one" },
    { value_expr: "0.1", description: "small_positive" },
    { value_expr: "-0.1", description: "small_negative" },
    { value_expr: "3.14159", description: "pi" },
  ]
}

///|
/// Double型のエッジケース
fn double_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "0.0", description: "zero" },
    { value_expr: "1.0", description: "one" },
    { value_expr: "-1.0", description: "negative_one" },
    { value_expr: "0.1", description: "small_positive" },
    { value_expr: "-0.1", description: "small_negative" },
    { value_expr: "3.14159265359", description: "pi" },
  ]
}

///|
/// Bool型のエッジケース
fn bool_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "true", description: "true" },
    { value_expr: "false", description: "false" },
  ]
}

///|
/// Char型のエッジケース
fn char_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "'a'", description: "lowercase_letter" },
    { value_expr: "'Z'", description: "uppercase_letter" },
    { value_expr: "'0'", description: "digit" },
    { value_expr: "' '", description: "space" },
    { value_expr: "'\\n'", description: "newline" },
    { value_expr: "'\\t'", description: "tab" },
  ]
}

///|
/// String型のエッジケース
fn string_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "\"\"", description: "empty_string" },
    { value_expr: "\"a\"", description: "single_char" },
    { value_expr: "\" \"", description: "space" },
    { value_expr: "\"日本語\"", description: "unicode" },
    { value_expr: "\"a\\nb\"", description: "multiline" },
    { value_expr: "\"\\\"quoted\\\"\"", description: "quoted" },
  ]
}

///|
/// Byte型のエッジケース
fn byte_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "0uy", description: "zero" },
    { value_expr: "1uy", description: "one" },
    { value_expr: "255uy", description: "max_byte" },
  ]
}

///|
/// Array[Int]型のエッジケース
fn array_int_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "[]", description: "empty_array" },
    { value_expr: "[0]", description: "single_element_zero" },
    { value_expr: "[1]", description: "single_element_one" },
    { value_expr: "[1, 2, 3]", description: "small_array" },
    { value_expr: "[0, 1, -1]", description: "mixed_values" },
  ]
}

///|
/// Array[String]型のエッジケース
fn array_string_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "[]", description: "empty_array" },
    { value_expr: "[\"\"]", description: "array_with_empty" },
    { value_expr: "[\"a\"]", description: "single_element" },
    { value_expr: "[\"a\", \"b\", \"c\"]", description: "small_array" },
    { value_expr: "[\"\", \"a\", \"\"]", description: "mixed_with_empty" },
  ]
}

///|
/// Array[Bool]型のエッジケース
fn array_bool_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "[]", description: "empty_array" },
    { value_expr: "[true]", description: "single_true" },
    { value_expr: "[false]", description: "single_false" },
    { value_expr: "[true, false]", description: "mixed_bools" },
  ]
}

///|
/// List[Int]型のエッジケース
fn list_int_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "[]", description: "empty_list" },
    { value_expr: "[0]", description: "single_element_zero" },
    { value_expr: "[1, 2, 3]", description: "small_list" },
  ]
}

///|
/// List[String]型のエッジケース
fn list_string_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "[]", description: "empty_list" },
    { value_expr: "[\"\"]", description: "list_with_empty" },
    { value_expr: "[\"a\", \"b\"]", description: "small_list" },
  ]
}

///|
/// Option[Int]型のエッジケース
fn option_int_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "None", description: "none" },
    { value_expr: "Some(0)", description: "some_zero" },
    { value_expr: "Some(1)", description: "some_one" },
    { value_expr: "Some(-1)", description: "some_negative" },
  ]
}

///|
/// Option[String]型のエッジケース
fn option_string_edge_cases() -> Array[EdgeCase] {
  [
    { value_expr: "None", description: "none" },
    { value_expr: "Some(\"\")", description: "some_empty" },
    { value_expr: "Some(\"a\")", description: "some_value" },
  ]
}

///|
/// テスト
test "edge_cases_for_int" {
  let cases = edge_cases_for_type("Int")
  inspect(cases.length(), content="7")
  inspect(cases[0].value_expr, content="0")
  inspect(cases[0].description, content="zero")
  inspect(cases[1].value_expr, content="1")
  inspect(cases[1].description, content="one")
}

///|
test "edge_cases_for_string" {
  let cases = edge_cases_for_type("String")
  inspect(cases.length(), content="6")
  inspect(cases[0].value_expr, content="\"\"")
  inspect(cases[0].description, content="empty_string")
}

///|
test "edge_cases_for_array_int" {
  let cases = edge_cases_for_type("Array[Int]")
  inspect(cases.length(), content="5")
  inspect(cases[0].value_expr, content="[]")
  inspect(cases[0].description, content="empty_array")
}

///|
test "edge_cases_for_unknown_type" {
  let cases = edge_cases_for_type("MyType")
  inspect(cases.length(), content="0")
}

///|
/// Convert edge cases to frequency distribution
/// Returns: [(weight, generator_expr)]
pub fn edge_cases_to_frequency(
  edge_cases : Array[EdgeCase],
) -> Array[FrequencyEntry] {
  let result : Array[FrequencyEntry] = []
  let mut i = 0
  while i < edge_cases.length() {
    let ec = edge_cases[i]
    Array::push(result, { weight: 10, generator_expr: "@pbt.Gen::pure(" + ec.value_expr + ")" })
    i = i + 1
  }
  result
}

///|
/// Build frequency distribution from type using edge cases
pub fn build_frequency_for_type(type_name : String) -> String {
  let edge_cases = edge_cases_for_type(type_name)
  let mut result = "@pbt.frequency([\n"
  // Add normal case with high weight
  result = result + "    (70, " + generator_expression_for_type(type_name) + "),\n"
  // Add edge cases with lower weight
  let mut i = 0
  while i < edge_cases.length() {
    let ec = edge_cases[i]
    result = result + "    (10, @pbt.Gen::pure(" + ec.value_expr + "))"
    if i < edge_cases.length() - 1 {
      result = result + ","
    }
    result = result + "\n"
    i = i + 1
  }
  result = result + "  ])"
  result
}

///|
test "edge_cases_to_frequency_int" {
  let cases = edge_cases_for_type("Int")
  let freq = edge_cases_to_frequency(cases)
  inspect(freq.length(), content="7")
  inspect(freq[0].weight, content="10")
  inspect(freq[0].generator_expr.contains("@pbt.Gen::pure(0)"), content="true")
  inspect(freq[1].generator_expr.contains("@pbt.Gen::pure(1)"), content="true")
}

///|
test "edge_cases_to_frequency_string" {
  let cases = edge_cases_for_type("String")
  let freq = edge_cases_to_frequency(cases)
  inspect(freq.length(), content="6")
  inspect(freq[0].weight, content="10")
  inspect(freq[0].generator_expr.contains("@pbt.Gen::pure(\"\")"), content="true")
}

///|
test "build_frequency_for_type_int" {
  let result = build_frequency_for_type("Int")
  inspect(result.contains("@pbt.frequency"), content="true")
  inspect(result.contains("@pbt.Gen::choose_int(-100, 100)"), content="true")
  inspect(result.contains("@pbt.Gen::pure(0)"), content="true")
  inspect(result.contains("@pbt.Gen::pure(2147483647)"), content="true")
}
