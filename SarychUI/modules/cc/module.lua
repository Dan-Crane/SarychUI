-- SarychUI Crowd Control (Cooldown Text) Module
local format = string.format
local floor = math.floor
local min, max = math.min, math.max

local moduleName = "cc"
local module = {}

-- Register module
SarychUI:RegisterModule(moduleName, module)

-- Cached DB accessor
local function DB()
    return SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
end

-- Internal state
local isEnabledFlag = true
local hooksInstalled = false

-- Locale-dependent suffixes
local locale = GetLocale and GetLocale() or "enUS"
local daySuffix = (locale == "ruRU") and " д." or "d"
local hourSuffix = (locale == "ruRU") and " ч." or "h"
local minuteSuffix = (locale == "ruRU") and " м." or "m"

-- Helpers to access settings with sane fallbacks
local function getSetting(key, default)
    local db = DB()
    if db and db[key] ~= nil then return db[key] end
    return default
end

local function PartyAbilityExempt(frame)
    return frame and frame.__sary_partyAbility and getSetting("partyAbilitiesExempt", true)
end

local function ResolveFontPath(fontNameOrPath)
    if type(fontNameOrPath) == "string" and fontNameOrPath:find("\\") then
        return fontNameOrPath
    end
    if SarychUI and SarychUI.Media and SarychUI.Media.GetFont then
        local path = SarychUI.Media.GetFont(fontNameOrPath or "Friz Quadrata TT")
        if path and path ~= "" then return path end
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and fontNameOrPath then
        local path = LSM:Fetch("font", fontNameOrPath, true)
        if path and path ~= "" then return path end
    end
    return "Fonts\\FRIZQT__.TTF"
end

-- Time formatting based on remaining seconds and settings
local function formatCooldownText(seconds)
    local defaultColor = getSetting("defaultColor", {1, 1, 1, 1})
    local fontSizeSmall = getSetting("fontSizeSmall", 14)
    local fontSizeMedium = getSetting("fontSizeMedium", 12)
    local fontSizeLarge = getSetting("fontSizeLarge", 12)

    if seconds >= 86400 then
        return format(" %d%s ", floor(seconds / 86400 + 0.5), daySuffix), defaultColor, 3600, fontSizeLarge
    elseif seconds >= 3600 then
        return format(" %d%s ", floor(seconds / 3600 + 0.5), hourSuffix), defaultColor, 60, fontSizeLarge
    elseif seconds >= 600 then
        return format(" %d%s ", floor(seconds / 60 + 0.5), minuteSuffix), defaultColor, 10, fontSizeLarge
    elseif seconds >= 60 then
        return format(" %d:%02d ", floor(seconds / 60), floor(seconds % 60)), defaultColor, 1, fontSizeMedium
    elseif seconds >= 10 then
        return format(" %02d ", floor(seconds + 0.5)), defaultColor, 0.1, fontSizeSmall
    else
        return format(" %d ", floor(seconds + 0.5)), defaultColor, 0.1, fontSizeSmall
    end
end

-- State stays off the cooldown widget. Writing fields, children or scripts onto
-- a Blizzard cooldown taints the parent action button, and combat Show/Hide is
-- then blocked as SarychUI.
local ccState = setmetatable({}, { __mode = "k" })

local function State(frame)
    local state = ccState[frame]
    if not state then
        state = {}
        ccState[frame] = state
    end
    return state
end

local function HideCountdown(state)
    if state.text then state.text:Hide() end
    if state.host then state.host:Hide() end
end

local function ClearCountdown(state)
    state.start = nil
    state.duration = nil
    state.nextUpdate = nil
    HideCountdown(state)
end

local ensureText

