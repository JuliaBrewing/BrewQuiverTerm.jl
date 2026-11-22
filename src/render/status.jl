# The status bar: the file, unsaved changes, the state of the brew, what undo would undo.

"""
    render_statusbar(s::Session; width = 100)

One line: the file of the session (or "new quiver") with `●` if it has unsaved changes,
the state of the brew (`ok`, `empty` for a quiver without nodes, or why it does not brew), the number of warnings, and the step undo would undo.
"""
function render_statusbar(s::Session; width::Integer = 100)
    f = filepath(s)
    file = f === nothing ? styled("new quiver", DIM) : plain(basename(f))
    isdirty(s) && (file *= " " * styled("●", CHANGED))
    st = isempty(nodes(quiver(s))) ? styled("empty", DIM) :
         isbrewed(s) ? styled("ok", SELECTED) :
                       styled("does not brew: " * plain(first(sprint(show, status(s)), 60)), WARNING)
    parts = [file, st]
    isempty(models(s)) ||
        push!(parts, styled("models: ", DIM) * join((string(nameof(typeof(m))) for m in values(models(s))), ", "))
    n = length(warnings(s))
    n > 0 && push!(parts, styled("$n warning" * (n == 1 ? "" : "s"), WARNING))
    u = undo_description(s)
    u === nothing || push!(parts, styled("undo: ", DIM) * plain(u))
    line = join(parts, styled("  │  ", DIM))
    return RenderableText(line; width)
end
