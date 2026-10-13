--[[
	AimbotTest DevTools v2  (Xeno)
	- UI ใหม่ ใหญ่ เรียบ หรู
	- ESP แบบ Screen-space ขนาดคงที่ ไม่เพี้ยนตอนเดินเข้าใกล้
	- Aim Assist แก้ใหม่: ทำงานหลังกล้องของเกม + โหมดตลอด/กดเมาส์ขวา + เลือกเป้า NPC/ผู้เล่น + แสดงสถานะ
	- ตัวนับจำนวนผู้เล่นในเซิร์ฟ (ในเมนู + แถบกลางจอ)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
while not LP do task.wait() LP = Players.LocalPlayer end
repeat task.wait() until Workspace.CurrentCamera
local Camera = Workspace.CurrentCamera

--------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------
local PRESETS = {
	{ "ฟ้า", Color3.fromRGB(80, 200, 255) },
	{ "ม่วง", Color3.fromRGB(160, 120, 255) },
	{ "แดง", Color3.fromRGB(255, 85, 95) },
	{ "เขียว", Color3.fromRGB(90, 230, 140) },
	{ "เหลือง", Color3.fromRGB(255, 210, 80) },
	{ "ขาว", Color3.fromRGB(245, 245, 250) },
}

local S = {
	espOn = true, espName = true, espBox = true, espBar = true, espInfo = true, espLine = false, espHighlight = true,
	espCol = PRESETS[1][2],
	fillTrans = 0.6,
	aimOn = false, aimSmooth = 6, aimFov = 180, aimPart = "Head", aimShowFov = true,
	aimMode = "hold", aimTarget = "All", aimWall = false,
	showCount = true,
	uiSize = 1,
	animTime = 0.25,
	menuKey = Enum.KeyCode.RightShift,
}

local T = {
	bg = Color3.fromRGB(13, 13, 18),
	side = Color3.fromRGB(18, 18, 24),
	card = Color3.fromRGB(23, 23, 31),
	line = Color3.fromRGB(40, 40, 52),
	text = Color3.fromRGB(240, 240, 248),
	sub = Color3.fromRGB(135, 138, 158),
	accent = Color3.fromRGB(124, 98, 255),
	off = Color3.fromRGB(52, 53, 68),
}

local alive = true
local conns = {}
local function bind(signal, fn)
	local c = signal:Connect(fn)
	table.insert(conns, c)
	return c
end

--------------------------------------------------------------------
-- UI helpers
--------------------------------------------------------------------
local function tween(o, props, t)
	pcall(function()
		TweenService:Create(o, TweenInfo.new(t or S.animTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
	end)
end

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local function corner(o, r) return mk("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end
local function stroke(o, col, th, tr)
	return mk("UIStroke", { Color = col or T.line, Thickness = th or 1, Transparency = tr or 0 }, o)
end

local GUI_NAME = "AimbotTest_DevTools_v2"

for _, name in ipairs({ GUI_NAME, "AimbotTest_v1_DevTools" }) do
	pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(name) if o then o:Destroy() end end)
	pcall(function() local o = LP:FindFirstChildOfClass("PlayerGui"):FindFirstChild(name) if o then o:Destroy() end end)
	pcall(function() if gethui then local o = gethui():FindFirstChild(name) if o then o:Destroy() end end end)
end
pcall(function() RunService:UnbindFromRenderStep("DevToolsAim") end)

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999

local function tryParent(fn)
	local ok = pcall(function() gui.Parent = fn() end)
	return ok and gui.Parent ~= nil
end
if not (gethui and tryParent(gethui)) then
	if not tryParent(function() return game:GetService("CoreGui") end) then
		tryParent(function() return LP:WaitForChild("PlayerGui", 10) end)
	end
end
if not gui.Parent then
	warn("[DevTools] ใส่ GUI ไม่สำเร็จ")
	return
end

-- ชั้นวาด ESP (อยู่ใต้เมนู)
local espLayer = mk("Frame", { Name = "ESPLayer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, gui)

--------------------------------------------------------------------
-- Main window
--------------------------------------------------------------------
local W, H = 700, 440
local SIDE_W = 190

local main = mk("CanvasGroup", {
	Name = "Main",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = T.bg,
	BorderSizePixel = 0,
	GroupTransparency = 1,
}, gui)
corner(main, 18)
stroke(main, T.line, 1, 0)
local uiScale = mk("UIScale", {}, main)

local function applyScale()
	local vp = (Workspace.CurrentCamera or Camera).ViewportSize
	local auto = math.min(1, (vp.X - 20) / W, (vp.Y - 20) / H)
	uiScale.Scale = math.max(0.4, auto * S.uiSize)
end
applyScale()
bind(Camera:GetPropertyChangedSignal("ViewportSize"), applyScale)

-- Sidebar
local side = mk("Frame", { Size = UDim2.new(0, SIDE_W, 1, 0), BackgroundColor3 = T.side, BorderSizePixel = 0 }, main)
mk("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = T.line, BorderSizePixel = 0 }, side)

local brand = mk("Frame", { Size = UDim2.new(1, 0, 0, 84), BackgroundTransparency = 1 }, side)
mk("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 24), Size = UDim2.new(1, -44, 0, 22),
	Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = T.text, Text = "AIMBOT TEST",
}, brand)
mk("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 47), Size = UDim2.new(1, -44, 0, 16),
	Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = T.sub, Text = "DevTools  •  v2",
}, brand)

local navHolder = mk("Frame", { Position = UDim2.fromOffset(12, 92), Size = UDim2.new(1, -24, 1, -170), BackgroundTransparency = 1 }, side)
mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, navHolder)

-- player count card (sidebar)
local countCard = mk("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -14), Size = UDim2.new(1, -24, 0, 58),
	BackgroundColor3 = T.card, BorderSizePixel = 0,
}, side)
corner(countCard, 12)
stroke(countCard, T.line, 1, 0)
mk("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 14),
	Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = T.sub, Text = "ผู้เล่นในเซิร์ฟ",
}, countCard)
local countBig = mk("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 25), Size = UDim2.new(1, -28, 0, 24),
	Font = Enum.Font.GothamBold, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = T.text, Text = "-",
}, countCard)

-- Content
local content = mk("Frame", { Position = UDim2.fromOffset(SIDE_W, 0), Size = UDim2.new(1, -SIDE_W, 1, 0), BackgroundTransparency = 1 }, main)
local header = mk("Frame", { Size = UDim2.new(1, 0, 0, 72), BackgroundTransparency = 1 }, content)
local pageTitle = mk("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -90, 1, 0),
	Font = Enum.Font.GothamBold, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = T.text, Text = "",
}, header)
local closeBtn = mk("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 20), Size = UDim2.fromOffset(32, 32),
	BackgroundColor3 = T.card, Text = "×", TextSize = 22, Font = Enum.Font.GothamBold,
	TextColor3 = T.sub, AutoButtonColor = false,
}, header)
corner(closeBtn, 10)
bind(closeBtn.MouseEnter, function() tween(closeBtn, { BackgroundColor3 = Color3.fromRGB(200, 70, 80), TextColor3 = Color3.new(1, 1, 1) }, 0.15) end)
bind(closeBtn.MouseLeave, function() tween(closeBtn, { BackgroundColor3 = T.card, TextColor3 = T.sub }, 0.15) end)

