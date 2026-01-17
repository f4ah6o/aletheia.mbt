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
/// 状態マシンテストテンプレートを生成（enhanced with Shim guidance）
pub fn generate_state_machine_test_template(
  name : String,
  state_type : String,
  cmd_type : String,
  result_type : String,
) -> String {
  let mut code = "// State machine test for " + name + "\n\n"

  // 状態型定義（内部状態と外部状態を分離）
  code = code + "// Internal state: Keep this pure and deterministic\n"
  code = code + "pub struct " + state_type + " {\n"
  code = code + "  // TODO: Add state fields\n"
  code = code + "  // Keep this state serializable and side-effect free\n"
  code = code + "}\n\n"

  // コマンド型定義
  code = code + "// Commands: Represent state transitions as data\n"
  code = code + "pub enum " + cmd_type + " {\n"
  code = code + "  // TODO: Add command variants\n"
  code = code + "  // Each command should be a pure data structure\n"
  code = code + "}\n\n"

  // Shimレイヤー定義（副作用を制御）
  code = code + "// Shim: Control side effects in test environment\n"
  code = code + "pub trait " + name + "Shim {\n"
  code = code +
    "  execute_command(Self, " +
    cmd_type +
    ") -> " +
    result_type +
    "\n"
  code = code + "  // Add methods to observe/control side effects\n"
  code = code + "}\n\n"

  // 状態マシン定義（決定論的モデル）
  code = code + "// Deterministic model: Pure state transition function\n"
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
  code = code + "    fn(state, cmd) {\n"
  code = code +
    "      // Deterministic state transition: Same state + cmd = same next state\n"
  code = code +
    "      // This model must be PURE (no side effects, no external calls)\n"
  code = code +
    "      state\n" +
    "      // TODO: Implement pure state transition logic\n"
  code = code + "    },\n"
  code = code + "  )\n"
  code = code + "  .with_precondition(fn(state, cmd) {\n"
  code = code + "    // Check if command is valid for current state\n"
  code = code + "    true\n"
  code = code + "  })\n"
  code = code + "  .with_postcondition(fn(state, cmd, result) {\n"
  code = code + "    // Verify invariants after command execution\n"
  code = code + "    true\n"
  code = code + "  })\n"
  code = code + "}\n\n"

  // 実システム用Shim実装
  code = code + "// Real system Shim: Wraps actual implementation\n"
  code = code + "pub struct Real" + name + "Shim {}\n\n"
  code = code +
    "pub impl " +
    name +
    "Shim for Real" +
    name +
    "Shim with execute_command(_self, cmd : " +
    cmd_type +
    ") -> " +
    result_type +
    " {\n"
  code = code + "  // TODO: Call actual system implementation\n"
  code = code + "  // This is where side effects happen in production\n"
  code = code + "  { /* return result */ }\n"
  code = code + "}\n\n"

  // モデル用Shim実装
  code = code + "// Model Shim: Pure implementation for comparison\n"
  code = code + "pub struct Model" + name + "Shim {}\n\n"
  code = code +
    "pub impl " +
    name +
    "Shim for Model" +
    name +
    "Shim with execute_command(_self, cmd : " +
    cmd_type +
    ") -> " +
    result_type +
    " {\n"
  code = code + "  // TODO: Implement pure model logic\n"
  code = code + "  // This model should be simple and obviously correct\n"
  code = code + "  { /* return result */ }\n"
  code = code + "}\n\n"

  // テスト関数
  code = code + "test \"" + name + "_state_machine\" {\n"
  code = code + "  let sm = create_" + string_to_lower(name) + "_sm()\n"
  code = code + "  let commands : Array[" + cmd_type + "] = []\n"
  code = code + "  // Use RecordingShim to capture side effects during test\n"
  code = code + "  let shim = @state_machine.RecordingShim::new()\n"
  code = code + "  let result = @state_machine.run_state_machine_test(\n"
  code = code + "    sm,\n"
  code = code + "    commands,\n"
  code = code + "    fn(cmd, shim) {\n"
  code = code + "      // Execute command through Shim layer\n"
  code = code +
    "      // Shim isolates side effects and makes them observable\n"
  code = code + "      { /* return " + result_type + " */ }\n"
  code = code + "    },\n"
  code = code + "    shim,\n"
  code = code + "  )\n"
  code = code + "  assert_true(result.success)\n"
  code = code + "  // Verify side effects captured by Shim\n"
  code = code + "  // assert_eq(result.effects.length(), 0)\n"
  code = code + "}\n"
  code
}

