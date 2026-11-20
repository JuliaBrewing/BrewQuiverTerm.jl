# Inspectors: a node or an arrow in detail.

function results_text(s, x::NodeSummary)
    ps = Pair{String, String}[]
    for (f, name) in ((:volume, "volume"), (:gravity, "gravity"), (:original_gravity, "original gravity"),
                      (:abv, "ABV"), (:ibu, "IBU"), (:srm, "color"), (:temperature, "temperature"),
                      (:carbonation, "carbonation"), (:mash_ph, "mash pH"))
        v = getfield(x, f)
        v === missing && continue
        push!(ps, name => (f === :srm ? swatch(x.color) * " " : "") * qtext(s, v))
    end
    return pairs_text(ps)
end

solids_table(s, c) = table(["Solid", "Amount", "Timing"],
                           [[plain(r.name), qtext(s, r.amount; role = _solid_role(x)),
                             r.timing === nothing ? "" : qtext(s, r.timing)]
                            for (x, r) in zip(c.solids, solid_rows(c))])
_solid_role(p::Portion) = unit_role(p.ingredient)
_solid_role(x) = :mass

liquor_text(s, c) = pairs_text([r.name => qtext(s, r.value) for r in liquor_rows(c)
                             if r.name == "temperature" || !iszero(r.value)])

minerals_text(c) = pairs_text([r.ion => value_text(r.concentration) for r in mineral_rows(c)
                               if !iszero(r.concentration)])

# contents: the liquor, the solids and the minerals
function contents_block(s, c)
    iszero(c) && return block(styled("empty", DIM))
    parts = Any[block(liquor_text(s, c))]
    isempty(solid_rows(c)) || push!(parts, solids_table(s, c))
    m = minerals_text(c)
    m == styled("–", DIM) || push!(parts, block(styled("water profile", "bold")) / block(m))
    return reduce(/, parts)
end

# what an arrow moved: its volume, or its mass when it moved no liquid (hops, malt)
moved_text(s, a::ArrowSummary) =
    iszero(a.moved_volume) ? qtext(s, a.moved_mass; role = something(amount_role(quiver(s)[a.source].initial), :mass)) :
                             qtext(s, a.moved_volume)

section(title) = block(styled(title, "bold " * ACCENT))

arrows_text(s, as::Vector{ArrowSummary}, other) =
    isempty(as) ? styled("–", DIM) :
    join((let t = "$(a.kind) $(other(a))" * (a.index > 1 ? " #$(a.index)" : "") *
                  (a.moved_volume === missing ? "" : "  " * styled(moved_text(s, a), DIM))
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
    parts = Any[block(results_text(s, x))]
    if !iszero(d.initial)
        push!(parts, section("initial"), contents_block(s, d.initial))
    end
    if d.contents !== nothing && x.kind !== :lot
        push!(parts, section("contents"), contents_block(s, d.contents))
    end
    if d.leftover !== nothing && !iszero(d.leftover)
        push!(parts, section("left over"), contents_block(s, d.leftover))
    end
    push!(parts, section("from"), block(arrows_text(s, d.incoming, a -> "← " * plain(a.source))))
    push!(parts, section("to"), block(arrows_text(s, d.outgoing, a -> "→ " * plain(a.destination))))
    eq = x.vessel === nothing ? nothing : equipment(quiver(s), x.vessel)
    if eq !== nothing
        ps = [f.label => (f.fraction && f.value isa Real ? fraction_text(f.value) : qtext(s, f.value))
              for f in fields(eq) if f.value !== nothing && f.value != ""]
        push!(parts, section("equipment of the $(plain(x.vessel))"), block(pairs_text(ps)))
    end
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
                      f.fraction && f.value isa Real ? fraction_text(f.value) :
                      qtext(s, f.value; role = field_role(quiver(s), r, f)))
          for f in fields(arrow)]
    rs = ["duration" => value_text(a.duration)]
    a.moved_volume === missing || push!(rs, "moved" => qtext(s, a.moved_volume) * ", " * qtext(s, a.moved_mass))
    a.released_water === missing || iszero(a.released_water) ||
        push!(rs, "evaporated" => qtext(s, a.released_water))
    a.released_co2 === missing || iszero(a.released_co2) || push!(rs, "CO₂ released" => qtext(s, a.released_co2))
    body = section("parameters") / block(pairs_text(ps)) / section("in the brew") /
           block(pairs_text(rs))
    title = "$(a.kind)  :$(plain(r.source)) → :$(plain(r.destination))" * (r.index > 1 ? " #$(r.index)" : "")
    return Panel(body; title, title_style = "bold " * ACCENT, width, fit = false,
                 style = a.selected ? SELECTED : DIM)
end

# the role of the units of a field of an arrow: a mass moved from a lot is in the unit of its
# ingredient; otherwise that of the quantity, or of the first unit the field takes
function field_role(q, r::ArrowRef, f::FieldSpec)
    if f.name === :amount && haskey(q, r.source)
        role = amount_role(q[r.source].initial)
        role === nothing || (f.value isa Unitful.Mass || f.value === nothing) && return role
    end
    f.value isa Unitful.Quantity && return unit_role(f.value)
    return isempty(f.units) ? nothing : unit_role(first(f.units))
end
field_role(f::FieldSpec) = f.value isa Unitful.Quantity ? unit_role(f.value) :
                           isempty(f.units) ? nothing : unit_role(first(f.units))
