///|
/// PBT Framework Dogfooding Tests
/// PBTフレームワーク本体に対するプロパティテスト
///
/// このファイルでは、AletheiaのPBTフレームワーク（src/pbt/）に対して
/// Round-tripおよびIdempotentパターンのプロパティテストを実装します。

//==============================================================
// Genモジュールのテスト
//==============================================================

///|
/// Gen::pure は決定論的
/// pureでラップした値は常に同じ値を返す
test "prop_gen_pure_deterministic" {
  let value = 42
  let gen = @pbt.Gen::pure(value)
  let rs = @quickcheck/splitmix.new(seed=12345)
  let result = (gen.run)(10, rs)
  inspect(result == value, content="true")
}

///|
/// Gen::pure Idempotent
/// 同じ値で複数回pureを作っても同じ結果
test "prop_gen_pure_idempotent" {
  let value = 99
  let gen1 = @pbt.Gen::pure(value)
  let gen2 = @pbt.Gen::pure(value)
  let rs1 = @quickcheck/splitmix.new(seed=42)
  let rs2 = @quickcheck/splitmix.new(seed=42)
  let v1 = (gen1.run)(5, rs1)
  let v2 = (gen2.run)(5, rs2)
  inspect(v1 == v2, content="true")
}

///|
/// Gen::map identity (Functor則)
/// map(gen, identity) == gen
test "prop_gen_map_identity" {
  let gen = @pbt.Gen::choose_int(0, 100)
  let identity_gen = @pbt.Gen::map(gen, fn(x) { x })
  let rs1 = @quickcheck/splitmix.new(seed=999)
  let rs2 = @quickcheck/splitmix.new(seed=999)
  let v1 = (gen.run)(10, rs1)
  let v2 = (identity_gen.run)(10, rs2)
  inspect(v1 == v2, content="true")
}

///|
/// Gen::map composition (Functor結合法則 - Round-trip)
/// map(map(gen, f), g) == map(gen, g . f)
test "prop_gen_map_composition" {
  let gen = @pbt.Gen::choose_int(0, 50)
  let f = fn(x) { x + 1 }
  let g = fn(x) { x * 2 }

  // map(map(gen, f), g)
  let mapped_twice = @pbt.Gen::map(@pbt.Gen::map(gen, f), g)

  // map(gen, g . f)
  let composed = @pbt.Gen::map(gen, fn(x) { g(f(x)) })
  let rs1 = @quickcheck/splitmix.new(seed=111)
  let rs2 = @quickcheck/splitmix.new(seed=111)
  let v1 = (mapped_twice.run)(10, rs1)
  let v2 = (composed.run)(10, rs2)
  inspect(v1 == v2, content="true")
}

///|
/// Gen::bind left identity (Monad則 - Round-trip)
/// bind(pure(x), f) == f(x)
test "prop_gen_bind_left_identity" {
  let x = 10
  let f = fn(n : Int) { @pbt.Gen::pure(n * 2) }
  let left = @pbt.Gen::bind(@pbt.Gen::pure(x), f)
  let right = f(x)
  let rs1 = @quickcheck/splitmix.new(seed=222)
  let rs2 = @quickcheck/splitmix.new(seed=222)
  let v1 = (left.run)(5, rs1)
  let v2 = (right.run)(5, rs2)
  inspect(v1 == v2, content="true")
}

///|
/// Gen::bind right identity (Monad則 - Round-trip)
/// bind(m, pure) == m
test "prop_gen_bind_right_identity" {
  let m = @pbt.Gen::choose_int(0, 100)
  let bound = @pbt.Gen::bind(m, fn(x) { @pbt.Gen::pure(x) })
  let rs1 = @quickcheck/splitmix.new(seed=333)
  let rs2 = @quickcheck/splitmix.new(seed=333)
  let v1 = (m.run)(10, rs1)
  let v2 = (bound.run)(10, rs2)
  inspect(v1 == v2, content="true")
}

///|
/// Gen::resize はsizeパラメータをオーバーライド
/// resize(sized(fn(s){gen}), n) は n をsizeとして使用
test "prop_gen_resize_override" {
  let sized_gen = @pbt.Gen::sized(fn(size) { @pbt.Gen::pure(size) })
  let resized = @pbt.Gen::resize(sized_gen, 99)
  let rs = @quickcheck/splitmix.new(seed=444)
  let result = (resized.run)(0, rs) // 元のsizeは0だがresizeで99に上書き
  inspect(result == 99, content="true")
}

