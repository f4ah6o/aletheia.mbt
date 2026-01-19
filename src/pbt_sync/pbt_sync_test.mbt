///|
test "pbt sync default is up to date" {
  let path = default_pbt_markdown_path()
  match check_sync(path) {
    Ok(_) => inspect("ok", content="ok")
    Err(errors) => fail(errors.join("\n"))
  }
}

///|
fn join_path(base : String, entry : String) -> String {
  @path.Path(base).join(@path.Path(entry)).to_string()
}

///|
fn ensure_dir(path : String) -> Unit {
  @fs.create_dir(path) catch {
    _ => ()
  }
}

///|
fn write_file(path : String, content : String) -> Unit {
  @fs.write_string_to_file(path, content) catch {
    _ => ()
  }
}

///|
fn read_file(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ => ""
  }
}

///|
fn remove_file(path : String) -> Unit {
  @fs.remove_file(path) catch {
    _ => ()
  }
}

///|
fn remove_dir(path : String) -> Unit {
  @fs.remove_dir(path) catch {
    _ => ()
  }
}

///|
test "sync_mbt_md_extracts_test_blocks_only" {
  let root = "src/tmp_pbt_sync_tests_blocks"
  let pkg_dir = join_path(root, "pkg")
  ensure_dir(root)
  ensure_dir(pkg_dir)
  write_file(join_path(pkg_dir, "moon.pkg.json"), "{}")
  let markdown_path = join_path(pkg_dir, "sample.mbt.md")
  write_file(
    markdown_path, "# Sample\n\n```mbt\nfn helper_fn() -> Int { 1 }\n```\n\n```mbt test\ntest \"from_mbt\" { assert_eq(1, 1) }\n```\n\n```mbt check\ntest \"from_check\" { assert_eq(2, 2) }\n```\n",
  )
  match sync(markdown_path) {
    Ok(_) => ()
    Err(errors) => fail(errors.join("\n"))
  }
  let generated_path = join_path(pkg_dir, "pbt_generated_test.mbt")
  let generated = read_file(generated_path)
  inspect(generated.contains("test \"from_mbt\""), content="true")
  inspect(generated.contains("test \"from_check\""), content="true")
  inspect(!generated.contains("helper_fn"), content="true")
  remove_file(markdown_path)
  remove_file(generated_path)
  remove_file(join_path(pkg_dir, "moon.pkg.json"))
  remove_dir(pkg_dir)
  remove_dir(root)
}

///|
test "sync_mbt_md_infers_nearest_package" {
  let root = "src/tmp_pbt_sync_tests_nested"
  let outer = join_path(root, "nested_outer")
  let inner = join_path(outer, "inner")
  ensure_dir(root)
  ensure_dir(outer)
  ensure_dir(inner)
  write_file(join_path(outer, "moon.pkg.json"), "{}")
  let markdown_path = join_path(inner, "nested.mbt.md")
  write_file(
    markdown_path, "```mbt test\ntest \"nested\" { assert_eq(1, 1) }\n```\n",
  )
  match sync(markdown_path) {
    Ok(_) => ()
    Err(errors) => fail(errors.join("\n"))
  }
  let generated_path = join_path(outer, "pbt_generated_test.mbt")
  inspect(@fs.path_exists(generated_path), content="true")
  remove_file(markdown_path)
  remove_file(generated_path)
  remove_file(join_path(outer, "moon.pkg.json"))
  remove_dir(inner)
  remove_dir(outer)
  remove_dir(root)
}

///|
test "sync_accepts_legacy_pbt_mbt_md" {
  let root = "tmp_pbt_sync_tests_legacy"
  let pkg_root = "src/tmp_pbt_sync_tests_legacy"
  let pkg_dir = join_path(pkg_root, "legacy_pkg")
  ensure_dir(root)
  ensure_dir(pkg_root)
  ensure_dir(pkg_dir)
  write_file(join_path(pkg_dir, "moon.pkg.json"), "{}")
  let markdown_path = join_path(root, "legacy.pbt.mbt.md")
  write_file(
    markdown_path, "## Package: tmp_pbt_sync_tests_legacy/legacy_pkg\n\n```mbt test\ntest \"legacy\" { assert_eq(1, 1) }\n```\n",
  )
  match sync(markdown_path) {
    Ok(_) => ()
    Err(errors) => fail(errors.join("\n"))
  }
  let generated_path = join_path(pkg_dir, "pbt_generated_test.mbt")
  let generated = read_file(generated_path)
  inspect(generated.contains("test \"legacy\""), content="true")
  remove_file(markdown_path)
  remove_file(generated_path)
  remove_file(join_path(pkg_dir, "moon.pkg.json"))
  remove_dir(pkg_dir)
  remove_dir(pkg_root)
  remove_dir(root)
}
