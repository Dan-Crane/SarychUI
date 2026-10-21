-- SarychUI Auras Module
-- Focus/ToT aura hiding, frame aura sizing, player buff rows, dispel highlight, buff frame management.
-- Extracted from frame so enabling/disabling Frames no longer gates these features.

local pairs = pairs
local moduleName = "auras"
local module = {}

SarychUI:RegisterModule(moduleName, module)

local AceEvent = LibStub("AceEvent-3.0")
local AceBucket = LibStub("AceBucket-3.0")
local AceHook = LibStub("AceHook-3.0")
AceEvent:Embed(module)
AceBucket:Embed(module)
AceHook:Embed(module)

local L = SarychUI.L

local function GetSetting(key, default)
	local db = SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
		or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
	if db and db[key] ~= nil then
		return db[key]
	end
	return default
end

local function ModuleDB()
	return SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
		or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
end

--------------------------------------------------------------------
-- Focus / ToT / Target aura hiding
--------------------------------------------------------------------
local focusAuraUpdateFrame = CreateFrame("Frame")
focusAuraUpdateFrame:Hide()

local function HideNamedAuras(prefix, hide)
	for i = 1, 32 do
		local buff = _G[prefix .. "Buff" .. i]
		if buff then
			if hide then
				buff:Hide()
				buff:SetAlpha(0)
				buff:SetScale(0.01)
			elseif buff.SetAlpha then
				buff:SetAlpha(1)
				buff:SetScale(1)
			end
		end
	end
	for i = 1, 16 do
		local debuff = _G[prefix .. "Debuff" .. i]
		if debuff then
			if hide then
				debuff:Hide()
				debuff:SetAlpha(0)
				debuff:SetScale(0.01)
			elseif debuff.SetAlpha then
				debuff:SetAlpha(1)
				debuff:SetScale(1)
			end
		end
	end
end

local function AuraHideOnUpdate()
	if GetSetting("hideFocusAuras", 0) == 1 then
		HideNamedAuras("FocusFrame", true)
	end
	if GetSetting("hideTargetAuras", 0) == 1 then
		HideNamedAuras("TargetFrame", true)
	end
end

local function SetAuraHideTicker(enabled)
	local runtime = SarychUI and SarychUI.Runtime
	if runtime and runtime.RegisterUpdate then
		focusAuraUpdateFrame:SetScript("OnUpdate", nil)
		if enabled then
			runtime:RegisterUpdate("auras.hide_named", 0.10, AuraHideOnUpdate)
		else
			runtime:UnregisterUpdate("auras.hide_named")
		end
		return
	end
	focusAuraUpdateFrame:SetScript("OnUpdate", enabled and AuraHideOnUpdate or nil)
end

function module:UpdateFocusAuras()
	local db = ModuleDB()
	if not db or not db.enabled then
		focusAuraUpdateFrame:Hide()
		SetAuraHideTicker(false)
		return
	end

	local hideFocus = GetSetting("hideFocusAuras", 0) == 1
	local hideTarget = GetSetting("hideTargetAuras", 0) == 1
	if hideFocus or hideTarget then
		focusAuraUpdateFrame:Show()
		SetAuraHideTicker(true)
	else
		focusAuraUpdateFrame:Hide()
		SetAuraHideTicker(false)
	end

	if hideFocus then
		HideNamedAuras("FocusFrame", true)
	else
		HideNamedAuras("FocusFrame", false)
	end
end

function module:UpdateTargetAuras()
	local db = ModuleDB()
	if not db or not db.enabled then
		return
	end
	self:UpdateFocusAuras()
	if GetSetting("hideTargetAuras", 0) == 1 then
		HideNamedAuras("TargetFrame", true)
	else
		HideNamedAuras("TargetFrame", false)
	end
end

function module:UpdateToTAuras()
	local db = ModuleDB()
	if not db or not db.enabled then
		return
	end

	if GetSetting("hideTargetOfTargetAuras", 0) == 1 then
		for _, v in pairs({ "TargetFrameToTDebuff", "FocusFrameToTDebuff" }) do
			for i = 1, 4 do
				local aura = _G[v .. i]
				if aura then
					aura:Hide()
					aura:SetScale(1e-4)
					aura:SetAlpha(0)
					aura.Show = function() end
				end
			end
		end
	else
		for _, v in pairs({ "TargetFrameToTDebuff", "FocusFrameToTDebuff" }) do
			for i = 1, 4 do
				local aura = _G[v .. i]
				if aura then
					aura:SetScale(1)
					aura:SetAlpha(1)
					aura.Show = nil
					aura:Show()
				end
			end
		end
	end
end

function module:ForceUpdateAuras()
	self:UpdateTargetAuras()
	self:UpdateToTAuras()
end

function module:RestoreAuras()
	focusAuraUpdateFrame:Hide()
	SetAuraHideTicker(false)

	if TargetFrame then
		for i = 1, 32 do
			local buff = _G["TargetFrameBuff" .. i]
			if buff then
				buff:SetAlpha(1)
				buff:SetScale(1)
				buff.Show = nil
				buff:Show()
			end
		end
		for i = 1, 16 do
			local debuff = _G["TargetFrameDebuff" .. i]
			if debuff then
				debuff:SetAlpha(1)
				debuff:SetScale(1)
				debuff.Show = nil
				debuff:Show()
			end
		end
	end

	if FocusFrame then
		for i = 1, 32 do
			local buff = _G["FocusFrameBuff" .. i]
			if buff then
				buff:SetAlpha(1)
				buff:SetScale(1)
				buff.Show = nil
				buff:Show()
			end
		end
		for i = 1, 16 do
			local debuff = _G["FocusFrameDebuff" .. i]
			if debuff then
				debuff:SetAlpha(1)
				debuff:SetScale(1)
				debuff.Show = nil
				debuff:Show()
			end
		end
	end

	for _, v in pairs({ "TargetFrameToTDebuff", "FocusFrameToTDebuff" }) do
		for i = 1, 4 do
			local aura = _G[v .. i]
			if aura then
				aura:SetScale(1)
				aura:SetAlpha(1)
				aura.Show = nil
				aura:Show()
			end
		end
	end
end

--------------------------------------------------------------------
-- Target / Focus aura size (RougeUI BuffSizer)
--------------------------------------------------------------------
local AURA_OFFSET_Y = 1
local AURA_START_X = 5
local mabs, mfloor, mceil = math.abs, math.floor, math.ceil
local auraCountFontName

local PLAYER_UNITS = {
	player = true,
	vehicle = true,
	pet = true,
}

local largeBuffList = {}
local largeDebuffList = {}

local function AddonLoaded(name)
	return IsAddOnLoaded and IsAddOnLoaded(name)
end

local function SettingOn(key)
	local v = GetSetting(key, 0)
	return v == 1 or v == true
end

local function UseCustomAuraSize()
	return SettingOn("changeFrameAuraSize")
end

local function AurasGrowUp()
	return SettingOn("frameAurasGrowUp")
end

local function GrowUpStartY()
	local y = tonumber(GetSetting("frameAurasGrowUpY", -17))
	if y == nil then return -17 end
	return y
