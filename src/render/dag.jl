# A drawing of the quiver as a layered graph, from the positions of BrewQuiverUICore: each
# layer a column, each node a dot of its color and its label, the arrows routed in the gaps
# between the columns with box-drawing characters.

# the directions a line leaves a cell, as bits, and the characters drawing them
const _N, _S, _W, _E = 1, 2, 4, 8
const _LINES = Dict(_N | _S => '│', _W | _E => '─', _S | _E => '┌', _S | _W => '┐', _N | _E => '└',
                    _N | _W => '┘', _N | _S | _E => '├', _N | _S | _W => '┤', _S | _W | _E => '┬',
                    _N | _W | _E => '┴', _N | _S | _W | _E => '┼', _N => '│', _S => '│', _W => '─',
                    _E => '─')

"""
    render_dag(s::Session; cell = 14)

A drawing of the quiver of `s` as a layered graph, from `positions(s)` (the nodeview
positions, or the layout of BrewQuiverUICore): each layer a column `cell` characters wide,
each node a dot of its color (`○` for none) and its label, cut to fit; the arrows from left
to right, routed in the gaps between the columns, passing behind the nodes on their way.
The selected node is in reverse video, the nodes changed in the last step highlighted.
Returns a block of text in Term markup.

With a `width`, only that many columns are drawn, around the node `focus` if given (a
third of the way in), else from the left.
"""
function render_dag(s::Session; cell::Integer = 14, width::Union{Nothing, Integer} = nothing,
                    focus::Union{Nothing, Symbol} = nothing)
    q = quiver(s)
    ns = nodes(q)
    isempty(ns) && return block(styled("an empty quiver", DIM))
    pos = positions(s)
    c0 = minimum(round(Int, pos[n][1]) for n in ns)
    r0 = minimum(round(Int, pos[n][2]) for n in ns)
    step = cell + 3                                     # a column, and its gap of 3
    # (1-based columns: the vertical lines in the first of the gap, the arrow head in the
    # second, the node from the third)
    start(n) = (round(Int, pos[n][1]) - c0) * step + 3
    row(n) = 2 * (round(Int, pos[n][2]) - r0) + 1
    text(n) = (t = String(n); "● " * (textwidth(t) ≤ cell - 2 ? t : first(t, cell - 3) * "…"))
    W = maximum(start(n) + textwidth(text(n)) for n in ns)
    height = maximum(row, ns) + 1                       # (and a channel below the last row)
    bits = zeros(Int, height, W)
    heads = falses(height, W)
    hline!(y, from, to) = for x in from:to; bits[y, x] |= _W | _E; end
    # a vertical line at column `x` from row `a` to row `b`, entered from the west at `a`
    # and left to the east at `b`
    function vline!(x, a, b)
        a == b && return (bits[a, x] |= _W | _E)
        down = b > a
        bits[a, x] |= _W | (down ? _S : _N)
        for y in min(a, b)+1:max(a, b)-1
            bits[y, x] |= _N | _S
        end
        bits[b, x] |= (down ? _N : _S) | _E
    end
    for (src, dst) in unique((a, b) for (a, b, _) in arrows(q))
        ys, yd = row(src), row(dst)
        g = start(dst) - 2                              # the column of the vertical line
        x1 = start(src) + textwidth(text(src))
        if round(Int, pos[dst][1]) - round(Int, pos[src][1]) ≤ 1
            # to the next layer: along the row of the source, then up or down
            hline!(ys, x1, g - 1)
            vline!(g, ys, yd)
        else
            # further: into the empty row below (or above) the source in the next gap, along
            # it, so as not to pass behind the nodes of the layers between, then up or down
            ch = yd < ys ? ys - 1 : ys + 1
            g1 = start(src) + step - 2
            hline!(ys, x1, g1 - 1)
            vline!(g1, ys, ch)
            hline!(ch, g1 + 1, g - 1)
            vline!(g, ch, yd)
        end
        heads[yd, g + 1] = true
    end
    grid = [bits[y, x] == 0 ? (heads[y, x] ? "▶" : " ") : string(_LINES[bits[y, x]])
            for y in 1:height, x in 1:W]
    sel = Set(r.label for r in selection(s) if r isa NodeRef)
    for n in ns
        y, x = row(n), start(n)
        t = text(n)
        c = node_color(s, n)
        name = plain(t[nextind(t, 1, 2):end])
        n in changed(s) && (name = styled(name, "bold " * CHANGED))
        n in sel && (name = styled(name, "reverse"))
        grid[y, x] = (c === nothing ? styled("○", DIM) : styled("●", c)) * " " * name
        for k in 1:textwidth(t)-1
            grid[y, x+k] = ""
        end
    end
    # the window of columns shown
    off = width === nothing || W ≤ width ? 0 :
          focus === nothing || !haskey(q, focus) ? 0 : clamp(start(focus) - width ÷ 3, 0, W - width)
    last_col = width === nothing ? W : min(W, off + width)
    for n in ns                                         # (labels cut at the right edge)
        y, x = row(n), start(n)
        if off < x ≤ last_col < x + textwidth(text(n)) - 1
            grid[y, x] = first(text(n), last_col - x + 1)
        end
    end
    shown = grid[:, off+1:last_col]
    return block(join((rstrip(join(shown[y, :])) for y in 1:height), '\n') |> rstrip)
end
