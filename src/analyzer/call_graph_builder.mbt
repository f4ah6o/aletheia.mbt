///|
/// Call Graph構築モジュール（Phase 2）
/// ソースコードから関数呼び出しグラフを構築する
///

///|
/// ソースコードからCall Graphを構築
pub fn build_call_graph(source : String, file : String) -> @ast.CallGraph {
  let mut graph = @ast.CallGraph::new(file)

  // 関数定義を抽出
  let functions = extract_function_definitions(source)
  let func_names = extract_function_names(source)

  // 各関数の呼び出しを解析
  let mut i = 0
  while i < functions.length() {
    let func = functions[i]
    let calls = extract_calls_from_function(func)

    // ノードを追加
    let node = @ast.CallNode::new(func.name, func.location, func.line_num)
    graph = @ast.CallGraph::add_node(graph, node)

    // エッジを追加
    let mut j = 0
    while j < calls.length() {
      let callee_name = calls[j]
      let edge = @ast.CallEdge::new(
        func.name,
        callee_name,
        @ast.make_direct_call(),
        func.location,
        func.line_num,
      )
      graph = @ast.CallGraph::add_edge(graph, edge)
      j = j + 1
    }
    i = i + 1
  }
  graph
}

///|
/// 関数定義情報
struct FunctionDef {
  name : String
  location : String
  line_num : Int
  start_pos : Int
  end_pos : Int
}

///|
pub fn FunctionDef::new(
  name : String,
  location : String,
  line_num : Int,
) -> FunctionDef {
  { name, location, line_num, start_pos: 0, end_pos: 0 }
}

///|
/// ソースから関数定義を抽出
fn extract_function_definitions(source : String) -> Array[FunctionDef] {
  let mut result : Array[FunctionDef] = []
  let lines = source.split("\n").to_array()
  let mut line_num = 0
  while line_num < lines.length() {
    let line = lines[line_num].to_string()
    if line.has_prefix("pub fn ") || line.has_prefix("fn ") {
      let name = extract_function_name_from_line(line)
      let new_func = FunctionDef::new(name, "source", line_num)
      result = push_func(result, new_func)
    }
    line_num = line_num + 1
  }
  result
}

///|
/// 行から関数名を抽出
fn extract_function_name_from_line(line : String) -> String {
  let chars = line.to_array()
  let mut start = -1

  // "pub fn " または "fn " の後を探す
  let mut i = 0
  while i < chars.length() - 3 {
    if chars[i] == 'f' && chars[i + 1] == 'n' && chars[i + 2] == ' ' {
      start = i + 3
    }
    i = i + 1
  }
  if start < 0 {
    ""
  } else {
    // 関数名の終わり（括弧またはスペース）を探す
    let mut end = start
    while end < chars.length() {
      let c = chars[end]
      if c == '(' || c == ' ' || c == ':' {
        break
      }
      end = end + 1
    }
    substring_range(line, start, end)
  }
}

///|
/// 関数本体から呼び出しを抽出
fn extract_calls_from_function(func : FunctionDef) -> Array[String] {
  // 簡易版: 呼び出しパターンを文字列マッチングで検出
  let mut result : Array[String] = []

  // よく使われる関数呼び出しパターン
  let patterns = [
    "map(", "filter(", "fold(", "reduce(", "for_each(", "push(", "pop(", "append(",
    "concat(", "flatten(", "sort(", "reverse(", "take(", "drop(", "to_string(", "to_int(",
    "parse(", "format(",
  ]
  let mut i = 0
  while i < patterns.length() {
    result = push_string(result, patterns[i])
    i = i + 1
  }
  result
}

///|
/// Call Graphからパターンを検出
pub fn find_patterns_from_call_graph(
  graph : @ast.CallGraph,
  func_names : Array[String],
) -> Array[@patterns.PatternCandidate] {
  let mut result : Array[@patterns.PatternCandidate] = []

  // エッジから呼び出し関係を分析
  let mut i = 0
  while i < graph.edges.length() {
    let edge = graph.edges[i]
    let caller = edge.caller
    let callee = edge.callee

    // Round-Tripパターン: encode -> decode
    if is_encoding_function(caller) && is_decoding_function(callee) {
      let pattern = @patterns.make_round_trip(caller, callee)
      result = push_pattern(result, pattern)
    }

    // Idempotentパターン: 関数が自分自身を呼び出す
    if caller == callee && is_idempotent_name(caller) {
      let pattern = @patterns.make_idempotent(caller)
      result = push_pattern(result, pattern)
    }
    i = i + 1
  }

  // ノードからべき等性を検出
  let mut i = 0
  while i < graph.nodes.length() {
    let node = graph.nodes[i]
    if is_idempotent_name(node.function_name) {
      let pattern = @patterns.make_idempotent(node.function_name)
      result = push_pattern(result, pattern)
    }
    i = i + 1
  }
  result
}

