// This file is part of mod-forever-ui.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
// Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program. If not, see <http://www.gnu.org/licenses/>.

// ForeverUI Patcher -- fait rendre au Lua l'indice des reglages d'apparence
// et le nom des choix, a la creation de personnage et chez le coiffeur
// (client 3.3.5a, build 12340).
//
// POURQUOI. Le Lua de 3.3.5 n'a aucune fonction qui dise quel choix
// d'apparence est applique (peau, visage, coiffure, couleur des cheveux,
// pilosite). ForeverUI ne peut donc pas numeroter les choix comme camelot,
// ni montrer la couleur du choix en cours. Le moteur les tient pourtant :
//   * a la creation, dans l'objet d'apparence pointe en 0xB6B1A0, aux
//     decalages +0x28, +0x2C, +0x34, +0x24 et +0x30 (l'ordre du paquet de
//     creation, 0x4E03EB-0x4E042F) ;
//   * chez le coiffeur, dans l'objet d'apparence du joueur (joueur actif,
//     0x4038F0, +0xB4C) : +0x34 coiffure, +0x24 couleur, +0x30 pilosite,
//     +0x28 peau (celui que font avancer 0x4F0490, 0x4EB500, 0x4EBCA0 et
//     0x4EB150, les memes routines qu'a la creation).
//
// CE QUE FAIT LE PATCH. Trois pieces :
//   * LA CREATION. CycleCharCustomization(reglage, decalage) ne rendait
//     rien. Sa fin (0x4E0BB3) saute desormais vers 66 octets poses dans la
//     place libre au bout de la section .text (0x9DE3B4), qui lisent
//     l'indice du reglage demande et le rendent au Lua (lua_pushnumber,
//     0x84E2A0). Avec un decalage de 0 la fonction ne change rien et sert de
//     lecture. La taille virtuelle de .text passe de 0x5DD3B3 a 0x5DD400 (sa
//     taille dans le fichier) pour couvrir ces octets.
//   * LE COIFFEUR. GetBarberShopStyleInfo(reglage) rendait nom, description,
//     prix et choix actuel ; elle rend en plus l'indice du choix en cours,
//     et pour la peau celui du visage (+0x2C), dont dependent les peaux.
//     La place libre de .text est prise : la seconde moitie de la fonction
//     (0x52E8CF-0x52E9AF, 225 octets) est reecrite plus serree dans sa
//     propre place, les quatre premieres valeurs calculees comme avant, et
//     son unique saut entrant (0x52E8C5) la vise au debut.
//   * LES NOMS. GetBarberShopStyleInfo(reglage, n) rend le seul nom du
//     choix n (BarberShopStyle.dbc, dans la langue du client), ou nil : le
//     jeu ne donnait que celui du choix en cours. A la creation,
//     CycleCharCustomization(reglage, 0, n) rend, apres l'indice, le nom du
//     choix n (coiffure, pilosite, peau), ou nil. Ce code (253 octets) n'a
//     plus de place dans .text : il va dans une petite section ajoutee en
//     fin de fichier (".fui", 0x200 octets, code executable), declaree dans
//     la place libre de la table des sections ; le corps du coiffeur et la
//     caverne de la creation l'appellent. Leurs appels vers le jeu sont poses selon l'adresse de la
//     section, qui depend du fichier (apres .rsrc, ou apres .wxl).
// Rien d'autre ne change.
//
// PRUDENCE. Le fichier n'est modifie que s'il est reconnu octet pour octet :
// chaque piece d'origine, deja patchee, ou patchee par une version
// precedente (alors mise a jour). Sinon, refus. Une copie
// Wow.exe.foreverui.bak est faite avant la premiere modification. La
// restauration remet les octets d'origine et retire la section : le fichier
// revient a l'octet pres (la section garde sa longueur et son SizeOfImage
// d'origine).
//
// Usage : ForeverUIPatcher.exe                     fenetre
//         ForeverUIPatcher.exe --status  <Wow.exe>  etat (code 0 d'origine,
//         ForeverUIPatcher.exe --patch   <Wow.exe>  10 patche, 15 a mettre a
//         ForeverUIPatcher.exe --restore <Wow.exe>  jour, 20 inconnu)

