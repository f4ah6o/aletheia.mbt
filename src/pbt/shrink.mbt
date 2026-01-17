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

///|
/// Generate shrink hints template for user-defined type
/// Similar to PropEr's ?SHRINK directive
pub fn generate_shrink_hints(
  type_name : String,
  variant_names : Array[String],
  field_info : Array[(String, String)],
) -> String {
  let mut result = "## Shrink Hints for " + type_name + "\n\n"
  result = result + "When implementing Shrink trait for `" + type_name + "`, consider:\n\n"

  if variant_names.length() > 0 {
    result = result + generate_enum_shrink_guidance(type_name, variant_names)
  } else if field_info.length() > 0 {
    result = result + generate_struct_shrink_guidance(type_name, field_info)
  } else {
    result = result + "### Type Analysis\n\n"
    result = result + "Custom type detected. Implement shrinking based on the type structure:\n"
    result = result + "- If enum: Shrink towards simpler variants\n"
    result = result + "- If struct: Shrink individual fields towards zero/empty\n"
    result = result + "- If nested: Apply depth-first shrinking\n\n"
  }

  result = result + "### Shrink Ordering\n\n"
  result = result + "Try shrunk candidates in this order:\n"
  result = result + "1. Empty/zero/simple variants\n"
  result = result + "2. Remove elements/components\n"
  result = result + "3. Simplify individual fields\n"
  result = result + "4. Try boundary values\n"
  result
}

///|
/// Generate shrink guidance for enum types
fn generate_enum_shrink_guidance(
  type_name : String,
  variants : Array[String],
) -> String {
  let mut result = "### Enum Shrink Strategy\n\n"
  result = result + "For enum `" + type_name + "` with variants: "

  let mut i = 0
  while i < variants.length() {
    result = result + "`" + variants[i] + "`"
    if i < variants.length() - 1 {
      result = result + ", "
    }
    i = i + 1
  }
  result = result + "\n\n"

  result = result + "**Recommended approach:**\n"
  result = result + "1. Define a \"simplest\" variant (usually the first one)\n"
  result = result + "2. Try shrinking to the simplest variant first\n"
  result = result + "3. Then try adjacent variants in the enum definition\n\n"

  if variants.length() > 0 {
    result = result + "**Variant ordering:**\n"
    let mut j = 0
    while j < variants.length() {
      let priority = if j == 0 { " (highest priority)" } else { "" }
      result = result + "- Level " + (j + 1).to_string() + priority + ": `" + variants[j] + "`\n"
      j = j + 1
    }
    result = result + "\n"
  }

  result
}

