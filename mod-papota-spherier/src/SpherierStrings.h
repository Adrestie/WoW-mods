/*
 * mod-papota-spherier — identifiants des chaines de messages.
 *
 * Les textes vivent en base : module_string (anglais, defaut) et
 * module_string_locale (frFR), servis selon la locale de la session avec
 * repli sur l'anglais. Source SQL : data\sql\world\..._strings.sql — tout
 * identifiant utilise ici DOIT y exister, le coeur journalise une erreur
 * (et renvoie « error ») pour un identifiant absent.
 */

#ifndef MOD_PAPOTA_SPHERIER_STRINGS_H_
#define MOD_PAPOTA_SPHERIER_STRINGS_H_

#include "Define.h"

constexpr char SPHERIER_MODULE[] = "mod-papota-spherier";

enum SpherierStrings : uint32
{
    SPHERIER_STR_INFO_ENTETE        = 1,
    SPHERIER_STR_INFO_CLASSE        = 2,
    SPHERIER_STR_INFO_BAREME        = 3,
    SPHERIER_STR_INFO_TRANCHE       = 4,
    SPHERIER_STR_INFO_OBJETS        = 5,
    SPHERIER_STR_INFO_SOURCE        = 6,
    SPHERIER_STR_RELOAD_OK          = 7,
    SPHERIER_STR_JOUEUR_INTROUVABLE = 8,
    SPHERIER_STR_STATUS_POINTS      = 9,
    SPHERIER_STR_STATUS_ACTIFS      = 10,
    SPHERIER_STR_ETAT_ABSENT_DE     = 11,
    SPHERIER_STR_POINTS_USAGE       = 12,
    SPHERIER_STR_POINTS_CIBLE       = 13,
    SPHERIER_STR_POINTS_AIDE_ADD    = 14,
    SPHERIER_STR_POINTS_AIDE_REMOVE = 15,
    SPHERIER_STR_POINTS_AIDE_SET    = 16,
    SPHERIER_STR_POINTS_CREDITE     = 17,
    SPHERIER_STR_POINTS_DEBITE      = 18,
    SPHERIER_STR_POINTS_FIXES       = 19,
    SPHERIER_STR_ACTIVE_OK          = 20,
    SPHERIER_STR_ETAT_ABSENT_SOI    = 21,
    SPHERIER_STR_ACT_INCONNU        = 22,
    SPHERIER_STR_ACT_CLASSE         = 23,
    SPHERIER_STR_ACT_DEJA           = 24,
    SPHERIER_STR_ACT_NON_ADJACENT   = 25,
    SPHERIER_STR_ACT_INSUFFISANT    = 26,
    SPHERIER_STR_RESET_OK           = 27,
    SPHERIER_STR_SHOW_REPLI         = 28,
    SPHERIER_STR_EDITOR_REPLI       = 29,
    SPHERIER_STR_GAIN_JOUEUR        = 30,
    SPHERIER_STR_PERTE_JOUEUR       = 31,
    SPHERIER_STR_FIXE_JOUEUR        = 32,
    SPHERIER_STR_SOURCE_INCONNUE    = 33,
    SPHERIER_STR_SERTI              = 34,
    SPHERIER_STR_EPINGLE            = 35,
    SPHERIER_STR_SERT_PAS_ACTIF     = 36,
    SPHERIER_STR_SERT_OCCUPE        = 37,
    SPHERIER_STR_SERT_VIDE          = 38,
    SPHERIER_STR_SERT_MAUVAIS_TYPE  = 39,
    SPHERIER_STR_SERT_OBJET_ABSENT  = 40,
    SPHERIER_STR_STATS_ENTETE       = 41,
    SPHERIER_STR_STATS_LIGNE        = 42,
    SPHERIER_STR_STATS_VIDE         = 43,
    SPHERIER_STR_SERT_TROP_RUNES    = 44,   // trois runes identiques au plus
    // L'etabli (§9, revision du 2026-08-27) : trois recettes.
    SPHERIER_STR_ETABLI_OK          = 45,
    SPHERIER_STR_ETABLI_PAS_PIERRE  = 46,
    SPHERIER_STR_ETABLI_PAS_RUNE    = 47,
    SPHERIER_STR_ETABLI_EFFETS      = 48,   // fusion : trois fois la MEME pierre
    SPHERIER_STR_ETABLI_QUALITES    = 49,   // relance : meme qualite exigee
    SPHERIER_STR_ETABLI_QUALITE_MAX = 50,   // rien au-dessus de la derniere
    SPHERIER_STR_ETABLI_RIEN        = 51,
    SPHERIER_STR_ETABLI_ABSENT      = 52,
    SPHERIER_STR_ETABLI_SAC_PLEIN   = 53,
    SPHERIER_STR_SERT_CLASSE        = 54,   // rune de rang d'une autre classe
    SPHERIER_STR_WIPEALL_OK         = 55,   // .spherier wipeall
    SPHERIER_STR_PRISME             = 56,   // Nexus prismatique absorbe : +N %
    SPHERIER_STR_STATUS_PRISMES     = 57    // .spherier status : prismes et majoration
};

#endif
