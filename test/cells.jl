# The cells of the overview: Tab through the columns, editing in place, choosing an
# ingredient, solving for a computed value, Space.

using BrewQuiverTerm: current, current_column, row_columns

# Tab from the node to its `column`
function cell!(app, label, column)
    goto!(app, label)
    while current_column(app) !== column
        handle!(app, :tab)
    end
    return app
end
frame(app) = render_text(render_app(app; width = 120, height = 40))
row(app, label) = only(l for l in split(frame(app), '\n') if occursin(Regex("\\b$label\\b"), l) && occursin("▶", l))

@testset "Cells of the overview" begin
    @testset "Columns" begin
        app = App(Session(single_batch()))
        @test row_columns(app.session, :pale) == [:amount, :ingredient, :temperature]
        @test row_columns(app.session, :wort)[1:2] == [:volume, :gravity]
        cell!(app, :pale, :ingredient)
        @test current(app) == NodeRef(:pale)
        @test occursin("\e[7m", render_app(app; width = 120, height = 40))   # (in reverse video)
        handle!(app, :down)                                    # the column is kept on the next row
        @test current(app) == NodeRef(:crystal) && current_column(app) === :ingredient
        goto!(app, :wort); handle!(app, :backtab)              # Shift-Tab: the last arrow
        @test current(app) isa ArrowRef && current_column(app) === nothing
        goto!(app, :pale); handle!(app, :right)                # → ←: as Tab and Shift-Tab
        @test current_column(app) === :amount
        handle!(app, :right); handle!(app, :left)
        @test current_column(app) === :amount
        handle!(app, :left)
        @test current(app) == NodeRef(:pale) && current_column(app) === nothing && app.mode isa Browse
        @test decode_keys("\e[1;2B\e[1;2A") == [:shift_down, :shift_up]
    end

    @testset "Editing in place" begin
        app = App(Session(single_batch()))
        cell!(app, :pale, :amount); handle!(app, 'e')
        @test app.mode isa Prompt && app.mode.cell == (:pale, :amount) && app.mode.buffer == "4.50 kg"
        r = row(app, "pale")
        @test occursin("4.50 kg▏", r) && occursin("Pale ale malt", r)   # typed in the cell
        @test occursin("(typed in place)", frame(app))
        answer!(app, "5")
        @test only(quiver(app.session)[:pale].initial.solids).amount ≈ 5u"kg"
        @test app.mode isa Browse && current_column(app) === :amount    # (back in the cell)
        # water: its volume, profile and temperature
        cell!(app, :strike_water, :temperature); handle!(app, 'e')
        @test app.mode.cell == (:strike_water, :temperature)
        answer!(app, "80C")
        @test quiver(app.session)[:strike_water].initial.liquor.temperature ≈ 80u"°C"
        cell!(app, :strike_water, :ingredient); handle!(app, 'e')
        @test app.mode isa Prompt && occursin("profile", lowercase(app.mode.question))
        answer!(app, "calcium 50")
        @test occursin("calcium 50", row(app, "strike_water"))
        # nothing to set
        cell!(app, :pale, :temperature); handle!(app, 'e')
        @test app.mode isa Browse && app.iserror && occursin("only water", app.message)
    end

    @testset "Choosing an ingredient" begin
        app = App(Session(single_batch()))
        name(l) = only(quiver(app.session)[l].initial.solids).ingredient.name
        fermentables = search_ingredients(app.session; role = :fermentable)
        cell!(app, :pale, :ingredient); handle!(app, 'e')
        p = app.mode
        @test p isa Picker && p.items == fermentables && !("Cascade" in p.items)   # those of its kind
        @test p.items[p.index] == "Pale ale malt"
        @test occursin("‹ Pale ale malt ›", row(app, "pale"))
        f = frame(app)
        @test occursin("type to search $(length(fermentables))", f)
        @test occursin(r"Munich malt\s+malt", f)                         # the list dropping down
        handle!(app, :up)
        @test p.items[p.index] == fermentables[findfirst(==("Pale ale malt"), fermentables) - 1]
        type!(app, "crys")                                              # typed: searched
        @test BrewQuiverTerm.matches(p) == ["Crystal 15", "Crystal 40", "Crystal 60", "Crystal 120"]
        @test occursin("4 of $(length(fermentables))", frame(app)) && occursin("‹ Crystal 15 ›", frame(app))
        foreach(_ -> handle!(app, :backspace), 1:4); type!(app, "chocolate")
        @test BrewQuiverTerm.matches(p)[1:2] == ["Chocolate malt", "Pale chocolate malt"]
        handle!(app, :esc)
        @test name(:pale) == "Pale ale malt"
        handle!(app, 'e'); type!(app, "crystal 6"); handle!(app, :enter)
        c = only(quiver(app.session)[:pale].initial.solids)
        @test c.ingredient.name == "Crystal 60" && c.amount ≈ 4.5u"kg"   # the amount kept
        handle!(app, 'u')
        @test name(:pale) == "Pale ale malt"
        # Shift-↓↑: the next, previous one at once
        i = findfirst(==("Pale ale malt"), fermentables)
        handle!(app, :shift_up)
        @test name(:pale) == fermentables[i - 1]
        handle!(app, :shift_down); handle!(app, :shift_down)
        @test name(:pale) == fermentables[i + 1]
        @test length(history(app.session)) == 1                          # (quick ones merged)
        cell!(app, :pale, :amount); handle!(app, :shift_down)
        @test app.iserror && occursin("Tab to its name", app.message)
        # the hops are chosen among the hops
        cell!(app, :cascade, :ingredient); handle!(app, 'e')
        @test "Citra" in app.mode.items && !("Pale ale malt" in app.mode.items)
    end

    @testset "Solving for a computed value" begin
        app = App(Session(single_batch()))
        cell!(app, :fermentor, :gravity); handle!(app, 'e')
        @test app.mode isa Prompt && app.mode.cell == (:fermentor, :gravity) && endswith(app.mode.buffer, "sg")
        answer!(app, "1.055")                                  # (in the unit shown)
        @test app.mode isa Prompt && app.mode.buffer == "pale crystal"   # the fermentables upstream
        handle!(app, :enter)
        @test app.mode isa SolutionView && !app.iserror
        @test gravity(result(app.session)[:fermentor]) ≈ 1.055u"sg" atol = 1e-4u"sg"
        handle!(app, :esc)
        cell!(app, :wort, :ibu); handle!(app, 'e'); answer!(app, "35")
        @test app.mode.buffer == "cascade"
        handle!(app, :enter)
        @test ibu(result(app.session)[:wort]) ≈ 35u"IBU" rtol = 1e-3
        handle!(app, :esc)
        cell!(app, :mash, :ph); handle!(app, 'e')
        @test app.mode isa Browse && app.iserror && occursin("cannot be solved for", app.message)
    end

    @testset "Space" begin
        app = App(Session(single_batch()))
        cell!(app, :fermentor, :gravity); handle!(app, ' ')
        @test occursin("computed by the brew", app.message) && occursin("goal", app.message)
        cell!(app, :pale, :ingredient); handle!(app, ' ')
        @test occursin("Shift-↓↑", app.message)
        cell!(app, :mash, :ph); handle!(app, ' ')
        @test occursin("computed", app.message) && !occursin("goal", app.message)
        goto!(app, :pale); handle!(app, ' ')
        @test occursin("Tab walks", app.message)
        goto!(app, :kettle); handle!(app, :backtab); handle!(app, ' ')
        @test occursin("the arrow :kettle → :wort", app.message)
    end
