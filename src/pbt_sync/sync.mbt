///|
/// PBT markdown sync support.
pub type SyncError = Array[String]

///|
pub struct SyncReport {
  written : Array[String]
  removed : Array[String]
  unchanged : Array[String]
}

///|
pub fn default_pbt_markdown_path() -> String {
  let content = read_file_content_or_empty("moon.mod.json")
  let source = match extract_json_string_value(content, "source") {
    None => "."
    Some(value) => value
  }
  let module_name = match extract_json_string_value(content, "name") {
    None => "module"
    Some(name) => module_short_name(name)
  }
  let filename = module_name + ".pbt.md"
  join_path(source, filename)
}

///|
pub fn sync(markdown_path : String) -> Result[SyncReport, SyncError] {
  let plan = build_expected_outputs(markdown_path)
  match plan {
    Err(errors) => Err(errors)
    Ok(plan) => {
      let expected_paths : Array[String] = []
      let mut i = 0
      while i < plan.outputs.length() {
        Array::push(expected_paths, normalize_path(plan.outputs[i].path))
        i = i + 1
      }
      let written : Array[String] = []
      let unchanged : Array[String] = []
      let write_errors : Array[String] = []
      let mut j = 0
      while j < plan.outputs.length() {
        let output = plan.outputs[j]
        match write_if_changed(output.path, output.content) {
          Ok(changed) =>
            if changed {
              Array::push(written, output.path)
            } else {
              Array::push(unchanged, output.path)
            }
          Err(msg) =>
            Array::push(
              write_errors,
              "Failed to write " + output.path + ": " + msg,
            )
        }
        j = j + 1
      }
      if write_errors.length() > 0 {
        return Err(write_errors)
      }
      match remove_stale_files(expected_paths) {
        Err(errors) => Err(errors)
        Ok(removed) => Ok({ written, removed, unchanged })
      }
    }
  }
}

///|
pub fn check_sync(markdown_path : String) -> Result[Unit, SyncError] {
  let plan = build_expected_outputs(markdown_path)
  match plan {
    Err(errors) => Err(errors)
    Ok(plan) => {
      let errors : Array[String] = []
      let expected_paths : Array[String] = []
      let mut i = 0
      while i < plan.outputs.length() {
        let output = plan.outputs[i]
        Array::push(expected_paths, normalize_path(output.path))
        match read_file_content(output.path) {
          Err(_) =>
            Array::push(errors, "Missing generated file: " + output.path)
          Ok(content) =>
            if content != output.content {
              Array::push(errors, "Out of date generated file: " + output.path)
            }
        }
        i = i + 1
      }
      let generated = collect_generated_files(plan.source_root)
      let mut j = 0
      while j < generated.length() {
        let path = generated[j]
        if !contains_path(expected_paths, path) {
          Array::push(errors, "Unexpected generated file: " + path)
        }
        j = j + 1
      }
      if errors.length() > 0 {
        Err(errors)
      } else {
        Ok(())
      }
    }
  }
}

///|
priv struct SyncPlan {
  source_root : String
  outputs : Array[OutputFile]
}

///|
priv struct OutputFile {
  path : String
  content : String
}

///|
priv struct ParsedBlock {
  pkg : String
  lines : Array[String]
}

///|
priv struct PackageBlocks {
  name : String
  blocks : Array[Array[String]]
}

///|
fn build_expected_outputs(
  markdown_path : String,
) -> Result[SyncPlan, SyncError] {
  let errors : Array[String] = []
  let markdown_result = read_file_content(markdown_path)
  let markdown = match markdown_result {
    Err(msg) => {
      Array::push(errors, "Failed to read markdown: " + msg)
      ""
    }
    Ok(content) => content
  }
  if errors.length() > 0 {
    return Err(errors)
  }
  let source_root = resolve_source_root()
  let blocks_result = if is_moonbit_markdown_path(markdown_path) &&
    !is_pbt_markdown_path(markdown_path) {
    match infer_package_name(markdown_path, source_root) {
      Err(msg) => return Err([msg])
      Ok(pkg_name) => parse_moonbit_markdown_blocks(markdown, pkg_name)
    }
  } else {
    parse_markdown_blocks(markdown)
  }
  let blocks = match blocks_result {
    Err(errs) => return Err(errs)
    Ok(found) => found
  }
  let grouped = group_blocks(blocks)
  grouped.sort_by((a, b) => String::compare(a.name, b.name))
  let outputs : Array[OutputFile] = []
  let mut i = 0
  while i < grouped.length() {
    let entry = grouped[i]
    match resolve_package_dir(source_root, entry.name) {
      Err(msg) => Array::push(errors, msg)
      Ok(dir) => {
        let content = render_blocks(entry.blocks)
        if content != "" {
          let output_path = join_path(dir, "pbt_generated_test.mbt")
          Array::push(outputs, { path: output_path, content })
        }
      }
    }
    i = i + 1
  }
  if errors.length() > 0 {
    Err(errors)
  } else {
    Ok({ source_root, outputs })
  }
}

