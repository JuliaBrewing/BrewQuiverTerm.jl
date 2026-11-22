# The overview of a quiver: a panel per vessel, in topological order, with the results of
# its nodes and the arrows leaving them.

# the arrows leaving a node: "Boil → wort" for a transformation, "→ grain_bed, kettle" for
# transfers and drains
function next_text(arrows::Vector{<:ArrowSummary})
    isempty(arrows) && return styled("–", DIM)
    sel(a, t) = a.selected ? styled(t, SELECTED) : t
    length(arrows) == 1 && arrows[1].kind ∉ ("Transfer", "Drain") &&
        return sel(arrows[1], "$(arrows[1].kind) → $(plain(arrows[1].destination))")
    return "→ " * join(unique(sel(a, plain(a.destination)) for a in arrows), ", ")
end

const STAGE_HEADER = ["", "Node", "Volume", "Gravity", "ABV", "IBU", "Color", "Temp.", "pH", "Next"]
const LOT_HEADER = ["", "Lot", "Amount", "Ingredient", "Temp.", "Next"]

# the columns of the cells of a row, after its marks and its label (see cells.jl)
const STAGE_COLUMNS = [:volume, :gravity, :abv, :ibu, :color, :temperature, :ph]
const LOT_COLUMNS = [:amount, :ingredient, :temperature]

# the cells of a row, with the cell of `column` highlighted, or replaced by `edit` (the
# text being typed in it)
function _cells(cells, columns, column, edit)
    j = column === nothing ? nothing : findfirst(==(column), columns)
    j === nothing && return cells
    cells = copy(cells)
    cells[j] = edit !== nothing ? edit : styled(Term.remove_markup(cells[j]), "inverse")
    return cells
end

function stage_row(s, x::NodeSummary, out; column = nothing, edit = nothing)
    cells = [qtext(s, x.volume), qtext(s, x.gravity), value_text(x.abv), value_text(x.ibu),
             x.srm === missing ? styled("–", DIM) : swatch(x.color) * " " * qtext(s, x.srm),
             qtext(s, x.temperature), value_text(x.mash_ph)]
    return [marks(x); label_text(x.label, x.selected, x.changed);
            _cells(cells, STAGE_COLUMNS, column, edit); next_text(out)]
end

function lot_row(s, x::NodeSummary, out; column = nothing, edit = nothing)
    cells = lot_cells(s, x, quiver(s)[x.label].initial)
    return [marks(x); label_text(x.label, x.selected, x.changed);
            _cells(cells, LOT_COLUMNS, column, edit); next_text(out)]
end

# the amount, the ingredient and the temperature of a lot, by what it holds (see lots.jl)
function lot_cells(s, x::NodeSummary, c::Contents)
    none = styled("–", DIM)
    h = holding(c)
    if h isa IngredientLot
        p = only(c.solids)
        amount = p.amount isa Real ? (isinteger(p.amount) ? string(Int(p.amount)) : format(p.amount)) * " ×" : qtext(s, p.amount; role = unit_role(p.ingredient))
        return [amount, swatch(x.color) * " " * plain(p.ingredient.name), none]
    elseif h isa WaterLot
        prof = profile_text(profile(c))
        return [qtext(s, uconvert(u"L", volume(c)); role = :volume),
                "water" * (isempty(prof) ? "" : styled(" " * prof, DIM)), qtext(s, c.liquor.temperature)]
    elseif h isa AgentLot
        return [qtext(s, total_mass(c); role = :agent), "salts, acids", none]
    elseif h isa Stage
        return [none, styled("nothing", DIM), none]
    end
    return [qtext(s, total_mass(c)), plain(x.contents), none]
end

# the marks of a node: selected, changed, warnings
marks(x::NodeSummary) = mark(x.selected, x.changed) * (isempty(x.warnings) ? " " : styled("⚠", WARNING))

"""
    render_overview(s::Session; width = 100, cell = nothing, edit = nothing)

The overview of the quiver of `s`: a panel for the lots (the nodes in no vessel), with their
contents, and one for each vessel, in topological order, with the results of its nodes
(volume, gravity, ABV, IBU, color, temperature, mash pH) and the arrows leaving them. The
selected items are marked `▶`, the nodes that changed in the last step `✱` and
highlighted, the nodes with warnings `⚠`. The `cell` `(node, column)` of the cursor is shown
in reverse video, or as the text `edit` (in Term markup) being typed in it.
"""
function render_overview(s::Session; width::Integer = 100, cell = nothing, edit = nothing)
    summaries = Dict(x.label => x for x in node_summaries(s))
    out = Dict{Symbol, Vector{ArrowSummary}}()
    for a in arrow_summaries(s)
        push!(get!(out, a.source, ArrowSummary[]), a)
    end
    panels = Any[]
    for (v, labels) in vessel_groups(s)
        col(n) = cell !== nothing && first(cell) == n ? last(cell) : nothing
        ed(n) = col(n) === nothing ? nothing : edit
        rows = [v === nothing ?
                    lot_row(s, summaries[n], get(out, n, ArrowSummary[]); column = col(n), edit = ed(n)) :
                    stage_row(s, summaries[n], get(out, n, ArrowSummary[]); column = col(n), edit = ed(n))
                for n in labels]
        t = table(v === nothing ? LOT_HEADER : STAGE_HEADER, rows; maxwidth = 40)
        title = v === nothing ? "lots" : plain(v)
        push!(panels, Panel(t; title, title_style = "bold " * ACCENT, width, fit = false,
                            style = DIM))
    end
    isempty(panels) && return Panel(styled("an empty quiver: add a node", DIM); width, title = "quiver")
    return reduce(/, panels)
end
