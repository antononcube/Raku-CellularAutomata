use v6.d;

unit module CellularAutomata;
use CellularAutomata::Scan;

#| Generates a list representing the evolution of the cellular automaton.
proto sub cellular-automaton(|) is export {*}

multi sub cellular-automaton($rule,
                             $init,
                             $time = 1,
                             :$method = Whatever) {
    given $method {
        when $_.isa(Whatever) || $_ ~~ Str:D && $_.lc eq 'scan' {
            my $obj = CellularAutomata::Scan.new;
            $obj.evolve(:$rule, :$init, :$time)
        }
        when $_ ~~ Str:D && $_.lc eq 'sparse' {
            die 'Method "sparse" is not implemented yet.'
        }
        default {
            die 'The value of $method is expected to be one of "scan", "sparse", or Whatever.'
        }
    }
}

