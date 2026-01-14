///|
/// Aletheia CLI エントリポイント
///
fn main {
  let args = @sys.get_cli_args()

  // 引数が空の場合はヘルプを表示
  if args.length() < 2 {
    let result = @cli.help_message()
    println(result)
    return
  }

  // コマンドをパースして実行
  let cmd = @cli.parse_args(args)
  let result = @cli.run_command(cmd)
  println(result)
}
