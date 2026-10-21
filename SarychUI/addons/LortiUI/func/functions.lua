-- Ported from Lorti UI func/functions.lua (rActionButtonStyler)
-- В режиме затемнения кнопки переключаются на media Lorti; при выключении — обратно.

local L = SarychUI_LortiUI
local cfg = L.cfg
local _G = _G

local classcolor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
if cfg.color.classcolored then
	cfg.color.normal = classcolor
end

local bgfile, edgefile = "", ""
if cfg.background.showshadow then
	edgefile = cfg.textures.outer_shadow
end
if cfg.background.useflatbackground and cfg.background.showbg then
	bgfile = cfg.textures.buttonbackflat
end

local backdrop = {
	bgFile = bgfile,
	edgeFile = edgefile,
	tile = false,
	tileSize = 32,
	edgeSize = cfg.background.inset,
	insets = {
		left = cfg.background.inset,
		right = cfg.background.inset,
		top = cfg.background.inset,
		bottom = cfg.background.inset,
	},
}

local function GetTexPath(tex)
	if tex and tex.GetTexture then
		return tex:GetTexture()
	end
end

local function NormalTextureOf(bu, name)
	-- The original Lorti uses NormalTexture for action buttons and
	-- NormalTexture2 for pet buttons. The button property is the fallback.
	if name and name:match("^PetActionButton%d+$") then
		return _G[name .. "NormalTexture2"] or (bu.GetNormalTexture and bu:GetNormalTexture())
	end
	return (name and _G[name .. "NormalTexture"])
		or (bu.GetNormalTexture and bu:GetNormalTexture())
		or (name and _G[name .. "NormalTexture2"])
end

local savedByButton = setmetatable({}, { __mode = "k" })
local styledByButton = setmetatable({}, { __mode = "k" })
local bgByButton = setmetatable({}, { __mode = "k" })
local petGlossByButton = setmetatable({}, { __mode = "k" })

-- A child frame or an addon field on a protected action button taints its
-- click. UseAction still runs out of combat, then /castsequence dies in
-- CastSpellByName and the client names SarychUI.
local function IsSecureBarButton(bu)
	local name = bu and bu.GetName and bu:GetName()
	if type(name) ~= "string" then
		return false
	end
	return name:match("^ActionButton%d+$")
		or name:match("^MultiBarBottomLeftButton%d+$")
		or name:match("^MultiBarBottomRightButton%d+$")
		or name:match("^MultiBarLeftButton%d+$")
		or name:match("^MultiBarRightButton%d+$")
		or name:match("^BonusActionButton%d+$")
		or name:match("^PetActionButton%d+$")
		or name:match("^ShapeshiftButton%d+$")
		or name:match("^PossessButton%d+$")
		or name:match("^StanceButton%d+$")
end

local function SavedOf(bu)
	return savedByButton[bu] or (bu and bu.suiLortiSaved)
end

local function MarkStyled(bu, styled)
	if not bu then
		return
	end
	if IsSecureBarButton(bu) then
		styledByButton[bu] = styled and true or nil
	else
		bu.suiLortiStyled = styled and true or nil
	end
end

local function IsStyled(bu)
	return styledByButton[bu] or (bu and bu.suiLortiStyled)
end

local function CallWidget(obj, method, ...)
	if not obj then return end
	local fn = obj[method]
	if fn then
		fn(obj, ...)
	end
end

local function ButtonBackground(bu)
	return bgByButton[bu] or bu.bg
end

local function ButtonIsOnScreen(bu)
	return bu and bu.IsVisible and bu:IsVisible()
end

-- Gloss and backdrop are parented to UIParent so they do not taint the
-- button. They do not hide with a disabled bar, so follow the button.
local function SyncOwnedChrome(bu)
	if not bu then
		return
	end
	local shown = ButtonIsOnScreen(bu)
	local bg = bgByButton[bu]
	if bg then
		if shown then
			bg:Show()
		else
			bg:Hide()
		end
	end
	local gloss = petGlossByButton[bu]
	local holder = gloss and gloss.GetParent and gloss:GetParent()
	if holder and holder ~= bu then
		if shown then
			holder:Show()
		else
			holder:Hide()
		end
	end
