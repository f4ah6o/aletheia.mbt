///|
/// パターンを配列に追加
fn append_pattern(
  arr : Array[@patterns.PatternCandidate],
  pat : @patterns.PatternCandidate,
) -> Array[@patterns.PatternCandidate] {
  let n = arr.length()
  let result : Array[@patterns.PatternCandidate] = []
  let mut i = 0
  while i < n {
    Array::push(result, arr[i])
    i = i + 1
  }
  Array::push(result, pat)
  result
}

///|
/// 文字列配列の末尾に要素を追加
fn push_strings(target : Array[String], items : Array[String]) -> Array[String] {
  let mut i = 0
  while i < items.length() {
    Array::push(target, items[i])
    i = i + 1
  }
  target
}

///|
/// 関数メタデータ配列の末尾に要素を追加
fn push_functions(
  target : Array[@ast.FunctionMeta],
  items : Array[@ast.FunctionMeta],
) -> Array[@ast.FunctionMeta] {
  let mut i = 0
  while i < items.length() {
    Array::push(target, items[i])
    i = i + 1
  }
  target
}

///|
fn push_arbitrary_impls(
  target : Array[@ast.ArbitraryImpl],
  items : Array[@ast.ArbitraryImpl],
) -> Array[@ast.ArbitraryImpl] {
  let mut i = 0
  while i < items.length() {
    Array::push(target, items[i])
    i = i + 1
  }
  target
}

///|
/// IntをStringに変換
fn int_to_string(n : Int) -> String {
  if n < 0 {
    "-" + int_to_string(-n)
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
    int_to_string(n / 10) + int_to_string(n % 10)
  }
}
