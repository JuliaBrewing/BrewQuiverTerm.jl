# The timeline: when each vessel is busy, as a chart, and when each node is filled, ready
# and emptied.

"""
    clock(t)

A time of the timeline (a time quantity from its start) as a clock reading, as BrewQuiver
writes them: `"8:05"`, or `"3d 14:20"` after the first day.
"""
function clock(t::Unitful.Time)
    m = round(Int, ustrip(u"minute", t))
    sign = m < 0 ? "-" : ""
    d, r = divrem(abs(m), 24 * 60)
    h, mi = divrem(r, 60)
    return string(sign, d > 0 ? "$(d)d " : "", h, ":", lpad(mi, 2, '0'))
end
clock(::Nothing) = "–"

"""
    render_timeline(s::Session; width = 100, start = 0u"minute", zoom = 0)

The timeline of the brew of `s` (from `start`, e.g. `8u"hr"`): a chart of when each vessel
is busy, each node of the vessel a bar of its color from when it starts being filled to
when it is emptied, over the first `1/2^zoom` of the timeline (zoom in to see the brew
day before a long fermentation); the vessels booked for two contents at once; and a table
of when each node is filled, ready and emptied.
"""
function render_timeline(s::Session; width::Integer = 100, start = 0u"minute", zoom::Integer = 0)
    b = vessel_bookings(s; start)
    b === nothing && return Panel(styled("the quiver does not brew: no timeline", WARNING);
                                  title = "timeline", width, fit = false)
    t0 = uconvert(u"minute", float(start))
    t1 = t0 + b.makespan / 2^max(0, zoom)
    names = [plain(v) for (v, _) in b.vessels]
    lw = isempty(names) ? 0 : maximum(textwidth, names)
    cw = max(10, width - lw - 8)                       # the columns of the chart
    col(t) = clamp(floor(Int, cw * (t - t0) / (t1 - t0)), 0, cw)
    lines = String[]
    push!(lines, " "^(lw + 2) * styled(rpad(clock(t0), cw ÷ 2) * lpad(clock(t1), cw - cw ÷ 2), DIM))
    for (v, bookings) in b.vessels
        cells = fill(" ", cw)
        for (k, x) in enumerate(bookings)
            a, z = col(x.from), col(x.to)
            z == a && x.to > x.from && (z = a + 1)
            c = something(node_color(s, x.label), ACCENT)
            ch = isodd(k) ? "█" : "▓"
            for i in a+1:min(z, cw)
                cells[i] = styled(ch, c)
            end
        end
        push!(lines, rpad(plain(v), lw) * "  " * join(cells))
    end
    chart = block(join(lines, '\n'))
    over = isempty(b.overlaps) ? block(styled("no vessel is booked twice at once", DIM)) :
           block(join((styled("⚠ " * plain(_overlap_text(o)), WARNING) for o in b.overlaps), '\n'))
    rows = [[plain(r.label), r.vessel === nothing ? "" : plain(r.vessel), clock(r.arrive), clock(r.ready),
             clock(r.leave)] for r in timeline_rows(s; start)]
    tbl = table(["Node", "Vessel", "Filled", "Ready", "Emptied"], rows)
    body = chart / over / section("nodes") / tbl
    title = "timeline  " * styled("$(format(b.makespan |> _days)) in all", DIM) *
            (zoom > 0 ? styled("  zoom ×$(2^zoom)", DIM) : "")
    return Panel(body; title, title_style = "bold " * ACCENT, width, fit = false, style = DIM)
end

_days(t) = t ≥ 2u"d" ? uconvert(u"d", t) : t ≥ 2u"hr" ? uconvert(u"hr", t) : uconvert(u"minute", t)
_overlap_text((v, a, b)) = "the $v holds :$a and :$b at once"
