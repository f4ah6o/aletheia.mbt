///|
/// ASTベースの関数抽出モジュール
/// moonbitlang/parserを使用してソースコードから関数メタデータを抽出する
///

///|
/// 公開関数のメタデータを抽出
/// CLIから呼び出されるメインエントリポイント
pub fn extract_public_functions(
  source : String,
  source_file : String,
) -> Array[@ast.FunctionMeta] {
  match extract_from_source_ast(source, source_file) {
    Ok(functions) => filter_public_functions(functions)
    Err(_) => []
  }
}

///|
/// 公開関数のみをフィルタリング
fn filter_public_functions(
  functions : Array[@ast.FunctionMeta],
) -> Array[@ast.FunctionMeta] {
  let result : Array[@ast.FunctionMeta] = []
  let mut i = 0
  while i < functions.length() {
    let f = functions[i]
    match f.visibility {
      @ast.Public => Array::push(result, f)
      _ => ()
    }
    i = i + 1
  }
  result
}

///|
/// pub fn xxx(...) 形式の関数名を抽出
pub fn extract_function_names(source : String) -> Array[String] {
  let functions = extract_public_functions(source, "unknown")
  let result : Array[String] = []
  let mut i = 0
  while i < functions.length() {
    Array::push(result, functions[i].name)
    i = i + 1
  }
  result
}

///|
/// ソースコードから関数メタデータを抽出（詳細版）
fn extract_from_source_ast(
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
    TopFuncDef(fun_decl~, ..) => [convert_fun_decl(fun_decl, source_file)]
    _ => []
  }
}

///|
/// FunDecl を FunctionMeta に変換
fn convert_fun_decl(
  decl : @syntax.FunDecl,
  source_file : String,
) -> @ast.FunctionMeta {
  let location = @ast.Location::unknown(source_file)
  let _type_params = extract_type_params(decl.quantifiers)
  let visibility = convert_visibility(decl.vis)

  // パラメータを抽出
  let args = extract_params(decl.decl_params)

  // 戻り値の型を抽出
  let return_type = extract_return_type(decl.return_type)

  // 可視性に応じて適切なコンストラクタを使用
  match visibility {
    @ast.Public =>
      @ast.FunctionMeta::with_signature(
        decl.name.name,
        args,
        return_type,
        location,
        type_params=_type_params,
      )
    @ast.Private => @ast.FunctionMeta::new(decl.name.name, location)
    @ast.Internal => @ast.FunctionMeta::new(decl.name.name, location)
  }
}

///|
/// パラメータを抽出
fn extract_params(params : @syntax.Parameters?) -> Array[@ast.ArgMeta] {
  match params {
    Some(param_list) => convert_params(param_list)
    None => []
  }
}

///|
/// Parameters を ArgMeta 配列に変換
fn convert_params(
  params : @list.List[@syntax.Parameter],
) -> Array[@ast.ArgMeta] {
  let result : Array[@ast.ArgMeta] = []
  params.each(fn(p) {
    let arg = convert_param(p)
    match arg {
      Some(a) => Array::push(result, a)
      None => ()
    }
  })
  result
}

///|
/// 単一の Parameter を ArgMeta に変換
fn convert_param(param : @syntax.Parameter) -> @ast.ArgMeta? {
  match param {
    Positional(binder~, ty~) =>
      Some(
        @ast.ArgMeta::with_options(binder.name, convert_type(ty), false, None),
      )
    Labelled(binder~, ty~) =>
      Some(
        @ast.ArgMeta::with_options(binder.name, convert_type(ty), false, None),
      )
    Optional(binder~, ty~, ..) =>
      Some(
        @ast.ArgMeta::with_options(
          binder.name,
          convert_type(ty),
          true,
          Some("default"),
        ),
      )
    QuestionOptional(binder~, ty~) =>
      Some(
        @ast.ArgMeta::with_options(binder.name, convert_type(ty), true, None),
      )
    DiscardPositional(..) =>
      // _ : Int のような場合はスキップ
      None
  }
}

