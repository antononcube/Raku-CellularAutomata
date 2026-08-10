use v6.d;

unit module CellularAutomata::Utilities;

#==========================================================
# Array padding helpers
#==========================================================

sub positional(Mu:D $value --> Bool:D) {
    $value ~~ Positional && $value !~~ Str
}

sub local-clone(Mu:D $value --> Mu:D) {
    positional($value) ?? $value.map({ local-clone($_) }).Array !! $value
}

sub local-mod(Int:D $value, Int:D $divisor --> Int:D) {
    (($value % $divisor) + $divisor) % $divisor
}

sub local-pair(Mu:D $value --> List:D) {
    my @values = positional($value) ?? $value.list !! ($value,);
    fail 'Padding side specification must contain one or two integers'
        unless @values.elems == 1 || @values.elems == 2;
    fail 'Padding side specification must contain integers'
        unless @values.grep({ $_ !~~ Int }).elems == 0;
    @values.elems == 1 ?? (@values[0], @values[0]) !! @values.List
}

sub amounts(Mu:D $specification, Int:D $rank --> Array:D) {
    return (^ $rank).map({ local-pair($specification) }).Array
        if $specification ~~ Int;

    fail 'Padding specification must be positional or an integer'
        unless positional($specification);
    my @values = $specification.list;
    fail 'Padding specification cannot be empty' unless @values;
    if @values.grep({ $_ ~~ Positional }).elems == 0 {
        return (^ $rank).map({ local-pair($specification) }).Array;
    }
    if @values.grep({ $_ !~~ Positional }).elems == 0 {
        return @values.map({ local-pair($_) }).Array;
    }
    fail 'Padding specification must contain integers or side pairs';
}

sub fill-like(Mu:D $template, Mu:D $value --> Mu:D) {
    positional($template)
        ?? $template.map({ fill-like($_, $value) }).Array
        !! $value
}

sub local-negate(Mu:D $value --> Mu:D) {
    positional($value)
        ?? $value.map({ local-negate($_) }).Array
        !! -$value
}

sub extrapolated(@values, Int:D $count, Mu:D $order, Bool:D :$left = False --> Array:D) {
    fail 'Extrapolated padding requires numeric values' if @values.grep({ $_ !~~ Numeric }).elems;
    return [] if $count <= 0;
    my $degree = $order == Inf ?? @values.elems - 1 !! $order;
    $degree = 0 max ($degree min (@values.elems - 1));
    my @base = $left ?? @values[0 .. $degree] !! @values[(@values.elems - $degree - 1) .. *];
    my @result;
    for ^$count -> $offset {
        my $x = $left ?? -$offset - 1 !! @base.elems + $offset;
        my $value = 0;
        for @base.kv -> $index, $base-value {
            my $term = $base-value;
            for ^@base.elems -> $other {
                next if $other == $index;
                $term *= ($x - $other) / ($index - $other);
            }
            $value += $term;
        }
        @result.push($value);
    }
    $left ?? @result.reverse.Array !! @result.Array
}

sub difference-padding(@values, Int:D $count, Bool:D :$left = False, Bool:D :$reversed = False --> Array:D) {
    fail 'Difference padding requires numeric values' if @values.grep({ $_ !~~ Numeric }).elems;
    return [] if $count <= 0;
    my @result;
    if $left {
        my $edge = @values[0];
        my $delta = @values.elems > 1 ?? @values[1] - @values[0] !! 0;
        for ^$count {
            $edge -= $delta;
            @result.push($reversed ?? $edge + $delta !! $edge);
        }
    } else {
        my $edge = @values[*-1];
        my $delta = @values.elems > 1 ?? @values[*-1] - @values[*-2] !! 0;
        for ^$count {
            $edge += $delta;
            @result.push($reversed ?? $edge - $delta !! $edge);
        }
    }
    $left ?? @result.reverse.Array !! @result.Array
}

sub padding-item(Mu:D $value, Mu:D $template --> Mu:D) {
    fill-like($template, $value)
}

