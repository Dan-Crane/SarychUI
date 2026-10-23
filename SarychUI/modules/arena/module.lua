-- SarychUI Arena Module
-- Arena enemy frames positioning, scaling and testing (based on sArena behavior)

local moduleName = "arena"
local module = {}

-- Register module
SarychUI:RegisterModule(moduleName, module)

-- Local references
local L = SarychUI.L

-- Helpers
local function GetDB()
	local root = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return root and root[moduleName]
end

local function GetSetting(key, default)
	local db = GetDB()
	if db and db[key] ~= nil then return db[key] end
	return default
end

-- Internal state
local arenaContainer
local eventFrame
local arenaDefaultPosition = nil
local firstArenaFramePosition = nil
local originalArenaFramePositions = {}
local distanceAlphaUpdateFrame = nil
local arenaTestContainer = nil
local arenaTestFrames = {}
local arenaTestCastbars = {}
-- Cache for nameplate lookups by GUID
local nameplateCache = {}
local nameplateCacheTime = {}

-- ============================================
-- sArena Trinkets logic (ported with minimal changes)
-- ============================================

module.Trinkets = CreateFrame("Frame")
local trinketSuffixes = {"Trinket1", "Trinket2", "Trinket3", "Trinket4"}

function module:RefreshTrinketBorders()
    local preview = SarychUI.ArenaPreview
    if preview and preview.RefreshAll then preview:RefreshAll() end
end

local Alliance = {
    ["Human"] = "Human",
    ["Dwarf"] = "Dwarf",
    ["Night Elf"] = "Night Elf",
    ["Gnome"] = "Gnome",
    ["Draenei"] = "Draenei",
}

local Horde = {
    ["Orc"] = "Orc",
    ["Undead"] = "Undead",
    ["Tauren"] = "Tauren",
    ["Troll"] = "Troll",
    ["Blood Elf"] = "Blood Elf",
}

local racialSpells = {
    ["Human"] = {id = 59752, icon = "Interface\\Icons\\Spell_Shadow_Charm", cd = 120},
    ["Orc"] = {id = 20572, icon = "Interface\\Icons\\racial_orc_berserkerstrength", cd = 120},
    ["Dwarf"] = {id = 20594, icon = "Interface\\Icons\\spell_shadow_unholystrength", cd = 120},
    ["Night Elf"] = {id = 58984, icon = "Interface\\Icons\\ability_ambush", cd = 120},
    ["Undead"] = {id = 7744, icon = "Interface\\Icons\\spell_shadow_raisedead", cd = 120},
    ["Tauren"] = {id = 20549, icon = "Interface\\Icons\\ability_warstomp", cd = 120},
    ["Gnome"] = {id = 20589, icon = "Interface\\Icons\\ability_rogue_trip", cd = 105},
    ["Troll"] = {id = 26297, icon = "Interface\\Icons\\racial_troll_berserk", cd = 180},
    ["Blood Elf"] = {id = 28730, icon = "Interface\\Icons\\spell_shadow_teleport", cd = 120},
    ["Draenei"] = {id = 28880, icon = "Interface\\Icons\\spell_holy_holyprotection", cd = 180},
}

-- Localized UnitRace() names -> racialSpells keys (fallback when raceFile unavailable)
local raceTranslation = {
    ["Человек"] = "Human",
    ["Орк"] = "Orc",
    ["Дворф"] = "Dwarf",
    ["Ночная эльфийка"] = "Night Elf",
    ["Ночной эльф"] = "Night Elf",
    ["Нежить"] = "Undead",
    ["Таурен"] = "Tauren",
    ["Гном"] = "Gnome",
    ["Тролль"] = "Troll",
    ["Эльф крови"] = "Blood Elf",
    ["Эльфийка крови"] = "Blood Elf",
    ["Дреней"] = "Draenei",
}

-- UnitRace() raceFile tokens (locale-independent) -> racialSpells keys
local raceFileToKey = {
    Human = "Human",
    Orc = "Orc",
    Dwarf = "Dwarf",
    NightElf = "Night Elf",
    Scourge = "Undead",
    Tauren = "Tauren",
    Gnome = "Gnome",
    Troll = "Troll",
    BloodElf = "Blood Elf",
    Draenei = "Draenei",
}

local function ResolveArenaRace(unit)
    if not unit then return "None" end
    local localized, raceFile = UnitRace(unit)
    if raceFile then
        local key = raceFileToKey[raceFile] or (racialSpells[raceFile] and raceFile)
        if key then return key end
    end
    local race = raceTranslation[localized] or localized
    if race and racialSpells[race] then return race end
    return race or "None"
end

function module.Trinkets:GetTrinketTextureByRaceAndFaction(race)
    if Alliance[race] then
        return "Interface\\Icons\\inv_jewelry_trinketpvp_01"
    elseif Horde[race] then
        return "Interface\\Icons\\inv_jewelry_trinketpvp_02"
    end
end

function module.Trinkets:CreateTrinketIcon(frame, texture, anchorFrame)
    local db = GetDB(); local tr = db and db.Trinkets or {}
    -- ArenaEnemyFrame is a protected SecureUnitButton.  Even an otherwise
    -- harmless visual child makes its secure click path inherit addon taint on
    -- this client, so FocusUnit from Blizzard's right-click handler is denied.
    -- Keep the cooldown in our own UIParent hierarchy and use the arena frame
    -- only as an anchor.  SetPoint reads its position without modifying it.
    local trinket = CreateFrame("Frame", nil, UIParent)
    trinket._arenaFrame = frame
    trinket:SetFrameLevel(frame:GetFrameLevel() + 3)
    trinket:SetSize(26, 26)
    trinket:SetScale(tr.scale or 1)

    if anchorFrame then
        trinket:SetPoint("LEFT", anchorFrame, "RIGHT", 5, 0)
    else
        if tr.point then
            trinket:SetPoint(tr.point, frame, tr.x, tr.y)
        else
            trinket:SetPoint("LEFT", frame, "RIGHT", 2, -2)
        end
    end

    trinket.Icon = CreateFrame("Frame", nil, trinket)
    trinket.Icon:SetFrameLevel(trinket:GetFrameLevel() - 1)
    trinket.Icon:SetAllPoints()

    trinket.Icon.Texture = trinket.Icon:CreateTexture(nil, "BORDER")
    trinket.Icon.Texture:SetAllPoints(trinket)
    trinket.Icon.Texture:SetTexture(texture)
    trinket.Icon.Texture:SetTexCoord(0, 1, 0, 1)

    -- Keep the artwork attached to its cooldown. Reparenting an all-points
    -- child to UIParent makes it fill UIParent instead of the 26px icon.
    trinket.Icon:SetAlpha(1)
    trinket:Show()

    -- CooldownFrame_SetTimer hides a Cooldown with no active timer. Keep that
    -- sweep separate from the always-visible icon and its UIParent holder.
    trinket.Cooldown = CreateFrame("Cooldown", nil, trinket, "CooldownFrameTemplate")
    trinket.Cooldown:SetAllPoints(trinket)
    trinket.Cooldown:SetFrameLevel(trinket:GetFrameLevel() + 1)
    trinket.Cooldown:SetAlpha(0.65)
    if trinket.Cooldown.SetDrawEdge then trinket.Cooldown:SetDrawEdge(true) end
    trinket.Cooldown:Hide()
    return trinket
end

function module.Trinkets:CreateNonHumanIcons(frame, id, race)
    if not racialSpells[race] then return end
    local db = GetDB()
    local tr = db and db.Trinkets or {}
    local trinket1
    if tr.enabled then
        trinket1 = self:CreateTrinketIcon(frame, self:GetTrinketTextureByRaceAndFaction(race))
        self["arena" .. id .. "Trinket1"] = trinket1
    end
    if tr.racialEnabled then
        self["arena" .. id .. "Trinket2"] = self:CreateTrinketIcon(frame, racialSpells[race].icon, trinket1)
    end
end

function module.Trinkets:CreateHumanIcon(frame, id)
    local db = GetDB()
    local tr = db and db.Trinkets or {}
    if tr.racialEnabled then
        self["arena" .. id .. "Trinket4"] = self:CreateTrinketIcon(frame, racialSpells["Human"].icon)
    end
end

function module.Trinkets:CreateIcon(frame)
    if not frame or not frame.GetID then return end
    local id = frame:GetID()
    if not id then return end
    local unit = "arena" .. id
    local previous = self._iconRace and self._iconRace[id]
    local guid = UnitGUID(unit)
    local priorGUID = self._iconGUID and self._iconGUID[id]
    local existing = self[unit .. "Trinket1"] or self[unit .. "Trinket2"] or self[unit .. "Trinket4"]

    -- Opponent slots exist before the enemy's unit data is available. Never
    -- create a placeholder (or leave an old icon visible) for an empty slot.
    if not UnitExists(unit) or not guid then
        for _, suffix in ipairs(trinketSuffixes) do
            local icon = self[unit .. suffix]
            if icon then icon:Hide() end
        end
        return
    end

    if priorGUID and guid ~= priorGUID then
        self:DeleteTrinketIcons(id)
        previous, existing = nil, nil
    end

    local race = ResolveArenaRace(unit)
    if not racialSpells[race] then
        -- UnitRace may briefly be unavailable for a known opponent.
        if previous and priorGUID == guid then
            race = previous
        else
            return
        end
    end
    local db = GetDB()
    local tr = db and db.Trinkets or {}
    local complete = race == "Human"
        and (not tr.racialEnabled or self[unit .. "Trinket4"])
        or race ~= "Human"
        and (not tr.enabled or self[unit .. "Trinket1"])
        and (not tr.racialEnabled or self[unit .. "Trinket2"])
    if previous == race and existing and complete and (not guid or not priorGUID or guid == priorGUID) then
        if guid and not priorGUID then self._iconGUID[id] = guid end
        for _, suffix in ipairs(trinketSuffixes) do
            local icon = self[unit .. suffix]
            if icon and not icon:IsShown() then icon:Show() end
        end
        return
    end

    if previous and previous ~= "Human" and race ~= "Human" and complete then
        local trinket = self[unit .. "Trinket1"]
        local racial = self[unit .. "Trinket2"]
        if trinket then trinket.Icon.Texture:SetTexture(self:GetTrinketTextureByRaceAndFaction(race)) end
        if racial then racial.Icon.Texture:SetTexture(racialSpells[race].icon) end
    else
        if previous or existing then self:DeleteTrinketIcons(id) end
        if race == "Human" then
            self:CreateHumanIcon(frame, id)
        else
            self:CreateNonHumanIcons(frame, id, race)
        end
    end

    self._iconRace = self._iconRace or {}
    self._iconGUID = self._iconGUID or {}
    self._iconRace[id] = race
    self._iconGUID[id] = guid or priorGUID
    if self._debug then
        print("[SUI arena] slot=" .. id .. " icons=" .. race .. " guid=" .. tostring(guid))
    end
