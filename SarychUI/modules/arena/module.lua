-- SarychUI Arena Module
-- Arena enemy frames positioning, scaling and testing (based on sArena behavior)

local moduleName = "arena"
local module = {}

-- Register module
SarychUI:RegisterModule(moduleName, module)

-- Local references
local L = SarychUI.L

-- Local drag mode для arena
-- Загружается из modules\arena\drag_mode.lua (добавлен в TOC перед module.lua)
local ArenaDragMode = SarychUI_ArenaDragMode

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
local distanceAlphaUpdateFrame = nil
local arenaTestContainer = nil
local arenaTestFrames = {}
-- Cache for nameplate lookups by GUID
local nameplateCache = {}
local nameplateCacheTime = {}

-- ============================================
-- sArena Trinkets logic (ported with minimal changes)
-- ============================================

module.Trinkets = CreateFrame("Frame")
local trinketSuffixes = {"Trinket1", "Trinket2", "Trinket3", "Trinket4"}

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
    ["None"] = {id = nil, icon = "Interface\\Icons\\inv_misc_questionmark", cd = 0},
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
    else
        return "Interface\\Icons\\inv_misc_questionmark"
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
    trinket.Icon.Texture:SetAllPoints()
    trinket.Icon.Texture:SetTexture(texture)
    trinket.Icon.Texture:SetTexCoord(0, 1, 0, 1)

    -- Keep the artwork attached to its cooldown. Reparenting an all-points
    -- child to UIParent makes it fill UIParent instead of the 26px icon.
    trinket.Icon:SetAlpha(1)
    trinket:Show()

    -- CooldownFrame_SetTimer hides a Cooldown with no active timer. Keep that
    -- sweep separate from the always-visible icon and its UIParent holder.
    trinket.Cooldown = CreateFrame("Cooldown", nil, trinket)
    trinket.Cooldown:SetAllPoints(trinket)
    trinket.Cooldown:SetFrameLevel(trinket:GetFrameLevel() + 1)
    if trinket.Cooldown.SetDrawEdge then trinket.Cooldown:SetDrawEdge(true) end
    trinket.Cooldown:Hide()
    return trinket
end

function module.Trinkets:CreateNonHumanIcons(frame, id, race)
    if not racialSpells[race] then race = "None" end
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
    local race = ResolveArenaRace(unit)
    if not racialSpells[race] then race = "None" end
    local previous = self._iconRace and self._iconRace[id]
    local guid = UnitGUID(unit)
    local priorGUID = self._iconGUID and self._iconGUID[id]
    local existing = self[unit .. "Trinket1"] or self[unit .. "Trinket2"] or self[unit .. "Trinket4"]

    -- A disappearing unit can make UnitRace unavailable. Keep the known
    -- race and existing cooldown until a genuine replacement is identified.
    if race == "None" and previous then race = previous end
    if previous == race and existing and (not guid or not priorGUID or guid == priorGUID) then
        if guid and not priorGUID then self._iconGUID[id] = guid end
        for _, suffix in ipairs(trinketSuffixes) do
            local icon = self[unit .. suffix]
            if icon and not icon:IsShown() then icon:Show() end
        end
        return
    end

    if guid and priorGUID and guid ~= priorGUID then
        self:DeleteTrinketIcons(id)
        previous = nil
    end

    if previous and previous ~= "Human" and race ~= "Human" then
        local trinket = self[unit .. "Trinket1"]
        local racial = self[unit .. "Trinket2"]
        if trinket then trinket.Icon.Texture:SetTexture(self:GetTrinketTextureByRaceAndFaction(race)) end
        if racial then racial.Icon.Texture:SetTexture(racialSpells[race].icon) end
    else
        if previous then self:DeleteTrinketIcons(id) end
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
        return
    end
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("UNIT_NAME_UPDATE")
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
	frame:ClearAllPoints()
	frame:SetPoint("TOP", UIParent, "BOTTOMLEFT", x, y - 8)
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

	-- Keep Blizzard's protected hierarchy intact. Frames 2-5 and all pets
	-- retain their original relative anchors and visibility parent.
	self:PlaceFirstArenaFrame()
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
    if ArenaDragMode then
        if ArenaDragMode:IsMoving() or ArenaDragMode:JustDragged() then
            return
        end
    end
    
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

