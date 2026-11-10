--[[
╔════════════════════════════════════════════════════════════════════╗
║   T H O N H U D       —   Roblox Lua (Luau) GUI Library            ║
║   Neon / hacker style  •  Tabs  •  Minimize                        ║
╚════════════════════════════════════════════════════════════════════╝
]]

------------------------------------------------------------------------
-- PHẦN 1 : LÕI (services, theme, hàm tiện ích)
------------------------------------------------------------------------
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Stats            = game:GetService("Stats")
local Lighting         = game:GetService("Lighting")
local TeleportService  = game:GetService("TeleportService")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local GUI_NAME = "ThonHUD"
do
	local old = PlayerGui:FindFirstChild(GUI_NAME)
	if old then old:Destroy() end
end

local Library = {
	Name      = "THONHUD",
	Version   = "1.0",
	ToggleKey = Enum.KeyCode.RightShift,
	Flags     = {},
	Stats     = { FPS = 60, Ping = 0, Mem = 0 },
	Destroyed = false,
	NotifyDuration = 4,
}

local connections   = {}
local themeHooks    = {}
local statsHooks    = {}
local spinning      = {}

---------------------------------------------------------------- THEME --
local Themes = {
	{ Name = "Cyber Cyan",   A = Color3.fromRGB(0, 229, 255),   B = Color3.fromRGB(124, 77, 255) },
	{ Name = "Neon Purple",  A = Color3.fromRGB(178, 102, 255), B = Color3.fromRGB(255, 61, 172) },
	{ Name = "Matrix Green", A = Color3.fromRGB(57, 255, 136),  B = Color3.fromRGB(0, 184, 255) },
	{ Name = "Blood Red",    A = Color3.fromRGB(255, 59, 79),   B = Color3.fromRGB(255, 154, 60) },
	{ Name = "Sunset",       A = Color3.fromRGB(255, 145, 77),  B = Color3.fromRGB(255, 61, 172) },
	{ Name = "Ice",          A = Color3.fromRGB(125, 211, 252), B = Color3.fromRGB(196, 181, 253) },
}

local Theme = {
	Background = Color3.fromRGB(9, 10, 15),
	Surface    = Color3.fromRGB(14, 16, 24),
	Surface2   = Color3.fromRGB(21, 24, 35),
	Surface3   = Color3.fromRGB(31, 35, 50),
	Stroke     = Color3.fromRGB(42, 47, 66),
	Text       = Color3.fromRGB(234, 239, 255),
	SubText    = Color3.fromRGB(135, 145, 175),
	Success    = Color3.fromRGB(46, 230, 140),
	Warning    = Color3.fromRGB(255, 196, 61),
	Danger     = Color3.fromRGB(255, 77, 95),
	Accent     = Themes[1].A,
	Accent2    = Themes[1].B,
}

local FONT_BOLD   = Enum.Font.GothamBold
local FONT_MEDIUM = Enum.Font.GothamMedium
local FONT_BLACK  = Enum.Font.GothamBlack
local FONT_BODY   = Enum.Font.Gotham
local FONT_MONO   = Enum.Font.Code

--------------------------------------------------------------- HELPERS --
local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

local function new(class, props, children)
	local inst = Instance.new(class)
	local parent
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then parent = v else inst[k] = v end
		end
	end
	if children then
		for _, child in ipairs(children) do child.Parent = inst end
	end
	if parent then inst.Parent = parent end
	return inst
end

local function tween(inst, duration, props, style, direction)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

local function corner(parent, radius)
	local r = (radius == "full") and UDim.new(1, 0) or UDim.new(0, radius or 8)
	return new("UICorner", { CornerRadius = r, Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function pad(parent, l, t, r, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0),
		Parent = parent,
	})
end

local function list(parent, padding, fill, hAlign, vAlign)
	return new("UIListLayout", {
		Padding = UDim.new(0, padding or 0),
		FillDirection = fill or Enum.FillDirection.Vertical,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

local function text(parent, props)
	local p = {
		BackgroundTransparency = 1, BorderSizePixel = 0,
		Font = FONT_MEDIUM, TextSize = 13, Text = "",
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = parent,
	}
	if props then for k, v in pairs(props) do p[k] = v end end
	return new("TextLabel", p)
end

local function hitbox(parent, z)
	return new("TextButton", {
		Name = "Hit", BackgroundTransparency = 1, BorderSizePixel = 0,
		Text = "", AutoButtonColor = false,
		Size = UDim2.new(1, 0, 1, 0), ZIndex = z or 2, Parent = parent,
	})
end

local function fmt(n) return string.format("%g", n) end

local function toHex(c)
	return string.format("#%02X%02X%02X",
		math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function escapeRich(s)
	s = tostring(s)
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

--------------------------------------------------- THEME ĐỘNG (hooks) --
local function onTheme(fn)
	table.insert(themeHooks, fn)
	fn()
end

local function fireTheme()
	for _, fn in ipairs(themeHooks) do pcall(fn) end
end

local themeToken
local function setAccent(a, b, instant)
	if instant then
		Theme.Accent, Theme.Accent2 = a, b
		fireTheme()
		return
	end
	local fromA, fromB = Theme.Accent, Theme.Accent2
	local token = {}
	themeToken = token
	task.spawn(function()
		local t0 = os.clock()
		while themeToken == token and not Library.Destroyed do
			local k = math.clamp((os.clock() - t0) / 0.4, 0, 1)
			k = k * k * (3 - 2 * k)
			Theme.Accent  = fromA:Lerp(a, k)
			Theme.Accent2 = fromB:Lerp(b, k)
			fireTheme()
			if k >= 1 then break end
			RunService.RenderStepped:Wait()
		end
	end)
end

local function accentGradient(parent, rotation, loop, spin)
	local g = new("UIGradient", { Rotation = rotation or 0, Parent = parent })
	onTheme(function()
		if loop then
			g.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.Accent),
				ColorSequenceKeypoint.new(0.5, Theme.Accent2),
				ColorSequenceKeypoint.new(1, Theme.Accent),
			})
		else
			g.Color = ColorSequence.new(Theme.Accent, Theme.Accent2)
		end
	end)
	if spin then table.insert(spinning, { g = g, speed = spin, rot = rotation or 0 }) end
	return g
end

--------------------------------------------------------- SCREEN GUI --
local ScreenGui = new("ScreenGui", {
	Name = GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
	Parent = PlayerGui,
})

--------------------------------------------------- SỐ LIỆU FPS / PING --
function Library:OnStats(fn)
	table.insert(statsHooks, fn)
	pcall(fn, Library.Stats)
end

do
	local acc, frames = 0, 0
	connect(RunService.RenderStepped, function(dt)
		for _, s in ipairs(spinning) do
			s.rot = (s.rot + dt * s.speed) % 360
			s.g.Rotation = s.rot
		end
		acc, frames = acc + dt, frames + 1
		if acc >= 0.25 then
			local S = Library.Stats
			S.FPS = S.FPS * 0.4 + (frames / acc) * 0.6
			local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() * 1000 end)
			if not ok or not ping or ping <= 0 then
				ok, ping = pcall(function()
					return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
				end)
			end
			S.Ping = (ok and ping) or 0
			local okM, mem = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
			S.Mem = (okM and mem) or 0
			acc, frames = 0, 0
			for _, fn in ipairs(statsHooks) do pcall(fn, S) end
		end
	end)
end

--------------------------------------------------------------- RIPPLE --
local function ripple(button)
	local mouse = UserInputService:GetMouseLocation()
	local abs, size = button.AbsolutePosition, button.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return end
	local px = math.clamp((mouse.X - abs.X) / size.X, 0, 1)
	local py = math.clamp((mouse.Y - abs.Y) / size.Y, 0, 1)
	local circle = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82,
		BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(px, 0, py, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		Size = UDim2.new(0, 0, 0, 0), ZIndex = 3, Parent = button,
	})
	corner(circle, "full")
	local tw = tween(circle, 0.55, { Size = UDim2.new(2.4, 0, 2.4, 0), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
	tw.Completed:Connect(function() circle:Destroy() end)
end

------------------------------------------------------------- KÉO THẢ --
local function makeDraggable(handle, target, onClick)
	local dragging, dragInput, dragStart, startPos, startAbs, moved = false, nil, nil, nil, nil, 0

	connect(handle.InputBegan, function(input)
		if not isPress(input) then return end
		dragging, moved = true, 0
		dragStart, startPos, startAbs = input.Position, target.Position, target.AbsolutePosition
		local c
		c = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				if c then c:Disconnect() end
				if moved < 6 and onClick then onClick() end
			end
		end)
	end)

	connect(handle.InputChanged, function(input)
		if isMove(input) then dragInput = input end
	end)

	connect(UserInputService.InputChanged, function(input)
		if not dragging or input ~= dragInput then return end
		local delta = input.Position - dragStart
		moved = math.max(moved, delta.Magnitude)
		local vp, size = ScreenGui.AbsoluteSize, target.AbsoluteSize
		local nx = math.clamp(startAbs.X + delta.X, 80 - size.X, vp.X - 80)
		local ny = math.clamp(startAbs.Y + delta.Y, 0, vp.Y - 44)
		tween(target, 0.07, {
			Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + (nx - startAbs.X),
				startPos.Y.Scale, startPos.Y.Offset + (ny - startAbs.Y)
			),
		}, Enum.EasingStyle.Quad)
	end)
end

