///|
/// Analyzerモジュール PBT Dogfooding Tests
/// analyzerモジュール（function_extractor, arbitrary_detector）に対するプロパティテスト
///
/// このファイルでは、Aletheiaのanalyzerモジュールに対して
/// Round-tripおよびIdempotentパターンのプロパティテストを実装します。

//==============================================================
// Function Extractor モジュールのテスト
//==============================================================

///|
/// extract_function_names と extract_public_functions の数は一致する
/// 同じソースコードに対して、名前のみの抽出とメタデータの抽出で同じ数の関数が見つかる
test "prop_extract_names_count_consistent" {
  let config = @pbt.CheckConfig::new(100, 50, 1001, 10)

  // テスト用のMoonBitソースコードを生成
  let gen_fn_name = @pbt.Gen::one_of([
    @pbt.Gen::pure("add"),
    @pbt.Gen::pure("sub"),
    @pbt.Gen::pure("mul"),
    @pbt.Gen::pure("div"),
    @pbt.Gen::pure("foo"),
    @pbt.Gen::pure("bar"),
    @pbt.Gen::pure("baz"),
  ])
  let gen_function = @pbt.Gen::map(gen_fn_name, fn(name) {
    "pub fn " + name + "(a : Int, b : Int) -> Int { a + b }\n"
  })
  let gen_source = @pbt.Gen::array_of(gen_function)
  @pbt.assert_check(
    "extract_function_names count consistent",
    gen_source,
    fn(source_lines) {
      let source = join_lines(source_lines)
      let names = @analyzer.extract_function_names(source)
      let metas = @analyzer.extract_public_functions(source, "test.mbt")
      let name_count = names.length()
      let meta_count = metas.length()
      if name_count == meta_count {
        Ok(())
      } else {
        Err(
          "count mismatch: names=" +
          int_to_string_a(name_count) +
          " metas=" +
          int_to_string_a(meta_count),
        )
      }
    },
    config~,
  )
}

///|
/// extract_function_names の全ての名前が extract_public_functions に含まれる
/// 名前抽出とメタデータ抽出の結果に不一致がない
test "prop_extract_names_subset" {
  let config = @pbt.CheckConfig::new(100, 50, 1002, 10)
  let gen_fn_name = @pbt.Gen::one_of([
    @pbt.Gen::pure("process"),
    @pbt.Gen::pure("handle"),
    @pbt.Gen::pure("transform"),
    @pbt.Gen::pure("compute"),
  ])
  let gen_function = @pbt.Gen::map(gen_fn_name, fn(name) {
    "pub fn " + name + "(x : Int) -> Int { x }\n"
  })
  let gen_source = @pbt.Gen::array_of(gen_function)
  @pbt.assert_check(
    "extract_function_names subset",
    gen_source,
    fn(source_lines) {
      let source = join_lines(source_lines)
      let names = @analyzer.extract_function_names(source)
      let metas = @analyzer.extract_public_functions(source, "test.mbt")

      // 名前が全てメタデータに含まれるか確認
      let mut all_found = true
      let mut i = 0
      while i < names.length() {
        let name = names[i]
        let mut found = false
        let mut j = 0
        while j < metas.length() {
          if metas[j].name == name {
            found = true
          }
          j = j + 1
        }
        if !found {
          all_found = false
        }
        i = i + 1
      }
      if all_found {
        Ok(())
      } else {
        Err("name not found in metas")
      }
    },
    config~,
  )
}

///|
/// 空入力は空配列を返す（Idempotent）
test "prop_extract_function_names_empty" {
  let source = ""
  let names = @analyzer.extract_function_names(source)
  inspect(names.length(), content="0")
}

///|
/// pub fn と priv fn を正しく区別
test "prop_extract_function_names_distinguishes_pub_priv" {
  let source = "pub fn public_func() -> Int { 1 }\npriv fn private_func() -> Int { 2 }"
  let names = @analyzer.extract_function_names(source)
  inspect(names.length(), content="1")
  inspect(names[0], content="public_func")
}

///|
/// extract_function_names 複雑なシグネチャ対応
test "prop_extract_function_names_complex_signatures" {
  // 有効なMoonBit構文を使用する（関数本体は複数行で記述）
  let source = "pub fn f1() -> Int {\n  1\n}\npub fn f2(x : Int) -> Int {\n  x\n}\npub fn f3(a : Int, b : Int, c : Int) -> Int {\n  a + b + c\n}\npub fn f4(\n  x : Int,\n  y : Int,\n) -> Int {\n  x + y\n}"
  let names = @analyzer.extract_function_names(source)
  inspect(names.length(), content="4")
}

//==============================================================
// Arbitrary Detector モジュールのテスト
//==============================================================

