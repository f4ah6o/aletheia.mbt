---
name: aletheia-pbt
description: Comprehensive workflow guide for applying Aletheia PBT to any MoonBit module, covering pattern analysis, template generation, test synchronization, and debugging best practices.
---

# Aletheia PBT Workflow Guide

## Overview

This guide provides a comprehensive workflow for using Aletheia to add property-based tests (PBT) to any MoonBit module. It covers pattern detection, template generation, test synchronization, and best practices.

## Workflow

### Phase 1: Analyze and Generate Templates

**Step 1: Choose your target**

Identify the MoonBit module or package you want to test:
- **Module root**: Directory containing `moon.mod.json`
- **Package directory**: Directory containing `moon.pkg` or `moon.pkg.json`

**Step 2: Analyze patterns (optional but recommended)**

```bash
moon run src/aletheia -- analyze <target-path> --explain
```

This command:
- Scans source code for PBT patterns
- Detects Round-Trip, Idempotent, and Producer-Consumer relationships
- Provides explanations for each detected pattern
- Outputs summary of findings

**Example output:**
```
Patterns detected in my_module:
- Round-Trip: parse_json <-> generate_json
- Round-Trip: parse_config <-> serialize_config
- Idempotent: normalize_path
- Producer-Consumer: create_state -> process_state
```

**Step 3: Generate templates**

```bash
moon run src/aletheia -- generate <target-path>
```

**Options:**
- `--dry-run` - Preview changes without writing files
- `--format json` - Output as JSON
- `--format markdown` - Output as markdown (default)

**Output:** `<module>.pbt.mbt.md` in the target root

This file contains:
- Auto-generated property test templates
- Function signatures with inferred types
- Placeholder test logic for you to refine

### Phase 2: Refine and Customize Templates

**Step 1: Review generated markdown**

Open the generated `<module>.pbt.mbt.md` and check:
- Are detected patterns accurate?
- Are function signatures correct?
- Do type inferences match your expectations?

**Step 2: Edit property definitions**

Customize tests for your domain:

```markdown
### prop_parse_generate_roundtrip

Round-trip property: parsing then generating preserves original data.

```mbt check
test "prop_parse_generate_roundtrip" {
  let fixtures = [
    "{\"name\":\"test\",\"value\":42}",
    "{\"empty\":true}",
    "{\"nested\":{\"key\":\"value\"}}",
  ]
  for json in fixtures {
    let parsed = @my_module.parse_json(json)
    let regenerated = @my_module.generate_json(parsed)
    assert_eq(regenerated, json)
  }
}
```
```

**Best practices:**
- Keep manual edits **outside** `<!-- aletheia:begin -->` / `<!-- aletheia:end -->` markers
- Use `mbt nocheck` initially while developing tests
- Switch to `mbt check` after verifying semantics
- Add realistic fixtures from your domain
- Include edge cases (empty strings, nulls, special characters)

**Step 3: Add custom test data**

```markdown
// Add domain-specific fixtures
let fixtures = [
  // Normal cases
  create_user("alice", 25),
  create_user("bob", 30),

  // Edge cases
  create_user("", 0),           // empty name, zero age
  create_user("x" * 1000, 150), // very long name

  // Boundary cases
  create_user("max", 999),      // maximum age
]
```

### Phase 3: Sync Tests to Packages

**Generate test files from markdown:**

```bash
moon run src/aletheia -- sync <module>.pbt.mbt.md
```

Or simply:
```bash
moon run src/aletheia -- sync  # Uses default path
```

**What sync does:**
1. Reads markdown file
2. Extracts code blocks from `## Package: <name>` sections
3. Generates `pbt_generated_test.mbt` in each package directory
4. Preserves manual edits outside generated sections

**Output structure:**
```
<target>/
├── moon.mod.json
├── <module>.pbt.mbt.md          # Source markdown
└── src/
    ├── package_a/
    │   ├── package_a.mbt
    │   └── pbt_generated_test.mbt  # Generated tests
    └── package_b/
        ├── package_b.mbt
        └── pbt_generated_test.mbt  # Generated tests
```

