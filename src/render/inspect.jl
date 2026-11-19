# Inspectors: a node or an arrow in detail.

function results_text(x::NodeSummary)
    ps = Pair{String, String}[]
    for (f, name) in ((:volume, "volume"), (:gravity, "gravity"), (:original_gravity, "original gravity"),
                      (:abv, "ABV"), (:ibu, "IBU"), (:srm, "color"), (:temperature, "temperature"),
                      (:carbonation, "carbonation"), (:mash_ph, "mash pH"))
        v = getfield(x, f)
        v === missing && continue
        push!(ps, name => (f === :srm ? swatch(x.color) * " " : "") * value_text(v))
    end
    return pairs_text(ps)
end

solids_table(c) = table(["Solid", "Amount", "Timing"],
                        [[plain(r.name), value_text(r.amount), r.timing === nothing ? "" : value_text(r.timing)]
                         for r in solid_rows(c)])

liquor_text(c) = pairs_text([r.name => value_text(r.value) for r in liquor_rows(c)
                             if r.name == "temperature" || !iszero(r.value)])

minerals_text(c) = pairs_text([r.ion => value_text(r.concentration) for r in mineral_rows(c)
                               if !iszero(r.concentration)])

# contents: the liquor, the solids and the minerals
function contents_text(c)
    iszero(c) && return block(styled("empty", DIM))
    parts = Any[block(liquor_text(c))]
    isempty(solid_rows(c)) || push!(parts, solids_table(c))
    m = minerals_text(c)
    m == styled("–", DIM) || push!(parts, block(styled("water profile", "bold")) / block(m))
    return reduce(/, parts)
end

# what an arrow moved: its volume, or its mass when it moved no liquid (hops, malt)
moved_text(a::ArrowSummary) = iszero(a.moved_volume) ? value_text(a.moved_mass) : value_text(a.moved_volume)

section(title) = block(styled(title, "bold " * ACCENT))

arrows_text(as::Vector{ArrowSummary}, other) =
    isempty(as) ? styled("–", DIM) :
    join((let t = "$(a.kind) $(other(a))" * (a.index > 1 ? " #$(a.index)" : "") *
                  (a.moved_volume === missing ? "" : "  " * styled(moved_text(a), DIM))
              a.selected ? styled(t, SELECTED) : t
          end for a in as), "\n")

"""
    render_node(s::Session, label; width = 80)

A node in detail: its results, its initial contents (for a lot), its contents and leftover
in the brew (liquor, solids with their timing, water profile), the arrows arriving and
leaving, and its warnings.
"""
function render_node(s::Session, label::Symbol; width::Integer = 80)
    d = node_detail(s, label)
    x = d.summary
    parts = Any[block(results_text(x))]
    if !iszero(d.initial)
        push!(parts, section("initial"), contents_text(d.initial))
    end
    if d.contents !== nothing && x.kind !== :lot
        push!(parts, section("contents"), contents_text(d.contents))
    end
    if d.leftover !== nothing && !iszero(d.leftover)
        push!(parts, section("left over"), contents_text(d.leftover))
    end
    push!(parts, section("from"), block(arrows_text(d.incoming, a -> "← " * plain(a.source))))
    push!(parts, section("to"), block(arrows_text(d.outgoing, a -> "→ " * plain(a.destination))))
    isempty(x.warnings) ||
        push!(parts, section("warnings"), block(join((styled("⚠ " * plain(w), WARNING) for w in x.warnings), "\n")))
    title = plain(":" * String(label)) * (x.vessel === nothing ? "" : "  in the $(plain(x.vessel))")
    return Panel(reduce(/, parts); title, title_style = "bold " * ACCENT, width, fit = false,
                 style = x.selected ? SELECTED : DIM)
end

"""
    render_arrow(s::Session, ref::ArrowRef; width = 80)

An arrow in detail: its fields (those not given are taken from the equipment of the vessel,
or defaults), its duration, and what it moved and released in the brew.
"""
function render_arrow(s::Session, r::ArrowRef; width::Integer = 80)
    a = arrow_summary(s, r)
    arrow = quiver(s)[r.source => r.destination, r.index]
    ps = [f.label => (f.value === nothing ? styled("from the vessel or default", DIM) :
                      f.fraction && f.value isa Real ? fraction_text(f.value) : value_text(f.value))
          for f in fields(arrow)]
    rs = ["duration" => value_text(a.duration)]
    a.moved_volume === missing || push!(rs, "moved" => value_text(a.moved_volume) * ", " * value_text(a.moved_mass))
    a.released_water === missing || iszero(a.released_water) ||
        push!(rs, "evaporated" => value_text(a.released_water))
    a.released_co2 === missing || iszero(a.released_co2) || push!(rs, "CO₂ released" => value_text(a.released_co2))
    body = section("parameters") / block(pairs_text(ps)) / section("in the brew") /
           block(pairs_text(rs))
    title = "$(a.kind)  :$(plain(r.source)) → :$(plain(r.destination))" * (r.index > 1 ? " #$(r.index)" : "")
    return Panel(body; title, title_style = "bold " * ACCENT, width, fit = false,
                 style = a.selected ? SELECTED : DIM)
end
