local BarVisibility = {}
_G.SarychUI_BarVisibility = BarVisibility

local managed = {
	{ name = "ShapeshiftBarFrame", group = "stance" },
	{ name = "SarychUI_DragonStanceBar", group = "stance" },
	{ name = "PetActionBarFrame", group = "pet" },
	{ name = "SarychUI_DragonPetBar", group = "pet" },
	{ name = "MainMenuBarBackpackButton", group = "bags" },
	{ name = "CharacterBag0Slot", group = "bags" },
	{ name = "CharacterBag1Slot", group = "bags" },
	{ name = "CharacterBag2Slot", group = "bags" },
	{ name = "CharacterBag3Slot", group = "bags" },
	{ name = "KeyRingButton", group = "bags" },
	{ name = "SarychUIMicroMenu", group = "micro" },
	{ name = "CharacterMicroButton", group = "micro" },
	{ name = "SpellbookMicroButton", group = "micro" },
	{ name = "TalentMicroButton", group = "micro" },
	{ name = "AchievementMicroButton", group = "micro" },
	{ name = "QuestLogMicroButton", group = "micro" },
	{ name = "SocialsMicroButton", group = "micro" },
	{ name = "PVPMicroButton", group = "micro" },
	{ name = "LFDMicroButton", group = "micro" },
	{ name = "MainMenuMicroButton", group = "micro" },
	{ name = "HelpMicroButton", group = "micro" },
	{ name = "ParagonMicroButton", group = "micro" },
	{ name = "CollectionsMicroButton", group = "micro" },
	{ name = "StoreMicroButton", group = "micro" },
}

local state = {
	enabled = false,
	hidden = false,
	wantedHidden = false,
	selected = {},
	wasShown = {},
	wasAlpha = {},
	alphaHidden = {},
	guarded = {},
}

local function IsOn(value)
	return value == 1 or value == true
end

local function GetSettings()
	local profile = SarychUI and SarychUI.db and SarychUI.db.profile
	local db = profile and profile.modules and profile.modules.mainmenubar
	return db, db and db.barVisibility
end

local function Guard(frame)
	if not frame or state.guarded[frame] then return end
	state.guarded[frame] = true
	frame:HookScript("OnShow", function(self)
		if state.hidden and state.selected[self] then
			if state.alphaHidden[self] then self:SetAlpha(0)
			else self:Hide() end
		end
	end)
end

local function Restore()
	if not state.hidden then return end
	local restoreStance, restorePet = false, false
	state.hidden = false
	for frame, group in pairs(state.selected) do
		if group == "stance" then restoreStance = true end
		if group == "pet" then restorePet = true end
		if state.alphaHidden[frame] then
			frame:SetAlpha(state.wasAlpha[frame] or 1)
		elseif state.wasShown[frame] then
			frame:Show()
		end
	end
	state.selected = {}
	state.wasShown = {}
	state.wasAlpha = {}
	state.alphaHidden = {}
	if (restoreStance or restorePet) and not (InCombatLockdown and InCombatLockdown()) then
		local module = SarychUI and SarychUI.modules and SarychUI.modules.mainmenubar
		local dragon = module and module.DragonStyle
		if dragon and dragon.active and dragon.UpdatePetAndStance then
			dragon:UpdatePetAndStance()
		else
			if restoreStance and _G.ShapeshiftBar_Update then
				_G.ShapeshiftBar_Update()
			end
			if restorePet and _G.PetActionBarFrame and _G.PetActionBar_Update then
				_G.PetActionBar_Update(_G.PetActionBarFrame)
				if _G.PetActionBarFrame.showgrid == 0 then
					if _G.PetHasActionBar and _G.PetHasActionBar()
						and _G.UnitIsVisible and _G.UnitIsVisible("pet") then
						if _G.ShowPetActionBar then _G.ShowPetActionBar(true) end
					else
						_G.PetActionBarFrame:Hide()
					end
				end
			end
		end
	end
end

local function SelectionMatches(settings)
	for _, entry in ipairs(managed) do
		local frame = _G[entry.name]
		if frame and (state.selected[frame] ~= nil) ~= IsOn(settings[entry.group]) then
			return false
		end
	end
	return true
end

local function Hide(settings)
	if state.hidden then return end
	state.selected = {}
	state.wasShown = {}
	state.wasAlpha = {}
	state.alphaHidden = {}
	for _, entry in ipairs(managed) do
		if IsOn(settings[entry.group]) then
			local frame = _G[entry.name]
			if frame then
				Guard(frame)
				state.selected[frame] = entry.group
				state.wasShown[frame] = frame:IsShown() and true or false
				if frame.IsProtected and frame:IsProtected() then
					state.alphaHidden[frame] = true
					state.wasAlpha[frame] = frame:GetAlpha()
				end
			end
		end
	end
	state.hidden = true
	for frame in pairs(state.selected) do
		if state.alphaHidden[frame] then frame:SetAlpha(0)
		else frame:Hide() end
	end
end

local function ApplyWanted()
	local _, settings = GetSettings()
	if state.wantedHidden and state.enabled and settings then
		if not state.hidden or not SelectionMatches(settings) then
			Restore()
			Hide(settings)
		else
			for frame in pairs(state.selected) do
				if state.alphaHidden[frame] then frame:SetAlpha(0)
				elseif frame:IsShown() then frame:Hide() end
			end
		end
	else
		Restore()
	end
end

function BarVisibility.Toggle(silent)
	if not state.enabled then return end
	state.wantedHidden = not state.wantedHidden
	ApplyWanted()
	local bindings = _G.SarychUI_ToggleBindings
	if bindings and bindings.SyncSecureHidden then
		bindings:SyncSecureHidden("bar_visibility", state.hidden)
	end
	local sound = state.wantedHidden and "igMiniMapZoomOut" or "igMiniMapZoomIn"
	if not silent and PlaySound then PlaySound(sound) end
	return sound
end

function BarVisibility.IsHidden()
	return state.hidden
end

function BarVisibility.IsGroupHidden(group)
	if not state.hidden then return false end
	for _, selectedGroup in pairs(state.selected) do
		if selectedGroup == group then return true end
	end
	return false
end

function BarVisibility.ApplySettings()
	local db, settings = GetSettings()
	local bindings = _G.SarychUI_ToggleBindings
	local key = bindings and bindings:NormalizeKey(settings and settings.key)
	state.enabled = db and IsOn(db.enabled) and settings and IsOn(settings.enabled) and key ~= nil
	if not state.enabled then state.wantedHidden = false end
	ApplyWanted()
	if bindings then
		if state.enabled then
			bindings:SetAction("bar_visibility", key, function()
				return BarVisibility.Toggle(true)
			end)
			if bindings.SetSecureFrames then
				local frames = {}
				for _, entry in ipairs(managed) do
					local frame = _G[entry.name]
					if IsOn(settings[entry.group]) and frame and frame.IsProtected
						and frame:IsProtected() then
						frames[#frames + 1] = frame
					end
				end
				bindings:SetSecureFrames("bar_visibility", frames, state.hidden)
			end
		else
			bindings:RemoveAction("bar_visibility")
		end
	end
end

function BarVisibility.Disable()
	state.enabled = false
	state.wantedHidden = false
	ApplyWanted()
	local bindings = _G.SarychUI_ToggleBindings
	if bindings then bindings:RemoveAction("bar_visibility") end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_REGEN_ENABLED")
boot:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		ApplyWanted()
	else
		BarVisibility.ApplySettings()
	end
end)
