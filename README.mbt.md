# Aletheia - Property-Based Testing Code Generation for MoonBit

Aletheia is a tool that automatically generates property-based tests from MoonBit source code.

## Overview

Aletheia automatically generates property-based testing (PBT) code from MoonBit source code by detecting common testing patterns.

- **Pattern Detection**: Automatically detects Round-Trip, Idempotent, Producer-Consumer, Invariant, and Oracle patterns
- **Test Generation**: Generates PBT code based on detected patterns
- **PBT Synchronization**: Syncs code blocks from `<module>.pbt.mbt.md` to per-package tests
- **Dogfooding**: Self-validates tool quality using its own test generation

## Current Status

### ✅ Implemented Modules

| Module | Description | Status |
|--------|-------------|--------|
| `parser` | Markdown parser | ✅ Complete |
| `patterns` | Pattern detection (Round-Trip, Idempotent, Producer-Consumer, Invariant, Oracle) | ✅ Complete |
| `generator` | PBT code generation with frequency-based generators | ✅ Complete |
| `cli` | CLI command parser | ✅ Complete |
| `analyzer` | Function extractor and arbitrary detector | ✅ Complete |
| `pbt` | PBT runtime with shrinking | ✅ Complete |
| `pbt_sync` | PBT synchronization | ✅ Complete |
| `dogfooding` | Self-testing | ✅ Complete |
| `state_machine` | State machine testing | ✅ Complete |

### Test Coverage

- **Total Tests**: 50+
- **Pass Rate**: 100%

## Usage

```bash
# Run all tests
moon test

# Type check
moon check

# CLI help
moon run src/aletheia

# Generate PBT targets
moon run src/aletheia -- generate ./src

# Generate with JSON summary (dry-run)
moon run src/aletheia -- generate ./src --dry-run --format json

# Analyze with detailed explanations
moon run src/aletheia -- analyze ./src --explain

# Sync PBT markdown (default: src/aletheia.pbt.mbt.md)
moon run src/aletheia -- sync

# Self-apply PBT generation (template output)
./scripts/self_pbt.sh
# self_pbt.sh runs generate/sync + moon info + moon fmt

# Development batch check
./scripts/dev-check.sh
```

## PBT Development Workflow

Workflow for modifying PBT test files or markdown:

1. Edit `.pbt.mbt.md` markdown file
2. Run `./scripts/self_pbt.sh` to regenerate test files
3. Verify with `moon test`
4. Commit both markdown and generated test files

**Important**: Always run `./scripts/self_pbt.sh` before committing PBT changes.
This script ensures generated test files are properly formatted with `moon fmt`.

```bash
# Recommended PBT development workflow
# 1. Edit markdown
vim src/aletheia.pbt.mbt.md

# 2. Regenerate test files
./scripts/self_pbt.sh

# 3. Run tests
moon test

# 4. Review changes
git status
git diff

# 5. Commit (both markdown and generated test files)
git add src/aletheia.pbt.mbt.md src/*/pbt_generated_test.mbt
git commit -m "feat: add PBT tests for XYZ"
```

## Claude Code Plugins

```bash
# Try plugin locally (general use)
claude --plugin-dir ./plugins/aletheia-pbt

# Try plugin locally (self-apply)
claude --plugin-dir ./plugins/aletheia-self-pbt

# Add marketplace and install (within Claude Code)
/plugin marketplace add .
/plugin install aletheia-pbt@f4ah6o-plugins
/plugin install aletheia-self-pbt@f4ah6o-plugins
```

## Module Structure

```
src/
├── aletheia.pbt.mbt.md  # PBT targets/properties aggregation
├── aletheia/       # CLI entry point
├── analyzer/       # Function extractor and arbitrary detector
├── ast/            # AST definitions
├── cli/            # CLI command processing
├── dogfooding/     # Self-testing (Dogfooding)
├── generator/      # PBT code generation
├── parser/         # Markdown parser
├── patterns/       # Pattern detection
├── pbt/            # PBT runtime
├── pbt_sync/       # PBT synchronization
└── state_machine/  # State machine testing
```

## Architecture

### Core Components

1. **aletheia** - CLI entry point for `moon-pbt-gen` tool
   - Commands: `analyze`, `generate`, `sync`, `help`

2. **analyzer** - Code analysis engine
   - Detects Arbitrary trait implementations for testable types
   - Extracts function metadata using moonbitlang/parser
   - Builds call graphs for dependency analysis

3. **generator** - PBT test code generation
   - Edge case input generation
   - Expression generators for various types
   - Oracle-based testing templates
   - Frequency-based property test generation

4. **patterns** - Pattern detection engine
   - Round-Trip (encode/decode, serialize/deserialize)
   - Idempotent (sort, normalize, trim)
   - Producer-Consumer chains
   - Collection invariants (Map, Filter, Sort)
   - Oracle patterns (implementation vs reference)

5. **pbt** - Property-Based Testing runtime
   - Test execution with configuration
   - Value generators
   - Test case shrinking for counterexamples
   - Advanced shrinking strategies

6. **state_machine** - Stateful system testing
   - Shim interface for side effects
   - Command generation and execution

### Recent Enhancements (v0.4.0)

- Statistics integration for better test insights
- Enhanced invariant detection for collections
- Advanced shrinking systems
- State machine testing support
- Improved template generation
- Size parameter control for recursive types

## Limitations

- **AST Parsing Precision**: Currently uses simple line scanning, complex signatures and type inference are not supported
- **Generated Test Adjustment**: Treat generated `.pbt.mbt.md` as templates; adjust types and properties as needed
- **Generation Markers**: Inserts `<!-- aletheia:begin -->` and `<!-- aletheia:end -->` in `.pbt.mbt.md`. Manual edits outside markers are preserved
- **Warnings**: Build warnings about unused variables/functions exist (no functional impact)

## Editing Generated Files

### Marker-Protected Sections

Generated files contain sections marked with `<!-- aletheia:begin -->` and `<!-- aletheia:end -->`.

- **Inside markers**: Auto-generated content, overwritten by `generate` command
- **Outside markers**: Manually added content is preserved

### Regeneration Rules

```bash
# Running generate multiple times produces identical results
moon run src/aletheia -- generate ./src
moon run src/aletheia -- generate ./src  # No diff

# Manual edits outside markers are preserved
echo "## Manual Notes" >> src/aletheia.pbt.mbt.md
moon run src/aletheia -- generate ./src
grep "Manual Notes" src/aletheia.pbt.mbt.md  # Manual Notes still present
```

### Verifying Determinism

To verify that generation is deterministic (produces identical output on multiple runs):

```bash
# Generate first time
moon run src/aletheia -- generate ./src
cp src/aletheia.pbt.mbt.md /tmp/original.md

# Generate second time
moon run src/aletheia -- generate ./src

# Compare - should have no differences
diff /tmp/original.md src/aletheia.pbt.mbt.md
```

Expected: No output (files are identical). If there are differences, generation is non-deterministic.

### Marker Specification

Generated files use HTML comment markers to delimit auto-generated content:

- **Start marker**: `<!-- aletheia:begin -->`
- **End marker**: `<!-- aletheia:end -->`

**Behavior**:
1. Content between markers is replaced on each generation
2. Content outside markers is preserved unchanged
3. If markers don't exist, they are created with all generated content inside
4. Manual edits should be placed outside markers to persist across regenerations


## Dependencies

- `moonbitlang/parser` - AST parsing
- `moonbitlang/x` - Standard extensions
- `moonbitlang/quickcheck` - PBT runtime

## License

Apache-2.0
