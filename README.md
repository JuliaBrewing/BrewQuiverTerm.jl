# BrewQuiverTerm

[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaBrewing.github.io/BrewQuiverTerm.jl/dev/) [![CI](https://github.com/JuliaBrewing/BrewQuiverTerm.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/JuliaBrewing/BrewQuiverTerm.jl/actions/workflows/ci.yml)

A terminal user interface for [BrewQuiver.jl](https://github.com/JuliaBrewing/BrewQuiver.jl),
built with [Term.jl](https://github.com/FedeClaudi/Term.jl) on
[BrewQuiverUICore.jl](https://github.com/JuliaBrewing/BrewQuiverUICore.jl), the core it shares
with the graphical interface.

The [documentation](https://JuliaBrewing.github.io/BrewQuiverTerm.jl/dev/) has a tutorial
that builds a batch from scratch with the keys, the views, the keys, and the API reference.

This package is **under development** and not registered. It takes BrewQuiver, its siblings
and BrewQuiverUICore from GitHub through the `[sources]` of `Project.toml` (Julia 1.11 or
later).

## Rendering

The rendering functions are pure: they take a session of BrewQuiverUICore and return Term
renderables, so they are tested without a terminal.

```julia
using BrewQuiverUICore, BrewQuiverTerm

s = open_session("bitter.quiver.json")
print(render_overview(s; width = 110))     # a panel per vessel, with the results of its nodes
print(render_node(s, :kettle))             # a node in detail
print(render_arrow(s, ArrowRef(:kettle, :wort)))
print(render_statusbar(s))
```

```
╭──── kettle ──────────────────────────────────────────────────────────────────────────╮
│       Node     Volume  Gravity   ABV   IBU     Color       Temp.     pH  Next        │
│  ───  ───────  ──────  ────────  ────  ──────  ──────────  ────────  ──  ─────────── │
│   ✱   kettle   27.5 L  1.046 sg  0.0%  0 IBU   ██ 7.5 SRM  71.7 °C   –   Boil → wort │
│  ▶✱   wort     23.5 L  1.054 sg  0.0%  22 IBU  ██ 8.4 SRM  100.0 °C  –   Chill → ... │
╰──────────────────────────────────────────────────────────────────────────────────────╯
```

`▶` marks the selection, `✱` the nodes that changed in the last edit (also highlighted), `⚠`
the nodes with warnings; `██` is the color of the beer.

## The app

```julia
using BrewQuiverTerm
BrewQuiverTerm.run("bitter.quiver.json")     # a quiver; or a BeerJSON recipe, imported; or nothing
```

| keys | |
|---|---|
| `↓` `↑` `j` `k`, `PgDn` `PgUp`, `g` `G` | move between the nodes, in topological order |
| `Tab` `Shift-Tab` | the node and the arrows leaving it |
| `Enter` `i` `→` | inspect the node or arrow (`↓` `↑` scroll, `j` `k` move) |
| `Esc` `q` `←` | back to the overview |
| `s` `Ctrl-S`, `S` | save, save as |
| `o` `Ctrl-O` | open a quiver, or import a BeerJSON recipe |
| `e` | edit the item: a lot of an ingredient (its amount, or its ingredient), water (its volume, temperature, or water profile: `calcium 50, sulfate 100`), a salt or acid (its amount), or an arrow (its kind, or a field chosen by number: `70 min`, `90%`, `at 55 min`, empty for the vessel's or the default) |
| `a` | add a stage (`trub kettle`), a lot of an ingredient (`munich 0.5 kg Munich malt`, `yeast 1 US-05`, `gypsum 4 g gypsum`), or water (`strike_water 16 L 75 °C`); an ingredient not known is defined there (`yield 80%, color 9 °L`) |
| `c` | connect the node to another: its label, and the kind of arrow if not a transfer (`wort boil`) |
| `E` | the equipment of the vessel of the node (capacity, dead space, evaporation, ...) |
| `L` | load a library of ingredients, a BeerJSON document; or `BrewQuiverTerm.run(path; library = "my_ingredients.json")` |
| `r`, `v` | rename the node, set its vessel |
| `x` `Delete` | remove the node (asking first) or the arrow |
| `u` `Ctrl-Z`, `U` `Ctrl-Y` | undo, redo (the selection follows) |
| `h` | the history of the edits |
| `d` | the drawing of the quiver as a layered graph (`l` arranges the nodes, undoably), or back |
| `t` | the timeline: a bar per vessel when it is busy, and when each node is filled, ready and emptied (`+` `-` zoom on the brew day) |
| `T` | solve for targets: `fermentor gravity 1.050 sg, wort ibu 30 IBU vary pale crystal, cascade` (lots scaled together, or a field of an arrow: `kettle>wort.time`); the solution is shown, and `u` undoes it |
| `M` | the models of BrewingFormulas the brew uses: bitterness, color, ABV, gravity (undoable) |
| `I` | the inventory: what the brew needs of each ingredient, with the stock of the library (`C` takes it from the stock, `W` writes the library) |
| `X` | export the recipes of the brew, as BeerJSON |
| `P` | the units of each kind of quantity: malts, hops, yeast, salts, volumes, temperatures, gravities, colors, ... (saved in `~/.config/brewquiver/units.toml`) |
| `?` | the keys |
| `q` `Ctrl-C` | quit, asking about unsaved changes (save, discard, cancel) |

The app is an `App` (a session of BrewQuiverUICore, whose selection is the cursor, and a
mode: `Browse`, `Inspect`, `Prompt`, `Confirm`, `Help`); `handle!(app, key)` does what a key
does in its mode, and `render_app(app; width, height)` draws a frame, so both are tested
with sequences of keys, without a terminal. `BrewQuiverTerm.run` only reads the keys (raw
mode, `decode_keys`), handles them and draws the frames on the alternate screen.

Every edit is a command of BrewQuiverUICore: a refused one (a value in the wrong unit, an
edit after which the quiver would no longer brew) changes nothing and shows why; the nodes
an edit changed are marked `✱` in the overview; the status bar shows what undo would undo.
Values are read with `parse_value`, the inverse of how they are shown. Each kind of quantity
is shown in its preferred unit (`P`: malts in lb, hops in oz, volumes in gal, ...), and a
number typed without a unit is in the unit shown (`25` replacing `27.0 L` is 25 L; `2500 mL`
is read as typed); for an empty field, in the preferred unit of its kind. Ingredients are found
by name (or a part of it) among those of the quiver, of the library, and the salts and acids
of brewing water; so a whole batch can be built from an empty quiver: water, lots, stages in
their vessels, and the arrows between them.

```
  ● pale─────────┬▶○ mash─────────┐ ○ sparge_water─┬▶● grain_bed────┬▶● kettle────────▶● wort ...
                 │                │                ├────────────────┤
  ● crystal──────┤                └▶● rested───────┘ ○ cascade──────┘
                 │
  ○ strike_water─┘
```

The drawing takes the positions of the nodes from BrewQuiverUICore (`positions`: those saved
in the file, or its layered layout): a column per layer, a dot of the color of the beer
before each label, the arrows to the next layer along the row of their source, and longer
ones along the empty rows between, so that they never pass behind a node.

## License

MIT.
