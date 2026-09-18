-- mod-stellar-tarot — the durations the module gives itself.
--
-- The core carries indexes 1 to 602 in SpellDuration.dbc and loads
-- `spellduration_dbc` over it (DBCStores.cpp). That table is empty on a stock
-- server, so the module writes its own here, in the range 700-799, and the SAME
-- rows into the client's patch: a duration the server knows and the client
-- does not would show the wrong countdown on the icon.
--
-- GENERATED from the design workbook by the author's tooling. Regenerable.

DELETE FROM `spellduration_dbc` WHERE `ID` BETWEEN 700 AND 799;
