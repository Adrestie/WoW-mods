# -*- coding: utf-8 -*-
r"""Inscrit les chemins de texture dans un M2 converti (v264).

Reproduit l'étape FixTXID de la chaîne de rétroportage, mais scriptable :

  python inscrit_textures.py <brut.m2 (MD21)> <converti.m2 (v264)> <manifest.json>

Le M2 moderne référence ses textures par fileDataID (chunk TXID de l'export
brut, dans l'ORDRE des entrées de texture) ; le manifeste de wow.export donne
le nom de fichier de chaque id. MultiConverter produit un v264 correct mais
aux noms VIDES : ce script appose « spells\<nom> » à la fin du fichier et
règle len/ofs de chaque entrée de type 0 (len compte le NUL terminal —
relevé sur les préparés de la Marque, la référence).

Les types 11, 12 et 13 sont laissés VIDES : ce sont les textures
variables, que CreatureDisplayInfo remplit. Le dossier vient du
manifeste quand il en porte un (les créatures), sinon « spells\ ».
"""
import json
import struct
import sys

sys.stdout.reconfigure(encoding="utf-8")
BS = chr(92)


def chunks(donnees):
    """(fourcc, debut, taille) des chunks d'un fichier MD21."""
    pos = 0
    while pos + 8 <= len(donnees):
        cc = donnees[pos:pos + 4]
        taille = struct.unpack_from("<I", donnees, pos + 4)[0]
        yield cc, pos + 8, taille
        pos += 8 + taille


def main(chemin_brut, chemin_converti, chemin_manifest):
    brut = open(chemin_brut, "rb").read()
    if brut[:4] != b"MD21":
        raise SystemExit("le brut n'est pas un MD21 : %s" % chemin_brut)
    txid = None
    for cc, debut, taille in chunks(brut):
        if cc == b"TXID":
            txid = list(struct.unpack_from("<%dI" % (taille // 4), brut, debut))
    if txid is None:
        raise SystemExit("chunk TXID absent — textures déjà inscrites ?")

    manifest = json.load(open(chemin_manifest, encoding="utf-8"))
    noms = {t["fileDataID"]: t["file"] for t in manifest["textures"]}
    absents = [i for i in txid if i and i not in noms]
    if absents:
        raise SystemExit("ids sans nom dans le manifeste : %s" % absents)

    d = bytearray(open(chemin_converti, "rb").read())
    if d[:4] != b"MD20":
        raise SystemExit("le converti n'est pas un MD20 : %s" % chemin_converti)
    nTex, ofsTex = struct.unpack_from("<2I", d, 0x50)
    if nTex != len(txid):
        raise SystemExit("%d textures dans le M2, %d ids TXID" % (nTex, len(txid)))

    inscrits = 0
    for i in range(nTex):
        off = ofsTex + i * 16
        typ, _flags, ln, _ofn = struct.unpack_from("<4I", d, off)
        if typ != 0 or ln:
            continue                     # type != 0 : texture remplaçable, on laisse
        if not txid[i]:
            continue
        # LE MANIFESTE FAIT FOI quand il porte un dossier : une creature
        # range ses textures sous « creature\<modele>\ », pas sous
        # « spells\ ». wow.export les note en relatif (« ..\creature\... ») :
        # on normalise et on ne garde que la partie utile. Un nom NU reste
        # un effet de sort, donc prefixe par « spells\ » comme avant.
        nom = noms[txid[i]].replace(chr(47), BS).lstrip("." + BS)
        chemin = nom if BS in nom else "spells" + BS + nom
        chemin = chemin.encode("latin-1") + b"\x00"
        struct.pack_into("<2I", d, off + 8, len(chemin), len(d))
        d.extend(chemin)
        inscrits += 1

    open(chemin_converti, "wb").write(bytes(d))
    print("%d chemin(s) inscrit(s) dans %s" % (inscrits, chemin_converti))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    main(sys.argv[1], sys.argv[2], sys.argv[3])
