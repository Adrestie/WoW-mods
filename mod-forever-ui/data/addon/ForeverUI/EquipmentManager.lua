-- Equipment manager page of the character sheet's right pane (camelot EquipmentManagerPane).
-- The client's GearManagerDialog is moved into the pane and its set buttons are reskinned as
-- cards; the client keeps the list, the selection, the tooltips and the clicks.
-- Sizes and anchors: camelot PaperDollFrame.xml and GearSetButtonTemplate.

ForeverUI = ForeverUI or {}
local L = ForeverUI.L

-- Card layout differs from camelot's GearSetButtonTemplate (card 169 x 44, background 152 x 49
-- at x = 42): list at x = 9, card 40 high, background 174 x 45 (the art keeps its 5 px overhang).
-- Width 174 makes the gap from the pane separator to the icon (8 px) equal the gap from the card
-- to the pane's right edge: 233 - 8 - LIST_X - 42 = 174. The button covers the whole card.
local CARD_BACKGROUND_W, CARD_BACKGROUND_H = 174, 45
local CARD_BACKGROUND_X = 42
local CARD_W, CARD_H = CARD_BACKGROUND_X + CARD_BACKGROUND_W, 40
local CARD_ICON, CARD_ICON_X = 36, 4
local CARD_TEXT_X = 55
local CARD_TEXT_W, CARD_TEXT_H = 98, 38
-- camelot anchors the checkmark at RIGHT -23 of a button that ends 25 px before the card edge.
-- Here the button covers the whole card, so the checkmark sits 12 px from the card's right edge.
local CHECKMARK_X = -12

local LIST_X, LIST_Y = 9, -8
local LIST_Y2 = 105
local BUTTON_W, BUTTON_H = 99, 28
local BUTTON_Y, BUTTON_GAP = 20, 50
local NEW_BUTTON_W, NEW_BUTTON_H = 180, 34
local NEW_BUTTON_Y, NEW_BUTTON_ICON_X = 50, 13
-- common-insideframe (107 x 107) has a pattern in each corner: nine-sliced, not stretched.
-- Corner 20: the corner pattern ends at 19 px.
-- Margins from camelot's TOPLEFT (1, 1) / BOTTOMRIGHT (-4, 2), shifted 3 px to the right.
local BORDER_CORNER = 20
local BORDER_MARGINS = { -4, 1, -1, -2 }

local ATLAS_BACKGROUND = "ui-character-info-outfitcard"
local ATLAS_HOVER = "ui-character-info-outfitcard-hover"
local ATLAS_SELECTED = "ui-character-info-outfitcard-selected"
local ATLAS_CHECKMARK = "ui-character-info-icon-tick"
local ATLAS_CIRCLE = "ui-character-info-outfiticon-frame"
local ATLAS_PLUS = "ui-character-info-icon-add"
local ATLAS_BORDER = "common-insideframe"
local ATLAS_LINE = "ui-character-info-scrollline"

-- camelot GearSetButtonTemplate hover buttons: Delete 14 x 14 at BOTTOMRIGHT (-21, 2), Edit
-- 16 x 16 left of it (-1); alpha 0.5 idle, 1 on hover; the texture shifts (1, -1) when pressed.
-- camelot's gear assigns a specialization, which 3.3.5 lacks: here it reopens the save popup on
-- the set to rename it or change its icon. SETTINGS replaces the missing EQUIPMENT_SET_SETTINGS.
local DELETE_SIZE = 14
local DELETE_X, DELETE_Y = -21, 2
local EDIT_SIZE = 16
local EDIT_X = -1
local DELETE_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local EDIT_ICON = "Interface\\WorldMap\\GEAR_64GREY"
local IDLE, HOVER = 0.5, 1.0

local panel, offset = nil, 0

-- Editing a set. 3.3.5 has no ModifyEquipmentSet: SaveEquipmentSet(name, icon) saves the worn
-- gear. So an edit equips the old set, saves it under the new name and icon, deletes the old one
-- and gives the new name the old one's rank. The swap is asynchronous (EQUIPMENT_SWAP_FINISHED).
-- 3.3.5 lists sets in creation order; the display order is kept in ForeverUIDB.setOrder.
local editSession
local intendedClose                   -- set while the addon hides the popup itself
local EDIT_TIMEOUT = 10                -- seconds before an edit is abandoned

