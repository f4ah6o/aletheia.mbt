///|
/// Arbitrary実装検出モジュール（Phase 1）
/// ソースコードからimpl Arbitrary for Tを検出し、型のテスト可能性を判定する
///

///|
/// プリミティブ型のArbitrary実装リスト（quickcheckに組み込み）
pub fn primitive_types() -> Array[String] {
  [
    "Int", "Int64", "UInt", "UInt64", "Float", "Double", "Bool", "Char", "String",
    "Byte",
  ]
}

///|
/// コンテナ型のパターン（型パラメータを取る）
pub fn container_patterns() -> Array[String] {
  ["Array", "List", "Map", "Set", "Option", "Result"]
}

///|
/// ソースコードからArbitrary実装を検出
pub fn detect_arbitrary_impls(source : String) -> Array[@ast.ArbitraryImpl] {
  let mut result : Array[@ast.ArbitraryImpl] = []

  // プリミティブ型を追加
  let primitives = primitive_types()
  let mut i = 0
  while i < primitives.length() {
    result = push_arb(result, @ast.ArbitraryImpl::primitive(primitives[i]))
    i = i + 1
  }

  // ユーザー定義のimplを検出
  let lines = split_lines(source)
  let mut line_num = 0
  while line_num < lines.length() {
    let line = lines[line_num]
    match extract_arbitrary_impl(line) {
      Some(type_name) => {
        let arb_impl = @ast.ArbitraryImpl::user_defined(type_name, line_num)
        result = push_arb(result, arb_impl)
      }
      None => ()
    }
    line_num = line_num + 1
  }
  result
}

///|
/// "impl Arbitrary for T" または "impl @quickcheck.Arbitrary for T" パターンを検出
fn extract_arbitrary_impl(line : String) -> String? {
  let trimmed = trim(line)

  // "impl Arbitrary for" を含むかチェック
  if trimmed.contains("impl") &&
    trimmed.contains("Arbitrary") &&
    trimmed.contains("for") {
    // 型名を抽出
    let after_for = substring_after(trimmed, "for")
    let type_name = trim(after_for)
    if type_name.length() > 0 {
      Some(type_name)
    } else {
      None
    }
  } else {
    None
  }
}

///|
/// 型がArbitraryを実装しているか判定
pub fn has_arbitrary(
  type_name : String,
  known_impls : Array[@ast.ArbitraryImpl],
) -> Bool {
  let primitives = primitive_types()

  // プリミティブ型チェック
  let mut found = false
  let mut i = 0
  while i < primitives.length() {
    if primitives[i] == type_name {
      found = true
    }
    i = i + 1
  }
  if found {
    return true
  }

  // 既知の実装チェック
  let mut i = 0
  while i < known_impls.length() {
    if known_impls[i].type_name == type_name {
      return true
    }
    i = i + 1
  }
  false
}

///|
/// コンテナ型の内部型をチェック
pub fn check_container_arbitrary(
  container_type : String,
  inner_types : Array[String],
  known_impls : Array[@ast.ArbitraryImpl],
) -> @ast.Testability {
  // Array[T], List[T] は T が Arbitrary なら OK
  if container_type == "Array" || container_type == "List" {
    if inner_types.length() > 0 {
      let inner = inner_types[0]
      if has_arbitrary(inner, known_impls) {
        @ast.testable()
      } else {
        @ast.needs_user_arbitrary([inner])
      }
    } else {
      @ast.testable()
    }
  } else if container_type == "Option" {
    if inner_types.length() > 0 {
      let inner = inner_types[0]
      if has_arbitrary(inner, known_impls) {
        @ast.testable()
      } else {
        @ast.needs_user_arbitrary([inner])
      }
    } else {
      @ast.testable()
    }
  } else if container_type == "Result" {
    // Result[E, T] は両方の型が必要
    if inner_types.length() >= 2 {
      let t1 = inner_types[0]
      let t2 = inner_types[1]
      let mut needed : Array[String] = []
      if !has_arbitrary(t1, known_impls) {
        needed = push_string(needed, t1)
      }
      if !has_arbitrary(t2, known_impls) {
        needed = push_string(needed, t2)
      }
      if needed.length() == 0 {
        @ast.testable()
      } else {
        @ast.needs_user_arbitrary(needed)
      }
    } else {
      @ast.testable()
    }
  } else if container_type == "Map" {
    // Map[K, V] は K と V が必要
    if inner_types.length() >= 2 {
      let k = inner_types[0]
      let v = inner_types[1]
      let mut needed : Array[String] = []
      if !has_arbitrary(k, known_impls) {
        needed = push_string(needed, k)
      }
      if !has_arbitrary(v, known_impls) {
        needed = push_string(needed, v)
      }
      if needed.length() == 0 {
        @ast.testable()
      } else {
        @ast.needs_user_arbitrary(needed)
      }
    } else {
      @ast.testable()
    }
  } else {
    @ast.testable()
  }
}