///|
fn is_pbt_markdown_path(path : String) -> Bool {
  path.has_suffix(".pbt.md") || path.has_suffix(".pbt.mbt.md")
}

///|
fn is_moonbit_markdown_path(path : String) -> Bool {
  path.has_suffix(".mbt.md")
}

///|
fn parse_moonbit_markdown_blocks(
  markdown : String,
  pkg : String,
) -> Result[Array[ParsedBlock], SyncError] {
  let blocks = @parser.extract_test_blocks(markdown)
  let result : Array[ParsedBlock] = []
  let mut i = 0
  while i < blocks.length() {
    let lines = split_lines(blocks[i].content)
    Array::push(result, { pkg, lines })
    i = i + 1
  }
  Ok(result)
}

///|
fn parse_markdown_blocks(
  markdown : String,
) -> Result[Array[ParsedBlock], SyncError] {
  let lines = split_lines(markdown)
  let blocks : Array[ParsedBlock] = []
  let errors : Array[String] = []
  let mut current_pkg : String? = None
  let mut in_block = false
  let mut block_lang = ""
  let mut block_lines : Array[String] = []
  let mut block_start = 0
  let mut line_num = 0
  while line_num < lines.length() {
    let line = lines[line_num]
    let trimmed = line.trim()
    if !in_block {
      if trimmed.has_prefix("## Package:") {
        let package_name = parse_package_name(trimmed.to_string())
        if package_name == "" {
          Array::push(
            errors,
            "Package heading missing name at line " + "\{line_num + 1}",
          )
          current_pkg = None
        } else {
          current_pkg = Some(package_name)
        }
      } else if trimmed.has_prefix("```") {
        in_block = true
        block_start = line_num + 1
        block_lang = parse_fence_lang(trimmed.to_string())
        block_lines = []
      }
    } else if trimmed.has_prefix("```") {
      if should_include_code_block(block_lang) {
        match current_pkg {
          None =>
            Array::push(
              errors,
              "Code block at line " +
              "\{block_start}" +
              " is not under a package heading",
            )
          Some(pkg) => Array::push(blocks, { pkg, lines: block_lines })
        }
      }
      in_block = false
      block_lang = ""
      block_lines = []
    } else {
      Array::push(block_lines, line)
    }
    line_num = line_num + 1
  }
  if in_block {
    Array::push(
      errors,
      "Unclosed code block starting at line " + "\{block_start}",
    )
  }
  if errors.length() > 0 {
    Err(errors)
  } else {
    Ok(blocks)
  }
}

///|
fn parse_package_name(line : String) -> String {
  let parts = line.split("## Package:").to_array()
  if parts.length() > 1 {
    parts[1].trim().to_string()
  } else {
    ""
  }
}

///|
fn parse_fence_lang(line : String) -> String {
  let parts = line.split("```").to_array()
  if parts.length() > 1 {
    parts[1].trim().to_string()
  } else {
    ""
  }
}

///|
fn should_include_code_block(lang : String) -> Bool {
  let tokens = split_lang_tokens(lang)
  let mut is_moonbit = false
  let mut nocheck = false
  let mut i = 0
  while i < tokens.length() {
    let token = tokens[i]
    if token == "mbt" || token == "moonbit" {
      is_moonbit = true
    } else if token == "nocheck" {
      nocheck = true
    }
    i = i + 1
  }
  is_moonbit && !nocheck
}

///|
fn split_lang_tokens(lang : String) -> Array[String] {
  let parts = lang.split(" ").to_array()
  let result : Array[String] = []
  let mut i = 0
  while i < parts.length() {
    let token = parts[i].trim().to_string()
    if token != "" {
      Array::push(result, token)
    }
    i = i + 1
  }
  result
}

///|
fn split_lines(source : String) -> Array[String] {
  source.split("\n").map(fn(s) { s.to_string() }).to_array()
}

///|
fn group_blocks(blocks : Array[ParsedBlock]) -> Array[PackageBlocks] {
  let result : Array[PackageBlocks] = []
  let mut i = 0
  while i < blocks.length() {
    let block = blocks[i]
    let idx = find_package_index(result, block.pkg)
    if idx < 0 {
      Array::push(result, { name: block.pkg, blocks: [block.lines] })
    } else {
      result[idx].blocks.push(block.lines)
    }
    i = i + 1
  }
  result
}

