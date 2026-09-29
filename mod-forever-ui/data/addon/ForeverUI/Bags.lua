-- ForeverUI: bag windows in the Camelot style (mainline ContainerFrameMixin geometry).
-- 3.3.5 has no C_Container.SetItemSearch: search matches name, type and subtype in Lua and
-- veils the rest (searchOverlay, black at 80 %). Nor C_Container.SortBags: items move one by
-- one, ordered by GetAuctionItemClasses, then quality, name and stack size.

-- Bag window settings, from ContainerFrameMixin (mainline/containerframe.lua).
-- Height = rows x slot + (rows - 1) x cellGap + GetPaddingHeight() + CalculateExtraHeight(),
-- so the window follows its contents; the width is the constant CONTAINER_WIDTH.
-- /fui bags prints computed and actual sizes; /fui bags <key> <value> tries a value.
local R = {
	-- Grid
	slot = 37,       -- ContainerFrameItemButtonTemplate
	cellGap = 5,         -- ITEM_SPACING_X and ITEM_SPACING_Y
	columns = 4,           -- GetColumns()
	width = 178,          -- CONTAINER_WIDTH

	-- Height
	-- camelot uses 9 for GetFirstButtonOffsetY(); with its metal border drawn here that leaves
	-- only 1.5 below the last row (7.5 left, 6 right). 6 more evens out the four sides.
	firstButtonY = 15,    -- camelot 9
	firstButtonX = -7,    -- GetInitialItemAnchor()
	header = 48,            -- GetPaddingHeight(): "titlebar and attic"
	searchStrip = 30,    -- same, + 30 on the backpack

	-- Purse, and the backpack grid anchored to it
	purseHeight = 13,     -- UpdateMoneyFrame()
	purseSide = 8,         -- UpdateCurrencyFrames()
	purseBottom = 14,         -- camelot 8, raised by the same 6
	purseGridGap = 4,  -- ContainerFrameBackpackMixin:GetInitialItemAnchor()
	purseFrame = 17,       -- camelot's border overhangs the purse

	-- Watched currencies strip, below the purse
	-- ContainerFrameTokenWatcherMixin:UpdateCurrencyFrames: the strip takes the bottom
	-- (BOTTOMLEFT (8, 8), BOTTOMRIGHT (-8, 8)) and the purse sits on its TOP, (0, 3).
	-- CalculateExtraHeight adds the strip height. Tokens chain leftwards from GetInitialTokenAnchor.
	tokenHeight = 17,      -- BackpackTokenFrameTemplate
	tokenSide = 8,          -- UpdateCurrencyFrames()
	tokenGap = 3,         -- gap between the strip and the purse above it
	tokenWidth = 50,      -- BackpackTokenTemplate
	tokenPiece = 12,        -- its height, and the icon's
	tokenIconX = 4,
	tokenIconY = 1,
	tokenOriginX = -17,     -- GetInitialTokenAnchor()
	tokenOriginY = -1,

	-- Attic
	-- Top-anchored, so the box and the sort button move down by the 6 the window grew.
	fieldWidth = 96,      -- SetSearchBoxPoint()
	fieldHeight = 18,
	fieldX = 42,
	fieldY = -43,           -- camelot -37
	sortWidth = 28,
	sortHeight = 26,
	sortX = -9,              -- UpdateSearchBox()
	sortY = -40,             -- camelot -34

	-- Frame decorations
	titleLeft = 35,       -- SetTitleOffsets(35): left edge of the title
	titleRight = -24,      -- SetTitleOffsets default
	titleContainer = -1,    -- TitleContainer: TOPLEFT / TOPRIGHT at -1
	titleStripHeight = 20,        -- its height
	titleText = -5,        -- TitleText: TOP (0, -5) in the container
	closeSize = 24,
	closeX = 1,
	closeY = 0,
	-- Portrait: 3.3.5 does not mask icons; as for its minimap buttons, the ring's opaque metal
	-- hides the corners of a square icon. camelot's ring is clear up to 10.3 px from the centre,
	-- fades up to 14.3 and is opaque up to 20.4, so the side must be >= 28.6 (edges cover the
	-- fade) and <= 28.8 (corners stay under the metal): 28.
	portrait = 28,
	portraitX = 14,         -- centre of the ring, measured on its art
	portraitY = -17,        -- and centre of the source portrait

	-- Bag stacking (UpdateContainerFrameAnchors)
	bagGap = 8,          -- CONTAINER_SPACING
	columnGap = -11,    -- column step
	rightEdge = 10,         -- GetInitialContainerFrameOffsetX, bars excluded
	bottomEdge = 85,           -- CONTAINER_OFFSET_Y
	topMargin = 8,         -- margin below the top of the screen (not in the source)

	-- Overall
	scale = 1,            -- 1 = camelot size; 1.25 = a quarter larger
}
ForeverUI = ForeverUI or {}

local FRAME_COUNT = NUM_CONTAINER_FRAMES or 13
local BAGS = { 0, 1, 2, 3, 4 }          -- backpack and the four equipped bags

-- Lua 5.1 reads backslashes as escapes: the separator is built from its char code.
local SEP = string.char(92)
local SQUARE_HOVER = "Interface" .. SEP .. "Buttons" .. SEP .. "ButtonHilight-Square"
local QUALITY_FRAME = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "whiteiconframe"

-- UpdateMiscellaneousFrames: the backpack shows INV_Misc_Bag_08, the keyring its own icon,
-- an equipped bag its item icon. Icons are 64 px with a 4 px dark border.
local ICON_BORDER = 4 / 64

local BACKPACK_PORTRAIT = "Interface" .. SEP .. "Icons" .. SEP .. "INV_Misc_Bag_08"
-- camelot's "Interface/Icons/ui-hud-actionbar-keyring" does not exist in 3.3.5; this is the
-- client's keyring icon.
local KEYRING_PORTRAIT = "Interface" .. SEP .. "ContainerFrame" .. SEP .. "KeyRing-Bag-Icon"

-- camelot frames every slot, full or empty, in dark gray (0.39, measured on a screenshot).
-- The quality color takes over from uncommon.
local FRAME_GRAY = 0.39
local TINTED_QUALITY = 2

