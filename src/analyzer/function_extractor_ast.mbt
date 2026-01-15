///|
/// ASTベースの関数抽出モジュール
/// moonbitlang/parserを使用してソースコードから関数メタデータを抽出する
///

///|
/// ソースコードから関数メタデータを抽出
pub fn extract_from_source_ast(
  source : String,
  source_file : String,
) -> Result[Array[@ast.FunctionMeta], String] {
  let (impls, errors) = @mb_parser.parse_string(source)

  // パースエラーをチェック
  if errors.length() > 0 {
    let mut error_msgs = ""
    for e in errors {
      error_msgs = error_msgs + e.to_string() + "; "
    }
    return Err("Parse error: " + error_msgs)
  }

  // impls から関数定義を抽出
  let functions = process_impls(impls, source_file)
  Ok(functions)
}

///|
/// Impl リストを処理して関数メタデータを抽出
fn process_impls(
  impls : @list.List[@syntax.Impl],
  source_file : String,
) -> Array[@ast.FunctionMeta] {
  let result : Array[@ast.FunctionMeta] = []

  // @list.List の反復処理
  impls.each(fn(impl_val) {
    let functions = extract_from_impl(impl_val, source_file)
    for f in functions {
      Array::push(result, f)
    }
  })

  result
}

///|
/// 単一の Impl から関数メタデータを抽出
fn extract_from_impl(
  impl_val : @syntax.Impl,
  source_file : String,
) -> Array[@ast.FunctionMeta] {
  match impl_val {
    TopFuncDef(fun_decl~, loc~) => {
      [convert_fun_decl(fun_decl, loc, source_file)]
    }
    _ => []
  }
}

///|
/// FunDecl を FunctionMeta に変換
fn convert_fun_decl(
  decl : @syntax.FunDecl,
  loc : @basic.Location,
  source_file : String,
) -> @ast.FunctionMeta {
  let location = @ast.Location::unknown(source_file)
  let type_params = extract_type_params(decl.quantifiers)
  let visibility = convert_visibility(decl.vis)

  // 可視性に応じて適切なコンストラクタを使用
  match visibility {
    @ast.Public => @ast.FunctionMeta::with_signature(
      decl.name.name,
      [],
      @ast.TypeMeta::unit(),
      location,
    )
    @ast.Private => @ast.FunctionMeta::new(decl.name.name, location)
    @ast.Internal => @ast.FunctionMeta::new(decl.name.name, location)
  }
}

///|
/// Visibility を変換
fn convert_visibility(vis : @syntax.Visibility) -> @ast.Visibility {
  match vis {
    Default => @ast.make_public()
    Priv(_) => @ast.make_private()
    Pub => @ast.make_public()
  }
}

///|
/// 型パラメータを抽出
fn extract_type_params(
  quantifiers : @list.List[@syntax.TypeVarBinder],
) -> Array[String] {
  let result : Array[String] = []

  quantifiers.each(fn(binder) {
    Array::push(result, binder.name)
  })

  result
}