///|
/// Generate shrink guidance for struct types
fn generate_struct_shrink_guidance(
  type_name : String,
  fields : Array[(String, String)],
) -> String {
  let mut result = "### Struct Shrink Strategy\n\n"
  result = result + "For struct `" + type_name + "`:\n\n"

  result = result + "**Field-specific strategies:**\n\n"
  let mut i = 0
  while i < fields.length() {
    let (field_name, field_type) = fields[i]
    let strategy = match field_type {
      "Int" => "Try 0, 1, -1, then halve"
      "String" => "Try \"\", then single char, then halve length"
      "Bool" => "Try false if true"
      "Double" => "Try 0.0, then halve towards zero"
      t if t.has_prefix("Array[") => "Try [], then single element, then halve"
      t if t.contains("?") => "Try None, then shrink Some value"
      _ => "Try zero/empty equivalent"
    }
    result = result + "- `" + field_name + "` (" + field_type + "): " + strategy + "\n"
    i = i + 1
  }

  result = result + "\n**Shrinking phases:**\n\n"
  result = result + "1. **Nil/Zero phase**: Try setting all fields to nil/zero\n"
  result = result + "2. **Depth-first phase**: Shrink nested structures before primitives\n"
  result = result + "3. **Field-wise phase**: Shrink each primitive field independently\n\n"

  result = result + "**Template code:**\n\n"
  result = result + "```mbt nocheck\n"
  result = result + "pub impl Shrink for " + type_name + " with shrink(self) -> Iter[" + type_name + "] {\n"
  result = result + "  let mut shrunk : Array[" + type_name + "] = []\n\n"

  result = result + "  // Phase 1: Try empty/simple variants\n"
  i = 0
  while i < fields.length() {
    let (field_name, field_type) = fields[i]
    let zero_val = match field_type {
      "Int" => "0"
      "String" => "\"\""
      "Bool" => "false"
      "Double" => "0.0"
      t if t.has_prefix("Array[") => "[]"
      t if t.contains("?") => "None"
      _ => "/* zero value */"
    }
    result = result + "  if self." + field_name + " != " + zero_val + " {\n"
    result = result + "    Array::push(shrunk, { ..self, " + field_name + ": " + zero_val + " })\n"
    result = result + "  }\n"
    i = i + 1
  }

  result = result + "\n  // Phase 2: Simplify individual fields\n"
  i = 0
  while i < fields.length() {
    let (field_name, field_type) = fields[i]
    let shrinker = match field_type {
      "Int" => "@pbt.shrink_int"
      "String" => "@pbt.shrink_string"
      "Bool" => "@pbt.shrink_bool"
      "Double" => "@pbt.shrink_double"
      t if t.has_prefix("Array[") => "@pbt.shrink_array"
      t if t.contains("?") => "@pbt.shrink_option(fn(x) { @pbt.shrink_int(x) })"
      _ => "@pbt.shrink_int"
    }
    result = result + "  for v in " + shrinker + "(self." + field_name + ") {\n"
    result = result + "    Array::push(shrunk, { ..self, " + field_name + ": v })\n"
    result = result + "  }\n"
    i = i + 1
  }

  result = result + "\n  shrunk.to_iter()\n"
  result = result + "}\n"
  result = result + "```\n\n"

  result
}

///|
test "generate_shrink_hints_enum" {
  let variants = ["Active", "Inactive", "Pending"]
  let result = generate_shrink_hints("Status", variants, [])
  inspect(result.contains("Shrink Hints for Status"), content="true")
  inspect(result.contains("Enum Shrink Strategy"), content="true")
  inspect(result.contains("Shrink Ordering"), content="true")
  inspect(result.contains("Active"), content="true")
}

///|
test "generate_shrink_hints_struct" {
  let fields = [("id", "Int"), ("name", "String"), ("tags", "Array[String]")]
  let result = generate_shrink_hints("User", [], fields)
  inspect(result.contains("Shrink Hints for User"), content="true")
  inspect(result.contains("Struct Shrink Strategy"), content="true")
  inspect(result.contains("id"), content="true")
  inspect(result.contains("name"), content="true")
  inspect(result.contains("Phase 1"), content="true")
  inspect(result.contains("Phase 2"), content="true")
}

///|
test "generate_shrink_hints_includes_ordering" {
  let result = generate_shrink_hints("CustomType", [], [])
  inspect(result.contains("Shrink Ordering"), content="true")
  inspect(result.contains("Empty/zero/simple variants"), content="true")
  inspect(result.contains("Remove elements/components"), content="true")
  inspect(result.contains("Simplify individual fields"), content="true")
  inspect(result.contains("Try boundary values"), content="true")
}

///|
test "generate_enum_shrink_guidance_includes_variants" {
  let variants = ["Red", "Green", "Blue"]
  let result = generate_enum_shrink_guidance("Color", variants)
  inspect(result.contains("Enum Shrink Strategy"), content="true")
  inspect(result.contains("Red"), content="true")
  inspect(result.contains("Green"), content="true")
  inspect(result.contains("Blue"), content="true")
  inspect(result.contains("simplest variant"), content="true")
}

///|
test "generate_struct_shrink_guidance_includes_fields" {
  let fields = [("count", "Int"), ("label", "String"), ("flag", "Bool")]
  let result = generate_struct_shrink_guidance("Item", fields)
  inspect(result.contains("Struct Shrink Strategy"), content="true")
  inspect(result.contains("count"), content="true")
  inspect(result.contains("label"), content="true")
  inspect(result.contains("flag"), content="true")
  inspect(result.contains("Template code"), content="true")
}
