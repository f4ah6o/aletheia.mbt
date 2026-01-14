///|
/// AST型定義モジュール
/// 関数メタデータ、型情報、可視性などを表現する型を提供する
///

/// ソースコード内の位置情報
pub struct Location {
  file : String
  line_start : Int
  line_end : Int
  column_start : Int
  column_end : Int
}

pub fn Location::unknown(file : String) -> Location {
  { file, line_start: 0, line_end: 0, column_start: 0, column_end: 0 }
}

/// 関数の可視性
pub enum Visibility {
  Public
  Private
  Internal
}

/// 型メタデータ
pub enum TypeMeta {
  Primitive(String)
  Generic(String, Array[TypeMeta])
  Function(Array[TypeMeta], TypeMeta)
  Tuple(Array[TypeMeta])
  Named(String)
  Unknown(String)
  Unit
}

/// 型の簡易名を取得
pub fn TypeMeta::simple_name(self : TypeMeta) -> String {
  match self {
    Primitive(s) => s
    Generic(name, _) => name
    Function(_, _) => "Function"
    Tuple(_) => "Tuple"
    Named(s) => s
    Unknown(s) => s
    Unit => "Unit"
  }
}

/// 引数メタデータ
pub struct ArgMeta {
  name : String
  type_ : TypeMeta
  is_optional : Bool
  default_value : Option[String]
}

pub fn ArgMeta::new(name : String, type_ : TypeMeta) -> ArgMeta {
  { name, type_, is_optional: false, default_value: None }
}

/// 関数メタデータ
pub struct FunctionMeta {
  name : String
  args : Array[ArgMeta]
  return_type : TypeMeta
  visibility : Visibility
  is_pure : Bool
  doc_comment : Option[String]
  location : Location
  type_params : Array[String]
}

pub fn FunctionMeta::new(name : String, location : Location) -> FunctionMeta {
  {
    name,
    args: [],
    return_type: Unit,
    visibility: Private,
    is_pure: true,
    doc_comment: None,
    location,
    type_params: []
  }
}

/// 関数シグネチャ文字列を生成
pub fn FunctionMeta::signature(self : FunctionMeta) -> String {
  let args_str = self.args.map(fn(a) { a.type_.simple_name() }).join(", ")
  let ret_str = self.return_type.simple_name()
  "(\{args_str}) -> \{ret_str}"
}

/// 型定義メタデータ（enum, struct）
pub struct TypeDefinition {
  name : String
  kind : TypeKind
  type_params : Array[String]
  location : Location
}

pub enum TypeKind {
  Struct(Array[StructField])
  Enum(Array[EnumVariant])
  Opaque
}

pub struct StructField {
  name : String
  type_ : TypeMeta
}

pub struct EnumVariant {
  name : String
  data : Option[TypeMeta]
}

/// PBTテスト可能性判定結果
pub enum Testability {
  Testable
  NeedsUserArbitrary(Array[String])
  NotTestable(String)
}

/// パターン候補
pub enum PatternCandidate {
  RoundTrip(String, String, TypeMeta)
  Idempotent(String)
  ProducerConsumer(String, String)
}

/// プロパティテスト定義
pub struct PropertyDef {
  name : String
  description : String
  target_functions : Array[String]
  body : String
  pattern : PatternCandidate
}

pub fn PropertyDef::new(name : String, pattern : PatternCandidate) -> PropertyDef {
  let targets = match pattern {
    RoundTrip(encoder, decoder, _) => [encoder, decoder]
    Idempotent(function) => [function]
    ProducerConsumer(producer, consumer) => [producer, consumer]
  }
  {
    name,
    description: "",
    target_functions: targets,
    body: "",
    pattern
  }
}
