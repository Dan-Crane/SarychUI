-- Native Party Abilities extension. Other players' cooldowns are estimates from observed casts.
local SUI = SarychUI
local Glow = SUI.PlatesAurasGlow
local extension = SUI:RegisterExtension("party_abilities", {})
local eventFrame = CreateFrame("Frame")
local units, active, icons = {}, {}, {}
local learnedDurations, talentRetry = {}, {}
local liveAuras = {}
local enabled, elapsed = false, 0
local trackingEvents = false
local lastDB
local lastInstanceKind
local talentLib = LibStub and LibStub("LibGroupTalents-1.0", true)
local cooldownCommPrefix = "SUI_PACD"
local resetters = {
	[23989] = { 19503, 60192, 13809, 14311, 19574, 34490, 19263, 53271, 49012 }, -- Readiness
	[14185] = { 14177, 26669, 11305, 26889, 36554 }, -- Preparation (Kick/Dismantle need glyph)
	[11958] = { 42931, 42917, 43012, 43039, 45438, 31687, 44572, 44545, 12472 }, -- Cold Snap
}
local shared = {
	{ 16979, 49376 }, -- Feral Charge
	{ 49231, 49233, 49236 }, -- Shocks
	{ 60192, 14311, 13809 }, -- Freezing traps
	{ 49067, 49056 }, -- Fire traps
	{ 34600 }, -- Snake Trap
	{ 43010, 43012 }, -- Wards
}
-- ATT: using one of these also puts the others on a shorter shared cooldown.
local linkedUse = {
	Human = { cooldown = 45, 59752, 42292 },
	Scourge = { cooldown = 45, 7744, 42292 },
	Dwarf = { cooldown = 45, 20594, 42292 },
}

local function DB()
	return SUI.db and SUI.db.profile and SUI.db.profile.modules and SUI.db.profile.modules.party_abilities
end

local function ApplyItemMeta(data, id)
	local meta = SUI.PartyAbilityItems and SUI.PartyAbilityItems[id]
	if not data or not meta then return end
	data.item = meta.item
	data.trinket = meta.trinket and true or nil
	data.itemName = meta.name
	data.icon = meta.icon or data.icon
	if meta.item then GetItemInfo(meta.item) end
end

local function SpellRecord(class, index, entry)
	local tab, talentIndex = entry[3], entry[4]
	local data = {
		class = class, cooldown = entry[2],
		talent = tab and true or nil, talentTab = tab, talentIndex = talentIndex,
		faction = entry[5], race = entry[6], excludeRace = entry[7], icon = entry[8],
		order = index * 10, enabled = true, glowWhen = "cooldown",
	}
	ApplyItemMeta(data, entry[1])
	return data
end

local function Seed(db)
	if not db then return end
	db.spells = db.spells or {}
	for _, id in ipairs({ 308726, 310773, 310787, 316161, 316465, 90101, 90105, 90108, 90110, 90112, 90113, 90115 }) do
		db.spells[id] = nil
	end
	local refreshList = (db.spellListVersion or 0) < 3
	for class, list in pairs(SUI.PartyAbilityPresets) do
		local fill = refreshList or not db.seeded or (class == "OTHER" and not db.otherSeeded)
		if fill then
			for index, entry in ipairs(list) do
				local id = entry[1]
				local data = db.spells[id]
				if not data then
					db.spells[id] = SpellRecord(class, index, entry)
				else
					data.class = class
					if entry[3] then
						data.talent, data.talentTab, data.talentIndex = true, entry[3], entry[4]
					end
					if class == "OTHER" then
						data.race, data.excludeRace, data.icon = entry[6], entry[7], entry[8] or data.icon
					end
					ApplyItemMeta(data, id)
				end
			end
		end
	end
	if refreshList then
		for id, data in pairs(db.spells) do ApplyItemMeta(data, id) end
	end
	db.seeded = true
	db.otherSeeded = true
	db.spellListVersion = 3
end

function extension:ResetSpellDefaults()
	local db = DB()
	if not db then return end
	local previous = db.spells or {}
	local baseline = { spells = {} }
	Seed(baseline)
	for id, data in pairs(baseline.spells) do
		local saved = previous[id]
		if saved then
			for _, key in ipairs({ "cooldown", "order", "enabled", "size", "highlight",
				"glowType", "glowWhen", "highlightColor", "useGlowColor", "glowLines", "glowFrequency",
				"glowLength", "glowThickness", "glowXOffset", "glowYOffset", "glowScale", "glowBorder" }) do
				if saved[key] ~= nil then data[key] = saved[key] end
			end
		end
	end
	db.spells = baseline.spells
	db.seeded, db.otherSeeded, db.spellListVersion = true, true, 3
	active = {}
end