end

local chromeWatch = CreateFrame("Frame")
local chromeElapsed = 0
chromeWatch:SetScript("OnUpdate", function(_, elapsed)
	if not L.enabled then
		return
	end
	chromeElapsed = chromeElapsed + elapsed
	if chromeElapsed < 0.2 then
		return
	end
	chromeElapsed = 0
	for bu in pairs(bgByButton) do
		SyncOwnedChrome(bu)
	end
	for bu in pairs(petGlossByButton) do
		SyncOwnedChrome(bu)
	end
end)

local function applyBackground(bu, anchor)
	if not cfg.background.showbg and not cfg.background.showshadow then
		return
	end
	local existing = ButtonBackground(bu)
	if existing then
		existing:Show()
		return
	end
	anchor = anchor or bu
	local secure = IsSecureBarButton(bu)
	local bg = CreateFrame("Frame", nil, secure and UIParent or bu)
	if secure then
		bgByButton[bu] = bg
		bg:SetFrameStrata(bu:GetFrameStrata() or "LOW")
	else
		bu.bg = bg
	end
	bg:SetPoint("TOPLEFT", anchor, "TOPLEFT", -4, 4)
	bg:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 4, -4)
	local lvl = bu:GetFrameLevel() or 1
	if lvl < 1 then lvl = 1 end
	bg:SetFrameLevel(math.max(lvl - 1, 0))

	if cfg.background.classcolored then
		cfg.background.backgroundcolor = classcolor
		cfg.background.shadowcolor = classcolor
	end

	if cfg.background.showbg and not cfg.background.useflatbackground then
		local t = bg:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(cfg.textures.buttonback)
		t:SetAllPoints(anchor)
		t:SetVertexColor(cfg.background.backgroundcolor.r, cfg.background.backgroundcolor.g, cfg.background.backgroundcolor.b, cfg.background.backgroundcolor.a)
	end

	if bg.SetBackdrop then
		bg:SetBackdrop(backdrop)
		if cfg.background.useflatbackground then
			bg:SetBackdropColor(cfg.background.backgroundcolor.r, cfg.background.backgroundcolor.g, cfg.background.backgroundcolor.b, cfg.background.backgroundcolor.a)
		end
		if cfg.background.showshadow then
			bg:SetBackdropBorderColor(cfg.background.shadowcolor.r, cfg.background.shadowcolor.g, cfg.background.shadowcolor.b, cfg.background.shadowcolor.a)
		end
	end
end

L.ApplyButtonBackground = applyBackground

local function ntSetVertexColorFunc(nt, r, g, b)
	if not L.enabled or L._painting or not nt then
		return
	end
	local parent = nt.GetParent and nt:GetParent()
	local action = parent and parent.action
	L._painting = true
	if r == 1 and g == 1 and b == 1 and action and IsEquippedAction(action) then
		nt:SetVertexColor(cfg.color.equipped.r, cfg.color.equipped.g, cfg.color.equipped.b, 1)
	elseif r == 0.5 and g == 0.5 and b == 1 then
		nt:SetVertexColor(cfg.color.normal.r, cfg.color.normal.g, cfg.color.normal.b, 1)
	elseif r == 1 and g == 1 and b == 1 then
		nt:SetVertexColor(cfg.color.normal.r, cfg.color.normal.g, cfg.color.normal.b, 1)
	end
	L._painting = false
end

local function HookNormalTex(nt)
	if not nt or nt.suiLortiHooked then
		return
	end
	local parent = nt.GetParent and nt:GetParent()
	-- UpdateUsable calls this SetVertexColor, then ActionButton_Update
	-- stores fields on the button. A post-hook there taints the button.
	if IsSecureBarButton(parent) then
		return
	end
	nt.suiLortiHooked = true
	hooksecurefunc(nt, "SetVertexColor", ntSetVertexColorFunc)
end

local function ColorActiveTex(ct)
	if not ct then
		return
	end
	local c = cfg.color.normal
	L._painting = true
	ct:SetVertexColor(c.r, c.g, c.b, c.a or 1)
	L._painting = false
