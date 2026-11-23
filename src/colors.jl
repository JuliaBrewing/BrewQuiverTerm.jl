# The colors of the frames as the terminal shows them: Term writes 24-bit colors, which
# some terminals do not show (they are turned into the 256 colors of xterm, whose colors 16
# to 255 are the same in every terminal, unlike the 16 of its theme); and the app paints its
# own background and text color, so that the theme of the terminal does not show through.

"""
    color_mode(env = ENV) -> Symbol

The colors the terminal shows: `:truecolor` when it says so (`COLORTERM` is `truecolor` or
`24bit`, as VS Code, iTerm2, Kitty, WezTerm, ... say), else `:ansi256`. The variable
`BREWQUIVER_COLORS` (`truecolor` or `256`) overrides it.
"""
function color_mode(env = ENV)
    c = lowercase(get(env, "BREWQUIVER_COLORS", ""))
    c in ("truecolor", "24bit") && return :truecolor
    c in ("256", "ansi256") && return :ansi256
    return lowercase(get(env, "COLORTERM", "")) in ("truecolor", "24bit") ? :truecolor : :ansi256
end

"""
    THEMES

The backgrounds and text colors of the app, as `(background, text)` in hex: `:dark` (its
own, the default: the colors of the app are made for a dark background); `:terminal` uses
those of the terminal (`nothing`).
"""
const THEMES = Dict{Symbol, Union{Nothing, Tuple{String, String}}}(
    :dark => ("#1c1c1c", "#d0d0d0"), :terminal => nothing)

"""
    theme_name(env = ENV) -> Symbol

The theme of the app: `BREWQUIVER_THEME` (`dark` or `terminal`), else `:dark`.
"""
function theme_name(env = ENV)
    t = Symbol(lowercase(get(env, "BREWQUIVER_THEME", "dark")))
    return haskey(THEMES, t) ? t : :dark
end

_rgb(hex) = (parse(Int, hex[2:3]; base = 16), parse(Int, hex[4:5]; base = 16), parse(Int, hex[6:7]; base = 16))

# the color of xterm's 256 nearest to (r, g, b): of its 6×6×6 cube, or of its grays
function _xterm256(r, g, b)
    levels = (0, 95, 135, 175, 215, 255)
    near(v) = argmin(i -> abs(levels[i] - v), 1:6) - 1
    ci = (near(r), near(g), near(b))
    cube = 16 + 36ci[1] + 6ci[2] + ci[3]
    dc = sum(abs2, (levels[ci[1]+1] - r, levels[ci[2]+1] - g, levels[ci[3]+1] - b))
    k = clamp(round(Int, ((r + g + b) / 3 - 8) / 10), 0, 23)
    gray = 8 + 10k
    dg = sum(abs2, (gray - r, gray - g, gray - b))
    return dg < dc ? 232 + k : cube
end

# the code of a color, foreground or background, in the mode
function _sgr(rgb, bg::Bool, mode)
    mode === :truecolor && return "\e[$(bg ? 48 : 38);2;$(rgb[1]);$(rgb[2]);$(rgb[3])m"
    return "\e[$(bg ? 48 : 38);5;$(_xterm256(rgb...))m"
end

# the codes setting the background and text color of a theme ("" for `:terminal`)
function theme_codes(theme::Symbol, mode::Symbol)
    colors = THEMES[theme]
    colors === nothing && return ""
    return _sgr(_rgb(colors[1]), true, mode) * _sgr(_rgb(colors[2]), false, mode)
end

"""
    adapt_colors(frame; mode = :truecolor, theme = :dark, width = nothing) -> String

The `frame` (with the ANSI codes of Term) for the terminal: its 24-bit colors turned into
the 256 of xterm for `mode = :ansi256`; and with a `theme` (see [`THEMES`](@ref)) its
background and text color painted wherever the frame leaves them to the terminal (each line
padded to `width`, if given, so that the background fills it).
"""
function adapt_colors(frame::AbstractString; mode::Symbol = :truecolor, theme::Symbol = :dark,
                      width::Union{Nothing, Integer} = nothing)
    out = mode === :truecolor ? String(frame) :
        replace(frame, r"\e\[(38|48);2;(\d+);(\d+);(\d+)m" => m -> begin
            c = match(r"\e\[(38|48);2;(\d+);(\d+);(\d+)m", m)
            _sgr(parse.(Int, (c[2], c[3], c[4])), c[1] == "48", mode)
        end)
    colors = THEMES[theme]
    colors === nothing && return out
    bg, fg = _sgr(_rgb(colors[1]), true, mode), _sgr(_rgb(colors[2]), false, mode)
    base = theme_codes(theme, mode)
    # (where the frame gives the colors back to the terminal, the theme's instead)
    out = replace(out, "\e[0m" => "\e[0m" * base, "\e[49m" => bg, "\e[39m" => fg)
    lines = map(split(out, '\n')) do l
        pad = width === nothing ? 0 : max(0, width - textwidth(Term.remove_ansi(l)))
        base * l * " "^pad * "\e[0m"
    end
    return join(lines, '\n')
end