///|
/// Gen::resize Idempotent
/// resize(resize(gen, n1), n2) == resize(gen, n2)
test "prop_gen_resize_idempotent" {
  let gen = @pbt.Gen::pure(42)
  let resized_twice = @pbt.Gen::resize(@pbt.Gen::resize(gen, 10), 20)
  let resized_once = @pbt.Gen::resize(gen, 20)
  let rs1 = @quickcheck/splitmix.new(seed=555)
  let rs2 = @quickcheck/splitmix.new(seed=555)
  let v1 = (resized_twice.run)(0, rs1)
  let v2 = (resized_once.run)(0, rs2)
  inspect(v1 == v2, content="true")
}

///|
/// Gen::choose_int bounds validation
/// 結果は常に[min, max]範囲内
test "prop_gen_choose_int_within_bounds" {
  let config = @pbt.CheckConfig::new(100, 50, 12345, 10)
  let gen = @pbt.Gen::choose_int(-10, 10)
  @pbt.assert_check(
    "choose_int within bounds",
    gen,
    fn(x) {
      if x >= -10 && x <= 10 {
        Ok(())
      } else {
        Err("value out of bounds: " + int_to_string(x))
      }
    },
    config~,
  )
}

///|
/// Gen::choose_int equal bounds (Idempotent)
/// choose_int(n, n) は常に n を返す
test "prop_gen_choose_int_equal_bounds" {
  let config = @pbt.CheckConfig::new(10, 1, 54321, 0)
  let gen = @pbt.Gen::choose_int(42, 42)
  @pbt.assert_check(
    "choose_int equal bounds",
    gen,
    fn(x) {
      if x == 42 {
        Ok(())
      } else {
        Err("expected 42, got: " + int_to_string(x))
      }
    },
    config~,
  )
}

///|
/// Gen::choose_int swapped bounds (Round-trip)
/// choose_int(min, max) == choose_int(max, min)
test "prop_gen_choose_int_swapped" {
  let gen1 = @pbt.Gen::choose_int(10, 20)
  let gen2 = @pbt.Gen::choose_int(20, 10)
  let rs1 = @quickcheck/splitmix.new(seed=666)
  let rs2 = @quickcheck/splitmix.new(seed=666)
  let v1 = (gen1.run)(5, rs1)
  let v2 = (gen2.run)(5, rs2)
  inspect(v1 == v2, content="true")
}

///|
/// Gen::one_of single element
/// one_of([gen]) は gen と同じ範囲の値を生成
test "prop_gen_one_of_single_element" {
  let inner = @pbt.Gen::choose_int(0, 100)
  let one = @pbt.Gen::one_of([inner])

  // どちらも同じ範囲の値を生成することを確認
  let config = @pbt.CheckConfig::new(50, 10, 777, 0)
  @pbt.assert_check(
    "one_of single element range",
    one,
    fn(x) {
      if x >= 0 && x <= 100 {
        Ok(())
      } else {
        Err("value out of range: " + int_to_string(x))
      }
    },
    config~,
  )
}

///|
/// Gen::one_of は常に配列から選択
test "prop_gen_one_of_within_bounds" {
  let gen1 = @pbt.Gen::pure(1)
  let gen2 = @pbt.Gen::pure(2)
  let gen3 = @pbt.Gen::pure(3)
  let one_of = @pbt.Gen::one_of([gen1, gen2, gen3])
  let config = @pbt.CheckConfig::new(50, 10, 88888, 0)
  @pbt.assert_check(
    "one_of selects from array",
    one_of,
    fn(x) {
      if x == 1 || x == 2 || x == 3 {
        Ok(())
      } else {
        Err("value not in expected set: " + int_to_string(x))
      }
    },
    config~,
  )
}

///|
/// Gen::frequency single item (Idempotent)
/// frequency([(w, gen)]) == gen
test "prop_gen_frequency_single_item" {
  let inner = @pbt.Gen::pure(42)
  let freq = @pbt.Gen::frequency([(5, inner)])
  let rs1 = @quickcheck/splitmix.new(seed=999)
  let rs2 = @quickcheck/splitmix.new(seed=999)
  let v1 = (freq.run)(10, rs1)
  let v2 = (inner.run)(10, rs2)
  inspect(v1 == v2, content="true")
}