end

local function ctSetVertexColorFunc(ct, r, g, b)
	if not L.enabled or L._painting or not ct or ct.suiLortiKeepBlizzardColor then
		return
	end
	if r == 1 and g == 1 and b == 1 then
		ColorActiveTex(ct)
	end
end

local function HookCheckedTex(ct)
	if not ct or ct.suiLortiCheckedHooked then
		return
	end
	ct.suiLortiCheckedHooked = true
	hooksecurefunc(ct, "SetVertexColor", ctSetVertexColorFunc)
end

local function SaveButton(bu, name)
	if SavedOf(bu) then
		return
	end
	local ic = _G[name .. "Icon"] or _G[name .. "IconTexture"]
	local fl = _G[name .. "Flash"]
	local nt = NormalTextureOf(bu, name)
	local ht = bu.GetHighlightTexture and bu:GetHighlightTexture()
	local pt = bu.GetPushedTexture and bu:GetPushedTexture()
	local ct = bu.GetCheckedTexture and bu:GetCheckedTexture()
	local saved = {
		normal = GetTexPath(nt) or [[Interface\Buttons\UI-Quickslot2]],
		highlight = GetTexPath(ht) or [[Interface\Buttons\ButtonHilight-Square]],
		pushed = GetTexPath(pt) or [[Interface\Buttons\UI-Quickslot-Depress]],
		checked = GetTexPath(ct) or [[Interface\Buttons\CheckButtonHilight]],
		flash = GetTexPath(fl) or [[Interface\Buttons\UI-QuickslotRed]],
		iconULx = 0, iconULy = 0, iconLLx = 0, iconLLy = 1, iconURx = 1, iconURy = 0, iconLRx = 1, iconLRy = 1,
	}
	if ic and ic.GetTexCoord then
		saved.iconULx, saved.iconULy, saved.iconLLx, saved.iconLLy, saved.iconURx, saved.iconURy, saved.iconLRx, saved.iconLRy = ic:GetTexCoord()
	end
	if IsSecureBarButton(bu) then
		savedByButton[bu] = saved
	else
		bu.suiLortiSaved = saved
	end
end

local function SetRegionTexture(tex, path)
	if not tex or not path then
		return
	end
	if tex.SetTexture then
		tex:SetTexture(path)
	end
	if tex.SetTexCoord then
		tex:SetTexCoord(0, 1, 0, 1)
	end
end

local function PinOverlay(tex, path, blend, anchor)
	if not tex then
		return
	end
	if path then
		SetRegionTexture(tex, path)
	end
	anchor = anchor or (tex.GetParent and tex:GetParent())
	if anchor then
		tex:ClearAllPoints()
		tex:SetAllPoints(anchor)
	end
	if tex.SetBlendMode and blend then
		tex:SetBlendMode(blend)
	end
	tex:SetAlpha(1)
end

local function PaintActionOverlays(bu, fl, anchor, isItem)
	PinOverlay(bu.GetHighlightTexture and bu:GetHighlightTexture(), cfg.textures.hover, "ADD", anchor)
	local pushed = bu.GetPushedTexture and bu:GetPushedTexture()
	PinOverlay(pushed, cfg.textures.pushed, "BLEND", anchor)
	local ct = bu.GetCheckedTexture and bu:GetCheckedTexture()
	-- CheckedTexture is Blizzard's yellow queued/current-action indicator
	-- (for example Heroic Strike). Keep it intact for action buttons instead
	-- of replacing it with Lorti's black checked overlay.
	if isItem then
		PinOverlay(ct, cfg.textures.checked, "ADD", anchor)
		ColorActiveTex(ct)
		HookCheckedTex(ct)
	end
	PinOverlay(fl, cfg.textures.flash, "ADD", anchor)
end

