# `array-pad`

## Primary Function

```raku
sub array-pad(
    Positional:D $array,
    Mu:D $padding-specification,
    Mu:D $padding = 0,
    Int:D :$interpolation-order = 1
    --> Positional:D
)
```

`array-pad` returns an array with elements added around the input array. The
input is not modified. The operation supports nested positional arrays of any
depth and sparse-array implementations. Cell values may be arbitrary Raku
objects unless a selected padding mode requires numeric arithmetic.

```raku
array-pad(@array, $m)
```

pads every side of every applicable dimension with `$m` elements using zero
padding. The three-argument form uses the supplied padding value or padding
mode. `:interpolation-order` applies to `Extrapolated` padding.

Implementations may accept a more general `Mu:D` for the first argument so
long as ordinary positional arrays, nested arrays, and sparse arrays have the
same behavior.

## Padding Amounts

Padding amounts are specified in array-dimension order, from the outermost
level inward.

| Form                                | Meaning                                                                      |
|-------------------------------------|------------------------------------------------------------------------------|
| `Int $m`                            | Add `$m` elements at both ends of every applicable dimension.                |
| `[$m, $n]`                          | Add `$m` at the beginning and `$n` at the end of every applicable dimension. |
| `[$m]`                              | Add `$m` at both ends of the applicable dimension.                           |
| `[[ $m1, $n1 ], [ $m2, $n2 ], ...]` | Specify beginning/end amounts for each dimension.                            |
| `[[ $m1 ], [ $m2 ], ...]`           | Specify symmetric amounts for each dimension.                                |
| `0`                                 | Leave a side unchanged.                                                      |
| Negative amount                     | Remove elements from that side.                                              |

A scalar or a two-element pair applies to every dimension unless explicit
per-dimension nesting is used. For example, `[1, 2]` applies one element at
the beginning and two at the end of every dimension of a matrix, whereas
`[[0, 0], [1, 2]]` applies no row padding and pads columns by one and two.

The number of dimension specifications may be less than the array depth. Only
the specified levels are padded; unspecified inner levels are unchanged. An
empty one-element specification such as `[[1]]` therefore pads only the first
level symmetrically.

Cropping is performed before any positive padding on the same side. Removing
more elements than a dimension contains is an error unless the implementation
explicitly supports empty dimensions as its normal array representation.

## Padding Values and Modes

The third positional argument may be a constant, a positional sequence of
constants, or one of the following canonical mode names. Mode names are
case-sensitive canonical strings.

| Raku value               | Meaning                                                                    |
|--------------------------|----------------------------------------------------------------------------|
| Any value `$c`           | Fill added cells with `$c`.                                                |
| `@constants`             | Repeat the constants cyclically in the padding.                            |
| `'Extrapolated'`         | Polynomially extrapolate values beyond each edge.                          |
| `'Fixed'`                | Repeat the edge value; corners use the corresponding original corner.      |
| `'Periodic'`             | Repeat the complete array cyclically.                                      |
| `'Reflected'`            | Reflect the array at each boundary without repeating the boundary element. |
| `'ReflectedDifferences'` | Reflect edge differences antisymmetrically.                                |
| `'Reversed'`             | Repeat the reversed complete array, including the edge sequence.           |
| `'ReversedDifferences'`  | Repeat reversed edge differences.                                          |
| `'ReversedNegation'`     | Repeat the reversed array after numeric negation.                          |

`Fixed` is value-dependent: every cell added at a corner is copied from the
corresponding corner of the original array, not from the result of padding a
neighboring dimension. This makes multidimensional corners consistent.

`Reversed` repeats the outermost original values as the innermost padding
values. `Reflected` differs by reflecting across the edge without repeating
the edge value. The difference modes operate on adjacent differences rather
than directly on values and then reconstruct the padded sequence. They are
useful for antisymmetric boundary conditions. `ReversedNegation` reverses the
source sequence and negates each value, so it requires a numeric negation
operation.

For a constant or cyclic constant sequence, the selected value is applied
independently at each dimension boundary. For a named mode, the source values
at that boundary determine the generated values.

## Extrapolation

`'Extrapolated'` fits a polynomial to the available edge values and evaluates
it beyond the edge. The `interpolation-order` option selects the polynomial
degree:

```raku
array-pad(@values, [0, 3], 'Extrapolated', :interpolation-order(2));
```

The default order is `1` (linear extrapolation). An order of `0` is constant
extrapolation. A maximal-order sentinel may be represented by `Inf` or a
package-defined `Maximum` value; it uses the greatest order supported by the
available values. The effective order must not exceed the number of usable
source values minus one.

Extrapolation requires values and arithmetic compatible with polynomial
interpolation. Unsupported values or an invalid interpolation order must
produce a typed exception rather than silently selecting another mode.

## Arrays and Dimensions

`array-pad` operates on full arrays at every selected depth. For a rectangular
multidimensional array, each dimension receives its requested beginning and
ending padding. Empty dimensions are normally padded for constant and cyclic
constant padding. Modes that depend on source values, such as `Fixed`, may
only pad nonempty dimensions because no edge value exists otherwise.

Sparse arrays retain their sparse representation when practical. Padding must
preserve explicit non-default values and correctly shift their coordinates;
the implementation may materialize a dense result when the selected padding
mode or return type requires it.

If a single amount or pair is intended to apply to only one dimension of a
multidimensional array, the caller must use an explicit per-dimension
specification. This avoids interpreting `[1, 2]` as row padding when it means
begin/end padding for every dimension.

## Return Value and Errors

The returned value has the same rank as the input, with each selected
dimension length changed by its beginning and ending amounts. Element order
inside the original array is preserved. With no positive or negative amounts,
the result is equivalent to the input in value and shape.

The implementation must reject malformed padding specifications, non-integral
amounts, inconsistent dimension specifications, unsupported mode names,
invalid interpolation orders, and impossible crops with typed exceptions.
It must not mutate the caller's input array.

## Related Operations

For a one-dimensional list, `array-pad(@list, $n)` adds `$n` elements on both
sides and is not the same as padding to a total length. Convenience functions
may be provided as:

```raku
sub pad-left(Positional:D $list, Int:D $length --> Positional:D)
sub pad-right(Positional:D $list, Int:D $length --> Positional:D)
```

These pad to a requested total length, unlike `array-pad`. For example,
`array-pad([1, 2, 3], 5)` adds five elements to each side, while
`pad-left([1, 2, 3], 5)` returns a list of length five.

For a one-dimensional list, the following cropping relations hold:

```raku
array-pad([1, 2, 3, 4], [-2, 0]);
# is equivalent to dropping the first two elements

array-pad([1, 2, 3, 4], [0, -2]);
# is equivalent to dropping the last two elements
```

## Conformance Examples

```raku
array-pad([1, 2, 3], 1);                         # zero padding
array-pad([1, 2, 3], [2, 4]);                    # asymmetric padding
array-pad([1, 2, 3], 2, 'Periodic');             # cyclic array padding
array-pad([1, 2, 3], 2, 'Reflected');            # reflected edges
array-pad([1, 2, 3], 3, 'Extrapolated');         # linear extrapolation
array-pad([1, 5, 7, 8], [0, 3], 'Extrapolated', :interpolation-order(2));

array-pad(
    [[1, 2], [3, 4]],
    [[-1, 2], [1, 3]],
    'Fixed'
);
```
