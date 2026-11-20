# Editing: the keys that edit the quiver through the commands of BrewQuiverUICore, with
# undo and redo. Every edit is one command applied to the session; a refused one becomes
# the message of the app.

# apply a command, with its description (or the reason it was refused) as the message
function edit!(app::App, cmd)
    attempt(app) do
        apply!(app.session, cmd)
        info!(app, describe(cmd))
    end
end

# ask for a line of text, then do `f(app, text)`
ask!(f, app::App, question, buffer = "") = (app.mode = Prompt(question, buffer, f, app.mode); app)

# a menu of keys, each closing it before doing its action
function menu!(app::App, question, choices)
    back = app.mode
    app.mode = Confirm(question, [k => (label, app -> (app.mode = back; action(app)))
                                  for (k, (label, action)) in choices], back)
    return app
end

# `e`: edit the item of the cursor (see lots.jl for the nodes)
edit_item!(app::App, ::Nothing) = app
function edit_item!(app::App, r::ArrowRef)
    a = quiver(app.session)[r.source => r.destination, r.index]
    choices = Pair{Char, Tuple{String, Any}}['0' => ("kind", app -> arrow_kind!(app, r))]
    for (i, f) in enumerate(fields(a))
        i ≤ 9 && push!(choices, Char('0' + i) => (f.label, app -> edit_field!(app, r, f)))
    end
    return menu!(app, "Edit which field of the $(nameof(typeof(a)))?", choices)
end

# the kind of an arrow, replaced by a new one of that kind, with its defaults
function arrow_kind!(app::App, r::ArrowRef)
    a = quiver(app.session)[r.source => r.destination, r.index]
    ask!(app, "Kind of :$(r.source) → :$(r.destination) (" * join(sort(collect(keys(ARROW_KINDS))), ", ") * ")",
         lowercase(string(nameof(typeof(a))))) do app, text
        kind = get(ARROW_KINDS, lowercase(strip(text)), nothing)
        kind === nothing && return error!(app, "$(repr(String(strip(text)))) is not a kind of arrow")
        edit!(app, SetArrow(r.source, r.destination, r.index, kind()))
    end
end

function edit_field!(app::App, r::ArrowRef, f::FieldSpec)
    current = f.value === nothing ? "" :
              f.fraction && f.value isa Real ? format(100f.value * u"percent") : format(f.value)
    ask!(app, "$(f.label) of :$(r.source) → :$(r.destination)" * (r.index > 1 ? " #$(r.index)" : ""),
         current) do app, text
        edit!(app, SetArrowField(r.source, r.destination, r.index, f.name, parse_value(text)))
    end
end

# `r`: rename the node of the cursor
function rename_node!(app::App)
    n = current_node(app)
    n === nothing && return app
    ask!(app, "Rename :$n to", String(n)) do app, text
        edit!(app, RenameNode(n, _label(text)))
    end
end

_label(text) = Symbol(strip(lstrip(strip(text), ':')))

# the arrows that can be connected by name, with their defaults
const ARROW_KINDS = Dict("transfer" => Transfer, "drain" => Drain, "mashrest" => MashRest,
                         "boil" => Boil, "chill" => Chill, "ferment" => Ferment, "prime" => Prime,
                         "carbonate" => () -> Carbonate(2.4u"vols"))

# `c`: connect the node of the cursor to another, "destination" or "destination kind"
function connect_node!(app::App)
    n = current_node(app)
    n === nothing && return app
    ask!(app, "Connect :$n to (a node, and the kind of arrow: transfer, drain, boil, ...)") do app, text
        words = split(text)
        isempty(words) && return error!(app, "give the node to connect to")
        kind = length(words) > 1 ? get(ARROW_KINDS, lowercase(words[2]), nothing) : Transfer
        kind === nothing && return error!(app, "$(repr(String(words[2]))) is not a kind of arrow: " *
                                               join(sort(collect(keys(ARROW_KINDS))), ", "))
        edit!(app, Connect(n => _label(words[1]), kind()))
    end
end

# `v`: the vessel of the node of the cursor
function set_vessel!(app::App)
    n = current_node(app)
    n === nothing && return app
    v = vessel(quiver(app.session), n)
    ask!(app, "Vessel of :$n (empty for none)", v === nothing ? "" : String(v)) do app, text
        edit!(app, SetVessel(n, isempty(strip(text)) ? nothing : _label(text)))
    end
end

# `x`: remove the node (after a question) or the arrow of the cursor
remove_item!(app::App, ::Nothing) = app
function remove_item!(app::App, r::NodeRef)
    app.mode = Confirm("Remove :$(r.label) and its arrows?", [
        'y' => ("yes", app -> (app.mode = _back(app); edit!(app, RemoveNode(r.label)))),
        'n' => ("no", app -> (app.mode = _back(app); app))], app.mode)
    return app
end
remove_item!(app::App, r::ArrowRef) = edit!(app, RemoveArrow(r.source, r.destination, r.index))
_back(app) = app.mode isa Confirm ? app.mode.back : app.mode

# `u`, `U`: undo and redo
function undo_step!(app::App)
    d = undo!(app.session)
    d === nothing ? error!(app, "nothing to undo") : info!(app, "undid " * d)
end
function redo_step!(app::App)
    d = redo!(app.session)
    d === nothing ? error!(app, "nothing to redo") : info!(app, "redid " * d)
end

"""
    History(back)

The history of the edits; any key but the arrows goes `back`.
"""
mutable struct HistoryView <: Mode
    back::Mode
end

# the editing keys, common to browsing and inspecting; whether `key` was one
function _edit_keys!(app::App, key)
    if key === 'e'
        edit_item!(app, current(app))
    elseif key === 'r'
        rename_node!(app)
    elseif key === 'a'
        add_node!(app)
    elseif key === 'c'
        connect_node!(app)
    elseif key === 'v'
        set_vessel!(app)
    elseif key in ('x', :delete)
        remove_item!(app, current(app))
    elseif key in ('u', :ctrl_z)
        undo_step!(app)
    elseif key in ('U', :ctrl_y)
        redo_step!(app)
    elseif key === 'h'
        app.mode = HistoryView(app.mode)
        app.scroll = 0
    elseif key === 'E'
        edit_equipment!(app)
    elseif key === 'L'
        load_library!(app)
    else
        return false
    end
    return true
end

function handle!(app::App, h::HistoryView, key)
    if key === :down
        app.scroll += 1
    elseif key === :up
        app.scroll = max(0, app.scroll - 1)
    elseif key in ('u', :ctrl_z)
        undo_step!(app)
    elseif key in ('U', :ctrl_y)
        redo_step!(app)
    else
        app.mode = h.back
        app.scroll = 0
    end
    return app
end
