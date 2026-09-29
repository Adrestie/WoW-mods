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

// ForeverUI Patcher: makes the Lua API return the index of each appearance setting and the
// names of its choices, at character creation and at the barber (client 3.3.5a, build 12340).
//
// Why: 3.3.5 Lua cannot tell which appearance choice (skin, face, hair style, hair color,
// facial hair) is applied, so ForeverUI cannot number the choices or show the current color.
// The engine stores them:
//   * at creation, in the appearance object pointed to by 0xB6B1A0, at +0x28, +0x2C, +0x34,
//     +0x24 and +0x30 (the order of the creation packet, 0x4E03EB-0x4E042F);
//   * at the barber, in the player's appearance object ([0x4038F0() + 0xB4C], active player):
//     +0x34 hair style, +0x24 hair color, +0x30 facial hair, +0x28 skin (the object advanced
//     by 0x4F0490, 0x4EB500, 0x4EBCA0 and 0x4EB150, the same routines as at creation).
//
// The patch has three pieces:
//   * Creation. CycleCharCustomization(setting, offset) returns nothing in the original client.
//     Its epilogue (0x4E0BB3) jumps to a 66-byte cave in the free space at the end of .text
//     (0x9DE3B4) that pushes the index of the requested setting (lua_pushnumber, 0x84E2A0).
//     With an offset of 0 the call changes nothing and acts as a getter. The VirtualSize of
//     .text grows from 0x5DD3B3 to 0x5DD400 (its raw size) to cover the cave.
//   * Barber. GetBarberShopStyleInfo(setting) returns name, description, cost and "is current";
//     it also returns the index of the current choice and, for the skin, the face index
//     (+0x2C), since skins depend on the face. .text has no free space left, so the second
//     half of the function (0x52E8CF-0x52E9AF, 225 bytes) is rewritten more compactly in
//     place, the first four values computed as before; its only incoming jump (0x52E8C5)
//     targets the new start.
//   * Names. GetBarberShopStyleInfo(setting, n) returns only the name of choice n
//     (BarberShopStyle.dbc, in the client language), or nil; the original returns only the
//     current one. At creation, CycleCharCustomization(setting, 0, n) returns, after the
//     index, the name of choice n (hair style, facial hair, skin), or nil. This code (253
//     bytes) does not fit in .text: it lives in a small section appended to the file (".fui",
//     0x200 bytes, executable), declared in the free space of the section table and called
//     from the barber body and the creation cave. Its calls into the game are relocated for
//     the section address, which depends on the file (after .rsrc, or after .wxl).
// Nothing else changes.
//
// Safety: the file is changed only if every piece is recognized byte for byte: original,
// patched, or patched by an earlier version (then updated). Otherwise it is refused.
// Wow.exe.foreverui.bak is written before the first change. Restore puts the original bytes
// back and removes the section, so the file is byte-identical to the original (the section
// stores the original length and SizeOfImage).
//
// Usage: ForeverUIPatcher.exe                     window
//        ForeverUIPatcher.exe --status  <Wow.exe>  state (exit code 0 original,
//        ForeverUIPatcher.exe --patch   <Wow.exe>  10 patched, 15 needs update,
//        ForeverUIPatcher.exe --restore <Wow.exe>  20 unknown)

using System;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Windows.Forms;

namespace ForeverUI
{
    enum State { Original, Patched, Partial, Unknown, Absent, Locked }

    // State of one patch piece. Old: patched by an earlier version, recognized so it can be
    // updated or restored.
    enum Piece { Original, Old, Current, Unknown }

    static class Patch
    {
        // File offsets (build 12340: .text at file offset 0x400)
        const int OFFSET_FUNCTION = 0xDFF50;   // CycleCharCustomization, VA 0x4E0B50
        const int OFFSET_SITE = 0xDFFB3;       // VA 0x4E0BB3
        const int OFFSET_CAVE = 0x5DD7B4;      // VA 0x9DE3B4
        const int OFFSET_VSIZE = 0x210;        // VirtualSize of .text
        const int OFFSET_JUMP = 0x12DCC6;      // GetBarberShopStyleInfo, rel8 of jne 0x52E8C5
        const int OFFSET_BARBER = 0x12DCCF;  // VA 0x52E8CF-0x52E9AF
        const int VA_CALL = 0x52E8D0;         // the call to the names routine, in the barber body

