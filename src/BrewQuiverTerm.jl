"""
    BrewQuiverTerm

A terminal user interface for BrewQuiver, built with Term.jl on BrewQuiverUICore: the
rendering functions take the view data of a session and return Term renderables, so that
they are tested without a terminal; the interaction loop is thin.
"""
module BrewQuiverTerm

using Unitful
using BrewQuiver
using BrewQuiverUICore
using Term: Term, Panel, RenderableText

include("style.jl")
include("render/overview.jl")
include("render/inspect.jl")
include("render/status.jl")

export render_overview, render_node, render_arrow, render_statusbar, render_text

end # module