///|
/// 型文字列からコンテナ情報を解析
/// 例: "Array[Int]" -> ("Array", ["Int"])
fn parse_container_type(type_str : String) -> (String, Array[String]) {
  // 左括弧の位置を探す
  let bracket_pos = find_char_arb(type_str, '[')
  if bracket_pos < 0 {
    (type_str, [])
  } else {
    let container_name = substring_range(type_str, 0, bracket_pos)
    let end_pos = type_str.length()
    let inner_str = substring_range(type_str, bracket_pos + 1, end_pos - 1)
    let inners = split_by_comma(inner_str)
    (container_name, inners)
  }
}

///|
/// 文字列内で文字が最初に現れる位置を検索
fn find_char_arb(s : String, c : Char) -> Int {
  let chars = s.to_array()
  let mut i = 0
  let mut found = -1
  while i < chars.length() {
    if chars[i] == c {
      found = i
    }
    i = i + 1
  }
  found
}

///|
/// カンマで型を分割
fn split_by_comma(s : String) -> Array[String] {
  let mut result : Array[String] = []
  let mut current = ""
  let mut depth = 0
  let chars = s.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == ',' && depth == 0 {
      result = push_string(result, trim(current))
      current = ""
    } else {
      if c == '[' || c == '(' {
        depth = depth + 1
      } else if c == ']' || c == ')' {
        depth = depth - 1
      }
      current = current + c.to_string()
    }
    i = i + 1
  }
  if current.length() > 0 {
    result = push_string(result, trim(current))
  }
  result
}

///|
/// 関数のテスト可能性を判定
pub fn check_function_testability(
  func : @ast.FunctionMeta,
  known_impls : Array[@ast.ArbitraryImpl],
) -> @ast.Testability {
  let mut all_types : Array[String] = []

  // 引数の型を収集
  let mut i = 0
  while i < func.args.length() {
    let arg_type = func.args[i].type_.simple_name()
    all_types = push_string(all_types, arg_type)
    i = i + 1
  }

  // 各型がArbitraryを実装しているかチェック
  let mut needed : Array[String] = []
  let mut i = 0
  while i < all_types.length() {
    let type_str = all_types[i]
    let (container, inners) = parse_container_type(type_str)
    if container == type_str {
      // コンテナ型ではない
      if !has_arbitrary(type_str, known_impls) {
        needed = push_string(needed, type_str)
      }
    } else {
      // コンテナ型
      match check_container_arbitrary(container, inners, known_impls) {
        @ast.NeedsUserArbitrary(types) => {
          let mut j = 0
          while j < types.length() {
            needed = push_string(needed, types[j])
            j = j + 1
          }
        }
        _ => ()
      }
    }
    i = i + 1
  }
  if needed.length() == 0 {
    @ast.testable()
  } else {
    @ast.needs_user_arbitrary(needed)
  }
}

///|
/// 型文字列のテスト可能性を簡易判定
pub fn check_type_testability(
  type_str : String,
  known_impls : Array[@ast.ArbitraryImpl],
) -> @ast.Testability {
  let (container, inners) = parse_container_type(type_str)
  if container == type_str {
    // プリミティブ型または単純型
    if has_arbitrary(type_str, known_impls) {
      @ast.testable()
    } else {
      @ast.needs_user_arbitrary([type_str])
    }
  } else {
    // コンテナ型
    check_container_arbitrary(container, inners, known_impls)
  }
}

