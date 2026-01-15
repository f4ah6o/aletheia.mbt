///|
/// ASTベースの呼び出しグラフ構築モジュール
/// moonbitlang/parserを使用して関数呼び出しグラフを構築する
///

///|
/// ソースコードから呼び出しグラフを構築
pub fn build_call_graph_ast(
  source : String,
  source_file : String,
) -> Result[@ast.CallGraph, String] {
  let (impls, errors) = @mb_parser.parse_string(source)

  // パースエラーをチェック
  if errors.length() > 0 {
    let mut error_msgs = ""
    for e in errors {
      error_msgs = error_msgs + e.to_string() + "; "
    }
    return Err("Parse error: " + error_msgs)
  }

  // impls から関数定義と呼び出し関係を抽出
  let graph = extract_call_graph(impls, source_file)
  Ok(graph)
}

///|
/// Impl リストから呼び出しグラフを抽出
fn extract_call_graph(
  impls : @list.List[@syntax.Impl],
  source_file : String,
) -> @ast.CallGraph {
  let mut graph = @ast.CallGraph::new(source_file)

  // 関数定義を収集
  impls.each(fn(impl_val) {
    match impl_val {
      TopFuncDef(fun_decl~, ..) => {
        let node = @ast.CallNode::new(fun_decl.name.name, source_file, 0)
        graph = graph.add_node(node)
      }
      _ => ()
    }
  })
  graph
}
