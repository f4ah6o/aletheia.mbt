///|
/// パターン検出モジュール（コンポーネントB）
/// Round-Trip、Idempotence、Producer-Consumerパターンを検出する
///

///|
/// パターン候補
pub enum PatternCandidate {
  /// Round-Trip: encode/decode, serialize/deserialize
  RoundTrip(String, String) // (encoder_name, decoder_name)
  /// べき等性: sort, normalize, trim など
  Idempotent(String) // function_name
  /// Producer-Consumer: 型による連鎖
  ProducerConsumer(String, String) // (producer, consumer)
  /// 不変条件: 操作前後で保存される性質
  Invariant(String, String) // (func_name, invariant_type)
  /// オラクル: 実装と参照実装の比較
  Oracle(String, String) // (implementation, oracle)
}

///|
/// 不変条件の種類
pub enum InvariantType {
  LengthPreserving
  LengthDecreasing
  LengthIncreasing
  OrderPreserving
  ContentPreserving
}

///|
pub fn InvariantType::to_string(self : InvariantType) -> String {
  match self {
    LengthPreserving => "LengthPreserving"
    LengthDecreasing => "LengthDecreasing"
    LengthIncreasing => "LengthIncreasing"
    OrderPreserving => "OrderPreserving"
    ContentPreserving => "ContentPreserving"
  }
}

///|
/// Round-Tripパターンを検出
pub fn find_round_trips(
  function_names : Array[String],
) -> Array[PatternCandidate] {
  let results : Array[PatternCandidate] = []

  // よく使われるペアの接頭辞・接尾辞
  let prefixes = [
    ("encode", "decode"),
    ("serialize", "deserialize"),
    ("marshal", "unmarshal"),
    ("parse", "generate"),
    ("parse", "command_to"),
    ("to_string", "from_string"),
    ("to_int", "from_int"),
    ("to_json", "from_json"),
    ("write", "read"),
    ("save", "load"),
  ]
  let mut i = 0
  while i < Array::length(function_names) {
    let name1 = function_names[i]
    let mut j = 0
    while j < Array::length(prefixes) {
      let pair = prefixes[j]
      let enc = pair.0
      let dec = pair.1
      if name1.has_prefix(enc) || name1.has_suffix(enc) {
        // 対応するデコーダーを探す
        let mut k = 0
        while k < Array::length(function_names) {
          let name2 = function_names[k]
          if name2.has_prefix(dec) || name2.has_suffix(dec) {
            Array::push(results, RoundTrip(name1, name2))
          } else {
            ()
          }
          k = k + 1
        }
      } else {
        ()
      }
      j = j + 1
    }
    i = i + 1
  }
  results
}

///|
/// べき等性パターンを検出
pub fn find_idempotent_functions(
  function_names : Array[String],
) -> Array[PatternCandidate] {
  let results : Array[PatternCandidate] = []
  let idempotent_keywords = [
    "sort", "normalize", "canonicalize", "trim", "clean", "compact", "dedupe", "unique",
    "flatten",
  ]
  let mut i = 0
  while i < Array::length(function_names) {
    let name = function_names[i]
    let mut j = 0
    while j < Array::length(idempotent_keywords) {
      let keyword = idempotent_keywords[j]
      if name.contains(keyword) {
        Array::push(results, Idempotent(name))
      } else {
        ()
      }
      j = j + 1
    }
    i = i + 1
  }
  results
}

///|
/// Producer-Consumerパターンを検出
pub fn find_producer_consumer(
  function_names : Array[String],
) -> Array[PatternCandidate] {
  let results : Array[PatternCandidate] = []
  let producer_prefixes = ["create", "make", "new", "build", "generate", "get"]
  let consumer_prefixes = ["process", "handle", "use", "consume", "transform"]
  let mut i = 0
  while i < Array::length(function_names) {
    let name1 = function_names[i]
    let mut j = 0
    while j < Array::length(producer_prefixes) {
      let prod = producer_prefixes[j]
      if name1.has_prefix(prod) {
        // 同じ名前のコンシューマーを探す
        let mut k = 0
        while k < Array::length(consumer_prefixes) {
          let cons = consumer_prefixes[k]
          let mut m = 0
          while m < Array::length(function_names) {
            let name2 = function_names[m]
            if name2.has_prefix(cons) {
              Array::push(results, ProducerConsumer(name1, name2))
            } else {
              ()
            }
            m = m + 1
          }
          k = k + 1
        }
      } else {
        ()
      }
      j = j + 1
    }
    i = i + 1
  }
  results
}

