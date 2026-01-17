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
/// Generate frequency-based generator expression with edge case emphasis
/// Distribution: 70% normal, 15% empty/zero, 15% boundary values
pub fn frequency_generator_for_type(type_name : String) -> String {
  match type_name {
    "Int" => {
      let mut r = "@pbt.frequency([\n"
      r = r + "    (70, @pbt.Gen::choose_int(-100, 100)),\n"
      r = r + "    (10, @pbt.Gen::pure(0)),\n"
      r = r + "    (10, @pbt.Gen::pure(1)),\n"
      r = r + "    (5, @pbt.Gen::pure(-1)),\n"
      r = r + "    (5, @pbt.Gen::one_of([\n"
      r = r + "      @pbt.Gen::pure(2147483647),\n"
      r = r + "      @pbt.Gen::pure(-2147483648)\n"
      r = r + "    ]))\n"
      r = r + "  ])"
      r
    }
    "Int64" => {
      let mut r = "@pbt.frequency([\n"
      r = r +
        "    (70, @pbt.Gen::map(@pbt.Gen::choose_int(-100, 100), fn(x : Int) { Int64::from_int(x) })),\n"
      r = r + "    (10, @pbt.Gen::pure(0L)),\n"
      r = r + "    (10, @pbt.Gen::pure(1L)),\n"
      r = r + "    (5, @pbt.Gen::pure(-1L)),\n"
      r = r + "    (5, @pbt.Gen::one_of([\n"
      r = r + "      @pbt.Gen::pure(9223372036854775807L),\n"
      r = r + "      @pbt.Gen::pure(-9223372036854775808L)\n"
      r = r + "    ]))\n"
      r = r + "  ])"
      r
    }
    "UInt" => {
      let mut r = "@pbt.frequency([\n"
      r = r +
        "    (70, @pbt.Gen::map(@pbt.Gen::choose_int(0, 100), fn(x : Int) { x.to_uint() })),\n"
      r = r + "    (15, @pbt.Gen::pure(0u)),\n"
      r = r + "    (10, @pbt.Gen::pure(1u)),\n"
      r = r + "    (5, @pbt.Gen::pure(4294967295u))\n"
      r = r + "  ])"
      r
    }
    "UInt64" => {
      let mut r = "@pbt.frequency([\n"
      r = r +
        "    (70, @pbt.Gen::map(@pbt.Gen::choose_int(0, 100), fn(x : Int) { UInt64::from_int(x) })),\n"
      r = r + "    (15, @pbt.Gen::pure(0UL)),\n"
      r = r + "    (10, @pbt.Gen::pure(1UL)),\n"
      r = r + "    (5, @pbt.Gen::pure(18446744073709551615UL))\n"
      r = r + "  ])"
      r
    }
    "Float" => {
      let mut r = "@pbt.frequency([\n"
      r = r + "    (70, @pbt.Gen::choose_float(-100.0, 100.0)),\n"
      r = r + "    (15, @pbt.Gen::pure(0.0)),\n"
      r = r + "    (10, @pbt.Gen::pure(1.0)),\n"
      r = r + "    (5, @pbt.Gen::one_of([\n"
      r = r + "      @pbt.Gen::pure(-1.0),\n"
      r = r + "      @pbt.Gen::pure(0.1)\n"
      r = r + "    ]))\n"
      r = r + "  ])"
      r
    }
    "Double" => {
      let mut r = "@pbt.frequency([\n"
      r = r + "    (70, @pbt.Gen::choose_float(-100.0, 100.0)),\n"
      r = r + "    (15, @pbt.Gen::pure(0.0)),\n"
      r = r + "    (10, @pbt.Gen::pure(1.0)),\n"
      r = r + "    (5, @pbt.Gen::one_of([\n"
      r = r + "      @pbt.Gen::pure(-1.0),\n"
      r = r + "      @pbt.Gen::pure(0.1)\n"
      r = r + "    ]))\n"
      r = r + "  ])"
      r
    }
    "Bool" => {
      let mut r = "@pbt.frequency([\n"
      r = r + "    (50, @pbt.Gen::pure(true)),\n"
      r = r + "    (50, @pbt.Gen::pure(false))\n"
      r = r + "  ])"
      r
    }
    "Char" => {
      let mut r = "@pbt.frequency([\n"
      r = r + "    (70, @pbt.Gen::choose_char(32, 126)),\n"
      r = r + "    (15, @pbt.Gen::pure(' ')),\n"
      r = r + "    (10, @pbt.Gen::pure('a')),\n"
      r = r + "    (5, @pbt.Gen::one_of([\n"
      r = r + "      @pbt.Gen::pure('\\n'),\n"
      r = r + "      @pbt.Gen::pure('\\t')\n"
      r = r + "    ]))\n"
      r = r + "  ])"
      r
    }
    "String" => {
      let mut r = "@pbt.frequency([\n"
      r = r + "    (70, @pbt.Gen::string(@pbt.Gen::choose_char(32, 126))),\n"
      r = r + "    (15, @pbt.Gen::pure(\"\")),\n"
      r = r +
        "    (10, @pbt.Gen::string_of_length(1, @pbt.Gen::choose_char(32, 126))),\n"
      r = r + "    (5, @pbt.Gen::one_of([\n"
      r = r + "      @pbt.Gen::pure(\" \\n\\t\"),\n"
      r = r + "      @pbt.Gen::pure(\"a\")\n"
      r = r + "    ]))\n"
      r = r + "  ])"
      r
    }
    "Byte" => {
      let mut r = "@pbt.frequency([\n"
      r = r + "    (70, @pbt.Gen::choose_byte(0, 255)),\n"
      r = r + "    (15, @pbt.Gen::pure(0uy)),\n"
      r = r + "    (10, @pbt.Gen::pure(1uy)),\n"
      r = r + "    (5, @pbt.Gen::pure(255uy))\n"
      r = r + "  ])"
      r
    }
    _ =>
      // コンテナ型の場合は要素型のジェネレータを取得
      if type_name.has_prefix("Array[") {
        let inner = extract_type_parameter(type_name, "Array[")
        let mut r = "@pbt.frequency([\n"
        r = r +
          "    (70, @pbt.Gen::array_of(" +
          generator_expression_for_type(inner) +
          ")),\n"
        r = r + "    (20, @pbt.Gen::pure([])),\n"
        r = r +
          "    (10, @pbt.Gen::array_of(@pbt.Gen::constant(" +
          inner +
          "::default())))\n"
        r = r + "  ])"
        r
      } else if type_name.has_prefix("List[") {
        let inner = extract_type_parameter(type_name, "List[")
        let mut r = "@pbt.frequency([\n"
        r = r +
          "    (70, @pbt.Gen::list_of(" +
          generator_expression_for_type(inner) +
          ")),\n"
        r = r + "    (20, @pbt.Gen::pure([])),\n"
        r = r +
          "    (10, @pbt.Gen::list_of(@pbt.Gen::constant(" +
          inner +
          "::default())))\n"
        r = r + "  ])"
        r
      } else if type_name.has_prefix("Option[") {
        let inner = extract_type_parameter(type_name, "Option[")
        let mut r = "@pbt.frequency([\n"
        r = r +
          "    (60, @pbt.Gen::option_of(" +
          generator_expression_for_type(inner) +
          ")),\n"
        r = r + "    (40, @pbt.Gen::pure(None))\n"
        r = r + "  ])"
        r
      } else {
        // ユーザー定義型はArbitrary実装に依存
        "@pbt.Gen::arbitrary()"
      }
  }
}

