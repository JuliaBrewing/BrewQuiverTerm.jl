# The look of the interface: colors, marks, and the text of values.

# colors of the interface
const ACCENT = "#5fafff"        # titles, borders of the focused panel
const CHANGED = "#ffd75f"       # the nodes that changed in the last step
const SELECTED = "#87d787"      # the selected items
const WARNING = "#ff875f"
const DIM = "#808080"

"""
    render_text(x) -> String

The text of a renderable without its colors and styles (the ANSI codes), e.g. to test what a
rendering function shows.
"""
render_text(x) = Term.remove_ansi(string(x))

# user text (labels, ingredient names) in Term markup: braces would start a style, and
# Term's escaping shows them doubled, so they are shown as parentheses
plain(s) = replace(string(s), '{' => '(', '}' => ')')

styled(s, style) = "{$style}$s{/$style}"

# a swatch of a color, "██" in it
swatch(::Nothing) = "  "
swatch(hex::AbstractString) = styled("██", hex)

# the marks of a node or arrow: selected, changed
mark(selected::Bool, changed::Bool) =
    (selected ? styled("▶", SELECTED) : " ") * (changed ? styled("✱", CHANGED) : " ")

# a label, highlighted when changed, bold when selected
function label_text(label, selected::Bool, changed::Bool)
    t = plain(label)
    changed && (t = styled(t, CHANGED))
    selected && (t = styled(t, "bold"))
    return t
end

# the text of a value: quantities, numbers, timings, priming sugars, ...
value_text(x::Union{Unitful.Quantity, Real, Missing, Nothing, Symbol}) = format(x)
value_text(x::Bool) = string(x)
value_text(x::AbstractString) = plain(x)
value_text(x::Union{Remaining, At}) = format(x)
value_text(x) = plain(string(nameof(typeof(x))))

# a value in the preferred units of a session (or of preferences), for a quantity of `role`
qtext(s, x::Unitful.Quantity; role = unit_role(x)) = plain(format(s, x; role))
qtext(s, t::Union{Remaining, At}; role = nothing) = plain(format(s, t))
qtext(s, x; role = nothing) = value_text(x)

# a fraction as a percentage
fraction_text(x::Real) = format(100x * u"percent")
fraction_text(x) = value_text(x)

# the width of text in Term markup, as shown
textwidth_shown(t) = textwidth(Term.remove_markup(t))

# pad text in Term markup to `w` columns
rpad_shown(t, w) = t * " "^max(0, w - textwidth_shown(t))

# a block of text in Term markup, as wide as its widest line (not wrapped at the width of
# the terminal)
block(t::AbstractString) =
    RenderableText(t; width = max(1, maximum(textwidth_shown, split(t, '\n'))))

# a table of strings (in Term markup) as aligned columns, with a bold header; an empty one
# shows a dim dash. Cells are cut to `maxwidth`, if given, with an ellipsis.
function table(header::Vector{String}, rows::Vector{Vector{String}}; maxwidth = nothing)
    isempty(rows) && return block(styled("–", DIM))
    cut(t) = maxwidth === nothing || textwidth_shown(t) ≤ maxwidth ? t :
             first(Term.remove_markup(t), maxwidth - 1) * "…"
    rows = [map(cut, r) for r in rows]
    ws = [maximum(textwidth_shown, [header[j]; [r[j] for r in rows]]) for j in eachindex(header)]
    line(cells) = rstrip(join((rpad_shown(c, w) for (c, w) in zip(cells, ws)), "  "))
    head = styled(line(header), "bold " * ACCENT)
    rule = styled(join(("─"^w for w in ws), "  "), DIM)
    return block(join([head; rule; [line(r) for r in rows]], "\n"))
end

# a list of `name  value` lines
function pairs_text(ps)
    isempty(ps) && return styled("–", DIM)
    w = maximum(length(first(p)) for p in ps)
    return join((styled(rpad(first(p), w), DIM) * "  " * last(p) for p in ps), "\n")
end