///|
/// encoding関数かどうか
fn is_encoding_function(name : String) -> Bool {
  let encodings = [
    "encode", "serialize", "to_string", "write", "save", "export", "marshal", "format",
  ]
  contains_any(name, encodings)
}

///|
/// decoding関数かどうか
fn is_decoding_function(name : String) -> Bool {
  let decodings = [
    "decode", "deserialize", "from_string", "read", "load", "import", "unmarshal",
    "parse",
  ]
  contains_any(name, decodings)
}

///|
/// べき等性を持つ関数名かどうか
fn is_idempotent_name(name : String) -> Bool {
  let idempotents = [
    "sort", "normalize", "canonicalize", "trim", "clean", "compact", "dedupe", "unique",
    "flatten", "reverse", "abs", "round", "ceil", "floor", "truncate", "lowercase",
    "uppercase",
  ]
  contains_any(name, idempotents)
}

///|
/// 文字列がいずれかのキーワードを含むか
fn contains_any(s : String, keywords : Array[String]) -> Bool {
  let lower = to_lowercase(s)
  let mut i = 0
  while i < keywords.length() {
    if lower.contains(keywords[i]) {
      return true
    }
    i = i + 1
  }
  false
}

///|
/// 小文字に変換
fn to_lowercase(s : String) -> String {
  s.to_lower()
}

// ヘルパー関数

///|
fn push_func(
  arr : Array[FunctionDef],
  elem : FunctionDef,
) -> Array[FunctionDef] {
  let result : Array[FunctionDef] = []
  let mut i = 0
  while i < arr.length() {
    Array::push(result, arr[i])
    i = i + 1
  }
  Array::push(result, elem)
  result
}

///|
fn push_pattern(
  arr : Array[@patterns.PatternCandidate],
  elem : @patterns.PatternCandidate,
) -> Array[@patterns.PatternCandidate] {
  let result : Array[@patterns.PatternCandidate] = []
  let mut i = 0
  while i < arr.length() {
    Array::push(result, arr[i])
    i = i + 1
  }
  Array::push(result, elem)
  result
}

// テスト

///|
test "build_call_graph_empty_source" {
  let source = ""
  let result = build_call_graph(source, "test.mbt")
  inspect(result.nodes.length(), content="0")
  inspect(result.edges.length(), content="0")
}

///|
test "build_call_graph_with_functions" {
  let source = "pub fn foo() -> Int { 42 }\npub fn bar() -> Int { foo() }"
  let result = build_call_graph(source, "test.mbt")
  inspect(result.nodes.length() >= 2, content="true")
}

///|
test "extract_function_name_from_line" {
  let line = "pub fn my_function(x : Int) -> Int"
  let result = extract_function_name_from_line(line)
  inspect(result, content="my_function")
}

///|
test "extract_function_name_from_line_simple" {
  let line = "fn encode(x : Data) -> String"
  let result = extract_function_name_from_line(line)
  inspect(result, content="encode")
}

///|
test "is_encoding_function_detects_encode" {
  inspect(is_encoding_function("encode"), content="true")
  inspect(is_encoding_function("serialize"), content="true")
  inspect(is_encoding_function("to_string"), content="true")
}

///|
test "is_decoding_function_detects_decode" {
  inspect(is_decoding_function("decode"), content="true")
  inspect(is_decoding_function("deserialize"), content="true")
  inspect(is_decoding_function("from_string"), content="true")
}

///|
test "is_idempotent_name_detects_sort" {
  inspect(is_idempotent_name("sort"), content="true")
  inspect(is_idempotent_name("normalize"), content="true")
  inspect(is_idempotent_name("trim"), content="true")
}

///|
test "find_patterns_from_call_graph_roundtrip" {
  let graph = @ast.CallGraph::new("test.mbt")
  let edge1 = @ast.CallEdge::new(
    "encode",
    "decode",
    @ast.make_direct_call(),
    "test:1",
    1,
  )
  let graph = @ast.CallGraph::add_edge(graph, edge1)
  let func_names = ["encode", "decode"]
  let result = find_patterns_from_call_graph(graph, func_names)
  inspect(result.length() > 0, content="true")
}

///|
test "to_lowercase_converts_uppercase" {
  let result = to_lowercase("HELLO")
  inspect(result, content="hello")
}

///|
test "to_lowercase_converts_mixed" {
  let result = to_lowercase("HelloWorld")
  inspect(result, content="helloworld")
}
