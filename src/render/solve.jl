# Targets and solving: what is typed to solve, and the solution.

# the quantities a target can be on, by name
const TARGET_QUANTITIES = Dict(
    "gravity" => gravity, "og" => original_gravity, "volume" => volume, "ibu" => ibu,
    "srm" => srm, "color" => srm, "abv" => abv, "carbonation" => carbonation)

"""
    parse_solve(text) -> Solve

The [`Solve`](@ref) command of what is typed: targets, then `vary` and the parameters, as
many as the targets, separated by commas:

    fermentor gravity 1.050 sg, wort ibu 30 IBU vary pale crystal, cascade

A target is a node, a quantity (gravity, og, volume, ibu, srm or color, abv, carbonation)
and its goal; a parameter is lots scaled together (`pale crystal`, see `Amount`), or a field
of an arrow, `source>destination.field` or `source>destination#2.field` (see `Setting`).
"""
function parse_solve(text::AbstractString)
    parts = split(text, r"\s+vary\s+"i)
    length(parts) == 2 || throw(ArgumentError(
        "give the targets, then vary and what to vary: e.g. fermentor gravity 1.050 sg vary pale crystal"))
    targets = [_target(strip(t)) for t in split(parts[1], ',') if !isempty(strip(t))]
    vary = [_parameter(strip(p)) for p in split(parts[2], ',') if !isempty(strip(p))]
    return Solve(targets, vary)
end

function _target(t)
    words = split(t)
    length(words) ≥ 3 || throw(ArgumentError("a target is a node, a quantity and a goal, not $(repr(String(t)))"))
    f = get(TARGET_QUANTITIES, lowercase(words[2]), nothing)
    f === nothing && throw(ArgumentError("$(repr(String(words[2]))) is not a quantity to target: " *
                                         join(sort(collect(keys(TARGET_QUANTITIES))), ", ")))
    return Target(_label(words[1]), f, parse_value(join(words[3:end], " ")))
end

function _parameter(p)
    m = match(r"^:?(\w+)\s*>\s*:?(\w+)(?:#(\d+))?\.(\w+)$", p)
    m === nothing || return Setting(Symbol(m[1]) => Symbol(m[2]), Symbol(m[4]);
                                    index = m[3] === nothing ? 1 : parse(Int, m[3]))
    return Amount(_label.(split(p))...)
end

"""
    render_solution(sol; width = 100)

A `Solution` of [`Solve`](@ref): whether it converged and in how many iterations, the
values of the parameters, and each target with its goal and what was reached.
"""
function render_solution(sol; width::Integer = 100)
    r = solution_rows(sol)
    head = r.converged ? styled("converged in $(r.iterations) iteration" * (r.iterations == 1 ? "" : "s"), SELECTED) :
                         styled("did not converge in $(r.iterations) iterations: the quiver is left at the best point found", WARNING)
    params = table(["Parameter", "Value"], [[plain(p.name), _value_text(p.value)] for p in r.parameters])
    targets = table(["Node", "Quantity", "Goal", "Reached"],
                    [[plain(t.node), t.quantity, value_text(t.goal), value_text(t.reached)] for t in r.targets])
    return Panel(block(head) / section("parameters") / params / section("targets") / targets;
                 title = "solution", title_style = "bold " * ACCENT, width, fit = false, style = DIM)
end

# the value of a parameter: the contents of lots, or the value of a field
_value_text(x) = value_text(x)
_value_text(c::Contents) = _contents_text(c)
_value_text(d::AbstractDict) = join((":$k " * _contents_text(v) for (k, v) in sort(collect(d); by = first)), ", ")
_contents_text(c::Contents) =
    isempty(c.solids) ? value_text(uconvert(u"L", volume(c))) :
    join((value_text(r.amount) * " " * plain(r.name) for r in solid_rows(c)), ", ")
