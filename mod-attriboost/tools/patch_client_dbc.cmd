@echo off
rem ---------------------------------------------------------------------------
rem  mod-attriboost - patch des DBC du client
rem
rem  Ajoute les 10 sorts et les 2 objets du module dans un Spell.dbc et un
rem  Item.dbc extraits du client, puis ecrit le resultat dans un dossier pret a
rem  empaqueter en MPQ. Les fichiers d'entree ne sont jamais modifies.
rem
rem  Usage :
rem     patch_client_dbc.cmd <dossier_source> [dossier_sortie]
rem     patch_client_dbc.cmd                  (demande les chemins)
rem
rem  Le serveur n'a pas besoin de ce patch : il lit les memes lignes depuis la
rem  table spell_dbc et la table item_dbc, remplies par 01_attriboost_dbc.sql.
rem
rem  Ce fichier doit rester en ASCII pur avec des fins de ligne Windows : cmd.exe
rem  ne lit pas l'UTF-8 et casse sur des fins de ligne Unix.
rem ---------------------------------------------------------------------------
setlocal
cd /d "%~dp0"

set PY=
where py >nul 2>&1 && set PY=py -3
if not defined PY where python >nul 2>&1 && set PY=python

if not defined PY (
    echo.
    echo ECHEC : Python 3 est introuvable.
    echo.
    echo Ce script a besoin de Python 3, sans aucune bibliotheque supplementaire.
    echo Installez-le depuis https://www.python.org/downloads/ en cochant
    echo "Add python.exe to PATH", puis relancez ce fichier.
    echo.
    pause
    exit /b 1
)

if not exist "attriboost_dbc.json" (
    echo.
    echo ECHEC : attriboost_dbc.json est absent de ce dossier.
    echo Lancez ce script depuis le dossier tools du module.
    echo.
    pause
    exit /b 1
)

%PY% "patch_client_dbc.py" %*
set CODE=%ERRORLEVEL%

echo.
if "%CODE%"=="0" (
    echo Patch termine sans erreur.
) else (
    echo Patch INTERROMPU : voir le message ci-dessus.
)
echo.
rem Pause seulement en double-clic ; en ligne de commande, on rend la main.
echo %CMDCMDLINE% | find /i "/c" > nul && pause
exit /b %CODE%