end

local function CustomFrameAuraLayout()
	return UseCustomAuraSize() or AurasGrowUp()
end

local function GetFramePosition(frame)
	if not frame then
		return 0, 0
	end
	return frame:GetLeft() or 0, frame:GetBottom() or 0
end

local function ShouldAuraBeLarge(caster)
	if not caster then
		return false
	end
	if PLAYER_UNITS[caster] then
		return true
	end
	if UnitIsUnit then
		for token in pairs(PLAYER_UNITS) do
			if UnitIsUnit(caster, token) then
				return true
			end
		end
	end
	return false
end

local function ApplyAuraCountFont(frameName, size)
	local frameCount = _G[frameName .. "Count"]
	if not frameCount or not frameCount.SetFont then
		return
	end
	if not auraCountFontName then
		auraCountFontName = frameCount.GetFont and frameCount:GetFont()
	end
	if auraCountFontName then
		frameCount:SetFont(auraCountFontName, size / 1.75, "OUTLINE")
	end
end

local function UpdateBuffAnchor(frame, buffName, index, numDebuffs, anchorIndex, size, offsetX, offsetY)
	local growUp = AurasGrowUp()
	local point, relativePoint, startY = "TOP", "BOTTOM", 32
	if growUp then
		point, relativePoint, startY = "BOTTOM", "TOP", GrowUpStartY()
	end
	local stackY = growUp and offsetY or -offsetY
	local buff = _G[buffName .. index]
	if not buff then return end
	buff:ClearAllPoints()

	if index == 1 then
		if UnitIsFriend("player", frame.unit) or numDebuffs == 0 then
			buff:SetPoint(point .. "LEFT", frame, relativePoint .. "LEFT", AURA_START_X, startY)
		else
			local debuffs = frame.debuffs
			if debuffs then
				local _, a = debuffs:GetPoint()
				if a then
					local _, b = a:GetPoint()
					if b == frame.buffs then
						debuffs:ClearAllPoints()
						debuffs:SetPoint(point .. "LEFT", frame, point .. "LEFT", 0, 0)
						debuffs:SetPoint(relativePoint .. "LEFT", frame, relativePoint .. "LEFT", 0, growUp and AURA_OFFSET_Y or -AURA_OFFSET_Y)
					end
				end
				buff:SetPoint(point .. "LEFT", debuffs, relativePoint .. "LEFT", 0, stackY)
			else
				local firstDebuff = _G[(frame:GetName() or "") .. "Debuff1"]
				if firstDebuff then
					buff:SetPoint(point .. "LEFT", firstDebuff, relativePoint .. "LEFT", 0, stackY)
				else
					buff:SetPoint(point .. "LEFT", frame, relativePoint .. "LEFT", AURA_START_X, startY)
				end
			end
		end
		if frame.buffs then
			frame.buffs:ClearAllPoints()
			frame.buffs:SetPoint(point .. "LEFT", buff, point .. "LEFT", 0, 0)
			frame.buffs:SetPoint(relativePoint .. "LEFT", buff, relativePoint .. "LEFT", 0, growUp and AURA_OFFSET_Y or -AURA_OFFSET_Y)
		end
		if not growUp then
			frame.spellbarAnchor = buff
		end
	elseif anchorIndex ~= (index - 1) then
		buff:SetPoint(point .. "LEFT", _G[buffName .. anchorIndex], relativePoint .. "LEFT", 0, stackY)
		if frame.buffs then
			frame.buffs:SetPoint(relativePoint .. "LEFT", buff, relativePoint .. "LEFT", 0, growUp and AURA_OFFSET_Y or -AURA_OFFSET_Y)
		end
		if not growUp then
			frame.spellbarAnchor = buff
		end
	else
		buff:SetPoint(point .. "LEFT", _G[buffName .. anchorIndex], point .. "RIGHT", offsetX, 0)
	end

	buff:SetWidth(size)
	buff:SetHeight(size)
end

local function UpdateDebuffAnchor(frame, debuffName, index, numBuffs, anchorIndex, size, offsetX, offsetY)
	local buff = _G[debuffName .. index]
	if not buff then return end
	buff:ClearAllPoints()
	local isFriend = UnitIsFriend("player", frame.unit)
	local growUp = AurasGrowUp()
	local point, relativePoint, startY = "TOP", "BOTTOM", 32
	if growUp then
		point, relativePoint, startY = "BOTTOM", "TOP", GrowUpStartY()
	end
	local stackY = growUp and offsetY or -offsetY

	if index == 1 then
		if isFriend and numBuffs > 0 then
			local buffs = frame.buffs or _G[(frame:GetName() or "") .. "Buff1"]
			if buffs then
				buff:SetPoint(point .. "LEFT", buffs, relativePoint .. "LEFT", 0, stackY)
			else
				buff:SetPoint(point .. "LEFT", frame, relativePoint .. "LEFT", AURA_START_X, startY)
			end
		else
			buff:SetPoint(point .. "LEFT", frame, relativePoint .. "LEFT", AURA_START_X, startY)
		end
		if frame.debuffs then
			frame.debuffs:ClearAllPoints()
			frame.debuffs:SetPoint(point .. "LEFT", buff, point .. "LEFT", 0, 0)
			frame.debuffs:SetPoint(relativePoint .. "LEFT", buff, relativePoint .. "LEFT", 0, growUp and AURA_OFFSET_Y or -AURA_OFFSET_Y)
		end
		if isFriend or (not isFriend and numBuffs == 0) then
			if not growUp then
				frame.spellbarAnchor = buff
			end
		end
	elseif anchorIndex ~= (index - 1) then
		buff:SetPoint(point .. "LEFT", _G[debuffName .. anchorIndex], relativePoint .. "LEFT", 0, stackY)
		if frame.debuffs then
			frame.debuffs:SetPoint(relativePoint .. "LEFT", buff, relativePoint .. "LEFT", 0, growUp and AURA_OFFSET_Y or -AURA_OFFSET_Y)
		end
		if isFriend or (not isFriend and numBuffs == 0) then
			if not growUp then
				frame.spellbarAnchor = buff
			end
		end
	else
		buff:SetPoint(point .. "LEFT", _G[debuffName .. (index - 1)], point .. "RIGHT", offsetX, 0)
	end

	buff:SetWidth(size)
	buff:SetHeight(size)
	local debuffFrame = _G[debuffName .. index .. "Border"]
	if debuffFrame then
		debuffFrame:SetWidth(size + 2)
		debuffFrame:SetHeight(size + 2)
	end
end

