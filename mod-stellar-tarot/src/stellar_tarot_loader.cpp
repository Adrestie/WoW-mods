/*
 * This file is part of mod-stellar-tarot.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * mod-stellar-tarot script loader.
 *
 * The function name is imposed by the CMake generation: Add<directory>Scripts,
 * with the dashes of the directory name turned into underscores.
 * mod-stellar-tarot -> Addmod_stellar_tarotScripts
 */

void AddSC_stellar_tarot_scripts();
void AddSC_stellar_tarot_commands();
// LE PROC DU COEUR : l'AuraScript qui previent la ligne quand son aura part.
void AddSC_stellar_tarot_proc();
// LE GARDIEN qu'une carte fait venir : sanglier ou double.
void AddSC_stellar_tarot_guardian();

void Addmod_stellar_tarotScripts()
{
    AddSC_stellar_tarot_scripts();
    AddSC_stellar_tarot_commands();
    AddSC_stellar_tarot_proc();
    AddSC_stellar_tarot_guardian();
}