local function ShowOwnedGloss(bu, path, r, g, b, a)
	local gloss = petGlossByButton[bu]
	if not gloss then
		local holder = CreateFrame("Frame", nil, UIParent)
		holder:SetFrameStrata(bu:GetFrameStrata() or "MEDIUM")
		holder:SetFrameLevel((bu:GetFrameLevel() or 0) + 1)
		holder:SetAllPoints(bu)
		gloss = holder:CreateTexture(nil, "OVERLAY")
		gloss:SetAllPoints(holder)
		petGlossByButton[bu] = gloss
	end
	if gloss:GetTexture() ~= path then gloss:SetTexture(path) end
	local cr, cg, cb, ca = gloss:GetVertexColor()
	if cr ~= r or cg ~= g or cb ~= b or ca ~= (a or 1) then
		gloss:SetVertexColor(r, g, b, a or 1)
	end
	if not gloss:IsShown() then gloss:Show() end
	SyncOwnedChrome(bu)
end

local function HideNativeRim(bu, name)
	local named = NormalTextureOf(bu, name)
	if named and named:GetAlpha() ~= 0 then named:SetAlpha(0) end
	local active = bu.GetNormalTexture and bu:GetNormalTexture()
	if active and active ~= named and active:GetAlpha() ~= 0 then active:SetAlpha(0) end
end

local function ApplyLortiTextures(bu, name, isItem)
	local ic = _G[name .. "Icon"] or _G[name .. "IconTexture"]
	local fl = _G[name .. "Flash"]
	local nt = NormalTextureOf(bu, name)
	-- LargeItemButtonTemplate / QuestItemTemplate buttons include the item name
	-- in the button itself.  Their IconTexture is the square visual slot; using
	-- the whole button as the anchor stretches both the icon and Lorti artwork.
	local decorationAnchor = isItem and ic or bu
	if not isItem then
		local saved = SavedOf(bu)
		if saved and bu.SetCheckedTexture and not IsSecureBarButton(bu) then
			bu:SetCheckedTexture(saved.checked)
			local checked = bu.GetCheckedTexture and bu:GetCheckedTexture()
			if checked then
				-- Keep Blizzard's CheckButtonHilight white-tinted, which preserves
				-- the native yellow queued/current-action indicator.
				if not IsSecureBarButton(bu) then
					checked.suiLortiKeepBlizzardColor = true
				end
				L._painting = true
				checked:SetVertexColor(1, 1, 1, 1)
				L._painting = false
			end
		end
	end

	PaintActionOverlays(bu, fl, decorationAnchor, isItem)

	-- Equipped items keep Blizzard's green Border. Do not swap the ring to
	-- gloss_grey: UpdateUsable then paints that ring white.
	local normalTex = cfg.textures.normal
	local vr, vg, vb, va = cfg.color.normal.r, cfg.color.normal.g, cfg.color.normal.b, cfg.color.normal.a
	local secure = IsSecureBarButton(bu)
	-- On protected buttons Blizzard can replace NormalTexture after styling.
	-- Keep its region invisible and draw Lorti's original artwork separately.
	if not secure then
		CallWidget(bu, "SetNormalTexture", normalTex)
	end
	nt = NormalTextureOf(bu, name)
	if secure then
		HideNativeRim(bu, name)
		ShowOwnedGloss(bu, normalTex, vr, vg, vb, va)
	elseif nt then
		SetRegionTexture(nt, normalTex)
		nt:SetAlpha(1)
		nt:ClearAllPoints()
		nt:SetAllPoints(decorationAnchor or bu)
		L._painting = true
		nt:SetVertexColor(vr, vg, vb, va)
		L._painting = false
		HookNormalTex(nt)
	end

	if ic then
		ic:SetTexCoord(0.1, 0.9, 0.1, 0.9)
		if not isItem then
			ic:ClearAllPoints()
			ic:SetPoint("TOPLEFT", bu, "TOPLEFT", 2, -2)
			ic:SetPoint("BOTTOMRIGHT", bu, "BOTTOMRIGHT", -2, 2)
		end
	end
	return decorationAnchor
end