local pageHolder = mk("Frame", { Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 1, -72), BackgroundTransparency = 1 }, content)

-- Pages
local pages, navBtns, pageTitles = {}, {}, {}
local orderN = 0
local function nxt() orderN = orderN + 1 return orderN end
local cardRows = {}

local function selectTab(name)
	for n, p in pairs(pages) do p.Visible = (n == name) end
	for n, b in pairs(navBtns) do
		local on = (n == name)
		tween(b.btn, { BackgroundTransparency = on and 0 or 1, TextColor3 = on and T.text or T.sub }, 0.2)
		b.ind.Visible = on
	end
	pageTitle.Text = pageTitles[name] or name
end

local function newPage(name)
	local b = mk("TextButton", {
		Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.card, BackgroundTransparency = 1, AutoButtonColor = false,
		Text = name, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = T.sub,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nxt(),
	}, navHolder)
	corner(b, 10)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 18) }, b)
	local ind = mk("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -12, 0.5, 0), Size = UDim2.fromOffset(3, 18),
		BackgroundColor3 = T.accent, BorderSizePixel = 0, Visible = false,
	}, b)
	corner(ind, 2)

	local page = mk("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.sub, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
	}, pageHolder)
	mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, page)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 28), PaddingRight = UDim.new(0, 28), PaddingBottom = UDim.new(0, 28) }, page)

	pages[name], navBtns[name], pageTitles[name] = page, { btn = b, ind = ind }, name
	bind(b.MouseButton1Click, function() selectTab(name) end)
	return page
