-- ForeverUI : les textes en anglais, la BASE (voir Textes.lua). Toute cle
-- existe ici ; une autre langue ne traduit que les valeurs.

ForeverUI.AjouterTextes("enUS", {
	-- ActionBar.lua
	ACTIONBAR_BUTTON1_MISSING = "ActionButton1 not found",
	ACTIONBAR_DEBUG = "bar: button %.0fx%.0f | parent %s | anchor %s on %s (%.0f, %.0f) | visible=%s | frame=%s | normal alpha=%.2f",
	ACTIONBAR_EDIT_LABEL = "Action Bar",

	-- Bags.lua
	BAGS_CLEANUP = "Clean Up Bags",
	BAGS_CLEANUP_TOOLTIP = "Combines stacks and puts your items in order.",
	BAGS_DEBUG_ANCHOR = " [%s on %s of %s, %d, %d]",
	BAGS_DEBUG_ANCHORS = "%d anchor(s):",
	BAGS_DEBUG_ANCHORS_FORCE = "the frame's anchors impose its height",
	BAGS_DEBUG_FRAME = "%s (bag %d): %d slots, %d rows",
	BAGS_DEBUG_MATCH = "MATCH",
	BAGS_DEBUG_MISMATCH = "MISMATCH",
	BAGS_DEBUG_NONE = "none",
	BAGS_DEBUG_NO_BAG_OPEN = "no bag open: open one, then type /fui sacs again",
	BAGS_DEBUG_RESIZED_AFTER = "someone sets the size AFTER us",
	BAGS_DEBUG_SCREEN = "the screen",
	BAGS_DEBUG_SEGMENT = "segment: ours visible=%s | the client's visible=%s",
	BAGS_DEBUG_SIZE = "computed %d x %d = grid %d + filler %d + extra %d | the frame is %.0f x %.0f  %s",
	BAGS_DEBUG_SKINNED = "skinned frames %d | slot %.0f | field visible=%s",
	BAGS_DEBUG_TOKENS = "tracked currencies %d/%d: %s",
	BAGS_DEBUG_WITNESS = "witness: set %s, read back at once %s, undone %s times -> %s",
	BAGS_NUMBER_EXPECTED = "expected value: a number",
	BAGS_SET = "bags: %s = %s",
	BAGS_UNKNOWN_SETTING = "unknown setting: ",

	-- BottomBar.lua
	BOTTOMBAR_DEBUG = "bottom: micro %.0f x %.0f (%d buttons) | bags %.0f x %.0f | anchor %s on %s (%.1f, %.1f) | keyring visible=%s",
	BOTTOMBAR_EDIT_LABEL_BAGS = "Bags",
	BOTTOMBAR_EDIT_LABEL_MICROMENU = "Menu",
	BOTTOMBAR_HOVER_PROMPT = "move the cursor over the character button: five seconds.",
	BOTTOMBAR_MICRO_BUTTON = "%2d %-24s %s on %s (%s, %s) | %.0f x %.0f | expected x=%d | visible=%s enabled=%s level=%d anchors=%d",
	BOTTOMBAR_MICRO_DEBUG = "micro menu: %d buttons, strip %.0f x %.0f, step %d",
	BOTTOMBAR_NOTHING = "(nothing)",
	BOTTOMBAR_UNDER_CURSOR = "under the cursor: ",

	-- Buffs.lua
	BUFFS_DEBUG_BUFFS = "buffs: unit %s, %d auras, %d hideable, %d shown | collapse %s (expanded %s) | consolidation %s (%d) | durations %s",
	BUFFS_DEBUG_DEBUFFS = "debuffs: %d (%s)",
	BUFFS_DEBUG_HIDDEN = "hidden",
	BUFFS_DEBUG_VISIBLE = "visible",
	BUFFS_DISHONORED_DESC = "Every faction, your own included, is hostile to you, and any player may attack you.",
	BUFFS_EDIT_LABEL_BUFFS = "Buff Frame",
	BUFFS_EDIT_LABEL_DEBUFFS = "Debuff Frame",

	-- CastBar.lua
	CASTBAR_EDIT_LABEL = "Cast Bar",

	-- CharacterFrame.lua
	CHARACTERFRAME_DEBUG_CLOSE_SAVED = "close button: report saved; type /reload to write it to disk.",
	CHARACTERFRAME_DEBUG_COVERED_BY = "      covered by: ",
	CHARACTERFRAME_DEBUG_COVERING = "   what covers its center and takes the mouse:",
	CHARACTERFRAME_DEBUG_COVERING_ROW = "      %-34s strata=%-16s level=%d",
	CHARACTERFRAME_DEBUG_HEAD_SCRIPTS = "   click=%s drag=%s receive=%s enabled=%s",
	CHARACTERFRAME_DEBUG_HEAD_STATE = "head: %dx%d strata=%s level=%d mouse=%s shown=%s",
	CHARACTERFRAME_DEBUG_HOVER_SLOT = "move the cursor over a slot for five seconds.",
	CHARACTERFRAME_DEBUG_HOVER_TABS = "move the cursor over the tabs: /fui perso tells what the mouse really touches",
	CHARACTERFRAME_DEBUG_NONE = "none",
	CHARACTERFRAME_DEBUG_PANES = "panes: ",
	CHARACTERFRAME_DEBUG_SHEET_OPEN_FIRST = "sheet: open it first, then run /fui perso again",
	CHARACTERFRAME_DEBUG_SHOWN_SCREENS = "client screens shown: %s | open group: %s",
	CHARACTERFRAME_DEBUG_TABS_OPEN_FIRST = "tabs: open the character sheet first, then run /fui onglets again",
	CHARACTERFRAME_DEBUG_TAB_STATE = "%-30s shown=%-5s mouse=%-5s enabled=%-5s strata=%-10s level=%d click=%s",
	CHARACTERFRAME_DEBUG_UNDER_CURSOR = "      under the cursor: ",
	CHARACTERFRAME_DEBUG_UNNAMED = "(unnamed)",
	CHARACTERFRAME_DEBUG_WATCH_END = "   (end of watch)",
	CHARACTERFRAME_HIDE_DETAILS = "Hide details",
	CHARACTERFRAME_MODEL_POSITION_USAGE = "model: /fui modele position <depth> <lateral> <height>",
	CHARACTERFRAME_MODEL_STATE = "model: scale=%s position=(%s, %s, %s)",
	CHARACTERFRAME_MODEL_USAGE = "model: echelle <n> | position <x> <y> <z> | position defaut",
	CHARACTERFRAME_PANES_MISSING = "Panes.lua is not loaded. A file added to the addon only arrives at the next game start: close and reopen the client. The character sheet stays inactive until then.",
	CHARACTERFRAME_SHOW_DETAILS = "Show details",
	CHARACTERFRAME_TITLES = "Titles",

	-- Chat.lua
	CHAT_DEBUG_FADE = "   lit %s (client %s, hover %s), outside for %.1f s | mouse over: chat %s, friends %s, column %s, bar %s, return %s",
	CHAT_DEBUG_HIDDEN = "hidden",
	CHAT_DEBUG_NO = "no",
	CHAT_DEBUG_REST = "   rest: coefficient %.2f (target %d) on %d pieces + %d of input | background %.2f (kept %.2f, done %s)",
	CHAT_DEBUG_SHOWN = "shown",
	CHAT_DEBUG_STATE = "chat %s: %d messages, %d visible, rank %d/%d, at bottom %s | bar %s alpha %.2f | return alpha %.2f | SetScrollOffset %s",
	CHAT_DEBUG_YES = "yes",
	CHAT_DEBUG_YES_UPPER = "YES",
	CHAT_LINES_RECORDED = "chat record %s: %d text objects (%d visible), %d messages; type /reload to save it.",
	CHAT_LINES_TEST = "ForeverUI, selection test: a line long enough to be wrapped by the chat, with accents (é è à ç), a link %s, an icon %s and a verylongwordwithoutanyspacetoseehowtheenginebreaksitwhenthereisnospaceatall end.",

	-- EquipmentManager.lua
	EQUIPMENTMANAGER_DEBUG_CARD = "   card %d: name=%s visible=%s anchor=%s tick=%s",
	EQUIPMENTMANAGER_DEBUG_CLOSED = "closed",
	EQUIPMENTMANAGER_DEBUG_KEPT_ORDER = "stored order: ",
	EQUIPMENTMANAGER_DEBUG_NO_DIALOG = "no cards: the client dialog is not there.",
	EQUIPMENTMANAGER_DEBUG_OPEN = "open",
	EQUIPMENTMANAGER_DEBUG_PLACED_ORDER = "placed order: ",
	EQUIPMENTMANAGER_DEBUG_SCROLL = "scroll = %d, cards that fit = %d, pane %s",
	EQUIPMENTMANAGER_DEBUG_SETS = "sets: the client publishes %d: %s",
	EQUIPMENTMANAGER_DEBUG_WORN = "worn = %s, editing = %s",
	EQUIPMENTMANAGER_NEW_SET = "New Set",

	-- GroupFinder.lua
	GROUPFINDER_DEBUG_HIDDEN = "hidden",
	GROUPFINDER_DEBUG_NONE = "none",
	GROUPFINDER_DEBUG_NOTHING = "nothing",
	GROUPFINDER_DEBUG_NOT_BUILT = "group finder: not built (LFDParentFrame missing?)",
	GROUPFINDER_DEBUG_RAID = "raid: search %s | server searching %s",
	GROUPFINDER_DEBUG_RAID_ENTRY = "   %s (%d): %s player(s) recorded",
	GROUPFINDER_DEBUG_SHOWN = "shown",
	GROUPFINDER_DEBUG_STATE = "group finder: view %s | type %s | mode %s | %d dungeons | our window %s, level %d | client content alpha %s, level %d",

	-- IconPicker.lua
	ICONPICKER_CLICK_TO_VIEW = "Click to view in the list",
	ICONPICKER_CURRENTLY_SELECTED = "Currently Selected",

	-- Layout.lua
	LAYOUT_EDIT_MODE_COMBAT = "edit mode is not available in combat.",
	LAYOUT_EDIT_MODE_OFF = "edit mode ended, positions saved.",
	LAYOUT_EDIT_MODE_ON = "edit mode active: drag the elements, /fui to finish.",
	LAYOUT_HELP = "commands: /fui (edit mode), /fui reset [element], /fui list, /fui debug, /fui barre, /fui bas, /fui barres, /fui sacs, /fui perso, /fui croix, /fui onglets, /fui modele, /fui sets, /fui reput [faction], /fui skills, /fui monnaie, /fui familier, /fui pvp [0..1], /fui arene, /fui bg, /fui social, /fui chercheur, /fui chat, /fui chatlignes, /fui titres, /fui minimap [echelle k], /fui carte, /fui souris, /fui journal, /fui suivi, /fui grimoire, /fui micro",
	LAYOUT_LIST_HEADER = "registered elements:",
	LAYOUT_LIST_MOVED = " - moved",
	LAYOUT_NO_CHAT_LINES = "no chat line report available.",
	LAYOUT_NO_DIAG = "no diagnostic available.",
	LAYOUT_NO_DIAG_ACTIONBAR = "no action bar diagnostic available.",
	LAYOUT_NO_DIAG_ARENA = "no arena team diagnostic available.",
	LAYOUT_NO_DIAG_BAGS = "no bag diagnostic available.",
	LAYOUT_NO_DIAG_BATTLEGROUNDS = "no battleground diagnostic available.",
	LAYOUT_NO_DIAG_BOTTOM = "no bottom-of-screen diagnostic available.",
	LAYOUT_NO_DIAG_BUFFS = "no buff diagnostic available.",
	LAYOUT_NO_DIAG_CHAT = "no chat diagnostic available.",
	LAYOUT_NO_DIAG_CURRENCY = "no currency diagnostic available.",
	LAYOUT_NO_DIAG_GROUPFINDER = "no dungeon finder diagnostic available.",
	LAYOUT_NO_DIAG_MICROMENU = "no micro menu diagnostic available.",
	LAYOUT_NO_DIAG_MINIMAP = "no minimap diagnostic available.",
	LAYOUT_NO_DIAG_PET = "no pet diagnostic available.",
	LAYOUT_NO_DIAG_PVP = "no PvP diagnostic available.",
	LAYOUT_NO_DIAG_QUESTLOG = "no quest log diagnostic available.",
	LAYOUT_NO_DIAG_REPUTATION = "no reputation diagnostic available.",
	LAYOUT_NO_DIAG_SETS = "no equipment set diagnostic available.",
	LAYOUT_NO_DIAG_SHEET = "no character sheet diagnostic available.",
	LAYOUT_NO_DIAG_SKILLS = "no skills diagnostic available.",
	LAYOUT_NO_DIAG_SOCIAL = "no Social window diagnostic available.",
	LAYOUT_NO_DIAG_SPELLBOOK = "no spellbook diagnostic available.",
	LAYOUT_NO_DIAG_STATUSBARS = "no status bar diagnostic available.",
	LAYOUT_NO_DIAG_TABS = "no tab diagnostic available.",
	LAYOUT_NO_DIAG_TITLES = "no titles diagnostic available.",
	LAYOUT_NO_DIAG_TRACKER = "no quest tracker diagnostic available.",
	LAYOUT_NO_DIAG_WORLDMAP = "no world map diagnostic available.",
	LAYOUT_NO_MODEL_TUNE = "no model adjustment available.",
	LAYOUT_NO_MOVE_IN_COMBAT = "cannot move while in combat.",
	LAYOUT_RESET_ALL = "all positions reset to default.",
	LAYOUT_RESET_ONE = "position reset to default: ",
	LAYOUT_SPY_NOTHING = "nothing",
	LAYOUT_SPY_PARENTS = "parents: ",
	LAYOUT_SPY_STARTED = "mouse spy: click the element you want; /fui souris to stop.",
	LAYOUT_SPY_STOPPED = "mouse spy stopped.",
	LAYOUT_SPY_TEXT = "text: ",
	LAYOUT_SPY_TEXTURE = "texture: ",
	LAYOUT_SPY_UNDER_MOUSE = "under the mouse: ",
	LAYOUT_SPY_UNNAMED = "(unnamed)",
	LAYOUT_UNKNOWN_ELEMENT = "unknown element: ",

	-- Minimap.lua
	MINIMAP_DEBUG_ABSENT = "MISSING",
	MINIMAP_DEBUG_BUTTON = "%-26s %s, angle %d",
	MINIMAP_DEBUG_CLOCK = "clock: %s | calendar: %s | coordinates: '%s'",
	MINIMAP_DEBUG_CYCLE = "cycle: time %s -> %s",
	MINIMAP_DEBUG_DAY = "day",
	MINIMAP_DEBUG_FRAME = "frame %s | mask %s | scale %.3f (project %.3f)",
	MINIMAP_DEBUG_HIDDEN = "hidden",
	MINIMAP_DEBUG_NIGHT = "night",
	MINIMAP_DEBUG_NOTHING_BUILT = "minimap: nothing built.",
	MINIMAP_DEBUG_NOT_LOADED = "not loaded",
	MINIMAP_DEBUG_NOT_SKINNED = "not skinned",
	MINIMAP_DEBUG_NO_ATLASUTIL = "minimap: AtlasUtil.lua is missing, nothing is skinned.",
	MINIMAP_DEBUG_NO_CLIENT_FRAMES = "minimap: the client has no MinimapCluster, Minimap or MinimapBackdrop.",
	MINIMAP_DEBUG_SCALE = "minimap: scale %.3f, size %.1f, on screen %.1f",
	MINIMAP_DEBUG_SIZES = "minimap: cluster %.0f x %.0f | container %.0f x %.0f | map %.0f",
	MINIMAP_DEBUG_SKINNED = "skinned",
	MINIMAP_DEBUG_VISIBLE = "visible",
	MINIMAP_DEBUG_ZONE = "zone: \"%s\" justified %s, width %.0f",
	MINIMAP_DEBUG_ZOOM = "zoom: level %s of %s | in visible=%s | out visible=%s",

	-- ObjectiveTracker.lua
	OBJECTIVETRACKER_ALL_OBJECTIVES = "All Objectives",
	OBJECTIVETRACKER_DEBUG_NOT_BUILT = "tracker: not built.",
	OBJECTIVETRACKER_DEBUG_STATE = "tracker: %.0f x %.0f, collapsed=%s | header %s | quests %d block(s) (%s) | achievements %d block(s) (%s) | handlers %d | sort %s, filter %s",
	OBJECTIVETRACKER_EDIT_LABEL = "Objective Tracker",
	OBJECTIVETRACKER_OPEN_MAP = "Open Quest Map",
	OBJECTIVETRACKER_READY = "Ready for turn-in",
	OBJECTIVETRACKER_SHARE_IN_CHAT = "Share in Chat",
	OBJECTIVETRACKER_UNTRACK = "Untrack",

	-- Panes.lua
	PANES_ERROR_UNKNOWN_HOST = "ForeverUI.Panes: unknown host -- ",
	PANES_REPORT_LINE = "%s: group=%s page=%s visible=%s | group pages: %s",
	PANES_REPORT_NEVER_BUILT = ", never built",
	PANES_REPORT_PAGE = "%s(%d frames%s)",

	-- PartyFrame.lua
	PARTYFRAME_EDIT_LABEL = "Party Frames",

	-- PetBar.lua
	PETBAR_EDIT_LABEL = "Pet Bar",

	-- PetTab.lua
	PETTAB_DEBUG_PET = "pet: HasPetUI=%s UnitExists=%s | level=%s name=%s family=%s",
	PETTAB_DEBUG_PREVIEW = "preview: %s | detail: %s",
	PETTAB_RESISTANCES = "Resistances",

	-- PlayerFrame.lua
	PLAYERFRAME_DEBUG = "state: struck=%s hate_list=%s threat=%s target=%s hostile=%s targets_me=%s glow=%s alpha=%.2f",
	PLAYERFRAME_DEBUG_NO_TARGET = "none",
	PLAYERFRAME_EDIT_LABEL = "Player Frame",

	-- ProfessionsBook.lua
	PROFESSIONSBOOK_COOKING_MISSING = "Visit a trainer to learn cooking. Cooking lets you learn recipes to create food that heals you out of combat and grants you temporary buffs.",
	PROFESSIONSBOOK_FIRST_AID_MISSING = "Visit a trainer to learn first aid.  First aid lets you turn cloth into bandages for healing yourself and others.",
	PROFESSIONSBOOK_FIRST_PROFESSION = "First Profession",
	PROFESSIONSBOOK_FISHING_MISSING = "Visit a trainer to learn fishing.  Fishing lets you catch fish and other strange things from water.  Fish can be cooked into delicious meals with the Cooking skill.",
	PROFESSIONSBOOK_MISSING_PROFESSION = "Visit a profession trainer in a major city to learn a new profession. You may have two professions. You may have any combination of gathering and production professions.",
	PROFESSIONSBOOK_SECOND_PROFESSION = "Second Profession",

	-- PvPArena.lua
	PVPARENA_DEBUG_DETAIL = "detail: open=%s team=%s season=%s",
	PVPARENA_DEBUG_NO_TEAM = "team %d: none",
	PVPARENA_DEBUG_SEASON = "season %s (previous %s) | arena points %s",
	PVPARENA_DEBUG_TEAM = "team %d: %s (%dv%d) rating %s | week %s/%s, me %s | season %s/%s | banner border %s emblem %s",

	-- PvPBattlegrounds.lua
	PVPBATTLEGROUNDS_DEBUG_BONUSES = "random: %s | call to arms: %s",
	PVPBATTLEGROUNDS_DEBUG_INFO = "GetBattlefieldInfo: %s, max group %s",
	PVPBATTLEGROUNDS_DEBUG_QUEUE = "queue %d: %s %s",
	PVPBATTLEGROUNDS_DEBUG_ROW = "%d: %s enter=%s holiday=%s random=%s id=%s%s",
	PVPBATTLEGROUNDS_DEBUG_SELECTED = " <- selected",

	-- Bank.lua
	BANK_TITLE = "Bank",
	BANK_COLON = "%s:",

	-- Mail.lua
	MAIL_OPEN_ALL = "Open All",
	MAIL_OPEN_ALL_OPENING = "Opening...",

	-- PvPTab.lua
	PVPTAB_CIVILIAN = "Civilian",
	PVPTAB_DISHONORED_LEFT = "Dishonored: %s left",
	PVPTAB_TOOLTIP_CIVILIAN = "Civilian",
	PVPTAB_DEBUG_GAUGE = "gauge: start %s direction %s | %s",
	PVPTAB_DEBUG_GAUGE_NOT_BUILT = "gauge: the screen is not built yet",
	PVPTAB_DEBUG_HONOR = "honor: current=%d lifetime=%d bestRank=%d today=%d (%d) yesterday=%d (%d)",
	PVPTAB_DEBUG_KEPT = "kept: rank=%s name=%s | kills=%d threshold=%s -> progress=%.3f",
	PVPTAB_DEBUG_NONE = "none",
	PVPTAB_DEBUG_QUARTER_ARC = "arc",
	PVPTAB_DEBUG_QUARTER_EMPTY = "empty",
	PVPTAB_DEBUG_QUARTER_FULL = "full",
	PVPTAB_DEBUG_RANK_COUNTER = "rank counter: UnitPVPRank=%s -> name=%s number=%s | GetPVPRankProgress=%s",
	PVPTAB_DEBUG_RANK_TITLES = "rank titles (%s, ids %d to %d): %s",
	PVPTAB_DEBUG_SEASON = "arena season: %s | faction: %s",
	PVPTAB_DEBUG_TEST_VALUE = "gauge set to %.0f %% (test value)",

	-- QuestLog.lua
	QUESTLOG_CLICK_DETAILS = "<Click to view Quest Details>",
	QUESTLOG_COUNT = "Quests: %s%d|r|cffffffff/%d|r",
	QUESTLOG_DEBUG_CLOSED = "closed",
	QUESTLOG_DEBUG_NOT_BUILT = "quest log: not built.",
	QUESTLOG_DEBUG_OPEN = "open",
	QUESTLOG_DEBUG_STATE = "quest log: panel %s (%.0f x %.0f) | %d header(s), %d quest(s) | search '%s' | objectives %s",
	QUESTLOG_EMPTY = "No quests available|n|nAccept quests by talking to characters with a |TInterface\\GossipFrame\\AvailableQuestIcon:16:16|t above their head.",
	QUESTLOG_NO_RESULTS = "No results found",
	QUESTLOG_READY = "Ready for turn-in",
	QUESTLOG_SEARCH = "Search Quest Log",
	QUESTLOG_SHARE_IN_CHAT = "Share in Chat",
	QUESTLOG_SHOW_OBJECTIVES = "Show Quest Objectives",
	QUESTLOG_TITLE_FAILED = "%s - (Failed)",
	QUESTLOG_TRACK_ALL = "Track All",
	QUESTLOG_UNTRACK = "Untrack",
	QUESTLOG_UNTRACK_ALL = "Untrack All",
	QUESTLOG_UNTRACK_QUEST = "Untrack Quest",

	-- RaidFrame.lua
	RAIDFRAME_EDIT_LABEL = "Raid Frames",

	-- ReputationTab.lua
	REPUTATIONTAB_DEBUG_CLIENT = "what the client exposes:",
	REPUTATIONTAB_DEBUG_CLIENT_ROW = "   %2d %-28s header=%-5s child=%-5s collapsed=%-5s hasRep=%-5s standing=%s raw=%s/%s/%s",
	REPUTATIONTAB_DEBUG_EDGES = "l=%.1f r=%.1f",
	REPUTATIONTAB_DEBUG_GEOMETRY = "geometry:",
	REPUTATIONTAB_DEBUG_PLACED = "what we place:",
	REPUTATIONTAB_DEBUG_PLACED_ROW = "   %d %s header=%s standing=%s raw=%s/%s/%s | bar=%s width=%s visible=%s tint=%.2f,%.2f,%.2f",
	REPUTATIONTAB_DEBUG_ROW_GEOMETRY = "   %d %-24s row %s(%s,%s) w=%s h=%s | chevron %sx%s shown=%s | name %s: %s",
	REPUTATIONTAB_DEBUG_ROW_RESOLVED = "      resolved: row %s | chevron %s | name %s w=%.1f justify=%s font=%s",
	REPUTATIONTAB_DEBUG_SUMMARY = "reputation: %d factions, offset %d, %d rows, %d placed",
	REPUTATIONTAB_DEBUG_UNKNOWN = "unknown",

	-- SkillsTab.lua
	SKILLSTAB_DEBUG_ROW = "   %2d %-28s header=%-5s collapsed=%-5s %s",
	SKILLSTAB_DEBUG_SUMMARY = "skills: %d client rows, offset %d, %d placed, selected=%s",

	-- Social.lua
	SOCIAL_DEBUG_FRIENDS = "friends %s (%s online), selected %s | ignored %s, selected %s",
	SOCIAL_DEBUG_LIST = "list: %d entry(ies), %d visible, offset %d",
	SOCIAL_DEBUG_NOT_BUILT = "Social window: not built (FriendsFrame missing?)",
	SOCIAL_DEBUG_STATE = "social: tab %s, sub-tab %s | our window %s | panel mouse %s",

	-- SpellBook.lua
	SPELLBOOK_DEBUG_NOT_BUILT = "spellbook: not built.",
	SPELLBOOK_DEBUG_ONE_PAGE = "one page",
	SPELLBOOK_DEBUG_STATE = "spellbook: %.0f x %.0f, %s | category %d/%d, page %d/%d | %s",
	SPELLBOOK_DEBUG_TWO_PAGES = "two pages",
	SPELLBOOK_FLYOUT_ASPECT = "Aspect",
	SPELLBOOK_FLYOUT_ASPECT_DESC = "Take on aspects of nature.",
	SPELLBOOK_FLYOUT_AURAS_DESC = "Activate a protective aura for your group.",
	SPELLBOOK_FLYOUT_BLESSINGS = "Blessings",
	SPELLBOOK_FLYOUT_BLESSINGS_DESC = "Places a Blessing on friendly targets.",
	SPELLBOOK_FLYOUT_GREATER_BLESSINGS = "Greater Blessings",
	SPELLBOOK_FLYOUT_GREATER_BLESSINGS_DESC = "Blessings that target all members of your group that share the same class.",
	SPELLBOOK_FLYOUT_IMP_SPELLS = "Imp Spells",
	SPELLBOOK_FLYOUT_IMP_SPELLS_DESC = "[PH] Commands the Imp to cast spells",
	SPELLBOOK_FLYOUT_JUDGEMENTS = "Judgements",
	SPELLBOOK_FLYOUT_PET_UTILITIES = "Pet Utilities",
	SPELLBOOK_FLYOUT_PET_UTILITIES_DESC = "Manage your pets.",
	SPELLBOOK_FLYOUT_PORTAL = "Portal",
	SPELLBOOK_FLYOUT_PORTAL_DESC = "Creates a portal, teleporting group members who use it to a major city.",
	SPELLBOOK_FLYOUT_SEALS = "Seals",
	SPELLBOOK_FLYOUT_SHAPESHIFT = "Shapeshift",
	SPELLBOOK_FLYOUT_SHAPESHIFT_DESC = "Shapeshift into a different form.",
	SPELLBOOK_FLYOUT_STANCES = "Stances",
	SPELLBOOK_FLYOUT_STANCES_DESC = "Activate a combat stance.",
	SPELLBOOK_FLYOUT_SUMMON_DEMON = "Summon Demon",
	SPELLBOOK_FLYOUT_SUMMON_DEMON_DESC = "Summons a Demon under the command of the Warlock",
	SPELLBOOK_FLYOUT_TELEPORT = "Teleport",
	SPELLBOOK_FLYOUT_TELEPORT_DESC = "Teleports you to a major city.",
	SPELLBOOK_FLYOUT_TRACKING = "Tracking",
	SPELLBOOK_FLYOUT_TRACKING_DESC = "Track your quarry.",
	SPELLBOOK_FLYOUT_UTILITY_BLESSINGS = "Utility Blessings",
	SPELLBOOK_FLYOUT_UTILITY_BLESSINGS_DESC = "Short duration Blessings used to save a single target.",
	SPELLBOOK_HIDE_PASSIVES = "Hide Passives",
	SPELLBOOK_HIDE_PASSIVES_DISABLED = "Hiding Passives is disabled while searching",
	SPELLBOOK_PAGE = "Page %d/%d",
	SPELLBOOK_USE_FLYOUTS = "Group Similar Spells on Flyouts",

	-- SpellBookSearch.lua
	SPELLBOOKSEARCH_HEADER_DESCRIPTION = "Description Matches",
	SPELLBOOKSEARCH_HEADER_EXACT = "Exact Matches",
	SPELLBOOKSEARCH_HEADER_GENERIC = "Matches",
	SPELLBOOKSEARCH_HEADER_NAME = "Name Matches",
	SPELLBOOKSEARCH_HEADER_RELATED = "Related Matches",
	SPELLBOOKSEARCH_INSTRUCTIONS = "Search abilities, keywords",
	SPELLBOOKSEARCH_NOT_ON_ACTIONBAR = "Missing from action bar",
	SPELLBOOKSEARCH_PREVIEW_OVERFLOW = "And %s more",

	-- Stable.lua (the pet's specialization, as the client names it)
	STABLE_TALENT_CUNNING = "Cunning",
	STABLE_TALENT_FEROCITY = "Ferocity",
	STABLE_TALENT_TENACITY = "Tenacity",

	-- StanceBar.lua
	STANCEBAR_EDIT_LABEL = "Stance Bar",

	-- StatusBars.lua
	STATUSBARS_DEBUG_STATE = "   level %s, max level %s, xp to earn %s | reputation default y=%s, saved y=%s, user placed %s",
	STATUSBARS_DEBUG = "status bars: row %.1f -> %.1f, top %s | width %.0f | xp visible=%s at y=%s | reputation visible=%s at y=%s",
	STATUSBARS_EDIT_LABEL_EXPERIENCE = "Experience Bar",
	STATUSBARS_EDIT_LABEL_REPUTATION = "Reputation Bar",

	-- TabardFrame.lua
	TABARDFRAME_POSITION_USAGE = "tabard: /fui tabard position <depth> <lateral> <height>",
	TABARDFRAME_STATE = "tabard: camera=%s scale=%s position=(%s, %s, %s)",
	TABARDFRAME_USAGE = "tabard: camera <n> | echelle <s> | position <x> <y> <z> | defaut | client",

	-- Talents.lua
	TALENTS_APPLY_CHANGES = "Apply Changes",
	TALENTS_CONFIRM_CLOSE = "You will lose any pending changes if you continue.",
	TALENTS_GATE_TOOLTIP = "Spend %d more points to unlock this row",
	TALENTS_INSPECT_TITLE = "%s's Talents",
	TALENTS_SPEC_ACTIVE = "Active",
	TALENTS_SPEC_PRIMARY = "Primary",
	TALENTS_SPEC_SECONDARY = "Secondary",
	TALENTS_UNDO_PENDING_CHANGES = "Undo Pending Changes",
	TALENTS_UNSPENT_POINTS = "Unspent Talents",

	-- TalentsSearch.lua
	TALENTSSEARCH_HIDE_PASSIVES = "Hide Passives",
	TALENTSSEARCH_NOT_ON_ACTIONBAR = "Missing from action bar",
	TALENTSSEARCH_PREVIEW_OVERFLOW = "And %s more",
	TALENTSSEARCH_SHOW_RANKS = "Show Ranks",
	TALENTSSEARCH_TOOLTIP_EXACT_MATCH = "Exact search match",
	TALENTSSEARCH_TOOLTIP_MATCH = "Search match",
	TALENTSSEARCH_TOOLTIP_NOT_ON_ACTIONBAR = "Not on action bar",
	TALENTSSEARCH_TOOLTIP_ON_DISABLED_ACTIONBAR = "On a disabled action bar",
	TALENTSSEARCH_TOOLTIP_ON_INACTIVE_BONUSBAR = "On an action bar belonging to a different stance",
	TALENTSSEARCH_TOOLTIP_RELATED_MATCH = "Related to the talent you searched for",

	-- TargetFrame.lua
	TARGETFRAME_EDIT_LABEL = "Target Frame",

	-- Taxi.lua
	TAXI_TITLE = "Flight Map",

	-- Titles.lua
	TITLES_DEBUG_ABSENT = "absent",
	TITLES_DEBUG_HIDDEN = "hidden",
	TITLES_DEBUG_SUMMARY = "titles: %d known + None, worn=%s, offset=%d, %d row(s) that fit",
	TITLES_DEBUG_VISIBLE = "VISIBLE",

	-- TokensTab.lua
	TOKENSTAB_DEBUG_CLIENT = "client: selectedToken=%s selectedID=%s | screen=%s",
	TOKENSTAB_DEBUG_ROW = "   %2d %-28s %s count=%-8s special=%-4s watched=%-5s unused=%s",
	TOKENSTAB_DEBUG_SUMMARY = "currencies: %d in the list, offset %d, %d placed, selected=%s",

	-- TradeSkill.lua
	TRADESKILL_CHECK_ALL = "Check All",
	TRADESKILL_CREATE_ALL_FORMAT = "%s [%d]",
	TRADESKILL_FILTER_SKILL_UP = "Has skill up",
	TRADESKILL_FILTER_SLOTS = "Slots",
	TRADESKILL_NAME_RANK = "%s %d/%d",
	TRADESKILL_NAME_RANK_MODIFIER = "%s %d (|cff20ff20+%d|r ) /%d",
	TRADESKILL_NO_RESULTS = "There are no results with your current filters.",
	TRADESKILL_REAGENT_COUNT = "%s/%d",
	TRADESKILL_REAGENTS = "Reagents:",
	TRADESKILL_SKILL_UP_EASY = "Low chance of gaining skill",
	TRADESKILL_SKILL_UP_MEDIUM = "High chance of gaining skill",
	TRADESKILL_SKILL_UP_OPTIMAL = "Guaranteed chance of gaining %d skill ups",
	TRADESKILL_UNCHECK_ALL = "Uncheck All",

	-- Trainer.lua
	TRAINER_RANK = "%d/%d",
	TRAINER_RANK_BONUS = "%d |cff20ff20(+%d)|r/%d",

	-- WorldMap.lua
	WORLDMAP_CURSOR_COORDS = "Cursor: %d, %d",
	WORLDMAP_DEBUG_BREADCRUMB = "breadcrumb: ",
	WORLDMAP_DEBUG_DETAIL = "map %.0f x %.0f at interface scale %.4f -> %.1f x %.1f",
	WORLDMAP_DEBUG_FLOORS = "floors: %d | built: %s | panel: %s",
	WORLDMAP_DEBUG_FRAME = "world map: %.0f x %.0f at scale %.4f, mode %s (client size %.4f, small window %.4f)",
	WORLDMAP_DEBUG_LANDMARK = "landmark %d: %s (%s) icon %s, link %s, instance map %s",
	WORLDMAP_DEBUG_MISSING = "world map: missing.",
	WORLDMAP_DEBUG_MODE_FULLSCREEN = "fullscreen",
	WORLDMAP_DEBUG_MODE_WINDOWED = "windowed",
	WORLDMAP_DEBUG_MOVABLE = "movable: %s (advancedWorldMap %s, lock %s)",
	WORLDMAP_DEBUG_NO_ATLAS = "world map: AtlasUtil.lua is missing, nothing is skinned.",
	WORLDMAP_DEBUG_NO_FRAME = "world map: the client has no WorldMapFrame.",
	WORLDMAP_DEBUG_WORLD_REFUSED = "world map: \"World\" refused by the client (map %s, continent %s, zone %s, floor %s, zoom out %s)",
	WORLDMAP_FILTER_SHOW = "Show:",
	WORLDMAP_PLAYER_COORDS = "Player: %d, %d",
	WORLDMAP_TITLE = "Map & Quest Log",
	WORLDMAP_WORLD = "World",
})