local function savedOrder()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.setOrder = ForeverUIDB.setOrder or {}
	return ForeverUIDB.setOrder
end

-- Client set indices in the saved order; sets not yet known go last.
local function orderedSets()
	local total = (GetNumEquipmentSets and GetNumEquipmentSets()) or 0
	local byName, inside = {}, {}
	for index = 1, total do
		local name = GetEquipmentSetInfo(index)
		if name then
			byName[name] = index
		end
	end

	-- Each name is kept once: duplicates take several ranks and push the card past the last rank.
	-- The saved order is pruned only when the client lists at least one set: between a save and
	-- its event the client lists none, and pruning would empty it.
	local order = savedOrder()

	local list, kept = {}, {}
	for _, name in ipairs(order) do
		if byName[name] and not inside[name] then
			list[#list + 1] = byName[name]
			inside[name] = true
			kept[#kept + 1] = name
		end
	end
	for index = 1, total do
		local name = GetEquipmentSetInfo(index)
		if name and not inside[name] then
			list[#list + 1] = index
			inside[name] = true
			kept[#kept + 1] = name
		end
	end

	if total > 0 then
		for rank = #order, 1, -1 do
			order[rank] = nil
		end
		for rank, name in ipairs(kept) do
			order[rank] = name
		end
	end
	return list
end
ForeverUI.EquipmentSetsOrder = orderedSets

-- A set is worn when each piece is in its own slot (the unpacked slot must match the key).
-- 3.3.5 has no active set and two sets can hold the same pieces, so the checkmark goes to the
-- last set equipped (UseEquipmentSet hook), only while it is still worn.
local function piecesInPlace(name)
	if not name or not GetEquipmentSetLocations or not EquipmentManager_UnpackLocation then
		return false
	end

	local locations = GetEquipmentSetLocations(name)
	if not locations then
		return false
	end

	local found = false
	for slotId, location in pairs(locations) do
		if type(location) == "number" and location > 1 then
			local player, _, bags, slot = EquipmentManager_UnpackLocation(location)
			if not player or bags or slot ~= slotId then
				return false
			end
			found = true
		end
	end
	return found
end

-- Name of the last set equipped.
local function activeSet()
	ForeverUIDB = ForeverUIDB or {}
	return ForeverUIDB.equippedSet
end

local function isSetWorn(name)
	return name ~= nil and name == activeSet() and piecesInPlace(name)
end

-- Remember the last set equipped, across sessions.
if hooksecurefunc and type(UseEquipmentSet) == "function" then
	hooksecurefunc("UseEquipmentSet", function(name)
		ForeverUIDB = ForeverUIDB or {}
		ForeverUIDB.equippedSet = name
		if ForeverUI.EquipmentSetsLayout then
			ForeverUI.EquipmentSetsLayout()
		end
	end)
end

-- Height of the card list, and how many cards fit in it.
local function listHeight()
	if not panel then
		return 0
	end
	return panel:GetHeight() - (-LIST_Y) - LIST_Y2
end

local function visibleCards()
	local location = math.floor(listHeight() / CARD_H)
	if location < 1 then
		location = 1
	end
	return location
end

-- Reskins a client set button as a card, once.
local function skinCard(button)
	if button.foreverCard then
		return
	end

	button:SetWidth(CARD_W)
	button:SetHeight(CARD_H)

	-- Hide the 3.3.5 empty-slot background; the icon is the button's NormalTexture and stays.
	local icon = button:GetNormalTexture()
	local regions = { button:GetRegions() }
	for _, region in ipairs(regions) do
		if region ~= icon and region.GetObjectType and region:GetObjectType() == "Texture" then
			local path = region.GetTexture and region:GetTexture()
			if type(path) == "string" and string.find(string.lower(path), "emptyslot") then
				region:SetAlpha(0)
			end
		end
	end
	if button:GetHighlightTexture() then
		button:GetHighlightTexture():SetAlpha(0)
	end
	if button.GetCheckedTexture and button:GetCheckedTexture() then
		button:GetCheckedTexture():SetAlpha(0)
	end

	local function map(atlas, layer)
		local t = button:CreateTexture(nil, layer)
		ForeverUI.SetAtlas(t, atlas, true)
		t:SetWidth(CARD_BACKGROUND_W)
		t:SetHeight(CARD_BACKGROUND_H)
		t:SetPoint("TOPLEFT", button, "TOPLEFT", CARD_BACKGROUND_X, 0)
		return t
	end

	-- Selected (ARTWORK) draws above hover (BORDER), whatever the creation order.
	button.foreverBackground = map(ATLAS_BACKGROUND, "BACKGROUND")
	button.foreverHover = map(ATLAS_HOVER, "BORDER")
	button.foreverHover:Hide()
	button.foreverSelected = map(ATLAS_SELECTED, "ARTWORK")
	button.foreverSelected:Hide()

	if icon then
		icon:ClearAllPoints()
		icon:SetWidth(CARD_ICON)
		icon:SetHeight(CARD_ICON)
		icon:SetPoint("LEFT", button, "LEFT", CARD_ICON_X, 0)
		icon:SetDrawLayer("ARTWORK")
	end

	local circle = button:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(circle, ATLAS_CIRCLE)
	circle:SetPoint("CENTER", icon or button, "CENTER", 0, 0)

	local checkMark = button:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(checkMark, ATLAS_CHECKMARK)
	checkMark:SetPoint("RIGHT", button, "RIGHT", CHECKMARK_X, 0)
	checkMark:Hide()
	button.foreverCheck = checkMark

	local text = _G[button:GetName() .. "Name"]
	if text then
		text:ClearAllPoints()
		text:SetFontObject(GameFontNormalLeft or GameFontNormal)
		text:SetWidth(CARD_TEXT_W)
		text:SetHeight(CARD_TEXT_H)
		text:SetJustifyH("LEFT")
		text:SetPoint("LEFT", button, "LEFT", CARD_TEXT_X, 0)
	end

	-- Delete and edit buttons, shown on the hovered card.
	-- name: frame name suffix; side: size; icon: texture path; tooltip: tooltip text
	local function smallButton(name, side, icon, tooltip, onClick)
		local b = CreateFrame("Button", button:GetName() .. name, button)
		b:SetWidth(side)
		b:SetHeight(side)
		b:SetFrameLevel(button:GetFrameLevel() + 2)

		local t = b:CreateTexture(nil, "ARTWORK")
		t:SetTexture(icon)
		t:SetAllPoints(b)
		t:SetAlpha(IDLE)
		b.texture = t

		b:SetScript("OnEnter", function(self)
			self.texture:SetAlpha(HOVER)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(tooltip)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function(self)
			self.texture:SetAlpha(IDLE)
			GameTooltip:Hide()
		end)
		b:SetScript("OnMouseDown", function(self)
			self.texture:ClearAllPoints()
			self.texture:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -1)
			self.texture:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 1, -1)
		end)
		b:SetScript("OnMouseUp", function(self)
			self.texture:ClearAllPoints()
			self.texture:SetAllPoints(self)
		end)
		b:SetScript("OnClick", onClick)
		b:Hide()
		return b
	end

	button.foreverDelete = smallButton("ForeverUIDelete", DELETE_SIZE,
		DELETE_ICON, DELETE, function(self)
			local map = self:GetParent()
			if not map.name or map.name == "" then
				return
			end
			local window = StaticPopup_Show("CONFIRM_DELETE_EQUIPMENT_SET", map.name)
			if window then
				window.data = map.name
			elseif UIErrorsFrame then
				UIErrorsFrame:AddMessage(ERR_CLIENT_LOCKED_OUT, 1.0, 0.1, 0.1, 1.0)
			end
		end)
	button.foreverDelete:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT",
		DELETE_X, DELETE_Y)

	button.foreverEdit = smallButton("ForeverUIEdit", EDIT_SIZE,
		EDIT_ICON, SETTINGS, function(self)
			local map = self:GetParent()
			if not map.name or map.name == "" then
				return
			end
			if ForeverUI.EquipmentSetEdit then
				ForeverUI.EquipmentSetEdit(map.name)
			end
		end)
	button.foreverEdit:SetPoint("RIGHT", button.foreverDelete, "LEFT",
		EDIT_X, 0)

	button.foreverCard = true
end

-- The set list is polled: sets live on the server, and no return, event or frame delay tells
-- when the client list is ready. Every 0.2 s while the pane is shown, the count, names and icons
-- are compared with the last layout, and the cards are laid out again when they differ.
local WATCH_INTERVAL = 0.2
local lastState, sinceCheck = nil, 0

local function listState()
	local total = (GetNumEquipmentSets and GetNumEquipmentSets()) or 0
	local parts = { tostring(total) }
	for index = 1, total do
		local name, icon = GetEquipmentSetInfo(index)
		parts[#parts + 1] = tostring(name) .. "=" .. tostring(icon)
	end
	return table.concat(parts, "|")
end

local function watchList(elapsed)
	sinceCheck = sinceCheck + (elapsed or 0)
	if sinceCheck < WATCH_INTERVAL then
		return
	end
	sinceCheck = 0

	local state = listState()
	if state ~= lastState then
		lastState = state
		if GearManagerDialog_Update then
			GearManagerDialog_Update()
		end
		-- layoutCards is defined below: call it through the published function.
		ForeverUI.EquipmentSetsLayout()
	end
end

-- Makes the next poll lay out the list again.
function ForeverUI.EquipmentSetsForget()
	lastState = nil
	sinceCheck = WATCH_INTERVAL
end

-- Hover is polled each frame, as in camelot's PaperDollEquipmentManagerPane_OnUpdate: the
-- delete and edit buttons are children of the card, so entering them fires the card's OnLeave.
local function trackHover(self, elapsed)
	watchList(elapsed)
	local dialog = _G["GearManagerDialog"]
	if not dialog or not dialog.buttons then
		return
	end

	for _, button in ipairs(dialog.buttons) do
		if button.foreverCard and button:IsShown() then
			local hovered = button:IsMouseOver() and button.name and button.name ~= ""
			if hovered then
				button.foreverHover:Show()
				button.foreverDelete:Show()
				button.foreverEdit:Show()
			else
				button.foreverHover:Hide()
				button.foreverDelete:Hide()
				button.foreverEdit:Hide()
			end
		end
	end
end
ForeverUI.EquipmentSetsHover = trackHover

-- Lays out the existing sets in a column, from the scroll offset.
local function layoutCards()
	local dialog = _G["GearManagerDialog"]
	if not dialog or not dialog.buttons or not panel then
		return
	end

	local total = (GetNumEquipmentSets and GetNumEquipmentSets()) or 0
	local location = visibleCards()
	if offset > total - location then
		offset = math.max(0, total - location)
	end

	-- Button i holds client set i; the saved order decides where it goes.
	local order = orderedSets()
	local buttonRank = {}
	for position, index in ipairs(order) do
		buttonRank[index] = position
	end

	local previous
	local byRank = {}
	for index, button in ipairs(dialog.buttons) do
		skinCard(button)
		if buttonRank[index] then
			byRank[buttonRank[index]] = button
		end
	end

	for position = 1, #dialog.buttons do
		local button = byRank[position]
		-- The client index is order[position], not the position itself.
		local index = order[position]
		local rank = position - offset
		if button and index and index <= total and rank >= 1 and rank <= location then
			button:ClearAllPoints()
			if previous then
				button:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, 0)
			else
				button:SetPoint("TOPLEFT", panel, "TOPLEFT", LIST_X, LIST_Y)
			end
			previous = button
			button:Show()

			if button.foreverSelected then
				if button:GetChecked() then
					button.foreverSelected:Show()
				else
					button.foreverSelected:Hide()
				end
			end
			if button.foreverCheck then
				if isSetWorn(button.name) then
					button.foreverCheck:Show()
				else
					button.foreverCheck:Hide()
				end
			end
		elseif button then
			button:Hide()
		end
	end

	-- Buttons without a set stay hidden.
	for index, button in ipairs(dialog.buttons) do
		if not buttonRank[index] then
			button:Hide()
		end
	end
end
ForeverUI.EquipmentSetsLayout = layoutCards

local function build(pane)
	panel = CreateFrame("Frame", "ForeverUIEquipmentPane", pane)
	panel:SetPoint("TOPLEFT", pane.stone, "BOTTOMLEFT", 0, 0)
	panel:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
	panel:SetFrameLevel(pane:GetFrameLevel() + 3)

	panel.border = ForeverUI.CreateNineSlice(panel, ATLAS_BORDER,
		BORDER_CORNER, BORDER_MARGINS, "BORDER")

	local line = panel:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(line, ATLAS_LINE)
	line:SetPoint("TOP", panel, "BOTTOM", 0, LIST_Y2)

	-- Mouse wheel scrolling: camelot's scroll bar is not reproduced.
	panel:SetScript("OnUpdate", trackHover)
	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", function(self, direction)
		local total = (GetNumEquipmentSets and GetNumEquipmentSets()) or 0
		offset = math.max(0, math.min(offset - direction, total - visibleCards()))
		layoutCards()
	end)

	return panel
