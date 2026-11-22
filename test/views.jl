# The drawing of the quiver, the timeline, and solving.

using BrewQuiverTerm: clock

@testset "Views" begin
    @testset "Drawing" begin
        s = Session(single_batch())
        t = render_text(render_dag(s))
        ls = split(t, '\n')
        for n in nodes(quiver(s))
            @test occursin(" " * String(n), t) || occursin("…", t)
        end
        @test occursin("● pale", t) && occursin("○ strike_water", t) && occursin("○ mash", t)
        # an arrow head before each node with arrows arriving, and none elsewhere
        @test count("▶", t) == count(n -> !isempty(predecessors(quiver(s), n)), nodes(quiver(s)))
        @test occursin("▶● kettle", t) && occursin("▶● bottles", t)
        # the stream of the batch along the first row, left to right
        first_row = ls[1]
        @test all(occursin(String(n), first_row) for n in (:mash, :kettle, :wort, :fermentor, :beer, :bottles))
        @test findfirst("mash", first_row)[1] < findfirst("kettle", first_row)[1] < findfirst("bottles", first_row)[1]
        # a window of columns, around a node
        w = render_text(render_dag(s; width = 40, focus = :bottles))
        @test all(textwidth(l) ≤ 40 for l in split(w, '\n'))
        @test occursin("bottles", w) && !occursin("pale", w)
        @test occursin("pale", render_text(render_dag(s; width = 40, focus = :pale)))
        @test occursin("pale", render_text(render_dag(s; width = 40)))
        # long labels are cut; a parti-gyle; an empty quiver
        @test occursin("priming_sug…", t)
        p = render_text(render_dag(Session(partigyle()); cell = 12))
        @test occursin("kettle1", p) && occursin("strong", p) && occursin("light", p)
        @test occursin("empty quiver", render_text(render_dag(Session(Quiver()))))
        select!(s, NodeRef(:kettle))                               # in reverse video
        @test occursin("\e[7mkettle\e[27m", string(render_dag(s)))
    end

    @testset "Timeline" begin
        @test clock(0u"minute") == "0:00" && clock(65u"minute") == "1:05"
        @test clock(14u"d" + 2u"hr") == "14d 2:00" && clock(-5u"minute") == "-0:05"
        @test clock(nothing) == "–"
        s = Session(single_batch())
        t = render_timeline(s; width = 100)
        ls = split(render_text(t), '\n')
        @test all(textwidth(l) == 100 for l in ls if !isempty(l))
        txt = render_text(t)
        @test occursin("28.1 d in all", txt) && occursin("28d 2:00", txt)
        for v in ("mashtun", "kettle", "fermentor", "bottles")
            @test any(l -> occursin(Regex("│  $v\\s+[ █▓]*█"), l), ls)
        end
        @test occursin("no vessel is booked twice", txt)
        @test occursin(r"fermentor\s+fermentor\s+2:00\s+2:00\s+14d 2:00", txt)
        z = render_text(render_timeline(s; width = 100, zoom = 5))
        @test occursin("zoom ×32", z) && occursin("21:04", z)
        # a vessel booked twice
        q = partigyle()
        q[:kettle2] = Contents()
        vessel!(q, :kettle2, :kettle1)
        vessel!(q, :wort2, :kettle1)
        s2 = Session(q)
        @test !isempty(vessel_bookings(s2).overlaps)
        @test occursin("the kettle1 holds", render_text(render_timeline(s2)))
        @test occursin("does not brew", render_text(render_timeline(Session(overdrawn()))))
    end

    @testset "Solving" begin
        c = parse_solve("fermentor gravity 1.050 sg, wort IBU 30 IBU vary pale crystal, cascade")
        @test [t.node for t in c.targets] == [:fermentor, :wort]
        @test c.targets[1].f === gravity && c.targets[2].goal == 30u"IBU"
        @test [p.labels for p in c.vary] == [[:pale, :crystal], [:cascade]]
        c = parse_solve("bottles carbonation 2.5 vols vary :priming_sugar")
        @test only(c.vary).labels == [:priming_sugar]
        c = parse_solve("wort volume 24 L, wort ibu 30 IBU VARY kettle>wort.time, cascade>kettle#2.amount")
        @test c.vary[1] == Setting(:kettle => :wort, :time)
        @test c.vary[2] == Setting(:cascade => :kettle, :amount; index = 2)
        for bad in ("wort gravity 1.050 sg", "wort gravity vary pale", "wort sweetness 3 vary pale",
                    "wort gravity lots vary pale")
            @test_throws ArgumentError parse_solve(bad)
        end
        s = Session(single_batch())
        sol = apply!(s, parse_solve("fermentor gravity 1.050 sg vary pale crystal"))
        r = render_text(render_solution(sol; width = 90))
        @test occursin("converged in", r) && occursin("amount of :pale, :crystal", r)
        @test occursin(r"fermentor\s+gravity\s+1.050 sg\s+1.050 sg", r)
        @test occursin(":crystal", r) && occursin("Pale ale malt", r)
        sol = apply!(s, Solve(:wort => ibu => 40u"IBU", Amount(:cascade); maxiter = 0))
        @test occursin("did not converge", render_text(render_solution(sol)))
        sol = apply!(s, Solve(:wort => volume => 25u"L", Setting(:kettle => :wort, :time)))
        @test occursin("time of :kettle => :wort", render_text(render_solution(sol)))
    end

    @testset "In the app" begin
        app = App(Session(single_batch()))
        handle!(app, 'd')
        @test app.mode isa DagView
        handle!(app, :down); handle!(app, 'j')
        @test current(app) == NodeRef(:cascade)
        handle!(app, :left)
        @test current(app) == NodeRef(:crystal)
        f = render_text(render_app(app; width = 100, height = 20))
        @test occursin("── quiver ─", f) && occursin(r"l\s+arrange", f)
        handle!(app, 'l')
        @test undo_description(app.session) == "Arrange the nodes" && app.message == "arranged the nodes"
        handle!(app, 'i')
        @test app.mode isa Inspect
        handle!(app, :esc); handle!(app, 'd'); handle!(app, 'd')
        @test app.mode isa Browse
        handle!(app, 'd'); handle!(app, 'q')
        @test app.mode isa Browse && !app.quit

        handle!(app, 't')
        @test app.mode isa TimelineView
        handle!(app, '+'); handle!(app, '+'); handle!(app, '-')
        @test app.mode.zoom == 1
        @test occursin("zoom ×2", render_text(render_app(app; width = 100, height = 20)))
        handle!(app, :esc)
        @test app.mode isa Browse

        handle!(app, 'T')
        @test app.mode isa Prompt
        answer!(app, "fermentor gravity 1.048 sg vary pale crystal")
        @test app.mode isa SolutionView && app.message == "Solve for the gravity of :fermentor"
        @test gravity(result(app.session)[:fermentor]) ≈ 1.048u"sg"
        @test occursin("converged", render_text(render_app(app; width = 100, height = 24)))
        handle!(app, 'u')                                      # undoes the solve, and goes back
        @test app.mode isa Browse
        @test !(gravity(result(app.session)[:fermentor]) ≈ 1.048u"sg")
        handle!(app, 'T'); answer!(app, "fermentor gravity 1.048 sg")
        @test app.iserror && occursin("vary", app.message) && app.mode isa Browse
        handle!(app, 'T'); answer!(app, "fermentor gravity 1.048 sg, wort ibu 30 IBU vary pale")
        @test app.iserror && occursin("as many", app.message)
    end
end
