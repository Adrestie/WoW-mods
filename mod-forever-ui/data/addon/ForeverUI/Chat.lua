-- ForeverUI: the chat window with Camelot's layout. The art files are the same as in 3.3.5;
-- only the positions change, plus a scroll bar, a scroll-to-bottom button and Camelot's friends
-- button. The WotLK chat code is kept: no function is replaced, the ones that reset what we
-- change are hooked (hooksecurefunc). At rest only the messages stay visible.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local C = {}
ForeverUI.Chat = C

local SEP = string.char(92)
local L = ForeverUI.L

-- Camelot layout values (FloatingChatFrame, FCF_SetButtonSide, MinimalScrollBar,
-- ScrollToBottomButton, ChatTabArtTemplate, FCFDock_*)
local G = {
	backgroundLeft = -2, backgroundTop = 3, backgroundRight = 7 + 8, backgroundBottom = -6,
	columnX = 3, columnTop = -3, columnBottom = 6,
	minimizeY = 4,
	friends = 32, friendsY = 27,
	backW = 17, backH = 15, returnX = -2, returnY = -2, barBottom = 2,
	barAlpha = 0.6, returnAlpha = 0.65,
	fadeIn = 0.15, returnFadeIn = 0.1, origin = 2.0,
	idleBackground = 0,
	flashFadeIn = 0.1, flashHold = 0.5,
	lineSpacing = 2,
	tabSide = 2, tabMargins = 20, tabTextY = -5,
	tabGap = 1, mobileTabY = -1, overflowGap = 5, overflowY = -1,
	inputX = -5, inputY = -2, inputRight = 8,
}

local ATLAS = {
	backButton = "minimal-scrollbar-arrow-returntobottom-c60",
	returnDown = "minimal-scrollbar-arrow-returntobottom-down-c60",
	returnHover = "minimal-scrollbar-arrow-returntobottom-over-c60",
	friends = "quickjoin-button-friendslist-up",
	friendsDown = "quickjoin-button-friendslist-down",
}

C.windows = {}

-- ------------------------------------------------------------ button column

-- Camelot's FCF_SetButtonSide: the button column is anchored to the background
local function placeColumn(window)
	local bf = window.buttonFrame
	local background = _G[window:GetName() .. "Background"]
	if not (bf and background) then return end
	bf:ClearAllPoints()
	if window.buttonSide == "right" then
		bf:SetPoint("TOPLEFT", background, "TOPRIGHT", G.columnX, G.columnTop)
		bf:SetPoint("BOTTOMLEFT", background, "BOTTOMRIGHT", G.columnX, G.columnBottom)
	else
		bf:SetPoint("TOPRIGHT", background, "TOPLEFT", -G.columnX, G.columnTop)
		bf:SetPoint("BOTTOMRIGHT", background, "BOTTOMLEFT", -G.columnX, G.columnBottom)
	end
end

-- Hides the up / down / bottom buttons; the window's OnShow shows them again
local function hideArrows(window)
	local name = window:GetName()
	for _, suffix in ipairs({ "ButtonFrameUpButton", "ButtonFrameDownButton", "ButtonFrameBottomButton" }) do
		local b = _G[name .. suffix]
		if b then
			b:SetAlpha(0)
			b:EnableMouse(false)
			b:Hide()
		end
	end
end

-- Friends button: left or right of the default chat's button column
local function placeFriends()
	local b = FriendsMicroButton
	local bf = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.buttonFrame
	if not (b and bf) then return end
	b:ClearAllPoints()
	if DEFAULT_CHAT_FRAME.buttonSide == "right" then
		b:SetPoint("BOTTOMRIGHT", bf, "TOPRIGHT", 0, G.friendsY)
	else
		b:SetPoint("BOTTOMLEFT", bf, "TOPLEFT", 0, G.friendsY)
	end
end

local function skinFriends()
	local b = FriendsMicroButton
	if not b or b.foreverChat then return end
	b.foreverChat = true
	b:SetWidth(G.friends)
	b:SetHeight(G.friends)
	for _, state in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", ATLAS.friends },
		{ "SetPushedTexture", "GetPushedTexture", ATLAS.friendsDown },
	}) do
		local e = ForeverUI.AtlasEntry(state[3])
		b[state[1]](b, e and e[1] or "")
		local t = b[state[2]](b)
		if t then
			ForeverUI.SetAtlas(t, state[3], true)
			t:ClearAllPoints()
			t:SetAllPoints(b)
		end
	end
	placeFriends()
end

-- ------------------------------------------------------------ scroll bar

local function fontSize(window)
	local _, size = window:GetFont()
	return size or 14
end

-- What the bar shows: message count, how many fit, and the position in messages from the top.
-- 3.3.5 counts the scroll in messages from the bottom (GetCurrentScroll).
local function scrollState(window)
	local total = window:GetNumMessages() or 0
	local visibleCount = math.max(1, math.floor((window:GetHeight() or 0) / (fontSize(window) + G.lineSpacing)))
	local maxValue = math.max(0, total - visibleCount)
	local fromBottom = window.GetCurrentScroll and window:GetCurrentScroll() or 0
	return total, visibleCount, math.max(0, math.min(maxValue, maxValue - fromBottom)), maxValue
end

-- Moving the bar scrolls the chat by the difference (SetScrollOffset when the client has it)
function C.scrollTo(window, rank)
	local _, _, current, maxValue = scrollState(window)
	local wanted = math.max(0, math.min(maxValue, rank))
	if window.SetScrollOffset then
		window:SetScrollOffset(maxValue - wanted)
	else
		for _ = 1, current - wanted do window:ScrollUp() end
		for _ = 1, wanted - current do window:ScrollDown() end
	end
	C.updateBar(window)
end

function C.updateBar(window)
	local d = C.windows[window]
	if not d then return end
	local total, visibleCount, rank = scrollState(window)
	d.bar:Configure(total, visibleCount, rank)
end