local function EnsureArenaTestFrames()
	if arenaTestContainer then return end
	arenaTestContainer = CreateFrame("Frame", "SarychUIArenaTestContainer", UIParent)
	arenaTestContainer:SetSize(180, 252)

	for i = 1, 5 do
		local frame = CreateFrame("Frame", "SarychUIArenaTestFrame" .. i, arenaTestContainer)
		frame:SetSize(102, 32)
		if i == 1 then
			frame:SetPoint("TOP", arenaTestContainer, "TOP", 0, 0)
		else
			frame:SetPoint("TOP", arenaTestFrames[i - 1], "BOTTOM", 0, -20)
		end

		local portrait = frame:CreateTexture(nil, "BACKGROUND")
		portrait:SetSize(30, 30)
		portrait:SetPoint("TOPRIGHT", -1, -4)
		portrait:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
		local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS.WARRIOR
		if coords then portrait:SetTexCoord(unpack(coords)) end

		local health = CreateFrame("StatusBar", nil, frame)
		health:SetSize(70, 8)
		health:SetPoint("TOPLEFT", 3, -11)
		health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		health:SetMinMaxValues(0, 1)
		health:SetValue(0.82)
		health:SetStatusBarColor(0.78, 0.61, 0.43)

		local mana = CreateFrame("StatusBar", nil, frame)
		mana:SetSize(70, 7)
		mana:SetPoint("TOPLEFT", 3, -19)
		mana:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		mana:SetMinMaxValues(0, 1)
		mana:SetValue(0.65)
		mana:SetStatusBarColor(0.2, 0.35, 0.95)

		local chrome = frame:CreateTexture(nil, "ARTWORK")
		chrome:SetSize(102, 32)
		chrome:SetPoint("TOPLEFT", 0, -2)
		chrome:SetTexture("Interface\\ArenaEnemyFrame\\UI-ArenaTargetingFrame")
		chrome:SetTexCoord(0.0, 0.796, 0.0, 0.5)

		local name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		name:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 3, 24)
		name:SetText("Arena " .. i)

		frame:Hide()
		arenaTestFrames[i] = frame
	end
	arenaTestContainer:Hide()
end

function module:HideArenaEnemyFrames()
	-- This function now hides only SarychUI's unprotected preview.  Calling
	-- Hide() or Blizzard event/update functions on ArenaEnemyFrame* taints the
	-- visibility that Blizzard must change during combat.
	if arenaTestContainer then arenaTestContainer:Hide() end
end

function module:Test(numOpponents)
	numOpponents = tonumber(numOpponents)
	if not numOpponents or numOpponents < 1 or numOpponents > 5 then return end

	self:ApplyContainerPosition()
	EnsureArenaTestFrames()
	arenaTestContainer:ClearAllPoints()
	if arenaContainer then
		arenaTestContainer:SetPoint("TOP", arenaContainer, "BOTTOM", 0, -8)
	else
		arenaTestContainer:SetPoint("RIGHT", UIParent, "RIGHT", -311, 131)
	end
	arenaTestContainer:SetScale(GetSetting("scale", 1.0))
	for i = 1, 5 do
		if i <= numOpponents then arenaTestFrames[i]:Show() else arenaTestFrames[i]:Hide() end
	end
	arenaTestContainer:Show()
	
	-- Show trinket and racial icons in test mode (with delay to ensure frames are set up)
	local db = GetDB()
	if db and db.Trinkets then
		local updateFrame = CreateFrame("Frame")
		local checkCount = 0
		updateFrame:SetScript("OnUpdate", function(self, elapsed)
			checkCount = checkCount + 1
			if checkCount >= 2 then
				self:SetScript("OnUpdate", nil)
				if module.ShowTestTrinkets then
					module:ShowTestTrinkets(numOpponents, db.Trinkets)
				end
			end
		end)
	end
end