///|
/// PatternCandidateを構築するヘルパー関数
pub fn make_round_trip(encoder : String, decoder : String) -> PatternCandidate {
  RoundTrip(encoder, decoder)
}

///|
pub fn make_idempotent(func : String) -> PatternCandidate {
  Idempotent(func)
}

///|
pub fn make_producer_consumer(
  producer : String,
  consumer : String,
) -> PatternCandidate {
  ProducerConsumer(producer, consumer)
}

///|
/// Invariantパターンを構築するヘルパー関数
pub fn make_invariant(func : String, inv_type : String) -> PatternCandidate {
  Invariant(func, inv_type)
}

///|
/// Oracleパターンを構築するヘルパー関数
pub fn make_oracle(
  implementation : String,
  oracle : String,
) -> PatternCandidate {
  Oracle(implementation, oracle)
}

///|
/// 不変条件パターンを検出
/// push/pop, insert/remove などの操作で保存される性質を検出
pub fn find_invariant_functions(
  function_names : Array[String],
) -> Array[PatternCandidate] {
  let results : Array[PatternCandidate] = []

  // 不変条件タイプごとのキーワード
  let length_preserving = ["map", "reverse", "shuffle", "swap", "rotate"]
  let length_decreasing = ["pop", "remove", "delete", "drop", "take", "filter"]
  let length_increasing = ["push", "insert", "add", "append", "prepend"]
  let order_preserving = ["map", "filter"]
  let content_preserving = ["sort", "reverse", "shuffle", "rotate"]
  let mut i = 0
  while i < Array::length(function_names) {
    let name = function_names[i]

    // LengthPreserving
    let mut j = 0
    while j < Array::length(length_preserving) {
      let keyword = length_preserving[j]
      if name.contains(keyword) {
        Array::push(results, Invariant(name, "LengthPreserving"))
      }
      j = j + 1
    }

    // LengthDecreasing
    let mut j = 0
    while j < Array::length(length_decreasing) {
      let keyword = length_decreasing[j]
      if name.contains(keyword) {
        Array::push(results, Invariant(name, "LengthDecreasing"))
      }
      j = j + 1
    }

    // LengthIncreasing
    let mut j = 0
    while j < Array::length(length_increasing) {
      let keyword = length_increasing[j]
      if name.contains(keyword) {
        Array::push(results, Invariant(name, "LengthIncreasing"))
      }
      j = j + 1
    }

    // OrderPreserving (map, filter は順序を保存)
    let mut j = 0
    while j < Array::length(order_preserving) {
      let keyword = order_preserving[j]
      if name.contains(keyword) &&
        !has_pattern(results, name, "OrderPreserving") {
        Array::push(results, Invariant(name, "OrderPreserving"))
      }
      j = j + 1
    }

    // ContentPreserving (sort, reverse などは内容を保存)
    let mut j = 0
    while j < Array::length(content_preserving) {
      let keyword = content_preserving[j]
      if name.contains(keyword) &&
        !has_pattern(results, name, "ContentPreserving") {
        Array::push(results, Invariant(name, "ContentPreserving"))
      }
      j = j + 1
    }
    i = i + 1
  }
  results
}

///|
/// 重複チェック用ヘルパー
fn has_pattern(
  patterns : Array[PatternCandidate],
  func : String,
  inv_type : String,
) -> Bool {
  let mut i = 0
  while i < patterns.length() {
    match patterns[i] {
      Invariant(f, t) => if f == func && t == inv_type { return true }
      _ => ()
    }
    i = i + 1
  }
  false
}

///|
/// オラクルパターンを検出
/// カスタム実装と標準ライブラリの対応を検出
pub fn find_oracle_candidates(
  function_names : Array[String],
) -> Array[PatternCandidate] {
  let results : Array[PatternCandidate] = []

  // カスタム実装を示すプレフィックス
  let custom_prefixes = [
    "my_", "custom_", "fast_", "optimized_", "simple_", "naive_",
  ]

  // 標準ライブラリ関数との対応付け
  let std_functions = [
    "sort", "reverse", "map", "filter", "fold", "reduce", "find", "contains", "length",
    "concat", "join", "split", "trim", "parse", "format",
  ]
  let mut i = 0
  while i < Array::length(function_names) {
    let name = function_names[i]

    // プレフィックス付きの関数を探す
    let mut j = 0
    while j < Array::length(custom_prefixes) {
      let prefix = custom_prefixes[j]
      if name.has_prefix(prefix) {
        // プレフィックスを除いた名前を取得
        let base_name = remove_prefix(name, prefix)

        // 対応する標準関数があるか確認
        let mut k = 0
        while k < Array::length(std_functions) {
          let std_func = std_functions[k]
          if base_name.contains(std_func) {
            // 標準関数が関数リストにあるか確認
            let mut m = 0
            while m < Array::length(function_names) {
              let other = function_names[m]
              if other != name &&
                other.contains(std_func) &&
                !has_custom_prefix(other, custom_prefixes) {
                Array::push(results, Oracle(name, other))
              }
              m = m + 1
            }
          }
          k = k + 1
        }
      }
      j = j + 1
    }
    i = i + 1
  }
  results
}

