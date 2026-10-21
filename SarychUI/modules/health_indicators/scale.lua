-- SarychUI nameplate scale for classic WoW plates (VirtualPlates-style).

local moduleName = "health_indicators"
local module = SarychUI:GetModule(moduleName)
if not module then return end

local SCALE_MIN = 0.5
local SCALE_MAX = 3
local SCALE_DEFAULT = 1
local FLASH = [[Interface\TargetingFrame\UI-TargetingFrame-Flash]]

local WorldFrameGetChildren = WorldFrame.GetChildren
local InCombat = false
local classicStarted = false

local Plates = {}
local PlatesVisible = {}

local function GetDB()
	if SarychUI.GetModuleProfile then
		return SarychUI:GetModuleProfile(moduleName)
	end
	local profile = SarychUI.db and SarychUI.db.profile
	return profile and profile.modules and profile.modules[moduleName]
end

local function GetMode()
	if SarychUI.GetNameplateMode then
		return SarychUI:GetNameplateMode()
	end
	return "classic"
end

function module:GetNameplateScale()
	local db = GetDB()
	local scale = db and tonumber(db.scale) or SCALE_DEFAULT
	if scale < SCALE_MIN then
		scale = SCALE_MIN
	elseif scale > SCALE_MAX then
		scale = SCALE_MAX
	end
	return scale
end

function module:GetClassicPlateVisual(plate)
	return plate and Plates[plate]
end

local function AttachAutolosText(plate, visual)
	local fs = plate and plate.fontStringRange
	if not fs or not visual or not fs.SetParent then
		return
	end
	if fs.GetParent and fs:GetParent() == visual then
		return
	end
	fs:SetParent(visual)
end

local function ApplyClassicPlateScale(plate)
	local scale = module:GetNameplateScale()
	local visual = plate and Plates[plate]
	if not visual then
		return
	end
	visual:SetScale(scale)
	AttachAutolosText(plate, visual)
	if not InCombat then
		plate:SetSize(visual.BaseWidth * scale, visual.BaseHeight * scale)
	end
end

local function ApplyClassicScaleAll()
	for plate in pairs(Plates) do
		ApplyClassicPlateScale(plate)
	end
end

local function ResetPoint(plate, region, point, relFrame, ...)
	if relFrame == plate then
		region:SetPoint(point, Plates[plate], ...)
	end
end

local function PlateOnShow(plate)
	local visual = Plates[plate]
	if not visual then
		return
	end
	PlatesVisible[plate] = visual
	visual:Show()
	AttachAutolosText(plate, visual)
	ApplyClassicPlateScale(plate)
	for index = 1, #plate do
		local region = plate[index]
		if region and region.GetNumPoints then
			for point = 1, region:GetNumPoints() do
				ResetPoint(plate, region, region:GetPoint(point))
			end
		end
	end
end

local function PlateOnHide(plate)
	PlatesVisible[plate] = nil
	local visual = Plates[plate]
	if visual then
		visual:Hide()
	end
end

local function ShouldKeepOnPlate(child, visual)
	if not child or child == visual then
		return true
	end
	if child._suiPlateAura then
		return true
	end
	return false
end

local function ReparentChildren(plate, ...)
	local visual = Plates[plate]
	for index = 1, select("#", ...) do
		local child = select(index, ...)
		if not ShouldKeepOnPlate(child, visual) then
			local levelOffset = child:GetFrameLevel() - plate:GetFrameLevel()
			child:SetParent(visual)
			child:SetFrameLevel(visual:GetFrameLevel() + levelOffset)
			plate[#plate + 1] = child
		end
	end
end

local function ReparentRegions(plate, ...)
	local visual = Plates[plate]
	for index = 1, select("#", ...) do
		local region = select(index, ...)
		region:SetParent(visual)
		plate[#plate + 1] = region
	end
end

local function PlateAdd(plate)
	if Plates[plate] or plate.UnitFrame then
		return
	end

	local visual = CreateFrame("Frame", nil, plate)
	Plates[plate] = visual
	plate._suiClassicVisual = visual
	visual:Hide()
	visual:SetPoint("TOP")
	visual.BaseWidth, visual.BaseHeight = plate:GetWidth(), plate:GetHeight()
	if not visual.BaseWidth or visual.BaseWidth == 0 then
		visual.BaseWidth = 128
	end
	if not visual.BaseHeight or visual.BaseHeight == 0 then
		visual.BaseHeight = 32
	end
	visual:SetSize(visual.BaseWidth, visual.BaseHeight)

	ReparentChildren(plate, plate:GetChildren())
	ReparentRegions(plate, plate:GetRegions())
	visual:EnableDrawLayer("HIGHLIGHT")

	if plate:GetScript("OnShow") then
		plate:HookScript("OnShow", PlateOnShow)
	else
		plate:SetScript("OnShow", PlateOnShow)
	end
	if plate:GetScript("OnHide") then
		plate:HookScript("OnHide", PlateOnHide)
	else
		plate:SetScript("OnHide", PlateOnHide)
	end
	if plate:IsVisible() then
		PlateOnShow(plate)
	end
end

local function PlatesScan(...)
	for index = 1, select("#", ...) do
		local frame = select(index, ...)
		if not Plates[frame] and not frame.UnitFrame then
			local region = frame:GetRegions()
			if region and region.GetObjectType and region:GetObjectType() == "Texture" and region.GetTexture and region:GetTexture() == FLASH then
				PlateAdd(frame)
			end
		end
	end
end

local childCount = 0
local function WorldFrameOnUpdate(self)
	if GetMode() ~= "classic" then
		return
	end
	local newChildCount = self:GetNumChildren()
	if childCount ~= newChildCount then
		childCount = newChildCount
		PlatesScan(WorldFrameGetChildren(self))
	end
end

local function StartClassicScale()
	if classicStarted then
		return
	end
	classicStarted = true
	WorldFrame:HookScript("OnUpdate", WorldFrameOnUpdate)
	PlatesScan(WorldFrameGetChildren(WorldFrame))
	childCount = WorldFrame:GetNumChildren()
end

function module:ApplyNameplateScale()
	if GetMode() ~= "classic" then
		return
	end
	StartClassicScale()
	ApplyClassicScaleAll()
	if SarychUI.NameplateDistancePreview and SarychUI.NameplateDistancePreview.RefreshAll then
		SarychUI.NameplateDistancePreview:RefreshAll()
	end
end

function module:InitializeNameplateScale()
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_LOGIN")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			InCombat = true
		elseif event == "PLAYER_REGEN_ENABLED" then
			InCombat = false
			module:ApplyNameplateScale()
		elseif event == "PLAYER_LOGIN" then
			module:ApplyNameplateScale()
		end
	end)

	self:ApplyNameplateScale()
end
