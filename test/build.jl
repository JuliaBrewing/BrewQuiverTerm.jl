# Building a quiver from scratch with the keys: water, lots with new ingredients, stages,
# arrows; then editing water, ingredients, the kinds of arrows, equipment, and a library.

using BrewQuiverTerm: holding, Stage, IngredientLot, WaterLot, AgentLot, Mixed, parse_lot,
    parse_water, parse_profile, profile_text, parse_properties

keys!(app, ks...) = foreach(k -> k isa AbstractString ? type!(app, k) : handle!(app, k), ks)
say!(app, text) = answer!(app, text)
lot_amount(app, l) = only(solids(quiver(app.session)[l].initial)).amount
ok(app) = (app.iserror && @info(app.message); !app.iserror)

@testset "Building" begin
    @testset "Parsing what is typed" begin
        @test parse_lot("munich 0.5 kg Munich malt") == (:munich, 0.5u"kg", "Munich malt")
        @test parse_lot("munich 0.5kg Munich") == (:munich, 0.5u"kg", "Munich")
        @test parse_lot("yeast 1 US-05") == (:yeast, 1.0, "US-05")
        @test parse_lot(":hops 30 g East Kent Goldings") == (:hops, 30u"g", "East Kent Goldings")
        @test_throws ArgumentError parse_lot("munich 0.5 kg")
        @test_throws ArgumentError parse_lot("munich lots Munich")
        @test parse_water("strike_water 16 L 75 °C") == (:strike_water, 16u"L", 75u"°C")
        @test parse_water("w 16L") == (:w, 16u"L", 20u"°C")
        @test_throws ArgumentError parse_water("w 16 kg")
        @test_throws ArgumentError parse_water("w 16 L hot")
        p = parse_profile("calcium 50, sulfate 100 mg/L")
        @test p.calcium ≈ 50u"mg/L" && p.sulfate ≈ 100u"mg/L" && iszero(p.sodium)
        @test parse_profile("Calcium 50 ppm").calcium ≈ 50u"mg/L"
        @test iszero(parse_profile("").calcium)
        @test_throws ArgumentError parse_profile("iron 3")
        @test_throws ArgumentError parse_profile("calcium")
        @test profile_text(p) == "calcium 50, sulfate 100 mg/L" && profile_text(WaterProfile()) == ""
        @test parse_properties("yield 80%, color 9 °L, kind Grain", (:yield, :color, :kind)) ==
              Dict(:yield => 80u"percent", :color => 9u"°L", :kind => :grain)
        @test_throws ArgumentError parse_properties("sweetness 3", (:yield,))
        @test_throws ArgumentError parse_properties("yield", (:yield,))
        @test holding(Contents()) == Stage()
        @test holding(Contents(pale => 1u"kg")) == IngredientLot()
        @test holding(Contents(water(1u"L"))) == WaterLot()
        @test holding(Contents(Salt(Gypsum()) => 4u"g")) == AgentLot()
        @test holding(Contents(Acid(LacticAcid()) => 2u"mL")) == AgentLot()
        @test holding(Contents(water(1u"L")) + Contents(pale => 1u"kg")) == Mixed()
    end

    @testset "A batch from scratch" begin
        app = App(Session(Quiver()))
        # water
        keys!(app, 'a', 'w'); say!(app, "strike_water 16 L 75 °C")
        @test ok(app) && current(app) == NodeRef(:strike_water)
        @test occursin("connect it with c", app.message)
        @test liquor(quiver(app.session)[:strike_water].initial).temperature ≈ 75u"°C"
        # lots of new ingredients, defined on the way
        keys!(app, 'a', 'l'); say!(app, "pale 4.5 kg Pale ale malt")
        @test app.mode isa Confirm && occursin("no ingredient named \"Pale ale malt\"", app.mode.question)
        @test [k for (k, _) in app.mode.choices] == ['f', 'h', 'c']
        handle!(app, 'f')
        @test app.mode isa Prompt && occursin("yield", app.mode.question)
        say!(app, "yield 80%, color 3 °L")
        @test ok(app) && lot_amount(app, :pale) ≈ 4.5u"kg"
        @test only(solids(quiver(app.session)[:pale].initial)).ingredient.color ≈ uconvert(u"SRM", 3u"°L")
        keys!(app, 'a', 'l'); say!(app, "cascade 50 g Cascade"); handle!(app, 'h'); say!(app, "alpha 6%")
        @test ok(app) && lot_amount(app, :cascade) ≈ 50u"g"
        keys!(app, 'a', 'l'); say!(app, "yeast 1 US-05"); handle!(app, 'c')
        say!(app, "attenuation 78%, form dry")
        @test ok(app) && lot_amount(app, :yeast) == 1
        # an ingredient now known: no question
        keys!(app, 'a', 'l'); say!(app, "pale2 1 kg pale ale")
        @test ok(app) && app.mode isa Browse && haskey(quiver(app.session), :pale2)
        keys!(app, 'a', 'l'); say!(app, "gypsum 4 g gypsum")
        @test ok(app) && holding(quiver(app.session)[:gypsum].initial) == AgentLot()
        # stages
        for (label, v) in (("mash", "mashtun"), ("rested", "mashtun"), ("kettle", "kettle"),
                           ("wort", "kettle"), ("fermentor", "fermentor"), ("beer", "fermentor"))
            keys!(app, 'a', 's'); say!(app, "$label $v")
            @test ok(app)
        end
        # arrows, in an order in which the quiver brews at each step
        for (src, rest) in ((:strike_water, "mash"), (:pale, "mash"), (:pale2, "mash"), (:gypsum, "mash"),
                            (:mash, "rested mashrest"), (:rested, "kettle drain"), (:cascade, "kettle"),
                            (:kettle, "wort boil"), (:wort, "fermentor drain"), (:yeast, "fermentor"),
                            (:fermentor, "beer ferment"))
            select!(app.session, NodeRef(src))
            handle!(app, 'c'); say!(app, rest)
            @test ok(app)
        end
        r = result(app.session)
        @test 1.040u"sg" < original_gravity(r[:beer]) < 1.130u"sg"     # (no sparge: strong)
        @test abv(r[:beer]) > 3u"percent" && ibu(r[:beer]) > 10u"IBU"
        @test profile(r[:mash]).sulfate > 0u"mg/L"
        # and it is saved and opened again
        mktempdir() do dir
            f = joinpath(dir, "scratch.quiver.json")
            handle!(app, 's'); app.mode.buffer = f; handle!(app, :enter)
            @test ok(app) && !isdirty(app.session)
            s2 = open_session(f)
            @test isbrewed(s2) && original_gravity(result(s2)[:beer]) ≈ original_gravity(r[:beer])
        end
        # each step is undone
        n = length(history(app.session))
        foreach(_ -> handle!(app, 'u'), 1:n)
        @test isempty(nodes(quiver(app.session)))
    end

    @testset "Editing lots" begin
        app = App(Session(single_batch()))
        # water: volume, temperature, profile
        select!(app.session, NodeRef(:strike_water)); handle!(app, 'e')
        @test app.mode isa Confirm && [l for (_, (l, _)) in app.mode.choices] == ["volume", "temperature", "water profile"]
        handle!(app, '2')
        @test app.mode.buffer == "75.0 °C"
        say!(app, "72 °C")
        @test ok(app) && liquor(quiver(app.session)[:strike_water].initial).temperature ≈ 72u"°C"
        keys!(app, 'e', '3')
        @test app.mode.buffer == ""
        say!(app, "calcium 50, sulfate 100")
        @test ok(app) && profile(quiver(app.session)[:strike_water].initial).sulfate ≈ 100u"mg/L"
        keys!(app, 'e', '3')
        @test app.mode.buffer == "calcium 50, sulfate 100 mg/L"
        say!(app, "iron 2")
        @test app.iserror && occursin("not an ion", app.message)
        keys!(app, 'e', '1'); say!(app, "17 L")
        @test ok(app) && isapprox(volume(quiver(app.session)[:strike_water].initial), 17u"L"; rtol = 1e-3)
        # an ingredient: one known, one defined (of the same kind), one ambiguous
        select!(app.session, NodeRef(:crystal)); keys!(app, 'e')
        @test [l for (_, (l, _)) in app.mode.choices] == ["amount", "ingredient"]
        handle!(app, '2')
        @test app.mode.buffer == "Crystal 60"
        say!(app, "Maris Otter")
        @test app.mode isa Confirm && [k for (k, _) in app.mode.choices] == ['f']
        handle!(app, 'f'); say!(app, "yield 81%, color 4 °L")
        @test ok(app) && only(solids(quiver(app.session)[:crystal].initial)).ingredient.name == "Maris Otter"
        keys!(app, 'e', '2'); say!(app, "Cascade")                  # a hop for a malt: refused
        @test app.iserror && occursin("takes a fermentable", app.message)
        keys!(app, 'e', '2'); say!(app, "a")
        @test app.iserror && occursin("could be", app.message)
        keys!(app, 'e', '1'); say!(app, "0.2 kg")
        @test ok(app) && lot_amount(app, :crystal) ≈ 0.2u"kg"
        # an undefined ingredient's properties refused
        keys!(app, 'a', 'l'); say!(app, "x 1 kg Unobtainium"); handle!(app, 'f'); say!(app, "sweetness 3")
        @test app.iserror && occursin("not a property", app.message) && !haskey(quiver(app.session), :x)
        # a stage, and an arrow's kind
        select!(app.session, NodeRef(:kettle)); handle!(app, 'e')
        @test app.iserror && occursin("filled by its arrows", app.message)
        select!(app.session, ArrowRef(:rested, :grain_bed)); keys!(app, 'e')
        @test first(app.mode.choices[1]) == '0' && last(app.mode.choices[1])[1] == "kind"
        handle!(app, '0')
        @test app.mode.buffer == "transfer"
        say!(app, "drain")
        @test app.iserror && occursin("one drain", app.message)        # rested already drains
        select!(app.session, ArrowRef(:chilled, :fermentor)); keys!(app, 'e', '0'); say!(app, "transfer")
        @test ok(app) && quiver(app.session)[:chilled => :fermentor, 1] isa Transfer
        keys!(app, 'e', '0'); say!(app, "stir")
        @test app.iserror && occursin("not a kind of arrow", app.message)
    end

    @testset "Equipment" begin
        app = App(Session(single_batch()))
        select!(app.session, NodeRef(:pale)); handle!(app, 'E')
        @test app.iserror && occursin("in no vessel", app.message)
        select!(app.session, NodeRef(:wort)); handle!(app, 'E')
        @test app.mode isa Confirm && occursin("equipment of the kettle", app.mode.question)
        labels = [l for (_, (l, _)) in app.mode.choices]
        @test labels[1:2] == ["name", "capacity"] && "evaporation" in labels
        handle!(app, Char('0' + findfirst(==("evaporation"), labels)))
        @test app.mode.buffer == ""
        say!(app, "5 L/h")
        @test ok(app) && equipment(quiver(app.session), :kettle).evaporation ≈ 5u"L/hr"
        keys!(app, 'E', '1'); say!(app, "Big kettle")
        @test ok(app) && equipment(quiver(app.session), :kettle).name == "Big kettle"
        t = render_text(render_node(app.session, :wort))
        @test occursin("equipment of the kettle", t) && occursin("Big kettle", t) && occursin("5.0 L/h", t)
        @test !occursin("equipment", render_text(render_node(app.session, :beer)))
        keys!(app, 'E', '2'); say!(app, "-3 L")
        @test app.iserror && occursin("negative", app.message)
        handle!(app, 'u')
        @test equipment(quiver(app.session), :kettle).name == ""
    end

    @testset "Library" begin
        mktempdir() do dir
            lib = Library()
            push!(lib, Fermentable("Munich malt"; color = 9u"°L"))
            f = joinpath(dir, "ingredients.json")
            writejson(f, lib)
            app = App(Session(single_batch()))
            handle!(app, 'L'); say!(app, f)
            @test ok(app) && occursin("loaded 1 ingredients", app.message)
            keys!(app, 'a', 'l'); say!(app, "munich 0.5 kg munich")
            @test ok(app) && app.mode isa Browse
            @test only(solids(quiver(app.session)[:munich].initial)).ingredient.color ≈ uconvert(u"SRM", 9u"°L")
            a = BrewQuiverTerm.run(; library = f, input = IOBuffer(""), output = IOBuffer(), size = (24, 90))
            @test length(library(a.session)) == 1
            handle!(app, 'L'); say!(app, joinpath(dir, "none.json"))
            @test app.iserror && occursin("no file", app.message)
        end
    end
end
