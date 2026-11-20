# Preferred units in the app: shown and typed, chosen with P, saved and read back.

@testset "Units" begin
    us = UnitPreferences(fermentable = u"lb", hop = u"oz", volume = u"gal", temperature = u"°F",
                         gravity = u"°P", absorption = u"qt/lb")
    s = Session(single_batch(); units = us)
    @testset "Shown" begin
        o = render_text(render_overview(s; width = 110))
        @test occursin("9.92 lb Pale ale malt", o) && occursin("1.76 oz Cascade", o)
        @test occursin("°P", o) && occursin("°F", o) && occursin(" gal", o) && !occursin(" sg", o)
        k = render_text(render_node(s, :kettle; width = 90))
        @test occursin(r"Cascade\s+0.882 oz\s+60 min remaining", k)
        @test occursin(r"volume\s+7.2\d gal", k)
        @test occursin("Transfer ← cascade #2  0.882 oz", k)
        a = render_text(render_arrow(s, ArrowRef(:cascade, :kettle, 2); width = 90))
        @test occursin(r"amount\s+0.882 oz", a)                  # (the unit of the hops of the lot)
        d = render_text(render_arrow(s, ArrowRef(:rested, :kettle); width = 90))
        @test occursin(r"absorption\s+0.479 qt/lb", d)
        sol = apply!(s, parse_solve("fermentor gravity 12 °P vary pale crystal"))
        r = render_text(render_solution(s, sol; width = 100))
        @test occursin("12.0 °P", r) && occursin("lb Pale ale malt", r)
        undo!(s)
    end

    @testset "Typed" begin
        app = App(Session(single_batch(); units = us))
        keys!(app, 'e', '1')                                         # the malt, in lb
        @test app.mode.buffer == "9.92 lb"
        say!(app, "10")
        @test lot_amount(app, :pale) ≈ 10u"lb"
        keys!(app, 'e', '1'); say!(app, "4 kg")                         # a unit typed is kept
        @test lot_amount(app, :pale) ≈ 4u"kg"
        select!(app.session, NodeRef(:strike_water)); keys!(app, 'e', '1')
        @test app.mode.buffer == "4.23 gal"
        say!(app, "5")
        @test volume(quiver(app.session)[:strike_water].initial) ≈ 5u"gal" rtol = 1e-3
        keys!(app, 'e', '2')
        @test app.mode.buffer == "167 °F"
        say!(app, "160")
        @test liquor(quiver(app.session)[:strike_water].initial).temperature ≈ 160u"°F"
        # an empty field: in the unit of its role
        select!(app.session, ArrowRef(:chilled, :fermentor)); keys!(app, 'e', '1')
        @test app.mode.buffer == ""
        say!(app, "0.5")
        @test quiver(app.session)[:chilled => :fermentor, 1].absorption ≈ 0.5u"qt/lb"
        # a transfer from a lot of hops, in the unit of hops
        select!(app.session, ArrowRef(:cascade, :kettle, 2)); keys!(app, 'e', '1')
        @test app.mode.buffer == "0.882 oz"
        say!(app, "0.5")
        @test quiver(app.session)[:cascade => :kettle, 2].amount ≈ 0.5u"oz"
        # new lots and water
        keys!(app, 'a', 'l'); say!(app, "munich 2 Pale ale malt")
        @test lot_amount(app, :munich) ≈ 2u"lb"
        keys!(app, 'a', 'l'); say!(app, "yeast2 2 US-05")
        @test lot_amount(app, :yeast2) == 2                          # a count of packs
        keys!(app, 'a', 'w'); say!(app, "top_up 1 60")
        @test volume(quiver(app.session)[:top_up].initial) ≈ 1u"gal" rtol = 1e-3
        @test liquor(quiver(app.session)[:top_up].initial).temperature ≈ 60u"°F"
        # the equipment, empty: in the unit of its role
        select!(app.session, NodeRef(:wort)); keys!(app, 'E', '2'); say!(app, "10")
        @test equipment(quiver(app.session), :kettle).capacity ≈ 10u"gal"
    end

    @testset "Chosen with P, and saved" begin
        mktempdir() do dir
            withenv("XDG_CONFIG_HOME" => dir) do
                app = App(Session(single_batch()))
                handle!(app, 'P')
                @test app.mode isa Confirm
                labels = [l for (_, (l, _)) in app.mode.choices]
                @test labels[1] == "malts and sugars (auto)" && "hops (g)" in labels
                handle!(app, 'h')
                @test [l for (_, (l, _)) in app.mode.choices][1] == "g (in use)"
                handle!(app, '4')                                     # oz
                @test units(app.session)[:hop] == u"oz" && app.mode isa Browse
                @test occursin("hops in oz (saved in", app.message)
                @test load_units() == UnitPreferences(hop = u"oz")
                @test occursin("oz Cascade", render_text(render_overview(app.session; width = 110)))
                # read when the app starts, and kept when another quiver is opened
                a = BrewQuiverTerm.run(; input = IOBuffer(""), output = IOBuffer(), size = (24, 90))
                @test units(a.session)[:hop] == u"oz"
                f = joinpath(dir, "q.json")
                save!(Session(single_batch()), f)
                handle!(a, 'o'); handle!(a, 'd'); say!(a, f)
                @test units(a.session)[:hop] == u"oz"
                # a broken file: the defaults, and a message
                write(units_path(), "[units]\nhop = \"furlongs\"\n")
                a = BrewQuiverTerm.run(; input = IOBuffer(""), output = IOBuffer(), size = (24, 90))
                @test a.iserror && occursin("units were not read", a.message)
                @test units(a.session) == UnitPreferences()
            end
        end
    end
end