local function TargetBuffSize(frame, auraName, numAuras, numOppositeAuras, largeAuraList, updateFunc, maxRowWidth, offsetX)
	local LARGE_AURA_SIZE = UseCustomAuraSize() and GetSetting("frameAuraSelfSize", 23) or 21
	local SMALL_AURA_SIZE = UseCustomAuraSize() and GetSetting("frameAuraOtherSize", 23) or 17
	local size, biggestAura
	local offsetY = AURA_OFFSET_Y
	local rowWidth = 0
	local firstBuffOnRow = 1
	local totFrame = frame.totFrame
	local growUp = AurasGrowUp()
	local haveTargetofTarget = (not growUp) and totFrame and totFrame.IsShown and totFrame:IsShown()
	local totFrameX, totFrameBottom = GetFramePosition(totFrame)
	local currentX, currentY

	if UseCustomAuraSize() then
		maxRowWidth = GetSetting("frameAuraRowWidth", 122)
	end

	for i = 1, numAuras do
		if largeAuraList[i] then
			size = LARGE_AURA_SIZE
			offsetY = AURA_OFFSET_Y + AURA_OFFSET_Y
		else
			size = SMALL_AURA_SIZE
		end

		if i == 1 then
			rowWidth = size
			frame.auraRows = (frame.auraRows or 0) + 1
			if frame.largestAura then
				offsetY = frame.largestAura
			end
		else
			rowWidth = rowWidth + size + offsetX
		end

		local verticalDistance = currentY and (currentY - totFrameBottom) or 0
		local horizontalDistance = rowWidth
		if currentX then
			horizontalDistance = mfloor(mabs((currentX + size + offsetX) - totFrameX)) + 5
		end

		if (haveTargetofTarget and horizontalDistance < size and verticalDistance > 0) or (rowWidth > maxRowWidth) then
			local anchorAura = _G[auraName .. firstBuffOnRow]
			local anchorW = anchorAura and (anchorAura.GetWidth and anchorAura:GetWidth() or 0) or 0
			if biggestAura and anchorAura then
				if biggestAura >= mfloor(anchorW + 0.5) then
					offsetY = (AURA_OFFSET_Y * 2) + (biggestAura - anchorW)
				end
			end
			updateFunc(frame, auraName, i, numOppositeAuras, firstBuffOnRow, size, offsetX, offsetY)
			rowWidth = size
			frame.auraRows = (frame.auraRows or 0) + 1
			firstBuffOnRow = i
			offsetY = AURA_OFFSET_Y
			biggestAura = nil
			frame.largestAura = nil
		else
			updateFunc(frame, auraName, i, numOppositeAuras, i - 1, size, offsetX, offsetY)
		end

		if not biggestAura or biggestAura < size then
			biggestAura = size
		end

		local firstAura = _G[auraName .. firstBuffOnRow]
		if firstAura then
			local firstW = firstAura.GetWidth and firstAura:GetWidth() or 0
			local calc = (AURA_OFFSET_Y * 2) + (biggestAura - firstW)
			if not frame.largestAura or frame.largestAura < calc then
				frame.largestAura = calc
			end
		end

		local aura = _G[auraName .. i]
		if aura then
			currentX, currentY = aura:GetLeft(), aura:GetTop()
		end
	end
end

local function AdjustTargetSpellbar(spellbar)
	if not spellbar then return end
	local parentFrame = spellbar.GetParent and spellbar:GetParent()
	if not parentFrame then return end

	if spellbar.boss then
		spellbar:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 25, 10)
	elseif parentFrame.haveToT then
		if parentFrame.buffsOnTop or (parentFrame.auraRows or 0) <= 1 then
			spellbar:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 25, -25)
		elseif parentFrame.spellbarAnchor then
			spellbar:SetPoint("TOPLEFT", parentFrame.spellbarAnchor, "BOTTOMLEFT", 20, -15)
		else
			spellbar:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 25, -25)
		end
	elseif parentFrame.haveElite then
		if parentFrame.buffsOnTop or (parentFrame.auraRows or 0) <= 1 then
			spellbar:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 25, -5)
		elseif parentFrame.spellbarAnchor then
			spellbar:SetPoint("TOPLEFT", parentFrame.spellbarAnchor, "BOTTOMLEFT", 20, -15)
		else
			spellbar:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 25, -5)
		end
	else
		if (not parentFrame.buffsOnTop) and (parentFrame.auraRows or 0) > 0 and parentFrame.spellbarAnchor then
			spellbar:SetPoint("TOPLEFT", parentFrame.spellbarAnchor, "BOTTOMLEFT", 20, -15)
		else
			spellbar:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 25, 7)
		end
	end
end

function module:LayoutFrameAuras(frame)
	if not frame or (frame ~= TargetFrame and frame ~= FocusFrame) then
		return
	end
	if not CustomFrameAuraLayout() then
		return
	end

	local unit = frame.unit
	if not unit then
		unit = (frame == FocusFrame) and "focus" or "target"
		frame.unit = unit
	end
	if not UnitExists or not UnitExists(unit) then
		return
	end

	local selfName = frame:GetName()
	if not selfName then return end

	local growUp = AurasGrowUp()

	frame.buffs = frame.buffs or _G[selfName .. "Buffs"]
	frame.debuffs = frame.debuffs or _G[selfName .. "Debuffs"]
	if not frame.totFrame then
		if frame == TargetFrame then
			frame.totFrame = TargetofTargetFrame
		elseif frame == FocusFrame then
			frame.totFrame = FocusFrameToT
		end
	end
	frame.spellbar = frame.spellbar or _G[selfName .. "SpellBar"]

	local isEnemy = UnitIsEnemy and UnitIsEnemy("player", unit)
	local customSize = UseCustomAuraSize()
	local numBuffs = 0
	local maxBuffs = frame.maxBuffs or 32

	for i = 1, maxBuffs do
		local name, _, icon, _, _, _, _, caster = UnitBuff(unit, i)
		if not name then break end
		if icon then
			local largeSize = ShouldAuraBeLarge(caster)
			local buffSize = largeSize and (customSize and GetSetting("frameAuraSelfSize", 23) or 21) or (customSize and GetSetting("frameAuraOtherSize", 23) or 17)
			local frameName = selfName .. "Buff" .. i
			if customSize then
				ApplyAuraCountFont(frameName, buffSize)
				local stealable = _G[frameName .. "Stealable"]
				if stealable then
					stealable:SetHeight(buffSize * 1.2)
					stealable:SetWidth(buffSize * 1.2)
				end
			end
			numBuffs = numBuffs + 1
			largeBuffList[numBuffs] = largeSize
		end
	end

	local numDebuffs = 0
	local maxDebuffs = frame.maxDebuffs or 16
	for i = 1, maxDebuffs do
		local debuffName, _, icon, _, _, _, _, caster = UnitDebuff(unit, i)
		if not debuffName then break end
		if icon then
			local largeSize = ShouldAuraBeLarge(caster)
			local buffSize = largeSize and (customSize and GetSetting("frameAuraSelfSize", 23) or 21) or (customSize and GetSetting("frameAuraOtherSize", 23) or 17)
			if customSize then
				ApplyAuraCountFont(selfName .. "Debuff" .. i, buffSize)
			end
			numDebuffs = numDebuffs + 1
			largeDebuffList[numDebuffs] = largeSize
		end
	end

	frame.auraRows = 0
	frame.largestAura = 0
	frame.spellbarAnchor = nil

	local maxRowWidth = customSize and GetSetting("frameAuraRowWidth", 122) or 122
	local xOffset = 3

	if isEnemy then
		TargetBuffSize(frame, selfName .. "Debuff", numDebuffs, numBuffs, largeDebuffList, UpdateDebuffAnchor, maxRowWidth, xOffset)
		TargetBuffSize(frame, selfName .. "Buff", numBuffs, numDebuffs, largeBuffList, UpdateBuffAnchor, maxRowWidth, xOffset)
	else
		TargetBuffSize(frame, selfName .. "Buff", numBuffs, numDebuffs, largeBuffList, UpdateBuffAnchor, maxRowWidth, xOffset)
		TargetBuffSize(frame, selfName .. "Debuff", numDebuffs, numBuffs, largeDebuffList, UpdateDebuffAnchor, maxRowWidth, xOffset)
	end

	if growUp then
		frame.auraRows = 0
	elseif frame.spellbar then
		AdjustTargetSpellbar(frame.spellbar)
	end
