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
import REPL

include("style.jl")
include("render/overview.jl")
include("render/inspect.jl")
include("render/status.jl")
include("keys.jl")
include("app.jl")
include("render/app.jl")
include("run.jl")

export render_overview, render_node, render_arrow, render_statusbar, render_text
export App, Mode, Browse, Inspect, Help, Prompt, Confirm, handle!, decode_keys, render_app,
    open_file

end # module