------------------------------------------------------------------------
-- PHẦN 2 : THÀNH PHẦN GIAO DIỆN (Section, Button, Toggle, Slider, ...)
------------------------------------------------------------------------
local Tab = {}
Tab.__index = Tab

function Tab:_order()
	self._n = self._n + 1
	return self._n
end

local function fire(callback, ...)
	if callback then
		local ok, err = pcall(callback, ...)
		if not ok then warn("[THONHUD] lỗi callback: " .. tostring(err)) end
	end
end

local function setFlag(cfg, value)
	if cfg and cfg.Flag then Library.Flags[cfg.Flag] = value end
end

local function card(tab, height, name)
	local f = new("Frame", {
		Name = name or "Card", Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Theme.Surface2, BorderSizePixel = 0,
		LayoutOrder = tab:_order(), Parent = tab.Scroll,
	})
	corner(f, 8)
	local st = stroke(f, Theme.Stroke, 1, 0.3)
	return f, st
end

local function hoverFx(hit, frame, st)
	connect(hit.MouseEnter, function()
		tween(frame, 0.18, { BackgroundColor3 = Theme.Surface3 })
		tween(st, 0.18, { Color = Theme.Accent, Transparency = 0.55 })
	end)
	connect(hit.MouseLeave, function()
		tween(frame, 0.18, { BackgroundColor3 = Theme.Surface2 })
		tween(st, 0.18, { Color = Theme.Stroke, Transparency = 0.3 })
	end)
end

------------------------------------------------------------- SECTION --
function Tab:CreateSection(name)
	local row = new("Frame", {
		Name = "Section", Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
		LayoutOrder = self:_order(), Parent = self.Scroll,
	})
	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 2),
		Size = UDim2.new(0, 3, 0, 12), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, Parent = row,
	})
	corner(bar, 2)
	accentGradient(bar, 90)
	text(row, {
		Text = string.upper(name or "SECTION"), Font = FONT_MONO, TextSize = 11,
		TextColor3 = Theme.SubText, Position = UDim2.new(0, 14, 0, 2), Size = UDim2.new(1, -14, 1, 0),
	})
	return row
end

-------------------------------------------------------------- BUTTON --
function Tab:CreateButton(cfg)
	local c, st = card(self, 38, "Button")
	c.ClipsDescendants = true
	text(c, { Text = cfg.Name or "Button", Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -50, 1, 0) })
	local arrow = text(c, {
		Text = "›", Font = FONT_BOLD, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(1, -36, 0, -2), Size = UDim2.new(0, 22, 1, 0),
	})
	onTheme(function() arrow.TextColor3 = Theme.Accent end)
	local hit = hitbox(c)
	hoverFx(hit, c, st)
	connect(hit.MouseButton1Click, function()
		ripple(c)
		tween(arrow, 0.12, { Position = UDim2.new(1, -30, 0, -2) })
		task.delay(0.12, function() tween(arrow, 0.2, { Position = UDim2.new(1, -36, 0, -2) }) end)
		fire(cfg.Callback)
	end)
	return { Frame = c }
end

-------------------------------------------------------------- TOGGLE --
function Tab:CreateToggle(cfg)
	local desc = cfg.Description
	local h = desc and 54 or 40
	local c, st = card(self, h, "Toggle")
	text(c, {
		Text = cfg.Name or "Toggle", Position = UDim2.new(0, 14, 0, desc and 9 or 0),
		Size = UDim2.new(1, -86, 0, desc and 18 or h),
	})
	if desc then
		text(c, {
			Text = desc, Font = FONT_BODY, TextSize = 11, TextColor3 = Theme.SubText,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(0, 14, 0, 27), Size = UDim2.new(1, -86, 0, 16),
		})
	end
	local track = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(0, 44, 0, 22), BackgroundColor3 = Theme.Surface3,
		BorderSizePixel = 0, Parent = c,
	})
	corner(track, "full")
	local trackStroke = stroke(track, Theme.Stroke, 1, 0.2)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.new(0, 16, 0, 16), BackgroundColor3 = Theme.SubText,
		BorderSizePixel = 0, Parent = track,
	})
	corner(knob, "full")

	local state = cfg.Default and true or false
	local obj = {}

	local function apply(inst, props, animate)
		if animate then tween(inst, 0.22, props)
		else for k, v in pairs(props) do inst[k] = v end end
	end
	local function render(animate)
		if state then
			apply(track, { BackgroundColor3 = Theme.Accent }, animate)
			apply(trackStroke, { Color = Theme.Accent, Transparency = 0.5 }, animate)
			apply(knob, { Position = UDim2.new(0, 25, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1) }, animate)
		else
			apply(track, { BackgroundColor3 = Theme.Surface3 }, animate)
			apply(trackStroke, { Color = Theme.Stroke, Transparency = 0.2 }, animate)
			apply(knob, { Position = UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = Theme.SubText }, animate)
		end
	end
	render(false)
	onTheme(function()
		if state then
			track.BackgroundColor3 = Theme.Accent
			trackStroke.Color = Theme.Accent
		end
	end)

	function obj:Set(v, silent)
		v = v and true or false
		if v == state then return end
		state = v
		setFlag(cfg, state)
		render(true)
		if not silent then fire(cfg.Callback, state) end
	end
	function obj:Get() return state end

	local hit = hitbox(c)
	hoverFx(hit, c, st)
	connect(hit.MouseButton1Click, function() obj:Set(not state) end)
	setFlag(cfg, state)
	return obj
end

-------------------------------------------------------------- SLIDER --
function Tab:CreateSlider(cfg)
	local min, max = cfg.Min or 0, cfg.Max or 100
	local inc = cfg.Increment or 1
	local suffix = cfg.Suffix or ""
	local c, st = card(self, 58, "Slider")
	text(c, { Text = cfg.Name or "Slider", Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -110, 0, 18) })
	local valueLabel = text(c, {
		Font = FONT_MONO, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -104, 0, 8), Size = UDim2.new(0, 90, 0, 18),
	})
	onTheme(function() valueLabel.TextColor3 = Theme.Accent end)

	local track = new("Frame", {
		Position = UDim2.new(0, 14, 0, 38), Size = UDim2.new(1, -28, 0, 6),
		BackgroundColor3 = Theme.Surface3, BorderSizePixel = 0, Parent = c,
	})
	corner(track, "full")
	local fill = new("Frame", {
		Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, Parent = track,
	})
	corner(fill, "full")
	accentGradient(fill, 0)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ZIndex = 2, Parent = track,
	})
	corner(knob, "full")
	local ring = stroke(knob, Theme.Accent, 2, 0.35)
	onTheme(function() ring.Color = Theme.Accent end)

	local function snap(v)
		v = math.floor((v - min) / inc + 0.5) * inc + min
		v = math.clamp(v, min, max)
		return tonumber(string.format("%.6f", v))
	end
	local value = snap(cfg.Default or min)

	local function render(animate)
		local rel = (max == min) and 0 or (value - min) / (max - min)
		valueLabel.Text = fmt(value) .. suffix
		if animate then
			tween(fill, 0.09, { Size = UDim2.new(rel, 0, 1, 0) }, Enum.EasingStyle.Quad)
			tween(knob, 0.09, { Position = UDim2.new(rel, 0, 0.5, 0) }, Enum.EasingStyle.Quad)
		else
			fill.Size = UDim2.new(rel, 0, 1, 0)
			knob.Position = UDim2.new(rel, 0, 0.5, 0)
		end
	end
	render(false)
	setFlag(cfg, value)

	local obj = {}
	function obj:Set(v, silent)
		v = snap(tonumber(v) or min)
		if v == value then return end
		value = v
		setFlag(cfg, value)
		render(true)
		if not silent then fire(cfg.Callback, value) end
	end
	function obj:Get() return value end

	local scroll = self.Scroll
	local hit = new("TextButton", {
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
		Position = UDim2.new(0, 8, 0, 26), Size = UDim2.new(1, -16, 0, 30),
		ZIndex = 3, Parent = c,
	})
	local dragging = false
	local function fromX(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		obj:Set(min + (max - min) * rel)
	end
	connect(hit.InputBegan, function(input)
		if not isPress(input) then return end
		dragging = true
		scroll.ScrollingEnabled = false
		tween(knob, 0.12, { Size = UDim2.new(0, 18, 0, 18) })
		fromX(input.Position.X)
		local cn
		cn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				scroll.ScrollingEnabled = true
				tween(knob, 0.15, { Size = UDim2.new(0, 14, 0, 14) })
				if cn then cn:Disconnect() end
			end
		end)
	end)
	connect(UserInputService.InputChanged, function(input)
		if dragging and isMove(input) then fromX(input.Position.X) end
	end)
	hoverFx(hit, c, st)
	return obj
end