        // Start of CycleCharCustomization up to the site: identifies the build
        static readonly byte[] FINGERPRINT = Hex(
            "558bec83ec0c578b7d086a0157e8bed3360083c40885c074556a0257e8afd336" +
            "0083c40885c07446566a0157e8afd43600d97dfe0fb745fe0d000c00008945f8" +
            "6a0257d96df8df7df48b75f483ee01d96dfee889d43600e814ae3a005056e83d" +
            "f6ffff");

        static readonly byte[] SITE_ORIGINAL = Hex("83c4185e33c05f8be55dc3");
        static readonly byte[] SITE_PATCHED = Hex("e9fcd74f00cccccccccccc");
        static readonly byte[] CAVE_PATCHED = Hex(
            "83c41883fe04772da1a0b1b60085c074240fb68ef1e39d008b040850db0424" +
            "83ec04dd1c2457e8c1fee6ff83c40cb801000000eb0233c05e5f8be55dc3282c342430");
        // CAVE_PATCHED is V1. V2 replaces its "mov eax, 1" with a call to the creation names
        // routine (at +46, rel32 at +47, relocated for the section address).
        const int CAVE_CALL = 46;
        const int VA_CAVE = 0x9DE3B4;
        static readonly byte[] VSIZE_ORIGINAL = { 0xB3, 0xD3, 0x5D, 0x00 };
        static readonly byte[] VSIZE_PATCHED = { 0x00, 0xD4, 0x5D, 0x00 };

        // Barber: jne 0x52E913 becomes jne 0x52E8CF
        static readonly byte[] JUMP_ORIGINAL = { 0x4C };
        static readonly byte[] JUMP_PATCHED = { 0x08 };
        static readonly byte[] BARBER_ORIGINAL = Hex(
            "83fb01753f56e8a6f9310056e8a0f93100e80b50edff05d00000008b008b80c0" +
            "0000006a0083c0ff506a00e891802c00d80d4c81a00083c414d95df8d945f8db" +
            "5dfceb4c5753e876fbffff8bf88b4f085156e82afa31008b570c5256e820fa31" +
            "00e8bb4fedff05d00000008b008b80c00000006a0083c0ff506a00e841802c00" +
            "d84f1083c420d95df8d945f8db5dfc5f8b45fc5056e867f9310053e821feffff" +
            "83c40c84c0741cd9e883ec08dd1c2456e81cf9310083c40c5bb8040000005e8b" +
            "e55dc356e8e8f8310083c4045bb8040000005e8be55dc3cccccccccccccccccc" +
            "cc");
        // V1, without the names: recognized so it can be updated
        static readonly byte[] BARBER_V1 = Hex(
            "5783fb01751356e8a5f9310056e89ff93100bf3c81a000eb1a53e8a2fbffff89" +
            "c7ff770856e857fa3100ff770c56e84efa31008d65e8e8e64fedff8b80d00000" +
            "008b80c00000006a0048506a00e86f802c00d84f10d95df8d945f8db5dfcff75" +
            "fc56e89af9310053e854feffff8d65e884c07409d9e8e84a000000eb0656e82e" +
            "f931006a045fe8964fedff85c0742a8b804c0b000085c074200fb68ba4e95200" +
            "50db0408e81c000000475883fb037509db402ce80d0000004789f88d65e85f5b" +
            "5e89ec5dc383ec08dd1c2456e800f9310083c40cc334243028cccccccccccccc" +
            "cc");
        // V2. ebx = setting - 1, esi = Lua state, [ebp-0x18] = edi saved here:
        //   push edi / call NAMES (rel32 at +2, relocated for the section) /
        //   cmp ebx, 1 / jne styles
        //   (color) pushnil x2 / edi = 0xA0813C (its cost factor at +0x10) / jmp cost
        //   styles:  record 0x52E490(ebx) in edi / pushstring [edi+8], [edi+0xC]
        //   cost:    lea esp, [ebp-0x18] / active player level - 1 /
        //            0x7F6990(0, level - 1, 0) * [edi+0x10] / pushinteger
        //   current: 0x52E790(ebx) ? pushnumber 1 : pushnil
        //   index:   edi = 4 / appearance object = [0x4038F0() + 0xB4C]; if present,
        //            pushnumber [object + table[ebx]] and edi = 5; for the skin (ebx = 3),
        //            also the face [object + 0x2C] and edi = 6 (skins depend on the face)
        //   end:     eax = edi, registers restored / pushfp: st0 -> pushnumber
        //   table:   34 24 30 28
        static readonly byte[] BARBER_V2 = Hex(
            "57e80000000083fb01751356e8a0f9310056e89af93100bf3c81a000eb1a53e8" +
            "9dfbffff89c7ff770856e852fa3100ff770c56e849fa31008d65e8e8e14fedff" +
            "8b80d00000008b80c00000006a0048506a00e86a802c00d84f10d95df8d945f8" +
            "db5dfcff75fc56e895f9310053e84ffeffff8d65e884c07409d9e8e84a000000" +
            "eb0656e829f931006a045fe8914fedff85c0742a8b804c0b000085c074200fb6" +
            "8ba9e9520050db0408e81c000000475883fb037509db402ce80d0000004789f8" +
            "8d65e85f5b5e89ec5dc383ec08dd1c2456e8fbf8310083c40cc334243028cccc" +
            "cc");

