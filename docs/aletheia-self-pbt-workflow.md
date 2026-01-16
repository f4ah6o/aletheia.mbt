---
name: aletheia-self-pbt
description: Self-dogfooding workflow for the f4ah6o/aletheia.mbt MoonBit repo, covering PBT generation, template updates, and validation with moon tools. Use when modifying the analyzer/patterns/generator/cli pipeline or regenerating this repo's .pbt.mbt.md files.
---

# Aletheia Self PBT

## Overview

Generate or sync Aletheia's own PBT templates, then iterate on detection and templates until they are mbt check ready.

## Workflow

### Phase 1: Generate or sync PBT templates

**Recommended approach: Full regenerate**
```bash
./scripts/self_pbt.sh
```

This script runs:
- `moon run src/aletheia -- generate ./src` - PBTターゲット収集
- `moon run src/aletheia -- sync` - テスト同期
- `moon info` - プロジェクト情報表示
- `moon fmt` - コード自動整形

**Alternative: Sync existing files**
```bash
moon run src/aletheia -- sync ./src
```

### Phase 2: Review generated files

**Best Practice: Consolidated Test Organization**

- **Primary file**: `src/aletheia.pbt.mbt.md` - Contains ALL package tests
- **Per-package files**: `src/<pkg>/<pkg>.pbt.mbt.md` - Should only reference main file

This approach avoids duplication and sync issues. When editing tests:
1. Add/modify tests in `src/aletheia.pbt.mbt.md`
2. Keep per-package `.pbt.mbt.md` files minimal (just metadata)
3. Run sync to regenerate `pbt_generated_test.mbt` files

**Review checklist:**
- Check template correctness in `src/aletheia.pbt.mbt.md`
- Keep templates as `mbt nocheck` until property logic is valid
- Switch to `mbt check` only after validating semantics

### Phase 3: Update detection/template logic

- **Pattern detection**: `src/patterns/patterns.mbt`
- **Signature extraction/type inference**: `src/analyzer/function_extractor.mbt`
- **Property templates**: `src/generator/property_gen.mbt`
- **CLI wiring**: `src/cli/main.mbt`

### Phase 4: Verify and debug

**Run tests:**
```bash
moon test
# Or update snapshots if needed:
moon test --update
```

**Review interfaces:**
```bash
moon info
```

## Known Issues and Solutions

### 1. Package Format Compatibility

**Issue**: The sync tool previously only supported `moon.pkg.json` format.

**Status**: ✅ FIXED - Now supports both `moon.pkg` (new format) and `moon.pkg.json` (legacy).

**Details**: `src/pbt_sync/sync.mbt` checks for both file formats when resolving package directories.

### 2. Blackbox Test Limitations

**Issue**: Generated tests run as blackbox tests, which cannot access internal types or constructors.

**Impact on testing:**
- Cannot directly construct internal enum variants (e.g., `Help`, `Analyze`, `Generate`)
- Cannot access internal functions without pub qualifier
- Must use fully-qualified names for public APIs (e.g., `@cli.parse_args`)

**Workarounds:**
1. Use fully-qualified public API calls: `@cli.command_to_args(@cli.parse_args(args))`
2. Test round-trip behavior through public interfaces only
3. Avoid direct construction of internal types in tests
4. Focus on observable behavior rather than internal state

### 3. Alias Normalization in Round-Trip Tests

**Issue**: CLI argument parsing normalizes short aliases to full command names.

**Example:**
- Input: `["moon-pbt-gen", "a", "./src"]`
- After round-trip: `["moon-pbt-gen", "analyze", "./src"]`

**Solution**: Either:
- Exclude alias tests from strict round-trip validation, OR
- Update test expectations to account for normalization

### 4. Debugging Test Failures

**When tests fail:**

1. **Identify the failing package**:
   ```bash
   moon test 2>&1 | grep "failed:"
   ```

2. **Check the generated test file**:
   - Look at `src/<pkg>/pbt_generated_test.mbt`
   - Verify sync correctly transferred the markdown test

3. **Verify markdown syntax**:
   - Ensure `## Package: <name>` header exists
   - Check code blocks use ` ```mbt check ` or ` ```mbt nocheck `

4. **Common issues**:
   - **"Cannot create values of the read-only type"**: Trying to use internal types in blackbox test
   - **"The value identifier X is unbound"**: Missing import or internal name
   - **"has no field X"**: API changed, update test accordingly

## Implementation Notes

### File Structure After Sync

```
src/
├── aletheia.pbt.mbt.md          # Main test definitions (edit here)
├── cli/
│   ├── cli.pbt.mbt.md           # Minimal (references main)
│   └── pbt_generated_test.mbt   # Auto-generated (DO NOT EDIT)
├── parser/
│   ├── parser.pbt.mbt.md        # Minimal
│   └── pbt_generated_test.mbt   # Auto-generated
└── ...
```

### Test Template Guidelines

When writing property tests in markdown:

1. **Use `mbt nocheck`** for templates that need manual verification
2. **Use `mbt check`** for complete, validated tests
3. **Prefix test names** with `prop_` for clarity
4. **Document properties** being tested (round-trip, idempotent, etc.)

Example:
````markdown
### prop_parse_args_command_to_args_roundtrip

Round-trip property: command_to_args(parse_args(args)) keeps args stable

```mbt check
test "prop_parse_args_command_to_args_roundtrip" {
  for args in fixtures {
    let args2 = @cli.command_to_args(@cli.parse_args(args))
    assert_eq(args2, args)
  }
}
```
````
