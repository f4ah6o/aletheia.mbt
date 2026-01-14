///|
test "check passes simple property" {
  let gen = Gen::choose_int(-10, 10)
  let config = CheckConfig::new(50, 10, 1, 0)
  assert_check(
    "add zero",
    gen,
    fn(x : Int) { if x + 0 == x { Ok(()) } else { Err("add zero failed") } },
    config~,
  )
}

///|
test "check failure reports message" {
  let gen = Gen::choose_int(0, 0)
  let config = CheckConfig::new(1, 1, 1, 0)
  let result = check(gen, fn(_x : Int) { Err("always fails") }, config~)
  match result {
    Ok(_) => fail("expected failure")
    Err(failure) => inspect(failure.message, content="always fails")
  }
}

///|
test "shrink int" {
  let shrunk = shrink_int(42).to_array()
  assert_eq(shrunk, [0, 21, 10, 5, 2, 1])
}

///|
test "shrink array" {
  let shrunk = shrink_array([1, 2, 3, 4]).to_array()
  assert_eq(shrunk, [[1, 2], [1], []])
}
