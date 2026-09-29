-- Login screen cinematics: camelot's CinematicsMenu over the 3.3.5 client movies.
-- Layout from blizzard_gluexml/mainline/cinematicsmenu.xml (DefaultPanelTemplate 819 x 559,
-- CinematicsMenuButtonTemplate 246 x 135, three columns, newest first). The window keeps
-- camelot's size even with one row; a translucent black background replaces the stone.
-- Movies follow GetClientExpansionLevel (1 WoW, 2 TBC, 3 WotLK) and play through the
-- client's Cinematics_PlayMovie. No paging: the three 3.3.5 movies always fit on one page.

local G = ForeverUIGlue
local L = G.L

-- Texts missing from 3.3.5: G.L (ForeverUIGlueTexts)
local TEXT = { SUBTITLES = L.GLUECINEMATICS_SHOW_SUBTITLES }

local MOVIES = {
	{ title = WORLD_OF_WARCRAFT, vignette = "StreamCinematic-Classic-Large" },
	{ title = BURNING_CRUSADE, vignette = "StreamCinematic-BC-Large" },
	{ title = WRATH_OF_THE_LICH_KING, vignette = "StreamCinematic-LK-Large" },
}
local M = { width = 819, height = 559, y = 50, thumbnailW = 246, thumbnailH = 135, gap = 17, columns = 3 }

local frame = CinematicsFrame

-- ------------------------------------------------------------ Client window

CinematicsBackground:SetAlpha(0)
CinematicsBackground:Hide()
G.Hook(CinematicsBackground, "OnShow", function(self)
	self:Hide()
end)

-- Black veil at 0.5, as GlueParent_AddModalFrame does
local veil = frame:CreateTexture(nil, "BACKGROUND")
veil:SetTexture(0, 0, 0, 0.5)
veil:SetAllPoints(GlueParent)

-- ------------------------------------------------------------ Window

local F = CreateFrame("Frame", "ForeverUICinematicsMenu", frame)
F:SetWidth(M.width)
F:SetHeight(M.height)
F:SetPoint("CENTER", GlueParent, "CENTER", 0, M.y)
F:EnableMouse(true)
G.Window(F, CINEMATICS, true)
local inset = CreateFrame("Frame", nil, F)
inset:SetPoint("TOPLEFT", F, "TOPLEFT", 6, -40)
inset:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -3, 4)
G.Inset(F, inset, true)

local function close()
	PlaySound("igMainMenuOptionCheckBoxOff")
	frame:Hide()
end

local closeButton = CreateFrame("Button", "ForeverUICinematicsMenuCloseButton", F)
closeButton:SetFrameLevel(F:GetFrameLevel() + 20)
G.WindowCloseButton(closeButton, F)
closeButton:ClearAllPoints()
closeButton:SetPoint("TOPRIGHT", F, "TOPRIGHT", 1, 0)
closeButton:SetScript("OnClick", close)

-- camelot OnKeyDown: Escape closes, other keys pass through
frame:SetScript("OnKeyDown", function(_, pressedKey)
	if pressedKey == "PRINTSCREEN" then
		Screenshot()
	elseif pressedKey == "ESCAPE" then
		close()
	end
end)

-- ------------------------------------------------------------ Thumbnails

