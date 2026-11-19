# The history of the edits.

"""
    render_history(s::Session; width = 80)

The steps of the history of `s`, oldest first: those done (✓), which undo would undo from
the last, and those undone (dim), which redo would redo from the first; the step whose
state was saved is marked "saved", and the current state "◀ now".
"""
function render_history(s::Session; width::Integer = 80)
    hs = history(s)
    lines = String[]
    now = findlast(h -> h.done, hs)
    now === nothing && push!(lines, styled("  the opened quiver", DIM) * styled("  ◀ now", ACCENT))
    for (i, h) in enumerate(hs)
        t = h.done ? styled("✓ ", SELECTED) * plain(h.description) : styled("  " * plain(h.description), DIM)
        h.saved && (t *= styled("  saved", CHANGED))
        i == now && (t *= styled("  ◀ now", ACCENT))
        push!(lines, t)
    end
    isempty(hs) && push!(lines, styled("no edits yet", DIM))
    return Panel(block(join(lines, '\n')); title = "history", title_style = "bold " * ACCENT,
                 width, fit = false, style = DIM)
end