end

-- Equip and Save stay the client's. New Set clears the selection then runs Save (3.3.5 has no
-- New Set button). The client's Delete is hidden: each card has its own.
local function placeButtons()
	local equipButton = _G["GearManagerDialogEquipSet"]
	local saveButton = _G["GearManagerDialogSaveSet"]
	local clear = _G["GearManagerDialogDeleteSet"]

	if equipButton then
		equipButton:SetWidth(BUTTON_W)
		equipButton:SetHeight(BUTTON_H)
		equipButton:ClearAllPoints()
		equipButton:SetPoint("BOTTOM", panel, "BOTTOM", -BUTTON_GAP, BUTTON_Y)
	end
	if saveButton then
		saveButton:SetWidth(BUTTON_W)
		saveButton:SetHeight(BUTTON_H)
		saveButton:ClearAllPoints()
		saveButton:SetPoint("BOTTOM", panel, "BOTTOM", BUTTON_GAP, BUTTON_Y)
	end
	if clear then
		clear:SetWidth(BUTTON_W)
		clear:SetHeight(BUTTON_H)
		clear:ClearAllPoints()
		clear:SetPoint("BOTTOM", saveButton or panel, "TOP", 0, 0)
		clear:Hide()
	end

	if not panel.new then
		local new = CreateFrame("Button", "ForeverUIEquipmentNewSet", panel,
			"UIPanelButtonTemplate")
		new:SetWidth(NEW_BUTTON_W)
		new:SetHeight(NEW_BUTTON_H)
		new:SetPoint("BOTTOM", panel, "BOTTOM", 0, NEW_BUTTON_Y)

		-- No client string matches camelot's PAPERDOLL_NEWEQUIPMENTSET.
		new:SetText(L.EQUIPMENTMANAGER_NEW_SET)

		-- Same look as the stat selectors: tertiary button, pressed while held.
		ForeverUI.SkinTertiaryButton(new, true)

		local plus = new:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(plus, ATLAS_PLUS)
		plus:SetPoint("LEFT", new, "LEFT", NEW_BUTTON_ICON_X, 0)

		new:SetScript("OnClick", function()
			local dialog = _G["GearManagerDialog"]
			if dialog then
				dialog.selectedSetName = nil
				dialog.selectedSet = nil
			end
			if GearManagerDialogSaveSet_OnClick then
				GearManagerDialogSaveSet_OnClick(_G["GearManagerDialogSaveSet"])
			end
		end)
		panel.new = new
	end

	-- New Set must stay above the client dialog, which covers the pane and takes the mouse.
	-- The dialog raises itself on each OnShow and this runs after it, so the level is recomputed
	-- from the dialog's current level every time.
	local dialog = _G["GearManagerDialog"]
	if panel.new and dialog then
		panel.new:SetFrameLevel(dialog:GetFrameLevel() + 5)
	end