        // Added section (the names): last in the section table, data at the end of the file.
        // A 12-byte header ("FUIN", original file length, original SizeOfImage, so it can be
        // removed byte for byte), then the code.
        static readonly byte[] SECTION_NAME = { 0x2E, 0x66, 0x75, 0x69, 0, 0, 0, 0 };  // ".fui"
        static readonly byte[] MAGIC = { 0x46, 0x55, 0x49, 0x4E };                   // "FUIN"
        const int SECTION_HEADER = 12;
        const int SECTION_SIZE = 0x200;
        const uint CHARACTERISTICS = 0x60000020;  // code, execute, read
        // Section code, two routines:
        //   * +0, barber names, called right after "push edi". Without a second argument it
        //     returns to the body. With a number n it calls 0x52F760(setting - 1, race, sex, n)
        //     (the barber lookup run after each step) and pushes only the record name
        //     (pushstring [record + 8]), or nil, then ends the function with 1 value.
        //     Race and sex: [active player + 0xD0] + 0x44 / + 0x46.
        //   * +CREATE_NAMES_OFFSET, creation names, called in place of the cave's "mov eax, 1"
        //     (index already pushed). Without a third argument, eax = 1. With a number n, it
        //     finds the BarberShopStyle row (count at 0xAD3238, 0x20-byte rows at [0xAD324C]:
        //     +4 type, +8 name, +0x14 race, +0x18 sex or -1, +0x1C number) of the setting's
        //     type (skin 3, hair style 0, facial hair 2) for the race (+0x18) and sex (+0x1C)
        //     of the appearance object [0xB6B1A0], and pushes its name, or nil; eax = 2.
        //     The barber index does not exist on the creation screen, so the table is scanned.
        static readonly byte[] CODE_SECTION = Hex(
            "6a0256e80000000083c40885c07501c36a0256e800000000db5dfce800000000" +
            "8b80d0000000ff75fc0fb64846510fb648445153e80000000085c0740e8b4008" +
            "ff700856e800000000eb0656e800000000b8010000008d65e85f5b5e89ec5dc3" +
            "6a0357e80000000083c40885c0750240c35356bb0300000085f6741131db83fe" +
            "02740ab30283fe04740383cbff6a0357e80000000083c40850db1c248b0da0b1" +
            "b60085c97443a14c32ad008b153832ad004a78358b7118397014751a39580475" +
            "158b701883feff74053b711c75088b342439701c740583c020ebd6ff700857e8" +
            "0000000083c408eb0957e80000000083c40483c4045e5bb802000000c3");
        // Calls into the game, as (rel32 offset, target) pairs. Barber names: isnumber,
        // tonumber, active player, lookup, pushstring, pushnil; creation names: isnumber,
        // tonumber, pushstring, pushnil.
        static readonly int[] RELOCS = { 4, 0x84DF20, 20, 0x84E030, 28, 0x4038F0, 53, 0x52F760, 69, 0x84E350, 77, 0x84E280, 100, 0x84DF20, 145, 0x84E030, 224, 0x84E350, 235, 0x84E280 };
        const int CREATE_NAMES_OFFSET = 96;
        // V1 section code: barber names only, the rest zero
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

        static bool Matches(byte[] d, int offset, byte[] expected)
        {
            if (offset < 0 || offset + expected.Length > d.Length) return false;
            for (int i = 0; i < expected.Length; i++)
                if (d[offset + i] != expected[i]) return false;
            return true;
        }