function extension:GetDB()
	local db = DB()
	Seed(db)
	if db and not db.displayMigrated then
		db.contexts = db.contexts or {}
		local old = db.content
		if old == "arena" or old == "party" or old == "raid" then
			for _, key in ipairs({ "arena", "group", "raid" }) do db.contexts[key] = false end
			db.contexts[old == "party" and "group" or old] = true
		elseif old == "cooldown" then
			db.displayMode = "cooldown"
		end
		for _, data in pairs(db.spells) do
			if data.show == "combat" or data.show == "outOfCombat" then data.show = "always" end
		end
		db.content = nil
		db.displayMigrated = true
	end
	if db and not db.worldRemoved then
		db.contexts = db.contexts or {}
		if db.contexts.world and db.contexts.arena == false
			and db.contexts.group == false and db.contexts.raid == false then
			db.contexts.group, db.contexts.raid = true, true
		end
		db.contexts.world = nil
		for _, data in pairs(db.spells) do
			if data.show == "world" then data.show = "always" end
		end
		db.worldRemoved = true
	end
	if db and not db.scaleRemoved then
		for _, layout in pairs(db.layouts or {}) do
			local scale = tonumber(layout.scale) or 1
			if scale ~= 1 then
				layout.size = math.floor((tonumber(layout.size) or 24) * scale + 0.5)
				layout.spacing = math.floor((tonumber(layout.spacing) or 2) * scale + 0.5)
				layout.x = math.floor((tonumber(layout.x) or 0) * scale + 0.5)
				layout.y = math.floor((tonumber(layout.y) or 0) * scale + 0.5)
			end
			layout.scale = nil
		end
		db.scaleRemoved = true
	end
	if db and not db.spellShowRemoved then
		for _, data in pairs(db.spells) do data.show = nil end
		db.spellShowRemoved = true
	end
	return db
end

