"""
    BrewQuiverTerm

A terminal user interface for BrewQuiver, built with Term.jl on BrewQuiverUICore: the
rendering functions take the view data of a session and return Term renderables, so that
they are tested without a terminal; the interaction loop is thin.
"""
module BrewQuiverTerm

using Unitful
using UnitfulBrewing
using BrewingFormulas: ibu, srm, abv
using BrewQuiver
using BrewQuiverUICore
using Term: Term, Panel, RenderableText
import REPL

include("style.jl")
include("colors.jl")
include("render/overview.jl")
include("render/inspect.jl")
include("render/status.jl")
include("keys.jl")
include("app.jl")
include("edit.jl")
include("lots.jl")
include("render/history.jl")
include("render/dag.jl")
include("render/timeline.jl")
include("render/solve.jl")
include("views.jl")
include("brewing.jl")
include("picker.jl")
include("cells.jl")
include("render/app.jl")
include("run.jl")

export render_overview, render_node, render_arrow, render_statusbar, render_text
export render_picker, render_history, render_inventory, render_dag, render_timeline, render_solution, parse_solve, clock
export App, Mode, Browse, Inspect, Help, Prompt, Confirm, HistoryView, DagView, TimelineView,
    SolutionView, InventoryView, Picker, handle!, decode_keys, render_app,
    open_file, adapt_colors, color_mode, theme_name, THEMES

# the API of BrewQuiverUICore (sessions, commands, undo and redo, view data, units, ...),
# so that `using BrewQuiverTerm` is enough to script the app as well as to run it
for name in names(BrewQuiverUICore)
    name === :BrewQuiverUICore || @eval export $name
end

end # module