end

-- Moves the client dialog into the pane: its window art is hidden and it covers the pane,
-- holding only its cards and buttons.
local function hostDialog()
	local dialog = _G["GearManagerDialog"]
	if not dialog or dialog.foreverHosted then
		return
	end

	dialog:SetParent(panel)
	dialog:ClearAllPoints()
	dialog:SetAllPoints(panel)
	dialog:SetFrameLevel(panel:GetFrameLevel() + 1)

	-- GearManagerDialog is toplevel and its OnShow calls Raise(), which would put it above
	-- everything in the pane on each opening.
	if dialog.SetToplevel then
		dialog:SetToplevel(false)
	end

	local regions = { dialog:GetRegions() }
	for _, region in ipairs(regions) do
		if region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end
	if dialog.title then
		dialog.title:Hide()
	end

	dialog.foreverHosted = true
end

-- Hides the red close button, every time: the client shows it again when it reopens.
-- UIPanelDialogTemplate names it $parentClose (GearManagerDialogClose), not $parentCloseButton.
local function hideCloseButton()
	for _, name in ipairs({ "GearManagerDialogClose", "GearManagerDialogCloseButton" }) do
		local button = _G[name]
		if button then
			button:Hide()
		end
	end
end

local function applySkin()
	local panes = ForeverUI.CharacterPanes
	local pane = panes and panes.right
	if not pane or not pane.stone or InCombatLockdown() then
		return
	end

	if not panel then
		build(pane)
	end

	-- The pane is a page of the right host: ForeverUI.Panes shows and hides it with the client
	-- dialog, now its child, so it does not survive a side tab change.
	hostDialog()
	hideCloseButton()
	placeButtons()
	layoutCards()
