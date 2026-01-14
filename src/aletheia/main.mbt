///|
/// Aletheia CLI エントリポイント
///

fn main {
  // TODO: CLI引数処理は後で実装（sysモジュールの調査が必要）
  // 簡易版: ヘルプメッセージを表示
  let result = @cli.help_message()
  println(result)
}
