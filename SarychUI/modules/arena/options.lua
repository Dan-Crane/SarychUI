-- SarychUI Arena Module Options

local moduleName = "arena"
local L = SarychUI.L
local ACR = LibStub and LibStub("AceConfigRegistry-3.0", true)
local originalEnabledSnapshot = nil

-- Get module
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local function RefreshArenaOptions()
	if SarychUI and SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif ACR then
		ACR:NotifyChange("SarychUI")
	end
end

local function NotifyArenaPreview(key, value, clear)
	local preview = SarychUI and SarychUI.ArenaPreview
	if type(key) == "string" and key:find("^arenaNumbers") then
		preview = SarychUI and SarychUI.ArenaNumbersPreview
	elseif key == "hideGroupRaidText" then
		preview = SarychUI and SarychUI.ArenaGroupTitlesPreview
	end
	if not preview then return end
	if clear and key and preview.ClearLiveValue then
		preview:ClearLiveValue(key)
		if preview.RefreshAll then preview:RefreshAll() end
		return
	end
	if key ~= nil and preview.SetLiveValue then
		preview:SetLiveValue(key, value)
	elseif preview.RefreshAll then
		preview:RefreshAll()
	end
end

local function IsAwesomeWotlkDetected()
	local compat = SarychUI and SarychUI.Compatibility
	if not compat then
		return false
	end
	if compat.GetDllDetectionState then
		return compat:GetDllDetectionState("awesome_wotlk") == "detected"
	end
	if compat.DetectAwesomeWotlkDll then
		return compat:DetectAwesomeWotlkDll()
	end
	return false
end

local function GetDB()
	local root = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return root and root[moduleName]
end

local function EnemySettings()
	local db = GetDB()
	if not db then return end
	db.enemyAbilities = db.enemyAbilities or { displayMode = "cooldown", anchorMode = "auto" }
	db.enemyAbilities.layout = db.enemyAbilities.layout or {
		side = "RIGHT", growth = "RIGHT", x = 2, y = 6,
		autoX = 7, autoY = 0, size = 24, spacing = 5, perRow = 5, cooldownEdge = true,
	}
	return db.enemyAbilities
end

local function RefreshEnemyAbilities()
	local extension = SarychUI.extensions and SarychUI.extensions.party_abilities
	if extension and extension.RefreshConfig then extension:RefreshConfig() end
	local preview = SarychUI.PartyAbilitiesPreview
	if preview and preview.RefreshAll then preview:RefreshAll() end
end

local function EnemyRange(key, label, minimum, maximum, order)
	local defaults = { x = 2, y = 6, autoX = 7, autoY = 0, size = 24, spacing = 5, perRow = 5 }
	return {
		type = "range", name = function() return L[label] end,
		min = minimum, max = maximum, step = 1, order = order,
		get = function()
			local settings = EnemySettings()
			local actual = settings and settings.anchorMode == "auto" and (key == "x" or key == "y") and (key == "x" and "autoX" or "autoY") or key
			return settings and tonumber(settings.layout[actual]) or defaults[actual]
		end,
		set = function(_, value)
			local settings = EnemySettings()
			if not settings then return end
			local actual = settings.anchorMode == "auto" and (key == "x" or key == "y") and (key == "x" and "autoX" or "autoY") or key
			settings.layout[actual] = value
			RefreshEnemyAbilities()
		end,
	}
end