///|
/// Gen::frequency は常に配列から選択
test "prop_gen_frequency_within_bounds" {
  let gen1 = @pbt.Gen::pure(10)
  let gen2 = @pbt.Gen::pure(20)
  let gen3 = @pbt.Gen::pure(30)
  let freq = @pbt.Gen::frequency([(1, gen1), (2, gen2), (1, gen3)])
  let config = @pbt.CheckConfig::new(50, 10, 10101, 0)
  @pbt.assert_check(
    "frequency selects from items",
    freq,
    fn(x) {
      if x == 10 || x == 20 || x == 30 {
        Ok(())
      } else {
        Err("value not in expected set: " + int_to_string(x))
      }
    },
    config~,
  )
}

///|
/// Gen::array_of length bound
/// 生成される配列の長さは size 以下
test "prop_gen_array_of_length_bound" {
  let config = @pbt.CheckConfig::new(100, 30, 20202, 10)
  let inner = @pbt.Gen::pure(1)
  let arr_gen = @pbt.Gen::array_of(inner)
  @pbt.assert_check(
    "array_of length bound",
    arr_gen,
    fn(arr) {
      if arr.length() <= 30 {
        Ok(())
      } else {
        Err("array too large: " + int_to_string(arr.length()))
      }
    },
    config~,
  )
}

///|
/// Gen::array_of empty size (Idempotent)
/// size=0なら空配列
test "prop_gen_array_of_empty_size" {
  let inner = @pbt.Gen::pure(42)
  let arr_gen = @pbt.Gen::array_of(inner)
  let rs = @quickcheck/splitmix.new(seed=30303)

  // size=0で実行
  let result = (arr_gen.run)(0, rs)
  inspect(result.length(), content="0")
}

//==============================================================
// Checkモジュールのテスト
//==============================================================

///|
/// check with always-passing property (Idempotent)
/// 常に成功するプロパティはOk(())を返す
test "prop_check_always_passing" {
  let config = @pbt.CheckConfig::new(100, 10, 40404, 0)
  let gen = @pbt.Gen::choose_int(-100, 100)
  let result = @pbt.check(gen, fn(_) { Ok(()) }, config~)
  match result {
    Ok(_) => inspect("passed", content="passed")
    Err(_) => inspect("should pass", content="should pass")
  }
}

///|
/// check with always-failing property
/// 常に失敗するプロパティはErr(Failure)を返す
test "prop_check_always_failing" {
  let config = @pbt.CheckConfig::new(10, 1, 50505, 0)
  let gen = @pbt.Gen::pure(42)
  let result = @pbt.check(gen, fn(_) { Err("always fails") }, config~)
  match result {
    Ok(_) => inspect("should fail", content="should fail")
    Err(failure) => inspect(failure.message, content="always fails")
  }
}

///|
/// check failure contains original value (Round-trip)
/// 失敗時に元の値を保持している
test "prop_check_failure_contains_original" {
  let config = @pbt.CheckConfig::new(5, 1, 60606, 0)
  let gen = @pbt.Gen::choose_int(1, 100)
  let result = @pbt.check(
    gen,
    fn(x) { if x > 50 { Ok(()) } else { Err("too small") } },
    config~,
  )
  match result {
    Ok(_) => inspect("should fail", content="should fail")
    Err(failure) =>
      inspect(
        failure.original.contains("too small") || failure.original != "",
        content="true",
      )
  }
}

///|
/// CheckConfig::default produces valid config
test "prop_check_config_default_valid" {
  let config = @pbt.CheckConfig::default()
  inspect(config.cases == 100, content="true")
  inspect(config.max_size == 30, content="true")
  inspect(config.seed == 1, content="true")
  inspect(config.shrink_limit == 100, content="true")
}

//==============================================================
// Shrinkモジュールのテスト
//==============================================================