-- rActionButtonStyler_AB_style
function L.StyleActionButton(self)
	if not L.enabled or not self then
		return
	end
	local parent = self.GetParent and self:GetParent()
	local pname = parent and parent.GetName and parent:GetName()
	if pname == "MultiCastActionBarFrame" or pname == "MultiCastActionPage1"
		or pname == "MultiCastActionPage2" or pname == "MultiCastActionPage3" then
		return
	end
	local name = self.GetName and self:GetName()
	if not name then
		return
	end
	local bu = _G[name] or self
	local bo = _G[name .. "Border"]
	local cd = _G[name .. "Cooldown"]

	SaveButton(bu, name)
	if bo then
		if bu.action and IsEquippedAction(bu.action) then
			bo:SetVertexColor(0, 1.0, 0, 0.35)
			bo:Show()
		else
			bo:Hide()
		end
	end
	ApplyLortiTextures(bu, name, false)
	if cd then
		cd:SetPoint("TOPLEFT", bu, "TOPLEFT", cfg.cooldown.spacing, -cfg.cooldown.spacing)
		cd:SetPoint("BOTTOMRIGHT", bu, "BOTTOMRIGHT", -cfg.cooldown.spacing, cfg.cooldown.spacing)
	end
	MarkStyled(bu, true)
	local bg = ButtonBackground(bu)
	if not bg then
		applyBackground(bu)
	end
	L.paintedButtons[name] = true
	SyncOwnedChrome(bu)
end

-- rActionButtonStyler_AB_stylepet
-- Pet buttons are protected. Moving their NormalTexture (66x66, centered)
-- or Icon taints the button, so a combat click cannot Show/Hide slots.
-- Draw the gloss on our own texture and only fade the Blizzard ring.
local function StylePetButton(bu, name)
	if not ButtonIsOnScreen(bu) then
		SyncOwnedChrome(bu)
		return
	end
	SaveButton(bu, name)
	HideNativeRim(bu, name)
	local ic = _G[name .. "Icon"] or _G[name .. "IconTexture"]
	if ic then
		ic:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	end
	local c = cfg.color.normal
	ShowOwnedGloss(bu, cfg.textures.normal, c.r, c.g, c.b, c.a)
	local bg = ButtonBackground(bu)
	if not bg then
		applyBackground(bu)
	end
	MarkStyled(bu, true)
	L.paintedButtons[name] = true
	SyncOwnedChrome(bu)
end

function L.StylePetButtons()
	if not L.enabled then
		return
	end
	local i, slots
	slots = NUM_PET_ACTION_SLOTS or 10
	for i = 1, slots do
		local name = "PetActionButton" .. i
		local bu = _G[name]
		if bu then
			StylePetButton(bu, name)
		end
	end
end

-- Only item-style buttons that live on the main menu bar panel are skinned.
-- Everything else (professions, talents/inspect, LFD rewards, loot, quests,
-- bags, bank, merchant, trade, mail...) must keep Blizzard's default look:
-- the gloss/vertex tint made those icons far too dark.
local function IsPanelItemButtonName(name)
	if type(name) ~= "string" then
		return false
	end
	if name == "MainMenuBarBackpackButton" then
		return true
	end
	return name:match("^CharacterBag%dSlot$") ~= nil
end

L.IsPanelItemButtonName = IsPanelItemButtonName

function L:PaintItemButton(button)
	if not self.enabled then
		return
	end
	if type(button) == "string" then
		button = _G[button]
	end
	if not button then
		return
	end
	local name = button.GetName and button:GetName()
	if not name or not IsPanelItemButtonName(name) then
		return
	end
	SaveButton(button, name)
	local decorationAnchor = ApplyLortiTextures(button, name, true)
	button.suiLortiStyled = true
	if not button.bg then
		applyBackground(button, decorationAnchor)
	else
		button.bg:Show()
	end
	self.paintedButtons[name] = true
end

