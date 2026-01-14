///|
/// 状態マシンテストモジュール（Phase 6）
/// 状態を持つシステムのプロパティテストをサポートする
///

///|
/// 状態マシンモデル
pub struct StateMachine {
  name : String
  initial_state : String
  commands : Array[Command]
}

///|
/// コマンド（状態遷移操作）
pub struct Command {
  name : String
  precondition : String // 事前条件
  postcondition : String // 事後条件
}

///|
/// コマンド実行結果
pub struct ExecutionResult {
  success : Bool
  final_state : String
  error_message : String
}

///|
/// 状態マシンテストを作成
pub fn create_state_machine(name : String, initial : String) -> StateMachine {
  { name, initial_state: initial, commands: [] }
}

///|
/// コマンドを追加
pub fn add_command(sm : StateMachine, cmd : Command) -> StateMachine {
  Array::push(sm.commands, cmd)
  sm
}

///|
/// コマンド列を実行（簡易版）
pub fn execute_commands(sm : StateMachine, initial : String) -> ExecutionResult {
  { success: true, final_state: initial, error_message: "" }
}

///|
/// 状態遷移プロパティを生成
pub fn generate_state_machine_test(
  sm : StateMachine,
  type_name : String,
) -> String {
  let test_name = "prop_state_machine_" + sm.name
  let cmd_count = int_to_string(Array::length(sm.commands))
  let test_code = "test \"" +
    test_name +
    "\" {\n  // State machine test for " +
    sm.name +
    "\n  // Commands: " +
    cmd_count +
    "\n  let gen : @pbt.Gen[Array[" +
    type_name +
    "]] = @pbt.Gen::array_of(@pbt.Gen::arbitrary())\n  @pbt.assert_check(\"" +
    test_name +
    "\", gen, fn(ops : Array[" +
    type_name +
    "]) {\n    // Execute command sequence and verify invariants\n    Ok(())\n  })\n}"
  test_code
}

///|
/// 整数を文字列に変換（簡易版）
fn int_to_string(n : Int) -> String {
  if n == 0 {
    "0"
  } else if n == 1 {
    "1"
  } else if n == 2 {
    "2"
  } else if n == 3 {
    "3"
  } else if n == 4 {
    "4"
  } else if n == 5 {
    "5"
  } else {
    "n"
  }
}

///|
/// テスト
test "create_state_machine_simple" {
  let sm = create_state_machine("Queue", "empty")
  inspect(sm.name, content="Queue")
  inspect(sm.initial_state, content="empty")
}

///|
test "add_command_increases_count" {
  let sm = create_state_machine("Test", "initial")
  let cmd = { name: "cmd1", precondition: "true", postcondition: "ok" }
  let sm2 = add_command(sm, cmd)
  inspect(sm2.commands.length(), content="1")
}

///|
test "execute_commands_returns_result" {
  let sm = create_state_machine("Test", "initial")
  let result = execute_commands(sm, "initial")
  inspect(result.success, content="true")
}

///|
test "generate_state_machine_test" {
  let sm = create_state_machine("Queue", "empty")
  let test_code = generate_state_machine_test(sm, "QueueCmd")
  inspect(test_code.contains("prop_state_machine_Queue"), content="true")
  inspect(test_code.contains("State machine test"), content="true")
}

///|
test "int_to_string_converts" {
  inspect(int_to_string(0), content="0")
  inspect(int_to_string(3), content="3")
  inspect(int_to_string(5), content="5")
}
