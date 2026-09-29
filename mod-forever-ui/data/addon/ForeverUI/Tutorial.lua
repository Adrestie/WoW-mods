-- Hides the 3.3.5 tutorial (TutorialFrame, its alert button and its badge).
-- TutorialFrame no longer listens to TUTORIAL_TRIGGER: no tip is queued or flagged as seen.
-- If other code shows them anyway, they hide at once.
-- The Tutorials option (showTutorials) stays, with no visible effect.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local T = {}
ForeverUI.Tutorial = T

function T.Suppress()
	if not TutorialFrame or TutorialFrame.foreverHidden then return end
	TutorialFrame.foreverHidden = true
	TutorialFrame:UnregisterEvent("TUTORIAL_TRIGGER")
	for _, frame in ipairs({ TutorialFrame, TutorialFrameAlertButton, TutorialFrameAlertButtonBadge }) do
		if frame then
			frame:HookScript("OnShow", function(self) self:Hide() end)
			frame:Hide()
		end
	end
end

T.Suppress()