local L = ForeverUI.L
local CLEANUP_TEXT = L.BAGS_CLEANUP
local CLEANUP_TOOLTIP = L.BAGS_CLEANUP_TOOLTIP

ForeverUI = ForeverUI or {}

-- ------------------------------------------------------------ frames
local frames = {}

local function skinButton(button)
	if not button or button.foreverSkinned then
		return
	end

	local name = button:GetName()

	-- SetItemButtonTexture_Base: an empty slot shows emptyBackgroundAtlas on the icon itself,
	-- never as a second texture. The 3.3.5 slot art is hidden.
	local normalFont = button:GetNormalTexture()
	if normalFont then
		normalFont:SetAlpha(0)
	end

	local hover = button:GetHighlightTexture()
	if hover then
		hover:SetTexture(SQUARE_HOVER)
		hover:SetBlendMode("ADD")
		hover:ClearAllPoints()
		hover:SetAllPoints(button)
	end

	local icon = _G[name .. "IconTexture"]
	if icon then
		icon:ClearAllPoints()
		icon:SetAllPoints(button)
		icon:SetTexCoord(0, 1, 0, 1)
		icon:SetDrawLayer("BORDER")
	end

	-- Item outline: WhiteIconFrame tinted by quality, as in SetItemButtonQuality_Base.
	local outline = button:CreateTexture(nil, "OVERLAY")
	outline:SetTexture(QUALITY_FRAME)
	outline:SetAllPoints(button)
	outline:SetVertexColor(FRAME_GRAY, FRAME_GRAY, FRAME_GRAY)
	button.foreverOutline = outline

	-- Search veil: black at 80 % over the whole button, as on the source ItemButton.
	local veil = button:CreateTexture(nil, "OVERLAY")
	veil:SetTexture(0, 0, 0, 0.8)
	veil:SetAllPoints(button)
	veil:Hide()
	button.foreverVeil = veil

	button.foreverSkinned = true
end

local function skinFrame(frame)
	if not frame or frame.foreverSkinned then
		return
	end

	local name = frame:GetName()

	-- 3.3.5 background art: four stacked pieces plus the one-slot version.
	-- ContainerFrame_GenerateFrame re-shows and retextures them on each open but keeps their alpha.
	for _, suffix in ipairs({ "BackgroundTop", "BackgroundMiddle1", "BackgroundMiddle2",
		"BackgroundBottom", "Background1Slot" }) do
		local texture = _G[name .. suffix]
		if texture then
			texture:SetAlpha(0)
		end
	end

	ForeverUI.SetPanelArt(frame)

	-- The client portrait is replaced by an icon cut round by the ring, not masked.
	local old = _G[name .. "Portrait"]
	if old then
		old:SetAlpha(0)
	end

	-- BORDER layer: always above the panel background (BACKGROUND) and below the metal
	-- (OVERLAY), whatever the creation order.
	local portrait = frame:CreateTexture(nil, "BORDER")
	portrait:SetWidth(R.portrait)
	portrait:SetHeight(R.portrait)
	portrait:SetPoint("CENTER", frame, "TOPLEFT", R.portraitX, R.portraitY)
	frame.foreverPortrait = portrait

	-- TitledPanelMixin:SetTitleOffsets(35) and TitleContainer: a 20 px frame from 35 to
	-- width - 24, text at TOP (0, -5), so the title centres between portrait and close button.
	-- A child frame, because the HeldBagLayout metal (OVERLAY) would cover a region of the bag
	-- frame. The client title is hidden.
	local oldTitle = _G[name .. "Name"]
	if oldTitle then
		oldTitle:SetAlpha(0)
	end

	local titleStrip = CreateFrame("Frame", nil, frame)
	titleStrip:SetFrameLevel(frame:GetFrameLevel() + 2)
	titleStrip:SetHeight(R.titleStripHeight)
	titleStrip:SetPoint("TOPLEFT", frame, "TOPLEFT", R.titleLeft, R.titleContainer)
	titleStrip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", R.titleRight, R.titleContainer)
	local title = titleStrip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", titleStrip, "TOP", 0, R.titleText)
	title:SetPoint("LEFT", titleStrip, "LEFT")
	title:SetPoint("RIGHT", titleStrip, "RIGHT")
	title:SetJustifyH("CENTER")
	frame.foreverTitleStrip = titleStrip
	frame.foreverTitle = title

	-- Close button: 24 x 24, TOPRIGHT (1, 0), the red X of modern panels
	-- (UIPanelCloseButtonNoScripts, atlas RedButton-Exit).
	local close = _G[name .. "CloseButton"]
	if close then
		close:SetWidth(R.closeSize)
		close:SetHeight(R.closeSize)
		close:ClearAllPoints()
		close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", R.closeX, R.closeY)
		for atlas, method in pairs({ ["redbutton-exit"] = "GetNormalTexture",
			["redbutton-exit-pressed"] = "GetPushedTexture",
			["redbutton-exit-disabled"] = "GetDisabledTexture",
			["redbutton-highlight"] = "GetHighlightTexture" }) do
			local texture = close[method] and close[method](close)
			if texture then
				ForeverUI.SetAtlas(texture, atlas, true)
				texture:ClearAllPoints()
				texture:SetAllPoints(close)
				if atlas == "redbutton-highlight" then
					texture:SetBlendMode("ADD")
				end
			end
		end
	end

	for index = 1, MAX_CONTAINER_ITEMS do
		skinButton(_G[name .. "Item" .. index])
	end

	frame.foreverSkinned = true
	table.insert(frames, frame)
end

-- ---------------------------------------------------------- search
local Search = { text = "" }
ForeverUI.BagSearch = Search

-- Item name, type and subtype. An uncached item still has its name in the link.
local function itemInfoOf(link)
	if not link then
		return nil
	end
	local name, _, _, _, _, type_, subType = GetItemInfo(link)
	if name then
		return name, type_, subType
	end
	return string.match(link, "%[(.+)%]")
end

