local SUI = SarychUI
local style = SUI.extensions.interface_style

local function ReloadAfterChange(revert)
	SUI:NotifySarychUIOptionsChange()
	if SUI.ShowReloadPopup then
		SUI:ShowReloadPopup("Необходимо перезагрузить интерфейс, чтобы применить изменения.", function()
			revert()
			SUI:NotifySarychUIOptionsChange()
		end)
	elseif StaticPopup_Show then
		StaticPopup_Show("SARYCHUI_RELOAD_UI")
	end
end

local function RefreshStylePreviews()
	if SUI.ActionBarAppearancePreview then SUI.ActionBarAppearancePreview:RefreshAll() end
	if SUI.ActionBarColorPreview then SUI.ActionBarColorPreview:RefreshAll() end
	if SUI.ActionBarTransparencyPreview then SUI.ActionBarTransparencyPreview:RefreshAll() end
	if SUI.AurasPreview then SUI.AurasPreview:RefreshAll() end
end

function style:GetOptions()
	return {
		type = "group",
		name = "Стиль интерфейса",
		args = {
			enabled = {
				type = "toggle", name = "Включить", order = 1,
				get = function()
					local db = style:GetDB()
					return db and db.enabled == true or false
				end,
				set = function(_, value)
					local db = style:GetDB()
					if not db or db.enabled == (value == true) then return end
					local previous = db.enabled
					db.enabled = value == true
					ReloadAfterChange(function() db.enabled = previous end)
				end,
			},
			textures = {
				type = "select", name = "Текстуры", order = 2,
				width = "full",
				disabled = function()
					local db = style:GetDB()
					return not (db and db.enabled)
				end,
				values = { black = "Тёмный стиль" },
				get = function() return style:GetTextureMode() end,
				set = function() end,
			},
			appearance = {
				type = "group", name = "", order = 3, inline = true,
				args = {
					styleColor = {
						type = "color", name = "Цвет текстур", order = 1,
						hasAlpha = true,
						disabled = function()
							local db = style:GetDB()
							return not (db and db.enabled)
						end,
						get = function() return style.GetColor() end,
						set = function(_, r, g, b, a)
							local db = style:GetDB()
							if not db then return end
							db.styleColor = { r = r, g = g, b = b, a = a or 1 }
							style:RefreshColor()
							RefreshStylePreviews()
							SUI:NotifySarychUIOptionsChange()
						end,
					},
					glossBrightness = {
						type = "range", name = "Яркость gloss", order = 2,
						width = "full", min = 0, max = 1, step = 0.05,
						disabled = function()
							local db = style:GetDB()
							return not (db and db.enabled)
						end,
						get = function() return style:GetGlossBrightness() end,
						set = function(_, value)
							local db = style:GetDB()
							if not db then return end
							db.glossBrightness = math.max(0, math.min(1, tonumber(value) or 1))
							style:RefreshGloss()
							RefreshStylePreviews()
							SUI:NotifySarychUIOptionsChange()
						end,
					},
					debuffOriginalColor = {
						type = "toggle", name = "Оригинальный цвет дебафов", order = 3,
						disabled = function()
							local db = style:GetDB()
							return not (db and db.enabled)
						end,
						get = function() return style:GetDebuffOriginalColor() end,
						set = function(_, value)
							local db = style:GetDB()
							if not db then return end
							db.debuffOriginalColor = value == true
							if style.RefreshAuras then style:RefreshAuras() end
							RefreshStylePreviews()
							SUI:NotifySarychUIOptionsChange()
						end,
					},
				},
			},
		},
	}
end
