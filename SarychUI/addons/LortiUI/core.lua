-- Lorti UI 1.6.4 (Lorti, 2011) — thenнение текстур Blizzard.
-- Подключается из Tools → Затемнение текстур интерфейса.

SarychUI_LortiUI = SarychUI_LortiUI or {}
local L = SarychUI_LortiUI

L.enabled = false
L.hooksInstalled = false
L.originalColors = {}
L.paintedButtons = {}

-- Lorti UI.lua cfg (media copied from Lorti UI/media)
local MEDIA = [[Interface\AddOns\SarychUI\addons\LortiUI\media\]]
L.cfg = L.cfg or {
	textures = {
		normal = MEDIA .. "gloss",
		flash = MEDIA .. "flash",
		hover = MEDIA .. "hover",
		pushed = MEDIA .. "pushed",
		checked = MEDIA .. "checked",
		equipped = MEDIA .. "gloss_grey",
		buttonback = MEDIA .. "button_background",
		buttonbackflat = MEDIA .. "button_background_flat",
		outer_shadow = MEDIA .. "outer_shadow",
	},
	background = {
		showbg = true,
		showshadow = true,
		useflatbackground = false,
		backgroundcolor = { r = 0.3, g = 0.3, b = 0.3, a = 0.7 },
		shadowcolor = { r = 0, g = 0, b = 0, a = 0.9 },
		classcolored = false,
		inset = 5,
	},
	color = {
		-- Keep button chrome as dark as the original Lorti UI. The configurable
		-- SarychUI dark tint applies to other interface artwork via GetColor().
		normal = { r = 0, g = 0, b = 0, a = 0.9 },
		equipped = { r = 0.3, g = 0.55, b = 0.1 },
		classcolored = false,
	},
	hotkeys = {
		show = true,
		fontsize = 12,
		pos1 = { a1 = "TOPRIGHT", x = 0, y = 0 },
		pos2 = { a1 = "TOPLEFT", x = 0, y = 0 },
	},
	macroname = {
		show = false,
		fontsize = 12,
		pos1 = { a1 = "BOTTOMLEFT", x = 0, y = 0 },
		pos2 = { a1 = "BOTTOMRIGHT", x = 0, y = 0 },
	},
	itemcount = {
		show = true,
		fontsize = 12,
		pos1 = { a1 = "BOTTOMRIGHT", x = 0, y = 0 },
	},
	cooldown = {
		spacing = 0,
	},
	font = [[Fonts\FRIZQT__.TTF]],
}

function L.GetColor()
	local mods = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	local db = mods and mods.tools
	local c = db and db.darkModeColor
	if c then
		return c.r or 0.37, c.g or 0.37, c.b or 0.37, c.a or 1
	end
	local n = L.cfg.color.normal
	return n.r, n.g, n.b, n.a
end

function L.IsSettingOn()
	local mods = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	local db = mods and mods.tools
	return db and db.enabled and (db.enableDarkMode == 1 or db.enableDarkMode == true)
end

function L:DarkenTexture(texture)
	if not texture or not texture.SetVertexColor then return end
	if not self.originalColors[texture] then
		local r, g, b, a = texture:GetVertexColor()
		self.originalColors[texture] = { r = r, g = g, b = b, a = a }
	end
	local cr, cg, cb, ca = self.GetColor()
	local prev = self._painting
	self._painting = true
	texture:SetVertexColor(cr, cg, cb, ca)
	self._painting = prev
end

function L:RestoreTexture(texture)
	if not texture or not texture.SetVertexColor then return end
	local orig = self.originalColors[texture]
	if orig then
		texture:SetVertexColor(orig.r, orig.g, orig.b, orig.a)
	else
		texture:SetVertexColor(1, 1, 1, 1)
	end
end

-- Arena frames and the classic party frames are protected. SetVertexColor on
-- their Blizzard textures taints the frame: the next combat Show/Hide/SetPoint
-- is blocked and blamed on SarychUI. Draw our own copy on top and never call
-- methods that modify the original.
local function IsSecureUnitArtwork(name)
	return type(name) == "string" and (
		name:match("^ArenaEnemyFrame%d")
		or name:match("^ArenaPrepFrame%d")
		or name:match("^PartyMemberFrame%d")
	) ~= nil
end

local secureArtworkWatch

local function SyncSecureArtworkOverlays()
	local overlays = L.arenaOverlays
	if not overlays then return end
	for tex, overlay in pairs(overlays) do
		local host = overlay._host
		if host then
			local parent = tex.GetParent and tex:GetParent()
			local shown = tex.IsShown and tex:IsShown() and parent and parent.IsVisible and parent:IsVisible()
			if shown then
				if not host:IsShown() then host:Show() end
			elseif host:IsShown() then
				host:Hide()
			end
		end
	end
end

