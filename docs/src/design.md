# How it is built

Everything but the drawing on a terminal is plain Julia, tested without one.

- **The core.** The session, the edit commands, undo and redo, the view data, the layout and
  the parsing of values are those of
  [BrewQuiverUICore](https://juliabrewing.github.io/BrewQuiverUICore.jl/dev/), shared with
  the graphical interface. Every edit is one of its commands: a refused one changes nothing
  and says why.
- **Rendering** functions ([`render_overview`](@ref), [`render_node`](@ref),
  [`render_dag`](@ref), ...) are pure: view data in, a Term renderable out. Tables are aligned
  text measured without its markup.
- **The app** is an [`App`](@ref): the session (whose selection is the cursor) and a
  [`Mode`](@ref) ([`Browse`](@ref), [`Inspect`](@ref), [`Prompt`](@ref), [`Confirm`](@ref),
  [`DagView`](@ref), ...). [`handle!`](@ref) does what a key does in a mode, dispatching on
  its type; [`render_app`](@ref) draws a frame of the size of the terminal.
- **The loop**, [`BrewQuiverTerm.run`](@ref), is thin: it puts the terminal in raw mode on
  the alternate screen, decodes what is typed ([`decode_keys`](@ref)), gives the keys to
  `handle!`, and draws the frames; it also reads from any `IO`, which is how it is tested.

The tests drive the app with sequences of keys and check its state and its frames, from
building a batch from an empty quiver to saving it and undoing every step.

## Adding a view

A new view is a rendering function, a mode, its `handle!` method, its `main_lines` and
`hints` in `render/app.jl`, and a key in `views.jl`; see [`TimelineView`](@ref) for an
example.
