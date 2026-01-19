///|
/// Shrink strategy patterns for common data structures
/// Provides templates for implementing custom shrink logic

///|
/// Shrink strategy for enumerated types
#warnings("-unused_constructor")
pub enum EnumShrinkStrategy {
  TryFirst(Array[String])
  RemoveVariants
  BoundaryFirst
}

///|
/// Shrink strategy for struct fields
#warnings("-unused_constructor")
pub enum FieldShrinkStrategy {
  PreferNil
  PreferZero
  PreserveInvariants
  DepthFirst
}

///|
/// Generate shrink strategy code for enum type
pub fn generate_enum_shrink_strategy(
  type_name : String,
  variants : Array[String],
  strategy : EnumShrinkStrategy,
) -> String {
  let mut result = "pub impl Shrink for " +
    type_name +
    " with shrink(self) -> Iter[" +
    type_name +
    "] {\n"
  result = result + "  let mut shrunk : Array[" + type_name + "] = []\n\n"
  match strategy {
    TryFirst(priority_variants) => {
      result = result + "  // Phase 1: Try priority variants first\n"
      let mut i = 0
      while i < priority_variants.length() {
        let variant = priority_variants[i]
        result = result +
          "  if !(self is " +
          type_name +
          "::" +
          variant +
          ") {\n"
        result = result +
          "    Array::push(shrunk, " +
          type_name +
          "::" +
          variant +
          ")\n"
        result = result + "  }\n\n"
        i = i + 1
      }
      result = result + "  // Phase 2: Try other variants\n"
      result = result + "  match self {\n"
      let mut j = 0
      while j < variants.length() {
        let variant = variants[j]
        result = result + "    " + type_name + "::" + variant + " => "
        if j > 0 {
          result = result +
            "Array::push(shrunk, " +
            type_name +
            "::" +
            variants[0] +
            ")\n"
        } else {
          result = result + "()\n"
        }
        j = j + 1
      }
      result = result + "  }\n"
    }
    RemoveVariants => {
      result = result + "  // Phase 1: Try first variant (simplest)\n"
      if variants.length() > 0 {
        result = result +
          "  if !(self is " +
          type_name +
          "::" +
          variants[0] +
          ") {\n"
        result = result +
          "    Array::push(shrunk, " +
          type_name +
          "::" +
          variants[0] +
          ")\n"
        result = result + "  }\n\n"
      }
      result = result + "  // Phase 2: Try adjacent variants\n"
      result = result + "  match self {\n"
      let mut j = 0
      while j < variants.length() {
        let variant = variants[j]
        result = result + "    " + type_name + "::" + variant + " => {\n"
        if j > 0 {
          result = result +
            "      Array::push(shrunk, " +
            type_name +
            "::" +
            variants[j - 1] +
            ")\n"
        }
        if j < variants.length() - 1 {
          result = result +
            "      Array::push(shrunk, " +
            type_name +
            "::" +
            variants[j + 1] +
            ")\n"
        }
        result = result + "    }\n"
        j = j + 1
      }
      result = result + "  }\n"
    }
    BoundaryFirst => {
      result = result + "  // Phase 1: Try boundary variants\n"
      if variants.length() >= 2 {
        let first = variants[0]
        let last = variants[variants.length() - 1]
        result = result + "  if !(self is " + type_name + "::" + first + ") {\n"
        result = result +
          "    Array::push(shrunk, " +
          type_name +
          "::" +
          first +
          ")\n"
        result = result + "  }\n"
        result = result + "  if !(self is " + type_name + "::" + last + ") {\n"
        result = result +
          "    Array::push(shrunk, " +
          type_name +
          "::" +
          last +
          ")\n"
        result = result + "  }\n\n"
      }
      result = result + "  // Phase 2: Try middle variants\n"
      result = result + "  match self {\n"
      let mut j = 0
      while j < variants.length() {
        let variant = variants[j]
        result = result + "    " + type_name + "::" + variant + " => {\n"
        if j > 0 && j < variants.length() - 1 {
          result = result +
            "      Array::push(shrunk, " +
            type_name +
            "::" +
            variants[0] +
            ")\n"
        }
        result = result + "    }\n"
        j = j + 1
      }
      result = result + "  }\n"
    }
  }
  result = result + "\n  shrunk.to_iter()\n"
  result = result + "}\n"
  result
}