end

ForeverUI.EquipmentPane = { Apply = applySkin, Frame = function() return panel end }

if hooksecurefunc then
	for _, name in ipairs({ "GearManagerDialog_Update", "GearManagerDialog_OnShow" }) do
		if type(_G[name]) == "function" then
			hooksecurefunc(name, function() applySkin() end)
		end
	end
end

-- ========== Edit a set
local pendingEdit = CreateFrame("Frame", "ForeverUIEquipmentEdit")
pendingEdit:Hide()

-- Gives new the rank of old in the saved order (appended if old is not there).
local function replaceInOrder(old, new)
    local order = savedOrder()
    local location
    for rank, known in ipairs(order) do
        if known == old then
            order[rank] = new
            location = rank
            break
        end
    end
    if not location then
        location = #order + 1
        order[location] = new
    end
    -- The new name may already be elsewhere in the order: keep only this copy.
    for rank = #order, 1, -1 do
        if rank ~= location and order[rank] == new then
            table.remove(order, rank)
            if rank < location then
                location = location - 1
            end
        end
    end
end

-- Saves the worn gear under the new name and icon, then deletes the old set.
local function finishEdit()
    local e = editSession
    editSession = nil
    pendingEdit:Hide()
    if not e then
        return
    end

    -- SaveEquipmentSet refuses an empty name.
    if not e.name or e.name == "" or not SaveEquipmentSet then
        return
    end

    -- GearManagerDialogPopup_Update sets selectedIcon only for icons on the visible page: when the
    -- set's icon is on another page it stays nil and SaveEquipmentSet fails, so the edit stops
    -- before anything is deleted.
    if type(e.icon) ~= "number" then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage(ERR_CLIENT_LOCKED_OUT, 1.0, 0.1, 0.1, 1.0)
        end
        return
    end

    local renamed = e.name ~= e.old

    -- At MAX_EQUIPMENT_SETS_PER_PLAYER a rename has no free slot to save before deleting, so the
    -- old set is deleted first. Its gear is worn at this point, so nothing is lost.
    local cap = MAX_EQUIPMENT_SETS_PER_PLAYER or 10
    local before = (GetNumEquipmentSets and GetNumEquipmentSets()) or 0
    if renamed and before >= cap and DeleteEquipmentSet then
        DeleteEquipmentSet(e.old)
        replaceInOrder(e.old, e.name)
        renamed = false
    end

    SaveEquipmentSet(e.name, e.icon)

    -- Delete the old set only if the new one exists, so a failed save loses nothing.
    if renamed and DeleteEquipmentSet then
        if GetEquipmentSetInfoByName and GetEquipmentSetInfoByName(e.name) then
            DeleteEquipmentSet(e.old)
            replaceInOrder(e.old, e.name)
        elseif UIErrorsFrame then
            UIErrorsFrame:AddMessage(ERR_CLIENT_LOCKED_OUT, 1.0, 0.1, 0.1, 1.0)
        end
    end

    ForeverUIDB = ForeverUIDB or {}
    if ForeverUIDB.equippedSet == e.old then
        ForeverUIDB.equippedSet = e.name
    end

    local dialog = _G["GearManagerDialog"]
    if dialog then
        dialog.selectedSetName = e.name
    end
    if ForeverUI.EquipmentSetsRefresh then
        ForeverUI.EquipmentSetsRefresh()
    end