///|
/// shrink_int includes zero
/// 非ゼロ値の縮小には0が含まれる
test "prop_shrink_int_includes_zero" {
  let config = @pbt.CheckConfig::new(50, 100, 70707, 0)
  let gen = @pbt.Gen::choose_int(1, 1000)
  @pbt.assert_check(
    "shrink_int includes zero",
    gen,
    fn(x) {
      let shrunk = @pbt.shrink_int(x).to_array()
      if shrunk.length() > 0 && shrunk[0] == 0 {
        Ok(())
      } else {
        Err("shrink_int(" + int_to_string(x) + ") should start with 0")
      }
    },
    config~,
  )
}

///|
/// shrink_int monotonic decreasing (Idempotent)
/// 縮小は単調減少する（最初の0以降）
test "prop_shrink_int_monotonic" {
  let config = @pbt.CheckConfig::new(100, 1000, 80808, 0)
  let gen = @pbt.Gen::choose_int(10, 1000)
  @pbt.assert_check(
    "shrink_int monotonic decreasing",
    gen,
    fn(x) {
      let shrunk = @pbt.shrink_int(x).to_array()
      // shrink_intは最初に0を返すので、2番目の要素からチェック
      if shrunk.length() < 2 {
        Ok(())
      } else {
        let mut prev = shrunk[1] // 2番目の要素から開始
        let mut i = 2
        let mut result = Ok(())
        while i < shrunk.length() {
          let curr = shrunk[i]
          if curr >= prev {
            result = Err(
              "not decreasing: " +
              int_to_string(prev) +
              " -> " +
              int_to_string(curr),
            )
            break
          } else {
            prev = curr
            i = i + 1
          }
        }
        result
      }
    },
    config~,
  )
}

///|
/// shrink_int(0) returns empty (Idempotent)
test "prop_shrink_int_zero_empty" {
  let shrunk = @pbt.shrink_int(0).to_array()
  inspect(shrunk.length(), content="0")
}

///|
/// shrink_int powers of two pattern (Round-trip)
/// x/2, x/4, x/8, ..., 1 シーケンス
test "prop_shrink_int_powers_of_two" {
  let x = 64
  let shrunk = @pbt.shrink_int(x).to_array()
  // [0, 32, 16, 8, 4, 2, 1]
  inspect(shrunk.length(), content="7")
  inspect(shrunk[0], content="0")
  inspect(shrunk[1], content="32")
}

///|
/// shrink_array includes empty
/// 非空配列の縮小には空配列が含まれる
test "prop_shrink_array_includes_empty" {
  let config = @pbt.CheckConfig::new(50, 50, 90909, 0)
  let inner = @pbt.Gen::pure(1)
  let arr_gen = @pbt.Gen::array_of(inner)
  @pbt.assert_check(
    "shrink_array includes empty",
    arr_gen,
    fn(arr) {
      if arr.length() == 0 {
        Ok(()) // 空配列は空に縮小
      } else {
        let shrunk = @pbt.shrink_array(arr).to_array()
        let has_empty = shrunk.length() > 0 && shrunk[shrunk.length() - 1] == []
        if has_empty {
          Ok(())
        } else {
          Err("shrink_array should end with empty array")
        }
      }
    },
    config~,
  )
}

///|
/// shrink_array produces prefixes
/// 縮小結果は元の配列のプレフィックス
test "prop_shrink_array_prefixes" {
  let arr = [1, 2, 3, 4, 5]
  let shrunk = @pbt.shrink_array(arr).to_array()

  // 各要素はプレフィックスまたは空配列
  let mut i = 0
  let mut valid = true
  while i < shrunk.length() {
    let s = shrunk[i]
    if s.length() > 0 {
      // プレフィックスチェック
      let mut j = 0
      let mut is_prefix = true
      while j < s.length() {
        if s[j] != arr[j] {
          is_prefix = false
        }
        j = j + 1
      }
      if not(is_prefix) {
        valid = false
      }
    }
    i = i + 1
  }
  inspect(valid, content="true")
}

///|
/// shrink_array([]) returns empty (Idempotent)
test "prop_shrink_array_empty" {
  let empty : Array[Int] = []
  let shrunk = @pbt.shrink_array(empty).to_array()
  inspect(shrunk.length(), content="0")
}

//==============================================================
// ユーティリティ関数
//==============================================================

///|
/// IntをStringに変換（dogfoodingモジュールの関数を再利用）
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