        static bool AllZero(byte[] d, int offset, int length)
        {
            if (offset < 0 || offset + length > d.Length) return false;
            for (int i = 0; i < length; i++)
                if (d[offset + i] != 0) return false;
            return true;
        }

        // Little-endian int32 read (I32) and write (E32) at offset o; Align rounds v up to a
        // multiple of a.
        static int I32(byte[] d, int o) { return BitConverter.ToInt32(d, o); }
        static void E32(byte[] d, int o, int v) { Array.Copy(BitConverter.GetBytes(v), 0, d, o, 4); }
        static int Align(int v, int a) { return (v + a - 1) / a * a; }

        // PE header fields used here. Pe: offset of the PE signature; Table: offset of the
        // section table.
        struct Header
        {
            public int Pe, Sections, Table, Base, SectionAlignment, FileAlignment, SizeOfImage, SizeOfHeaders;
        }

        // False if d is not a PE image or its section table does not fit in the headers.
        static bool ReadHeader(byte[] d, out Header h)
        {
            h = new Header();
            h.Pe = I32(d, 0x3C);
            if (h.Pe <= 0 || h.Pe + 0x100 > d.Length || I32(d, h.Pe) != 0x4550) return false;
            h.Sections = BitConverter.ToUInt16(d, h.Pe + 6);
            h.Table = h.Pe + 24 + BitConverter.ToUInt16(d, h.Pe + 20);
            h.Base = I32(d, h.Pe + 24 + 28);
            h.SectionAlignment = I32(d, h.Pe + 24 + 32);
            h.FileAlignment = I32(d, h.Pe + 24 + 36);
            h.SizeOfImage = I32(d, h.Pe + 24 + 56);
            h.SizeOfHeaders = I32(d, h.Pe + 24 + 60);
            return h.Sections > 0 && h.SectionAlignment > 0 && h.FileAlignment > 0 && h.Table + h.Sections * 40 <= h.SizeOfHeaders;
        }

        // Section code with its calls into the game relocated for address va.
        // template: CODE_SECTION or CODE_SECTION_V1
        static byte[] CodeSection(int va, byte[] template)
        {
            byte[] c = (byte[])template.Clone();
            for (int i = 0; i < RELOCS.Length; i += 2)
                if (RELOCS[i] + 4 <= c.Length)
                    E32(c, RELOCS[i], RELOCS[i + 1] - (va + RELOCS[i] + 4));
            return c;
        }

        // State of the added section, Original if absent. When recognized, va: address of its
        // code; raw: file offset of its data.
        static Piece Section(byte[] d, out int va, out int raw)
        {
            va = 0;
            raw = 0;
            Header h;
            if (!ReadHeader(d, out h)) return Piece.Unknown;
            int t = h.Table + (h.Sections - 1) * 40;
            if (!Matches(d, t, SECTION_NAME)) return Piece.Original;
            int rva = I32(d, t + 12), size = I32(d, t + 16);
            raw = I32(d, t + 20);
            if (size != SECTION_SIZE || raw + size != d.Length || !Matches(d, raw, MAGIC)
                || (uint)I32(d, t + 36) != CHARACTERISTICS)
                return Piece.Unknown;
            va = h.Base + rva + SECTION_HEADER;
            int code = raw + SECTION_HEADER, rest = SECTION_SIZE - SECTION_HEADER;
            if (Matches(d, code, CodeSection(va, CODE_SECTION))
                && AllZero(d, code + CODE_SECTION.Length, rest - CODE_SECTION.Length))
                return Piece.Current;
            if (Matches(d, code, CodeSection(va, CODE_SECTION_V1))
                && AllZero(d, code + CODE_SECTION_V1.Length, rest - CODE_SECTION_V1.Length))
                return Piece.Old;
            return Piece.Unknown;
        }

        static Piece Section(byte[] d)
        {
            int va, raw;
            return Section(d, out va, out raw);
        }

        // Address of the recognized section's code, 0 otherwise
        static int SectionVa(byte[] d)
        {
            int va, raw;
            Piece p = Section(d, out va, out raw);
            return (p == Piece.Current || p == Piece.Old) ? va : 0;
        }

