-- ForeverUI: texts in the client's language. Texts the 3.3.5 client has (GlobalStrings.lua)
-- are read from their globals; any other displayed text comes from ForeverUI.L.KEY.
-- A language is a Texts_<GetLocale code>.lua file calling ForeverUI.AddTexts, listed in the
-- .toc after Texts_enUS.lua; enUS fills missing keys and languages. Keep %s / %d in number and
-- order (Lua 5.1 string.format cannot reorder them). Keys unknown to enUS show as is and go to
-- ForeverUI.missingTexts (the test bench rejects them).

ForeverUI = ForeverUI or {}

local languages = {}
local BASE = "enUS"

function ForeverUI.AddTexts(language, texts)
	local t = languages[language] or {}
	for key, text in pairs(texts) do t[key] = text end
	languages[language] = t
end

ForeverUI.missingTexts = {}

ForeverUI.L = setmetatable({}, {
	__index = function(_, key)
		local t = languages[GetLocale()]
		local text = t and t[key]
		if text == nil and languages[BASE] then text = languages[BASE][key] end
		if text == nil then
			ForeverUI.missingTexts[key] = true
			text = tostring(key)
		end
		return text
	end,
})

-- keys of one language (for the test bench)
function ForeverUI.TextsFor(language)
	return languages[language]
end
