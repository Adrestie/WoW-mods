-- camelot's MinimalScrollBar, rebuilt: 3.3.5 has neither it nor the ScrollBox that drives it.
-- The caller gives the row count, the rows that fit and the offset; the bar returns the new
-- offset and touches no list.
-- Measured on the art, not the atlas names: thumb-bottom fades out (alpha 1 to 255 over 36 px),
-- so it is not used; both thumb ends are thumb-top, the bottom one flipped.
-- The arrows (17 x 11) overhang the 8-wide bar by 4.5 on each side.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local WIDTH = 8
local ARROW_W, ARROW_H = 17, 11
local CURSOR_TIP = 8                  -- minimal-scrollbar-thumb-top
local CURSOR_MIN = 2 * CURSOR_TIP    -- both ends, no middle
local TRACK_TIP = 8

local ATLAS = {
	trackTop = "minimal-scrollbar-track-top-c60",
	trackMiddle = "!minimal-scrollbar-track-middle-c60",
	trackBottom = "minimal-scrollbar-track-bottom-c60",
	cursorTip = "minimal-scrollbar-thumb-top-c60",
	cursorMiddle = "minimal-scrollbar-thumb-middle-c60",
	upArrow = "minimal-scrollbar-arrow-top-c60",
	upArrowHover = "minimal-scrollbar-arrow-top-over-c60",
	downArrow = "minimal-scrollbar-arrow-bottom-c60",
	downArrowHover = "minimal-scrollbar-arrow-bottom-over-c60",
}

-- Mouse Y in a frame's coordinates: GetCursorPosition returns screen coordinates, so divide
-- by the frame's effective scale.
local function mouse(frame)
	local _, y = GetCursorPosition()
	return y / (frame:GetEffectiveScale() or 1)
end

-- Arrow button; step: rows moved per click (-1 up, 1 down).
local function createArrow(bar, name, atlas, hoverAtlas, step)
	local button = CreateFrame("Button", name, bar)
	button:SetWidth(ARROW_W)
	button:SetHeight(ARROW_H)

	local image = button:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(image, atlas, true)
	image:SetAllPoints(button)
	button.image = image

	button:SetScript("OnEnter", function(self)
		ForeverUI.SetAtlas(self.image, hoverAtlas, true)
	end)
	button:SetScript("OnLeave", function(self)
		ForeverUI.SetAtlas(self.image, atlas, true)
	end)
	button:SetScript("OnClick", function()
		bar:MoveTo(bar.offset + step)
	end)

	return button
end