///|
/// プレフィックスを除去
fn remove_prefix(s : String, prefix : String) -> String {
  if s.has_prefix(prefix) {
    let chars = s.to_array()
    let prefix_len = prefix.length()
    let mut result = ""
    let mut i = prefix_len
    while i < chars.length() {
      result = result + chars[i].to_string()
      i = i + 1
    }
    result
  } else {
    s
  }
}

///|
/// カスタムプレフィックスを持つかチェック
fn has_custom_prefix(name : String, prefixes : Array[String]) -> Bool {
  let mut i = 0
  while i < prefixes.length() {
    if name.has_prefix(prefixes[i]) {
      return true
    }
    i = i + 1
  }
  false
}

///|
/// テスト
test "find_round_trips_simple" {
  let names = ["encode_data", "decode_data", "to_string", "from_string"]
  let results = find_round_trips(names)
  inspect(results.length(), content="2")
}

///|
test "find_round_trips_parse_generate" {
  let names = ["parse_markdown", "generate_markdown"]
  let results = find_round_trips(names)
  inspect(results.length(), content="1")
}

///|
test "find_round_trips_parse_command_to" {
  let names = ["parse_args", "command_to_args"]
  let results = find_round_trips(names)
  inspect(results.length(), content="1")
}

///|
test "find_idempotent_functions_simple" {
  let names = ["sort_array", "normalize_path", "trim_string", "add_numbers"]
  let results = find_idempotent_functions(names)
  inspect(results.length(), content="3")
}

///|
test "find_producer_consumer_simple" {
  let names = ["create_user", "process_user", "delete_user"]
  let results = find_producer_consumer(names)
  inspect(results.length(), content="1")
}

///|
test "find_round_trips_empty" {
  let names : Array[String] = []
  let results = find_round_trips(names)
  inspect(results.length(), content="0")
}

///|
test "find_idempotent_functions_empty" {
  let names : Array[String] = []
  let results = find_idempotent_functions(names)
  inspect(results.length(), content="0")
}

///|
test "find_invariant_functions_length_preserving" {
  let names = ["map_values", "reverse_list", "shuffle_array"]
  let results = find_invariant_functions(names)
  // map_values: LengthPreserving + OrderPreserving
  // reverse_list: LengthPreserving + ContentPreserving
  // shuffle_array: LengthPreserving + ContentPreserving
  inspect(results.length() > 0, content="true")
}

///|
test "find_invariant_functions_length_changing" {
  let names = ["push_item", "pop_item", "filter_list"]
  let results = find_invariant_functions(names)
  // push_item: LengthIncreasing
  // pop_item: LengthDecreasing
  // filter_list: LengthDecreasing + OrderPreserving
  inspect(results.length() > 0, content="true")
}

///|
test "find_invariant_functions_empty" {
  let names : Array[String] = []
  let results = find_invariant_functions(names)
  inspect(results.length(), content="0")
}

///|
test "find_oracle_candidates_simple" {
  let names = ["my_sort", "sort", "custom_reverse", "reverse"]
  let results = find_oracle_candidates(names)
  // my_sort -> sort, custom_reverse -> reverse
  inspect(results.length(), content="2")
}

///|
test "find_oracle_candidates_no_match" {
  let names = ["encode", "decode", "process"]
  let results = find_oracle_candidates(names)
  inspect(results.length(), content="0")
}

///|
test "make_invariant_helper" {
  let pattern = make_invariant("push", "LengthIncreasing")
  match pattern {
    Invariant(func, inv_type) => {
      inspect(func, content="push")
      inspect(inv_type, content="LengthIncreasing")
    }
    _ => inspect("fail", content="ok")
  }
}

///|
test "make_oracle_helper" {
  let pattern = make_oracle("my_sort", "sort")
  match pattern {
    Oracle(implementation, oracle) => {
      inspect(implementation, content="my_sort")
      inspect(oracle, content="sort")
    }
    _ => inspect("fail", content="ok")
  }
}