sub pad-axis(
    @input,
    Int:D $left,
    Int:D $right,
    Mu:D $padding,
    Mu:D $interpolation-order,
    --> Array:D
) {
    my @values = @input.Array;
    my $start = 0 max $left * -1;
    my $end = @values.elems - (0 max $right * -1);
    fail 'Cannot crop more elements than the array contains'
        if $start > $end;
    @values = @values[$start ..^ $end].map({ local-clone($_) }).Array;
    my $template = @values[0] // @input[0] // 0;
    my $mode = $padding ~~ Str ?? $padding !! '';
    my @left-values;
    my @right-values;
    if $left > 0 || $right > 0 {
        if $mode eq 'Extrapolated' {
            @left-values = extrapolated(@values, $left, $interpolation-order, :left);
            @right-values = extrapolated(@values, $right, $interpolation-order);
        } elsif $mode eq 'ReflectedDifferences' || $mode eq 'ReversedDifferences' {
            my $reversed = $mode eq 'ReversedDifferences';
            @left-values = difference-padding(@values, $left, :left, :$reversed);
            @right-values = difference-padding(@values, $right, :$reversed);
        } elsif $mode eq 'Fixed' {
            @left-values = (^$left).map({ local-clone(@values[0] // $template) }).Array;
            @right-values = (^$right).map({ local-clone(@values[*-1] // $template) }).Array;
        } elsif $mode eq 'Periodic' || $mode eq 'Reversed' || $mode eq 'Reflected' || $mode eq 'ReversedNegation' {
            fail 'Named padding requires a nonempty array' unless @values;
            for ^$left -> $index {
                my $source = $mode eq 'Periodic' ?? @values[local-mod($index - $left, @values.elems)]
                    !! $mode eq 'Reversed' ?? @values[local-mod($left - $index - 1, @values.elems)]
                    !! $mode eq 'Reflected' ?? @values[local-mod($index + 1, @values.elems)]
                    !! @values[local-mod($left - $index - 1, @values.elems)];
                @left-values.push($mode eq 'ReversedNegation' ?? local-negate($source) !! local-clone($source));
            }
            for ^$right -> $index {
                my $source = $mode eq 'Periodic' ?? @values[local-mod($index, @values.elems)]
                    !! $mode eq 'Reversed' ?? @values[local-mod(@values.elems - $index - 1, @values.elems)]
                    !! $mode eq 'Reflected' ?? @values[local-mod(@values.elems - $index - 2, @values.elems)]
                    !! @values[local-mod(@values.elems - $index - 1, @values.elems)];
                @right-values.push($mode eq 'ReversedNegation' ?? local-negate($source) !! local-clone($source));
            }
    } elsif positional($padding) {
            fail 'Cyclic padding cannot use an empty sequence' unless $padding.elems;
            @left-values = (^$left).map({ padding-item($padding[local-mod($left - $_ - 1, $padding.elems)], $template) }).Array;
            @right-values = (^$right).map({ padding-item($padding[local-mod($_, $padding.elems)], $template) }).Array;
        } else {
            @left-values = (^$left).map({ padding-item($padding, $template) }).Array;
            @right-values = (^$right).map({ padding-item($padding, $template) }).Array;
        }
    }
    (@left-values, @values, @right-values).flat.Array
}

sub pad-recursive(
    Mu:D $value,
    @amounts,
    Int:D $depth,
    Mu:D $padding,
    Mu:D $interpolation-order
    --> Mu:D
) {
    return local-clone($value) unless positional($value) && $depth < @amounts.elems;
    my @children = $value.list.map({
        pad-recursive($_, @amounts, $depth + 1, $padding, $interpolation-order)
    }).Array;
    pad-axis(@children, @amounts[$depth][0], @amounts[$depth][1], $padding, $interpolation-order)
}

#==========================================================
# Array pad
#==========================================================

#| Pads or crops an array at its selected dimensions.
our proto sub array-pad(|) is export {*}

multi sub array-pad(
    Positional:D $array,
    Mu:D $padding-specification,
    Mu:D $padding = 0,
    Mu:D :$interpolation-order = 1
    --> Positional:D
) {
    my $rank = 1;
    my $probe = $array;
    while positional($probe) && $probe.elems && positional($probe[0]) {
        $rank++;
        $probe = $probe[0];
    }
    pad-recursive($array, amounts($padding-specification, $rank), 0, $padding, $interpolation-order)
}

#==========================================================
# Center array helpers
#==========================================================

sub shape(Mu:D $value --> Array:D) {
    return [] unless positional($value);
    my @children = $value.list;
    return [0] unless @children;
    my @child-shapes = @children.map({ shape($_) });
    my $depth = @child-shapes.map(*.elems).max;
    my @dimensions;
    for ^$depth -> $index {
        @dimensions.push(@child-shapes.map({ $_[$index] // 0 }).max);
    }
    [@children.elems, |@dimensions].Array
}

sub wrap-rank(Mu:D $value, Int:D $extra --> Mu:D) {
    $extra <= 0 ?? $value !! wrap-rank([$value], $extra - 1)
}

sub filled-shape(Mu:D $shape, Int:D $depth, Mu:D $value --> Mu:D) {
    my @shape = $shape.list;
    return local-clone($value) if $depth >= @shape.elems;
    (0 ..^ @shape[$depth]).map({ filled-shape($shape, $depth + 1, $value) }).Array
}

sub rectangularize(Mu:D $value, Mu:D $shape, Int:D $depth, Mu:D $padding --> Mu:D) {
    my @shape = $shape.list;
    return local-clone($value) if $depth >= @shape.elems;
    my @children = positional($value) ?? $value.list !! [];
    my @result = @children.map({ rectangularize($_, $shape, $depth + 1, $padding) }).Array;
    while @result.elems < @shape[$depth] {
        @result.push(filled-shape($shape, $depth + 1, $padding));
    }
    @result[0 ..^ @shape[$depth]].Array
}

sub target-dimensions(Mu:D $specification, @source-shape --> Array:D) {
    my @requested = positional($specification) ?? $specification.list !! ($specification,);
    my @result;
    for @requested.kv -> $index, $requested-dimension {
        if $requested-dimension.isa(Whatever) {
            @result.push(@source-shape[$index])
        } else {
            fail 'Center-array dimensions must be non-negative integers or sentinels'
                unless $requested-dimension ~~ Int && $requested-dimension >= 0;
            @result.push($requested-dimension)
        }
    }
    @result
}

#==========================================================
# Center array
#==========================================================

#| Centers data in an array with the requested dimensions.
our proto sub center-array(|) is export {*}

multi sub center-array(
    Mu:D $dimension-specification,
    Mu:D :$padding = 0,
    Bool:D :$sparse = False,
    Mu:D :$interpolation-order = 1
    --> Positional:D
) {
    my @dimensions = positional($dimension-specification)
        ?? $dimension-specification.list
        !! ($dimension-specification,);
    my $seed = [1];
    center-array($seed, $dimension-specification, $padding, :$sparse, :$interpolation-order)
}

#| Centers data in an array with the requested dimensions.
multi sub center-array(
    Mu:D $array,
    Mu:D $dimension-specification,
    Mu:D $padding = 0,
    Bool:D :$sparse = False,
    Mu:D :$interpolation-order = 1
    --> Positional:D
) {
    my $source = positional($array) ?? local-clone($array) !! [$array];
    my @source-shape = shape($source);
    my @requested = positional($dimension-specification)
        ?? $dimension-specification.list
        !! ($dimension-specification,);
    my $source-rank = @source-shape.elems;
    my $target-rank = @requested.elems;
    if $target-rank > $source-rank {
        $source = wrap-rank($source, $target-rank - $source-rank);
        my @prefix = 1 xx ($target-rank - $source-rank);
        @source-shape = [|@prefix, |@source-shape].Array;
        $source-rank = $target-rank;
    }
    $source = rectangularize($source, item(@source-shape), 0, $padding);
    my @target;
    for @requested.kv -> $index, $requested-dimension {
        if $requested-dimension.isa(Whatever) {
            @target.push(@source-shape[$index]);
        } else {
            fail 'Center-array dimensions must be non-negative integers or sentinels'
                unless $requested-dimension ~~ Int && $requested-dimension >= 0;
            @target.push($requested-dimension);
        }
    }
    @target.append(@source-shape[$target-rank .. *]) if @target.elems < $source-rank;
    my @amounts;
    for ^$target-rank -> $index {
        my $delta = @target[$index] - @source-shape[$index];
        @amounts.push([$delta div 2, $delta - ($delta div 2)]);
    }
    my $amount-specification = @amounts.Array;
    array-pad($source, item($amount-specification), $padding, :$interpolation-order)
}

#==========================================================
# List convolve
#==========================================================

#| Forms the convolution of a kernel with a list.
our proto sub list-convolve($kernel, $data, |) is export {*}


#==========================================================
# Cellar automaton rules from number
#==========================================================

sub cellular-automaton-from-number(UInt:D $rn, Int:D :colors(:$k) = 2, Int:D :$r = 1) is export {
    my $d = 2 * $r + 1;
    my @keys = cross(|((^$k).reverse xx $d));
    my @digits = $rn.base($k).comb;
    if @digits.elems < $k ** $d { @digits = |('0' xx ($k ** $d - @digits.elems)), |@digits }
    my @values = @digits.map(*.Int);
    return @keys Z=> @values;
}
