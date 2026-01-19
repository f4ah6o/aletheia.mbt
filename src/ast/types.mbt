///|
/// AST型定義モジュール
/// 関数メタデータ、型情報、可視性などを表現する型を提供する
///

///|
/// ソースコード内の位置情報
pub struct Location {
  file : String
  line_start : Int
  line_end : Int
  column_start : Int
  column_end : Int
}

///|
pub fn Location::unknown(file : String) -> Location {
  { file, line_start: 0, line_end: 0, column_start: 0, column_end: 0 }
}

///|
/// 関数の可視性
pub enum Visibility {
  Public
  Private
  Internal
}

///|
pub fn make_public() -> Visibility {
  Public
}

///|
pub fn make_private() -> Visibility {
  Private
}

///|
pub fn make_internal() -> Visibility {
  Internal
}

///|
/// 型メタデータ
#warnings("-unused_constructor")
pub enum TypeMeta {
  Primitive(String)
  Generic(String, Array[TypeMeta])
  Function(Array[TypeMeta], TypeMeta)
  Tuple(Array[TypeMeta])
  Named(String)
  Unknown(String)
  Unit
}

///|
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

///|
pub fn TypeMeta::unit() -> TypeMeta {
  Unit
}

///|
pub fn TypeMeta::named(name : String) -> TypeMeta {
  Named(name)
}

///|
pub fn TypeMeta::generic(
  name : String,
  inner_types : Array[TypeMeta],
) -> TypeMeta {
  Generic(name, inner_types)
}

///|
/// 引数メタデータ
pub struct ArgMeta {
  name : String
  type_ : TypeMeta
  is_optional : Bool
  default_value : String?
}

///|
pub fn ArgMeta::new(name : String, type_ : TypeMeta) -> ArgMeta {
  { name, type_, is_optional: false, default_value: None }
}

///|
pub fn ArgMeta::with_options(
  name : String,
  type_ : TypeMeta,
  is_optional : Bool,
  default_value : String?,
) -> ArgMeta {
  { name, type_, is_optional, default_value }
}

///|
/// 関数メタデータ
pub struct FunctionMeta {
  name : String
  args : Array[ArgMeta]
  return_type : TypeMeta
  visibility : Visibility
  is_pure : Bool
  doc_comment : String?
  location : Location
  type_params : Array[String]
}

///|
pub fn FunctionMeta::new(name : String, location : Location) -> FunctionMeta {
  {
    name,
    args: [],
    return_type: Unit,
    visibility: Private,
    is_pure: true,
    doc_comment: None,
    location,
    type_params: [],
  }
}

///|
pub fn FunctionMeta::with_signature(
  name : String,
  args : Array[ArgMeta],
  return_type : TypeMeta,
  location : Location,
  type_params? : Array[String] = [],
) -> FunctionMeta {
  {
    name,
    args,
    return_type,
    visibility: Public,
    is_pure: true,
    doc_comment: None,
    location,
    type_params,
  }
}

///|
/// 関数シグネチャ文字列を生成
pub fn FunctionMeta::signature(self : FunctionMeta) -> String {
  let args_str = self.args.map(fn(a) { a.type_.simple_name() }).join(", ")
  let ret_str = self.return_type.simple_name()
  "(\{args_str}) -> \{ret_str}"
}

///|
/// 型定義メタデータ（enum, struct）
#warnings("-struct_never_constructed")
pub struct TypeDefinition {
  name : String
  kind : TypeKind
  type_params : Array[String]
  location : Location
}

///|
#warnings("-unused_constructor")
pub enum TypeKind {
  Struct(Array[StructField])
  Enum(Array[EnumVariant])
  Opaque
}

///|
#warnings("-struct_never_constructed")
pub struct StructField {
  name : String
  type_ : TypeMeta
}

///|
#warnings("-struct_never_constructed")
pub struct EnumVariant {
  name : String
  data : TypeMeta?
}

///|
/// PBTテスト可能性判定結果
pub enum Testability {
  Testable
  NeedsUserArbitrary(Array[String])
  NotTestable(String)
}

///|
pub fn testable() -> Testability {
  Testable
}

///|
pub fn needs_user_arbitrary(types : Array[String]) -> Testability {
  NeedsUserArbitrary(types)
}

///|
pub fn not_testable(reason : String) -> Testability {
  NotTestable(reason)
}

///|
/// Arbitrary実装情報
pub struct ArbitraryImpl {
  type_name : String
  is_primitive : Bool
  is_container : Bool
  inner_types : Array[String]
  impl_line : Int?
}

///|
pub fn ArbitraryImpl::primitive(name : String) -> ArbitraryImpl {
  {
    type_name: name,
    is_primitive: true,
    is_container: false,
    inner_types: [],
    impl_line: None,
  }
}

///|
pub fn ArbitraryImpl::container(
  name : String,
  inners : Array[String],
) -> ArbitraryImpl {
  {
    type_name: name,
    is_primitive: false,
    is_container: true,
    inner_types: inners,
    impl_line: None,
  }
}

///|
pub fn ArbitraryImpl::user_defined(name : String, line : Int) -> ArbitraryImpl {
  {
    type_name: name,
    is_primitive: false,
    is_container: false,
    inner_types: [],
    impl_line: Some(line),
  }
}

