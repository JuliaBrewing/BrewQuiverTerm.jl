# The frame of the app: the status bar, the main view of the mode, the message or prompt
# line, and the keys.

const HELP = """
{bold}Moving{/bold}
  ↓ ↑  j k        next, previous node (in the overview), scroll (in the inspector: j k move)
  PgDn PgUp       ten nodes down, up
  g G  Home End   first, last node
  → ←  Tab  Shift-Tab
                  the node, its columns (in the overview) and the arrows leaving it;
                  ↓ ↑ keep the column in the rows that have it
  Space           what the cell, node or arrow is, and what e does to it
  i               inspect the node or arrow
  Esc  q  ←       back to the overview

{bold}Editing{/bold}  (each edit can be undone; the nodes it changed are marked ✱)
  e  Enter        edit: an ingredient (amount, which one; water: volume, temperature,
                  profile), or an arrow (its kind, or a field); on a cell, in place: an
                  ingredient is chosen in a list of those of its kind (typed to search), and a
                  value computed by the brew (gravity, IBU, ...) takes a goal and what to
                  vary to reach it, and is solved for
                  A value proposed (shown in reverse video) is replaced by what is
                  typed, and deleted whole by Backspace; → ← End Home keep it, to change it
  Shift-↓ ↑       on an ingredient's name: the next, previous one of its kind
  a               add an ingredient, chosen in a list (typed to search; the starter library,
                  and yours, see L), then its label and amount (pale malt 4.5 kg: the
                  words of a label are joined by _); water (strike_water 16 L 75 °C); a
                  stage; an ingredient typed (munich 0.5 kg Munich malt, Tab completes);
                  or start from a template (single batch, parti-gyle, ...). An unknown
                  ingredient can be defined there
  E               the equipment of the vessel of the node
  L               load your library of ingredients (a BeerJSON document), on top of the
                  starter library
  c               connect the node to another: its label, and the kind of arrow (wort boil)
  r               rename the node
  v               the vessel of the node
  x  Delete       remove the node (asks first) or the arrow
  u  Ctrl-Z       undo
  U  Ctrl-Y       redo
  h               the history of the edits

{bold}Views{/bold}
  d               the drawing of the quiver, or back to the overview: the stages aligned by
                  vessel; l arranges them with each ingredient next to where it goes, f with
                  all the ingredients first (undoable)
  t               the timeline: when each vessel is busy (+ - zoom on the brew day)
  T               solve: targets (node quantity goal), vary, as many parameters:
                  fermentor gravity 1.050 sg, wort ibu 30 IBU vary pale crystal, cascade
                  (ingredients scaled together, or a field of an arrow: kettle>wort.time)

{bold}Brewing{/bold}
  M               the models: bitterness, color, ABV, gravity (undoable)
  I               the inventory: what the brew needs, with the stock of the library
                  (C takes it from the stock, W writes the library)
  X               export the recipes, as BeerJSON
  P               the units of each kind of quantity (malts, hops, volumes, ...), shown and
                  typed: a number typed without a unit is in the unit shown

{bold}Files{/bold}
  s  Ctrl-S       save
  S               save as
  o  Ctrl-O       open a quiver, or import a BeerJSON recipe

  ?               this help
  q  Ctrl-C       quit (asks about unsaved changes)
"""

# the keys of a mode, as `key => what it does`
hints(::Browse) = ["↓↑" => "move", "←→ Tab" => "columns, arrows", "Space" => "what is it",
                   "Enter e" => "edit", "i" => "inspect", "u" => "undo", "U" => "redo", "?" => "help", "q" => "quit"]
hints(::Inspect) = ["↓↑" => "scroll", "j k" => "move", "Tab" => "arrows", "Enter e" => "edit", "u" => "undo",
                    "U" => "redo", "Esc" => "back", "?" => "help"]
hints(::DagView) = ["↓↑" => "move", "Tab" => "arrows", "Enter e" => "edit", "i" => "inspect", "l" => "arrange", "f" => "ingredients first",
                    "d" => "overview", "u" => "undo", "?" => "help"]
hints(::TimelineView) = ["+ -" => "zoom", "↓↑" => "scroll", "Esc" => "back"]
hints(::InventoryView) = ["C" => "take from the stock", "W" => "write the library", "↓↑" => "scroll",
                          "Esc" => "back"]
hints(::SolutionView) = ["u" => "undo the solve", "Esc" => "back"]
hints(::HistoryView) = ["↓↑" => "scroll", "u" => "undo", "U" => "redo", "Esc" => "back"]
hints(::Help) = ["↓↑" => "scroll", "Esc" => "back"]
hints(::Picker) = ["type" => "search", "↓↑" => "choose", "Enter" => "pick", "Esc" => "cancel"]
hints(p::Prompt) = [p.complete === nothing ? Pair{String, String}[] : ["Tab" => "complete"];
                    p.fresh ? ["type" => "replace", "Bksp" => "clear", "→" => "change"] : Pair{String, String}[];
                    "Enter" => "ok"; "Esc" => "cancel"]

# the second line of keys: the common ones, where the quiver is browsed
const MORE_KEYS = ["a" => "add", "c" => "connect", "x" => "remove", "d" => "drawing", "t" => "timeline",
                   "T" => "solve", "I" => "inventory", "h" => "history", "s" => "save", "o" => "open"]
more_hints(::Union{Browse, Inspect, DagView}) = MORE_KEYS
more_hints(::Mode) = Pair{String, String}[]
hints(c::Confirm) = [[string(k) => label for (k, (label, _)) in c.choices]; "Esc" => "cancel"]

