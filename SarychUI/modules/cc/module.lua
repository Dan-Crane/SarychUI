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

-- Per-frame update
local function cooldown_OnUpdate(frame, elapsed)
    local state = ccState[frame]
    local textObj = state and state.text
	-- Проверяем, включен ли модуль
	if not isEnabledFlag then
		if textObj then textObj:Hide() end
        if state and state.host then state.host:Hide() end
		return
	end

    if not textObj or not textObj:IsShown() then return end

    state.nextUpdate = (state.nextUpdate or 0) - elapsed
    if state.nextUpdate > 0 then return end

    if not PartyAbilityExempt(frame) then
        local minIconSize = getSetting("minIconSize", 23)
        if frame:GetWidth() < minIconSize or frame:GetHeight() < minIconSize then
            textObj:SetText("")
            textObj:Hide()
            return
        end

        local minScale = getSetting("minScale", 0.5)
        if (frame:GetEffectiveScale() / UIParent:GetEffectiveScale()) < minScale then
            textObj:SetText("")
            state.nextUpdate = 1
            return
        end
    end

    local start = state.start or 0
    local duration = state.duration or 0
    local remain = duration - ((GetTime and GetTime() or 0) - start)
    if floor(remain + 0.5) <= 0 then
        textObj:Hide()
        if state.host then state.host:Hide() end
        return
    end

    local displayText, color, interval, fontSize = formatCooldownText(remain)

    local fontPath = ResolveFontPath(getSetting("font", "Friz Quadrata TT"))
    local fontFlags = getSetting("fontFlags", "OUTLINE")
    local scale = min((frame:GetParent() and frame:GetParent():GetWidth() or 36) / 36, 1)
    local adjustedSize = max(fontSize * scale, 1)
    textObj:SetFont(fontPath, adjustedSize, fontFlags)
    textObj:SetText(displayText)
    textObj:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    textObj:SetWidth(50)
    textObj:SetJustifyH("CENTER")

    state.nextUpdate = interval
end

local function ensureText(frame)
    local state = State(frame)
    if state.text then return state.text end
    if frame.__sary_cc_noCount or state.noCount then return nil end

    local minScale = getSetting("minScale", 0.5)
    local parent = frame:GetParent()
    local pWidth = parent and parent:GetWidth() or 36
    local scale = min(pWidth / 36, 1)
    if not PartyAbilityExempt(frame) and scale < minScale then
        state.noCount = true
        return nil
    end
    state.noCount = nil

    local host = CreateFrame("Frame", nil, UIParent)
    host:SetAllPoints(frame)
    host:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
    host:SetFrameLevel((frame:GetFrameLevel() or 0) + 5)
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
local function handleSetCooldown(frame, start, duration)
	if not isEnabledFlag then return end
	if not frame then return end

	local minDuration = getSetting("minDuration", 3)
    local state = State(frame)
    if PartyAbilityExempt(frame) then
        state.noCount = nil
    end
    if frame.__sary_cc_noCount then
        state.noCount = true
    end
    if start and start > 0 and duration and duration > minDuration then
        state.start = start
        state.duration = duration
        state.nextUpdate = 0
        if not state.noCount and not frame.__sary_cc_noCount then
            local text = state.text or ensureText(frame)
            if text then
                if state.host then
                    state.host:SetAllPoints(frame)
                    state.host:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
                    state.host:SetFrameLevel((frame:GetFrameLevel() or 0) + 5)
                    state.host:Show()
                end
                text:Show()
            end
        end
    else
        if state.text then state.text:Hide() end
        if state.host then state.host:Hide() end
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

local function PollBars()
    if not isEnabledFlag then return end
    for p = 1, #BAR_PREFIXES do
        local prefix = BAR_PREFIXES[p]
        for i = 1, 12 do
            local button = _G[prefix .. i]
            local cooldown = _G[prefix .. i .. "Cooldown"]
            if button and cooldown and button.action and button.action > 0 and GetActionCooldown then
                local start, duration = GetActionCooldown(button.action)
                handleSetCooldown(cooldown, start, duration)
            end
        end
    end
    for i = 1, 10 do
        local petCooldown = _G["PetActionButton" .. i .. "Cooldown"]
        if petCooldown and GetPetActionCooldown then
            local start, duration = GetPetActionCooldown(i)
            handleSetCooldown(petCooldown, start, duration)
        end
        local formCooldown = _G["ShapeshiftButton" .. i .. "Cooldown"]
        if formCooldown and GetShapeshiftFormCooldown then
            local start, duration = GetShapeshiftFormCooldown(i)
            handleSetCooldown(formCooldown, start, duration)
        end
    end
end

local driver = CreateFrame("Frame")
driver:Hide()
local pollAcc = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    pollAcc = pollAcc + elapsed
    if pollAcc >= 0.1 then
        pollAcc = 0
        PollBars()
    end
    for frame, state in pairs(ccState) do
        -- The countdown sits on its own frame. Hide it with the source icon,
        -- including options previews whose parent window just closed.
        if not frame:IsVisible() then
            if state.text then state.text:Hide() end
            if state.host and state.host:IsShown() then state.host:Hide() end
        elseif state.text and state.text:IsShown() then
            cooldown_OnUpdate(frame, elapsed)
        elseif state.start and state.duration and state.duration > 0
            and not state.noCount and not frame.__sary_cc_noCount then
            local remain = state.duration - ((GetTime and GetTime() or 0) - state.start)
            if remain > 0 then
                handleSetCooldown(frame, state.start, state.duration)
            end
        end
    end
end)

-- Blizzard calls CooldownFrame_SetTimer from PetActionBar_UpdateCooldowns and
-- ShapeshiftBar_UpdateState, before the protected button Show/Hide. A
-- hooksecurefunc there taints the rest of that update. Bar numbers are polled
-- from this frame. Our own frames call SarychUI_NotifyCooldown.
function SarychUI_NotifyCooldown(frame, start, duration, enable)
    if enable == 0 then
        handleSetCooldown(frame, 0, 0)
    else
        handleSetCooldown(frame, start, duration)
    end
end

local function installHooks()
    if hooksInstalled then return end
    hooksInstalled = true
    driver:Show()
end

function module:ApplySettings()
    isEnabledFlag = DB() and DB().enabled ~= false
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
        if state.text then state.text:Hide() end
        if state.host then state.host:Hide() end
    end

    -- Invite / arena countdown follow cc enable state.
    local tools = SarychUI and SarychUI.modules and SarychUI.modules.tools
    if tools then
        if tools.DisableInviteCountdown then tools:DisableInviteCountdown() end
        if tools.DisableArenaCountdown then tools:DisableArenaCountdown() end
    end
end