        // V2 creation cave. sectionVa: address of the section code
        static byte[] CaveV2(int sectionVa)
        {
            byte[] c = (byte[])CAVE_PATCHED.Clone();
            c[CAVE_CALL] = 0xE8;
            E32(c, CAVE_CALL + 1, sectionVa + CREATE_NAMES_OFFSET - (VA_CAVE + CAVE_CALL + 5));
            return c;
        }

        // V2 barber body. namesVa: address of the barber names routine (start of the section code)
        static byte[] BarberV2(int namesVa)
        {
            byte[] c = (byte[])BARBER_V2.Clone();
            E32(c, 2, namesVa - (VA_CALL + 5));
            return c;
        }

        // State of the creation piece: site, cave and .text VirtualSize
        static Piece Creation(byte[] d)
        {
            if (Matches(d, OFFSET_SITE, SITE_ORIGINAL) && AllZero(d, OFFSET_CAVE, CAVE_PATCHED.Length)
                && Matches(d, OFFSET_VSIZE, VSIZE_ORIGINAL))
                return Piece.Original;
            if (!Matches(d, OFFSET_SITE, SITE_PATCHED) || !Matches(d, OFFSET_VSIZE, VSIZE_PATCHED))
                return Piece.Unknown;
            if (Matches(d, OFFSET_CAVE, CAVE_PATCHED))
                return Piece.Old;
            int va = SectionVa(d);
            if (va > 0 && Matches(d, OFFSET_CAVE, CaveV2(va)))
                return Piece.Current;
            return Piece.Unknown;
        }

        // State of the barber piece: incoming jump and function body
        static Piece Barber(byte[] d)
        {
            if (Matches(d, OFFSET_JUMP, JUMP_ORIGINAL) && Matches(d, OFFSET_BARBER, BARBER_ORIGINAL))
                return Piece.Original;
            if (!Matches(d, OFFSET_JUMP, JUMP_PATCHED))
                return Piece.Unknown;
            if (Matches(d, OFFSET_BARBER, BARBER_V1))
                return Piece.Old;
            int va = SectionVa(d);
            if (va > 0 && Matches(d, OFFSET_BARBER, BarberV2(va)))
                return Piece.Current;
            return Piece.Unknown;
        }

        // Overall state of the file. d: its contents, null if it cannot be read
        public static State Read(string path, out byte[] d)
        {
            d = null;
            if (!File.Exists(path)) return State.Absent;
            try { d = File.ReadAllBytes(path); }
            catch (IOException) { return State.Locked; }
            catch (UnauthorizedAccessException) { return State.Locked; }
            if (d.Length < OFFSET_CAVE + CAVE_PATCHED.Length || d[0] != 'M' || d[1] != 'Z')
                return State.Unknown;
            if (!Matches(d, OFFSET_FUNCTION, FINGERPRINT))
                return State.Unknown;
            Piece creation = Creation(d), barber = Barber(d), section = Section(d);
            if (creation == Piece.Unknown || barber == Piece.Unknown || section == Piece.Unknown)
                return State.Unknown;
            if (creation == Piece.Original && barber == Piece.Original && section == Piece.Original)
                return State.Original;
            if (creation == Piece.Current && barber == Piece.Current && section == Piece.Current)
                return State.Patched;
            return State.Partial;
        }

        // The file with the names section appended; null if the header has no room to declare it
        static byte[] AddSection(byte[] d)
        {
            Header h;
            if (!ReadHeader(d, out h)) return null;
            int t = h.Table + h.Sections * 40;
            if (t + 40 > h.SizeOfHeaders || !AllZero(d, t, 40) || h.SizeOfImage % h.SectionAlignment != 0)
                return null;
            int raw = Align(d.Length, h.FileAlignment);
            int rva = h.SizeOfImage;
            byte[] r = new byte[raw + SECTION_SIZE];
            Array.Copy(d, r, d.Length);
            Array.Copy(SECTION_NAME, 0, r, t, SECTION_NAME.Length);
            E32(r, t + 8, SECTION_SIZE);
            E32(r, t + 12, rva);
            E32(r, t + 16, SECTION_SIZE);
            E32(r, t + 20, raw);
            E32(r, t + 36, unchecked((int)CHARACTERISTICS));
            r[h.Pe + 6] = (byte)(h.Sections + 1);
            r[h.Pe + 7] = (byte)((h.Sections + 1) >> 8);
            E32(r, h.Pe + 24 + 56, rva + Align(SECTION_SIZE, h.SectionAlignment));
            Array.Copy(MAGIC, 0, r, raw, MAGIC.Length);
            E32(r, raw + 4, d.Length);
            E32(r, raw + 8, h.SizeOfImage);
            byte[] code = CodeSection(h.Base + rva + SECTION_HEADER, CODE_SECTION);
            Array.Copy(code, 0, r, raw + SECTION_HEADER, code.Length);
            return r;
        }

