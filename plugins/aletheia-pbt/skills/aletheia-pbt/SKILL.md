---
name: aletheia-pbt
description: Apply Aletheia to generate and sync property-based tests for any MoonBit module. Use when asked to add or update .pbt.mbt.md templates and per-package tests.
---

# Aletheia PBT

## Overview

Apply Aletheia to a target MoonBit module or package to generate .pbt.mbt.md templates and sync them into per-package tests.

## Workflow

### Phase 1: Analyze and Generate

**1. Choose a target path**
   - Use a module root (contains moon.mod.json) or a package directory (contains moon.pkg or moon.pkg.json).

**2. Analyze patterns (optional)**
   ```bash
   moon run src/aletheia -- analyze <path> --explain
   ```
   This shows detected patterns (Round-Trip, Idempotent, Producer-Consumer) with explanations.

**3. Generate templates**
   ```bash
   moon run src/aletheia -- generate <path>
   ```
   Options:
   - `--dry-run --format json` - Preview changes without writing
   - `--format markdown` - Output markdown format (default)

   Output: `<module>.pbt.mbt.md` in the target root (derived from moon.mod.json).

### Phase 2: Refine Templates

**1. Review generated markdown**
   - Check that detected patterns make sense
   - Verify function signatures are correct

**2. Edit property definitions**
   - Keep manual edits outside `<!-- aletheia:begin -->` / `<!-- aletheia:end -->` markers
   - Leave code blocks as `mbt nocheck` until properties are validated
   - Switch to `mbt check` after verifying semantics

**3. Add custom fixtures and test data**
   - Add realistic test cases for your domain
   - Include edge cases and corner cases

### Phase 3: Sync Tests

**Run sync to generate test files:**
```bash
moon run src/aletheia -- sync [path]
```
Defaults to `<source>/<module>.pbt.mbt.md` if path not specified.

This creates:
- `<package>/pbt_generated_test.mbt` files for each package
- Tests are marked as `test` and `inspect` based on your markdown

### Phase 4: Verify

**1. Check project status:**
```bash
moon info
```
Review interface changes (.mbti files).

**2. Format code:**
```bash
moon fmt
```

**3. Run tests:**
```bash
moon test
```
Or update snapshots if needed:
```bash
moon test --update
```

## Common Issues and Troubleshooting

### 1. Package Format Compatibility

**Issue**: Sync tool may not find package files.

**Supported formats**:
- `moon.pkg` (new format, MoonBit v0.7.1+)
- `moon.pkg.json` (legacy format)

The sync tool automatically checks for both formats.

### 2. Blackbox Test Limitations

**Issue**: Generated tests run as blackbox tests, which cannot access:
- Internal types or constructors
- Functions without `pub` qualifier
- Private enum variants

**Workarounds**:
1. Use fully-qualified public API calls (e.g., `@module.function()`)
2. Test round-trip behavior through public interfaces only
3. Avoid direct construction of internal types
4. Focus on observable behavior rather than internal state

### 3. Type Inference Issues

**Issue**: Generated code may have incorrect types for generic functions.

**Solutions**:
- Manually specify type parameters in the markdown
- Add explicit type annotations to generated tests
- Use `mbt nocheck` until types are verified

### 4. Debugging Test Failures

**When tests fail:**

1. **Identify the failing package**:
   ```bash
   moon test 2>&1 | grep "failed:"
   ```

2. **Check the generated test file**:
   - Look at `<package>/pbt_generated_test.mbt`
   - Verify sync correctly transferred the markdown test

3. **Verify markdown syntax**:
   - Ensure `## Package: <name>` header exists
   - Check code blocks use ` ```mbt check ` or ` ```mbt nocheck `

4. **Common errors**:
   - "Cannot create values of the read-only type" - Trying to use internal types
   - "The value identifier X is unbound" - Missing import or internal name
   - "has no field X" - API changed, update test accordingly

## Best Practices

### Test Organization

**Consolidated approach** (recommended for large modules):
- Single `<module>.pbt.mbt.md` at module root
- Contains all package tests in one file
- Use `## Package: <name>` headers to separate packages

**Distributed approach** (for small modules):
- One `.pbt.mbt.md` per package
- Easier to navigate for focused changes

### Property Template Guidelines

When writing property tests in markdown:

1. **Use `mbt nocheck`** for templates that need manual verification
2. **Use `mbt check`** for complete, validated tests
3. **Prefix test names** with `prop_` for clarity
4. **Document properties** being tested (round-trip, idempotent, etc.)

Example:
````markdown
### prop_parse_command_roundtrip

Round-trip property: parsing and generating commands preserves data.

```mbt check
test "prop_parse_command_roundtrip" {
  let commands = [
    ["analyze", "./src"],
    ["generate", "./src", "--format", "json"],
  ]
  for cmd in commands {
    let parsed = @aletheia.parse_command(cmd)
    let generated = @aletheia.command_to_args(parsed)
    assert_eq(generated, cmd)
  }
}
```
````

### Iterative Development

1. **Start with `mbt nocheck`** - Get tests compiling without validation
2. **Fix type errors** - Ensure all types match
3. **Switch to `mbt check`** - Enable semantic checks
4. **Add assertions** - Verify properties hold
5. **Run `moon test`** - Validate tests pass
6. **Refine fixtures** - Add more realistic test cases

### Preserving Manual Edits

The sync tool preserves:
- Content outside `<!-- aletheia:begin -->` / `<!-- aletheia:end -->`
- Manual edits to test logic
- Custom fixtures and test data

It regenerates:
- Content between markers (based on latest source analysis)
- Package structure and test scaffolding
