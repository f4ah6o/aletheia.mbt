---
name: pbt-workflow-guide
description: Interactive guide for applying PBT patterns to MoonBit modules. Use for pattern selection, generator design, Shrink implementation, and state machine test design.
---

# PBT Workflow Guide

## Overview

This skill provides an interactive guide for applying Property-Based Testing (PBT) patterns to MoonBit modules. Unlike `aletheia-pbt` which generates and syncs test templates automatically, this guide helps developers:

- Select appropriate PBT patterns based on function characteristics
- Design effective generators with proper distribution control
- Implement custom `Shrink` for complex types
- Design state machine tests with shim abstractions

## Pattern Decision Tree

Use this flow to select the appropriate pattern for a given function:

```
Q1: What type of function?
│
├─ Transformation (A -> B)
│   └─ Q2: Inverse exists?
│       ├─ YES → Round-Trip
│       └─ NO → Q3: Measurable output properties?
│           ├─ YES → Invariant
│           └─ NO → Q4: Reference implementation exists?
│               ├─ YES → Oracle
│               └─ NO → Producer-Consumer or unit tests
│
├─ Normalization (A -> A)
│   └─ Idempotent
│
└─ Stateful system
    └─ State Machine + Shim
```

### Pattern Summary

| Pattern | Use Case | Example |
|---------|----------|---------|
| Round-Trip | Encode/decode pairs | `parse(to_string(x)) == x` |
| Idempotent | Normalization functions | `sort(sort(x)) == sort(x)` |
| Invariant | Collection operations | `map(f, xs).length() == xs.length()` |
| Oracle | Algorithm verification | `my_sort(x) == stdlib_sort(x)` |
| Producer-Consumer | Chained operations | `consume(produce(x))` succeeds |
| State Machine | Stateful systems | Commands executed against model |

## Generator Design Guide

### Distribution Strategy

Effective PBT requires intentional control over input distribution:

| Category | Percentage | Purpose |
|----------|------------|---------|
| Normal values | 70% | Typical usage patterns |
| Edge cases | 15% | Empty, zero, single element |
| Boundary values | 15% | Limits, extremes |

### Using `frequency` for Distribution Control

```mbt
fn gen_my_int() -> @qc.Gen[Int] {
  @qc.frequency([
    (70, @qc.int()),                    // Normal values
    (15, @qc.one_of([@qc.pure(0), @qc.pure(1), @qc.pure(-1)])),  // Edge cases
    (15, @qc.one_of([@qc.pure(@int.max_value), @qc.pure(@int.min_value)])),  // Boundaries
  ])
}
```

### Type-Specific Edge Cases

| Type | Edge Cases |
|------|------------|
| Int | 0, 1, -1, MAX_INT, MIN_INT |
| String | "", single char, unicode, multiline (`\n`) |
| Array | [], single element, all same, sorted, reversed |
| Option | None, Some(edge_value) |
| Map | empty, single entry, duplicate values |

### Using `sized` for Recursive Types

For recursive types (trees, nested structures), use `sized` to prevent infinite recursion:

```mbt
fn gen_tree[T](gen_value : @qc.Gen[T]) -> @qc.Gen[Tree[T]] {
  @qc.sized(fn(size) {
    if size <= 0 {
      gen_value.map(Leaf)
    } else {
      @qc.frequency([
        (1, gen_value.map(Leaf)),
        (3, @qc.resize(size / 2, gen_tree(gen_value)).bind(fn(left) {
          @qc.resize(size / 2, gen_tree(gen_value)).map(fn(right) {
            Node(left, right)
          })
        })),
      ])
    }
  })
}
```

## Statistics & Classification Guide

### Using `classify` for Test Insight

Add classification to understand what your tests actually cover:

```mbt
test "my_property" {
  @qc.quick_check_fn(fn(xs : Array[Int]) {
    @qc.classify(xs.is_empty(), "empty")
    @qc.classify(xs.length() == 1, "single")
    @qc.classify(xs.length() > 10, "large")
    // ... property assertion
  })
}
```

### Using `collect` for Value Distribution

```mbt
test "check_distribution" {
  @qc.quick_check_fn(fn(n : Int) {
    @qc.collect(n % 10, "last digit")
    // ... property assertion
  })
}
```

### Interpreting Statistics

- If edge cases appear < 1% of the time, increase their frequency in the generator
- If certain categories never appear, your generator may have blind spots
- Use statistics to validate your distribution assumptions

## Shrink Implementation Guide

### Why Custom Shrink Matters

When a property fails, QuickCheck shrinks the counterexample to find the minimal failing case. Custom `Shrink` implementations help:

- Find smaller, more readable counterexamples
- Debug faster by isolating the essential failure

### Shrink Implementation Template

