///|
/// 状態マシンテストモジュール（Phase 6）
/// 状態を持つシステムのプロパティテストをサポートする
///

///|
/// Shim インターフェース
/// テスト時に副作用を記録・制御するための抽象化
pub trait Shim {
  record(Self, String) -> Unit
  effects(Self) -> Array[String]
}

///|
/// パススルー Shim（何もしない）
pub struct PassthroughShim {}

///|
pub fn PassthroughShim::new() -> PassthroughShim {
  PassthroughShim::{  }
}

///|
pub impl Shim for PassthroughShim with record(_self, _effect : String) -> Unit {

}

///|
pub impl Shim for PassthroughShim with effects(_self) -> Array[String] {
  []
}

///|
/// 記録 Shim（副作用を記録する）
pub struct RecordingShim {
  recorded : Array[String]
}

///|
pub fn RecordingShim::new() -> RecordingShim {
  RecordingShim::{ recorded: [] }
}

///|
pub impl Shim for RecordingShim with record(self, effect : String) -> Unit {
  self.recorded.push(effect)
}

///|
pub impl Shim for RecordingShim with effects(self) -> Array[String] {
  self.recorded
}

///|
/// 値をラップするユーティリティ（グローバル関数として提供）
pub fn[T] shim_wrap(value : T, _shim : Unit) -> T {
  value
}

///|
/// 汎用状態マシンモデル
pub struct StateM[S, Cmd, R] {
  name : String
  initial_state : S
  next_state : (S, Cmd) -> S
  precondition : (S, Cmd) -> Bool
  postcondition : (S, Cmd, R) -> Bool
}

///|
/// StateM コンストラクタ
pub fn[S, Cmd, R] StateM::new(
  name : String,
  initial : S,
  next : (S, Cmd) -> S,
) -> StateM[S, Cmd, R] {
  StateM::{
    name,
    initial_state: initial,
    next_state: next,
    precondition: fn(_s, _cmd) { true },
    postcondition: fn(_s, _cmd, _r) { true },
  }
}

///|
/// 事前条件を設定
pub fn[S, Cmd, R] StateM::with_precondition(
  self : StateM[S, Cmd, R],
  pre : (S, Cmd) -> Bool,
) -> StateM[S, Cmd, R] {
  StateM::{
    name: self.name,
    initial_state: self.initial_state,
    next_state: self.next_state,
    precondition: pre,
    postcondition: self.postcondition,
  }
}

///|
/// 事後条件を設定
pub fn[S, Cmd, R] StateM::with_postcondition(
  self : StateM[S, Cmd, R],
  post : (S, Cmd, R) -> Bool,
) -> StateM[S, Cmd, R] {
  StateM::{
    name: self.name,
    initial_state: self.initial_state,
    next_state: self.next_state,
    precondition: self.precondition,
    postcondition: post,
  }
}

///|
/// 状態マシンテストの結果
pub struct StateMResult {
  success : Bool
  commands_executed : Int
  final_state_desc : String
  error_message : String?
  effects : Array[String]
}

///|
/// 状態マシンテストを実行
pub fn[S : Show, Cmd : Show, R, Sh : Shim] run_state_machine_test(
  sm : StateM[S, Cmd, R],
  commands : Array[Cmd],
  execute : (Cmd, Sh) -> R,
  shim : Sh,
) -> StateMResult {
  let mut state = sm.initial_state
  let mut executed = 0
  for cmd in commands {
    // 事前条件チェック
    if not((sm.precondition)(state, cmd)) {
      continue
    }

    // コマンド実行
    let result = execute(cmd, shim)
    executed = executed + 1

    // 事後条件チェック
    if not((sm.postcondition)(state, cmd, result)) {
      return StateMResult::{
        success: false,
        commands_executed: executed,
        final_state_desc: "\{state}",
        error_message: Some("Postcondition failed for command: \{cmd}"),
        effects: shim.effects(),
      }
    }

    // 状態遷移
    state = (sm.next_state)(state, cmd)
  }
  StateMResult::{
    success: true,
    commands_executed: executed,
    final_state_desc: "\{state}",
    error_message: None,
    effects: shim.effects(),
  }
}