function Search.Matches(link)
	if Search.text == "" then
		return true
	end
	if not link then
		return false
	end

	local name, type_, subType = itemInfoOf(link)
	for _, field in ipairs({ name, type_, subType }) do
		if field and string.find(string.lower(field), Search.text, 1, true) then
			return true
		end
	end
	return false
end

-- SetItemButtonTexture_Base: one texture holds either the item or the empty-slot background.
-- 3.3.5 hides the icon of an empty slot, so it is shown again with the atlas.
-- texture: item icon, or nil for an empty slot.
local function placeIcon(button, texture)
	local icon = _G[button:GetName() .. "IconTexture"]
	if not icon then
		return
	end

	if texture then
		icon:SetTexture(texture)
		icon:SetTexCoord(0, 1, 0, 1)
	else
		ForeverUI.SetAtlas(icon, "bags-item-slot64", true)
	end
	icon:Show()
end

function Search.Apply(frame)
	local name = frame:GetName()
	local bag = frame:GetID()
	for index = 1, frame.size or 0 do
		local button = _G[name .. "Item" .. index]
		if button and button.foreverVeil then
			local slot = button:GetID()
			local link = GetContainerItemLink(bag, slot)
			placeIcon(button, GetContainerItemInfo(bag, slot))

			if link and not Search.Matches(link) then
				button.foreverVeil:Show()
			else
				button.foreverVeil:Hide()
			end

			-- The outline is always shown; it takes the quality color from uncommon up.
			local outline = button.foreverOutline
			if outline then
				local quality = select(4, GetContainerItemInfo(bag, slot))
				local color = link and quality and quality >= TINTED_QUALITY
					and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
				if color then
					outline:SetVertexColor(color.r, color.g, color.b)
				else
					outline:SetVertexColor(FRAME_GRAY, FRAME_GRAY, FRAME_GRAY)
				end
				outline:Show()
			end
		end
	end
end

-- Veils the keyring button when no keyring item matches the search
-- (camelot BaseBagSlotButtonMixin:UpdateBagMatchesSearch). No search, no veil.
function Search.Keyring()
	local b = KeyRingButton
	if not b then
		return
	end
	if not b.foreverVeil then
		local veil = b:CreateTexture(nil, "OVERLAY")
		veil:SetTexture(0, 0, 0, 0.8)
		veil:SetAllPoints(b)
		veil:Hide()
		b.foreverVeil = veil
	end
	local match = Search.text == ""
	if not match then
		local bag = KEYRING_CONTAINER or -2
		for slot = 1, GetContainerNumSlots(bag) or 0 do
			local link = GetContainerItemLink(bag, slot)
			if link and Search.Matches(link) then
				match = true
				break
			end
		end
	end
	if match then b.foreverVeil:Hide() else b.foreverVeil:Show() end
end

function Search.All()
	for _, frame in ipairs(frames) do
		if frame:IsShown() then
			Search.Apply(frame)
		end
	end
	Search.Keyring()
end

function Search.Set(text)
	Search.text = string.lower(text or "")
	Search.All()
end

-- -------------------------------------------------------------- sort
-- Categories keep the game's order, as listed by GetAuctionItemClasses.
local Sort = { queue = {}, active = false }
ForeverUI.BagSort = Sort

local classRank

-- classRank: item class name -> its rank in GetAuctionItemClasses.
local function buildRanks()
	if classRank then
		return
	end
	classRank = {}
	if GetAuctionItemClasses then
		local classes = { GetAuctionItemClasses() }
		for index, name in ipairs(classes) do
			classRank[name] = index
		end
	end
end

-- Item in a bag slot with its sort keys; nil when the slot is empty.
local function readCell(bag, slot)
	local link = GetContainerItemLink(bag, slot)
	if not link then
		return nil
	end
	local _, count, locked = GetContainerItemInfo(bag, slot)
	local name, _, quality, _, _, type_, subType, maxStack = GetItemInfo(link)
	return {
		link = link,
		count = count or 1,
		locked = locked,
		name = name or string.match(link, "%[(.+)%]") or link,
		quality = quality or 0,
		className = classRank[type_ or ""] or 99,
		subType = subType or "",
		maxStack = maxStack or 1,
	}
end

-- Sort order: class, subtype, quality (best first), name, then larger stacks first.
local function before(a, b)
	if a.className ~= b.className then
		return a.className < b.className
	end
	if a.subType ~= b.subType then
		return a.subType < b.subType
	end
	if a.quality ~= b.quality then
		return a.quality > b.quality
	end
	if a.name ~= b.name then
		return a.name < b.name
	end
	return a.count > b.count
end

-- Current bag state: one cell per slot, in order.
local function collect()
	local cells = {}
	for _, bag in ipairs(Sort.bags or BAGS) do
		for slot = 1, (GetContainerNumSlots(bag) or 0) do
			table.insert(cells, {
				bag = bag,
				slot = slot,
				object = readCell(bag, slot),
			})
		end
	end
	return cells
end

local function locked(cell)
	local _, _, isLocked = GetContainerItemInfo(cell.bag, cell.slot)
	return isLocked
end

-- Makes one move per call; returns true while work remains. The server must confirm each
-- move before the next, otherwise the slot is still locked.
local function doStep()
	local cells = collect()

	-- 1. merge partial stacks of the same item
	for i = 1, #cells do
		local a = cells[i].object
		if a and a.count < a.maxStack then
			for j = i + 1, #cells do
				local b = cells[j].object
				if b and b.link == a.link and b.count < b.maxStack then
					if locked(cells[i]) or locked(cells[j]) then
						return true
					end
					PickupContainerItem(cells[j].bag, cells[j].slot)
					PickupContainerItem(cells[i].bag, cells[i].slot)
					return true
				end
			end
		end
	end

    -- 2. order: cell i must hold the i-th sorted item
	local objects = {}
	for _, cell in ipairs(cells) do
		if cell.object then
			table.insert(objects, cell.object)
		end
	end
	table.sort(objects, before)

	for i = 1, #cells do
		local wanted = objects[i]
		local present = cells[i].object
		local sameItem = (wanted == nil and present == nil)
			or (wanted and present and wanted.link == present.link and wanted.count == present.count)
		if not sameItem then
			if wanted == nil then
				return false        -- nothing left to place
			end
			-- find the cell holding the wanted item
			for j = i + 1, #cells do
				local candidate = cells[j].object
				if candidate and candidate.link == wanted.link and candidate.count == wanted.count then
					if locked(cells[i]) or locked(cells[j]) then
						return true
					end
					PickupContainerItem(cells[j].bag, cells[j].slot)
					PickupContainerItem(cells[i].bag, cells[i].slot)
					return true
				end
			end
			return false            -- not found: stop rather than loop
		end
	end

	return false                    -- everything in place