end

--------------------------------------------------------------------
-- Player buffs per row (RougeUI BuffsRow)
--------------------------------------------------------------------
local function SeparatePlayerAuraPositioning()
	return GetSetting("manageBuffs", 0) == 1
		and GetSetting("playerAuraPositionMode", "together") == "separate"
end

local function NormalizePlayerAuraGrowth(value)
	return value == "left_to_right" and "left_to_right" or "right_to_left"
end

local function PlayerBuffGrowthDirection()
	if GetSetting("manageBuffs", 0) ~= 1 then
		return "right_to_left"
	end
	if SeparatePlayerAuraPositioning() then
		return NormalizePlayerAuraGrowth(GetSetting("playerBuffGrowthDirection", "right_to_left"))
	end
	return NormalizePlayerAuraGrowth(GetSetting("playerAuraGrowthDirection", "right_to_left"))
end

local function PlayerDebuffGrowthDirection()
	if GetSetting("manageBuffs", 0) ~= 1 then
		return "right_to_left"
	end
	if SeparatePlayerAuraPositioning() then
		return NormalizePlayerAuraGrowth(GetSetting("playerDebuffGrowthDirection", "right_to_left"))
	end
	return NormalizePlayerAuraGrowth(GetSetting("playerAuraGrowthDirection", "right_to_left"))
end

local function FrameIsShown(frame)
	return frame and (not frame.IsShown or frame:IsShown())
end

local function PlayerAuraButtonsPerRow()
	if SettingOn("changePlayerBuffRow") then
		local count = tonumber(GetSetting("playerBuffsPerRow", 8)) or 8
		if count > 0 then
			return count
		end
	end
	return BUFFS_PER_ROW or 8
end

local function PlayerBuffGrowthOrigin()
	return ConsolidatedBuffs or TemporaryEnchantFrame or BuffFrame
end

local function ConsolidatedBuffsTakesSlot()
	if not FrameIsShown(ConsolidatedBuffs) then
		return false
	end
	if BuffFrame and type(BuffFrame.numConsolidated) == "number" then
		return BuffFrame.numConsolidated > 0
	end
	if ShouldShowConsolidatedBuffFrame then
		return not not ShouldShowConsolidatedBuffFrame()
	end
	return true
end

local function IsCollapsedPlayerBuff(buff)
	if not buff then
		return true
	end
	if buff.consolidated then
		return true
	end
	local parent = buff.GetParent and buff:GetParent()
	if not parent then
		return false
	end
	if ConsolidatedBuffsContainer and parent == ConsolidatedBuffsContainer then
		return true
	end
	if ConsolidatedBuffsTooltip and parent == ConsolidatedBuffsTooltip then
		return true
	end
	return false
end

local function CollectVisiblePlayerBuffs(includeEnchants)
	local frames = {}
	if includeEnchants then
		if FrameIsShown(TempEnchant1) then
			frames[#frames + 1] = TempEnchant1
		end
		if FrameIsShown(TempEnchant2) then
			frames[#frames + 1] = TempEnchant2
		end
	end
	local maxBuffs = BUFF_MAX_DISPLAY or 32
	for index = 1, maxBuffs do
		local buff = _G["BuffButton" .. index]
		if FrameIsShown(buff) and not IsCollapsedPlayerBuff(buff) then
			frames[#frames + 1] = buff
		end
	end
	return frames
end

local function CollectLeftToRightPlayerBuffs()
	local frames = {}
	if ConsolidatedBuffsTakesSlot() then
		frames[#frames + 1] = ConsolidatedBuffs
	end
	local visible = CollectVisiblePlayerBuffs(true)
	for index = 1, #visible do
		frames[#frames + 1] = visible[index]
	end
	return frames
end

local function VisiblePlayerBuffSlotCount(includeEnchants)
	return #CollectLeftToRightPlayerBuffs()
end

local function RestoreTemporaryEnchantGrowth()
	if TempEnchant1 and TemporaryEnchantFrame then
		TempEnchant1:ClearAllPoints()
		TempEnchant1:SetPoint("TOPRIGHT", TemporaryEnchantFrame, "TOPRIGHT", 0, 0)
	end
	if TempEnchant2 and TempEnchant1 then
		TempEnchant2:ClearAllPoints()
		TempEnchant2:SetPoint("RIGHT", TempEnchant1, "LEFT", -5, 0)
	end
end

local playerDebuffAnchor

local function EnsurePlayerDebuffAnchor()
	if playerDebuffAnchor then
		return playerDebuffAnchor
	end

	playerDebuffAnchor = CreateFrame("Frame", "SarychUIPlayerDebuffAnchor", UIParent)
	playerDebuffAnchor:SetWidth(50)
	playerDebuffAnchor:SetHeight(50)
	playerDebuffAnchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -205, -105)
	if BuffFrame and BuffFrame.GetFrameStrata then
		playerDebuffAnchor:SetFrameStrata(BuffFrame:GetFrameStrata())
	end
	return playerDebuffAnchor
end

local function PlayerDebuffsPerRow()
	return PlayerAuraButtonsPerRow()
end

function module:LayoutPlayerBuffsLeftToRight()
	if AddonLoaded("SimpleAuraFilter") or PlayerBuffGrowthDirection() ~= "left_to_right" then
		return
	end

	local origin = PlayerBuffGrowthOrigin()
	if not origin then return end
	local frames = CollectLeftToRightPlayerBuffs()
	local perRow = PlayerAuraButtonsPerRow()
	local rowSpacing = BUFF_ROW_SPACING or 15

	for index, frame in ipairs(frames) do
		-- The consolidate icon is also the mover; do not rip it off its saved point.
		if frame ~= origin then
			frame:ClearAllPoints()
			if index == 1 then
				frame:SetPoint("TOPLEFT", origin, "TOPRIGHT", 0, 0)
			elseif ((index - 1) % perRow) == 0 then
				local above = frames[index - perRow]
				if above then
					frame:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -rowSpacing)
				end
			else
				frame:SetPoint("LEFT", frames[index - 1], "RIGHT", 5, 0)
			end
		end
	end
end

function module:LayoutCombinedPlayerDebuffsLeftToRight()
	if AddonLoaded("SimpleAuraFilter") or SeparatePlayerAuraPositioning()
		or PlayerDebuffGrowthDirection() ~= "left_to_right" then
		return
	end

	local origin = PlayerBuffGrowthOrigin()
	if not origin then return end
	local perRow = PlayerAuraButtonsPerRow()
	local rowSpacing = BUFF_ROW_SPACING or 15
	local buffCount = VisiblePlayerBuffSlotCount(true)
	local buffRows = math.max(1, mceil(buffCount / perRow))
	local startY = -buffRows * (30 + rowSpacing)
	local visibleDebuffs = {}
	local maxDebuffs = DEBUFF_MAX_DISPLAY or 16

	for index = 1, maxDebuffs do
		local debuff = _G["DebuffButton" .. index]
		if FrameIsShown(debuff) then
			visibleDebuffs[#visibleDebuffs + 1] = debuff
		end
	end

	for index, debuff in ipairs(visibleDebuffs) do
		debuff:ClearAllPoints()
		if index == 1 then
			debuff:SetPoint("TOPLEFT", origin, "TOPRIGHT", 0, startY)
		elseif ((index - 1) % perRow) == 0 then
			local above = visibleDebuffs[index - perRow]
			debuff:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -rowSpacing)
		else
			debuff:SetPoint("LEFT", visibleDebuffs[index - 1], "RIGHT", 6, 0)
		end
	end
end

function module:LayoutSeparatePlayerDebuffs()
	if AddonLoaded("SimpleAuraFilter") or not SeparatePlayerAuraPositioning() or not BuffFrame then
		return
	end

	local anchor = EnsurePlayerDebuffAnchor()
	local perRow = PlayerDebuffsPerRow()
	local rowSpacing = BUFF_ROW_SPACING or 15
	local maxDebuffs = DEBUFF_MAX_DISPLAY or 16
	local leftToRight = PlayerDebuffGrowthDirection() == "left_to_right"

	for index = 1, maxDebuffs do
		local debuff = _G["DebuffButton" .. index]
		if debuff then
			if debuff:GetParent() ~= anchor then
				debuff:SetParent(anchor)
			end
			debuff:SetScale(1)
			debuff:ClearAllPoints()
			if index == 1 then
				if leftToRight then
					debuff:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 0, 0)
				else
					debuff:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
				end
			elseif (index % perRow) == 1 then
				local above = _G["DebuffButton" .. (index - perRow)]
				if above then
					if leftToRight then
						debuff:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -rowSpacing)
					else
						debuff:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -rowSpacing)
					end
				end
			else
				local previous = _G["DebuffButton" .. (index - 1)]
				if previous then
					if leftToRight then
						debuff:SetPoint("LEFT", previous, "RIGHT", 5, 0)
					else
						debuff:SetPoint("RIGHT", previous, "LEFT", -5, 0)
					end
				end
			end
		end
	end
