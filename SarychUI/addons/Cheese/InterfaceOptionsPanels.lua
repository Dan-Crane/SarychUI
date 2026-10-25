-- Controls for the native Interface > AddOns > Cheese panel.
local function GetConfig()
	return SarychUI and SarychUI.db and SarychUI.db.profile
		and SarychUI.db.profile.addons and SarychUI.db.profile.addons.Cheese
end

function CheeseOptions_Refresh(panel)
	local config = GetConfig()
	if not config then return end
	local checkbox = _G[panel:GetName() .. "ShowSpellAlerts"]
	local slider = _G[panel:GetName() .. "SpellAlertOpacitySlider"]
	checkbox:SetChecked(config.showSpellAlerts ~= false)
	slider:SetValue(config.spellAlertOpacity or 1)
	if config.showSpellAlerts == false then
		slider:Disable()
	else
		slider:Enable()
	end
end

function CheeseOptions_SetAlerts(enabled)
	local config = GetConfig()
	if not config then return end
	config.showSpellAlerts = enabled and true or false
	if not enabled and CheeseSpellActivationOverlayFrame then
		CheeseSpellActivationOverlay_HideAllOverlays(CheeseSpellActivationOverlayFrame)
	elseif enabled and Cheese_RefreshSpellOverlays then
		Cheese_RefreshSpellOverlays()
	end
	CheeseOptions_Refresh(InterfaceOptionsCheesePanel)
end

function CheeseOptions_SetOpacity(value)
	local config = GetConfig()
	if not config then return end
	value = math.floor(value * 100 + 0.5) / 100
	config.spellAlertOpacity = value
	if CheeseSpellActivationOverlayFrame then
		CheeseSpellActivationOverlayFrame:SetAlpha(value)
	end
end