using System;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Windows.Forms;

namespace ForeverUI
{
    enum Etat { Origine, Patche, Partiel, Inconnu, Absent, Verrouille }

    // l'etat d'une piece ; Ancienne : patchee par une version precedente,
    // reconnue pour la mise a jour et la restauration
    enum Piece { Origine, Ancienne, Patchee, Inconnue }

    static class Patch
    {
        // emplacements dans le fichier (build 12340 : .text a 0x400 dans le fichier)
        const int OFFSET_FONCTION = 0xDFF50;   // CycleCharCustomization, VA 0x4E0B50
        const int OFFSET_SITE = 0xDFFB3;       // VA 0x4E0BB3
        const int OFFSET_CAVE = 0x5DD7B4;      // VA 0x9DE3B4
        const int OFFSET_VSIZE = 0x210;        // taille virtuelle de .text
        const int OFFSET_SAUT = 0x12DCC6;      // GetBarberShopStyleInfo : le rel8 du jne en VA 0x52E8C5
        const int OFFSET_COIFFEUR = 0x12DCCF;  // VA 0x52E8CF-0x52E9AF
        const int VA_APPEL = 0x52E8D0;         // le « call » vers les noms, dans le corps du coiffeur

        // le debut de CycleCharCustomization, jusqu'au site : l'empreinte du build
        static readonly byte[] EMPREINTE = Hex(
            "558bec83ec0c578b7d086a0157e8bed3360083c40885c074556a0257e8afd336" +
            "0083c40885c07446566a0157e8afd43600d97dfe0fb745fe0d000c00008945f8" +
            "6a0257d96df8df7df48b75f483ee01d96dfee889d43600e814ae3a005056e83d" +
            "f6ffff");

        static readonly byte[] SITE_ORIGINE = Hex("83c4185e33c05f8be55dc3");
        static readonly byte[] SITE_PATCHE = Hex("e9fcd74f00cccccccccccc");
        static readonly byte[] CAVE_PATCHE = Hex(
            "83c41883fe04772da1a0b1b60085c074240fb68ef1e39d008b040850db0424" +
            "83ec04dd1c2457e8c1fee6ff83c40cb801000000eb0233c05e5f8be55dc3282c342430");
        // version 2 : « call » vers les noms de la creation a la place du
        // « mov eax, 1 » (+46, rel32 a +47, pose selon la section)
        const int CAVE_APPEL = 46;
        const int VA_CAVE = 0x9DE3B4;
        static readonly byte[] VSIZE_ORIGINE = { 0xB3, 0xD3, 0x5D, 0x00 };
        static readonly byte[] VSIZE_PATCHE = { 0x00, 0xD4, 0x5D, 0x00 };