end

function module:RestoreCombinedPlayerDebuffs(refresh)
	if not BuffFrame then return end
	local maxDebuffs = DEBUFF_MAX_DISPLAY or 16
	local restored = false

	for index = 1, maxDebuffs do
		local debuff = _G["DebuffButton" .. index]
		if debuff and playerDebuffAnchor and debuff:GetParent() == playerDebuffAnchor then
			debuff:SetParent(BuffFrame)
			debuff:SetScale(1)
			debuff:ClearAllPoints()
			restored = true
		end
	end

	if refresh and restored then
		if BuffFrame_Update then
			pcall(BuffFrame_Update)
		elseif DebuffButton_UpdateAnchors then
			for index = 1, maxDebuffs do
				if _G["DebuffButton" .. index] then
					pcall(DebuffButton_UpdateAnchors, "DebuffButton", index)
				end
			end
		end
	end
end

function module:OnBuffFrameUpdateAllBuffAnchors()
	if not BuffFrame then
		return
	end
	if AddonLoaded("SimpleAuraFilter") then
		return
	end
	if PlayerBuffGrowthDirection() == "left_to_right" then
		self:LayoutPlayerBuffsLeftToRight()
		return
	end
	if not SettingOn("changePlayerBuffRow") then
		return
	end

	local buff, previousBuff, aboveBuff
	local numBuffs = 0
	local BUFFS_PER_ROW = GetSetting("playerBuffsPerRow", 8)
	if BUFFS_PER_ROW < 1 then BUFFS_PER_ROW = 1 end
	local slack = BuffFrame.numEnchants or 0
	if BuffFrame.numConsolidated and BuffFrame.numConsolidated > 0 then
		slack = slack + 1
	end
	local rowSpacing = BUFF_ROW_SPACING or 15
	local actual = BUFF_ACTUAL_DISPLAY or 0

	for i = 1, actual do
		buff = _G["BuffButton" .. i]
		if buff and not buff.consolidated then
			numBuffs = numBuffs + 1
			local index = numBuffs + slack
			buff:ClearAllPoints()
			if index > 1 and (index % BUFFS_PER_ROW) == 1 then
				if index == BUFFS_PER_ROW + 1 and ConsolidatedBuffs then
					buff:SetPoint("TOPRIGHT", ConsolidatedBuffs, "BOTTOMRIGHT", 0, -rowSpacing - 3)
				elseif aboveBuff then
					buff:SetPoint("TOPRIGHT", aboveBuff, "BOTTOMRIGHT", 0, -rowSpacing)
				end
				aboveBuff = buff
			elseif index == 1 then
				buff:SetPoint("TOPRIGHT", BuffFrame, "TOPRIGHT", 0, 0)
				aboveBuff = buff
			else
				if numBuffs == 1 then
					if (BuffFrame.numEnchants or 0) > 0 and TemporaryEnchantFrame then
						buff:SetPoint("TOPRIGHT", TemporaryEnchantFrame, "TOPLEFT", -5, 0)
						aboveBuff = TemporaryEnchantFrame
					elseif ConsolidatedBuffs then
						buff:SetPoint("TOPRIGHT", ConsolidatedBuffs, "TOPLEFT", -5, 0)
					end
				elseif previousBuff then
					buff:SetPoint("RIGHT", previousBuff, "LEFT", -5, 0)
				end
			end
			previousBuff = buff
		end
	end
end

function module:OnBuffButtonUpdateAnchors()
	if PlayerBuffGrowthDirection() == "left_to_right" then
		self:LayoutPlayerBuffsLeftToRight()
	end
end

function module:OnBuffFrameEnchantUpdated()
	if self._playerBuffGrowthDirection ~= "left_to_right" then
		self._playerEnchantGrowthMask = nil
		return
	end
	local mask = (FrameIsShown(TempEnchant1) and 1 or 0) + (FrameIsShown(TempEnchant2) and 2 or 0)
	if self._playerEnchantGrowthMask == mask then return end
	self._playerEnchantGrowthMask = mask
	self:LayoutPlayerBuffsLeftToRight()
	if not self._playerAurasSeparate then
		self:LayoutCombinedPlayerDebuffsLeftToRight()
	end
end

