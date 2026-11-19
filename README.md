# BrewQuiverTerm

[![CI](https://github.com/JuliaBrewing/BrewQuiverTerm.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/JuliaBrewing/BrewQuiverTerm.jl/actions/workflows/ci.yml)

A terminal user interface for [BrewQuiver.jl](https://github.com/JuliaBrewing/BrewQuiver.jl),
built with [Term.jl](https://github.com/FedeClaudi/Term.jl) on
[BrewQuiverUICore.jl](https://github.com/JuliaBrewing/BrewQuiverUICore.jl), the core it shares
with the graphical interface.

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
| `e` | edit: the amount of a lot (`4.8 kg`, `17 L`, `2`), or a field of an arrow, chosen by its number (`70 min`, `90%`, `at 55 min`, empty for the vessel's or the default) |
| `a` | add a node: its label, and its vessel if any (`trub kettle`) |
| `c` | connect the node to another: its label, and the kind of arrow if not a transfer (`wort boil`) |
| `r`, `v` | rename the node, set its vessel |
| `x` `Delete` | remove the node (asking first) or the arrow |
| `u` `Ctrl-Z`, `U` `Ctrl-Y` | undo, redo (the selection follows) |
| `h` | the history of the edits |
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
Values are read with `parse_value`, the inverse of how they are shown.

Coming next: the timeline, the targets, and a drawing of the quiver.

## License

MIT.