        // The file as it was before AddSection: original length and header values, read from
        // the section
        static byte[] RemoveSection(byte[] d)
        {
            Header h;
            if (!ReadHeader(d, out h)) return null;
            int t = h.Table + (h.Sections - 1) * 40;
            int raw = I32(d, t + 20);
            int length = I32(d, raw + 4), image = I32(d, raw + 8);
            if (length <= 0 || length > raw || image <= 0) return null;
            byte[] r = new byte[length];
            Array.Copy(d, r, length);
            for (int i = 0; i < 40; i++) r[t + i] = 0;
            r[h.Pe + 6] = (byte)(h.Sections - 1);
            r[h.Pe + 7] = (byte)((h.Sections - 1) >> 8);
            E32(r, h.Pe + 24 + 56, image);
            return r;
        }

        static void Write(string path, byte[] d)
        {
            // Write a sibling file, then copy it over the original
            string tmp = path + ".foreverui.tmp";
            File.WriteAllBytes(tmp, d);
            File.Copy(tmp, path, true);
            File.Delete(tmp);
        }

        // Returns the resulting state (Patched on success). Current pieces are left as they
        // are; Old pieces are updated.
        public static State Apply(string path)
        {
            byte[] d;
            State e = Read(path, out d);
            if (e != State.Original && e != State.Partial) return e;
            // Read the piece states before touching the section: the creation and barber
            // versions depend on it.
            Piece creation = Creation(d), barber = Barber(d);
            int va, raw;
            Piece section = Section(d, out va, out raw);
            if (section == Piece.Original)
            {
                d = AddSection(d);
                if (d == null) return State.Unknown;
            }
            else if (section == Piece.Old)
            {
                byte[] code = CodeSection(va, CODE_SECTION);
                Array.Copy(code, 0, d, raw + SECTION_HEADER, code.Length);
            }
            string copy = path + ".foreverui.bak";
            if (!File.Exists(copy)) File.Copy(path, copy);
            va = SectionVa(d);
            if (creation == Piece.Original || creation == Piece.Old)
            {
                Array.Copy(SITE_PATCHED, 0, d, OFFSET_SITE, SITE_PATCHED.Length);
                Array.Copy(CaveV2(va), 0, d, OFFSET_CAVE, CAVE_PATCHED.Length);
                Array.Copy(VSIZE_PATCHED, 0, d, OFFSET_VSIZE, VSIZE_PATCHED.Length);
            }
            if (barber == Piece.Original || barber == Piece.Old)
            {
                Array.Copy(JUMP_PATCHED, 0, d, OFFSET_JUMP, JUMP_PATCHED.Length);
                Array.Copy(BarberV2(va), 0, d, OFFSET_BARBER, BARBER_V2.Length);
            }
            Write(path, d);
            return Read(path, out d);
        }

        // Returns the resulting state (Original on success)
        public static State Restore(string path)
        {
            byte[] d;
            State e = Read(path, out d);
            if (e != State.Patched && e != State.Partial) return e;
            Piece creation = Creation(d), barber = Barber(d), section = Section(d);
            if (creation == Piece.Current || creation == Piece.Old)
            {
                Array.Copy(SITE_ORIGINAL, 0, d, OFFSET_SITE, SITE_ORIGINAL.Length);
                for (int i = 0; i < CAVE_PATCHED.Length; i++) d[OFFSET_CAVE + i] = 0;
                Array.Copy(VSIZE_ORIGINAL, 0, d, OFFSET_VSIZE, VSIZE_ORIGINAL.Length);
            }
            if (barber == Piece.Current || barber == Piece.Old)
            {
                Array.Copy(JUMP_ORIGINAL, 0, d, OFFSET_JUMP, JUMP_ORIGINAL.Length);
                Array.Copy(BARBER_ORIGINAL, 0, d, OFFSET_BARBER, BARBER_ORIGINAL.Length);
            }
            if (section == Piece.Current || section == Piece.Old)
            {
                d = RemoveSection(d);
                if (d == null) return State.Unknown;
            }
            Write(path, d);
            return Read(path, out d);
        }
    }

