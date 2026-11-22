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
edit_lot!(app::App, n, c, ::Mixed) = error!(app, ":$n holds several things: set them on the nodes it comes from")
edit_lot!(app::App, n, c, ::AgentLot) = edit_amount!(app, n, total_mass(c), :agent)
edit_lot!(app::App, n, c, ::IngredientLot) =
    menu!(app, "Edit :$n", ['1' => ("amount", app -> edit_amount!(app, n, only(c.solids).amount,
                                                                     unit_role(only(c.solids).ingredient))),
                            '2' => ("ingredient", app -> pick_ingredient!(app, n, only(c.solids).ingredient))])
edit_lot!(app::App, n, c, ::WaterLot) =
    menu!(app, "Edit :$n", ['1' => ("volume", app -> edit_amount!(app, n, uconvert(u"L", volume(c)), :volume)),
                            '2' => ("temperature", app -> edit_temperature!(app, n, c)),
                            '3' => ("water profile", app -> edit_profile!(app, n, c))])

# (shown, and read when typed without a unit, in the preferred unit of `role`)
edit_amount!(app::App, n, current, role) =
    ask!(app, "Amount of :$n", qtext(app.session, current; role)) do app, text
        edit!(app, SetAmount(n, parse_value(app.session, text, current; role)))
    end

edit_temperature!(app::App, n, c) =
    ask!(app, "Temperature of :$n", qtext(app.session, c.liquor.temperature)) do app, text
        edit!(app, SetTemperature(n, parse_value(app.session, text, c.liquor.temperature)))
    end

const IONS = (:calcium, :magnesium, :sodium, :chloride, :sulfate, :bicarbonate)

# a water profile as typed: "calcium 50, sulfate 100" (mg/L when no unit is given)
function profile_text(p)
    t = join(("$ion $(round(Int, ustrip(u"mg/L", getfield(p, ion))))" for ion in IONS
              if !iszero(getfield(p, ion))), ", ")
    return isempty(t) ? "" : t * " mg/L"
end
function parse_profile(text)
    kw = Dict{Symbol, Unitful.Quantity}()
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

# ---------------------------------------------------------------------------------------
# finding and defining ingredients

# the kinds of ingredients that can be defined, and the properties each takes
const INGREDIENT_KINDS = [
    'f' => ("fermentable", Fermentable, (:yield, :potential, :color, :moisture, :di_ph, :buffering, :kind)),
    'h' => ("hop", Hop, (:alpha, :form)),
    'c' => ("culture", Culture, (:attenuation, :kind, :form))]
const SYMBOL_PROPERTIES = (:kind, :form)

# the role of the ingredients of a type (see `unit_role`), or `nothing` for any
_role(::Nothing) = nothing
_role(::Type{Fermentable}) = :fermentable
_role(::Type{Hop}) = :hop
_role(::Type{Culture}) = :culture
_role(::Type) = :agent

# do `f(app, ingredient)` with the ingredient of the catalog named `text` (of type `kind`, if
# given): the one of that name, or the only one matching it; when several match, choose one
# in a list (or define a new one); when none does, offer to define it
function with_ingredient(f, app::App, text, kind = nothing)
    name = String(strip(text))
    isempty(name) && return error!(app, "give the name of an ingredient")
    c = catalog(app.session)
    ok(i) = kind === nothing || i isa kind
    for (n, i) in c
        lowercase(n) == lowercase(name) && ok(i) && return f(app, i)
    end
    role = _role(kind)
    found = search_ingredients(app.session, name; role)
    length(found) == 1 && return f(app, c[only(found)])
    isempty(found) && return define_menu!(f, app, name, kind)
    app.mode = Picker("Which ingredient?", search_ingredients(app.session; role); filter = name,
                      submit = (app, x) -> f(app, c[x]), back = app.mode, tags = ingredient_tags(app.session),
                      search = t -> search_ingredients(app.session, t; role),
                      create = (app, t) -> define_menu!(f, app, t, kind))
    return info!(app, "$(length(found)) ingredients match $(repr(name)): choose one, or define it")
end

# define a new ingredient named `name` (a `kind`, or asking which), then `f(app, ingredient)`
function define_menu!(f, app::App, name, kind = nothing)
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
    kw = Dict{Symbol, Union{Symbol, Unitful.Quantity, Real}}()
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

# `a`: add an ingredient (from a list, or typed), water, a stage, or start from a template
add_node!(app::App) =
    menu!(app, "Add", ['i' => ("an ingredient", add_ingredient!), 'w' => ("water", add_water!),
                       's' => ("a stage", add_stage!), 'l' => ("an ingredient, typed", add_lot!),
                       't' => ("a template", pick_template!)])

function _added!(app::App, cmd)
    edit!(app, cmd)
    if haskey(quiver(app.session), cmd.label) && !app.iserror
        select!(app.session, NodeRef(cmd.label))
        app.column = nothing
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

# `a i`: an ingredient chosen in a list of the catalog (and water), typed to search, then its
# label and amount
function add_ingredient!(app::App)
    s = app.session
    tags = ingredient_tags(s)
    tags["water"] = "water"
    app.mode = Picker("Add an ingredient", ["water"; search_ingredients(s)];
                      submit = (app, x) -> x == "water" ? add_water!(app) : add_amount!(app, catalog(app.session)[x]),
                      back = app.mode, tags,
                      search = t -> [occursin(lowercase(strip(t)), "water") ? ["water"] : String[];
                                     search_ingredients(app.session, t)],
                      create = (app, t) -> define_menu!(add_amount!, app, t))
    return info!(app, "type to search $(length(app.mode.items)) ingredients")
end