----------------------------------------------------------- DROPDOWN --
function Tab:CreateDropdown(cfg)
	local multi = cfg.Multi and true or false
	local options = cfg.Options or {}
	local c, st = card(self, 40, "Dropdown")
	c.ClipsDescendants = true
	text(c, { Text = cfg.Name or "Dropdown", Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0.45, -14, 0, 40) })
	local valueLabel = text(c, {
		Font = FONT_MONO, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.6, -44, 0, 40),
	})
	onTheme(function() valueLabel.TextColor3 = Theme.Accent end)
	local chevron = text(c, {
		Text = "›", Font = FONT_BOLD, TextSize = 22, TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -20, 0, 20), Size = UDim2.new(0, 20, 0, 24), Rotation = 90,
	})
	local header = hitbox(c)
	header.Size = UDim2.new(1, 0, 0, 40)
	local holder = new("Frame", {
		Position = UDim2.new(0, 8, 0, 44), Size = UDim2.new(1, -16, 0, 0),
		BackgroundTransparency = 1, Parent = c,
	})
	list(holder, 3)

	local selected, buttons, open = {}, {}, false
	local obj = {}

	local function result()
		if multi then
			local out = {}
			for _, o in ipairs(options) do if selected[o] then table.insert(out, o) end end
			return out
		end
		for _, o in ipairs(options) do if selected[o] then return o end end
		return nil
	end
	local function summary()
		local picked = {}
		for _, o in ipairs(options) do if selected[o] then table.insert(picked, tostring(o)) end end
		if #picked == 0 then return "—" end
		if #picked <= 2 then return table.concat(picked, ", ") end
		return picked[1] .. ", " .. picked[2] .. " +" .. (#picked - 2)
	end
	local function listHeight()
		return #options * 30 + math.max(#options - 1, 0) * 3
	end
	local function resize(animate)
		local h = open and (44 + listHeight() + 8) or 40
		holder.Size = UDim2.new(1, -16, 0, listHeight())
		if animate then tween(c, 0.25, { Size = UDim2.new(1, 0, 0, h) })
		else c.Size = UDim2.new(1, 0, 0, h) end
		tween(chevron, 0.25, { Rotation = open and -90 or 90 })
	end
	local function refresh()
		for opt, b in pairs(buttons) do
			local on = selected[opt] == true
			tween(b.btn, 0.15, { BackgroundTransparency = on and 0.8 or 1 })
			b.label.TextColor3 = on and Theme.Text or Theme.SubText
			b.dot.BackgroundTransparency = on and 0 or 1
		end
		valueLabel.Text = summary()
	end
	local function pick(opt)
		if multi then
			selected[opt] = (not selected[opt]) or nil
		else
			selected = { [opt] = true }
			open = false
			resize(true)
		end
		refresh()
		setFlag(cfg, result())
		fire(cfg.Callback, result())
	end
	local function build()
		for _, b in pairs(buttons) do b.btn:Destroy() end
		buttons = {}
		for i, opt in ipairs(options) do
			local btn = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Accent,
				BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
				AutoButtonColor = false, LayoutOrder = i, Parent = holder,
			})
			corner(btn, 6)
			local dot = new("Frame", {
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0),
				Size = UDim2.new(0, 6, 0, 6), BackgroundColor3 = Theme.Accent,
				BackgroundTransparency = 1, BorderSizePixel = 0, Parent = btn,
			})
			corner(dot, "full")
			local lbl = text(btn, {
				Text = tostring(opt), TextSize = 12, TextColor3 = Theme.SubText,
				Position = UDim2.new(0, 26, 0, 0), Size = UDim2.new(1, -32, 1, 0),
			})
			buttons[opt] = { btn = btn, label = lbl, dot = dot }
			onTheme(function()
				dot.BackgroundColor3 = Theme.Accent
				btn.BackgroundColor3 = Theme.Accent
			end)
			connect(btn.MouseEnter, function() if not selected[opt] then lbl.TextColor3 = Theme.Text end end)
			connect(btn.MouseLeave, function() if not selected[opt] then lbl.TextColor3 = Theme.SubText end end)
			connect(btn.MouseButton1Click, function() pick(opt) end)
		end
		refresh()
		resize(false)
	end

	function obj:Set(v, silent)
		selected = {}
		if multi and type(v) == "table" then
			for _, o in ipairs(v) do selected[o] = true end
		elseif v ~= nil then
			selected[v] = true
		end
		refresh()
		setFlag(cfg, result())
		if not silent then fire(cfg.Callback, result()) end
	end
	function obj:Get() return result() end
	function obj:Refresh(newOptions)
		options, selected = newOptions or {}, {}
		build()
	end

	build()
	if cfg.Default ~= nil then obj:Set(cfg.Default, true) end
	hoverFx(header, c, st)
	connect(header.MouseButton1Click, function()
		open = not open
		resize(true)
	end)
	return obj
end

----------------------------------------------------------- KEYBIND --
function Tab:CreateKeybind(cfg)
	local c, st = card(self, 40, "Keybind")
	text(c, { Text = cfg.Name or "Keybind", Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -150, 1, 0) })
	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 116, 0, 26), BackgroundColor3 = Theme.Surface3,
		BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = c,
	})
	corner(btn, 6)
	local bst = stroke(btn, Theme.Stroke, 1, 0.2)
	local lbl = text(btn, {
		Font = FONT_MONO, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 1, 0),
	})
	onTheme(function() lbl.TextColor3 = Theme.Accent end)

	local key = cfg.Default
	local listening = false
	local obj = {}
	local function render()
		lbl.Text = listening and "[ ... ]" or ("[ " .. (key and key.Name or "None") .. " ]")
	end
	render()
	setFlag(cfg, key)

	function obj:Set(k, silent)
		key = k
		setFlag(cfg, key)
		render()
		if not silent then fire(cfg.Changed, key) end
	end
	function obj:Get() return key end

	hoverFx(btn, c, st)
	connect(btn.MouseButton1Click, function()
		listening = true
		Library.Listening = true
		render()
		tween(bst, 0.15, { Color = Theme.Accent, Transparency = 0 })
	end)
	connect(UserInputService.InputBegan, function(input, processed)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				if input.KeyCode ~= Enum.KeyCode.Escape then obj:Set(input.KeyCode) else render() end
				tween(bst, 0.15, { Color = Theme.Stroke, Transparency = 0.2 })
				task.defer(function() Library.Listening = false end)
			end
			return
		end
		if not processed and key and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == key then
			fire(cfg.Callback, key)
		end
	end)
	return obj
end

------------------------------------------------------------- TEXTBOX --
function Tab:CreateInput(cfg)
	local c, st = card(self, 40, "Input")
	text(c, { Text = cfg.Name or "Input", Position = UDim2.new(0, 14, 0, 0), Size = cfg.Wide and UDim2.new(0, 96, 1, 0) or UDim2.new(1, -190, 1, 0) })
	local box = new("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = cfg.Wide and UDim2.new(1, -124, 0, 26) or UDim2.new(0, 160, 0, 26),
		BackgroundColor3 = Theme.Surface3, BorderSizePixel = 0,
		Font = FONT_MONO, TextSize = 12, TextColor3 = Theme.Text,
		PlaceholderText = cfg.Placeholder or "type here...", PlaceholderColor3 = Theme.SubText,
		Text = cfg.Default or "", ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = c,
	})
	corner(box, 6)
	pad(box, 8, 0, 8, 0)
	local bst = stroke(box, Theme.Stroke, 1, 0.2)
	connect(box.Focused, function() tween(bst, 0.15, { Color = Theme.Accent, Transparency = 0 }) end)
	connect(box.FocusLost, function(enterPressed)
		tween(bst, 0.15, { Color = Theme.Stroke, Transparency = 0.2 })
		setFlag(cfg, box.Text)
		fire(cfg.Callback, box.Text, enterPressed)
	end)
	setFlag(cfg, box.Text)
	return {
		Get = function() return box.Text end,
		Set = function(_, v) box.Text = tostring(v) end,
	}
end

-------------------------------------------------- LABEL / PARAGRAPH --
function Tab:CreateLabel(txt)
	local row = new("Frame", {
		Name = "Label", Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
		LayoutOrder = self:_order(), Parent = self.Scroll,
	})
	local l = text(row, {
		Text = txt or "", Font = FONT_MONO, TextSize = 12, TextColor3 = Theme.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(1, -8, 1, 0),
	})
	return { Frame = row, Set = function(_, t) l.Text = tostring(t) end }
end

function Tab:CreateParagraph(cfg)
	local c = card(self, 0, "Paragraph")
	c.AutomaticSize = Enum.AutomaticSize.Y
	c.Size = UDim2.new(1, 0, 0, 0)
	pad(c, 14, 12, 14, 12)
	list(c, 4)
	local title = text(c, {
		Text = cfg.Title or "", Font = FONT_BOLD, TextSize = 13,
		Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1,
	})
	local body = text(c, {
		Text = cfg.Content or "", Font = FONT_BODY, TextSize = 12, TextColor3 = Theme.SubText,
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2,
	})
	return {
		Frame = c,
		Set = function(_, t, b)
			if t then title.Text = t end
			if b then body.Text = b end
		end,
	}
end

