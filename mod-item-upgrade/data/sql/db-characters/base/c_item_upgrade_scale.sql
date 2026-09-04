-- ---------------------------------------------------------------------------
-- mod-item-upgrade : the upgrade scale (ranks, gains and prices)
--
-- WHAT THIS SCRIPT DOES
-- It rebuilds the whole upgrade scale: which stats can be raised, over how many
-- ranks, by how much per rank, and at what price. It replaces the minimal scale
-- shipped by the module itself (8 stats, 2 ranks).
--
-- WHEN IT RUNS
-- Automatically, at server startup: the updater applies every .sql file under a
-- module's data/sql folders. Its filename starts with `c_` so that it sorts
-- after the module's own `b_` files, which create the tables it fills.
--
-- IT IS REPLAYABLE
-- Nothing is ever added twice: the script empties, then rebuilds. It works from
-- any starting state, and upgrades players already bought are kept, lowered to
-- the new maximum rank where needed. Edit it and restart: the updater notices
-- the change and applies it again.
--
-- To apply it by hand instead, run the whole file in ONE go: it uses temporary
-- tables that vanish when the connection closes.
--
-- TO CUSTOMISE: the three settings below, then the token table further down.
-- The full walkthrough is in README section 6.
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

-- --- SETTINGS ---------------------------------------------------------------

-- How many ranks each stat has. Papota value: 20.
SET @MAX_RANK := 20;

-- Bonus gained at each rank, as a percentage of the item's base value.
-- Papota value: 5, which gives +5 % at rank 1 and +100 % at rank 20.
SET @PCT_PER_RANK := 5;

-- Price of one rank, in GOLD, the same for every rank.
-- Papota value: 350, so 7 000 gold to take one stat to rank 20.
SET @GOLD_PER_RANK := 350;

-- --- 1. The upgradeable stats -----------------------------------------------
-- One row per stat. The `pos` column fixes the identifier of rank 1, and
-- therefore of every other rank: id = pos + (number of stats) x (rank - 1).
-- Never renumber `pos` on a live server: purchased upgrades refer to it.
-- `type` is the stat's code in the core (ItemModType).
-- Deleting a row here removes that stat from the system.

DROP TEMPORARY TABLE IF EXISTS tmp_stats;
CREATE TEMPORARY TABLE tmp_stats (pos INT PRIMARY KEY, type INT);
INSERT INTO tmp_stats (pos, type) VALUES
  ( 1,  0),   -- Mana
  ( 2,  1),   -- Health
  ( 3,  3),   -- Agility
  ( 4,  4),   -- Strength
  ( 5,  5),   -- Intellect
  ( 6,  6),   -- Spirit
  ( 7,  7),   -- Stamina
  ( 8, 12),   -- Defense rating
  ( 9, 13),   -- Dodge rating
  (10, 14),   -- Parry rating
  (11, 15),   -- Block rating
  (12, 16),   -- Hit rating (melee)
  (13, 17),   -- Hit rating (ranged)
  (14, 18),   -- Hit rating (spell)
  (15, 19),   -- Crit rating (melee)
  (16, 20),   -- Crit rating (ranged)
  (17, 21),   -- Crit rating (spell)
  (18, 22),   -- Hit taken rating (melee)
  (19, 23),   -- Hit taken rating (ranged)
  (20, 24),   -- Hit taken rating (spell)
  (21, 25),   -- Crit taken rating (melee)
  (22, 26),   -- Crit taken rating (ranged)
  (23, 27),   -- Crit taken rating (spell)
  (24, 28),   -- Haste rating (melee)
  (25, 29),   -- Haste rating (ranged)
  (26, 30),   -- Haste rating (spell)
  (27, 31),   -- Hit rating
  (28, 32),   -- Critical strike rating
  (29, 33),   -- Hit taken rating
  (30, 34),   -- Crit taken rating
  (31, 35),   -- Resilience rating
  (32, 36),   -- Haste rating
  (33, 37),   -- Expertise rating
  (34, 38),   -- Attack power
  (35, 39),   -- Ranged attack power
  (36, 43),   -- Mana per 5 seconds
  (37, 44),   -- Armor penetration rating
  (38, 45),   -- Spell power
  (39, 46),   -- Health per 5 seconds
  (40, 47),   -- Spell penetration
  (41, 48);   -- Block value

SET @NB_STATS := (SELECT COUNT(*) FROM tmp_stats);

-- --- 2. The ranks -----------------------------------------------------------
-- The list 1, 2, 3 ... up to @MAX_RANK. Generated, nothing to edit here: to
-- change the number of ranks, change @MAX_RANK above.