local function vignette(rank, movie, id)
	local b = CreateFrame("Button", "ForeverUICinematicsMenuButton" .. rank, F)
	b:SetWidth(M.thumbnailW)
	b:SetHeight(M.thumbnailH)
	local column = (rank - 1) % M.columns
	local rowLine = math.floor((rank - 1) / M.columns)
	b:SetPoint("TOPLEFT", inset, "TOPLEFT", 19 + column * (M.thumbnailW + M.gap),
		-(19 + rowLine * (M.thumbnailH + M.gap)))
	local top = movie.vignette .. "-Up"
	local down = movie.vignette .. "-Down"
	b:SetNormalTexture(G.atlas[string.lower(top)][1])
	G.PlaceAtlas(b:GetNormalTexture(), top)
	b:SetPushedTexture(G.atlas[string.lower(down)][1])
	G.PlaceAtlas(b:GetPushedTexture(), down)
	-- Highlight rotated a quarter turn (Rect UL (1, 0), UR (1, 1), LL (0, 0), LR (0, 1))
	local e = G.atlas["streamcinematic-highlight"]
	b:SetHighlightTexture(e[1])
	local h = b:GetHighlightTexture()
	h:SetTexCoord(e[3], e[4], e[2], e[4], e[3], e[5], e[2], e[5])
	h:SetBlendMode("ADD")
	h:ClearAllPoints()
	h:SetAllPoints(b)
	b.reading = b:CreateTexture(nil, "OVERLAY")
	G.PlaceAtlas(b.reading, "StreamCinematic-PlayButton")
	b.reading:SetWidth(43)
	b.reading:SetHeight(43)
	b.reading:SetPoint("TOPRIGHT", b, "TOPRIGHT", -5, -5)
	b:SetNormalFontObject(G.Font("GlueFontNormal"))
	b:SetHighlightFontObject(G.Font("GlueFontHighlight"))
	b:SetDisabledFontObject(G.Font("GlueFontDisable"))
	b:SetText(movie.title)
	local text = b:GetFontString()
	text:SetWidth(230)
	text:ClearAllPoints()
	text:SetPoint("BOTTOM", b, "BOTTOM", 0, 11)
	b:SetPushedTextOffset(2, -2)
	b:SetScript("OnMouseDown", function(self)
		self.reading:SetPoint("TOPRIGHT", self, "TOPRIGHT", -3, -7)
	end)
	b:SetScript("OnMouseUp", function(self)
		self.reading:SetPoint("TOPRIGHT", self, "TOPRIGHT", -5, -5)
	end)
	-- The client's Cinematics_PlayMovie reads the movie number from its own button
	b:SetScript("OnClick", function()
		Cinematics_PlayMovie(_G["CinematicsButton" .. id])
	end)
	return b
end

local vignettes = {}
local count = math.min(frame.numMovies or GetClientExpansionLevel(), #MOVIES)
for rank = 1, count do
	-- Newest first
	local id = count - rank + 1
	vignettes[rank] = vignette(rank, MOVIES[id], id)
end

-- ------------------------------------------------------------ Subtitles checkbox

local caption = F:CreateFontString(nil, "ARTWORK")
caption:SetFontObject(G.Font("GlueFontNormal"))
caption:SetPoint("BOTTOM", F, "BOTTOM", 12, 27)
caption:SetText(TEXT.SUBTITLES)
local checkbox = CreateFrame("CheckButton", "ForeverUICinematicsMenuSubtitles", F)
checkbox:SetWidth(26)
checkbox:SetHeight(26)
checkbox:SetPoint("RIGHT", caption, "LEFT", -4, 0)
checkbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
checkbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
checkbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
checkbox:GetHighlightTexture():SetBlendMode("ADD")
checkbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
checkbox:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
checkbox:SetScript("OnShow", function(self)
	self:SetChecked(GetCVarBool("movieSubtitle") and true or false)
end)
checkbox:SetScript("OnClick", function(self)
	local yes = self:GetChecked() and self:GetChecked() ~= 0
	if yes then
		PlaySound("igMainMenuOptionCheckBoxOn")
	else
		PlaySound("igMainMenuOptionCheckBoxOff")
	end
	SetCVar("movieSubtitle", yes and "1" or "0")
end)

G.Hook(frame, "OnShow", function()
	frame:Raise()
end)

-- ------------------------------------------------------------ Movie subtitles
-- At the bottom, as camelot's SubtitlesFrame. The 3.3.5 client puts them at TOP (0, -630),
-- meant for a 768-high screen, which is mid-screen on camelot's 1200-high one.

MovieFrameSubtitleString:SetFontObject(G.Font("MovieSubtitleFont"))
MovieFrameSubtitleString:ClearAllPoints()
MovieFrameSubtitleString:SetWidth(800)
MovieFrameSubtitleString:SetHeight(138)
MovieFrameSubtitleString:SetPoint("BOTTOM", MovieFrame, "BOTTOM", 0, 0)