///|
/// Generate shrink strategy code for struct type
pub fn generate_struct_shrink_strategy(
  type_name : String,
  fields : Array[(String, String)],
  strategies : Array[FieldShrinkStrategy],
) -> String {
  let mut result = "pub impl Shrink for " +
    type_name +
    " with shrink(self) -> Iter[" +
    type_name +
    "] {\n"
  result = result + "  let mut shrunk : Array[" + type_name + "] = []\n\n"
  let mut has_prefer_nil = false
  let mut has_prefer_zero = false
  let mut has_depth_first = false
  let mut i = 0
  while i < strategies.length() {
    match strategies[i] {
      PreferNil => has_prefer_nil = true
      PreferZero => has_prefer_zero = true
      DepthFirst => has_depth_first = true
      PreserveInvariants => ()
    }
    i = i + 1
  }
  if has_prefer_nil || has_prefer_zero {
    result = result + "  // Phase 1: Try nil/zero variants\n"
    let nil_fields : Array[String] = []
    let zero_fields : Array[(String, String)] = []
    let mut j = 0
    while j < fields.length() {
      let (field_name, field_type) = fields[j]
      if has_prefer_nil && is_optional_type(field_type) {
        nil_fields.push(field_name)
      }
      if has_prefer_zero {
        match field_type {
          "Int" => zero_fields.push((field_name, "0"))
          "Double" => zero_fields.push((field_name, "0.0"))
          "Bool" => zero_fields.push((field_name, "false"))
          "String" => zero_fields.push((field_name, "\"\""))
          _ =>
            if field_type.has_prefix("Array[") {
              zero_fields.push((field_name, "[]"))
            }
        }
      }
      j = j + 1
    }
    if nil_fields.length() > 0 {
      result = result + "  // Try setting optional fields to None\n"
      let mut j = 0
      while j < nil_fields.length() {
        let field = nil_fields[j]
        result = result + "  if self." + field + " != None {\n"
        result = result +
          "    Array::push(shrunk, { ..self, " +
          field +
          ": None })\n"
        result = result + "  }\n"
        j = j + 1
      }
    }
    if zero_fields.length() > 0 {
      result = result + "  // Try setting fields to zero/empty values\n"
      let mut j = 0
      while j < zero_fields.length() {
        let (field, zero_val) = zero_fields[j]
        result = result + "  if self." + field + " != " + zero_val + " {\n"
        result = result +
          "    Array::push(shrunk, { ..self, " +
          field +
          ": " +
          zero_val +
          " })\n"
        result = result + "  }\n"
        j = j + 1
      }
    }
    result = result + "\n"
  }
  if has_depth_first {
    result = result + "  // Phase 2: Shrink nested structures first\n"
    let mut j = 0
    while j < fields.length() {
      let (field_name, field_type) = fields[j]
      if is_nested_type(field_type) {
        let shrinker = get_shrinker_for_type(field_type)
        result = result +
          "  // Shrink nested field '" +
          field_name +
          "' (" +
          field_type +
          ")\n"
        result = result +
          "  for v in " +
          shrinker +
          "(self." +
          field_name +
          ") {\n"
        result = result +
          "    Array::push(shrunk, { ..self, " +
          field_name +
          ": v })\n"
        result = result + "  }\n"
      }
      j = j + 1
    }
    result = result + "\n"
  }
  result = result + "  // Phase 3: Shrink primitive fields\n"
  let mut j = 0
  while j < fields.length() {
    let (field_name, field_type) = fields[j]
    if !is_nested_type(field_type) {
      let shrinker = get_shrinker_for_type(field_type)
      result = result +
        "  for v in " +
        shrinker +
        "(self." +
        field_name +
        ") {\n"
      result = result +
        "    Array::push(shrunk, { ..self, " +
        field_name +
        ": v })\n"
      result = result + "  }\n"
    }
    j = j + 1
  }
  result = result + "\n  shrunk.to_iter()\n"
  result = result + "}\n"
  result
}

///|
/// Generate hierarchical shrink strategy
pub fn generate_hierarchical_shrink(
  type_name : String,
  nested_types : Array[String],
) -> String {
  let mut result = "pub impl Shrink for " +
    type_name +
    " with shrink(self) -> Iter[" +
    type_name +
    "] {\n"
  result = result + "  let mut shrunk : Array[" + type_name + "] = []\n\n"
  result = result + "  // Hierarchical shrinking: depth-limited approach\n"
  result = result +
    "  // This prevents exponential explosion when shrinking\n\n"
  result = result + "  // Level 1: Try empty/minimal variants\n"
  result = result + "  // TODO: Add minimal variant candidate\n\n"
  if nested_types.length() > 0 {
    let mut i = 0
    while i < nested_types.length() {
      let nested = nested_types[i]
      result = result +
        "  // Level " +
        (i + 2).to_string() +
        ": Shrink " +
        nested +
        "\n"
      result = result + "  // TODO: Add shrink logic for " + nested + "\n\n"
      i = i + 1
    }
  }
  result = result +
    "  // Level " +
    (nested_types.length() + 2).to_string() +
    ": Shrink top-level primitives\n"
  result = result + "  // TODO: Add primitive field shrinking\n\n"
  result = result + "  shrunk.to_iter()\n"
  result = result + "}\n"
  result
}

///|
/// Check if type is optional (contains ?)
fn is_optional_type(type_name : String) -> Bool {
  type_name.contains("?") || type_name.contains("Option[")
}

