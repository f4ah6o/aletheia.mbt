///|
/// QuickCheck ジェネレータ式モジュール（Phase 1.2）
/// 型に応じた適切なQuickCheckジェネレータ式を生成する
///

///|
/// 型に応じたQuickCheckジェネレータ式を生成
pub fn generator_expression_for_type(type_name : String) -> String {
  match type_name {
    "Int" => "@pbt.Gen::choose_int(-100, 100)"
    "Int64" =>
      "@pbt.Gen::map(@pbt.Gen::choose_int(-100, 100), fn(x : Int) { Int64::from_int(x) })"
    "UInt" =>
      "@pbt.Gen::map(@pbt.Gen::choose_int(0, 100), fn(x : Int) { x.to_uint() })"
    "UInt64" =>
      "@pbt.Gen::map(@pbt.Gen::choose_int(0, 100), fn(x : Int) { UInt64::from_int(x) })"
    "Float" => "@pbt.Gen::choose_float(-100.0, 100.0)"
    "Double" => "@pbt.Gen::choose_float(-100.0, 100.0)"
    "Bool" => "@pbt.Gen::one_of([@pbt.Gen::pure(true), @pbt.Gen::pure(false)])"
    "Char" => "@pbt.Gen::choose_char(32, 126)"
    "String" => "@pbt.Gen::string(@pbt.Gen::choose_char(32, 126))"
    "Byte" => "@pbt.Gen::choose_byte(0, 255)"
    "Array[Int]" => "@pbt.Gen::array_of(@pbt.Gen::choose_int(-100, 100))"
    "Array[String]" =>
      "@pbt.Gen::array_of(@pbt.Gen::string(@pbt.Gen::choose_char(32, 126)))"
    "Array[Bool]" =>
      "@pbt.Gen::array_of(@pbt.Gen::one_of([@pbt.Gen::pure(true), @pbt.Gen::pure(false)]))"
    "Array[Char]" => "@pbt.Gen::array_of(@pbt.Gen::choose_char(32, 126))"
    "List[Int]" => "@pbt.Gen::list_of(@pbt.Gen::choose_int(-100, 100))"
    "List[String]" =>
      "@pbt.Gen::list_of(@pbt.Gen::string(@pbt.Gen::choose_char(32, 126)))"
    "Option[Int]" => "@pbt.Gen::option_of(@pbt.Gen::choose_int(-100, 100))"
    "Option[String]" =>
      "@pbt.Gen::option_of(@pbt.Gen::string(@pbt.Gen::choose_char(32, 126)))"
    "Result[Int, String]" =>
      "@pbt.Gen::result_of(@pbt.Gen::choose_int(-100, 100), @pbt.Gen::string(@pbt.Gen::choose_char(32, 126)))"
    _ =>
      // コンテナ型の簡易パース
      if type_name.has_prefix("Array[") {
        let inner = extract_type_parameter(type_name, "Array[")
        "@pbt.Gen::array_of(" + generator_expression_for_type(inner) + ")"
      } else if type_name.has_prefix("List[") {
        let inner = extract_type_parameter(type_name, "List[")
        "@pbt.Gen::list_of(" + generator_expression_for_type(inner) + ")"
      } else if type_name.has_prefix("Option[") {
        let inner = extract_type_parameter(type_name, "Option[")
        "@pbt.Gen::option_of(" + generator_expression_for_type(inner) + ")"
      } else {
        // ユーザー定義型はArbitrary実装に依存
        "@pbt.Gen::arbitrary()"
      }
  }
}

///|
/// 型パラメータを抽出（簡易実装）
/// 例: "Array[Int]" -> "Int"
fn extract_type_parameter(type_str : String, prefix : String) -> String {
  let start = prefix.length()
  let inner = substring_range(type_str, start, type_str.length() - 1)
  inner
}

///|
/// 文字列の範囲を抽出
fn substring_range(s : String, start : Int, end : Int) -> String {
  let chars = s.to_array()
  let mut result = ""
  let mut i = start
  while i < end {
    result = result + chars[i].to_string()
    i = i + 1
  }
  result
}

///|
/// 型がプリミティブ型か判定
pub fn is_primitive_type(type_name : String) -> Bool {
  let primitives = [
    "Int", "Int64", "UInt", "UInt64", "Float", "Double", "Bool", "Char", "String",
    "Byte",
  ]
  let mut i = 0
  while i < primitives.length() {
    if primitives[i] == type_name {
      return true
    }
    i = i + 1
  }
  false
}

///|
/// 型がコンテナ型か判定
pub fn is_container_type(type_name : String) -> Bool {
  type_name.has_prefix("Array[") ||
  type_name.has_prefix("List[") ||
  type_name.has_prefix("Option[") ||
  type_name.has_prefix("Result[") ||
  type_name.has_prefix("Map[")
}

///|
/// テスト
test "generator_expression_for_primitive_types" {
  inspect(
    generator_expression_for_type("Int"),
    content="@pbt.Gen::choose_int(-100, 100)",
  )
  inspect(
    generator_expression_for_type("String"),
    content="@pbt.Gen::string(@pbt.Gen::choose_char(32, 126))",
  )
  inspect(
    generator_expression_for_type("Bool"),
    content="@pbt.Gen::one_of([@pbt.Gen::pure(true), @pbt.Gen::pure(false)])",
  )
}

///|
test "generator_expression_for_container_types" {
  inspect(
    generator_expression_for_type("Array[Int]"),
    content="@pbt.Gen::array_of(@pbt.Gen::choose_int(-100, 100))",
  )
  inspect(
    generator_expression_for_type("List[String]"),
    content="@pbt.Gen::list_of(@pbt.Gen::string(@pbt.Gen::choose_char(32, 126)))",
  )
}

///|
test "is_primitive_type" {
  inspect(is_primitive_type("Int"), content="true")
  inspect(is_primitive_type("String"), content="true")
  inspect(is_primitive_type("Array[Int]"), content="false")
  inspect(is_primitive_type("MyType"), content="false")
}

///|
test "is_container_type" {
  inspect(is_container_type("Array[Int]"), content="true")
  inspect(is_container_type("List[String]"), content="true")
  inspect(is_container_type("Option[Bool]"), content="true")
  inspect(is_container_type("Int"), content="false")
  inspect(is_container_type("String"), content="false")
}
