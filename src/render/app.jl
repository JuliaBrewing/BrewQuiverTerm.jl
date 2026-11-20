# The frame of the app: the status bar, the main view of the mode, the message or prompt
# line, and the keys.

const HELP = """
{bold}Moving{/bold}
  ↓ ↑  j k        next, previous node (in the overview), scroll (in the inspector: j k move)
  PgDn PgUp       ten nodes down, up
  g G  Home End   first, last node
  Tab  Shift-Tab  the node and the arrows leaving it
  Enter  i  →     inspect the node or arrow
  Esc  q  ←       back to the overview

{bold}Editing{/bold}  (each edit can be undone; the nodes it changed are marked ✱)
  e               edit: a lot (amount, ingredient; water: volume, temperature, profile),
                  or an arrow (its kind, or a field)
  a               add a stage, a lot of an ingredient (munich 0.5 kg Munich malt), or water
                  (strike_water 16 L 75 °C); an unknown ingredient can be defined there
  E               the equipment of the vessel of the node
  L               load a library of ingredients (a BeerJSON document)
  c               connect the node to another: its label, and the kind of arrow (wort boil)
  r               rename the node
  v               the vessel of the node
  x  Delete       remove the node (asks first) or the arrow
  u  Ctrl-Z       undo
  U  Ctrl-Y       redo
  h               the history of the edits

{bold}Views{/bold}
  d               the drawing of the quiver (l arranges the nodes), or back to the overview
  t               the timeline: when each vessel is busy (+ - zoom on the brew day)
  T               solve: targets (node quantity goal), vary, as many parameters:
                  fermentor gravity 1.050 sg, wort ibu 30 IBU vary pale crystal, cascade
                  (lots scaled together, or a field of an arrow: kettle>wort.time)

{bold}Files{/bold}
  s  Ctrl-S       save
  S               save as
  o  Ctrl-O       open a quiver, or import a BeerJSON recipe

  ?               this help
  q  Ctrl-C       quit (asks about unsaved changes)
"""

hints(::Browse) = "↓↑ move  Tab arrows  Enter inspect  e edit  u undo  U redo  ? help  q quit"
hints(::Inspect) = "↓↑ scroll  j k move  Tab arrows  e edit  u undo  U redo  Esc back  ? help"
hints(::DagView) = "↓↑ j k move  Tab arrows  Enter inspect  l arrange  d overview  e edit  u undo  ? help"
hints(::TimelineView) = "+ - zoom  ↓↑ scroll  any other key: back"
hints(::SolutionView) = "any key: back (u undoes the solve)"
hints(::HistoryView) = "↓↑ scroll  u undo  U redo  any other key: back"
hints(::Help) = "↓↑ scroll  any other key: back"
hints(::Prompt) = "Enter: ok  Esc: cancel"
hints(c::Confirm) = join(("$k: $label" for (k, (label, _)) in c.choices), "  ") * "  Esc: cancel"

# the lines of the main view of a mode
main_lines(app::App, ::Browse, width) = _lines(render_overview(app.session; width))
main_lines(app::App, ::Inspect, width) = _lines(_inspector(app, current(app), width))
main_lines(app::App, h::Help, width) = _lines(Panel(block(HELP); title = "keys", width, fit = false,
                                                     title_style = "bold " * ACCENT, style = DIM))
main_lines(app::App, m::Union{Prompt, Confirm}, width) = main_lines(app, m.back, width)
main_lines(app::App, ::HistoryView, width) = _lines(render_history(app.session; width))
main_lines(app::App, ::DagView, width) =
    _lines(Panel(render_dag(app.session; width = width - 6, focus = current_node(app)); title = "quiver",
                 title_style = "bold " * ACCENT, width, fit = false, style = DIM))
main_lines(app::App, v::TimelineView, width) = _lines(render_timeline(app.session; width, zoom = v.zoom))
main_lines(app::App, v::SolutionView, width) = _lines(render_solution(v.solution; width))

_inspector(app, r::NodeRef, width) = render_node(app.session, r.label; width)
_inspector(app, r::ArrowRef, width) = render_arrow(app.session, r; width)
_inspector(app, ::Nothing, width) = Panel(styled("nothing selected", DIM); width)

_lines(x) = split(string(x), '\n')

# the first line shown of `n`, to keep the line `focus` (or nothing) in a window of `h`
# lines: when it is out of view, it is brought to the middle
function window(scroll, focus, h, n)
    top = clamp(scroll, 0, max(0, n - h))
    (focus === nothing || top ≤ focus < top + h) && return top
    return clamp(focus - h ÷ 2, 0, max(0, n - h))
end

# the bottom line: the prompt being typed, the question asked, or the last message
function message_line(app::App, p::Prompt)
    return styled(plain(p.question) * ": ", "bold " * ACCENT) * plain(p.buffer) * styled("▏", ACCENT)
end
message_line(app::App, c::Confirm) = styled(plain(c.question), "bold " * WARNING)
message_line(app::App, ::Mode) =
    isempty(app.message) ? "" : styled(plain(app.message), app.iserror ? WARNING : DIM)

"""
    render_app(app::App; width = 100, height = 30) -> String

The frame of the app, `height` lines of `width` columns: the status bar, the main view of
its mode (the overview, scrolled to keep the selection in view, the inspector, the help),
the message or prompt line and the keys. It only changes the scroll of `app`.
"""
function render_app(app::App; width::Integer = 100, height::Integer = 30)
    h = max(1, height - 3)
    lines = main_lines(app, app.mode, width)
    focus = app.mode isa Browse || (app.mode isa Union{Prompt, Confirm} && app.mode.back isa Browse) ?
        findfirst(l -> occursin("▶", Term.remove_ansi(l)), lines) : nothing
    focus = focus === nothing ? nothing : focus - 1
    app.scroll = window(app.scroll, focus, h, length(lines))
    shown = lines[app.scroll+1:min(end, app.scroll + h)]
    append!(shown, fill("", h - length(shown)))
    status = string(render_statusbar(app.session; width))
    msg = string(RenderableText(message_line(app, app.mode); width))
    keys = string(RenderableText(styled(hints(app.mode), DIM); width))
    return join([first(split(status, '\n')); shown; first(split(msg, '\n')); first(split(keys, '\n'))], '\n')
end
