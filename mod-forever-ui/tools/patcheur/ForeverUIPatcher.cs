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

// ForeverUI Patcher -- fait rendre au Lua de la creation de personnage
// l'indice des reglages d'apparence (client 3.3.5a, build 12340).
//
// POURQUOI. Le Lua des ecrans d'accueil de 3.3.5 n'a aucune fonction qui dise
// quel choix d'apparence est applique (peau, visage, coiffure, couleur des
// cheveux, pilosite). ForeverUI ne peut donc pas numeroter les choix comme
// camelot. Le moteur les tient pourtant : dans l'objet d'apparence pointe en
// 0xB6B1A0, aux decalages +0x28, +0x2C, +0x34, +0x24 et +0x30 (l'ordre du
// paquet de creation, 0x4E03EB-0x4E042F).
//
// CE QUE FAIT LE PATCH. CycleCharCustomization(reglage, decalage) ne rendait
// rien. Sa fin (0x4E0BB3) saute desormais vers 66 octets poses dans la place
// libre au bout de la section .text (0x9DE3B4), qui lisent l'indice du
// reglage demande et le rendent au Lua (lua_pushnumber, 0x84E2A0). Avec un
// decalage de 0 la fonction ne change rien et sert de lecture. La taille
// virtuelle de .text passe de 0x5DD3B3 a 0x5DD400 (sa taille dans le
// fichier) pour couvrir ces octets. Rien d'autre ne change.
//
// PRUDENCE. Le fichier n'est modifie que s'il est reconnu octet pour octet :
// d'origine (tous les emplacements intacts) ou deja patche. Sinon, refus.
// Une copie Wow.exe.foreverui.bak est faite avant la premiere modification.
// La restauration remet les octets d'origine.
//
// Usage : ForeverUIPatcher.exe                     fenetre
//         ForeverUIPatcher.exe --status  <Wow.exe>  etat (code 0 d'origine,
//         ForeverUIPatcher.exe --patch   <Wow.exe>  10 patche, 20 inconnu)
//         ForeverUIPatcher.exe --restore <Wow.exe>

using System;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Windows.Forms;

namespace ForeverUI
{
    enum Etat { Origine, Patche, Inconnu, Absent, Verrouille }

    static class Patch
    {
        // emplacements dans le fichier (build 12340 : .text a 0x400 dans le fichier)
        const int OFFSET_FONCTION = 0xDFF50;   // CycleCharCustomization, VA 0x4E0B50
        const int OFFSET_SITE = 0xDFFB3;       // VA 0x4E0BB3
        const int OFFSET_CAVE = 0x5DD7B4;      // VA 0x9DE3B4
        const int OFFSET_VSIZE = 0x210;        // taille virtuelle de .text

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
        static readonly byte[] VSIZE_ORIGINE = { 0xB3, 0xD3, 0x5D, 0x00 };
        static readonly byte[] VSIZE_PATCHE = { 0x00, 0xD4, 0x5D, 0x00 };

        static byte[] Hex(string s)
        {
            byte[] r = new byte[s.Length / 2];
            for (int i = 0; i < r.Length; i++)
                r[i] = Convert.ToByte(s.Substring(i * 2, 2), 16);
            return r;
        }

        static bool Egal(byte[] d, int offset, byte[] attendu)
        {
            if (offset + attendu.Length > d.Length) return false;
            for (int i = 0; i < attendu.Length; i++)
                if (d[offset + i] != attendu[i]) return false;
            return true;
        }

        static bool Nul(byte[] d, int offset, int longueur)
        {
            if (offset + longueur > d.Length) return false;
            for (int i = 0; i < longueur; i++)
                if (d[offset + i] != 0) return false;
            return true;
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
            bool origine = Egal(d, OFFSET_SITE, SITE_ORIGINE) && Nul(d, OFFSET_CAVE, CAVE_PATCHE.Length)
                && Egal(d, OFFSET_VSIZE, VSIZE_ORIGINE);
            if (origine) return Etat.Origine;
            bool patche = Egal(d, OFFSET_SITE, SITE_PATCHE) && Egal(d, OFFSET_CAVE, CAVE_PATCHE)
                && Egal(d, OFFSET_VSIZE, VSIZE_PATCHE);
            if (patche) return Etat.Patche;
            return Etat.Inconnu;
        }

        static void Ecrire(string chemin, byte[] d)
        {
            // ecriture dans un fichier voisin, puis remplacement
            string tmp = chemin + ".foreverui.tmp";
            File.WriteAllBytes(tmp, d);
            File.Copy(tmp, chemin, true);
            File.Delete(tmp);
        }

        // rend l'etat obtenu (Patche si reussi)
        public static Etat Appliquer(string chemin)
        {
            byte[] d;
            Etat e = Lire(chemin, out d);
            if (e != Etat.Origine) return e;
            string copie = chemin + ".foreverui.bak";
            if (!File.Exists(copie)) File.Copy(chemin, copie);
            Array.Copy(SITE_PATCHE, 0, d, OFFSET_SITE, SITE_PATCHE.Length);
            Array.Copy(CAVE_PATCHE, 0, d, OFFSET_CAVE, CAVE_PATCHE.Length);
            Array.Copy(VSIZE_PATCHE, 0, d, OFFSET_VSIZE, VSIZE_PATCHE.Length);
            Ecrire(chemin, d);
            return Lire(chemin, out d);
        }

        // rend l'etat obtenu (Origine si reussi)
        public static Etat Restaurer(string chemin)
        {
            byte[] d;
            Etat e = Lire(chemin, out d);
            if (e != Etat.Patche) return e;
            Array.Copy(SITE_ORIGINE, 0, d, OFFSET_SITE, SITE_ORIGINE.Length);
            for (int i = 0; i < CAVE_PATCHE.Length; i++) d[OFFSET_CAVE + i] = 0;
            Array.Copy(VSIZE_ORIGINE, 0, d, OFFSET_VSIZE, VSIZE_ORIGINE.Length);
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
            patcher.Enabled = e == Etat.Origine;
            restaurer.Enabled = e == Etat.Patche;
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
