# Changelog

The version is the first word of the newest heading; the installer writes it
into the mark it leaves in the client's archive.

## 0.1.0 (unreleased)

- The catalogue: cards with four edges, boards with a number per row and per
  column, tags, and the effect of a card at each of its four levels. Loaded
  before the world opens, reloaded by `.tarot reload`.
- `.tarot info` and `.tarot reload`. Handing out a card is the core's `.additem`.
- The installer, the remover, the identifier shift, the backups.
- A test catalogue of twelve cards and three boards, with placeholder effects.
- The binder: a card or a board used from the bags joins the account's
  collection and is destroyed; one already known is refused, and its tooltip
  says so. `.tarot study`, `.tarot binder`, the `/tarot` window with its tags.
- The two spells the client must know for a card or a board to be usable,
  shipped for the server (`spell_dbc`) and the client (`stellartarot_Spell.dbc`).
- The board: a slot to equip one, cards laid by drag and drop and taken off by
  right-click, the board's numbers around the grid, each edge lit where it
  matches and the activation level of each card, "Remove all", the card in
  hand shown large with its four levels, the list of active effects, and
  presets saved for the account. `.tarot board|place|remove|clear|preset`,
  and `.tarot layout` for game masters.
- The effects: a card is one row, with a spell and/or a script per level and
  a `cumulative` flag; applied as auras and script instances, recomputed at
  every change of the layout, at login and at reload. A card that cannot be
  played is refused at load. Two example scripts, `gold_on_kill` and
  `heal_on_kill`, described through `module_string`. `.tarot effects`.
- Forty-four test auras, one per card and level, +1234 to one statistic,
  hidden from the aura bar; one visible banner aura, "Stellar Tarot", while
  any effect is in force.
- The deck: an "All" tab and one per tag, every card carries one tag, every
  card of the tab shown -- free, laid, or unknown with the hint to find it;
  a number for the players in front of every name. A larger window: Deck,
  Board, and Preview over Active effects, all of one width.
- The board: a laid card fills its cell, its edge numbers in small
  trapezoids of the module's own art (black, or dark green on a match), the
  board's numbers lit green when matched, two numbers per row and per column,
  a preview of each board in the picker, a confirmation before "Remove all".
- The banner aura's tooltip lists the effects in force, merged by kind with
  their figures added. "Active effects" reads as an equipment set: the card,
  then one line per active level.
- The cards' art: a card is composed in the window from a frame, its
  illustration (512 x 512 behind the frame's window) and its icon (256 x 256,
  cut on the card's subject, framed like the game's icons). The `art` column
  names the pair; the twelve test cards ship with theirs.
- Laying a card on a taken cell replaces the card there; a laid card can be
  dragged to another cell (a move, or a swap with the card there) or off the
  board. `.tarot move`. While a card is held over the board, the window
  shows the outcome before it is let go: matches and levels gained in cyan,
  lost in red.
- The loot: where cards and boards come from, one row per source in
  `mod_stellar_tarot_source` -- a given card or board or one drawn at random,
  from a creature killed, sorted by entry, expansion, place, heroic mode,
  rank and level. What wins joins the loot window. Three settings: on/off, a
  rate on every chance, whether a known card may drop again. `.tarot sources`.
- The workbench: a component shared with the other modules of the repository
  (`data/lua/Workbench/`, placed once in `lua_scripts/Workbench/`), one
  object, one window (three slots, the result, "Craft", the recipes behind
  the "i"), locked to the craft of the first item placed. The tarot brings
  two recipes: three cards into one drawn at random, three boards likewise.
  `.tarot fuse`. The result box shows a card, or a board, under the game's
  red question mark (`data/art/Interface/mod-Tarot/Icons/`).