function extension:GetLayoutKind()
	local wrapper = SUI.addons and SUI.addons.CompactRaidFrame
	local available = wrapper and wrapper.IsRuntimeEnabled and wrapper:IsRuntimeEnabled()
	if available == nil then available = CompactRaidFrameEnabled ~= false and CUF_CVar ~= nil end
	if not available then return "blizzard" end
	if (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0 then return "compact" end
	if CUF_CVar and CUF_CVar.GetCVarBool and CUF_CVar:GetCVarBool("useCompactPartyFrames") then
		return "compact"
	end
	return "blizzard"
end

local function IsInGroup()
	return (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0
		or (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0
end

local function ContentMode()
	local _, kind = IsInInstance()
	return kind or "none"
end

local function EnemySettings()
	local modules = SUI.db and SUI.db.profile and SUI.db.profile.modules
	local arena = modules and modules.arena
	if not arena or arena.enabled == false or arena.frameType ~= "classic" then return end
	arena.enemyAbilities = arena.enemyAbilities or {
		displayMode = "cooldown",
		anchorMode = "auto",
		layout = { side = "RIGHT", growth = "RIGHT", x = 2, y = 6,
			autoX = 7, autoY = 0, size = 24, spacing = 5, perRow = 5, cooldownEdge = true },
	}
	return arena.enemyAbilities
end

local function EnemyAllowed()
	local settings = EnemySettings()
	local arena = SUI.db and SUI.db.profile and SUI.db.profile.modules and SUI.db.profile.modules.arena
	return settings and settings.enabled ~= false and (ContentMode() == "arena" or (arena and (arena.testMode or 0) > 0))
end

local function ContextFlags()
	local kind = ContentMode()
	local raid = (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0
	local party = (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0
	if kind == "arena" then return { arena = true } end
	return {
		raid = kind == "raid" or raid,
		group = kind == "party" or (party and not raid),
	}
end

local function Allowed(db)
	if not IsInGroup() then return false end
	local flags = ContextFlags()
	local contexts = db.contexts or {}
	for key in pairs(flags) do
		if flags[key] and contexts[key] ~= false then return true end
	end
	return false
end

local function AddUnit(token, enemy)
	if not UnitExists(token) then return end
	local guid = UnitGUID(token)
	local _, class = UnitClass(token)
	local _, race = UnitRace(token)
	if guid and class then units[guid] = { token = token, class = class, race = race, enemy = enemy } end
end

local function Roster()
	local old = units
	units = {}
	if (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0 then
		for i = 1, GetNumRaidMembers() do AddUnit("raid" .. i) end
	elseif IsInGroup() then
		AddUnit("player")
		for i = 1, 4 do AddUnit("party" .. i) end
	end
	if EnemyAllowed() then
		for i = 1, 5 do AddUnit("arena" .. i, true) end
		local arenaModule = SUI.modules and SUI.modules.arena
		if arenaModule and arenaModule.GetVisibleTestFrame then
			for i = 1, 5 do
				if arenaModule:GetVisibleTestFrame(i) then
					units["sui:arena-test:" .. i] = { token = "arena" .. i, class = "WARRIOR", race = "Orc", enemy = true, test = true }
				end
			end
		end
	end
	for guid in pairs(active) do if not units[guid] then active[guid] = nil end end
	for guid in pairs(learnedDurations) do if not units[guid] then learnedDurations[guid] = nil end end
	for guid in pairs(talentRetry) do if not units[guid] then talentRetry[guid] = nil end end
	-- Queue inspection as soon as the party is known, before anyone casts.
	if talentLib and talentLib.GetGUIDTalents then
		local now = GetTime()
		for guid, member in pairs(units) do
			if not member.enemy and guid ~= UnitGUID("player") and (talentRetry[guid] or 0) <= now then
				if talentLib:GetGUIDTalents(guid) then
					talentRetry[guid] = nil
				else
					talentRetry[guid] = now + 1
				end
			end
		end
	end
	for guid in pairs(old) do if not units[guid] then
		for key, icon in pairs(icons) do if icon.guid == guid then icon:Hide(); Glow.Stop(icon) end end
	end end
end

local function FrameMap()
	local map = {}
	if EnemyAllowed() then
		local arenaModule = SUI.modules and SUI.modules.arena
		for i = 1, 5 do
			local testFrame = arenaModule and arenaModule.GetVisibleTestFrame and arenaModule:GetVisibleTestFrame(i)
			if testFrame then map["sui:arena-test:" .. i] = { testFrame, "arena" } end
			local frame = _G["ArenaEnemyFrame" .. i]
			local guid = UnitGUID("arena" .. i)
			if frame and frame:IsVisible() and guid and units[guid] then
				map[guid] = { frame, "arena" }
			end
		end
	end
	-- Compact frames take priority when both layouts exist.
	for i = 1, 40 do
		local frame = _G["CompactRaidFrame" .. i]
		if frame and frame:IsVisible() and frame.unit then
			local guid = UnitGUID(frame.unit)
			if guid and units[guid] and not map[guid] then map[guid] = { frame, "compact" } end
		end
	end
	for group = 1, 8 do
		for member = 1, 5 do
			local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
			if frame and frame:IsVisible() and frame.unit then
				local guid = UnitGUID(frame.unit)
				if guid and units[guid] and not map[guid] then map[guid] = { frame, "compact" } end
			end
		end
	end
	for i = 1, 5 do
		local frame = _G["CompactPartyFrameMember" .. i]
		if frame and frame:IsVisible() and frame.unit then
			local guid = UnitGUID(frame.unit)
			if guid and units[guid] and not map[guid] then map[guid] = { frame, "compact" } end
		end
	end
	for i = 1, 4 do
		local frame = _G["PartyMemberFrame" .. i]
		local guid = UnitGUID("party" .. i)
		if frame and frame:IsVisible() and guid and units[guid] and not map[guid] then
			map[guid] = { frame, "blizzard" }
		end
	end
	return map
end

function extension:PrepareIcon(icon)
	if not icon or icon._paChrome then return end
	icon._paChrome = true
	local border = icon:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	border:SetBlendMode("ADD")
	border:SetAlpha(0)
	border:Hide()
	border:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	border:SetPoint("CENTER", icon.texture or icon, "CENTER", 0.4, 0.5)
	icon.border = border
	icon.UpdateBorderSize = function()
		local width, height = icon:GetWidth(), icon:GetHeight()
		if not width or width < 1 then return end
		border:SetSize(width * 1.67, (height and height > 1 and height or width) * 1.67)
	end
	if Glow and Glow.Install then Glow.Install(icon) end
end

local function NewIcon(key, guid)
	local icon = CreateFrame("Frame", nil, UIParent)
	icon.guid = guid
	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints(icon)
	icon.texture:SetTexCoord(0, 1, 0, 1)
	icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
	icon.cooldown:SetAllPoints(icon)
	icon.cooldown:SetAlpha(0.65)
	icon.cooldown.__sary_partyAbility = true
	extension:PrepareIcon(icon)
	icon:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		local data = self.spellData
		if data and data.item then
			GameTooltip:SetHyperlink("item:" .. data.item)
		else
			GameTooltip:SetHyperlink("spell:" .. self.spellID)
		end
		GameTooltip:Show()
	end)
	icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
	icons[key] = icon
	return icon
end

local function MatchSpell(spellID, spellName, class, db)
	local direct = db.spells[spellID]
	if direct and (direct.class == class or direct.class == "OTHER") then return spellID, direct end
	if not spellName then return end
	for id, data in pairs(db.spells) do
		if (data.class == class or data.class == "OTHER") and GetSpellInfo(id) == spellName then return id, data end
	end
end

local presetCooldowns = {}
for _, list in pairs(SUI.PartyAbilityPresets or {}) do
	for _, entry in ipairs(list) do presetCooldowns[entry[1]] = entry[2] end
end

local function CooldownDuration(guid, id, data)
	local configured = tonumber(data and data.cooldown) or 0
	local rule = SUI.PartyAbilityCooldownRules and SUI.PartyAbilityCooldownRules[id]
	if not rule or configured ~= presetCooldowns[id] then return configured end
	-- Keep ATT's preset estimate until the relevant inspect data arrives.
	if rule.talents and not (talentLib and talentLib.GetGUIDTalents and talentLib:GetGUIDTalents(guid)) then
		return configured
	end
	-- Inspect exposes teammates' talents, but their glyphs are only available
	-- when they also sync LibGroupTalents. Missing glyphs must not hide talents.
	local glyphsKnown = not rule.glyphs or (talentLib and talentLib.GetGUIDGlyphs and talentLib:GetGUIDGlyphs(guid))
		or (UnitGUID and guid == UnitGUID("player"))
	if rule.glyphs and not glyphsKnown and not rule.talents then return configured end
	local duration = glyphsKnown and rule.base or (rule.unknownGlyphBase or configured)
	for _, modifier in ipairs(rule.talents or {}) do
		local talentName = GetSpellInfo(modifier[1])
		local rank = talentLib and talentLib.GUIDHasTalent and talentName
			and tonumber(talentLib:GUIDHasTalent(guid, talentName)) or 0
		if modifier.percents then
			duration = duration * (1 + (modifier.percents[math.min(rank, #modifier.percents - 1) + 1] or 0))
		else
			if modifier.percent then duration = duration * (1 + modifier.percent * rank) end
			if modifier.seconds then duration = duration + modifier.seconds * rank end
		end
	end
	for _, modifier in ipairs(glyphsKnown and rule.glyphs or {}) do
		if talentLib and talentLib.GUIDHasGlyph then
			for _, glyphID in ipairs(modifier.ids) do
				if talentLib:GUIDHasGlyph(guid, glyphID) then
					if modifier.percent then duration = duration * (1 + modifier.percent) end
					if modifier.seconds then duration = duration + modifier.seconds end
					break
				end
			end
		end
	end
	return math.max(0.5, duration)
end

local function ModifierDataKnown(guid, id, data)
	local rule = SUI.PartyAbilityCooldownRules and SUI.PartyAbilityCooldownRules[id]
	if not rule or tonumber(data.cooldown) ~= presetCooldowns[id] then return true end
	if rule.talents and not (talentLib and talentLib.GetGUIDTalents and talentLib:GetGUIDTalents(guid)) then return false end
	if rule.glyphs and not (talentLib and talentLib.GetGUIDGlyphs and talentLib:GetGUIDGlyphs(guid))
		and guid ~= UnitGUID("player") then return false end
	return true
end

function extension:RefreshActiveDurations(guid)
	local db = self:GetDB()
	if not db or not db.spells then return end
	for memberGUID, spells in pairs(active) do
		if not guid or memberGUID == guid then
			for id, state in pairs(spells) do
				local data = db.spells[id]
				if data and not state.shared and not state.native and not state.displayed then
					state.duration = CooldownDuration(memberGUID, id, data)
					if state.pendingUntil and ModifierDataKnown(memberGUID, id, data) then state.pendingUntil = nil end
				end
			end
		end
	end
end

local function SyncPlayerCooldown(guid, id, data, state, now)
	if not state or state.shared or not GetSpellCooldown or not UnitGUID
		or guid ~= UnitGUID("player") or tonumber(data.cooldown) ~= presetCooldowns[id] then return end
	local start, duration = GetSpellCooldown(id)
	if not start or not duration or start <= 0 or duration <= 2 then
		local spellName = GetSpellInfo(id)
		if spellName then start, duration = GetSpellCooldown(spellName) end
	end
	-- Ignore the global cooldown and a previous cast's timer. The game's own
	-- active cooldown includes talents, glyphs, gear and other local modifiers.
	if start and duration and start > 0 and duration > 2
		and start + duration > now and math.abs(start - state.start) <= 3 then
		state.start, state.duration, state.native = start, duration, true
		if SendAddonMessage and (state.sentDuration ~= duration or state.sentStart ~= start) then
			local channel = (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0 and "RAID" or "PARTY"
			SendAddonMessage(cooldownCommPrefix,
				"C|" .. guid .. "|" .. id .. "|" .. duration .. "|" .. math.max(0, now - start), channel)
			state.sentDuration, state.sentStart = duration, start
		end
	end
end

local function SyncOwnCooldowns(now)
	local guid = UnitGUID and UnitGUID("player")
	local db = DB()
	local spells = guid and active[guid]
	if not spells or not db or not db.spells then return end
	for id, state in pairs(spells) do
		local data = db.spells[id]
		if data then SyncPlayerCooldown(guid, id, data, state, now) end
	end
end

local function ReceiveCooldown(prefix, message, sender)
	if prefix ~= cooldownCommPrefix or type(message) ~= "string" or type(sender) ~= "string" then return end
	local guid, idText, durationText, ageText = message:match("^C|([^|]+)|(%d+)|([%d%.]+)|([%d%.]+)$")
	local id, duration, age = tonumber(idText), tonumber(durationText), tonumber(ageText)
	local member = guid and units[guid]
	if not member or member.enemy or member.test or not id or not duration or not age
		or duration <= 2 or duration > 3600 or age < 0 or age > duration then return end
	local name = UnitName(member.token)
	if not name or (sender ~= name and sender:match("^[^-]+") ~= name) then return end
	local db = DB()
	local data = db and db.spells and db.spells[id]
	if not data or data.enabled == false or (data.class ~= member.class and data.class ~= "OTHER")
		or tonumber(data.cooldown) ~= presetCooldowns[id] then return end
	local now = GetTime()
	local start = now - age
	active[guid] = active[guid] or {}
	local state = active[guid][id]
	if state and state.start > start + 1 then return end
	learnedDurations[guid] = learnedDurations[guid] or {}
	learnedDurations[guid][id] = duration
	if not state or (state.displayed and start > state.start + 3) then
		state = {}
		active[guid][id] = state
	end
	-- An already drawn timer keeps its original start and duration. The exact
	-- value from this message is ready for the next cast instead.
	if state.displayed then return end
	state.start, state.duration, state.native = start, duration, true
	state.pendingUntil = nil
	extension:Render()
end

local function ObservedCooldown(guid, id, data, now)
	local learned = tonumber(data.cooldown) == presetCooldowns[id]
		and learnedDurations[guid] and learnedDurations[guid][id]
	local state = { start = now, duration = learned or CooldownDuration(guid, id, data), native = learned and true or nil }
	local member = units[guid]
	if not learned and member and not member.enemy and guid ~= UnitGUID("player")
		and not ModifierDataKnown(guid, id, data) then
		-- Allow the inspect result or the caster's exact cooldown message to
		-- arrive before the timer is drawn for the first time.
		state.pendingUntil = now + 0.8
	end
	return state
end

function extension:Observe(guid, spellID, spellName)
	if not enabled or not units[guid] then return end
	local db = self:GetDB()
	local id, data = MatchSpell(spellID, spellName, units[guid].class, db)
	local now = GetTime()
	if id and data and data.enabled ~= false then
		active[guid] = active[guid] or {}
		local prior = active[guid][id]
		if not prior or (not prior.native and now - prior.start > 0.4)
			or (prior.native and now - prior.start > 3) then
			active[guid][id] = ObservedCooldown(guid, id, data, now)
		end
	end
	for _, group in ipairs(shared) do
		local matched = false
		for _, memberID in ipairs(group) do
			if spellID == memberID or (spellName and GetSpellInfo(memberID) == spellName) then matched = true; break end
		end
		if matched then
			for configuredID, configured in pairs(db.spells) do
				if configured.class == units[guid].class and configured.enabled ~= false then
					for _, memberID in ipairs(group) do
						if GetSpellInfo(configuredID) == GetSpellInfo(memberID) then
							active[guid] = active[guid] or {}
								local prior = active[guid][configuredID]
								if not prior or now - prior.start > 0.4 then
									active[guid][configuredID] = ObservedCooldown(guid, configuredID, configured, now)
								end
							break
						end
					end
				end
			end
			break
		end
	end
	local resets = resetters[spellID]
	if resets and active[guid] then
		for _, resetID in ipairs(resets) do
			local resetName = GetSpellInfo(resetID)
			for trackedID in pairs(active[guid]) do
				if trackedID == resetID or (resetName and GetSpellInfo(trackedID) == resetName) then
					active[guid][trackedID] = nil
				end
			end
		end
	end
	if spellID == 14185 and active[guid] and talentLib and talentLib.GUIDHasGlyph
		and talentLib:GUIDHasGlyph(guid, 56819) then
		-- Glyph of Preparation also resets Kick and Dismantle.
		active[guid][1766] = nil
		active[guid][51722] = nil
	end
	local member = units[guid]
	local link = member and linkedUse[member.race]
	if link then
		local found = false
		for index = 1, #link do
			if link[index] == spellID or link[index] == id then found = true break end
		end
		if found then
			local spells = self:GetDB().spells
			active[guid] = active[guid] or {}
			for index = 1, #link do
				local linkedID = link[index]
				if linkedID ~= id and linkedID ~= spellID and spells[linkedID] then
					local prior = active[guid][linkedID]
					local remain = prior and (prior.start + prior.duration - now) or 0
					if remain < link.cooldown then
						active[guid][linkedID] = { start = now, duration = link.cooldown, shared = true }
					end
				end
			end
		end
	end
	self:Render()
end

local function ShouldShow(data, remaining, displayMode)
	if data.enabled == false then return false end
	if displayMode == "cooldown" and remaining <= 0 then return false end
	return true
end

local function HasTalent(member, guid, id, data)
	-- A witnessed cast is stronger evidence than an inspection result that may
	-- arrive late or be incomplete for another party member.
	if active[guid] and active[guid][id] then return true end
	if talentLib and talentLib.GetGUIDTalents and talentLib:GetGUIDTalents(guid) then
		if data.talentTab and data.talentIndex and talentLib.GetTalentInfo then
			local _, _, _, _, spent = talentLib:GetTalentInfo(member.token, data.talentTab, data.talentIndex)
			if spent ~= nil then return (tonumber(spent) or 0) > 0 end
		end
		return talentLib:GUIDHasTalent(guid, GetSpellInfo(id)) ~= nil
	end
	-- Until inspection succeeds, a witnessed cast is the only reliable evidence.
	return active[guid] and active[guid][id] ~= nil
end

local TRINKET_SLOT_1, TRINKET_SLOT_2 = 13, 14
local lastInspect = {}

local function TrinketEquipped(unit, data, spellID)
	if not unit or not (data.item or data.trinket) then return true end
	local spellName = GetSpellInfo(spellID)
	local seen = false
	for slot = TRINKET_SLOT_1, TRINKET_SLOT_2 do
		local itemID = GetInventoryItemID(unit, slot)
		if itemID then
			seen = true
			if data.item and itemID == data.item then return true end
			if spellName and GetItemSpell(itemID) == spellName then return true end
		end
	end
	if not seen and not UnitIsUnit(unit, "player") and CanInspect and CanInspect(unit) then
		local guid = UnitGUID(unit)
		local now = GetTime()
		if guid and (lastInspect[guid] or 0) + 10 < now then
			lastInspect[guid] = now
			NotifyInspect(unit)
		end
	end
	return false
end

function extension:EntryLabel(id, data)
	data = data or {}
	if data.item then
		local name = GetItemInfo(data.item)
		if name and name ~= "" then return name end
	end
	local spell = GetSpellInfo(id)
	if spell and spell ~= "" then return spell end
	if data.itemName and data.itemName ~= "" then return data.itemName end
	return "ID " .. tostring(id)
end

function extension:EntryIcon(id, data)
	data = data or {}
	if data.item then
		local icon = select(10, GetItemInfo(data.item))
		if icon then return icon end
	end
	return select(3, GetSpellInfo(id)) or data.icon
end

local function AbilityAvailable(member, guid, id, data)
	if data.faction and UnitFactionGroup and (member.test and "Horde" or UnitFactionGroup(member.token)) ~= data.faction then return false end
	if data.race and member.race ~= data.race then return false end
	if data.excludeRace and member.race == data.excludeRace then return false end
	if (data.item or data.trinket) and not member.enemy and not TrinketEquipped(member.token, data, id) then return false end
	if not data.talent then return true end
	if member.enemy then return true end
	return HasTalent(member, guid, id, data)
end

local function RaiseIcon(icon, frame)
	extension:PrepareIcon(icon)
	local strata = frame.GetFrameStrata and frame:GetFrameStrata()
	if strata and icon:GetFrameStrata() ~= strata then icon:SetFrameStrata(strata) end
	local level = (frame:GetFrameLevel() or 0) + 20
	if icon:GetFrameLevel() ~= level then
		icon:SetFrameLevel(level)
		icon._glowDirty = true
	end
	if icon.cooldown and icon.cooldown.SetFrameLevel then
		icon.cooldown:SetFrameLevel((icon:GetFrameLevel() or level) + 1)
	end
	if icon.UpdateBorderSize then icon:UpdateBorderSize() end
end

local function AuraMatters(member, spellID, spellName)
	local db = DB()
	if not member or not db or not db.spells then return false end
	for id, data in pairs(db.spells) do
		local highlight = data.highlight
		if data.glowWhen == "active" and highlight and highlight ~= 0 and highlight ~= false
			and (data.class == member.class or data.class == "OTHER") then
			if not spellID and not spellName then return true end
			if spellID and id == spellID then return true end
			if spellName and spellName ~= "" and GetSpellInfo(id) == spellName then return true end
		end
	end
	return false
end

local function MarkAura(guid, spellID, spellName, present)
	if not guid then return end
	local set = liveAuras[guid]
	if present then
		set = set or {}
		liveAuras[guid] = set
		if spellID then set[spellID] = true end
		if spellName and spellName ~= "" then set[spellName] = true end
	elseif set then
		if spellID then set[spellID] = nil end
		if spellName and spellName ~= "" then set[spellName] = nil end
	end
end

local function AuraSet(unit, guid)
	local set = {}
	local function Scan(method)
		if not unit or not method then return end
		for index = 1, 40 do
			local name, _, _, _, _, _, _, _, _, _, spellID = method(unit, index)
			if not name then break end
			set[name] = true
			if spellID then set[spellID] = true end
		end
	end
	Scan(UnitBuff)
	Scan(UnitDebuff)
	local extra = guid and liveAuras[guid]
	if extra then
		for key, on in pairs(extra) do
			if on then set[key] = true end
		end
	end
	return set
end

local function GlowNow(data, spellID, remaining, auras)
	local highlight = data.highlight
	if highlight == nil or highlight == false or highlight == 0 then return false end
	local when = data.glowWhen or "cooldown"
	if when == "always" then return true end
	if when == "ready" then return remaining <= 0 end
	if when == "active" then
		local name = GetSpellInfo(spellID)
		return auras and (auras[spellID] or (name and auras[name])) and true or false
	end
	return remaining > 0
end

local function Position(icon, frame, layout, index, data, cellSize, autoAnchor, rowCount, centerRows)
	local side = layout.side or "RIGHT"
	local point = side == "LEFT" and "RIGHT" or side == "RIGHT" and "LEFT"
		or side == "TOP" and "BOTTOM" or "TOP"
	local dx, dy = 0, 0
	local size = tonumber(data.size) or tonumber(layout.size) or 24
	cellSize = cellSize or size
	local spacing = tonumber(layout.spacing) or 2
	local perRow = math.max(1, tonumber(layout.perRow) or 6)
	local col, row = (index - 1) % perRow, math.floor((index - 1) / perRow)
	local growth = layout.growth or "RIGHT"
	if autoAnchor then
		point, side = "LEFT", "RIGHT"
		dx = col * (cellSize + spacing)
		dy = (((rowCount or 1) - 1) / 2 - row) * (cellSize + spacing)
		frame = autoAnchor
	elseif growth == "RIGHT" then dx, dy = col * (cellSize + spacing), -row * (cellSize + spacing)
	elseif growth == "LEFT" then dx, dy = -col * (cellSize + spacing), -row * (cellSize + spacing)
	elseif growth == "UP" then dx, dy = row * (cellSize + spacing), col * (cellSize + spacing)
	else dx, dy = row * (cellSize + spacing), -col * (cellSize + spacing) end
	if centerRows and not autoAnchor and (growth == "RIGHT" or growth == "LEFT") then
		dy = dy + ((rowCount or 1) - 1) * (cellSize + spacing) / 2
	end
	local x, y = (tonumber(autoAnchor and layout.autoX or layout.x) or (autoAnchor and 7 or 0)) + dx,
		(tonumber(autoAnchor and layout.autoY or layout.y) or 0) + dy
	RaiseIcon(icon, frame)
	if icon._anchor == frame and icon._point == point and icon._side == side
		and icon._x == x and icon._y == y and icon._size == size then return end
	icon._anchor, icon._point, icon._side = frame, point, side
	icon._x, icon._y, icon._size = x, y, size
	icon:SetSize(size, size)
	RaiseIcon(icon, frame)
	if icon.glowing and Glow.Fit then Glow.Fit(icon) end
	icon:ClearAllPoints()
	icon:SetPoint(point, frame, side, x, y)
end

function extension:PositionIcon(icon, frame, layout, index, data, cellSize, autoAnchor, rowCount, centerRows)
	Position(icon, frame, layout, index, data, cellSize, autoAnchor, rowCount, centerRows)
end

function extension:ApplyIconAppearance(icon, layout)
	local drawEdge = layout.cooldownEdge == true
	if icon.cooldown.SetDrawEdge and icon._drawEdge ~= drawEdge then
		icon._drawEdge = drawEdge
		if icon.timerStart and icon.timerDuration then
			CooldownFrame_SetTimer(icon.cooldown, icon.timerStart, icon.timerDuration, 1)
			if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(icon.cooldown, icon.timerStart, icon.timerDuration, 1) end
		end
		icon.cooldown:SetDrawEdge(drawEdge)
	end
end

function extension:Render()
	local db = self:GetDB()
	local partyAllowed = db and db.enabled ~= false and Allowed(db)
	local enemyAllowed = EnemyAllowed()
	if not enabled or not db or (not partyAllowed and not enemyAllowed) then
		for _, icon in pairs(icons) do icon:Hide(); Glow.Stop(icon); icon.glowing = nil end
		return
	end
	local seen = {}
	local now = GetTime()
	local frames = FrameMap()
	for guid, member in pairs(units) do
		local target = frames[guid]
		local frame, kind = target and target[1], target and target[2]
		local showMember = member.enemy and enemyAllowed or (not member.enemy and partyAllowed)
		if frame and showMember and (member.enemy or db.showPlayer ~= false or not UnitIsUnit(member.token, "player"))
			and (member.test or not UnitIsDeadOrGhost or not UnitIsDeadOrGhost(member.token)) then
			local auras = member.test and {} or AuraSet(member.token, guid)
			local list = {}
			for id, data in pairs(db.spells or {}) do
				local known = GetSpellInfo(id) or data.item or data.trinket or data.icon
				if (data.class == member.class or data.class == "OTHER") and known
					and (not member.enemy or not (data.race or data.trinket))
					and AbilityAvailable(member, guid, id, data) then
					local state = active[guid] and active[guid][id]
					if state and not member.test then SyncPlayerCooldown(guid, id, data, state, now) end
					if member.test and data.enabled ~= false then
						local duration = math.max(1, tonumber(data.cooldown) or 60)
						if not state or state.start + state.duration <= now then
							active[guid] = active[guid] or {}
							state = { start = now - duration * 0.25, duration = duration }
							active[guid][id] = state
						end
					end
					local remaining = state and math.max(0, state.start + state.duration - now) or 0
					local mode = member.enemy and ((EnemySettings() or {}).displayMode or "all") or db.displayMode
					if ShouldShow(data, remaining, mode) then
						list[#list + 1] = { id = id, data = data, state = state, remaining = remaining }
					end
				end
			end
			table.sort(list, function(a, b)
				local ao, bo = tonumber(a.data.order) or 100, tonumber(b.data.order) or 100
				return ao == bo and a.id < b.id or ao < bo
			end)
			if member.test and member.token == "arena1" then
				for index = #list, 4, -1 do list[index] = nil end
			end
			local layout = kind == "arena" and ((EnemySettings() or {}).layout or {})
				or (db.layouts and db.layouts[kind] or {})
			local cellSize = tonumber(layout.size) or 24
			for _, item in ipairs(list) do cellSize = math.max(cellSize, tonumber(item.data.size) or 0) end
			local autoAnchor
			if member.enemy and (EnemySettings() or {}).anchorMode == "auto" then
				local arenaModule = SUI.modules and SUI.modules.arena
				local index = tonumber(member.token and member.token:match("^arena(%d+)$"))
				if arenaModule and arenaModule.GetAbilityAnchor and index then
					autoAnchor = arenaModule:GetAbilityAnchor(index, member.test)
				end
			end
			local rowCount = math.ceil(#list / math.max(1, tonumber(layout.perRow) or 6))
			for index, item in ipairs(list) do
				local key = guid .. ":" .. item.id
				local icon = icons[key] or NewIcon(key, guid)
				seen[key] = true
				local tex = extension:EntryIcon(item.id, item.data)
				if icon.spellID ~= item.id or icon._tex ~= tex then
					icon.spellID = item.id
					icon.spellData = item.data
					icon._tex = tex
					icon.texture:SetTexture(tex)
				end
				Position(icon, frame, layout, index, item.data, cellSize, autoAnchor, rowCount, member.enemy)
				self:ApplyIconAppearance(icon, layout)
				if item.state and item.state.pendingUntil and item.state.pendingUntil > now then
					icon.texture:SetVertexColor(0.7, 0.7, 0.7)
					if icon.timerStart then
						CooldownFrame_SetTimer(icon.cooldown, 0, 0, 0)
						if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(icon.cooldown, 0, 0, 0) end
						icon.timerStart, icon.timerDuration = nil, nil
					end
				elseif item.remaining > 0 then
					item.state.displayed = true
					icon.texture:SetVertexColor(1, 1, 1)
					if icon.timerStart ~= item.state.start or icon.timerDuration ~= item.state.duration then
						CooldownFrame_SetTimer(icon.cooldown, item.state.start, item.state.duration, 1)
						if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(icon.cooldown, item.state.start, item.state.duration, 1) end
						icon.timerStart = item.state.start
						icon.timerDuration = item.state.duration
					end
				else
					icon.texture:SetVertexColor(1, 1, 1)
					if icon.timerStart then
						CooldownFrame_SetTimer(icon.cooldown, 0, 0, 0)
						if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(icon.cooldown, 0, 0, 0) end
						icon.timerStart, icon.timerDuration = nil, nil
					end
				end
				local glowNow = GlowNow(item.data, item.id, item.remaining, auras)
				local sameGlow = icon.glowing and icon.glowData == item.data and not icon._glowDirty
				if glowNow and not sameGlow then
					if icon.UpdateBorderSize then icon:UpdateBorderSize() end
					Glow.Start(icon, item.data)
					icon.glowing, icon.glowData, icon._glowDirty = true, item.data, nil
				elseif not glowNow and icon.glowing then
					Glow.Stop(icon)
					icon.glowing, icon.glowData = nil, nil
				end
				icon:Show()
			end
		end
	end
	for key, icon in pairs(icons) do
		if not seen[key] then icon:Hide(); if icon.glowing then Glow.Stop(icon); icon.glowing = nil end end
	end
end

function extension:RefreshConfig()
	local db = self:GetDB()
	local enemy = EnemySettings()
	if lastDB and lastDB ~= db then active = {} end
	lastDB = db
	if db and (db.enabled ~= false or (enemy and enemy.enabled ~= false)) then self:Enable() else self:Disable() end
	if enabled then
		self:RefreshActiveDurations()
		for _, icon in pairs(icons) do
			if icon.glowing then Glow.Stop(icon); icon.glowing = nil end
		end
		Roster(); self:Render()
	end
end

local function UpdateTick()
	local db = DB()
	local tracking = enabled and ((db and db.enabled ~= false and IsInGroup()) or EnemyAllowed())
	if tracking ~= trackingEvents then
		trackingEvents = tracking
		if tracking then
			eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		else
			eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			eventFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		end
	end
	if not tracking then
		eventFrame:SetScript("OnUpdate", nil)
		return
	end
	eventFrame:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta
		if elapsed < 0.5 then return end
		elapsed = 0
		if talentLib and talentLib.GetGUIDTalents then
			local now = GetTime()
			for guid, retryAt in pairs(talentRetry) do
				if retryAt <= now then
					if talentLib:GetGUIDTalents(guid) then talentRetry[guid] = nil
					else talentRetry[guid] = now + 5 end
				end
			end
		end
		SyncOwnCooldowns(GetTime())
		extension:Render()
	end)
end

function extension:OnTalentUpdate(_, guid)
	if guid and units[guid] then
		-- Talent inspection can finish seconds after a cast. It updates which
		-- abilities are available, but must not erase observed cooldowns.
		learnedDurations[guid] = nil
		talentRetry[guid] = nil
		self:RefreshActiveDurations(guid)
		self:Render()
	end
end

function extension:OnGlyphUpdate(_, guid)
	if guid and units[guid] then
		learnedDurations[guid] = nil
		self:RefreshActiveDurations(guid)
		self:Render()
	end
end

function extension:Enable()
	if enabled then return end
	enabled = true
	for _, name in ipairs({ "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
		"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TALENT_UPDATE", "UNIT_NAME_UPDATE",
		"UNIT_FACTION", "UNIT_AURA", "ARENA_OPPONENT_UPDATE", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED",
		"INSPECT_TALENT_READY", "CHAT_MSG_ADDON" }) do
		eventFrame:RegisterEvent(name)
	end
	if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(cooldownCommPrefix) end
	if talentLib and talentLib.RegisterCallback then
		talentLib.RegisterCallback(self, "LibGroupTalents_Update", "OnTalentUpdate")
		talentLib.RegisterCallback(self, "LibGroupTalents_GlyphUpdate", "OnGlyphUpdate")
	end
	Roster()
	UpdateTick()
	self:Render()
end

function extension:Disable()
	if not enabled then return end
	enabled = false
	eventFrame:UnregisterAllEvents()
	trackingEvents = false
	if talentLib and talentLib.UnregisterCallback then
		talentLib.UnregisterCallback(self, "LibGroupTalents_Update")
		talentLib.UnregisterCallback(self, "LibGroupTalents_GlyphUpdate")
	end
	eventFrame:SetScript("OnUpdate", nil)
	for _, icon in pairs(icons) do icon:Hide(); Glow.Stop(icon); icon.glowing = nil end
end

function extension:Initialize() self:RefreshConfig() end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "CHAT_MSG_ADDON" then
		local prefix, message, _, sender = ...
		ReceiveCooldown(prefix, message, sender)
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, subevent, sourceGUID, _, _, destGUID, _, _, spellID, spellName = ...
		if subevent == "UNIT_DIED" and destGUID then
			active[destGUID] = nil
			liveAuras[destGUID] = nil
			extension:Render()
		elseif subevent == "SPELL_CAST_SUCCESS" and sourceGUID and units[sourceGUID] then
			extension:Observe(sourceGUID, spellID, spellName)
		elseif destGUID and units[destGUID] and AuraMatters(units[destGUID], spellID, spellName) then
			if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" or subevent == "SPELL_AURA_APPLIED_DOSE" then
				MarkAura(destGUID, spellID, spellName, true)
				extension:Render()
			elseif subevent == "SPELL_AURA_REMOVED" then
				MarkAura(destGUID, spellID, spellName, false)
				extension:Render()
			end
		end
	elseif event == "UNIT_AURA" then
		local unit = ...
		local guid = unit and UnitGUID(unit)
		local member = guid and units[guid]
		if member and AuraMatters(member) then
			liveAuras[guid] = nil
			extension:Render()
		end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit, spellName, _, _, spellID = ...
		local guid = unit and UnitGUID(unit)
		if guid and units[guid] then extension:Observe(guid, spellID, spellName) end
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		local itemID = ...
		local db = DB()
		local relevant = false
		if itemID and db and db.spells then
			for _, data in pairs(db.spells) do
				if data.item == itemID then
					relevant = true
					local name = GetItemInfo(itemID)
					if name and name ~= "" then data.itemName = name end
				end
			end
		end
		if relevant then
			extension:Render()
			if SUI.NotifySarychUIOptionsChange then SUI:NotifySarychUIOptionsChange() end
		end
	else
		local kind = ContentMode()
		if event == "PLAYER_ENTERING_WORLD" or (event == "ZONE_CHANGED_NEW_AREA" and kind ~= lastInstanceKind) then
			active = {}
			learnedDurations = {}
			talentRetry = {}
			liveAuras = {}
		end
		lastInstanceKind = kind
		Roster()
		if event == "PLAYER_TALENT_UPDATE" then
			extension:RefreshActiveDurations(UnitGUID("player"))
		end
		UpdateTick()
		extension:Render()
	end
end)
