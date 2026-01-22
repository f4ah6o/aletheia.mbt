///|
pub struct CheckConfig {
  cases : Int
  max_size : Int
  seed : UInt64
  shrink_limit : Int
}

///|
pub impl Default for CheckConfig with default() {
  CheckConfig::{ cases: 100, max_size: 30, seed: 1, shrink_limit: 100 }
}

///|
pub fn CheckConfig::new(
  cases : Int,
  max_size : Int,
  seed : UInt64,
  shrink_limit : Int,
) -> CheckConfig {
  CheckConfig::{ cases, max_size, seed, shrink_limit }
}

///|
pub struct Failure {
  case_index : Int
  size : Int
  seed : UInt64
  message : String
  original : String
  shrunk : String?
} derive(Show)

///|
pub fn[T : Show] check(
  gen : Gen[T],
  prop : (T) -> Result[Unit, String],
  config? : CheckConfig = CheckConfig::default(),
  shrink? : (T) -> Iter[T],
) -> Result[Unit, Failure] {
  let config = config
  let cases = if config.cases < 0 { 0 } else { config.cases }
  let max_size = if config.max_size < 0 { 0 } else { config.max_size }
  let rs = @quickcheck/splitmix.new(seed=config.seed)
  for i in 0..<cases {
    let size = if i < max_size { i } else { max_size }
    let value = (gen.run)(size, rs)
    match prop(value) {
      Ok(_) => ()
      Err(msg) => {
        let original = "\{value}"
        let mut final_value = value
        let mut final_msg = msg
        let mut shrunk : String? = None
        match shrink {
          None => ()
          Some(shrinker) => {
            let (shrunk_value, shrunk_msg) = shrink_value(
              value,
              final_msg,
              prop,
              shrinker,
              config.shrink_limit,
            )
            final_value = shrunk_value
            final_msg = shrunk_msg
            shrunk = Some("\{final_value}")
          }
        }
        return Err(Failure::{
          case_index: i,
          size,
          seed: config.seed,
          message: final_msg,
          original,
          shrunk,
        })
      }
    }
  }
  Ok(())
}

///|
fn[T] shrink_value(
  value : T,
  message : String,
  prop : (T) -> Result[Unit, String],
  shrinker : (T) -> Iter[T],
  limit : Int,
) -> (T, String) {
  if limit <= 0 {
    return (value, message)
  }
  let mut current = value
  let mut current_msg = message
  let mut rounds = 0
  while rounds < limit {
    let mut found = false
    for candidate in shrinker(current) {
      match prop(candidate) {
        Ok(_) => ()
        Err(msg) => {
          current = candidate
          current_msg = msg
          found = true
          break
        }
      }
    }
    if not(found) {
      break
    }
    rounds += 1
  }
  (current, current_msg)
}

///|
pub fn[T : Show] assert_check(
  label : String,
  gen : Gen[T],
  prop : (T) -> Result[Unit, String],
  config? : CheckConfig = CheckConfig::default(),
  shrink? : (T) -> Iter[T],
) -> Unit raise {
  match check(gen, prop, config~, shrink?) {
    Ok(_) => ()
    Err(failure) => fail("\{label}: \{failure}")
  }
}

///|
/// 統計エントリ
pub struct StatEntry {
  label : String
  count : Int
  percentage : Double
} derive(Show)

///|
/// 統計情報
pub struct Statistics {
  entries : Array[StatEntry]
  mut total : Int
} derive(Show)

///|
pub fn Statistics::new() -> Statistics {
  { entries: [], total: 0 }
}

///|
pub fn Statistics::add_label(self : Statistics, label : String) -> Unit {
  // 既存のラベルを探す
  for i in 0..<self.entries.length() {
    if self.entries[i].label == label {
      self.entries[i] = {
        label: self.entries[i].label,
        count: self.entries[i].count + 1,
        percentage: 0.0,
      }
      return
    }
  }
  // 新しいラベルを追加
  self.entries.push({ label, count: 1, percentage: 0.0 })
}

///|
pub fn Statistics::finalize(self : Statistics) -> Unit {
  let total = self.total
  if total == 0 {
    return
  }
  for i in 0..<self.entries.length() {
    let entry = self.entries[i]
    self.entries[i] = {
      label: entry.label,
      count: entry.count,
      percentage: entry.count.to_double() / total.to_double() * 100.0,
    }
  }
}