-- Options table
function module:GetOptions()
    -- snapshot original enabled when opening options (persist while panel is open)
    local db = GetDB()
    if originalEnabledSnapshot == nil then
        originalEnabledSnapshot = db and (db.enabled == true) or false
    end
    local originalEnabled = originalEnabledSnapshot
    local options = {
		type = "group",
		name = "Арена",
		desc = "Настройка фреймов арены",
		childGroups = "tab",
		args = {
			-- General tab - same layout pattern as Bags -> Общее
			general = {
				type = "group",
				name = L and (L["General"] or "Общее") or "Общее",
				order = 1,
				args = {
					enabled = {
						type = "toggle",
						name = L and (L["Enable_Module"] or "Включить модуль") or "Включить модуль",
						desc = "Включить или выключить модуль",
						order = 1,
						width = "full",
						get = function()
							local db = GetDB()
							return db and db.enabled or false
						end,
						set = function(_, value)
							local db = GetDB()
							if db then
								db.enabled = value and true or false
							end
						end,
					},
					reloadUI = {
						type = "execute",
						name = "Перезагрузить",
						desc = "Применить изменение статуса модуля (Reload UI)",
						order = 1.5,
						func = function()
							if ReloadUI then ReloadUI() end
						end,
						hidden = function()
							local db = GetDB(); if not db then return true end
							local current = db.enabled and true or false
							return current == (originalEnabled and true or false)
						end,
					},
					useAwesomeWotlk = {
						type = "group",
						name = "Использовать AwesomeWotlk",
						order = 4,
						inline = true,
						hidden = function()
							local db = GetDB()
							return not (db and db.enabled)
						end,
						args = {
							notDetectedNotice = {
								type = "description",
								name = "|cffff4444AwesomeWotlk не обнаружен.|r |cff808080Статус: Система -> Обзор.|r",
								order = 0,
								width = "full",
								hidden = function()
									return IsAwesomeWotlkDetected()
								end,
							},
							enabled = {
								type = "toggle",
								name = "Включить поддержку AwesomeWotlk",
								desc = "Доступно только при обнаруженном AwesomeWotlk (Система -> Обзор).",
								order = 1,
								width = "full",
								disabled = function()
									return not IsAwesomeWotlkDetected()
								end,
								get = function()
									if not IsAwesomeWotlkDetected() then
										return false
									end
									local db = GetDB()
									return (db and db.useAwesomeWotlk == true) or false
								end,
								set = function(_, value)
									if not IsAwesomeWotlkDetected() then
										return
									end
									local db = GetDB(); if not db then return end
									db.useAwesomeWotlk = value and true or false
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									NotifyArenaPreview("useAwesomeWotlk", value and true or false)
									RefreshArenaOptions()
								end,
							},
						},
					},
					awesomeBenefitNote = {
						type = "description",
						name = "|cFFFFD700Пометка:|r Улучшает качество событий неймплейтов, повышает производительность и точность отображения арены.",
						order = 5,
						width = "full",
						hidden = function()
							local db = GetDB()
							return not (db and db.enabled)
						end,
					},
				},
			},
			
			-- Arena settings
			appearance = {
				type = "group",
				name = "Настройки",
				order = 2,
				disabled = function()
					local db = GetDB()
					return not (db and db.enabled)
				end,
				args = {
					arenaPreview = {
						type = "description",
						name = "",
						order = 0,
						width = "full",
						suiArenaPreview = true,
					},
					displayBox = {
						type = "group",
						name = "Отображение",
						order = 1,
						inline = true,
						args = {
							scale = {
								type = "range",
								name = "Масштаб фреймов",
								desc = "Изменяет масштаб вражеских фреймов арены",
								order = 1,
								min = 0.5,
								max = 2.0,
								step = 0.01,
								isPercent = false,
								width = "full",
								get = function()
									local db = GetDB()
									return db and (db.scale or 1.0) or 1.0
								end,
								set = function(_, value)
									local m = SarychUI.modules[moduleName]
									if m and m.SetScale then
										m:SetScale(value)
									end
								end,
							},
							frameSpacing = {
								type = "range",
								name = "Отступ между фреймами",
								desc = "Расстояние между соседними фреймами арены",
								order = 1.5,
								min = 0, max = 60, step = 1,
								width = "full",
								suiPreviewKey = "frameSpacing",
								get = function()
									local db = GetDB()
									return db and (db.frameSpacing or 40) or 40
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.frameSpacing = value
									if module.ApplyFrameSpacing then module:ApplyFrameSpacing() end
									NotifyArenaPreview("frameSpacing", value)
								end,
							},
							classColorHP = {
								type = "toggle",
								name = "Цвет класса для полосы здоровья",
								desc = "Красить полосу здоровья арены в цвет класса противника",
								order = 2,
								width = "full",
								get = function()
									local db = GetDB()
									-- default: enabled (true) when nil
									return db and (db.classColorHP ~= false)
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.classColorHP = value and true or false
									local m = SarychUI.modules[moduleName]
									if m and m.ApplyClassColoring then
										m:ApplyClassColoring()
									end
									NotifyArenaPreview("classColorHP", value and true or false)
								end,
							},
							distanceAlpha = {
								type = "toggle",
								name = "Включить прозрачность от дистанции",
								desc = "Делает арена фреймы полупрозрачными (50%), когда противник дальше 40 ярдов.\n\nРаботает только с AwesomeWotlk.",
								order = 3,
								width = "full",
								suiHelpIcon = true,
								hidden = function()
									local db = GetDB()
									return not (db and db.useAwesomeWotlk == true and IsAwesomeWotlkDetected())
								end,
								get = function()
									local db = GetDB()
									return (db and db.distanceAlpha == true) or false
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.distanceAlpha = value and true or false
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									NotifyArenaPreview("distanceAlpha", value and true or false)
								end,
							},
						},
					},
					positionTestBox = {
						type = "group",
						name = "Расположение и тестирование",
						order = 2,
						inline = true,
						args = {
							freeMove = {
								type = "execute",
								name = function()
									local db = GetDB() or {}
									if db.showDragFrame == 1 then
										return "Свободное перемещение |cff00ff00(вкл)|r"
									end
									return "Свободное перемещение"
								end,
								desc = "Показать зелёную рамку для перетаскивания контейнера арены",
								order = 1,
								width = "full",
								suiFullRow = true,
								func = function()
									local db = GetDB()
									if not db then return end
									local val = not (db.showDragFrame == 1)
									db.showDragFrame = val and 1 or 0
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									local panel = SarychUI.PositionDragPanel
									if panel and panel.Toggle then panel:Toggle("arenaContainer", val) end
									RefreshArenaOptions()
								end,
								suiResetDefaults = function()
									local db = GetDB(); if not db then return end
									local def = SarychUI.defaults and SarychUI.defaults.profile.modules.arena
									db.arenaX = (def and def.arenaX) or -311
									db.arenaY = (def and def.arenaY) or 131
									db.arenaA = (def and def.arenaA) or "RIGHT"
									db.arenaR = (def and def.arenaR) or "RIGHT"
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									local panel = SarychUI.PositionDragPanel
									if panel and panel.SyncDraftIfOpen then
										panel:SyncDraftIfOpen("arenaContainer", db.arenaX, db.arenaY, db.arenaA, db.arenaR)
									end
									RefreshArenaOptions()
								end,
							},
							test2 = {
								type = "toggle",
								name = "Показать 2 арена фрейма",
								desc = "Показать 2 тестовых фрейма",
								order = 3,
								width = "full",
								get = function()
									local db = GetDB()
									return db and db.testMode == 2
								end,
								set = function(_, value)
									local db = GetDB()
									local m = SarychUI.modules[moduleName]
									if not db or not m then return end
									if value then
										local oldMode = db.testMode or 0
										db.testMode = 2
										if not (m.Test and m:Test(2)) then db.testMode = oldMode end
									else
										db.testMode = 0
										if m.HideArenaEnemyFrames then m:HideArenaEnemyFrames() end
									end
								end,
							},
							test3 = {
								type = "toggle",
								name = "Показать 3 арена фрейма",
								desc = "Показать 3 тестовых фрейма",
								order = 4,
								width = "full",
								get = function()
									local db = GetDB()
									return db and db.testMode == 3
								end,
								set = function(_, value)
									local db = GetDB()
									local m = SarychUI.modules[moduleName]
									if not db or not m then return end
									if value then
										local oldMode = db.testMode or 0
										db.testMode = 3
										if not (m.Test and m:Test(3)) then db.testMode = oldMode end
									else
										db.testMode = 0
										if m.HideArenaEnemyFrames then m:HideArenaEnemyFrames() end
									end
								end,
							},
							test5 = {
								type = "toggle",
								name = "Показать 5 арена фреймов",
								desc = "Показать 5 тестовых фреймов",
								order = 5,
								width = "full",
								get = function()
									local db = GetDB()
									return db and db.testMode == 5
								end,
								set = function(_, value)
									local db = GetDB()
									local m = SarychUI.modules[moduleName]
									if not db or not m then return end
									if value then
										local oldMode = db.testMode or 0
										db.testMode = 5
										if not (m.Test and m:Test(5)) then db.testMode = oldMode end
									else
										db.testMode = 0
										if m.HideArenaEnemyFrames then m:HideArenaEnemyFrames() end
									end
								end,
							},
						},
					},
					trinketsBox = {
						type = "group",
						name = "Тринкеты и расовые способности",
						order = 3,
						inline = true,
						args = {
							trinketEnabled = {
								type = "toggle",
								name = "Включить тринкеты",
								desc = "Включить отображение иконок тринкетов. У людей в этом слоте показывается «Каждый за себя».",
								order = 1,
								width = "full",
								get = function()
									local db = GetDB()
									return db and db.Trinkets and db.Trinkets.enabled or false
								end,
								set = function(_, value)
									local db = GetDB()
									if not db then return end
									db.Trinkets = db.Trinkets or {}
									db.Trinkets.enabled = value and true or false
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									if m and m.Trinkets then m.Trinkets:RefreshIcons() end
									NotifyArenaPreview("trinketEnabled", value and true or false)
								end,
							},
							racialEnabled = {
								type = "toggle",
								name = "Включить расовую способность",
								desc = "Включить отображение отдельных иконок расовых способностей. «Каждый за себя» зависит от настройки тринкетов.",
								order = 2,
								width = "full",
								get = function()
									local db = GetDB()
									return db and db.Trinkets and db.Trinkets.racialEnabled or false
								end,
								set = function(_, value)
									local db = GetDB()
									if not db then return end
									db.Trinkets = db.Trinkets or {}
									db.Trinkets.racialEnabled = value and true or false
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									if m and m.Trinkets then m.Trinkets:RefreshIcons() end
									NotifyArenaPreview("racialEnabled", value and true or false)
								end,
							},
							trinketsScale = {
								type = "range",
								name = "Масштаб иконок",
								desc = "Изменяет масштаб иконок тринкетов и расовых способностей",
								order = 3,
								min = 0.5,
								max = 2.0,
								step = 0.01,
								width = "full",
								suiPreviewKey = "trinketsScale",
								get = function()
									local db = GetDB()
									return db and db.Trinkets and (db.Trinkets.scale or 1.0) or 1.0
								end,
								set = function(_, value)
									local db = GetDB()
									if not db then return end
									db.Trinkets = db.Trinkets or {}
									db.Trinkets.scale = tonumber(value) or 1.0
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									if m and m.Trinkets then m.Trinkets:RefreshIcons() end
									NotifyArenaPreview("trinketsScale", nil, true)
								end,
							},
						},
					},
				},
			},

			extra = {
				type = "group",
				name = L and (L["Extra"] or "Дополнительно") or "Дополнительно",
				order = 3,
				disabled = function()
					local db = GetDB()
					return not (db and db.enabled)
				end,
				args = {
					arenaNumbersPreview = {
						type = "description",
						name = "",
						order = 0,
						width = "full",
						suiArenaNumbersPreview = true,
					},
					arenaNumbersBox = {
						type = "group",
						name = "Заменять имена на номера",
						desc = "Добавлено по просьбе: Hannahmckay",
						order = 1,
						inline = true,
						suiHelpIcon = true,
						args = {
							arenaNumbers = {
								type = "toggle",
								name = "Включить",
								desc = "Включает замену имён противников на номера arena1-5. Ниже можно отдельно выбрать неймплейты и арена-фреймы.",
								order = 1,
								width = "full",
								suiPreviewKey = "arenaNumbers",
								get = function()
									local db = GetDB()
									return db and (db.arenaNumbers == 1 or db.arenaNumbers == true)
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.arenaNumbers = value and 1 or 0
									local m = SarychUI.modules[moduleName]
									if m and m.UpdateArenaNameplates then
										m:UpdateArenaNameplates()
									end
									NotifyArenaPreview("arenaNumbers", value and 1 or 0)
									RefreshArenaOptions()
								end,
							},
							arenaNumbersNameplates = {
								type = "toggle",
								name = "Заменять на неймплейтах",
								desc = "На арене заменяет имя над неймплейтом противника на его номер arena1-5.",
								order = 2,
								width = "full",
								suiPreviewKey = "arenaNumbersNameplates",
								disabled = function()
									local db = GetDB()
									return not (db and (db.arenaNumbers == 1 or db.arenaNumbers == true))
								end,
								get = function()
									local db = GetDB()
									return db and (db.arenaNumbersNameplates == nil
										or db.arenaNumbersNameplates == 1 or db.arenaNumbersNameplates == true)
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.arenaNumbersNameplates = value and 1 or 0
									local m = SarychUI.modules[moduleName]
									if m and m.UpdateArenaNameplates then
										m:UpdateArenaNameplates()
									end
									NotifyArenaPreview("arenaNumbersNameplates", value and 1 or 0)
								end,
							},
							arenaNumbersArenaFrames = {
								type = "toggle",
								name = "Заменять на арена-фреймах",
									desc = "На арене заменяет имена на номера в стандартных арена-фреймах.",
								order = 3,
								width = "full",
								suiPreviewKey = "arenaNumbersArenaFrames",
								disabled = function()
									local db = GetDB()
									return not (db and (db.arenaNumbers == 1 or db.arenaNumbers == true))
								end,
								get = function()
									local db = GetDB()
									return db and (db.arenaNumbersArenaFrames == nil
										or db.arenaNumbersArenaFrames == 1 or db.arenaNumbersArenaFrames == true)
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.arenaNumbersArenaFrames = value and 1 or 0
									local m = SarychUI.modules[moduleName]
									if m and m.UpdateArenaNameplates then
										m:UpdateArenaNameplates()
									end
									NotifyArenaPreview("arenaNumbersArenaFrames", value and 1 or 0)
								end,
							},
						},
					},
					groupTitlesPreview = {
						type = "description",
						name = "",
						order = 2,
						width = "full",
						suiArenaGroupTitlesPreview = true,
					},
					hideGroupRaidBox = {
						type = "group",
						name = "Скрыть текст «Группа/рейд»",
						order = 3,
						inline = true,
						args = {
							hideGroupRaidText = {
								type = "toggle",
								name = "Включить",
								desc = "На арене скрывает надписи «Группа» и «Рейд» над рамками персонажей. Вне арены текст не трогает.",
								order = 1,
								width = "full",
								suiPreviewKey = "hideGroupRaidText",
								get = function()
									local db = GetDB()
									return db and (db.hideGroupRaidText == 1 or db.hideGroupRaidText == true)
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.hideGroupRaidText = value and 1 or 0
									local m = SarychUI.modules[moduleName]
									if m and m.UpdateGroupTitles then
										m:UpdateGroupTitles()
									end
									NotifyArenaPreview("hideGroupRaidText", value and 1 or 0)
								end,
							},
						},
					},
					retabBox = {
						type = "group",
						name = "Переназначение TAB",
						desc = "Добавлено по просьбе: Hannahmckay",
						order = 4,
						inline = true,
						args = {
							retab = {
								type = "toggle",
								name = "Включить",
								desc = "На арене и на поле боя TAB выбирает вражеских игроков, а не мобов.",
								order = 1,
								width = "full",
								get = function()
									local db = GetDB()
									return db and (db.retab == 1 or db.retab == true)
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.retab = value and 1 or 0
									local m = SarychUI.modules[moduleName]
									if m and m.UpdateRetab then
										m:UpdateRetab()
									end
								end,
							},
						},
					},
				},
			},
		},
	}
	options.args.enemyAbilities = {
		type = "group", name = "Способности противников", order = 4,
		args = {
			enabled = {
				type = "toggle", name = "Включить", order = 1, width = "full",
				get = function()
					local settings = EnemySettings()
					return settings and settings.enabled ~= false
				end,
				set = function(_, value)
					local settings = EnemySettings()
					if not settings then return end
					settings.enabled = value and true or false
					RefreshEnemyAbilities()
					RefreshArenaOptions()
				end,
			},
			display = {
				type = "select", name = function() return L["PA_Content"] end, order = 2,
				disabled = function() local settings = EnemySettings(); return not settings or settings.enabled == false end,
				values = { all = L["PA_AllAbilities"], cooldown = L["PA_CooldownAbilities"],
					__order = { "all", "cooldown" } },
				get = function()
					local settings = EnemySettings()
					return settings and settings.displayMode or "cooldown"
				end,
				set = function(_, value)
					local settings = EnemySettings()
					if not settings then return end
					settings.displayMode = value
					RefreshEnemyAbilities()
				end,
			},
			anchorMode = {
				type = "select", name = "Крепление", order = 2.5,
				disabled = function() local settings = EnemySettings(); return not settings or settings.enabled == false end,
				values = { auto = "Автоматическое крепление", manual = "Ручное размещение",
					__order = { "auto", "manual" } },
				get = function()
					local settings = EnemySettings()
					return settings and settings.anchorMode or "auto"
				end,
				set = function(_, value)
					local settings = EnemySettings()
					if not settings then return end
					settings.anchorMode = value
					RefreshEnemyAbilities()
				end,
			},
			controls = { type = "group", inline = true, name = "", order = 3, suiTwoCol = true,
				disabled = function() local settings = EnemySettings(); return not settings or settings.enabled == false end,
				args = {
					side = { type = "select", name = function() return L["PA_Side"] end, order = 1,
							hidden = function() local settings = EnemySettings(); return settings and settings.anchorMode == "auto" end,
						values = { LEFT = L["PA_Left"], RIGHT = L["PA_Right"],
							TOP = L["PA_Up"], BOTTOM = L["PA_Down"],
							__order = { "LEFT", "RIGHT", "TOP", "BOTTOM" } },
						get = function()
							local settings = EnemySettings()
							return settings and settings.layout.side or "RIGHT"
						end,
						set = function(_, value)
							local settings = EnemySettings()
							if not settings then return end
							settings.layout.side = value
							RefreshEnemyAbilities()
						end },
					growth = { type = "select", name = function() return L["PA_Growth"] end, order = 2,
							hidden = function() local settings = EnemySettings(); return settings and settings.anchorMode == "auto" end,
						values = { LEFT = L["PA_Left"], RIGHT = L["PA_Right"],
							UP = L["PA_Up"], DOWN = L["PA_Down"],
							__order = { "RIGHT", "LEFT", "UP", "DOWN" } },
						get = function()
							local settings = EnemySettings()
							return settings and settings.layout.growth or "RIGHT"
						end,
						set = function(_, value)
							local settings = EnemySettings()
							if not settings then return end
							settings.layout.growth = value
							RefreshEnemyAbilities()
						end },
					x = EnemyRange("x", "PA_OffsetX", -150, 150, 3),
					y = EnemyRange("y", "PA_OffsetY", -150, 150, 4),
					spacing = EnemyRange("spacing", "PA_Spacing", 0, 30, 5),
					perRow = EnemyRange("perRow", "PA_PerRow", 1, 20, 6),
					size = EnemyRange("size", "PA_Size", 12, 128, 7),
				} },
			cooldownEdge = { type = "toggle", name = function() return L["PA_CooldownEdge"] end, order = 4,
				disabled = function() local settings = EnemySettings(); return not settings or settings.enabled == false end,
				get = function()
					local settings = EnemySettings()
					return settings and settings.layout.cooldownEdge == true
				end,
				set = function(_, value)
					local settings = EnemySettings()
					if not settings then return end
					settings.layout.cooldownEdge = value
					RefreshEnemyAbilities()
				end },
			spells = { type = "execute", name = "Настройка заклинаний", order = 99,
				width = "full", suiFullRow = true,
				disabled = function() local settings = EnemySettings(); return not settings or settings.enabled == false end,
				func = function()
					local core = SarychUI.OptionsCore
					if not core then return end
					core._twoPaneSelected = core._twoPaneSelected or {}
					core._twoPaneSelected["extensions/registered"] = "party_abilities"
					core._addonListTabState = core._addonListTabState or {}
					core._addonListTabState.party_abilities = "spells"
					core:SelectSection("sui:extensions")
					core:Refresh()
				end },
		},
	}
	return options
end
