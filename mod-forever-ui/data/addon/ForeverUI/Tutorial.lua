-- ForeverUI : le tutoriel de 3.3.5 masque (demande de l'utilisateur,
-- 2026-09-28 : « le tutoriel n'est pas adapte a la nouvelle interface,
-- masque le »).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (TutorialFrame.xml / .lua de 3.3.5) :
--   TutorialFrame ecoute TUTORIAL_TRIGGER ; TutorialFrame_NewTutorial met
--   l'astuce en file, montre TutorialFrameAlertButton (le point
--   d'interrogation au bas de l'ecran) et, hors combat, ouvre TutorialFrame
--   (TutorialFrame_Update, qui marque l'astuce vue : FlagTutorial) ;
--   TutorialFrameAlertButtonBadge compte les astuces en attente.
--
-- CE QUI EST FAIT. TutorialFrame n'ecoute plus TUTORIAL_TRIGGER : aucune
-- astuce n'entre en file et aucune n'est marquee vue. Si un autre code les
-- montre malgre tout, la fenetre, le bouton et son compteur se referment
-- aussitot. La case « Tutoriels » des options (showTutorials) reste, sans
-- effet visible.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local T = {}
ForeverUI.Tutoriel = T

function T.Masquer()
	if not TutorialFrame or TutorialFrame.foreverMasque then return end
	TutorialFrame.foreverMasque = true
	TutorialFrame:UnregisterEvent("TUTORIAL_TRIGGER")
	for _, cadre in ipairs({ TutorialFrame, TutorialFrameAlertButton, TutorialFrameAlertButtonBadge }) do
		if cadre then
			cadre:HookScript("OnShow", function(self) self:Hide() end)
			cadre:Hide()
		end
	end
end

T.Masquer()
