using Documenter
using BrewQuiverTerm

makedocs(;
    modules = [BrewQuiverTerm],
    sitename = "BrewQuiverTerm.jl",
    authors = "JuliaBrewing contributors",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://juliabrewing.github.io/BrewQuiverTerm.jl",
        edit_link = "main",
        size_threshold_warn = 200 * 1024,
    ),
    pages = [
        "Home" => "index.md",
        "Tutorial: a batch from scratch" => "tutorial.md",
        "Views" => "views.md",
        "Keys" => "keys.md",
        "How it is built" => "design.md",
        "API reference" => "api.md",
    ],
    checkdocs = :exports,
)

deploydocs(;
    repo = "github.com/JuliaBrewing/BrewQuiverTerm.jl.git",
    devbranch = "main",
    push_preview = true,
)
