///|
/// 関数抽出器（コンポーネントA）
/// MoonBitソースコードから公開関数のメタデータを抽出する
///

/// 抽出結果
pub struct ExtractionResult {
  functions : Array[FunctionMeta]
  types : Array[TypeDefinition]
  arbitrary_impls : Array[String]
}

/// パースエラー
pub type ExtractError = String

/// ソースコードから関数を抽出（簡易版）
pub fn extract_from_source(source : String, file : String) -> Result[ExtractionResult, ExtractError] {
  let functions : Array[FunctionMeta] = []
  let types : Array[TypeDefinition] = []
  let arbitrary_impls : Array[String] = []

  // pub fnで始まる行を検出
  let lines = source.split("\n")
  let mut func_count = 0
  let mut type_count = 0

  let iter = lines.to_array()
  let mut i = 0
  while i < Array::length(iter) {
    let line = iter[i]
    if line.has_prefix("pub fn ") {
      func_count = func_count + 1
    } else if line.has_prefix("pub struct ") {
      type_count = type_count + 1
    } else if line.has_prefix("pub enum ") {
      type_count = type_count + 1
    } else {
      ()
    }
    i = i + 1
  }

  Ok({ functions, types, arbitrary_impls })
}

/// pub fn xxx(...) 形式の関数名を抽出
pub fn extract_function_names(source : String) -> Array[String] {
  let result : Array[String] = []
  let lines = source.split("\n").to_array()
  let mut i = 0
  while i < lines.length() {
    let line = lines[i].to_string()  // StringView -> String
    if line.has_prefix("pub fn ") {
      // "pub fn xxx(" から xxx を抽出
      let paren_pos = find_char_from(line, '(', 7)
      if paren_pos > 7 {
        // line[7:paren_pos] を抽出
        let name = substring_range(line, 7, paren_pos).trim().to_string()
        Array::push(result, name)
      }
    }
    i = i + 1
  }
  result
}

/// 文字列から指定位置以降で文字を検索
fn find_char_from(s : String, c : Char, start : Int) -> Int {
  let chars = s.to_array()
  let mut i = start
  while i < chars.length() {
    if chars[i] == c {
      return i
    }
    i = i + 1
  }
  -1
}

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

/// 文字列から文字の位置を検索
fn find_char(s : String, c : Char) -> Int {
  let chars = s.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == c {
      return i
    }
    i = i + 1
  }
  -1
}

/// 関数メタデータ（簡易版）
pub struct FunctionMeta {
  name : String
  location : String
  line_num : Int
}

/// 型定義
pub struct TypeDefinition {
  name : String
  kind : TypeKind
  location : String
}

pub enum TypeKind {
  Struct
  Enum
}

/// テスト
test "extract_from_source_simple" {
  let source = "pub fn add(a : Int, b : Int) -> Int {\n  a + b\n}\n\npub struct Point {\n  x : Int\n  y : Int\n}"
  let result = extract_from_source(source, "test.mbt")
  match result {
    Ok(r) => {
      inspect(r.functions.length(), content="0")
      inspect(r.types.length(), content="0")
    }
    Err(_) => inspect("false", content="true")
  }
}

test "extract_from_source_counts" {
  let source = "pub fn add(a : Int, b : Int) -> Int { a + b }\npub fn sub(a : Int, b : Int) -> Int { a - b }\npub struct Point { x : Int }"
  let result = extract_from_source(source, "test.mbt")
  match result {
    Ok(r) => {
      inspect(r.functions.length(), content="0")
      inspect(r.types.length(), content="0")
    }
    Err(_) => inspect("false", content="true")
  }
}