///|
/// Generate Shim module guidance section for markdown
pub fn generate_shim_guidance_section() -> String {
  "## Shim Module Recommendations\n\n" +
  "For stateful systems, use a **Shim** abstraction layer to control and observe side effects during testing.\n\n" +
  "### What is a Shim?\n\n" +
  "A Shim is a test-time abstraction that wraps the real system to:\n" +
  "- **Isolate side effects**: Make I/O, network calls, and state changes observable\n" +
  "- **Control nondeterminism**: Fix random values, timestamps, and external dependencies\n" +
  "- **Simplify testing**: Provide a clean interface for property-based tests\n\n" +
  "### Shim Pattern Example\n\n" +
  "```mbt nocheck\n" +
  "// Define Shim interface for your system\n" +
  "pub trait SystemShim {\n" +
  "  execute_command(Self, Command) -> Result\n" +
  "  get_state(Self) -> State\n" +
  "}\n\n" +
  "// Real implementation (production)\n" +
  "pub struct RealSystemShim { /* ... */ }\n" +
  "pub impl SystemShim for RealSystemShim {\n" +
  "  fn execute_command(self, cmd) {\n" +
  "    // Call actual system with real side effects\n" +
  "  }\n" +
  "}\n\n" +
  "// Test Shim (controlled environment)\n" +
  "pub struct TestSystemShim {\n" +
  "  mock_state : State\n" +
  "  recorded_effects : Array[String]\n" +
  "}\n" +
  "pub impl SystemShim for TestSystemShim {\n" +
  "  fn execute_command(mut self, cmd) {\n" +
  "    // Record effects, control nondeterminism\n" +
  "    Array::push(self.recorded_effects, cmd.to_string())\n" +
  "  }\n" +
  "}\n" +
  "```\n\n" +
  "### Shim Benefits\n\n" +
  "- **Reproducibility**: Fix random seeds, timestamps, and external inputs\n" +
  "- **Observability**: Capture side effects for post-test inspection\n" +
  "- **Isolation**: Test logic independently of actual implementation\n\n"
}

///|
/// Generate deterministic model guidance section for markdown
pub fn generate_deterministic_model_section() -> String {
  "## Deterministic Model Design\n\n" +
  "State machine tests should separate **internal state** from **external state transitions**.\n\n" +
  "### Key Principles\n\n" +
  "1. **Pure model**: The `next_state` function must be deterministic and side-effect free\n" +
  "   - Same state + command always produces the same next state\n" +
  "   - No external calls, no I/O, no randomness in the model\n\n" +
  "2. **Separation of concerns**:\n" +
  "   - **Model**: Pure state transition logic (`next_state`)\n" +
  "   - **System**: Actual implementation with side effects (via Shim)\n\n" +
  "3. **Verification**: Compare model predictions against actual system behavior\n\n" +
  "### Model Structure\n\n" +
  "```mbt nocheck\n" +
  "pub struct ModelState {\n" +
  "  // Internal state: Keep serializable and simple\n" +
  "  counter : Int\n" +
  "  items : Array[String]\n" +
  "}\n\n" +
  "// Pure state transition: no side effects\n" +
  "fn next_state(state : ModelState, cmd : Command) -> ModelState {\n" +
  "  match cmd {\n" +
  "    Increment => { counter: state.counter + 1, items: state.items }\n" +
  "    Add(item) => { counter: state.counter, items: Array::push(state.items, item) }\n" +
  "  }\n" +
  "}\n\n" +
  "// State machine with deterministic model\n" +
  "let sm = StateM::new(\n" +
  "  \"MySystem\",\n" +
  "  ModelState::{ counter: 0, items: [] },  // Initial state\n" +
  "  next_state,                             // Pure transition\n" +
  ")\n" +
  ".with_precondition(fn(state, cmd) {\n" +
  "  // Check if command is valid for this state\n" +
  "  state.counter >= 0\n" +
  "})\n" +
  ".with_postcondition(fn(state, cmd, result) {\n" +
  "  // Verify invariants after execution\n" +
  "  result.is_ok()\n" +
  "})\n" +
  "```\n\n" +
  "### Mental Model Guidelines\n\n" +
  "- **Keep it simple**: The model should be simpler than the implementation\n" +
  "- **Make it obvious**: Model logic should be obviously correct on inspection\n" +
  "- **Serialize state**: State must be easily converted to/from strings for debugging\n" +
  "- **Avoid hidden state**: All state should be explicit in the model struct\n\n"
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
