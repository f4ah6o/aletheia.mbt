///|
/// Oracleテンプレート生成モジュール（Phase 2 Enhanced Oracle Templates）
/// 実装と参照実装の比較パターンに対するガイダンスを提供する
///

///|
/// Oracleテストタイプ
#warnings("-unused_constructor")
pub enum OracleTestType {
  SameOutputOracle
  PropertyOracle
  InverseOracle
  StateOracle
}

///|
/// Oracleテストテンプレート構造体
pub struct OracleTestTemplate {
  name : String
  implementation : String
  oracle : String
  comparison_strategy : String
  guidance : String
  examples : Array[String]
}

///|
/// Generate Oracle test with implementation guidance
pub fn generate_oracle_test_with_guidance(
  implementation : String,
  oracle : String,
  type_name : String,
) -> OracleTestTemplate {
  let test_name = "prop_" + implementation + "_vs_" + oracle + "_oracle"
  let comparison_strategy = determine_comparison_strategy(
    implementation, oracle,
  )
  let guidance = generate_oracle_guidance(
    implementation, oracle, comparison_strategy,
  )
  let examples = generate_oracle_examples(implementation, oracle, type_name)
  {
    name: test_name,
    implementation,
    oracle,
    comparison_strategy,
    guidance,
    examples,
  }
}

///|
/// Determine the best comparison strategy for the oracle pair
fn determine_comparison_strategy(
  implementation : String,
  _oracle : String,
) -> String {
  // Based on naming patterns, suggest comparison strategy
  if has_prefix_str(implementation, "my_") ||
    has_prefix_str(implementation, "custom_") {
    "direct_comparison"
  } else if contains_str(implementation, "sort") {
    "ordered_comparison"
  } else if contains_str(implementation, "optimize") ||
    contains_str(implementation, "fast") {
    "equivalence_comparison"
  } else {
    "direct_comparison"
  }
}

///|
/// Generate detailed guidance for implementing Oracle tests
fn generate_oracle_guidance(
  _implementation : String,
  _oracle : String,
  strategy : String,
) -> String {
  let mut result = "## Oracle Test Guidance\n\n"
  result = result + "### Comparison Strategy: " + strategy + "\n\n"
  let strategy_desc = match strategy {
    "direct_comparison" =>
      "Direct comparison checks that both implementations produce identical outputs.\n\n" +
      "**When to use:**\n" +
      "- Comparing custom implementation with standard library\n" +
      "- Verifying optimized version against simple reference\n" +
      "- Testing refactor preserves behavior\n\n" +
      "**Guidance:**\n" +
      "- Ensure both functions have identical input types\n" +
      "- Use assert_eq for exact value comparison\n" +
      "- For floating point, consider approximate comparison\n" +
      "- Test with edge cases: empty, single element, boundary values\n"
    "ordered_comparison" =>
      "Ordered comparison checks that outputs contain same elements regardless of order.\n\n" +
      "**When to use:**\n" +
      "- Comparing sorting algorithms\n" +
      "- Testing set-like operations\n" +
      "- Verifying order-independent transformations\n\n" +
      "**Guidance:**\n" +
      "- Sort both outputs before comparing\n" +
      "- Or use multiset comparison (count each element)\n" +
      "- For arrays: compare length, then compare sorted versions\n" +
      "- Consider handling duplicates correctly\n"
    "equivalence_comparison" =>
      "Equivalence comparison checks functional equivalence with possible performance differences.\n\n" +
      "**When to use:**\n" +
      "- Comparing optimized vs simple implementations\n" +
      "- Testing different algorithms with same semantics\n" +
      "- Verifying parallel vs sequential versions\n\n" +
      "**Guidance:**\n" +
      "- Focus on semantic equivalence, not performance\n" +
      "- Test with various input distributions\n" +
      "- Verify error handling matches\n" +
      "- Check that invariants are preserved\n"
    _ => "Standard comparison strategy\n"
  }
  result = result + strategy_desc
  result = result + "\n### Mismatch Classification\n\n"
  result = result +
    "When tests fail, classify the mismatch to understand the root cause:\n\n"
  result = result +
    "- **Edge case difference**: Only fails on boundary values\n"
  result = result +
    "- **Algorithm difference**: Different approach leads to different results\n"
  result = result +
    "- **Error handling difference**: One version fails, other succeeds\n"
  result = result + "- **Performance edge case**: Timeout or excessive memory\n"
  result = result +
    "- **Floating point precision**: Numerical differences within epsilon\n\n"
  result = result + "### Debugging Steps\n\n"
  result = result +
    "1. **Identify the failing input**: Record the counterexample\n"
  result = result +
    "2. **Compare outputs step-by-step**: Print intermediate values\n"
  result = result +
    "3. **Check assumptions**: Verify both implementations handle edge cases\n"
  result = result +
    "4. **Add unit tests**: Convert counterexample to unit test for both\n"
  result = result + "5. **Verify the fix**: Ensure both pass the unit test\n\n"
  result = result + "### Common Pitfalls\n\n"
  result = result +
    "- **Different error handling**: One returns Option, other throws\n"
  result = result +
    "- **Side effects**: Functions modify global state or have I/O\n"
  result = result +
    "- **Non-determinism**: Randomness, time-based, or concurrent behavior\n"
  result = result + "- **Floating point**: Accumulated rounding errors\n"
  result = result +
    "- **Undefined behavior**: Relying on implementation details\n\n"
  result
}

