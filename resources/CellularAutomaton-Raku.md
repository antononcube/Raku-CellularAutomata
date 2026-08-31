# `cellular-automaton`

## Primary Function

```raku
multi sub cellular-automaton(
    $rule where * ~~ UInt:D | Str:D --> Callable:D
)
```

```raku
multi sub cellular-automaton(
    Mu:D $rule,
    Mu:D $initial-condition,
    Mu:D $time-specification = 1,
    Mu:D $space-specification = Automatic,
    *%options --> Mu:D
)
```

`cellular-automaton` evolves an initial condition according to a rule. The
one-argument multi candidate returns a callable operator; the multi candidate
with an initial condition performs evolution.

```raku
cellular-automaton($rule, $initial-condition, $t)
```

returns the selected evolution for steps `0..$t`. With no time argument it
performs one step. The initial condition is step `0`; therefore an integer
`$t` produces `$t + 1` states unless a selector requests a different result.
The states in an evolution have a consistent shape and size.

The function also supports operator form:

```raku
my &step = cellular-automaton($rule);
step($initial-condition)
```

The operator form is equivalent to one-step evolution. A partially applied
rule may also be called with an initial condition in the ordinary Raku way.

## Rule Specifications

Rules may be supplied as integers, positional values, hashes, callables,
replacement pairs, or names.

| Raku form                                          | Meaning                                                |
|----------------------------------------------------|--------------------------------------------------------|
| `Int`                                              | Elementary rule number (`0..255`).                     |
| `[$n, $k]`                                         | General nearest-neighbor rule with `$k` colors.        |
| `[$n, $k, $range]`                                 | General rule with `$k` colors and numeric range.       |
| `[$n, $k, @ranges]`                                | Multidimensional rule with one range per dimension.    |
| `[$n, $k, @offsets]`                               | Rule using explicit neighborhood offsets.              |
| `[$n, $k, $range-spec, $order]`                    | Order-`$order` rule.                                   |
| `[$n, [$k, 1]]`                                    | `$k`-color nearest-neighbor totalistic rule.           |
| `[$n, [$k, 1], $range]`                            | `$k`-color range-`$range` totalistic rule.             |
| `[$n, [$k, @weights], $range-spec]`                | Weighted-neighborhood rule.                            |
| `@replacements`                                    | Explicit neighborhood replacements.                    |
| `[$callable, [], $range-spec]`                     | Callable applied to each neighborhood.                 |
| `Callable`                                         | Boolean function applied to each Boolean neighborhood. |
| `Hash`                                             | Association-style rule specification.                  |
| `Str`                                              | Named rule.                                            |
| `Callable` returned by `cellular-automaton($rule)` | One-step operator.                                     |

For `[$n, $k]`, the implicit weights are `[$k ** 2, $k, 1]` and the rule is
equivalent to `[$n, [$k, [$k ** 2, $k, 1]]]`. A complete callable whose number
of Boolean variables can be determined is treated as a Boolean rule; the
neighborhood contains that many cells and is centered by extending
`ceiling($variables / 2)` cells to the left.

### Callable Rules

A callable in the explicit form receives the neighborhood as its first
argument and the zero-based step number as its second argument:

```raku
my &rule = -> @neighborhood, Int $step {
    ([+] @neighborhood) mod 2
};

cellular-automaton([&rule, [], 1], [[1], 0], 20)
```

The callable may return any Raku value. Explicit replacement pairs may use
patterns and may likewise produce symbolic or non-integer values. For a
one-dimensional explicit offset list, neighbors are passed in offset order.
For a multidimensional range, the neighborhood is a full array with
dimensions `2 × range + 1`; explicit multidimensional offsets use a flat list
in the supplied offset order.

An order-`s` rule depends on the preceding `s` states. Its initial condition
must provide those `s` states, and the evolution begins with those states when
the selected time range includes negative steps.

### Rule Hashes

Hash keys are kebab-case equivalents of the Wolfram Language association
keys:

| Key                     | Value                                      |
|-------------------------|--------------------------------------------|
| `rule-number`           | Rule number.                               |
| `totalistic-code`       | Totalistic rule code.                      |
| `outer-totalistic-code` | Outer-totalistic rule code.                |
| `growth-cases`          | Neighbor counts that turn a zero into one. |
| `growth-survival-cases` | `[ @growth, @survival ]` count sets.       |
| `growth-decay-cases`    | `[ @growth, @decay ]` count sets.          |
| `dimension`             | Overall dimension.                         |
| `colors`                | Number of cell colors.                     |
| `range`                 | Rule range.                                |
| `neighborhood`          | Neighborhood type or size.                 |

Growth rules use binary states. `growth-cases` changes `0` to `1` for a
matching count and otherwise preserves the old value. A
`growth-survival-cases` rule grows matching zero cells, preserves matching one
cells, and sets all other cells to zero. A `growth-decay-cases` rule grows
matching zero cells, sets matching one cells to zero, and otherwise preserves
the old value.

In two dimensions, `neighborhood => 'VonNeumann'` or `5` selects the
cross-shaped neighborhood, while `'Moore'` or `9` selects the 3×3
neighborhood. The same names and compatible integer neighborhood sizes apply
in higher dimensions.

The following names are predefined:

| Name         | Equivalent rule                                         |
|--------------|---------------------------------------------------------|
| `Rule30`     | `30`                                                    |
| `Rule90`     | `90`                                                    |
| `Rule110`    | `110`                                                   |
| `Code1599`   | `[1599, [3, 1]]`                                        |
| `GameOfLife` | `[224, [2, [[2, 2, 2], [2, 1, 2], [2, 2, 2]]], [1, 1]]` |

Names are matched case-insensitively only if the implementation documents that
policy; the canonical spellings above must always work.

## Initial Conditions

Initial conditions are cyclic when supplied as a complete one-dimensional
list. The neighbor to the left of the first item is the last item, and vice
versa.

| Form                                             | Meaning                                            |
|--------------------------------------------------|----------------------------------------------------|
| `@values`                                        | Explicit cyclic values.                            |
| `[@values, $background]`                         | Values superimposed on a constant background.      |
| `[@values, @background]`                         | Values superimposed on a repeating background.     |
| `[@offset-blocks, $background]`                  | Blocks placed at explicit offsets on a background. |
| `@rows`                                          | Explicit list of values in tow dimensions.         |
| `[$active-spec, $background-spec]`               | Values in any dimension with padding.              |
| `[$active-spec, $background-spec]` for order `s` | `s` initial states.                                |

- An active specification can be a list of values or a list of `[$values, $offset]` pairs. In one dimension the first active value defaults to offset `0`.
- In `d` dimensions, the first value at indices `[0; ...; 0]` defaults to offset `[0; ...; 0]`. 
- The first active element is aligned with the first background element. A background list repeats as necessary.
- Sparse arrays are valid wherever an array is accepted and are useful for large, mostly empty initial conditions.
- Unless a background is supplied, `All` and `Automatic` include every cell in the explicit active condition.

## Time and Space Selection

The third argument may be an integer or a time/space selector. A selector is a
positional list whose first element selects time and later elements select
space dimensions:

| Time form                    | Meaning                                              |
|------------------------------|------------------------------------------------------|
| `$t`                         | Steps `0..$t`.                                       |
| `[$t]`                       | Only step `$t`, returned as a one-element evolution. |
| `[[$t]]`                     | Only step `$t`, returned as the state itself.        |
| `[$start, $end]`             | Inclusive range of steps.                            |
| `[$start, $end, $increment]` | Inclusive stepped range.                             |

`cellular-automaton($rule, $init, [$time-spec])` uses `Automatic` space
selection. A scalar selector is normalized as a time selector; nested arrays
preserve the distinction between an evolution and one selected state.

For each spatial dimension:

| Space form                   | Meaning                                                        |
|------------------------------|----------------------------------------------------------------|
| `All`                        | Every cell that can be affected during the selected evolution. |
| `Automatic`                  | The region differing from the background.                      |
| `0`                          | The cell aligned with the start of the active specification.   |
| `$x`                         | Offsets from the origin through `$x` to the right.             |
| `-$x`                        | Offsets through `$x` to the left.                              |
| `[$x]`                       | Only offset `$x` to the right.                                 |
| `[-$x]`                      | Only offset `$x` to the left.                                  |
| `[$start, $end]`             | Inclusive offset range.                                        |
| `[$start, $end, $increment]` | Inclusive stepped offset range.                                |

All returned states have the same selected dimensions. `All` grows according
to the initial active width, number of steps, and rule range. `Automatic` may
trim unchanged background cells and considers only the requested time steps.
Explicit space ranges can be used to force equal regions for different rules.

- With an initial condition specified by `$active-spec` of width $w$, the region that can be affected after $t$ steps by a cellular automaton with a rule of range $r$ has width $w + 2 * r * t$.

## Result and Errors

The result is a `Positional` evolution unless the selector explicitly asks for
one state. A one-dimensional state is a positional sequence; a
multidimensional state is nested positional data. The implementation must
preserve cell values without coercing symbolic, Boolean, or continuous values
to integers.

The implementation must reject malformed rule shapes, incompatible
dimensions, invalid colors or ranges, impossible time/space selectors, and
insufficient initial states for an order-`s` rule with a typed exception. It
must not silently reinterpret a malformed positional rule as a different rule
kind.

## Optional Visualization Helper

Implementations may provide:

```raku
sub rule-plot(Mu:D $rule, *%options --> Mu:D)
```

`rule-plot` returns a representation suitable for visualizing the rule. It is
not required for evolution and must accept the same rule specifications as
`cellular-automaton`.

## Conformance Examples

```raku
# Rule 30, two steps from a single active cell.
cellular-automaton(30, [[1], 0], 2);

# Rule 90 as an explicit neighborhood function.
my &rule90 = -> @n, Int $step { (@n[0] + @n[2]) mod 2 };
cellular-automaton([&rule90, [], 1], [[1], 0], 50);

# 2D totalistic rule, selecting only step 30.
cellular-automaton([14, [2, 1], [1, 1]], [[[1]], 0], [[30]]);

# Association syntax uses kebab-case keys.
cellular-automaton(
    { totalistic-code => 26, dimension => 2, neighborhood => 'VonNeumann' },
    [[[1]], 0],
    [[[30]]]
);

# Operator form
cellular-automaton(30)
```