///|
/// Type を TypeMeta に変換
fn convert_type(ty : @syntax.Type?) -> @ast.TypeMeta {
  match ty {
    Some(t) => convert_type_to_meta(t)
    None => @ast.TypeMeta::unit()
  }
}

///|
/// Type を TypeMeta に変換
fn convert_type_to_meta(ty : @syntax.Type) -> @ast.TypeMeta {
  match ty {
    Name(constr_id~, tys~, ..) => {
      // 名前付き型: Int, String, Array[Int] など
      let name = extract_constr_id_name(constr_id)
      // 型パラメータを抽出して再帰的に変換
      let inner_types = convert_type_list(tys)
      if inner_types.length() > 0 {
        @ast.TypeMeta::generic(name, inner_types)
      } else {
        @ast.TypeMeta::named(name)
      }
    }
    Arrow(..) => @ast.TypeMeta::named("Function")
    Tuple(..) => @ast.TypeMeta::named("Tuple")
    Option(..) => @ast.TypeMeta::named("Option")
    Object(_) => @ast.TypeMeta::named("Object")
    Any(_) => @ast.TypeMeta::named("Any")
  }
}

///|
/// Type リストを TypeMeta 配列に変換
fn convert_type_list(types : @list.List[@syntax.Type]) -> Array[@ast.TypeMeta] {
  let result : Array[@ast.TypeMeta] = []
  types.each(fn(t) { Array::push(result, convert_type_to_meta(t)) })
  result
}

///|
/// ConstrId から名前を抽出
fn extract_constr_id_name(constr_id : @syntax.ConstrId) -> String {
  match constr_id.id {
    Ident(name~) => name
    Dot(..) => "Unknown" // pkg::Type 形式はとりあえず "Unknown"
  }
}

///|
/// 戻り値の型を抽出
fn extract_return_type(ret : @syntax.Type?) -> @ast.TypeMeta {
  convert_type(ret)
}

///|
/// Visibility を変換
fn convert_visibility(vis : @syntax.Visibility) -> @ast.Visibility {
  match vis {
    Default => @ast.make_private() // pub なしは private
    Priv(_) => @ast.make_private()
    Pub(..) => @ast.make_public() // pub 付きは public
  }
}

///|
/// 型パラメータを抽出
fn extract_type_params(
  quantifiers : @list.List[@syntax.TypeVarBinder],
) -> Array[String] {
  let result : Array[String] = []
  quantifiers.each(fn(binder) { Array::push(result, binder.name) })
  result
}

///|
/// ソースコードから関数とテスト可能性をまとめて抽出
pub fn extract_with_testability(
  source : String,
  source_file : String,
) -> @ast.ExtractionResult {
  let functions = extract_public_functions(source, source_file)
  let arbitrary_impls = detect_arbitrary_impls(source)
  let testable_functions : Array[String] = []
  let needs_arbitrary : Array[String] = []
  let mut i = 0
  while i < functions.length() {
    let func = functions[i]
    let testability = check_function_testability(func, arbitrary_impls)
    match testability {
      @ast.Testability::Testable => Array::push(testable_functions, func.name)
      @ast.Testability::NeedsUserArbitrary(types) => {
        let mut j = 0
        while j < types.length() {
          if !string_array_contains(needs_arbitrary, types[j]) {
            Array::push(needs_arbitrary, types[j])
          }
          j = j + 1
        }
      }
      @ast.Testability::NotTestable(_) => ()
    }
    i = i + 1
  }
  @ast.ExtractionResult::new(source_file)
  |> @ast.ExtractionResult::with_functions(functions)
  |> @ast.ExtractionResult::with_arbitrary_impls(arbitrary_impls)
  |> @ast.ExtractionResult::with_testable_functions(testable_functions)
  |> @ast.ExtractionResult::with_needs_arbitrary(needs_arbitrary)
}