function module:OnDebuffButtonUpdateAnchors(buttonName, index)
	if AddonLoaded("SimpleAuraFilter") then
		return
	end
	if SeparatePlayerAuraPositioning() then
		self:LayoutSeparatePlayerDebuffs()
		return
	end
	if PlayerDebuffGrowthDirection() == "left_to_right" then
		self:LayoutCombinedPlayerDebuffsLeftToRight()
		return
	end
	if not SettingOn("changePlayerBuffRow") or not BuffFrame then
		return
	end
	if not buttonName or not index then
		return
	end

	local numBuffs = (BUFF_ACTUAL_DISPLAY or 0) + (BuffFrame.numEnchants or 0)
	local BUFFS_PER_ROW = GetSetting("playerBuffsPerRow", 8)
	if BUFFS_PER_ROW < 1 then BUFFS_PER_ROW = 1 end
	if BuffFrame.numConsolidated and BuffFrame.numConsolidated > 0 then
		numBuffs = numBuffs - BuffFrame.numConsolidated + 1
	end

	local rows = mceil(numBuffs / BUFFS_PER_ROW)
	local buff = _G[buttonName .. index]
	if not buff then return end
	local rowSpacing = BUFF_ROW_SPACING or 15

	buff:ClearAllPoints()
	if index > 1 and (index % BUFFS_PER_ROW) == 1 then
		buff:SetPoint("TOP", _G[buttonName .. (index - BUFFS_PER_ROW)], "BOTTOM", 0, -rowSpacing)
	elseif index == 1 then
		local offsetY
		if rows < 2 then
			offsetY = (2 * rowSpacing) + 30
		else
			offsetY = rows * (rowSpacing + 30)
		end
		buff:SetPoint("TOPRIGHT", BuffFrame, "BOTTOMRIGHT", 0, -offsetY)
	else
		buff:SetPoint("RIGHT", _G[buttonName .. (index - 1)], "LEFT", -6, 0)
	end
end

function module:OnFrameAuraLayoutUpdated(frame)
	-- TargetFrame_UpdateAuras is also used by protected boss frames.  Keep the
	-- secure hook, but never touch anything except the two frames owned here.
	if CustomFrameAuraLayout() and (frame == TargetFrame or frame == FocusFrame) then
		self:LayoutFrameAuras(frame)
	end
end

function module:UpdateLayoutHooks()
	-- Blizzard clears and rebuilds every aura anchor on each update. Reapply our
	-- layout immediately after that work so the icons cannot jump back below the
	-- target/focus frame while waiting for the throttled UNIT_AURA callback.
	if TargetFrame_UpdateAuras and not self:IsHooked("TargetFrame_UpdateAuras") then
		self:SecureHook("TargetFrame_UpdateAuras", "OnFrameAuraLayoutUpdated")
	end
	if FocusFrame_UpdateAuras and not self:IsHooked("FocusFrame_UpdateAuras") then
		self:SecureHook("FocusFrame_UpdateAuras", "OnFrameAuraLayoutUpdated")
	end

	if AddonLoaded("SimpleAuraFilter") then
		-- other addon owns player buff rows
	else
		if BuffFrame_UpdateAllBuffAnchors and not self:IsHooked("BuffFrame_UpdateAllBuffAnchors") then
			self:SecureHook("BuffFrame_UpdateAllBuffAnchors", "OnBuffFrameUpdateAllBuffAnchors")
		end
		if BuffButton_UpdateAnchors and not self:IsHooked("BuffButton_UpdateAnchors") then
			self:SecureHook("BuffButton_UpdateAnchors", "OnBuffButtonUpdateAnchors")
		end
		if DebuffButton_UpdateAnchors and not self:IsHooked("DebuffButton_UpdateAnchors") then
			self:SecureHook("DebuffButton_UpdateAnchors", "OnDebuffButtonUpdateAnchors")
		end
		if BuffFrame_Enchant_OnUpdate and not self:IsHooked("BuffFrame_Enchant_OnUpdate") then
			self:SecureHook("BuffFrame_Enchant_OnUpdate", "OnBuffFrameEnchantUpdated")
		end
	end
end

function module:RefreshAuraLayout()
	if TargetFrame and TargetFrame_UpdateAuras then
		pcall(TargetFrame_UpdateAuras, TargetFrame)
	end
	if CustomFrameAuraLayout() and TargetFrame then
		self:LayoutFrameAuras(TargetFrame)
	end
	if FocusFrame then
		if FocusFrame_UpdateAuras then
			pcall(FocusFrame_UpdateAuras, FocusFrame)
		elseif TargetFrame_UpdateAuras then
			pcall(TargetFrame_UpdateAuras, FocusFrame)
		end
		if CustomFrameAuraLayout() then
			self:LayoutFrameAuras(FocusFrame)
		end
	end
	if PlayerBuffGrowthDirection() == "right_to_left" then
		RestoreTemporaryEnchantGrowth()
	end
	if BuffFrame_Update then
		pcall(BuffFrame_Update)
	elseif BuffFrame_UpdateAllBuffAnchors then
		pcall(BuffFrame_UpdateAllBuffAnchors)
	end
	if PlayerBuffGrowthDirection() == "left_to_right" then
		self:LayoutPlayerBuffsLeftToRight()
	end
	if SeparatePlayerAuraPositioning() then
		self:LayoutSeparatePlayerDebuffs()
	elseif PlayerDebuffGrowthDirection() == "left_to_right" then
		self:LayoutCombinedPlayerDebuffsLeftToRight()
	end
end

--------------------------------------------------------------------
-- Player buff frame management (ConsolidatedBuffs / BuffFrame)
--------------------------------------------------------------------
local buffFrameBlizzardDefaultPosition = nil
local buffMoverFrame = nil

local function GetPlayerBuffMoverFrame()
	return ConsolidatedBuffs or TemporaryEnchantFrame or BuffFrame
end

local function RefreshPlayerBuffAnchors()
	if BuffFrame_Update then
		pcall(BuffFrame_Update)
	elseif BuffFrame_UpdateAllBuffAnchors then
		pcall(BuffFrame_UpdateAllBuffAnchors)
	end
end

local function SetPlayerBuffGroupScale(scale)
	scale = scale or 1
	if BuffFrame then
		BuffFrame:SetScale(scale)
	end
	if TemporaryEnchantFrame then
		TemporaryEnchantFrame:SetScale(scale)
	end
	if ConsolidatedBuffs then
		ConsolidatedBuffs:SetScale(scale)
	end
end

