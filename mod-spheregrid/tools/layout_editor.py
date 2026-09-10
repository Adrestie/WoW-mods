# -*- coding: utf-8 -*-
# This file is part of mod-spheregrid.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

r"""The layout editor, out of the game.

ONE LAYOUT, TWO EDITORS, ONE FILE. The grid is composed here or in game with
`.spheregrid editor`, and both write the same XML in the same folder. This one
does what the game cannot -- draw a grid from the bank, paint what the cells
grant, and turn the whole thing into the SQL the module ships -- and reads back
whatever the game wrote while it was open.

ONE IMAGE, NOT FIVE THOUSAND SHAPES. A grid is two and a half thousand cells
and as many links; asking the canvas to hold each one as an object of its own
made every pan and every dab of the brush redraw them all, one call apiece, and
the window crawled. The whole view is painted into a single image instead --
map, links and cells -- and the canvas is handed that. Panning and zooming
repaint it; the map's false colour is kept between frames and only the patch
under the brush is recomputed.

THE MAP TRAVELS WITH THE LAYOUT: the same name with `.png` instead of `.xml`,
in the same folder. Opening a layout opens its map; saving saves both.

    python tools/layout_editor.py [layout.xml]

    left click     select a cell, or paint     wheel     zoom
    right drag     move about                  F         fit the grid
    middle drag    move the quality rings      Ctrl+S    save
    Ctrl+Z / Y     undo, redo
"""
import copy
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from layout import geometry, generate, paint, palette, sql, xmlio    # noqa: E402

try:
    import tkinter as tk
    from tkinter import filedialog, messagebox, ttk
except ImportError:                                    # pragma: no cover
    tk = None

BANK = os.path.join(HERE, "layout", "bank.xml")


MODULE = os.path.dirname(HERE)

# THE CLASS SPELLS THE GRID CAN TEACH. Four per class -- one of mobility and
# one per specialisation -- allocated in the order the module lists its
# classes: 8600000 + ten per class, plus the slot. What the cells may hold is
# therefore known without asking anybody, and their names are read from the
# module's own Spell.dbc.
SPELL_BASE = 8600000
SPELLS_PER_CLASS = 4


def spell_names():
    """Every spell the module ships, by identifier, from its own DBC."""
    try:
        from spheregrid import dbc
        table = dbc.read(os.path.join(MODULE, "data", "dbc", "spheregrid_Spell.dbc"))
        return dict((ident, dbc.read_string(table, record, 136))
                    for ident, record in table.by_id().items())
    except Exception:
        return {}


def spell_offset(layout):
    """How far this layout's spells stand from the module's own numbering.

    A GRID BELONGS TO THE COPY IT WAS INSTALLED FROM, and the installer may
    have moved the module's identifiers to make room on that server. The
    layout says so itself: a spell cell that already teaches somebody carries
    the number that server uses, and the distance to the number the module
    ships is the offset -- every spell of the family having moved together.
    """
    for cell in layout.cells:
        for klass, ident in cell.spells.items():
            if klass not in xmlio.CLASSES:
                continue
            order = list(xmlio.CLASSES).index(klass)
            slot = ident % 10
            if slot >= SPELLS_PER_CLASS:
                continue
            return ident - (SPELL_BASE + order * 10 + slot)
    return 0


def spells_of(klass, names, offset=0):
    """The four a class can be taught, named where the DBC knows them."""
    order = list(xmlio.CLASSES).index(klass)
    out = []
    for slot in range(SPELLS_PER_CLASS):
        ident = SPELL_BASE + order * 10 + slot
        out.append((ident + offset, names.get(ident, "")))
    return out


def worldserver_conf(server):
    """The server's configuration file, whichever of the two names it wears."""
    for name in ("worldserver.conf", "worldserver.conf.dist"):
        path = os.path.join(server, "configs", name)
        if os.path.isfile(path):
            return path
    return None


def server_of(path):
    """The server a layout belongs to.

    A layout lives in `<server>/lua_scripts/SphereGrid/editor/layouts`, so the
    server is a few steps up from it -- the first folder on the way that holds
    a worldserver.conf. Asking the operator is the fallback, not the rule.
    """
    here = os.path.dirname(os.path.abspath(path))
    for _ in range(8):
        if worldserver_conf(here):
            return here
        parent = os.path.dirname(here)
        if parent == here:
            break
        here = parent
    return None


def settings_path():
    """Where the window keeps the little it remembers between two runs.

    NOT IN THE MODULE. What one operator last opened is his business and not
    the module's, so it lives with his own settings and never in the
    repository -- a checkout stays the same whoever has been editing.
    """
    base = (os.environ.get("APPDATA")
            or os.path.join(os.path.expanduser("~"), ".config"))
    return os.path.join(base, "mod-spheregrid", "layout_editor.json")