-- ------------------------------------------------------------ scroll-to-bottom button

local function createReturnButton(window)
	local name = window:GetName()
	local b = CreateFrame("Button", name .. "ForeverScrollToBottom", window)
	b:SetWidth(G.backW)
	b:SetHeight(G.backH)
	b:SetPoint("BOTTOMRIGHT", window.resizeButton, "TOPRIGHT", G.returnX, G.returnY)
	for _, state in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", ATLAS.backButton },
		{ "SetPushedTexture", "GetPushedTexture", ATLAS.returnDown },
		{ "SetHighlightTexture", "GetHighlightTexture", ATLAS.returnHover },
	}) do
		local e = ForeverUI.AtlasEntry(state[3])
		b[state[1]](b, e and e[1] or "")
		local t = b[state[2]](b)
		if t then
			ForeverUI.SetAtlas(t, state[3], true)
			t:ClearAllPoints()
			t:SetAllPoints(b)
		end
	end
	local flash = b:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(flash, ATLAS.backButton, true)
	flash:SetBlendMode("ADD")
	flash:SetAllPoints(b)
	flash:SetAlpha(0)
	b.flash = flash
	b:SetAlpha(0)
	b:SetScript("OnClick", function()
		PlaySound("igChatBottom")
		window:ScrollToBottom()
		C.updateBar(window)
	end)
	return b
end

-- ------------------------------------------------------------ idle state

-- Appends frame's regions to inside, skipping those in exclude (animated by the client)
local function regions(frame, exclude, inside)
	for _, r in ipairs({ frame:GetRegions() }) do
		if not exclude[r] then table.insert(inside, r) end
	end
end

-- What fades out at rest: the tab's regions (not its alert glow; TabFlash is a child frame),
-- the column buttons (not the hidden arrows), and for the default chat the menu button, the
-- friends button and the dock overflow button (not its highlight, which flashes on alerts).
-- The input box regions are kept apart.
function C.recordIdle(window)
	local d = C.windows[window]
	local name = window:GetName()
	d.faded, d.input = {}, {}
	local tab = _G[name .. "Tab"]
	if tab then
		regions(tab, { [tab.glow or false] = true }, d.faded)
	end
	local arrows = {}
	for _, suffix in ipairs({ "ButtonFrameUpButton", "ButtonFrameDownButton", "ButtonFrameBottomButton" }) do
		if _G[name .. suffix] then arrows[_G[name .. suffix]] = true end
	end
	for _, b in ipairs({ window.buttonFrame:GetChildren() }) do
		if not arrows[b] then table.insert(d.faded, b) end
	end
	if window == DEFAULT_CHAT_FRAME then
		if ChatFrameMenuButton then table.insert(d.faded, ChatFrameMenuButton) end
		if FriendsMicroButton then table.insert(d.faded, FriendsMicroButton) end
		local overhang = GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.overflowButton
		if overhang then regions(overhang, { [overhang:GetHighlightTexture() or false] = true }, d.faded) end
	end
	if window.editBox then regions(window.editBox, {}, d.input) end
end

-- Applies the idle factor every frame (the client resets the tab text alpha);
-- the active input box stays fully visible
function C.applyIdle(window)
	local d = C.windows[window]
	local input = window.editBox
	local active = input and (ACTIVE_CHAT_EDIT_BOX == input or input:HasFocus()) and true or false
	for _, object in ipairs(d.faded) do object:SetAlpha(d.idle) end
	for _, r in ipairs(d.input) do r:SetAlpha(active and 1 or d.idle) end
end

-- Lining: a copy of each background and border texture, with the same parent, layer and anchors.
-- The client paints the background; the lining tops it up.
function C.createLining(window)
	local d = C.windows[window]
	local name = window:GetName()
	d.doubles = {}
	for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do
		local o = _G[name .. suffix]
		if o then
			local t = o:GetParent():CreateTexture(nil, (o:GetDrawLayer()))
			t:SetTexture(o:GetTexture())
			t:SetTexCoord(o:GetTexCoord())
			t:SetAllPoints(o)
			t:SetAlpha(0)
			t:Hide()
			table.insert(d.doubles, { o, t })
		end
	end
end

-- Adds what the client's background lacks to reach the lit opacity, max(opacity, 0.25):
-- alpha = 1 - (1 - wanted) / (1 - client); nothing when the client already reaches it
function C.applyLining(window)
	local d = C.windows[window]
	local wanted = math.max(window.oldAlpha or 0, DEFAULT_CHATFRAME_ALPHA or 0.25) * d.idle
	for _, pair in ipairs(d.doubles) do
		local o, t = pair[1], pair[2]
		local client = o:GetAlpha()
		if o:IsShown() and wanted > client + 0.001 then
			t:SetVertexColor(o:GetVertexColor())
			t:SetAlpha(1 - (1 - wanted) / (1 - client))
			t:Show()
		elseif t:IsShown() then
			t:SetAlpha(0)
			t:Hide()
		end
	end
end

-- ------------------------------------------------------------ tabs

C.tabs = {}

-- Camelot's ChatTabArtTemplate: the sides overhang the tab by 2, the middle stretches between
-- them (selected and highlight textures follow). The text is centered, except on whisper tabs,
-- where it stays left after the icon (FCF_OpenTemporaryWindow).
function C.skinTab(tab)
	if not tab or C.tabs[tab] then return end
	local name = tab:GetName()
	local left, middle, right = _G[name .. "Left"], _G[name .. "Middle"], _G[name .. "Right"]
	if not (left and middle and right) then return end
	C.tabs[tab] = true
	left:ClearAllPoints()
	left:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", -G.tabSide, 0)
	right:ClearAllPoints()
	right:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", G.tabSide, 0)
	middle:ClearAllPoints()
	middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
	middle:SetPoint("RIGHT", right, "LEFT", 0, 0)
	local text = _G[name .. "Text"]
	if text and not tab.conversationIcon then
		text:ClearAllPoints()
		text:SetPoint("CENTER", tab, "CENTER", 0, G.tabTextY)
	end