end

local function newCard(page, title)
	if title then
		mk("TextLabel", {
			LayoutOrder = nxt(), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.sub,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom, Text = title,
		}, page)
	end
	local c = mk("Frame", {
		LayoutOrder = nxt(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.card, BorderSizePixel = 0,
	}, page)
	corner(c, 14)
	stroke(c, T.line, 1, 0)
	mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, c)
	cardRows[c] = 0
	return c
end

local function newRow(c, h)
	cardRows[c] = cardRows[c] + 1
	local f = mk("Frame", { LayoutOrder = cardRows[c], Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1 }, c)
	if cardRows[c] > 1 then
		mk("Frame", { Size = UDim2.new(1, -40, 0, 1), Position = UDim2.fromOffset(20, 0), BackgroundColor3 = T.line, BorderSizePixel = 0 }, f)
	end
	return f
end

local function rowText(f, text, desc, rightW)
	rightW = rightW or 80
	local hasDesc = desc ~= nil
	mk("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(20, hasDesc and 9 or 0),
		Size = hasDesc and UDim2.new(1, -(rightW + 30), 0, 20) or UDim2.new(1, -(rightW + 30), 1, 0),
		Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = T.text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = text,
	}, f)
	if hasDesc then
		mk("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 30), Size = UDim2.new(1, -(rightW + 30), 0, 16),
			Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.sub,
			TextXAlignment = Enum.TextXAlignment.Left, Text = desc,
		}, f)
	end
end

local function addToggle(c, text, key, desc, cb)
	local f = newRow(c, desc and 58 or 50)
	rowText(f, text, desc, 60)
	local hit = mk("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, f)
	local sw = mk("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(44, 24),
		BackgroundColor3 = T.off, BorderSizePixel = 0,
	}, f)
	corner(sw, 12)
	local knob = mk("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, sw)
	corner(knob, 9)
	local function render(instant)
		local on = S[key]
		local d = instant and 0 or S.animTime
		tween(sw, { BackgroundColor3 = on and T.accent or T.off }, d)
		tween(knob, { Position = on and UDim2.new(0, 23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, d)
	end
	render(true)
	bind(hit.MouseButton1Click, function()
		S[key] = not S[key]
		render()
		if cb then cb(S[key]) end
	end)
end

local function addSlider(c, text, key, min, max, dec, cb)
	local f = newRow(c, 68)
	mk("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -140, 0, 20),
		Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = T.text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = text,
	}, f)
	local val = mk("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Position = UDim2.new(1, -20, 0, 10), Size = UDim2.fromOffset(100, 20),
		Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = T.accent,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "",
	}, f)
	local hitA = mk("Frame", { Position = UDim2.fromOffset(20, 38), Size = UDim2.new(1, -40, 0, 22), BackgroundTransparency = 1 }, f)
	local track = mk("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = T.off, BorderSizePixel = 0,
	}, hitA)
	corner(track, 3)
	local fill = mk("Frame", { BackgroundColor3 = T.accent, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, track)
	corner(fill, 3)
	local knob = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, track)
	corner(knob, 8)

	local mult = 10 ^ (dec or 0)
	local function render(v)
		local a = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		val.Text = tostring(v)
	end
	render(S[key])
	local dragging = false
	local function setFromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = math.floor((min + (max - min) * a) * mult + 0.5) / mult
		S[key] = v
		render(v)
		if cb then cb(v) end
	end
	bind(hitA.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(i.Position.X)
		end
	end)
	bind(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			setFromX(i.Position.X)
		end
	end)
	bind(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
end

local function addChoice(c, text, key, options, cb)
	local f = newRow(c, 58)
	rowText(f, text, nil, 270)
	local seg = mk("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(250, 34),
		BackgroundColor3 = T.bg, BorderSizePixel = 0,
	}, f)
	corner(seg, 9)
	local n = #options
	local btns = {}
	local function render()
		for name, b in pairs(btns) do
			local on = (S[key] == name)
			tween(b, { BackgroundTransparency = on and 0 or 1, TextColor3 = on and Color3.new(1, 1, 1) or T.sub }, 0.2)
		end
	end
	for idx, opt in ipairs(options) do
		local b = mk("TextButton", {
			Position = UDim2.new((idx - 1) / n, 2, 0, 2), Size = UDim2.new(1 / n, -4, 1, -4),
			BackgroundColor3 = T.accent, BackgroundTransparency = 1, Text = opt[2],
			Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.sub, AutoButtonColor = false,
		}, seg)
		corner(b, 7)
		btns[opt[1]] = b
		bind(b.MouseButton1Click, function()
			S[key] = opt[1]
			render()
			if cb then cb(opt[1]) end
		end)
	end
	render()
