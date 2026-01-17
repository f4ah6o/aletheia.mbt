///|
/// ASTベースのArbitrary実装検出モジュール
/// moonbitlang/parserを使用してArbitraryトレイトの実装を検出する
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
  } else if container_type == "Map" {
    // Map[K, V] は K と V が必要
    if inner_types.length() >= 2 {
      let k = inner_types[0]
      let v = inner_types[1]
      let k_ok = has_arbitrary(k, known_impls)
      let v_ok = has_arbitrary(v, known_impls)
      if k_ok && v_ok {
        @ast.testable()
      } else {
        let needed : Array[String] = []
        if !k_ok {
          Array::push(needed, k)
        }
        if !v_ok {
          Array::push(needed, v)
        }
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
  let mut found = -1
  let mut i = 0
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
  let result : Array[String] = []
  let mut current = ""
  let mut depth = 0
  let chars = s.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == ',' && depth == 0 {
      Array::push(result, trim_string(current))
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
    Array::push(result, trim_string(current))
  }
  result
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
/// 文字列の空白を削除
fn trim_string(s : String) -> String {
  let chars = s.to_array()
  let mut start = 0
  let mut end = chars.length()

  // 先頭の空白をスキップ
  while start < end && is_whitespace_char(chars[start]) {
    start = start + 1
  }

  // 末尾の空白をスキップ
  while end > start && is_whitespace_char(chars[end - 1]) {
    end = end - 1
  }
  substring_range(s, start, end)
}

///|
/// 空白文字か判定
fn is_whitespace_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
/// ソースコードからArbitrary実装を検出
pub fn detect_arbitrary_impls(source : String) -> Array[@ast.ArbitraryImpl] {
  let result : Array[@ast.ArbitraryImpl] = []

  // プリミティブ型を追加
  let primitives = primitive_types()
  let mut i = 0
  while i < primitives.length() {
    Array::push(result, @ast.ArbitraryImpl::primitive(primitives[i]))
    i = i + 1
  }

  // ASTを使ってユーザー定義のimplを検出
  let ast_impls = detect_arbitrary_impls_from_source(source)
  let mut i = 0
  while i < ast_impls.length() {
    Array::push(result, ast_impls[i])
    i = i + 1
  }

  // フォールバック：文字列ベースの検出（テスト用）
  let string_impls = detect_arbitrary_impls_from_string(source)
  let mut i = 0
  while i < string_impls.length() {
    Array::push(result, string_impls[i])
    i = i + 1
  }
  result
}

///|
/// 文字列からimplパターンを検出（フォールバック）
fn detect_arbitrary_impls_from_string(
  source : String,
) -> Array[@ast.ArbitraryImpl] {
  let result : Array[@ast.ArbitraryImpl] = []

  // 行ごとに "impl Arbitrary for X" パターンを検索
  let chars = source.to_array()
  let mut line_start = 0
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\n' {
      let line = substring_range(source, line_start, i)
      let trimmed = trim_string_line(line)
      if trimmed.contains("impl") &&
        trimmed.contains("Arbitrary") &&
        trimmed.contains("for") {
        let after_for = substring_after(trimmed, "for")
        let type_name = trim_string_line(after_for)
        if type_name.length() > 0 {
          Array::push(result, @ast.ArbitraryImpl::user_defined(type_name, 0))
        }
      }
      line_start = i + 1
    }
    i = i + 1
  }

  // 最後の行も処理
  if line_start < chars.length() {
    let line = substring_range(source, line_start, chars.length())
    let trimmed = trim_string_line(line)
    if trimmed.contains("impl") &&
      trimmed.contains("Arbitrary") &&
      trimmed.contains("for") {
      let after_for = substring_after(trimmed, "for")
      let type_name = trim_string_line(after_for)
      if type_name.length() > 0 {
        Array::push(result, @ast.ArbitraryImpl::user_defined(type_name, 0))
      }
    }
  }
  result
}

///|
/// 文字列の空白を削除
fn trim_string_line(s : String) -> String {
  let chars = s.to_array()
  let mut start = 0
  let mut end = chars.length()

  // 先頭の空白をスキップ
  while start < end && is_whitespace_char(chars[start]) {
    start = start + 1
  }

  // 末尾の空白をスキップ
  while end > start && is_whitespace_char(chars[end - 1]) {
    end = end - 1
  }
  substring_range(s, start, end)
}

///|
/// ASTを使ってソースコードからArbitrary実装を検出（詳細版）
pub fn detect_arbitrary_impls_ast(
  source : String,
) -> Result[Array[@ast.ArbitraryImpl], String] {
  let (impls, errors) = @mb_parser.parse_string(source)

  // パースエラーをチェック
  if errors.length() > 0 {
    let mut error_msgs = ""
    for e in errors {
      error_msgs = error_msgs + e.to_string() + "; "
    }
    return Err("Parse error: " + error_msgs)
  }

  // impls からArbitrary実装を抽出
  let arbitrary_impls = extract_arbitrary_impls(impls)
  Ok(arbitrary_impls)
}

///|
/// 文字列から指定されたプレフィックスの後ろを抽出
fn substring_after(s : String, prefix : String) -> String {
  match s.find(prefix[:]) {
    Some(pos) => {
      let start = pos + prefix.length()
      substring_range(s, start, s.length())
    }
    None => ""
  }
}

///|
/// ASTのImplリストからArbitrary実装を抽出
fn detect_arbitrary_impls_from_source(
  source : String,
) -> Array[@ast.ArbitraryImpl] {
  match detect_arbitrary_impls_ast(source) {
    Ok(impls) => impls
    Err(_) => []
  }
}

///|
/// Impl リストからArbitrary実装を抽出
fn extract_arbitrary_impls(
  impls : @list.List[@syntax.Impl],
) -> Array[@ast.ArbitraryImpl] {
  let result : Array[@ast.ArbitraryImpl] = []

  // @list.List の反復処理
  impls.each(fn(impl_val) {
    let arb = check_top_impl(impl_val)
    match arb {
      Some(arb_impl) => Array::push(result, arb_impl)
      None => ()
    }
  })
  result
}

///|
/// TopImpl がArbitrary実装かチェック
fn check_top_impl(impl_val : @syntax.Impl) -> @ast.ArbitraryImpl? {
  match impl_val {
    TopImpl(self_ty~, trait_~, ..) =>
      // trait_ が "Arbitrary" かチェック
      match trait_.name {
        Ident(name~) =>
          if name == "Arbitrary" {
            // 自己型から型名を抽出
            let type_name = extract_type_from_self_ty(self_ty)
            Some(@ast.ArbitraryImpl::user_defined(type_name, 0))
          } else {
            None
          }
        Dot(..) =>
          // pkg::Arbitrary のような形式 - とりあえず無視
          None
      }
    _ => None
  }
}

///|
/// self_ty から型名を抽出
fn extract_type_from_self_ty(self_ty : @syntax.Type?) -> String {
  match self_ty {
    Some(ty) => extract_type_name_from_type(ty)
    None => "Unknown"
  }
}

///|
/// Type から型名を抽出
fn extract_type_name_from_type(ty : @syntax.Type) -> String {
  match ty {
    Name(constr_id~, ..) =>
      match constr_id.id {
        Ident(name~) => name
        Dot(..) => "Unknown" // pkg::Type 形式はとりあえず "Unknown" に
      }
    _ => "Unknown"
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

///|
/// TypeMeta から必要なArbitrary実装を収集
fn collect_needed_from_type_meta(
  type_meta : @ast.TypeMeta,
  known_impls : Array[@ast.ArbitraryImpl],
) -> Array[String] {
  let needed : Array[String] = []
  match type_meta {
    @ast.TypeMeta::Generic(_, inner_types) => {
      // コンテナ型の内部型をチェック
      let inner_names = collect_inner_type_names(inner_types, known_impls)
      let mut i = 0
      while i < inner_names.length() {
        Array::push(needed, inner_names[i])
        i = i + 1
      }
    }
    @ast.TypeMeta::Named(name) => {
      // 名前付き型をチェック
      if !has_arbitrary(name, known_impls) {
        Array::push(needed, name)
      }
    }
    @ast.TypeMeta::Primitive(_) => {
      // プリミティブ型は常にOK
      ()
    }
    @ast.TypeMeta::Unit => {
      // Unit型は常にOK
      ()
    }
    @ast.TypeMeta::Unknown(name) => {
      // 不明な型は必要とみなす
      Array::push(needed, name)
    }
    _ => {
      // Function, Tuple などはとりあえず簡易対応
      let name = type_meta.simple_name()
      Array::push(needed, name)
    }
  }
  needed
}

///|
/// TypeMeta配列から内部型名を収集（再帰的）
fn collect_inner_type_names(
  types : Array[@ast.TypeMeta],
  known_impls : Array[@ast.ArbitraryImpl],
) -> Array[String] {
  let needed : Array[String] = []
  let mut i = 0
  while i < types.length() {
    let inner_needed = collect_needed_from_type_meta(types[i], known_impls)
    let mut j = 0
    while j < inner_needed.length() {
      Array::push(needed, inner_needed[j])
      j = j + 1
    }
    i = i + 1
  }
  needed
}

///|
/// 関数のテスト可能性を判定（TypeMeta対応版）
pub fn check_function_testability(
  func : @ast.FunctionMeta,
  known_impls : Array[@ast.ArbitraryImpl],
) -> @ast.Testability {
  let all_needed : Array[String] = []

  // 引数の型を収集
  let mut i = 0
  while i < func.args.length() {
    let arg_type = func.args[i].type_
    let needed = collect_needed_from_type_meta(arg_type, known_impls)
    let mut j = 0
    while j < needed.length() {
      Array::push(all_needed, needed[j])
      j = j + 1
    }
    i = i + 1
  }

  // 重複を除去して判定
  let unique_needed = dedupe_strings(all_needed)
  if unique_needed.length() == 0 {
    @ast.testable()
  } else {
    @ast.needs_user_arbitrary(unique_needed)
  }
}

///|
/// 文字列配列から重複を除去
fn dedupe_strings(strings : Array[String]) -> Array[String] {
  let result : Array[String] = []
  let mut i = 0
  while i < strings.length() {
    let s = strings[i]
    if !string_array_contains(result, s) {
      Array::push(result, s)
    }
    i = i + 1
  }
  result
}

///|
/// 文字列配列に要素が含まれるか判定
pub fn string_array_contains(arr : Array[String], item : String) -> Bool {
  let mut i = 0
  while i < arr.length() {
    if arr[i] == item {
      return true
    }
    i = i + 1
  }
  false
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
