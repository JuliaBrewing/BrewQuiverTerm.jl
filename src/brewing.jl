# The models a session brews with, the export of its recipes, and the inventory of the
# library for its brew.

const MODEL_KEYS = ['b' => :bitterness, 'c' => :color, 'a' => :abv, 'g' => :gravity]

_model_name(m) = string(nameof(typeof(m)))

# `M`: choose a model, by kind
function choose_model!(app::App)
    inuse = models_in_use(app.session)
    menu!(app, "Models", [k => ("$kind ($(_model_name(inuse[kind])))", app -> choose_model!(app, kind))
                          for (k, kind) in MODEL_KEYS])
end

function choose_model!(app::App, kind::Symbol)
    current = models_in_use(app.session)[kind]
    choices = [Char('0' + i) => (_model_name(m) * (m == current ? " (in use)" : ""),
                                 app -> edit!(app, set_model(app.session, kind, m)))
               for (i, m) in enumerate(MODEL_CHOICES[kind])]
    return menu!(app, "The $kind model", choices)
end

# `X`: export the brew as BeerJSON recipes
function export_prompt!(app::App)
    f = filepath(app.session)
    default = f === nothing ? "recipes.json" :
              replace(f, r"\.quiver\.json$" => ".beerjson.json", r"(?<!\.beerjson)\.json$" => ".beerjson.json")
    ask!(app, "Export the recipes (BeerJSON) to", default) do app, path
        export_recipes(app.session, path)
        info!(app, "exported the recipes to $(basename(path))")
    end
end

"""
    InventoryView(back)

What the brew needs of each ingredient, with the stock of the library (see
[`render_inventory`](@ref)): `C` takes it from the stock, `W` writes the library.
"""
struct InventoryView <: Mode
    back::Mode
end

"""
    render_inventory(s::Session; width = 100)

What the brew of `s` needs of each ingredient, with the stock of the library of the session
and `⚠` for what is short (or not known to be in stock).
"""
function render_inventory(s::Session; width::Integer = 100)
    rows = Vector{String}[[plain(r.name), _amount_text(r.needed),
             r.stock === nothing ? styled("–", DIM) : _amount_text(r.stock),
             r.short ? styled("⚠ short", WARNING) : styled("✓", SELECTED)] for r in inventory_rows(s)]
    n = length(library(s))
    head = block(isbrewed(s) ? styled("the library has $n ingredient" * (n == 1 ? "" : "s"), DIM) :
                               styled("the quiver does not brew", WARNING))
    return Panel(head / table(["Ingredient", "Needed", "In stock", ""], rows); title = "inventory",
                 title_style = "bold " * ACCENT, width, fit = false, style = DIM)
end
_amount_text(x::Real) = "$(round(Int, x)) ×"
_amount_text(x) = value_text(x)

function handle!(app::App, v::InventoryView, key)
    if key === 'C'
        menu!(app, "Take what the brew uses from the stock of the library?", [
            'y' => ("yes", app -> begin
                messages = consume_stock!(app.session)
                info!(app, "took the brew from the stock" *
                           (isempty(messages) ? "" : ": $(length(messages)) short") *
                           "; W writes the library")
            end),
            'n' => ("no", app -> app)])
    elseif key === 'W'
        ask!(app, "Write the library to", something(app.library_path, "ingredients.json")) do app, path
            save_library(app.session, path)
            app.library_path = String(path)
            info!(app, "wrote the library to $(basename(path))")
        end
    elseif key === :down
        app.scroll += 1
    elseif key === :up
        app.scroll = max(0, app.scroll - 1)
    else
        app.mode = v.back
        app.scroll = 0
    end
    return app
end

# the keys for brewing, common to browsing and inspecting; whether `key` was one
function _brewing_keys!(app::App, key)
    if key === 'M'
        choose_model!(app)
    elseif key === 'X'
        export_prompt!(app)
    elseif key === 'I'
        app.mode = InventoryView(app.mode)
        app.scroll = 0
    else
        return false
    end
    return true
end
