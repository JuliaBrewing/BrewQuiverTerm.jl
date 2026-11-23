# The interaction loop: read keys, handle them, draw the frame. Kept thin: everything else
# is in app.jl and the rendering functions.

"""
    BrewQuiverTerm.run(path = nothing; library = nothing, theme = theme_name(), colors = color_mode(),
                       input = stdin, output = stdout, size = nothing)

The interactive app on the quiver saved at `path`, or on a BeerJSON recipe imported from it,
or on a new quiver, with the ingredients of the BeerJSON documents `library` (a path or a
vector of paths) to add. Press `?` for the keys. On a terminal, it takes the alternate screen in
raw mode, and gives it back when it quits; `size = (height, width)` overrides the size of
the terminal. Returns the [`App`](@ref) when it quits (or when `input` ends).

The app paints its own background and text colors, those of `theme` (`:dark`, or `:terminal`
for the terminal's own; see [`THEMES`](@ref)), so that the colors of the
terminal's theme do not show through; and it writes 24-bit colors where the terminal shows
them, else the 256 colors of xterm (`colors = :truecolor` or `:ansi256`, see
[`color_mode`](@ref)). The variables `BREWQUIVER_THEME` and `BREWQUIVER_COLORS` set the
defaults.
"""
function run(path::Union{Nothing, AbstractString} = nothing; library = nothing,
             theme::Symbol = theme_name(), colors::Symbol = color_mode(), input::IO = stdin,
             output::IO = stdout, size = nothing)
    haskey(THEMES, theme) || throw(ArgumentError("theme is one of $(join(repr.(sort!(collect(keys(THEMES)))), ", "))"))
    colors in (:truecolor, :ansi256) || throw(ArgumentError("colors is :truecolor or :ansi256"))
    app = App(path === nothing ? Session(Quiver()) : open_file(path))
    try
        set_units!(app.session, load_units())         # (the preferred units, if saved)
    catch e
        e isa ArgumentError || rethrow()
        error!(app, "the preferred units were not read: " * e.msg)
    end
    if library !== nothing
        paths = library isa AbstractString ? [library] : collect(library)
        set_library!(app.session, paths...)
        length(paths) == 1 && (app.library_path = String(only(paths)))
    end
    term = input isa Base.TTY ? REPL.Terminals.TTYTerminal("", input, output, stderr) : nothing
    term === nothing || REPL.Terminals.raw!(term, true)
    print(output, "\e[?1049h\e[?25l")              # the alternate screen, no cursor
    try
        while !app.quit
            h, w = something(size, displaysize(output))
            frame = adapt_colors(render_app(app; width = w, height = h); mode = colors, theme, width = w)
            print(output, theme_codes(theme, colors), "\e[H\e[2J", frame)
            flush(output)
            eof(input) && break
            for key in decode_keys(String(readavailable(input)))
                handle!(app, key)
                app.quit && break
            end
        end
    finally
        print(output, "\e[0m\e[?25h\e[?1049l")
        term === nothing || REPL.Terminals.raw!(term, false)
    end
    return app
end