        // le coiffeur : jne 0x52E913 devient jne 0x52E8CF
        static readonly byte[] SAUT_ORIGINE = { 0x4C };
        static readonly byte[] SAUT_PATCHE = { 0x08 };
        static readonly byte[] COIFFEUR_ORIGINE = Hex(
            "83fb01753f56e8a6f9310056e8a0f93100e80b50edff05d00000008b008b80c0" +
            "0000006a0083c0ff506a00e891802c00d80d4c81a00083c414d95df8d945f8db" +
            "5dfceb4c5753e876fbffff8bf88b4f085156e82afa31008b570c5256e820fa31" +
            "00e8bb4fedff05d00000008b008b80c00000006a0083c0ff506a00e841802c00" +
            "d84f1083c420d95df8d945f8db5dfc5f8b45fc5056e867f9310053e821feffff" +
            "83c40c84c0741cd9e883ec08dd1c2456e81cf9310083c40c5bb8040000005e8b" +
            "e55dc356e8e8f8310083c4045bb8040000005e8be55dc3cccccccccccccccccc" +
            "cc");
        // la version 1 (29/09), sans les noms : reconnue pour la mise a jour
        static readonly byte[] COIFFEUR_V1 = Hex(
            "5783fb01751356e8a5f9310056e89ff93100bf3c81a000eb1a53e8a2fbffff89" +
            "c7ff770856e857fa3100ff770c56e84efa31008d65e8e8e64fedff8b80d00000" +
            "008b80c00000006a0048506a00e86f802c00d84f10d95df8d945f8db5dfcff75" +
            "fc56e89af9310053e854feffff8d65e884c07409d9e8e84a000000eb0656e82e" +
            "f931006a045fe8964fedff85c0742a8b804c0b000085c074200fb68ba4e95200" +
            "50db0408e81c000000475883fb037509db402ce80d0000004789f88d65e85f5b" +
            "5e89ec5dc383ec08dd1c2456e800f9310083c40cc334243028cccccccccccccc" +
            "cc");
        // ebx = reglage - 1, esi = l'etat Lua, [ebp-0x18] = edi sauve ici :
        //   push edi / call NOMS (rel32 a +2, pose selon la section) /
        //   cmp ebx, 1 / jne styles
        //   (couleur) pushnil x2 / edi = 0xA0813C (son facteur en +0x10) / jmp cout
        //   styles :  fiche 0x52E490(ebx) dans edi / pushstring [edi+8], [edi+0xC]
        //   cout :    lea esp, [ebp-0x18] / niveau du joueur actif - 1 /
        //             0x7F6990(0, niveau - 1, 0) * [edi+0x10] / pushinteger
        //   actuel :  0x52E790(ebx) ? pushnumber 1 : pushnil
        //   indice :  edi = 4 / objet d'apparence = [0x4038F0() + 0xB4C], si
        //             present pushnumber [objet + table[ebx]] et edi = 5 ; pour
        //             la peau (ebx = 3), aussi le visage [objet + 0x2C] et
        //             edi = 6 (le moteur retient les peaux selon le visage)
        //   fin :     eax = edi, registres rendus / pushfp : st0 -> pushnumber
        //   table :   34 24 30 28
        static readonly byte[] COIFFEUR_V2 = Hex(
            "57e80000000083fb01751356e8a0f9310056e89af93100bf3c81a000eb1a53e8" +
            "9dfbffff89c7ff770856e852fa3100ff770c56e849fa31008d65e8e8e14fedff" +
            "8b80d00000008b80c00000006a0048506a00e86a802c00d84f10d95df8d945f8" +
            "db5dfcff75fc56e895f9310053e84ffeffff8d65e884c07409d9e8e84a000000" +
            "eb0656e829f931006a045fe8914fedff85c0742a8b804c0b000085c074200fb6" +
            "8ba9e9520050db0408e81c000000475883fb037509db402ce80d0000004789f8" +
            "8d65e85f5b5e89ec5dc383ec08dd1c2456e8fbf8310083c40cc334243028cccc" +
            "cc");

