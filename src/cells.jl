# The cells of the overview: Tab walks the cursor through the columns of a row; `e` edits the
# cell in place (a lot's amount, ingredient, temperature), or for a value computed by the
# brew, sets a goal for it and solves; Space says what the cell is; Shift-↓↑ change the
# ingredient of a lot to the next, previous one of its kind.

# the columns of the row of node `n` in the overview: a lot (a node in no vessel), or a stage
row_columns(s, n::Symbol) = vessel(quiver(s), n) === nothing ? LOT_COLUMNS : STAGE_COLUMNS

"""
    current_column(app) -> Union{Nothing, Symbol}

The column of the cursor in the row of the node it is on, or `nothing` when it is on the
node itself (or on an arrow).
"""
function current_column(app::App)
    r = current(app)
    (r isa NodeRef && app.column !== nothing && app.column in row_columns(app.session, r.label)) || return nothing
    return app.column
end

const COLUMN_NAMES = Dict(:volume => "volume", :gravity => "gravity", :abv => "ABV", :ibu => "bitterness",
                          :color => "color", :temperature => "temperature", :ph => "mash pH",
                          :amount => "amount", :ingredient => "ingredient")

# the computed values that can be solved for: the quantity of a target, and the lots of
# which role are varied by default to reach it
const SOLVABLE = Dict(:volume => (volume, :water), :gravity => (gravity, :fermentable),
                      :abv => (abv, :fermentable), :ibu => (ibu, :hop), :color => (srm, :fermentable))

# the value of a computed column in a node summary
_computed(x::NodeSummary, c::Symbol) =
    c === :color ? x.srm : c === :ph ? x.mash_ph : getfield(x, c)

# put the prompt just opened in the cell `(n, c)` of the overview
_in_place!(app::App, n, c) = (app.mode isa Prompt && (app.mode.cell = (n, c)); app)

# ---------------------------------------------------------------------------------------
# editing a cell

"""
    edit_cell!(app, n, column)

`e` on a cell of the overview: the amount, ingredient (a list of those of its kind) or
temperature of a lot, typed in place; for a value computed by the brew, a goal for it, and
what to vary to reach it, solved.
"""
function edit_cell!(app::App, n::Symbol, c::Symbol)
    row_columns(app.session, n) === STAGE_COLUMNS && return solve_cell!(app, n, c)
    contents = quiver(app.session)[n].initial
    h = holding(contents)
    if c === :amount
        h isa Union{IngredientLot, WaterLot, AgentLot} || return error!(app, _why_not(n, h))
        edit_lot_amount!(app, n, contents, h)
    elseif c === :ingredient
        h isa IngredientLot && return pick_ingredient!(app, n, only(contents.solids).ingredient)
        h isa WaterLot || return error!(app, _why_not(n, h))
        edit_profile!(app, n, contents)
    else
        h isa WaterLot || return error!(app, "only water has a temperature to set: :$n " *
                                             (h isa IngredientLot ? "is at the temperature of what it goes into" : "has none"))
        edit_temperature!(app, n, contents)
    end
    return _in_place!(app, n, c)
end

edit_lot_amount!(app, n, c, ::IngredientLot) =
    edit_amount!(app, n, only(c.solids).amount, unit_role(only(c.solids).ingredient))
edit_lot_amount!(app, n, c, ::WaterLot) = edit_amount!(app, n, uconvert(u"L", volume(c)), :volume)
edit_lot_amount!(app, n, c, ::AgentLot) = edit_amount!(app, n, total_mass(c), :agent)

_why_not(n, ::Stage) = ":$n holds nothing: it is filled by its arrows"
_why_not(n, ::Mixed) = ":$n holds several things: set them on the lots it comes from"
_why_not(n, ::Holding) = ":$n has no such thing to set"

# a computed value: a goal for it, then what to vary to reach it
function solve_cell!(app::App, n::Symbol, c::Symbol)
    haskey(SOLVABLE, c) || return error!(app, "the $(COLUMN_NAMES[c]) of :$n is computed by the brew, and " *
                                              "cannot be solved for: edit the lots and arrows that make it")
    f, role = SOLVABLE[c]
    current = _computed(node_summary(app.session, n), c)
    current = current === missing ? nothing : current
    ask!(app, "Goal for the $(COLUMN_NAMES[c]) of :$n", current === nothing ? "" : qtext(app.session, current)) do app, text
        goal = parse_value(app.session, text, current)
        ask!(app, "Reach $(COLUMN_NAMES[c]) $(qtext(app.session, goal)) at :$n by varying (lots scaled " *
                  "together, or an arrow field: kettle>wort.time)", join(_lots_of(app.session, n, role), " ")) do app, text
            solve!(app, Solve([Target(n, f, goal)], [_parameter(strip(text))]))
        end
    end
    return _in_place!(app, n, c)
end

# the lots upstream of `n` holding an ingredient of `role` (or water, for :water)
function _lots_of(s, n, role)
    q = quiver(s)
    up = _upstream(q, n)
    return [String(l) for l in nodes(q) if l in up && vessel(q, l) === nothing &&
            (h = holding(q[l].initial); role === :water ? h isa WaterLot :
             h isa IngredientLot && unit_role(only(q[l].initial.solids).ingredient) === role)]