end

-- SaveEquipmentSet and DeleteEquipmentSet return before the client list changes; the list is
-- refreshed on EQUIPMENT_SETS_CHANGED, registered here because the client listens to it only
-- while its dialog is shown.
pendingEdit:RegisterEvent("EQUIPMENT_SETS_CHANGED")
pendingEdit:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
pendingEdit:SetScript("OnEvent", function(self, event, completed, name)
    if event == "EQUIPMENT_SETS_CHANGED" then
        -- On the next frame: the client may not have rebuilt its list yet.
        if ForeverUI.EquipmentSetsRefresh then
            ForeverUI.EquipmentSetsRefresh()
        end
        return
    end
    if editSession and completed and name == editSession.old then
        finishEdit()
    end
end)

-- Abandon an edit whose gear swap does not finish in time (combat, locked item).
pendingEdit:SetScript("OnUpdate", function(self, elapsed)
    if not editSession then
        self:Hide()
        return
    end
    editSession.rest = (editSession.rest or EDIT_TIMEOUT) - (elapsed or 0)
    if editSession.rest <= 0 then
        editSession = nil
        self:Hide()
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage(ERR_CLIENT_LOCKED_OUT, 1.0, 0.1, 0.1, 1.0)
        end
    end
end)

-- Starts an edit: equips the old set; finishEdit runs on EQUIPMENT_SWAP_FINISHED.
-- name: new set name; icon: icon index from the popup
local function startEdit(name, icon)
    if not editSession or not name or name == "" then
        editSession = nil
        return
    end
    editSession.name = name
    editSession.icon = icon

    -- Already worn: nothing to equip.
    if piecesInPlace(editSession.old) then
        finishEdit()
        return
    end

    if UseEquipmentSet then
        UseEquipmentSet(editSession.old)
    end
    editSession.rest = EDIT_TIMEOUT
    pendingEdit:Show()