        // LA SECTION AJOUTEE (les noms). Derniere de la table, ses donnees en
        // fin de fichier : "FUIN", la longueur d'origine du fichier et son
        // SizeOfImage (de quoi la retirer a l'octet pres), puis le code.
        static readonly byte[] NOM_SECTION = { 0x2E, 0x66, 0x75, 0x69, 0, 0, 0, 0 };  // ".fui"
        static readonly byte[] MAGIE = { 0x46, 0x55, 0x49, 0x4E };                   // "FUIN"
        const int ENTETE_SECTION = 12;
        const int TAILLE_SECTION = 0x200;
        const uint CARACTERISTIQUES = 0x60000020;  // code, execution, lecture
        // Le code de la section, en deux routines :
        //   * +0, les noms du coiffeur, appele juste apres « push edi » : sans
        //     second argument, retour au corps ; avec un nombre n,
        //     0x52F760(reglage - 1, race, sexe, n) -- la recherche du coiffeur
        //     apres chaque cran -- et le seul nom de la fiche (pushstring
        //     [fiche + 8]), ou nil ; fin de la fonction, 1 valeur. Race et sexe :
        //     [joueur actif + 0xD0] + 0x44 / + 0x46.
        //   * +DECALAGE_NOMSC, les noms de la creation, appele a la place du
        //     « mov eax, 1 » de la caverne (l'indice deja pousse) : sans
        //     troisieme argument, eax = 1 ; avec un nombre n, la ligne de
        //     BarberShopStyle (nombre en 0xAD3238, lignes de 0x20 en
        //     [0xAD324C] : +4 type, +8 nom, +0x14 race, +0x18 sexe ou -1, +0x1C
        //     numero) du type du reglage (peau 3, coiffure 0, pilosite 2), pour
        //     la race (+0x18) et le sexe (+0x1C) de l'objet d'apparence
        //     [0xB6B1A0] : son nom, ou nil ; eax = 2. (L'index du coiffeur
        //     n'existe pas a l'ecran de creation : la table se parcourt.)
        static readonly byte[] CODE_SECTION = Hex(
            "6a0256e80000000083c40885c07501c36a0256e800000000db5dfce800000000" +
            "8b80d0000000ff75fc0fb64846510fb648445153e80000000085c0740e8b4008" +
            "ff700856e800000000eb0656e800000000b8010000008d65e85f5b5e89ec5dc3" +
            "6a0357e80000000083c40885c0750240c35356bb0300000085f6741131db83fe" +
            "02740ab30283fe04740383cbff6a0357e80000000083c40850db1c248b0da0b1" +
            "b60085c97443a14c32ad008b153832ad004a78358b7118397014751a39580475" +
            "158b701883feff74053b711c75088b342439701c740583c020ebd6ff700857e8" +
            "0000000083c408eb0957e80000000083c40483c4045e5bb802000000c3");
        // les appels vers le jeu : (decalage du rel32, cible) -- isnumber,
        // tonumber, joueur actif, recherche, pushstring, pushnil ; puis
        // isnumber, tonumber, pushstring, pushnil
        static readonly int[] RELOCS = { 4, 0x84DF20, 20, 0x84E030, 28, 0x4038F0, 53, 0x52F760, 69, 0x84E350, 77, 0x84E280, 100, 0x84DF20, 145, 0x84E030, 224, 0x84E350, 235, 0x84E280 };
        const int DECALAGE_NOMSC = 96;
        // la section de la version precedente (29/09) : les noms du coiffeur
        // seuls, le reste a zero
        static readonly byte[] CODE_SECTION_V1 = Hex(
            "6a0256e80000000083c40885c07501c36a0256e800000000db5dfce800000000" +
            "8b80d0000000ff75fc0fb64846510fb648445153e80000000085c0740e8b4008" +
            "ff700856e800000000eb0656e800000000b8010000008d65e85f5b5e89ec5dc3");

        static byte[] Hex(string s)
        {
            byte[] r = new byte[s.Length / 2];
            for (int i = 0; i < r.Length; i++)
                r[i] = Convert.ToByte(s.Substring(i * 2, 2), 16);
            return r;
        }

        static bool Egal(byte[] d, int offset, byte[] attendu)
        {
            if (offset < 0 || offset + attendu.Length > d.Length) return false;
            for (int i = 0; i < attendu.Length; i++)
                if (d[offset + i] != attendu[i]) return false;
            return true;
        }

        static bool Nul(byte[] d, int offset, int longueur)
        {
            if (offset < 0 || offset + longueur > d.Length) return false;
            for (int i = 0; i < longueur; i++)
                if (d[offset + i] != 0) return false;
            return true;
        }

        static int I32(byte[] d, int o) { return BitConverter.ToInt32(d, o); }
        static void E32(byte[] d, int o, int v) { Array.Copy(BitConverter.GetBytes(v), 0, d, o, 4); }
        static int Aligner(int v, int a) { return (v + a - 1) / a * a; }

        // l'en-tete PE
        struct Entete
        {
            public int Pe, Sections, Table, Base, AlignSection, AlignFichier, TailleImage, TailleEntetes;
        }

