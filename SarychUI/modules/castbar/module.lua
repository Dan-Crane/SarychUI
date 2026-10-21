-- SarychUI Castbar
-- Classic Blizzard bars or Dragonflight artwork; timers live on this module.

local moduleName = "castbar"
local module = {}
SarychUI:RegisterModule(moduleName, module)

function module:DB()
	return SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
		or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
end

function module:IsEnabled()
	local db = self:DB()
	return db and db.enabled ~= false
end

function module:GetBarStyle()
	-- Style is locked for the session; swapping artwork safely needs /reload.
	if self._bootBarStyle then
		return self._bootBarStyle
	end
	local db = self:DB()
	return (db and db.barStyle) or "classic"
end

function module:IsDragonflight()
	return self:IsEnabled() and self:GetBarStyle() == "dragonflight"
end

function module:GetStyleFrame(unitType)
	if self:IsDragonflight() and self.DF and self.DF.GetFrame then
		return self.DF:GetFrame(unitType)
	end
	if unitType == "player" then
		return CastingBarFrame
	elseif unitType == "target" then
		return TargetFrameSpellBar
	elseif unitType == "focus" then
		return FocusFrameSpellBar
	end
	return nil
end

local function ApplyTimers()
	local tools = SarychUI and SarychUI.modules and SarychUI.modules.tools
	if tools and tools.ApplyCastbarTimers then
		tools:ApplyCastbarTimers()
	end
end

function module:Enable()
	local db = self:DB()
	if not db or not db.enabled then
		return
	end
	self._bootBarStyle = self._bootBarStyle or (db.barStyle or "classic")
	if self._bootBarStyle == "dragonflight" and self.DF then
		self.DF:Enable()
	elseif self.DF then
		self.DF:Disable()
	end
	self:ApplyChannelTicks()
	ApplyTimers()
end

function module:Disable()
	if self.Ticks then
		self.Ticks:Disable()
	end
	if self.DF then
		self.DF:Disable()
	end
	local tools = SarychUI and SarychUI.modules and SarychUI.modules.tools
	if tools and tools.DisableCastbarTimers then
		tools:DisableCastbarTimers()
	end
end

function module:ApplyChannelTicks()
	if not self.Ticks then
		return
	end
	local db = self:DB()
	local ticksOn = db and (db.enableCastbarTicks == nil or db.enableCastbarTicks == 1 or db.enableCastbarTicks == true)
	if self:IsEnabled() and ticksOn then
		self.Ticks:Enable()
	else
		self.Ticks:Disable()
	end
end

function module:ApplyScale()
	if self.DF and self.DF.ApplyScale then
		self.DF:ApplyScale()
	end
end

function module:ApplyPlayerIcon()
	if self.DF and self.DF.ApplyPlayerIcon then
		self.DF:ApplyPlayerIcon()
	end
end

function module:ApplyPlayerIconBorderAlpha()
	if self.DF and self.DF.ApplyPlayerIconBorderAlpha then
		self.DF:ApplyPlayerIconBorderAlpha()
	end
end

function module:ApplyPlayerIconCooldown()
	if self.DF and self.DF.ApplyPlayerIconCooldown then
		self.DF:ApplyPlayerIconCooldown()
	end
end

function module:ApplyPlayerTimerOffset()
	local tools = SarychUI and SarychUI.modules and SarychUI.modules.tools
	if tools and tools.ApplyPlayerCastbarTimerOffset then
		tools:ApplyPlayerCastbarTimerOffset()
	end
end

function module:RefreshConfig()
	if self:IsEnabled() then
		self:Enable()
	else
		self:Disable()
	end
end
