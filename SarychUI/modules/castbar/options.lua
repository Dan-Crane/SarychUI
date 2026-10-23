-- Options: Кастбар (after Action Bar, before Player resources).

local moduleName = "castbar"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local function DB()
	return SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
end

local function NotifyOptionsChange()
	if SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif SarychUI.RefreshConfig then
		SarychUI:RefreshConfig()
	end
end

local function GetTimerSetting(key, default)
	local db = DB()
	if db and db[key] ~= nil then
		return db[key]
	end
	return default
end

local function isTimerOn(key)
	local v = GetTimerSetting(key, 1)
	return v == 1 or v == true
end

local function GetBarStyle()
	local db = DB()
	return (db and db.barStyle) or "classic"
end

local function IsDragonflightStyle()
	return GetBarStyle() == "dragonflight"
end

local function OpenCastbarSettings()
	local OC = SarychUI and SarychUI.OptionsCore
	if OC and OC.SelectTab then
		OC:SelectTab("settings")
	end
end

local function ApplyScale()
	if module.ApplyScale then
		module:ApplyScale()
	end
end

local function ApplyPlayerTimerOffset()
	if module.ApplyPlayerTimerOffset then
		module:ApplyPlayerTimerOffset()
	end
	if SarychUI.CastbarTimerPreview and SarychUI.CastbarTimerPreview.RefreshAll then
		SarychUI.CastbarTimerPreview:RefreshAll()
	end
end

local DF_FIRST_SCALE = 0.9
local DF_FIRST_TIMER_Y = 40

local function SeedDragonflightDefaults(db)
	if not db or db.dragonflightDefaultsApplied then
		return false
	end
	db.scale = DF_FIRST_SCALE
	db.playerTimerOffsetY = DF_FIRST_TIMER_Y
	db.dragonflightDefaultsApplied = true
	return true
end

local function UnseedDragonflightDefaults(db)
	if not db then
		return
	end
	db.scale = 1
	db.playerTimerOffsetY = 0
	db.dragonflightDefaultsApplied = nil
end

local function timerToggleGet(key)
	return function()
		return isTimerOn(key)
	end
end

local function timerToggleSet(key)
	return function(_, val)
		local db = DB()
		if not db then return end
		db[key] = val and 1 or 0
		local tools = SarychUI and SarychUI.modules and SarychUI.modules.tools
		if tools and tools.ApplyCastbarTimers then
			tools:ApplyCastbarTimers()
		end
		if SarychUI.CastbarTimerPreview and SarychUI.CastbarTimerPreview.RefreshAll then
			SarychUI.CastbarTimerPreview:RefreshAll()
		end
		NotifyOptionsChange()
	end
end

local function tickToggleGet(key)
	return function()
		return isTimerOn(key)
	end
end

local function tickToggleSet(key)
	return function(_, val)
		local db = DB()
		if not db then return end
		db[key] = val and 1 or 0
		if module.ApplyChannelTicks then
			module:ApplyChannelTicks()
		end
		NotifyOptionsChange()
	end
end

