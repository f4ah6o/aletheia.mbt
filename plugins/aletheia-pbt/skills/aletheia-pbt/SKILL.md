---
name: aletheia-pbt
description: Apply Aletheia to generate and sync property-based tests for any MoonBit module. Use when asked to add or update .pbt.mbt.md templates and per-package tests.
---

# Aletheia PBT

## Overview

Apply Aletheia to a target MoonBit module or package to generate .pbt.mbt.md templates and sync them into per-package tests.

## Workflow

1. Choose a target path
   - Use a module root (contains moon.mod.json) or a package directory (contains moon.pkg.json).

2. Analyze patterns (optional)
   - moon run src/aletheia -- analyze <path> --explain

3. Generate templates
   - moon run src/aletheia -- generate <path>
   - Use --dry-run --format json for previews.
   - Output path is <module>.pbt.mbt.md in the target root (derived from moon.mod.json).

4. Refine templates
   - Keep manual edits outside <!-- aletheia:begin --> / <!-- aletheia:end -->.
   - Leave code blocks as mbt nocheck until properties are validated; switch to mbt check afterward.

5. Sync tests
   - moon run src/aletheia -- sync [path] (defaults to <source>/<module>.pbt.mbt.md).

6. Verify
   - moon info && moon fmt
   - moon test (or moon test --update if snapshots change)
