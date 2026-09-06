# -*- coding: utf-8 -*-
r"""Peint la CARTE DES STATS, canal par canal, avec la palette imposée.

Un logiciel de dessin ordinaire ne convient pas : ses pinceaux doux produisent
des valeurs intermédiaires qui ne correspondent à aucune statistique, et rien ne
l'empêche de poser du rouge 137. Ici, on ne choisit pas une couleur, on choisit
une STATISTIQUE : la nuance et le canal en découlent, et rien d'autre ne peut
être écrit dans l'image.

LE PINCEAU N'ADOUCIT PAS LA VALEUR, IL ADOUCIT LA DENSITÉ. Un falloff de 0 est
un disque dur ; à 1, la probabilité de poser un pixel décroît du centre au bord,
et le bord devient un pointillé — exactement la transition que le générateur
attend, sans jamais écrire une nuance hors palette. Le scatter disperse chaque
touche autour du curseur, comme un aérographe à grains.

Peindre une statistique ne POSE QUE SON BIT : poser du critique par-dessus de la
puissance d'attaque, ou de l'esprit par-dessus de l'intelligence, laisse le reste
en place, et le pixel porte tout — c'est ainsi qu'on fait un cluster mélangé. Le
mode « retirer » efface le seul bit de la statistique choisie.

L'IMAGE EST PRESQUE NOIRE EN VRAI (un bit vaut 1, 2, 4…) : la fenêtre montre une
FAUSSE COULEUR, d'autant plus vive qu'un pixel porte de bits, et SURLIGNE en
blanc les pixels qui portent la statistique sélectionnée.

    python peint_carte.py [image.png]        (défaut : carte_seed.png)

    clic gauche      peindre            molette         zoom (centré au curseur)
    clic droit       déplacer la vue    F               ajuster la vue
    [ et ]           taille du pinceau  Ctrl+Z / Ctrl+Y annuler / rétablir
    Ctrl+S           enregistrer        Ctrl+O          charger
"""
import os
import random
import sys
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

import numpy as np
from PIL import Image, ImageTk

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from palette_carte import (CANAUX, COULEURS_QUALITE, PALETTE, QUALITES_DEFAUT, TAILLE,  # noqa: E402
                           affiche, couleur, decode, lit_qualites, pnginfo_qualites,
                           qualite_au_pixel, rayons_qualite)
import genere_commune as GC  # noqa: E402
import impostor as IMP  # noqa: E402

ICI = os.path.dirname(os.path.abspath(__file__))
DEFAUT = os.path.join(ICI, "carte_seed.png")
HISTORIQUE_MAX = 60


# ---------------------------------------------------------------------------
# L'image : trois plans de gris, un par canal
# ---------------------------------------------------------------------------
class Carte:
    def __init__(self, chemin):
        self.chemin = chemin
        self.qualites = list(QUALITES_DEFAUT)
        if os.path.exists(chemin):
            brut = Image.open(chemin)
            self.qualites = lit_qualites(brut)       # AVANT convert : le texte y est
            img = brut.convert("RGB")
            if img.size != (TAILLE, TAILLE):
                img = img.resize((TAILLE, TAILLE), Image.NEAREST)
        else:
            img = Image.new("RGB", (TAILLE, TAILLE), (0, 0, 0))
        # Tableaux numpy (H, W) uint8 : c'est là qu'on peint.
        self.plans = [np.array(b, dtype=np.uint8) for b in img.split()]
        self.sale = False
        # L'IMPOSTOR : le dessin d'une disposition cuit en RGBA, dans le cadre
        # de la carte. Ce n'est pas peint, ce n'est pas enregistré : c'est un
        # calque de lecture, pour voir où les nœuds tombent.
        self.impostor = None
        self.montre_impostor = True
        self.surligne = None        # (plan, bit) de la statistique sélectionnée

    def ecrit(self, chemin):
        """Écrit l'image ET ses anneaux de qualité, sans changer le fichier courant."""
        Image.merge("RGB", [Image.fromarray(p) for p in self.plans]).save(
            chemin, pnginfo=pnginfo_qualites(self.qualites))

    def sauve(self, chemin=None):
        chemin = chemin or self.chemin
        self.ecrit(chemin)
        self.chemin, self.sale = chemin, False

    def vue(self, x0, y0, x1, y1, largeur, hauteur):
        """Le rectangle visible, fusionné et mis à l'échelle de l'écran."""
        x0, y0 = max(0, int(x0)), max(0, int(y0))
        x1, y1 = min(TAILLE, int(x1) + 1), min(TAILLE, int(y1) + 1)
        if x1 <= x0 or y1 <= y0:
            return Image.new("RGB", (largeur, hauteur), (30, 30, 30))
        plans = [p[y0:y1, x0:x1] for p in self.plans]
        vue = affiche(plans)
        # LE SURLIGNAGE : les pixels qui portent le bit sélectionné, en blanc.
        # C'est ce qui rend un masque de bits lisible — la fausse couleur dit
        # « combien », le surlignage dit « lequel ».
        if self.surligne is not None:
            plan, bit = self.surligne
            m = (plans[plan] & bit) != 0
            if m.any():
                a = np.array(vue)
                a[m] = np.clip(a[m].astype(np.int32) + 150, 0, 255).astype(np.uint8)
                vue = Image.fromarray(a)
        vue = vue.resize((largeur, hauteur), Image.NEAREST)
        if self.impostor is not None and self.montre_impostor:
            calque = self.impostor.crop((x0, y0, x1, y1)).resize((largeur, hauteur), Image.NEAREST)
            vue = Image.alpha_composite(vue.convert("RGBA"), calque).convert("RGB")
        return vue

    def pixel(self, x, y):
        if 0 <= x < TAILLE and 0 <= y < TAILLE:
            return tuple(int(p[y, x]) for p in self.plans)
        return None