end

local MAX_STEPS = 400
local timeSinceStep = 0

local clock = CreateFrame("Frame", "ForeverUIBagSortTicker")
clock:Hide()
clock:SetScript("OnUpdate", function(self, elapsed)
	timeSinceStep = timeSinceStep + elapsed
	if timeSinceStep < 0.1 then
		return
	end
	timeSinceStep = 0

	Sort.steps = (Sort.steps or 0) + 1
	if Sort.steps > MAX_STEPS or not doStep() then
		Sort.active = false
		self:Hide()
		Search.All()
	end
end)

-- bags: bag ids to sort (the bank, Bank.lua); defaults to the player's bags
function Sort.Start(bags)
	if Sort.active then
		return
	end
	Sort.bags = bags
	if CursorHasItem() then
		ClearCursor()
	end
	buildRanks()
	Sort.active = true
	Sort.steps = 0
	timeSinceStep = 0
	clock:Show()
end

-- ------------------------------------------- search box and sort button
local field = CreateFrame("EditBox", "ForeverUIBagSearchBox", UIParent, "InputBoxTemplate")
field:SetWidth(R.fieldWidth)
field:SetHeight(R.fieldHeight)
field:SetAutoFocus(false)
field:SetMaxLetters(15)
field:SetTextInsets(16, 20, 0, 0)
field:Hide()

local magnifier = field:CreateTexture(nil, "OVERLAY")
ForeverUI.SetAtlas(magnifier, "common-search-magnifyingglass", true)
magnifier:SetWidth(10)
magnifier:SetHeight(10)
magnifier:SetPoint("LEFT", field, "LEFT", 1, -1)

local placeholder = field:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
placeholder:SetPoint("LEFT", field, "LEFT", 16, 0)
placeholder:SetText(SEARCH)

local clear = CreateFrame("Button", nil, field)
clear:SetWidth(17)
clear:SetHeight(17)
clear:SetPoint("RIGHT", field, "RIGHT", -3, 0)
clear:Hide()
local closeButton = clear:CreateTexture(nil, "ARTWORK")
ForeverUI.SetAtlas(closeButton, "common-search-clearbutton", true)
closeButton:SetWidth(10)
closeButton:SetHeight(10)
closeButton:SetPoint("TOPLEFT", clear, "TOPLEFT", 3, -3)
closeButton:SetAlpha(0.5)
clear:SetScript("OnEnter", function() closeButton:SetAlpha(1) end)
clear:SetScript("OnLeave", function() closeButton:SetAlpha(0.5) end)
clear:SetScript("OnClick", function()
	field:SetText("")
	field:ClearFocus()
end)

local function updateField()
	local text = field:GetText() or ""
	if text == "" and not field:HasFocus() then
		placeholder:Show()
	else
		placeholder:Hide()
	end
	if text == "" then
		clear:Hide()
	else
		clear:Show()
	end
end

field:SetScript("OnTextChanged", function(self)
	updateField()
	Search.Set(self:GetText())
end)
field:SetScript("OnEditFocusGained", updateField)
field:SetScript("OnEditFocusLost", updateField)
field:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
field:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

-- BagSearch_OnChar: four identical characters in a row release the focus, so a held key
-- does not trap the player in the box.
field:SetScript("OnChar", function(self)
	local text = self:GetText() or ""
	if string.len(text) >= 4 then
		local repeated = true
		for i = 1, 3 do
			if string.sub(text, -i, -i) ~= string.sub(text, -1 - i, -1 - i) then
				repeated = false
				break
			end
		end
		if repeated then
			self:ClearFocus()
		end
	end
end)

local sortButton = CreateFrame("Button", "ForeverUIBagSortButton", UIParent)
sortButton:SetWidth(R.sortWidth)
sortButton:SetHeight(R.sortHeight)
sortButton:Hide()

-- 3.3.5: SetNormalTexture and the like take only a file path; a texture object raises an
-- error. So the sheet path is set first, then the atlas is applied to the created texture.
-- place, getter: setter and getter names; width, height: optional centred size; add: ADD blend
local function applyState(button, place, getter, atlas, width, height, add)
	local e = ForeverUI.AtlasEntry(atlas)
	if not e then
		return nil
	end

	button[place](button, e[1])
	local texture = button[getter](button)
	if not texture then
		return nil
	end

	ForeverUI.SetAtlas(texture, atlas, true)
	texture:ClearAllPoints()
	if width then
		texture:SetWidth(width)
		texture:SetHeight(height)
		texture:SetPoint("CENTER")
	else
		texture:SetAllPoints(button)
	end
	if add then
		texture:SetBlendMode("ADD")
	end
	return texture
end

applyState(sortButton, "SetNormalTexture", "GetNormalTexture", "bags-button-autosort-up")
applyState(sortButton, "SetPushedTexture", "GetPushedTexture", "bags-button-autosort-down")

-- The highlight is a client file, not an atlas entry: 24 x 23, centred.
sortButton:SetHighlightTexture(SQUARE_HOVER)
local sortHighlight = sortButton:GetHighlightTexture()
if sortHighlight then
	sortHighlight:SetBlendMode("ADD")
	sortHighlight:ClearAllPoints()
	sortHighlight:SetWidth(24)
	sortHighlight:SetHeight(23)
	sortHighlight:SetPoint("CENTER")
end

sortButton:SetScript("OnClick", function()
	Sort.Start()
end)
sortButton:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText(CLEANUP_TEXT, 1, 1, 1)
	GameTooltip:AddLine(CLEANUP_TOOLTIP, nil, nil, nil, true)
	GameTooltip:Show()