///|
/// detect_arbitrary_impls は全プリミティブ型を含む（Idempotent）
test "prop_arbitrary_primitives_complete" {
  let impls = @analyzer.detect_arbitrary_impls("")

  // プリミティブ型が全て含まれる
  let primitives = @analyzer.primitive_types()
  let mut all_found = true
  let mut i = 0
  while i < primitives.length() {
    let prim = primitives[i]
    if !@analyzer.has_arbitrary(prim, impls) {
      all_found = false
    }
    i = i + 1
  }
  inspect(all_found, content="true")
}

///|
/// has_arbitrary はプリミティブ型に対して常にtrue
test "prop_has_arbitrary_reflexive_primitives" {
  let impls = @analyzer.detect_arbitrary_impls("")
  let primitives = @analyzer.primitive_types()
  let mut all_true = true
  let mut i = 0
  while i < primitives.length() {
    let prim = primitives[i]
    if !@analyzer.has_arbitrary(prim, impls) {
      all_true = false
    }
    i = i + 1
  }
  inspect(all_true, content="true")
}

///|
/// has_arbitrary はユーザー定義型を正しく検出
test "prop_has_arbitrary_user_defined" {
  let source = "impl Arbitrary for MyType\nimpl Arbitrary for OtherType"
  let impls = @analyzer.detect_arbitrary_impls(source)
  inspect(@analyzer.has_arbitrary("MyType", impls), content="true")
  inspect(@analyzer.has_arbitrary("OtherType", impls), content="true")
  inspect(@analyzer.has_arbitrary("UnknownType", impls), content="false")
}

///|
/// check_type_testability と has_arbitrary の一貫性（Round-trip）
/// プリミティブ型は常にTestable
test "prop_check_type_testability_consistent" {
  let impls = @analyzer.detect_arbitrary_impls("")
  let primitives = @analyzer.primitive_types()
  let mut all_testable = true
  let mut i = 0
  while i < primitives.length() {
    let prim = primitives[i]
    let result = @analyzer.check_type_testability(prim, impls)
    match result {
      r => {
        // Testableケースの確認
        let is_testable = match r {
          @ast.Testability::Testable => true
          _ => false
        }
        if !is_testable {
          all_testable = false
        }
      }
    }
    i = i + 1
  }
  inspect(all_testable, content="true")
}

///|
/// check_type_testability はユーザー定義型をNeedsUserArbitraryと判定
test "prop_check_type_testability_user_defined" {
  let impls = @analyzer.detect_arbitrary_impls("")
  let result = @analyzer.check_type_testability("MyCustomType", impls)
  match result {
    @ast.Testability::NeedsUserArbitrary(types) =>
      inspect(types.length() > 0 && types[0] == "MyCustomType", content="true")
    _ => inspect("should be NeedsUserArbitrary", content="fail")
  }
}

///|
/// check_type_testability はコンテナ型の内部型をチェック
test "prop_check_type_testability_container_primitive" {
  let impls = @analyzer.detect_arbitrary_impls("")

  // Array[Int] は Testable
  let result1 = @analyzer.check_type_testability("Array[Int]", impls)
  match result1 {
    @ast.Testability::Testable => inspect("ok", content="ok")
    _ => inspect("Array[Int] should be Testable", content="fail")
  }

  // Array[MyType] は NeedsUserArbitrary
  let result2 = @analyzer.check_type_testability("Array[MyType]", impls)
  match result2 {
    @ast.Testability::NeedsUserArbitrary(_) => inspect("ok", content="ok")
    _ => inspect("Array[MyType] should be NeedsUserArbitrary", content="fail")
  }
}

///|
/// check_type_testability はMapの両方の型をチェック
test "prop_check_type_testability_map_types" {
  let impls = @analyzer.detect_arbitrary_impls("")

  // Map[String, Int] は Testable
  let result1 = @analyzer.check_type_testability("Map[String, Int]", impls)
  match result1 {
    @ast.Testability::Testable => inspect("ok", content="ok")
    _ => inspect("Map[String, Int] should be Testable", content="fail")
  }

  // Map[MyType, Int] は NeedsUserArbitrary
  let result2 = @analyzer.check_type_testability("Map[MyType, Int]", impls)
  match result2 {
    @ast.Testability::NeedsUserArbitrary(_) => inspect("ok", content="ok")
    _ =>
      inspect("Map[MyType, Int] should be NeedsUserArbitrary", content="fail")
  }
}

///|
/// check_function_testability はプリミティブ引数のみでTestable
test "prop_check_function_testability_primitives" {
  let impls = @analyzer.detect_arbitrary_impls("")

  // テスト用の関数メタデータを作成
  let location = @ast.Location::unknown("test.mbt")
  let args = [
    @ast.ArgMeta::new("x", @ast.TypeMeta::named("Int")),
    @ast.ArgMeta::new("y", @ast.TypeMeta::named("Int")),
  ]
  let func = @ast.FunctionMeta::with_signature(
    "add",
    args,
    @ast.TypeMeta::named("Int"),
    location,
    type_params=[],
  )
  let result = @analyzer.check_function_testability(func, impls)
  match result {
    @ast.Testability::Testable => inspect("ok", content="ok")
    _ => inspect("should be Testable", content="fail")
  }
}

