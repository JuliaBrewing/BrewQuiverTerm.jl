# Picking an item in a list: typing searches it, ↓↑ choose, Enter picks. Shown in place in a
# cell of the overview (with the matches dropping down below it), or as a list.

"""
    Picker(question, items; submit, back, cell = nothing, tags = Dict(), search = nothing,
           create = nothing, filter = "", current = nothing)

A choice among `items` (strings), for `question`, starting at `current`: typed letters
search the items (each word in an item, those starting with it first; or `search(text)` gives
the matches in order), ↓↑ choose among the matches, Enter calls `submit(app, item)`, Esc goes
`back`. With a `cell` (`(node, column)`), it is shown in that cell of the overview, else as a
list, with the `tags` of the items (e.g. their kind). With `create`, the matches end with
"define <text>", which calls `create(app, text)`.
"""
mutable struct Picker <: Mode
    question::String
    items::Vector{String}
    tags::Dict{String, String}
    filter::String
    index::Int
    submit::Function
    back::Mode
    cell::Union{Nothing, Tuple{Symbol, Symbol}}
    search::Union{Nothing, Function}
    create::Union{Nothing, Function}
end

function Picker(question, items; submit, back, cell = nothing, tags = Dict{String, String}(),
                search = nothing, create = nothing, filter = "", current = nothing)
    p = Picker(String(question), collect(String, items), Dict{String, String}(tags), String(filter), 1,
               submit, back, cell, search, create)
    i = current === nothing ? nothing : findfirst(==(current), matches(p))
    p.index = something(i, 1)
    return p
end

# the items matching the filter, best first
function matches(p::Picker)
    isempty(strip(p.filter)) && return p.items
    p.search === nothing || return [x for x in p.search(p.filter) if x in p.items]
    return _match(p.items, p.filter)
end

# the items in which each word of `text` is found: those starting with it first, then those
# with a word starting with it, then the others
function _match(items, text)
    t = lowercase(strip(text))
    words = split(t)
    rank(x) = (l = lowercase(x); startswith(l, t) ? 1 :
                                 all(w -> any(startswith(y, w) for y in split(l, r"[\s\-/()]+")), words) ? 2 : 3)
    found = [x for x in items if all(w -> occursin(w, lowercase(x)), words)]
    return sort!(found; by = rank, alg = Base.Sort.DEFAULT_STABLE)
end

# the entries of the list: the matches, and "define" when the text names none of them
const DEFINE = "\0define"
function entries(p::Picker)
    m = matches(p)
    p.create === nothing || isempty(strip(p.filter)) ||
        any(x -> lowercase(x) == lowercase(strip(p.filter)), m) || return [m; DEFINE]
    return m
end
entry_text(p::Picker, x) = x == DEFINE ? "+ define \"$(strip(p.filter))\"" : x

function handle!(app::App, p::Picker, key)
    es = entries(p)
    k = length(es)
    if key === :down
        p.index = min(k, p.index + 1)
    elseif key === :up
        p.index = max(1, p.index - 1)
    elseif key === :pagedown
        p.index = min(k, p.index + 10)
    elseif key === :pageup
        p.index = max(1, p.index - 10)
    elseif key === :enter
        isempty(es) && return error!(app, "nothing matches $(repr(p.filter))")
        app.mode = p.back
        x = es[clamp(p.index, 1, k)]
        attempt(() -> x == DEFINE ? p.create(app, String(strip(p.filter))) : p.submit(app, x), app)
    elseif key === :esc
        app.mode = p.back
    elseif key === :backspace
        isempty(p.filter) || (p.filter = p.filter[1:prevind(p.filter, lastindex(p.filter))]; p.index = 1)
    elseif key isa Char
        p.filter *= key
        p.index = 1
    end
    return app
end

# ---------------------------------------------------------------------------------------
# drawing

const LIST_ROWS = 10          # the matches shown at once

# the window of entries shown: `LIST_ROWS` around the one chosen
function _window(p::Picker)
    es = entries(p)
    top = clamp(p.index - LIST_ROWS ÷ 2, 1, max(1, length(es) - LIST_ROWS + 1))
    return es, top:min(length(es), top + LIST_ROWS - 1)
end

const LIST_BACKGROUND = "on_#303030"

# the line of an entry, `w` wide: its text, then its tag from the column `nw`, the chosen one
# in reverse video; on a background, `bg`, when dropping down over the overview
function _entry_line(p::Picker, es, i, w, nw; bg = false)
    x = es[i]
    name = first(entry_text(p, x), w - 3)
    tag = first(get(p.tags, x, ""), max(0, w - max(nw, length(name) + 2) - 1))
    left = rpad(" " * name, max(nw, length(name) + 2))
    pad = " "^max(0, w - length(left) - length(tag))
    i == p.index && return styled(plain(left * tag * pad), "bold inverse " * SELECTED)
    t = plain(left) * styled(tag, DIM) * pad
    return bg ? styled(t, LIST_BACKGROUND) : t
end

# the column of the tags: after the longest name
_name_width(p::Picker, es) = maximum(x -> length(entry_text(p, x)), es; init = 10) + 3

_list_width(p::Picker) = (es = entries(p);
    clamp(_name_width(p, es) + maximum(x -> length(get(p.tags, x, "")), es; init = 0) + 1, 20, 60))

"""
    render_picker(p::Picker; width = 100)

The list of a [`Picker`](@ref): the entries matching what is typed, around the one chosen.
"""
function render_picker(p::Picker; width::Integer = 100)
    es, r = _window(p)
    w = width - 6
    nw = _name_width(p, es)
    body = isempty(es) ? styled("nothing matches", DIM) : join((_entry_line(p, es, i, w, nw) for i in r), "\n")
    more = isempty(es) ? "" : styled("\n$(length(es) > length(r) ? "… " : "")$(length(matches(p))) " *
                                     "of $(length(p.items))", DIM)
    return Panel(block(body * more); title = plain(p.question), title_style = "bold " * ACCENT,
                 width, fit = false, style = DIM)
end

# the lines of the overview with the entries of the picker dropping down below its cell, on
# the line `f` (1-based), at the column of the chosen item
function _drop_down(lines, p::Picker, f)
    es, r = _window(p)
    isempty(es) && return lines
    stripped = Term.remove_ansi(lines[f])
    at = findfirst('‹', stripped)
    col = at === nothing ? 4 : textwidth(stripped[1:prevind(stripped, at)])
    w = _list_width(p)
    out = copy(lines)
    for (k, i) in enumerate(r)
        j = f + k
        j > length(out) && push!(out, "")
        below = collect(Term.remove_ansi(out[j]))
        length(below) < col + w && append!(below, fill(' ', col + w - length(below)))
        cell = string(RenderableText(_entry_line(p, es, i, w, _name_width(p, es); bg = true); width = w))
        out[j] = String(below[1:col]) * first(split(cell, '\n')) * String(below[col+w+1:end])
    end
    return out
end