end)
sortButton:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

-- ------------------------------------------------------------ measures
-- ContainerFrameMixin:GetRows, CalculateWidth, CalculateHeight, GetPaddingHeight,
-- CalculateExtraHeight and their backpack overrides. The height derives from the row count,
-- never from a chain of anchors.
local function measure(frame)
	local size = frame.size or 0
	local m = { isBackpack = frame:GetID() == 0 }

	m.rowLines = math.ceil(size / R.columns)                      -- GetRows()
	m.grid = m.rowLines * R.slot + (m.rowLines - 1) * R.cellGap

	-- GetPaddingHeight(): bottom of the first button plus title and attic; the backpack adds the
	-- search box strip.
	m.overhead = R.firstButtonY + R.header
	if m.isBackpack then
		m.overhead = m.overhead + R.searchStrip
	end

	-- CalculateExtraHeight(): the purse, on the backpack only, plus the watched currencies strip
	-- when there is one.
	m.tokens = m.isBackpack and ForeverUI.BagsWatchedCount() or 0
	m.extra = m.isBackpack and R.purseHeight or 0
	if m.tokens > 0 then
		m.extra = m.extra + R.tokenHeight + R.tokenGap
	end

	m.height = m.grid + m.overhead + m.extra                       -- CalculateHeight()
	m.width = R.width                                           -- CalculateWidth()
	return m
end

-- ContainerFrameMixin:UpdateSearchBox: the search box and sort button show only on the
-- backpack.
local function layoutTools()
	local host
	for _, frame in ipairs(frames) do
		if frame:IsShown() and frame:GetID() == 0 then
			host = frame
			break
		end
	end

	if not host then
		field:Hide()
		sortButton:Hide()
		-- BagSearch_OnHide: no search box visible, so the search is cleared.
		if field:GetText() ~= "" then
			field:SetText("")
		end
		return
	end

	-- Both are anchored to the top, as in the source: the attic has a fixed height.
	field:SetParent(host)
	field:ClearAllPoints()
	field:SetWidth(R.fieldWidth)
	field:SetHeight(R.fieldHeight)
	field:SetPoint("TOPLEFT", host, "TOPLEFT", R.fieldX, R.fieldY)
	field:Show()

	sortButton:SetParent(host)
	sortButton:ClearAllPoints()
	sortButton:SetWidth(R.sortWidth)
	sortButton:SetHeight(R.sortHeight)
	sortButton:SetPoint("TOPRIGHT", host, "TOPRIGHT", R.sortX, R.sortY)
	sortButton:Show()
end

-- Purse border: two ends and a stretched middle, 17 high.
local function skinPurse(purse)
	if not purse or purse.foreverBordered then
		return
	end

	purse:SetHeight(R.purseHeight)

	local left = purse:CreateTexture(nil, "BACKGROUND")
	if not ForeverUI.SetAtlas(left, "common-coinbox-left", true) then
		left:Hide()
		return
	end
	left:SetWidth(R.purseFrame / 2)
	left:SetHeight(R.purseFrame)
	left:SetPoint("LEFT", purse, "LEFT", 0, 0)

	local right = purse:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(right, "common-coinbox-right", true)
	right:SetWidth(R.purseFrame / 2)
	right:SetHeight(R.purseFrame)
	right:SetPoint("RIGHT", purse, "RIGHT", 0, 0)

	local middle = purse:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(middle, "_common-coinbox-center", true)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

	purse.foreverBordered = true
end

-- ------------------------------------------- watched currencies, below the purse
-- GetBackpackCurrencyInfo(i) gives name, count, typeSpecial, icon and item id, i up to
-- MAX_WATCHED_TOKENS (3). As in the currency tab, typeSpecial 1 (arena points) and 2 (honor,
-- per faction, cropped to 0.03125 .. 0.59375) have their own icons.
local ARENA_TOKEN = "Interface\\PVPFrame\\PVP-ArenaPoints-Icon"
local HONOR_TOKEN = "Interface\\TargetingFrame\\UI-PVP-%s"
local TOKEN_CORNER, TOKEN_SIDE = 0.03125, 0.59375

-- Token count font: GameFontHighlight, one size larger than camelot's GameFontHighlightSmall.
-- The count is anchored LEFT and RIGHT (not TOPLEFT) so it stays centred on the icon.
local TOKEN_FONT = "GameFontHighlight"

local function readTokens()
	local list = {}
	local maximum = MAX_WATCHED_TOKENS or 3
	for rank = 1, maximum do
		local name, count, special, icon = nil, nil, nil, nil
        if GetBackpackCurrencyInfo then
            name, count, special, icon = GetBackpackCurrencyInfo(rank)
        end
		if name then
			list[#list + 1] = {
				name = name, count = count or 0,
				special = special, icon = icon,
			}
		end
	end
	return list
end

-- Number of watched currencies. Read from the data, not the screen: the window height is
-- computed before the strip is laid out.
function ForeverUI.BagsWatchedCount()
	return #readTokens()
end

local function placeTokenIcon(texture, data)
	if data.special == 1 then
		texture:SetTexture(ARENA_TOKEN)
		texture:SetTexCoord(0, 1, 0, 1)
	elseif data.special == 2 then
		local faction = UnitFactionGroup and UnitFactionGroup("player")
		if faction then
			texture:SetTexture(string.format(HONOR_TOKEN, faction))
			texture:SetTexCoord(TOKEN_CORNER, TOKEN_SIDE, TOKEN_CORNER, TOKEN_SIDE)
		else
			texture:SetTexture("")
			texture:SetTexCoord(0, 1, 0, 1)
		end
	else
		texture:SetTexture(data.icon or "")
		texture:SetTexCoord(0, 1, 0, 1)
	end
end