# a key, as a key cap: in reverse video
keycap(k) = styled(" " * plain(k) * " ", "inverse")

# the keys of a mode in a line: each key cap, then what it does; on a narrow screen, the
# hints before the last are dropped until they fit
function hints_text(hints; width = nothing)
    hs = collect(hints)
    text(hs) = join((keycap(k) * " " * plain(what) for (k, what) in hs), "  ")
    while width !== nothing && length(hs) > 1 && textwidth_shown(text(hs)) > width
        deleteat!(hs, length(hs) - 1)
    end
    return text(hs)
end

# the lines of the main view of a mode
main_lines(app::App, ::Browse, width) =
    _lines(render_overview(app.session; width, cell = _cursor_cell(app)))
_cursor_cell(app) = (c = current_column(app); c === nothing ? nothing : (current_node(app), c))
main_lines(app::App, ::Inspect, width) = _lines(_inspector(app, current(app), width))
main_lines(app::App, h::Help, width) = _lines(Panel(block(HELP); title = "keys", width, fit = false,
                                                     title_style = "bold " * ACCENT, style = DIM))
main_lines(app::App, m::Union{Prompt, Confirm}, width) = main_lines(app, m.back, width)
# typed, or chosen, in place
main_lines(app::App, p::Prompt, width) = p.cell === nothing || !(p.back isa Browse) ? main_lines(app, p.back, width) :
    _lines(render_overview(app.session; width, cell = p.cell,
                           edit = _typed(p)))
# the text of a prompt, as typed: the one proposed in reverse video (typing replaces it)
_typed(p::Prompt) = (p.fresh ? styled(plain(p.buffer), "bold inverse") : styled(plain(p.buffer), "bold")) *
                    styled("▏", ACCENT)
function main_lines(app::App, p::Picker, width)
    (p.cell === nothing || !(p.back isa Browse)) && return _lines(render_picker(p; width))
    es = entries(p)
    chosen = isempty(es) ? "nothing matches" : entry_text(p, es[clamp(p.index, 1, length(es))])
    lines = _lines(render_overview(app.session; width, cell = p.cell,
                                   edit = styled("‹ " * plain(chosen) * " ›", "bold " * SELECTED)))
    f = findfirst(l -> occursin("▶", Term.remove_ansi(l)), lines)
    return f === nothing ? lines : _drop_down(lines, p, f)
end
main_lines(app::App, ::HistoryView, width) = _lines(render_history(app.session; width))
main_lines(app::App, ::DagView, width) =
    _lines(Panel(render_dag(app.session; width = width - 6, focus = current_node(app)); title = "quiver",
                 title_style = "bold " * ACCENT, width, fit = false, style = DIM))
main_lines(app::App, v::TimelineView, width) = _lines(render_timeline(app.session; width, zoom = v.zoom))
main_lines(app::App, ::InventoryView, width) = _lines(render_inventory(app.session; width))
main_lines(app::App, v::SolutionView, width) = _lines(render_solution(app.session, v.solution; width))

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
    p.cell === nothing || return styled(plain(p.question), "bold " * ACCENT) * styled("  (typed in place)", DIM)
    line = styled(plain(p.question) * ": ", "bold " * ACCENT) * _typed(p)
    cs = completions(p)
    isempty(cs) || (line *= styled("   Tab: " * plain(join(first(cs, 4), " · ")) * (length(cs) > 4 ? " …" : ""), DIM))
    return line
end
function message_line(app::App, p::Picker)
    n = length(matches(p))
    return styled(plain(p.question) * ": ", "bold " * ACCENT) * plain(p.filter) * styled("▏", ACCENT) *
           styled(isempty(p.filter) ? "  type to search $(length(p.items))" : "  $n of $(length(p.items))", DIM)
end
message_line(app::App, c::Confirm) = styled(plain(c.question), "bold " * WARNING)
message_line(app::App, ::Mode) =
    isempty(app.message) ? "" : styled(plain(app.message), app.iserror ? WARNING : DIM)

"""
    render_app(app::App; width = 100, height = 30) -> String

The frame of the app, `height` lines of `width` columns: the status bar, the main view of
its mode (the overview, scrolled to keep the selection in view, the inspector, the help),
the message or prompt line and two lines of keys: those of the mode, and the common ones. It only changes the scroll of `app`.
"""
function render_app(app::App; width::Integer = 100, height::Integer = 30)
    h = max(1, height - 4)
    lines = main_lines(app, app.mode, width)
    focus = app.mode isa Browse || (app.mode isa Union{Prompt, Confirm, Picker} && app.mode.back isa Browse) ?
        findfirst(l -> occursin("▶", Term.remove_ansi(l)), lines) : nothing
    focus = focus === nothing ? nothing : focus - 1
    # (the list dropping down below a cell in view too)
    app.mode isa Picker && app.mode.cell !== nothing && focus !== nothing &&
        (focus += min(length(entries(app.mode)), LIST_ROWS))
    app.scroll = window(app.scroll, focus, h, length(lines))
    shown = lines[app.scroll+1:min(end, app.scroll + h)]
    append!(shown, fill("", h - length(shown)))
    status = string(render_statusbar(app.session; width))
    msg = string(RenderableText(message_line(app, app.mode); width))
    keys = string(RenderableText(hints_text(hints(app.mode); width); width))
    more = string(RenderableText(hints_text(more_hints(app.mode); width); width))
    return join([first(split(status, '\n')); shown; first(split(msg, '\n')); first(split(keys, '\n'));
                 first(split(more, '\n'))], '\n')
end