end

function module.Trinkets:DeleteTrinketIcons(id)
    if id then
        if self._debug and self._iconRace and self._iconRace[id] then
            print("[SUI arena] remove arena" .. id .. " race=" .. tostring(self._iconRace[id]))
        end
        if self._iconRace then self._iconRace[id] = nil end
        if self._iconGUID then self._iconGUID[id] = nil end
        for _, suffix in ipairs(trinketSuffixes) do
            local name = "arena" .. id .. suffix
            if self[name] then
                local trinket = self[name]
                trinket:Hide()
                trinket:ClearAllPoints()
                trinket:SetParent(nil)
                trinket:SetAlpha(0)
                trinket:UnregisterAllEvents()
                if trinket.Icon and trinket.Icon.Texture then
                    trinket.Icon.Texture:SetTexture(nil)
                end
                self[name] = nil
            end
        end
    else
        for i = 1, (MAX_ARENA_ENEMIES or 5) do self:DeleteTrinketIcons(i) end
    end
end

function module.Trinkets:Initialize()
    local db = GetDB()
    if not db then return end
    db.Trinkets = db.Trinkets or { enabled = true, racialEnabled = true, scale = 1 }
    self:RefreshIcons()
end

function module.Trinkets:RefreshIcons()
    if self._debug then print("[SUI arena] RefreshIcons instance=" .. tostring(select(2, IsInInstance()))) end
    self._lastReset = "RefreshIcons"
    self:DeleteTrinketIcons()
    local db = GetDB()
    local tr = db and db.Trinkets or {}
    if select(2, IsInInstance()) ~= "arena" or not (tr.enabled or tr.racialEnabled) then
        self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:UnregisterEvent("UNIT_NAME_UPDATE")
        self:SetScript("OnUpdate", nil)
        return
    end
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("UNIT_NAME_UPDATE")
    self._iconRetryElapsed = 0
    self:SetScript("OnUpdate", function(owner, elapsed)
        owner._iconRetryElapsed = (owner._iconRetryElapsed or 0) + elapsed
        if owner._iconRetryElapsed < 0.5 then return end
        owner._iconRetryElapsed = 0
        for i = 1, (MAX_ARENA_ENEMIES or 5) do
            if UnitExists("arena" .. i) then
                owner:CreateIcon(_G["ArenaEnemyFrame" .. i])
            end
        end
    end)
    local opponentCount = (type(GetNumArenaOpponents) == "function" and GetNumArenaOpponents()) or 0
    for i = 1, (MAX_ARENA_ENEMIES or 5) do
        if i <= opponentCount or UnitExists("arena" .. i) then
            self:CreateIcon(_G["ArenaEnemyFrame" .. i])
        end
    end
end

function module.Trinkets:ARENA_OPPONENT_UPDATE(unit, updateReason)
    local id = type(unit) == "string" and tonumber(unit:match("^arena(%d+)$"))
    if not id then return end
    self._lastUpdateReason = self._lastUpdateReason or {}
    self._lastUpdateReason[id] = updateReason
    if self._debug then
        print("[SUI arena] event " .. unit .. " " .. tostring(updateReason)
            .. " exists=" .. tostring(UnitExists(unit)) .. " guid=" .. tostring(UnitGUID(unit)))
    end
    local db = GetDB()
    local tr = db and db.Trinkets or {}
    if select(2, IsInInstance()) == "arena" and (tr.enabled or tr.racialEnabled) then
        self:CreateIcon(_G["ArenaEnemyFrame" .. id])
    end
end

function module.Trinkets:UNIT_NAME_UPDATE(unit)
    local id = type(unit) == "string" and tonumber(unit:match("^arena(%d+)$"))
    if id and select(2, IsInInstance()) == "arena" then
        self:CreateIcon(_G["ArenaEnemyFrame" .. id])
    end
end

module.Trinkets:SetScript("OnEvent", function(self, event, ...)
    return self[event] and self[event](self, ...)
end)

function module.Trinkets:UNIT_SPELLCAST_SUCCEEDED(unitID, spell)
    if not unitID or not unitID:match("^arena%d+$") then return end
    local id = tonumber(unitID:match("^arena(%d+)$"))
    if id then self:CreateIcon(_G["ArenaEnemyFrame" .. id]) end
    local race = ResolveArenaRace(unitID)
    local trinketSpellInfo = GetSpellInfo(42292)
    local humanSpellInfo = GetSpellInfo(59752)
    if not spell then return end
    if spell == trinketSpellInfo then
        if self[unitID .. "Trinket1"] then
            local trinket = self[unitID .. "Trinket1"]
            if trinket.Cooldown.SetDrawEdge then trinket.Cooldown:SetDrawEdge(true) end
            CooldownFrame_SetTimer(trinket.Cooldown, GetTime(), 120, 1)
            if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(trinket.Cooldown, GetTime(), 120, 1) end
        end
    end
    if race == "Human" and spell == humanSpellInfo then
        if self[unitID .. "Trinket4"] then
            local trinket = self[unitID .. "Trinket4"]
            if trinket.Cooldown.SetDrawEdge then trinket.Cooldown:SetDrawEdge(true) end
            CooldownFrame_SetTimer(trinket.Cooldown, GetTime(), 120, 1)
            if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(trinket.Cooldown, GetTime(), 120, 1) end
        end
    end
    if racialSpells[race] and racialSpells[race].id and spell == GetSpellInfo(racialSpells[race].id) then
        if self[unitID .. "Trinket2"] then
            local trinket = self[unitID .. "Trinket2"]
            if trinket.Cooldown.SetDrawEdge then trinket.Cooldown:SetDrawEdge(true) end
            CooldownFrame_SetTimer(trinket.Cooldown, GetTime(), racialSpells[race].cd, 1)
            if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(trinket.Cooldown, GetTime(), racialSpells[race].cd, 1) end
        end
    end
end

function module.Trinkets:PLAYER_ENTERING_WORLD()
    if self._debug then print("[SUI arena] PLAYER_ENTERING_WORLD") end
    self:RefreshIcons()
end

function module.Trinkets:PLAYER_LEAVING_WORLD()
    if self._debug then print("[SUI arena] PLAYER_LEAVING_WORLD") end
    self._lastReset = "PLAYER_LEAVING_WORLD"
    self:DeleteTrinketIcons()
end

SLASH_SARYCHUIARENATRINKETS1 = "/atrinkets"
SlashCmdList.SARYCHUIARENATRINKETS = function(message)
    local trinkets = module.Trinkets
    if message == "debug" then
        trinkets._debug = not trinkets._debug
        print("[SUI arena] debug=" .. tostring(trinkets._debug))
    end

    local function IconState(icon)
        if not icon then return "missing" end
        local texture = icon.Icon and icon.Icon.Texture and icon.Icon.Texture:GetTexture()
        local file = type(texture) == "string" and texture:match("([^\\/]+)$") or tostring(texture)
        local visible = type(icon.IsVisible) == "function" and icon:IsVisible()
        return (icon:IsShown() and "shown" or "hidden") .. "/vis=" .. tostring(visible)
            .. "/a=" .. tostring(icon:GetAlpha()) .. "/ui=" .. tostring(icon:GetParent() == UIParent)
            .. "/cd=" .. tostring(icon.Cooldown and icon.Cooldown:IsShown())
            .. "/" .. tostring(file)
    end

    local db = GetDB()
    local config = db and db.Trinkets
    print("[SUI arena] instance=" .. tostring(select(2, IsInInstance()))
        .. " trinket=" .. tostring(config and config.enabled)
        .. " racial=" .. tostring(config and config.racialEnabled)
        .. " reset=" .. tostring(trinkets._lastReset)
        .. " opponents=" .. tostring(type(GetNumArenaOpponents) == "function" and GetNumArenaOpponents() or "?"))
    for id = 1, (MAX_ARENA_ENEMIES or 5) do
        local unit = "arena" .. id
        local frame = _G["ArenaEnemyFrame" .. id]
        local localizedRace, raceFile = UnitRace(unit)
        print("[SUI arena] " .. unit
            .. " exists=" .. tostring(UnitExists(unit))
            .. " frame=" .. tostring(frame and frame:IsShown())
            .. " apiRace=" .. tostring(raceFile or localizedRace)
            .. " race=" .. tostring(trinkets._iconRace and trinkets._iconRace[id])
            .. " guid=" .. tostring(trinkets._iconGUID and trinkets._iconGUID[id])
            .. " event=" .. tostring(trinkets._lastUpdateReason and trinkets._lastUpdateReason[id])
            .. " tr=" .. IconState(trinkets[unit .. "Trinket1"])
            .. " racial=" .. IconState(trinkets[unit .. "Trinket2"])
            .. " human=" .. IconState(trinkets[unit .. "Trinket4"]))
    end
end

-- Class color for arena healthbars (ported from sArena)
local function ColorArenaHealthByClass(frame)
	if not frame or not frame.unit then return end
	if not frame.healthbar then return end
	-- respect setting
	local db = GetDB(); if not (db == nil or db.classColorHP == nil or db.classColorHP == true) then return end
	if not UnitIsPlayer(frame.unit) then return end
	local _, class = UnitClass(frame.unit)
	if not class then return end
	local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if not color then return end
	frame.healthbar:SetStatusBarColor(color.r, color.g, color.b)
end

local function TrySetupHooks()
	-- Do not hooksecurefunc ArenaEnemyFrame_UpdatePlayer. On this client the
	-- C wrapper taints the original body, so Show() at Blizzard_ArenaUI.lua:144
	-- and ArenaEnemyFrames:Show() inside it are blocked in combat.
	if module.ScheduleSecureFramePaint then
		module:ScheduleSecureFramePaint()
	end
	module._hooksDone = true
end

-- Apply or reset class coloring on all arena frames based on setting
function module:ApplyClassColoring()
	if not MAX_ARENA_ENEMIES then return end
	local db = GetDB()
	local enabled = (db == nil or db.classColorHP == nil or db.classColorHP == true)
	for i = 1, MAX_ARENA_ENEMIES do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame and frame.healthbar then
			if enabled then
				ColorArenaHealthByClass(frame)
			else
				if UnitFrameHealthBar_Update then
					UnitFrameHealthBar_Update(frame.healthbar, frame.unit)
				end
			end
		end
	end
end

-- Save original position of first ArenaEnemyFrame (from Blizzard UI)
function module:SaveOriginalArenaFramePosition()
	if not firstArenaFramePosition then
		local firstFrame = _G["ArenaEnemyFrame1"]
		if firstFrame then
			local point, relativeTo, relativePoint, xOfs, yOfs = firstFrame:GetPoint()
			if point then
				firstArenaFramePosition = {
					point = point,
					relativeTo = relativeTo,
					relativePoint = relativePoint,
					xOfs = xOfs,
					yOfs = yOfs
				}
			end
		end
	end
end

