use v6.d;

unit module CellularAutomata::Utilities;

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