function module:SaveDefaultBuffPosition()
	local mover = GetPlayerBuffMoverFrame()
	if mover and not buffFrameBlizzardDefaultPosition then
		local point, relativeTo, relativePoint, xOfs, yOfs = mover:GetPoint()
		if point then
			buffFrameBlizzardDefaultPosition = {
				point = point,
				relativeTo = relativeTo and relativeTo.GetName and relativeTo:GetName() or "UIParent",
				relativePoint = relativePoint,
				xOfs = xOfs,
				yOfs = yOfs,
			}
		end
	end

	if mover and SarychUI.DragMode then
		if not SarychUI.DragMode:GetFrameData("buffFrame") then
			buffMoverFrame = mover
			SarychUI.DragMode:RegisterFrame("buffFrame", mover, {
				dragPoint = "TOPRIGHT",
				dragOffsetX = 0,
				dragOffsetY = 2.5,
				dragWidth = 280,
				dragHeight = 225,
				dragText = L and (L["Buffs"] or "Бафы") or "Бафы",
				scaleFrame = BuffFrame,
				interceptSetPoint = true,
				getPoint = function()
					return {
						GetSetting("buffFrameA", "TOPRIGHT"),
						UIParent,
						GetSetting("buffFrameR", "TOPRIGHT"),
						GetSetting("buffFrameX", -205),
						GetSetting("buffFrameY", -13),
					}
				end,
				getScale = function()
					return GetSetting("buffFrameScale", 1.0)
				end,
				onPositionChanged = function(point, relativePoint, xOfs, yOfs)
					local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
					if panel and panel.IsOpen and panel:IsOpen() and panel.OnDragPosition then
						if panel:OnDragPosition("buffFrame", xOfs, yOfs, point, relativePoint) then
							return
						end
					end
					local db = ModuleDB()
					if not db then return end
					db.buffFrameA = point
					db.buffFrameR = relativePoint
					db.buffFrameX = xOfs
					db.buffFrameY = yOfs
					if C_Timer and C_Timer.After then
						C_Timer.After(0.1, function()
							RefreshPlayerBuffAnchors()
							if UpdateBuffAnchors then
								UpdateBuffAnchors()
							end
						end)
					end
				end,
			})
		end
	end

	local debuffAnchor = EnsurePlayerDebuffAnchor()
	if debuffAnchor and SarychUI.DragMode and not SarychUI.DragMode:GetFrameData("debuffFrame") then
		SarychUI.DragMode:RegisterFrame("debuffFrame", debuffAnchor, {
			dragPoint = "TOPRIGHT",
			dragOffsetX = 0,
			dragOffsetY = 2.5,
			dragWidth = 280,
			dragHeight = 100,
			dragText = "Дебафы",
			getPoint = function()
				return {
					GetSetting("debuffFrameA", "TOPRIGHT"),
					UIParent,
					GetSetting("debuffFrameR", "TOPRIGHT"),
					GetSetting("debuffFrameX", -205),
					GetSetting("debuffFrameY", -105),
				}
			end,
			getScale = function()
				return GetSetting("debuffFrameScale", 1.0)
			end,
			onPositionChanged = function(point, relativePoint, xOfs, yOfs)
				local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
				if panel and panel.IsOpen and panel:IsOpen() and panel.OnDragPosition then
					if panel:OnDragPosition("debuffFrame", xOfs, yOfs, point, relativePoint) then
						return
					end
				end
				local db = ModuleDB()
				if not db then return end
				db.debuffFrameA = point
				db.debuffFrameR = relativePoint
				db.debuffFrameX = xOfs
				db.debuffFrameY = yOfs
			end,
		})
	end
end

function module:ApplyBuffManagement()
	local db = ModuleDB()
	if not db or not db.enabled then return end
	if not SarychUI.DragMode then return end
	if not GetPlayerBuffMoverFrame() or not BuffFrame then return end

	if not SarychUI.DragMode:GetFrameData("buffFrame") then
		self:SaveDefaultBuffPosition()
	end
	if not SarychUI.DragMode:GetFrameData("debuffFrame") then
		self:SaveDefaultBuffPosition()
	end

	local manageBuffs = GetSetting("manageBuffs", 0) == 1
	local separate = manageBuffs and GetSetting("playerAuraPositionMode", "together") == "separate"
	local showDragFrame = GetSetting("showBuffDragFrame", 0) == 1
	local showGrid = GetSetting("showBuffGrid", 0) == 1
	local showDebuffDragFrame = separate and GetSetting("showDebuffDragFrame", 0) == 1
	local showDebuffGrid = separate and GetSetting("showDebuffGrid", 0) == 1

	SarychUI.DragMode:EnableEditMode("buffFrame", manageBuffs, showDragFrame, showGrid)

	if manageBuffs then
		SarychUI.DragMode:SetFramePosition("buffFrame",
			GetSetting("buffFrameA", "TOPRIGHT"),
			GetSetting("buffFrameR", "TOPRIGHT"),
			GetSetting("buffFrameX", -205),
			GetSetting("buffFrameY", -13))
		SarychUI.DragMode:SetFrameScale("buffFrame", GetSetting("buffFrameScale", 1.0))
		SetPlayerBuffGroupScale(GetSetting("buffFrameScale", 1.0))
	else
		SetPlayerBuffGroupScale(1.0)
	end

	if separate then
		SarychUI.DragMode:EnableEditMode("debuffFrame", true, showDebuffDragFrame, showDebuffGrid)
		SarychUI.DragMode:SetFramePosition("debuffFrame",
			GetSetting("debuffFrameA", "TOPRIGHT"),
			GetSetting("debuffFrameR", "TOPRIGHT"),
			GetSetting("debuffFrameX", -205),
			GetSetting("debuffFrameY", -105))
		SarychUI.DragMode:SetFrameScale("debuffFrame", GetSetting("debuffFrameScale", 1.0))
		self:LayoutSeparatePlayerDebuffs()
	else
		SarychUI.DragMode:EnableEditMode("debuffFrame", false, false, false)
		if playerDebuffAnchor then
			playerDebuffAnchor:SetScale(1.0)
		end
		self:RestoreCombinedPlayerDebuffs(true)
	end

	local buffGrowth = PlayerBuffGrowthDirection()
	local debuffGrowth = PlayerDebuffGrowthDirection()
	local growthChanged = self._playerBuffGrowthDirection ~= buffGrowth
		or self._playerDebuffGrowthDirection ~= debuffGrowth
	self._playerBuffGrowthDirection = buffGrowth
	self._playerDebuffGrowthDirection = debuffGrowth
	self._playerAurasSeparate = separate

	if buffGrowth == "right_to_left" then
		RestoreTemporaryEnchantGrowth()
	end
	if growthChanged then
		RefreshPlayerBuffAnchors()
	end
	if buffGrowth == "left_to_right" then
		self:LayoutPlayerBuffsLeftToRight()
	end
	if separate then
		self:LayoutSeparatePlayerDebuffs()
	elseif debuffGrowth == "left_to_right" then
		self:LayoutCombinedPlayerDebuffsLeftToRight()
	end

	SarychUI.DragMode:ShowGrid((showGrid and manageBuffs) or (showDebuffGrid and separate))
end

