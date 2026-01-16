///|
pub fn shrink_int(x : Int) -> Iter[Int] {
  if x == 0 {
    return [].iter()
  }
  let candidates : Array[Int] = [0]
  let mut current = x / 2
  while current != 0 {
    candidates.push(current)
    current = current / 2
  }
  candidates.iter()
}

///|
pub fn[T] shrink_array(values : Array[T]) -> Iter[Array[T]] {
  let len = values.length()
  if len == 0 {
    return [].iter()
  }
  let candidates : Array[Array[T]] = []
  let mut n = len / 2
  while n > 0 {
    candidates.push(values[:n].to_array())
    n = n / 2
  }
  candidates.push([])
  candidates.iter()
}

///|
/// 文字列のshrink
/// 空文字列に向けて縮小し、部分文字列を試す
pub fn shrink_string(s : String) -> Iter[String] {
  if s == "" {
    return [].iter()
  }
  let candidates : Array[String] = []
  let chars = s.to_array()
  let len = chars.length()

  // 空文字列を最初に試す
  candidates.push("")

  // 長さを半分ずつにする
  let mut n = len / 2
  while n > 0 {
    let mut result = ""
    let mut i = 0
    while i < n {
      result = result + chars[i].to_string()
      i = i + 1
    }
    candidates.push(result)
    n = n / 2
  }

  // 各文字を削除した文字列
  let mut i = 0
  while i < len && i < 10 {
    // 最初の10文字だけ試す
    let mut result = ""
    let mut j = 0
    while j < len {
      if j != i {
        result = result + chars[j].to_string()
      }
      j = j + 1
    }
    candidates.push(result)
    i = i + 1
  }
  candidates.iter()
}

///|
/// タプルのshrink
/// 両方の要素をshrinkし、それぞれを固定してもう一方をshrinkする
pub fn[A, B] shrink_tuple2(
  t : (A, B),
  shrink_a : (A) -> Iter[A],
  shrink_b : (B) -> Iter[B],
) -> Iter[(A, B)] {
  let (a, b) = t
  let candidates : Array[(A, B)] = []

  // aをshrinkしてbを固定
  for a_shrunk in shrink_a(a) {
    candidates.push((a_shrunk, b))
  }

  // bをshrinkしてaを固定
  for b_shrunk in shrink_b(b) {
    candidates.push((a, b_shrunk))
  }
  candidates.iter()
}

///|
/// Optionのshrink
/// Some(x)をNoneに縮小し、Some(x)の中身もshrinkする
pub fn[T] shrink_option(opt : T?, shrink_t : (T) -> Iter[T]) -> Iter[T?] {
  match opt {
    None => [].iter()
    Some(value) => {
      let candidates : Array[T?] = []
      // Noneを最初に試す
      candidates.push(None)
      // 中身をshrinkする
      for v in shrink_t(value) {
        candidates.push(Some(v))
      }
      candidates.iter()
    }
  }
}

///|
/// Double のshrink
/// 0に向けて縮小する
pub fn shrink_double(x : Double) -> Iter[Double] {
  if x == 0.0 {
    return [].iter()
  }
  let candidates : Array[Double] = [0.0]
  let mut current = x / 2.0
  let mut count = 0
  while current.abs() > 0.001 && count < 10 {
    candidates.push(current)
    current = current / 2.0
    count = count + 1
  }
  candidates.iter()
}

///|
/// Bool のshrink
/// trueをfalseに縮小する
pub fn shrink_bool(b : Bool) -> Iter[Bool] {
  if b {
    [false].iter()
  } else {
    [].iter()
  }
}

///|
/// Shrinkテンプレートを生成（コード生成用）
pub fn generate_shrink_template(
  type_name : String,
  fields : Array[(String, String)],
) -> String {
  let mut result = "fn shrink_" +
    type_name.to_lower() +
    "(value : " +
    type_name +
    ") -> Iter[" +
    type_name +
    "] {\n"
  result = result + "  let candidates : Array[" + type_name + "] = []\n"

  // 各フィールドをshrinkしてcandidatesに追加
  let mut i = 0
  while i < fields.length() {
    let (field_name, field_type) = fields[i]
    let shrinker = match field_type {
      "Int" => "shrink_int"
      "String" => "shrink_string"
      "Bool" => "shrink_bool"
      "Double" => "shrink_double"
      _ => "shrink_" + field_type.to_lower()
    }
    result = result +
      "  for v in " +
      shrinker +
      "(value." +
      field_name +
      ") {\n"
    result = result + "    candidates.push({ .." + field_name + ": v })\n"
    result = result + "  }\n"
    i = i + 1
  }
  result = result + "  candidates.iter()\n"
  result = result + "}\n"
  result
}

///|
fn string_to_lower(s : String) -> String {
  let chars = s.to_array()
  let mut result = ""
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    let code = c.to_int()
    if code >= 65 && code <= 90 {
      result = result + Int::unsafe_to_char(code + 32).to_string()
    } else {
      result = result + c.to_string()
    }
    i = i + 1
  }
  result
}

///|
test "shrink_string_empty" {
  let result = shrink_string("")
  inspect(result.count(), content="0")
}

///|
test "shrink_string_nonempty" {
  let result = shrink_string("hello")
  let arr = result.to_array()
  inspect(arr.length() > 0, content="true")
  inspect(arr.contains(""), content="true")
}

///|
test "shrink_option_none" {
  let result = shrink_option((None : Int?), shrink_int)
  inspect(result.count(), content="0")
}

///|
test "shrink_option_some" {
  let result = shrink_option(Some(10), shrink_int)
  let arr = result.to_array()
  inspect(arr.length() > 0, content="true")
  inspect(arr.contains(None), content="true")
}

///|
test "shrink_bool_true" {
  let result = shrink_bool(true)
  let arr = result.to_array()
  inspect(arr.length(), content="1")
  inspect(arr[0], content="false")
}

///|
test "shrink_bool_false" {
  let result = shrink_bool(false)
  inspect(result.count(), content="0")
}
