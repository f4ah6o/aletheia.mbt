///|
/// コマンドを実行
pub fn run_command(cmd : Command) -> String {
  match cmd {
    Analyze(path, options) => run_analyze(path, options)
    Generate(path, options) => run_generate(path, options)
    Sync(path, options) => run_sync(path, options)
    Help => help_message()
  }
}

///|
fn run_analyze(path : String, options : CommandOptions) -> String {
  let packages = analyze_packages(path)
  match options.format {
    Text =>
      "Analyzing: " +
      path +
      "\n" +
      format_analysis_text(path, packages, options.explain)
    Json => format_analysis_json(path, packages, options.explain)
  }
}

///|
fn run_generate(path : String, options : CommandOptions) -> String {
  let prefix = "Collecting PBT targets for: " + path + "\n"
  match build_per_package_reports(path, options) {
    Err(msg) =>
      match options.format {
        Text => prefix + "No MoonBit package found under: " + path + "\n"
        Json =>
          json_object([
            ("ok", json_bool(false)),
            ("command", json_string("generate")),
            ("path", json_string(path)),
            ("error", json_string(msg)),
          ])
      }
    Ok((reports, skipped)) =>
      match options.format {
        Text => {
          let mut result = prefix
          if reports.length() == 0 {
            result = result + "No PBT targets detected.\n"
          } else {
            result = result +
              format_generate_reports_text(reports, options.explain)
          }
          if options.explain && skipped.length() > 0 {
            result = result + "\n" + format_skipped_reports_text(skipped)
          }
          result
        }
        Json =>
          if options.explain {
            format_generate_reports_json_with_skipped(reports, skipped, true)
          } else {
            format_generate_reports_json(reports, false)
          }
      }
  }
}

///|
fn run_sync(path : String, options : CommandOptions) -> String {
  match options.format {
    Text =>
      "Syncing PBT markdown: " +
      path +
      "\n" +
      format_sync_text(path, options.dry_run)
    Json => format_sync_json(path, options.dry_run)
  }
}