end

local function addSwatches(c, text)
	local f = newRow(c, 58)
	rowText(f, text, nil, 230)
	local holder = mk("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0),
		Size = UDim2.fromOffset(#PRESETS * 30, 24), BackgroundTransparency = 1,
	}, f)
	local items = {}
	local function render()
		for _, it in ipairs(items) do
			it.stroke.Transparency = (S.espCol == it.col) and 0 or 1
		end
	end
	for idx, p in ipairs(PRESETS) do
		local b = mk("TextButton", {
			Position = UDim2.fromOffset((idx - 1) * 30, 1), Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = p[2], Text = "", AutoButtonColor = false,
		}, holder)
		corner(b, 11)
		local st = stroke(b, Color3.new(1, 1, 1), 2, 1)
		table.insert(items, { col = p[2], stroke = st })
		bind(b.MouseButton1Click, function()
			S.espCol = p[2]
			render()
		end)
	end
	render()
end

local function addButton(c, text, desc, btnText, cb)
	local f = newRow(c, 60)
	rowText(f, text, desc, 130)
	local b = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(104, 34),
		BackgroundColor3 = T.accent, Text = btnText, Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false,
	}, f)
	corner(b, 9)
	bind(b.MouseEnter, function() tween(b, { BackgroundColor3 = Color3.fromRGB(150, 128, 255) }, 0.15) end)
	bind(b.MouseLeave, function() tween(b, { BackgroundColor3 = T.accent }, 0.15) end)
	bind(b.MouseButton1Click, function() cb() end)
end

local function addStatus(c, init)
	local f = newRow(c, 50)
	return mk("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -40, 1, 0),
		Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = T.sub,
		TextXAlignment = Enum.TextXAlignment.Left, Text = init,
	}, f)
end

local function addNote(c, text)
	local f = newRow(c, 50)
	mk("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -40, 1, 0),
		Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = T.sub,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Text = text,
	}, f)
end

--------------------------------------------------------------------
-- Drag window
--------------------------------------------------------------------
do
	local dragging, startPos, startMouse
	local function makeDrag(handle)
		bind(handle.InputBegan, function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging, startPos, startMouse = true, main.Position, i.Position
			end
		end)
	end
	makeDrag(header)
	makeDrag(brand)
	bind(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startMouse
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	bind(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
end

local menuOpen = true
local function setMenu(open)
	menuOpen = open
	if open then
		main.Visible = true
		tween(main, { GroupTransparency = 0 }, S.animTime)
	else
		tween(main, { GroupTransparency = 1 }, S.animTime)
		task.delay(S.animTime, function()
			if not menuOpen and alive then main.Visible = false end
		end)
	end
end
bind(closeBtn.MouseButton1Click, function() setMenu(false) end)
bind(UIS.InputBegan, function(i, gp)
	if not gp and i.KeyCode == S.menuKey then setMenu(not menuOpen) end
end)

-- ปุ่มลอยเปิด/ปิดเมนู
do
	local fb = mk("TextButton", {
		Name = "FloatToggle", Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 14, 0.5, -22),
		BackgroundColor3 = T.bg, BackgroundTransparency = 0.05, Text = "☰", TextSize = 20,
		Font = Enum.Font.GothamBold, TextColor3 = T.text, AutoButtonColor = false,
	}, gui)
	corner(fb, 22)
	stroke(fb, T.accent, 1.5, 0.2)
	bind(fb.MouseButton1Click, function() setMenu(not menuOpen) end)
end

--------------------------------------------------------------------
-- Player count (HUD + sidebar)
--------------------------------------------------------------------
local hud = mk("Frame", {
	Name = "CountHUD", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 50),
	Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = T.bg, BackgroundTransparency = 0.12, BorderSizePixel = 0,
}, gui)
corner(hud, 15)
stroke(hud, T.line, 1, 0)
mk("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, hud)
mk("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
}, hud)
local dot = mk("Frame", { LayoutOrder = 1, Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.fromRGB(90, 230, 140), BorderSizePixel = 0 }, hud)
corner(dot, 4)
local hudTxt = mk("TextLabel", {
	LayoutOrder = 2, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.text, Text = "",
}, hud)