-- Calculate default container position based on original ArenaEnemyFrame position
function module:CalculateDefaultContainerPosition()
	-- Если дефолтная позиция уже вычислена, не пересчитываем её
	-- Это гарантирует, что дефолтная позиция остается неизменной
	if arenaDefaultPosition then
		return
	end
	
	if not firstArenaFramePosition then
		self:SaveOriginalArenaFramePosition()
	end
	
	-- Если получили оригинальную позицию, вычисляем позицию контейнера
	if firstArenaFramePosition then
		-- Первый фрейм привязан к контейнеру как "TOP" к "BOTTOM" с offset 0, -8
		-- Используем оригинальную позицию первого фрейма как базу для дефолтной позиции
		
		-- Если первый фрейм привязан к UIParent, используем его позицию как базу
		local relativeTo = firstArenaFramePosition.relativeTo
		if relativeTo == UIParent or (relativeTo and relativeTo.GetName and relativeTo:GetName() == "UIParent") then
			-- Контейнер использует ту же точку привязки и те же координаты
			-- Используем оригинальную позицию первого фрейма как есть (без смещения)
			arenaDefaultPosition = {
				point = firstArenaFramePosition.point,
				relativeTo = UIParent,
				relativePoint = firstArenaFramePosition.relativePoint,
				xOfs = firstArenaFramePosition.xOfs,
				yOfs = firstArenaFramePosition.yOfs
			}
		else
			-- Fallback: используем позицию первого фрейма как есть
			arenaDefaultPosition = {
				point = firstArenaFramePosition.point,
				relativeTo = firstArenaFramePosition.relativeTo,
				relativePoint = firstArenaFramePosition.relativePoint,
				xOfs = firstArenaFramePosition.xOfs,
				yOfs = firstArenaFramePosition.yOfs
			}
		end
	end
end

-- Keep Blizzard's secure buttons anchored only to Blizzard's UIParent.
-- The movable SarychUI frame is a position editor, never an anchor in the
-- ArenaEnemyFrame click hierarchy.
function module:PlaceFirstArenaFrame()
	if not arenaContainer or (InCombatLockdown and InCombatLockdown()) then return end
	local frame = _G["ArenaEnemyFrame1"]
	if not frame then return end
	local x = arenaContainer:GetCenter()
	local y = arenaContainer:GetBottom()
	if not x or not y then return end
	local parentScale = UIParent:GetEffectiveScale()
	local frameScale = frame:GetEffectiveScale()
	if not parentScale or parentScale <= 0 or not frameScale or frameScale <= 0 then return end
	local ratio = frameScale / parentScale
	frame:ClearAllPoints()
	frame:SetPoint("TOP", UIParent, "BOTTOMLEFT", x / ratio, (y - 8) / ratio)
end

function module:ClampArenaToScreen()
	if not arenaContainer or (InCombatLockdown and InCombatLockdown()) then return end
	local drag = SarychUI.DragMode and SarychUI.DragMode:GetFrameData("arenaContainer")
	if drag and drag.isMoving then return end
	local first = _G.ArenaEnemyFrame1
	local last = _G.ArenaEnemyFrame5
	if not first or not last then return end
	local parentScale = UIParent:GetEffectiveScale()
	local scale = first:GetEffectiveScale()
	if not parentScale or parentScale <= 0 or not scale then return end
	local ratio = scale / parentScale
	local left, right = first:GetLeft(), first:GetRight()
	local top, bottom = first:GetTop(), last:GetBottom()
	if not (left and right and top and bottom) then return end
	left, right, top, bottom = left * ratio, right * ratio, top * ratio, bottom * ratio
	local width, height = UIParent:GetWidth(), UIParent:GetHeight()
	local dx, dy = 0, 0
	if right - left > width then
		dx = width / 2 - (left + right) / 2
	elseif left < 0 then dx = -left
	elseif right > width then dx = width - right end
	if top - bottom > height then
		dy = height / 2 - (top + bottom) / 2
	elseif bottom < 0 then dy = -bottom
	elseif top > height then dy = height - top end
	if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then return end
	local point, _, relativePoint, x, y = arenaContainer:GetPoint()
	if not point then return end
	x, y = (x or 0) + dx, (y or 0) + dy
	arenaContainer:ClearAllPoints()
	arenaContainer:SetPoint(point, UIParent, relativePoint or point, x, y)
	local db = GetDB()
	if db then db.arenaA, db.arenaR, db.arenaX, db.arenaY = point, relativePoint or point, x, y end
	self:PlaceFirstArenaFrame()
end

function module:ApplyFrameSpacing()
	local gap = tonumber(GetSetting("frameSpacing", 40)) or 40
	if gap < 0 then gap = 0 elseif gap > 60 then gap = 60 end
	if InCombatLockdown and InCombatLockdown() then
		if eventFrame then eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED") end
		return
	end
	for i = 2, 5 do
		local frame = _G["ArenaEnemyFrame" .. i]
		local previous = _G["ArenaEnemyFrame" .. (i - 1)]
		if frame and previous then
			if not originalArenaFramePositions[i] then
				local point, relativeTo, relativePoint, x, y = frame:GetPoint()
				if point then originalArenaFramePositions[i] = { point, relativeTo, relativePoint, x, y } end
			end
			frame:ClearAllPoints()
			frame:SetPoint("TOP", previous, "BOTTOM", 0, -gap)
		end
	end
end

-- Create/ensure Blizzard_ArenaUI and attach frames under our container
function module:InitializeContainer()
	-- ArenaEnemyFrame* and ArenaEnemyFrames are protected.  Never rebuild their
	-- hierarchy from combat (for example when PLAYER_ENTERING_WORLD fires after
	-- reconnecting to an arena).
	if InCombatLockdown and InCombatLockdown() then return end

	-- Do not LoadAddOn("Blizzard_ArenaUI") here.  Frame OnLoad calls
	-- UnitFrame_Initialize, which SetScript's OnEvent.  Doing that from addon
	-- code leaves the handler tainted, so Blizzard's later Show/Hide in combat
	-- is reported as ADDON_ACTION_BLOCKED on SarychUI.  The client loads the
	-- addon itself; we only anchor frames after they already exist.

	-- Сохраняем оригинальную позицию первого фрейма ДО того, как мы его изменим
	if MAX_ARENA_ENEMIES then
		local firstFrame = _G["ArenaEnemyFrame1"]
		if firstFrame and not firstArenaFramePosition then
			self:SaveOriginalArenaFramePosition()
		end
	end

	if not arenaContainer then
		-- This frame is only the movable editor for the position.
		arenaContainer = CreateFrame("Frame", "SarychUIArenaContainer", UIParent)
		arenaContainer:SetSize(200, 1)
		
		-- Вычисляем дефолтную позицию контейнера на основе оригинальной позиции первого фрейма
		self:CalculateDefaultContainerPosition()
		
		-- Устанавливаем контейнер на дефолтную позицию
		if arenaDefaultPosition then
			arenaContainer:SetPoint(
				arenaDefaultPosition.point,
				arenaDefaultPosition.relativeTo,
				arenaDefaultPosition.relativePoint,
				arenaDefaultPosition.xOfs,
				arenaDefaultPosition.yOfs
			)
		else
			-- Fallback: если не удалось получить оригинальную позицию, используем старый подход
			arenaContainer:SetPoint("RIGHT", UIParent, "RIGHT", -311, 131)
			-- Сохраняем как дефолт
			if not arenaDefaultPosition then
				local point, relativeTo, relativePoint, xOfs, yOfs = arenaContainer:GetPoint()
				if point then
					arenaDefaultPosition = {
						point = point,
						relativeTo = relativeTo,
						relativePoint = relativePoint,
						xOfs = xOfs,
						yOfs = yOfs
					}
				end
			end
		end
	end

	if ArenaEnemyFrames then
		ArenaEnemyFrames:SetScale(GetSetting('scale', 1.0))
	end

	-- Keep Blizzard's protected hierarchy intact; only change frame anchors
	-- out of combat. Blizzard still owns their visibility and pet frames.
	self:PlaceFirstArenaFrame()
	self:ApplyFrameSpacing()
	self:ClampArenaToScreen()
	if MAX_ARENA_ENEMIES then
		for i = 1, MAX_ARENA_ENEMIES do
			local frame = _G["ArenaEnemyFrame" .. i]
			if frame then
				ColorArenaHealthByClass(frame)
			end
		end
	end

	TrySetupHooks()
end

-- Ensure container position matches DB immediately
function module:ApplyContainerPosition()
    local db = GetDB(); if not db then return end
    if not arenaContainer then return end
    if InCombatLockdown and InCombatLockdown() then return end
    
    -- Проверяем, не происходит ли сейчас drag или только что был drag - если да, не применяем позицию
    -- Это предотвращает перезапись позиции во время drag и сразу после него
    local dragData = SarychUI.DragMode and SarychUI.DragMode:GetFrameData("arenaContainer")
    if dragData and (dragData.isMoving or dragData.justDragged or dragData._settleUpdater) then return end
    
    -- Вычисляем дефолтную позицию если еще не вычислена
    if not arenaDefaultPosition then
        self:CalculateDefaultContainerPosition()
    end
    
    -- Проверяем, являются ли координаты в БД offset (от сброса) или абсолютными (от drag)
    -- Правило: offset ТОЛЬКО если координаты = 0,0 (это сброс)
    -- ВСЕ остальное - абсолютные координаты от drag
    local xOfs = db.arenaX
    local yOfs = db.arenaY
    local isOffset = (xOfs == 0 and yOfs == 0)
    
    -- Если это offset от дефолта (сброс) - применяем offset
    if isOffset and arenaDefaultPosition then
        local finalX = arenaDefaultPosition.xOfs + 0
        local finalY = arenaDefaultPosition.yOfs + 0
        
        arenaContainer:ClearAllPoints()
        arenaContainer:SetPoint(
            arenaDefaultPosition.point,
            arenaDefaultPosition.relativeTo,
            arenaDefaultPosition.relativePoint,
            finalX,
            finalY
        )
    else
        -- Если это абсолютные координаты (от drag) - применяем напрямую
        local point = db.arenaA or (arenaDefaultPosition and arenaDefaultPosition.point) or 'RIGHT'
        local relativePoint = db.arenaR or (arenaDefaultPosition and arenaDefaultPosition.relativePoint) or 'RIGHT'
        
        if xOfs == nil or yOfs == nil then
            if arenaDefaultPosition then
                point = arenaDefaultPosition.point
                relativePoint = arenaDefaultPosition.relativePoint
                xOfs = arenaDefaultPosition.xOfs
                yOfs = arenaDefaultPosition.yOfs
            else
                point = 'RIGHT'
                relativePoint = 'RIGHT'
                xOfs = -311
                yOfs = 131
            end
        end
        
        arenaContainer:ClearAllPoints()
        arenaContainer:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)
    end
	self:PlaceFirstArenaFrame()
	self:ApplyFrameSpacing()
	self:ClampArenaToScreen()