DROP TEMPORARY TABLE IF EXISTS tmp_ranks;
CREATE TEMPORARY TABLE tmp_ranks (rank_no INT PRIMARY KEY);
INSERT INTO tmp_ranks (rank_no)
WITH RECURSIVE series (n) AS (
    SELECT 1 UNION ALL SELECT n + 1 FROM series WHERE n < @MAX_RANK
)
SELECT n FROM series;

-- --- 3. Tokens required, by rank range --------------------------------------
-- Each row says: from rank `rank_min` to rank `rank_max`, this item is needed.
-- The quantity starts at 1 on the range's first rank and goes up by one at each
-- following rank.
-- Ranks 1 to 3 appear nowhere: they only cost gold.
-- To require no token at all, insert nothing into this table.

DROP TEMPORARY TABLE IF EXISTS tmp_tokens;
CREATE TEMPORARY TABLE tmp_tokens (rank_min INT, rank_max INT, item INT);
INSERT INTO tmp_tokens (rank_min, rank_max, item) VALUES
  ( 4,  7, 801050),   -- Shard of Power    : 1, 2, 3 then 4
  ( 8, 11, 801051),   -- Fragment of Power : 1, 2, 3 then 4
  (12, 15, 801052),   -- Core of Power     : 1, 2, 3 then 4
  (16, 19, 801053),   -- Gem of Power      : 1, 2, 3 then 4
  (20, 20, 801054);   -- Crown of Power    : 1

-- --- 4. Putting purchased upgrades aside ------------------------------------
-- The scale is about to be destroyed and rebuilt. First we note, for every
-- upgrade already bought, its stat and its rank, the latter lowered to the new
-- maximum if it exceeds it. On a fresh install this table stays empty and the
-- steps using it do nothing.

DROP TEMPORARY TABLE IF EXISTS tmp_purchases;
CREATE TEMPORARY TABLE tmp_purchases (
    guid INT UNSIGNED, item_guid INT UNSIGNED, stat_type INT, stat_rank INT,
    PRIMARY KEY (guid, item_guid, stat_type)
);
INSERT IGNORE INTO tmp_purchases (guid, item_guid, stat_type, stat_rank)
SELECT u.guid, u.item_guid, s.stat_type, LEAST(s.stat_rank, @MAX_RANK)
FROM character_item_upgrade u
JOIN mod_item_upgrade_stats s ON s.id = u.stat_id;

-- --- 5. Rebuilding the scale ------------------------------------------------

DELETE FROM character_item_upgrade;
DELETE FROM mod_item_upgrade_stats_req;
DELETE FROM mod_item_upgrade_stats;

INSERT INTO mod_item_upgrade_stats (id, stat_type, stat_mod_pct, stat_rank)
SELECT s.pos + @NB_STATS * (r.rank_no - 1), s.type, r.rank_no * @PCT_PER_RANK, r.rank_no
FROM tmp_stats s
CROSS JOIN tmp_ranks r;

-- Gold cost: the same for every rank. The module counts in COPPER, hence the
-- conversion (1 gold = 10 000 copper).
INSERT INTO mod_item_upgrade_stats_req (stat_id, req_type, req_val1, req_val2)
SELECT id, 1, @GOLD_PER_RANK * 10000, NULL
FROM mod_item_upgrade_stats;

-- Token cost: only for ranks covered by a range above.
INSERT INTO mod_item_upgrade_stats_req (stat_id, req_type, req_val1, req_val2)
SELECT s.id, 4, t.item, s.stat_rank - t.rank_min + 1
FROM mod_item_upgrade_stats s
JOIN tmp_tokens t ON s.stat_rank BETWEEN t.rank_min AND t.rank_max;

-- --- 6. Restoring purchased upgrades ----------------------------------------
-- Each upgrade finds its place again through its stat and its rank. Those whose
-- stat no longer exists in the scale are not restored.

INSERT INTO character_item_upgrade (guid, item_guid, stat_id)
SELECT p.guid, p.item_guid, s.id
FROM tmp_purchases p
JOIN mod_item_upgrade_stats s ON s.stat_type = p.stat_type AND s.stat_rank = p.stat_rank;

DROP TEMPORARY TABLE tmp_stats;
DROP TEMPORARY TABLE tmp_ranks;
DROP TEMPORARY TABLE tmp_tokens;
DROP TEMPORARY TABLE tmp_purchases;

-- --- 7. Check ---------------------------------------------------------------
-- Expected with the Papota values: 41 stats, maximum rank 20, 820 scale rows,
-- 5 % at rank 1 and 100 % at the maximum rank.

SELECT COUNT(DISTINCT stat_type) AS stats,
       MAX(stat_rank)            AS maximum_rank,
       COUNT(*)                  AS scale_rows,
       MIN(stat_mod_pct)         AS percent_at_rank_1,
       MAX(stat_mod_pct)         AS percent_at_maximum_rank
FROM mod_item_upgrade_stats;
