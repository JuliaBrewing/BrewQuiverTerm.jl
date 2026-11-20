# Lots and their ingredients: editing a lot by what it holds, adding stages, lots and water,
# defining new ingredients, the equipment of vessels, and the library of ingredients.

# what a node holds, which decides how it is edited
abstract type Holding end
struct Stage <: Holding end            # filled by its arrows
struct IngredientLot <: Holding end    # one ingredient (a malt, a hop, a yeast)
struct WaterLot <: Holding end         # water, with its temperature and profile
struct AgentLot <: Holding end         # a salt or an acid, dissolved
struct Mixed <: Holding end            # several things

function holding(c::Contents)
    iszero(c) && return Stage()
    iszero(c.liquor) && length(c.solids) == 1 && only(c.solids) isa Portion && return IngredientLot()
    isempty(c.solids) || return Mixed()
    l = c.liquor
    # (an acid holds some water: water is a lot of more water than minerals)
    iszero(l.extract) && iszero(l.alcohol) && mass(l) > total_mass(c) - mass(l) && return WaterLot()
    iszero(l.extract) && iszero(l.alcohol) && return AgentLot()
    return Mixed()
end

function edit_item!(app::App, r::NodeRef)
    c = quiver(app.session)[r.label].initial
    return edit_lot!(app, r.label, c, holding(c))
end

edit_lot!(app::App, n, c, ::Stage) = error!(app, ":$n is filled by its arrows: edit them (Tab to select one)")
edit_lot!(app::App, n, c, ::Mixed) = error!(app, ":$n holds several things: set them on the lots it comes from")
edit_lot!(app::App, n, c, ::AgentLot) = edit_amount!(app, n, format(total_mass(c)))
edit_lot!(app::App, n, c, ::IngredientLot) =
    menu!(app, "Edit :$n", ['1' => ("amount", app -> edit_amount!(app, n, format(only(c.solids).amount))),
                            '2' => ("ingredient", app -> edit_ingredient!(app, n, only(c.solids).ingredient))])
edit_lot!(app::App, n, c, ::WaterLot) =
    menu!(app, "Edit :$n", ['1' => ("volume", app -> edit_amount!(app, n, format(volume(c)))),
                            '2' => ("temperature", app -> edit_temperature!(app, n, c)),
                            '3' => ("water profile", app -> edit_profile!(app, n, c))])

edit_amount!(app::App, n, current) =
    ask!(app, "Amount of :$n", current) do app, text
        edit!(app, SetAmount(n, parse_value(text)))
    end

edit_temperature!(app::App, n, c) =
    ask!(app, "Temperature of :$n", format(c.liquor.temperature)) do app, text
        edit!(app, SetTemperature(n, parse_value(text)))
    end

const IONS = (:calcium, :magnesium, :sodium, :chloride, :sulfate, :bicarbonate)

# a water profile as typed: "calcium 50, sulfate 100" (mg/L when no unit is given)
function profile_text(p)
    t = join(("$ion $(round(Int, ustrip(u"mg/L", getfield(p, ion))))" for ion in IONS
              if !iszero(getfield(p, ion))), ", ")
    return isempty(t) ? "" : t * " mg/L"
end
function parse_profile(text)
    kw = Dict{Symbol, Any}()
    unit = occursin("ppm", text) ? u"mg/L" : nothing
    for part in split(replace(text, "mg/L" => "", "ppm" => ""), ',')
        words = split(part)
        isempty(words) && continue
        ion = Symbol(lowercase(words[1]))
        ion in IONS || throw(ArgumentError("$(repr(String(words[1]))) is not an ion: " * join(IONS, ", ")))
        length(words) == 2 || throw(ArgumentError("give each ion and its concentration: calcium 50, sulfate 100"))
        v = parse_value(words[2])
        kw[ion] = v isa Real ? v * something(unit, u"mg/L") : v
    end
    return WaterProfile(; kw...)
end

edit_profile!(app::App, n, c) =
    ask!(app, "Water profile of :$n (mg/L)", profile_text(profile(c))) do app, text
        edit!(app, SetWaterProfile(n, parse_profile(text)))
    end

# the ingredient of a lot: one of the catalog, or a new one of the same kind
edit_ingredient!(app::App, n, old) =
    ask!(app, "Ingredient of :$n", old.name) do app, text
        with_ingredient(app, text, typeof(old)) do app, i
            edit!(app, SetIngredient(n, i))
        end
    end

# ---------------------------------------------------------------------------------------
# finding and defining ingredients

# the kinds of ingredients that can be defined, and the properties each takes
const INGREDIENT_KINDS = [
    'f' => ("fermentable", Fermentable, (:yield, :potential, :color, :moisture, :di_ph, :buffering, :kind)),
    'h' => ("hop", Hop, (:alpha, :form)),
    'c' => ("culture", Culture, (:attenuation, :kind, :form))]
const SYMBOL_PROPERTIES = (:kind, :form)

# do `f(app, ingredient)` with the ingredient of the catalog named `text`; if there is none,
# offer to define it (as a `kind`, or asking which)
function with_ingredient(f, app::App, text, kind = nothing)
    name = strip(text)
    i = try
        find_ingredient(app.session, name)
    catch e
        e isa ArgumentError || rethrow()
        occursin("no ingredient", e.msg) || return error!(app, e.msg)
        nothing
    end
    i === nothing || return f(app, i)
    kinds = [k => (label, app -> define_ingredient!(f, app, name, label, T, props))
             for (k, (label, T, props)) in INGREDIENT_KINDS if kind === nothing || T === kind]
    isempty(kinds) && return error!(app, "there is no ingredient named $(repr(String(name)))")
    return menu!(app, "There is no ingredient named $(repr(String(name))). Define it as a", kinds)
