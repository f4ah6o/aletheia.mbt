///|
/// ASTベースのArbitrary実装検出モジュール
/// moonbitlang/parserを使用してArbitraryトレイトの実装を検出する
///

///|
/// ソースコードからArbitrary実装を検出
pub fn detect_arbitrary_impls_ast(
  source : String,
  source_file : String,
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
    TopImpl(trait_~, ..) => {
      // trait_ が "Arbitrary" かチェック
      match trait_.name {
        Ident(name~) => {
          if name == "Arbitrary" {
            // TODO: 自己型から型名を抽出
            Some(@ast.ArbitraryImpl::user_defined("Unknown", 0))
          } else {
            None
          }
        }
        Dot(..) => None
      }
    }
    _ => None
  }
}
