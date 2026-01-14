///|
test "pbt sync default is up to date" {
  let path = default_pbt_markdown_path()
  match check_sync(path) {
    Ok(_) => inspect("ok", content="ok")
    Err(errors) => fail(errors.join("\n"))
  }
}
