# Package development prompts

----

## Convert Wolfram Language (WL) function pages into Raku specs

```text
Analyze the text of "./resources/ArrayPad-WL.txt" and derive from a Markdown file that is a corresponding Raku specification. 
For the Raku functions use kebab-case. I.e. The Wolfram Language `ArrayPad` should become `array-pad`.
``` 

----

## Implementation of `array-pad` and `center-array`

```text
Implement the subs `array-pad` and `center-array` in "./CellularAutomata/Utilities.rakumod".
Adhere the to specs "./resources/ArrayPad-Raku.md" and "./resources/CenterArray-Raku.md" respectively.
```

----

## Implementation of `list-convolve`

Is it needed?

----

## Implementation of `CellularAutomata::Scan`

```text
Analyze the specification "./resources/CellularAutomation-Raku.md" and implement method `evolve` of the class 
`CellularAutomata::Scan`. Use only Raku built-in functions and data structures. Implement 1-dimensional rules only.
```