local function updateCount()
	local n = #Players:GetPlayers()
	local mx = Players.MaxPlayers
	countBig.Text = n .. " / " .. mx
	hudTxt.Text = "ผู้เล่น  " .. n .. " / " .. mx
	hud.Visible = S.showCount
end
updateCount()
bind(Players.PlayerAdded, updateCount)
bind(Players.PlayerRemoving, function() task.defer(updateCount) end)

--------------------------------------------------------------------
-- ESP (screen-space, ขนาดตัวหนังสือคงที่)
--------------------------------------------------------------------
local esp = {}

local function getMoney(plr)
	local ls = plr:FindFirstChild("leaderstats")
	if ls then
		for _, n in ipairs({ "Money", "Cash", "เงิน", "Coins", "Gold" }) do
			local v = ls:FindFirstChild(n)
			if v then return v.Value end
		end
	end
	return plr:GetAttribute("Money") or plr:GetAttribute("Cash") or 0
end

local function getItems(plr)
	local names = {}
	local char = plr.Character
	if char then
		for _, t in ipairs(char:GetChildren()) do
			if t:IsA("Tool") then table.insert(names, t.Name) end
		end
	end
	local bp = plr:FindFirstChildOfClass("Backpack")
	if bp then
		for _, t in ipairs(bp:GetChildren()) do
			if t:IsA("Tool") then table.insert(names, t.Name) end
		end
	end
	return names
end

local function destroyESP(plr)
	local d = esp[plr]
	if d then
		for _, o in ipairs(d.objs) do pcall(function() o:Destroy() end) end
		esp[plr] = nil
	end
end

local function buildESP(plr)
	destroyESP(plr)
	local char = plr.Character
	if not char then return end
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	local hum = char:WaitForChild("Humanoid", 5)
	if not (hrp and hum) or plr.Character ~= char or not alive then return end

	local d = { objs = {}, hum = hum, hrp = hrp, nextInfo = 0 }

	local root = mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, espLayer)
	d.root = root
	d.boxStroke = stroke(root, S.espCol, 1.5, 0)

	d.nameLbl = mk("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -5), Size = UDim2.fromOffset(220, 16),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
		TextStrokeTransparency = 0.45, TextColor3 = S.espCol, Text = plr.DisplayName,
	}, root)

	d.barBg = mk("Frame", {
		Position = UDim2.new(0, -9, 0, 0), Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, BorderSizePixel = 0,
	}, root)
	corner(d.barBg, 2)
	d.fill = mk("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(80, 255, 120), BorderSizePixel = 0,
	}, d.barBg)
	corner(d.fill, 2)

	d.info = mk("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(1, 7, 0, 0), Size = UDim2.fromOffset(170, 60),
		Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5, RichText = true, Text = "",
	}, root)

	d.line = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = S.espCol, BorderSizePixel = 0, Visible = false,
	}, espLayer)

	d.hl = mk("Highlight", {
		Adornee = char, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, OutlineTransparency = 0,
	}, gui)

	d.objs = { root, d.line, d.hl }
	esp[plr] = d
end

local function trackPlayer(plr)
	if plr == LP then return end
	bind(plr.CharacterAdded, function() task.defer(buildESP, plr) end)
	bind(plr.CharacterRemoving, function() destroyESP(plr) end)
	if plr.Character then task.defer(buildESP, plr) end
end
for _, p in ipairs(Players:GetPlayers()) do trackPlayer(p) end
bind(Players.PlayerAdded, trackPlayer)
bind(Players.PlayerRemoving, destroyESP)

