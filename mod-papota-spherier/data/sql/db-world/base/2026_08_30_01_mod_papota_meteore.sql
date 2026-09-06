-- mod-papota-spherier : NETTOYAGE du retroport du Meteore (8600072).
--
-- Le retroport (trois creatures habillees des modeles exportes, orchestrees
-- par scripts — 2026-08-30/31) a ete RETIRE le 2026-08-31 : le sort est
-- revenu a sa forme DBC d'origine (zone + brulure, visuel emprunte 2253).
-- Ce fichier ne fait plus que supprimer ce que sa version precedente posait.
-- Les habillages 802104-06 restent dormants dans les DBC.

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (803807, 803808, 803809);
DELETE FROM `creature_template` WHERE `entry` IN (803807, 803808, 803809);
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (802104, 802105, 802106);
