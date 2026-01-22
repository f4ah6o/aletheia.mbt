///|
/// ファイル内容を読み込み
fn read_file_content(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ => ""
  }
}

///|
/// ディレクトリ一覧を安全に取得
fn read_dir_entries(path : String) -> Array[String] {
  @fs.read_dir(path) catch {
    _ => []
  }
}

///|
/// パスがディレクトリか判定
fn is_dir(path : String) -> Bool {
  @fs.is_dir(path) catch {
    _ => false
  }
}

///|
/// パスがファイルか判定
fn is_file(path : String) -> Bool {
  @fs.is_file(path) catch {
    _ => false
  }
}

///|
/// パスを結合
fn join_path(base : String, name : String) -> String {
  let entry_path = @path.Path(name)
  if entry_path.is_absolute() {
    name
  } else {
    @path.Path(base).join(entry_path).to_string()
  }
}

///|
fn extract_module_name_from_mod(content : String) -> String? {
  let key = "\"name\""
  match content.find(key) {
    None => None
    Some(pos) => {
      let chars = content.to_array()
      let mut i = pos + key.length()
      while i < chars.length() && chars[i].is_whitespace() {
        i = i + 1
      }
      if i >= chars.length() || chars[i] != ':' {
        return None
      }
      i = i + 1
      while i < chars.length() && chars[i].is_whitespace() {
        i = i + 1
      }
      if i >= chars.length() || chars[i] != '"' {
        return None
      }
      i = i + 1
      let mut value = ""
      while i < chars.length() && chars[i] != '"' {
        value = value + chars[i].to_string()
        i = i + 1
      }
      Some(value)
    }
  }
}

///|
fn module_short_name(name : String) -> String {
  let parts = name.split("/").to_array()
  if parts.length() == 0 {
    name
  } else {
    parts[parts.length() - 1].to_string()
  }
}

///|
fn extract_module_name() -> String {
  let content = read_file_content("moon.mod.json")
  match extract_module_name_from_mod(content) {
    None => "module"
    Some(name) => module_short_name(name)
  }
}

///|
fn output_path_for_pbt(path : String, module_name : String) -> String {
  let dir = if is_dir(path) {
    path
  } else {
    @path.Path(path).dirname().to_string()
  }
  let filename = module_name + ".pbt.md"
  @path.Path(dir).join(@path.Path(filename)).to_string()
}

///|
/// 親ディレクトリを取得
fn path_dirname(path : String) -> String {
  @path.Path(path).dirname().to_string()
}

///|
/// パッケージディレクトリか判定
/// moon.pkg (new format) または moon.pkg.json (legacy) の存在をチェック
fn has_moon_pkg(path : String) -> Bool {
  let pkg_file_new = join_path(path, "moon.pkg")
  let pkg_file_legacy = join_path(path, "moon.pkg.json")
  @fs.path_exists(pkg_file_new) || @fs.path_exists(pkg_file_legacy)
}

///|
/// 除外対象ディレクトリか判定
fn should_skip_dir(name : String) -> Bool {
  name == ".git" ||
  name == ".moon" ||
  name == ".mooncakes" ||
  name == ".moonagent" ||
  name == "_build" ||
  name == "target" ||
  name == "node_modules"
}

///|
/// 近傍のパッケージディレクトリを探索
fn find_package_dir(start : String) -> String? {
  let mut current = start
  while true {
    if has_moon_pkg(current) {
      return Some(current)
    }
    let parent = path_dirname(current)
    if parent == current {
      break
    }
    current = parent
  }
  None
}

///|
/// 入力パスからパッケージディレクトリを解決
fn resolve_package_dirs(path : String) -> Array[String] {
  if is_file(path) {
    match find_package_dir(path_dirname(path)) {
      Some(dir) => [dir]
      None => []
    }
  } else if is_dir(path) {
    if has_moon_pkg(path) {
      [path]
    } else {
      collect_package_dirs(path)
    }
  } else {
    []
  }
}

///|
/// 配下のパッケージディレクトリを再帰的に収集
fn collect_package_dirs(root : String) -> Array[String] {
  let result : Array[String] = []
  let entries = read_dir_entries(root)
  entries.sort_by((a, b) => String::compare(a, b))
  let mut i = 0
  while i < entries.length() {
    let entry = entries[i]
    if should_skip_dir(entry) {
      i = i + 1
      continue
    }
    let path = join_path(root, entry)
    if is_dir(path) {
      if has_moon_pkg(path) {
        Array::push(result, path)
      }
      let nested = collect_package_dirs(path)
      let _ = push_strings(result, nested)

    }
    i = i + 1
  }
  result
}

///|
/// パッケージパスからモジュール名を抽出
fn extract_module_name_from_package(package_dir : String) -> String {
  // パスセパレータ（/または\）で分割して最後の要素を取得
  let separator = "/"
  let components = package_dir.split(separator).to_array()
  if components.length() > 0 {
    components[components.length() - 1].to_string()
  } else {
    "module"
  }
}