///|
pub fn Statistics::to_string(self : Statistics) -> String {
  if self.entries.length() == 0 {
    return "No statistics collected"
  }
  let mut result = "Statistics (total: " + self.total.to_string() + "):\n"
  for i in 0..<self.entries.length() {
    let entry = self.entries[i]
    result = result +
      "  " +
      entry.label +
      ": " +
      entry.count.to_string() +
      " (" +
      format_percentage(entry.percentage) +
      "%)\n"
  }
  result
}

///|
fn format_percentage(p : Double) -> String {
  let int_part = p.to_int()
  let frac_part = ((p - int_part.to_double()) * 10.0).to_int()
  int_part.to_string() + "." + frac_part.to_string()
}

///|
/// 統計付きチェック結果
pub struct CheckResult[T] {
  passed : Bool
  failure : Failure?
  stats : Statistics?
  phantom : T?
} derive(Show)

///|
/// 分類付きプロパティを実行
/// 条件に基づいてテストケースを分類し、統計を収集する
pub fn[T] classify(
  label : String,
  condition : Bool,
  prop : (T) -> Result[Unit, String],
) -> (T) -> (Result[Unit, String], String?) {
  fn(value : T) -> (Result[Unit, String], String?) {
    let result = prop(value)
    if condition {
      (result, Some(label))
    } else {
      (result, None)
    }
  }
}

///|
/// 値を収集してプロパティを実行
/// 値を文字列に変換して統計を収集する
pub fn[T, V : Show] collect(
  value : V,
  prop : (T) -> Result[Unit, String],
) -> (T) -> (Result[Unit, String], String?) {
  fn(input : T) -> (Result[Unit, String], String?) {
    let result = prop(input)
    (result, Some("\{value}"))
  }
}

///|
/// 統計付きチェックを実行
pub fn[T : Show] check_with_stats(
  gen : Gen[T],
  prop : (T) -> (Result[Unit, String], String?),
  config? : CheckConfig = CheckConfig::default(),
  shrink? : (T) -> Iter[T],
) -> CheckResult[T] {
  let config = config
  let cases = if config.cases < 0 { 0 } else { config.cases }
  let max_size = if config.max_size < 0 { 0 } else { config.max_size }
  let rs = @quickcheck/splitmix.new(seed=config.seed)
  let stats = Statistics::new()
  for i in 0..<cases {
    let size = if i < max_size { i } else { max_size }
    let value = (gen.run)(size, rs)
    let (result, label_opt) = prop(value)
    stats.total = stats.total + 1

    // ラベルがあれば統計に追加
    match label_opt {
      Some(label) => stats.add_label(label)
      None => ()
    }
    match result {
      Ok(_) => ()
      Err(msg) => {
        let original = "\{value}"
        let mut final_value = value
        let mut final_msg = msg
        let mut shrunk : String? = None
        match shrink {
          None => ()
          Some(shrinker) => {
            let (shrunk_value, shrunk_msg) = shrink_value_with_stats(
              value,
              final_msg,
              fn(v) { prop(v).0 },
              shrinker,
              config.shrink_limit,
            )
            final_value = shrunk_value
            final_msg = shrunk_msg
            shrunk = Some("\{final_value}")
          }
        }
        stats.finalize()
        return {
          passed: false,
          failure: Some(Failure::{
            case_index: i,
            size,
            seed: config.seed,
            message: final_msg,
            original,
            shrunk,
          }),
          stats: Some(stats),
          phantom: None,
        }
      }
    }
  }
  stats.finalize()
  { passed: true, failure: None, stats: Some(stats), phantom: None }
}

///|
fn[T] shrink_value_with_stats(
  value : T,
  message : String,
  prop : (T) -> Result[Unit, String],
  shrinker : (T) -> Iter[T],
  limit : Int,
) -> (T, String) {
  if limit <= 0 {
    return (value, message)
  }
  let mut current = value
  let mut current_msg = message
  let mut rounds = 0
  while rounds < limit {
    let mut found = false
    for candidate in shrinker(current) {
      match prop(candidate) {
        Ok(_) => ()
        Err(msg) => {
          current = candidate
          current_msg = msg
          found = true
          break
        }
      }
    }
    if not(found) {
      break
    }
    rounds += 1
  }
  (current, current_msg)
}

///|
/// 統計付きアサーション
pub fn[T : Show] assert_check_with_stats(
  label : String,
  gen : Gen[T],
  prop : (T) -> (Result[Unit, String], String?),
  config? : CheckConfig = CheckConfig::default(),
  shrink? : (T) -> Iter[T],
) -> Unit raise {
  let result = check_with_stats(gen, prop, config~, shrink?)
  match result.stats {
    Some(stats) => println(stats.to_string())
    None => ()
  }
  match result.failure {
    Some(failure) => fail("\{label}: \{failure}")
    None => ()
  }
}