function L:RestoreButton(bu)
	if type(bu) == "string" then
		bu = _G[bu]
	end
	if not bu then
		return
	end
	local name = bu.GetName and bu:GetName()
	if not name then
		return
	end
	local saved = SavedOf(bu)
	local ic = _G[name .. "Icon"] or _G[name .. "IconTexture"]
	local fl = _G[name .. "Flash"]
	local nt = NormalTextureOf(bu, name)
	local bo = _G[name .. "Border"]
	local secure = IsSecureBarButton(bu)

	MarkStyled(bu, false)
	savedByButton[bu] = nil
	if bo and not secure then
		bo.Show = nil
	end

	if saved then
		if bu.SetHighlightTexture and not secure then
			bu:SetHighlightTexture(saved.highlight)
		end
		if bu.SetPushedTexture and not secure then
			bu:SetPushedTexture(saved.pushed)
		end
		if bu.SetCheckedTexture and not secure then
			bu:SetCheckedTexture(saved.checked)
		end
		if secure then
			local highlight = bu.GetHighlightTexture and bu:GetHighlightTexture()
			local pushed = bu.GetPushedTexture and bu:GetPushedTexture()
			local checked = bu.GetCheckedTexture and bu:GetCheckedTexture()
			if highlight then highlight:SetTexture(saved.highlight) end
			if pushed then pushed:SetTexture(saved.pushed) end
			if checked then checked:SetTexture(saved.checked) end
		end
		if fl then
			fl:SetTexture(saved.flash)
		end
		if bu.SetNormalTexture and not secure then
			bu:SetNormalTexture(saved.normal)
		end
		if ic then
			ic:SetTexCoord(saved.iconULx, saved.iconULy, saved.iconLLx, saved.iconLLy, saved.iconURx, saved.iconURy, saved.iconLRx, saved.iconLRy)
			if not secure and not name:match("^PetActionButton%d+$") then
				ic:SetPoint("TOPLEFT", bu, "TOPLEFT", 2, -2)
				ic:SetPoint("BOTTOMRIGHT", bu, "BOTTOMRIGHT", -2, 2)
			end
		end
	else
		if bu.SetNormalTexture and not secure then
			bu:SetNormalTexture([[Interface\Buttons\UI-Quickslot2]])
		end
		if ic then
			ic:SetTexCoord(0, 1, 0, 1)
		end
	end

	nt = NormalTextureOf(bu, name)
	if nt then
		if secure then
			nt:SetTexture(saved and saved.normal or [[Interface\Buttons\UI-Quickslot2]])
		end
		nt:SetAlpha(1)
		self:RestoreTexture(nt)
	end
	local activeNormal = bu.GetNormalTexture and bu:GetNormalTexture()
	if activeNormal and activeNormal ~= nt then activeNormal:SetAlpha(1) end
	if petGlossByButton[bu] then
		petGlossByButton[bu]:Hide()
	end
	if bo and bu.action and IsEquippedAction(bu.action) then
		bo:SetVertexColor(0, 1.0, 0, 0.35)
		bo:Show()
	elseif bo then
		bo:Hide()
	end
	local bg = ButtonBackground(bu)
	if bg then
		bg:Hide()
	end
	bgByButton[bu] = nil
	MarkStyled(bu, false)
	self.paintedButtons[name] = nil

	-- Free panels use Frost's ActionButtonTemplate geometry (icon fill + oversized
	-- Quickslot rim). Restore that instead of leaving Lorti's 2px inset / gloss.
	if bu.sarychDefaultActionArtwork then
		local FA = SarychUI and SarychUI.FrostAtomBars
		local ActionBar = FA and FA.ActionBar
		if ActionBar and ActionBar.ResetDefaultActionArtwork then
			ActionBar:ResetDefaultActionArtwork(bu)
		end
	end
end

L.paperDollSlots = {
	"HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
	"ShirtSlot", "TabardSlot", "WristSlot", "HandsSlot", "WaistSlot",
	"LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot",
	"Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot",
	"RangedSlot", "AmmoSlot",
}

function L:PaintAllItemButtons()
	-- Panel-only: backpack + bag slots on the main menu bar.
	local i
	self:PaintItemButton("MainMenuBarBackpackButton")
	for i = 0, 3 do
		self:PaintItemButton("CharacterBag" .. i .. "Slot")
	end
end