end

function module:DeleteArenaFrames()
	-- Deliberately empty.  These are Blizzard protected unit buttons.  The old
	-- implementation called Hide() here on every world transition and therefore
	-- tainted their visibility.  Blizzard_ArenaUI later calls Show() in combat
	-- from ArenaEnemyFrame_UpdatePlayer, which produced ADDON_ACTION_BLOCKED.
	-- Blizzard owns their visibility; SarychUI only positions them out of combat.
end

-- Restore arena frames to default Blizzard state
function module:RestoreArenaFrames()
	if not MAX_ARENA_ENEMIES then return end
	if InCombatLockdown() then 
		-- Schedule restore after combat
		C_Timer.After(0.1, function() self:RestoreArenaFrames() end)
		return
	end
	
	-- Restore first frame to original position if we saved it.  Never force-load
	-- Blizzard_ArenaUI: that taints ArenaEnemyFrame OnEvent for the whole session.
	if firstArenaFramePosition then
		local firstFrame = _G["ArenaEnemyFrame1"]
		if firstFrame then
			firstFrame:ClearAllPoints()
			firstFrame:SetPoint(
				firstArenaFramePosition.point,
				firstArenaFramePosition.relativeTo or UIParent,
				firstArenaFramePosition.relativePoint,
				firstArenaFramePosition.xOfs,
				firstArenaFramePosition.yOfs
			)
		end
	end
	for i = 2, 5 do
		local frame = _G["ArenaEnemyFrame" .. i]
		local position = originalArenaFramePositions[i]
		if frame and position then
			frame:ClearAllPoints()
			frame:SetPoint(position[1], position[2] or UIParent, position[3], position[4], position[5])
		end
	end
	if ArenaEnemyFrames then
		ArenaEnemyFrames:SetScale(1)
	end
	
	-- Remove class color lock from healthbars and let Blizzard update them
	for i = 1, MAX_ARENA_ENEMIES do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame and frame.healthbar then
			-- Let Blizzard update healthbar
			if UnitFrameHealthBar_Update then
				UnitFrameHealthBar_Update(frame.healthbar, frame.unit)
			end
		end
	end
	
	-- Let Blizzard handle visibility and positioning of remaining frames
	-- Blizzard will show/hide frames based on arena status
end

local TEST_CAST_SPELLS = { 1464, 2060, 133, 116, 403 }
local TEST_CLASSES = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "SHAMAN" }

local function EnsureArenaTestFrames()
	if InCombatLockdown and InCombatLockdown() then return false end
	if not _G.ArenaEnemyFrame1 and Arena_LoadUI and securecall then
		-- Load the Blizzard UI through its secure FrameXML entry point.
		securecall("Arena_LoadUI")
	end
	if not _G.ArenaEnemyFrame1 then return false end
	if not arenaTestContainer then
		-- Visibility marker only; the displayed frames remain Blizzard's frames.
		arenaTestContainer = CreateFrame("Frame", "SarychUIArenaTestContainer", UIParent)
		arenaTestContainer:SetSize(1, 1)
		arenaTestContainer:Hide()
	end
	for i = 1, 5 do
		arenaTestFrames[i] = _G["ArenaEnemyFrame" .. i]
	end
	return true
end

local function EnsureTestCastbar(id)
	local bar = arenaTestCastbars[id]
	if bar then return bar end
	local source = _G["ArenaEnemyFrame" .. id .. "CastingBar"]
	if not source then return end

	-- The native bar has no active cast in test mode, so its own scripts hide it.
	-- Draw a sample over its exact geometry without changing those scripts.
	bar = CreateFrame("StatusBar", "SarychUIArenaTestCastingBar" .. id, UIParent)
	bar:SetAllPoints(source)
	bar:SetFrameStrata(source:GetFrameStrata() or "MEDIUM")
	bar:SetFrameLevel((source:GetFrameLevel() or 0) + 1)
	local sourceTexture = source:GetStatusBarTexture()
	bar:SetStatusBarTexture(sourceTexture and sourceTexture:GetTexture()
		or [[Interface\TargetingFrame\UI-StatusBar]])
	bar:SetStatusBarColor(1, 0.7, 0)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0.65)
	bar:EnableMouse(false)

	local background = bar:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints(bar)
	background:SetTexture([[Interface\Buttons\WHITE8X8]])
	background:SetVertexColor(0, 0, 0, 0.5)

	local sourceName = source:GetName()
	local sourceBorder = sourceName and _G[sourceName .. "Border"]
	if sourceBorder then
		local border = bar:CreateTexture(nil, "OVERLAY")
		border:SetAllPoints(sourceBorder)
		border:SetTexture(sourceBorder:GetTexture())
	end
	local spellName, _, spellIcon = GetSpellInfo(TEST_CAST_SPELLS[id])
	local sourceIcon = sourceName and _G[sourceName .. "Icon"]
	local icon = bar:CreateTexture(nil, "ARTWORK")
	if sourceIcon then
		icon:SetAllPoints(sourceIcon)
	else
		icon:SetSize(16, 16)
		icon:SetPoint("RIGHT", bar, "LEFT", -5, 0)
	end
	icon:SetTexture(spellIcon or [[Interface\Icons\Spell_Fire_FlameBolt]])

	local sourceText = sourceName and _G[sourceName .. "Text"]
	local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	if sourceText then
		text:SetAllPoints(sourceText)
	else
		text:SetPoint("CENTER", bar, "CENTER", 0, 3)
	end
	text:SetText(spellName or "Cast")

	local spark = bar:CreateTexture(nil, "OVERLAY")
	spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
	spark:SetBlendMode("ADD")
	spark:SetSize(32, 32)
	spark:SetPoint("CENTER", bar, "LEFT", source:GetWidth() * 0.65, 0)

	bar:Hide()
	arenaTestCastbars[id] = bar
	return bar
end

function module:HideArenaEnemyFrames()
	local wasTesting = arenaTestContainer and arenaTestContainer:IsShown()
	if arenaTestContainer then arenaTestContainer:Hide() end
	for i = 1, 5 do
		if arenaTestCastbars[i] then arenaTestCastbars[i]:Hide() end
		for _, suffix in ipairs({ "Trinket1", "Racial" }) do
			local icon = _G["SarychUIArenaTestTrinket" .. i .. suffix]
			if icon then icon:Hide() end
		end
	end
	if wasTesting and not (InCombatLockdown and InCombatLockdown()) then
		for i = 1, 5 do
			local frame = arenaTestFrames[i]
			if frame and securecall then
				if ArenaEnemyFrame_UpdatePlayer then securecall("ArenaEnemyFrame_UpdatePlayer", frame) end
				if select(2, IsInInstance()) ~= "arena" then
					securecall(frame.Hide, frame)
				end
			end
		end
		if ArenaEnemyFrames and securecall then
			if select(2, IsInInstance()) == "arena" and ArenaEnemyFrames_UpdateVisible then
				securecall("ArenaEnemyFrames_UpdateVisible")
			else
				securecall(ArenaEnemyFrames.Hide, ArenaEnemyFrames)
			end
		end
	end
	local abilities = SarychUI.extensions and SarychUI.extensions.party_abilities
	if abilities and abilities.RefreshConfig then abilities:RefreshConfig() end
	if SarychUI.DragMode then
		SarychUI.DragMode:RefreshDragOverlay("arenaContainer")
	end
end

function module:GetVisibleTestFrame(index)
	local frame = arenaTestFrames[index]
	if arenaTestContainer and arenaTestContainer:IsShown() and frame and frame:IsVisible() then
		return frame
	end
end

function module:GetAbilityAnchor(index, test)
	local db = GetDB()
	local tr = db and db.Trinkets or {}
	local anchor
	if test then
		if tr.racialEnabled then anchor = _G["SarychUIArenaTestTrinket" .. index .. "Racial"] end
		if not (anchor and anchor:IsShown()) and tr.enabled then
			anchor = _G["SarychUIArenaTestTrinket" .. index .. "Trinket1"]
		end
	else
		local prefix = "arena" .. index
		if tr.racialEnabled then
			anchor = self.Trinkets[prefix .. "Trinket2"] or self.Trinkets[prefix .. "Trinket4"]
		end
		if not (anchor and anchor:IsShown()) and tr.enabled then
			anchor = self.Trinkets[prefix .. "Trinket1"]
		end
	end
	if anchor and anchor:IsShown() then return anchor end
	return test and self:GetVisibleTestFrame(index) or _G["ArenaEnemyFrame" .. index]
end

function module:Test(numOpponents)
	numOpponents = tonumber(numOpponents)
	if not numOpponents or numOpponents < 1 or numOpponents > 5 then return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	if select(2, IsInInstance()) == "arena" then return false end
	if not EnsureArenaTestFrames() or not securecall then return false end

	self:InitializeContainer()
	self:ApplyContainerPosition()
	self:ApplyFrameSpacing()
	if ArenaEnemyFrames then securecall(ArenaEnemyFrames.Show, ArenaEnemyFrames) end
	for i = 1, 5 do
		local frame = arenaTestFrames[i]
		local castbar = EnsureTestCastbar(i)
		if frame and i <= numOpponents then
			if ArenaEnemyFrame_SetMysteryPlayer then securecall("ArenaEnemyFrame_SetMysteryPlayer", frame) end
			if ArenaEnemyFrame_Unlock then securecall("ArenaEnemyFrame_Unlock", frame) end
			if frame.name then frame.name:SetText("arena" .. i) end
			local class = TEST_CLASSES[i]
			if frame.classPortrait and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class] then
				frame.classPortrait:SetTexture([[Interface\TargetingFrame\UI-Classes-Circles]])
				frame.classPortrait:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]))
			end
			if frame.healthbar and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
				local color = RAID_CLASS_COLORS[class]
				frame.healthbar:SetStatusBarColor(color.r, color.g, color.b)
			end
			securecall(frame.Show, frame)
			if castbar then castbar:Show() end
		else
			if frame then securecall(frame.Hide, frame) end
			if castbar then castbar:Hide() end
			for _, suffix in ipairs({ "Trinket1", "Racial" }) do
				local icon = _G["SarychUIArenaTestTrinket" .. i .. suffix]
				if icon then icon:Hide() end
			end
		end
	end
	arenaTestContainer:Show()
	if not arenaTestFrames[1]:IsVisible() then
		self:HideArenaEnemyFrames()
		return false
	end
	local db = GetDB()
	if db and db.Trinkets then self:ShowTestTrinkets(numOpponents, db.Trinkets) end
	local abilities = SarychUI.extensions and SarychUI.extensions.party_abilities
	if abilities and abilities.RefreshConfig then abilities:RefreshConfig() end
	if SarychUI.DragMode then
		SarychUI.DragMode:RefreshDragOverlay("arenaContainer")
	end
	
	return true
end

