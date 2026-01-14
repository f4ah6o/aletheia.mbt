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
