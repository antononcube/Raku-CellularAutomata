use v6.d;

unit module Sparse;

#| Creates a list or a list of lists with specified elements at the center.
our proto sub center-array(|) is export {*}

#| Forms the convolution of a kernel with a list.
our proto sub list-convolve($kernel, $data, |) is export {*}
