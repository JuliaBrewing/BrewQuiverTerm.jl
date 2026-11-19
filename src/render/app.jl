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
  e               edit: the amount of a lot, or a field of an arrow
  a               add a node: its label, and its vessel if any
  c               connect the node to another: its label, and the kind of arrow if not a transfer
  r               rename the node
  v               the vessel of the node
  x  Delete       remove the node (asks first) or the arrow
  u  Ctrl-Z       undo
  U  Ctrl-Y       redo
  h               the history of the edits

{bold}Files{/bold}
  s  Ctrl-S       save
  S               save as
  o  Ctrl-O       open a quiver, or import a BeerJSON recipe

  ?               this help
  q  Ctrl-C       quit (asks about unsaved changes)
"""

hints(::Browse) = "↓↑ move  Tab arrows  Enter inspect  e edit  u undo  U redo  ? help  q quit"
hints(::Inspect) = "↓↑ scroll  j k move  Tab arrows  e edit  u undo  U redo  Esc back  ? help"
hints(::HistoryView) = "↓↑ scroll  u undo  U redo  any other key: back"
hints(::Help) = "any key: back"
hints(::Prompt) = "Enter: ok  Esc: cancel"
hints(c::Confirm) = join(("$k: $label" for (k, (label, _)) in c.choices), "  ") * "  Esc: cancel"

# the lines of the main view of a mode
main_lines(app::App, ::Browse, width) = _lines(render_overview(app.session; width))
main_lines(app::App, ::Inspect, width) = _lines(_inspector(app, current(app), width))
main_lines(app::App, h::Help, width) = _lines(Panel(block(HELP); title = "keys", width, fit = false,
                                                     title_style = "bold " * ACCENT, style = DIM))
main_lines(app::App, m::Union{Prompt, Confirm}, width) = main_lines(app, m.back, width)
main_lines(app::App, ::HistoryView, width) = _lines(render_history(app.session; width))

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
