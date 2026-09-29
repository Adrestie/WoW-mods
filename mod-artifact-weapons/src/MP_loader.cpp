/*
 * Chargeur du module mod-artifact-weapons (repris de mod-papota-spells).
 *
 * Le nom de la fonction est impose par la generation CMake : Add<dossier>Scripts,
 * les tirets du nom de dossier devenant des soulignes.
 * mod-artifact-weapons -> Addmod_artifact_weaponsScripts
 */

// From SC
void SC_AddPapotaSpellScripts();

// Add all
void Addmod_artifact_weaponsScripts()
{
    SC_AddPapotaSpellScripts();
}