        static bool LireEntete(byte[] d, out Entete h)
        {
            h = new Entete();
            h.Pe = I32(d, 0x3C);
            if (h.Pe <= 0 || h.Pe + 0x100 > d.Length || I32(d, h.Pe) != 0x4550) return false;
            h.Sections = BitConverter.ToUInt16(d, h.Pe + 6);
            h.Table = h.Pe + 24 + BitConverter.ToUInt16(d, h.Pe + 20);
            h.Base = I32(d, h.Pe + 24 + 28);
            h.AlignSection = I32(d, h.Pe + 24 + 32);
            h.AlignFichier = I32(d, h.Pe + 24 + 36);
            h.TailleImage = I32(d, h.Pe + 24 + 56);
            h.TailleEntetes = I32(d, h.Pe + 24 + 60);
            return h.Sections > 0 && h.AlignSection > 0 && h.AlignFichier > 0 && h.Table + h.Sections * 40 <= h.TailleEntetes;
        }

        // le code de la section (ou sa version precedente), pose a l'adresse va
        static byte[] CodeSection(int va, byte[] gabarit)
        {
            byte[] c = (byte[])gabarit.Clone();
            for (int i = 0; i < RELOCS.Length; i += 2)
                if (RELOCS[i] + 4 <= c.Length)
                    E32(c, RELOCS[i], RELOCS[i + 1] - (va + RELOCS[i] + 4));
            return c;
        }

        // la section : Origine si elle n'est pas la ; va = l'adresse de son
        // code et brut = ses donnees dans le fichier, quand elle est reconnue
        static Piece Section(byte[] d, out int va, out int brut)
        {
            va = 0;
            brut = 0;
            Entete h;
            if (!LireEntete(d, out h)) return Piece.Inconnue;
            int t = h.Table + (h.Sections - 1) * 40;
            if (!Egal(d, t, NOM_SECTION)) return Piece.Origine;
            int rva = I32(d, t + 12), taille = I32(d, t + 16);
            brut = I32(d, t + 20);
            if (taille != TAILLE_SECTION || brut + taille != d.Length || !Egal(d, brut, MAGIE)
                || (uint)I32(d, t + 36) != CARACTERISTIQUES)
                return Piece.Inconnue;
            va = h.Base + rva + ENTETE_SECTION;
            int code = brut + ENTETE_SECTION, reste = TAILLE_SECTION - ENTETE_SECTION;
            if (Egal(d, code, CodeSection(va, CODE_SECTION))
                && Nul(d, code + CODE_SECTION.Length, reste - CODE_SECTION.Length))
                return Piece.Patchee;
            if (Egal(d, code, CodeSection(va, CODE_SECTION_V1))
                && Nul(d, code + CODE_SECTION_V1.Length, reste - CODE_SECTION_V1.Length))
                return Piece.Ancienne;
            return Piece.Inconnue;
        }

        static Piece Section(byte[] d)
        {
            int va, brut;
            return Section(d, out va, out brut);
        }

        // l'adresse du code de la section reconnue, 0 sinon
        static int VaSection(byte[] d)
        {
            int va, brut;
            Piece p = Section(d, out va, out brut);
            return (p == Piece.Patchee || p == Piece.Ancienne) ? va : 0;
        }

        static byte[] CaveV2(int vaSection)
        {
            byte[] c = (byte[])CAVE_PATCHE.Clone();
            c[CAVE_APPEL] = 0xE8;
            E32(c, CAVE_APPEL + 1, vaSection + DECALAGE_NOMSC - (VA_CAVE + CAVE_APPEL + 5));
            return c;
        }

        static byte[] CoiffeurV2(int vaNoms)
        {
            byte[] c = (byte[])COIFFEUR_V2.Clone();
            E32(c, 2, vaNoms - (VA_APPEL + 5));
            return c;
        }

        static Piece Creation(byte[] d)
        {
            if (Egal(d, OFFSET_SITE, SITE_ORIGINE) && Nul(d, OFFSET_CAVE, CAVE_PATCHE.Length)
                && Egal(d, OFFSET_VSIZE, VSIZE_ORIGINE))
                return Piece.Origine;
            if (!Egal(d, OFFSET_SITE, SITE_PATCHE) || !Egal(d, OFFSET_VSIZE, VSIZE_PATCHE))
                return Piece.Inconnue;
            if (Egal(d, OFFSET_CAVE, CAVE_PATCHE))
                return Piece.Ancienne;
            int va = VaSection(d);
            if (va > 0 && Egal(d, OFFSET_CAVE, CaveV2(va)))
                return Piece.Patchee;
            return Piece.Inconnue;
        }

