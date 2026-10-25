-- SarychUI controls the embedded Purgeatory lifecycle.
local ADDON_NAME = "Purgeatory"

local wrapper = {
    name = ADDON_NAME,
    author = "Mayen",
    version = "3",
    enabled = false,
    loaded = false,
}

local function GetConfig()
    local profile = SarychUI and SarychUI.db and SarychUI.db.profile
    return profile and profile.addons and profile.addons[ADDON_NAME]
end

local function IsStandaloneEnabled()
    return SarychUI_IsStandalonePurgeatoryEnabled and SarychUI_IsStandalonePurgeatoryEnabled()
end

function wrapper:IsRuntimeEnabled()
    return self.enabled and _G.Purgeatory and _G.Purgeatory.enabled or false
end

function wrapper:SetRuntimeEnabled(enable)
    if enable and IsStandaloneEnabled() then
        if SarychUI and SarychUI.Print then
            SarychUI:Print("|cffff0000Purgeatory:|r отключите отдельную версию аддона перед включением встроенной.")
        end
        return false
    end
    if enable then
        return SarychUI:EnableAddOn(ADDON_NAME)
    end
    return SarychUI:DisableAddOn(ADDON_NAME)
end

function wrapper:Initialize()
    self.loaded = SarychUI_PurgeatoryEmbeddedAvailable and _G.Purgeatory ~= nil
    self.enabled = false
    if self.loaded then
        _G.Purgeatory:OnInitialize()
    end
end

function wrapper:Enable()
    if IsStandaloneEnabled() or not SarychUI_PurgeatoryEmbeddedAvailable or not _G.Purgeatory then
        self.enabled = false
        local config = GetConfig()
        if config then config.enabled = false end
        return false
    end
    _G.Purgeatory:Enable()
    self.enabled = _G.Purgeatory.enabled and true or false
    self.loaded = true
    return self.enabled
end

function wrapper:Disable()
    self.enabled = false
    if SarychUI_PurgeatoryEmbeddedAvailable and _G.Purgeatory then
        _G.Purgeatory:Disable()
        local dialog = LibStub and LibStub("AceConfigDialog-3.0", true)
        if dialog then dialog:Close("Purgeatory") end
    end
    return true
end

function wrapper:OpenConfig()
    if not self:IsRuntimeEnabled() then return false end
    return _G.Purgeatory:OpenConfig()
end

function wrapper:GetOptions()
    return {
        type = "group",
        name = "Purgeatory",
        args = {
            enabled = {
                type = "toggle",
                name = "Включить",
                desc = "Включить или выключить оповещения о прерываниях и рассеиваниях.",
                order = 1,
                get = function() return wrapper:IsRuntimeEnabled() end,
                set = function(_, value) wrapper:SetRuntimeEnabled(value) end,
                disabled = IsStandaloneEnabled,
            },
            open = {
                type = "execute",
                name = "Открыть настройки Purgeatory",
                order = 2,
                hidden = function() return not wrapper:IsRuntimeEnabled() end,
                func = function() wrapper:OpenConfig() end,
            },
            description = {
                type = "description",
                name = "Оповещения о рассеиваниях и прерываниях. При выключении события боя и уведомления отключаются сразу.\n\nАвтор: Mayen",
                order = 3,
                width = "full",
            },
            conflict = {
                type = "description",
                name = "|cffff0000Обнаружена отдельная версия Purgeatory.|r Отключите её в списке аддонов, чтобы использовать встроенную.",
                order = 4,
                width = "full",
                hidden = function() return not IsStandaloneEnabled() end,
            },
        },
    }
end

SarychUI:RegisterAddOn(ADDON_NAME, wrapper)
return wrapper