///|
/// Generate examples for Oracle tests
fn generate_oracle_examples(
  implementation : String,
  oracle : String,
  type_name : String,
) -> Array[String] {
  let examples : Array[String] = []

  // Basic example
  let ex1 = "```mbt nocheck\n" +
    "test \"" +
    implementation +
    "_vs_" +
    oracle +
    "\" {\n" +
    "  let gen = @pbt.frequency([\n" +
    "    (70, @pbt.Gen::arbitrary()),\n" +
    "    (20, @pbt.Gen::pure(default_value())),\n" +
    "    (10, @pbt.Gen::pure(boundary_value()))\n" +
    "  ])\n" +
    "  let config = @pbt.CheckConfig::new(cases=100, max_size=30, seed=42)\n" +
    "  let result = @pbt.check_with_stats(gen, fn(x : " +
    type_name +
    ") {\n" +
    "    let impl_result = " +
    implementation +
    "(x)\n" +
    "    let oracle_result = " +
    oracle +
    "(x)\n" +
    "    assert_eq(impl_result, oracle_result)\n" +
    "    (Ok(()), Some(\"comparison\"))\n" +
    "  }, config~)\n" +
    "  assert_true(result.passed)\n" +
    "}\n" +
    "```"
  examples.push(ex1)

  // Property-based example with classification
  let ex2 = "```mbt nocheck\n" +
    "test \"" +
    implementation +
    "_property_vs_" +
    oracle +
    "\" {\n" +
    "  let gen = @pbt.frequency([\n" +
    "    (70, @pbt.Gen::arbitrary()),\n" +
    "    (15, @pbt.Gen::pure([])),\n" +
    "    (15, @pbt.Gen::array_of(@pbt.Gen::constant(" +
    type_name +
    "::default())))\n" +
    "  ])\n" +
    "  let config = @pbt.CheckConfig::new(cases=100, max_size=30, seed=42)\n" +
    "  let result = @pbt.check_with_stats(gen, fn(x : " +
    type_name +
    ") {\n" +
    "    let impl_result = " +
    implementation +
    "(x)\n" +
    "    let oracle_result = " +
    oracle +
    "(x)\n" +
    "    let label = if impl_result == oracle_result {\n" +
    "      Some(\"match\")\n" +
    "    } else {\n" +
    "      Some(\"mismatch\")\n" +
    "    }\n" +
    "    assert_eq(impl_result, oracle_result)\n" +
    "    (Ok(()), label)\n" +
    "  }, config~)\n" +
    "  assert_true(result.passed)\n" +
    "}\n" +
    "```"
  examples.push(ex2)
  examples
}

