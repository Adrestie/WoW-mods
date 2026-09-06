@echo off
rem ===========================================================================
rem  exporte_grilles.bat - les dix grilles XML de l'editeur -> UN seul SQL
rem
rem  Chaque classe passe par importe_layout.lua, qui relit son XML, le CONTROLE
rem  (c'est le Verify de l'editeur, pas un controle a part) et emet son bloc
rem  DELETE + INSERT. Les dix blocs sont ensuite concatenes.
rem
rem  UNE CLASSE EN DEFAUT ARRETE TOUT. Un fichier a moitie ecrit appliquerait
rem  des grilles depareillees, et le defaut se lirait en base au lieu de se
rem  lire dans l'editeur. Corriger la disposition, puis relancer.
rem
rem    exporte_grilles.bat [sortie.sql]           les dix grilles de classe
rem    exporte_grilles.bat commune [sortie.sql]   la GRILLE COMMUNE seule
rem
rem  En mode commune, le SQL efface les dix grilles de classe et pose la grille
rem  0 avec ses dix departs : le module retombe sur elle pour toute classe qui
rem  n'a plus de grille propre.
rem
rem  Le fichier produit s'applique a la main sur la base world, puis
rem  .spherier reload en jeu.
rem ===========================================================================
setlocal

set "SERVEUR=D:\Serveur WoW\server_hard\bin\RelWithDebInfo"
set "LUA=D:\Serveur WoW\server_hard\modules\mod-ale\src\lualib\lua\RelWithDebInfo\lua52_interpreter.exe"
set "OUTIL=D:\Serveur WoW\outils_spherier\importe_layout.lua"

set "MODE=%~1"
set "SORTIE=%~2"
if /i not "%MODE%"=="commune" (
    set "SORTIE=%~1"
    set "MODE=classes"
)
if "%SORTIE%"=="" set "SORTIE=D:\Serveur WoW\outils_spherier\sql\spherier_grilles.sql"

rem Les dix classes de WotLK : nom de la disposition dans l'editeur, puis
rem class_id du client. Le 10 n'existe pas - le druide porte le 11.
rem En mode commune, une seule disposition, sous la classe 0.
set "CLASSES=warrior:1 paladin:2 hunter:3 rogue:4 priest:5 deathknight:6 shaman:7 mage:8 warlock:9 druid:11"
if /i "%MODE%"=="commune" set "CLASSES=commune:0"

if not exist "%LUA%" (
    echo ECHEC : interpreteur introuvable.
    echo   "%LUA%"
    exit /b 1
)
if not exist "%OUTIL%" (
    echo ECHEC : importe_layout.lua introuvable.
    echo   "%OUTIL%"
    exit /b 1
)

set "MORCEAUX=%TEMP%\spherier_grilles"
if exist "%MORCEAUX%" rd /s /q "%MORCEAUX%"
mkdir "%MORCEAUX%"
if errorlevel 1 exit /b 1

rem LE REPERTOIRE DE TRAVAIL EST bin\RelWithDebInfo : importe_layout.lua y
rem charge Spherier_Server.lua par un chemin relatif, il ne tourne pas ailleurs.
pushd "%SERVEUR%"
if errorlevel 1 (
    echo ECHEC : repertoire serveur introuvable.
    echo   "%SERVEUR%"
    exit /b 1
)

for %%C in (%CLASSES%) do (
    for /f "tokens=1,2 delims=:" %%N in ("%%C") do (
        echo.
        echo --- %%N ^(class_id %%O^)
        rem Le 3e argument vide laisse le point de depart au marquage du XML.
        "%LUA%" "%OUTIL%" %%N %%O "" "%MORCEAUX%\%%O.sql"
        if errorlevel 1 (
            echo.
            echo ECHEC sur %%N. "%SORTIE%" n'a pas ete touche.
            popd
            exit /b 1
        )
    )
)

popd

rem Assemblage : l'en-tete, puis les dix blocs dans l'ordre des class_id.
rem
rem TOUT OU RIEN. Les quatre tables papota_sphere_* sont en InnoDB, la
rem transaction porte donc vraiment - en MyISAM elle n'aurait rien fait et la
rem promesse aurait ete fausse. Applique par "mysql < fichier", le client
rem s'arrete a la premiere erreur et rend la main SANS avoir atteint le COMMIT :
rem la connexion se ferme, InnoDB annule tout. Aucune classe a moitie ecrite,
rem aucune classe effacee sans etre remplacee.
rem
rem A ne pas casser : n'introduire ici AUCUN ordre DDL (CREATE, ALTER, TRUNCATE).
rem MySQL valide implicitement avant de l'executer, ce qui couperait la
rem transaction en deux sans le dire.
> "%SORTIE%" echo -- Grilles du spherier : les dix classes, en un seul fichier.
>>"%SORTIE%" echo -- Genere par exporte_grilles.bat le %DATE% a %TIME%
>>"%SORTIE%" echo -- REGENERABLE : chaque bloc efface sa classe avant de la reecrire.
>>"%SORTIE%" echo -- TOUT OU RIEN : les dix blocs sont encadres par une transaction.
>>"%SORTIE%" echo.
>>"%SORTIE%" echo START TRANSACTION;
>>"%SORTIE%" echo.

for %%C in (%CLASSES%) do (
    for /f "tokens=1,2 delims=:" %%N in ("%%C") do (
        type "%MORCEAUX%\%%O.sql" >> "%SORTIE%"
        >>"%SORTIE%" echo.
    )
)

>>"%SORTIE%" echo COMMIT;

rd /s /q "%MORCEAUX%"

echo.
echo SQL unique ecrit : "%SORTIE%"
endlocal