///|
/// Check if type is nested (contains Array or custom types)
fn is_nested_type(type_name : String) -> Bool {
  let has_array = type_name.has_prefix("Array[")
  let has_list = type_name.has_prefix("List[")
  let has_option = type_name.contains("?")
  let not_primitive = !is_primitive_type(type_name)
  has_array || has_list || has_option || not_primitive
}

///|
/// Check if type is primitive
fn is_primitive_type(type_name : String) -> Bool {
  match type_name {
    "Int" => true
    "Int64" => true
    "Double" => true
    "Bool" => true
    "String" => true
    "Char" => true
    _ => false
  }
}

///|
/// Get shrinker function name for type
fn get_shrinker_for_type(type_name : String) -> String {
  if is_optional_type(type_name) {
    let inner1 = type_name.replace(old="?", new="")
    let inner2 = inner1.replace(old="Option[", new="")
    let inner = inner2.replace(old="]", new="")
    "@pbt.shrink_option(fn(x : " +
    inner +
    ") { " +
    get_shrinker_for_type(inner) +
    "(x) })"
  } else if type_name.has_prefix("Array[") {
    "@pbt.shrink_array"
  } else {
    match type_name {
      "Int" => "@pbt.shrink_int"
      "Double" => "@pbt.shrink_double"
      "Bool" => "@pbt.shrink_bool"
      "String" => "@pbt.shrink_string"
      _ => "@pbt.shrink_int"
    }
  }
}

///|
test "generate_enum_shrink_strategy_simple" {
  let variants = ["Active", "Inactive", "Pending"]
  let result = generate_enum_shrink_strategy("Status", variants, RemoveVariants)
  inspect(result.contains("pub impl Shrink for Status"), content="true")
  inspect(result.contains("Status::Active"), content="true")
  inspect(result.contains("Phase 1"), content="true")
}

///|
test "generate_enum_shrink_strategy_try_first" {
  let variants = ["Error", "Success", "Pending"]
  let result = generate_enum_shrink_strategy(
    "Result",
    variants,
    TryFirst(["Error", "Success"]),
  )
  inspect(
    result.contains("Phase 1: Try priority variants first"),
    content="true",
  )
  inspect(result.contains("Result::Error"), content="true")
  inspect(result.contains("Phase 2: Try other variants"), content="true")
}

///|
test "generate_struct_shrink_strategy_prefer_nil" {
  let fields = [("id", "Int"), ("name", "String"), ("optional", "String?")]
  let result = generate_struct_shrink_strategy("User", fields, [
    PreferNil,
    PreferZero,
  ])
  inspect(result.contains("pub impl Shrink for User"), content="true")
  inspect(result.contains("Phase 1: Try nil/zero variants"), content="true")
  inspect(result.contains("optional"), content="true")
}

///|
test "generate_struct_shrink_strategy_depth_first" {
  let fields = [("id", "Int"), ("items", "Array[String]"), ("data", "String")]
  let result = generate_struct_shrink_strategy("Container", fields, [DepthFirst])
  inspect(
    result.contains("Phase 2: Shrink nested structures first"),
    content="true",
  )
  inspect(result.contains("@pbt.shrink_array"), content="true")
}

///|
test "generate_hierarchical_shrink_nested" {
  let nested = ["Array[String]", "Option[Int]"]
  let result = generate_hierarchical_shrink("Data", nested)
  inspect(result.contains("Hierarchical shrinking"), content="true")
  inspect(result.contains("Level 1"), content="true")
  inspect(result.contains("Level 2"), content="true")
  inspect(result.contains("Level 3"), content="true")
}

///|
test "is_optional_type_returns_true_for_option" {
  inspect(is_optional_type("Int?"), content="true")
  inspect(is_optional_type("Option[Int]"), content="true")
  inspect(is_optional_type("String"), content="false")
}

///|
test "is_primitive_type_detects_primitives" {
  inspect(is_primitive_type("Int"), content="true")
  inspect(is_primitive_type("String"), content="true")
  inspect(is_primitive_type("Double"), content="true")
  inspect(is_primitive_type("Bool"), content="true")
  inspect(is_primitive_type("Array[Int]"), content="false")
}

///|
test "is_nested_type_detects_arrays" {
  inspect(is_nested_type("Array[Int]"), content="true")
  inspect(is_nested_type("Array[String]"), content="true")
  inspect(is_nested_type("Int"), content="false")
  inspect(is_nested_type("String"), content="false")
}

///|
test "get_shrinker_for_type_maps_correctly" {
  inspect(get_shrinker_for_type("Int"), content="@pbt.shrink_int")
  inspect(get_shrinker_for_type("String"), content="@pbt.shrink_string")
  inspect(get_shrinker_for_type("Double"), content="@pbt.shrink_double")
  inspect(get_shrinker_for_type("Array[Int]"), content="@pbt.shrink_array")
}
