-- mod-spheregrid — The creature displays and models, for the SERVER.
--
-- The module's creatures wear displays the game does not know. The client
-- learns them from `patch-Z.MPQ`; the server learns them here, and without
-- these rows it refuses every `creature_model_info` that names one -- which is
-- what tells it a creature's size and reach.
--
-- Generated from the module's own DBC files, the same the client receives.
--
-- Regenerable: each range is deleted before it is written again.

DELETE FROM `creaturedisplayinfo_dbc` WHERE `ID` BETWEEN 802501 AND 802558;
INSERT INTO `creaturedisplayinfo_dbc` (`ID`, `ModelID`, `SoundID`, `ExtendedDisplayInfoID`, `CreatureModelScale`, `CreatureModelAlpha`, `TextureVariation_1`, `TextureVariation_2`, `TextureVariation_3`, `PortraitTextureName`, `BloodLevel`, `BloodID`, `NPCSoundID`, `ParticleColorID`, `CreatureGeosetData`, `ObjectEffectPackageID`) VALUES
(802501, 802501, 0, 0, 1, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
(802502, 1731, 0, 0, 1, 0, '', '', '', '', 0, 0, 0, 0, 0, 0),
(802503, 802503, 0, 0, 1, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
(802504, 802504, 0, 0, 1, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
(802505, 802505, 0, 0, 1, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
(802506, 802506, 0, 0, 1, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
(802507, 802507, 0, 0, 1, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
(802508, 802508, 0, 0, 1, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
(802509, 802509, 0, 0, 1, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
(802510, 802510, 0, 0, 1, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
(802511, 802511, 0, 0, 1, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
(802512, 802512, 0, 0, 1, 255, 'NorthrendGhoul01', '', '', '', 0, 0, 316, 0, 0, 0),
(802513, 802512, 0, 0, 1, 255, 'NorthrendGhoul02', '', '', '', 0, 0, 316, 0, 0, 0),
(802514, 802512, 0, 0, 1, 255, 'NorthrendGhoul03', '', '', '', 0, 0, 316, 0, 0, 0),
(802515, 802512, 0, 0, 1, 255, 'NorthrendGhoul04', '', '', '', 0, 0, 316, 0, 0, 0),
(802520, 802520, 0, 0, 1, 255, 'shamanascendant_energetic_6118992', 'shamanascendant_energetic_6118990', 'shamanascendant_energetic_6118991', '', 0, 0, 0, 0, 0, 0),
(802521, 802520, 0, 0, 1, 255, 'shamanascendant_energetic_6118995', 'shamanascendant_energetic_6118993', 'shamanascendant_energetic_6118994', '', 0, 0, 0, 0, 0, 0),
(802522, 802520, 0, 0, 1, 255, 'shamanascendant_energetic_6118998', 'shamanascendant_energetic_6118996', 'shamanascendant_energetic_6118997', '', 0, 0, 0, 0, 0, 0),
(802530, 802530, 0, 0, 1, 255, 'eredarbrutemalearmor_green', 'eredarbrutemalearmor_glow_green', '', '', 0, 0, 0, 0, 0, 0),
(802558, 802558, 0, 0, 0.5, 255, '', '', '', '', 0, 0, 0, 0, 0, 0);

DELETE FROM `creaturemodeldata_dbc` WHERE `ID` BETWEEN 802501 AND 802558;
INSERT INTO `creaturemodeldata_dbc` (`ID`, `Flags`, `ModelName`, `SizeClass`, `ModelScale`, `BloodID`, `FootprintTextureID`, `FootprintTextureLength`, `FootprintTextureWidth`, `FootprintParticleScale`, `FoleyMaterialID`, `FootstepShakeSize`, `DeathThudShakeSize`, `SoundID`, `CollisionWidth`, `CollisionHeight`, `MountHeight`, `GeoBoxMinX`, `GeoBoxMinY`, `GeoBoxMinZ`, `GeoBoxMaxX`, `GeoBoxMaxY`, `GeoBoxMaxZ`, `WorldEffectScale`, `AttachedEffectScale`, `MissileCollisionRadius`, `MissileCollisionPush`, `MissileCollisionRaise`) VALUES
(802501, 0, 'spells\\spheregrid_spell_groundhook.mdx', 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.6111, 2.031, 0.269092, -0.268983, -0.195972, -0.002365, 0.262755, 0.186011, 0.441103, 1, 1, 0, 0, 0),
(802503, 0, 'spells\\spheregrid_star_red.mdx', 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.6111, 2.031, 0.269092, -0.268983, -0.195972, -0.002365, 0.262755, 0.186011, 0.441103, 1, 1, 0, 0, 0),
(802504, 0, 'spells\\spheregrid_star_yellow.mdx', 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.6111, 2.031, 0.269092, -0.268983, -0.195972, -0.002365, 0.262755, 0.186011, 0.441103, 1, 1, 0, 0, 0),
(802505, 0, 'spells\\spheregrid_star_green.mdx', 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.6111, 2.031, 0.269092, -0.268983, -0.195972, -0.002365, 0.262755, 0.186011, 0.441103, 1, 1, 0, 0, 0),
(802506, 0, 'spells\\starfall_state_nosun.mdx', 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.6111, 2.031, 0.269092, -0.268983, -0.195972, -0.002365, 0.262755, 0.186011, 0.441103, 1, 1, 0, 0, 0),
(802507, 0, 'World\\Goober\\G_RuneGroundBlue01.mdx', 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.6111, 2.031, 0.269092, -0.268983, -0.195972, -0.002365, 0.262755, 0.186011, 0.441103, 1, 1, 0, 0, 0),
(802508, 0, 'spells\\priest_angelicfeather_state.mdx', 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.6111, 2.031, 0.269092, -0.268983, -0.195972, -0.002365, 0.262755, 0.186011, 0.441103, 1, 1, 0, 0, 0),
(802509, 0, 'spells\\7fx_paladin_holybubble.mdx', 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.6111, 2.031, 0.269092, -0.268983, -0.195972, -0.002365, 0.262755, 0.186011, 0.441103, 1, 1, 0, 0, 0),
(802510, 0, 'spells\\cfx_priest_halo_cast02.mdx', 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.6111, 2.031, 0.269092, -0.268983, -0.195972, -0.002365, 0.262755, 0.186011, 0.441103, 1, 1, 0, 0, 0),
(802511, 0, 'spells\\cfx_priest_halo_cast.mdx', 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.6111, 2.031, 0.269092, -0.268983, -0.195972, -0.002365, 0.262755, 0.186011, 0.441103, 1, 1, 0, 0, 0),
(802512, 0, 'Creature\\NorthrendGhoul\\NorthrendGhoul.mdx', 0, 1, 3, 4, 18, 12, 1, 0, 0, 0, 2644, 0.6111, 2.031, 1.217973, -1, -1.4, -2, 1.4, 1.7, 2.3, 1, 1, 0, 0, 0),
(802520, 0, 'creature\\shamanascendant_energetic\\shamanascendant_energetic.mdx', 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.6111, 2.031, 0.269092, -0.268983, -0.195972, -0.002365, 0.262755, 0.186011, 0.441103, 1, 1, 0, 0, 0),
(802530, 0, 'creature\\eredarbrutemalearmored\\eredarbrutemalearmored.mdx', 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.6111, 2.031, 0.269092, -0.268983, -0.195972, -0.002365, 0.262755, 0.186011, 0.441103, 1, 1, 0, 0, 0),
(802558, 0, 'spells\\11fx_arcaneorb02.mdx', 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.6111, 2.031, 0.269092, -0.268983, -0.195972, -0.002365, 0.262755, 0.186011, 0.441103, 1, 1, 0, 0, 0);

