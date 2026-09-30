# -*- coding: utf-8 -*-
"""The installer's window (MIT licence).

The user picks the module and the folders, reads what is in place, and
installs or removes with one button. The work runs in a background thread;
what the engine says goes to the log at the bottom."""
import json
import os
import queue
import threading
import tkinter as tk
import traceback
from tkinter import filedialog, ttk
from tkinter import font as tkfont

import core

# Dark palette.
BG = "#1e1f22"            # window
CARD = "#2b2d31"          # folder panel, dialogs
FIELD = "#111214"         # entries, lists, log
BORDER = "#3a3d44"
BUTTON = "#3a3d44"
BUTTON_HOVER = "#4a4e57"
TEXT = "#e3e5e8"
MUTED = "#9aa0a8"
ACCENT = "#5b8def"
GOOD = "#5fcf85"
BAD = "#f07070"
SELECTED = "#35507f"

# Colour of the state badge, per state.
BADGES = {
    "absent": ("NOT INSTALLED", "#2f8f4e"),
    "present": ("INSTALLED", "#3b6fd4"),
    "conflict": ("CONFLICT", "#c94141"),
    "error": ("ERROR", "#c94141"),
    "unknown": ("NOT CHECKED", "#5a5e66"),
    "busy": ("WORKING", "#5a5e66"),
}
# Action buttons: (label, style name, colour, colour under the mouse).
ACTIONS = {
    "install": ("Install", "Install.TButton", "#2f8f4e", "#37a65b"),
    "remove": ("Remove", "Remove.TButton", "#c94141", "#d95454"),
    "leftovers": ("Remove leftovers", "Leftovers.TButton", "#c7771f", "#d98a2e"),
}

# The fields: (key in the settings, label, kind of path, needed only by a server module).
FIELDS = [
    ("module", "Module folder", "folder", False),
    ("server", "Worldserver folder", "folder", False),
    ("sources", "AzerothCore sources", "folder", True),
    ("client", "Game folder", "folder", False),
    ("mysql", "MySQL client", "file", True),
]
# What goes in each field, said while it is empty.
EMPTY = {
    "module": "The folder of the module to install or remove: the one that holds installer.json "
              "(for example ...\\WoW-mods\\mod-spheregrid).",
    "server": "The server folder that holds worldserver.exe (for example ...\\build\\bin\\RelWithDebInfo). "
              "The configuration, the databases, the Lua scripts and the server DBC files are found from it.",
    "sources": "Leave empty: found through the build folder's CMakeCache.txt. Otherwise the AzerothCore source "
               "tree, the folder that holds src and modules: the module is copied into its modules folder.",
    "client": "The World of Warcraft 3.3.5a folder, the one that holds Wow.exe and Data (not Data itself): "
              "the module's DBC rows and art are written into its Data archives.",
    "mysql": "Leave empty: found by itself (worldserver.conf, the PATH, MySQL Server's bin folder). Otherwise "
             "mysql.exe, in the bin folder of MySQL Server: it reads and cleans the databases.",
}


