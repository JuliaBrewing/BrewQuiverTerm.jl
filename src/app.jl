# The state of the interactive app and what each key does, by mode. Pure of the terminal:
# keys in, state changed; the loop in run.jl reads the keys and draws the frames.

"""
    Mode

What the app is doing, which decides what the keys do: [`Browse`](@ref) the overview,
[`Inspect`](@ref) the selected node or arrow, answer a [`Prompt`](@ref) or a
[`Confirm`](@ref)ation, read the [`Help`](@ref).
"""
abstract type Mode end

"""
    Browse()

The overview of the quiver: the keys move the selection between the nodes and their arrows.
"""
struct Browse <: Mode end

"""
    Inspect()

The selected node or arrow in detail.
"""
struct Inspect <: Mode end

"""
    Help(back)

The keys of the app; any key goes `back` to the previous mode.
"""
struct Help <: Mode
    back::Mode
end

"""
    Prompt(question, buffer, submit, back)

A line of text to type, for `question`, starting with `buffer`: Enter calls
`submit(app, text)`, Esc goes `back`.
"""
mutable struct Prompt <: Mode
    question::String
    buffer::String
    submit::Any
    back::Mode
end

"""
    Confirm(question, choices, back)

A question answered with a key: `choices` are `key => (label, action)`, the action called as
`action(app)`; Esc goes `back`.
"""
struct Confirm <: Mode
    question::String
    choices::Vector{Pair{Char, Tuple{String, Any}}}
    back::Mode
end

"""
    App(session)

The state of the interactive app: the `Session` of BrewQuiverUICore being edited
(whose selection is the cursor of the app), the [`Mode`](@ref), the scroll of the main view,
the last message, whether to quit, and the file of the library of ingredients. Keys are given to [`handle!`](@ref), frames drawn
with [`render_app`](@ref).
"""
mutable struct App
    session::Session
    mode::Mode
    scroll::Int
    message::String
    iserror::Bool
    quit::Bool
    # the file of the library of ingredients, to save its stock
    library_path::Union{Nothing, String}
end
App(s::Session) = (app = App(s, Browse(), 0, "", false, false, nothing); _select_first!(app); app)

_select_first!(app) =
    (ns = nodes(quiver(app.session)); isempty(ns) || select!(app.session, NodeRef(first(ns))); app)

info!(app, msg) = (app.message = msg; app.iserror = false; app)
error!(app, msg) = (app.message = msg; app.iserror = true; app)

# run `f()`, showing the errors a user can cause as messages
function attempt(f, app)
    try
        f()
    catch e
        e isa InterruptException && rethrow()
        e isa Union{CommandError, ArgumentError, DomainError, SystemError, Base.IOError,
                    ErrorException, Unitful.DimensionError} || rethrow()
        error!(app, _error_message(e))
    end
    return app
end
_error_message(e::CommandError) = sprint(showerror, e)
_error_message(e::ArgumentError) = e.msg
_error_message(e::Exception) = first(sprint(showerror, e), 200)

# ---------------------------------------------------------------------------------------
# the cursor: the primary selection of the session

"""
    current(app) -> Union{Nothing, ItemRef}

The item the cursor is on: the primary (last) selected item of the session.
"""
current(app::App) = (sel = selection(app.session); isempty(sel) ? nothing : last(sel))

# the node of the cursor: the node selected, or the source of the arrow selected
current_node(app::App) = _node(current(app))
_node(::Nothing) = nothing
_node(r::NodeRef) = r.label
_node(r::ArrowRef) = r.source

# move the cursor `step` nodes, in topological order
function move!(app::App, step::Integer)
    ns = nodes(quiver(app.session))
    isempty(ns) && return app
    n = current_node(app)
    i = n === nothing ? 1 : clamp(something(findfirst(==(n), ns), 1) + step, 1, length(ns))
    select!(app.session, NodeRef(ns[i]))
    app.scroll = app.mode isa Inspect ? 0 : app.scroll
    return app
end

# the arrows leaving the node of the cursor, in order
function outgoing(app::App, n::Symbol)
    q = quiver(app.session)
    return [ArrowRef(n, d, i) for d in successors(q, n) for i in eachindex(q[n => d])]
end

# cycle the cursor through the node and the arrows leaving it
function cycle!(app::App, step::Integer)
    n = current_node(app)
    n === nothing && return app
    refs = ItemRef[NodeRef(n); outgoing(app, n)]
    i = something(findfirst(==(current(app)), refs), 1)
    select!(app.session, refs[mod1(i + step, length(refs))])
    app.scroll = 0
    return app
end

# ---------------------------------------------------------------------------------------
# files

"""
    open_file(path) -> Session

A session of the file at `path`: a quiver saved by BrewQuiver, or a BeerJSON document whose
first recipe is imported.
"""
function open_file(path::AbstractString)
    isfile(path) || throw(ArgumentError("there is no file $path"))
    return occursin("\"beerjson\"", read(path, String)) ? import_recipe(path) : open_session(path)
end