function L:ApplyButtons()
	local i
	for i = 1, 12 do
		self.StyleActionButton(_G["ActionButton" .. i])
		self.StyleActionButton(_G["BonusActionButton" .. i])
		self.StyleActionButton(_G["MultiBarBottomLeftButton" .. i])
		self.StyleActionButton(_G["MultiBarBottomRightButton" .. i])
		self.StyleActionButton(_G["MultiBarRightButton" .. i])
		self.StyleActionButton(_G["MultiBarLeftButton" .. i])
	end
	self.StylePetButtons()
	for i = 1, 2 do
		self.StyleActionButton(_G["PossessButton" .. i])
	end
	local forms = NUM_SHAPESHIFT_SLOTS or 10
	for i = 1, forms do
		self.StyleActionButton(_G["ShapeshiftButton" .. i])
	end
	self:PaintAllItemButtons()

	-- Free panels (barMode = "frostatom") never call ActionButton_Update, so the
	-- classic hooks above never reach SarychUIActionButtonN. Style them the same
	-- way: Lorti gloss / overlay swap + vertex tint.
	local FA = SarychUI and SarychUI.FrostAtomBars
	if FA and FA.IsActive and FA.IsActive() and FA.ForEachStyledButton then
		FA.ForEachStyledButton(self.StyleActionButton)
	end
end

function L:RestoreButtons()
	local name, names, i
	names = {}
	for name in pairs(self.paintedButtons) do
		names[#names + 1] = name
	end
	for i = 1, #names do
		self:RestoreButton(names[i])
	end
end

function L:InstallButtonHooks()
	if self.buttonHooksInstalled then
		return
	end
	self.buttonHooksInstalled = true
	if not hooksecurefunc then
		return
	end

	-- Do not hook UpdateUsable or UpdateState. ActionButton_Update calls
	-- them and then stores rangeTimer and feedback_action on the button.
	-- The post-hook taints those stores, so the button's click is SarychUI
	-- and /castsequence dies in CastSpellByName.
	if ActionButton_Update then
		hooksecurefunc("ActionButton_Update", L.StyleActionButton)
	end
	if ActionButton_ShowGrid then
		hooksecurefunc("ActionButton_ShowGrid", L.StyleActionButton)
	end
	-- Blizzard may replace the button's normal region outside ActionButton_Update.
	-- Keep that region hidden; the Lorti artwork belongs to our own frame.
	if ActionButton_OnEvent then
		hooksecurefunc("ActionButton_OnEvent", function(button, event)
			if not L.enabled or not IsStyled(button) then
				return
			end
			local name = button.GetName and button:GetName()
			HideNativeRim(button, name)
			if event ~= "ACTIONBAR_UPDATE_USABLE" then return end
			local borderName = name and (name .. "Border")
			local border = borderName and _G[borderName]
			if border and button.action and IsEquippedAction(button.action) then
				border:SetVertexColor(0, 1.0, 0, 0.35)
				border:Show()
			end
		end)
	end
	if ActionButton_OnUpdate then
		hooksecurefunc("ActionButton_OnUpdate", function(button)
			if L.enabled and IsStyled(button) then
				HideNativeRim(button, button.GetName and button:GetName())
			end
		end)
	end
	if PetActionBar_Update then
		hooksecurefunc("PetActionBar_Update", L.StylePetButtons)
	end
	-- After UpdateState returns, Show/Hide of the stance slots is already done.
	-- Styling here does not run inside that loop.
	if ShapeshiftBar_UpdateState then
		hooksecurefunc("ShapeshiftBar_UpdateState", function()
			if not L.enabled then
				return
			end
			local n = NUM_SHAPESHIFT_SLOTS or 10
			local i
			for i = 1, n do
				local button = _G["ShapeshiftButton" .. i]
				if button and button:IsVisible() then
					L.StyleActionButton(button)
				end
			end
		end)
	end

	if SetItemButtonTexture then
		hooksecurefunc("SetItemButtonTexture", function(button)
			L:PaintItemButton(button)
		end)
	end
	if SetItemButtonNormalTextureVertexColor then
		hooksecurefunc("SetItemButtonNormalTextureVertexColor", function(button, r, g, b)
			if r == 1 and g == 1 and b == 1 then
				L:PaintItemButton(button)
			elseif r == 0.5 and g == 0.5 and b == 1 then
				L:PaintItemButton(button)
			end
		end)
	end
	-- ContainerFrame_Update / PaperDollItemSlotButton_Update hooks were removed:
	-- bag, character and inspect item slots keep their default Blizzard textures.
end