### Phase 4: Verify and Debug

**Step 1: Check project interfaces**

```bash
moon info
```

Review interface changes (.mbti files) to ensure:
- New types are recognized
- Function signatures match expectations
- No unexpected interface changes

**Step 2: Format code**

```bash
moon fmt
```

This ensures consistent formatting across generated files.

**Step 3: Run tests**

```bash
moon test
```

**If tests fail:**

1. Identify failing package:
```bash
moon test 2>&1 | grep "failed:"
```

2. Check generated test file:
```bash
cat src/<package>/pbt_generated_test.mbt
```

3. Verify markdown syntax:
- `## Package: <name>` header exists
- Code blocks use ` ```mbt check ` or ` ```mbt nocheck `
- Proper indentation in code blocks

4. Update snapshots if needed:
```bash
moon test --update
```

## Common Issues and Solutions

### 1. Package Format Compatibility

**Issue**: Sync tool reports "Package not found"

**Supported formats:**
- `moon.pkg` (new format, MoonBit v0.7.1+)
- `moon.pkg.json` (legacy format)

**Solution**: The sync tool automatically checks for both formats. Ensure your package directory contains one of these files.

### 2. Blackbox Test Limitations

**Issue**: Tests fail with "Cannot create values of the read-only type" or "Unbound identifier"

**Cause**: Generated tests run as blackbox tests, which cannot access:
- Internal types or constructors
- Functions without `pub` qualifier
- Private enum variants

**Workarounds:**

1. **Use fully-qualified public API calls:**
```moonbit
// Instead of: parse_command(args)
// Use: @cli.parse_command(args)
```

2. **Test through public interfaces only:**
```moonbit
// Test round-trip behavior through public APIs
let result = @public_api.process(input)
let output = @public_api.serialize(result)
assert_eq(output, expected)
```

3. **Avoid direct construction of internal types:**
```moonbit
// Don't do this:
// let cmd = @cli.InternalCommand("analyze")

// Do this instead:
let cmd = @cli.parse_command(["analyze", "./src"])
```

### 3. Type Inference Issues

**Issue**: Generated code has incorrect types for generic functions

**Solutions:**
- Manually specify type parameters in markdown:
```markdown
let result : MyType = @module.function_generic[Int](input)
```

- Add explicit type annotations:
```markdown
let data : List[String] = @module.process(input)
```

- Use `mbt nocheck` until types are verified

### 4. Alias Normalization in Round-Trip Tests

**Issue**: CLI argument parsing normalizes short aliases

**Example:**
- Input: `["tool", "a", "./src"]`
- After round-trip: `["tool", "analyze", "./src"]`

**Solutions:**
1. Exclude alias tests from strict round-trip validation
2. Update test expectations to account for normalization
3. Use full command names in test fixtures

### 5. Sync Not Updating Tests

**Issue**: Changes in markdown don't appear in generated tests