function load!(app::App, path::AbstractString)
    s = open_file(path)
    set_library!(s, library(app.session))             # (the library stays loaded)
    set_units!(s, units(app.session))                 # (and so do the units)
    app.session = s
    app.mode = Browse()
    app.scroll = 0
    _select_first!(app)
    info!(app, filepath(s) === nothing ? "imported $(basename(path)): save it as a quiver" :
                                         "opened $(basename(path))")
    return app
end

function save_file!(app::App)
    filepath(app.session) === nothing && return save_as!(app)
    attempt(app) do
        BrewQuiverUICore.save!(app.session)
        info!(app, "saved $(basename(filepath(app.session)))")
    end
end

function save_as!(app::App, then = app -> nothing)
    default = something(filepath(app.session), "quiver.quiver.json")
    app.mode = Prompt("Save as", default, (app, path) -> begin
        BrewQuiverUICore.save!(app.session, path)
        info!(app, "saved $(basename(path))")
        then(app)
    end, app.mode)
    return app
end

# ask before losing unsaved changes, then do `f(app)`
function unless_unsaved(f, app::App, what::AbstractString)
    isdirty(app.session) || return f(app)
    app.mode = Confirm("There are unsaved changes. $what", [
        's' => ("save first", app -> (app.mode = Browse(); _save_then(f, app))),
        'd' => ("discard them", app -> (app.mode = Browse(); f(app))),
        'c' => ("cancel", app -> (app.mode = Browse(); app))], app.mode)
    return app
end
function _save_then(f, app)
    filepath(app.session) === nothing && return save_as!(app, f)
    save_file!(app)
    app.iserror || f(app)
    return app
end

quit!(app::App) = unless_unsaved(app -> (app.quit = true; app), app, "Quit?")

function open_prompt!(app::App, question)
    unless_unsaved(app, "Open another file?") do app
        app.mode = Prompt(question, "", (app, path) -> load!(app, path), Browse())
        app
    end
end

# ---------------------------------------------------------------------------------------
# keys

"""
    handle!(app::App, key)

What `key` (a `Char` or a `Symbol`, see [`decode_keys`](@ref)) does in the current mode of
`app`. Errors a user can cause (a refused edit, a file that cannot be read) become the
message of the app.
"""
handle!(app::App, key) = (app.message = ""; app.iserror = false; handle!(app, app.mode, key); app)

# keys common to browsing and inspecting
function _common!(app::App, key)
    if key in ('j',)
        move!(app, 1)
    elseif key in ('k',)
        move!(app, -1)
    elseif key === :tab
        cycle!(app, 1)
    elseif key === :backtab
        cycle!(app, -1)
    elseif key === '?'
        app.mode = Help(app.mode)
        app.scroll = 0
    elseif key in ('s', :ctrl_s)
        save_file!(app)
    elseif key === 'S'
        save_as!(app)
    elseif key in ('o', :ctrl_o)
        open_prompt!(app, "Open a quiver or a BeerJSON recipe")
    elseif key === :ctrl_c
        quit!(app)
    else
        return _edit_keys!(app, key) || _view_keys!(app, key) || _brewing_keys!(app, key)
    end
    return true
end

function handle!(app::App, ::Browse, key)
    _common!(app, key) && return app
    if key === :down
        move!(app, 1)
    elseif key === :up
        move!(app, -1)
    elseif key === :pagedown
        move!(app, 10)
    elseif key === :pageup
        move!(app, -10)
    elseif key in (:home, 'g')
        move!(app, -typemax(Int) ÷ 2)
    elseif key in (:end, 'G')
        move!(app, typemax(Int) ÷ 2)
    elseif key in (:enter, 'i', :right)
        current(app) === nothing || (app.mode = Inspect(); app.scroll = 0)
    elseif key === 'q'
        quit!(app)
    end
    return app
end

function handle!(app::App, ::Inspect, key)
    _common!(app, key) && return app
    if key === :down
        app.scroll += 1
    elseif key === :up
        app.scroll = max(0, app.scroll - 1)
    elseif key === :pagedown
        app.scroll += 10
    elseif key === :pageup
        app.scroll = max(0, app.scroll - 10)
    elseif key in (:esc, 'q', :left)
        app.mode = Browse()
        app.scroll = 0
    end
    return app
end

function handle!(app::App, h::Help, key)
    if key === :down
        app.scroll += 1
    elseif key === :up
        app.scroll = max(0, app.scroll - 1)
    else
        app.mode = h.back
        app.scroll = 0
    end
    return app
end

function handle!(app::App, p::Prompt, key)
    if key === :enter
        app.mode = p.back
        attempt(() -> p.submit(app, strip(p.buffer)), app)
    elseif key === :esc
        app.mode = p.back
    elseif key === :backspace
        isempty(p.buffer) || (p.buffer = p.buffer[1:prevind(p.buffer, lastindex(p.buffer))])
    elseif key isa Char
        p.buffer *= key
    end
    return app
end

function handle!(app::App, c::Confirm, key)
    if key === :esc
        app.mode = c.back
        return app
    end
    for (k, (_, action)) in c.choices
        key == k && return attempt(() -> action(app), app)
    end
    return app
end