-- Creates the backpack's currency strip once.
local function setupSegment(frame)
	if frame.foreverSegment then
		return frame.foreverSegment
	end

	local segment = CreateFrame("Frame", "ForeverUIBagTokens", frame)
	segment:SetHeight(R.tokenHeight)

	-- Border: two 8 x 17 ends and a stretched middle, cut like the purse.
	local left = segment:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(left, "common-currencybox-left", true)
	left:SetWidth(R.tokenSide)
	left:SetHeight(R.tokenHeight)
	left:SetPoint("LEFT", segment, "LEFT", 0, 0)

	local right = segment:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(right, "common-currencybox-right", true)
	right:SetWidth(R.tokenSide)
	right:SetHeight(R.tokenHeight)
	right:SetPoint("RIGHT", segment, "RIGHT", 0, 0)

	local middle = segment:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(middle, "_common-currencybox-center", true)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

	segment.tokens = {}
	for rank = 1, (MAX_WATCHED_TOKENS or 3) do
		local token = CreateFrame("Button", "ForeverUIBagToken" .. rank, segment)
		token:SetWidth(R.tokenWidth)
		token:SetHeight(R.tokenPiece)

		local icon = token:CreateTexture(nil, "ARTWORK")
		icon:SetWidth(R.tokenPiece)
		icon:SetHeight(R.tokenPiece)
		icon:SetPoint("RIGHT", token, "RIGHT", R.tokenIconX, R.tokenIconY)
		token.icon = icon

		local count = token:CreateFontString(nil, "ARTWORK", TOKEN_FONT)
		count:SetJustifyH("RIGHT")
		count:SetPoint("LEFT", token, "LEFT", 0, 0)
		count:SetPoint("RIGHT", icon, "LEFT", 0, 0)
		token.count = count

		-- Tokens chain leftwards from the right edge.
		if rank == 1 then
			token:SetPoint("RIGHT", segment, "RIGHT", R.tokenOriginX, R.tokenOriginY)
		else
			token:SetPoint("RIGHT", segment.tokens[rank - 1], "LEFT", 0, 0)
		end

		token:Hide()
		segment.tokens[rank] = token
	end

	frame.foreverSegment = segment
	return segment
end

-- Fills the strip from the data; returns the number of currencies shown.
local function updateSegment(frame)
	local segment = setupSegment(frame)
	local list = readTokens()

	for rank, token in ipairs(segment.tokens) do
		local data = list[rank]
		if data then
			placeTokenIcon(token.icon, data)
			token.count:SetText(data.count)
			token:Show()
		else
			token:Hide()
		end
	end

	if #list > 0 then
		segment:Show()
	else
		segment:Hide()
	end
	return #list
end

-- Title and portrait (ContainerFrameMixin:UpdateName, UpdateMiscellaneousFrames).
local function updateHeader(frame)
	-- UpdateName: the name comes from the bag. The keyring has none (GetBagName(-2) returns
	-- nothing), so the client's own title text is used.
	local title = frame.foreverTitle
	if title then
		local bagName = GetBagName and GetBagName(frame:GetID())
		if not bagName or bagName == "" then
			local oldTitle = _G[frame:GetName() .. "Name"]
			bagName = oldTitle and oldTitle:GetText() or ""
		end
		title:SetText(bagName)
	end

	-- UpdateMiscellaneousFrames: backpack, keyring, or the bag's own item icon.
	local portrait = frame.foreverPortrait
	if portrait then
		local id = frame:GetID()
		local texture
		if id == 0 then
			texture = BACKPACK_PORTRAIT
		elseif id == (KEYRING_CONTAINER or -2) then
			texture = KEYRING_PORTRAIT
		elseif ContainerIDToInventoryID then
			texture = GetInventoryItemTexture("player", ContainerIDToInventoryID(id))
		end
		portrait:SetTexture(texture)
		-- Crop the 4 px dark border of the 64 px icon, as the client does for icons in a ring.
		portrait:SetTexCoord(ICON_BORDER, 1 - ICON_BORDER,
			ICON_BORDER, 1 - ICON_BORDER)
	end
end

-- Sizes the window, places purse and currency strip, and re-anchors the whole grid
-- (ContainerFrameMixin:UpdateFrameSize, GetInitialItemAnchor, GetAnchorLayout).
local function layoutGrid(frame)
	updateHeader(frame)

	local size = frame.size or 0
	if size <= 1 then
		return                      -- the one-slot gift bag keeps its shape
	end

	local name = frame:GetName()
	local m = measure(frame)
	local purse = _G[name .. "MoneyFrame"]

	-- UpdateFrameSize(): the window takes the computed size.
	frame:SetScale(R.scale)
	frame:SetWidth(m.width)
	frame:SetHeight(m.height)

	-- UpdateFrameSize calls NineSliceUtil.UpdateCornerCropping right after SetSize; otherwise
	-- the corners overlap on a short window.
	if ForeverUI.UpdatePanelCorners then
		ForeverUI.UpdatePanelCorners(frame)
	end

	-- Read the height back at once, for /fui bags: a wrong read-back means the frame's anchors
	-- set its height; a right one that later differs means something resizes it after us.
	frame.foreverRequested = m.height
	frame.foreverReadBack = frame:GetHeight()

	-- UpdateCurrencyFrames(): the currency strip takes the bottom, the purse sits on it and the
	-- grid hangs on the purse. Without watched currencies the purse takes the bottom.
	if m.isBackpack and purse then
		skinPurse(purse)
		local placed = updateSegment(frame)
		local segment = frame.foreverSegment

		purse:ClearAllPoints()
		if placed > 0 and segment then
			segment:ClearAllPoints()
			segment:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT",
				R.tokenSide, R.purseBottom)
			segment:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
				-R.tokenSide, R.purseBottom)
			purse:SetPoint("BOTTOMLEFT", segment, "TOPLEFT", 0, R.tokenGap)
			purse:SetPoint("BOTTOMRIGHT", segment, "TOPRIGHT", 0, R.tokenGap)
		else
			purse:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT",
				R.purseSide, R.purseBottom)
			purse:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
				-R.purseSide, R.purseBottom)
		end
		purse:Show()
	end

	-- GetAnchorLayout(): BottomRightToTopLeft, 4 columns, gap 5. The whole grid is re-anchored
	-- because 3.3.5 uses its own gaps (4 px between rows).
	for index = 1, size do
		local button = _G[name .. "Item" .. index]
		if button then
			button:SetWidth(R.slot)
			button:SetHeight(R.slot)
			button:ClearAllPoints()
			if index == 1 then
				if m.isBackpack and purse then
					-- ContainerFrameBackpackMixin:GetInitialItemAnchor()
					button:SetPoint("BOTTOMRIGHT", purse, "TOPRIGHT",
						0, R.purseGridGap)
				else
					-- ContainerFrameMixin:GetInitialItemAnchor()
					button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
						R.firstButtonX, R.firstButtonY)
				end
			elseif math.fmod(index - 1, R.columns) == 0 then
				button:SetPoint("BOTTOMRIGHT", _G[name .. "Item" .. (index - R.columns)],
					"TOPRIGHT", 0, R.cellGap)
			else
				button:SetPoint("BOTTOMRIGHT", _G[name .. "Item" .. (index - 1)],
					"BOTTOMLEFT", -R.cellGap, 0)
			end
		end
	end