end

-- Camelot's PanelTemplates_TabResize: text + 20 + margin, at least both sides;
-- with a forced size, the text takes the rest
function C.resize(tab, margin, size, fixedTextWidth)
	local name = tab:GetName()
	local text = _G[name .. "Text"]
	if not text then return end
	margin = margin or 0
	text:SetWidth(fixedTextWidth or 0)
	local textWidth = text:GetStringWidth()
	local width = textWidth + G.tabMargins + margin
	local sides = _G[name .. "Left"]:GetWidth() + _G[name .. "Right"]:GetWidth()
	if size then
		width = math.max(size, sides)
		textWidth = width - G.tabMargins - margin
	elseif width < sides then
		width = sides
		textWidth = width - G.tabMargins - margin
	end
	text:SetWidth(textWidth)
	tab:SetWidth(width)
end

-- Camelot's FCFDock_SetPrimary: the dock sits on top of the primary chat's background
function C.placeDockAnchor(dock)
	local primary = dock and dock.primary
	local background = primary and _G[primary:GetName() .. "Background"]
	if not background then return end
	dock:ClearAllPoints()
	dock:SetPoint("BOTTOMLEFT", background, "TOPLEFT", 0, 0)
	dock:SetPoint("BOTTOMRIGHT", background, "TOPRIGHT", 0, 0)
end

-- Camelot's FCFDock_UpdateTabs: fixed tabs from the dock's bottom left, whisper tabs from the
-- scroll list's left, 1 apart; the overflow button at the dock's bottom right, the list 5
-- before it
function C.placeDock(dock)
	if not (dock and dock.DOCKED_CHAT_FRAMES and dock.scrollFrame) then return end
	local child = dock.scrollFrame:GetScrollChild()
	local lastFixed, lastMobile
	for _, window in ipairs(dock.DOCKED_CHAT_FRAMES) do
		local tab = _G[window:GetName() .. "Tab"]
		if tab then
			tab:ClearAllPoints()
			if window.isStaticDocked then
				if lastFixed then
					tab:SetPoint("LEFT", lastFixed, "RIGHT", G.tabGap, 0)
				else
					tab:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0)
				end
				lastFixed = tab
			else
				if lastMobile then
					tab:SetPoint("LEFT", lastMobile, "RIGHT", G.tabGap, 0)
				elseif child then
					tab:SetPoint("LEFT", child, "LEFT", 0, G.mobileTabY)
				end
				lastMobile = tab
			end
		end
	end
	local overhang = dock.overflowButton
	if overhang then
		overhang:ClearAllPoints()
		overhang:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, 0)
	end
	if overhang and overhang:IsShown() then
		dock.scrollFrame:SetPoint("BOTTOMRIGHT", overhang, "BOTTOMLEFT", -G.overflowGap, G.overflowY)
	else
		dock.scrollFrame:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, 0)
	end
end

-- Skins a window's tab, then sizes it (the dock's size if it is in the scroll list)
local function skinTabOf(window)
	local tab = _G[window:GetName() .. "Tab"]
	C.skinTab(tab)
	if not C.tabs[tab] then return end
	local dock = GENERAL_CHAT_DOCK
	local size
	if window.isDocked and not window.isStaticDocked and dock and dock.scrollFrame then
		size = dock.scrollFrame.dynTabSize
	end
	C.resize(tab, tab.sizePadding or 0, size)
end

-- ------------------------------------------------------------ selection

-- Alt + drag on the chat highlights text. 3.3.5 reaches the clipboard only by Ctrl+C in an
-- edit box, so a hidden read-only box holds the text and takes the keyboard only while Ctrl is
-- held (3.3.5 cannot see a key without taking the keyboard). Any other action clears the
-- selection: Ctrl released, a click, moving, casting, another edit box, a panel, Escape, scrolling.
-- The engine draws one font string per message, wrapped at the chat width without indent; a
-- measuring string with the same font and width wraps the same way, so a word's line comes from
-- the text height up to that word. A word longer than a line is measured letter by letter.

local S = { hidden = {} }
C.selection = S

-- Calls a method the client may lack: nil instead of an error
local function call(object, method, ...)
	if not object[method] then return nil end
	local r = { pcall(object[method], object, ...) }
	if not r[1] then return nil end
	return r[2], r[3], r[4], r[5]
end

-- Highlight color (not a Camelot element)
S.color = { 0.3, 0.5, 1, 0.4 }

-- Raid markers as typed in chat: the client's ICON_TAG_RAID_TARGET_*1 tag
-- ({rt1} to {rt8} in English)
local MARKERS = { "STAR", "CIRCLE", "DIAMOND", "TRIANGLE", "MOON", "SQUARE", "CROSS", "SKULL" }
local function imageTag(raw)
	local n = tonumber(string.match(raw, "RaidTargetingIcon_(%d)"))
	local name = n and MARKERS[n] and _G["ICON_TAG_RAID_TARGET_" .. MARKERS[n] .. "1"]
	return name and ("{" .. name .. "}") or ""
end

-- Visible units of a message: a letter (UTF-8), a bar (||), an image (|T...|t);
-- color codes (|c, |r) and link codes (|H...|h, |h) are invisible, the link text is kept;
-- an image copies as its raid marker tag
function C.units(text)
	local u, i, n = {}, 1, string.len(text or "")
	while i <= n do
		local c = string.sub(text, i, i)
		if c == "|" then
			local s = string.sub(text, i + 1, i + 1)
			if s == "c" then
				i = i + 10
			elseif s == "r" or s == "h" then
				i = i + 2
			elseif s == "H" then
				local finish = string.find(text, "|h", i + 2, true)
				i = finish and finish + 2 or n + 1
			elseif s == "T" then
				local finish = string.find(text, "|t", i + 2, true) or n
				local raw = string.sub(text, i, finish + 1)
				table.insert(u, { raw = raw, copy = imageTag(raw) })
				i = finish + 2
			elseif s == "n" then
				table.insert(u, { raw = "", copy = "\n" })
				i = i + 2
			else
				table.insert(u, { raw = "||", copy = "|" })
				i = i + (s == "|" and 2 or 1)
			end
		else
			local b = string.byte(c)
			local l = (b >= 240 and 4) or (b >= 224 and 3) or (b >= 192 and 2) or 1
			local letter = string.sub(text, i, i + l - 1)
			table.insert(u, { raw = letter, copy = letter, space = (letter == " ") })
			i = i + l
		end
	end
	return u