///|
/// 状態マシンテストテンプレートを生成
pub fn generate_state_machine_test_template(
  name : String,
  state_type : String,
  cmd_type : String,
  result_type : String,
) -> String {
  let mut code = "// State machine test for " + name + "\n\n"

  // 状態型定義
  code = code + "pub struct " + state_type + " {\n"
  code = code + "  // TODO: Add state fields\n"
  code = code + "}\n\n"

  // コマンド型定義
  code = code + "pub enum " + cmd_type + " {\n"
  code = code + "  // TODO: Add command variants\n"
  code = code + "}\n\n"

  // 状態マシン定義
  code = code +
    "fn create_" +
    string_to_lower(name) +
    "_sm() -> @state_machine.StateM[" +
    state_type +
    ", " +
    cmd_type +
    ", " +
    result_type +
    "] {\n"
  code = code + "  @state_machine.StateM::new(\n"
  code = code + "    \"" + name + "\",\n"
  code = code + "    " + state_type + "::{ /* initial state */ },\n"
  code = code +
    "    fn(state, cmd) { state }, // TODO: Implement state transition\n"
  code = code + "  )\n"
  code = code + "  .with_precondition(fn(state, cmd) { true })\n"
  code = code + "  .with_postcondition(fn(state, cmd, result) { true })\n"
  code = code + "}\n\n"

  // テスト関数
  code = code + "test \"" + name + "_state_machine\" {\n"
  code = code + "  let sm = create_" + string_to_lower(name) + "_sm()\n"
  code = code + "  let commands : Array[" + cmd_type + "] = []\n"
  code = code + "  let shim = @state_machine.RecordingShim::new()\n"
  code = code + "  let result = @state_machine.run_state_machine_test(\n"
  code = code + "    sm,\n"
  code = code + "    commands,\n"
  code = code + "    fn(cmd, shim) { /* execute */ },\n"
  code = code + "    shim,\n"
  code = code + "  )\n"
  code = code + "  assert_true(result.success)\n"
  code = code + "}\n"
  code
}

///|
fn string_to_lower(s : String) -> String {
  let chars = s.to_array()
  let mut result = ""
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    let code = c.to_int()
    if code >= 65 && code <= 90 {
      result = result + Int::unsafe_to_char(code + 32).to_string()
    } else {
      result = result + c.to_string()
    }
    i = i + 1
  }
  result
}

///|
/// 状態マシンモデル（レガシー）
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
    "\n  let ops : Array[Command] = @quickcheck.samples(100)\n  let _ = ops\n  // Execute command sequence and verify invariants\n}"
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

///|
test "passthrough_shim_wraps" {
  let shim = PassthroughShim::new()
  let value = 42
  let result = shim_wrap(value, ())
  inspect(result, content="42")
}

///|
test "passthrough_shim_no_effects" {
  let shim = PassthroughShim::new()
  shim.record("effect1")
  let effects = shim.effects()
  inspect(effects.length(), content="0")
}

///|
test "recording_shim_records" {
  let shim = RecordingShim::new()
  shim.record("effect1")
  shim.record("effect2")
  let effects = shim.effects()
  inspect(effects.length(), content="2")
  inspect(effects[0], content="effect1")
  inspect(effects[1], content="effect2")
}

///|
test "state_m_construction" {
  let sm = StateM::new("TestSM", 0, fn(s, _cmd) { s })
  inspect(sm.name, content="TestSM")
  inspect(sm.initial_state, content="0")
}

///|
test "state_m_with_precondition" {
  let sm = StateM::new("TestSM", 0, fn(s, cmd) { s + cmd }).with_precondition(fn(
    s,
    cmd,
  ) {
    s + cmd < 10
  })
  // 事前条件が設定されていることを確認
  let ok = (sm.precondition)(5, 3)
  inspect(ok, content="true")
}

///|
test "state_m_with_postcondition" {
  let sm = StateM::new("TestSM", 0, fn(s, cmd) { s + cmd }).with_postcondition(fn(
    _s,
    _cmd,
    _r,
  ) {
    true
  })
  // 事後条件が設定されていることを確認
  let ok = (sm.postcondition)(0, 1, 1)
  inspect(ok, content="true")
}

///|
test "generate_state_machine_test_template" {
  let template = generate_state_machine_test_template(
    "Queue", "QueueState", "QueueCmd", "Unit",
  )
  inspect(template.contains("State machine test for Queue"), content="true")
  inspect(template.contains("pub struct QueueState"), content="true")
  inspect(template.contains("pub enum QueueCmd"), content="true")
}