        static Piece Coiffeur(byte[] d)
        {
            if (Egal(d, OFFSET_SAUT, SAUT_ORIGINE) && Egal(d, OFFSET_COIFFEUR, COIFFEUR_ORIGINE))
                return Piece.Origine;
            if (!Egal(d, OFFSET_SAUT, SAUT_PATCHE))
                return Piece.Inconnue;
            if (Egal(d, OFFSET_COIFFEUR, COIFFEUR_V1))
                return Piece.Ancienne;
            int va = VaSection(d);
            if (va > 0 && Egal(d, OFFSET_COIFFEUR, CoiffeurV2(va)))
                return Piece.Patchee;
            return Piece.Inconnue;
        }

        public static Etat Lire(string chemin, out byte[] d)
        {
            d = null;
            if (!File.Exists(chemin)) return Etat.Absent;
            try { d = File.ReadAllBytes(chemin); }
            catch (IOException) { return Etat.Verrouille; }
            catch (UnauthorizedAccessException) { return Etat.Verrouille; }
            if (d.Length < OFFSET_CAVE + CAVE_PATCHE.Length || d[0] != 'M' || d[1] != 'Z')
                return Etat.Inconnu;
            if (!Egal(d, OFFSET_FONCTION, EMPREINTE))
                return Etat.Inconnu;
            Piece creation = Creation(d), coiffeur = Coiffeur(d), section = Section(d);
            if (creation == Piece.Inconnue || coiffeur == Piece.Inconnue || section == Piece.Inconnue)
                return Etat.Inconnu;
            if (creation == Piece.Origine && coiffeur == Piece.Origine && section == Piece.Origine)
                return Etat.Origine;
            if (creation == Piece.Patchee && coiffeur == Piece.Patchee && section == Piece.Patchee)
                return Etat.Patche;
            return Etat.Partiel;
        }

        // la section des noms, ajoutee en fin de fichier ; null si l'en-tete
        // n'a pas la place de la declarer
        static byte[] AjouterSection(byte[] d)
        {
            Entete h;
            if (!LireEntete(d, out h)) return null;
            int t = h.Table + h.Sections * 40;
            if (t + 40 > h.TailleEntetes || !Nul(d, t, 40) || h.TailleImage % h.AlignSection != 0)
                return null;
            int brut = Aligner(d.Length, h.AlignFichier);
            int rva = h.TailleImage;
            byte[] r = new byte[brut + TAILLE_SECTION];
            Array.Copy(d, r, d.Length);
            Array.Copy(NOM_SECTION, 0, r, t, NOM_SECTION.Length);
            E32(r, t + 8, TAILLE_SECTION);
            E32(r, t + 12, rva);
            E32(r, t + 16, TAILLE_SECTION);
            E32(r, t + 20, brut);
            E32(r, t + 36, unchecked((int)CARACTERISTIQUES));
            r[h.Pe + 6] = (byte)(h.Sections + 1);
            r[h.Pe + 7] = (byte)((h.Sections + 1) >> 8);
            E32(r, h.Pe + 24 + 56, rva + Aligner(TAILLE_SECTION, h.AlignSection));
            Array.Copy(MAGIE, 0, r, brut, MAGIE.Length);
            E32(r, brut + 4, d.Length);
            E32(r, brut + 8, h.TailleImage);
            byte[] code = CodeSection(h.Base + rva + ENTETE_SECTION, CODE_SECTION);
            Array.Copy(code, 0, r, brut + ENTETE_SECTION, code.Length);
            return r;
        }

        // le fichier tel qu'avant la section : sa longueur, son en-tete
        static byte[] RetirerSection(byte[] d)
        {
            Entete h;
            if (!LireEntete(d, out h)) return null;
            int t = h.Table + (h.Sections - 1) * 40;
            int brut = I32(d, t + 20);
            int longueur = I32(d, brut + 4), image = I32(d, brut + 8);
            if (longueur <= 0 || longueur > brut || image <= 0) return null;
            byte[] r = new byte[longueur];
            Array.Copy(d, r, longueur);
            for (int i = 0; i < 40; i++) r[t + i] = 0;
            r[h.Pe + 6] = (byte)(h.Sections - 1);
            r[h.Pe + 7] = (byte)((h.Sections - 1) >> 8);
            E32(r, h.Pe + 24 + 56, image);
            return r;
        }

