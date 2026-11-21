# Tutorial: a batch from scratch

This tutorial builds an English bitter from an empty quiver, using only the keys of the
app: water, malts, hops and yeast (defining them as we go), the stages of the vessels, and
the arrows between them; then it edits it, undoes, draws it, looks at its timeline, solves
it for a gravity, and saves it.

The screens below are those of the app itself, drawn while this page was built: the keys
are given to it as you would type them.

```@setup tut
using BrewQuiverTerm, BrewQuiver, Unitful, UnitfulBrewing
screen(app; width = 100, height = 24) =
    println(join(rstrip.(split(render_text(render_app(app; width, height)), '\n')), '\n'))
# press keys: characters, and \r for Enter
press!(app, keys) = foreach(k -> handle!(app, k), decode_keys(keys))
# answer the prompt on screen, replacing what it proposes
answer!(app, text) = (app.mode.buffer = ""; press!(app, text * "\r"))
```

## An empty quiver

`BrewQuiverTerm.run()` starts with an empty quiver; here, the same app without the terminal:

```@example tut
app = App(Session(Quiver()))
screen(app; height = 8)
```

## Water

`a` adds a node, and asks which kind:

```@example tut
press!(app, "a")
screen(app; height = 6)
```

`w` for water, then its label, volume and temperature:

```@example tut
press!(app, "w")
answer!(app, "strike_water 16 L 75 °C")
screen(app; height = 14)
```

The new node is selected, and the message reminds us to connect it.

## Lots of ingredients

A lot is a label, an amount and an ingredient. The quiver has no ingredients yet, so the app
offers to define it:

```@example tut
press!(app, "al")
answer!(app, "pale 4.5 kg Pale ale malt")
screen(app; height = 6)
```

```@example tut
press!(app, "f")
screen(app; height = 6)
```

```@example tut
answer!(app, "yield 80%, color 3 °L")
press!(app, "al"); answer!(app, "crystal 0.3 kg Crystal 60")
press!(app, "f"); answer!(app, "yield 74%, color 60 °L")
press!(app, "al"); answer!(app, "cascade 50 g Cascade")
press!(app, "h"); answer!(app, "alpha 6%")
press!(app, "al"); answer!(app, "yeast 1 US-05")
press!(app, "c"); answer!(app, "attenuation 78%, form dry")
screen(app; height = 16)
```

Once defined, an ingredient is found by its name or a part of it: `pale2 1 kg pale` would
take the same malt. Salts and acids are always known (`gypsum 4 g gypsum`), and a library of
ingredients can be loaded with `L`.

## Stages

The stages of each vessel are empty nodes, filled by the arrows: a label and a vessel.

```@example tut
for (label, v) in (("mash", "mashtun"), ("rested", "mashtun"), ("kettle", "kettle"),
                   ("wort", "kettle"), ("chilled", "kettle"), ("fermentor", "fermentor"),
                   ("beer", "fermentor"))
    press!(app, "as"); answer!(app, "$label $v")
end
```

## Arrows

`c` connects the node of the cursor to another, with a transfer of everything unless a kind
of arrow is given (`mashrest`, `drain`, `boil`, `chill`, `ferment`, `prime`, ...). The
quiver must brew after each edit, so the yeast goes in before the fermentation:

```@example tut
for (src, to) in ((:strike_water, "mash"), (:pale, "mash"), (:crystal, "mash"),
                  (:mash, "rested mashrest"), (:rested, "kettle drain"), (:cascade, "kettle"),
                  (:kettle, "wort boil"), (:wort, "chilled chill"), (:chilled, "fermentor drain"),
                  (:yeast, "fermentor"),
                  (:fermentor, "beer ferment"))
    select!(app.session, NodeRef(src))     # (the cursor; with the keys: ↓ ↑)
    press!(app, "c"); answer!(app, to)
end
screen(app; height = 40)
```

The batch brews, chilled to 20 °C before the fermentor: with no sparge, 16 L of water give a
small, strong wort, which the next section fixes. The `⚠` on the mash is a warning of its
mash pH: crystal malt was given no distilled water pH (the inspector, `Enter`, says so).

## Editing, and undo

`e` edits the item of the cursor; on water, it asks what to edit, and we take more water:

```@example tut
select!(app.session, NodeRef(:strike_water))
press!(app, "e")
screen(app; height = 5)
```

```@example tut
press!(app, "1"); answer!(app, "24 L")
screen(app; height = 34)
```

The nodes that changed are marked `✱`, and the status bar tells what `u` would undo. On an
arrow, `e` offers its kind and its fields, e.g. the time of the boil:

```@example tut
select!(app.session, ArrowRef(:kettle, :wort))
press!(app, "e1"); answer!(app, "70 min")
press!(app, "u")
app.message
```

Every edit can be undone (`u`) and redone (`U`); `h` shows the history:

```@example tut
press!(app, "h")
screen(app; height = 30)
```

```@example tut
press!(app, "\e")   # back
nothing # hide
```

## Inspecting

`Enter` shows the node of the cursor in detail:

```@example tut
select!(app.session, NodeRef(:kettle))
press!(app, "\r")
screen(app; height = 32)
```

`Tab` moves the cursor to the arrows leaving the node, and `Esc` goes back.

## The drawing, the timeline, and solving

`d` draws the quiver, around the cursor:

```@example tut
press!(app, "\e")
select!(app.session, NodeRef(:strike_water))
press!(app, "d")
screen(app; height = 12)
```

`t` shows when each vessel is busy; `+` zooms on the brew day:

```@example tut
press!(app, "\et++++")
screen(app; height = 12)
```

`T` solves for targets: here the original gravity, by the amount of the malts, kept in their
proportions:

```@example tut
press!(app, "\eT")
answer!(app, "beer og 1.048 sg vary pale crystal")
screen(app; height = 16)
```

## Saving

`s` saves (asking for a path the first time), and `q` quits, asking first if there are
unsaved changes:

```@example tut
press!(app, "\eS"); answer!(app, joinpath(mktempdir(), "bitter.quiver.json"))
screen(app; height = 3)
```