function module:GetOptions()
	local options = {
		type = "group",
		name = "Кастбар",
		desc = "Настройка полос каста игрока, цели и фокуса.",
		childGroups = "tab",
		args = {
			general = {
				type = "group",
				name = "Общее",
				order = 1,
				args = {
					enabled = {
						type = "toggle",
						name = "Включить модуль",
						desc = "Включить или выключить модуль «Кастбар».",
						order = 1,
						width = "full",
						get = function()
							return DB() and DB().enabled
						end,
						set = function(_, v)
							local db = DB()
							if not db then return end
							db.enabled = v and true or false
							if v then
								SarychUI:EnableModule(moduleName)
							else
								SarychUI:DisableModule(moduleName)
							end
							NotifyOptionsChange()
						end,
					},
					typeRow = {
						type = "group",
						name = "Тип кастбара",
						order = 10,
						inline = true,
						suiSelectWithButton = true,
						args = {
							select = {
								type = "select",
								name = "Внешний вид",
								desc = "Классические полосы каста WoW или оформление Dragonflight. Для смены типа требуется /reload.",
								order = 1,
								values = {
									__order = { "classic", "dragonflight" },
									classic = "Классические",
									dragonflight = "Dragonflight",
								},
								get = function()
									return GetBarStyle()
								end,
								set = function(_, value)
									local db = DB()
									if not db then return end
									local previous = db.barStyle or "classic"
									if previous == value then return end
									db.barStyle = value
									local seeded = value == "dragonflight" and SeedDragonflightDefaults(db)
									NotifyOptionsChange()
									local function revert()
										db.barStyle = previous
										if seeded then
											UnseedDragonflightDefaults(db)
										end
										NotifyOptionsChange()
									end
									local text = "Тип кастбара изменён. Для безопасного применения требуется перезагрузка интерфейса."
									if SarychUI.T then text = SarychUI:T(text) end
									if SarychUI.ShowReloadPopup then
										SarychUI:ShowReloadPopup(text, revert)
									elseif StaticPopup_Show then
										StaticPopup_Show("SARYCHUI_RELOAD_UI")
									end
								end,
							},
							openSettings = {
								type = "execute",
								name = "Настройки",
								desc = "Открыть настройки кастбара.",
								order = 2,
								func = OpenCastbarSettings,
							},
						},
					},
					modeHint = {
						type = "description",
						name = "|cFFFFD700Внимание:|r После смены типа кастбара потребуется перезагрузка интерфейса.",
						order = 30,
						width = "full",
					},
				},
			},
			settings = {
				type = "group",
				name = "Настройки",
				order = 2,
				disabled = function()
					local db = DB()
					return not (db and db.enabled)
				end,
				args = {
					appearanceBox = {
						type = "group",
						name = "Полосы каста",
						order = 2,
						inline = true,
						hidden = function() return not IsDragonflightStyle() end,
						args = {
							scale = {
								type = "range",
								name = "Масштаб",
								desc = "Масштаб полос каста Dragonflight.",
								min = 0.5,
								max = 2.0,
								step = 0.05,
								order = 1,
								width = "full",
								suiFullRow = true,
								get = function()
									local db = DB()
									return db and db.scale or 1
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.scale = val
									ApplyScale()
								end,
							},
							showPlayerIcon = {
								type = "toggle",
								name = "Иконка заклинания игрока",
								desc = "Показывать иконку текущего заклинания слева от кастбара игрока.",
								order = 2,
								width = "full",
								get = function()
									local db = DB()
									return db and (db.showPlayerIcon == true or db.showPlayerIcon == 1) or false
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.showPlayerIcon = val and true or false
									if module.ApplyPlayerIcon then
										module:ApplyPlayerIcon()
									end
									NotifyOptionsChange()
								end,
							},
							showPlayerIconCooldown = {
								type = "toggle",
								name = "Ход каста поверх иконки",
								desc = "Показывать круговой индикатор времени каста поверх иконки заклинания.",
								order = 3,
								width = "full",
								hidden = function()
									local db = DB()
									return not (db and (db.showPlayerIcon == true or db.showPlayerIcon == 1))
								end,
								get = function()
									local db = DB()
									return not db or db.showPlayerIconCooldown ~= false
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.showPlayerIconCooldown = val and true or false
									if module.ApplyPlayerIconCooldown then
										module:ApplyPlayerIconCooldown()
									end
									NotifyOptionsChange()
								end,
							},
						},
					},
					playerTimerBox = {
						type = "group",
						name = "Таймер игрока",
						order = 2,
						inline = true,
						hidden = function() return not IsDragonflightStyle() end,
						args = {
							playerTimerOffsetX = {
								type = "range",
								name = "Смещение по X",
								desc = "Горизонтальное смещение таймера игрока относительно текущего положения.",
								min = -200,
								max = 200,
								step = 1,
								order = 1,
								get = function()
									local db = DB()
									return db and db.playerTimerOffsetX or 0
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.playerTimerOffsetX = val
									ApplyPlayerTimerOffset()
								end,
							},
							playerTimerOffsetY = {
								type = "range",
								name = "Смещение по Y",
								desc = "Вертикальное смещение таймера игрока относительно текущего положения.",
								min = -200,
								max = 200,
								step = 1,
								order = 2,
								get = function()
									local db = DB()
									return db and db.playerTimerOffsetY or 0
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.playerTimerOffsetY = val
									ApplyPlayerTimerOffset()
								end,
							},
						},
					},
					classicCastbarBox = {
						type = "group",
						name = "Положение кастбара",
						order = 1,
						inline = true,
						hidden = IsDragonflightStyle,
						args = {
							classicCastbarOffsetY = {
								type = "range",
								name = "Смещение по Y",
								desc = "Вертикальное смещение самого кастбара игрока от положения Blizzard.",
								min = -300,
								max = 300,
								step = 1,
								order = 1,
								width = "full",
								get = function()
									local db = DB()
									return db and db.classicCastbarOffsetY or 0
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.classicCastbarOffsetY = val
									if module.ApplyClassicCastbarOffset then module:ApplyClassicCastbarOffset() end
								end,
							},
						},
					},
					dragonflightCastbarBox = {
						type = "group",
						name = "Положение кастбара",
						order = 1,
						inline = true,
						hidden = function() return not IsDragonflightStyle() end,
						args = {
							dragonflightCastbarOffsetY = {
								type = "range",
								name = "Смещение по Y",
								desc = "Вертикальное смещение кастбара игрока Dragonflight от положения Blizzard.",
								min = -300,
								max = 300,
								step = 1,
								order = 1,
								width = "full",
								get = function()
									local db = DB()
									return db and db.dragonflightCastbarOffsetY or 0
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.dragonflightCastbarOffsetY = val
									if module.ApplyDragonflightCastbarOffset then module:ApplyDragonflightCastbarOffset() end
								end,
							},
						},
					},
				},
			},
			timers = {
				type = "group",
				name = "Таймеры",
				order = 3,
				disabled = function()
					local db = DB()
					return not (db and db.enabled)
				end,
				args = {
					castbarBox = {
						type = "group",
						name = "Таймер на каст барах",
						desc = "Настройки отображения таймеров на панелях каста заклинаний",
						order = 1,
						inline = true,
						args = {
							preview = {
								type = "description",
								name = "",
								order = 0,
								width = "full",
								suiCastbarTimerPreview = true,
							},
							enableCastbarTimers = {
								type = "toggle",
								name = "Включить",
								desc = "Включить отображение таймеров на каст барах",
								order = 1,
								width = "full",
								get = timerToggleGet("enableCastbarTimers"),
								set = timerToggleSet("enableCastbarTimers"),
							},
							castbarTargets = {
								type = "group",
								name = "Отображать на",
								order = 2,
								inline = true,
								disabled = function() return not isTimerOn("enableCastbarTimers") end,
								args = {
									enableCastbarPlayer = {
										type = "toggle",
										name = "Игрок",
										desc = "Показывать таймер на каст баре игрока",
										order = 1,
										width = "full",
										disabled = function() return not isTimerOn("enableCastbarTimers") end,
										get = timerToggleGet("enableCastbarPlayer"),
										set = timerToggleSet("enableCastbarPlayer"),
									},
									enableCastbarTarget = {
										type = "toggle",
										name = "Цель",
										desc = "Показывать таймер на каст баре цели",
										order = 2,
										width = "full",
										disabled = function() return not isTimerOn("enableCastbarTimers") end,
										get = timerToggleGet("enableCastbarTarget"),
										set = timerToggleSet("enableCastbarTarget"),
									},
									enableCastbarFocus = {
										type = "toggle",
										name = "Фокус",
										desc = "Показывать таймер на каст баре фокуса",
										order = 3,
										width = "full",
										disabled = function() return not isTimerOn("enableCastbarTimers") end,
										get = timerToggleGet("enableCastbarFocus"),
										set = timerToggleSet("enableCastbarFocus"),
									},
								},
							},
						},
					},
					ticksBox = {
						type = "group",
						name = "Тики каналов",
						desc = "Вертикальные метки тиков на полосе канальных заклинаний (как в Gnosis).",
						order = 2,
						inline = true,
						args = {
							enableCastbarTicks = {
								type = "toggle",
								name = "Включить",
								desc = "Показывать тики на канальных заклинаниях игрока, цели и фокуса.",
								order = 1,
								width = "full",
								get = tickToggleGet("enableCastbarTicks"),
								set = tickToggleSet("enableCastbarTicks"),
							},
							tickTargets = {
								type = "group",
								name = "Отображать на",
								order = 2,
								inline = true,
								disabled = function() return not isTimerOn("enableCastbarTicks") end,
								args = {
									enableCastbarTicksPlayer = {
										type = "toggle",
										name = "Игрок",
										desc = "Тики на кастбаре игрока",
										order = 1,
										width = "full",
										get = tickToggleGet("enableCastbarTicksPlayer"),
										set = tickToggleSet("enableCastbarTicksPlayer"),
									},
									enableCastbarTicksTarget = {
										type = "toggle",
										name = "Цель",
										desc = "Тики на кастбаре цели",
										order = 2,
										width = "full",
										get = tickToggleGet("enableCastbarTicksTarget"),
										set = tickToggleSet("enableCastbarTicksTarget"),
									},
									enableCastbarTicksFocus = {
										type = "toggle",
										name = "Фокус",
										desc = "Тики на кастбаре фокуса",
										order = 3,
										width = "full",
										get = tickToggleGet("enableCastbarTicksFocus"),
										set = tickToggleSet("enableCastbarTicksFocus"),
									},
								},
							},
							castbarTickColor = {
								type = "color",
								name = "Цвет тиков",
								desc = "Цвет вертикальных меток на полосе канала.",
								order = 3,
								hasAlpha = true,
								disabled = function() return not isTimerOn("enableCastbarTicks") end,
								get = function()
									local db = DB()
									local c = db and db.castbarTickColor
									if not c then
										return 1, 1, 1, 0.9
									end
									return c.r or 1, c.g or 1, c.b or 1, c.a or 0.9
								end,
								set = function(_, r, g, b, a)
									local db = DB()
									if not db then return end
									db.castbarTickColor = db.castbarTickColor or {}
									db.castbarTickColor.r = r
									db.castbarTickColor.g = g
									db.castbarTickColor.b = b
									db.castbarTickColor.a = a or 0.8
									if module.ApplyChannelTicks then
										module:ApplyChannelTicks()
									end
								end,
							},
							castbarTickWidth = {
								type = "range",
								name = "Толщина",
								desc = "Ширина вертикальной метки тика.",
								order = 4,
								min = 1,
								max = 6,
								step = 1,
								disabled = function() return not isTimerOn("enableCastbarTicks") end,
								get = function()
									local db = DB()
									return db and db.castbarTickWidth or 2
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.castbarTickWidth = val
									if module.ApplyChannelTicks then
										module:ApplyChannelTicks()
									end
								end,
							},
							castbarTickHaste = {
								type = "toggle",
								name = "Скорость заклинаний добавляет тики",
								desc = "Как в Gnosis: при высокой скорости заклинаний число тиков растёт (Cataclysm и аналоги). На классическом WotLK обычно не нужно.",
								order = 5,
								width = "full",
								disabled = function() return not isTimerOn("enableCastbarTicks") end,
								get = function()
									local v = GetTimerSetting("castbarTickHaste", 0)
									return v == 1 or v == true
								end,
								set = tickToggleSet("castbarTickHaste"),
							},
						},
					},
				},
			},
		},
	}
	options.args.settings.args.ticksBox = options.args.timers.args.ticksBox
	options.args.settings.args.ticksBox.order = 3
	options.args.timers.args.ticksBox = nil
	options.args.timers.args.playerTimerBox = options.args.settings.args.playerTimerBox
	options.args.timers.args.playerTimerBox.order = 2
	options.args.settings.args.playerTimerBox = nil
	return options
end
