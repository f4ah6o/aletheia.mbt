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
