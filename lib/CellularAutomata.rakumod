use v6.d;

unit module CellularAutomata;
use CellularAutomata::Scan;
use CellularAutomata::Utilities;

#==========================================================
# Cellular automaton
#==========================================================

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

#==========================================================
# Rule table
#==========================================================

#| Generates a text or HTML table representing the given rule.
proto sub rule-table($spec, :$method = Whatever, *%args) is export {*}

multi sub rule-table(UInt:D $rule-id, :$method = Whatever, *%args) {
    rule-table(cellular-automaton-from-number($rule-id), |%args)
}

multi sub rule-table(@rules, :$method = Whatever, *%args) {
    given $method {
        when $_.isa(Whatever) || $_ ~~ Str:D && $_.lc eq 'text' {
            text-rule-table(@rules, |%args)
        }
        when $_ ~~ Str:D && $_.lc eq 'html' {
            html-rule-table(@rules, |%args)
        }
        default {
            die 'The value of the option $method is expected to be one of "html", "text", or Whatever.'
        }
    }
}

sub text-rule-table(@rules, :$one = '■', :$zero = '□') {

    my @a = @rules.map: -> $rule {
        my ($lhs, $rhs) = $rule.kv;
        $lhs.map({ $_ ?? $one !! $zero }).join
    };

    my @b = @rules.map: -> $rule {
        my ($lhs, $rhs) = $rule.kv;
        ' ' ~ ($rhs ?? $one !! $zero) ~ ' '
    };

    @a.join('  ') ~ "\n" ~ @b.join('  ')
}

sub html-rule-table(@rules,
                    UInt:D :$cell-size = 16,
                    Str:D :$one = 'DarkGray',
                    Str:D :$zero = 'Black',
                    Str:D :$border = 'White',
                    Str:D :$background = 'Black') {
    my $cell = -> $v {
        qq:to/HTML/.trim;
        <td style="
            width:{$cell-size}px;
            height:{$cell-size}px;
            border:1px solid $border;
            background:{ $v ?? $one !! $zero };
        "></td>
        HTML
    };

    my @top;
    my @bottom;

    for @rules -> $rule {
        my ($lhs, $rhs) = $rule.kv;

        @top.push(
                '<td><table style="border-collapse:collapse"><tr>'
                        ~ $lhs.map({ $cell($_) }).join
                ~ '</tr></table></td>'
                );

        @bottom.push(
                '<td style="text-align:center"><table style="border-collapse:collapse; margin:auto"><tr>'
                        ~ $cell($rhs)
                ~ '</tr></table></td>'
                );
    }

    qq:to/HTML/;
    <table style="
        border-collapse:separate;
        border-spacing:6px 2px;
        background: $background;
        padding:6px;
    ">
      <tr>
        {@top.join("\n")}
      </tr>
      <tr>
        {@bottom.join("\n")}
      </tr>
    </table>
    HTML
}