local function updateESP()
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	local col = S.espCol
	local camPos = cam.CFrame.Position
	local now = os.clock()

	for plr, d in pairs(esp) do
		local hum, hrp = d.hum, d.hrp
		if not (hum.Parent and hrp.Parent) then
			destroyESP(plr)
		else
			local on = S.espOn
			d.hl.Enabled = on and S.espHighlight
			d.hl.FillColor, d.hl.OutlineColor, d.hl.FillTransparency = col, col, S.fillTrans

			local pos, vis = cam:WorldToViewportPoint(hrp.Position)
			if not (on and vis) then
				d.root.Visible = false
				d.line.Visible = false
			else
				local top = cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2.8, 0))
				local bot = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.2, 0))
				local h = math.clamp(math.abs(bot.Y - top.Y), 28, 800)
				local w = h * 0.55
				local cx, cy = pos.X, (top.Y + bot.Y) / 2

				d.root.Position = UDim2.fromOffset(cx - w / 2, cy - h / 2)
				d.root.Size = UDim2.fromOffset(w, h)
				d.root.Visible = true

				d.boxStroke.Enabled = S.espBox
				d.boxStroke.Color = col

				d.nameLbl.Visible = S.espName
				if S.espName then
					local dist = math.floor((camPos - hrp.Position).Magnitude)
					d.nameLbl.Text = plr.DisplayName .. "  [" .. dist .. "m]"
					d.nameLbl.TextColor3 = col
				end

				d.barBg.Visible = S.espBar
				if S.espBar then
					local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
					d.fill.Size = UDim2.fromScale(1, frac)
					d.fill.BackgroundColor3 = Color3.fromHSV(frac * 0.33, 0.85, 1)
				end

				d.info.Visible = S.espInfo
				if S.espInfo and now >= d.nextInfo then
					d.nextInfo = now + 0.4
					local items = getItems(plr)
					local itemTxt = (#items > 0) and table.concat(items, ", ") or "-"
					d.info.Text = string.format("<b>HP</b>  %d / %d\n<b>$</b>  %s\n<b>ของ</b>  %s",
						math.floor(hum.Health), math.floor(hum.MaxHealth), tostring(getMoney(plr)), itemTxt)
				end

				if S.espLine then
					local from = Vector2.new(vp.X / 2, vp.Y)
					local to = Vector2.new(cx, bot.Y)
					local delta = to - from
					d.line.Size = UDim2.fromOffset(delta.Magnitude, 1.5)
					d.line.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
					d.line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
					d.line.BackgroundColor3 = col
					d.line.Visible = true
				else
					d.line.Visible = false
				end
			end
		end
	end
end
bind(RunService.RenderStepped, function()
	if alive then updateESP() end
end)

--------------------------------------------------------------------
-- Aim Assist
--------------------------------------------------------------------
local partMap = {
	Head = { "Head" },
	Torso = { "UpperTorso", "Torso" },
	Arms = { "RightUpperArm", "Right Arm", "LeftUpperArm", "Left Arm" },
	Legs = { "RightUpperLeg", "Right Leg", "LeftUpperLeg", "Left Leg" },
}

local aimHL = mk("Highlight", {
	FillColor = Color3.fromRGB(255, 60, 60), OutlineColor = Color3.new(1, 1, 1),
	FillTransparency = 0.25, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false,
}, gui)

local fovCircle = mk("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1, Visible = false,
}, gui)
corner(fovCircle, 1000)
stroke(fovCircle, Color3.new(1, 1, 1), 1.5, 0.35)

local npcCache, npcNext = {}, 0
local function refreshNPCs()
	local now = os.clock()
	if now < npcNext then return end
	npcNext = now + 2
	table.clear(npcCache)
	local folder = Workspace:FindFirstChild("TrainingTargets")
	for _, o in ipairs((folder or Workspace):GetDescendants()) do
		if o:IsA("Humanoid") then
			local m = o.Parent
			if m and m:IsA("Model") and not Players:GetPlayerFromCharacter(m) then
				table.insert(npcCache, m)
			end
		end
	end
end

local function getTargetPart(model)
	local list = partMap[S.aimPart]
	if list then
		for _, n in ipairs(list) do
			local p = model:FindFirstChild(n)
			if p and p:IsA("BasePart") then return p end
		end
	end
	local r = model:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then return r end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function isVisible(part, model)
	local origin = Camera.CFrame.Position
	rayParams.FilterDescendantsInstances = { LP.Character }
	local r = Workspace:Raycast(origin, part.Position - origin, rayParams)
	return r == nil or r.Instance:IsDescendantOf(model)