# ---------------------------------------------------------------------------
# Le pinceau : taille, falloff en DENSITÉ, scatter
# ---------------------------------------------------------------------------
def masque_touche(rayon, falloff, rng):
    """Un disque de booléens : plein au cœur, pointillé vers le bord.

    `falloff` est la part du rayon qui s'adoucit : 0 = disque dur, 1 = la
    densité décroît linéairement du centre au bord.
    """
    r = max(1, int(rayon))
    yy, xx = np.ogrid[-r:r + 1, -r:r + 1]
    d = np.sqrt(xx * xx + yy * yy) / float(r)
    if falloff <= 0.0:
        return d <= 1.0
    coeur = 1.0 - falloff
    p = np.clip((1.0 - d) / falloff, 0.0, 1.0)
    p[d <= coeur] = 1.0
    p[d > 1.0] = 0.0
    return rng.random(p.shape) < p


class Pinceau:
    def __init__(self):
        self.rayon = 24
        self.falloff = 0.5
        self.scatter = 0
        self.rng = np.random.default_rng()

    def touche(self, carte, x, y, operations):
        """Pose une touche. `operations` : liste de (plan, op, bits) où op est
        "pose" (OU avec bits), "retire" (ET NON bits) ou "zero" (le canal à 0).
        Rend le rectangle touché (x0, y0, x1, y1) ou None."""
        if self.scatter > 0:
            a = self.rng.random() * 2 * np.pi
            d = np.sqrt(self.rng.random()) * self.scatter
            x, y = x + d * np.cos(a), y + d * np.sin(a)
        r = max(1, int(self.rayon))
        cx, cy = int(round(x)), int(round(y))
        x0, y0, x1, y1 = cx - r, cy - r, cx + r + 1, cy + r + 1
        m = masque_touche(r, self.falloff, self.rng)
        # découpe aux bords de l'image
        mx0, my0 = max(0, -x0), max(0, -y0)
        mx1, my1 = m.shape[1] - max(0, x1 - TAILLE), m.shape[0] - max(0, y1 - TAILLE)
        x0, y0, x1, y1 = max(0, x0), max(0, y0), min(TAILLE, x1), min(TAILLE, y1)
        if x1 <= x0 or y1 <= y0:
            return None
        m = m[my0:my1, mx0:mx1]
        for plan, op, bits in operations:
            zone = carte.plans[plan][y0:y1, x0:x1]
            if op == "pose":
                zone[m] |= np.uint8(bits)
            elif op == "retire":
                zone[m] &= np.uint8(~bits & 0xFF)
            else:
                zone[m] = 0
        return (x0, y0, x1, y1)


