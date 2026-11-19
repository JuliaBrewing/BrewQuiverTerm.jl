# Editing in the app: the commands through prompts, refusals, undo and redo, the history.

# answer the open prompt with `text`, replacing what it proposes
answer!(app, text) = (app.mode.buffer = ""; type!(app, text); handle!(app, :enter))
amount(s, label) = only(solids(quiver(s)[label].initial)).amount
goto!(app, label) = select!(app.session, NodeRef(label))

@testset "Editing" begin
    @testset "Amounts of lots" begin
        app = App(Session(single_batch()))
        handle!(app, 'e')
        @test app.mode isa Prompt && app.mode.question == "Amount of :pale" && app.mode.buffer == "4.50 kg"
        answer!(app, "4.8 kg")
        @test app.mode isa Browse && amount(app.session, :pale) ≈ 4.8u"kg"
        @test app.message == "Set :pale to 4.8 kg" && !app.iserror
        @test :bottles in changed(app.session)
        @test occursin("✱", render_text(render_app(app; width = 110, height = 60)))
        goto!(app, :strike_water); handle!(app, 'e')
        @test app.mode.buffer == "16.0 L"
        answer!(app, "17 L")
        @test volume(quiver(app.session)[:strike_water].initial) ≈ 17u"L"
        goto!(app, :yeast); handle!(app, 'e'); answer!(app, "2")
        @test amount(app.session, :yeast) == 2
        # refused: the quiver would not brew, or the text is not a value
        goto!(app, :strike_water); handle!(app, 'e'); answer!(app, "1 L")
        @test app.iserror && occursin("would no longer brew", app.message)
        @test volume(quiver(app.session)[:strike_water].initial) ≈ 17u"L"
        handle!(app, 'e'); answer!(app, "plenty")
        @test app.iserror && occursin("not a number", app.message)
        handle!(app, 'e'); handle!(app, :esc)
        @test app.mode isa Browse && volume(quiver(app.session)[:strike_water].initial) ≈ 17u"L"
        # a stage has no amount
        goto!(app, :kettle); handle!(app, 'e')
        @test app.mode isa Browse && app.iserror && occursin("filled by its arrows", app.message)
    end

    @testset "Fields of arrows" begin
        app = App(Session(single_batch()))
        goto!(app, :kettle); handle!(app, :tab)
        @test current(app) == ArrowRef(:kettle, :wort, 1)
        handle!(app, 'e')
        @test app.mode isa Confirm && occursin("Boil", app.mode.question)
        @test [label for (_, (label, _)) in app.mode.choices] == ["time", "evaporation", "stand", "stand temperature"]
        handle!(app, '1')
        @test app.mode isa Prompt && app.mode.buffer == "60 min"
        answer!(app, "70 min")
        @test quiver(app.session)[:kettle => :wort, 1].time ≈ 70u"minute"
        @test app.message == "Set the time of :kettle => :wort to 70 minute"
        # a fraction, shown and typed as a percentage
        goto!(app, :mash); handle!(app, :tab); handle!(app, 'e'); handle!(app, '3')
        @test app.mode.buffer == "95.0%"
        answer!(app, "90%")
        @test quiver(app.session)[:mash => :rested, 1].conversion ≈ 0.9
        # a timing, and an optional field left to the vessel
        goto!(app, :cascade); handle!(app, :tab); handle!(app, :tab); handle!(app, 'e'); handle!(app, '2')
        @test app.mode.buffer == "10 min remaining"
        answer!(app, "at 55 min")
        @test quiver(app.session)[:cascade => :kettle, 2].timing == At(55u"minute")
        goto!(app, :chilled); handle!(app, :tab); handle!(app, 'e'); handle!(app, '1')
        @test app.mode.buffer == ""                            # no absorption given
        answer!(app, "0.8 L/kg")
        @test quiver(app.session)[:chilled => :fermentor, 1].absorption ≈ 0.8u"L/kg"
        # refused
        goto!(app, :kettle); handle!(app, :tab); handle!(app, 'e'); handle!(app, '1'); answer!(app, "3 kg")
        @test app.iserror && occursin("quantity in minute", app.message)
        handle!(app, 'e'); handle!(app, :esc)
        @test app.mode isa Browse
    end

    @testset "Nodes and arrows" begin
        app = App(Session(single_batch()))
        goto!(app, :kettle); handle!(app, 'r')
        @test app.mode.buffer == "kettle"
        answer!(app, "boiler")
        @test haskey(quiver(app.session), :boiler) && current(app) == NodeRef(:boiler)
        handle!(app, 'r'); answer!(app, ":wort")
        @test app.iserror && occursin("already a node", app.message)
        handle!(app, 'a'); answer!(app, "trub boiler")
        @test vessel(quiver(app.session), :trub) == :boiler && current(app) == NodeRef(:trub)
        handle!(app, 'a'); answer!(app, "   ")
        @test app.iserror
        handle!(app, 'v')
        @test app.mode.buffer == "boiler"
        answer!(app, "")
        @test vessel(quiver(app.session), :trub) === nothing
        handle!(app, 'v'); answer!(app, "fermentor")
        @test vessel(quiver(app.session), :trub) == :fermentor
        goto!(app, :sparge_water); handle!(app, 'c'); answer!(app, "mash")
        @test :mash in successors(quiver(app.session), :sparge_water)
        @test app.message == "Connect :sparge_water => :mash"
        goto!(app, :trub); handle!(app, 'c'); answer!(app, "bottles chill")
        @test quiver(app.session)[:trub => :bottles, 1] isa Chill
        handle!(app, 'c'); answer!(app, "bottles stir")
        @test app.iserror && occursin("not a kind of arrow", app.message)
        goto!(app, :bottles); handle!(app, 'c'); answer!(app, "pale")
        @test app.iserror && occursin("cycle", app.message)
        goto!(app, :trub)
        # removing: a node after a question, an arrow at once
        goto!(app, :trub); handle!(app, 'x')
        @test app.mode isa Confirm
        handle!(app, 'n')
        @test haskey(quiver(app.session), :trub) && app.mode isa Browse
        handle!(app, :delete); handle!(app, 'y')
        @test !haskey(quiver(app.session), :trub)
        goto!(app, :cascade); handle!(app, :tab); handle!(app, 'x')
        @test length(quiver(app.session)[:cascade => :boiler]) == 1
        @test app.message == "Remove the arrow :cascade => :boiler"
    end

    @testset "Undo, redo and history" begin
        app = App(Session(single_batch()))
        handle!(app, 'u')
        @test app.iserror && app.message == "nothing to undo"
        handle!(app, 'e'); answer!(app, "4.8 kg")
        goto!(app, :kettle); handle!(app, 'r'); answer!(app, "boiler")
        handle!(app, 'u')
        @test app.message == "undid Rename :kettle to :boiler" && haskey(quiver(app.session), :kettle)
        @test current(app) == NodeRef(:kettle)                 # the selection before the step
        handle!(app, :ctrl_z)
        @test amount(app.session, :pale) ≈ 4.5u"kg"
        handle!(app, 'U')
        @test app.message == "redid Set :pale to 4.8 kg" && amount(app.session, :pale) ≈ 4.8u"kg"
        handle!(app, 'h')
        @test app.mode isa HistoryView
        t = render_text(render_app(app; width = 100, height = 20))
        @test occursin("✓ Set :pale to 4.8 kg  ◀ now", t) && occursin("Rename :kettle to :boiler", t)
        handle!(app, :ctrl_y)                                  # redo from the history
        @test haskey(quiver(app.session), :boiler) && app.mode isa HistoryView
        handle!(app, :esc)
        @test app.mode isa Browse
        handle!(app, :ctrl_y)
        @test app.message == "nothing to redo"
        # the status bar tells what undo would undo
        @test occursin("undo: Rename :kettle to :boiler", render_text(render_app(app; width = 120, height = 20)))
    end

    @testset "Rendering the history" begin
        mktempdir() do dir
            file = joinpath(dir, "q.json")
            save!(Session(single_batch()), file)
            s = open_session(file)
            t = render_text(render_history(s))
            @test occursin("no edits yet", t) && occursin("the opened quiver  ◀ now", t)
            apply!(s, SetAmount(:pale, 4.6u"kg"))
            save!(s)
            apply!(s, SetAmount(:crystal, 0.4u"kg"))
            undo!(s)
            ls = split(render_text(render_history(s; width = 80)), '\n')
            @test any(l -> occursin("✓ Set :pale to 4.6 kg  saved  ◀ now", l), ls)
            @test any(l -> occursin("  Set :crystal to 0.4 kg", l) && !occursin("✓", l), ls)
            @test all(textwidth(l) == 80 for l in ls if !isempty(l))
        end
    end
end
