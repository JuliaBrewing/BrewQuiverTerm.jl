# Models, export and inventory in the app.

using BeerJSON: BeerJSONParser

@testset "Brewing" begin
    @testset "Models" begin
        app = App(Session(single_batch()))
        ibu0 = ibu(result(app.session)[:wort])
        handle!(app, 'M')
        @test app.mode isa Confirm
        @test [l for (_, (l, _)) in app.mode.choices] ==
              ["bitterness (Tinseth)", "color (Morey)", "abv (Balling)", "gravity (SugarGravityQuad)"]
        handle!(app, 'b')
        @test [l for (_, (l, _)) in app.mode.choices] == ["Tinseth (in use)", "Rager"]
        handle!(app, '2')
        @test app.mode isa Browse && app.message == "Use the models bitterness Rager"
        @test models(app.session) == (bitterness = BrewingFormulas.Rager(),)
        @test !(ibu(result(app.session)[:wort]) ≈ ibu0)
        @test occursin("models: Rager", render_text(render_statusbar(app.session; width = 120)))
        keys!(app, 'M', 'c', '2')
        @test models_in_use(app.session).color == BrewingFormulas.Daniels()
        handle!(app, 'u'); handle!(app, 'u')
        @test models(app.session) == (;) && ibu(result(app.session)[:wort]) ≈ ibu0
        @test !occursin("models", render_text(render_statusbar(app.session)))
        keys!(app, 'M', :esc)
        @test app.mode isa Browse
    end

    @testset "Export" begin
        mktempdir() do dir
            f = joinpath(dir, "bitter.quiver.json")
            save!(Session(single_batch()), f)
            app = App(open_session(f))
            handle!(app, 'X')
            @test app.mode.buffer == joinpath(dir, "bitter.beerjson.json")
            handle!(app, :enter)
            @test ok(app) && occursin("exported the recipes", app.message)
            @test !isempty(readjson(BeerJSONParser, joinpath(dir, "bitter.beerjson.json")).beerjson.recipes)
            app = App(Session(overdrawn()))
            handle!(app, 'X')
            @test app.mode.buffer == "recipes.json"
            say!(app, joinpath(dir, "x.json"))
            @test app.iserror && occursin("does not brew", app.message)
        end
    end

    @testset "Inventory" begin
        mktempdir() do dir
            lib = Library()
            push!(lib, pale; stock = 3u"kg")
            push!(lib, cascade; stock = 100u"g")
            push!(lib, us05; stock = 2)
            f = joinpath(dir, "ingredients.json")
            writejson(f, lib)
            app = BrewQuiverTerm.run(; library = f, input = IOBuffer(""), output = IOBuffer(), size = (24, 90))
            @test app.library_path == f
            # the batch, opened with the library kept
            q = joinpath(dir, "bitter.quiver.json")
            save!(Session(single_batch()), q)
            handle!(app, 'o'); handle!(app, 'd'); say!(app, q)
            @test ok(app) && length(library(app.session)) == 3
            handle!(app, 'I')
            @test app.mode isa InventoryView
            t = render_text(render_app(app; width = 100, height = 20))
            @test occursin("the library has 3 ingredients", t)
            @test occursin(r"Pale ale malt\s+4.50 kg\s+3.00 kg\s+⚠ short", t)
            @test occursin(r"Cascade\s+50 g\s+100 g\s+✓", t)
            @test occursin(r"Crystal 60\s+300 g\s+–\s+⚠ short", t)
            @test occursin(r"US-05\s+1 ×\s+2 ×\s+✓", t)          # (a count of packs, kept in the file)
            @test occursin("C take from the stock", t)
            handle!(app, 'C')
            @test app.mode isa Confirm
            handle!(app, 'n')
            @test app.mode isa InventoryView && stock(library(app.session), "Cascade") ≈ 100u"g"
            keys!(app, 'C', 'y')
            @test app.mode isa InventoryView && occursin("took the brew from the stock: 1 short", app.message)
            @test stock(library(app.session), "Cascade") ≈ 50u"g" && iszero(stock(library(app.session), "Pale ale malt"))
            handle!(app, 'W')
            @test app.mode.buffer == f
            handle!(app, :enter)
            @test ok(app) && stock(Library(f), "Cascade") ≈ 50u"g" && stock(Library(f), "US-05") == 1
            handle!(app, :esc)
            @test app.mode isa Browse
            # without a library, and without a brew
            app = App(Session(overdrawn()))
            handle!(app, 'I')
            @test occursin("does not brew", render_text(render_app(app; width = 100, height = 12)))
            keys!(app, 'C', 'y')
            @test app.iserror
            handle!(app, 'W')
            @test app.mode.buffer == "ingredients.json"
        end
    end
end