// ヘルパー関数

///|
fn push_arb(
  arr : Array[@ast.ArbitraryImpl],
  elem : @ast.ArbitraryImpl,
) -> Array[@ast.ArbitraryImpl] {
  let result : Array[@ast.ArbitraryImpl] = []
  let mut i = 0
  while i < arr.length() {
    Array::push(result, arr[i])
    i = i + 1
  }
  Array::push(result, elem)
  result
}

///|
pub fn push_string(arr : Array[String], elem : String) -> Array[String] {
  let result : Array[String] = []
  let mut i = 0
  while i < arr.length() {
    Array::push(result, arr[i])
    i = i + 1
  }
  Array::push(result, elem)
  result
}

///|
fn split_lines(s : String) -> Array[String] {
  let lines = s.split("\n")
  lines.map(fn(sv) { sv.to_string() }).to_array()
}

///|
fn is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn trim(s : String) -> String {
  let chars = s.to_array()
  let mut start = 0
  let mut end = chars.length()

  // 先頭の空白をスキップ
  while start < end && is_whitespace(chars[start]) {
    start = start + 1
  }

  // 末尾の空白をスキップ
  while end > start && is_whitespace(chars[end - 1]) {
    end = end - 1
  }
  substring_range(s, start, end)
}

///|
fn substring_after(s : String, prefix : String) -> String {
  match s.find(prefix[:]) {
    Some(pos) => {
      let start = pos + prefix.length()
      substring_range(s, start, s.length())
    }
    None => ""
  }
}

// テスト

///|
test "detect_arbitrary_impls_contains_primitives" {
  let source = ""
  let result = detect_arbitrary_impls(source)
  inspect(result.length() > 0, content="true")
  inspect(has_arbitrary("Int", result), content="true")
  inspect(has_arbitrary("String", result), content="true")
}

///|
test "extract_arbitrary_impl_detects_impl_pattern" {
  let line = "impl Arbitrary for MyType"
  let result = extract_arbitrary_impl(line)
  match result {
    Some(type_name) => inspect(type_name, content="MyType")
    None => inspect("fail", content="fail")
  }
}

///|
test "extract_arbitrary_impl_with_quickcheck_prefix" {
  let line = "impl @quickcheck.Arbitrary for User"
  let result = extract_arbitrary_impl(line)
  match result {
    Some(type_name) => inspect(type_name, content="User")
    None => inspect("fail", content="fail")
  }
}

///|
test "parse_container_type_array" {
  let (container, inners) = parse_container_type("Array[Int]")
  inspect(container, content="Array")
  inspect(inners.length(), content="1")
}

///|
test "parse_container_type_map" {
  let (container, inners) = parse_container_type("Map[String, Int]")
  inspect(container, content="Map")
  inspect(inners.length(), content="2")
}

///|
test "check_type_testability_primitive" {
  let impls = detect_arbitrary_impls("")
  let result = check_type_testability("Int", impls)
  match result {
    @ast.Testable => inspect("ok", content="ok")
    _ => inspect("fail", content="fail")
  }
}

///|
test "check_type_testability_user_defined" {
  let impls = detect_arbitrary_impls("")
  let result = check_type_testability("MyType", impls)
  match result {
    @ast.NeedsUserArbitrary(_) => inspect("ok", content="ok")
    _ => inspect("fail", content="fail")
  }
}

///|
test "check_type_testability_array_primitive" {
  let impls = detect_arbitrary_impls("")
  let result = check_type_testability("Array[Int]", impls)
  match result {
    @ast.Testable => inspect("ok", content="ok")
    _ => inspect("fail", content="fail")
  }
}

///|
test "check_type_testability_array_user_defined" {
  let impls = detect_arbitrary_impls("")
  let result = check_type_testability("Array[MyType]", impls)
  match result {
    @ast.NeedsUserArbitrary(_) => inspect("ok", content="ok")
    _ => inspect("fail", content="fail")
  }
}