local function StartTestIconCooldown(icon, duration)
	if not icon or not icon.Cooldown then return end
	icon._testDuration = duration
	local now = GetTime()
	if icon._testStart and now < icon._testStart + duration then return end
	local start = now - duration * 0.25
	icon._testStart = start
	CooldownFrame_SetTimer(icon.Cooldown, start, duration, 1)
	if SarychUI_NotifyCooldown then
		SarychUI_NotifyCooldown(icon.Cooldown, start, duration, 1)
	end
end

-- Show trinket and racial icons for test mode
function module:ShowTestTrinkets(numOpponents, trinketsDB)
	if not trinketsDB then return end
	if InCombatLockdown() then return end
	if not arenaTestContainer or not arenaTestContainer:IsShown() then return end
	
	local trinketsEnabled = trinketsDB.enabled == true
	local racialEnabled = trinketsDB.racialEnabled == true
	local scale = trinketsDB.scale or 1.0
	
	-- Test race (using Orc for example)
	local testRace = "Orc"
	local trinketTexture = "Interface\\Icons\\inv_jewelry_trinketpvp_02" -- Horde trinket
	local racialTexture = "Interface\\Icons\\racial_orc_berserkerstrength" -- Orc racial
	
	for i = 1, numOpponents do
		local frame = arenaTestFrames[i]
		if not frame then break end
		local frameScale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
		
		-- Handle trinket icon
		local trinket = self:GetOrCreateTestTrinket(frame, i, "Trinket1")
		if trinket then
			if trinketsEnabled then
				trinket:SetScale(scale * frameScale)
				trinket.Icon.Texture:SetTexture(trinketTexture)
				trinket.Icon:Show()
				trinket:Show()
				StartTestIconCooldown(trinket, 45)
			else
				-- Hide if disabled
				trinket:Hide()
				if trinket.Icon then
					trinket.Icon:Hide()
				end
			end
		end
		
		-- Handle racial icon
		-- Если тринкеты включены, расовая позиционируется справа от тринкета
		-- Если тринкеты выключены, расовая позиционируется на месте тринкета
		local racial = self:GetOrCreateTestTrinket(frame, i, "Racial", nil)
		if racial then
			if racialEnabled then
				racial:SetScale(scale * frameScale)
				racial.Icon.Texture:SetTexture(racialTexture)
				racial.Icon:Show()
				racial:Show()
				StartTestIconCooldown(racial, 90)
				
				-- Перепозиционируем расовую в зависимости от состояния тринкетов
				racial:ClearAllPoints()
				if trinketsEnabled and trinket then
					-- Тринкеты включены - расовая справа от тринкета
					racial:SetPoint("LEFT", trinket, "RIGHT", 5, 0)
				else
					-- Тринкеты выключены - расовая на месте тринкета
					racial:SetPoint("LEFT", frame, "RIGHT", 2, -2)
				end
			else
				-- Hide if disabled
				racial:Hide()
				if racial.Icon then
					racial.Icon:Hide()
				end
			end
		end
	end
end

-- Get or create test trinket icon
function module:GetOrCreateTestTrinket(frame, id, suffix, anchorFrame)
	if not frame then return nil end
	
	local trinketName = "SarychUIArenaTestTrinket" .. id .. suffix
	local trinket = _G[trinketName]
	
	if not trinket then
		-- Keep preview icons out of Blizzard's protected button hierarchy.
		trinket = CreateFrame("Frame", trinketName, UIParent)
		trinket:SetFrameLevel(frame:GetFrameLevel() + 3)
		trinket:SetSize(26, 26)
		
		-- Position
		if anchorFrame then
			trinket:SetPoint("LEFT", anchorFrame, "RIGHT", 5, 0)
		else
			trinket:SetPoint("LEFT", frame, "RIGHT", 2, -2)
		end
		
		-- Icon frame
		trinket.Icon = CreateFrame("Frame", nil, trinket)
		trinket.Icon:SetFrameLevel(trinket:GetFrameLevel() - 1)
		trinket.Icon:SetAllPoints()
		
		-- Texture
		trinket.Icon.Texture = trinket.Icon:CreateTexture(nil, "BORDER")
		trinket.Icon.Texture:SetAllPoints(trinket)
		trinket.Icon.Texture:SetTexCoord(0, 1, 0, 1)
		trinket.Cooldown = CreateFrame("Cooldown", nil, trinket, "CooldownFrameTemplate")
		trinket.Cooldown:SetAllPoints(trinket)
		trinket.Cooldown:SetFrameLevel(trinket:GetFrameLevel() + 1)
		trinket.Cooldown:SetAlpha(0.65)
		if trinket.Cooldown.SetDrawEdge then trinket.Cooldown:SetDrawEdge(true) end
		trinket.Cooldown:Hide()
		trinket:SetScript("OnUpdate", function(self, elapsed)
			if self:IsShown() and self._testDuration then
				self._testTick = (self._testTick or 0) + elapsed
				if self._testTick >= 0.2 then
					self._testTick = 0
					StartTestIconCooldown(self, self._testDuration)
				end
			end
		end)
		
		-- Enable mouse for testing
		trinket:EnableMouse(true)
		trinket:SetMovable(true)
	end
	
	return trinket
end

-- ============================================
-- Distance-based alpha transparency
-- ============================================

-- Helper function to check if AwesomeWotlk mode is enabled
local function UseAwesomeWotlk()
	local db = GetDB()
	return db and db.useAwesomeWotlk == true
end

-- Helper function to check if autolos is enabled
local function IsAutolosEnabled()
	-- Check global variable first
	if _G.autolosEnabled == false then
		return false
	end
	
	-- Check SarychUI database
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.autolos then
		return SarychUI.db.profile.addons.autolos.enabled ~= false
	end
	
	-- Default to true if autolosEnabled is not explicitly false
	return (_G.autolosEnabled ~= false)
end

-- Reused buffer so WorldFrame walks call GetChildren() once per scan instead of
-- once per index (these run up to 10x/sec).
local worldChildren = {}

local function CollectWorldChildren(...)
	local n = select("#", ...)
	for i = 1, n do
		worldChildren[i] = select(i, ...)
	end
	for i = n + 1, #worldChildren do
		worldChildren[i] = nil
	end
	return n
end

-- Helper function to check if autolos is working (has nameplates with range property)
local function IsAutolosWorking()
	if not IsAutolosEnabled() then
		return false
	end
	
	-- Check if there are any nameplates with range property (autolos sets this)
	local numChildren = CollectWorldChildren(WorldFrame:GetChildren())
	for i = 1, numChildren do
		local frame = worldChildren[i]
		if frame and frame.range and frame.guid then
			-- Found at least one nameplate with range property, autolos is working
			return true
		end
	end
	
	return false
end

-- Helper function to get nameplate by GUID (with caching)
local function GetNamePlateByGUID(guid)
	if not guid then return nil end
	
	-- Check cache first (cache is valid for 0.5 seconds)
	local cacheEntry = nameplateCache[guid]
	local cacheTime = nameplateCacheTime[guid]
	local currentTime = GetTime()
	
	if cacheEntry and cacheTime and (currentTime - cacheTime) < 0.5 then
		-- Verify cached nameplate is still valid
		if cacheEntry.range or (cacheEntry.UnitFrame and cacheEntry.UnitFrame.unit) then
			return cacheEntry
		else
			-- Cache entry is invalid, remove it
			nameplateCache[guid] = nil
			nameplateCacheTime[guid] = nil
		end
	end
	
	-- Cache miss or expired, search for nameplate
	local nameplate = nil
	
	-- Try C_NamePlate if AwesomeWotlk is enabled
	if UseAwesomeWotlk() and C_NamePlate then
		-- C_NamePlate doesn't have GetNamePlateByGUID, so we need to iterate
		local nameplates = C_NamePlate.GetNamePlates()
		if nameplates then
			for _, np in ipairs(nameplates) do
				if np and np.UnitFrame and np.UnitFrame.unit then
					local nameplateGUID = UnitGUID(np.UnitFrame.unit)
					if nameplateGUID == guid then
						nameplate = np
						break
					end
				end
			end
		end
	end
	
	-- Fallback: search through WorldFrame children (like autolos does)
	if not nameplate then
		local numChildren = CollectWorldChildren(WorldFrame:GetChildren())
		for i = 1, numChildren do
			local frame = worldChildren[i]
			if frame and frame.guid and frame.guid == guid and frame.range then
				nameplate = frame
				break
			end
		end
	end
	
	-- Update cache if nameplate found
	if nameplate then
		nameplateCache[guid] = nameplate
		nameplateCacheTime[guid] = currentTime
	end
	
	return nameplate
end

-- Clear nameplate cache
local function ClearNameplateCache()
	nameplateCache = {}
	nameplateCacheTime = {}
end

-- Function to get distance value from nameplate (1 if > 40, 0 if <= 40)
local function GetDistanceValue(nameplate)
	if not nameplate then return 1 end -- Default to 1 (far) if no nameplate
	
	local range = nil
	
	-- Try to get range from nameplate
	if nameplate.range then
		-- Direct range property (from autolos)
		range = nameplate.range
	elseif nameplate.UnitFrame and nameplate.UnitFrame.unit then
		-- For C_NamePlate, we might need to check if range is available
		-- In WoW 3.3.5, nameplates have range property set by the game
		-- Check if the frame has range property
		if nameplate.UnitFrame.range then
			range = nameplate.UnitFrame.range
		end
	end
	
	-- If range is 0 or nil, consider it as "not available" (default to 1)
	if not range or range == 0 then
		return 1
	end
	
	-- Return 1 if > 40, 0 if <= 40
	return (range > 40) and 1 or 0
end

-- Function to update arena frame alpha based on distance
local function UpdateArenaFrameDistanceAlpha()
	local db = GetDB()
	if not db or not db.enabled then return end
	if not db.useAwesomeWotlk or not db.distanceAlpha then return end
	
	-- Cheap gates first: outside an arena there is nothing to update, and the
	-- autolos probe below walks every WorldFrame child.
	local instanceType = select(2, IsInInstance())
	if instanceType ~= "arena" then return end
	
	if not MAX_ARENA_ENEMIES then return end
	
	-- Check if autolos is enabled and working
	if not IsAutolosEnabled() or not IsAutolosWorking() then return end
	
	-- Update each arena frame
	for i = 1, MAX_ARENA_ENEMIES do
		local frame = _G["ArenaEnemyFrame" .. i]
		if frame and frame.unit and UnitExists(frame.unit) then
			local arenaGUID = UnitGUID(frame.unit)
			if arenaGUID then
				local nameplate = GetNamePlateByGUID(arenaGUID)
				local distanceValue = GetDistanceValue(nameplate)
				
				-- If distanceValue == 0 (<= 40 yards), set alpha to 1.0 (fully opaque)
				-- If distanceValue == 1 (> 40 yards), set alpha to 0.5 (50% transparent)
				local targetAlpha = (distanceValue == 0) and 1.0 or 0.5
				frame:SetAlpha(targetAlpha)
			else
				-- If no GUID, default to full opacity
				frame:SetAlpha(1.0)
			end
		end
	end
