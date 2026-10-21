local ToggleBindings = {}
_G.SarychUI_ToggleBindings = ToggleBindings
SarychUI.ToggleBindings = ToggleBindings

local State = {
	actions = {},
	buttons = {},
	nextActionOrder = 0,
	nextButtonID = 0,
	owner = CreateFrame("Frame", "SarychUIToggleBindingOwner", UIParent),
	eventFrame = CreateFrame("Frame"),
}

local function NormalizeKey(key)
	if type(key) ~= "string" then
		return nil
	end
	key = key:gsub("^%s+", ""):gsub("%s+$", "")
	if key == "" or key:upper() == "NONE" then
		return nil
	end
	return key:upper()
end

function ToggleBindings:NormalizeKey(key)
	return NormalizeKey(key)
end

local function ReportCallbackError(message)
	if geterrorhandler then
		local handler = geterrorhandler()
		if handler then
			handler(message)
		end
	end
end

function ToggleBindings:Dispatch(key)
	key = NormalizeKey(key)
	if not key then
		return
	end

	local matching = {}
	for _, action in pairs(State.actions) do
		if action.key == key then
			matching[#matching + 1] = action
		end
	end
	table.sort(matching, function(left, right)
		return left.order < right.order
	end)

	local sounds = {}
	local soundOrder = {}
	for _, action in ipairs(matching) do
		local ok, sound = pcall(action.callback)
		if not ok then
			ReportCallbackError(sound)
		elseif type(sound) == "string" and sound ~= "" and not sounds[sound] then
			sounds[sound] = true
			soundOrder[#soundOrder + 1] = sound
		end
	end

	if PlaySound then
		for _, sound in ipairs(soundOrder) do
			PlaySound(sound)
		end
	end
end

local function GetButton(key)
	local button = State.buttons[key]
	if button then
		return button
	end

	State.nextButtonID = State.nextButtonID + 1
	local name = "SarychUIToggleBindingButton" .. State.nextButtonID
	button = CreateFrame("Button", name, State.owner)
	button:SetSize(1, 1)
	button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -20, -20)
	button:SetAlpha(0)
	button:RegisterForClicks("AnyUp")
	button:SetScript("OnClick", function()
		ToggleBindings:Dispatch(key)
	end)
	State.buttons[key] = button
	return button
end

local function QueueRebuild()
	State.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function ToggleBindings:Rebuild()
	if InCombatLockdown and InCombatLockdown() then
		QueueRebuild()
		return false
	end

	State.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
	ClearOverrideBindings(State.owner)

	local keys = {}
	for _, action in pairs(State.actions) do
		keys[action.key] = true
	end
	for key in pairs(keys) do
		local button = GetButton(key)
		SetOverrideBindingClick(State.owner, true, key, button:GetName(), "LeftButton")
	end
	return true
end

function ToggleBindings:SetAction(id, key, callback)
	if type(id) ~= "string" or id == "" then
		return false
	end

	key = NormalizeKey(key)
	if not key or type(callback) ~= "function" then
		return self:RemoveAction(id)
	end

	local action = State.actions[id]
	if not action then
		State.nextActionOrder = State.nextActionOrder + 1
		action = { order = State.nextActionOrder }
		State.actions[id] = action
	end
	action.key = key
	action.callback = callback
	self:Rebuild()
	return true
end

function ToggleBindings:RemoveAction(id)
	if State.actions[id] == nil then
		return false
	end
	State.actions[id] = nil
	self:Rebuild()
	return true
end

State.eventFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		ToggleBindings:Rebuild()
	end
end)