def field_state(key, path):
    """(ok, text) of a field's content: ok is None while it is empty, True if the path is the one expected
    there, False otherwise; text says so, or what goes there."""
    if not path:
        return None, EMPTY[key]
    if key == "module":
        folder = core.module_folder(path)
        if folder:
            try:
                with open(os.path.join(folder, core.MANIFEST_NAME), encoding="utf-8") as f:
                    m = json.load(f)
                return True, "installer.json found: %s (%s)." % (m.get("title") or m.get("module"), m.get("module"))
            except (OSError, ValueError, AttributeError):
                return False, "installer.json is unreadable in this folder."
        if os.path.isdir(path):
            inside = sorted(n for n in os.listdir(path) if os.path.isfile(os.path.join(path, n, core.MANIFEST_NAME)))
            if inside:
                return False, "This folder holds several modules: choose one of them (%s)." % ", ".join(inside[:4])
        return False, "No installer.json in this folder: choose the module's own folder, the one that holds it."
    if key == "server":
        if os.path.isfile(os.path.join(path, "worldserver.exe")):
            return True, "worldserver.exe found: the configuration, the databases, the Lua scripts and the " \
                         "server DBC files are read from here."
        return False, "No worldserver.exe in this folder: choose the folder that holds it."
    if key == "sources":
        if os.path.isdir(os.path.join(path, "src")) and os.path.isdir(os.path.join(path, "modules")):
            return True, "AzerothCore sources: the module is copied into %s." % os.path.join(path, "modules")
        return False, "Not an AzerothCore source tree: the folder must hold src and modules."
    if key == "client":
        if os.path.basename(os.path.normpath(path)).lower() == "data" and \
                os.path.isfile(os.path.join(os.path.dirname(os.path.normpath(path)), "Wow.exe")):
            return False, "This is the Data folder: choose its parent, the one that holds Wow.exe."
        try:
            core.Client(path)
            return True, "Game found: the module's DBC rows and art are written into its Data archives."
        except (core.InstallerError, OSError):
            return False, "No Data folder with .MPQ archives here: choose the folder that holds Wow.exe and Data."
    if os.path.isfile(path) and os.path.basename(path).lower() == "mysql.exe":
        return True, "MySQL client: it reads and cleans the databases named in worldserver.conf."
    return False, "Not mysql.exe: choose mysql.exe in the bin folder of MySQL Server."


def module_is_server(path):
    """False when the module's manifest says it is a package for the game only."""
    try:
        with open(os.path.join(core.module_folder(path) or "", core.MANIFEST_NAME), encoding="utf-8") as f:
            return json.load(f).get("server_module", True) is not False
    except (OSError, ValueError, AttributeError):
        return True


def dark_title_bar(window):
    """Asks Windows for a dark title bar (Windows 10 20H1 and later; ignored elsewhere)."""
    try:
        import ctypes
        window.update_idletasks()
        handle = ctypes.windll.user32.GetParent(window.winfo_id())
        value = ctypes.c_int(1)
        for attribute in (20, 19):          # DWMWA_USE_IMMERSIVE_DARK_MODE, then its older number
            if ctypes.windll.dwmapi.DwmSetWindowAttribute(handle, attribute, ctypes.byref(value),
                                                          ctypes.sizeof(value)) == 0:
                break
    except (AttributeError, OSError):
        pass