-- Per-frame update
local function cooldown_OnUpdate(frame, elapsed)
    local state = ccState[frame]
    local textObj = state and state.text
    if not state or not state.start then return end
    local remain = state.start + state.duration - GetTime()
    if remain <= 0.5 then
        ClearCountdown(state)
        return
    end
    local owner = frame:GetParent()
    if not isEnabledFlag or not (owner and owner:IsVisible()) then
        HideCountdown(state)
        state.nextUpdate = 0
        return
    end

    state.nextUpdate = (state.nextUpdate or 0) - elapsed
    if state.nextUpdate > 0 then return end

    if state.duration <= getSetting("minDuration", 3) or frame.__sary_cc_noCount then
        HideCountdown(state)
        state.nextUpdate = 0
        return
    end

    if not PartyAbilityExempt(frame) then
        local minIconSize = getSetting("minIconSize", 23)
        if frame:GetWidth() < minIconSize or frame:GetHeight() < minIconSize then
            HideCountdown(state)
            state.nextUpdate = 0
            return
        end

        local minScale = getSetting("minScale", 0.5)
        if (frame:GetEffectiveScale() / UIParent:GetEffectiveScale()) < minScale then
            HideCountdown(state)
            state.nextUpdate = 0
            return
        end
    end

    textObj = textObj or ensureText(frame)
    if not textObj then
        state.nextUpdate = 0
        return
    end

    local displayText, color, interval, fontSize = formatCooldownText(remain)

    local fontPath = ResolveFontPath(getSetting("font", "Friz Quadrata TT"))
    local fontFlags = getSetting("fontFlags", "OUTLINE")
    local scale = min((frame:GetParent() and frame:GetParent():GetWidth() or 36) / 36, 1)
    local adjustedSize = max(fontSize * scale, 1)
    if state.fontPath ~= fontPath or state.fontSize ~= adjustedSize or state.fontFlags ~= fontFlags then
        textObj:SetFont(fontPath, adjustedSize, fontFlags)
        state.fontPath, state.fontSize, state.fontFlags = fontPath, adjustedSize, fontFlags
    end
    if state.displayText ~= displayText then
        textObj:SetText(displayText)
        state.displayText = displayText
    end
    local alpha = color[4] or 1
    if state.colorR ~= color[1] or state.colorG ~= color[2] or state.colorB ~= color[3] or state.colorA ~= alpha then
        textObj:SetTextColor(color[1], color[2], color[3], alpha)
        state.colorR, state.colorG, state.colorB, state.colorA = color[1], color[2], color[3], alpha
    end
    local strata = frame:GetFrameStrata() or "MEDIUM"
    if strata == "BACKGROUND" or strata == "LOW" or strata == "MEDIUM" then
        strata = "HIGH"
    end
    local level = (frame:GetFrameLevel() or 0) + 5
    if state.action then
        -- Action effects may use HIGH levels above 100 during another cast.
        -- Keep the countdown above those effects and below tooltips.
        strata, level = "DIALOG", 1
    end
    if state.strata ~= strata then
        state.host:SetFrameStrata(strata)
        state.strata = strata
    end
    if state.level ~= level then
        state.host:SetFrameLevel(level)
        state.level = level
    end
    -- The text is a UIParent child, so button fades must never affect it.
    if state.host:GetAlpha() ~= 1 then state.host:SetAlpha(1) end
    if textObj:GetAlpha() ~= 1 then textObj:SetAlpha(1) end
    state.host:Show()
    textObj:Show()

    state.nextUpdate = interval
end

ensureText = function(frame)
    local state = State(frame)
    if state.text then return state.text end
    if frame.__sary_cc_noCount then return nil end

    local parent = frame:GetParent()
    local pWidth = parent and parent:GetWidth() or 36
    local scale = min(pWidth / 36, 1)

    local host = CreateFrame("Frame", nil, UIParent)
    host:SetAllPoints(frame)
    host:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
    host:SetFrameLevel((frame:GetFrameLevel() or 0) + 5)
    host:SetAlpha(1)
    host:EnableMouse(false)
    state.host = host

    local text = host:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", host, "CENTER", 0, 1)

    local fontPath = ResolveFontPath(getSetting("font", "Friz Quadrata TT"))
    local fontFlags = getSetting("fontFlags", "OUTLINE")
    local fontSizeLarge = getSetting("fontSizeLarge", 12)
    local adjustedSize = max(fontSizeLarge * scale, 1)
    text:SetFont(fontPath, adjustedSize, fontFlags)

    local color = getSetting("defaultColor", {1, 1, 1, 1})
    text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    text:SetWidth(50)
    text:SetJustifyH("CENTER")

    state.text = text
    return text
end

