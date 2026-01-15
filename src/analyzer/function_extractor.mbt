///|
/// 関数抽出器（コンポーネントA）
/// MoonBitソースコードから公開関数のメタデータを抽出する
///

///|
/// 抽出結果
pub struct ExtractionResult {
  functions : Array[@ast.FunctionMeta]
  types : Array[@ast.TypeDefinition]
  arbitrary_impls : Array[@ast.ArbitraryImpl]
}

///|
/// パースエラー
pub type ExtractError = String

///|
/// ソースコードから関数を抽出（簡易版）
pub fn extract_from_source(
  source : String,
  file : String,
) -> Result[ExtractionResult, ExtractError] {
  let functions = extract_public_functions(source, file)
  let types : Array[@ast.TypeDefinition] = []
  let arbitrary_impls = detect_arbitrary_impls(source)
  Ok({ functions, types, arbitrary_impls })
}

///|
/// 公開関数のメタデータを抽出
pub fn extract_public_functions(
  source : String,
  file : String,
) -> Array[@ast.FunctionMeta] {
  let lines = split_lines(source)
  let mut result : Array[@ast.FunctionMeta] = []
  let mut i = 0
  while i < lines.length() {
    let line = lines[i].trim().to_string()
    if line.has_prefix("pub fn ") {
      let (signature, end_index) = collect_signature(lines, i)
      match parse_signature(signature, file) {
        Some(meta) => result = push_function_meta(result, meta)
        None => ()
      }
      i = end_index + 1
    } else {
      i = i + 1
    }
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
fn collect_signature(lines : Array[String], start_index : Int) -> (String, Int) {
  let mut result = ""
  let mut depth = 0
  let mut seen_paren = false
  let mut i = start_index
  while i < lines.length() {
    let line = lines[i].trim().to_string()
    if result.length() > 0 {
      result = result + " "
    }
    result = result + line
    let chars = line.to_array()
    let mut j = 0
    while j < chars.length() {
      if chars[j] == '(' {
        depth = depth + 1
        seen_paren = true
      } else if chars[j] == ')' {
        if depth > 0 {
          depth = depth - 1
        }
      } else {
        ()
      }
      j = j + 1
    }
    if seen_paren && depth == 0 && (line.contains("{") || line.contains("=")) {
      return (result, i)
    }
    if !seen_paren && line.contains("{") {
      return (result, i)
    }
    i = i + 1
  }
  if lines.length() == 0 {
    ("", start_index)
  } else {
    (result, lines.length() - 1)
  }
}

///|
fn parse_signature(signature : String, file : String) -> @ast.FunctionMeta? {
  let sig = signature.trim().to_string()
  if !sig.has_prefix("pub fn ") {
    return None
  }
  let paren_pos = find_char(sig, '(')
  if paren_pos < 0 {
    return None
  }
  let name_part = substring_range(sig, 7, paren_pos).trim().to_string()
  let (name, type_params) = split_name_and_type_params(name_part)
  if name.length() == 0 {
    return None
  }
  let close_paren = find_matching_paren(sig, paren_pos)
  if close_paren < 0 {
    return None
  }
  let args_str = substring_range(sig, paren_pos + 1, close_paren)
  let args = parse_args_list(args_str)
  let return_type = parse_return_type(sig, close_paren)
  let location = @ast.Location::unknown(file)
  Some(
    @ast.FunctionMeta::with_signature(
      name,
      args,
      return_type,
      location,
      type_params~,
    ),
  )
}

///|
fn split_name_and_type_params(name_part : String) -> (String, Array[String]) {
  let open_pos = find_char(name_part, '[')
  if open_pos < 0 {
    (name_part.trim().to_string(), [])
  } else {
    let close_pos = find_last_char(name_part, ']')
    let name = substring_range(name_part, 0, open_pos).trim().to_string()
    let params = if close_pos > open_pos {
      let params_str = substring_range(name_part, open_pos + 1, close_pos)
      split_params(params_str)
    } else {
      []
    }
    (name, params)
  }
}

///|
fn split_params(params_str : String) -> Array[String] {
  let parts = params_str.split(",").to_array()
  let result : Array[String] = []
  let mut i = 0
  while i < parts.length() {
    let trimmed = parts[i].trim().to_string()
    if trimmed.length() > 0 {
      Array::push(result, trimmed)
    }
    i = i + 1
  }
  result
}

///|
fn parse_args_list(args_str : String) -> Array[@ast.ArgMeta] {
  let mut result : Array[@ast.ArgMeta] = []
  let parts = split_args(args_str)
  let mut i = 0
  while i < parts.length() {
    match parse_arg(parts[i]) {
      Some(arg) => result = push_arg_meta(result, arg)
      None => ()
    }
    i = i + 1
  }
  result
}

///|
fn parse_arg(arg_str : String) -> @ast.ArgMeta? {
  let trimmed = arg_str.trim().to_string()
  if trimmed.length() == 0 {
    return None
  }
  let eq_pos = find_top_level_char(trimmed, '=')
  let (left, default_value) = if eq_pos >= 0 {
    let left = substring_range(trimmed, 0, eq_pos).trim().to_string()
    let right = substring_range(trimmed, eq_pos + 1, trimmed.length())
      .trim()
      .to_string()
    (left, Some(right))
  } else {
    (trimmed, None)
  }
  let colon_pos = find_top_level_char(left, ':')
  if colon_pos < 0 {
    return None
  }
  let mut name = substring_range(left, 0, colon_pos).trim().to_string()
  let type_str = substring_range(left, colon_pos + 1, left.length())
    .trim()
    .to_string()
  let mut is_optional = false
  if name.has_suffix("?") {
    is_optional = true
    name = substring_range(name, 0, name.length() - 1)
  }
  if name.has_suffix("~") {
    name = substring_range(name, 0, name.length() - 1)
  }
  let type_ = parse_type_meta(type_str)
  Some(@ast.ArgMeta::with_options(name, type_, is_optional, default_value))
}

///|
fn parse_return_type(signature : String, close_paren : Int) -> @ast.TypeMeta {
  let tail = substring_range(signature, close_paren + 1, signature.length())
  let arrow_pos = match tail.find("->"[:]) {
    Some(pos) => pos
    None => -1
  }
  if arrow_pos < 0 {
    return @ast.TypeMeta::unit()
  }
  let mut after = substring_range(tail, arrow_pos + 2, tail.length())
    .trim()
    .to_string()
  let mut end_pos = after.length()
  let raise_pos = match after.find("raise"[:]) {
    Some(pos) => pos
    None => -1
  }
  if raise_pos >= 0 && raise_pos < end_pos {
    end_pos = raise_pos
  }
  let brace_pos = find_char(after, '{')
  if brace_pos >= 0 && brace_pos < end_pos {
    end_pos = brace_pos
  }
  let eq_pos = find_char(after, '=')
  if eq_pos >= 0 && eq_pos < end_pos {
    end_pos = eq_pos
  }
  after = substring_range(after, 0, end_pos).trim().to_string()
  parse_type_meta(after)
}

///|
fn parse_type_meta(type_str : String) -> @ast.TypeMeta {
  let trimmed = type_str.trim().to_string()
  if trimmed.length() == 0 || trimmed == "Unit" {
    @ast.TypeMeta::unit()
  } else {
    @ast.TypeMeta::named(trimmed)
  }
}

///|
fn split_args(args_str : String) -> Array[String] {
  let result : Array[String] = []
  let mut current = ""
  let mut depth_paren = 0
  let mut depth_bracket = 0
  let chars = args_str.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == ',' && depth_paren == 0 && depth_bracket == 0 {
      let part = current.trim().to_string()
      if part.length() > 0 {
        Array::push(result, part)
      }
      current = ""
    } else {
      if c == '(' {
        depth_paren = depth_paren + 1
      } else if c == ')' {
        if depth_paren > 0 {
          depth_paren = depth_paren - 1
        }
      } else if c == '[' {
        depth_bracket = depth_bracket + 1
      } else if c == ']' {
        if depth_bracket > 0 {
          depth_bracket = depth_bracket - 1
        }
      }
      current = current + c.to_string()
    }
    i = i + 1
  }
  let last = current.trim().to_string()
  if last.length() > 0 {
    Array::push(result, last)
  }
  result
}

///|
fn find_matching_paren(s : String, start : Int) -> Int {
  let chars = s.to_array()
  let mut depth = 0
  let mut i = start
  while i < chars.length() {
    if chars[i] == '(' {
      depth = depth + 1
    } else if chars[i] == ')' {
      depth = depth - 1
      if depth == 0 {
        return i
      }
    }
    i = i + 1
  }
  -1
}

///|
fn find_top_level_char(s : String, target : Char) -> Int {
  let chars = s.to_array()
  let mut depth_paren = 0
  let mut depth_bracket = 0
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '(' {
      depth_paren = depth_paren + 1
    } else if c == ')' {
      if depth_paren > 0 {
        depth_paren = depth_paren - 1
      }
    } else if c == '[' {
      depth_bracket = depth_bracket + 1
    } else if c == ']' {
      if depth_bracket > 0 {
        depth_bracket = depth_bracket - 1
      }
    }
    if c == target && depth_paren == 0 && depth_bracket == 0 {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn find_last_char(s : String, target : Char) -> Int {
  let chars = s.to_array()
  let mut i = chars.length() - 1
  while i >= 0 {
    if chars[i] == target {
      return i
    }
    i = i - 1
  }
  -1
}

///|
fn push_function_meta(
  arr : Array[@ast.FunctionMeta],
  elem : @ast.FunctionMeta,
) -> Array[@ast.FunctionMeta] {
  let result : Array[@ast.FunctionMeta] = []
  let mut i = 0
  while i < arr.length() {
    Array::push(result, arr[i])
    i = i + 1
  }
  Array::push(result, elem)
  result
}

///|
fn push_arg_meta(
  arr : Array[@ast.ArgMeta],
  elem : @ast.ArgMeta,
) -> Array[@ast.ArgMeta] {
  let result : Array[@ast.ArgMeta] = []
  let mut i = 0
  while i < arr.length() {
    Array::push(result, arr[i])
    i = i + 1
  }
  Array::push(result, elem)
  result
}

///|
/// 文字列の範囲を抽出
fn substring_range(s : String, start : Int, end : Int) -> String {
  let chars = s.to_array()
  let mut result = ""
  let mut i = start
  while i < end {
    result = result + chars[i].to_string()
    i = i + 1
  }
  result
}

///|
/// 文字列から文字の位置を検索
fn find_char(s : String, c : Char) -> Int {
  let chars = s.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == c {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// テスト
test "extract_from_source_simple" {
  let source = "pub fn add(a : Int, b : Int) -> Int {\n  a + b\n}\n\npub struct Point {\n  x : Int\n  y : Int\n}"
  let result = extract_from_source(source, "test.mbt")
  match result {
    Ok(r) => {
      inspect(r.functions.length(), content="1")
      inspect(r.types.length(), content="0")
    }
    Err(_) => inspect("false", content="true")
  }
}

///|
test "extract_from_source_counts" {
  let source = "pub fn add(a : Int, b : Int) -> Int { a + b }\npub fn sub(a : Int, b : Int) -> Int { a - b }\npub struct Point { x : Int }"
  let result = extract_from_source(source, "test.mbt")
  match result {
    Ok(r) => {
      inspect(r.functions.length(), content="2")
      inspect(r.types.length(), content="0")
    }
    Err(_) => inspect("false", content="true")
  }
}

///|
test "extract_from_source_signature" {
  let source = "pub fn g(\n  data~ : Array[String],\n  start? : Int = 0,\n) -> String { \"\" }"
  let result = extract_from_source(source, "test.mbt")
  match result {
    Ok(r) => {
      inspect(r.functions.length(), content="1")
      let sig = r.functions[0].signature()
      inspect(sig, content="(Array[String], Int) -> String")
    }
    Err(_) => inspect("false", content="true")
  }
}
