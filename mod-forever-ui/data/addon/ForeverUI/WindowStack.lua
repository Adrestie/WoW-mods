-- ForeverUI: keeps the large windows (character sheet, spellbook, talents) from interleaving.
-- Each window sets explicit frame levels relative to its root, so two roots of the same strata
-- mix on screen, and Raise only lifts the root. Open windows are stacked back to front instead;
-- an opened or clicked window comes to the front.

ForeverUI = ForeverUI or {}

local P = { windows = {}, order = {} }
ForeverUI.WindowStack = P

-- Highest frame level in a subtree
local function highestLevel(frame)
	local n = frame:GetFrameLevel()
	for _, child in ipairs({ frame:GetChildren() }) do
		local m = highestLevel(child)
		if m > n then n = m end
	end
	return n
end

-- Lowest frame level in a subtree: a client frame can sit below its root
local function lowestLevel(frame)
	local n = frame:GetFrameLevel()
	for _, child in ipairs({ frame:GetChildren() }) do
		local m = lowestLevel(child)
		if m < n then n = m end
	end
	return n
end

-- Frame levels of a subtree, parents before children
local function collect(frame, list)
	table.insert(list, { frame, frame:GetFrameLevel() })
	for _, child in ipairs({ frame:GetChildren() }) do collect(child, list) end
	return list
end

-- Moves the root to a level and shifts its descendants by the same gap. Depending on the
-- client, SetFrameLevel may already move the children, so only misplaced frames are reset.
local function placeLevel(root, level)
	local gap = level - root:GetFrameLevel()
	if gap == 0 then return end
	for _, e in ipairs(collect(root, {})) do
		local wanted = math.max(0, e[2] + gap)
		if e[1]:GetFrameLevel() ~= wanted then e[1]:SetFrameLevel(wanted) end
	end
end

-- In combat a protected root (the spellbook has secure buttons) cannot change level;
-- the other windows stack around it.
local function isBlocked(f)
	return InCombatLockdown() and f.root.IsProtected and f.root:IsProtected()
end

local function openWindows()
	local l = {}
	for _, key in ipairs(P.order) do
		local f = P.windows[key]
		if f.root:IsVisible() then table.insert(l, f) end
	end
	return l
end

-- Puts the given window at the front and restacks the open windows in order
function P.bringToFront(key)
	local f = P.windows[key]
	if not f then return end
	for i, c in ipairs(P.order) do
		if c == key then table.remove(P.order, i) break end
	end
	table.insert(P.order, key)
	local level
	for _, g in ipairs(openWindows()) do
		-- Each window's lowest frame goes one level above the previous window's highest frame;
		-- the back window returns to its base level, so levels do not grow with each click.
		if not isBlocked(g) then
			if level then
				placeLevel(g.root, g.root:GetFrameLevel() + level - lowestLevel(g.root))
			else
				placeLevel(g.root, g.base)
			end
		end
		level = highestLevel(g.root) + 1
	end
end

-- Front-most open window under the mouse
local function underMouse()
	local l = openWindows()
	for i = #l, 1, -1 do
		for _, zone in ipairs(l[i].zones()) do
			if zone and zone:IsVisible() and MouseIsOver(zone) then return l[i] end
		end
	end
end

-- Registers a window. root: frame whose level moves; zones: function returning the frames
-- that belong to the window on screen (overflowing art, outside tabs)
function P.register(key, root, zones)
	if P.windows[key] then return end
	P.windows[key] = { key = key, root = root, zones = zones, base = root:GetFrameLevel() }
	table.insert(P.order, key)
	root:HookScript("OnShow", function() P.bringToFront(key) end)
	if root:IsVisible() then P.bringToFront(key) end
end

-- Detects clicks on the next frame: 3.3.5 has no global click event, and a click on a
-- button does not reach its parent. Nothing to do while only one window is open.
local watcher = CreateFrame("Frame")
P.watcher = watcher
local pressed = false
watcher:SetScript("OnUpdate", function()
	local down = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
	if down and not pressed then
		local l = openWindows()
		-- Restack even when the front window is clicked: the client's Raise (toplevel roots)
		-- only lifts the root
		if #l > 1 then
			local f = underMouse()
			if f then P.bringToFront(f.key) end
		end
	end
	pressed = down and true or false
end)

-- ---------- Moving
-- Saved window positions (ForeverUIDB), read on each show: saved variables load after the files
local function positions()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.positions = ForeverUIDB.positions or {}
	return ForeverUIDB.positions
end

-- Makes a window draggable by its title bar and remembers its position.
-- frame: window; handle: drag area; key: saved position key
-- The window is re-anchored by its top center, so width changes (small spellbook, pet
-- talents) stay centered. Out of combat only: the spellbook has secure buttons.
function P.makeMovable(frame, handle, key)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function()
		if not InCombatLockdown() then frame:StartMoving() end
	end)
	handle:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		if InCombatLockdown() then return end
		local cx = frame:GetCenter()
		local ux = UIParent:GetCenter()
		local x, y = cx - ux, frame:GetTop() - UIParent:GetTop()
		frame:ClearAllPoints()
		frame:SetPoint("TOP", UIParent, "TOP", x, y)
		-- The position is ours: the client must not save it too
		if frame.SetUserPlaced then frame:SetUserPlaced(false) end
		positions()[key] = { x = x, y = y }
	end)
	local function restorePosition()
		local p = positions()[key]
		if not p or InCombatLockdown() then return end
		frame:ClearAllPoints()
		frame:SetPoint("TOP", UIParent, "TOP", p.x, p.y)
	end
	frame:HookScript("OnShow", restorePosition)
	restorePosition()
end
