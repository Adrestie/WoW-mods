-- Hosts and their contents: the single place that decides what a window shows.
-- A host is a fixed surface (a pane, a column) in which contents replace each other, like
-- LeftPaneHost / RightPaneHost in camelot CharacterFrame.xml. A content is built once, on
-- first show, then only shown or hidden; nothing is recomputed.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Panes = {}
ForeverUI.Panes = Panes

local hosts = {}        -- name -> host (frame, contents, pages, furniture, group, current)
local hostOrder = {}
local L = ForeverUI.L

-- ---------------------------------------------------------------- hosts

-- Declares a host on an existing frame; the library only records where contents go.
function Panes.NewHost(name, frame)
	local host = hosts[name]
	if not host then
		host = { name = name, contents = {}, order = {}, pages = {},
		         furniture = {}, displayed = true }
		hosts[name] = host
		hostOrder[#hostOrder + 1] = name
	end
	host.frame = frame
	return host
end

-- ------------------------------------------------------------ contents

-- def = { host, group, id, build }: group is the screen a tab opens (it sets every host);
-- id names the page. Pages of the same host and group replace each other.
-- build(hostFrame) runs once, on first show, and returns our root frame (or nil) and the
-- list of client frames the content owns. Client frames are not reparented (they would
-- lose their level and strata), so they are shown and hidden with the root.
function Panes.Register(def)
	local host = hosts[def.host]
	if not host then
		error(ForeverUI.L.PANES_ERROR_UNKNOWN_HOST .. tostring(def.host))
	end

	local content = {
		id = def.id,
		group = def.group,
		build = def.build,
		host = host,
		built = false,
		frames = {},
	}
	host.contents[def.id] = content
	host.order[#host.order + 1] = def.id

	-- The first page declared for a group becomes its default page.
	if host.pages[def.group] == nil then
		host.pages[def.group] = def.id
	end
	return content
end

local function assemble(content)
	if content.built then
		return
	end
	content.built = true                     -- set before the call: no re-entry

	if content.build then
		local root, frames = content.build(content.host.frame)
		content.root = root
		content.frames = frames or {}
	end
end

-- Furniture: frames a host shows for a group whatever the page (stone band, page tabs),
-- like camelot UpdateRightPaneHeader. Can be called several times; frames add up.
function Panes.Furniture(name, group, frames)
	local host = hosts[name]
	if not host then
		return
	end
	local list = host.furniture[group] or {}
	host.furniture[group] = list
	for _, frame in ipairs(frames or {}) do
		if frame then
			list[#list + 1] = frame
		end
	end
end

-- Shows or hides a content and the client frames it owns; builds it on first show
local function place(content, visible)
	if visible then
		assemble(content)
	elseif not content.built then
		-- Never shown, so nothing to hide: do not build it just for that.
		return
	end

	if content.root then
		if visible then content.root:Show() else content.root:Hide() end
	end
	for _, frame in ipairs(content.frames) do
		if frame and frame.Show then
			if visible then frame:Show() else frame:Hide() end
		end
	end
end

-- ------------------------------------------------------------- display

-- Applies a host's group and page: shows the wanted content and furniture, hides the rest
local function apply(host)
	local wanted = host.displayed and host.pages[host.group or ""] or nil

	for _, id in ipairs(host.order) do
		place(host.contents[id], id == wanted)
	end
	host.current = wanted

	-- Furniture: hide everything declared, then show the current group's, so a frame shared by
	-- two groups does not depend on the loop order.
	local activeFrames = {}
	local ownScreen = host.furniture[host.group or ""]
	if host.displayed and wanted and ownScreen then
		for _, frame in ipairs(ownScreen) do
			activeFrames[frame] = true
		end
	end
	for _, list in pairs(host.furniture) do
		for _, frame in ipairs(list) do
			if frame and frame.Hide and not activeFrames[frame] then
				frame:Hide()
			end
		end
	end
	for frame in pairs(activeFrames) do
		if frame.Show then
			frame:Show()
		end
	end

	-- A host with no content is hidden, so an empty right pane (with its background and stone
	-- band) does not stay on a tab that has nothing to put there.
	if host.frame then
		local needed = host.displayed and wanted ~= nil
		if needed then host.frame:Show() else host.frame:Hide() end
	end
end

-- Opens a group: a whole screen, all hosts at once.
function Panes.ShowGroup(group)
	for _, name in ipairs(hostOrder) do
		local host = hosts[name]
		host.group = group
		apply(host)
	end
	Panes.group = group
end

function Panes.CurrentGroup()
	return Panes.group
end

-- Switches the page of a host without changing the group (two buttons sharing one surface).
function Panes.ShowPage(name, id)
	local host = hosts[name]
	if not host or not host.contents[id] then
		return
	end
	host.pages[host.group or ""] = id
	apply(host)
end

function Panes.CurrentPage(name)
	local host = hosts[name]
	return host and host.current
end

-- Hides a whole host (a collapsed pane). The group and the chosen page are kept for when it
-- is expanded again.
function Panes.SetHostShown(name, state)
	local host = hosts[name]
	if not host then
		return
	end
	host.displayed = state and true or false
	apply(host)
end

-- Tells whether a host has something to show for this group, without building anything
-- (e.g. whether the collapse button makes sense).
function Panes.HasContent(name, group)
	local host = hosts[name]
	return host ~= nil and host.pages[group or host.group or ""] ~= nil
end

-- Re-applies the current state. Call it when a content is registered after its group was
-- opened, never from a display loop.
function Panes.Refresh()
	for _, name in ipairs(hostOrder) do
		apply(hosts[name])
	end
end

-- Debug report: what each host shows and owns.
function Panes.Report()
	local rows = {}
	for _, name in ipairs(hostOrder) do
		local host = hosts[name]
		local pages = {}
		for _, id in ipairs(host.order) do
			local content = host.contents[id]
			if content.group == host.group then
				pages[#pages + 1] = string.format(L.PANES_REPORT_PAGE, id,
					#content.frames, content.built and "" or L.PANES_REPORT_NEVER_BUILT)
			end
		end
		rows[#rows + 1] = string.format(
			L.PANES_REPORT_LINE,
			name, tostring(host.group), tostring(host.current),
			tostring(host.displayed), table.concat(pages, ", "))
	end
	return rows
end