end

-- The popup's Okay is replaced, not hooked: a hook would run after the client has already saved
-- the worn gear under that name. Outside an edit the client's handler runs unchanged.
local function reclaimOkay()
    local okay = _G["GearManagerDialogPopupOkay"]
    if not okay or okay.foreverOkay then
        return
    end

    okay:SetScript("OnClick", function(self, button, pressed)
        local popup = _G["GearManagerDialogPopup"]
        if editSession and popup and popup.name and popup.name ~= "" then
            -- Read the name before hiding: GearManagerDialogPopup_OnHide clears popup.name and abandons
            -- the edit, hence the intendedClose flag.
            local name = popup.name
            -- No icon chosen, no index: the client's GetEquipmentSetIconInfo(nil) raises an error.
            local iconIndex
            if popup.selectedIcon then
                iconIndex = select(2, GetEquipmentSetIconInfo(popup.selectedIcon))
            end
            local inProgress = editSession

            intendedClose = true
            popup:Hide()
            intendedClose = nil

            editSession = inProgress
            startEdit(name, iconIndex)
            return
        end
        if GearManagerDialogPopupOkay_OnClick then
            GearManagerDialogPopupOkay_OnClick(self, button, pressed)
        end
    end)
    okay.foreverOkay = true
end

-- Opens the save popup on an existing set (called by the gear button).
function ForeverUI.EquipmentSetEdit(name)
    if not name or name == "" then
        return
    end

    local dialog = _G["GearManagerDialog"]
    if dialog then
        dialog.selectedSetName = name
        if GearManagerDialog_Update then
            GearManagerDialog_Update()
        end
    end

    editSession = { old = name }
    reclaimOkay()

    if GearManagerDialogSaveSet_OnClick then
        GearManagerDialogSaveSet_OnClick(_G["GearManagerDialogSaveSet"])
    end

    -- Set the name here: the client fills the field only in RecalculateGearManagerDialogPopup,
    -- which only OnShow calls.
    local field = _G["GearManagerDialogPopupEditBox"]
    if field then
        field:SetText(name)
    end