------------------------------------------------------------- CONSOLE --
function Tab:CreateConsole(cfg)
	cfg = cfg or {}
	local c = card(self, cfg.Height or 150, "Console")
	c.BackgroundColor3 = Color3.fromRGB(7, 8, 12)
	c.ClipsDescendants = true
	local bar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0, Parent = c,
	})
	local dotColors = { Theme.Danger, Theme.Warning, Theme.Success }
	for i, col in ipairs(dotColors) do
		local d = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10 + (i - 1) * 14, 0.5, 0),
			Size = UDim2.new(0, 8, 0, 8), BackgroundColor3 = col, BorderSizePixel = 0, Parent = bar,
		})
		corner(d, "full")
	end
	text(bar, {
		Text = cfg.Name or "terminal", Font = FONT_MONO, TextSize = 11, TextColor3 = Theme.SubText,
		Position = UDim2.new(0, 58, 0, 0), Size = UDim2.new(1, -66, 1, 0),
	})
	local body = new("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 1, -24),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Accent, CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = c,
	})
	onTheme(function() body.ScrollBarImageColor3 = Theme.Accent end)
	pad(body, 10, 6, 10, 6)
	list(body, 2)

	local obj, lines, count = {}, {}, 0
	local levels = { INFO = "Accent", OK = "Success", WARN = "Warning", ERR = "Danger" }
	function obj:Log(msg, level)
		level = level or "INFO"
		count = count + 1
		local col = Theme[levels[level] or "Accent"]
		local line = text(body, {
			RichText = true, Font = FONT_MONO, TextSize = 12, TextWrapped = true,
			TextColor3 = Theme.Text, TextYAlignment = Enum.TextYAlignment.Top,
			AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = count,
			Text = string.format(
				'<font color="%s">[%s]</font> <font color="%s">%s</font>  %s',
				toHex(Theme.SubText), os.date("%H:%M:%S"), toHex(col), level, escapeRich(msg)
			),
		})
		table.insert(lines, line)
		if #lines > 100 then table.remove(lines, 1):Destroy() end
		task.defer(function()
			RunService.Heartbeat:Wait()
			body.CanvasPosition = Vector2.new(0, 99999)
		end)
	end
	function obj:Clear()
		for _, l in ipairs(lines) do l:Destroy() end
		lines = {}
	end
	Library._console = obj
	return obj
end

--------------------------------------------------------------- GRAPH --
function Tab:CreateGraph(cfg)
	cfg = cfg or {}
	local n, maxV = cfg.Samples or 36, cfg.Max or 120
	local c = card(self, 96, "Graph")
	text(c, { Text = cfg.Name or "Graph", Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(0.5, 0, 0, 18) })
	local val = text(c, {
		Font = FONT_MONO, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(0.5, -14, 0, 18),
	})
	onTheme(function() val.TextColor3 = Theme.Accent end)
	local area = new("Frame", {
		Position = UDim2.new(0, 14, 0, 32), Size = UDim2.new(1, -28, 0, 52),
		BackgroundTransparency = 1, Parent = c,
	})
	list(area, 2, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom)
	local bars, values = {}, {}
	for i = 1, n do
		values[i] = 0
		bars[i] = new("Frame", {
			Size = UDim2.new(1 / n, -2, 0, 2), BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0, LayoutOrder = i, Parent = area,
		})
		corner(bars[i], 2)
	end
	local obj = {}
	function obj:Push(v, label)
		table.remove(values, 1)
		table.insert(values, v)
		for i = 1, n do
			local k = math.clamp(values[i] / maxV, 0, 1)
			bars[i].Size = UDim2.new(1 / n, -2, k, 2)
			bars[i].BackgroundColor3 = Theme.Accent:Lerp(Theme.Accent2, 1 - k)
		end
		val.Text = label or fmt(math.floor(v + 0.5))
	end
	return obj
end

-------------------------------------------------------- THEME PICKER --
local themeMarkers = {}
Library.CurrentTheme = Themes[1].Name

function Library:SetTheme(name, instant)
	for _, th in ipairs(Themes) do
		if th.Name == name then
			Library.CurrentTheme = name
			setAccent(th.A, th.B, instant)
			for _, mark in ipairs(themeMarkers) do pcall(mark, name) end
			return true
		end
	end
	return false
end

function Library:GetThemes()
	local out = {}
	for _, th in ipairs(Themes) do table.insert(out, th.Name) end
	return out
end

function Tab:CreateThemePicker(cfg)
	cfg = cfg or {}
	local c = card(self, 78, "ThemePicker")
	text(c, { Text = cfg.Name or "Theme", Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -28, 0, 18) })
	local row = new("Frame", {
		Position = UDim2.new(0, 14, 0, 36), Size = UDim2.new(1, -28, 0, 30),
		BackgroundTransparency = 1, Parent = c,
	})
	list(row, 12, Enum.FillDirection.Horizontal)
	local rings = {}
	for i, th in ipairs(Themes) do
		local sw = new("TextButton", {
			Size = UDim2.new(0, 30, 0, 30), BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = row,
		})
		corner(sw, "full")
		new("UIGradient", { Rotation = 45, Color = ColorSequence.new(th.A, th.B), Parent = sw })
		rings[th.Name] = stroke(sw, Color3.new(1, 1, 1), 2, 1)
		connect(sw.MouseButton1Click, function()
			Library:SetTheme(th.Name)
			fire(cfg.Callback, th.Name)
		end)
	end
	local function mark(name)
		for n, r in pairs(rings) do tween(r, 0.2, { Transparency = (n == name) and 0 or 1 }) end
	end
	table.insert(themeMarkers, mark)
	for n, r in pairs(rings) do r.Transparency = (n == Library.CurrentTheme) and 0 or 1 end
	return { Frame = c }
end

------------------------------------------------------------------------
-- PHẦN 3 : THÔNG BÁO (toast)
------------------------------------------------------------------------
Library.Notifications = true

local notifyHolder = new("Frame", {
	Name = "Notifications", AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -16), Size = UDim2.new(0, 300, 1, -32),
	BackgroundTransparency = 1, Parent = ScreenGui,
})
list(notifyHolder, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)

local notifyIcons  = { info = "i", success = "✓", warning = "!", error = "×" }
local notifyColors = { info = "Accent", success = "Success", warning = "Warning", error = "Danger" }
local notifyCount  = 0

function Library:Log(msg, level)
	if Library._console then Library._console:Log(msg, level) end
end

function Library:Notify(cfg)
	cfg = cfg or {}
	if not Library.Notifications and not cfg.Force then return end
	notifyCount = notifyCount + 1
	local kind = notifyColors[cfg.Type or "info"] and (cfg.Type or "info") or "info"
	local color = Theme[notifyColors[kind]]
	local duration = cfg.Duration or Library.NotifyDuration or 4

	local wrap = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, LayoutOrder = notifyCount, Parent = notifyHolder,
	})
	local box = new("Frame", {
		Position = UDim2.new(1.25, 0, 0, 0), Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0, ClipsDescendants = true, Parent = wrap,
	})
	corner(box, 10)
	stroke(box, color, 1, 0.55)
	new("Frame", {
		Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0, Parent = box,
	})
	local icon = new("Frame", {
		Position = UDim2.new(0, 16, 0, 12), Size = UDim2.new(0, 24, 0, 24),
		BackgroundColor3 = color, BackgroundTransparency = 0.8, BorderSizePixel = 0, Parent = box,
	})
	corner(icon, "full")
	text(icon, {
		Text = notifyIcons[kind], Font = FONT_BOLD, TextSize = 14, TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 1, 0),
	})
	local body = new("Frame", {
		Position = UDim2.new(0, 50, 0, 0), Size = UDim2.new(1, -62, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = box,
	})
	pad(body, 0, 11, 0, 15)
	list(body, 2)
	text(body, {
		Text = cfg.Title or "Notification", Font = FONT_BOLD, TextSize = 13,
		Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1,
	})
	if cfg.Content and cfg.Content ~= "" then
		text(body, {
			Text = cfg.Content, Font = FONT_BODY, TextSize = 12, TextColor3 = Theme.SubText,
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2,
		})
	end
	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = color,
		BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = box,
	})

	local dismissed = false
	local function dismiss()
		if dismissed then return end
		dismissed = true
		local tw = tween(box, 0.3, { Position = UDim2.new(1.25, 0, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tw.Completed:Connect(function() wrap:Destroy() end)
	end

	tween(box, 0.45, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
	tween(bar, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
	task.delay(duration, dismiss)
	local hit = hitbox(box, 5)
	connect(hit.MouseButton1Click, dismiss)
end

------------------------------------------------------------------------
-- PHẦN 4 : CỬA SỔ CHÍNH & XÂY DỰNG GIAO DIỆN
------------------------------------------------------------------------
local SHAPE_ORDER = { "grid", "circle", "ring", "diamond", "square", "bars" }

local function buildShape(parent, kind)
	local box = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 18, 0, 18), BackgroundTransparency = 1, Parent = parent,
	})
	local fills, strokes = {}, {}
	local function block(x, y, w, h, r, rot)
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, 0.5, y),
			Size = UDim2.new(0, w, 0, h), BackgroundColor3 = Theme.SubText,
			BorderSizePixel = 0, Rotation = rot or 0, Parent = box,
		})
		if r then corner(f, r) end
		table.insert(fills, f)
	end
	local function outline(w, h, r)
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, w, 0, h), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = box,
		})
		corner(f, r)
		table.insert(strokes, stroke(f, Theme.SubText, 2, 0))
	end
	if kind == "circle" then block(0, 0, 14, 14, "full")
	elseif kind == "ring" then outline(13, 13, "full")
	elseif kind == "diamond" then block(0, 0, 11, 11, 2, 45)
	elseif kind == "square" then outline(11, 11, 3); block(0, 0, 5, 5, 1)
	elseif kind == "bars" then block(-5, 3, 4, 8, 2); block(0, 0, 4, 14, 2); block(5, 2, 4, 10, 2)
	else block(-4, -4, 7, 7, 2); block(4, -4, 7, 7, 2); block(-4, 4, 7, 7, 2); block(4, 4, 7, 7, 2) end
	return function(color)
		for _, f in ipairs(fills) do tween(f, 0.2, { BackgroundColor3 = color }) end
		for _, st in ipairs(strokes) do tween(st, 0.2, { Color = color }) end
	end
