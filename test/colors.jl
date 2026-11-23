# The colors for the terminal: 24-bit or the 256 of xterm, and the theme's background.

using BrewQuiverTerm: _xterm256, theme_codes

@testset "Colors" begin
    @test color_mode(Dict("COLORTERM" => "truecolor")) === :truecolor
    @test color_mode(Dict("COLORTERM" => "24bit")) === :truecolor
    @test color_mode(Dict{String, String}()) === :ansi256              # (Terminal.app says nothing)
    @test color_mode(Dict("COLORTERM" => "truecolor", "BREWQUIVER_COLORS" => "256")) === :ansi256
    @test color_mode(Dict("BREWQUIVER_COLORS" => "truecolor")) === :truecolor
    @test theme_name(Dict{String, String}()) === :dark
    @test theme_name(Dict("BREWQUIVER_THEME" => "Terminal")) === :terminal
    @test theme_name(Dict("BREWQUIVER_THEME" => "pink")) === :dark
    # the nearest of xterm's 256: of the cube, or of the grays
    @test _xterm256(0, 0, 0) == 16 && _xterm256(255, 255, 255) == 231
    @test _xterm256(0x87, 0xd7, 0x87) == 114 && _xterm256(0xff, 0x87, 0x5f) == 209
    @test _xterm256(128, 128, 128) == 244 && _xterm256(0x1c, 0x1c, 0x1c) == 234

    f = render_app(App(Session(single_batch())); width = 60, height = 10)
    @test occursin("\e[38;2;", f)                                        # (Term's 24-bit colors)
    a = adapt_colors(f; mode = :ansi256, width = 60)
    @test !occursin(";2;", a) && occursin("\e[38;5;", a)                  # all in the 256
    @test render_text(a) == join(rpad.(split(render_text(f), '\n'), 60), '\n')   # the same text
    ls = split(a, '\n')
    @test all(startswith(l, theme_codes(:dark, :ansi256)) for l in ls)    # each line on the background
    @test !occursin("\e[49m", a) && !occursin("\e[39m", a)               # never the terminal's
    @test all(textwidth(BrewQuiverTerm.Term.remove_ansi(l)) == 60 for l in ls)
    t = adapt_colors(f; mode = :truecolor, theme = :terminal)
    @test t == f                                                          # nothing to change
    @test occursin("\e[48;2;28;28;28m", adapt_colors(f; mode = :truecolor))
    # the app, run with them
    out = IOBuffer()
    BrewQuiverTerm.run(; input = IOBuffer("q"), output = out, size = (10, 60), colors = :ansi256)
    s = String(take!(out))
    @test occursin("\e[48;5;234m", s) && !occursin(";2;", s) && endswith(s, "\e[0m\e[?25h\e[?1049l")
    @test_throws ArgumentError BrewQuiverTerm.run(; input = IOBuffer(""), output = IOBuffer(), theme = :pink)
    @test_throws ArgumentError BrewQuiverTerm.run(; input = IOBuffer(""), output = IOBuffer(), colors = :mono)
end