///|
fn find_package_index(sections : Array[PackageBlocks], name : String) -> Int {
  let mut i = 0
  while i < sections.length() {
    if sections[i].name == name {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn render_blocks(blocks : Array[Array[String]]) -> String {
  let output_lines : Array[String] = []
  let mut i = 0
  while i < blocks.length() {
    let normalized = normalize_block_lines(blocks[i])
    if normalized.length() > 0 {
      if output_lines.length() > 0 {
        Array::push(output_lines, "")
      }
      output_lines.append(normalized)
    }
    i = i + 1
  }
  if output_lines.length() == 0 {
    ""
  } else {
    output_lines.join("\n") + "\n"
  }
}

///|
fn normalize_block_lines(lines : Array[String]) -> Array[String] {
  let trimmed = trim_empty_lines(lines)
  if trimmed.length() == 0 {
    return []
  }
  let first_trimmed = trimmed[0].trim().to_string()
  if first_trimmed == "///|" {
    trimmed
  } else {
    let result : Array[String] = []
    Array::push(result, "///|")
    result.append(trimmed)
    result
  }
}

///|
fn trim_empty_lines(lines : Array[String]) -> Array[String] {
  let mut start = 0
  let mut end = lines.length()
  while start < end && is_blank_line(lines[start]) {
    start = start + 1
  }
  while end > start && is_blank_line(lines[end - 1]) {
    end = end - 1
  }
  let result : Array[String] = []
  let mut i = start
  while i < end {
    Array::push(result, lines[i])
    i = i + 1
  }
  result
}

///|
fn infer_package_name(
  markdown_path : String,
  source_root : String,
) -> Result[String, String] {
  let dir = @path.Path(markdown_path).dirname().to_string()
  match find_package_dir(dir, source_root) {
    None =>
      Err(
        "Failed to find package for markdown: " + normalize_path(markdown_path),
      )
    Some(pkg_dir) => relative_package_name(source_root, pkg_dir)
  }
}

///|
fn find_package_dir(start : String, source_root : String) -> String? {
  let mut current = start
  let normalized_root = normalize_path(source_root)
  while true {
    if has_moon_pkg(current) {
      return Some(current)
    }
    if normalize_path(current) == normalized_root {
      break
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
fn has_moon_pkg(path : String) -> Bool {
  let pkg_file_new = join_path(path, "moon.pkg")
  let pkg_file_legacy = join_path(path, "moon.pkg.json")
  @fs.path_exists(pkg_file_new) || @fs.path_exists(pkg_file_legacy)
}

///|
fn path_dirname(path : String) -> String {
  @path.Path(path).dirname().to_string()
}

///|
fn relative_package_name(
  source_root : String,
  package_dir : String,
) -> Result[String, String] {
  let normalized_root = normalize_path(source_root)
  let normalized_pkg = normalize_path(package_dir)
  if normalized_root == normalized_pkg {
    return Ok(".")
  }
  let prefix = if normalized_root.has_suffix("/") {
    normalized_root
  } else {
    normalized_root + "/"
  }
  if normalized_pkg.has_prefix(prefix) {
    Ok(substring_from(normalized_pkg, String::length(prefix)))
  } else {
    Err("Package is outside source root: " + normalized_pkg)
  }
}

///|
fn substring_from(s : String, start : Int) -> String {
  let chars = s.to_array()
  let mut i = start
  let mut result = ""
  while i < chars.length() {
    result = result + chars[i].to_string()
    i = i + 1
  }
  result
}

///|
fn is_blank_line(line : String) -> Bool {
  line.trim().to_string() == ""
}

///|
fn resolve_source_root() -> String {
  let content = read_file_content_or_empty("moon.mod.json")
  let source = match extract_json_string_value(content, "source") {
    None => "."
    Some(value) => value
  }
  normalize_path(source)
}

///|
fn resolve_package_dir(
  source_root : String,
  pkg_name : String,
) -> Result[String, String] {
  let trimmed = pkg_name.trim().to_string()
  if trimmed == "" {
    return Err("Package name is empty")
  }
  let package_path = @path.Path(trimmed)
  if package_path.is_absolute() {
    return Err("Package path must be relative: " + trimmed)
  }
  let dir = if trimmed == "." {
    source_root
  } else {
    join_path(source_root, trimmed)
  }
  if !is_dir(dir) {
    return Err("Package directory not found: " + dir)
  }
  // Support both moon.pkg (new format) and moon.pkg.json (legacy)
  let pkg_file_new = join_path(dir, "moon.pkg")
  let pkg_file_legacy = join_path(dir, "moon.pkg.json")
  if !is_file(pkg_file_new) && !is_file(pkg_file_legacy) {
    return Err("Package missing moon.pkg or moon.pkg.json: " + dir)
  }
  Ok(dir)
}

///|
fn collect_generated_files(path : String) -> Array[String] {
  let result : Array[String] = []
  if is_dir(path) {
    if should_skip_dir(path) {
      return result
    }
    let entries = read_dir_entries(path)
    let mut i = 0
    while i < entries.length() {
      let child = join_path(path, entries[i])
      if is_dir(child) {
        result.append(collect_generated_files(child))
      } else if is_file(child) {
        let name = basename(child)
        if name == "pbt_generated_test.mbt" {
          Array::push(result, normalize_path(child))
        }
      }
      i = i + 1
    }
  }
  result.sort_by((a, b) => String::compare(a, b))
  result
}

///|
fn extract_package_dirs(expected_paths : Array[String]) -> Array[String] {
  let result : Array[String] = []
  let mut i = 0
  while i < expected_paths.length() {
    let path = expected_paths[i]
    let dir = path_dirname(path)
    if !contains_dir(result, dir) {
      Array::push(result, dir)
    }
    i = i + 1
  }
  result
}

///|
fn contains_dir(dirs : Array[String], dir : String) -> Bool {
  let normalized = normalize_path(dir)
  let mut i = 0
  while i < dirs.length() {
    if normalize_path(dirs[i]) == normalized {
      return true
    }
    i = i + 1
  }
  false
}

///|
fn collect_generated_files_from_dirs(dirs : Array[String]) -> Array[String] {
  let result : Array[String] = []
  if dirs.length() == 0 {
    return result
  }
  let mut i = 0
  while i < dirs.length() {
    result.append(collect_generated_files(dirs[i]))
    i = i + 1
  }
  result.sort_by((a, b) => String::compare(a, b))
  result
}

///|
fn remove_stale_files(
  expected_paths : Array[String],
) -> Result[Array[String], SyncError] {
  let package_dirs = extract_package_dirs(expected_paths)
  let generated = collect_generated_files_from_dirs(package_dirs)
  let removed : Array[String] = []
  let errors : Array[String] = []
  let mut i = 0
  while i < generated.length() {
    let path = generated[i]
    if !contains_path(expected_paths, path) {
      match remove_file(path) {
        Err(msg) => Array::push(errors, "Failed to remove " + path + ": " + msg)
        Ok(_) => Array::push(removed, path)
      }
    }
    i = i + 1
  }
  if errors.length() > 0 {
    Err(errors)
  } else {
    Ok(removed)
  }
}

///|
fn contains_path(paths : Array[String], path : String) -> Bool {
  let mut i = 0
  while i < paths.length() {
    if paths[i] == path {
      return true
    }
    i = i + 1
  }
  false
}

///|
fn remove_file(path : String) -> Result[Unit, String] {
  try {
    @fs.remove_file(path)
    Ok(())
  } catch {
    err => Err("\{err}")
  }
}

///|
fn write_if_changed(path : String, content : String) -> Result[Bool, String] {
  match read_file_content(path) {
    Ok(existing) =>
      if existing == content {
        Ok(false)
      } else {
        try {
          @fs.write_string_to_file(path, content)
          Ok(true)
        } catch {
          err => Err("\{err}")
        }
      }
    Err(_) =>
      try {
        @fs.write_string_to_file(path, content)
        Ok(true)
      } catch {
        err => Err("\{err}")
      }
  }
}

///|
fn read_file_content(path : String) -> Result[String, String] {
  Ok(@fs.read_file_to_string(path)) catch {
    err => Err("\{err}")
  }
}

///|
fn read_file_content_or_empty(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ => ""
  }
}

///|
fn extract_json_string_value(content : String, key : String) -> String? {
  let quoted = "\"" + key + "\""
  match content.find(quoted) {
    None => None
    Some(pos) => {
      let chars = content.to_array()
      let mut i = pos + quoted.length()
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
fn join_path(base : String, entry : String) -> String {
  let entry_path = @path.Path(entry)
  if entry_path.is_absolute() {
    entry
  } else {
    @path.Path(base).join(entry_path).to_string()
  }
}

///|
fn normalize_path(path : String) -> String {
  @path.Path(path).to_string()
}

///|
fn basename(path : String) -> String {
  @path.Path(path).basename().to_string()
}

///|
fn read_dir_entries(path : String) -> Array[String] {
  @fs.read_dir(path) catch {
    _ => []
  }
}

///|
fn is_dir(path : String) -> Bool {
  @fs.is_dir(path) catch {
    _ => false
  }
}

///|
fn is_file(path : String) -> Bool {
  @fs.is_file(path) catch {
    _ => false
  }
}

///|
fn should_skip_dir(path : String) -> Bool {
  let name = basename(path)
  name == ".git" ||
  name == "_build" ||
  name == "target" ||
  name == ".mooncakes" ||
  name == ".moonagent"
}