# ---------------------------------------------------------------------------
# L'historique : par trait, la zone d'avant
# ---------------------------------------------------------------------------
class Historique:
    def __init__(self):
        self.avant, self.apres = [], []

    def debut_trait(self, carte):
        # Photographie complète mais légère : on ne garde que les plans, et l'on
        # ne retiendra à la fin que le rectangle réellement touché.
        self._copie = [p.copy() for p in carte.plans]
        self._bbox = None

    def etend(self, bbox):
        if bbox is None:
            return
        if self._bbox is None:
            self._bbox = list(bbox)
        else:
            self._bbox = [min(self._bbox[0], bbox[0]), min(self._bbox[1], bbox[1]),
                          max(self._bbox[2], bbox[2]), max(self._bbox[3], bbox[3])]

    def fin_trait(self, carte):
        if self._bbox is None:
            return
        x0, y0, x1, y1 = self._bbox
        avant = [c[y0:y1, x0:x1].copy() for c in self._copie]
        apres = [p[y0:y1, x0:x1].copy() for p in carte.plans]
        self.avant.append((self._bbox, avant, apres))
        del self.avant[:-HISTORIQUE_MAX]
        self.apres.clear()
        self._copie = None

    def _applique(self, carte, bbox, plans):
        x0, y0, x1, y1 = bbox
        for p, z in zip(carte.plans, plans):
            p[y0:y1, x0:x1] = z

    def annule(self, carte):
        if not self.avant:
            return False
        bbox, avant, apres = self.avant.pop()
        self._applique(carte, bbox, avant)
        self.apres.append((bbox, avant, apres))
        return True

    def retablit(self, carte):
        if not self.apres:
            return False
        bbox, avant, apres = self.apres.pop()
        self._applique(carte, bbox, apres)
        self.avant.append((bbox, avant, apres))
        return True


