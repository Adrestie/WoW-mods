-- Chat configuration window (ChatConfigFrame) in the Camelot style (chatconfigframe.xml):
-- dialog border and header, tooltip-backdrop boxes, MinimalScrollBar. Positions, sizes and
-- logic stay 3.3.5's. Each tooltip-bordered box keeps the colors the client gave it; the
-- background is drawn only if the box had one.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local C = {}
ForeverUI.ChatConfig = C

-- camelot: DialogHeaderTemplate headerTextPadding
local N = { header = 100 }

-- Returns the frame's backdrop if its edge is the tooltip border
local function tooltipBorder(f)
	local background = f.GetBackdrop and f:GetBackdrop()
	return background and type(background.edgeFile) == "string"
		and string.find(string.lower(background.edgeFile), "ui%-tooltip%-border") and background
end

-- Skins a frame with a tooltip <Backdrop> as TooltipBackdropTemplate or
-- TooltipBorderBackdropTemplate, keeping the colors the client set
function C.Box(f)
	local background = tooltipBorder(f)
	if not background or f.foreverNineSlice then return end
	local r, g, b, a = f:GetBackdropBorderColor()
	local cr, cg, cb = f:GetBackdropColor()
	local hasBackground = background.bgFile ~= nil
	local p = ForeverUI.Tooltips.Skin(f)
	for name, t in pairs(p) do
		if name == "Center" then
			if hasBackground then
				t:SetVertexColor(cr or 0, cg or 0, cb or 0, 1)
			else
				t:SetAlpha(0)
			end
		else
			t:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
		end
	end
end

-- Skins every descendant: boxes and scroll bars. MinimalScrollBar has no tooltip trim,
-- so the $parentBorder of UIPanelScrollBarTemplateLightBorder is removed.
function C.Scan(frame)
	for _, c in ipairs({ frame:GetChildren() }) do
		local name = c:GetName()
		local sb = c:GetObjectType() == "ScrollFrame" and name and _G[name .. "ScrollBar"]
		if sb and not sb.foreverBar then
			local trim = _G[sb:GetName() .. "Border"]
			if trim then trim:SetBackdrop(nil) end
			Tpl.Bar(sb)
		end
		C.Box(c)
		C.Scan(c)
	end
end

function C.Skin()
	local f = ChatConfigFrame
	if not f or f.foreverSkin then return end
	f:SetBackdrop(nil)
	local frame, background = Tpl.DialogFrame(f)
	ChatConfigFrameHeader:SetAlpha(0)
	ChatConfigFrameHeaderText:SetAlpha(0)
	local header = Tpl.Header(f, ChatConfigFrameHeaderText:GetText(), GameFontNormal, N.header)
	local function title()
		header:Place(ChatConfigFrameHeaderText:GetText())
	end
	hooksecurefunc(ChatConfigFrameHeaderText, "SetText", title)
	hooksecurefunc(ChatConfigFrameHeaderText, "SetFormattedText", title)
	f.foreverSkin = { frame = frame, background = background, header = header }
	C.Scan(f)
	-- Rows and tabs the client creates later
	f:HookScript("OnShow", function(self) C.Scan(self) end)
	for _, name in ipairs({ "ChatConfig_CreateCheckboxes", "ChatConfig_CreateTieredCheckboxes",
			"ChatConfig_CreateColorSwatches" }) do
		if type(_G[name]) == "function" then
			hooksecurefunc(name, function(rowsFrame)
				if rowsFrame then C.Scan(rowsFrame) end
			end)
		end
	end
end

C.Skin()
