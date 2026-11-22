# Keys

The keys of the app, as `?` shows them:

```@example keys
using BrewQuiverTerm
println(BrewQuiverTerm.Term.remove_markup(BrewQuiverTerm.HELP))
```

## What is typed

Values are read with `parse_value` of BrewQuiverUICore, the inverse of how they are shown:
`4.8 kg`, `17 L`, `95%`, `70 min`, `4 L/h`, `1.050 sg`, `80 °C`, any unit of Unitful or
UnitfulBrewing, a plain number for a count or a fraction, a timing (`10 min remaining`,
`at 55 min`), or nothing (empty, `–`) to leave a field to the vessel or the default.

| prompt | what to type | example |
|---|---|---|
| add a stage | label, and vessel | `trub kettle` |
| add an ingredient (`a i`, after choosing it in the list) | label (of words, joined by `_`), and amount | `pale malt 4.5 kg`, `yeast 1` |
| add an ingredient, typed (`a l`) | label, amount, ingredient (or a part of its name; `Tab` completes it) | `munich 0.5 kg Munich malt`, `yeast 1 US-05`, `gypsum 4 g gypsum` |
| add water | label, volume, and temperature (20 °C if not given) | `strike_water 16 L 75 °C` |
| a new ingredient | its properties, separated by commas | fermentable: `yield 80%, color 9 °L` (also `potential`, `moisture`, `di_ph`, `buffering`, `kind`); hop: `alpha 5%, form pellet`; culture: `attenuation 78%, kind ale, form dry` |
| connect | the destination, and the kind of arrow | `wort boil` |
| water profile | ions and their concentrations, in mg/L | `calcium 50, sulfate 100` |
| solve | targets (node, quantity, goal), `vary`, as many parameters | `fermentor gravity 1.050 sg, wort ibu 30 IBU vary pale crystal, cascade` |

In a solve, the quantities are `gravity`, `og`, `volume`, `ibu`, `srm` (or `color`), `abv`
and `carbonation`; a parameter is lots scaled together (`pale crystal`), or a field of an
arrow, `kettle>wort.time` or `cascade>kettle#2.amount` for the second of two arrows.

## Lists

Ingredients (and templates) are chosen in a list: typing searches it (each word in a name,
those starting with it first), `↓` `↑` choose, `Enter` picks, `Esc` cancels. When what is
typed names none of them, the list ends with `+ define "..."`, to define a new ingredient.
The ingredients are those of the starter library of BrewQuiverUICore (common malts, sugars,
hops and yeasts, with typical values), of your library (`L`, or
`BrewQuiverTerm.run(; library = "my_ingredients.json")`), which wins on equal names, of the
quiver, and the salts and acids of brewing water.