function L:DarkenArenaArtwork(name)
	local tex = _G[name]
	if not tex or not tex.GetParent then return end
	local parent = tex:GetParent()
	if not parent then return end
	self.arenaOverlays = self.arenaOverlays or {}
	local overlay = self.arenaOverlays[tex]
	if not overlay then
		-- Own frame, not a region of the protected arena button. Creating a
		-- texture on ArenaEnemyFrame taints its right-click FocusUnit handler.
		local host = CreateFrame("Frame", nil, UIParent)
		host:Hide()
		host:SetFrameStrata((parent.GetFrameStrata and parent:GetFrameStrata()) or "MEDIUM")
		local level = (parent.GetFrameLevel and parent:GetFrameLevel()) or 1
		if level < 1 then level = 1 end
		host:SetFrameLevel(level + 1)
		overlay = host:CreateTexture(nil, "ARTWORK")
		overlay:SetAllPoints(host)
		host:SetAllPoints(tex)
		local path = tex.GetTexture and tex:GetTexture()
		if path and overlay.SetTexture then
			overlay:SetTexture(path)
		end
		if tex.GetTexCoord and overlay.SetTexCoord then
			overlay:SetTexCoord(tex:GetTexCoord())
		end
		overlay._host = host
		self.arenaOverlays[tex] = overlay
		if not secureArtworkWatch then
			secureArtworkWatch = CreateFrame("Frame")
			local elapsed = 0
			secureArtworkWatch:SetScript("OnUpdate", function(_, dt)
				elapsed = elapsed + (dt or 0)
				if elapsed < 0.2 then return end
				elapsed = 0
				SyncSecureArtworkOverlays()
			end)
		end
	end
	local cr, cg, cb, ca = self.GetColor()
	overlay:SetVertexColor(cr, cg, cb, ca)
	SyncSecureArtworkOverlays()
end

function L:RestoreArenaArtwork(name)
	local tex = type(name) == "string" and _G[name] or name
	local overlay = tex and self.arenaOverlays and self.arenaOverlays[tex]
	if overlay then
		overlay:Hide()
		if overlay._host then
			overlay._host:Hide()
		end
	end
end

function L:DarkenNamed(name)
	if IsSecureUnitArtwork(name) then
		self:DarkenArenaArtwork(name)
		return
	end
	if type(name) == "string" then
		self:DarkenTexture(_G[name])
	elseif name then
		self:DarkenTexture(name)
	end
end

function L:RestoreNamed(name)
	if IsSecureUnitArtwork(name) then
		self:RestoreArenaArtwork(name)
		return
	end
	if type(name) == "string" then
		self:RestoreTexture(_G[name])
	elseif name then
		self:RestoreTexture(name)
	end
end

function L:DarkenFirstRegion(frame)
	if not frame or not frame.GetRegions then return end
	local region = frame:GetRegions()
	if region then
		self:DarkenTexture(region)
	end
end

function L:RestoreFirstRegion(frame)
	if not frame or not frame.GetRegions then return end
	local region = frame:GetRegions()
	if region then
		self:RestoreTexture(region)
	end
end

function L:InstallHooks()
	if self.hooksInstalled then return end
	self.hooksInstalled = true
	if self.InstallFrameHooks then
		self:InstallFrameHooks()
	end
	if self.InstallButtonHooks then
		self:InstallButtonHooks()
	end
	if self.InstallAuraHooks then
		self:InstallAuraHooks()
	end
	if self.InstallCompactRaidHooks then
		self:InstallCompactRaidHooks()
	end
end

function L:Apply()
	if not self.IsSettingOn() then
		self:Disable()
		return
	end
	self.enabled = true
	self:InstallHooks()
	if self.ApplyFrames then
		self:ApplyFrames()
	end
	if self.ApplyButtons then
		self:ApplyButtons()
	end
	if self.ApplyAuras then
		self:ApplyAuras()
	end
	if self.ApplyCompactRaid then
		self:ApplyCompactRaid()
	end
	local frameMod = SarychUI and SarychUI.modules and SarychUI.modules.frame
	if frameMod and frameMod.ApplyClassIcons then
		frameMod:ApplyClassIcons()
	end
	local prMod = SarychUI and SarychUI.modules and SarychUI.modules.player_resources
	if prMod and prMod.ApplyTotemsDarkMode then
		prMod:ApplyTotemsDarkMode()
	end
	local arenaMod = SarychUI and SarychUI.modules and SarychUI.modules.arena
	if arenaMod and arenaMod.RefreshTrinketBorders then
		arenaMod:RefreshTrinketBorders()
	end
end

function L:Enable()
	self:Apply()
end

function L:Disable()
	self.enabled = false
	if self.RestoreButtons then
		self:RestoreButtons()
	end
	if self.RestoreAuras then
		self:RestoreAuras()
	end
	if self.RestoreCompactRaid then
		self:RestoreCompactRaid()
	end
	if self.RestoreFrames then
		self:RestoreFrames()
	end
	wipe(self.originalColors)
	wipe(self.paintedButtons)
	if self.paintedAuras then
		wipe(self.paintedAuras)
	end
	local frameMod = SarychUI and SarychUI.modules and SarychUI.modules.frame
	if frameMod and frameMod.ApplyClassIcons then
		frameMod:ApplyClassIcons()
	end
	local prMod = SarychUI and SarychUI.modules and SarychUI.modules.player_resources
	if prMod and prMod.ApplyTotemsDarkMode then
		prMod:ApplyTotemsDarkMode()
	end
	local arenaMod = SarychUI and SarychUI.modules and SarychUI.modules.arena
	if arenaMod and arenaMod.RefreshTrinketBorders then
		arenaMod:RefreshTrinketBorders()
	end
end
