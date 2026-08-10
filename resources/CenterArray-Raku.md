# `center-array`

## Primary Function

```raku
multi sub center-array(
    Mu:D $dimension-specification,
    Mu:D :$padding = 0,
    Bool:D :$sparse = False,
    Int:D :$interpolation-order = 1
    --> Positional:D
)
```

```raku
multi sub center-array(
    Mu:D $array,
    Mu:D $dimension-specification,
    Mu:D $padding = 0,
    Bool:D :$sparse = False,
    Int:D :$interpolation-order = 1
    --> Positional:D
)
```

`center-array` creates a target-shaped array and places the input at its
center. It adds padding when the target is larger and crops the centered
region when the target is smaller. The input is not modified.

The one-argument data-less form creates an array containing a single `1` at
the center and zero elsewhere:

```raku
center-array(5);       # [0, 0, 1, 0, 0]
center-array([5, 5]);  # a 5 × 5 array with a centered 1
```

The two-argument form centers the supplied array. A non-positional expression
is treated as a one-element array before centering, so
`center-array($value, 5)` places `$value` at the center of a list of length 5.

## Target Dimensions

The dimension specification is either an integer or a positional sequence of
dimension specifications.

| Form              | Meaning                                           |
|-------------------|---------------------------------------------------|
| `Int $n`          | Target size of the applicable/deepest dimension.  |
| `[$n1, $n2, ...]` | Target size in each dimension, outermost first.   |
| `Inherited`       | Keep the corresponding input dimension unchanged. |
| `All`             | Infer the dimension from the input collection.    |

Every explicit target dimension must be a non-negative integer or one of the
sentinels above. `Inherited` means that no padding or cropping occurs at that
level. `All` uses the largest extent found at that level, which is useful when
conforming a collection of ragged arrays into a full rectangular array.

`Inherited` and `All` are exported package sentinel values, not string
spellings. Their exact concrete types are implementation-defined.

If the target has more dimensions than the input, the input is centered at the
deepest level and the missing outer levels are created around it. If the target
has fewer dimensions, centering applies to the dimensions represented by the
target specification; unspecified inner dimensions retain their input shape.

For an input array with dimensions `@source` and target dimensions `@target`,
the centered offset for a dimension is:

```text
delta = target - source
left  = floor(delta / 2)
right = delta - left
```

Positive offsets add padding; negative offsets crop. Thus, when the difference
is odd, the extra element is placed on the right. The original values remain
in their relative order.

## Padding

The default background is zero. The optional `$padding` argument accepts a
constant value, a cyclic positional sequence, or the named modes defined by
`ArrayPad-Raku.md`:

```raku
center-array([1, 2, 3], 6, :padding(Missing));
center-array([1, 2, 3], 6, :padding('Extrapolated'));
```

Supported named modes are:

| Mode                     | Meaning                                               |
|--------------------------|-------------------------------------------------------|
| `'Extrapolated'`         | Polynomial extrapolation beyond the centered data.    |
| `'Fixed'`                | Repeat boundary values, including consistent corners. |
| `'Periodic'`             | Repeat the complete array cyclically.                 |
| `'Reflected'`            | Reflect at boundaries without repeating the edge.     |
| `'ReflectedDifferences'` | Reflect edge differences antisymmetrically.           |
| `'Reversed'`             | Repeat the reversed source sequence.                  |
| `'ReversedDifferences'`  | Repeat reversed edge differences.                     |
| `'ReversedNegation'`     | Repeat reversed, numerically negated values.          |

When cropping is required, padding is not evaluated for the removed region.
Value-dependent modes may fail for empty source dimensions because no boundary
value exists; constant padding remains valid in that case.

For `Extrapolated` padding, implementations should expose the same option as
`array-pad`:

```raku
center-array(@values, 8, :padding('Extrapolated'), :interpolation-order(2));
```

The default interpolation order is `1`. The option must be accepted either as
a named argument or through the package's common padding options object, but
the behavior must match `array-pad`.

## Output Representation

By default, `center-array` returns a full nested positional array, even when
the input is sparse. With `:sparse(True)`, it returns the package's sparse
array representation and preserves the sparse background where possible:

```raku
center-array(@values, [5, 5], :padding(0), :sparse(True));
```

Sparse input is accepted in either output mode. A sparse input's background
value is preserved for sparse output, regardless of the requested padding
value. Implementations may materialize a dense result when a padding mode
requires inspecting or extrapolating all values.

## Ragged and Mixed Inputs

The input may be a full array, ragged array, scalar expression, or sparse
array. Ragged input can be centered when each item has a compatible array
depth. `All` dimensions are intended to turn such compatible ragged input into
a full array by using the maximum extent at each level.

Mixed items with incompatible depths must be normalized before they are
centered. The implementation must reject an ambiguous target rank rather than
silently placing items at unrelated levels. A caller can normalize each item
with explicit `Inherited` dimensions and then center the resulting collection.

## Relations

`center-array` is a centered specialization of `array-pad`: it determines the
left and right amounts from the source and target dimensions, then applies the
requested padding mode. Unlike `array-pad`, its integer dimension argument is a
target size, not an amount to add.

For one-dimensional lists:

```raku
center-array([1, 2, 3], 5);
# [0, 1, 2, 3, 0]

center-array([1, 2, 3, 4, 5, 6, 7, 8, 9], 3);
# [4, 5, 6]
```

`pad-left` and `pad-right` are length-oriented one-sided helpers and are not
substitutes for centered placement. `center-array(@list, $n)` always attempts
equal padding/cropping and puts the extra element on the right.

## Errors and Guarantees

The implementation must reject negative target dimensions, malformed dimension
specifications, incompatible target rank, invalid padding modes, impossible
value-dependent padding, and unsupported sparse output requests with typed
exceptions. It must not mutate the input.

The result must have the requested dimensions, except that `Inherited` keeps
the corresponding source dimensions and `All` resolves from the input. The
centered source region must retain every value that is not cropped by the
target dimensions.

## Conformance Examples

```raku
# Center a scalar in a list.
center-array('x', 5);

# Center a list in a matrix; the list occupies the deepest level.
center-array([1, 2, 3], [5, 5]);

# Center a matrix with more rows and fewer columns.
center-array([[1, 2, 3], [4, 5, 6]], [4, 1]);

# Keep the input's first dimension and conform the second to length 3.
center-array([9], [Inherited, 3]);

# Infer dimensions across a ragged collection.
center-array(
    [[[1, 2, 3], [4, 5, 6]], [[a, b], [c, d], [e, f]]],
    [All, All, All]
);

# Request sparse output.
center-array([1, 2, 3], [5, 5], :padding(0), :sparse(True));
```
