# `list-convolve`

## Primary Function

```raku
sub list-convolve(
    Mu:D $kernel,
    Mu:D $data,
    Mu:D $alignment = [-1, 1],
    Mu:D $padding = CyclicData,
    Callable:D $multiply = &infix:<*>,
    Callable:D $combine = &infix:<+>,
    Int:D $level = 0
    --> Positional:D
)
```

`list-convolve` slides a kernel across data and combines the products at each
alignment. It works with exact values, approximate numbers, symbolic values,
nested arrays, and sparse arrays. The input values are not modified.

The default operation is equivalent to multiplying corresponding kernel/data
elements with `*` and summing them with `+`. The default alignment
`[-1, 1]` allows no overhang, and the default padding `CyclicData` means that
the data is used cyclically when a requested alignment reaches beyond an edge.
For the two-argument form, the no-overhang result has length
`data-length - kernel-length + 1` in one dimension.

## Calling Forms

The following forms are equivalent to the signature above:

```raku
list-convolve($kernel, $data)
list-convolve($kernel, $data, $alignment)
list-convolve($kernel, $data, $alignment, $padding)
list-convolve($kernel, $data, $alignment, $padding, $multiply, $combine)
list-convolve($kernel, $data, $alignment, $padding, $multiply, $combine, $level)
```

The implementation may additionally expose named arguments
`:multiply`, `:combine`, and `:level`; positional and named forms must have
the same behavior.

## Alignment and Overhang

An alignment is an integer or a two-element positional pair:

```raku
$alignment        # equivalent to [$alignment, $alignment]
[$left, $right]
```

The values identify the kernel element aligned with the first and last data
elements. Kernel indices use the Wolfram-style convention in which `1` is the
first kernel element and `-1` is the last kernel element. The kernel is
advanced one data position between successive output elements.

| Alignment | Meaning |
|---|---|
| `[-1, 1]` | No overhangs; the default. |
| `[-1, -1]` | Maximum overhang at the right end only. |
| `[1, 1]` | Maximum overhang at the left end only. |
| `[1, -1]` | Maximum overhang at both ends. |
| `$k` | Equivalent to `[$k, $k]`; align kernel element `$k` with successive data elements. |

For a pair `[$left, $right]`, the first output includes the first data value
paired with kernel element `$left`, and the last output includes the last data
value paired with kernel element `$right`. The output contains every
successive placement between those boundary alignments. A kernel element that
falls outside the data is resolved by the selected padding policy.

With maximal overhang at only one end, the output has the same length as the
data. With maximal overhang at both ends, it includes the full padded
convolution. In higher dimensions, alignment is a pair of coordinate vectors:

```raku
[[$left-1, $left-2, ...], [$right-1, $right-2, ...]]
```

A scalar alignment pair is broadcast to every dimension. The output shape and
kernel placement are computed independently in each dimension.

## Data Padding

Padding is used only for kernel positions that overhang the data. The padding
argument may be:

| Value | Meaning |
|---|---|
| `CyclicData` | Repeat the data cyclically; the default. |
| Any scalar `$p` | Repeat `$p` at every overhanging position. |
| `@padding` | Repeat the supplied sequence cyclically. |
| `$data` | Treat the data itself as cyclic. |
| `[]` | Do not pad; omit contributions outside the data. |

`CyclicData` is a package sentinel meaning “use `$data` as the padding
sequence”; it is distinct from an arbitrary sequence supplied by the caller.
A padding sequence is applied independently along each dimension. In a
multidimensional convolution, padding data has the same dimensional structure
as the data whenever the boundary requires multidimensional values.

When padding is `[]`, an overhanging kernel position contributes no term. This
is important for custom combine functions: the function is applied only to
terms that exist, rather than to an artificial zero. If no terms exist at an
output position, the result is the identity/empty result defined by the
combine operation, or a typed error when no identity can be inferred.

## Generalized Convolution

The `multiply` callable replaces pairwise multiplication and `combine` replaces
addition:

