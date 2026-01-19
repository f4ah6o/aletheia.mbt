---
name: aletheia-pbt
description: Apply Aletheia to generate and sync property-based tests for any MoonBit module. Use when asked to add or update .pbt.mbt.md templates and per-package tests.
---

# Aletheia PBT

## Overview

Apply Aletheia to a target MoonBit module or package to generate .pbt.mbt.md templates and sync them into per-package tests.

## Prerequisites & Installation

This skill assumes a working MoonBit toolchain. Aletheia is published on mooncakes.io, so you can install it directly:

```bash
moon add f4ah6o/aletheia
```

After installing, run the CLI from your target repo:

```bash
moon run f4ah6o/aletheia/aletheia -- analyze /path/to/target --explain
moon run f4ah6o/aletheia/aletheia -- generate /path/to/target
moon run f4ah6o/aletheia/aletheia -- sync /path/to/target
```

If you already have the aletheia.mbt repo locally, you can also run `moon run src/aletheia` from that repo instead.

## v0.4.0 Features

- **5 Pattern Types**: Round-Trip, Idempotent, Producer-Consumer, Invariant, and Oracle
- **State Machine Testing**: Support for stateful system testing with command generation
- **Enhanced Shrinking**: Advanced shrinking strategies for better counterexample analysis
- **Statistics Integration**: Built-in statistics for test insights
- **Size Parameter Control**: Configurable size parameters for recursive types

## Workflow

1. Choose a target path
   - Use a module root (contains moon.mod.json) or a package directory (contains moon.pkg.json).

2. Analyze patterns (optional)
   - `moon run src/aletheia -- analyze <path> --explain`
   - Shows detailed pattern detection with explanations

3. Generate templates
   - `moon run src/aletheia -- generate <path>`
   - CLI Options:
     - `--dry-run`: Preview without writing files
     - `--explain`: Output detection details
     - `--format <text|json>`: Output format (default: text)
   - Output path is `<module>.pbt.mbt.md` in the target root (derived from moon.mod.json).

4. Refine templates
   - Keep manual edits outside `<!-- aletheia:begin -->` / `<!-- aletheia:end -->`.
   - Leave code blocks as `mbt nocheck` until properties are validated; switch to `mbt check` afterward.

5. Sync tests
   - `moon run src/aletheia -- sync [path]` (defaults to `<source>/<module>.pbt.mbt.md`).

6. Verify
   - `moon info && moon fmt`
   - `moon test` (or `moon test --update` if snapshots change)

## Pattern Types

Aletheia automatically detects these patterns:

1. **Round-Trip**: encode/decode, serialize/deserialize
2. **Idempotent**: sort, normalize, trim
3. **Producer-Consumer**: Producer-consumer chains
4. **Invariant**: Collection invariants (Map, Filter, Sort)
5. **Oracle**: Implementation vs reference comparison