///|
/// Generate Oracle test markdown section
pub fn generate_oracle_guidance_section() -> String {
  "## Oracle Pattern Testing Guide\n\n" +
  "Oracle tests compare your implementation against a trusted reference implementation.\n\n" +
  "### When to Use Oracle Tests\n\n" +
  "- **Custom implementations**: Compare against standard library\n" +
  "- **Optimized versions**: Verify faster code preserves behavior\n" +
  "- **Refactoring**: Ensure new implementation produces same results\n" +
  "- **Algorithm alternatives**: Test different approaches agree\n\n" +
  "### Choosing the Right Oracle\n\n" +
  "1. **Simple and trusted**: Use the clearest, most obviously correct implementation\n" +
  "2. **Well-tested**: Prefer standard library or widely-verified code\n" +
  "3. **Similar behavior**: Handle same inputs and produce comparable outputs\n" +
  "4. **No dependencies**: Avoid circular dependencies between implementations\n\n" +
  "### Comparison Strategies\n\n" +
  "#### Direct Comparison\n" +
  "```mbt nocheck\n" +
  "assert_eq(my_implementation(x), reference_implementation(x))\n" +
  "```\n" +
  "Use when: Both implementations return exactly the same type\n\n" +
  "#### Property Comparison\n" +
  "```mbt nocheck\n" +
  "// Compare results using a property\n" +
  "assert_eq(my_sort(xs).length(), reference_sort(xs).length())\n" +
  "assert_eq(sort(my_sort(xs)), sort(reference_sort(xs)))\n" +
  "```\n" +
  "Use when: Results differ in form but have equivalent properties\n\n" +
  "#### Inverse Verification\n" +
  "```mbt nocheck\n" +
  "// Verify f and g are inverses\n" +
  "assert_eq(g(f(x)), x)\n" +
  "assert_eq(f(g(y)), y)\n" +
  "```\n" +
  "Use when: Two functions are inverse operations\n\n" +
  "### Common Patterns\n\n" +
  "#### Sorting Algorithm Oracle\n" +
  "- Verify sorted output has same elements as input\n" +
  "- Check ordering property (each element <= next)\n" +
  "- Test stability (preserve relative order of equal elements)\n\n" +
  "#### Data Structure Oracle\n" +
  "- Compare with simple but slow implementation\n" +
  "- Verify invariants (size, depth, balance)\n" +
  "- Check iteration order matches\n\n" +
  "### Handling Differences\n\n" +
  "If oracle tests reveal legitimate differences:\n" +
  "- Document the expected difference\n" +
  "- Create a comparison function that accounts for it\n" +
  "- Add tests for both implementations separately\n" +
  "- Consider if the difference is a bug or feature\n\n" +
  "### Best Practices\n\n" +
  "- **Test both directions**: Verify impl vs oracle and oracle vs impl\n" +
  "- **Use same generators**: Both implementations get identical inputs\n" +
  "- **Fix seeds for failures**: Reproduce mismatches consistently\n" +
  "- **Document assumptions**: Clearly state when implementations may differ\n" +
  "- **Keep oracle simple**: Complexity defeats the purpose of having a reference\n\n"
}

///|
/// String utility functions
fn has_prefix_str(s : String, prefix : String) -> Bool {
  if s.length() < prefix.length() {
    false
  } else {
    let self_chars = s.to_array()
    let prefix_chars = prefix.to_array()
    let mut i = 0
    let mut result = true
    while i < prefix.length() {
      if self_chars[i] != prefix_chars[i] {
        result = false
      }
      i = i + 1
    }
    result
  }
}

///|
fn contains_str(s : String, pattern : String) -> Bool {
  let self_len = s.length()
  let pat_len = pattern.length()
  if self_len < pat_len {
    false
  } else if pat_len == 0 {
    true
  } else {
    let mut i = 0
    while i <= self_len - pat_len {
      let mut j = 0
      let mut found = true
      while j < pat_len {
        let self_chars = s.to_array()
        let pat_chars = pattern.to_array()
        if self_chars[i + j] != pat_chars[j] {
          found = false
        }
        j = j + 1
      }
      if found {
        return true
      }
      i = i + 1
    }
    false
  }
}

///|
/// Tests
test "generate_oracle_test_with_guidance_structure" {
  let template = generate_oracle_test_with_guidance(
    "my_sort", "sort", "Array[Int]",
  )
  inspect(template.name, content="prop_my_sort_vs_sort_oracle")
  inspect(template.implementation, content="my_sort")
  inspect(template.oracle, content="sort")
  inspect(template.guidance.length() > 0, content="true")
  inspect(template.examples.length() > 0, content="true")
}

///|
test "determine_comparison_strategy_custom" {
  let strategy1 = determine_comparison_strategy("my_sort", "sort")
  inspect(strategy1, content="direct_comparison")
  let strategy2 = determine_comparison_strategy("custom_sort", "std_sort")
  inspect(strategy2, content="direct_comparison")
  let strategy3 = determine_comparison_strategy("quick_sort", "merge_sort")
  inspect(strategy3, content="ordered_comparison")
}

///|
test "generate_oracle_guidance_contains_key_sections" {
  let guidance = generate_oracle_guidance(
    "my_sort", "sort", "direct_comparison",
  )
  inspect(guidance.contains("Comparison Strategy"), content="true")
  inspect(guidance.contains("Mismatch Classification"), content="true")
  inspect(guidance.contains("Debugging Steps"), content="true")
  inspect(guidance.contains("Common Pitfalls"), content="true")
}

///|
test "generate_oracle_examples_structure" {
  let examples = generate_oracle_examples("my_sort", "sort", "Array[Int]")
  inspect(examples.length(), content="2")
  inspect(examples[0].contains("@pbt.check_with_stats"), content="true")
  inspect(examples[0].contains("assert_eq"), content="true")
}

///|
test "generate_oracle_guidance_section_comprehensive" {
  let section = generate_oracle_guidance_section()
  inspect(section.contains("When to Use Oracle Tests"), content="true")
  inspect(section.contains("Choosing the Right Oracle"), content="true")
  inspect(section.contains("Comparison Strategies"), content="true")
  inspect(section.contains("Best Practices"), content="true")
}