end

-- Width taken by the visible right action bars.
local function rightBarsWidth()
	-- EditModeUtil:GetRightActionBarWidth() does not exist in 3.3.5; its right bars are
	-- MultiBarRight and MultiBarLeft.
	local width = 0
	for _, barName in ipairs({ "MultiBarRight", "MultiBarLeft" }) do
		local bar = _G[barName]
		if bar and bar:IsShown() then
			width = width + bar:GetWidth()
		end
	end
	return width
end

local function openBags()
	-- The client keeps the stacking order in ContainerFrame1.bags (GetBagsShown in the source).
	local list = {}
	if ContainerFrame1 and ContainerFrame1.bags then
		for _, frameName in ipairs(ContainerFrame1.bags) do
			local frame = _G[frameName]
			if frame and frame:IsShown() then
				table.insert(list, frame)
			end
		end
	end
	if #list == 0 then
		for _, frame in ipairs(frames) do
			if frame:IsShown() and (frame.size or 0) > 0 then
				table.insert(list, frame)
			end
		end
	end
	return list
end

-- UpdateContainerFrameAnchors: bags stack bottom to top, CONTAINER_SPACING apart, and start
-- a new column to the left when the screen is full. Unlike the source, a stacked bag costs
-- its height plus the gap, and topMargin is kept below the screen top, so no bag goes past
-- the top edge.
local function layoutBags()
	local screenHeight = GetScreenHeight() / R.scale
	local offsetX = (rightBarsWidth() + R.rightEdge) / R.scale
	local offsetY = R.bottomEdge / R.scale
	local available = screenHeight - offsetY - R.topMargin / R.scale
	local free = available
	local previous, firstInColumn

	for index, frame in ipairs(openBags()) do
		frame:SetScale(R.scale)
		frame:ClearAllPoints()
		local height = frame:GetHeight()
		if index == 1 then
			frame:SetPoint("BOTTOMRIGHT", frame:GetParent(), "BOTTOMRIGHT",
				-offsetX, offsetY)
			firstInColumn = frame
			free = free - height
		elseif free < height + R.bagGap then
			frame:SetPoint("BOTTOMRIGHT", firstInColumn, "BOTTOMLEFT",
				R.columnGap, 0)
			firstInColumn = frame
			free = available - height
		else
			frame:SetPoint("BOTTOMRIGHT", previous, "TOPRIGHT", 0, R.bagGap)
			free = free - height - R.bagGap
		end
		previous = frame
	end
end
ForeverUI.BagsStack = layoutBags

-- 3.3.5 resizes its bag frames at times the hooks do not all cover. One pass on the next
-- frame re-measures and re-applies the size if it moved. Only hooks request it, never
-- itself, so it cannot loop against the client.
local recheck = CreateFrame("Frame", "ForeverUIBagsRecheck")
recheck:Hide()
recheck:SetScript("OnUpdate", function(self)
	self:Hide()
	local needsRedo = false
	for _, frame in ipairs(frames) do
		if frame:IsShown() and (frame.size or 0) > 1 then
			local m = measure(frame)
			if math.abs(frame:GetHeight() - m.height) > 0.5
				or math.abs(frame:GetWidth() - m.width) > 0.5 then
				frame.foreverUndoCount = (frame.foreverUndoCount or 0) + 1
				layoutGrid(frame)
				needsRedo = true
			end
		end
	end
	if needsRedo then
		-- A height changed: the stacking depends on it.
		layoutBags()
	end
end)

local function requestRecheck()
	recheck:Show()
end

ForeverUI.BagsLayout = layoutTools

-- ------------------------------------------------------------- hooks
local function skinAll()
	for index = 1, FRAME_COUNT do
		skinFrame(_G["ContainerFrame" .. index])
	end
end

skinAll()
updateField()

if hooksecurefunc then
	-- The client resets its own pieces each time a bag opens.
	hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
		skinFrame(frame)
		layoutGrid(frame)
		layoutTools()
		-- GenerateFrame runs updateContainerFrameAnchors (our stacking) before it shows the bag,
		-- so the new bag was skipped; stack again now that it is shown.
		layoutBags()
		Search.All()
		requestRecheck()
	end)

	-- ContainerFrame_Update runs on every bag update and resets the client's pieces; the grid
	-- is re-applied after it, or the original size comes back.
	hooksecurefunc("ContainerFrame_Update", function(frame)
		layoutGrid(frame)
		Search.Apply(frame)
		requestRecheck()
	end)

	hooksecurefunc("ContainerFrame_OnHide", function()
		layoutTools()
	end)

	-- The client resets scale and anchors on each re-layout: re-apply ours, size included.
	hooksecurefunc("updateContainerFrameAnchors", function()
		for _, frame in ipairs(frames) do
			if frame:GetScale() ~= R.scale then
				frame:SetScale(R.scale)
			end
			if frame:IsShown() then
				layoutGrid(frame)
			end
		end
		-- The client just stacked the bags with its own gaps; re-stack with camelot's.
		layoutBags()
		requestRecheck()
	end)
end

-- ManageBackpackTokenFrame reparents BackpackTokenFrame into the backpack and resets its
-- height (BACKPACK_HEIGHT + 22), undoing ours: the client strip stays hidden and the
-- backpack is re-laid out after it.
local function silenceClientSegment()
	local old = _G["BackpackTokenFrame"]
	if old then
		old:Hide()
		if old.EnableMouse then
			old:EnableMouse(false)
		end
	end
