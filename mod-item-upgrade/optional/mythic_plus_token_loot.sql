-- ---------------------------------------------------------------------------
-- OPTIONAL : power tokens handed out by the Mythic+ system
--
-- On Papota the tokens are obtained ONLY through our in-house Mythic+ system
-- (lua_scripts/MythicPlus, table world_mythic_loot, WORLD database). These rows
-- reproduce our distribution: 100 % on each completed run, in a quantity that
-- depends on the keystone tier (Shard from tier 10, Fragment 20, Core 30,
-- Gem 40, Crown 50+ at 5 %).
--
-- Without that system these rows do nothing: they fill a table nobody reads.
-- Provide another source instead, such as a vendor, a loot table or a quest.
-- See README section 7.
--
-- This file sits OUTSIDE data/sql on purpose, so the updater does not apply it
-- on its own. Run it by hand if you want it.
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;
CREATE TABLE IF NOT EXISTS `world_mythic_loot` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `itemid` int unsigned NOT NULL,
  `itemname` varchar(255) NOT NULL COMMENT 'Item name for reference only - not used by script',
  `amount` int unsigned NOT NULL DEFAULT '1',
  `type` varchar(32) NOT NULL,
  `faction` char(1) NOT NULL DEFAULT 'N',
  `loot_bracket` varchar(50) NOT NULL COMMENT 'Tier eligibility: bracket names, ranges (1-3), single tiers (5), or conditions (5+, 3-)',
  `chancePercent` float NOT NULL,
  `additionalID` int unsigned DEFAULT NULL,
  `additionalType` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
DELETE FROM `world_mythic_loot` WHERE `itemid` BETWEEN 801050 AND 801054;
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