end

local function findTarget()
	local center = Camera.ViewportSize / 2
	local best, bestDist, bestModel
	local nCand = 0

	local function check(m)
		local hum = m:FindFirstChildOfClass("Humanoid")
		if not (hum and hum.Health > 0) then return end
		nCand = nCand + 1
		local part = getTargetPart(m)
		if not part then return end
		local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
		if not onScreen then return end
		local dist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
		if dist <= S.aimFov and (not bestDist or dist < bestDist) then
			if S.aimWall and not isVisible(part, m) then return end
			best, bestDist, bestModel = part, dist, m
		end
	end

	if S.aimTarget == "NPC" or S.aimTarget == "All" then
		for _, m in ipairs(npcCache) do
			if m.Parent then check(m) end
		end
	end
	if S.aimTarget == "Player" or S.aimTarget == "All" then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP and p.Character then check(p.Character) end
		end
	end
	return best, bestModel, nCand
end

local holding = false
bind(UIS.InputBegan, function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton2 then holding = true end
end)
bind(UIS.InputEnded, function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton2 then holding = false end
end)

local aimStatus -- ตั้งค่าหลังสร้างหน้า Aim
local lastStatus, statusNext = "", 0
local function setStatus(txt, good)
	if not aimStatus then return end
	local now = os.clock()
	if txt == lastStatus or now < statusNext then return end
	lastStatus, statusNext = txt, now + 0.2
	aimStatus.Text = txt
	aimStatus.TextColor3 = good and Color3.fromRGB(90, 230, 140) or T.sub
end

local function aimStep(dt)
	if not alive then return end
	Camera = Workspace.CurrentCamera
	if not Camera then return end

	fovCircle.Visible = S.aimOn and S.aimShowFov
	fovCircle.Size = UDim2.fromOffset(S.aimFov * 2, S.aimFov * 2)

	if not S.aimOn then
		aimHL.Enabled = false
		setStatus("ปิดอยู่", false)
		return
	end

	refreshNPCs()
	local part, model, nCand = findTarget()
	if part then
		aimHL.Adornee = part
		aimHL.Enabled = true
		local active = (S.aimMode == "always") or holding
		if active then
			local alpha = math.clamp(dt * (30 / math.max(S.aimSmooth, 1)), 0, 1)
			Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, part.Position), alpha)
			setStatus("● กำลังล็อก: " .. model.Name, true)
		else
			setStatus("● พบเป้า: " .. model.Name .. "  (กดเมาส์ขวาค้างเพื่อล็อก)", true)
		end
	else
		aimHL.Enabled = false
		setStatus("○ ไม่พบเป้าในวง FOV  (เป้าที่ตรวจเจอ " .. nCand .. ")", false)
	end
end
-- ทำงานหลังสคริปต์กล้องของ Roblox เพื่อไม่ให้ถูกทับ
RunService:BindToRenderStep("DevToolsAim", Enum.RenderPriority.Camera.Value + 1, aimStep)

--------------------------------------------------------------------
-- Performance (FPS Boost)
--------------------------------------------------------------------
local backup = {}
local fpsActive = false

local function boostFPS()
	if fpsActive then return end
	fpsActive = true
	backup = { effects = {} }
	pcall(function()
		backup.quality = settings().Rendering.QualityLevel
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
	end)
	backup.lighting = {
		GlobalShadows = Lighting.GlobalShadows, FogEnd = Lighting.FogEnd, Brightness = Lighting.Brightness,
	}
	Lighting.GlobalShadows = false
	Lighting.FogEnd = 9e9
	Lighting.Brightness = 2
	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("PostEffect") then
			table.insert(backup.effects, { inst = e, kind = "enabled", value = e.Enabled })
			e.Enabled = false
		elseif e:IsA("Atmosphere") or e:IsA("Sky") or e:IsA("Clouds") then
			table.insert(backup.effects, { inst = e, kind = "parent" })
			e.Parent = nil
		end
	end
end

local function restoreFPS()
	if not fpsActive then return end
	fpsActive = false
	if backup.lighting then
		for k, v in pairs(backup.lighting) do Lighting[k] = v end
	end
	if backup.quality then
		pcall(function() settings().Rendering.QualityLevel = backup.quality end)
	end
	for _, r in ipairs(backup.effects or {}) do
		pcall(function()
			if r.kind == "enabled" then r.inst.Enabled = r.value else r.inst.Parent = Lighting end
		end)
	end
	backup = {}