///|
/// Detect if type is potentially recursive (needs size control)
pub fn is_recursive_type(type_name : String) -> Bool {
  // Known recursive types
  let recursive_keywords = [
    "Tree", "Node", "Graph", "LinkedList", "Nested", "Recursive",
  ]
  let mut i = 0
  while i < recursive_keywords.length() {
    if has_substring(type_name, recursive_keywords[i]) {
      return true
    }
    i = i + 1
  }
  // Deeply nested container types
  if has_substring(type_name, "Array[Array[") ||
    has_substring(type_name, "List[List[") ||
    has_substring(type_name, "Array[Option[") ||
    has_substring(type_name, "Option[Array[") {
    true
  } else {
    false
  }
}

///|
/// Generate size-controlled generator expression for complex types
/// Distribution: Uses @pbt.sized to control generation depth/size
pub fn sized_generator_for_type(type_name : String) -> String {
  if is_recursive_type(type_name) {
    let mut r = "@pbt.sized(fn(size : Int) -> @pbt.Gen["
    r = r + type_name
    r = r + "] {\n"
    r = r + "  let max_depth = min(size, 5)\n"
    r = r + "  "
    r = r + generate_sized_variant(type_name, "max_depth")
    r = r + "\n})"
    r
  } else {
    // For non-recursive types, use frequency generator
    frequency_generator_for_type(type_name)
  }
}

///|
/// Generate size-controlled variant for recursive types
fn generate_sized_variant(type_name : String, size_var : String) -> String {
  match type_name {
    t if t.has_prefix("Array[") => {
      let inner = extract_type_parameter(type_name, "Array[")
      if is_recursive_type(inner) {
        // Nested array: limit both dimensions
        "@pbt.Gen::array_of_with_size(" +
        size_var +
        ", " +
        sized_generator_for_type(inner) +
        ")"
      } else {
        "@pbt.Gen::array_of_with_size(" +
        size_var +
        ", " +
        generator_expression_for_type(inner) +
        ")"
      }
    }
    t if t.has_prefix("List[") => {
      let inner = extract_type_parameter(type_name, "List[")
      if is_recursive_type(inner) {
        "@pbt.Gen::list_of_with_size(" +
        size_var +
        ", " +
        sized_generator_for_type(inner) +
        ")"
      } else {
        "@pbt.Gen::list_of_with_size(" +
        size_var +
        ", " +
        generator_expression_for_type(inner) +
        ")"
      }
    }
    _ =>
      // For user-defined recursive types, suggest custom implementation
      "// TODO: Implement sized generator for " +
      type_name +
      "\n  // Use depth-limited generation to avoid infinite recursion\n  @pbt.Gen::arbitrary()"
  }
}