def remembered():
    import json
    try:
        with open(settings_path(), encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return {}


def remember_that(**what):
    import json
    kept = remembered()
    kept.update(what)
    try:
        os.makedirs(os.path.dirname(settings_path()), exist_ok=True)
        with open(settings_path(), "w", encoding="utf-8") as handle:
            json.dump(kept, handle, indent=2)
    except Exception:
        pass                # remembering is a courtesy, never a condition

# What a cell looks like. A node wears the colour of its quality, as the game
# does; a socket and a spell cell wear their own, since neither has one.
QUALITY_COLOURS = {1: (157, 157, 157), 2: (30, 255, 0), 3: (0, 112, 221),
                   4: (163, 53, 238), 5: (255, 128, 0)}
EMPTY_COLOUR = (74, 74, 74)
SLOT_COLOUR = (63, 208, 212)
SPELL_COLOUR = (255, 209, 0)
LINK_COLOUR = (90, 90, 90)
START_COLOUR = (255, 255, 255)
PATH_COLOUR = (255, 64, 64)
LINKING_COLOUR = (0, 255, 200)
STRAY_COLOUR = (255, 96, 0)
TANGLE_COLOUR = (255, 0, 128)
RING_COLOUR = (70, 70, 70)
BACKGROUND = (16, 16, 16)
ROW_BACKGROUND = "#1e1e1e"
SELECTED_BACKGROUND = "#264f78"

UNDO_DEPTH = 60

# EVERY CLASS ITS OWN COLOUR, the game's own, so ten paths drawn at once are
# told apart at a glance. Where they run together the colours are added, and
# the shared stretch goes pale -- which is exactly what it is.
ALL = -1
CLASS_COLOURS = {1: (199, 156, 110), 2: (245, 140, 186), 3: (171, 212, 115),
                 4: (255, 245, 105), 5: (255, 255, 255), 6: (196, 31, 59),
                 7: (0, 112, 222), 8: (105, 204, 240), 9: (148, 130, 201),
                 11: (255, 125, 10)}


class Editor(object):
    def __init__(self, root, path=None):
        self.root = root
        self.root.title("mod-spheregrid - layout editor")
        self.layout = xmlio.Layout("untitled")
        self.path = None
        self.bank = generate.read_bank(BANK)
        self.selected = None
        self.paths = {}                 # class -> the cells of its path
        self.dirty = False
        self.undo, self.redo = [], []
        self.watched = 0.0

        # The view: the world point at the top left corner, and pixels per unit.
        self.origin = (-10.0, -10.0)
        self.scale = 6.0

        self.map = None                 # the painted map, beside the layout
        self.preview = None             # its false colour, kept between frames
        self.photo = None               # what the canvas is holding
        self.item = None
        self.pending = None             # a repaint asked for and not yet done
        self.anchor = None              # where a drag started
        self.needs_fit = False          # a fit asked for before the window had a size
        self.waiting = None             # the first cell of a link being made
        self.pointer = (0, 0)
        self.stray = set()      # the cells a cut has left on their own
        self.tangles = []       # links that lie over one another, or over a cell
        self.tangled = set()    # those links, ready to be drawn
        self.tangle_at = 0
        self.spell_names = spell_names()
        self.offset = 0          # how far this layout's spells stand from the module's

        self._build()
        if path and os.path.isfile(path):
            self.open_layout(path)
        else:
            self.schedule()
        self.root.after(1000, self._watch)

    # -- the window ---------------------------------------------------------
    def _build(self):
        bar = tk.Frame(self.root)
        bar.pack(side="top", fill="x")
        for label, command in (("Open", self.ask_open), ("Save", self.save),
                               ("Save as", self.save_as), ("Export SQL", self.export),
                               ("Fit", self.fit)):
            tk.Button(bar, text=label, command=command).pack(side="left", padx=2, pady=2)
        self.show_map = tk.IntVar(value=1)
        tk.Checkbutton(bar, text="Show the map", variable=self.show_map,
                       command=self.schedule).pack(side="left", padx=8)
        self.title = tk.Label(bar, text="", anchor="w")
        self.title.pack(side="left", padx=10)

        body = tk.Frame(self.root)
        body.pack(side="top", fill="both", expand=True)

        column = tk.Frame(body, width=270)
        column.pack(side="left", fill="y")
        column.pack_propagate(False)

        self.panels = ttk.Notebook(column)
        self.panels.pack(side="top", fill="both", expand=True)
        # What the view shows follows the room one is standing in.
        self.panels.bind("<<NotebookTabChanged>>", lambda e: self.schedule())

        # WHAT A CELL HOLDS IS ALWAYS IN SIGHT. It used to live in the editing
        # room, so clicking a cell while generating told a wall.
        detail = tk.LabelFrame(column, text="Selected cell", padx=8, pady=6)
        detail.pack(side="bottom", fill="x")
        self.cell_label = tk.Label(detail, text="No cell selected", anchor="w",
                                   justify="left", wraplength=240)
        self.cell_label.pack(fill="x")

        self._generate_panel()
        self._paint_panel()
        self._rarity_panel()
        self._edit_panel()

        self.canvas = tk.Canvas(body, bg="#101010", highlightthickness=0)
        self.canvas.pack(side="left", fill="both", expand=True)
        self.canvas.bind("<ButtonPress-3>", self.on_grab)
        self.canvas.bind("<B3-Motion>", self.on_pan)
        self.canvas.bind("<MouseWheel>", self.on_wheel)
        self.canvas.bind("<Button-1>", self.on_press)
        self.canvas.bind("<B1-Motion>", self.on_drag)
        self.canvas.bind("<ButtonRelease-1>", self.on_release)
        self.canvas.bind("<B2-Motion>", self.on_centre)
        self.canvas.bind("<Motion>", self.on_move)
        self.canvas.bind("<Configure>", lambda e: self.on_resize())

        # WHAT IS WRONG IS ALWAYS IN SIGHT. A grid without a door for every
        # class is not finished, and that is worth saying without being
        # asked: the banner shows itself the moment something is amiss and
        # goes away when nothing is.
        self.status = tk.Label(self.root, text="", anchor="w")
        self.status.pack(side="bottom", fill="x")
        self.warning = tk.Label(self.root, text="", anchor="w", fg="#ffffff",
                                bg="#8b1a1a", padx=8, pady=3)

        self.root.bind("<Control-z>", lambda e: self.undo_step())
        self.root.bind("<Control-y>", lambda e: self.redo_step())
        self.root.bind("<Control-s>", lambda e: self.save())
        self.root.bind("f", lambda e: self.fit())
        self.root.bind("F", lambda e: self.fit())
        self.root.bind("<Escape>", lambda e: self.mode_changed())

    def _generate_panel(self):
        frame = tk.Frame(self.panels, padx=8, pady=8)
        self.panels.add(frame, text="Generate")

        tk.Label(frame, text="Seed", anchor="w").pack(fill="x")
        line = tk.Frame(frame)
        line.pack(fill="x")
        self.seed = tk.StringVar(value="1")
        tk.Entry(line, textvariable=self.seed, width=12).pack(side="left")
        tk.Button(line, text="Roll", command=self.roll_seed).pack(side="left", padx=4)

        tk.Label(frame, text="Clusters", anchor="w").pack(fill="x", pady=(10, 0))
        self.count = tk.IntVar(value=128)
        tk.Scale(frame, from_=4, to=400, orient="horizontal", variable=self.count,
                 command=lambda _=None: self.show_estimate()).pack(fill="x")

        every = generate.sizes(self.bank)
        tk.Label(frame, text="Cells per cluster", anchor="w").pack(fill="x", pady=(10, 0))
        self.low = tk.IntVar(value=every[0])
        self.high = tk.IntVar(value=every[-1])
        tk.Scale(frame, from_=every[0], to=every[-1], orient="horizontal",
                 variable=self.low, label="at least",
                 command=lambda _=None: self.bound("low")).pack(fill="x")
        tk.Scale(frame, from_=every[0], to=every[-1], orient="horizontal",
                 variable=self.high, label="at most",
                 command=lambda _=None: self.bound("high")).pack(fill="x")

        self.estimate = tk.Label(frame, text="", anchor="w", fg="#888888")
        self.estimate.pack(fill="x", pady=(8, 0))
        tk.Button(frame, text="Generate layout",
                  command=self.do_generate).pack(fill="x", pady=(10, 0))
        tk.Label(frame, anchor="w", justify="left", fg="#888888", wraplength=230,
                 text="The drawing only: what the cells grant is painted "
                      "afterwards.").pack(fill="x", pady=(6, 0))
        self.show_estimate()

    def _paint_panel(self):
        frame = tk.Frame(self.panels, padx=8, pady=8)
        self.panels.add(frame, text="Paint")

        # ONE LAYER PER STATISTIC. Several can be selected at once, and the
        # brush then lays all of them on the same pixels. An eye closed takes
        # a statistic out of the drawing -- and out of reach of the brush, for
        # painting what one cannot see is how a map goes wrong.
        tk.Label(frame, text="Layers", anchor="w").pack(fill="x")
        box = tk.Frame(frame, bg=ROW_BACKGROUND, bd=1, relief="sunken")
        box.pack(fill="x")
        self.layers = {}
        for key, channel, _ in palette.PALETTE:
            row = tk.Frame(box, bg=ROW_BACKGROUND)
            row.pack(fill="x")
            seen = tk.IntVar(value=1)
            eye = tk.Checkbutton(row, variable=seen, bg=ROW_BACKGROUND,
                                 activebackground=ROW_BACKGROUND, bd=0,
                                 highlightthickness=0,
                                 command=lambda k=key: self.toggle_layer(k))
            eye.pack(side="left")
            tint = "#%02x%02x%02x" % palette.STAT_COLOURS[key]
            swatch = tk.Label(row, text="   ", bg=tint)
            swatch.pack(side="left", padx=(0, 6))
            name = tk.Label(row, text=key, anchor="w", bg=ROW_BACKGROUND,
                            fg="#dddddd")
            name.pack(side="left", fill="x", expand=True)
            self.layers[key] = {"row": row, "name": name, "seen": seen,
                                "chosen": False}
            for widget in (row, name, swatch):
                widget.bind("<Button-1>", lambda e, k=key: self.pick_layer(k, e))
        tk.Label(frame, anchor="w", justify="left", fg="#888888", wraplength=230,
                 text="Click a layer to paint it, Ctrl-click to add another.").pack(
            fill="x", pady=(2, 0))
        self.pick_layer(palette.PALETTE[0][0], None)

        self.erase = tk.IntVar(value=0)
        tk.Checkbutton(frame, text="Erase those statistics instead",
                       variable=self.erase).pack(fill="x", pady=(4, 0))

        self.brush = tk.IntVar(value=40)
        tk.Scale(frame, from_=2, to=300, orient="horizontal", variable=self.brush,
                 label="brush, in map pixels").pack(fill="x", pady=(8, 0))
        self.falloff = tk.DoubleVar(value=0.8)
        tk.Scale(frame, from_=0.0, to=1.0, resolution=0.05, orient="horizontal",
                 variable=self.falloff, label="falloff").pack(fill="x")
        self.scatter = tk.DoubleVar(value=0.3)
        tk.Scale(frame, from_=0.0, to=1.0, resolution=0.05, orient="horizontal",
                 variable=self.scatter, label="scatter").pack(fill="x")

        tk.Button(frame, text="Regenerate the statistics",
                  command=self.do_assign).pack(fill="x", pady=(12, 0))
        self.keep_spells = tk.IntVar(value=1)
        tk.Checkbutton(frame, text="Leave the spell cells alone",
                       variable=self.keep_spells).pack(fill="x")

    def _rarity_panel(self):
        """THE QUALITY IS NOT PAINTED. It follows the distance to a centre, in
        five bands, and that is a different gesture from laying a statistic --
        hence a room of its own."""
        frame = tk.Frame(self.panels, padx=8, pady=8)
        self.panels.add(frame, text="Rarity")

        tk.Label(frame, anchor="w", justify="left", fg="#888888", wraplength=230,
                 text="Five bands, from the heart out, as a share of the "
                      "distance to the edge.").pack(fill="x")
        self.bands = []
        for index, name in enumerate(xmlio.QUALITIES):
            row = tk.Frame(frame)
            row.pack(fill="x", pady=(6, 0))
            tk.Label(row, text="   ", bg="#%02x%02x%02x" % QUALITY_COLOURS[index + 1]
                     ).pack(side="left", padx=(0, 6))
            tk.Label(row, text=name, anchor="w", width=12).pack(side="left")
            value = tk.DoubleVar(value=palette.DEFAULT_BANDS[index])
            tk.Scale(frame, from_=0, to=100, resolution=1, orient="horizontal",
                     variable=value, length=230,
                     command=lambda _=None: self.rings_changed()).pack(fill="x")
            self.bands.append(value)

        tk.Button(frame, text="Centre the rings on the grid",
                  command=self.centre_rings).pack(fill="x", pady=(14, 0))
        tk.Label(frame, anchor="w", justify="left", fg="#888888", wraplength=230,
                 text="Or middle-drag on the map to put the centre where the "
                      "heart of the grid is.").pack(fill="x", pady=(4, 0))

    def _edit_panel(self):
        frame = tk.Frame(self.panels, padx=8, pady=8)
        self.panels.add(frame, text="Edit")

        # WHAT A CLICK DOES COMES FIRST: it governs the canvas itself, and the
        # rest of this room speaks about whatever that click has taken.
        tk.Label(frame, text="What a click does", anchor="w").pack(fill="x")
        self.mode = tk.StringVar(value="select")
        for value, label in (("select", "Select a cell"),
                             ("link", "Link: click two cells")):
            tk.Radiobutton(frame, text=label, value=value, variable=self.mode,
                           anchor="w", command=self.mode_changed).pack(fill="x")
        tk.Label(frame, anchor="w", justify="left", fg="#888888", wraplength=240,
                 text="Two cells already joined are parted instead. Escape "
                      "drops the one waiting.").pack(fill="x", pady=(0, 10))

        # THE CLASS COMES NEXT AND THE REST FOLLOWS FROM IT. Which paths are
        # drawn, which spells are offered, whose start is being set: all of it
        # hangs on the class one is looking through, so it is asked at the top
        # and everything below answers to it.
        tk.Label(frame, text="View as class", anchor="w").pack(fill="x")
        self.klass = tk.IntVar(value=ALL)
        chooser = ttk.Combobox(frame, state="readonly", width=20,
                               values=["all"] + ["%d  %s" % (k, xmlio.CLASS_NAMES[k])
                                                 for k in xmlio.CLASSES])
        chooser.current(0)
        chooser.bind("<<ComboboxSelected>>",
                     lambda e: self.class_changed(chooser.get()))
        chooser.pack(fill="x")

        self.preview_button = tk.Button(
            frame, text="Preview path from class start node",
            command=self.preview_path, state="disabled")
        self.preview_button.pack(fill="x", pady=(6, 0))

        tk.Label(frame, text="The selected cell is a", anchor="w").pack(
            fill="x", pady=(12, 0))
        self.kind = tk.StringVar(value=xmlio.NODE)
        kinds = tk.Frame(frame)
        kinds.pack(fill="x")
        self.kind_buttons = []
        for value, label in ((xmlio.NODE, "node"), (xmlio.SLOT, "socket"),
                             (xmlio.SPELL, "spell")):
            button = tk.Radiobutton(kinds, text=label, value=value,
                                    variable=self.kind, command=self.set_kind,
                                    state="disabled")
            button.pack(side="left")
            self.kind_buttons.append(button)

        self.spell_label = tk.Label(frame, text="Spell taught, class by class",
                                    anchor="w", fg="#666666")
        self.spell_label.pack(fill="x", pady=(10, 0))
        self.spell_choice = ttk.Combobox(frame, state="disabled", width=26)
        self.spell_choice.pack(fill="x")
        row = tk.Frame(frame)
        row.pack(fill="x", pady=(2, 0))
        self.teach_button = tk.Button(row, text="Teach it", state="disabled",
                                      command=self.assign_spell)
        self.teach_button.pack(side="left", expand=True, fill="x")
        self.forget_button = tk.Button(row, text="Teach nothing", state="disabled",
                                       command=self.clear_spell)
        self.forget_button.pack(side="left", expand=True, fill="x")

        self.start_button = tk.Button(frame, text="Set as class's start",
                                      command=self.set_start, state="disabled")
        self.start_button.pack(fill="x", pady=(12, 0))

        tk.Button(frame, text="Check the grid",
                  command=self.check).pack(fill="x", pady=(14, 0))
        self.report = tk.Label(frame, text="", anchor="w", justify="left",
                               wraplength=230, fg="#cccccc")
        self.report.pack(fill="x", pady=(6, 0))
        # They appear only when there is something to go and see.
        self.stray_button = tk.Button(frame, text="Show the stray island",
                                      command=self.focus_stray)
        self.tangle_button = tk.Button(frame, text="Show the tangled links",
                                       command=self.focus_tangle)

    # -- generating ---------------------------------------------------------
    def roll_seed(self):
        self.seed.set(str(random.randrange(1, 2 ** 31)))

    def bound(self, which):
        """The two ends of the range never cross."""
        if self.low.get() > self.high.get():
            if which == "low":
                self.high.set(self.low.get())
            else:
                self.low.set(self.high.get())
        self.show_estimate()

    def show_estimate(self):
        cells = generate.estimate(self.bank, self.count.get(),
                                  self.low.get(), self.high.get())
        shapes = len(generate.within(self.bank, self.low.get(), self.high.get()))
        self.estimate.config(text="about %d cells, from %d shapes" % (cells, shapes))

    def do_generate(self):
        try:
            seed = int(self.seed.get())
        except ValueError:
            messagebox.showerror("Seed", "The seed is a whole number.")
            return
        self.remember()
        name = self.layout.name if self.path else "untitled"
        self.layout = generate.generate(self.bank, count=self.count.get(), seed=seed,
                                        low=self.low.get(), high=self.high.get(),
                                        name=name)
        self.selected, self.paths = None, {}
        self.dirty = True
        self.fit()
        self.check()

    # -- the layers ---------------------------------------------------------
    def pick_layer(self, key, event=None):
        """A click takes that layer alone; Ctrl adds it to the ones already
        taken. A hidden layer cannot be picked."""
        if not self.layers[key]["seen"].get():
            return
        holding = bool(event is not None and (event.state & 0x0004))
        if holding:
            self.layers[key]["chosen"] = not self.layers[key]["chosen"]
        else:
            for other in self.layers.values():
                other["chosen"] = False
            self.layers[key]["chosen"] = True
        self.refresh_layers()

    def toggle_layer(self, key):
        """An eye closed hides the statistic and drops it from the brush."""
        if not self.layers[key]["seen"].get():
            self.layers[key]["chosen"] = False
        self.preview = None
        self.refresh_layers()
        self.schedule()

    def refresh_layers(self):
        for key, layer in self.layers.items():
            hidden = not layer["seen"].get()
            colour = SELECTED_BACKGROUND if layer["chosen"] else ROW_BACKGROUND
            layer["row"].config(bg=colour)
            layer["name"].config(bg=colour,
                                 fg="#666666" if hidden else "#dddddd")

    def selected_stats(self):
        return [key for key, _, _ in palette.PALETTE
                if self.layers[key]["chosen"] and self.layers[key]["seen"].get()]

    def visible_mask(self):
        return palette.mask_of([key for key, _, _ in palette.PALETTE
                                if self.layers[key]["seen"].get()])

    # -- painting -----------------------------------------------------------
    def ensure_map(self):
        if self.map is None:
            self.map = paint.StatMap.blank()
            self.map.bands = [value.get() for value in self.bands]
            self.preview = None
        return self.map

    def centre_rings(self):
        """The rings back where the grid's heart is: the middle of its
        clusters, not the middle of the image."""
        if not self.layout.clusters:
            return
        stat_map = self.ensure_map()
        box = geometry.frame(self.layout.clusters)
        x = sum(c["x"] for c in self.layout.clusters) / len(self.layout.clusters)
        y = sum(c["y"] for c in self.layout.clusters) / len(self.layout.clusters)
        px, py = geometry.to_map(x, y, box, stat_map.size)
        stat_map.centre = (min(1.0, max(0.0, px / float(stat_map.size))),
                           min(1.0, max(0.0, py / float(stat_map.size))))
        self.dirty = True
        self.schedule()
        self.say("rings centred at %.3f, %.3f" % stat_map.centre)

    def rings_changed(self):
        if self.map is None:
            return
        self.map.bands = [value.get() for value in self.bands]
        self.dirty = True
        self.schedule()

    def do_assign(self):
        if not self.layout.cells:
            return
        self.remember()
        seed = int(self.seed.get()) if self.seed.get().isdigit() else 1
        touched = paint.assign(self.layout, self.map, seed=seed,
                               overwrite_spells=not self.keep_spells.get())
        self.dirty = True
        self.schedule()
        self.say("%d cells given a statistic" % touched)

    def paint_at(self, x, y):
        """A dab where the pointer is, and the false colour patched to match --
        recomputing the whole map for every dab is what made the brush drag."""
        stats = self.selected_stats()
        if not stats:
            self.say("no layer selected: nothing to paint with")
            return
        stat_map = self.ensure_map()
        box = geometry.frame(self.layout.clusters) if self.layout.clusters \
            else (0.0, 0.0, 1.0)
        px, py = geometry.to_map(x, y, box, stat_map.size)
        radius = self.brush.get()
        stat_map.dab(px, py, radius, stats, falloff=self.falloff.get(),
                     scatter=self.scatter.get(), remove=bool(self.erase.get()))
        self.dirty = True
        if self.preview is None:
            return
        reach = int(radius * 2 + 4)
        left, top = max(0, px - reach), max(0, py - reach)
        right = min(stat_map.size, px + reach)
        bottom = min(stat_map.size, py + reach)
        if right <= left or bottom <= top:
            return
        patch = stat_map.pixels[top:bottom, left:right]
        self.preview.paste(palette.display([patch[:, :, i] for i in range(3)],
                                           self.visible_mask()), (left, top))

    # -- editing ------------------------------------------------------------
    def class_changed(self, chosen):
        """`all` is a class of its own here: every path at once, every spell."""
        self.klass.set(ALL if str(chosen).startswith("all")
                       else int(str(chosen).split()[0]))
        self.refresh_cell_controls()

    def offered_spells(self):
        """What the list holds: one class's four, or all forty when the choice
        is `all` -- named, and each saying whose it is."""
        if self.klass.get() != ALL:
            return [(ident, name, self.klass.get()) for ident, name
                    in spells_of(self.klass.get(), self.spell_names, self.offset)]
        out = []
        for klass in xmlio.CLASSES:
            for ident, name in spells_of(klass, self.spell_names, self.offset):
                out.append((ident, "%s  (%s)" % (name, xmlio.CLASS_NAMES[klass]),
                            klass))
        return out

    def refresh_cell_controls(self):
        """The kind and the spell shown are those of the cell in hand, and
        what cannot be done from here is greyed rather than left to fail: no
        cell in hand, nothing to say about one; no spell cell, nothing to
        teach; no class chosen, no door to set."""
        cell = self.layout.by_id().get(self.selected)
        offered = self.offered_spells()
        self.spell_choice.config(values=["%d  %s" % (i, n) for i, n, _ in offered])

        holding = "normal" if cell is not None else "disabled"
        teaching = ("normal" if cell is not None and cell.kind == xmlio.SPELL
                    else "disabled")
        self.preview_button.config(state=holding)
        for button in self.kind_buttons:
            button.config(state=holding)
        self.spell_label.config(fg="#dddddd" if teaching == "normal" else "#666666")
        self.spell_choice.config(state="readonly" if teaching == "normal"
                                 else "disabled")
        self.teach_button.config(state=teaching)
        self.forget_button.config(state=teaching)
        self.start_button.config(state="normal" if (cell is not None
                                                    and self.klass.get() != ALL)
                                 else "disabled")
        if cell is None:
            return
        self.kind.set(cell.kind)
        taught = set(cell.spells.values())
        for index, (ident, _, _) in enumerate(offered):
            if ident in taught and (self.klass.get() == ALL
                                    or cell.spells.get(self.klass.get()) == ident):
                self.spell_choice.current(index)
                return
        self.spell_choice.set("")

    def set_kind(self):
        """A node holds a statistic, a socket holds nothing of its own, and a
        spell cell teaches. Changing one lets go of what the other carried."""
        cell = self.layout.by_id().get(self.selected)
        if cell is None or cell.kind == self.kind.get():
            return
        self.remember()
        cell.kind = self.kind.get()
        if cell.kind != xmlio.NODE:
            cell.stat, cell.quality = None, 1
        if cell.kind != xmlio.SPELL:
            cell.spell, cell.spells = 0, {}
        self.dirty = True
        self.describe()
        self.schedule()

    def forget_spell(self, ident, except_cell=None):
        """Take that spell off every cell that teaches it. Returns the cells
        it was taken from."""
        taken = []
        for cell in self.layout.cells:
            if cell is except_cell:
                continue
            for klass, held in list(cell.spells.items()):
                if held == ident:
                    del cell.spells[klass]
                    taken.append(cell.id)
            if cell.spell == ident:
                cell.spell = next(iter(cell.spells.values()), 0)
        return taken

    def assign_spell(self):
        """A SPELL IS TAUGHT IN ONE PLACE. Laid down a second time it leaves
        the first: the cell it stood on stays where it is and keeps everything
        else, only the reference moves."""
        cell = self.layout.by_id().get(self.selected)
        chosen = self.spell_choice.get()
        if cell is None or not chosen:
            return
        if cell.kind != xmlio.SPELL:
            self.say("that cell is not a spell cell")
            return
        ident = int(chosen.split()[0])
        owner = dict((i, k) for i, _, k in self.offered_spells()).get(ident)
        klass = owner if self.klass.get() == ALL else self.klass.get()
        self.remember()
        moved = self.forget_spell(ident, except_cell=cell)
        cell.spells[klass] = ident
        # The cell's own spell is the one a class without a line of its own
        # falls back on, so the first one taught takes that place.
        if not cell.spell:
            cell.spell = ident
        self.dirty = True
        self.describe()
        self.schedule()
        self.say("%s learns %d here%s" % (xmlio.CLASS_NAMES[klass], ident,
                                          "" if not moved
                                          else "; taken off cell %d" % moved[0]))

    def clear_spell(self):
        cell = self.layout.by_id().get(self.selected)
        if cell is None or not cell.spells:
            return
        chosen = self.spell_choice.get()
        ident = int(chosen.split()[0]) if chosen else None
        self.remember()
        if self.klass.get() != ALL and self.klass.get() in cell.spells:
            ident = cell.spells[self.klass.get()]
        if ident is None:
            return
        self.forget_spell(ident)
        self.dirty = True
        self.describe()
        self.schedule()

    def set_start(self):
        if not self.selected:
            return
        self.remember()
        self.layout.starts[self.klass.get()] = self.selected
        self.dirty = True
        self.schedule()
        self.check()

    def preview_path(self):
        """EVERY DOOR AT ONCE when the choice is `all`: one path per class that
        has a start, each in the colour of its class, and where two run
        together the colours add up."""
        if not self.selected:
            self.report.config(text="Pick a cell first.")
            return
        wanted = xmlio.CLASSES if self.klass.get() == ALL else [self.klass.get()]
        self.paths, lines = {}, []
        for klass in wanted:
            start = self.layout.starts.get(klass)
            if not start:
                lines.append("%s: no start" % xmlio.CLASS_NAMES[klass])
                continue
            path = geometry.shortest_path(self.layout, start, self.selected)
            if path:
                self.paths[klass] = path
                lines.append("%s: %d cells" % (xmlio.CLASS_NAMES[klass], len(path)))
            else:
                lines.append("%s: no way there" % xmlio.CLASS_NAMES[klass])
        self.report.config(text=chr(10).join(lines) or "No class has a start.",
                           fg="#cccccc")
        self.schedule()

    def check(self):
        islands = geometry.components(self.layout)
        missing = [xmlio.CLASS_NAMES[k] for k in xmlio.CLASSES
                   if k not in self.layout.starts]
        lines = []
        if len(islands) > 1:
            biggest = max(len(i) for i in islands)
            lines.append("%d islands: %d cells apart from the main one."
                         % (len(islands), len(self.layout.cells) - biggest))
            # A CUT IS WORTH GOING TO SEE. The smallest island is the odd one
            # out, so that is where the window offers to take you -- and the
            # offer stands only while there is a cut.
            self.stray = min(islands, key=len)
            self.stray_button.config(
                text="Show the stray island (%d cells)" % len(self.stray))
            self.stray_button.pack(fill="x", pady=(6, 0))
        else:
            lines.append("One island: every cell can be walked to.")
            self.stray = set()
            self.stray_button.pack_forget()

        # LINKS THAT LIE OVER ONE ANOTHER. Three cells in a row joined all
        # three ways, or a link drawn straight through a cell it does not
        # join: in both the grid says one thing and shows another.
        self.tangles = []
        self.tangled = set()
        for first, second, _ in geometry.overlapping_links(self.layout):
            self.tangles.append((first[0], first[1]))
            self.tangled.add(frozenset(first))
            self.tangled.add(frozenset(second))
        for link, cell_id in geometry.links_over_cells(self.layout):
            self.tangles.append((link[0], link[1]))
            self.tangled.add(frozenset(link))
        if self.tangles:
            lines.append("%d link(s) lie over another link or over a cell."
                         % len(self.tangled))
            self.tangle_button.config(
                text="Show the tangled links (%d)" % len(self.tangles))
            self.tangle_button.pack(fill="x", pady=(4, 0))
            self.tangle_at = 0
        else:
            self.tangle_button.pack_forget()
        if missing:
            lines.append("WITHOUT A START: " + ", ".join(missing))
        self.report.config(text="\n".join(lines),
                           fg="#ff6060" if (missing or len(islands) > 1
                                           or self.tangles) else "#60ff60")
        self.warn(missing, islands)

    def warn(self, missing, islands):
        """The banner: what is amiss, in one line, or nothing at all."""
        troubles = []
        if missing:
            troubles.append("no start yet for " + ", ".join(missing))
        if len(islands) > 1:
            troubles.append("%d islands" % len(islands))
        if self.tangles:
            troubles.append("%d tangled link(s)" % len(self.tangles))
        if troubles:
            self.warning.config(text="   ".join(troubles).upper())
            self.warning.pack(side="bottom", fill="x")
        else:
            self.warning.pack_forget()

    def focus_stray(self):
        """The window taken to the cells that stand apart, and one of them put
        in hand so the panel says where it is."""
        places = geometry.positions(self.layout)
        points = [places[i] for i in self.stray if i in places]
        if not points:
            return
        xs = [p[0] for p in points]
        ys = [p[1] for p in points]
        width = max(200, self.canvas.winfo_width())
        height = max(200, self.canvas.winfo_height())
        span = max(4.0, max(max(xs) - min(xs), max(ys) - min(ys)) + 8.0)
        self.scale = 0.8 * min(width, height) / span
        middle = ((min(xs) + max(xs)) / 2.0, (min(ys) + max(ys)) / 2.0)
        self.origin = (middle[0] - width / self.scale / 2.0,
                       middle[1] + height / self.scale / 2.0)
        self.selected = sorted(self.stray)[0]
        self.describe()
        self.schedule()
        self.say("%d cells cut off from the rest" % len(self.stray))

    def focus_tangle(self):
        """Taken to one tangle, then the next: pressing again walks the list."""
        if not self.tangles:
            return
        self.tangle_at %= len(self.tangles)
        a, b = self.tangles[self.tangle_at]
        self.tangle_at += 1
        places = geometry.positions(self.layout)
        if a not in places or b not in places:
            return
        width = max(200, self.canvas.winfo_width())
        height = max(200, self.canvas.winfo_height())
        first, second = places[a], places[b]
        span = max(6.0, math.hypot(first[0] - second[0], first[1] - second[1]) + 8.0)
        self.scale = 0.8 * min(width, height) / span
        middle = ((first[0] + second[0]) / 2.0, (first[1] + second[1]) / 2.0)
        self.origin = (middle[0] - width / self.scale / 2.0,
                       middle[1] + height / self.scale / 2.0)
        self.selected = a
        self.describe()
        self.schedule()
        self.say("tangle %d of %d: cells %d and %d"
                 % (self.tangle_at, len(self.tangles), a, b))

    # -- the file -----------------------------------------------------------
    def ask_open(self):
        """The dialog opens where the last layout was, this run or any other."""
        last = self.path or remembered().get("last") or ""
        path = filedialog.askopenfilename(
            title="Open a layout", filetypes=[("Layout", "*.xml")],
            initialdir=os.path.dirname(last) if last else HERE,
            initialfile=os.path.basename(last) if last else "")
        if path:
            self.open_layout(path)

    def open_layout(self, path):
        self.layout = xmlio.read(path)
        self.path = os.path.abspath(path)
        remember_that(last=self.path)
        self.watched = os.path.getmtime(path)
        self.dirty = False
        self.undo, self.redo = [], []
        self.selected, self.paths = None, {}
        self.offset = spell_offset(self.layout)
        beside = paint.map_path(path)
        self.map = paint.StatMap.load(beside) if os.path.isfile(beside) else None
        self.preview = None
        if self.map is not None:
            for index, value in enumerate(self.bands):
                value.set(self.map.bands[index])
        self.fit()
        self.check()

    def save(self):
        if not self.path:
            return self.save_as()
        xmlio.write(self.layout, self.path)
        if self.map is not None:
            self.map.bands = [value.get() for value in self.bands]
            self.map.save(paint.map_path(self.path))
        self.watched = os.path.getmtime(self.path)
        self.dirty = False
        self.say("saved  %s" % self.path)

    def save_as(self):
        path = filedialog.asksaveasfilename(
            title="Save the layout", defaultextension=".xml",
            filetypes=[("Layout", "*.xml")])
        if not path:
            return
        self.layout.name = os.path.splitext(os.path.basename(path))[0]
        self.path = os.path.abspath(path)
        remember_that(last=self.path)
        self.save()

    def export(self):
        """The layout saved, the SQL written beside it, and the SQL applied.

        THE OPERATOR SHOULD HAVE ONE THING LEFT TO DO, and that is to type
        `.spheregrid reload` in game. So the file is written under the name
        the module ships it as, and then handed to the world database of the
        server this layout belongs to -- the one whose `lua_scripts` it sits
        in. Where that cannot be found, the file is still written and the
        window says so rather than pretending.
        """
        if not self.path:
                messagebox.showinfo(
                    "Written, not applied",
                    NEWLINE.join((
                        out,
                        "",
                        "No worldserver.conf was found, so there is no "
                        "database to hand it to. Apply the file yourself, "
                        "and then, in game:",
                        "",
                        "        .spheregrid reload",
                        "",
                        "NOT `.reload ale`, which reloads the interface "
                        "only.")))
                return
        remember_that(server=os.path.abspath(server))

        try:
            import install
            target = install.Target(server, MODULE, None)
            target.run_sql("world", source=out)
        except Exception as trouble:
            messagebox.showwarning(
                "Export",
                "%s\n\nWritten, but the database refused it:\n\n%s"
                % (out, str(trouble)[:600]))
            return
        self.say("applied to %s -- now type .spheregrid reload in game"
                 % target.databases["world"]["name"])
        messagebox.showinfo(
            "Applied. One thing left: .spheregrid reload",
            NEWLINE.join((
                "The grid is in %s." % target.databases["world"]["name"],
                "",
                "ONE THING LEFT, in game:",
                "",
                "        .spheregrid reload",
                "",
                "NOT `.reload ale`. That one reloads the Lua interface "
                "only, and the interface reads the tables as it draws -- so "
                "the grid LOOKS new while the module still judges by the "
                "old one, and a cell is refused on links you can see. This "
                "is the command that makes the module read the tables "
                "again.",
                "",
                out)))

    def _watch(self):
        """THE GAME MAY HAVE WRITTEN THE FILE. The in-game editor saves the same
        XML in the same folder; when it does, this window follows -- unless
        there is unsaved work here, in which case the choice is the operator's."""
        try:
            if self.path and os.path.isfile(self.path):
                stamp = os.path.getmtime(self.path)
                if stamp > self.watched + 0.5:
                    self.watched = stamp
                    if not self.dirty:
                        self.open_layout(self.path)
                        self.say("reloaded: the file changed on disk")
                    elif messagebox.askyesno(
                            "The file changed",
                            "The layout was written by something else -- the game, "
                            "most likely -- and this window has unsaved work.\n\n"
                            "Take what is on disk and lose what is here?"):
                        self.open_layout(self.path)
        finally:
            self.root.after(1000, self._watch)

    # -- undo ---------------------------------------------------------------
    def remember(self):
        self.undo.append(copy.deepcopy(self.layout))
        del self.undo[:-UNDO_DEPTH]
        self.redo = []

    def undo_step(self):
        if not self.undo:
            return
        self.redo.append(copy.deepcopy(self.layout))
        self.layout = self.undo.pop()
        self.dirty = True
        self.schedule()
        self.check()

    def redo_step(self):
        if not self.redo:
            return
        self.undo.append(copy.deepcopy(self.layout))
        self.layout = self.redo.pop()
        self.dirty = True
        self.schedule()
        self.check()

    # -- the view -----------------------------------------------------------
    def to_screen(self, point):
        """THE GRID IS DRAWN THE WAY THE GAME DRAWS IT. Its cells hang from the
        bottom left of the game's canvas, so a greater y stands higher; a
        window counts its rows downwards. The origin holds the world point at
        the TOP left corner, and y is taken away rather than added."""
        return ((point[0] - self.origin[0]) * self.scale,
                (self.origin[1] - point[1]) * self.scale)

    def to_world(self, sx, sy):
        return (self.origin[0] + sx / self.scale, self.origin[1] - sy / self.scale)

    def fit(self):
        """Every cluster in view.

        A WINDOW THAT HAS NOT BEEN LAID OUT YET MEASURES ONE PIXEL. Fitting
        against that put the grid in the corner of a window it had not seen, so
        a fit asked for too early is remembered and done again the moment the
        canvas knows its own size.
        """
        width, height = self.canvas.winfo_width(), self.canvas.winfo_height()
        if width <= 1 or height <= 1:
            self.needs_fit = True
            return self.schedule()
        self.needs_fit = False
        if not self.layout.clusters:
            self.origin, self.scale = (-10.0, -10.0), 6.0
            return self.schedule()
        x0, y0, side = geometry.frame(self.layout.clusters)
        self.scale = 0.98 * min(width, height) / side
        self.origin = (x0 - (width / self.scale - side) / 2.0,
                       y0 + side + (height / self.scale - side) / 2.0)
        self.schedule()

    def on_resize(self):
        """The canvas has a size at last, or a new one: a fit that was asked
        for before it did is honoured now."""
        if self.needs_fit:
            self.fit()
        else:
            self.schedule()

    def on_grab(self, event):
        self.anchor = (event.x, event.y, self.origin)

    def on_pan(self, event):
        if not self.anchor:
            return
        sx, sy, origin = self.anchor
        self.origin = (origin[0] - (event.x - sx) / self.scale,
                       origin[1] + (event.y - sy) / self.scale)
        self.schedule()

    def on_wheel(self, event):
        under = self.to_world(event.x, event.y)
        self.scale *= 1.15 if event.delta > 0 else 1 / 1.15
        self.scale = max(0.5, min(400.0, self.scale))
        self.origin = (under[0] - event.x / self.scale,
                       under[1] + event.y / self.scale)
        self.schedule()

    def on_press(self, event):
        # WHERE THE POINTER IS, NOW. The line that trails a link being made
        # starts at the cursor, and the cursor is only known from the moment it
        # moves: without this the first click drew a line back to wherever the
        # mouse had last been, or to the corner it had never left.
        self.pointer = (event.x, event.y)
        if self.painting():
            self.remember()
            return self.on_drag(event)
        cell = self.nearest(event.x, event.y)
        if cell is None:
            return
        if self.mode.get() == "link":
            return self.link_click(cell)
        self.selected = cell
        self.describe()
        self.schedule()

    # -- the links ----------------------------------------------------------
    def mode_changed(self):
        self.waiting = None
        self.schedule()

    def link_click(self, cell):
        """The first click takes a cell, the second makes or unmakes the link
        between the two. Clicking the same one twice lets it go."""
        if self.waiting is None:
            self.waiting = cell
            self.selected = cell
            self.describe()
            self.say("linking from cell %d" % cell)
        elif self.waiting == cell:
            self.waiting = None
            self.say("nothing linked")
        else:
            self.remember()
            first, second = self.waiting, cell
            before = len(self.layout.links)
            self.layout.links = [(a, b) for a, b in self.layout.links
                                 if (a, b) not in ((first, second), (second, first))]
            if len(self.layout.links) == before:
                self.layout.links.append((first, second))
                self.say("cells %d and %d linked" % (first, second))
            else:
                self.say("cells %d and %d parted" % (first, second))
            self.waiting = None
            self.dirty = True
            self.check()
        self.schedule()

    def on_move(self, event):
        """The line that follows the pointer while a link is being made."""
        if self.waiting is None or self.painting():
            return
        self.pointer = (event.x, event.y)
        self.schedule()

    def on_drag(self, event):
        if not self.painting():
            return
        x, y = self.to_world(event.x, event.y)
        self.paint_at(x, y)
        self.schedule()

    def on_release(self, event):
        if self.painting():
            self.schedule()

    def on_centre(self, event):
        """THE RINGS ARE NOT BOUND TO THE MIDDLE OF THE MAP. A grid whose heart
        sits off-centre wants its qualities centred there too, so the middle
        button drags the centre where it belongs."""
        if self.map is None or not self.layout.clusters:
            return
        box = geometry.frame(self.layout.clusters)
        px, py = geometry.to_map(*self.to_world(event.x, event.y), box=box,
                                 size=self.map.size)
        self.map.centre = (min(1.0, max(0.0, px / float(self.map.size))),
                           min(1.0, max(0.0, py / float(self.map.size))))
        self.dirty = True
        self.schedule()
        self.say("rings centred at %.3f, %.3f" % self.map.centre)

    def painting(self):
        return self.panels.index(self.panels.select()) == 1

    def on_rarity(self):
        return self.panels.index(self.panels.select()) == 2

    def nearest(self, sx, sy):
        """The cell under the pointer, if one is close enough. Two thousand
        distances are nothing next to asking the canvas what it holds."""
        x, y = self.to_world(sx, sy)
        reach = max(0.35, 8.0 / self.scale)
        best, chosen = reach * reach, None
        for cell_id, place in geometry.positions(self.layout).items():
            span = (place[0] - x) ** 2 + (place[1] - y) ** 2
            if span < best:
                best, chosen = span, cell_id
        return chosen

    # -- the rendering ------------------------------------------------------
    def schedule(self):
        """A repaint at the next turn of the loop, and one only: a drag fires
        far more events than a window can draw."""
        if self.pending is None:
            self.pending = self.root.after_idle(self.render)

    def render(self):
        self.pending = None
        try:
            from PIL import Image, ImageDraw, ImageTk
        except ImportError:
            self.say("Pillow is missing: nothing can be drawn")
            return
        width = max(1, self.canvas.winfo_width())
        height = max(1, self.canvas.winfo_height())

        # ONE THING AT A TIME. The rings are read against nothing, so the map
        # steps aside while they are being set; and the brush wants the map
        # bare, so the rings step aside while it paints. Elsewhere the map is
        # shown, since a filled ring would hide it.
        rarity = self.on_rarity()
        frame = Image.new("RGB", (width, height), BACKGROUND)
        if self.show_map.get() and self.map is not None and not rarity:
            self.blit_map(frame)
        draw = ImageDraw.Draw(frame)
        if self.map is not None and rarity:
            self.draw_rings(draw)

        places = geometry.positions(self.layout)
        # What the paths paint: a cell or a link on several of them takes the
        # sum of their colours.
        tint, link_tint = {}, {}
        for klass, path in self.paths.items():
            colour = CLASS_COLOURS.get(klass, PATH_COLOUR)
            for cell_id in path:
                held = tint.setdefault(cell_id, [0, 0, 0])
                for index in range(3):
                    held[index] = min(255, held[index] + colour[index])
            for first, second in zip(path, path[1:]):
                held = link_tint.setdefault(frozenset((first, second)), [0, 0, 0])
                for index in range(3):
                    held[index] = min(255, held[index] + colour[index])
        margin = 40
        screen = {}
        for cell_id, place in places.items():
            x, y = self.to_screen(place)
            if -margin <= x <= width + margin and -margin <= y <= height + margin:
                screen[cell_id] = (x, y)

        for a, b in self.layout.links:
            first, second = screen.get(a), screen.get(b)
            if first is None and second is None:
                continue                       # both ends off the window
            if first is None:
                first = self.to_screen(places[a])
            if second is None:
                second = self.to_screen(places[b])
            lit = link_tint.get(frozenset((a, b)))
            if frozenset((a, b)) in self.tangled:
                draw.line([first, second], width=3, fill=TANGLE_COLOUR)
            draw.line([first, second], width=2 if lit else 1,
                      fill=tuple(lit) if lit else LINK_COLOUR)

        # The line that follows the pointer while a link is being made.
        if self.waiting is not None and self.waiting in places:
            draw.line([self.to_screen(places[self.waiting]), self.pointer],
                      fill=LINKING_COLOUR, width=2)

        starts = dict((node, klass) for klass, node in self.layout.starts.items())
        radius = max(1.5, self.scale * 0.34)
        for cell in self.layout.cells:
            place = screen.get(cell.id)
            if place is None:
                continue
            x, y = place
            # A NODE WEARS ITS STATISTIC and is ringed by its quality: the two
            # things it carries, both read at a glance. In the rarity room it
            # is the other way about -- there the quality is the subject, so
            # the cell is filled with it.
            edge, width_ = None, 1
            if cell.kind == xmlio.SLOT:
                colour = SLOT_COLOUR
            elif cell.kind == xmlio.SPELL:
                colour = SPELL_COLOUR
            elif not cell.stat:
                colour = EMPTY_COLOUR
            elif rarity:
                colour = QUALITY_COLOURS.get(cell.quality, EMPTY_COLOUR)
            else:
                colour = palette.STAT_COLOURS.get(cell.stat, EMPTY_COLOUR)
                if radius >= 3.0:
                    edge = QUALITY_COLOURS.get(cell.quality, EMPTY_COLOUR)
            if cell.id in self.stray:
                edge, width_ = STRAY_COLOUR, 2
            if cell.id in starts:
                edge, width_ = START_COLOUR, 2
            elif cell.id in tint:
                edge, width_ = tuple(tint[cell.id]), 2
            if cell.id == self.selected:
                edge, width_ = START_COLOUR, 3
            if cell.id == self.waiting:
                edge, width_ = LINKING_COLOUR, 3
            draw.ellipse([x - radius, y - radius, x + radius, y + radius],
                         fill=colour, outline=edge, width=width_)

        self.photo = ImageTk.PhotoImage(frame)
        if self.item is None:
            self.item = self.canvas.create_image(0, 0, image=self.photo, anchor="nw")
        else:
            self.canvas.itemconfig(self.item, image=self.photo)
        self.say()

    def blit_map(self, frame):
        """The visible corner of the map, and nothing more. Its false colour is
        computed once and kept: only a dab of the brush patches it."""
        from PIL import Image
        if self.preview is None:
            self.preview = self.map.preview(self.visible_mask())
        box = geometry.frame(self.layout.clusters) if self.layout.clusters \
            else (0.0, 0.0, 1.0)
        size = self.preview.size[0]
        width, height = frame.size
        # The window, in map pixels. The two corners are taken the way they
        # fall and then sorted: the map and the window agree on which way is
        # up, but nothing says the world does.
        first = geometry.to_map(*self.to_world(0, 0), box=box, size=size)
        second = geometry.to_map(*self.to_world(width, height), box=box, size=size)
        left, right = sorted((first[0], second[0]))
        top, bottom = sorted((first[1], second[1]))
        left, top = max(0, left), max(0, top)
        right, bottom = min(size, right + 1), min(size, bottom + 1)
        if right <= left or bottom <= top:
            return
        piece = self.preview.crop((left, top, right, bottom))
        # Where that piece lands on the window.
        x0, y0 = self.to_screen(geometry.to_world(left, top, box, size))
        x1, y1 = self.to_screen(geometry.to_world(right, bottom, box, size))
        target = (max(1, int(round(x1 - x0))), max(1, int(round(y1 - y0))))
        frame.paste(piece.resize(target, Image.NEAREST), (int(round(x0)), int(round(y0))))

    def draw_rings(self, draw):
        box = geometry.frame(self.layout.clusters) if self.layout.clusters \
            else (0.0, 0.0, 1.0)
        size = self.map.size
        centre = geometry.to_world(self.map.centre[0] * size,
                                   self.map.centre[1] * size, box, size)
        cx, cy = self.to_screen(centre)
        # EACH BAND IN ITS OWN COLOUR: the one the game gives that quality, so
        # they are read at a glance instead of counted from the middle. Filled,
        # and darker inside than at the edge, so a band is a place and not a
        # line -- the outermost first, the heart last, or each would bury the
        # one before it.
        radii = palette.quality_radii(self.map.bands, size)
        for index in range(len(radii) - 1, -1, -1):
            colour = QUALITY_COLOURS.get(index + 1, RING_COLOUR)
            inside = tuple(int(part * 0.35) for part in colour)
            span = radii[index] / float(size) * box[2] * self.scale
            draw.ellipse([cx - span, cy - span, cx + span, cy + span],
                         fill=inside, outline=colour, width=2)

    def describe(self):
        cell = self.layout.by_id().get(self.selected)
        if not cell:
            self.cell_label.config(text="No cell selected")
            return
        what = {xmlio.NODE: "node", xmlio.SLOT: "rune socket",
                xmlio.SPELL: "spell cell"}[cell.kind]
        lines = ["cell %d, cluster %d, ring %d, branch %d"
                 % (cell.id, cell.cluster, cell.ring, cell.branch), what]
        if cell.kind == xmlio.NODE and cell.stat:
            lines.append("%s, %s" % (cell.stat, xmlio.QUALITIES[cell.quality - 1]))
        if cell.kind == xmlio.SPELL:
            lines.append("spell %d" % cell.spell)
            for klass in sorted(cell.spells):
                lines.append("  %s: %d" % (xmlio.CLASS_NAMES.get(klass, klass),
                                           cell.spells[klass]))
        for klass, node in self.layout.starts.items():
            if node == cell.id:
                lines.append("START of %s" % xmlio.CLASS_NAMES.get(klass, klass))
        self.cell_label.config(text="\n".join(lines))
        self.refresh_cell_controls()

    def say(self, extra=""):
        counts = self.layout.counts()
        self.title.config(text="%s%s" % (self.layout.name, " *" if self.dirty else ""))
        self.status.config(text="%d clusters, %d cells (%d nodes, %d sockets, "
                                "%d spell cells), %d links, %d starts   %s"
                                % (len(self.layout.clusters), len(self.layout.cells),
                                   counts[xmlio.NODE], counts[xmlio.SLOT],
                                   counts[xmlio.SPELL], len(self.layout.links),
                                   len(self.layout.starts), extra))


def main(argv):
    if "--selftest" in argv:
        return selftest(argv)
    if tk is None:
        print("tkinter is missing: this tool needs it")
        return 2
    root = tk.Tk()
    root.geometry("1400x900")
    # Named a layout, it opens that one; named none, it takes up where it was
    # left -- the last layout opened, whenever that was.
    wanted = argv[1] if len(argv) > 1 else remembered().get("last")
    Editor(root, wanted)
    root.mainloop()
    return 0


def selftest(argv):
    """Everything the window rests on, and how long a frame takes."""
    import time
    bank = generate.read_bank(BANK)
    print("bank: %d shapes, %s cells" % (len(bank), generate.sizes(bank)))
    made = generate.generate(bank, count=128, seed=1, name="selftest")
    print("generated: %d clusters, %d cells, %d links, %d islands"
          % (len(made.clusters), len(made.cells), len(made.links),
             len(geometry.components(made))))
    drawn = paint.StatMap.blank(2048)
    drawn.dab(1024, 1024, 200, "strength", falloff=0.8, scatter=0.3)
    print("painted: %d cells given a statistic" % paint.assign(made, drawn, seed=1))
    if tk is None:
        return 0
    root = tk.Tk()
    root.geometry("1400x900")
    editor = Editor(root, None)
    editor.layout = made
    editor.map = drawn
    root.update()
    editor.fit()
    root.update()
    for _ in range(3):
        start = time.time()
        editor.render()
        print("frame: %.0f ms" % ((time.time() - start) * 1000))
    start = time.time()
    for step in range(20):
        editor.paint_at(-20 + step, -20 + step)
    print("20 dabs: %.0f ms" % ((time.time() - start) * 1000))
    root.destroy()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
