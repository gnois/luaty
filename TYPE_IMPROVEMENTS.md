# Type System Improvements

This document describes the improvements made to Luaty's type inference system, inspired by the Simple-sub algorithm from LPTK's research.

## Background

Luaty originally used a traditional Hindley-Milner (HM) type inference system with unification. While HM is effective for parametric polymorphism, it has limitations with subtyping and recursive types.

## Simple-sub Improvements Implemented

### 1. Type Variable Bounds

**What it is**: Instead of eagerly unifying type variables, we now track upper and lower bounds for each type variable.

**Benefits**:
- More flexible subtyping constraints
- Better handling of union types
- More precise type inference in complex scenarios

**Implementation**:
- Added `lower_bounds` and `upper_bounds` tracking in `lt/solve.lt`
- Type variables can accumulate multiple bounds before final resolution
- `add_lower_bound(tvar, bound)` - adds a lower bound (tvar :> bound)
- `add_upper_bound(tvar, bound)` - adds an upper bound (tvar <: bound)

### 2. Constrain Function for Subtyping

**What it is**: A new `constrain(a, b)` function that checks if type `a` is a subtype of type `b`.

**Benefits**:
- Separates subtyping checks from unification
- Handles contravariance in function parameters correctly
- Better support for union types in subtyping relationships

**Key features**:
- Handles union types: `A|B <: C` iff `A <: C` and `B <: C`
- Handles union types: `A <: B|C` iff `A <: B` or `A <: C`
- Function subtyping is contravariant in parameters, covariant in returns

### 3. Improved Union Type Simplification

**What it is**: Enhanced the `flatten` function in `lt/type.lt` to better simplify union types.

**Benefits**:
- More compact type representations
- Removes redundant types from unions
- Better readability of inferred types

**How it works**:
- When creating union types, remove subtypes that are dominated by supertypes
- If `num <: num|str`, the union simplifies to just the broader type
- Bidirectional checking ensures the most general type is kept

### 4. Compact Recursive Type Representation

**What it is**: New `compact_rec` function to detect and represent recursive types compactly.

**Benefits**:
- Prevents infinite loops when printing recursive types
- More readable type representations
- Foundation for future recursive type support

**Implementation**:
- Tracks seen types during traversal
- Detects cycles in type graphs
- Returns compact representations

### 5. Type Levels for Let-Polymorphism (Foundation)

**What it is**: Infrastructure for tracking type variable levels (currently not fully utilized).

**Future benefits**:
- Support for let-polymorphism
- More precise generalization
- Better handling of polymorphic recursion

**Status**: 
- Variables `type_level` and `var_levels` added to `lt/solve.lt`
- Currently unused but ready for future enhancement

## Technical Details

### Changes in lt/solve.lt

1. **Bounds tracking**:
   ```lua
   var lower_bounds = {}  -- lower_bounds[id] = {types...}
   var upper_bounds = {}  -- upper_bounds[id] = {types...}
   ```

2. **Enhanced unification**:
   - When unifying two type variables, their bounds are merged
   - When unifying a type variable with a concrete type, bounds are updated

3. **New constrain function**:
   - Exported as part of the solver API
   - Available for use in type checking

### Changes in lt/type.lt

1. **Improved flatten function**:
   - Bidirectional subtype checking
   - Dominated type removal
   - More efficient union simplification

2. **New compact_rec function**:
   - Recursive type detection
   - Cycle-safe traversal
   - Exported for external use

3. **Enhanced exports**:
   - `compact_rec` - for compact recursive type representation
   - `subtype` - for subtype checking

## Comparison with Original HM

| Feature | Original HM | With Simple-sub Improvements |
|---------|-------------|------------------------------|
| Subtyping | Basic equality | Full subtyping with bounds |
| Union types | Simple flattening | Smart simplification with subtype removal |
| Recursive types | Basic support | Compact representation with cycle detection |
| Type variables | Immediate unification | Bounds accumulation before resolution |
| Polymorphism | Standard let-polymorphism | Infrastructure for enhanced polymorphism |

## Testing

All existing tests pass with these improvements:
- No regressions in existing type inference
- Backward compatible with existing code
- Foundation for more advanced type system features

## Future Enhancements

These improvements provide a foundation for:

1. **Full let-polymorphism**: Using type levels to better handle polymorphic functions
2. **Better error messages**: Using bounds to provide more informative type errors
3. **Row polymorphism**: Extending to support row types for tables
4. **Recursive type inference**: Full support for mutually recursive type definitions
5. **Gradual typing**: Mix of static and dynamic typing with better precision

## References

- [Simple-sub GitHub Repository](https://github.com/LPTK/simple-sub) by LPTK
- [The Simple Essence of Algebraic Subtyping](https://infoscience.epfl.ch/record/278576) - ICFP 2020 Pearl
- [Demystifying MLsub](https://lptk.github.io/programming/2020/03/26/demystifying-mlsub.html) - Blog post by Lionel Parreaux

## Credits

These improvements are inspired by and adapted from the Simple-sub algorithm developed by Lionel Parreaux (LPTK) and colleagues, which provides a simpler and more accessible approach to algebraic subtyping than the original MLsub.