end

local function fetchImage(url)
	local requestFn = request or http_request
	local save, toAsset = writefile, getcustomasset or getsynasset
	if not (requestFn and save and toAsset) then return nil end
	local ok, res = pcall(requestFn, { Url = url, Method = "GET" })
	if not ok or type(res) ~= "table" or not res.Body then return nil end
	if res.StatusCode and res.StatusCode ~= 200 then return nil end
	local file = "thonhud_logo.png"
	if not pcall(save, file, res.Body) then return nil end
	local okAsset, id = pcall(toAsset, file)
	return okAsset and id or nil
end

function Library:CreateWindow(cfg)
	cfg = cfg or {}
	local W = { Tabs = {}, ActiveTab = nil, State = "boot" }
	local title    = cfg.Title or Library.Name
	local subtitle = cfg.Subtitle or ("GUI  •  v" .. Library.Version)
	local width    = cfg.Width or 650
	local height   = cfg.Height or 430
	local HEADER_H, SIDEBAR_W = 50, 172
	local white = Color3.new(1, 1, 1)
	local logoChar = cfg.Logo or string.upper(string.sub(title, 1, 1))

	local Root = new("Frame", {
		Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(width, height), BackgroundTransparency = 1,
		Visible = false, Parent = ScreenGui,
	})
	local sizeScale = new("UIScale", { Parent = Root })
	local userScale = 1
	local function fit()
		local vp = ScreenGui.AbsoluteSize
		local s = math.min(1, (vp.X - 24) / width, (vp.Y - 24) / height)
		sizeScale.Scale = math.max(s, 0.45) * userScale
	end
	fit()
	connect(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"), fit)
	function W:SetScale(s) userScale = s; fit() end

	local fades = {}
	local function addFade(inst, prop, shown)
		local f = { inst = inst, prop = prop, shown = shown, hidden = 1 }
		table.insert(fades, f)
		return f
	end

	local shadow = new("Frame", { Name = "Shadow", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Root })
	for i, grow in ipairs({ 14, 28, 46 }) do
		local layer = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 8),
			Size = UDim2.new(1, grow, 1, grow), BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.78 + i * 0.05, BorderSizePixel = 0, Parent = shadow,
		})
		corner(layer, 12 + grow / 2)
		addFade(layer, "BackgroundTransparency", 0.78 + i * 0.05)
	end
	for i, grow in ipairs({ 6, 16 }) do
		local g = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, grow, 1, grow), BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 0.9 + i * 0.03, BorderSizePixel = 0, Parent = shadow,
		})
		corner(g, 12 + grow / 2)
		onTheme(function() g.BackgroundColor3 = Theme.Accent end)
		addFade(g, "BackgroundTransparency", 0.9 + i * 0.03)
	end

	local Main = new("Frame", {
		Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0, Parent = Root,
	})
	corner(Main, 12)
	local animScale = new("UIScale", { Parent = Main })
	local mainStroke = stroke(Main, white, 1.5, 0)
	accentGradient(mainStroke, 0, true, 50)
	local mainFade = addFade(Main, "BackgroundTransparency", 0)
	addFade(mainStroke, "Transparency", 0)

	local Content = new("CanvasGroup", {
		Name = "Content", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
		BorderSizePixel = 0, GroupTransparency = 0, Parent = Main,
	})
	corner(Content, 12)
	addFade(Content, "GroupTransparency", 0)

	local function orb(which, size, px, py)
		for i = 1, 4 do
			local s = size * (1 - (i - 1) * 0.23)
			local f = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(px, 0, py, 0),
				Size = UDim2.fromOffset(s, s), BackgroundColor3 = Theme[which],
				BackgroundTransparency = 0.955, BorderSizePixel = 0, Parent = Content,
			})
			corner(f, "full")
			onTheme(function() f.BackgroundColor3 = Theme[which] end)
		end
	end
	orb("Accent", 340, 0.96, 0.1)
	orb("Accent2", 300, 0.28, 1.02)

	local Header = new("Frame", {
		Name = "Header", Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.2, BorderSizePixel = 0, Active = true, Parent = Content,
	})
	local hline = new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = white, BorderSizePixel = 0, Parent = Header,
	})
	accentGradient(hline, 0).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.6, 0.6), NumberSequenceKeypoint.new(1, 1),
	})

	local logoTargets = {}
	local function addLogoImage(parent, radius)
		local img = new("ImageLabel", {
			BackgroundTransparency = 1, BorderSizePixel = 0, Image = "", ImageTransparency = 1,
			ScaleType = Enum.ScaleType.Crop, Size = UDim2.new(1, 0, 1, 0), ZIndex = 2, Parent = parent,
		})
		corner(img, radius)
		table.insert(logoTargets, { holder = parent, img = img })
	end

	local logo = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.new(0, 30, 0, 30),
		BackgroundColor3 = white, BorderSizePixel = 0, Parent = Header,
	})
	corner(logo, 9)
	accentGradient(logo, 45)
	text(logo, {
		Name = "LogoLetter", Text = logoChar, Font = FONT_BLACK, TextSize = 17, TextColor3 = Theme.Background,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 1, 0),
	})
	addLogoImage(logo, 9)
	local titleLabel = text(Header, {
		Text = string.upper(title), Font = FONT_BLACK, TextSize = 16, TextColor3 = white,
		Position = UDim2.new(0, 54, 0, 8), Size = UDim2.new(0, 130, 0, 18),
	})
	accentGradient(titleLabel, 0)
	text(Header, {
		Text = subtitle, Font = FONT_MONO, TextSize = 10, TextColor3 = Theme.SubText,
		Position = UDim2.new(0, 54, 0, 27), Size = UDim2.new(0, 180, 0, 14),
	})

	local chips = text(Header, {
		RichText = true, Font = FONT_MONO, TextSize = 11, TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -98, 0.5, 0), Size = UDim2.new(0, 170, 0, 20),
	})
	Library:OnStats(function(S)
		local col = S.FPS >= 55 and Theme.Success or (S.FPS >= 30 and Theme.Warning or Theme.Danger)
		chips.Text = string.format(
			'FPS <font color="%s">%d</font>   PING <font color="%s">%dms</font>',
			toHex(col), math.floor(S.FPS + 0.5), toHex(Theme.Accent), math.floor(S.Ping + 0.5)
		)
	end)

	local function headerButton(glyph, xOffset, hoverColor, size)
		local b = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOffset, 0.5, 0),
			Size = UDim2.new(0, 30, 0, 30), BackgroundColor3 = Theme.Surface3,
			BackgroundTransparency = 0.45, BorderSizePixel = 0, Text = glyph, Font = FONT_BOLD,
			TextSize = size or 18, TextColor3 = Theme.SubText, AutoButtonColor = false, Parent = Header,
		})
		corner(b, 8)
		connect(b.MouseEnter, function()
			tween(b, 0.15, { BackgroundColor3 = hoverColor, BackgroundTransparency = 0.7, TextColor3 = hoverColor })
		end)
		connect(b.MouseLeave, function()
			tween(b, 0.15, { BackgroundColor3 = Theme.Surface3, BackgroundTransparency = 0.45, TextColor3 = Theme.SubText })
		end)
		return b
	end
	local btnMin   = headerButton("—", -52, Theme.Warning, 14)
	local btnClose = headerButton("×", -14, Theme.Danger, 20)
	makeDraggable(Header, Root)

	local Sidebar = new("Frame", {
		Name = "Sidebar", Position = UDim2.new(0, 0, 0, HEADER_H), Size = UDim2.new(0, SIDEBAR_W, 1, -HEADER_H),
		BackgroundColor3 = Theme.Surface, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = Content,
	})
	new("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = Sidebar,
	})
	text(Sidebar, {
		Text = "MENU", Font = FONT_MONO, TextSize = 10, TextColor3 = Theme.SubText,
		Position = UDim2.new(0, 18, 0, 12), Size = UDim2.new(1, -36, 0, 14),
	})
	local TabList = new("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 1, -104),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = Sidebar,
	})
	pad(TabList, 10, 4, 10, 4)
	list(TabList, 4)

	local userCard = new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 54),
		BackgroundColor3 = Theme.Surface2, BorderSizePixel = 0, Parent = Sidebar,
	})
	corner(userCard, 10)
	stroke(userCard, Theme.Stroke, 1, 0.3)
	local avatar = new("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.new(0, 34, 0, 34),
		BackgroundColor3 = Theme.Surface3, BorderSizePixel = 0, Image = "",
		ScaleType = Enum.ScaleType.Crop, Parent = userCard,
	})
	corner(avatar, "full")
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and img then avatar.Image = img end
	end)
	local online = new("Frame", {
		Position = UDim2.new(0, 36, 0.5, 5), Size = UDim2.new(0, 10, 0, 10),
		BackgroundColor3 = Theme.Success, BorderSizePixel = 0, Parent = userCard,
	})
	corner(online, "full")
	stroke(online, Theme.Surface2, 2, 0)
	text(userCard, {
		Text = LocalPlayer.DisplayName, Font = FONT_BOLD, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, 54, 0, 10), Size = UDim2.new(1, -60, 0, 16),
	})
	text(userCard, {
		Text = "@" .. LocalPlayer.Name, Font = FONT_MONO, TextSize = 10, TextColor3 = Theme.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.new(0, 54, 0, 27), Size = UDim2.new(1, -60, 0, 14),
	})

	local Pages = new("Frame", {
		Name = "Pages", Position = UDim2.new(0, SIDEBAR_W, 0, HEADER_H),
		Size = UDim2.new(1, -SIDEBAR_W, 1, -HEADER_H), BackgroundTransparency = 1,
		ClipsDescendants = true, Parent = Content,
	})

	function W:SelectTab(target)
		local tab = target
		if type(target) == "string" then
			for _, t in ipairs(W.Tabs) do if t.Name == target then tab = t end end
		end
		if type(tab) ~= "table" or W.ActiveTab == tab then return end
		if W.ActiveTab then W.ActiveTab:_setActive(false) end
		W.ActiveTab = tab
		tab:_setActive(true)
	end

	function W:CreateTab(tcfg)
		tcfg = tcfg or {}
		local tab = setmetatable({ Window = W, Name = tcfg.Name or "Tab", _n = 0, Active = false }, Tab)
		local idx = #W.Tabs + 1
		table.insert(W.Tabs, tab)
		W._seq = (W._seq or 0) + 1

		local btn = new("TextButton", {
			Name = tab.Name, Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Theme.Surface3,
			BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
			LayoutOrder = W._seq, ClipsDescendants = true, Parent = TabList,
		})
		corner(btn, 9)
		local glow = new("Frame", {
			Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = white, BackgroundTransparency = 1,
			BorderSizePixel = 0, Parent = btn,
		})
		corner(glow, 9)
		local glowGrad = new("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
			Parent = glow,
		})
		onTheme(function() glowGrad.Color = ColorSequence.new(Theme.Accent, Theme.Accent2) end)
		local bar = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 3, 0, 0),
			BackgroundColor3 = white, BorderSizePixel = 0, Parent = btn,
		})
		corner(bar, 2)
		accentGradient(bar, 90)

		local shapeHolder = new("Frame", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0),
			Size = UDim2.new(0, 24, 1, 0), Parent = btn,
		})
		local setIconColor = buildShape(shapeHolder, tcfg.Shape or SHAPE_ORDER[((idx - 1) % #SHAPE_ORDER) + 1])
		local label = text(btn, {
			Text = tab.Name, Font = FONT_MEDIUM, TextSize = 13, TextColor3 = Theme.SubText,
			Position = UDim2.new(0, 44, 0, 0), Size = UDim2.new(1, -52, 1, 0),
		})

		local page = new("CanvasGroup", {
			Name = tab.Name, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
			BorderSizePixel = 0, GroupTransparency = 1, Visible = false, Parent = Pages,
		})
		local scroll = new("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent, ScrollBarImageTransparency = 0.3,
			CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y, VerticalScrollBarInset = Enum.ScrollBarInset.None,
			Parent = page,
		})
		onTheme(function() scroll.ScrollBarImageColor3 = Theme.Accent end)
		pad(scroll, 14, 12, 14, 14)
		list(scroll, 8)
		tab.Scroll = scroll

		function tab:_setActive(on)
			tab.Active = on
			tween(btn, 0.2, { BackgroundTransparency = 1 })
			tween(glow, 0.25, { BackgroundTransparency = on and 0 or 1 })
			tween(bar, 0.25, { Size = UDim2.new(0, 3, 0, on and 18 or 0) }, Enum.EasingStyle.Back)
			tween(label, 0.2, { TextColor3 = on and Theme.Text or Theme.SubText })
			setIconColor(on and Theme.Text or Theme.SubText)
			if on then
				page.Visible = true
				page.Position = UDim2.new(0, 0, 0, 16)
				tween(page, 0.32, { Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0 })
			else
				tween(page, 0.15, { GroupTransparency = 1 })
				task.delay(0.16, function() if not tab.Active then page.Visible = false end end)
			end
		end

		function tab:Remove()
			for i, t in ipairs(W.Tabs) do
				if t == tab then table.remove(W.Tabs, i) break end
			end
			btn:Destroy()
			page:Destroy()
			if W.ActiveTab == tab then
				W.ActiveTab = nil
				if W.Tabs[1] then W:SelectTab(W.Tabs[1]) end
			end
		end

		connect(btn.MouseEnter, function()
			if tab.Active then return end
			tween(btn, 0.15, { BackgroundTransparency = 0.6 })
			tween(label, 0.15, { TextColor3 = Theme.Text })
		end)
		connect(btn.MouseLeave, function()
			if tab.Active then return end
			tween(btn, 0.15, { BackgroundTransparency = 1 })
			tween(label, 0.15, { TextColor3 = Theme.SubText })
		end)
		connect(btn.MouseButton1Click, function() W:SelectTab(tab) end)

		if idx == 1 then W:SelectTab(tab) end
		return tab
	end

	local Pill = new("Frame", {
		Name = "Pill", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.new(0, 204, 0, 42), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.06,
		BorderSizePixel = 0, Visible = false, Active = true, Parent = ScreenGui,
	})
	corner(Pill, "full")
	local pillScale = new("UIScale", { Parent = Pill })
	local pillStroke = stroke(Pill, white, 1.5, 0)
	accentGradient(pillStroke, 0, true, 60)
	local pillLogo = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Size = UDim2.new(0, 28, 0, 28),
		BackgroundColor3 = white, BorderSizePixel = 0, Parent = Pill,
	})
	corner(pillLogo, "full")
	accentGradient(pillLogo, 45)
	text(pillLogo, {
		Name = "LogoLetter", Text = logoChar, Font = FONT_BLACK, TextSize = 15, TextColor3 = Theme.Background,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 1, 0),
	})
	addLogoImage(pillLogo, "full")
	text(Pill, {
		Text = string.upper(title), Font = FONT_BLACK, TextSize = 13,
		Position = UDim2.new(0, 44, 0, 0), Size = UDim2.new(0, 90, 1, 0),
	})
	local pillFps = text(Pill, {
		Font = FONT_MONO, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -86, 0, 0), Size = UDim2.new(0, 72, 1, 0),
	})
	onTheme(function() pillFps.TextColor3 = Theme.Accent end)
	Library:OnStats(function(S) pillFps.Text = string.format("%d FPS", math.floor(S.FPS + 0.5)) end)
	connect(Pill.MouseEnter, function() tween(pillScale, 0.15, { Scale = 1.06 }) end)
	connect(Pill.MouseLeave, function() tween(pillScale, 0.15, { Scale = 1 }) end)
	makeDraggable(Pill, Pill, function() W:Restore() end)

	local logoSrc = cfg.LogoImage
	if type(logoSrc) == "string" and logoSrc ~= "" then
		task.spawn(function()
			local src = logoSrc
			if string.find(src, "^https?://") then src = fetchImage(src) end
			if not src or Library.Destroyed then return end
			for _, t in ipairs(logoTargets) do
				t.img.Image = src
				tween(t.img, 0.3, { ImageTransparency = 0 })
				t.holder.BackgroundTransparency = 1
				local letter = t.holder:FindFirstChild("LogoLetter")
				if letter then letter.TextTransparency = 1 end
			end
		end)
	end

	local token, pillToken = 0, 0
	local function showMain()
		token = token + 1
		Root.Visible = true
		animScale.Scale = 0.9
		for _, f in ipairs(fades) do f.inst[f.prop] = f.hidden end
		for _, f in ipairs(fades) do tween(f.inst, 0.35, { [f.prop] = f.shown }) end
		tween(animScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	local function hideMain()
		token = token + 1
		local my = token
		for _, f in ipairs(fades) do tween(f.inst, 0.2, { [f.prop] = f.hidden }) end
		tween(animScale, 0.25, { Scale = 0.88 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.26, function() if my == token then Root.Visible = false end end)
	end
	local function showPill()
		pillToken = pillToken + 1
		Pill.Visible = true
		pillScale.Scale = 0.5
		tween(pillScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	local function hidePill()
		pillToken = pillToken + 1
		local my = pillToken
		tween(pillScale, 0.2, { Scale = 0.5 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.21, function() if my == pillToken then Pill.Visible = false end end)
	end

	function W:Minimize()
		if W.State ~= "open" then return end
		W.State = "minimized"
		hideMain()
		task.delay(0.12, function() if W.State == "minimized" then showPill() end end)
	end
	function W:Restore()
		if W.State ~= "minimized" then return end
		W.State = "open"
		hidePill()
		task.delay(0.1, function() if W.State == "open" then showMain() end end)
	end
	function W:Toggle()
		if W.State == "open" then
			W._prev, W.State = "open", "hidden"
			hideMain()
		elseif W.State == "minimized" then
			W._prev, W.State = "minimized", "hidden"
			hidePill()
		elseif W.State == "hidden" then
			W.State = W._prev or "open"
			if W.State == "open" then showMain() else showPill() end
		end
	end
	function W:SetBackgroundTransparency(t)
		mainFade.shown = t
		if W.State == "open" then tween(Main, 0.2, { BackgroundTransparency = t }) end
	end
	function W:Destroy() Library:Destroy() end

	connect(btnMin.MouseButton1Click, function() W:Minimize() end)
	connect(btnClose.MouseButton1Click, function()
		W:Toggle()
		Library:Notify({
			Title = "GUI đã được ẩn",
			Content = "Nhấn [" .. Library.ToggleKey.Name .. "] để mở lại.",
			Duration = 3,
		})
	end)
	connect(UserInputService.InputBegan, function(input, processed)
		if processed or Library.Listening then return end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Library.ToggleKey then
			W:Toggle()
		end
	end)

	local function boot()
		local Boot = new("Frame", {
			Name = "Boot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.fromOffset(380, 150), BackgroundColor3 = Theme.Background,
			BackgroundTransparency = 0.04, BorderSizePixel = 0, Parent = ScreenGui,
		})
		corner(Boot, 12)
		accentGradient(stroke(Boot, white, 1.5, 0), 0, true, 90)
		local bootScale = new("UIScale", { Scale = 0.8, Parent = Boot })
		tween(bootScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		accentGradient(text(Boot, {
			Text = string.upper(title) .. "  //  BOOT", Font = FONT_BLACK, TextSize = 15, TextColor3 = white,
			Position = UDim2.new(0, 20, 0, 14), Size = UDim2.new(1, -40, 0, 20),
		}), 0)
		local term = text(Boot, {
			Font = FONT_MONO, TextSize = 12, TextColor3 = Theme.SubText, TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.new(0, 20, 0, 44), Size = UDim2.new(1, -40, 0, 68),
		})
		local barBg = new("Frame", {
			Position = UDim2.new(0, 20, 1, -26), Size = UDim2.new(1, -40, 0, 5),
			BackgroundColor3 = Theme.Surface3, BorderSizePixel = 0, Parent = Boot,
		})
		corner(barBg, "full")
		local barFill = new("Frame", {
			Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = white, BorderSizePixel = 0, Parent = barBg,
		})
		corner(barFill, "full")
		accentGradient(barFill, 0)

		local lines = {
			"> init core .............. ok",
			"> mount interface ........ ok",
			"> sync modules ........... ok",
			"> welcome, " .. LocalPlayer.Name,
		}
		local shown = ""
		for i, line in ipairs(lines) do
			for ch = 1, #line, 2 do
				term.Text = shown .. string.sub(line, 1, ch)
				task.wait(0.012)
			end
			shown = shown .. line .. "\n"
			term.Text = shown
			tween(barFill, 0.25, { Size = UDim2.new(i / #lines, 0, 1, 0) })
			task.wait(0.08)
		end
		task.wait(0.3)
		tween(bootScale, 0.25, { Scale = 0.9 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(Boot, 0.25, { BackgroundTransparency = 1 })
		task.wait(0.22)
		Boot:Destroy()
	end

	task.spawn(function()
		if cfg.Intro ~= false then boot() end
		if Library.Destroyed then return end
		W.State = "open"
		showMain()
		if cfg.OnReady then fire(cfg.OnReady, W) end
	end)

	Library.Window = W
	return W
end

function Library:Destroy()
	Library.Destroyed = true
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	connections, themeHooks, statsHooks, spinning = {}, {}, {}, {}
	ScreenGui:Destroy()
end

------------------------------------------------------------------------
-- PHẦN 5 : TÍCH HỢP TOÀN BỘ LOGIC VÀO CÁC TAB PHÙ HỢP TRÊN THONHUD
------------------------------------------------------------------------
local Window = Library:CreateWindow({
	Title = "THONHUD",
	Subtitle = "CHAT SERVER V42",
	Intro = true,
	LogoImage = "https://cdn.phototourl.com/member/2026-11-10-eddddbc5-3528-4375-88df-8b53bd89ada4.png",
	OnReady = function()
		Library:Notify({
			Title = "THONHUD đã sẵn sàng",
			Content = "Giao diện THONHUD đã kích hoạt thành công!",
			Type = "success", Duration = 5,
		})
	end,
})

local AutoFarmEnabled = false
local AutoCollectEnabled = false
local MoneyFarmEnabled = false
local AutoClickTraitEnabled = false
local attackHeight = 4
local collectDelay = 0.12

local selectedMobName = nil
local selectedGemName = nil
local selectedPlayerName = nil
local currentMoneyTarget = nil
local currentSpecificTarget = nil
local myChatName = LocalPlayer.Name

-------------------------------------------------------------- TAB 1: NÂNG --
local TabNang = Window:CreateTab({ Name = "Nâng", Shape = "bars" })
TabNang:CreateSection("Tính năng tự động")

TabNang:CreateToggle({
	Name = "Auto Farm (Kén)",
	Description = "Tự động tấn công các Kén / Breakables trong khu vực",
	Default = false,
	Callback = function(v) AutoFarmEnabled = v end,
})

TabNang:CreateToggle({
	Name = "Auto Nhặt Hạt Thường",
	Description = "Tự động dịch chuyển nhặt hạt siêu tốc (Tối ưu chống lag)",
	Default = false,
	Callback = function(v) AutoCollectEnabled = v end,
})

TabNang:CreateToggle({
	Name = "Farm Tiền (Toàn Bộ Quái)",
	Description = "Tự động tìm và farm tất cả quái xung quanh",
	Default = false,
	Callback = function(v) MoneyFarmEnabled = v end,
})

TabNang:CreateToggle({
	Name = "Auto Click Chọn Chỉ Số",
	Description = "Tự động chọn các chỉ số buff mạnh khi quay thưởng",
	Default = false,
	Callback = function(v) AutoClickTraitEnabled = v end,
})

TabNang:CreateSection("Cài đặt tốc độ")
TabNang:CreateSlider({
	Name = "Tốc độ nhặt hạt / vòng lặp",
	Min = 0.01, Max = 1.0, Default = 0.12, Increment = 0.01, Suffix = "s",
	Callback = function(v) collectDelay = v end,
})

-------------------------------------------------------------- TAB 2: QUÁI --
local TabQuai = Window:CreateTab({ Name = "Quái", Shape = "circle" })
TabQuai:CreateSection("Quản lý quái")

local function RefreshMobList()
	Library:Notify({ Title = "Quái", Content = "Đang quét danh sách quái trong workspace...", Type = "info" })
	local foundNames = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj ~= LocalPlayer.Character then
			local humanoid = obj:FindFirstChildOfClass("Humanoid")
			local rootPart = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChild("Head")
			if humanoid and rootPart and not Players:GetPlayerFromCharacter(obj) then
				foundNames[obj.Name] = true
			end
		end
	end

	for mName, _ in pairs(foundNames) do
		TabQuai:CreateToggle({
			Name = "Farm Quái: " .. mName,
			Description = "Chỉ định đánh riêng loại quái này",
			Default = false,
			Callback = function(state)
				if state then
					selectedMobName = mName
					Library:Notify({ Title = "Đã chọn quái", Content = "Đang nhắm mục tiêu: " .. mName, Type = "success" })
				else
					if selectedMobName == mName then selectedMobName = nil end
				end
			end,
		})
	end
end

TabQuai:CreateButton({
	Name = "Làm Mới Danh Sách Quái",
	Callback = function()
		RefreshMobList()
	end,
})

-------------------------------------------------------------- TAB 3: HẠT --
local TabHat = Window:CreateTab({ Name = "Hạt", Shape = "ring" })
TabHat:CreateSection("Quản lý hạt / orb")

local function RefreshGemList()
	local foundGemNames = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj ~= LocalPlayer.Character and not Players:GetPlayerFromCharacter(obj) then
			if obj:IsA("BasePart") or obj:IsA("Model") then
				local name = obj.Name
				local lowerName = name:lower()
				local fullName = obj:GetFullName():lower()
				
				local isInvalid = fullName:find("shop") or fullName:find("buy") or fullName:find("gamepass") or 
								  fullName:find("ui") or fullName:find("safezone") or fullName:find("portal") or 
								  fullName:find("gate") or fullName:find("store") or fullName:find("menu") or obj:FindFirstChildOfClass("Humanoid")
				
				local isOrbOnly = lowerName == "orb" or lowerName == "voidorb" or lowerName:find("orb")
				
				if isOrbOnly and not isInvalid and not lowerName:find("terrain") and not lowerName:find("baseplate") then
					foundGemNames[name] = true
				end
			end
		end
	end

	for gName, _ in pairs(foundGemNames) do
		local displayName = gName
		if gName:lower() == "orb" then displayName = "Hạt thường" end
		if gName:lower() == "voidorb" then displayName = "Hạt Void" end

		TabHat:CreateToggle({
			Name = "Nhặt: " .. displayName,
			Description = "Tự động nhặt vật phẩm: " .. gName,
			Default = false,
			Callback = function(state)
				if state then
					selectedGemName = gName
					Library:Notify({ Title = "Đã chọn hạt", Content = "Đang nhặt loại: " .. displayName, Type = "success" })
				else
					if selectedGemName == gName then selectedGemName = nil end
				end
			end,
		})
	end
end

RefreshGemList()

-------------------------------------------------------------- TAB 4: SĂN --
local TabSan = Window:CreateTab({ Name = "Săn", Shape = "diamond" })
TabSan:CreateSection("Danh sách người chơi")

local function RefreshPlayerList()
	Library:Notify({ Title = "Săn", Content = "Đang quét người chơi trong server...", Type = "info" })
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			TabSan:CreateToggle({
				Name = "Săn người chơi: " .. plr.Name,
				Description = "Teleport và tự động tấn công người chơi này",
				Default = false,
				Callback = function(state)
					if state then
						selectedPlayerName = plr.Name
						Library:Notify({ Title = "Mục tiêu săn", Content = "Đang săn: " .. plr.Name, Type = "warning" })
					else
						if selectedPlayerName == plr.Name then selectedPlayerName = nil end
					end
				end,
			})
		end
	end
end

TabSan:CreateButton({
	Name = "Làm Mới Danh Sách Người Chơi",
	Callback = function()
		RefreshPlayerList()
	end,
})

-------------------------------------------------------------- TAB 5: FIX --
local TabFix = Window:CreateTab({ Name = "Fix Lag", Shape = "square" })
TabFix:CreateSection("Cài đặt hiệu năng")

TabFix:CreateToggle({
	Name = "Tăng FPS tối đa",
	Description = "Mở khóa giới hạn FPS của Roblox",
	Default = false,
	Callback = function(v)
		pcall(function()
			if setfpscap then setfpscap(v and 999 or 60) end
		end)
	end,
})

TabFix:CreateToggle({
	Name = "Xóa Hiệu Ứng Nặng",
	Description = "Tắt Particle, Trail, Fire, Shadows để mượt máy",
	Default = false,
	Callback = function(v)
		pcall(function()
			if v then
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
						obj.Enabled = false
					end
				end
				Lighting.GlobalShadows = false
			else
				Lighting.GlobalShadows = true
			end
		end)
	end,
})

TabFix:CreateToggle({
	Name = "Tối Ưu Đồ Họa (SmoothPlastic)",
	Description = "Chuyển vật liệu sang nhựa mịn giảm tải GPU",
	Default = false,
	Callback = function(v)
		pcall(function()
			for _, part in ipairs(workspace:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Material = v and Enum.Material.SmoothPlastic or Enum.Material.Plastic
				end
			end
		end)
	end,
})

-------------------------------------------------------------- TAB 6: CHAT --
local TabChat = Window:CreateTab({ Name = "Chat Server", Shape = "grid" })
TabChat:CreateSection("Phòng Chat Chung Toàn Server")

local channelName = "SpiderHub_GlobalServerChat"

TabChat:CreateButton({
	Name = "Kết nối & Nhận tin nhắn toàn cầu",
	Callback = function()
		pcall(function()
			MessagingService:SubscribeAsync(channelName, function(message)
				local data = message.Data
				if data and data.sender and data.text then
					Library:Log("[" .. data.sender .. "]: " .. data.text)
					Library:Notify({ Title = "Chat từ " .. data.sender, Content = data.text, Type = "info" })
				end
			end)
			Library:Notify({ Title = "Thành công", Content = "Đã kết nối kênh chat server chung!", Type = "success" })
		end)
	end,
})

TabChat:CreateToggle({
	Name = "Mô phỏng tin nhắn test",
	Description = "Gửi thông báo thử nghiệm hệ thống",
	Default = false,
	Callback = function(on)
		if on then
			Library:Log("[" .. myChatName .. "]: Đã bật tính năng chat server.")
			pcall(function()
				MessagingService:PublishAsync(channelName, {sender = myChatName, text = "Xin chào mọi người từ THONHUD!"})
			end)
		end
	end,
})

------------------------------------------------------------------------
-- VÒNG LẶP XỬ LÝ TỰ ĐỘNG (BACKEND LOOP)
------------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(collectDelay)
		
		if selectedPlayerName then
			pcall(function()
				local targetPlayer = Players:FindFirstChild(selectedPlayerName)
				if targetPlayer and targetPlayer.Character then
					local tRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
					local tHumanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
					local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
					
					if tRoot and tHumanoid and tHumanoid.Health > 0 and myRoot then
						myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 10)
						local attackRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Attack")
						if attackRemote then
							for i = 1, 4 do attackRemote:FireServer(targetPlayer.Character) end
						end
					end
				end
			end)
		end
		
		if selectedGemName then
			pcall(function()
				local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if myRoot then
					for _, obj in ipairs(workspace:GetDescendants()) do
						if (obj.Name == selectedGemName) and (obj:IsA("BasePart") or obj:IsA("Model")) then
							local targetPart = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
							if targetPart then
								myRoot.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 2, 0))
								break
							end
						end
					end
				end
			end)
		end
		
		if AutoClickTraitEnabled then
			pcall(function()
				for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
					if gui:IsA("ScreenGui") and gui.Enabled then
						for _, desc in ipairs(gui:GetDescendants()) do
							if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Visible then
								local t = desc.Text:upper()
								local isBad = t:find("TRỪ") or t:find("GIẢM") or t:find("DOWN") or t:find("-")
								local isGood = t:find("OFFENSIVE") or t:find("RĂNG NANH") or t:find("DAMAGE") or t:find("SPEED") or t:find("HEALTH") or t:find("TĂNG") or t:find("+")
								
								if isGood and not isBad then
									local p = desc.Parent
									while p and p ~= gui do
										for _, btn in ipairs(p:GetDescendants()) do
											if btn:IsA("TextButton") and (btn.Text:upper():find("CHỌN") or btn.Text:upper():find("SELECT")) then
												if getconnections then
													for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do
														conn:Fire()
													end
												end
											end
										end
										p = p.Parent
									end
								end
							end
						end
					end
				end
			end)
		end
		
		if AutoFarmEnabled then
			pcall(function()
				local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				local breakables = workspace:FindFirstChild("Breakables")
				if myRoot and breakables then
					for _, target in ipairs(breakables:GetChildren()) do
						local targetPart = target:IsA("Model") and (target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")) or (target:IsA("BasePart") and target)
						if targetPart then
							myRoot.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, attackHeight, 0))
							local attackRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Attack")
							if attackRemote then
								for i = 1, 4 do attackRemote:FireServer(target) end
							end
							break
						end
					end
				end
			end)
		end
		
		if MoneyFarmEnabled and not selectedMobName then
			pcall(function()
				local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if myRoot then
					local isValidTarget = false
					if currentMoneyTarget and currentMoneyTarget.Parent then
						local humanoid = currentMoneyTarget:FindFirstChildOfClass("Humanoid")
						local rootPart = currentMoneyTarget:FindFirstChild("HumanoidRootPart") or currentMoneyTarget.PrimaryPart or currentMoneyTarget:FindFirstChild("Head")
						if humanoid and humanoid.Health > 0 and rootPart then
							isValidTarget = true
							myRoot.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, attackHeight, 0))
							local attackRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Attack")
							if attackRemote then
								for i = 1, 4 do attackRemote:FireServer(currentMoneyTarget) end
							end
						else
							if rootPart then myRoot.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, 2, 0)) end
							task.wait(0.3)
							currentMoneyTarget = nil
						end
					end
					if not isValidTarget then
						currentMoneyTarget = nil
						for _, obj in ipairs(workspace:GetDescendants()) do
							if obj:IsA("Model") and obj ~= LocalPlayer.Character then
								local humanoid = obj:FindFirstChildOfClass("Humanoid")
								local rootPart = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChild("Head")
								if humanoid and humanoid.Health > 0 and rootPart and not Players:GetPlayerFromCharacter(obj) then
									currentMoneyTarget = obj
									break
								end
							end
						end
					end
				end
			end)
		else
			currentMoneyTarget = nil
		end

		if selectedMobName then
			pcall(function()
				local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if myRoot then
					local isValidTarget = false
					if currentSpecificTarget and currentSpecificTarget.Parent and currentSpecificTarget.Name == selectedMobName then
						local humanoid = currentSpecificTarget:FindFirstChildOfClass("Humanoid")
						local rootPart = currentSpecificTarget:FindFirstChild("HumanoidRootPart") or currentSpecificTarget.PrimaryPart or currentSpecificTarget:FindFirstChild("Head")
						if humanoid and humanoid.Health > 0 and rootPart then
							isValidTarget = true
							myRoot.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, attackHeight, 0))
							local attackRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Attack")
							if attackRemote then
								for i = 1, 4 do attackRemote:FireServer(currentSpecificTarget) end
							end
						else
							if rootPart then myRoot.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, 2, 0)) end
							task.wait(0.3)
							currentSpecificTarget = nil
						end
					end
					if not isValidTarget then
						currentSpecificTarget = nil
						for _, obj in ipairs(workspace:GetDescendants()) do
							if obj:IsA("Model") and obj.Name == selectedMobName and obj ~= LocalPlayer.Character then
								local humanoid = obj:FindFirstChildOfClass("Humanoid")
								local rootPart = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChild("Head")
								if humanoid and humanoid.Health > 0 and rootPart then
									currentSpecificTarget = obj
									break
								end
							end
						end
					end
				end
			end)
		else
			currentSpecificTarget = nil
		end
		
		if AutoCollectEnabled then
			pcall(function()
				local v551 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if v551 then
					if not _G._seedCacheTick or tick() - _G._seedCacheTick > 2 then
						_G._seedCacheTick = tick()
						_G._seedCacheList = {}
						for _, v637 in ipairs(workspace:GetDescendants()) do
							if v637:IsA("BasePart") then
								local v659 = v637:GetFullName():lower()
								local v660 = v637.Name:lower()
								local v661 = v659:find("shop") or v659:find("gamepass") or v659:find("ui") or (v637.Size.Magnitude > 6)
								local v662 = (v660 == "orb") or (v660 == "voidorb") or v660:find("orb")
								if (not v661 and v662) then
									table.insert(_G._seedCacheList, v637)
								end
							end
						end
					end
					for _, v637 in ipairs(_G._seedCacheList or {}) do 
						if v637 and v637.Parent then 
							v551.CFrame = v637.CFrame
							break
						end 
					end 
				end
			end)
		end
	end
end)