**Solutions:**
1. Ensure changes are between `<!-- aletheia:begin -->` / `<!-- aletheia:end -->`
2. Check that `## Package: <name>` header matches directory name
3. Verify code blocks use correct fence style (` ```mbt check `)
4. Run sync with verbose output to debug

## Best Practices

### Test Organization

**Consolidated Approach** (recommended for large modules):

```markdown
# my_module.pbt.mbt.md

## Package: core
Tests for core package...

## Package: utils
Tests for utils package...

## Package: parser
Tests for parser package...
```

**Advantages:**
- Single file for all tests
- Easier to see patterns across packages
- Better for documenting module-wide properties

**Distributed Approach** (for small modules):

```
src/core/core.pbt.mbt.md
src/utils/utils.pbt.mbt.md
src/parser/parser.pbt.mbt.md
```

**Advantages:**
- Tests close to source code
- Easier for focused changes
- Less merge conflicts

### Property Template Guidelines

**Naming conventions:**
```markdown
// Good: Clear and descriptive
### prop_parse_json_roundtrip
### prop_normalize_idempotent
### prop_encoder_decoder_consistent

// Avoid: Vague names
### test_json
### check_normalize
```

**Documenting properties:**
```markdown
### prop_parse_command_roundtrip

Round-trip property: Parsing command args and generating them back
produces the original argument list.

This ensures:
- Short aliases are normalized correctly
- Flag order doesn't matter
- Default values are handled consistently

```mbt check
...
```
```

**Choosing between mbt check and mbt nocheck:**

| State | Use When | Example |
|-------|----------|---------|
| `mbt nocheck` | Developing new tests, types not finalized | Initial template generation |
| `mbt check` | Tests are complete and verified | Final production tests |

### Iterative Development Workflow

1. **Generate** - Run `generate` to create initial templates
2. **Compile** - Use `mbt nocheck` to get tests compiling
3. **Fix Types** - Correct type inference errors
4. **Add Logic** - Implement property assertions
5. **Validate** - Switch to `mbt check`
6. **Test** - Run `moon test` to verify
7. **Refine** - Add more fixtures and edge cases
8. **Repeat** - Go back to step 2 for improvements

### Preserving Manual Edits

The sync tool uses markers to identify auto-generated content:

```markdown
<!-- aletheia:begin -->
[Auto-generated content - will be overwritten]
<!-- aletheia:end -->

[Manual content - preserved forever]
```

**What's preserved:**
- Custom test logic outside markers
- Manual fixtures and test data
- Documentation and comments
- Your own test cases

**What's regenerated:**
- Content between markers
- Package scaffolding
- Function signatures (updated from source)

## Implementation Notes

### File Structure After Sync

```
my_project/
├── moon.mod.json
├── my_module.pbt.mbt.md          # Edit here
└── src/
    ├── core/
    │   ├── core.mbt              # Your source
    │   └── pbt_generated_test.mbt # Auto-generated (do not edit)
    ├── parser/
    │   ├── parser.mbt            # Your source
    │   └── pbt_generated_test.mbt # Auto-generated (do not edit)
    └── utils/
        ├── utils.mbt             # Your source
        └── pbt_generated_test.mbt # Auto-generated (do not edit)
```

**Important:**
- Edit `.pbt.mbt.md` files, not `pbt_generated_test.mbt`
- Generated files are overwritten on each sync
- Use version control to track changes

### Test Template Structure

```markdown
## Package: <package_name>

### prop_<property_name>

Brief description of what property tests.

```mbt check
test "prop_<property_name>" {
  let fixtures = [
    // Test cases here
  ]
  for input in fixtures {
    // Property assertion here
    assert_eq(@module.function(input), expected)
  }
}
```
```

### Example: Complete Workflow

```bash
# 1. Analyze your module
moon run src/aletheia -- analyze ./my_module --explain

# 2. Generate templates
moon run src/aletheia -- generate ./my_module

# 3. Edit markdown (in my_module.pbt.mbt.md)
vim my_module.pbt.mbt.md

# 4. Sync to generate test files
moon run src/aletheia -- sync my_module.pbt.mbt.md

# 5. Check interfaces
moon info

# 6. Format code
moon fmt

# 7. Run tests
moon test

# 8. Iterate if needed
vim my_module.pbt.mbt.md  # Make changes
moon run src/aletheia -- sync  # Re-sync
moon test  # Verify
```

## Advanced Usage

### Custom Property Patterns

You can add custom property patterns beyond auto-detected ones:

```markdown
### prop_custom_invariant

Custom invariant: After operation X, property Y always holds.

```mbt check
test "prop_custom_invariant" {
  let states = generate_random_states(100)
  for state in states {
    let result = @module.process(state)
    assert invariant_holds(result)
  }
}
```
```

### Integration with Existing Tests

Generated tests coexist with hand-written tests:

```
src/core/
├── core_test.mbt              # Hand-written unit tests
└── pbt_generated_test.mbt     # Generated property tests
```

Both are run by `moon test`.

### Continuous Integration

Add to your CI pipeline:

```yaml
- name: Run PBT
  run: |
    moon run src/aletheia -- sync
    moon test
```

This ensures:
- Tests stay in sync with code changes
- Properties are continuously validated
- Regressions are caught early