        static void Ecrire(string chemin, byte[] d)
        {
            // ecriture dans un fichier voisin, puis remplacement
            string tmp = chemin + ".foreverui.tmp";
            File.WriteAllBytes(tmp, d);
            File.Copy(tmp, chemin, true);
            File.Delete(tmp);
        }

        // rend l'etat obtenu (Patche si reussi) ; les pieces deja patchees
        // restent telles quelles, les anciennes sont mises a jour
        public static Etat Appliquer(string chemin)
        {
            byte[] d;
            Etat e = Lire(chemin, out d);
            if (e != Etat.Origine && e != Etat.Partiel) return e;
            // l'etat des pieces se lit avant de toucher a la section, dont
            // dependent les versions de la creation et du coiffeur
            Piece creation = Creation(d), coiffeur = Coiffeur(d);
            int va, brut;
            Piece section = Section(d, out va, out brut);
            if (section == Piece.Origine)
            {
                d = AjouterSection(d);
                if (d == null) return Etat.Inconnu;
            }
            else if (section == Piece.Ancienne)
            {
                byte[] code = CodeSection(va, CODE_SECTION);
                Array.Copy(code, 0, d, brut + ENTETE_SECTION, code.Length);
            }
            string copie = chemin + ".foreverui.bak";
            if (!File.Exists(copie)) File.Copy(chemin, copie);
            va = VaSection(d);
            if (creation == Piece.Origine || creation == Piece.Ancienne)
            {
                Array.Copy(SITE_PATCHE, 0, d, OFFSET_SITE, SITE_PATCHE.Length);
                Array.Copy(CaveV2(va), 0, d, OFFSET_CAVE, CAVE_PATCHE.Length);
                Array.Copy(VSIZE_PATCHE, 0, d, OFFSET_VSIZE, VSIZE_PATCHE.Length);
            }
            if (coiffeur == Piece.Origine || coiffeur == Piece.Ancienne)
            {
                Array.Copy(SAUT_PATCHE, 0, d, OFFSET_SAUT, SAUT_PATCHE.Length);
                Array.Copy(CoiffeurV2(va), 0, d, OFFSET_COIFFEUR, COIFFEUR_V2.Length);
            }
            Ecrire(chemin, d);
            return Lire(chemin, out d);
        }

        // rend l'etat obtenu (Origine si reussi)
        public static Etat Restaurer(string chemin)
        {
            byte[] d;
            Etat e = Lire(chemin, out d);
            if (e != Etat.Patche && e != Etat.Partiel) return e;
            Piece creation = Creation(d), coiffeur = Coiffeur(d), section = Section(d);
            if (creation == Piece.Patchee || creation == Piece.Ancienne)
            {
                Array.Copy(SITE_ORIGINE, 0, d, OFFSET_SITE, SITE_ORIGINE.Length);
                for (int i = 0; i < CAVE_PATCHE.Length; i++) d[OFFSET_CAVE + i] = 0;
                Array.Copy(VSIZE_ORIGINE, 0, d, OFFSET_VSIZE, VSIZE_ORIGINE.Length);
            }
            if (coiffeur == Piece.Patchee || coiffeur == Piece.Ancienne)
            {
                Array.Copy(SAUT_ORIGINE, 0, d, OFFSET_SAUT, SAUT_ORIGINE.Length);
                Array.Copy(COIFFEUR_ORIGINE, 0, d, OFFSET_COIFFEUR, COIFFEUR_ORIGINE.Length);
            }
            if (section == Piece.Patchee || section == Piece.Ancienne)
            {
                d = RetirerSection(d);
                if (d == null) return Etat.Inconnu;
            }
            Ecrire(chemin, d);
            return Lire(chemin, out d);
        }
    }

    static class Textes
    {
        static readonly bool FR = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "fr";
        public static string T(string fr, string en) { return FR ? fr : en; }