-- Central SetCooldown bridge
local function handleSetCooldown(frame, start, duration, enable)
	if not frame then return end
    local state = State(frame)
    if not isEnabledFlag or enable == 0 or type(start) ~= "number" or type(duration) ~= "number"
        or start <= 0 or duration <= 0 or start + duration <= GetTime() + 0.5 then
        ClearCountdown(state)
        return
    end
    if state.start ~= start or state.duration ~= duration then
        state.start = start
        state.duration = duration
        state.nextUpdate = 0
    end
end

local BAR_PREFIXES = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarLeftButton",
    "MultiBarRightButton",
    "BonusActionButton",
}

local INVENTORY_SLOT_NAMES = {
    "AmmoSlot", "HeadSlot", "NeckSlot", "ShoulderSlot", "ShirtSlot",
    "ChestSlot", "WaistSlot", "LegsSlot", "FeetSlot", "WristSlot",
    "HandsSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot",
    "Trinket1Slot", "BackSlot", "MainHandSlot", "SecondaryHandSlot",
    "RangedSlot", "TabardSlot",
}
local inventorySlotIDs = {}
local function CaptureActionButton(button, cooldown)
    if not cooldown then return end
    local state = State(cooldown)
    local action = button and button.action
    if state.action ~= action then
        ClearCountdown(state)
        state.action = action
    end
    if button and button.action and button.action > 0 and GetActionCooldown then
        local start, duration, enable = GetActionCooldown(button.action)
        local currentEnd = state.start and state.duration and (state.start + state.duration)
        if currentEnd and currentEnd > GetTime() + 0.5 then
            local incomingEnd = type(start) == "number" and type(duration) == "number" and (start + duration)
            if not incomingEnd or enable == 0 or start <= 0 or duration <= 0
                or incomingEnd <= GetTime() + 0.5
                or (duration <= 2 and state.duration > 2 and incomingEnd < currentEnd - 0.5) then
                -- An action update can briefly report no cooldown or just the GCD.
                return
            end
        end
        handleSetCooldown(cooldown, start, duration, enable)
    else
        handleSetCooldown(cooldown, 0, 0)
    end
end

local function CaptureCooldownSources()
    if not isEnabledFlag then return end
    for p = 1, #BAR_PREFIXES do
        local prefix = BAR_PREFIXES[p]
        for i = 1, 12 do
            local button = _G[prefix .. i]
            local cooldown = _G[prefix .. i .. "Cooldown"]
            CaptureActionButton(button, cooldown)
        end
    end
    for i = 1, 120 do
        local button = _G["SarychUIActionButton" .. i]
        if button then
            CaptureActionButton(button, button.cooldown or button.Cooldown
                or _G["SarychUIActionButton" .. i .. "Cooldown"])
        end
    end
    local bars = SarychUI and SarychUI.FrostAtomBars
    if bars and bars.IsActive and bars.IsActive() and bars.ForEachStyledButton then
        bars.ForEachStyledButton(function(button)
            if button then
                local name = button.GetName and button:GetName()
                CaptureActionButton(button, button.cooldown or button.Cooldown
                    or (name and _G[name .. "Cooldown"]))
            end
        end)
    end
    for i = 1, 10 do
        local petCooldown = _G["PetActionButton" .. i .. "Cooldown"]
        if petCooldown and GetPetActionCooldown then
            local start, duration, enable = GetPetActionCooldown(i)
            handleSetCooldown(petCooldown, start, duration, enable)
        end
        local formCooldown = _G["ShapeshiftButton" .. i .. "Cooldown"]
        if formCooldown and GetShapeshiftFormCooldown then
            local start, duration, enable = GetShapeshiftFormCooldown(i)
            handleSetCooldown(formCooldown, start, duration, enable)
        end
    end
    if GetInventoryItemCooldown and GetInventorySlotInfo then
        for i = 1, #INVENTORY_SLOT_NAMES do
            local name = INVENTORY_SLOT_NAMES[i]
            local button = _G["Character" .. name]
            local cooldown = button and (_G["Character" .. name .. "Cooldown"] or button.Cooldown)
            if cooldown then
                local slotID = inventorySlotIDs[name]
                if not slotID then
                    slotID = GetInventorySlotInfo(name)
                    inventorySlotIDs[name] = slotID
                end
                if slotID then
                    local start, duration, enable = GetInventoryItemCooldown("player", slotID)
                    handleSetCooldown(cooldown, start, duration, enable)
                end
            end
        end
    end
end

