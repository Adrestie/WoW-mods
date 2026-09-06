/*
 * Chargeur du module mod-papota-spherier.
 *
 * Le nom de la fonction est impose par la generation CMake : Add<dossier>Scripts,
 * les tirets du nom de dossier devenant des soulignes.
 * mod-papota-spherier -> Addmod_papota_spherierScripts
 */

void AddSC_spherier_scripts();
void AddSC_spherier_commands();
void AddSC_spherier_sorts();

void Addmod_papota_spherierScripts()
{
    AddSC_spherier_scripts();
    AddSC_spherier_commands();
    AddSC_spherier_sorts();
}