        public static string Etat(Etat e)
        {
            switch (e)
            {
                case ForeverUI.Etat.Origine: return T("Client d'origine : prêt à être patché.", "Original client: ready to be patched.");
                case ForeverUI.Etat.Patche: return T("Client patché : ForeverUI numérote les choix d'apparence.", "Patched client: ForeverUI numbers the appearance choices.");
                case ForeverUI.Etat.Partiel: return T("Client patché par une version précédente : patchez pour le mettre à jour.", "Client patched by an earlier version: patch it to update.");
                case ForeverUI.Etat.Absent: return T("Wow.exe introuvable à cet emplacement.", "Wow.exe not found at this location.");
                case ForeverUI.Etat.Verrouille: return T("Wow.exe est ouvert ou protégé : fermez le jeu.", "Wow.exe is open or protected: close the game.");
                default: return T("Wow.exe non reconnu (build 12340 attendu) : aucune modification.", "Wow.exe not recognized (build 12340 expected): nothing changed.");
            }
        }
    }

    class Fenetre : Form
    {
        readonly TextBox chemin = new TextBox();
        readonly Label etat = new Label();
        readonly Button patcher = new Button();
        readonly Button restaurer = new Button();

        public Fenetre()
        {
            Text = "ForeverUI Patcher";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            ClientSize = new Size(560, 150);
            StartPosition = FormStartPosition.CenterScreen;

            var legende = new Label { Text = "Wow.exe", Location = new Point(12, 16), AutoSize = true };
            chemin.Location = new Point(80, 12);
            chemin.Width = 380;
            chemin.Text = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Wow.exe");
            chemin.TextChanged += delegate { Rafraichir(); };
            var parcourir = new Button { Text = Textes.T("Parcourir...", "Browse..."), Location = new Point(470, 10), Width = 78 };
            parcourir.Click += delegate
            {
                using (var d = new OpenFileDialog { Filter = "Wow.exe|Wow.exe|*.exe|*.exe", FileName = "Wow.exe" })
                    if (d.ShowDialog(this) == DialogResult.OK) chemin.Text = d.FileName;
            };
            etat.Location = new Point(12, 50);
            etat.Size = new Size(536, 40);
            patcher.Text = Textes.T("Patcher", "Patch");
            patcher.Location = new Point(352, 108);
            patcher.Width = 95;
            patcher.Click += delegate { Agir(Patch.Appliquer(chemin.Text), ForeverUI.Etat.Patche); };
            restaurer.Text = Textes.T("Restaurer", "Restore");
            restaurer.Location = new Point(453, 108);
            restaurer.Width = 95;
            restaurer.Click += delegate { Agir(Patch.Restaurer(chemin.Text), ForeverUI.Etat.Origine); };
            Controls.AddRange(new Control[] { legende, chemin, parcourir, etat, patcher, restaurer });
            Rafraichir();
        }

        void Agir(Etat obtenu, Etat voulu)
        {
            Rafraichir();
            if (obtenu != voulu)
                MessageBox.Show(this, Textes.Etat(obtenu), Text, MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }

        void Rafraichir()
        {
            byte[] d;
            Etat e = Patch.Lire(chemin.Text, out d);
            etat.Text = Textes.Etat(e);
            patcher.Enabled = e == Etat.Origine || e == Etat.Partiel;
            restaurer.Enabled = e == Etat.Patche || e == Etat.Partiel;
        }
    }

    static class Programme
    {
        static int Code(Etat e)
        {
            switch (e)
            {
                case Etat.Origine: return 0;
                case Etat.Patche: return 10;
                case Etat.Partiel: return 15;
                default: return 20;
            }
        }

        [STAThread]
        static int Main(string[] args)
        {
            if (args.Length == 2)
            {
                byte[] d;
                Etat e;
                if (args[0] == "--patch") e = Patch.Appliquer(args[1]);
                else if (args[0] == "--restore") e = Patch.Restaurer(args[1]);
                else e = Patch.Lire(args[1], out d);
                Console.WriteLine(e);
                return Code(e);
            }
            Application.EnableVisualStyles();
            Application.Run(new Fenetre());
            return 0;
        }
    }
}