///|
/// Calculate safe nesting depth for type
pub fn safe_nesting_depth(type_name : String) -> Int {
  if has_substring(type_name, "Array[Array[") {
    2 // Limit nested arrays
  } else if has_substring(type_name, "List[List[") {
    2 // Limit nested lists
  } else if has_substring(type_name, "Tree") || has_substring(type_name, "Node") {
    3 // Allow deeper trees but limit
  } else {
    5 // Default limit
  }
}

///|
/// Helper function to check if string contains substring
fn has_substring(s : String, pattern : String) -> Bool {
  let s_len = s.length()
  let pat_len = pattern.length()
  if s_len < pat_len {
    false
  } else if pat_len == 0 {
    true
  } else {
    let mut i = 0
    while i <= s_len - pat_len {
      let mut j = 0
      let mut found = true
      while j < pat_len {
        let s_chars = s.to_array()
        let pat_chars = pattern.to_array()
        if s_chars[i + j] != pat_chars[j] {
          found = false
        }
        j = j + 1
      }
      if found {
        return true
      }
      i = i + 1
    }
    false
  }
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

///|
test "frequency_generator_for_int" {
  let result = frequency_generator_for_type("Int")
  inspect(result.contains("@pbt.frequency"), content="true")
  inspect(result.contains("@pbt.Gen::pure(0)"), content="true")
  inspect(result.contains("@pbt.Gen::pure(1)"), content="true")
  inspect(result.contains("@pbt.Gen::pure(-1)"), content="true")
  inspect(result.contains("2147483647"), content="true")
  inspect(result.contains("-2147483648"), content="true")
}

///|
test "frequency_generator_for_string" {
  let result = frequency_generator_for_type("String")
  inspect(result.contains("@pbt.frequency"), content="true")
  inspect(result.contains("@pbt.Gen::pure(\"\")"), content="true")
  inspect(result.contains("@pbt.Gen::string_of_length"), content="true")
  inspect(
    result.contains("@pbt.Gen::string(@pbt.Gen::choose_char(32, 126))"),
    content="true",
  )
}

///|
test "frequency_generator_for_array" {
  let result = frequency_generator_for_type("Array[Int]")
  inspect(result.contains("@pbt.frequency"), content="true")
  inspect(result.contains("@pbt.Gen::pure([])"), content="true")
  inspect(result.contains("@pbt.Gen::array_of"), content="true")
}

///|
test "frequency_generator_for_option" {
  let result = frequency_generator_for_type("Option[Int]")
  inspect(result.contains("@pbt.frequency"), content="true")
  inspect(result.contains("@pbt.Gen::pure(None)"), content="true")
  inspect(result.contains("@pbt.Gen::option_of"), content="true")
}

///|
test "is_recursive_type_tree" {
  inspect(is_recursive_type("TreeNode"), content="true")
  inspect(is_recursive_type("BinaryTree"), content="true")
  inspect(is_recursive_type("LinkedList"), content="true")
  inspect(is_recursive_type("Graph"), content="true")
}

///|
test "is_recursive_type_nested_containers" {
  inspect(is_recursive_type("Array[Array[Int]]"), content="true")
  inspect(is_recursive_type("List[List[String]]"), content="true")
  inspect(is_recursive_type("Array[Option[Int]]"), content="true")
  inspect(is_recursive_type("Option[Array[Int]]"), content="true")
}

///|
test "is_recursive_type_simple" {
  inspect(is_recursive_type("Int"), content="false")
  inspect(is_recursive_type("String"), content="false")
  inspect(is_recursive_type("Array[Int]"), content="false")
  inspect(is_recursive_type("Option[Bool]"), content="false")
}

///|
test "sized_generator_for_recursive_type" {
  let result = sized_generator_for_type("BinaryTree")
  inspect(result.contains("@pbt.sized"), content="true")
  inspect(result.contains("max_depth"), content="true")
}

///|
test "sized_generator_for_nested_array" {
  let result = sized_generator_for_type("Array[Array[Int]]")
  inspect(result.contains("@pbt.sized"), content="true")
  inspect(result.contains("array_of_with_size"), content="true")
}

///|
test "sized_generator_for_simple_type_uses_frequency" {
  let result = sized_generator_for_type("Int")
  inspect(result.contains("@pbt.frequency"), content="true")
  inspect(result.contains("@pbt.Gen::pure(0)"), content="true")
}

///|
test "safe_nesting_depth_calculation" {
  inspect(safe_nesting_depth("Array[Array[Int]]"), content="2")
  inspect(safe_nesting_depth("List[List[String]]"), content="2")
  inspect(safe_nesting_depth("TreeNode"), content="3")
  inspect(safe_nesting_depth("Int"), content="5")
}