    static class Texts
    {
        static readonly bool FR = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "fr";
        // The French text on a French UI culture, the English one otherwise
        public static string T(string fr, string en) { return FR ? fr : en; }

        public static string State(State e)
        {
            switch (e)
            {
                case ForeverUI.State.Original: return T("Client d'origine : prêt à être patché.", "Original client: ready to be patched.");
                case ForeverUI.State.Patched: return T("Client patché : ForeverUI numérote les choix d'apparence.", "Patched client: ForeverUI numbers the appearance choices.");
                case ForeverUI.State.Partial: return T("Client patché par une version précédente : patchez pour le mettre à jour.", "Client patched by an earlier version: patch it to update.");
                case ForeverUI.State.Absent: return T("Wow.exe introuvable à cet emplacement.", "Wow.exe not found at this location.");
                case ForeverUI.State.Locked: return T("Wow.exe est ouvert ou protégé : fermez le jeu.", "Wow.exe is open or protected: close the game.");
                default: return T("Wow.exe non reconnu (build 12340 attendu) : aucune modification.", "Wow.exe not recognized (build 12340 expected): nothing changed.");
            }
        }
    }

    class Window : Form
    {
        readonly TextBox path = new TextBox();
        readonly Label state = new Label();
        readonly Button patchButton = new Button();
        readonly Button restoreButton = new Button();

        public Window()
        {
            Text = "ForeverUI Patcher";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            ClientSize = new Size(560, 150);
            StartPosition = FormStartPosition.CenterScreen;

            var label = new Label { Text = "Wow.exe", Location = new Point(12, 16), AutoSize = true };
            path.Location = new Point(80, 12);
            path.Width = 380;
            path.Text = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Wow.exe");
            path.TextChanged += delegate { UpdateStatus(); };
            var browse = new Button { Text = Texts.T("Parcourir...", "Browse..."), Location = new Point(470, 10), Width = 78 };
            browse.Click += delegate
            {
                using (var d = new OpenFileDialog { Filter = "Wow.exe|Wow.exe|*.exe|*.exe", FileName = "Wow.exe" })
                    if (d.ShowDialog(this) == DialogResult.OK) path.Text = d.FileName;
            };
            state.Location = new Point(12, 50);
            state.Size = new Size(536, 40);
            patchButton.Text = Texts.T("Patcher", "Patch");
            patchButton.Location = new Point(352, 108);
            patchButton.Width = 95;
            patchButton.Click += delegate { ReportResult(Patch.Apply(path.Text), ForeverUI.State.Patched); };
            restoreButton.Text = Texts.T("Restaurer", "Restore");
            restoreButton.Location = new Point(453, 108);
            restoreButton.Width = 95;
            restoreButton.Click += delegate { ReportResult(Patch.Restore(path.Text), ForeverUI.State.Original); };
            Controls.AddRange(new Control[] { label, path, browse, state, patchButton, restoreButton });
            UpdateStatus();
        }

        // Refreshes the status; warns if the operation ended in another state than wanted
        void ReportResult(State obtained, State wanted)
        {
            UpdateStatus();
            if (obtained != wanted)
                MessageBox.Show(this, Texts.State(obtained), Text, MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }

        void UpdateStatus()
        {
            byte[] d;
            State e = Patch.Read(path.Text, out d);
            state.Text = Texts.State(e);
            patchButton.Enabled = e == State.Original || e == State.Partial;
            restoreButton.Enabled = e == State.Patched || e == State.Partial;
        }
    }

    static class Program
    {
        // Process exit code for a state (see Usage)
        static int Code(State e)
        {
            switch (e)
            {
                case State.Original: return 0;
                case State.Patched: return 10;
                case State.Partial: return 15;
                default: return 20;
            }
        }

        [STAThread]
        static int Main(string[] args)
        {
            if (args.Length == 2)
            {
                byte[] d;
                State e;
                if (args[0] == "--patch") e = Patch.Apply(args[1]);
                else if (args[0] == "--restore") e = Patch.Restore(args[1]);
                else e = Patch.Read(args[1], out d);
                Console.WriteLine(e);
                return Code(e);
            }
            Application.EnableVisualStyles();
            Application.Run(new Window());
            return 0;
        }
    }
}
