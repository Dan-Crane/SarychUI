-- Global enabled state
CheeseEnabled = CheeseEnabled ~= false;

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.Cheese then
		return SarychUI.db.profile.addons.Cheese.enabled ~= false;
	end
	return CheeseEnabled;
end

local trackedActionButtons = setmetatable({}, { __mode = "k" });
-- Do not store fields on the action button. That taints it, and a macro
-- /castsequence then fails CastSpellByName as SarychUI even out of combat.
local glowByButton = setmetatable({}, { __mode = "k" });
local eventsByButton = {};

function CheeseActionButton_Update(self)
	trackedActionButtons[self] = true;
	if not IsEnabled() then
		if ( eventsByButton[self] ) then
			Cheese_UnregisterEvent("CHEESE_SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", self);
			Cheese_UnregisterEvent("CHEESE_SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", self);
			eventsByButton[self] = nil;
		end
		CheeseActionButton_HideOverlayGlow(self);
		return;
	end
	if ( HasAction(self.action) ) then
		if ( not eventsByButton[self] ) then
			Cheese_RegisterEvent("CHEESE_SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", self, CheeseActionButton_OnEventOverlayGlowShow);
			Cheese_RegisterEvent("CHEESE_SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", self, CheeseActionButton_OnEventOverlayGlowHide);
			eventsByButton[self] = true;
		end
	else
		if ( eventsByButton[self] ) then
			Cheese_UnregisterEvent("CHEESE_SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", self);
			Cheese_UnregisterEvent("CHEESE_SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", self);
			eventsByButton[self] = nil;
		end
	end

	CheeseActionButton_UpdateOverlayGlow(self);
end

function CheeseActionButton_RefreshAll()
	for button in pairs(trackedActionButtons) do
		CheeseActionButton_Update(button);
	end
end

hooksecurefunc("ActionButton_Update", CheeseActionButton_Update);

--Overlay stuff
local unusedOverlayGlows = {};
local numOverlays = 0;

local function IsAnimPlaying(self)
	return self.isPlaying;
end

function CheeseActionButton_GetOverlayGlow()
	local overlay = tremove(unusedOverlayGlows);
	if ( not overlay ) then
		numOverlays = numOverlays + 1;
		overlay = CreateFrame("Frame", "CheeseActionButtonOverlay"..numOverlays, UIParent, "CheeseActionBarButtonSpellActivationAlert");
		local animOut = overlay.animOut;
		animOut.isPlaying = false;
		animOut.IsPlaying = IsAnimPlaying;
	end
	return overlay;
end

function CheeseActionButton_UpdateOverlayGlow(self)
	-- The glow is parented to UIParent so it does not taint the button.
	-- A hidden bar still has buttons, and the glow would stay in empty space.
	if not self:IsVisible() then
		CheeseActionButton_HideOverlayGlow(self);
		return;
	end
	local globalID = Cheese_GetActionSpellID(self.action);
	if ( globalID and Cheese_IsSpellOverlayed(globalID) ) then
		CheeseActionButton_ShowOverlayGlow(self);
	else
		CheeseActionButton_HideOverlayGlow(self);
	end
end

local function PlaceOverlay(overlay, button)
	local frameWidth, frameHeight = button:GetSize();
	overlay:SetParent(UIParent);
	overlay:SetFrameStrata(button:GetFrameStrata() or "MEDIUM");
	overlay:SetFrameLevel((button:GetFrameLevel() or 0) + 5);
	if overlay.EnableMouse then
		overlay:EnableMouse(false);
	end
	overlay:ClearAllPoints();
	overlay:SetSize(frameWidth * 1.4, frameHeight * 1.4);
	overlay:SetPoint("TOPLEFT", button, "TOPLEFT", -frameWidth * 0.2, frameHeight * 0.2);
	overlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", frameWidth * 0.2, -frameHeight * 0.2);
	overlay.actionButton = button;
end

function CheeseActionButton_ShowOverlayGlow(self)
	if not self:IsVisible() then
		CheeseActionButton_HideOverlayGlow(self);
		return;
	end
	local overlay = glowByButton[self];
	if ( overlay ) then
		PlaceOverlay(overlay, self);
		if ( overlay.animOut:IsPlaying() ) then
			overlay.animOut:Stop();
			overlay.animIn:Play();
		end
	else
		overlay = CheeseActionButton_GetOverlayGlow();
		glowByButton[self] = overlay;
		PlaceOverlay(overlay, self);
		overlay.animIn:Play();
	end
end

function CheeseActionButton_HideOverlayGlow(self)
	local overlay = glowByButton[self];
	if ( overlay ) then
		if ( overlay.animIn:IsPlaying() ) then
			overlay.animIn:Stop();
		end
		if ( self:IsVisible() ) then
			overlay.animOut:Play();
		else
			CheeseActionButton_OverlayGlowAnimOutFinished(overlay.animOut);
		end
	end
end

function CheeseActionButton_OverlayGlowAnimOutFinished(animGroup)
	local overlay = animGroup:GetParent();
	local actionButton = overlay.actionButton;
	overlay:Hide();
	tinsert(unusedOverlayGlows, overlay);
	if actionButton then
		glowByButton[actionButton] = nil;
	end
	overlay.actionButton = nil;
end

function CheeseActionButton_OnEvent(self, event)
	if ( event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" ) then
		local globalID = Cheese_GetActionSpellID(self.action);
		if ( not globalID or globalID == 0 ) then
			CheeseActionButton_HideOverlayGlow(self);
		end
		return;
	end
end

hooksecurefunc("ActionButton_OnEvent", CheeseActionButton_OnEvent);

local glowWatch = CreateFrame("Frame");
local glowElapsed = 0;
glowWatch:SetScript("OnUpdate", function(_, elapsed)
	if not IsEnabled() then
		return;
	end
	glowElapsed = glowElapsed + elapsed;
	if glowElapsed < 0.2 then
		return;
	end
	glowElapsed = 0;
	for button, overlay in pairs(glowByButton) do
		if overlay:IsShown() and not button:IsVisible() then
			CheeseActionButton_HideOverlayGlow(button);
		end
	end
end);

function CheeseActionButton_OnEventOverlayGlowShow(self, arg1)
	local globalID = Cheese_GetActionSpellID(self.action);
	if ( globalID == arg1 ) then
		CheeseActionButton_ShowOverlayGlow(self);
	end
end

function CheeseActionButton_OnEventOverlayGlowHide(self, arg1)
	local globalID = Cheese_GetActionSpellID(self.action);
	if ( globalID == arg1 ) then
		CheeseActionButton_HideOverlayGlow(self);
	end
end
