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

Coming next: the interactive app (`BrewQuiverTerm.run("bitter.quiver.json")`) with
navigation, editing, undo and redo, the timeline and the targets.

## License

MIT.
