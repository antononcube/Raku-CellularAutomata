use v6.d;

use CellularAutomata::Utilities;

unit class CellularAutomata::Scan;

sub is-positional(Mu:D $value --> Bool:D) {
    $value ~~ Positional && $value !~~ Str
}

sub local-range(Mu:D $value --> List:D) {
    return ($value, $value) if $value ~~ Int;
    if $value ~~ Rat || $value ~~ Num {
        my $numerator = $value.numerator;
        my $denominator = $value.denominator;
        return ($denominator, $numerator);
    }
    if is-positional($value) && $value.elems == 2 {
        return ($value[0].Int, $value[1].Int);
    }
    fail 'A one-dimensional range must be an integer, rational, or pair.'
}

sub named-rule(Str:D $name --> Mu:D) {
    given $name.lc {
        when 'rule30' { 30 }
        when 'rule90' { 90 }
        when 'rule110' { 110 }
        when 'code1599' { [1599, [3, 1]] }
        default { fail "Unknown cellular automaton rule: $name" }
    }
}

sub rule-model(Mu:D $rule --> Hash:D) {
    my $normalized-rule = $rule ~~ Str ?? named-rule($rule) !! $rule;
    if $normalized-rule ~~ Int {

        fail 'Elementary rule numbers must be between 0 and 255.'
        unless 0 <= $normalized-rule <= 255;

        return { kind => 'number', code => $normalized-rule, colors => 2, left => 1, right => 1 };
    }
    if $normalized-rule ~~ Hash {
        my %rule = $normalized-rule;
        my $dimension = %rule<dimension> // 1;

        fail 'CellularAutomata::Scan supports one-dimensional rules only.'
        unless $dimension == 1;

        my $colors = (%rule<colors> // 2).Int;
        my ($left, $right) = local-range(%rule<range> // 1);
        if %rule<rule-number>:exists {
            return { kind => 'number', code => %rule<rule-number>.Int,
                colors => $colors, left => $left, right => $right };
        }
        if %rule<totalistic-code>:exists {
            return { kind => 'totalistic', code => %rule<totalistic-code>.Int,
                colors => $colors, left => $left, right => $right };
        }
        if (%rule<growth-cases>:exists) || (%rule<growth-survival-cases>:exists)
            || (%rule<growth-decay-cases>:exists) {
            return { kind => 'growth', growth => %rule<growth-cases>,
                survival => %rule<growth-survival-cases>, decay => %rule<growth-decay-cases>,
                colors => 2, left => $left, right => $right };
        }
        fail 'Rule association does not contain a supported one-dimensional rule.'
    }
    if $normalized-rule ~~ Callable {
        return { kind => 'boolean-callable', callable => $normalized-rule,
            colors => 2, left => 1, right => 1 };
    }
    fail 'Unsupported cellular automaton rule.'
}

sub model-from-positional(Mu:D $rule --> Hash:D) {
    my @rule = $rule.list;
    fail 'Rule specification cannot be empty' unless @rule;
    if @rule.all ~~ Pair {
        return { kind => 'replacements', replacements => @rule.Array,
            colors => 2, left => ((@rule[0].key.elems - 1) div 2),
            right => ((@rule[0].key.elems - 1) div 2) };
    }
    if @rule[0] ~~ Callable {
        my ($left, $right) = local-range(@rule[2] // 1);
        return { kind => 'explicit-callable', callable => @rule[0],
            colors => 2, left => $left, right => $right };
    }
    my $code = @rule[0].Int;
    my $colors = 2;
    my ($left, $right) = (1, 1);
    my $kind = 'number';
    my @offsets;
    if @rule[1] ~~ Positional {
        $colors = @rule[1][0].Int;
        $kind = 'totalistic' if @rule[1].elems > 1;
        ($left, $right) = local-range(@rule[2] // 1) if @rule[2]:exists;
    } elsif @rule[1]:exists {
        $colors = @rule[1].Int;
        if @rule[2]:exists && is-positional(@rule[2])
            && @rule[2].elems && @rule[2][0] ~~ Positional {
            @offsets = @rule[2].map({ $_[0].Int }).Array;
            $left = -@offsets.min;
            $right = @offsets.max;
        } else {
            ($left, $right) = local-range(@rule[2] // 1) if @rule[2]:exists;
        }
    }
    my %model = (kind => $kind, code => $code, colors => $colors,
        left => $left, right => $right);
    %model<offsets> = @offsets if @offsets;
    %model
}

sub decode-rule(Mu:D $rule --> Hash:D) {
    return model-from-positional($rule) if is-positional($rule);
    rule-model($rule)
}

sub model-number-value(%model, @neighborhood --> Mu:D) {
    my $base = %model<colors>;
    my $index = 0;
    for @neighborhood -> $value {
        $index = $index * $base + $value.Int;
    }
    (%model<code> div ($base ** $index)) mod $base
}

sub model-totalistic-value(%model, @neighborhood --> Mu:D) {
    my $sum = [+] @neighborhood.map(*.Int);
    my $base = %model<colors>;
    (%model<code> div ($base ** $sum)) mod $base
}

sub model-growth-value(%model, @neighborhood, Mu:D $old --> Int:D) {
    my $count = @neighborhood.grep(* == 1).elems;
    if %model<growth>:defined && %model<growth>.grep(* == $count).elems {
        return 1;
    }
    if %model<survival>:defined && is-positional(%model<survival>) {
        return 1 if $old == 0 && %model<survival>[0].grep(* == $count).elems;
        return 1 if $old == 1 && %model<survival>[1].grep(* == $count).elems;
        return 0;
    }
    if %model<decay>:defined && is-positional(%model<decay>) {
        return 1 if $old == 0 && %model<decay>[0].grep(* == $count).elems;
        return 0 if $old == 1 && %model<decay>[1].grep(* == $count).elems;
    }
    $old.Int
}

sub  model-replacement-value(%model, @neighborhood --> Mu:D) {
    for %model<replacements>.List -> $replacement {
        my @pattern = $replacement.key ~~ Positional ?? $replacement.key.list !! ($replacement.key,);
        next unless @pattern.elems == @neighborhood.elems;
        next unless ([&&] @pattern.kv.map(-> $index, $value { $value === Any ?? True !! $value eqv @neighborhood[$index] }));
        return $replacement.value;
    }
    fail 'No explicit replacement matches the neighborhood.'
}

sub model-call-rule(%model, @neighborhood, Int:D $step --> Mu:D) {
    my &callable = %model<callable>;
    if %model<kind> eq 'explicit-callable' {
        return callable(@neighborhood, $step);
    }
    my $arity = callable.arity;
    $arity >= @neighborhood.elems
        ?? callable(|@neighborhood)
        !! callable(@neighborhood, $step)
}

sub next-state(@state, %model, Int:D $step, Mu:D $background, Bool:D :$cyclic --> Array:D) {
    my $left = %model<left>.Int;
    my $right = %model<right>.Int;
    my @next;
    for ^@state.elems -> $position {
        my @neighborhood;
        my @offsets = %model<offsets> // (-$left .. $right).Array;
        for @offsets -> $offset {
            my $index = $position + $offset;
            if $cyclic {
                my $wrapped-index = (($index mod @state.elems) + @state.elems) mod @state.elems;
                @neighborhood.push(@state[$wrapped-index]);
            } elsif 0 <= $index < @state.elems {
                @neighborhood.push(@state[$index]);
            } else {
                if is-positional($background) {
                    my $wrapped-index = (($index mod $background.elems) + $background.elems) mod $background.elems;
                    @neighborhood.push($background[$wrapped-index]);
                } else {
                    @neighborhood.push($background);
                }
            }
        }
        my $old = @state[$position];
        my $value;
        given %model<kind> {
            when 'number' { $value = model-number-value(%model, @neighborhood) }
            when 'totalistic' { $value = model-totalistic-value(%model, @neighborhood) }
            when 'growth' { $value = model-growth-value(%model, @neighborhood, $old) }
            when 'replacements' { $value =  model-replacement-value(%model, @neighborhood) }
            default { $value = model-call-rule(%model, @neighborhood, $step) }
        }
        @next.push($value);
    }
    @next.Array
}

sub time-selection(Mu:D $time --> Hash:D) {
    if $time ~~ Int {
        return { maximum => $time.Int, selected => (0 .. $time.Int).Array, scalar => False };
    }

    fail 'Time specification must be an integer or positional selector.'
    unless is-positional($time) && $time.elems;

    my @values = $time.list;
    if @values[0] ~~ Positional {
        my @inner = @values[0].list;
        if @inner.elems == 1 {
            return { maximum => @inner[0].Int, selected => [@inner[0].Int], scalar => True };
        }
    }
    if @values.elems == 1 {
        return { maximum => @values[0].Int, selected => [@values[0].Int], scalar => True };
    }
    my $start = @values[0].Int;
    my $end = @values[1].Int;
    my $step = @values[2] // 1;
    fail 'Time selector increment cannot be zero.' if $step == 0;
    my @selected = $start <= $end
        ?? ($start, $start + $step ... $end).grep(* <= $end)
        !! ($start, $start + $step ... $end).grep(* >= $end);
    { maximum => @selected.max, selected => @selected.Array, scalar => False }
}

method evolve(:$rule!, :@init! is copy, :steps(:$time) = 1, *%args --> Mu:D) {
    fail 'evolve requires a rule named :rule' unless $rule.defined;
    my %model = decode-rule($rule);
    my %selection = time-selection($time);
    my $maximum = %selection<maximum>.Int;

    # Redundant with the current signature.
    fail 'Negative evolution steps are not supported by (CellularAutomata::Scan).' if $maximum < 0;

    my $background = %args<background> // 0;
    my $cyclic = (%args<background>:exists).not && !is-positional(@init[0] // Nil);
    my @initial = @init.Array;
    if @init.elems == 2 && is-positional(@init[0]) {
        @initial = @init[0].Array;
        $background = @init[1];
        $cyclic = False;
    }

    fail 'Initial condition must not be empty.' unless @initial.elems;

    my $required-width = @initial.elems + ($cyclic ?? 0 !! ((%model<left> + %model<right>) * $maximum));
    if !$cyclic && @initial.elems < $required-width {
        my $left-padding = %model<left> * $maximum;
        my $right-padding = %model<right> * $maximum;
        @initial = array-pad(item(@initial), [$left-padding, $right-padding], item($background));
    }
    my @states;
    @states.push(item(@initial.Array));
    for 1 .. $maximum -> $step {
        my $current-state = @states[*-1];
        @states.push(item(next-state($current-state, %model, $step, $background, :$cyclic)));
    }
    my @selected = %selection<selected>.map({ @states[$_ // 0] // @states[*-1] }).Array;
    if (%args<space-specification>:exists) || (%args<space>:exists) {
        my $space = %args<space-specification> // %args<space>;
        my ($start, $end) = $space ~~ Int ?? (0, $space) !! is-positional($space) ?? ($space[0], $space[*-1]) !! (0, @states[0].end);
        @selected = @selected.map({ $_[$start .. $end].Array }).Array;
    }

    return %selection<scalar> ?? @selected[0] !! @selected
}