end

function define_ingredient!(f, app::App, name, label, T, props)
    ask!(app, "New $label $(repr(String(name))), e.g. " * EXAMPLES[label]) do app, text
        f(app, T(String(name); parse_properties(text, props)...))
    end
end

const EXAMPLES = Dict("fermentable" => "yield 80%, color 9 °L",
                      "hop" => "alpha 5%, form pellet",
                      "culture" => "attenuation 78%, kind ale, form dry")

# "yield 80%, color 9 °L" as keyword arguments, among the `props` allowed
function parse_properties(text, props)
    kw = Dict{Symbol, Any}()
    for part in split(text, ',')
        words = split(part)
        isempty(words) && continue
        k = Symbol(lowercase(words[1]))
        k in props || throw(ArgumentError("$(repr(String(words[1]))) is not a property: " * join(props, ", ")))
        length(words) ≥ 2 || throw(ArgumentError("give a value for $k"))
        v = join(words[2:end], " ")
        kw[k] = k in SYMBOL_PROPERTIES ? Symbol(lowercase(v)) : parse_value(v)
    end
    return kw
end

# ---------------------------------------------------------------------------------------
# adding nodes

# `a`: add a stage, a lot of an ingredient, or water
add_node!(app::App) =
    menu!(app, "Add", ['s' => ("a stage", add_stage!), 'l' => ("a lot of an ingredient", add_lot!),
                       'w' => ("water", add_water!)])

function _added!(app::App, cmd)
    edit!(app, cmd)
    if haskey(quiver(app.session), cmd.label) && !app.iserror
        select!(app.session, NodeRef(cmd.label))
        info!(app, describe(cmd) * ": connect it with c")
    end
    return app
end

add_stage!(app::App) =
    ask!(app, "Add a stage: its label, and its vessel if any (e.g. trub kettle)") do app, text
        words = split(text)
        isempty(words) && return error!(app, "give a label")
        _added!(app, AddNode(_label(words[1]); vessel = length(words) > 1 ? _label(words[2]) : nothing))
    end

add_lot!(app::App) =
    ask!(app, "Add a lot: its label, amount and ingredient (e.g. munich 0.5 kg Munich malt)") do app, text
        label, amount, name = parse_lot(text)
        with_ingredient(app, name) do app, i
            _added!(app, AddNode(label, i => amount))
        end
    end

# the quantity typed from word `i` ("0.5 kg", or "0.5kg", or a count "2"), and the index of
# the word after it
function quantity_at(words, i)
    if i + 1 ≤ length(words)
        q = try parse_value(words[i] * " " * words[i+1]) catch; nothing end
        q isa Unitful.Quantity && return q, i + 2
    end
    return parse_value(words[i]), i + 1
end

# "munich 0.5 kg Munich malt" as (:munich, 0.5 kg, "Munich malt"); "yeast 1 US-05" for counts
function parse_lot(text)
    words = split(text)
    length(words) ≥ 3 || throw(ArgumentError("give a label, an amount and an ingredient: munich 0.5 kg Munich malt"))
    amount, k = quantity_at(words, 2)
    k ≤ length(words) || throw(ArgumentError("give the ingredient after the amount"))
    return _label(words[1]), amount, join(words[k:end], " ")
end

# "strike_water 16 L 75 °C" as (:strike_water, 16 L, 75 °C); 20 °C if not given
function parse_water(text)
    words = split(text)
    length(words) ≥ 2 || throw(ArgumentError("give a label and a volume: strike_water 16 L 75 °C"))
    v, k = quantity_at(words, 2)
    v isa Unitful.Volume || throw(ArgumentError("give the volume of the water, e.g. 16 L"))
    t = k ≤ length(words) ? parse_value(join(words[k:end], " ")) : 20.0u"°C"
    t isa Unitful.Temperature || throw(ArgumentError("give the temperature of the water, e.g. 75 °C"))
    return _label(words[1]), v, t
end

add_water!(app::App) =
    ask!(app, "Add water: its label, volume and temperature (e.g. strike_water 16 L 75 °C)") do app, text
        label, v, temperature = parse_water(text)
        _added!(app, AddNode(label, water(v; temperature)))
    end

# ---------------------------------------------------------------------------------------
# equipment and library

# `E`: a field of the equipment of the vessel of the node of the cursor
function edit_equipment!(app::App)
    n = current_node(app)
    n === nothing && return app
    v = vessel(quiver(app.session), n)
    v === nothing && return error!(app, ":$n is in no vessel: set its vessel with v")
    eq = something(equipment(quiver(app.session), v), Vessel())
    choices = [Char('0' + i) => (f.label, app -> edit_equipment_field!(app, v, f))
               for (i, f) in enumerate(fields(eq)) if i ≤ 9]
    return menu!(app, "Edit which field of the equipment of the $v?", choices)
end

function edit_equipment_field!(app::App, v, f::FieldSpec)
    ask!(app, "$(f.label) of the $v", f.value === nothing ? "" : format(f.value)) do app, text
        value = f.name === :name ? String(strip(text)) : parse_value(text)
        edit!(app, SetEquipmentField(v, f.name, value))
    end
end

# `L`: load a library of ingredients
load_library!(app::App) =
    ask!(app, "Load a library of ingredients (a BeerJSON document)") do app, path
        isfile(path) || throw(ArgumentError("there is no file $path"))
        set_library!(app.session, path)
        info!(app, "loaded $(length(library(app.session))) ingredients from $(basename(path))")
    end