///|
/// パターン候補
#warnings("-unused_constructor")
pub enum PatternCandidate {
  RoundTrip(String, String, TypeMeta)
  Idempotent(String)
  ProducerConsumer(String, String)
}

///|
/// プロパティテスト定義
pub struct PropertyDef {
  name : String
  description : String
  target_functions : Array[String]
  body : String
  pattern : PatternCandidate
}

///|
pub fn PropertyDef::new(
  name : String,
  pattern : PatternCandidate,
) -> PropertyDef {
  let targets = match pattern {
    RoundTrip(encoder, decoder, _) => [encoder, decoder]
    Idempotent(function) => [function]
    ProducerConsumer(producer, consumer) => [producer, consumer]
  }
  { name, description: "", target_functions: targets, body: "", pattern }
}

///|
/// 呼び出しグラフ（Phase 2）
pub struct CallGraph {
  nodes : Array[CallNode]
  edges : Array[CallEdge]
  source_file : String
}

///|
pub fn CallGraph::new(source_file : String) -> CallGraph {
  { nodes: [], edges: [], source_file }
}

///|
pub fn CallGraph::add_node(self : CallGraph, node : CallNode) -> CallGraph {
  let nodes : Array[CallNode] = []
  let mut i = 0
  while i < self.nodes.length() {
    Array::push(nodes, self.nodes[i])
    i = i + 1
  }
  Array::push(nodes, node)
  { nodes, edges: self.edges, source_file: self.source_file }
}

///|
pub fn CallGraph::add_edge(self : CallGraph, edge : CallEdge) -> CallGraph {
  let edges : Array[CallEdge] = []
  let mut i = 0
  while i < self.edges.length() {
    Array::push(edges, self.edges[i])
    i = i + 1
  }
  Array::push(edges, edge)
  { nodes: self.nodes, edges, source_file: self.source_file }
}

///|
/// 呼び出しグラフのノード
pub struct CallNode {
  function_name : String
  location : String
  line_num : Int
  calls : Array[String] // 呼び出す関数名リスト
  called_by : Array[String] // 呼び出される関数名リスト
}

///|
pub fn CallNode::new(
  name : String,
  location : String,
  line_num : Int,
) -> CallNode {
  { function_name: name, location, line_num, calls: [], called_by: [] }
}

///|
/// 呼び出しエッジ
pub struct CallEdge {
  caller : String
  callee : String
  call_type : CallType
  location : String
  line_num : Int
}

///|
pub fn CallEdge::new(
  caller : String,
  callee : String,
  call_type : CallType,
  location : String,
  line_num : Int,
) -> CallEdge {
  { caller, callee, call_type, location, line_num }
}

///|
/// 呼び出しの種類
pub enum CallType {
  DirectCall // func(args)
  MethodCall // obj.method(args)
  PipelineCall // value |> func
  ChainCall // 関数合成
}

///|
pub fn make_direct_call() -> CallType {
  DirectCall
}

///|
pub fn make_method_call() -> CallType {
  MethodCall
}

///|
pub fn make_pipeline_call() -> CallType {
  PipelineCall
}

///|
pub fn make_chain_call() -> CallType {
  ChainCall
}

///|
pub fn call_type_to_string(ct : CallType) -> String {
  match ct {
    DirectCall => "direct"
    MethodCall => "method"
    PipelineCall => "pipeline"
    ChainCall => "chain"
  }
}

///|
/// 抽出結果（関数とテスト可能性をまとめた構造）
pub struct ExtractionResult {
  source_file : String
  functions : Array[FunctionMeta]
  arbitrary_impls : Array[ArbitraryImpl]
  testable_functions : Array[String]
  needs_arbitrary : Array[String]
}

///|
pub fn ExtractionResult::new(source_file : String) -> ExtractionResult {
  {
    source_file,
    functions: [],
    arbitrary_impls: [],
    testable_functions: [],
    needs_arbitrary: [],
  }
}

///|
pub fn ExtractionResult::with_functions(
  self : ExtractionResult,
  functions : Array[FunctionMeta],
) -> ExtractionResult {
  {
    source_file: self.source_file,
    functions,
    arbitrary_impls: self.arbitrary_impls,
    testable_functions: self.testable_functions,
    needs_arbitrary: self.needs_arbitrary,
  }
}

///|
pub fn ExtractionResult::with_arbitrary_impls(
  self : ExtractionResult,
  arbitrary_impls : Array[ArbitraryImpl],
) -> ExtractionResult {
  {
    source_file: self.source_file,
    functions: self.functions,
    arbitrary_impls,
    testable_functions: self.testable_functions,
    needs_arbitrary: self.needs_arbitrary,
  }
}

///|
pub fn ExtractionResult::with_testable_functions(
  self : ExtractionResult,
  testable_functions : Array[String],
) -> ExtractionResult {
  {
    source_file: self.source_file,
    functions: self.functions,
    arbitrary_impls: self.arbitrary_impls,
    testable_functions,
    needs_arbitrary: self.needs_arbitrary,
  }
}

///|
pub fn ExtractionResult::with_needs_arbitrary(
  self : ExtractionResult,
  needs_arbitrary : Array[String],
) -> ExtractionResult {
  {
    source_file: self.source_file,
    functions: self.functions,
    arbitrary_impls: self.arbitrary_impls,
    testable_functions: self.testable_functions,
    needs_arbitrary,
  }
}
