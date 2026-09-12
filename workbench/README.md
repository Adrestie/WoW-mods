# The workbench

A component shared by the modules of this repository: ONE object in the
world (game object 803700), ONE window, and any number of modules bringing
their recipes to it. None of them owns it.

`Workbench.ext` is the server side -- the Lua engine loads `.ext` files
before every `.lua`, so a module's provider finds the global `Workbench`
ready -- and `Workbench_Client.lua` the window, sent over AIO. `VERSION` is
an integer; an installer replaces a copy in place only by a newer one.

Every module that uses the bench ships an identical copy of this folder as
`data/lua/Workbench/`, and its installer places it in `lua_scripts/Workbench/`
when it is absent or older, and removes it when no other provider remains.
The object's template is shipped by every such module too, inserted only
when absent, and removed by the last one to go.

A module registers itself as a provider from its own Lua:

```lua
Workbench.Register({
    module  = "mod-something",
    Owns    = function(entry) ... end,             -- is that item ours?
    kinds   = {                                    -- the item types, in order (optional)
        { key = "stone", name = { enUS = "Stones", frFR = "Pierres" },
          Of = function(entry) ... end },          -- is that item of this type?
    },
    recipes = {
        { key = "fuse", slots = 3,
          name = { enUS = "Fuse three stones", frFR = "Fusionner trois pierres" },
          Fits    = function(player, placed, entry) ... end, -- may that item join what is placed?
          Accepts = function(player, entries) ... end,    -- is that combination sound?
          Preview = function(player, entries) ... end,    -- what it gives (optional)
          Run     = function(player, entries) ... end },  -- do it: the module's own command
    },
})
```

The window is the one the sphere grid's workbench had: three slots, an
arrow, the result, a "Craft" button, a list under a clicked slot of what the
bags hold that the bench would take -- sorted by type, quality and name, with
a tab per type standing on its left edge when several are present -- and an
"i" in the corner listing the recipes -- those of the locked craft, or of every craft while the bench is
empty. The line above the slots names the recipe the placed items make; the
result box shows what `Preview` returns for it: `{ entry = item }` for an
item known in advance, or `{ icon = path, text = "...", quality = n }` for a
draw or an amount. Without `Preview`, the box shows the recipe's name.
For an item, the server sends the client the item's card (the same packet
the core answers an item query with, built from `item_template`) before the
state, so the result shows at once even for an item the player never held.

What is on the bench decides: the first item placed names its provider, and
while anything stays on the bench an item of another provider is refused;
taking everything off frees the bench. Within the provider, an item is
offered in the list and accepted on the bench only if some recipe with room
left says it may join what is placed (`Fits`, optional: a recipe without it
takes anything the provider owns).

The source of truth is this folder; the author's tooling copies it into every
module that uses it.