```raku
my &multiply = -> $kernel-value, $data-value {
    $kernel-value ~ ':' ~ $data-value
};
my &combine = -> @terms { @terms.join('|') };

list-convolve(@kernel, @data, 1, 0, &multiply, &combine);
```

Conceptually, for every output position, the implementation evaluates
`combine` over the sequence produced by applying `multiply` to each aligned
kernel/data pair. The default callables are `*` and `+`.

`combine` must receive terms in kernel traversal order. If it is a variadic
operator rather than a callable accepting a sequence, the implementation may
adapt it, but nested data must retain the kernel's structure. When a custom
combine function is used in place of `+`, explicit nested expressions are
generated to the depth of the kernel so the result preserves that structure.

## Level Selection

The optional `level` selects the array level at which convolution is applied.
Level `0` applies to the outer data and kernel. A positive level applies the
same convolution to the positional arrays found at that depth, preserving
levels outside it. The selected level must exist in both operands and have
compatible shapes.

Level selection is useful for applying a one-dimensional filter independently
to rows, columns, or members of a nested collection. A level-aware result
retains the surrounding array structure.

## Multidimensional Convolution

For multidimensional kernels and data, each kernel coordinate is aligned with
the corresponding data coordinate. The convolution scans the Cartesian grid
of valid placements and combines all aligned kernel/data products at each
output coordinate.

```raku
list-convolve(
    [[1, 1], [1, 1]],
    [[a, b, c], [d, e, f], [g, h, i]]
);
```

An alignment such as `1` is broadcast to all dimensions. To specify different
overhangs per dimension, provide coordinate vectors for the left and right
boundaries. The output dimensions are determined independently in each
dimension, just as in the one-dimensional case.

## Sparse and Structured Data

Sparse arrays are valid kernel or data operands. Implementations should avoid
materializing zero regions when the kernel, padding, and combine operation
permit sparse evaluation. Explicit non-default entries must be included at
their shifted coordinates.

Time-series or other indexed sequence types may be supported through an
adapter. Such an adapter must preserve the source index metadata and return a
time-series result whose values are the same as applying `list-convolve` to
the underlying path.

## Return Value and Errors

The result is a positional sequence or nested positional array with the shape
implied by the alignment and the operands. It contains one combined value per
kernel placement. Symbolic and non-numeric values are preserved when the
custom callables support them.

The implementation must reject malformed kernels, incompatible dimensions,
invalid alignment ranks or kernel indices, invalid padding shapes, unsupported
levels, and missing combine identities with typed exceptions. It must not
silently switch between cyclic padding and no padding.

## Relations

The two-argument form is the standard no-overhang convolution. A maximal
one-sided overhang produces a result as long as the data. With zero padding
and maximal overhang at both ends, coefficient-list convolution can multiply
polynomials and digit-list convolution can multiply integers after carrying.

For a kernel `{1, -1}`, the no-overhang result is the successive first-order
difference according to the package's kernel alignment convention. A moving
average is expressed by a normalized kernel:

```raku
list-convolve([1/2, 1/2], @data);
```

## Conformance Examples

```raku
# Default, no-overhang convolution.
list-convolve([x, y], [a, b, c, d, e, f]);

# Same-length cyclic convolution.
list-convolve([x, y], [a, b, c, d, e, f], 1);

# Align kernel element 2 with successive data elements.
list-convolve([x, y, z], [1, 2, 3, 4, 5, 6], 2);

# Constant and cyclic sequence padding.
list-convolve([x, y, z], [1, 2, 3, 4, 5], 1, 'zzz');
list-convolve([x, y, z], [1, 2, 3, 4, 5], 1, [aa, bb, cc]);

# Polynomial coefficient convolution.
list-convolve([a, b, c], [1, 2, 3, 4], [1, -1], 0);

# Custom operations.
list-convolve([x, y], [1, 2, 3, 4], 1, 0,
    -> $k, $v { $k * $v },
    -> @terms { [+] @terms });
```
