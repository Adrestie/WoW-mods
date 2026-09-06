-- mod-papota-spherier : le totem 803803 n'est plus le Totem de maree de
-- soins mais le Totem de lien d'esprit (refonte du sort 8600063).
--
-- Un fichier A PART, et un simple UPDATE : le SQL d'origine
-- (2026_08_27_04_mod_papota_invocations.sql) cree la creature par un
-- INSERT sans suppression prealable, donc le rejouer casse sur un
-- doublon de cle. On ne le touche plus.
UPDATE `creature_template` SET `name` = 'Totem de lien d''esprit'
WHERE `entry` = 803803;