end

-- Initialize distance alpha update frame
local function InitializeDistanceAlphaUpdate()
	if distanceAlphaUpdateFrame then return end
	
	-- Clear cache when initializing
	ClearNameplateCache()
	
	distanceAlphaUpdateFrame = CreateFrame("Frame")
	distanceAlphaUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
		self.updateTime = (self.updateTime or 0) + elapsed
		-- Update every 0.1 seconds (10 times per second)
		if self.updateTime >= 0.1 then
			self.updateTime = 0
			UpdateArenaFrameDistanceAlpha()
		end
	end)
end

-- Cleanup distance alpha update frame
local function CleanupDistanceAlphaUpdate()
	if distanceAlphaUpdateFrame then
		distanceAlphaUpdateFrame:SetScript("OnUpdate", nil)
		distanceAlphaUpdateFrame = nil
	end
	
	-- Clear cache when cleaning up
	ClearNameplateCache()
	
	-- Reset all arena frame alphas to 1.0
	if MAX_ARENA_ENEMIES then
		for i = 1, MAX_ARENA_ENEMIES do
			local frame = _G["ArenaEnemyFrame" .. i]
			if frame then
				frame:SetAlpha(1.0)
			end
		end
	end
end

--------------------------------------------------------------------
-- Arena numbers on nameplates (RougeUI ArenaNumbers)
--------------------------------------------------------------------
local ARENA_NAME_UNITS = { "arena1", "arena2", "arena3", "arena4", "arena5" }
local NAMEPLATE_BORDER = "Interface\\Tooltips\\Nameplate-Border"
local NAMEPLATE_FLASH = "Interface\\TargetingFrame\\UI-TargetingFrame-Flash"
local arenaPlateFrame
local activeArenaPlates = {}
local arenaNameToUnit = {}
local arenaPlateChildCount = -1
local arenaNameScanElapsed = 0
local enpNameHooked = false
local arenaNumbersModuleActive = false
-- Never store addon state on Blizzard's protected arena unit buttons.  Even an
-- otherwise harmless custom field can taint a later combat-time visibility
-- update in Blizzard_ArenaUI.  Keep state in our own weak-key table instead.
local blizzardArenaNameState = setmetatable({}, { __mode = "k" })

local function ArenaNumbersOn()
	if not arenaNumbersModuleActive then return false end
	local db = GetDB()
	if not db or not db.enabled then return false end
	return db.arenaNumbers == 1 or db.arenaNumbers == true
end

local function ArenaNameplatesOn()
	if not ArenaNumbersOn() then return false end
	local db = GetDB()
	-- nil means enabled so profiles created before the split keep their old
	-- nameplate behaviour.
	return db.arenaNumbersNameplates == nil
		or db.arenaNumbersNameplates == 1
		or db.arenaNumbersNameplates == true
end

local function ArenaFramesOn()
	if not ArenaNumbersOn() then return false end
	local db = GetDB()
	return db.arenaNumbersArenaFrames == nil
		or db.arenaNumbersArenaFrames == 1
		or db.arenaNumbersArenaFrames == true
end

local function WipeArenaNameMap()
	for k in pairs(arenaNameToUnit) do
		arenaNameToUnit[k] = nil
	end
end

local function RefreshArenaNameMap()
	WipeArenaNameMap()
	if select(2, IsInInstance()) ~= "arena" then return end
	for i = 1, #ARENA_NAME_UNITS do
		local unit = ARENA_NAME_UNITS[i]
		if UnitExists(unit) then
			local name, realm = UnitName(unit)
			if name then
				arenaNameToUnit[name] = unit
				if realm and realm ~= "" then
					arenaNameToUnit[name .. "-" .. realm] = unit
				end
			end
		end
	end
end

local function ArenaIndexForName(name)
	if not name then return nil end
	local unit = arenaNameToUnit[name]
	if not unit and type(name) == "string" then
		unit = arenaNameToUnit[name:match("^([^-]+)")]
	end
	if not unit then return nil end
	return unit:match("^arena(%d+)$")
end

local function ArenaIndexForUnitFrame(frame, name)
	local unit = frame and (frame.unit or frame.UnitToken)
	local num = type(unit) == "string" and unit:match("^arena(%d+)$")
	if num then return num end

	local guid = frame and frame.guid
	if guid then
		for i = 1, #ARENA_NAME_UNITS do
			if UnitGUID(ARENA_NAME_UNITS[i]) == guid then
				return tostring(i)
			end
		end
	end

	num = ArenaIndexForName(name or (frame and frame.UnitName))
	if num then return num end

	-- Arena units can become available immediately before a nameplate update;
	-- refresh on demand instead of waiting for the one-second safety scan.
	RefreshArenaNameMap()
	return ArenaIndexForName(name or (frame and frame.UnitName))
end

function SarychUI:GetArenaNameplateDisplayName(frame, name)
	if not ArenaNameplatesOn() or select(2, IsInInstance()) ~= "arena" then
		return name
	end
	return ArenaIndexForUnitFrame(frame, name) or name
end

function SarychUI:GetArenaFrameDisplayName(unit, name)
	if not ArenaFramesOn() or select(2, IsInInstance()) ~= "arena" then
		return name
	end
	local num = type(unit) == "string" and unit:match("^arena(%d+)$")
	return num or ArenaIndexForName(name) or name
end

local function IsENPManagedPlate(plate)
	local unitFrame = plate and plate.UnitFrame
	if not unitFrame or not unitFrame.Name then return false end
	local E = _G.SarychUI_ElvUI_NamePlates
	local NP = E and E.GetModule and E:GetModule("NamePlates", true)
	if NP and NP.CreatedPlates and NP.CreatedPlates[plate] then
		return true
	end
	local frameName = unitFrame.GetName and unitFrame:GetName()
	return frameName and frameName:match("^ENP_NamePlate") ~= nil
end

local function RestorePlateName(plate)
	if not plate then return end
	if plate._suiOldName then
		-- ElvUI owns and deliberately hides the original Blizzard FontString.
		-- Showing it here was the source of the centered duplicate number/name.
		if IsENPManagedPlate(plate) then
			plate._suiOldName:Hide()
		else
			plate._suiOldName:SetAlpha(1)
		end
	end
	if plate._suiArenaName then
		plate._suiArenaName:Hide()
		plate._suiArenaName:SetText("")
	end
	plate._suiArenaFormatted = false
	plate._suiLastArenaText = nil
end

local function InitBlizzardPlate(plate)
	if plate._suiArenaInit then return end
	if IsENPManagedPlate(plate) then return end
	local _, border, _, _, _, _, name = plate:GetRegions()
	if not name or not name.GetObjectType or name:GetObjectType() ~= "FontString" then
		return
	end
	plate._suiArenaInit = true
	plate._suiOldName = name
	plate._suiBorder = border
	local fs = plate:CreateFontString(nil, "ARTWORK")
	fs:SetFont(STANDARD_TEXT_FONT, 12, "")
	fs:SetTextColor(1, 1, 1)
	if border then
		fs:SetPoint("BOTTOM", border, "TOP", 0, -15)
	else
		fs:SetPoint("BOTTOM", plate, "TOP", 0, -15)
	end
	fs:Hide()
	plate._suiArenaName = fs
end

local function UpdateBlizzardPlate(plate)
	if IsENPManagedPlate(plate) then
		RestorePlateName(plate)
		activeArenaPlates[plate] = nil
		return
	end
	if not plate._suiArenaInit then
		InitBlizzardPlate(plate)
	end
	if not plate._suiOldName or not plate._suiArenaName then return end

	local rawName = plate._suiOldName:GetText()
	local arenaNum = ArenaNameplatesOn() and select(2, IsInInstance()) == "arena" and ArenaIndexForName(rawName)
	if arenaNum then
		plate._suiOldName:SetAlpha(0)
		if plate._suiLastArenaText ~= arenaNum then
			plate._suiLastArenaText = arenaNum
			plate._suiArenaName:SetText(arenaNum)
		end
		if not plate._suiArenaFormatted then
			plate._suiArenaFormatted = true
			plate._suiArenaName:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
			plate._suiArenaName:ClearAllPoints()
			plate._suiArenaName:SetPoint("BOTTOM", plate, "TOP", 0, -15)
		end
		if not plate._suiArenaName:IsShown() then
			plate._suiArenaName:Show()
		end
	else
		RestorePlateName(plate)
	end
end

local function IsBlizzardNameplate(frame)
	if IsENPManagedPlate(frame) then return false end
	if not frame or frame.GetName and frame:GetName() then
		return false
	end
	local region = select(2, frame:GetRegions())
	if not region or region.GetObjectType and region:GetObjectType() ~= "Texture" then
		return false
	end
	local tex = region.GetTexture and region:GetTexture()
	return tex == NAMEPLATE_BORDER or tex == NAMEPLATE_FLASH
end

local function ApplyENPArenaName(frame)
	if not frame or not frame.Name then return end
	local displayName = SarychUI:GetArenaNameplateDisplayName(frame, frame.UnitName)
	if displayName and displayName ~= frame.Name:GetText() then
		frame.Name:SetText(displayName)
	end
end

local function HookENPArenaNames()
	if enpNameHooked then return end
	local E = _G.SarychUI_ElvUI_NamePlates
	if not E or not E.GetModule then return end
	local NP = E:GetModule("NamePlates", true)
	if not NP or not NP.Update_Name then return end
	enpNameHooked = true
	hooksecurefunc(NP, "Update_Name", function(_, frame)
		ApplyENPArenaName(frame)
	end)
end

local function RefreshENPArenaNames()
	local E = _G.SarychUI_ElvUI_NamePlates
	if not E or not E.GetModule then return end
	local NP = E:GetModule("NamePlates", true)
	if not NP then return end
	if NP.ForEachVisiblePlate and NP.Update_Name then
		NP:ForEachVisiblePlate("Update_Name")
	elseif NP.VisiblePlates then
		for frame in pairs(NP.VisiblePlates) do
			ApplyENPArenaName(frame)
		end
	end
end

local function UpdateAwesomePlates()
	if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
	local plates = C_NamePlate.GetNamePlates()
	if not plates then return end
	local replace = ArenaNameplatesOn() and select(2, IsInInstance()) == "arena"
	for i = 1, #plates do
		local np = plates[i]
		local uf = np and np.UnitFrame
		if uf then
			local nameFS = uf.name or uf.Name
			local num = replace and ArenaIndexForUnitFrame(uf, uf.UnitName)
			if num and nameFS and nameFS.SetText then
				local current = nameFS:GetText()
				if current and current ~= "" and current ~= num then
					uf._suiArenaOriginalName = current
				end
				nameFS:SetText(num)
				uf._suiArenaNumberApplied = true
			elseif uf._suiArenaNumberApplied and nameFS and nameFS.SetText then
				local original = uf.UnitName or uf._suiArenaOriginalName
				if original then nameFS:SetText(original) end
				uf._suiArenaNumberApplied = nil
				uf._suiArenaOriginalName = nil
			end
		end
	end