-- Show trinket and racial icons for test mode
function module:ShowTestTrinkets(numOpponents, trinketsDB)
	if not trinketsDB then return end
	if InCombatLockdown() then return end
	
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
		
		-- Handle trinket icon
		local trinket = self:GetOrCreateTestTrinket(frame, i, "Trinket1")
		if trinket then
			if trinketsEnabled then
				trinket:SetScale(scale)
				trinket.Icon.Texture:SetTexture(trinketTexture)
				trinket.Icon:Show()
				trinket:Show()
				trinket:SetCooldown(0, -1)
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
				racial:SetScale(scale)
				racial.Icon.Texture:SetTexture(racialTexture)
				racial.Icon:Show()
				racial:Show()
				racial:SetCooldown(0, -1)
				
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
		trinket = CreateFrame("Cooldown", trinketName, frame)
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
		trinket.Icon.Texture:SetAllPoints()
		trinket.Icon.Texture:SetTexCoord(0, 1, 0, 1)
		
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
	local shouldApplyPosition = true
	if ArenaDragMode then
		if ArenaDragMode:IsMoving() or ArenaDragMode:JustDragged() then
			shouldApplyPosition = false
		end
	end
	
	-- Применяем позицию только если не происходит drag
	if shouldApplyPosition then
		self:ApplyContainerPosition()
	end
	
	if ArenaEnemyFrames and not (InCombatLockdown and InCombatLockdown()) then
		ArenaEnemyFrames:SetScale(db.scale or 1.0)
	end

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
		local updateFrame = CreateFrame("Frame")
		updateFrame:SetScript("OnUpdate", function(self)
			self:SetScript("OnUpdate", nil)
			if module.ShowTestTrinkets then
				module:ShowTestTrinkets(db.testMode, db.Trinkets)
			end
		end)
	end
	
	-- Используем локальный ArenaDragMode или fallback на глобальный
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
	
	-- Пробуем использовать локальный ArenaDragMode
	if ArenaDragMode and arenaContainer then
		-- Включаем/отключаем режим редактирования
		if showDrag then
			ArenaDragMode:Enable(arenaContainer, {
				dragText = "Арена",
				dragPoint = "TOPRIGHT",
				dragOffsetX = 0,
				dragOffsetY = 2.5,
				dragWidth = 280,
				dragHeight = 225,
			}, showDrag, showGrid, function(point, relativePoint, xOfs, yOfs)
				-- Callback при изменении позиции
				local db = GetDB(); if not db then return end
				
				-- Сохраняем абсолютные координаты как есть
				db.arenaA = point
				db.arenaR = relativePoint
				db.arenaX = xOfs
				db.arenaY = yOfs
				module:PlaceFirstArenaFrame()
				
				-- If test mode is active, re-run to reflect new anchor instantly
				if db.testMode and db.testMode > 0 then
					local updateFrame = CreateFrame("Frame")
					updateFrame:SetScript("OnUpdate", function(self)
						self:SetScript("OnUpdate", nil)
						if module.Test then
							module:Test(db.testMode)
						end
					end)
				end
			end)
		else
			ArenaDragMode:Disable(arenaContainer)
		end
		
		ArenaDragMode:ShowGrid(showGrid and showDrag)
	else
		-- Fallback на глобальный DragMode если локальный не загрузился
		if SarychUI.DragMode then
			-- Регистрируем фрейм если еще не зарегистрирован
			if not SarychUI.DragMode:GetFrameData("arenaContainer") then
				self:RegisterDrag()
			end
			
			SarychUI.DragMode:EnableEditMode("arenaContainer", showDrag, showDrag, showGrid)
			SarychUI.DragMode:ShowGrid(showGrid and showDrag)
		end
	end
end

-- Register container in DragMode system (legacy - используется локальный ArenaDragMode)
function module:RegisterDrag()
	-- Локальный ArenaDragMode инициализируется в ApplySettings
	-- Эта функция оставлена для совместимости
	if not arenaContainer then return end
	
	-- Вычисляем дефолтную позицию если еще не вычислена
	if not arenaDefaultPosition then
		self:CalculateDefaultContainerPosition()
	end
end

-- Public API used by options
function module:SetScale(value)
	local db = GetDB(); if not db then return end
	value = tonumber(value) or 1.0
	db.scale = value
	if ArenaEnemyFrames and not (InCombatLockdown and InCombatLockdown()) then
		ArenaEnemyFrames:SetScale(value)
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
		eventFrame:RegisterEvent("ADDON_LOADED")
		eventFrame:RegisterEvent("ARENA_OPPONENT_UPDATE")
		eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
		eventFrame:SetScript("OnEvent", function(_, event, addonName)
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
	if arenaTestContainer then
		arenaTestContainer:Hide()
	end
	-- DragMode cleanup (локальный ArenaDragMode)
	if ArenaDragMode and arenaContainer then
		ArenaDragMode:Disable(arenaContainer)
	end
	-- Fallback на глобальный DragMode
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
