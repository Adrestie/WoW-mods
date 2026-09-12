-- mod-stellar-tarot — the workbench, an object SHARED with the other modules
-- of the repository that have recipes (mod-spheregrid among them).
--
-- One template, the same in every module, inserted ONLY WHEN ABSENT: whoever
-- installs first puts it down, and nobody rewrites it. Where it stands in the
-- world is placed by hand, as a game master: `.gobject add 803700`.
--
-- NO DELETE HERE, on purpose: the module's remover replays the deletes of its
-- SQL, and this object must outlive the module when another provider still
-- uses it. The remover takes it out itself, when it is the last one to go.

INSERT IGNORE INTO `gameobject_template`
  (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`,
   `size`, `Data0`, `Data1`, `Data2`, `Data3`, `ScriptName`) VALUES
(803700, 3, 8176, 'Workbench', '', '', '', 1.6, 0, 0, 0, 0, '');

INSERT IGNORE INTO `gameobject_template_locale` (`entry`, `locale`, `name`, `castBarCaption`) VALUES
(803700, 'frFR', 'Établi', '');
