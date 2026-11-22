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
const LOT_HEADER = ["", "Lot", "Contents", "Next"]

function stage_row(s, x::NodeSummary, out)
    return [marks(x), label_text(x.label, x.selected, x.changed),
            qtext(s, x.volume), qtext(s, x.gravity), value_text(x.abv), value_text(x.ibu),
            x.srm === missing ? styled("–", DIM) : swatch(x.color) * " " * qtext(s, x.srm),
            qtext(s, x.temperature), value_text(x.mash_ph),
            next_text(out)]
end

lot_row(x::NodeSummary, out) =
    [marks(x), label_text(x.label, x.selected, x.changed), swatch(x.color) * " " * plain(x.contents),
     next_text(out)]

# the marks of a node: selected, changed, warnings
marks(x::NodeSummary) = mark(x.selected, x.changed) * (isempty(x.warnings) ? " " : styled("⚠", WARNING))

"""
    render_overview(s::Session; width = 100)

The overview of the quiver of `s`: a panel for the lots (the nodes in no vessel), with their
contents, and one for each vessel, in topological order, with the results of its nodes
(volume, gravity, ABV, IBU, color, temperature, mash pH) and the arrows leaving them. The
selected items are marked `▶`, the nodes that changed in the last step `✱` and
highlighted, the nodes with warnings `⚠`.
"""
function render_overview(s::Session; width::Integer = 100)
    summaries = Dict(x.label => x for x in node_summaries(s))
    out = Dict{Symbol, Vector{ArrowSummary}}()
    for a in arrow_summaries(s)
        push!(get!(out, a.source, ArrowSummary[]), a)
    end
    panels = Any[]
    for (v, labels) in vessel_groups(s)
        rows = [v === nothing ? lot_row(summaries[n], get(out, n, ArrowSummary[])) :
                                stage_row(s, summaries[n], get(out, n, ArrowSummary[])) for n in labels]
        t = table(v === nothing ? LOT_HEADER : STAGE_HEADER, rows; maxwidth = 40)
        title = v === nothing ? "lots" : plain(v)
        push!(panels, Panel(t; title, title_style = "bold " * ACCENT, width, fit = false,
                            style = DIM))
    end
    isempty(panels) && return Panel(styled("an empty quiver: add a node", DIM); width, title = "quiver")
    return reduce(/, panels)
end
