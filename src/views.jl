# The other views of the app: the drawing of the quiver, the timeline, and solving.

"""
    DagView()

The drawing of the quiver (see [`render_dag`](@ref)): the keys move the selection as in the
overview; `l` arranges the nodes (the layout of BrewQuiverUICore, undoable).
"""
struct DagView <: Mode end

"""
    TimelineView(back, zoom)

The timeline (see [`render_timeline`](@ref)): `+` and `-` zoom in and out on its start.
"""
mutable struct TimelineView <: Mode
    back::Mode
    zoom::Int
end

"""
    SolutionView(back, solution)

The solution of the last `Solve`.
"""
struct SolutionView <: Mode
    back::Mode
    solution::Any
end

# `T`: solve for targets
function solve_prompt!(app::App)
    ask!(app, "Solve (targets vary parameters), e.g. fermentor gravity 1.050 sg vary pale crystal") do app, text
        cmd = parse_solve(text)
        sol = apply!(app.session, cmd)
        app.mode = SolutionView(app.mode, sol)
        sol.converged ? info!(app, describe(cmd)) : error!(app, describe(cmd) * ": did not converge")
    end
end

# the keys of the views, common to browsing and inspecting; whether `key` was one
function _view_keys!(app::App, key)
    if key === 'd'
        app.mode = app.mode isa DagView ? Browse() : DagView()
        app.scroll = 0
    elseif key === 't'
        app.mode = TimelineView(app.mode, 0)
        app.scroll = 0
    elseif key === 'T'
        solve_prompt!(app)
    else
        return false
    end
    return true
end

function handle!(app::App, ::DagView, key)
    _common!(app, key) && return app
    if key in (:down, :right)
        move!(app, 1)
    elseif key in (:up, :left)
        move!(app, -1)
    elseif key === 'l'
        attempt(app) do
            layout!(app.session)
            info!(app, "arranged the nodes")
        end
    elseif key === :enter
        current(app) === nothing || (app.mode = Inspect(); app.scroll = 0)
    elseif key in (:esc, 'q')
        app.mode = Browse()
    end
    return app
end

function handle!(app::App, v::TimelineView, key)
    if key in ('+', '=')
        v.zoom = min(v.zoom + 1, 12)
    elseif key === '-'
        v.zoom = max(v.zoom - 1, 0)
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

function handle!(app::App, v::SolutionView, key)
    app.mode = v.back
    key in ('u', :ctrl_z) && undo_step!(app)          # (undo the solve)
    return app
end