# the label and amount of a new lot of `i`
function add_amount!(app::App, i)
    p = units(app.session)
    example = i isa Culture ? "1" : qtext(app.session, _default_amount(i); role = unit_role(i))
    ask!(app, "Add $(i.name): its label and amount (e.g. $(suggest_label(app.session, i.name)) $example)",
         suggest_label(app.session, i.name) * " " * example) do app, text
        label, amount = parse_label_amount(text)
        a = amount isa Real && !(i isa Culture) ? amount * preferred_unit(p, unit_role(i)) : amount
        _added!(app, AddNode(label, i => a))
    end
end

_default_amount(::Fermentable) = 1.0u"kg"
_default_amount(::Hop) = 25.0u"g"
_default_amount(::AbstractIngredient) = 5.0u"g"

# a label for a lot of the ingredient `name` not taken in the quiver of `s`: its first word,
# or all its words, joined by underscores, numbered if needed
function suggest_label(s, name)
    q = quiver(s)
    words = [w for w in split(lowercase(name), r"[^\p{L}\p{N}]+") if !isempty(w)]
    isempty(words) && (words = ["lot"])
    for l in unique([words[1]; join(words, "_")])
        occursin(r"^\p{L}", l) && !haskey(q, Symbol(l)) && return l
    end
    base = join(words, "_")
    k = 2
    while haskey(q, Symbol(base, "_", k))
        k += 1
    end
    return "$(base)_$k"
end

# `a l`: typed, with the ingredient completed by Tab
function add_lot!(app::App)
    ask!(app, "Add (label amount ingredient, Tab completes)") do app, text
        label, amount, name = parse_lot(text)
        with_ingredient(app, name) do app, i
            # (a bare number: the preferred unit of the ingredient, but a count of a culture)
            a = amount isa Real && !(i isa Culture) ? amount * preferred_unit(units(app.session), unit_role(i)) : amount
            _added!(app, AddNode(label, i => a))
        end
    end
    app.mode.complete = buffer -> _complete_lot(app.session, buffer)
    return app
end

# the completions of the name of the ingredient typed after the label and amount: the text
# before it, and the names of the catalog matching it
function _complete_lot(s, buffer)
    words = split(buffer)
    k = _amount_index(words)
    (k === nothing || k == length(words) && !endswith(buffer, ' ')) && return buffer, String[]
    _, after = try quantity_at(words, k) catch; return buffer, String[] end
    n = length(words) ≥ after ? join(words[after:end], " ") : ""
    prefix = join(words[1:after-1], " ") * " "
    return prefix, isempty(strip(n)) ? String[] : search_ingredients(s, n)
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

# the index of the first word of an amount (a number), after the words of a label
_amount_index(words) = findfirst(w -> occursin(r"^[+-]?[\d.]", w), words)

# the label of the words before the amount: "pale malt" as :pale_malt
function _label_words(words, k, example)
    (k === nothing || k == 1) && throw(ArgumentError("give a label, then an amount: $example"))
    return Symbol(join((lstrip(w, ':') for w in words[1:k-1]), "_"))
end

# "munich 0.5 kg Munich malt" as (:munich, 0.5 kg, "Munich malt"); "yeast 1 US-05" for counts;
# a label of several words is joined by underscores ("pale malt 4 kg ..." as :pale_malt)
function parse_lot(text)
    words = split(text)
    k = _amount_index(words)
    label = _label_words(words, k, "munich 0.5 kg Munich malt")
    amount, after = quantity_at(words, k)
    after ≤ length(words) || throw(ArgumentError("give the ingredient after the amount"))
    return label, amount, join(words[after:end], " ")
end

# "pale malt 4.5 kg" as (:pale_malt, 4.5 kg)
function parse_label_amount(text)
    words = split(text)
    k = _amount_index(words)
    label = _label_words(words, k, "pale 4.5 kg")
    amount, after = quantity_at(words, k)
    after ≤ length(words) && throw(ArgumentError("give only a label and an amount, e.g. pale 4.5 kg"))
    return label, amount
end

# "strike_water 16 L 75 °C" as (:strike_water, 16 L, 75 °C); 20 °C if not given; numbers
# without units in `volume` and `temperature`, if given
function parse_water(text; volume = nothing, temperature = nothing)
    words = split(text)
    i = _amount_index(words)
    label = _label_words(words, i, "strike_water 16 L 75 °C")
    v, k = quantity_at(words, i)
    v isa Real && volume !== nothing && (v = v * volume)
    v isa Unitful.Volume || throw(ArgumentError("give the volume of the water, e.g. 16 L"))
    t = k ≤ length(words) ? parse_value(join(words[k:end], " "); unit = temperature) : 20.0u"°C"
    t isa Unitful.Temperature || throw(ArgumentError("give the temperature of the water, e.g. 75 °C"))
    return label, v, t
end

add_water!(app::App) =
    ask!(app, "Add water: its label, volume and temperature (e.g. strike_water 16 L 75 °C)",
         suggest_label(app.session, "water") * " ") do app, text
        p = units(app.session)
        label, v, temperature = parse_water(text; volume = preferred_unit(p, :volume),
                                            temperature = preferred_unit(p, :temperature))
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
    role = field_role(f)
    ask!(app, "$(f.label) of the $v", f.value === nothing ? "" : qtext(app.session, f.value; role)) do app, text
        value = f.name === :name ? String(strip(text)) : parse_value(app.session, text, f.value; role)
        edit!(app, SetEquipmentField(v, f.name, value))
    end
end

# `L`: load a library of ingredients
load_library!(app::App) =
    ask!(app, "Load a library of ingredients (a BeerJSON document)") do app, path
        isfile(path) || throw(ArgumentError("there is no file $path"))
        set_library!(app.session, path)
        app.library_path = String(path)
        info!(app, "loaded $(length(library(app.session))) ingredients from $(basename(path))")
    end