```mbt
pub impl Shrink for MyType with shrink(self) -> Iter[MyType] {
  let mut shrunk : Array[MyType] = []

  // Phase 1: Try simplest values first
  shrunk.push(MyType::default())

  // Phase 2: Simplify individual fields
  for field_shrunk in self.field.shrink() {
    shrunk.push(MyType::new(field_shrunk, self.other_field))
  }
  for other_shrunk in self.other_field.shrink() {
    shrunk.push(MyType::new(self.field, other_shrunk))
  }

  // Phase 3: Try boundary values
  shrunk.push(MyType::with_boundary_values())

  shrunk.iter()
}
```

### Shrinking Order Principles

1. **Try empty/zero first** - Simplest possible values
2. **Shrink one field at a time** - Isolate the problematic component
3. **Preserve structure when possible** - Keep overall shape while simplifying contents
4. **Respect invariants** - Don't generate invalid shrunk values

## State Machine Testing Guide

State machine testing verifies stateful systems by:
1. Generating sequences of commands
2. Executing them against both a model (pure) and the real system
3. Verifying postconditions after each command

### Shim Abstraction Pattern

Wrap non-deterministic or side-effecting operations in a shim:

```mbt
// Shim interface - isolates side effects
trait Shim {
  fn create_user(self, name : String) -> Result[UserId, Error]
  fn get_user(self, id : UserId) -> Result[User, Error]
  fn delete_user(self, id : UserId) -> Result[Unit, Error]
}

// Real implementation
struct RealShim { ... }

// Test implementation with controlled behavior
struct TestShim {
  users : Map[UserId, User]
  next_id : Int
}
```

### StateM Model Design

```mbt
// Model state - pure, no side effects
struct ModelState {
  users : Map[UserId, User]
  deleted : Set[UserId]
}

// Commands
enum UserCmd {
  Create(String)
  Get(UserId)
  Delete(UserId)
}

// State machine definition
let sm = StateM::new(
  "UserSystem",
  ModelState::default(),  // initial state
  fn(state, cmd) {        // next_state - must be PURE!
    match cmd {
      Create(name) => { ... }
      Get(id) => state  // queries don't change state
      Delete(id) => { ... }
    }
  },
)
.with_precondition(fn(state, cmd) {
  // Only allow valid commands
  match cmd {
    Get(id) | Delete(id) => state.users.contains(id)
    _ => true
  }
})
.with_postcondition(fn(state, cmd, result) {
  // Verify model matches reality
  match cmd {
    Get(id) => result == state.users.get(id)
    _ => true
  }
})
```

### Deterministic Model Principles

1. **Model state must be pure** - No side effects in `next_state`
2. **Model should be simple** - Easier than the real implementation
3. **Capture essential behavior** - Abstract away implementation details
4. **Use shims for non-determinism** - Wrap timestamps, random values, I/O

## Workflow Steps

### Step 1: Identify Target Functions

List functions in your module and categorize them:
- Transformation functions (input -> different output)
- Normalization functions (input -> same type, simplified)
- Stateful operations (side effects, state changes)

### Step 2: Apply Pattern Decision Tree

For each function, walk through the decision tree to select a pattern.

### Step 3: Design Generators

For each input type:
1. Identify edge cases specific to your domain
2. Choose distribution percentages
3. Implement using `frequency`, `one_of`, `sized` as needed

### Step 4: Add Statistics

Add `classify` and `collect` calls to verify coverage:
- Run tests with verbose output
- Verify edge cases appear at expected frequencies
- Adjust generators if distribution is skewed

### Step 5: Implement Custom Shrink (if needed)

For custom types with complex structure:
1. Implement `Shrink` trait
2. Follow shrinking order principles
3. Test that shrunk values maintain type invariants

### Step 6: Write Properties

Implement the actual property tests using the selected patterns.

### Step 7: Iterate

- Run tests and analyze failures
- Use statistics to improve coverage
- Refine generators based on discovered edge cases

## Quick Reference

### Generator Expressions

| Expression | Purpose |
|------------|---------|
| `@qc.pure(x)` | Always generate x |
| `@qc.one_of([g1, g2])` | Equal probability choice |
| `@qc.frequency([(w1, g1), (w2, g2)])` | Weighted choice |
| `@qc.sized(fn(n) { ... })` | Size-dependent generation |
| `@qc.resize(n, gen)` | Override size parameter |
| `gen.filter(pred)` | Only values satisfying pred |
| `gen.map(f)` | Transform generated values |
| `gen.bind(f)` | Chain generators |

### Property Patterns

```mbt
// Round-Trip
decode(encode(x)) == x

// Idempotent
f(f(x)) == f(x)

// Invariant
output.property() satisfies constraint

// Oracle
my_impl(x) == reference_impl(x)
```

### Statistics Patterns

```mbt
// Binary classification
@qc.classify(condition, "label")

// Value collection
@qc.collect(value, "category")

// Multiple labels
@qc.classify(c1, "l1")
@qc.classify(c2, "l2")
```