class InstallerWindow(object):
    def __init__(self, root, module, settings, load_manifest):
        self.root = root
        self.settings = settings
        self.load_manifest = load_manifest
        self.events = queue.Queue()
        self.context = None           # (M, server, client, dbs, state) of the last check
        self.working = False
        self.filling = False          # fields being filled by the window itself
        self.action = None
        core.output = lambda text: self.events.put(("log", text))

        root.withdraw()
        root.title("WoW-mods installer")
        root.configure(bg=BG)
        scale = root.winfo_fpixels("1i") / 96.0
        width = min(int(1000 * scale), root.winfo_screenwidth() - 40)
        height = min(int(860 * scale), root.winfo_screenheight() - 80)
        root.geometry("%dx%d" % (width, height))
        root.minsize(int(800 * scale), int(640 * scale))
        root.protocol("WM_DELETE_WINDOW", self.close)
        self.styles()

        outer = ttk.Frame(root, padding=(20, 16, 20, 12))
        outer.pack(fill="both", expand=True)
        ttk.Label(outer, text="WoW-mods installer", style="Title.TLabel").pack(anchor="w")
        ttk.Label(outer, text="Installs a module, or removes it when it is present.",
                  style="Hint.TLabel").pack(anchor="w", pady=(0, 12))

        # Folders: one row per field, with what goes there under it.
        ttk.Label(outer, text="FOLDERS", style="Section.TLabel").pack(anchor="w", pady=(0, 4))
        box = ttk.Frame(outer, style="Card.TFrame", padding=(14, 10))
        box.pack(fill="x")
        box.columnconfigure(1, weight=1)
        self.vars, self.rows, self.notes = {}, {}, {}
        for i, (key, label, kind, _) in enumerate(FIELDS):
            var = tk.StringVar(value=(module if key == "module" and module else settings.get(key) or ""))
            var.trace_add("write", lambda *_, k=key: self.fields_changed(k))
            note = ttk.Label(box, style="CardHint.TLabel", justify="left", wraplength=600)
            widgets = [ttk.Label(box, text=label, style="CardField.TLabel", width=20),
                       ttk.Entry(box, textvariable=var),
                       ttk.Button(box, text="Browse...", command=lambda k=key, t=kind: self.browse(k, t)),
                       note]
            widgets[1].bind("<Return>", lambda _: self.check())
            widgets[0].grid(row=2 * i, column=0, sticky="w", pady=(6, 0))
            widgets[1].grid(row=2 * i, column=1, sticky="ew", padx=8, pady=(6, 0))
            widgets[2].grid(row=2 * i, column=2, pady=(6, 0))
            note.grid(row=2 * i + 1, column=1, columnspan=2, sticky="w", padx=8, pady=(2, 4))
            self.vars[key], self.rows[key], self.notes[key] = var, widgets, note
            self.show_note(key)
        box.bind("<Configure>", lambda e: [n.configure(wraplength=max(300, e.width - 260))
                                           for n in self.notes.values()])
        bar = ttk.Frame(box, style="Card.TFrame")
        bar.grid(row=2 * len(FIELDS), column=0, columnspan=3, sticky="ew", pady=(8, 0))
        self.places = ttk.Label(bar, text="", style="CardHint.TLabel", justify="left", wraplength=700)
        self.places.pack(side="left")
        self.check_button = ttk.Button(bar, text="Check", style="Accent.TButton", command=self.check)
        self.check_button.pack(side="right")

        # Progress, at the bottom of the window.
        status = ttk.Frame(outer)
        status.pack(side="bottom", fill="x", pady=(8, 0))
        self.progress = ttk.Progressbar(status, mode="determinate", length=180)
        self.progress.pack(side="left")
        self.progress_text = ttk.Label(status, text="", style="Hint.TLabel")
        self.progress_text.pack(side="left", padx=10)

        # State, then log, in two panes the user can resize.
        panes = ttk.PanedWindow(outer, orient="vertical")
        panes.pack(fill="both", expand=True, pady=(14, 0))
        top = ttk.Frame(panes)
        panes.add(top, weight=4)
        head = ttk.Frame(top)
        head.pack(fill="x")
        self.badge = tk.Label(head, font=("Segoe UI", 10, "bold"), fg="white", padx=10, pady=3)
        self.badge.pack(side="left")
        self.module_title = ttk.Label(head, text="", style="Module.TLabel")
        self.module_title.pack(side="left", padx=12)
        self.action_button = ttk.Button(head, text="Install", style="Install.TButton", command=self.act)
        self.action_button.pack(side="right")
        self.explanation = ttk.Label(top, text="", wraplength=860, justify="left")
        self.explanation.pack(fill="x", pady=(8, 6))
        top.bind("<Configure>", lambda e: self.explanation.configure(wraplength=max(300, e.width - 10)))
        tree_box = ttk.Frame(top)
        tree_box.pack(fill="both", expand=True)
        self.tree = ttk.Treeview(tree_box, columns=("detail",), show="tree headings", height=7)
        self.tree.heading("#0", text="What", anchor="w")
        self.tree.heading("detail", text="Where", anchor="w")
        self.tree.column("#0", width=230, stretch=False)
        self.tree.column("detail", width=600, stretch=True)
        self.tree.tag_configure("group", font=("Segoe UI", 9, "bold"))
        self.tree.tag_configure("conflict", foreground=BAD)
        scroll = ttk.Scrollbar(tree_box, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=scroll.set)
        self.tree.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")

        bottom = ttk.Frame(panes)
        panes.add(bottom, weight=1)
        ttk.Label(bottom, text="LOG", style="Section.TLabel").pack(anchor="w", pady=(8, 4))
        log_box = ttk.Frame(bottom)
        log_box.pack(fill="both", expand=True)
        self.log = tk.Text(log_box, height=6, wrap="none", font=("Consolas", 9), relief="flat", borderwidth=0,
                           background=FIELD, foreground=TEXT, insertbackground=TEXT, selectbackground=SELECTED,
                           highlightthickness=1, highlightbackground=BORDER, highlightcolor=BORDER,
                           padx=6, pady=4, state="disabled")
        log_scroll = ttk.Scrollbar(log_box, orient="vertical", command=self.log.yview)
        self.log.configure(yscrollcommand=log_scroll.set)
        self.log.pack(side="left", fill="both", expand=True)
        log_scroll.pack(side="right", fill="y")

        self.show_state("unknown", "", "Fill in the folders, then press Check.")
        dark_title_bar(root)
        root.deiconify()
        self.root.after(60, self.poll)
        if self.ready(quiet=True):
            self.root.after(200, self.check)

    # -- look -----------------------------------------------------------------
    def styles(self):
        style = ttk.Style(self.root)
        style.theme_use("clam")
        base = ("Segoe UI", 9)
        style.configure(".", background=BG, foreground=TEXT, fieldbackground=FIELD, bordercolor=BORDER,
                        lightcolor=BORDER, darkcolor=BORDER, troughcolor=FIELD, focuscolor=ACCENT,
                        selectbackground=SELECTED, selectforeground=TEXT, insertcolor=TEXT, font=base)
        style.configure("TFrame", background=BG)
        style.configure("Card.TFrame", background=CARD)
        style.configure("TLabel", background=BG, foreground=TEXT)
        style.configure("Title.TLabel", font=("Segoe UI", 17, "bold"))
        style.configure("Module.TLabel", font=("Segoe UI", 12, "bold"))
        style.configure("Section.TLabel", font=("Segoe UI", 8, "bold"), foreground=MUTED)
        style.configure("Hint.TLabel", foreground=MUTED)
        style.configure("CardField.TLabel", background=CARD, font=("Segoe UI", 9, "bold"))
        style.configure("CardHint.TLabel", background=CARD, foreground=MUTED)
        style.configure("CardGood.TLabel", background=CARD, foreground=GOOD)
        style.configure("CardBad.TLabel", background=CARD, foreground=BAD)
        style.configure("Dialog.TFrame", background=CARD)
        style.configure("Dialog.TLabel", background=CARD, foreground=TEXT)
        style.configure("Dialog.TCheckbutton", background=CARD, foreground=TEXT, indicatorbackground=FIELD,
                        indicatorforeground=TEXT, focuscolor=CARD)
        style.map("Dialog.TCheckbutton", background=[("active", CARD)], indicatorbackground=[("active", BUTTON)])
        for name, colour in (("DialogInfo", ACCENT), ("DialogWarning", "#e0a040"), ("DialogError", BAD)):
            style.configure(name + ".TLabel", background=CARD, foreground=colour, font=("Segoe UI", 12, "bold"))
        style.configure("TEntry", fieldbackground=FIELD, foreground=TEXT, insertcolor=TEXT, padding=(6, 4))
        style.map("TEntry", bordercolor=[("focus", ACCENT)], lightcolor=[("focus", ACCENT)])
        style.configure("TButton", background=BUTTON, foreground=TEXT, bordercolor=BUTTON, lightcolor=BUTTON,
                        darkcolor=BUTTON, padding=(14, 5))
        style.map("TButton", background=[("disabled", CARD), ("pressed", BORDER), ("active", BUTTON_HOVER)],
                  foreground=[("disabled", MUTED)], lightcolor=[("active", BUTTON_HOVER)],
                  darkcolor=[("active", BUTTON_HOVER)], bordercolor=[("focus", ACCENT)])
        coloured = [("Accent.TButton", ACCENT, "#6f9cf2", ("Segoe UI", 9, "bold"), (18, 5))]
        coloured += [(s, c, h, ("Segoe UI", 10, "bold"), (24, 7)) for _, s, c, h in ACTIONS.values()]
        for name, colour, hover, font, padding in coloured:
            style.configure(name, background=colour, foreground="white", bordercolor=colour, lightcolor=colour,
                            darkcolor=colour, font=font, padding=padding)
            style.map(name, background=[("disabled", BUTTON), ("active", hover)],
                      foreground=[("disabled", MUTED)], lightcolor=[("active", hover)],
                      darkcolor=[("active", hover)], bordercolor=[("disabled", BUTTON), ("focus", "white")])
        # Tree rows as tall as the text, whatever the screen scaling.
        style.configure("Treeview", background=FIELD, fieldbackground=FIELD, foreground=TEXT, bordercolor=BORDER,
                        rowheight=int(tkfont.nametofont("TkDefaultFont").metrics("linespace") * 1.5))
        style.map("Treeview", background=[("selected", SELECTED)], foreground=[("selected", TEXT)])
        style.configure("Treeview.Heading", background=CARD, foreground=MUTED, bordercolor=BORDER,
                        lightcolor=CARD, darkcolor=CARD, relief="flat")
        style.map("Treeview.Heading", background=[("active", BUTTON)])
        style.configure("Vertical.TScrollbar", background=BUTTON, troughcolor=BG, bordercolor=BG, arrowcolor=MUTED,
                        lightcolor=BUTTON, darkcolor=BUTTON)
        style.map("Vertical.TScrollbar", background=[("active", BUTTON_HOVER)])
        style.configure("Horizontal.TProgressbar", background=ACCENT, troughcolor=FIELD, bordercolor=BORDER,
                        lightcolor=ACCENT, darkcolor=ACCENT)
        style.configure("Sash", sashthickness=6, background=BG, bordercolor=BG, lightcolor=BG, darkcolor=BG)

    def show_state(self, kind, title, text, action=None):
        label, colour = BADGES[kind]
        self.badge.configure(text=label, bg=colour)
        self.module_title.configure(text=title)
        self.explanation.configure(text=text)
        self.action = action
        if action:
            self.action_button.configure(text=ACTIONS[action][0], style=ACTIONS[action][1])
        self.update_buttons()

    def update_buttons(self):
        self.check_button.configure(state="disabled" if self.working else "normal")
        self.action_button.configure(state="normal" if self.action and not self.working else "disabled")

    def dialog(self, title, text, buttons, kind="info", focus=0, option=None):
        """A modal dialog in the window's colours; buttons: [(label, value, style)], left to right, the one
        at index focus has the focus. Returns the value of the button pressed, None if it is closed; with
        option (the text of a box, ticked at first), returns (value, ticked)."""
        top = tk.Toplevel(self.root)
        top.withdraw()
        top.title(title)
        top.configure(bg=CARD)
        top.transient(self.root)
        top.resizable(False, False)
        chosen = {"value": None}
        body = ttk.Frame(top, style="Dialog.TFrame", padding=(24, 18, 24, 16))
        body.pack(fill="both", expand=True)
        ttk.Label(body, text=title, style="Dialog%s.TLabel" % kind.capitalize()).pack(anchor="w")
        ttk.Label(body, text=text, style="Dialog.TLabel", wraplength=560, justify="left").pack(anchor="w",
                                                                                           pady=(8, 18))
        ticked = tk.BooleanVar(value=True)
        if option:
            ttk.Checkbutton(body, text=option, variable=ticked, style="Dialog.TCheckbutton").pack(anchor="w",
                                                                                                pady=(0, 16))
        row = ttk.Frame(body, style="Dialog.TFrame")
        row.pack(fill="x")
        widgets = []
        for label, value, button_style in reversed(buttons):
            b = ttk.Button(row, text=label, style=button_style,
                           command=lambda v=value: (chosen.update(value=v), top.destroy()))
            b.pack(side="right", padx=(8, 0))
            widgets.insert(0, b)
        top.bind("<Escape>", lambda _: top.destroy())
        top.bind("<Return>", lambda _: top.focus_get().invoke() if hasattr(top.focus_get(), "invoke") else None)
        dark_title_bar(top)
        top.update_idletasks()
        x = self.root.winfo_rootx() + (self.root.winfo_width() - top.winfo_reqwidth()) // 2
        y = self.root.winfo_rooty() + (self.root.winfo_height() - top.winfo_reqheight()) // 3
        top.geometry("+%d+%d" % (max(0, x), max(0, y)))
        top.deiconify()
        top.grab_set()
        widgets[focus].focus_set()
        self.root.wait_window(top)
        return (chosen["value"], ticked.get()) if option else chosen["value"]

    # -- fields ---------------------------------------------------------------
    def show_note(self, key):
        ok, text = field_state(key, self.values()[key])
        self.notes[key].configure(text=("✓ " if ok else "✗ " if ok is False else "") + text,
                                  style="CardGood.TLabel" if ok else "CardBad.TLabel" if ok is False
                                  else "CardHint.TLabel")

    def browse(self, key, kind):
        current = self.vars[key].get().strip()
        start = current if os.path.isdir(current) else os.path.dirname(current) if current else ""
        label = dict((k, l) for k, l, _, _ in FIELDS)[key]
        if kind == "folder":
            path = filedialog.askdirectory(parent=self.root, initialdir=start, mustexist=True,
                                           title="%s: %s" % (label, EMPTY[key].split(" (")[0]))
        else:
            path = filedialog.askopenfilename(parent=self.root, initialdir=start, title="%s: mysql.exe" % label,
                                              filetypes=[("mysql.exe", "mysql.exe"), ("*.exe", "*.exe")])
        if path:
            self.vars[key].set(os.path.normpath(path))
            if self.ready(quiet=True):
                self.check()

    def fields_changed(self, key):
        self.show_note(key)
        if self.filling or self.working:
            return
        self.context = None
        self.tree.delete(*self.tree.get_children())
        self.places.configure(text="")
        self.show_state("unknown", self.module_title.cget("text"), "The folders changed: press Check.")

    def values(self):
        return {key: var.get().strip().strip('"') for key, var in self.vars.items()}

    def ready(self, quiet=False):
        """True if the fields needed for a check hold the expected paths; otherwise says which one is wrong."""
        server_module = module_is_server(self.values()["module"])
        for key, label, _, server_only in FIELDS:
            if server_only and not server_module:
                continue
            ok = field_state(key, self.values()[key])[0]
            needed = key in ("module", "server", "client")
            if ok is False or (needed and ok is None):
                if not quiet:
                    self.show_state("unknown", "", "%s: %s" % (label, field_state(key, self.values()[key])[1]))
                return False
        return True

    def show_rows(self, server_module):
        for key, _, _, server_only in FIELDS:
            for w in self.rows[key]:
                if server_only and not server_module:
                    w.grid_remove()
                else:
                    w.grid()

    # -- background work ------------------------------------------------------
    def work(self, text, job, done):
        """Runs job() in a thread, then done(result) here; failures go to failed()."""
        self.working = True
        self.update_buttons()
        self.progress_text.configure(text=text)
        self.progress.configure(mode="indeterminate")
        self.progress.start(12)

        def target():
            try:
                self.events.put(("done", done, job()))
            except Exception as e:
                self.events.put(("failed", e, traceback.format_exc()))
        threading.Thread(target=target, daemon=True).start()

    def poll(self):
        try:
            while True:
                event = self.events.get_nowait()
                if event[0] == "log":
                    self.write_log(event[1])
                    continue
                self.working = False
                self.progress.stop()
                self.progress.configure(mode="determinate", value=0)
                self.progress_text.configure(text="")
                if event[0] == "done":
                    event[1](event[2])
                else:
                    self.failed(event[1], event[2])
                self.update_buttons()
        except queue.Empty:
            pass
        self.root.after(60, self.poll)

    def write_log(self, text):
        self.log.configure(state="normal")
        self.log.insert("end", text + "\n")
        self.log.see("end")
        self.log.configure(state="disabled")

    def failed(self, error, trace):
        message, unexpected = core.describe_failure(error)
        self.write_log("")
        self.write_log("FAILED: %s" % message)
        if unexpected:
            self.write_log(trace)
        if self.pending_action:
            self.dialog("Failed", message[0].upper() + message[1:], [("Close", None, "TButton")], kind="error")
            self.pending_action = None
            self.check()
        else:
            self.context = None
            self.show_state("error", self.module_title.cget("text"), message[0].upper() + message[1:])

    # -- check ----------------------------------------------------------------
    pending_action = None

    def check(self):
        if self.working or not self.ready():
            return
        v = self.values()

        def job():
            M = self.load_manifest(core.module_folder(v["module"]))
            server = core.open_server(M, v["server"], v["sources"])
            client = core.Client(v["client"])
            dbs = {}
            if M.server_module:
                dbs = core.open_databases(server, v["mysql"] or core.find_mysql(server, self.settings))
            core.check_package_place(M, server)
            return M, server, client, dbs, core.survey(M, server, client, dbs)

        self.show_state("busy", self.module_title.cget("text"), "Reading the server, the game archives and "
                                                                "the database...")
        self.work("Checking...", job, self.checked)

    def checked(self, context):
        M, server, client, dbs, state = context
        self.context = context
        self.filling = True
        self.vars["module"].set(M.root)
        if M.server_module:
            self.vars["sources"].set(server.sources)
            self.vars["mysql"].set(dbs["world"].mysql)
        self.filling = False
        self.show_rows(M.server_module)
        core.remember(self.settings, M, server, client, dbs)
        # Where the worldserver keeps its files, relative to its folder when inside it.
        self.places.configure(text="Found from the worldserver folder:  " + "  \u00b7  ".join(
            "%s: %s" % (label, os.path.relpath(path, server.bin)
                       if label != "databases" and core.is_inside(path, server.bin) else path)
            for label, path in core.folder_lines(M, server, client, dbs)[1:] if label not in ("sources", "game")))
        self.fill_tree(state, client)
        title = "%s  (%s)" % (M.title, M.name) if M.title != M.name else M.name
        if state.strong():
            what = "files, DBC rows and database data, players' data included" if M.server_module \
                else "game files, addons and DBC rows"
            self.show_state("present", title, "The module is present, in whole or in part. Remove takes away "
                                              "everything that is left of it: %s." % what, "remove")
        elif state.weak():
            self.show_state("conflict", title, "These items carry the module's identifiers, but nothing proves "
                                               "they are its own: the module cannot be installed while they are "
                                               "there. If they are leftovers of an installation of this module, "
                                               "Remove leftovers takes away their database and DBC rows (never "
                                               "a game file). If they belong to something else, the identifiers "
                                               "of one of the two have to change.", "leftovers")
        else:
            self.show_state("absent", title, "No trace of the module. Install puts it in place: %s." % (
                "sources, configuration, Lua scripts, DBC rows and game files; the server is rebuilt afterwards"
                if M.server_module else "game files, addons and DBC rows"), "install")
        self.write_log("%s: %s" % (M.name, {"remove": "present", "leftovers": "conflict",
                                            "install": "not installed"}[self.action]))

    def fill_tree(self, state, client):
        self.tree.delete(*self.tree.get_children())
        groups = [("Traces of the module", state.lines(), ""),
                  ("Carry its identifiers without being proven its own", state.conflict_lines(), "conflict"),
                  ("Archives that could not be read", [("archive", "%s (%s)" % u) for u in client.unreadable],
                   "conflict")]
        shown = False
        for name, lines, tag in groups:
            if not lines:
                continue
            shown = True
            parent = self.tree.insert("", "end", text="%s (%d)" % (name, len(lines)), open=True, tags=("group",))
            for area, text in lines:
                self.tree.insert(parent, "end", text=area, values=(text,), tags=(tag,))
        if not shown:
            self.tree.insert("", "end", text="No trace of the module", values=("",))

    # -- install, remove --------------------------------------------------------
    def act(self):
        if self.working or not self.context or not self.action:
            return
        M, server, client, dbs, state = self.context
        action = self.action
        cancel = ("Cancel", False, "TButton")
        refusals = core.wow_exe_refusals(M, client) if action == "install" else []
        if any(s != "original" for _, s in refusals):
            self.dialog("Cannot install %s" % M.title, core.refusal_text(client, refusals)[0].upper()
                        + core.refusal_text(client, refusals)[1:] + ".", [("Close", None, "TButton")], kind="error")
            return
        # The existing archives about to change, offered for a backup.
        changing = core.install_targets(M, client) if action == "install" \
            else sorted(core.removal_plan(M, state, action == "leftovers"))
        archives = core.archives_to_back_up(changing)
        option = "Back up first the archive%s about to change: %s" % (
            "s" if len(archives) > 1 else "",
            ", ".join("%s (%s)" % (os.path.basename(p), core.size_text(n)) for p, n in archives)) \
            if archives else None
        if action == "install":
            where = ("the server sources, its configuration and Lua scripts, the game archives (MPQ)"
                     + (" and the server DBC files" if any(d.server is not None for d in M.dbc) else "")
                     if M.server_module else "the game archives (MPQ) and Interface\\AddOns")
            text = "The installer writes into %s.%s" % (
                where, "\n\nThe server must be rebuilt afterwards." if M.server_module else "")
            if refusals:
                text += "\n\n%s." % core.refusal_text(client, refusals)
            answer = self.dialog("Install %s?" % M.title, text,
                                 [("Patch Wow.exe and install" if refusals else "Install", True,
                                   ACTIONS["install"][1]), cancel], option=option)
        elif action == "remove":
            answer = self.dialog("Remove %s?" % M.title, "Everything that is left of it goes: %s.\n\nThis cannot "
                                 "be undone." % ("files, DBC rows and database data, players' data included"
                                                 if M.server_module else "game files, addons and DBC rows"),
                                 [("Remove", True, ACTIONS["remove"][1]), cancel], kind="warning", focus=1,
                                 option=option)
        else:
            answer = self.dialog("Remove the leftovers of %s?" % M.title, "The database rows and DBC rows listed "
                                 "as conflicts go; game files never do. Do it only if they are leftovers of this "
                                 "module.", [("Remove leftovers", True, ACTIONS["leftovers"][1]), cancel],
                                 kind="warning", focus=1, option=option)
        ok, backup = answer if option else (answer, False)
        if not ok:
            return

        def job():
            # Read again: the state may have changed since the check.
            fresh = core.survey(M, server, core.Client(client.folder), dbs)
            now = "remove" if fresh.strong() else "leftovers" if fresh.weak() else "install"
            if now != action:
                raise core.InstallerError("the state changed since the check: check again")
            core.refuse_while_running(server, client)
            if action == "install":
                core.install_and_check(M, server, client, dbs, patch_exe=bool(refusals), backup=backup)
            else:
                core.remove_and_check(M, server, client, dbs, fresh, leftovers=action == "leftovers",
                                      backup=backup)
            return M, server, action

        self.pending_action = action
        self.write_log("")
        self.work({"install": "Installing...", "remove": "Removing...", "leftovers": "Removing leftovers..."}
                  [action], job, self.acted)

    def acted(self, result):
        M, server, action = result
        self.pending_action = None
        if action == "install":
            title, text = "Installation complete", ""
            if M.server_module:
                text = "\n".join(core.build_steps(server))
                text += "\n\n" + ("On first start, the core updater applies the module's SQL."
                                  if server.updates_mask & 6 == 6 else
                                  "The installer applied the module's SQL itself (the core updater is off).")
        else:
            title = "Uninstallation complete" if action == "remove" else "Leftovers removed"
            text = "\n".join(core.build_steps(server)) if M.server_module else ""
        self.dialog(title, text or "Nothing else to do.", [("Close", None, "Accent.TButton")])
        self.check()

    def close(self):
        if self.working:
            self.dialog("Please wait", "The installer is working: wait until it has finished.",
                        [("Close", None, "TButton")], kind="warning")
            return
        self.root.destroy()


def run(module, settings, load_manifest):
    """Opens the window; module: the module folder given on the command line (or dropped on the exe)."""
    try:
        import ctypes
        ctypes.windll.shcore.SetProcessDpiAwareness(1)      # sharp text on scaled screens
    except (AttributeError, OSError):
        pass
    root = tk.Tk()
    InstallerWindow(root, module, settings, load_manifest)
    root.mainloop()