end

local function unload()
	alive = false
	pcall(function() RunService:UnbindFromRenderStep("DevToolsAim") end)
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	restoreFPS()
	for plr in pairs(esp) do destroyESP(plr) end
	gui:Destroy()
end

--------------------------------------------------------------------
-- Build pages
--------------------------------------------------------------------
local pEsp = newPage("ESP")
do
	local c1 = newCard(pEsp, "การแสดงผล")
	addToggle(c1, "เปิด ESP", "espOn", "เปิด/ปิดทุกอย่างของ ESP")
	addToggle(c1, "ชื่อและระยะ", "espName")
	addToggle(c1, "กรอบตัวผู้เล่น", "espBox")
	addToggle(c1, "หลอดเลือด", "espBar")
	addToggle(c1, "ข้อมูล (เลือด / เงิน / ของ)", "espInfo")
	addToggle(c1, "เส้นโยงหาผู้เล่น", "espLine")
	addToggle(c1, "ไฮไลต์ตัวผู้เล่น", "espHighlight")
	local c2 = newCard(pEsp, "สี")
	addSwatches(c2, "สีของ ESP")
	addSlider(c2, "ความโปร่งใสไฮไลต์", "fillTrans", 0, 1, 2)
end

local pAim = newPage("Aim Assist")
do
	local c1 = newCard(pAim, "ทั่วไป")
	addToggle(c1, "เปิด Aim Assist", "aimOn", "ล็อกกล้องไปที่เป้าที่ใกล้กลางจอที่สุด")
	addChoice(c1, "โหมดล็อก", "aimMode", { { "hold", "กดเมาส์ขวา" }, { "always", "ตลอด" } })
	addChoice(c1, "เป้าหมาย", "aimTarget", { { "NPC", "NPC" }, { "Player", "ผู้เล่น" }, { "All", "ทั้งหมด" } })
	addChoice(c1, "ส่วนที่ล็อก", "aimPart", { { "Head", "หัว" }, { "Torso", "ตัว" }, { "Arms", "แขน" }, { "Legs", "ขา" } })
	local c2 = newCard(pAim, "ปรับแต่ง")
	addToggle(c2, "แสดงวง FOV", "aimShowFov")
	addToggle(c2, "เช็คกำแพง", "aimWall", "ล็อกเฉพาะเป้าที่มองเห็นจริง")
	addSlider(c2, "ความสมูท", "aimSmooth", 1, 20, 1)
	addSlider(c2, "ขนาดวง FOV", "aimFov", 40, 500, 0)
	local c3 = newCard(pAim, "สถานะ")
	aimStatus = addStatus(c3, "ปิดอยู่")
end

local pPerf = newPage("Performance")
do
	local c = newCard(pPerf, "กราฟิก")
	addButton(c, "บูต FPS", "ลดเงา ปิดเอฟเฟกต์ ลดคุณภาพกราฟิก", "เปิดใช้", boostFPS)
	addButton(c, "คืนค่ากราฟิกเดิม", "ย้อนกลับเป็นค่าก่อนบูต", "คืนค่า", restoreFPS)
end

local pSet = newPage("Settings")
do
	local c1 = newCard(pSet, "หน้าตา")
	addSlider(c1, "ขนาด UI", "uiSize", 0.7, 1.4, 2, function() applyScale() end)
	addSlider(c1, "ความเร็วแอนิเมชัน (วินาที)", "animTime", 0.1, 1.5, 2)
	addToggle(c1, "แสดงจำนวนผู้เล่นกลางจอ", "showCount", nil, function() updateCount() end)
	local c2 = newCard(pSet, "ทั่วไป")
	addNote(c2, "เปิด/ปิดเมนู: RightShift หรือกดปุ่ม ☰ ด้านซ้ายของจอ")
	addButton(c2, "ปิดสคริปต์", "ลบเมนูและฟีเจอร์ทั้งหมดออกจากเกม", "ปิด", unload)
end

selectTab("ESP")
main.Visible = true
setMenu(true)
print("AimbotTest DevTools v2 Loaded!")
