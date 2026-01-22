///|
fn json_object(pairs : Array[(String, String)]) -> String {
  let mut result = "{"
  let mut i = 0
  while i < pairs.length() {
    if i > 0 {
      result = result + ","
    }
    result = result + json_string(pairs[i].0) + ":" + pairs[i].1
    i = i + 1
  }
  result + "}"
}

///|
fn json_array(values : Array[String]) -> String {
  let mut result = "["
  let mut i = 0
  while i < values.length() {
    if i > 0 {
      result = result + ","
    }
    result = result + values[i]
    i = i + 1
  }
  result + "]"
}

///|
fn json_string(value : String) -> String {
  "\"" + json_escape(value) + "\""
}

///|
fn json_bool(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn json_number(value : Int) -> String {
  int_to_string(value)
}

///|
fn json_escape(value : String) -> String {
  let chars = value.to_array()
  let mut result = ""
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    match c {
      '"' => result = result + "\\\""
      '\\' => result = result + "\\\\"
      '\n' => result = result + "\\n"
      '\r' => result = result + "\\r"
      '\t' => result = result + "\\t"
      '\b' => result = result + "\\b"
      '\f' => result = result + "\\f"
      _ =>
        if c.to_int() < 0x20 {
          result = result + "\\u00" + byte_to_hex(c.to_int())
        } else {
          result = result + c.to_string()
        }
    }
    i = i + 1
  }
  result
}

///|
fn byte_to_hex(value : Int) -> String {
  hex_digit(value / 16) + hex_digit(value % 16)
}

///|
fn hex_digit(value : Int) -> String {
  match value {
    0 => "0"
    1 => "1"
    2 => "2"
    3 => "3"
    4 => "4"
    5 => "5"
    6 => "6"
    7 => "7"
    8 => "8"
    9 => "9"
    10 => "a"
    11 => "b"
    12 => "c"
    13 => "d"
    14 => "e"
    _ => "f"
  }
}
