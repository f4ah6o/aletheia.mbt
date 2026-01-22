///|
/// PBT markdown sync support.

///|
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