///|
/// check_function_testability はユーザー定義型引数でNeedsUserArbitrary
test "prop_check_function_testability_custom_type" {
  let impls = @analyzer.detect_arbitrary_impls("")
  let location = @ast.Location::unknown("test.mbt")
  let args = [@ast.ArgMeta::new("x", @ast.TypeMeta::named("MyType"))]
  let func = @ast.FunctionMeta::with_signature(
    "process",
    args,
    @ast.TypeMeta::named("Int"),
    location,
    type_params=[],
  )
  let result = @analyzer.check_function_testability(func, impls)
  match result {
    @ast.Testability::NeedsUserArbitrary(_) => inspect("ok", content="ok")
    _ => inspect("should be NeedsUserArbitrary", content="fail")
  }
}

///|
/// extract_with_testability は関数とテスト可能性を抽出する
test "prop_extract_with_testability_basic" {
  let source = "pub fn add(x : Int, y : Int) -> Int { x + y }\npub fn process(s : String) -> Int { 0 }"
  let result = @analyzer.extract_with_testability(source, "test.mbt")

  // 2つの公開関数が見つかる
  inspect(result.functions.length(), content="2")
  // 両方ともプリミティブ型のみなので testable
  inspect(result.testable_functions.length(), content="2")
  // ユーザー定義型は不要
  inspect(result.needs_arbitrary.length(), content="0")
}

///|
/// extract_with_testability はジェネリック型のテスト可能性を判定する
test "prop_extract_with_testability_generic_types" {
  let source = "pub fn process_list(xs : Array[Int]) -> Int { 0 }\npub fn process_custom(x : MyType) -> Int { 0 }"
  let result = @analyzer.extract_with_testability(source, "test.mbt")

  // 2つの公開関数が見つかる
  inspect(result.functions.length(), content="2")
  // Array[Int] は testable (Int はプリミティブ)
  inspect(result.testable_functions.length(), content="1")
  inspect(result.testable_functions[0], content="process_list")
  // MyType はユーザー定義型が必要
  inspect(result.needs_arbitrary.length(), content="1")
  inspect(result.needs_arbitrary[0], content="MyType")
}

///|
/// extract_public_functions はジェネリック型を正しく抽出する
test "prop_extract_public_functions_generic_types" {
  let source = "pub fn process_array(xs : Array[Int]) -> Int { 0 }\npub fn process_map(m : Map[String, Int]) -> Int { 0 }"
  let functions = @analyzer.extract_public_functions(source, "test.mbt")

  inspect(functions.length(), content="2")

  // 最初の関数: process_array(xs : Array[Int]) -> Int
  let func1 = functions[0]
  inspect(func1.name, content="process_array")
  inspect(func1.args.length(), content="1")
  match func1.args[0].type_ {
    @ast.TypeMeta::Generic(name, inner_types) => {
      inspect(name, content="Array")
      inspect(inner_types.length(), content="1")
      match inner_types[0] {
        @ast.TypeMeta::Named(inner_name) => inspect(inner_name, content="Int")
        _ => inspect("should be Named", content="fail")
      }
    }
    _ => inspect("should be Generic", content="fail")
  }

  // 2番目の関数: process_map(m : Map[String, Int]) -> Int
  let func2 = functions[1]
  inspect(func2.name, content="process_map")
  inspect(func2.args.length(), content="1")
  match func2.args[0].type_ {
    @ast.TypeMeta::Generic(name, inner_types) => {
      inspect(name, content="Map")
      inspect(inner_types.length(), content="2")
      match inner_types[0] {
        @ast.TypeMeta::Named(inner_name) => inspect(inner_name, content="String")
        _ => inspect("should be Named", content="fail")
      }
      match inner_types[1] {
        @ast.TypeMeta::Named(inner_name) => inspect(inner_name, content="Int")
        _ => inspect("should be Named", content="fail")
      }
    }
    _ => inspect("should be Generic", content="fail")
  }
}

//==============================================================
// ユーティリティ関数
//==============================================================

///|
/// 行配列を結合
fn join_lines(lines : Array[String]) -> String {
  let mut result = ""
  let mut i = 0
  while i < lines.length() {
    result = result + lines[i]
    i = i + 1
  }
  result
}

///|
/// IntをStringに変換（analyzer_test用）
fn int_to_string_a(n : Int) -> String {
  if n < 0 {
    "-" + int_to_string_a(-n)
  } else if n == 0 {
    "0"
  } else if n < 10 {
    match n {
      1 => "1"
      2 => "2"
      3 => "3"
      4 => "4"
      5 => "5"
      6 => "6"
      7 => "7"
      8 => "8"
      _ => "9"
    }
  } else {
    int_to_string_a(n / 10) + int_to_string_a(n % 10)
  }
}