end

-- Raw text of units a to b
local function raw(units, a, b)
	local t = {}
	for k = a, b do t[#t + 1] = units[k].raw end
	return table.concat(t)
end

-- Two hidden measuring strings, one on a single line, one at the message width;
-- they take the font and settings of the measured font string
local measureStrings
local function measureMessage(r, c)
	if not measureStrings then
		local frame = CreateFrame("Frame", nil, UIParent)
		frame:SetAlpha(0)
		frame:SetWidth(1)
		frame:SetHeight(1)
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
		measureStrings = { row = frame:CreateFontString(nil, "ARTWORK"), block = frame:CreateFontString(nil, "ARTWORK") }
		measureStrings.row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		measureStrings.block:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	end
	local font, size, outline = r:GetFont()
	for _, m in pairs(measureStrings) do
		m:SetFont(font, size, outline)
		if m.SetSpacing then m:SetSpacing(call(r, "GetSpacing") or 0) end
	end
	measureStrings.row:SetWidth(0)
	measureStrings.block:SetWidth(c and c.width or r:GetWidth())
	if measureStrings.block.SetIndentedWordWrap then measureStrings.block:SetIndentedWordWrap(call(r, "GetIndentedWordWrap") and true or false) end
	if measureStrings.block.SetNonSpaceWrap then measureStrings.block:SetNonSpaceWrap(call(r, "CanNonSpaceWrap") and true or false) end
	return measureStrings
end

-- Line layout of a chat font string: its units, the first unit of each line, the line height;
-- cached while its text and width do not change
function C.layout(r)
	local text, width = r:GetText() or "", r:GetWidth()
	local c = S.hidden[r]
	if c and c.text == text and c.width == width then return c end
	c = { text = text, width = width, widths = {} }
	local m = measureMessage(r, c)
	m.row:SetText("A")
	c.lineHeight = math.max(1, m.row:GetStringHeight())
	local u = C.units(text)
	c.units = u
	local function rows(b)
		m.block:SetText(raw(u, 1, b))
		return math.floor(m.block:GetStringHeight() / c.lineHeight + 0.5)
	end
	local starts, done = { 1 }, 1
	local a, n = 1, #u
	while a <= n do
		while a <= n and u[a].space do a = a + 1 end
		if a > n then break end
		local b = a
		while b < n and not u[b + 1].space do b = b + 1 end
		local L = rows(b)
		if L > done then
			m.row:SetText(raw(u, a, b))
			if m.row:GetStringWidth() <= width then
				-- the word moves to the next line
				for k = done + 1, L do starts[k] = a end
			else
				-- a word longer than a line: break by letter
				for v = a, b do
					local Lv = rows(v)
					for k = done + 1, Lv do starts[k] = v end
					if Lv > done then done = Lv end
				end
			end
			done = math.max(done, L)
		end
		a = b + 1
	end
	c.starts, c.lineCount = starts, #starts
	S.hidden[r] = c
	return c
end

-- Width from the start of line n to boundary b (before unit b)
local function widthUpTo(r, c, n, b)
	local start = c.starts[n]
	if b <= start then return 0 end
	local key = n * 100000 + b
	if not c.widths[key] then
		local m = measureMessage(r, c)
		m.row:SetText(raw(c.units, start, b - 1))
		c.widths[key] = m.row:GetStringWidth()
	end
	return c.widths[key]
end

-- Displayed messages, top to bottom
function C.visibleMessages(window)
	local list = {}
	for _, r in ipairs({ window:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:IsVisible() and (r:GetAlpha() or 0) > 0.01
			and (r:GetText() or "") ~= "" and r:GetTop() then
			table.insert(list, r)
		end
	end
	table.sort(list, function(p, q) return p:GetTop() > q:GetTop() end)
	return list
end

-- Cursor position in the chat's scale
local function cursor(window)
	local x, y = GetCursorPosition()
	local e = window:GetEffectiveScale()
	return x / e, y / e
end

-- Under the cursor: the message rank and the nearest boundary;
-- above the first message, its start; below the last, its end
function C.hitTest(list, x, y)
	if #list == 0 then return nil end
	if y > list[1]:GetTop() then return 1, 1 end
	for rank, r in ipairs(list) do
		if y >= r:GetBottom() or rank == #list then
			local c = C.layout(r)
			if y < r:GetBottom() then return rank, #c.units + 1 end
			local n = math.min(c.lineCount, math.max(1, math.floor((r:GetTop() - y) / c.lineHeight) + 1))
			local start = c.starts[n]
			local finish = c.starts[n + 1] or (#c.units + 1)
			local xr = x - r:GetLeft()
			local down, top = start, finish
			while down < top do
				local middle = math.floor((down + top) / 2)
				if widthUpTo(r, c, n, middle) < xr then down = middle + 1 else top = middle end
			end
			local b = down
			if b > start and (xr - widthUpTo(r, c, n, b - 1)) < (widthUpTo(r, c, n, b) - xr) then
				b = b - 1
			end
			return rank, b
		end
	end
end

-- Anchor and tip, in reading order
local function bounds()
	local a, b = S.anchor, S.tip
	if a[1] > b[1] or (a[1] == b[1] and a[2] > b[2]) then a, b = b, a end
	return a, b
end

-- Highlight: one rectangle per line piece, on the chat itself
-- (BORDER layer: below the text)
function C.paint()
	local d = S.window and C.windows[S.window]
	if not d then return end
	local k = 0
	if S.anchor and S.tip then
		local a, b = bounds()
		for rank = a[1], b[1] do
			local r = S.messages[rank]
			local c = C.layout(r)
			local first = (rank == a[1]) and a[2] or 1
			local last = (rank == b[1]) and b[2] or (#c.units + 1)
			for n = 1, c.lineCount do
				local p = math.max(c.starts[n], first)
				local q = math.min(c.starts[n + 1] or (#c.units + 1), last)
				if p < q then
					local x1, x2 = widthUpTo(r, c, n, p), widthUpTo(r, c, n, q)
					if x2 > x1 then
						k = k + 1
						local t = d.highlights[k]
						if not t then
							t = S.window:CreateTexture(nil, "BORDER")
							t:SetTexture(S.color[1], S.color[2], S.color[3], S.color[4])
							d.highlights[k] = t
						end
						t:ClearAllPoints()
						t:SetPoint("TOPLEFT", r, "TOPLEFT", x1, -(n - 1) * c.lineHeight)
						t:SetWidth(x2 - x1)
						t:SetHeight(c.lineHeight)
						t:Show()
					end
				end
			end
		end
	end
	for i = k + 1, #d.highlights do d.highlights[i]:Hide() end
end

-- Text to copy: what is visible, links by their text, markers by name; one message per line
function C.selectionText()
	if not (S.anchor and S.tip) then return "" end
	local a, b = bounds()
	local parts = {}
	for rank = a[1], b[1] do
		local c = C.layout(S.messages[rank])
		local first = (rank == a[1]) and a[2] or 1
		local last = (rank == b[1]) and b[2] or (#c.units + 1)
		local t = {}
		for k = first, last - 1 do t[#t + 1] = c.units[k].copy end
		parts[#parts + 1] = table.concat(t)
	end
	return table.concat(parts, "\n")
end

-- Hidden edit box holding the copy; read-only: typed text is undone
local box = CreateFrame("EditBox", nil, UIParent)
box:SetMultiLine(true)
box:SetAutoFocus(false)
box:SetFontObject(ChatFontNormal)
box:SetWidth(200)
box:SetHeight(20)
box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
box:SetAlpha(0)
box:EnableMouse(false)
S.box = box

function C.clear()
	local d = S.window and C.windows[S.window]
	S.window, S.messages, S.anchor, S.tip, S.dragging, S.text = nil, nil, nil, nil, false, nil
	S.ctrl, S.base = false, nil
	if d then
		for _, t in ipairs(d.highlights) do t:Hide() end
	end
	if box:HasFocus() then box:ClearFocus() end
end

box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
box:SetScript("OnEditFocusLost", function()
	if S.text then C.clear() end
end)
box:SetScript("OnTextChanged", function(self, userInput)
	if userInput and S.text then
		self:SetText(S.text)
		self:HighlightText()
	end
end)

function C.beginSelection(window)
	C.clear()
	local list = C.visibleMessages(window)
	local rank, b = C.hitTest(list, cursor(window))
	if not rank then return end
	S.window, S.messages, S.dragging = window, list, true
	S.anchor, S.tip = { rank, b }, { rank, b }
	C.paint()
end

-- Moves the selection tip to the cursor
function C.follow()
	local rank, b = C.hitTest(S.messages, cursor(S.window))
	if rank and (rank ~= S.tip[1] or b ~= S.tip[2]) then
		S.tip = { rank, b }
		C.paint()
	end
end

-- Ends the drag and puts the selected text in the hidden box
function C.finalize()
	if not S.dragging then return end
	C.follow()
	S.dragging = false
	local text = C.selectionText()
	if text == "" then
		C.clear()
		return
	end
	S.text = text
	box:SetText(text)
	-- State watched to clear the selection: the character, the chat scroll, the selected texts
	local speed = GetUnitSpeed and GetUnitSpeed("player") or 0
	S.base = {
		taxi = UnitOnTaxi and UnitOnTaxi("player") and true or false,
		speed = speed,
		facing = GetPlayerFacing and GetPlayerFacing() or 0,
		falling = IsFalling and IsFalling() and true or false,
		scrolling = S.window.GetCurrentScroll and S.window:GetCurrentScroll() or 0,
		texts = {},
	}
	for rank, r in ipairs(S.messages) do S.base.texts[rank] = r:GetText() end
end

-- Any action other than Ctrl+C since the selection was made?
function C.otherInput()
	local b = S.base
	if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") or IsMouseButtonDown("MiddleButton") then
		return true
	end
	if not S.window:IsVisible() then return true end
	local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
	if focus and focus ~= box then return true end
	if not b.taxi then
		if (GetUnitSpeed and GetUnitSpeed("player") or 0) ~= b.speed then return true end
		if math.abs((GetPlayerFacing and GetPlayerFacing() or 0) - b.facing) > 0.001 then return true end
		if (IsFalling and IsFalling() and true or false) ~= b.falling then return true end
	end
	if (S.window.GetCurrentScroll and S.window:GetCurrentScroll() or 0) ~= b.scrolling then return true end
	for rank, r in ipairs(S.messages) do
		if r:GetText() ~= b.texts[rank] then return true end
	end
	return false
end

-- Once selected: Ctrl down gives the hidden box the keyboard;
-- Ctrl up, or any other action, clears the selection
function C.watchCopy()
	if IsControlKeyDown() then
		if not S.ctrl then
			S.ctrl = true
			box:SetText(S.text)
			box:SetFocus()
			box:HighlightText()
		end
	elseif S.ctrl then
		C.clear()
		return
	end
	if C.otherInput() then C.clear() end
end

-- Mouse catcher over the chat, active only while Alt is held;
-- without Alt, clicks pass through to the world and links
function C.createCatcher(window, d)
	d.highlights = {}
	local catcher = CreateFrame("Frame", nil, window)
	catcher:SetAllPoints(window)
	catcher:EnableMouse(false)
	catcher:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then C.beginSelection(window) end
	end)
	catcher:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then C.finalize() end
	end)
	d.catcher, d.grab = catcher, false
end

local selectionWatcher = CreateFrame("Frame")
selectionWatcher:SetScript("OnUpdate", function()
	local alt = IsAltKeyDown() and true or false
	for window, d in pairs(C.windows) do
		local grab = ((alt and window:IsVisible()) or (S.dragging and S.window == window)) and true or false
		if grab ~= d.grab then
			d.grab = grab
			d.catcher:EnableMouse(grab)
		end
	end
	if S.dragging then
		C.follow()
	elseif S.text then
		C.watchCopy()
	end
end)
C.selectionWatcher = selectionWatcher

-- A spell cast, a panel opened or Escape clears the selection
local function cancelCopy()
	if S.text and not S.dragging then C.clear() end
end
selectionWatcher:RegisterEvent("UNIT_SPELLCAST_SENT")
selectionWatcher:SetScript("OnEvent", function(_, _, unit)
	if unit == "player" then cancelCopy() end
end)
if ShowUIPanel then hooksecurefunc("ShowUIPanel", cancelCopy) end
if ToggleGameMenu then hooksecurefunc("ToggleGameMenu", cancelCopy) end

-- ------------------------------------------------------------ window skin

function C.applySkin(window)
	if not window or C.windows[window] or not window.buttonFrame then return end
	local name = window:GetName()
	-- The background overhangs on the right to hold the scroll bar
	local background = _G[name .. "Background"]
	if background then
		background:ClearAllPoints()
		background:SetPoint("TOPLEFT", window, "TOPLEFT", G.backgroundLeft, G.backgroundTop)
		background:SetPoint("TOPRIGHT", window, "TOPRIGHT", G.backgroundRight, G.backgroundTop)
		background:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", G.backgroundLeft, G.backgroundBottom)
		background:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", G.backgroundRight, G.backgroundBottom)
	end
	hideArrows(window)
	window:HookScript("OnShow", hideArrows)
	local bf = window.buttonFrame
	if bf.minimizeButton then
		bf.minimizeButton:ClearAllPoints()
		bf.minimizeButton:SetPoint("TOP", bf, "TOP", 0, G.minimizeY)
	end
	placeColumn(window)

	local d = { window = window }
	d.backButton = createReturnButton(window)
	local bar = ForeverUI.CreateScrollBar(name .. "ForeverScrollBar", window, window)
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, 0)
	bar:SetPoint("BOTTOMLEFT", d.backButton, "TOPLEFT", 0, G.barBottom)
	bar:SetAlpha(0)
	bar.onScroll = function(rank) C.scrollTo(window, rank) end
	d.bar = bar
	-- Input box: TOPLEFT as in 3.3.5, right edge on the bar's right edge + 8 (camelot: RIGHT on the
	-- bar; the same point is taken on the chat, where the bar starts, so only TOPLEFT sets the height)
	local input = window.editBox
	if input then
		input:ClearAllPoints()
		input:SetPoint("TOPLEFT", window, "BOTTOMLEFT", G.inputX, G.inputY)
		input:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", bar:GetWidth() + G.inputRight, G.inputY)
	end
	skinTabOf(window)
	-- Target alphas: the bar and the return button light up with the chat
	d.barTarget, d.returnTarget = 0, 0
	d.barSpeed, d.returnSpeed = 1, 1
	d.flashTime = 0
	C.windows[window] = d
	C.createCatcher(window, d)
	C.recordIdle(window)
	C.createLining(window)
	d.isLit = window.hasBeenFaded and true or false
	d.hover, d.inside, d.outside = false, 0, 0
	d.idle = d.isLit and 1 or 0
	d.idleTarget = d.idle
	d.idleSpeed = 1
	C.applyIdle(window)
	C.updateBar(window)
end

-- ------------------------------------------------------------ fade

-- Target alphas of the bar and return button, with durations in seconds
local function setTargets(d, bar, backButton, barDuration, returnDuration)
	d.barTarget = bar
	d.returnTarget = backButton
	d.barSpeed = G.barAlpha / math.max(0.01, barDuration)
	d.returnSpeed = G.returnAlpha / math.max(0.01, returnDuration)
end

local function lightUp(d)
	setTargets(d, G.barAlpha, G.returnAlpha, G.fadeIn, G.returnFadeIn)
	d.idleTarget, d.idleSpeed = 1, 1 / G.fadeIn
end

local function turnOff(d)
	setTargets(d, 0, 0, G.origin, G.origin)
	d.idleTarget, d.idleSpeed = 0, 1 / G.origin
end

-- FCF_OnUpdate's hover zones, plus the bar and the return button (outside the chat)
local function isHovered(window, d)
	if not window:IsShown() then return false end
	local top = 28
	if IsCombatLog and CombatLogQuickButtonFrame_Custom and IsCombatLog(window) then
		top = top + CombatLogQuickButtonFrame_Custom:GetHeight()
	end
	return (window:IsMouseOver(top, -2, -2, 2)
		or (window.isDocked and FriendsMicroButton and FriendsMicroButton:IsMouseOver())
		or (window.buttonFrame and window.buttonFrame:IsMouseOver())
		or (d.bar:IsShown() and MouseIsOver(d.bar)) or MouseIsOver(d.backButton)) and true or false
end
C.isHovered = isHovered

-- Moves object's alpha toward target at speed per second
local function approach(object, target, speed, elapsed)
	local a = object:GetAlpha()
	if a < target then
		a = math.min(target, a + speed * elapsed)
	elseif a > target then
		a = math.max(target, a - speed * elapsed)
	end
	object:SetAlpha(a)
end

-- Every frame: the bar follows the chat, the fade advances, the return button flashes while
-- not at the bottom. FCF_OnUpdate lights the chat only if the cursor stays still, and calling
-- FCF_FadeInChatFrame would set hasBeenFaded from the addon: FCF_OnUpdate runs in UIParent's
-- OnUpdate before UnitPopup_OnUpdate, so the taint would reach the unit menus.
local engine = CreateFrame("Frame")
engine:SetScript("OnUpdate", function(self, elapsed)
	elapsed = elapsed or 0
	-- Hover: 0.2 s inside to light up, 1 s outside to turn off, cursor still or not;
	-- a lit docked window lights the whole dock
	local showRegion, hide = CHAT_TAB_SHOW_DELAY or 0.2, CHAT_TAB_HIDE_DELAY or 1
	local dock = false
	for window, d in pairs(C.windows) do
		if isHovered(window, d) then
			d.inside, d.outside = d.inside + elapsed, 0
			if d.inside >= showRegion then d.hover = true end
		else
			d.inside, d.outside = 0, d.outside + elapsed
			if d.outside >= hide then d.hover = false end
		end
		if d.hover and window.isDocked then dock = true end
	end
	for window, d in pairs(C.windows) do
		local isLit = (d.hover or window.hasBeenFaded or (dock and window.isDocked)) and true or false
		if isLit ~= d.isLit then
			d.isLit = isLit
			if isLit then lightUp(d) else turnOff(d) end
		end
		if d.idle < d.idleTarget then
			d.idle = math.min(d.idleTarget, d.idle + d.idleSpeed * elapsed)
		elseif d.idle > d.idleTarget then
			d.idle = math.max(d.idleTarget, d.idle - d.idleSpeed * elapsed)
		end
		C.applyIdle(window)
		C.applyLining(window)
		if window:IsShown() then
			C.updateBar(window)
			local atBottom = window:AtBottom()
			if atBottom then
				d.flashTime = 0
				d.backButton.flash:SetAlpha(0)
			else
				-- 0.1 s in, 0.5 s held, 0.1 s out, 0.5 s off (ScrollToBottomFlashInterval)
				local cycle = 2 * (G.flashFadeIn + G.flashHold)
				d.flashTime = (d.flashTime + elapsed) % cycle
				local t = d.flashTime
				local a
				if t < G.flashFadeIn then a = t / G.flashFadeIn
				elseif t < G.flashFadeIn + G.flashHold then a = 1
				elseif t < 2 * G.flashFadeIn + G.flashHold then a = 1 - (t - G.flashFadeIn - G.flashHold) / G.flashFadeIn
				else a = 0 end
				d.backButton.flash:SetAlpha(a)
			end
			-- Not at the bottom: the bar lights up and the return button stays visible
			local barTarget = atBottom and d.barTarget or G.barAlpha
			local returnTarget = atBottom and d.returnTarget or 1
			-- Not at the bottom, the bar fades in as in FCF_FadeInScrollbar
			approach(d.bar, barTarget, atBottom and d.barSpeed or G.barAlpha / G.fadeIn, elapsed)
			approach(d.backButton, returnTarget, math.max(d.returnSpeed, G.returnAlpha / G.returnFadeIn), elapsed)
		end
	end
end)
C.engine = engine

-- ------------------------------------------------------------ hooks

function C.skinAll()
	for _, name in ipairs(CHAT_FRAMES or {}) do
		C.applySkin(_G[name])
	end
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		C.applySkin(_G["ChatFrame" .. i])
	end
	skinFriends()
	-- Menu button at the bottom of the default chat's column
	if ChatFrameMenuButton and ChatFrame1ButtonFrame then
		ChatFrameMenuButton:ClearAllPoints()
		ChatFrameMenuButton:SetPoint("BOTTOM", ChatFrame1ButtonFrame, "BOTTOM", 0, 0)
	end
	-- The dock and its tabs (the client placed a newly skinned window's tab before the skin)
	C.placeDockAnchor(GENERAL_CHAT_DOCK)
	C.placeDock(GENERAL_CHAT_DOCK)
end

C.skinAll()

-- On first load, each window's saved background opacity is set to 0 once, so only messages
-- show at rest. The client keeps it; later changes from the tab menu are respected.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(self, _, addon)
	if addon ~= "ForeverUI" then return end
	self:UnregisterEvent("ADDON_LOADED")
	ForeverUIDB = ForeverUIDB or {}
	if ForeverUIDB.chatIdleBackground then return end
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		SetChatWindowAlpha(i, G.idleBackground)
	end
	ForeverUIDB.chatIdleBackground = true
end)
C.watcher = watcher

if FCF_SetButtonSide then
	hooksecurefunc("FCF_SetButtonSide", function(window)
		if C.windows[window] then placeColumn(window) end
		if window == DEFAULT_CHAT_FRAME then placeFriends() end
	end)
end
if FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", C.skinAll) end
-- Chat tab sizes only (the function serves every tab in the game);
-- the dock, after each client reorder
if PanelTemplates_TabResize then
	hooksecurefunc("PanelTemplates_TabResize", function(tab, margin, size, _, fixedTextWidth)
		if C.tabs[tab] then C.resize(tab, margin, size, fixedTextWidth) end
	end)
end
if FCFDock_UpdateTabs then hooksecurefunc("FCFDock_UpdateTabs", C.placeDock) end
if FCFDock_SetPrimary then hooksecurefunc("FCFDock_SetPrimary", C.placeDockAnchor) end

-- Diagnostics: /fui chat
function ForeverUI.ChatDebug()
	local say = function(t) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. t) end
	for window, d in pairs(C.windows) do
		if window:IsShown() then
			local total, visibleCount, rank, maxValue = scrollState(window)
			say(string.format(L.CHAT_DEBUG_STATE,
				window:GetName(), total, visibleCount, rank, maxValue, tostring(window:AtBottom()),
				d.bar:IsShown() and L.CHAT_DEBUG_SHOWN or L.CHAT_DEBUG_HIDDEN, d.bar:GetAlpha(), d.backButton:GetAlpha(),
				window.SetScrollOffset and L.CHAT_DEBUG_YES or L.CHAT_DEBUG_NO))
			-- What FCF_OnUpdate checks before fading the chat, and our pieces
			local function yes(v) return v and L.CHAT_DEBUG_YES_UPPER or L.CHAT_DEBUG_NO end
			say(string.format(L.CHAT_DEBUG_FADE,
				yes(d.isLit), yes(window.hasBeenFaded), yes(d.hover), d.outside,
				yes(window:IsMouseOver(28, -2, -2, 2)), yes(window.isDocked and FriendsMicroButton and FriendsMicroButton:IsMouseOver()),
				yes(window.buttonFrame and window.buttonFrame:IsMouseOver()),
				yes(d.bar:IsShown() and MouseIsOver(d.bar)), yes(MouseIsOver(d.backButton))))
			local _, _, _, _, _, opacity = GetChatWindowInfo(window:GetID())
			say(string.format(L.CHAT_DEBUG_REST,
				d.idle, d.idleTarget, #d.faded, #d.input, _G[window:GetName() .. "Background"]:GetAlpha(),
				opacity or -1, yes(ForeverUIDB and ForeverUIDB.chatIdleBackground)))
		end
	end
end

-- /fui chatlines: adds a long test message to the shown window and, two frames later, records
-- its font strings in ForeverUIDB.chatRecord (saved on the next /reload), to see how the engine
-- lays out chat lines. The text is L.CHAT_LINES_TEST (link then icon); the hearthstone name
-- comes from GetItemInfo, or its id while not cached.
local function test()
	local link = "|cffffffff|Hitem:6948:0:0:0:0:0:0:0:80|h[" .. (GetItemInfo(6948) or "6948") .. "]|h|r"
	return string.format(L.CHAT_LINES_TEST, link,
		"|TInterface" .. SEP .. "TargetingFrame" .. SEP .. "UI-RaidTargetingIcon_1:0|t")
end

local holder, measure
function C.recordLines(window)
	if not holder then
		holder = CreateFrame("Frame", nil, UIParent)
		holder:SetAlpha(0)
		holder:SetWidth(1)
		holder:SetHeight(1)
		holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
		measure = holder:CreateFontString(nil, "ARTWORK")
		measure:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
	end
	local rel = { window = window:GetName() }
	rel.left, rel.top, rel.right, rel.down = window:GetLeft(), window:GetTop(), window:GetRight(), window:GetBottom()
	rel.width, rel.height, rel.scale = window:GetWidth(), window:GetHeight(), window:GetEffectiveScale()
	rel.font, rel.size, rel.outline = window:GetFont()
	rel.spacing = call(window, "GetSpacing")
	rel.justification = call(window, "GetJustifyH")
	rel.indent = call(window, "GetIndentedWordWrap")
	rel.insertMode = call(window, "GetInsertMode")
	rel.messages = call(window, "GetNumMessages")
	rel.linesDisplayed = call(window, "GetNumLinesDisplayed")
	rel.currentLine = call(window, "GetCurrentLine")
	rel.scrolling = call(window, "GetCurrentScroll")
	-- Last messages, as the client keeps them
	rel.latest = {}
	local n = rel.messages or 0
	for i = math.max(1, n - 5), n do
		table.insert(rel.latest, { rank = i, text = (call(window, "GetMessageInfo", i)) })
	end
	-- The window's font strings
	rel.texts = {}
	local visibleCount = 0
	for rank, r in ipairs({ window:GetRegions() }) do
		if r:GetObjectType() == "FontString" then
			local t = { rank = rank }
			t.displayed, t.visible, t.alpha = r:IsShown() and true or false, r:IsVisible() and true or false, r:GetAlpha()
			t.left, t.top, t.right, t.down = r:GetLeft(), r:GetTop(), r:GetRight(), r:GetBottom()
			t.width, t.height = r:GetWidth(), r:GetHeight()
			t.textWidth, t.textHeight = r:GetStringWidth(), call(r, "GetStringHeight")
			t.text = r:GetText()
			t.red, t.green, t.blue, t.opacity = r:GetTextColor()
			t.font, t.size, t.outline = r:GetFont()
			t.justification = call(r, "GetJustifyH")
			t.wordWrap = call(r, "CanWordWrap")
			t.indent = call(r, "GetIndentedWordWrap")
			t.points = r:GetNumPoints()
			if t.points > 0 then
				local p, target, pc, x, y = r:GetPoint(1)
				t.point = string.format("%s %s %s %.2f %.2f", tostring(p),
					target and target.GetName and (target:GetName() or "?") or "nil", tostring(pc), x or 0, y or 0)
			end
			-- The measure we would make: same font, one line, then at the window width
			if t.text and t.font then
				measure:SetFont(t.font, t.size, t.outline)
				measure:SetWidth(0)
				measure:SetText(t.text)
				t.measure = measure:GetStringWidth()
				t.measureHeight = measure:GetStringHeight()
				measure:SetWidth(rel.width)
				t.measureWrapped = measure:GetStringHeight()
			end
			if t.visible then visibleCount = visibleCount + 1 end
			table.insert(rel.texts, t)
		end
	end
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.chatRecord = rel
	DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccffForeverUI|r " .. L.CHAT_LINES_RECORDED,
		rel.window, #rel.texts, visibleCount, n))
end

local pending = CreateFrame("Frame")
pending:Hide()
pending:SetScript("OnUpdate", function(self)
	self.images = self.images + 1
	if self.images < 3 then return end
	self:Hide()
	C.recordLines(self.window)
end)
C.pendingRecord = pending

function ForeverUI.ChatRecordLines()
	local window = (GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.selected) or DEFAULT_CHAT_FRAME
	if not (window and window:IsShown()) then window = DEFAULT_CHAT_FRAME end
	window:AddMessage(test(), 1, 1, 0)
	pending.window, pending.images = window, 0
	pending:Show()
end
