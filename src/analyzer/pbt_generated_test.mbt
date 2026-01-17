///|
test "prop_extract_function_names_skips_private" {
  let source : String =
    #|fn private_fn() -> Int { 1 }
    #|pub fn public_fn() -> Int { 2 }
    #|
  let names = extract_function_names(source)
  inspect(names.length(), content="1")
  inspect(names[0], content="public_fn")
}

///|
test "prop_extract_public_functions_reads_signature" {
  let source : String =
    #|pub fn greet(name : String, times : Int) -> String { "hi" }
    #|
  let funcs = extract_public_functions(source, "sample.mbt")
  inspect(funcs.length(), content="1")
  let f = funcs[0]
  inspect(f.name, content="greet")
  inspect(f.args.length(), content="2")
  inspect(f.args[0].type_.simple_name(), content="String")
  inspect(f.return_type.simple_name(), content="String")
}

///|
test "prop_detect_arbitrary_impls_finds_user_defined" {
  let source : String =
    #|impl Arbitrary for Foo
    #|pub fn build() -> Int { 1 }
    #|
  let impls = detect_arbitrary_impls(source)
  let mut found = false
  let mut i = 0
  while i < impls.length() {
    if impls[i].type_name == "Foo" {
      found = true
    }
    i = i + 1
  }
  inspect(found, content="true")
}

///|
test "prop_extract_generic_function_captures_type_params" {
  let source : String =
    #|pub fn identity[T](x : T) -> T { x }
    #|
  let funcs = extract_public_functions(source, "sample.mbt")
  inspect(funcs.length(), content="1")
  let f = funcs[0]
  inspect(f.name, content="identity")
  inspect(f.type_params.length(), content="1")
  inspect(f.type_params[0], content="T")
}

///|
test "prop_extract_generic_function_with_multiple_type_params" {
  let source : String =
    #|pub fn swap[A, B](x : A, y : B) -> (B, A) { (y, x) }
    #|
  let funcs = extract_public_functions(source, "sample.mbt")
  inspect(funcs.length(), content="1")
  let f = funcs[0]
  inspect(f.name, content="swap")
  inspect(f.type_params.length(), content="2")
  inspect(f.type_params[0], content="A")
  inspect(f.type_params[1], content="B")
}

///|
test "prop_extract_non_generic_function_has_empty_type_params" {
  let source : String =
    #|pub fn add(x : Int, y : Int) -> Int { x + y }
    #|
  let funcs = extract_public_functions(source, "sample.mbt")
  inspect(funcs.length(), content="1")
  let f = funcs[0]
  inspect(f.name, content="add")
  inspect(f.type_params.length(), content="0")
}