# ---------------------------------------------------------------------------
# L'application
# ---------------------------------------------------------------------------
class Appli(tk.Tk):
    def __init__(self, chemin):
        super().__init__()
        self.title("Carte des stats — " + os.path.basename(chemin))
        self.carte = Carte(chemin)
        self.pinceau = Pinceau()
        self.histo = Historique()
        self.outil = ("stat", PALETTE[0])       # ("stat", entrée) | ("noir",) | ("efface", canal)
        self.echelle = 0.45                      # pixels écran par pixel image
        self.ox, self.oy = 0.0, 0.0              # coin haut-gauche visible, en pixels image
        self.dernier = None
        self.photo = None
        self._construit()
        self.after(50, self.ajuste_vue)

    # --- construction --------------------------------------------------------
    def _construit(self):
        gauche = ttk.Frame(self, padding=6)
        gauche.pack(side="left", fill="y")
        self.canvas = tk.Canvas(self, bg="#1e1e1e", highlightthickness=0, cursor="crosshair")
        self.canvas.pack(side="right", fill="both", expand=True)

        ttk.Label(gauche, text="Statistique", font=("Segoe UI", 10, "bold")).pack(anchor="w")
        self.v_mode = tk.StringVar(value="pose")
        f = ttk.Frame(gauche)
        f.pack(fill="x")
        ttk.Radiobutton(f, text="poser", variable=self.v_mode, value="pose").pack(side="left")
        ttk.Radiobutton(f, text="retirer", variable=self.v_mode, value="retire").pack(side="left", padx=8)
        self.boutons = {}
        for entree in PALETTE:
            stat, canal, bit = entree
            f = tk.Frame(gauche)
            f.pack(fill="x", pady=1)
            sw = tk.Label(f, width=3, bg="#%02x%02x%02x" % couleur(canal, bit))
            sw.pack(side="left")
            b = tk.Button(f, text="%s  (%s bit %d)" % (stat, canal, bit.bit_length() - 1),
                          anchor="w", relief="flat",
                          command=lambda e=entree: self.choisit(("stat", e)))
            b.pack(side="left", fill="x", expand=True)
            self.boutons[("stat", entree)] = b
        ttk.Separator(gauche).pack(fill="x", pady=4)
        for texte, outil in (("Noir — effacer les trois canaux", ("noir",)),
                             ("Effacer le canal R", ("efface", "R")),
                             ("Effacer le canal G", ("efface", "G")),
                             ("Effacer le canal B", ("efface", "B"))):
            b = tk.Button(gauche, text=texte, anchor="w", relief="flat",
                          command=lambda o=outil: self.choisit(o))
            b.pack(fill="x", pady=1)
            self.boutons[outil] = b

        ttk.Separator(gauche).pack(fill="x", pady=6)
        ttk.Label(gauche, text="Pinceau", font=("Segoe UI", 10, "bold")).pack(anchor="w")
        self.v_rayon = tk.IntVar(value=self.pinceau.rayon)
        self.v_falloff = tk.DoubleVar(value=self.pinceau.falloff)
        self.v_scatter = tk.IntVar(value=self.pinceau.scatter)
        for texte, var, a, b_ in (("taille (rayon, px)", self.v_rayon, 1, 160),
                                  ("falloff (0 dur → 1 doux)", self.v_falloff, 0.0, 1.0),
                                  ("scatter (px)", self.v_scatter, 0, 200)):
            ttk.Label(gauche, text=texte).pack(anchor="w")
            ttk.Scale(gauche, from_=a, to=b_, variable=var, orient="horizontal",
                      command=lambda _v: self.maj_pinceau()).pack(fill="x")
        self.lbl_pinceau = ttk.Label(gauche, text="")
        self.lbl_pinceau.pack(anchor="w")

        ttk.Separator(gauche).pack(fill="x", pady=6)
        ttk.Label(gauche, text="Qualité — épaisseur des anneaux (% du rayon)",
                  font=("Segoe UI", 10, "bold")).pack(anchor="w")
        self.v_qualites = []
        for k in range(5):
            f = ttk.Frame(gauche)
            f.pack(fill="x")
            q = k + 1                       # anneau central = qualité 1
            c = COULEURS_QUALITE[q]
            tk.Label(f, width=2, bg="#%02x%02x%02x" % c).pack(side="left")
            ttk.Label(f, text="q%d" % q, width=3).pack(side="left")
            var = tk.DoubleVar(value=self.carte.qualites[k])
            ttk.Scale(f, from_=0, to=100, variable=var, orient="horizontal",
                      command=lambda _v, k=k: self.maj_qualites(k)).pack(side="left", fill="x", expand=True)
            lab = ttk.Label(f, text="%3.0f %%" % var.get(), width=6)
            lab.pack(side="left")
            self.v_qualites.append((var, lab))
        self.v_anneaux = tk.BooleanVar(value=True)
        ttk.Checkbutton(gauche, text="afficher les anneaux", variable=self.v_anneaux,
                        command=self.redessine).pack(anchor="w")

        ttk.Separator(gauche).pack(fill="x", pady=6)
        self.v_grille = tk.BooleanVar(value=True)
        self.v_divisions = tk.IntVar(value=13)
        f = ttk.Frame(gauche)
        f.pack(fill="x")
        ttk.Checkbutton(f, text="quadrillage", variable=self.v_grille,
                        command=self.redessine).pack(side="left")
        ttk.Spinbox(f, from_=2, to=40, width=4, textvariable=self.v_divisions,
                    command=self.redessine).pack(side="left", padx=4)

        ttk.Separator(gauche).pack(fill="x", pady=6)
        ttk.Label(gauche, text="Disposition", font=("Segoe UI", 10, "bold")).pack(anchor="w")
        f = ttk.Frame(gauche)
        f.pack(fill="x")
        self.v_clusters = tk.IntVar(value=128)
        self.v_graine = tk.IntVar(value=1)
        ttk.Label(f, text="clusters").pack(side="left")
        ttk.Spinbox(f, from_=8, to=400, width=5, textvariable=self.v_clusters).pack(side="left", padx=(2, 8))
        ttk.Label(f, text="graine").pack(side="left")
        ttk.Spinbox(f, from_=1, to=99999, width=6, textvariable=self.v_graine).pack(side="left", padx=2)
        ttk.Button(gauche, text="Générer → layouts\\commune.xml", command=self.genere_layout).pack(fill="x", pady=(4, 1))
        ttk.Button(gauche, text="Charger un layout en impostor…", command=self.charge_layout).pack(fill="x", pady=1)
        self.v_impostor = tk.BooleanVar(value=True)
        ttk.Checkbutton(gauche, text="afficher l'impostor", variable=self.v_impostor,
                        command=self.bascule_impostor).pack(anchor="w")
        self.lbl_layout = ttk.Label(gauche, text="aucune disposition chargée", wraplength=230, justify="left")
        self.lbl_layout.pack(anchor="w")

        ttk.Separator(gauche).pack(fill="x", pady=6)
        for texte, cmd in (("Annuler  (Ctrl+Z)", self.annule), ("Rétablir  (Ctrl+Y)", self.retablit),
                           ("Enregistrer  (Ctrl+S)", self.enregistre),
                           ("Enregistrer sous…", self.enregistre_sous),
                           ("Charger…  (Ctrl+O)", self.charge), ("Ajuster la vue  (F)", self.ajuste_vue)):
            ttk.Button(gauche, text=texte, command=cmd).pack(fill="x", pady=1)

        self.statut = ttk.Label(gauche, text="", wraplength=230, justify="left")
        self.statut.pack(anchor="w", pady=(8, 0))

        self.canvas.bind("<Configure>", lambda e: self.redessine())
        self.canvas.bind("<ButtonPress-1>", self.debut_trait)
        self.canvas.bind("<B1-Motion>", self.trait)
        self.canvas.bind("<ButtonRelease-1>", self.fin_trait)
        self.canvas.bind("<ButtonPress-3>", self.debut_pan)
        self.canvas.bind("<B3-Motion>", self.pan)
        self.canvas.bind("<MouseWheel>", self.zoom)
        self.canvas.bind("<Motion>", self.survol)
        self.bind("<Control-z>", lambda e: self.annule())
        self.bind("<Control-y>", lambda e: self.retablit())
        self.bind("<Control-s>", lambda e: self.enregistre())
        self.bind("<Control-o>", lambda e: self.charge())
        self.bind("<Key-f>", lambda e: self.ajuste_vue())
        self.bind("<Key-bracketleft>", lambda e: self.change_rayon(-4))
        self.bind("<Key-bracketright>", lambda e: self.change_rayon(4))
        self.protocol("WM_DELETE_WINDOW", self.quitte)
        self.choisit(self.outil)
        self.maj_pinceau()

    # --- outils --------------------------------------------------------------
    def choisit(self, outil):
        self.outil = outil
        for cle, b in self.boutons.items():
            b.configure(bg="#3c6ea0" if cle == outil else self.cget("bg"),
                        fg="white" if cle == outil else "black")
        if outil[0] == "stat":
            _stat, canal, bit = outil[1]
            self.carte.surligne = (CANAUX[canal], bit)
        else:
            self.carte.surligne = None
        self.redessine()

    def operations(self):
        if self.outil[0] == "stat":
            _stat, canal, bit = self.outil[1]
            return [(CANAUX[canal], self.v_mode.get(), bit)]
        if self.outil[0] == "noir":
            return [(0, "zero", 0), (1, "zero", 0), (2, "zero", 0)]
        return [(CANAUX[self.outil[1]], "zero", 0)]

    def maj_pinceau(self):
        self.pinceau.rayon = int(self.v_rayon.get())
        self.pinceau.falloff = float(self.v_falloff.get())
        self.pinceau.scatter = int(self.v_scatter.get())
        self.lbl_pinceau.configure(text="rayon %d px · falloff %.2f · scatter %d px"
                                   % (self.pinceau.rayon, self.pinceau.falloff, self.pinceau.scatter))
        self.dessine_curseur()

    def maj_qualites(self, k):
        var, lab = self.v_qualites[k]
        self.carte.qualites[k] = float(var.get())
        lab.configure(text="%3.0f %%" % var.get())
        self.carte.sale = True
        self.redessine()

    def pousse_qualites(self):
        """Les curseurs prennent les valeurs de la carte (après un chargement)."""
        for k, (var, lab) in enumerate(self.v_qualites):
            var.set(self.carte.qualites[k])
            lab.configure(text="%3.0f %%" % var.get())

    def change_rayon(self, d):
        self.v_rayon.set(max(1, min(160, self.pinceau.rayon + d)))
        self.maj_pinceau()

    # --- vue -----------------------------------------------------------------
    def ecran_vers_image(self, sx, sy):
        return self.ox + sx / self.echelle, self.oy + sy / self.echelle

    def image_vers_ecran(self, ix, iy):
        return (ix - self.ox) * self.echelle, (iy - self.oy) * self.echelle

    def ajuste_vue(self):
        w, h = max(1, self.canvas.winfo_width()), max(1, self.canvas.winfo_height())
        self.echelle = min(w, h) / float(TAILLE)
        self.ox = -(w / self.echelle - TAILLE) / 2
        self.oy = -(h / self.echelle - TAILLE) / 2
        self.redessine()

    def zoom(self, e):
        facteur = 1.25 if e.delta > 0 else 0.8
        ix, iy = self.ecran_vers_image(e.x, e.y)
        self.echelle = max(0.05, min(16.0, self.echelle * facteur))
        self.ox, self.oy = ix - e.x / self.echelle, iy - e.y / self.echelle
        self.redessine()

    def debut_pan(self, e):
        self._pan = (e.x, e.y)

    def pan(self, e):
        dx, dy = e.x - self._pan[0], e.y - self._pan[1]
        self.ox -= dx / self.echelle
        self.oy -= dy / self.echelle
        self._pan = (e.x, e.y)
        self.redessine()

    def redessine(self):
        w, h = max(1, self.canvas.winfo_width()), max(1, self.canvas.winfo_height())
        if w < 2 or h < 2:
            return
        # Le rectangle image visible, rendu à l'échelle : on n'agrandit que ce
        # qu'on voit, jamais les 4 M de pixels.
        x0, y0 = self.ox, self.oy
        x1, y1 = self.ox + w / self.echelle, self.oy + h / self.echelle
        vue = Image.new("RGB", (w, h), (30, 30, 30))
        cx0, cy0 = max(0.0, x0), max(0.0, y0)
        cx1, cy1 = min(float(TAILLE), x1), min(float(TAILLE), y1)
        if cx1 > cx0 and cy1 > cy0:
            sx0, sy0 = self.image_vers_ecran(cx0, cy0)
            sx1, sy1 = self.image_vers_ecran(cx1, cy1)
            lw, lh = max(1, int(round(sx1 - sx0))), max(1, int(round(sy1 - sy0)))
            morceau = self.carte.vue(cx0, cy0, cx1 - 1, cy1 - 1, lw, lh)
            vue.paste(morceau, (int(round(sx0)), int(round(sy0))))
        if self.v_anneaux.get():
            # Les cinq cercles, dans l'espace de l'image puis projetés à l'écran.
            from PIL import ImageDraw
            d = ImageDraw.Draw(vue)
            cx, cy = self.image_vers_ecran(TAILLE / 2.0, TAILLE / 2.0)
            for k, r in enumerate(rayons_qualite(self.carte.qualites, TAILLE)):
                rs = r * self.echelle
                if rs > 0.5:
                    d.ellipse([cx - rs, cy - rs, cx + rs, cy + rs],
                              outline=COULEURS_QUALITE[k + 1], width=2)
        self.photo = ImageTk.PhotoImage(vue)
        self.canvas.delete("all")
        self.canvas.create_image(0, 0, image=self.photo, anchor="nw")
        if self.v_grille.get():
            n = max(2, int(self.v_divisions.get()))
            for k in range(n + 1):
                t = k * TAILLE / float(n)
                sx, _ = self.image_vers_ecran(t, 0)
                _, sy = self.image_vers_ecran(0, t)
                self.canvas.create_line(sx, 0, sx, h, fill="#3a3a5a")
                self.canvas.create_line(0, sy, w, sy, fill="#3a3a5a")
        self.dessine_curseur()
        self.title("Carte des stats — %s%s" % (os.path.basename(self.carte.chemin),
                                                " *" if self.carte.sale else ""))

    def dessine_curseur(self, pos=None):
        self.canvas.delete("curseur")
        if pos is None:
            pos = getattr(self, "_souris", None)
        if pos is None:
            return
        r = self.pinceau.rayon * self.echelle
        self.canvas.create_oval(pos[0] - r, pos[1] - r, pos[0] + r, pos[1] + r,
                                outline="#ffffff", tags="curseur")
        if self.pinceau.scatter:
            s = (self.pinceau.rayon + self.pinceau.scatter) * self.echelle
            self.canvas.create_oval(pos[0] - s, pos[1] - s, pos[0] + s, pos[1] + s,
                                    outline="#888888", dash=(3, 3), tags="curseur")

    # --- peinture ------------------------------------------------------------
    def debut_trait(self, e):
        self.histo.debut_trait(self.carte)
        self.dernier = None
        self.trait(e)

    def trait(self, e):
        ix, iy = self.ecran_vers_image(e.x, e.y)
        cv = self.operations()
        pas = max(1.0, self.pinceau.rayon / 3.0)
        if self.dernier is None:
            points = [(ix, iy)]
        else:
            lx, ly = self.dernier
            d = max(abs(ix - lx), abs(iy - ly))
            n = max(1, int(d / pas))
            points = [(lx + (ix - lx) * k / n, ly + (iy - ly) * k / n) for k in range(1, n + 1)]
        for px, py in points:
            self.histo.etend(self.pinceau.touche(self.carte, px, py, cv))
        self.dernier = (ix, iy)
        self.carte.sale = True
        self._souris = (e.x, e.y)
        self.redessine()

    def fin_trait(self, e):
        self.histo.fin_trait(self.carte)
        self.dernier = None
        self.redessine()

    def survol(self, e):
        self._souris = (e.x, e.y)
        self.dessine_curseur((e.x, e.y))
        ix, iy = self.ecran_vers_image(e.x, e.y)
        px = self.carte.pixel(int(ix), int(iy))
        if px is None:
            self.statut.configure(text="hors carte")
            return
        stats = decode(px)
        q = qualite_au_pixel(ix, iy, TAILLE, self.carte.qualites)
        self.statut.configure(text="(%d, %d)  bits R/G/B %s  ·  qualité %d\n%s" % (
            int(ix), int(iy), px, q,
            "  ·  ".join(s for s, _ in stats) if stats else "noir — liant"))

    # --- disposition : générer, charger, montrer -----------------------------
    def genere_layout(self):
        """Génère depuis l'image EN MÉMOIRE — pas depuis le fichier, qui peut
        être en retard d'un trait. La carte passe par un PNG temporaire, le
        générateur ne lisant que des fichiers."""
        temp = os.path.join(ICI, "carte_en_cours.png")
        self.carte.ecrit(temp)
        self.statut.configure(text="génération en cours…")
        self.update_idletasks()
        try:
            g = GC.genere(int(self.v_clusters.get()), int(self.v_graine.get()),
                          carte_png=temp, nom="commune")
            chemin = GC.ecrit_xml(g)
        except Exception as e:  # noqa: BLE001 — on veut le voir dans la fenêtre
            messagebox.showerror("Génération", str(e))
            return
        finally:
            try:
                os.remove(temp)
            except OSError:
                pass
        texte, stats = GC.bilan(g)
        self.pose_impostor(chemin, texte)

    def charge_layout(self):
        chemin = filedialog.askopenfilename(initialdir=GC.LAYOUTS, filetypes=[("Disposition", "*.xml")])
        if chemin:
            self.pose_impostor(chemin, os.path.basename(chemin))

    def pose_impostor(self, chemin, texte):
        layout = IMP.lit_layout(chemin)
        self.carte.impostor = IMP.bake(layout, TAILLE)
        self.v_impostor.set(True)
        self.carte.montre_impostor = True
        self.lbl_layout.configure(text="%s\n%d emplacements, %d liaisons"
                                  % (texte, len(layout["noeuds"]), len(layout["liaisons"])))
        self.redessine()

    def bascule_impostor(self):
        self.carte.montre_impostor = bool(self.v_impostor.get())
        self.redessine()

    # --- historique et fichiers ---------------------------------------------
    def annule(self):
        if self.histo.annule(self.carte):
            self.carte.sale = True
            self.redessine()

    def retablit(self):
        if self.histo.retablit(self.carte):
            self.carte.sale = True
            self.redessine()

    def enregistre(self):
        self.carte.sauve()
        self.redessine()
        self.statut.configure(text="enregistré : " + self.carte.chemin)

    def enregistre_sous(self):
        chemin = filedialog.asksaveasfilename(defaultextension=".png", initialdir=ICI,
                                              filetypes=[("PNG", "*.png")])
        if chemin:
            self.carte.sauve(chemin)
            self.redessine()

    def charge(self):
        if self.carte.sale and not messagebox.askyesno(
                "Modifications non enregistrées", "Abandonner les modifications en cours ?"):
            return
        chemin = filedialog.askopenfilename(initialdir=ICI, filetypes=[("PNG", "*.png")])
        if chemin:
            impostor, montre, surligne = self.carte.impostor, self.carte.montre_impostor, self.carte.surligne
            self.carte = Carte(chemin)
            self.carte.impostor, self.carte.montre_impostor, self.carte.surligne = impostor, montre, surligne
            self.histo = Historique()
            self.pousse_qualites()
            self.ajuste_vue()

    def quitte(self):
        if self.carte.sale and not messagebox.askyesno(
                "Modifications non enregistrées", "Quitter sans enregistrer ?"):
            return
        self.destroy()


if __name__ == "__main__":
    Appli(sys.argv[1] if len(sys.argv) > 1 else DEFAUT).mainloop()