function module:ResetBuffManagement()
	local mover = buffMoverFrame or GetPlayerBuffMoverFrame()
	if not mover then return end

	if SarychUI.DragMode then
		local data = SarychUI.DragMode:GetFrameData("buffFrame")
		if data and data.originalSetPoint then
			mover.SetPoint = data.originalSetPoint
		end
		SarychUI.DragMode:EnableEditMode("buffFrame", false, false, false)
		SarychUI.DragMode:EnableEditMode("debuffFrame", false, false, false)
		SarychUI.DragMode:ShowGrid(false)
	end

	pcall(function()
		if mover:IsMovable() then
			mover:SetMovable(false)
		end
	end)
	pcall(function()
		if mover:IsUserPlaced() then
			mover:SetUserPlaced(false)
		end
	end)
	pcall(function()
		mover:SetDontSavePosition(false)
	end)

	mover:ClearAllPoints()
	if buffFrameBlizzardDefaultPosition then
		local relativeTo = _G[buffFrameBlizzardDefaultPosition.relativeTo] or UIParent
		pcall(function()
			mover:SetPoint(
				buffFrameBlizzardDefaultPosition.point,
				relativeTo,
				buffFrameBlizzardDefaultPosition.relativePoint,
				buffFrameBlizzardDefaultPosition.xOfs,
				buffFrameBlizzardDefaultPosition.yOfs
			)
		end)
	else
		pcall(function()
			mover:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -205, -13)
		end)
	end

	SetPlayerBuffGroupScale(1.0)
	RestoreTemporaryEnchantGrowth()
	self._playerBuffGrowthDirection = nil
	self._playerDebuffGrowthDirection = nil
	self._playerAurasSeparate = nil
	self._playerEnchantGrowthMask = nil
	if playerDebuffAnchor then
		playerDebuffAnchor:SetScale(1.0)
	end
	self:RestoreCombinedPlayerDebuffs(true)
	RefreshPlayerBuffAnchors()
end

function module:ResetBuffManagementToDefaults()
	local db = ModuleDB()
	if not db then return end
	db.playerAuraPositionMode = "together"
	db.playerAuraGrowthDirection = "right_to_left"
	db.playerBuffGrowthDirection = "right_to_left"
	db.playerDebuffGrowthDirection = "right_to_left"
	db.buffFrameA = "TOPRIGHT"
	db.buffFrameR = "TOPRIGHT"
	db.buffFrameX = -205
	db.buffFrameY = -13
	db.buffFrameScale = 1.0
	db.debuffFrameA = "TOPRIGHT"
	db.debuffFrameR = "TOPRIGHT"
	db.debuffFrameX = -205
	db.debuffFrameY = -105
	db.debuffFrameScale = 1.0
	db.showBuffDragFrame = 0
	db.showBuffGrid = 0
	db.showDebuffDragFrame = 0
	db.showDebuffGrid = 0

	if SarychUI.DragMode then
		SarychUI.DragMode:SetFramePosition("buffFrame", "TOPRIGHT", "TOPRIGHT", -205, -13)
		SarychUI.DragMode:SetFrameScale("buffFrame", 1.0)
		SarychUI.DragMode:SetFramePosition("debuffFrame", "TOPRIGHT", "TOPRIGHT", -205, -105)
		SarychUI.DragMode:SetFrameScale("debuffFrame", 1.0)
	end
	self:ApplyBuffManagement()
end

--------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------
function module:Initialize()
end

function module:Enable()
	self.db = ModuleDB()
	if not self.db or not self.db.enabled then return end

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnEvent")
	self:RegisterEvent("UNIT_INVENTORY_CHANGED", "OnEvent")
	if self.auraUpdateBucket then
		self:UnregisterBucket(self.auraUpdateBucket)
	end
	self.auraUpdateBucket = self:RegisterBucketEvent("UNIT_AURA", 0.2, "OnAuraUpdate")

	if SarychUI.DragMode and GetPlayerBuffMoverFrame() then
		self:SaveDefaultBuffPosition()
	end

	self:UpdateLayoutHooks()
	self:ApplyBuffManagement()
	self:RefreshAuraLayout()
	self:ForceUpdateAuras()
	if self.ApplyPoisonIcons then
		self:ApplyPoisonIcons()
	end

	local toolsModule = SarychUI:GetModule("tools", true)
	if toolsModule and toolsModule.ApplyDispelHighlight then
		toolsModule:ApplyDispelHighlight()
	end
end

function module:Disable()
	self:UnregisterAllEvents()
	if self.auraUpdateBucket then
		self:UnregisterBucket(self.auraUpdateBucket)
		self.auraUpdateBucket = nil
	end
	if self.UnhookAll then
		self:UnhookAll()
	end
	self:RestoreAuras()
	self:ResetBuffManagement()
	if self.ResetPoisonIcons then
		self:ResetPoisonIcons()
	end
	if TargetFrame_UpdateAuras and TargetFrame then
		pcall(TargetFrame_UpdateAuras, TargetFrame)
	end
	if FocusFrame then
		if FocusFrame_UpdateAuras then
			pcall(FocusFrame_UpdateAuras, FocusFrame)
		elseif TargetFrame_UpdateAuras then
			pcall(TargetFrame_UpdateAuras, FocusFrame)
		end
	end
	if BuffFrame_Update then
		pcall(BuffFrame_Update)
	elseif BuffFrame_UpdateAllBuffAnchors then
		pcall(BuffFrame_UpdateAllBuffAnchors)
	end

	local toolsModule = SarychUI:GetModule("tools", true)
	if toolsModule and toolsModule.DisableDispelHighlight then
		toolsModule:DisableDispelHighlight()
	end
end

function module:RefreshConfig()
	if SarychUI.InvalidateModuleProfileCaches then
		SarychUI:InvalidateModuleProfileCaches()
	end
	self:Disable()
	self:Enable()
end

function module:ApplySettings()
	local db = ModuleDB()
	if db and db.enabled then
		self:UpdateLayoutHooks()
		self:ApplyBuffManagement()
		self:RefreshAuraLayout()
		self:ForceUpdateAuras()
		if self.ApplyPoisonIcons then
			self:ApplyPoisonIcons()
		end
		local toolsModule = SarychUI:GetModule("tools", true)
		if toolsModule and toolsModule.ApplyDispelHighlight then
			toolsModule:ApplyDispelHighlight()
		end
	end
end

function module:OnEvent(event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		self:SaveDefaultBuffPosition()
		self:UpdateLayoutHooks()
		self:ApplyBuffManagement()
		self:RefreshAuraLayout()
		self:ForceUpdateAuras()
		if self.ApplyPoisonIcons then
			self:ApplyPoisonIcons()
		end
	elseif event == "PLAYER_FOCUS_CHANGED" then
		self:UpdateFocusAuras()
		if CustomFrameAuraLayout() and FocusFrame then
			self:LayoutFrameAuras(FocusFrame)
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		if CustomFrameAuraLayout() and TargetFrame then
			self:LayoutFrameAuras(TargetFrame)
		end
		self:UpdateTargetAuras()
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		if self.ApplyPoisonIcons then
			self:ApplyPoisonIcons()
		end
	elseif event == "UNIT_INVENTORY_CHANGED" then
		local unit = ...
		if unit == "player" and self.ApplyPoisonIcons then
			self:ApplyPoisonIcons()
		end
	end
end

function module:OnAuraUpdate(units)
	if not units then return end
	for unit in pairs(units) do
		if unit == "focus" then
			self:UpdateFocusAuras()
			if CustomFrameAuraLayout() and FocusFrame then
				self:LayoutFrameAuras(FocusFrame)
			end
		elseif unit == "target" then
			if CustomFrameAuraLayout() and TargetFrame then
				self:LayoutFrameAuras(TargetFrame)
			end
			self:UpdateTargetAuras()
		end
	end
end
