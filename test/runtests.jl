using Test
using Unitful
using UnitfulBrewing
using BrewingFormulas
using BrewQuiver
using BrewQuiverUICore
using BrewQuiverTerm
using BrewQuiverTerm: plain, table, block

include("quivers.jl")

lines(x) = split(render_text(x), '\n')
stripped(x) = join(rstrip.(lines(x)), '\n')
# the row of a node in the overview, by its label column
row(ls, label) = only(l for l in ls if occursin(Regex("^│  .{3}  $(label) "), l))

@testset "BrewQuiverTerm" begin

@testset "Style" begin
    @test plain("Weird {name}") == "Weird (name)"
    @test stripped(table(["A", "Bee"], [["{red}x{/red}", "1"], ["yy", "22"]])) ==
          "A   Bee\n──  ───\nx   1\nyy  22"
    @test stripped(table(["A"], Vector{String}[])) == "–"
    t = stripped(table(["A"], [["abcdefghij"]]; maxwidth = 5))
    @test occursin("abcd…", t)
end

@testset "Overview" begin
    s = Session(single_batch())
    o = render_overview(s; width = 110)
    ls = lines(o)
    @test all(textwidth(l) == 110 for l in ls if !isempty(l))
    text = render_text(o)
    for title in ("lots", "mashtun", "kettle", "fermentor", "bottles")
        @test occursin("── $title ─", text)
    end
    @test occursin("4.5 kg Pale ale malt", text) && occursin("→ mash", text)
    @test occursin("Boil → wort", text) && occursin("→ grain_bed, kettle", text)
    wort = row(ls, "wort")
    @test occursin("1.0", wort) && occursin(" sg", wort) && occursin("IBU", wort) && occursin("°C", wort)
    @test !occursin("✱", text) && !occursin("▶", text)
    @test occursin("⚠", row(ls, "mash"))   # crystal without its pH

    # the selection, and the nodes changed by an edit
    select!(s, NodeRef(:wort))
    apply!(s, SetAmount(:crystal, 0.4u"kg"))
    ls = lines(render_overview(s; width = 110))
    @test occursin("▶✱", row(ls, "wort"))
    @test occursin("✱", row(ls, "crystal"))
    @test !occursin("✱", row(ls, "cascade"))

    # a quiver that does not brew, and an empty one
    f = render_text(render_overview(Session(overdrawn()); width = 80))
    @test occursin("–", f) && occursin(" a ", f)
    @test occursin("empty quiver", render_text(render_overview(Session(Quiver()); width = 60)))
end

@testset "Inspectors" begin
    s = Session(single_batch())
    k = render_text(render_node(s, :kettle; width = 80))
    @test all(textwidth(l) == 80 for l in split(k, '\n') if !isempty(l))
    @test occursin(":kettle  in the kettle", k)
    for x in ("volume", "gravity", "IBU", "contents", "water", "extract", "from", "to")
        @test occursin(x, k)
    end
    @test occursin("60 min remaining", k) && occursin("10 min remaining", k)
    @test occursin("Transfer ← cascade #2  25 g", k) && occursin("Drain ← rested", k)
    @test occursin("Boil → wort", k)
    @test !occursin("initial", k) && !occursin("left over", k)

    p = render_text(render_node(s, :pale; width = 80))
    @test occursin("initial", p) && occursin("Pale ale malt", p) && !occursin("contents", p)
    g = render_text(render_node(s, :grain_bed; width = 80))
    @test occursin("left over", g) && occursin("spent grain", g)
    m = render_text(render_node(s, :mash; width = 80))
    @test occursin("warnings", m) && occursin("distilled water pH", m) && occursin("mash pH", m)
    @test !occursin("water profile", render_text(render_node(s, :wort; width = 80)))
    q = single_batch()
    q[:strike_water] = water(16u"L"; temperature = 75u"°C",
                             profile = WaterProfile(calcium = 50u"mg/L", sulfate = 100u"mg/L"))
    w = render_text(render_node(Session(q), :strike_water; width = 80))
    @test occursin("water profile", w) && occursin(r"calcium\s+50 mg/L", w) && !occursin("sodium", w)

    b = render_text(render_arrow(s, ArrowRef(:kettle, :wort); width = 80))
    @test occursin("Boil  :kettle → :wort", b)
    @test occursin("time               60 min", b) && occursin("evaporation        4.0 L/h", b)
    @test occursin("evaporated", b) && occursin("duration    60 min", b)
    r = render_text(render_arrow(s, ArrowRef(:mash, :rested); width = 80))
    @test occursin("conversion   95.0%", r)
    d = render_text(render_arrow(s, ArrowRef(:chilled, :fermentor); width = 80))
    @test occursin("from the vessel or default", d) && occursin("retain", d)
    h = render_text(render_arrow(s, ArrowRef(:cascade, :kettle, 2); width = 80))
    @test occursin("#2", h) && occursin("10 min remaining", h) && occursin("moved", h)
    f = render_text(render_arrow(Session(overdrawn()), ArrowRef(:w, :a); width = 60))
    @test occursin("parameters", f) && !occursin("moved", f)
end

@testset "Status bar" begin
    s = Session(single_batch())
    t = render_text(render_statusbar(s; width = 100))
    @test occursin("new quiver ●", t) && occursin("brewed", t) && !occursin("undo", t)
    apply!(s, SetAmount(:pale, 4.8u"kg"))
    @test occursin("undo: Set :pale to 4.8 kg", render_text(render_statusbar(s)))
    mktempdir() do dir
        save!(s, joinpath(dir, "bitter.quiver.json"))
        t = render_text(render_statusbar(s))
        @test occursin("bitter.quiver.json", t) && !occursin("●", t)
    end
    @test occursin("does not brew", render_text(render_statusbar(Session(overdrawn()))))
    q = single_batch()
    equip!(q, :kettle, Vessel(capacity = 20u"L"))
    @test occursin(r"\d warnings", render_text(render_statusbar(Session(q))))
end

include("app.jl")
include("edit.jl")
include("views.jl")
include("build.jl")

end
