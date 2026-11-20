# The interaction loop: read keys, handle them, draw the frame. Kept thin: everything else
# is in app.jl and the rendering functions.

"""
    BrewQuiverTerm.run(path = nothing; library = nothing, input = stdin, output = stdout, size = nothing)

The interactive app on the quiver saved at `path`, or on a BeerJSON recipe imported from it,
or on a new quiver, with the ingredients of the BeerJSON documents `library` (a path or a
vector of paths) to add. Press `?` for the keys. On a terminal, it takes the alternate screen in
raw mode, and gives it back when it quits; `size = (height, width)` overrides the size of
the terminal. Returns the [`App`](@ref) when it quits (or when `input` ends).
"""
function run(path::Union{Nothing, AbstractString} = nothing; library = nothing, input::IO = stdin,
             output::IO = stdout, size = nothing)
    app = App(path === nothing ? Session(Quiver()) : open_file(path))
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
            print(output, "\e[H\e[2J", render_app(app; width = w, height = h))
            flush(output)
            eof(input) && break
            for key in decode_keys(String(readavailable(input)))
                handle!(app, key)
                app.quit && break
            end
        end
    finally
        print(output, "\e[?25h\e[?1049l")
        term === nothing || REPL.Terminals.raw!(term, false)
    end
    return app
end