end

if hooksecurefunc and type(_G["ManageBackpackTokenFrame"]) == "function" then
	hooksecurefunc("ManageBackpackTokenFrame", function()
		silenceClientSegment()
		for _, frame in ipairs(frames) do
			if frame:IsShown() and frame:GetID() == 0 then
				layoutGrid(frame)
			end
		end
	end)
end

-- "Show on Backpack" always goes through SetCurrencyBackpack (currency tab boxes and the
-- client's modified click), so the backpack is re-laid out after it.
if hooksecurefunc and type(_G["SetCurrencyBackpack"]) == "function" then
	hooksecurefunc("SetCurrencyBackpack", function()
		for _, frame in ipairs(frames) do
			if frame:IsShown() and frame:GetID() == 0 then
				layoutGrid(frame)
			end
		end
	end)
end

local listener = CreateFrame("Frame", "ForeverUIBagsWatcher")
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:RegisterEvent("BAG_UPDATE")
-- A watched currency amount changed.
listener:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
listener:SetScript("OnEvent", function()
	skinAll()
	silenceClientSegment()
	for _, frame in ipairs(frames) do
		if frame:IsShown() then
			layoutGrid(frame)
		end
	end
	layoutTools()
	Search.All()
	requestRecheck()
end)

-- Re-applies the whole layout after a setting changes.
function ForeverUI.BagsApply()
	for _, frame in ipairs(frames) do
		layoutGrid(frame)
	end
	layoutTools()
	Search.All()
end

-- /fui bags: for each open bag, the computed size and the frame's actual size. A mismatch
-- means something resizes the frame after us.
ForeverUI.BagsDebug = function()
	local openCount = 0
	for _, frame in ipairs(frames) do
		if frame:IsShown() and (frame.size or 0) > 0 then
			openCount = openCount + 1
			local name = frame:GetName()
			local m = measure(frame)
			local actualW, actualH = frame:GetWidth(), frame:GetHeight()
			local sizeMatch = (math.abs(actualH - m.height) < 0.5)
				and (math.abs(actualW - m.width) < 0.5)

			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				"|cff66ccffForeverUI|r " .. L.BAGS_DEBUG_FRAME,
				name, frame:GetID(), frame.size or 0, m.rowLines))
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				"   " .. L.BAGS_DEBUG_SIZE,
				m.width, m.height, m.grid, m.overhead, m.extra, actualW, actualH,
				sizeMatch and ("|cff44ff44" .. L.BAGS_DEBUG_MATCH .. "|r") or ("|cffff4444" .. L.BAGS_DEBUG_MISMATCH .. "|r")))

			if not sizeMatch then
				-- The read-back tells which of the two cases it is.
				DEFAULT_CHAT_FRAME:AddMessage(string.format(
					"   " .. L.BAGS_DEBUG_WITNESS,
					tostring(frame.foreverRequested), tostring(frame.foreverReadBack),
					tostring(frame.foreverUndoCount or 0),
					(frame.foreverReadBack and frame.foreverRequested
						and math.abs(frame.foreverReadBack - frame.foreverRequested) < 0.5)
						and ("|cffff4444" .. L.BAGS_DEBUG_RESIZED_AFTER .. "|r")
						or ("|cffff4444" .. L.BAGS_DEBUG_ANCHORS_FORCE .. "|r")))

				local rows = string.format("   " .. L.BAGS_DEBUG_ANCHORS, frame:GetNumPoints())
				for index = 1, frame:GetNumPoints() do
					local point, target, targetPoint, x, y = frame:GetPoint(index)
					rows = rows .. string.format(L.BAGS_DEBUG_ANCHOR,
						tostring(point), tostring(targetPoint),
						target and (target.GetName and target:GetName() or "?") or L.BAGS_DEBUG_SCREEN,
						x or 0, y or 0)
				end
				DEFAULT_CHAT_FRAME:AddMessage(rows)
			end
		end
	end

	if openCount == 0 then
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cff66ccffForeverUI|r " .. L.BAGS_DEBUG_NO_BAG_OPEN)
	end

	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"   " .. L.BAGS_DEBUG_SKINNED,
		#frames, R.slot, tostring(field:IsShown())))

	-- Watched currencies: what the client gives and what is shown. The client strip must be hidden.
	local tracked = readTokens()
	local names = {}
	for _, token in ipairs(tracked) do
		names[#names + 1] = string.format("%s=%s", token.name, tostring(token.count))
	end
	local segment = _G["ForeverUIBagTokens"]
	local old = _G["BackpackTokenFrame"]
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"   " .. L.BAGS_DEBUG_TOKENS, #tracked, MAX_WATCHED_TOKENS or 3,
		(#names > 0) and table.concat(names, ", ") or L.BAGS_DEBUG_NONE))
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"   " .. L.BAGS_DEBUG_SEGMENT,
		tostring(segment and segment:IsShown()),
		tostring(old and old:IsShown())))

	-- All settings, sorted by name, so the list stays complete when settings change.
	local keys = {}
	for key in pairs(R) do
		table.insert(keys, key)
	end
	table.sort(keys)
	local row = ""
	for _, key in ipairs(keys) do
		row = row .. string.format("%s=%s  ", key, tostring(R[key]))
		if string.len(row) > 80 then
			DEFAULT_CHAT_FRAME:AddMessage("   " .. row)
			row = ""
		end
	end
	if row ~= "" then
		DEFAULT_CHAT_FRAME:AddMessage("   " .. row)
	end
end

-- Changes a setting in game, to try it before fixing it in R.
-- key: name in R; value: new number
function ForeverUI.BagsSet(key, value)
	if R[key] == nil then
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. L.BAGS_UNKNOWN_SETTING .. tostring(key))
		return false
	end
	local count = tonumber(value)
	if not count then
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. L.BAGS_NUMBER_EXPECTED)
		return false
	end
	R[key] = count
	ForeverUI.BagsApply()
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cff66ccffForeverUI|r " .. L.BAGS_SET, key, tostring(count)))
	return true
end