-- Blizzard updates these cooldowns through CooldownFrame_SetTimer. Read the
-- aura data after its frame update without hooking that shared timer function.
local function CaptureFrameAuras(frame)
    if not isEnabledFlag or (frame ~= TargetFrame and frame ~= FocusFrame) then return end
    local unit = frame.unit
    local frameName = frame:GetName()
    if not unit or not frameName then return end

    local function Capture(kind, count, getter)
        for i = 1, count do
            local button = _G[frameName .. kind .. i]
            local cooldown = _G[frameName .. kind .. i .. "Cooldown"]
            if cooldown then
                if button and button:IsShown() then
                    local _, _, icon, _, _, duration, expirationTime = getter(unit, i)
                    if icon and duration and duration > 0 and expirationTime then
                        handleSetCooldown(cooldown, expirationTime - duration, duration, 1)
                    else
                        handleSetCooldown(cooldown, 0, 0)
                    end
                else
                    handleSetCooldown(cooldown, 0, 0)
                end
            end
        end
    end

    Capture("Buff", MAX_TARGET_BUFFS or 32, UnitBuff)
    Capture("Debuff", MAX_TARGET_DEBUFFS or 16, UnitDebuff)
end

local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnEvent", function(self)
    self.refreshPending = true
end)
driver:SetScript("OnUpdate", function(_, elapsed)
    if driver.refreshPending then
        driver.refreshPending = nil
        CaptureCooldownSources()
    end
    for frame, state in pairs(ccState) do
        if state.start then
            cooldown_OnUpdate(frame, elapsed)
        elseif state.host and state.host:IsShown() then
            HideCountdown(state)
        end
    end
end)

-- Blizzard calls CooldownFrame_SetTimer before protected button updates. Hooking
-- that shared function can taint Show/Hide, so bar values are read on events.
-- Our own frames call SarychUI_NotifyCooldown directly.
function SarychUI_NotifyCooldown(frame, start, duration, enable)
    handleSetCooldown(frame, start, duration, enable)
end

-- Transient cooldown owners can drop their widget without leaving an anchored
-- text host behind for every proc.
function SarychUI_ReleaseCooldown(frame)
    local state = frame and ccState[frame]
    if not state then return end
    ClearCountdown(state)
    if state.host then state.host:ClearAllPoints() end
    ccState[frame] = nil
end

local function installHooks()
    if hooksInstalled then return end
    hooksInstalled = true
    for _, event in ipairs({
        "ACTIONBAR_UPDATE_COOLDOWN", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
        "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_COOLDOWN",
        "PET_BAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN",
        "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD",
    }) do
        driver:RegisterEvent(event)
    end
    if TargetFrame_UpdateAuras then
        hooksecurefunc("TargetFrame_UpdateAuras", CaptureFrameAuras)
    end
    if FocusFrame_UpdateAuras then
        hooksecurefunc("FocusFrame_UpdateAuras", CaptureFrameAuras)
    end
    driver:Show()
end

function module:ApplySettings()
    isEnabledFlag = DB() and DB().enabled ~= false
    if hooksInstalled then
        if isEnabledFlag then
            driver.refreshPending = true
            driver:Show()
        else
            driver:Hide()
        end
    end
    for _, state in pairs(ccState) do
        state.nextUpdate = 0
        if not isEnabledFlag then ClearCountdown(state) end
    end
    -- Invite / arena countdown UI lives here; runtime stays in tools.
    local tools = SarychUI and SarychUI.modules and SarychUI.modules.tools
    if tools then
        if tools.ApplyInviteCountdown then tools:ApplyInviteCountdown() end
        if tools.ApplyArenaCountdown then tools:ApplyArenaCountdown() end
    end
end

function module:Enable()
    isEnabledFlag = true
    installHooks()
    driver:Show()
    self:ApplySettings()
end

function module:Disable()
    isEnabledFlag = false
    driver:Hide()
    for _, state in pairs(ccState) do
        ClearCountdown(state)
    end

    -- Invite / arena countdown follow cc enable state.
    local tools = SarychUI and SarychUI.modules and SarychUI.modules.tools
    if tools then
        if tools.DisableInviteCountdown then tools:DisableInviteCountdown() end
        if tools.DisableArenaCountdown then tools:DisableArenaCountdown() end
    end
end