end

local function ArenaPlateOnUpdate(_, elapsed)
	if not ArenaNumbersOn() then
		return
	end

	if ArenaNameplatesOn() then
		local childCount = WorldFrame and WorldFrame.GetNumChildren and WorldFrame:GetNumChildren() or 0
		if childCount ~= arenaPlateChildCount then
			arenaPlateChildCount = childCount
			local n = CollectWorldChildren(WorldFrame:GetChildren())
			for i = 1, n do
				local plate = worldChildren[i]
				if plate and not activeArenaPlates[plate] and IsBlizzardNameplate(plate) then
					activeArenaPlates[plate] = true
					InitBlizzardPlate(plate)
				end
			end
		end
	end

	arenaNameScanElapsed = arenaNameScanElapsed + (elapsed or 0)
	if arenaNameScanElapsed >= 1 then
		arenaNameScanElapsed = 0
		RefreshArenaNameMap()
		RefreshENPArenaNames()
	end

	if select(2, IsInInstance()) == "arena" then
		if ArenaNameplatesOn() then
			for plate in pairs(activeArenaPlates) do
				if plate.IsShown and plate:IsShown() then
					UpdateBlizzardPlate(plate)
				end
			end
			UpdateAwesomePlates()
		end
	end
end

local function RestoreAllArenaPlates()
	for plate in pairs(activeArenaPlates) do
		RestorePlateName(plate)
	end
end

local function GetBlizzardArenaName(frame)
	if not frame then return nil end
	if frame.name and frame.name.SetText then return frame.name end
	if frame.Name and frame.Name.SetText then return frame.Name end
	local frameName = frame.GetName and frame:GetName()
	local name = frameName and _G[frameName .. "Name"]
	return name and name.SetText and name or nil
end

local function ApplyBlizzardArenaFrameName(frame)
	if not frame then return end
	local name = GetBlizzardArenaName(frame)
	if not name then return end
	local state = blizzardArenaNameState[frame]
	if not state then
		state = {}
		blizzardArenaNameState[frame] = state
	end
	local frameName = frame.GetName and frame:GetName()
	local unit = frame.unit
	local num = type(unit) == "string" and unit:match("^arena(%d+)$")
	if not num and frameName then
		num = frameName:match("^ArenaEnemyFrame(%d+)$")
		if num then unit = "arena" .. num end
	end
	local shouldNumber = ArenaFramesOn()
		and select(2, IsInInstance()) == "arena"
		and num

	if shouldNumber then
		local current = name:GetText()
		if current and current ~= "" and current ~= num then
			state.originalName = current
		end
		name:SetText(num)
		state.numberApplied = true
	elseif state.numberApplied then
		local original = (unit and UnitName(unit)) or state.originalName
		if original then name:SetText(original) end
		state.numberApplied = nil
		state.originalName = nil
	end
end

local function RefreshBlizzardArenaFrameNames()
	for i = 1, (MAX_ARENA_ENEMIES or 5) do
		ApplyBlizzardArenaFrameName(_G["ArenaEnemyFrame" .. i])
	end
end

local function HookBlizzardArenaFrameNames()
	-- Names are applied on our own frame, one tick after Blizzard writes them.
	-- A hook on ArenaEnemyFrame_UpdatePlayer taints its combat Show().
	if module.ScheduleSecureFramePaint then
		module:ScheduleSecureFramePaint()
	end
end

function module:ScheduleSecureFramePaint()
	if not self._securePaintFrame then
		local paint = CreateFrame("Frame")
		paint:Hide()
		paint:SetScript("OnUpdate", function(frame)
			frame:Hide()
			if not MAX_ARENA_ENEMIES then return end
			local db = GetDB()
			local colorOn = (db == nil or db.classColorHP == nil or db.classColorHP == true)
			if colorOn then
				local i
				for i = 1, MAX_ARENA_ENEMIES do
					ColorArenaHealthByClass(_G["ArenaEnemyFrame" .. i])
				end
			end
			RefreshBlizzardArenaFrameNames()
		end)
		self._securePaintFrame = paint
	end
	self._securePaintFrame:Show()
end

local function RefreshAllArenaNumberTargets()
	RefreshENPArenaNames()
	UpdateAwesomePlates()
	RefreshBlizzardArenaFrameNames()
end

--------------------------------------------------------------------
-- Hide "Group/Raid" titles (RougeUI HideTitles), only in arena
--------------------------------------------------------------------
local groupTitlesFrame
local groupTitlesHooked = false

local function HideGroupTitlesOn()
	local db = GetDB()
	if not db or not db.enabled then return false end
	return db.hideGroupRaidText == 1 or db.hideGroupRaidText == true
end

local function ShouldHideGroupTitles()
	return HideGroupTitlesOn() and select(2, IsInInstance()) == "arena"
end

local function SetTitleAlpha(frame, alpha)
	if frame and frame.SetAlpha then
		frame:SetAlpha(alpha)
	end
end

local function ApplyGroupTitleVisibility()
	local hide = ShouldHideGroupTitles()
	local alpha = hide and 0 or 1
	SetTitleAlpha(_G.CompactPartyFrameTitle, alpha)
	if CompactPartyFrame then
		SetTitleAlpha(CompactPartyFrame.title, alpha)
	end
	for i = 1, 8 do
		SetTitleAlpha(_G["CompactRaidGroup" .. i .. "Title"], alpha)
	end
	if PlayerFrameGroupIndicator then
		if hide then
			PlayerFrameGroupIndicator:Hide()
		elseif type(PlayerFrame_UpdateGroupIndicator) == "function" then
			PlayerFrame_UpdateGroupIndicator()
		end
	end
end

local function HookGroupTitles()
	if groupTitlesHooked then return end
	groupTitlesHooked = true
	if PlayerFrameGroupIndicator then
		hooksecurefunc(PlayerFrameGroupIndicator, "Show", function(self)
			if ShouldHideGroupTitles() then
				self:Hide()
			end
		end)
	end
	if CompactRaidGroup_GenerateForGroup then
		hooksecurefunc("CompactRaidGroup_GenerateForGroup", function()
			ApplyGroupTitleVisibility()
		end)
	end
	if CompactPartyFrame_Generate then
		hooksecurefunc("CompactPartyFrame_Generate", function()
			ApplyGroupTitleVisibility()
		end)
	end
end

function module:UpdateGroupTitles()
	HookGroupTitles()
	ApplyGroupTitleVisibility()
	if HideGroupTitlesOn() then
		if not groupTitlesFrame then
			groupTitlesFrame = CreateFrame("Frame")
			groupTitlesFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
			groupTitlesFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
			groupTitlesFrame:SetScript("OnEvent", function()
				ApplyGroupTitleVisibility()
			end)
		end
		groupTitlesFrame:Show()
	elseif groupTitlesFrame then
		groupTitlesFrame:Hide()
	end
end

function module:UpdateArenaNameplates()
	HookENPArenaNames()
	HookBlizzardArenaFrameNames()
	RefreshArenaNameMap()
	if ArenaNumbersOn() then
		if not arenaPlateFrame then
			arenaPlateFrame = CreateFrame("Frame")
			arenaPlateFrame:SetScript("OnUpdate", ArenaPlateOnUpdate)
			arenaPlateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
			arenaPlateFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
			arenaPlateFrame:RegisterEvent("ARENA_OPPONENT_UPDATE")
			arenaPlateFrame:RegisterEvent("UNIT_NAME_UPDATE")
			arenaPlateFrame:SetScript("OnEvent", function(_, event, unit)
				-- Blizzard_ArenaUI can be load-on-demand, so its updater may not
				-- exist yet during SarychUI's initial Enable call.
				HookBlizzardArenaFrameNames()
				if event == "UNIT_NAME_UPDATE" and unit
					and (type(unit) ~= "string" or not unit:match("^arena%d+$")) then
					return
				end
				RefreshArenaNameMap()
				if select(2, IsInInstance()) ~= "arena" then
					RestoreAllArenaPlates()
				end
				RefreshAllArenaNumberTargets()
			end)
		end
		arenaPlateFrame:Show()
		arenaPlateChildCount = -1
		if not ArenaNameplatesOn() then
			RestoreAllArenaPlates()
		end
		RefreshAllArenaNumberTargets()
	else
		if arenaPlateFrame then
			arenaPlateFrame:Hide()
		end
		RestoreAllArenaPlates()
		RefreshAllArenaNumberTargets()
		WipeArenaNameMap()
	end
end

--------------------------------------------------------------------
-- TAB remapping (RougeUI retab): arena/BG TAB -> enemy players, not pets/mobs
--------------------------------------------------------------------
local RETAB_KEY = "TAB"
local RETAB_BUTTON_NAME = "SarychUITabber"
local retabButton
local retabFrame
local retabModuleActive = false

local function RetabOn()
	if not retabModuleActive then return false end
	local db = GetDB()
	if not db or not db.enabled then return false end
	return db.retab == 1 or db.retab == true
end

local function ApplyRetab()
	if InCombatLockdown() then
		if retabFrame then
			retabFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		end
		return
	end
	if not retabButton then return end
	local _, instanceType = IsInInstance()
	if RetabOn() and (instanceType == "arena" or instanceType == "pvp") then
		SetOverrideBindingClick(retabButton, true, RETAB_KEY, RETAB_BUTTON_NAME)
	else
		ClearOverrideBindings(retabButton)
	end
end

function module:UpdateRetab()
	if not retabButton then
		retabButton = CreateFrame("Button", RETAB_BUTTON_NAME, nil, "SecureActionButtonTemplate")
		retabButton:RegisterForClicks("AnyDown")
		retabButton:SetAttribute("type", "macro")
		if SecureHandlerWrapScript then
			SecureHandlerWrapScript(retabButton, "OnClick", retabButton, [[
				if down then
					self:SetAttribute("macrotext","/targetenemyplayer\n/targetlasttarget [noexists]")
				end]])
		end
	end
	if not retabFrame then
		retabFrame = CreateFrame("Frame")
		retabFrame:SetScript("OnEvent", function(self, event)
			if event == "PLAYER_REGEN_ENABLED" then
				self:UnregisterEvent("PLAYER_REGEN_ENABLED")
			end
			ApplyRetab()
		end)
	end
	if RetabOn() then
		retabFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		retabFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		retabFrame:Show()
	else
		retabFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
		retabFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
	end
	ApplyRetab()
end