end

# the nodes from which `n` can be reached
function _upstream(q, n)
    seen, todo = Set{Symbol}(), [n]
    while !isempty(todo)
        for p in predecessors(q, pop!(todo))
            p in seen || (push!(seen, p); push!(todo, p))
        end
    end
    return seen
end

# ---------------------------------------------------------------------------------------
# the ingredients of a lot

# the ingredients of the kind of `ing` in the catalog of the session, by name
function _same_kind(s, ing)
    role = unit_role(ing)
    return sort!([name for (name, i) in catalog(s) if unit_role(i) === role]; by = lowercase)
end

"""
    Picker(question, items, index, submit, back, cell)

A choice among `items` (strings), from `items[index]`, shown in place in the `cell` of the
overview: ↓↑ move through them, a letter jumps to the next one starting with it, Enter calls
`submit(app, item)`, Esc goes `back`.
"""
mutable struct Picker <: Mode
    question::String
    items::Vector{String}
    index::Int
    submit::Function
    back::Mode
    cell::Tuple{Symbol, Symbol}
end

function pick_ingredient!(app::App, n::Symbol, ing)
    items = _same_kind(app.session, ing)
    i = something(findfirst(==(ing.name), items), 1)
    app.mode = Picker("Ingredient of :$n", items, i, (app, name) -> set_ingredient!(app, n, name),
                      app.mode, (n, :ingredient))
    return app
end

set_ingredient!(app::App, n, name) = edit!(app, SetIngredient(n, catalog(app.session)[name]))

function handle!(app::App, p::Picker, key)
    k = length(p.items)
    if key === :down
        p.index = min(k, p.index + 1)
    elseif key === :up
        p.index = max(1, p.index - 1)
    elseif key === :pagedown
        p.index = min(k, p.index + 10)
    elseif key === :pageup
        p.index = max(1, p.index - 10)
    elseif key === :home
        p.index = 1
    elseif key === :end
        p.index = k
    elseif key === :enter
        app.mode = p.back
        attempt(() -> p.submit(app, p.items[p.index]), app)
    elseif key === :esc
        app.mode = p.back
    elseif key isa Char && isletter(key)
        # the next item starting with the letter, after the current one
        order = [mod1(p.index + j, k) for j in 1:k]
        j = findfirst(i -> startswith(lowercase(p.items[i]), lowercase(key)), order)
        j === nothing || (p.index = order[j])
    end
    return app
end

"""
    next_ingredient!(app, step)

Shift-↓↑ on the ingredient of a lot: the ingredient `step` places after it among those of
its kind (see [`Picker`](@ref)), set at once; consecutive changes are one step of the
history.
"""
function next_ingredient!(app::App, step::Integer)
    n = current_node(app)
    c = n === nothing ? nothing : quiver(app.session)[n].initial
    (current_column(app) === :ingredient && holding(c) isa IngredientLot) ||
        return error!(app, "Shift-↓↑ change the ingredient of a lot: Tab to its ingredient first")
    items = _same_kind(app.session, only(c.solids).ingredient)
    i = something(findfirst(==(only(c.solids).ingredient.name), items), 1)
    j = clamp(i + step, 1, length(items))
    j == i && return info!(app, "no other ingredient of its kind " * (step > 0 ? "after" : "before") * " it")
    return set_ingredient!(app, n, items[j])
end

# ---------------------------------------------------------------------------------------
# Space: what the item of the cursor is, and what `e` does to it

"""
    explain_cell!(app)

Space: says what the cell (or node, or arrow) of the cursor is, and what editing it does.
"""
function explain_cell!(app::App)
    r = current(app)
    r === nothing && return app
    r isa ArrowRef && return info!(app, "the arrow :$(r.source) → :$(r.destination)" *
                                        (r.index > 1 ? " #$(r.index)" : "") * ": e edits its kind or a field")
    n = r.label
    c = current_column(app)
    c === nothing && return info!(app, ":$n: e edits it, Tab walks through its columns and the arrows leaving it")
    name = COLUMN_NAMES[c]
    if row_columns(app.session, n) === STAGE_COLUMNS
        haskey(SOLVABLE, c) && return info!(app, "the $name of :$n is computed by the brew: e sets a goal for " *
                                                 "it, and solves for it by varying lots or an arrow field")
        return info!(app, "the $name of :$n is computed by the brew, from the lots and arrows that make it")
    end
    h = holding(quiver(app.session)[n].initial)
    c === :ingredient && h isa IngredientLot &&
        return info!(app, "the ingredient of :$n: e chooses another of its kind, Shift-↓↑ the next, previous one")
    c === :ingredient && h isa WaterLot &&
        return info!(app, "the water profile of :$n: e edits it, e.g. calcium 50, sulfate 100 (mg/L)")
    c === :temperature && !(h isa WaterLot) && return info!(app, "only water lots have a temperature to set")
    h isa Union{Stage, Mixed} && return info!(app, _why_not(n, h))
    return info!(app, "the $name of :$n: e edits it" *
                      (c === :temperature ? "" : " (a number without a unit is in the unit shown)"))
end
