///|
/// PBT markdownを同期
fn format_sync_text(markdown_path : String, dry_run : Bool) -> String {
  if dry_run {
    match @pbt_sync.check_sync(markdown_path) {
      Err(errors) => {
        let mut output = "=== PBT Sync (dry-run) Failed ===\n"
        output = output + errors.join("\n") + "\n"
        output
      }
      Ok(_) => {
        let mut output = "=== PBT Sync (dry-run) ===\n"
        output = output + "Markdown: " + markdown_path + "\n"
        output = output + "Status: up to date\n"
        output
      }
    }
  } else {
    sync_targets(markdown_path)
  }
}

///|
fn format_sync_json(markdown_path : String, dry_run : Bool) -> String {
  if dry_run {
    match @pbt_sync.check_sync(markdown_path) {
      Err(errors) =>
        json_object([
          ("ok", json_bool(false)),
          ("command", json_string("sync")),
          ("path", json_string(markdown_path)),
          ("dry_run", json_bool(true)),
          ("errors", json_array(errors.map(json_string))),
        ])
      Ok(_) =>
        json_object([
          ("ok", json_bool(true)),
          ("command", json_string("sync")),
          ("path", json_string(markdown_path)),
          ("dry_run", json_bool(true)),
          ("status", json_string("up_to_date")),
        ])
    }
  } else {
    match @pbt_sync.sync(markdown_path) {
      Err(errors) =>
        json_object([
          ("ok", json_bool(false)),
          ("command", json_string("sync")),
          ("path", json_string(markdown_path)),
          ("dry_run", json_bool(false)),
          ("errors", json_array(errors.map(json_string))),
        ])
      Ok(report) =>
        json_object([
          ("ok", json_bool(true)),
          ("command", json_string("sync")),
          ("path", json_string(markdown_path)),
          ("dry_run", json_bool(false)),
          ("written", json_array(report.written.map(json_string))),
          ("removed", json_array(report.removed.map(json_string))),
          ("unchanged", json_array(report.unchanged.map(json_string))),
        ])
    }
  }
}

///|
fn sync_targets(markdown_path : String) -> String {
  let result = @pbt_sync.sync(markdown_path)
  match result {
    Err(errors) => {
      let mut output = "=== PBT Sync Failed ===\n"
      output = output + errors.join("\n") + "\n"
      output
    }
    Ok(report) => {
      let mut output = "=== PBT Sync ===\n"
      output = output + "Markdown: " + markdown_path + "\n"
      output = output +
        "Written: " +
        int_to_string(report.written.length()) +
        "\n"
      output = output +
        "Removed: " +
        int_to_string(report.removed.length()) +
        "\n"
      output = output +
        "Unchanged: " +
        int_to_string(report.unchanged.length()) +
        "\n"
      output
    }
  }
}
