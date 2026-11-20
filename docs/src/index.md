# BrewQuiverTerm.jl

A terminal user interface for [BrewQuiver.jl](https://github.com/JuliaBrewing/BrewQuiver.jl),
the engine that models brewing as a quiver: a directed acyclic multigraph whose nodes are the
contents of vessels at the stages of the brewing, and whose arrows are the processes between
them. It is built with [Term.jl](https://github.com/FedeClaudi/Term.jl) on
[BrewQuiverUICore.jl](https://juliabrewing.github.io/BrewQuiverUICore.jl/dev/), the core it
shares with the graphical interface.

With it you can open a quiver or import a BeerJSON recipe, or start from nothing, and

- see every node with its results (volume, gravity, ABV, IBU, color, temperature, mash pH),
  grouped by vessel, and each node or arrow in detail;
- build and edit the quiver: lots of ingredients (defining new ones as you go), water and its
  profile, stages, arrows, equipment;
- undo and redo every edit, with a history;
- draw the quiver as a graph, see the timeline of the vessels, and solve for targets;
- save, with a question before losing changes.

## Installation and start

The package is under development and not registered. It takes BrewQuiver, its siblings and
BrewQuiverUICore from GitHub through the `[sources]` of its `Project.toml` (Julia 1.11 or
later):

```julia
using Pkg
Pkg.add(url = "https://github.com/JuliaBrewing/BrewQuiverTerm.jl")

using BrewQuiverTerm
BrewQuiverTerm.run("bitter.quiver.json")       # a quiver
BrewQuiverTerm.run("recipe.json")              # a BeerJSON recipe, imported
BrewQuiverTerm.run(; library = "my_ingredients.json")   # a new quiver, with a library
```

Press `?` for the keys, `q` to quit.

## A screen

```@setup home
using BrewQuiverTerm, BrewQuiverUICore, BrewQuiver, Unitful, UnitfulBrewing
include(joinpath(pkgdir(BrewQuiverTerm), "docs", "quivers.jl"))
screen(app; width = 100, height = 30) =
    println(join(rstrip.(split(render_text(render_app(app; width, height)), '\n')), '\n'))
```

```@example home
app = App(Session(single_batch()))
foreach(k -> handle!(app, k), decode_keys("jjjjjjjjjjj"))   # down to the wort
screen(app)
```

`▶` is the cursor, `✱` marks the nodes that changed in the last edit, `⚠` those with
warnings, and `██` is the color of the beer (in color, on a terminal).

Start with the [Tutorial: a batch from scratch](@ref).
