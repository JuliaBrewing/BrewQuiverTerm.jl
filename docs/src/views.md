# Views

```@setup views
using BrewQuiverTerm, BrewQuiverUICore, BrewQuiver, Unitful, UnitfulBrewing
include(joinpath(pkgdir(BrewQuiverTerm), "docs", "quivers.jl"))
text(x) = println(join(rstrip.(split(render_text(x), '\n')), '\n'))
s = Session(single_batch())
```

Each view of the app is drawn by a rendering function, which takes a session of
BrewQuiverUICore and returns a Term renderable: they can be used on their own, in the REPL or
in a notebook, and printed in color.

## The overview

[`render_overview`](@ref): a panel for the lots and one for each vessel, in topological
order, with the results of each node and the arrows leaving it.

```@example views
text(render_overview(s; width = 100))
```

## A node, an arrow

[`render_node`](@ref) shows the results of a node, its contents (liquor, solids with their
timing, water profile), what is left over, the arrows in and out, the equipment of its vessel
and its warnings; [`render_arrow`](@ref) the fields of an arrow (with those taken from the
vessel or the defaults), and what it moved and released.

```@example views
text(render_node(s, :grain_bed; width = 80))
```

```@example views
text(render_arrow(s, ArrowRef(:kettle, :wort); width = 80))
```

## The drawing

[`render_dag`](@ref) draws the quiver as a layered graph, from the positions of
BrewQuiverUICore: a column per layer, the arrows to the next layer along the row of their
source, longer ones along the empty rows between, so that they never pass behind a node.

```@example views
text(render_dag(s))
```

## The timeline

[`render_timeline`](@ref): a bar per vessel when it is busy, each node in its color, the
vessels booked twice at once, and when each node is filled, ready and emptied; `zoom` looks
at the start (the brew day before a long fermentation).

```@example views
text(render_timeline(s; width = 100, zoom = 5))
```

## Solutions and history

```@example views
sol = apply!(s, parse_solve("fermentor gravity 1.050 sg, wort ibu 30 IBU vary pale crystal, cascade"))
text(render_solution(sol; width = 90))
```

```@example views
text(render_history(s; width = 80))
```

## The status bar

```@example views
text(render_statusbar(s; width = 100))
```
