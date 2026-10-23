-- A one-shot texture snapshot for the frame under the mouse cursor.
local strataOrder = {
	BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4,
	DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}
local layerOrder = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }

local function Say(message)
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage("SUI текстуры: " .. message)
	end
end

local function FrameName(frame)
	return (frame and frame.GetName and frame:GetName()) or "<без имени>"
end

local function UnderCursor(region, x, y)
	if not region.GetLeft then return false end
	local left, right = region:GetLeft(), region:GetRight()
	local bottom, top = region:GetBottom(), region:GetTop()
	return left and right and bottom and top
		and x >= left and x <= right and y >= bottom and y <= top
end

local function Alpha(region, owner)
	local alpha = region.GetAlpha and region:GetAlpha() or 1
	local r, g, b, a = 1, 1, 1, 1
	if region.GetVertexColor then r, g, b, a = region:GetVertexColor() end
	alpha = alpha * (a or 1)
	local frame = owner
	while frame do
		if frame.GetAlpha then alpha = alpha * (frame:GetAlpha() or 1) end
		frame = frame.GetParent and frame:GetParent()
	end
	return alpha, r, g, b
end

local function Inspect()
	local focus = GetMouseFocus and GetMouseFocus()
	if not focus then Say("под курсором нет фрейма") return end
	local button = focus
	for _ = 1, 8 do
		if button.GetNormalTexture and button:GetNormalTexture() then break end
		button = button.GetParent and button:GetParent()
		if not button then break end
	end
	if not button or not button.GetNormalTexture or not button:GetNormalTexture() then
		Say("под курсором " .. FrameName(focus) .. "; наведите курсор на кнопку")
		return
	end

	local name = FrameName(button)
	local cursorX, cursorY = GetCursorPosition()
	local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
	cursorX, cursorY = cursorX / scale, cursorY / scale
	local roles = {}
	local function Tag(region, role)
		if region then roles[region] = role end
	end
	Tag(button:GetNormalTexture(), "normal")
	if button.GetHighlightTexture then Tag(button:GetHighlightTexture(), "hover") end
	if button.GetPushedTexture then Tag(button:GetPushedTexture(), "pushed") end
	if button.GetCheckedTexture then Tag(button:GetCheckedTexture(), "checked") end
	for _, suffix in ipairs({ "Icon", "IconTexture", "NormalTexture", "NormalTexture2", "Border", "Flash" }) do
		Tag(_G[name .. suffix], suffix)
	end

	local found, visited, order = {}, {}, 0
	local function Add(region, owner, own)
		if not region or not region.GetTexture or found[region] then return end
		local texture = region:GetTexture()
		if not texture then return end
		local hit = UnderCursor(region, cursorX, cursorY)
		if not own and not hit then return end
		local shown = region.IsShown and region:IsShown()
		local visible = region.IsVisible and region:IsVisible()
		local alpha, r, g, b = Alpha(region, owner)
		local layer, sublevel
		if region.GetDrawLayer then layer, sublevel = region:GetDrawLayer() end
		order = order + 1
		found[region] = true
		table.insert(found, {
			owner = owner, region = region, texture = texture,
			role = roles[region] or (region.GetName and region:GetName()) or "Texture",
			hit = hit, shown = shown, visible = visible,
			alpha = alpha, r = r, g = g, b = b,
			strata = owner.GetFrameStrata and owner:GetFrameStrata() or "MEDIUM",
			level = owner.GetFrameLevel and owner:GetFrameLevel() or 0,
			layer = layer or "ARTWORK", sublevel = sublevel or 0, order = order,
		})
	end
	local function Collect(frame, depth, own)
		if not frame or visited[frame] or not frame.GetRegions then return end
		visited[frame] = true
		for _, region in ipairs({ frame:GetRegions() }) do Add(region, frame, own) end
		if depth <= 0 or not frame.GetChildren then return end
		local children = { frame:GetChildren() }
		for i = 1, math.min(#children, 200) do
			Collect(children[i], depth - 1, own)
		end
	end
	Collect(button, 2, true)
	for region in pairs(roles) do
		local owner = region.GetParent and region:GetParent() or button
		Add(region, owner, true)
	end
	local parent = button.GetParent and button:GetParent()
	if parent and parent.GetRegions then
		for _, region in ipairs({ parent:GetRegions() }) do Add(region, parent, false) end
		if parent.GetChildren then
			local siblings = { parent:GetChildren() }
			for i = 1, math.min(#siblings, 200) do Collect(siblings[i], 0, false) end
		end
	end

	local function Active(entry)
		return entry.hit and entry.shown ~= false and entry.visible ~= false and entry.alpha > 0.01
	end
	table.sort(found, function(a, b)
		local av, bv = Active(a), Active(b)
		if av ~= bv then return av end
		local as, bs = strataOrder[a.strata] or 0, strataOrder[b.strata] or 0
		if as ~= bs then return as > bs end
		if a.level ~= b.level then return a.level > b.level end
		local al, bl = layerOrder[a.layer] or 0, layerOrder[b.layer] or 0
		if al ~= bl then return al > bl end
		if a.sublevel ~= b.sublevel then return a.sublevel > b.sublevel end
		return a.order > b.order
	end)

	Say(string.format("%s; стиль=%s; текстур=%d; порядок сверху вниз", name,
		SarychUI_InterfaceStyle and SarychUI_InterfaceStyle.enabled and "вкл" or "выкл", #found))
	for i = 1, math.min(#found, 24) do
		local item = found[i]
		local flags = (item.hit and "курсор" or "мимо") .. "," ..
			((item.shown == false or item.visible == false) and "скрыта" or "видна")
		Say(string.format("[%d]%s %s/%s %s %s:%d/%s:%d a=%.2f rgb=%.2f,%.2f,%.2f | %s",
			i, i == 1 and Active(item) and " ВЕРХ?" or "", FrameName(item.owner),
			item.role, flags, item.strata, item.level, item.layer, item.sublevel,
			item.alpha, item.r or 1, item.g or 1, item.b or 1, tostring(item.texture)))
	end
	if #found > 24 then Say("показаны первые 24 из " .. #found) end
end

SLASH_SUISTYLEINSPECT1 = "/suistyleinspect"
SLASH_SUISTYLEINSPECT2 = "/suitex"
SlashCmdList["SUISTYLEINSPECT"] = Inspect
