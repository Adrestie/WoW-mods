-- ForeverUI: achievement_criteria_data rows of the statistics ForeverUI adds (data/dbc/statistics.json).
-- Apply to the world database, after adding the statistics' rows to Achievement.dbc and
-- Achievement_Criteria.dbc. Without these rows the server does not count the boss kills.
-- Safe to run again: the rows are deleted by criterion, then inserted. The DELETE alone removes them.
-- The server reads them on start (or with .reload achievement_criteria_data).

DELETE FROM `achievement_criteria_data` WHERE `criteria_id` IN (64301, 64302, 64303, 64304, 64305, 64306, 64307, 64308, 64309, 64310, 64311, 64312, 64313, 64314, 64315, 64316, 64317, 64318, 64319, 64320, 64321);

INSERT INTO `achievement_criteria_data` (`criteria_id`, `type`, `value1`, `value2`, `ScriptName`) VALUES
(64301, 12, 0, 0, ''),
(64302, 12, 0, 0, ''),
(64303, 12, 0, 0, ''),
(64304, 12, 0, 0, ''),
(64305, 12, 0, 0, ''),
(64306, 12, 0, 0, ''),
(64307, 12, 0, 0, ''),
(64308, 12, 0, 0, ''),
(64309, 12, 0, 0, ''),
(64310, 12, 0, 0, ''),
(64311, 12, 0, 0, ''),
(64312, 12, 0, 0, ''),
(64313, 12, 0, 0, ''),
(64314, 12, 0, 0, '');