end

-- Popup closed another way (Cancel, Escape): the edit is abandoned.
if hooksecurefunc and type(GearManagerDialogPopup_OnHide) == "function" then
    hooksecurefunc("GearManagerDialogPopup_OnHide", function()
        if editSession and not intendedClose and not pendingEdit:IsShown() then
            editSession = nil
        end
    end)
end

-- Lays the list out again on the next frame: right after a save or delete,
-- GetNumEquipmentSets and GetEquipmentSetInfo still return the old state.
-- Requested by events and by the end of an edit; it hides itself after one run.
local listRecheck = CreateFrame("Frame", "ForeverUIEquipmentRecheck")
listRecheck:Hide()
listRecheck:SetScript("OnUpdate", function(self)
    self:Hide()
    if GearManagerDialog_Update then
        GearManagerDialog_Update()
    end
    ForeverUI.EquipmentSetsLayout()
end)

-- /fui sets: prints the client's sets, the saved order and the displayed cards, to show where
-- they disagree.
function ForeverUI.EquipmentSetsDebug()
	local say = function(text)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. text)
	end

	local total = (GetNumEquipmentSets and GetNumEquipmentSets()) or 0
	local names = {}
	for index = 1, total do
		local name, icon = GetEquipmentSetInfo(index)
		names[#names + 1] = string.format("%d=%s(%s)", index, tostring(name), tostring(icon))
	end
	say(string.format(L.EQUIPMENTMANAGER_DEBUG_SETS, total,
		table.concat(names, ", ")))

	say(L.EQUIPMENTMANAGER_DEBUG_KEPT_ORDER .. table.concat(savedOrder(), ", "))

	local ranks = {}
	for position, index in ipairs(orderedSets()) do
		ranks[#ranks + 1] = string.format("%d<-%d", position, index)
	end
	say(L.EQUIPMENTMANAGER_DEBUG_PLACED_ORDER .. table.concat(ranks, ", "))
	say(string.format(L.EQUIPMENTMANAGER_DEBUG_SCROLL,
		offset, visibleCards(), (panel and panel:IsShown()) and L.EQUIPMENTMANAGER_DEBUG_OPEN or L.EQUIPMENTMANAGER_DEBUG_CLOSED))
	say(string.format(L.EQUIPMENTMANAGER_DEBUG_WORN,
		tostring(ForeverUIDB and ForeverUIDB.equippedSet), tostring(editSession and editSession.old)))

	local dialog = _G["GearManagerDialog"]
	if not dialog or not dialog.buttons then
		say(L.EQUIPMENTMANAGER_DEBUG_NO_DIALOG)
		return
	end
	for index, button in ipairs(dialog.buttons) do
		if button.name and button.name ~= "" or button:IsShown() then
			local anchor = button:GetPoint(1)
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				L.EQUIPMENTMANAGER_DEBUG_CARD,
				index, tostring(button.name), tostring(button:IsShown()),
				tostring(anchor),
				tostring(button.foreverCheck and button.foreverCheck:IsShown())))
		end
	end
end

function ForeverUI.EquipmentSetsRefresh()
    -- Forget the known state so the next poll lays out the list, whenever the client is done.
    ForeverUI.EquipmentSetsForget()
    listRecheck:Show()
end