INSERT INTO `world_mythic_loot` (`id`, `itemid`, `itemname`, `amount`, `type`, `faction`, `loot_bracket`, `chancePercent`, `additionalID`, `additionalType`) VALUES (1,801050,'Éclat de Puissance',2,'gear','N','10-13',100,NULL,NULL),(2,801050,'Éclat de Puissance',6,'gear','N','14-17',100,NULL,NULL),(3,801050,'Éclat de Puissance',10,'gear','N','18-19',100,NULL,NULL),(4,801050,'Éclat de Puissance',2,'gear','N','30-33',100,NULL,NULL),(5,801050,'Éclat de Puissance',6,'gear','N','34-37',100,NULL,NULL),(6,801050,'Éclat de Puissance',10,'gear','N','38-39',100,NULL,NULL),(7,801050,'Éclat de Puissance',2,'gear','N','40-43',100,NULL,NULL),(8,801050,'Éclat de Puissance',6,'gear','N','44-47',100,NULL,NULL),(9,801050,'Éclat de Puissance',10,'gear','N','48-49',100,NULL,NULL),(10,801050,'Éclat de Puissance',2,'gear','N','50-53',100,NULL,NULL),(11,801050,'Éclat de Puissance',6,'gear','N','54-57',100,NULL,NULL),(12,801050,'Éclat de Puissance',10,'gear','N','58-59',100,NULL,NULL),(13,801050,'Éclat de Puissance',20,'gear','N','60-77',100,NULL,NULL),(14,801050,'Éclat de Puissance',30,'gear','N','78-79',100,NULL,NULL),(15,801050,'Éclat de Puissance',40,'gear','N','80-83',100,NULL,NULL),(16,801050,'Éclat de Puissance',50,'gear','N','84-87',100,NULL,NULL),(17,801050,'Éclat de Puissance',60,'gear','N','88-89',100,NULL,NULL),(18,801050,'Éclat de Puissance',70,'gear','N','90-93',100,NULL,NULL),(19,801050,'Éclat de Puissance',100,'gear','N','94+',100,NULL,NULL),(100,801051,'Fragment de Puissance',2,'gear','N','20-23',100,NULL,NULL),(101,801051,'Fragment de Puissance',6,'gear','N','24-27',100,NULL,NULL),(102,801051,'Fragment de Puissance',10,'gear','N','28-29',100,NULL,NULL),(103,801051,'Fragment de Puissance',2,'gear','N','40-43',100,NULL,NULL),(104,801051,'Fragment de Puissance',6,'gear','N','44-47',100,NULL,NULL),(105,801051,'Fragment de Puissance',10,'gear','N','48-49',100,NULL,NULL),(106,801051,'Fragment de Puissance',2,'gear','N','50-53',100,NULL,NULL),(107,801051,'Fragment de Puissance',6,'gear','N','54-57',100,NULL,NULL),(108,801051,'Fragment de Puissance',10,'gear','N','58-59',100,NULL,NULL),(109,801051,'Fragment de Puissance',10,'gear','N','60-69',100,NULL,NULL),(110,801051,'Fragment de Puissance',14,'gear','N','70-73',100,NULL,NULL),(111,801051,'Fragment de Puissance',20,'gear','N','74-79',100,NULL,NULL),(112,801051,'Fragment de Puissance',30,'gear','N','80-83',100,NULL,NULL),(113,801051,'Fragment de Puissance',40,'gear','N','84-87',100,NULL,NULL),(114,801051,'Fragment de Puissance',50,'gear','N','88-89',100,NULL,NULL),(115,801051,'Fragment de Puissance',60,'gear','N','90-93',100,NULL,NULL),(116,801051,'Fragment de Puissance',70,'gear','N','94-97',100,NULL,NULL),(117,801051,'Fragment de Puissance',100,'gear','N','98+',100,NULL,NULL),(200,801052,'Noyau de Puissance',2,'gear','N','30-33',100,NULL,NULL),(201,801052,'Noyau de Puissance',6,'gear','N','34-37',100,NULL,NULL),(202,801052,'Noyau de Puissance',10,'gear','N','38-39',100,NULL,NULL),(203,801052,'Noyau de Puissance',15,'gear','N','50-53',100,NULL,NULL),(204,801052,'Noyau de Puissance',20,'gear','N','54-57',100,NULL,NULL),(205,801052,'Noyau de Puissance',25,'gear','N','58-59',100,NULL,NULL),(206,801052,'Noyau de Puissance',30,'gear','N','60-77',100,NULL,NULL),(207,801052,'Noyau de Puissance',40,'gear','N','78-79',100,NULL,NULL),(208,801052,'Noyau de Puissance',50,'gear','N','80-83',100,NULL,NULL),(209,801052,'Noyau de Puissance',60,'gear','N','84-87',100,NULL,NULL),(210,801052,'Noyau de Puissance',70,'gear','N','88-89',100,NULL,NULL),(211,801052,'Noyau de Puissance',80,'gear','N','90-93',100,NULL,NULL),(212,801052,'Noyau de Puissance',90,'gear','N','94-97',100,NULL,NULL),(213,801052,'Noyau de Puissance',100,'gear','N','98-99',100,NULL,NULL),(214,801052,'Noyau de Puissance',100,'gear','N','100+',100,NULL,NULL),(300,801053,'Gemme de Puissance',2,'gear','N','40-43',100,NULL,NULL),(301,801053,'Gemme de Puissance',6,'gear','N','44-47',100,NULL,NULL),(302,801053,'Gemme de Puissance',10,'gear','N','48-59',100,NULL,NULL),(303,801053,'Gemme de Puissance',2,'gear','N','60-63',100,NULL,NULL),(304,801053,'Gemme de Puissance',6,'gear','N','64-67',100,NULL,NULL),(305,801053,'Gemme de Puissance',10,'gear','N','68-79',100,NULL,NULL),(306,801053,'Gemme de Puissance',14,'gear','N','80-83',100,NULL,NULL),(307,801053,'Gemme de Puissance',20,'gear','N','84-87',100,NULL,NULL),(308,801053,'Gemme de Puissance',25,'gear','N','88-89',100,NULL,NULL),(309,801053,'Gemme de Puissance',30,'gear','N','90-93',100,NULL,NULL),(310,801053,'Gemme de Puissance',40,'gear','N','94-97',100,NULL,NULL),(311,801053,'Gemme de Puissance',50,'gear','N','98-99',100,NULL,NULL),(312,801053,'Gemme de Puissance',60,'gear','N','100+',100,NULL,NULL),(400,801054,'Couronne de Puissance',2,'gear','N','50+',5,NULL,NULL);
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