end

@testset "Enter edits, and the values proposed are replaced" begin
    app = App(Session(single_batch()))
    cell!(app, :pale, :amount); handle!(app, :enter)               # Enter: as e
    @test app.mode isa Prompt && app.mode.buffer == "4.50 kg" && app.mode.fresh
    @test occursin(r"type\s+replace", frame(app))
    type!(app, "5"); handle!(app, :enter)                          # typing replaces it
    @test only(quiver(app.session)[:pale].initial.solids).amount ≈ 5u"kg"
    handle!(app, :enter); handle!(app, :backspace)                 # Backspace deletes it whole
    @test app.mode.buffer == ""
    handle!(app, :esc); handle!(app, :enter); handle!(app, :delete)
    @test app.mode.buffer == ""
    handle!(app, :esc); handle!(app, 'e'); handle!(app, :end); type!(app, "0")
    @test app.mode.buffer == "5.00 kg0"                            # (End, → ←, Home: to change it)
    handle!(app, :backspace); handle!(app, :backspace)
    @test app.mode.buffer == "5.00 k"
    handle!(app, :esc)
    goto!(app, :pale); handle!(app, 'i')
    @test app.mode isa Inspect
    handle!(app, :enter)                                           # editing from the inspector
    @test app.mode isa Confirm && occursin("Edit :pale", app.mode.question)
end

@testset "Templates" begin
    app = App(Session(Quiver()))
    @test occursin("template", frame(app))                     # the empty quiver says so
    keys!(app, 'a', 't')
    @test app.mode isa Picker && app.mode.items == first.(TEMPLATES)
    @test occursin("parti-gyle", frame(app)) && occursin("two beers", frame(app))
    type!(app, "parti"); handle!(app, :enter)
    @test app.mode isa Browse && !app.iserror && isbrewed(app.session)
    @test haskey(quiver(app.session), :kettle2) && occursin("a new parti-gyle", app.message)
    # a quiver with changes: asks first
    apply!(app.session, SetAmount(:pale, 7u"kg"))
    keys!(app, 'a', 't'); type!(app, "single"); handle!(app, :enter)
    @test app.mode isa Confirm && occursin("unsaved", app.mode.question)
    handle!(app, 'd')
    @test !haskey(quiver(app.session), :kettle2) && haskey(quiver(app.session), :bottles)
end
