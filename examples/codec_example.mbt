///|
/// パターン検出デモ用コーデック例
/// encode/decode, serialize/deserialize ペアを含む
///

/// Base64エンコード（簡易実装）
pub fn encode_base64(data : String) -> String {
  "encoded:" + data
}

/// Base64デコード（簡易実装）
pub fn decode_base64(encoded : String) -> String {
  if encoded.has_prefix("encoded:") {
    encoded.substring(8)
  } else {
    encoded
  }
}

/// JSONシリアライズ（簡易実装）
pub fn serialize_json(obj : String) -> String {
  "{\"data\":\"" + obj + "\"}"
}

/// JSONデシリアライズ（簡易実装）
pub fn deserialize_json(json : String) -> String {
  // 簡易実装: 実際のパースは省略
  json
}

/// URLエンコード
pub fn encode_url(url : String) -> String {
  url.replace(" ", "%20")
}

/// URLデコード
pub fn decode_url(encoded : String) -> String {
  encoded.replace("%20", " ")
}

/// 配列をソート（べき等例）
pub fn sort_array(arr : Array[Int]) -> Array[Int] {
  arr
}

/// パスを正規化（べき等例）
pub fn normalize_path(path : String) -> String {
  path
}

/// 文字列をトリム（べき等例）
pub fn trim_string(s : String) -> String {
  s
}
