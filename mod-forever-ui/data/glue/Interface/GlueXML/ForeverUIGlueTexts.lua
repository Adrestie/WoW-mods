-- Login screen texts in the client's language.
-- A text the 3.3.5 client has (GlueStrings.lua) is read from its global; every other shown
-- text is read from G.L.KEY (G = ForeverUIGlue), never hard-coded.
-- Each language is a ForeverUIGlueTexts_<code>.lua file calling
-- ForeverUIGlue.AddTexts("<code>", { KEY = "text" }). English (enUS) is the fallback for
-- missing keys and for languages without a file.
-- To add a language: copy ForeverUIGlueTexts_enUS.lua to ForeverUIGlueTexts_<code>.lua
-- (GetLocale code), translate the values without touching keys or %s / %d (same count and
-- order), and list it in ForeverUIGlue.xml after ForeverUIGlueTexts_enUS.lua.

ForeverUIGlue = ForeverUIGlue or {}
local G = ForeverUIGlue

local languages = {}
local BASE = "enUS"

function G.AddTexts(language, texts)
	local t = languages[language] or {}
	for key, text in pairs(texts) do t[key] = text end
	languages[language] = t
end

-- Keys looked up that no language has.
G.missingTexts = {}

-- G.L[key]: text in the client's language, else English, else the key itself.
G.L = setmetatable({}, {
	__index = function(_, key)
		local t = languages[GetLocale()]
		local text = t and t[key]
		if text == nil and languages[BASE] then text = languages[BASE][key] end
		if text == nil then
			G.missingTexts[key] = true
			text = tostring(key)
		end
		return text
	end,
})

function G.TextsFor(language)
	return languages[language]
end