-- Apply position and scale based on DB and DragMode
function module:ApplySettings()
	self:UpdateArenaNameplates()
	self:UpdateGroupTitles()
	self:UpdateRetab()
	local db = GetDB()
	if not db or not db.enabled then return end
	
	-- Проверяем, не происходит ли сейчас drag или только что был drag - если да, не применяем позицию
	-- Это предотвращает перезапись позиции во время drag и сразу после него
	self:ApplyContainerPosition()
	
	if ArenaEnemyFrames and not (InCombatLockdown and InCombatLockdown()) then
		ArenaEnemyFrames:SetScale(db.scale or 1.0)
	end
	self:ApplyFrameSpacing()
	self:ClampArenaToScreen()

	-- Apply class coloring immediately according to setting
	self:ApplyClassColoring()
	
	-- Initialize or cleanup distance alpha update based on settings
	if db.useAwesomeWotlk and db.distanceAlpha then
		InitializeDistanceAlphaUpdate()
	else
		CleanupDistanceAlphaUpdate()
	end
	
	-- Если тестовый режим активен, обновляем отображение иконок тринкетов
	if db.testMode and db.testMode > 0 and db.Trinkets then
		self:ShowTestTrinkets(db.testMode, db.Trinkets)
		local abilities = SarychUI.extensions and SarychUI.extensions.party_abilities
		if abilities and abilities.RefreshConfig then abilities:RefreshConfig() end
		if SarychUI.DragMode then SarychUI.DragMode:RefreshDragOverlay("arenaContainer") end
	end
	
	-- Общий режим перемещения и общая сетка.
	local showDrag = db.showDragFrame == 1
	local showGrid = db.showGrid == 1
	
	-- Проверяем что arenaContainer существует
	if not arenaContainer then
		return
	end
	
	-- Вычисляем дефолтную позицию если еще не вычислена
	if not arenaDefaultPosition then
		self:CalculateDefaultContainerPosition()
	end
	
	if SarychUI.DragMode then
		self:RegisterDrag()
		SarychUI.DragMode:EnableEditMode("arenaContainer", showDrag, showDrag, showGrid)
		SarychUI.DragMode:ShowGrid(showGrid and showDrag)
	end
end

-- The container is an unprotected position editor; arena unit buttons stay in
-- Blizzard's protected hierarchy.
local function ArenaDragBounds()
	local parentScale = UIParent:GetEffectiveScale()
	if not parentScale or parentScale <= 0 then return end
	local left, bottom, right, top
	local function Include(frame)
		if not frame then return end
		local l, b, r, t = frame:GetLeft(), frame:GetBottom(), frame:GetRight(), frame:GetTop()
		local scale = frame:GetEffectiveScale()
		if not (l and b and r and t and scale and scale > 0 and r > l and t > b) then return end
		local ratio = scale / parentScale
		l, b, r, t = l * ratio, b * ratio, r * ratio, t * ratio
		left = left and math.min(left, l) or l
		bottom = bottom and math.min(bottom, b) or b
		right = right and math.max(right, r) or r
		top = top and math.max(top, t) or t
	end

	if arenaTestContainer and arenaTestContainer:IsShown() then
		for i = 1, 5 do
			local frame = arenaTestFrames[i]
			if frame and frame:IsVisible() then
				Include(frame)
				if arenaTestCastbars[i] and arenaTestCastbars[i]:IsShown() then Include(arenaTestCastbars[i]) end
				for _, suffix in ipairs({ "Trinket1", "Racial" }) do
					local icon = _G["SarychUIArenaTestTrinket" .. i .. suffix]
					if icon and icon:IsShown() then Include(icon) end
				end
			end
		end
	else
		for i = 1, (MAX_ARENA_ENEMIES or 5) do
			local frame = _G["ArenaEnemyFrame" .. i]
			if frame and frame:IsShown() then Include(frame) end
		end
	end
	-- Keep the left snap corner fixed; trim only the right edge of the editor.
	return left, bottom, right and right - 20, top
end

function module:RegisterDrag()
	if not arenaContainer or not SarychUI.DragMode
		or SarychUI.DragMode:GetFrameData("arenaContainer") then return end
	SarychUI.DragMode:RegisterFrame("arenaContainer", arenaContainer, {
		dragText = "Арена",
		dragPoint = "TOP",
		dragOffsetX = -24,
		dragOffsetY = 3,
		dragBoundsOffsetY = 12,
		-- Fallback based on five 102x32 preview frames with 20px gaps.
		dragWidth = 82,
		dragHeight = 240,
		getDragBounds = ArenaDragBounds,
		preservePositionOnDisable = true,
		getPoint = function()
			local point, _, relativePoint, x, y = arenaContainer:GetPoint()
			return { point or "RIGHT", UIParent, relativePoint or "RIGHT", x or 0, y or 0 }
		end,
		onPositionChanged = function(point, relativePoint, x, y)
			local db = GetDB(); if not db then return end
			db.arenaA, db.arenaR, db.arenaX, db.arenaY = point, relativePoint, x, y
			module:PlaceFirstArenaFrame()
			module:ClampArenaToScreen()
			local panel = SarychUI.PositionDragPanel
			if panel and panel.OnDragPosition then
				panel:OnDragPosition("arenaContainer", db.arenaX, db.arenaY, db.arenaA, db.arenaR)
			end
			if db.testMode and db.testMode > 0 then
				local updateFrame = CreateFrame("Frame")
				updateFrame:SetScript("OnUpdate", function(self)
					self:SetScript("OnUpdate", nil)
					if module.Test then module:Test(db.testMode) end
				end)
			end
		end,
	})
end

-- Public API used by options
function module:SetScale(value)
	local db = GetDB(); if not db then return end
	value = tonumber(value) or 1.0
	db.scale = value
	if ArenaEnemyFrames and not (InCombatLockdown and InCombatLockdown()) then
		ArenaEnemyFrames:SetScale(value)
	end
	self:PlaceFirstArenaFrame()
	self:ClampArenaToScreen()
	if SarychUI.DragMode then
		SarychUI.DragMode:RefreshDragOverlay("arenaContainer")
	end
end

-- Lifecycle
function module:Enable()
	arenaNumbersModuleActive = true
	retabModuleActive = true
	self:UpdateArenaNameplates()
	self:UpdateGroupTitles()
	self:UpdateRetab()
	local db = GetDB(); if not db or not db.enabled then return end
	
	-- Сбрасываем тестовый режим при загрузке/перезагрузке
	if db.testMode and db.testMode > 0 then
		db.testMode = 0
		-- Do not call Hide() on Blizzard arena unit buttons here.  A reload clears
		-- the preview by itself, while touching protected visibility would taint
		-- the first combat update.
	end
	
    self:InitializeContainer()
	self:RegisterDrag()
	self:ApplySettings()
    
    -- sArena-like trinkets lifecycle
    module.Trinkets:RegisterEvent("PLAYER_ENTERING_WORLD")
    module.Trinkets:RegisterEvent("PLAYER_LEAVING_WORLD")
    module.Trinkets:RegisterEvent("ARENA_OPPONENT_UPDATE")
    module.Trinkets:Initialize()

	if not eventFrame then
		eventFrame = CreateFrame("Frame")
		eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
		eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
			eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
			eventFrame:RegisterEvent("UI_SCALE_CHANGED")
		eventFrame:RegisterEvent("ADDON_LOADED")
		eventFrame:RegisterEvent("ARENA_OPPONENT_UPDATE")
		eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
		eventFrame:SetScript("OnEvent", function(_, event, addonName)
			if event == "PLAYER_REGEN_ENABLED" then
				eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
				self:ApplyFrameSpacing()
				return
			end
			if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
				self:ApplyContainerPosition()
				self:ClampArenaToScreen()
				return
			end
			if event == "ARENA_OPPONENT_UPDATE"
				or (event == "UNIT_NAME_UPDATE" and type(addonName) == "string" and addonName:match("^arena%d+$")) then
				self:ScheduleSecureFramePaint()
				return
			end
			if event == "ADDON_LOADED" then
				if addonName == "Blizzard_ArenaUI" then
					self:InitializeContainer()
					self:ScheduleSecureFramePaint()
					module.Trinkets:RefreshIcons()
				end
				return
			end
			if event == "PLAYER_ENTERING_WORLD" then
				-- Сбрасываем тестовый режим при входе в мир
				local db = GetDB()
				if arenaTestContainer and arenaTestContainer:IsShown() then
					self:HideArenaEnemyFrames()
				end
				if db and db.testMode and db.testMode > 0 then
					db.testMode = 0
				end
				
				local instanceType = select(2, IsInInstance())
				if instanceType == "arena" then
					-- Frames survive zoning.  Re-apply only the out-of-combat hierarchy
					-- and position; never Hide/Show them or call Blizzard's updater.
					self:InitializeContainer()
				else
					-- Cleanup distance alpha when leaving arena
					CleanupDistanceAlphaUpdate()
				end
			elseif event == "PLAYER_LEAVING_WORLD" then
				-- Blizzard_ArenaUI owns protected frame visibility across zoning.
				CleanupDistanceAlphaUpdate()
			elseif event == "ZONE_CHANGED_NEW_AREA" then
				-- Check if we're still in arena
				local instanceType = select(2, IsInInstance())
				if instanceType ~= "arena" then
					CleanupDistanceAlphaUpdate()
				else
					-- Clear cache when entering arena (new opponents)
					ClearNameplateCache()
				end
			end
		end)
	end
end

function module:Disable()
	arenaNumbersModuleActive = false
	self:HideArenaEnemyFrames()
	-- Shared DragMode cleanup.
	if SarychUI.DragMode then
		SarychUI.DragMode:EnableEditMode("arenaContainer", false, false, false)
		SarychUI.DragMode:UnregisterFrame("arenaContainer")
	end
	-- Events
	if eventFrame then
		eventFrame:UnregisterAllEvents()
		eventFrame:SetScript("OnEvent", nil)
		eventFrame = nil
	end
	
	-- Restore arena frames to default Blizzard state before removing container
	self:RestoreArenaFrames()
	
	-- Container
	if arenaContainer then
		arenaContainer:Hide()
		arenaContainer:SetParent(nil)
		arenaContainer = nil
	end
	
	-- Trinkets cleanup
	if module.Trinkets then
		module.Trinkets._lastReset = "Disable"
		module.Trinkets:DeleteTrinketIcons()
		module.Trinkets:UnregisterAllEvents()
	end
	
	-- Cleanup distance alpha update
	CleanupDistanceAlphaUpdate()

	if arenaPlateFrame then
		arenaPlateFrame:Hide()
	end
	RestoreAllArenaPlates()
	RefreshAllArenaNumberTargets()
	WipeArenaNameMap()
	if groupTitlesFrame then
		groupTitlesFrame:Hide()
	end
	ApplyGroupTitleVisibility()
	retabModuleActive = false
	if retabFrame then
		retabFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
		retabFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
	end
	ApplyRetab()
end

function module:RefreshConfig()
	self:Disable()
	self:Enable()
end