-- name: global name (arrows and thumb derive theirs from it); parent: owner frame;
-- list: the scrolled frame, which the bar anchors to as camelot's does to its ScrollBox.
function ForeverUI.CreateScrollBar(name, parent, list)
	local bar = CreateFrame("Frame", name, parent)
	bar:SetWidth(WIDTH)
	bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 5, -2)
	bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 5, 4)

	bar.total = 0
	bar.visibleCount = 0
	bar.offset = 0

	local top = createArrow(bar, name .. "Up", ATLAS.upArrow,
		ATLAS.upArrowHover, -1)
	top:SetPoint("TOP", bar, "TOP", 0, 0)
	bar.upArrow = top

	local down = createArrow(bar, name .. "Down", ATLAS.downArrow,
		ATLAS.downArrowHover, 1)
	down:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
	bar.downArrow = down

	-- Track between the arrows: two rounded ends and a stretched middle.
	local track = CreateFrame("Frame", nil, bar)
	track:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
	track:SetPoint("BOTTOMRIGHT", down, "TOPRIGHT", 0, 0)
	track:SetWidth(WIDTH)
	bar.track = track

	local function slice(frame, atlas, layer)
		local t = frame:CreateTexture(nil, layer or "BACKGROUND")
		ForeverUI.SetAtlas(t, atlas, true)
		t:SetWidth(WIDTH)
		return t
	end

	local trackTop = slice(track, ATLAS.trackTop)
	trackTop:SetHeight(TRACK_TIP)
	trackTop:SetPoint("TOP", track, "TOP", 0, 0)
	local trackBottom = slice(track, ATLAS.trackBottom)
	trackBottom:SetHeight(TRACK_TIP)
	trackBottom:SetPoint("BOTTOM", track, "BOTTOM", 0, 0)
	local trackMiddle = slice(track, ATLAS.trackMiddle)
	trackMiddle:SetPoint("TOPLEFT", trackTop, "BOTTOMLEFT", 0, 0)
	trackMiddle:SetPoint("BOTTOMRIGHT", trackBottom, "TOPRIGHT", 0, 0)

	-- Thumb: three slices in a frame that moves.
	local cursor = CreateFrame("Frame", name .. "Thumb", track)
	cursor:SetWidth(WIDTH)
	cursor:SetHeight(CURSOR_MIN)
	cursor:EnableMouse(true)
	bar.cursor = cursor

	local cTop = slice(cursor, ATLAS.cursorTip, "ARTWORK")
	cTop:SetHeight(CURSOR_TIP)
	cTop:SetPoint("TOP", cursor, "TOP", 0, 0)

	-- Same piece, flipped: swap the top and bottom of its atlas rectangle.
	local cBottom = slice(cursor, ATLAS.cursorTip, "ARTWORK")
	local e = ForeverUI.AtlasEntry(ATLAS.cursorTip)
	if e then
		cBottom:SetTexCoord(e[2], e[3], e[5], e[4])
	end
	cBottom:SetHeight(CURSOR_TIP)
	cBottom:SetPoint("BOTTOM", cursor, "BOTTOM", 0, 0)

	local cMiddle = slice(cursor, ATLAS.cursorMiddle, "ARTWORK")
	cMiddle:SetPoint("TOPLEFT", cTop, "BOTTOMLEFT", 0, 0)
	cMiddle:SetPoint("BOTTOMRIGHT", cBottom, "TOPRIGHT", 0, 0)

	-- Bar methods

	-- Moves to offset `to`, clamped. The bar knows only its three numbers, not the list.
	-- Calls onScroll(offset) when the offset changes.
	function bar:MoveTo(to)
		local maximum = math.max(0, self.total - self.visibleCount)
		to = math.max(0, math.min(math.floor(to + 0.5), maximum))
		if to == self.offset then
			return
		end
		self.offset = to
		self:Reposition()
		if self.onScroll then
			self.onScroll(to)
		end
	end

	-- Places the thumb: its height shows the visible share, its position the offset.
	function bar:Reposition()
		local height = self.track:GetHeight() or 0
		local maximum = math.max(0, self.total - self.visibleCount)

		if height <= 0 or maximum <= 0 then
			self.cursor:Hide()
			return
		end

		local part = self.visibleCount / self.total
		local size = math.max(CURSOR_MIN, math.floor(height * part + 0.5))
		if size > height then
			size = height
		end
		local travel = height - size

		self.cursor:SetHeight(size)
		self.cursor:ClearAllPoints()
		self.cursor:SetPoint("TOP", self.track, "TOP", 0,
			-travel * (self.offset / maximum))
		self.cursor:Show()
	end

	-- The caller gives the row count, rows that fit, current offset. The bar hides when
	-- everything fits. When it shows or hides, onVisibility(shown) tells the caller, whose
	-- content takes or gives back the space.
	function bar:Configure(total, visibleCount, offset)
		self.total = total or 0
		self.visibleCount = visibleCount or 0
		self.offset = offset or 0
		local hasBar = self.total > self.visibleCount
		if hasBar then
			self:Show()
			self:Reposition()
		else
			self:Hide()
		end
		if hasBar ~= self.wasNeeded then
			self.wasNeeded = hasBar
			if self.onVisibility then self.onVisibility(hasBar) end
		end
	end

	-- Thumb drag: an OnUpdate follows the mouse while the button is held. 3.3.5 has no mouse
	-- tracking on a frame.
	cursor:SetScript("OnMouseDown", function(self)
		self.grab = mouse(self)
		self.grabOffset = bar.offset
		self:SetScript("OnUpdate", function(me)
			local height = bar.track:GetHeight() or 0
			local travel = height - (me:GetHeight() or 0)
			local maximum = math.max(0, bar.total - bar.visibleCount)
			if travel <= 0 or maximum <= 0 then
				return
			end
			local traveled = me.grab - mouse(me)
			bar:MoveTo(me.grabOffset + traveled / travel * maximum)
		end)
	end)
	cursor:SetScript("OnMouseUp", function(self)
		self:SetScript("OnUpdate", nil)
	end)

	-- Clicking the track jumps one page toward the click.
	track:EnableMouse(true)
	track:SetScript("OnMouseDown", function(self)
		local y = mouse(self)
		local hovered = bar.cursor:GetTop() or 0
		local below = bar.cursor:GetBottom() or 0
		if y > hovered then
			bar:MoveTo(bar.offset - bar.visibleCount)
		elseif y < below then
			bar:MoveTo(bar.offset + bar.visibleCount)
		end
	end)

	bar:Hide()
	return bar
end
