# The interactive app: keys, modes, files, frames and the loop, without a terminal.

using BrewQuiverTerm: current, window

type!(app, text) = foreach(k -> handle!(app, k), decode_keys(text))
sel(app) = current(app)

@testset "Keys" begin
    @test decode_keys("ab\r\t\e[A\e[B\e[C\e[D\x7f") ==
          ['a', 'b', :enter, :tab, :up, :down, :right, :left, :backspace]
    @test decode_keys("\e") == [:esc]
    @test decode_keys("\e[5~\e[6~\e[H\e[F\e[Z\e[3~") == [:pageup, :pagedown, :home, :end, :backtab, :delete]
    @test decode_keys("\x1a\x19\x13\x03\x0f") == [:ctrl_z, :ctrl_y, :ctrl_s, :ctrl_c, :ctrl_o]
    @test decode_keys("é/→") == ['é', '/', '→']
    @test decode_keys("\e[99;5Xa") == ['a']                    # unknown sequences dropped
    @test decode_keys("\eOA") == [:up]
end

@testset "App" begin
    @testset "Moving" begin
        app = App(Session(single_batch()))
        @test sel(app) == NodeRef(:pale) && app.mode isa Browse
        type!(app, "j")
        @test sel(app) == NodeRef(:crystal)
        handle!(app, :down); handle!(app, :up); handle!(app, 'k')
        @test sel(app) == NodeRef(:pale)
        handle!(app, :end)
        @test sel(app) == NodeRef(:bottles)
        handle!(app, 'g')
        @test sel(app) == NodeRef(:pale)
        handle!(app, :pagedown)
        @test sel(app) == NodeRef(nodes(quiver(app.session))[11])
        handle!(app, 'G'); handle!(app, :down)
        @test sel(app) == NodeRef(:bottles)                    # stays at the end
        # the arrows of a node
        handle!(app, 'g'); type!(app, "jj")
        @test sel(app) == NodeRef(:cascade)
        handle!(app, :tab)
        @test sel(app) == ArrowRef(:cascade, :kettle, 1)
        handle!(app, :tab)
        @test sel(app) == ArrowRef(:cascade, :kettle, 2)
        handle!(app, :tab)
        @test sel(app) == NodeRef(:cascade)
        handle!(app, :backtab)
        @test sel(app) == ArrowRef(:cascade, :kettle, 2)
        handle!(app, 'j')                                      # from an arrow, to the next node
        @test sel(app) == NodeRef(:yeast)
        # an empty quiver
        e = App(Session(Quiver()))
        @test sel(e) === nothing
        handle!(e, 'j'); handle!(e, :tab); handle!(e, :enter)
        @test sel(e) === nothing && e.mode isa Browse
    end

    @testset "Inspecting and help" begin
        app = App(Session(single_batch()))
        handle!(app, :enter)
        @test app.mode isa Inspect
        handle!(app, :down); handle!(app, :down)
        @test app.scroll == 2
        handle!(app, :up)
        @test app.scroll == 1
        handle!(app, 'j')                                      # the next node, from the top
        @test sel(app) == NodeRef(:crystal) && app.scroll == 0 && app.mode isa Inspect
        handle!(app, :esc)
        @test app.mode isa Browse
        handle!(app, '?')
        @test app.mode isa Help && app.mode.back isa Browse
        handle!(app, 'x')
        @test app.mode isa Browse
        handle!(app, 'i'); handle!(app, '?'); handle!(app, :enter)
        @test app.mode isa Inspect
        handle!(app, 'q')
        @test app.mode isa Browse && !app.quit
    end

    @testset "Files" begin
        mktempdir() do dir
            file = joinpath(dir, "bitter.quiver.json")
            # save a new quiver: asks for a path
            app = App(Session(single_batch()))
            handle!(app, 's')
            @test app.mode isa Prompt && app.mode.question == "Save as"
            handle!(app, :backspace)                           # edit the default path
            @test app.mode.buffer == "quiver.quiver.jso"
            app.mode.buffer = ""
            type!(app, file)
            handle!(app, :enter)
            @test app.mode isa Browse && isfile(file) && !isdirty(app.session)
            @test occursin("saved bitter.quiver.json", app.message) && !app.iserror
            # save again, to its own file
            apply!(app.session, SetAmount(:pale, 4.6u"kg"))
            handle!(app, :ctrl_s)
            @test !isdirty(app.session) && readjson(Quiver, file)[:pale].initial ≈ Contents(pale => 4.6u"kg")
            # a prompt cancelled
            handle!(app, 'S'); handle!(app, :esc)
            @test app.mode isa Browse

            # open: a quiver, a BeerJSON recipe, a missing file
            app = App(Session(Quiver()))
            app.session = Session(Quiver())                    # (clean enough: nothing to lose)
            handle!(app, 'o')
            @test app.mode isa Confirm                         # a new quiver is never saved
            handle!(app, 'd')
            @test app.mode isa Prompt
            type!(app, file); handle!(app, :enter)
            @test filepath(app.session) == file && sel(app) == NodeRef(:pale)
            @test occursin("opened", app.message)
            handle!(app, 'o')                                  # clean: no question
            @test app.mode isa Prompt
            type!(app, joinpath(@__DIR__, "data", "RRSummerBitter.json")); handle!(app, :enter)
            @test filepath(app.session) === nothing && occursin("imported", app.message)
            @test isbrewed(app.session) && !isempty(nodes(quiver(app.session)))
            handle!(app, 'o'); handle!(app, 'd')
            type!(app, joinpath(dir, "nothing.json")); handle!(app, :enter)
            @test app.iserror && occursin("no file", app.message) && app.mode isa Browse
            @test filepath(app.session) === nothing            # unchanged
        end
    end

    @testset "Quitting" begin
        mktempdir() do dir
            file = joinpath(dir, "q.json")
            save!(Session(single_batch()), file)
            app = App(open_session(file))
            handle!(app, 'q')
            @test app.quit                                     # nothing to lose
            app = App(open_session(file))
            apply!(app.session, SetAmount(:pale, 4.6u"kg"))
            handle!(app, 'q')
            @test app.mode isa Confirm && !app.quit
            handle!(app, 'x')                                  # not a choice
            @test app.mode isa Confirm
            handle!(app, 'c')
            @test app.mode isa Browse && !app.quit
            handle!(app, :ctrl_c); handle!(app, :esc)
            @test !app.quit
            handle!(app, 'q'); handle!(app, 's')               # save, then quit
            @test app.quit && !isdirty(app.session)
            app = App(Session(single_batch()))
            handle!(app, 'q'); handle!(app, 'd')               # discard
            @test app.quit
            app = App(Session(single_batch()))
            handle!(app, 'q'); handle!(app, 's')               # never saved: asks where
            @test app.mode isa Prompt && !app.quit
            app.mode.buffer = joinpath(dir, "new.json")
            handle!(app, :enter)
            @test app.quit && isfile(joinpath(dir, "new.json"))
        end
    end

    @testset "Frames" begin
        @test window(0, nothing, 10, 50) == 0
        @test window(0, 5, 10, 50) == 0                         # in view: kept
        @test window(0, 30, 10, 50) == 25                       # brought to the middle
        @test window(25, 3, 10, 50) == 0
        @test window(45, nothing, 10, 50) == 40

        app = App(Session(single_batch()))
        f = render_app(app; width = 100, height = 20)
        ls = split(render_text(f), '\n')
        @test length(ls) == 20
        @test occursin("new quiver ●", ls[1]) && occursin("q quit", ls[end])
        @test any(l -> occursin("▶", l) && occursin("pale", l), ls)
        handle!(app, :end)
        ls = split(render_text(render_app(app; width = 100, height = 20)), '\n')
        @test length(ls) == 20 && any(l -> occursin("▶", l) && occursin("bottles", l), ls)
        handle!(app, :enter)
        ls = split(render_text(render_app(app; width = 100, height = 20)), '\n')
        @test occursin(":bottles", ls[2]) && occursin("Esc back", ls[end])
        handle!(app, '?')
        @test !occursin("this help", render_text(render_app(app; width = 100, height = 30)))
        for _ in 1:20; handle!(app, :down); end                # scrolled to the end
        @test occursin("this help", render_text(render_app(app; width = 100, height = 30)))
        @test app.mode isa Help
        handle!(app, :esc); handle!(app, 'S')
        ls = split(render_text(render_app(app; width = 100, height = 20)), '\n')
        @test occursin("Save as: quiver.quiver.json▏", ls[end-1]) && occursin("Esc: cancel", ls[end])
        handle!(app, :esc); handle!(app, :ctrl_c)              # (in the inspector, q goes back)
        ls = split(render_text(render_app(app; width = 100, height = 20)), '\n')
        @test occursin("unsaved changes", ls[end-1]) && occursin("s: save first", ls[end])
        handle!(app, 'c'); handle!(app, 'o'); handle!(app, 'd')
        type!(app, "/no/such/file"); handle!(app, :enter)
        ls = split(render_text(render_app(app; width = 100, height = 20)), '\n')
        @test occursin("no file", ls[end-1])
    end

    @testset "The loop" begin
        mktempdir() do dir
            file = joinpath(dir, "bitter.quiver.json")
            save!(Session(single_batch()), file)
            out = IOBuffer()
            app = BrewQuiverTerm.run(file; input = IOBuffer("jjj\r\eq"), output = out, size = (24, 90))
            @test app.mode isa Browse && app.quit
            o = String(take!(out))
            @test startswith(o, "\e[?1049h") && endswith(o, "\e[?1049l")
            @test count("\e[H\e[2J", o) == 1                    # all keys read at once
            # the input ends: the loop ends
            app = BrewQuiverTerm.run(file; input = IOBuffer("j"), output = IOBuffer(), size = (24, 90))
            @test !app.quit && current(app) == NodeRef(:crystal)
            app = BrewQuiverTerm.run(; input = IOBuffer(""), output = IOBuffer(), size = (24, 90))
            @test isempty(nodes(quiver(app.session)))
            @test BrewQuiverTerm.run(joinpath(@__DIR__, "data", "RRSummerBitter.json"); input = IOBuffer(""),
                                     output = IOBuffer(), size = (24, 90)).session |> isbrewed
        end
    end
end

@testset "Help fits" begin
    using Term: remove_markup
    @test all(textwidth(remove_markup(l)) ≤ 94 for l in split(BrewQuiverTerm.HELP, '\n'))
end
