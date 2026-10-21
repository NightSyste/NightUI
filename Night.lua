local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")

local LOGO_URL = "https://i.ibb.co/dqhXvHX/7pj9jqd-removebg-preview.png"
local function resolveLogoAsset()
	local asset = LOGO_URL
	pcall(function()
		if getcustomasset and writefile and (game.HttpGet or http_request or request) then
			local fn = "ns_logo.png"
			if not (isfile and isfile(fn)) then
				local getter = game.HttpGet or function(self, u) return (http_request or request)({ Url = u, Method = "GET" }).Body end
				local res = getter(game, LOGO_URL)
				if res and #res > 0 then
					writefile(fn, res)
				end
			end
			if isfile and isfile(fn) then
				asset = getcustomasset(fn)
			end
		end
	end)
	return asset
end
local LOGO_ASSET = resolveLogoAsset()

local FlagsProxy = setmetatable({}, {
	__index = function(t, k)
		local dummy = {
			Value = false,
			Type = "Dummy",
			Set = function(self, val) self.Value = val end,
			SetValue = function(self, val) self.Value = val end,
			OnChanged = function() end,
		}
		rawset(t, k, dummy)
		return dummy
	end
})

local Library = {
	Flags = FlagsProxy,
	Options = FlagsProxy,
	Toggles = FlagsProxy,
	Windows = {},
	Notifications = {},
	ConfigStore = {},
	ConfigFileName = "NightSystem_Config.json",
	AutoSave = true,
	ToggleKey = Enum.KeyCode.LeftControl,
	Theme = {
		Accent       = Color3.fromRGB(85, 115, 250),
		AccentGlow   = Color3.fromRGB(115, 145, 255),
		MainBg       = Color3.fromRGB(22, 24, 30),
		SidebarBg    = Color3.fromRGB(18, 20, 26),
		CardBg       = Color3.fromRGB(26, 28, 36),
		RowBg        = Color3.fromRGB(30, 34, 46),
		RowHover     = Color3.fromRGB(38, 44, 60),
		Border       = Color3.fromRGB(48, 52, 70),
		BorderLight  = Color3.fromRGB(70, 78, 105),
		TextWhite    = Color3.fromRGB(255, 255, 255),
		TextBright   = Color3.fromRGB(240, 245, 255),
		TextMuted    = Color3.fromRGB(155, 165, 185),
		CheckFill    = Color3.fromRGB(85, 115, 250),
		SliderFill   = Color3.fromRGB(64, 66, 75),
		CloseRed     = Color3.fromRGB(245, 65, 85),
		CloseBorder  = Color3.fromRGB(255, 120, 140),
		KeybindBg    = Color3.fromRGB(44, 52, 75),
		KeybindText  = Color3.fromRGB(245, 250, 255),
		KeybindStroke= Color3.fromRGB(85, 120, 245),
		Transparency = 0.04,
		NeonBorder   = Color3.fromRGB(85, 115, 250),
		CardBorder   = Color3.fromRGB(48, 52, 70),
		SubBorder    = Color3.fromRGB(42, 46, 60),
		GlassBg      = Color3.fromRGB(22, 24, 30),
		ControlBg    = Color3.fromRGB(30, 34, 46),
	}
}
Library.__index = Library

local function getGuiParent()
	local okHui, hui = pcall(function()
		if gethui then
			local h = gethui()
			if h then
				local _ = h:FindFirstChild("_")
				return h
			end
		end
		return nil
	end)
	if okHui and hui then return hui end

	local okCore, core = pcall(function()
		local c = game:GetService("CoreGui")
		local _ = c:FindFirstChild("RobloxGui")
		return c
	end)
	if okCore and core then return core end

	return LocalPlayer:WaitForChild("PlayerGui")
end

local function mountScreenGui(screenGui, guiName)
	local parent = getGuiParent()
	local ok = pcall(function()
		local existing = parent:FindFirstChild(guiName)
		if existing then
			existing:Destroy()
		end
		screenGui.Parent = parent
	end)
	if not ok or not screenGui.Parent then
		local pg = LocalPlayer:WaitForChild("PlayerGui")
		pcall(function()
			local existing = pg:FindFirstChild(guiName)
			if existing then
				existing:Destroy()
			end
		end)
		screenGui.Parent = pg
	end
end

local function tween(obj, info, props)
	local t = TweenService:Create(obj, info or TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Library.Theme.CardBorder
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0.25
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function addPadding(parent, top, bottom, left, right)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, top or 0)
	pad.PaddingBottom = UDim.new(0, bottom or 0)
	pad.PaddingLeft = UDim.new(0, left or 0)
	pad.PaddingRight = UDim.new(0, right or 0)
	pad.Parent = parent
	return pad
end

local function addSizeConstraint(parent, minSize, maxSize)
	local sc = Instance.new("UISizeConstraint")
	if minSize then sc.MinSize = minSize end
	if maxSize then sc.MaxSize = maxSize end
	sc.Parent = parent
	return sc
end

local function styleBrightButtonText(textObj, fontSize)
	textObj.TextColor3 = Color3.fromRGB(245, 250, 255)
	textObj.Font = Enum.Font.GothamBold
	textObj.TextSize = fontSize or 13
	textObj.TextStrokeTransparency = 1
end

local function applyMetallicHeader(frame)
	frame.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
	frame.BackgroundTransparency = 0.20
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(36, 42, 58)),
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(24, 27, 36)),
	})
	grad.Rotation = 90
	grad.Parent = frame
	return grad
end

local function applyButtonGradient(frame, isHovered)
	frame.BackgroundColor3 = isHovered and Color3.fromRGB(46, 54, 76) or Color3.fromRGB(34, 38, 52)
	frame.BackgroundTransparency = 0

	local grad = frame:FindFirstChildOfClass("UIGradient")
	if not grad then
		grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Parent = frame
	end

	if isHovered then
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(52, 60, 84)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(38, 44, 62)),
		})
	else
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(38, 42, 58)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 32, 44)),
		})
	end

	if not frame:FindFirstChild("TopShine") then
		local shine = Instance.new("Frame")
		shine.Name = "TopShine"
		shine.Size = UDim2.new(1, -8, 0, 1)
		shine.Position = UDim2.new(0, 4, 0, 1)
		shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		shine.BackgroundTransparency = 0.85
		shine.BorderSizePixel = 0
		shine.ZIndex = frame.ZIndex + 1
		shine.Parent = frame
	end

	return grad
end

local function attachButtonFX(btn, stroke)
	local btnScale = btn:FindFirstChildOfClass("UIScale")
	if not btnScale then
		btnScale = Instance.new("UIScale")
		btnScale.Scale = 1
		btnScale.Parent = btn
	end

	btn.MouseEnter:Connect(function()
		applyButtonGradient(btn, true)
		if stroke then
			tween(stroke, TweenInfo.new(0.14), {
				Transparency = 0.0,
				Color = Library.Theme.NeonBorder
			})
		end
		tween(btnScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.015 })
	end)

	btn.MouseLeave:Connect(function()
		applyButtonGradient(btn, false)
		if stroke then
			tween(stroke, TweenInfo.new(0.16), {
				Transparency = 0.16,
				Color = Library.Theme.NeonBorder
			})
		end
		tween(btnScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 })
	end)

	btn.MouseButton1Down:Connect(function()
		tween(btnScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.965 })
	end)

	btn.MouseButton1Up:Connect(function()
		tween(btnScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.015 })
	end)
end

local function attachTouchScrollBarAndArrows(parentFrame, scrollFrame, layoutObj, railPosition, railSize, stepPixels)
	stepPixels = stepPixels or 95

	local Rail = Instance.new("Frame")
	Rail.Name = "MobileScrollRail"
	Rail.Position = railPosition
	Rail.Size = railSize
	Rail.BackgroundTransparency = 1
	Rail.ZIndex = 6
	Rail.Parent = parentFrame

	local btnHeight = 15

	local UpBtn = Instance.new("TextButton")
	UpBtn.Name = "ScrollUpBtn"
	UpBtn.Size = UDim2.new(1, 0, 0, btnHeight)
	UpBtn.Position = UDim2.new(0, 0, 0, 0)
	UpBtn.Text = "▲"
	UpBtn.AutoButtonColor = false
	UpBtn.ZIndex = 7
	UpBtn.Parent = Rail
	styleBrightButtonText(UpBtn, 9)
	addCorner(UpBtn, 4)
	local upStroke = addStroke(UpBtn, Library.Theme.NeonBorder, 1.0, 0.18)
	applyButtonGradient(UpBtn, false)
	attachButtonFX(UpBtn, upStroke)

	local DownBtn = Instance.new("TextButton")
	DownBtn.Name = "ScrollDownBtn"
	DownBtn.Size = UDim2.new(1, 0, 0, btnHeight)
	DownBtn.Position = UDim2.new(0, 0, 1, -btnHeight)
	DownBtn.Text = "▼"
	DownBtn.AutoButtonColor = false
	DownBtn.ZIndex = 7
	DownBtn.Parent = Rail
	styleBrightButtonText(DownBtn, 9)
	addCorner(DownBtn, 4)
	local downStroke = addStroke(DownBtn, Library.Theme.NeonBorder, 1.0, 0.18)
	applyButtonGradient(DownBtn, false)
	attachButtonFX(DownBtn, downStroke)

	local TrackBtn = Instance.new("TextButton")
	TrackBtn.Name = "ThickScrollTrack"
	TrackBtn.Size = UDim2.new(0, 4, 1, -(btnHeight * 2 + 6))
	TrackBtn.Position = UDim2.new(0.5, -2, 0, btnHeight + 3)
	TrackBtn.BackgroundColor3 = Color3.fromRGB(20, 30, 42)
	TrackBtn.BackgroundTransparency = 0.52
	TrackBtn.BorderSizePixel = 0
	TrackBtn.Text = ""
	TrackBtn.AutoButtonColor = false
	TrackBtn.ZIndex = 7
	TrackBtn.Parent = Rail
	addCorner(TrackBtn, 2)
	addStroke(TrackBtn, Library.Theme.SubBorder, 1, 0.35)

	local Thumb = Instance.new("Frame")
	Thumb.Name = "ThickThumb"
	Thumb.Size = UDim2.new(1, 0, 0.35, 0)
	Thumb.Position = UDim2.new(0, 0, 0, 0)
	Thumb.BackgroundColor3 = Library.Theme.NeonBorder
	Thumb.BackgroundTransparency = 0.14
	Thumb.BorderSizePixel = 0
	Thumb.ZIndex = 8
	Thumb.Parent = TrackBtn
	addCorner(Thumb, 2)
	addStroke(Thumb, Color3.fromRGB(240, 252, 255), 1, 0.2)

	local function getMaxScroll()
		local canvasH = scrollFrame.CanvasSize.Y.Offset
		local viewH = scrollFrame.AbsoluteWindowSize.Y
		return math.max(0, canvasH - viewH)
	end

	local function updateThumbFromScroll()
		local canvasH = scrollFrame.CanvasSize.Y.Offset
		local viewH = scrollFrame.AbsoluteWindowSize.Y
		local maxScroll = math.max(0, canvasH - viewH)
		if maxScroll <= 2 then
			Thumb.Size = UDim2.new(1, 0, 1, 0)
			Thumb.Position = UDim2.new(0, 0, 0, 0)
		else
			local ratio = math.clamp(viewH / math.max(1, canvasH), 0.16, 0.92)
			local scrollPct = math.clamp(scrollFrame.CanvasPosition.Y / maxScroll, 0, 1)
			Thumb.Size = UDim2.new(1, 0, ratio, 0)
			Thumb.Position = UDim2.new(0, 0, scrollPct * (1 - ratio), 0)
		end
	end

	scrollFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(updateThumbFromScroll)
	scrollFrame:GetPropertyChangedSignal("CanvasSize"):Connect(updateThumbFromScroll)
	scrollFrame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateThumbFromScroll)
	task.defer(updateThumbFromScroll)

	local function scrollByDelta(deltaY)
		local maxS = getMaxScroll()
		local targetY = math.clamp(scrollFrame.CanvasPosition.Y + deltaY, 0, maxS)
		tween(scrollFrame, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CanvasPosition = Vector2.new(0, targetY)
		})
	end

	local holdingUp = false
	local holdingDown = false

	UpBtn.MouseButton1Down:Connect(function()
		holdingUp = true
		scrollByDelta(-stepPixels)
		task.spawn(function()
			task.wait(0.26)
			while holdingUp do
				scrollByDelta(-math.floor(stepPixels * 0.55))
				task.wait(0.06)
			end
		end)
	end)
	UpBtn.MouseButton1Up:Connect(function() holdingUp = false end)
	UpBtn.MouseLeave:Connect(function() holdingUp = false end)

	DownBtn.MouseButton1Down:Connect(function()
		holdingDown = true
		scrollByDelta(stepPixels)
		task.spawn(function()
			task.wait(0.26)
			while holdingDown do
				scrollByDelta(math.floor(stepPixels * 0.55))
				task.wait(0.06)
			end
		end)
	end)
	DownBtn.MouseButton1Up:Connect(function() holdingDown = false end)
	DownBtn.MouseLeave:Connect(function() holdingDown = false end)

	local draggingTrack = false
	local function setScrollFromInput(input)
		local trackTop = TrackBtn.AbsolutePosition.Y
		local trackH = math.max(1, TrackBtn.AbsoluteSize.Y)
		local pct = math.clamp((input.Position.Y - trackTop) / trackH, 0, 1)
		local maxS = getMaxScroll()
		scrollFrame.CanvasPosition = Vector2.new(0, math.floor(maxS * pct))
	end

	TrackBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingTrack = true
			setScrollFromInput(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingTrack = false
			holdingUp = false
			holdingDown = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if draggingTrack and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setScrollFromInput(input)
		end
	end)

	return Rail
end

local function resolveKeyItem(val)
	if typeof(val) == "EnumItem" then
		return val
	elseif type(val) == "string" and val ~= "" then
		if Enum.KeyCode[val] then
			return Enum.KeyCode[val]
		elseif Enum.UserInputType[val] then
			return Enum.UserInputType[val]
		end
	end
	return nil
end

local function formatKeyName(keyItem)
	if not keyItem then return "None" end
	local name = keyItem.Name or tostring(keyItem)
	local shortNames = {
		RightShift = "RShift",
		LeftShift = "LShift",
		RightControl = "RCtrl",
		LeftControl = "LCtrl",
		RightAlt = "RAlt",
		LeftAlt = "LAlt",
		MouseButton1 = "MB1",
		MouseButton2 = "MB2",
		MouseButton3 = "MB3",
		Backspace = "Back",
		CapsLock = "Caps",
	}
	return shortNames[name] or name
end

local function normalizeArgs(kind, a, b, c, d, e)
	if type(a) == "table" then
		return a
	end
	local cfg = { Name = tostring(a or kind) }
	if kind == "Toggle" then
		if type(b) == "boolean" then
			cfg.Default = b
			cfg.Callback = type(c) == "function" and c or nil
		elseif type(b) == "function" then
			cfg.Callback = b
		else
			cfg.Callback = type(c) == "function" and c or (type(d) == "function" and d or nil)
			if type(c) == "boolean" then cfg.Default = c end
		end
	elseif kind == "Button" then
		if type(b) == "function" then
			cfg.Callback = b
		elseif type(c) == "function" then
			cfg.Callback = c
		end
	elseif kind == "Slider" then
		if type(b) == "string" and type(c) == "number" and type(d) == "number" then
			cfg.Min = math.min(c, d)
			cfg.Max = math.max(c, d)
			cfg.Default = cfg.Min
			cfg.Callback = type(e) == "function" and e or nil
		elseif type(b) == "number" and type(c) == "number" then
			cfg.Min = math.min(b, c)
			cfg.Max = math.max(b, c)
			cfg.Default = type(d) == "number" and d or cfg.Min
			cfg.Callback = type(e) == "function" and e or (type(d) == "function" and d or nil)
		end
	elseif kind == "Dropdown" then
		if type(b) == "table" then
			cfg.Options = b
			if type(c) == "function" then
				cfg.Callback = c
			else
				cfg.Default = c
				cfg.Callback = type(d) == "function" and d or nil
			end
		elseif type(c) == "table" then
			cfg.Options = c
			cfg.Callback = type(d) == "function" and d or nil
		end
	elseif kind == "Colorpicker" then
		if typeof(b) == "Color3" then
			cfg.Default = b
			cfg.Callback = type(c) == "function" and c or nil
		elseif typeof(c) == "Color3" then
			cfg.Default = c
			cfg.Callback = type(d) == "function" and d or nil
		end
	elseif kind == "Bind" then
		if (typeof(b) == "EnumItem" or type(b) == "string") and type(c) == "function" then
			cfg.Default = b
			cfg.Callback = c
		elseif typeof(c) == "EnumItem" or type(c) == "string" then
			cfg.Default = c
			cfg.Callback = type(d) == "function" and d or nil
		elseif type(b) == "function" then
			cfg.Callback = b
		end
	elseif kind == "Textbox" then
		if type(b) == "function" then
			cfg.Callback = b
		elseif type(c) == "function" then
			cfg.Default = tostring(b or "")
			cfg.Callback = c
		elseif type(d) == "function" then
			cfg.Callback = d
		end
	end
	return cfg
end

local function registerFlag(flag, name, obj)
	if flag and flag ~= "" then
		rawset(Library.Flags, flag, obj)
	end
	if name and name ~= "" and rawget(Library.Flags, name) == nil then
		rawset(Library.Flags, name, obj)
	end
end

local NotifScreenGui = nil

function Library.MakeNotification(selfOrCfg, maybeCfg)
	local config = (selfOrCfg == Library) and maybeCfg or selfOrCfg
	config = type(config) == "table" and config or { Name = "Notification", Content = tostring(config or "") }
	local titleText = config.Name or config.Title or "NightSystem"
	local bodyText  = config.Content or config.Text or config.Description or ""
	local duration  = config.Time or config.Duration or 4

	if not NotifScreenGui or not NotifScreenGui.Parent then
		NotifScreenGui = Instance.new("ScreenGui")
		NotifScreenGui.Name = "NightSystemNotifications"
		NotifScreenGui.ResetOnSpawn = false
		NotifScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		mountScreenGui(NotifScreenGui, "NightSystemNotifications")

		local holder = Instance.new("Frame")
		holder.Name = "Holder"
		holder.Size = UDim2.new(0, 290, 1, -24)
		holder.Position = UDim2.new(1, -304, 0, 12)
		holder.BackgroundTransparency = 1
		holder.Parent = NotifScreenGui

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		layout.Padding = UDim.new(0, 8)
		layout.Parent = holder
	end

	local holder = NotifScreenGui:FindFirstChild("Holder")
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 68)
	card.BackgroundColor3 = Library.Theme.CardBg
	card.BackgroundTransparency = 0.18
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Parent = holder
	addCorner(card, 7)
	addStroke(card, Library.Theme.NeonBorder, 1.3, 0.15)

	local cardScale = Instance.new("UIScale")
	cardScale.Scale = 0.85
	cardScale.Parent = card
	tween(cardScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.0 })

	local hdr = Instance.new("Frame")
	hdr.Size = UDim2.new(1, 0, 0, 24)
	hdr.BorderSizePixel = 0
	hdr.Parent = card
	addCorner(hdr, 7)
	applyMetallicHeader(hdr)

	local tLbl = Instance.new("TextLabel")
	tLbl.Size = UDim2.new(1, -16, 1, 0)
	tLbl.Position = UDim2.new(0, 10, 0, 0)
	tLbl.BackgroundTransparency = 1
	tLbl.Text = tostring(titleText)
	styleBrightButtonText(tLbl, 13)
	tLbl.TextXAlignment = Enum.TextXAlignment.Left
	tLbl.Parent = hdr

	local cLbl = Instance.new("TextLabel")
	cLbl.Size = UDim2.new(1, -20, 1, -30)
	cLbl.Position = UDim2.new(0, 10, 0, 26)
	cLbl.BackgroundTransparency = 1
	cLbl.Text = tostring(bodyText)
	cLbl.TextColor3 = Library.Theme.TextMuted
	cLbl.Font = Enum.Font.Gotham
	cLbl.TextSize = 12
	cLbl.TextWrapped = true
	cLbl.TextXAlignment = Enum.TextXAlignment.Left
	cLbl.TextYAlignment = Enum.TextYAlignment.Top
	cLbl.Parent = card

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 2)
	bar.Position = UDim2.new(0, 0, 1, -2)
	bar.BackgroundColor3 = Library.Theme.NeonBorder
	bar.BorderSizePixel = 0
	bar.Parent = card

	tween(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })
	task.delay(duration, function()
		if card and card.Parent then
			tween(cardScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.05 })
			tween(card, TweenInfo.new(0.22), { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) })
			task.wait(0.23)
			if card then card:Destroy() end
		end
	end)
end
Library.Notify           = Library.MakeNotification
Library.Notification     = Library.MakeNotification
Library.SendNotification = Library.MakeNotification

function Library:SetToggleKey(newKey)
	local resolved = resolveKeyItem(newKey)
	if resolved then
		self.ToggleKey = resolved
		for _, win in ipairs(self.Windows) do
			if win.SetToggleKey then
				win:SetToggleKey(resolved)
			end
		end
	end
end

local function serializeValue(v)
	if typeof(v) == "Color3" then
		return { __type = "Color3", r = v.R, g = v.G, b = v.B }
	elseif typeof(v) == "EnumItem" then
		return { __type = "EnumItem", enum = tostring(v.EnumType), name = v.Name }
	else
		return v
	end
end

local function deserializeValue(v)
	if type(v) == "table" and v.__type == "Color3" then
		return Color3.new(v.r, v.g, v.b)
	elseif type(v) == "table" and v.__type == "EnumItem" then
		local et = Enum[v.enum]
		if et and et[v.name] then
			return et[v.name]
		end
		return nil
	else
		return v
	end
end

local isAutoSaving = false
local function scheduleAutoSave()
	if not Library.AutoSave then return end
	if isAutoSaving then return end
	isAutoSaving = true
	task.delay(0.25, function()
		isAutoSaving = false
		pcall(function()
			if writefile then
				local json = HttpService:JSONEncode(Library.ConfigStore)
				writefile(Library.ConfigFileName, json)
			end
		end)
	end)
end

function Library:Init()
	return self
end

function Library:LoadConfiguration(fileName)
	local target = fileName or self.ConfigFileName
	pcall(function()
		if isfile and readfile and isfile(target) then
			local raw = readfile(target)
			local decoded = HttpService:JSONDecode(raw)
			if type(decoded) == "table" then
				for k, v in pairs(decoded) do
					self.ConfigStore[k] = deserializeValue(v)
				end
				if self.ConfigStore["_NS_AutoSave"] ~= nil then
					self.AutoSave = not not self.ConfigStore["_NS_AutoSave"]
				end
			end
		end
	end)
	return self
end
Library.LoadConfig = Library.LoadConfiguration

function Library:SaveConfiguration(fileName)
	local target = fileName or self.ConfigFileName
	pcall(function()
		if writefile then
			local json = HttpService:JSONEncode(self.ConfigStore)
			writefile(target, json)
		end
	end)
	return self
end
Library.SaveConfig = Library.SaveConfiguration

function Library:DeleteConfiguration(fileName)
	local target = fileName or self.ConfigFileName
	self.ConfigStore = {}
	pcall(function()
		if delfile and isfile and isfile(target) then
			delfile(target)
		elseif writefile then
			writefile(target, "{}")
		end
	end)
	return self
end
Library.DeleteConfig = Library.DeleteConfiguration
Library.ResetConfig  = Library.DeleteConfiguration

Library:LoadConfiguration()

function Library:Destroy()
	pcall(function() RunService:UnbindFromRenderStep("NightSystem_Aimbot") end)
	for _, win in ipairs(self.Windows) do
		if win.ScreenGui and win.ScreenGui.Parent then
			win.ScreenGui:Destroy()
		end
	end
	if NotifScreenGui and NotifScreenGui.Parent then
		NotifScreenGui:Destroy()
	end
end
Library.Unload = Library.Destroy

local BASE_WIDTH  = 860
local BASE_HEIGHT = 500

local function playPrettyLoader(screenGui, titleText, onFinished)
	local LoaderCard = Instance.new("Frame")
	LoaderCard.Name = "NightSystemLoader"
	LoaderCard.AnchorPoint = Vector2.new(0.5, 0.5)
	LoaderCard.Size = UDim2.new(0, 340, 0, 148)
	LoaderCard.Position = UDim2.new(0.5, 0, 0.5, 0)
	LoaderCard.BackgroundColor3 = Color3.fromRGB(18, 26, 36)
	LoaderCard.BackgroundTransparency = 0.28
	LoaderCard.BorderSizePixel = 0
	LoaderCard.ZIndex = 50
	LoaderCard.Parent = screenGui
	addCorner(LoaderCard, 10)
	local loaderStroke = addStroke(LoaderCard, Library.Theme.NeonBorder, 1.5, 0.08)

	local loaderScale = Instance.new("UIScale")
	loaderScale.Scale = 0.05
	loaderScale.Parent = LoaderCard

	local lGrad = Instance.new("UIGradient")
	lGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(24, 34, 46)),
		ColorSequenceKeypoint.new(0.53, Color3.fromRGB(36, 48, 62)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(118, 145, 172)),
		ColorSequenceKeypoint.new(0.74, Color3.fromRGB(46, 62, 80)),
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(18, 25, 34)),
	})
	lGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.32),
		NumberSequenceKeypoint.new(0.53, 0.28),
		NumberSequenceKeypoint.new(0.55, 0.10),
		NumberSequenceKeypoint.new(0.76, 0.24),
		NumberSequenceKeypoint.new(1.00, 0.36),
	})
	lGrad.Rotation = 68
	lGrad.Parent = LoaderCard

	local lGlow = Instance.new("Frame")
	lGlow.Size = UDim2.new(1, 8, 1, 8)
	lGlow.Position = UDim2.new(0, -4, 0, -4)
	lGlow.BackgroundTransparency = 1
	lGlow.ZIndex = 49
	lGlow.Parent = LoaderCard
	addCorner(lGlow, 13)
	addStroke(lGlow, Library.Theme.NeonBorder, 2.0, 0.65)

	for i = 1, 3 do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 9, 0, 9)
		dot.Position = UDim2.new(0, 14 + (i - 1) * 15, 0, 12)
		dot.BackgroundColor3 = Color3.fromRGB(24, 34, 46)
		dot.BackgroundTransparency = 0.72
		dot.ZIndex = 52
		dot.Parent = LoaderCard
		addCorner(dot, 5)
		addStroke(dot, Library.Theme.NeonBorder, 1, 0.25)
	end

	local SpinnerOuter = Instance.new("Frame")
	SpinnerOuter.Size = UDim2.new(0, 42, 0, 42)
	SpinnerOuter.Position = UDim2.new(0, 22, 0, 44)
	SpinnerOuter.BackgroundColor3 = Color3.fromRGB(24, 34, 46)
	SpinnerOuter.BackgroundTransparency = 0.35
	SpinnerOuter.ZIndex = 52
	SpinnerOuter.Parent = LoaderCard
	addCorner(SpinnerOuter, 21)
	local spinStroke = addStroke(SpinnerOuter, Library.Theme.NeonBorder, 2.0, 0.08)

	local spinGrad = Instance.new("UIGradient")
	spinGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.0),
		NumberSequenceKeypoint.new(0.65, 0.25),
		NumberSequenceKeypoint.new(1.00, 0.85),
	})
	spinGrad.Parent = spinStroke

	local SpinnerLogo = Instance.new("ImageLabel")
	SpinnerLogo.Size = UDim2.new(0, 26, 0, 26)
	SpinnerLogo.Position = UDim2.new(0.5, -13, 0.5, -13)
	SpinnerLogo.BackgroundTransparency = 1
	SpinnerLogo.Image = LOGO_ASSET
	SpinnerLogo.ScaleType = Enum.ScaleType.Fit
	SpinnerLogo.ZIndex = 53
	SpinnerLogo.Parent = SpinnerOuter

	local TitleLbl = Instance.new("TextLabel")
	TitleLbl.Size = UDim2.new(1, -88, 0, 24)
	TitleLbl.Position = UDim2.new(0, 76, 0, 42)
	TitleLbl.BackgroundTransparency = 1
	TitleLbl.Text = tostring(titleText)
	styleBrightButtonText(TitleLbl, 17)
	TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
	TitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
	TitleLbl.ZIndex = 52
	TitleLbl.Parent = LoaderCard

	local SubLbl = Instance.new("TextLabel")
	SubLbl.Size = UDim2.new(1, -88, 0, 18)
	SubLbl.Position = UDim2.new(0, 76, 0, 66)
	SubLbl.BackgroundTransparency = 1
	SubLbl.Text = "Initializing UI..."
	SubLbl.TextColor3 = Library.Theme.TextMuted
	SubLbl.Font = Enum.Font.GothamMedium
	SubLbl.TextSize = 12
	SubLbl.TextXAlignment = Enum.TextXAlignment.Left
	SubLbl.ZIndex = 52
	SubLbl.Parent = LoaderCard

	local PctLbl = Instance.new("TextLabel")
	PctLbl.Size = UDim2.new(0, 54, 0, 18)
	PctLbl.Position = UDim2.new(1, -68, 0, 96)
	PctLbl.BackgroundTransparency = 1
	PctLbl.Text = "0%"
	styleBrightButtonText(PctLbl, 12)
	PctLbl.TextXAlignment = Enum.TextXAlignment.Right
	PctLbl.ZIndex = 52
	PctLbl.Parent = LoaderCard

	local BarTrack = Instance.new("Frame")
	BarTrack.Size = UDim2.new(1, -36, 0, 8)
	BarTrack.Position = UDim2.new(0, 18, 0, 118)
	BarTrack.BackgroundColor3 = Color3.fromRGB(20, 30, 42)
	BarTrack.BackgroundTransparency = 0.45
	BarTrack.BorderSizePixel = 0
	BarTrack.ZIndex = 52
	BarTrack.Parent = LoaderCard
	addCorner(BarTrack, 4)
	addStroke(BarTrack, Library.Theme.SubBorder, 1, 0.35)

	local BarFill = Instance.new("Frame")
	BarFill.Size = UDim2.new(0, 0, 1, 0)
	BarFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	BarFill.BorderSizePixel = 0
	BarFill.ZIndex = 53
	BarFill.Parent = BarTrack
	addCorner(BarFill, 4)
	applyButtonGradient(BarFill, true)

	local spinning = true
	task.spawn(function()
		while spinning and LoaderCard.Parent do
			spinGrad.Rotation = (spinGrad.Rotation + 14) % 360
			SpinnerLogo.Rotation = (SpinnerLogo.Rotation - 8) % 360
			task.wait(0.02)
		end
	end)

	tween(loaderScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.0 })

	task.spawn(function()
		local steps = {
			{ pct = 0.22, txt = "Initializing NightSystem Glass UI...", waitTime = 1.15 },
			{ pct = 0.54, txt = "Loading Frosted Theme & Shaders...", waitTime = 1.35 },
			{ pct = 0.85, txt = "Building Tabs & Responsive Grid...", waitTime = 1.30 },
			{ pct = 1.00, txt = "Ready!", waitTime = 1.20 },
		}
		local currentPct = 0
		for _, st in ipairs(steps) do
			SubLbl.Text = st.txt
			tween(BarFill, TweenInfo.new(st.waitTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(st.pct, 0, 1, 0)
			})
			local startP = currentPct
			local elapsed = 0
			while elapsed < st.waitTime do
				local dt = task.wait(0.02)
				elapsed = elapsed + dt
				local alpha = math.clamp(elapsed / st.waitTime, 0, 1)
				local val = math.floor((startP + (st.pct - startP) * alpha) * 100 + 0.5)
				PctLbl.Text = tostring(val) .. "%"
			end
			currentPct = st.pct
		end

		spinning = false
		local pop = tween(loaderScale, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.08 })
		pop.Completed:Connect(function()
			tween(LoaderCard, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0.95 })
			local shrink = tween(loaderScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.01 })
			shrink.Completed:Connect(function()
				if LoaderCard then LoaderCard:Destroy() end
				if onFinished then onFinished() end
			end)
		end)
	end)
end

function Library.MakeWindow(selfOrConfig, maybeConfig)
	local config = (selfOrConfig == Library) and maybeConfig or selfOrConfig
	if type(config) == "string" then
		config = { Name = config }
	end
	config = config or {}

	local customCfg = config.SaveName or config.ConfigFolder or config.ConfigName or config.FileName
	if customCfg and customCfg ~= "" then
		if not string.find(customCfg, "%.json$") then
			customCfg = customCfg .. ".json"
		end
		Library.ConfigFileName = customCfg
		Library:LoadConfiguration(customCfg)
	end

	local windowTitle = config.Name or config.Title or config.LoadingTitle or "NightSystem"
	local toggleKey   = resolveKeyItem(config.ToggleKey or config.Bind) or Library.ToggleKey
	local winWidth    = config.Width or BASE_WIDTH
	local winHeight   = config.Height or BASE_HEIGHT

	local guiName = "NightSystemUI_" .. tostring(windowTitle):gsub("%W", "")

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = guiName
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mountScreenGui(ScreenGui, guiName)

	local MainWin = Instance.new("Frame")
	MainWin.Name = "MainWin"
	MainWin.AnchorPoint = Vector2.new(0.5, 0.5)
	MainWin.Size = UDim2.new(0, winWidth, 0, winHeight)
	MainWin.Position = UDim2.new(0.5, 0, 0.5, 0)
	MainWin.BackgroundColor3 = Library.Theme.MainBg
	MainWin.BackgroundTransparency = Library.Theme.Transparency
	MainWin.BorderSizePixel = 0
	MainWin.Active = true
	MainWin.Visible = false
	MainWin.Parent = ScreenGui
	addCorner(MainWin, 10)
	local MainStroke = addStroke(MainWin, Library.Theme.Border, 1.2, 0.20)

	local userScale = 1.0
	local WinScale = Instance.new("UIScale")
	WinScale.Scale = 0.02
	WinScale.Parent = MainWin

	local WinGrad = Instance.new("UIGradient")
	WinGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(26, 29, 38)),
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(18, 20, 26)),
	})
	WinGrad.Rotation = 90
	WinGrad.Parent = MainWin

	local OuterGlow = Instance.new("Frame")
	OuterGlow.Name = "OuterGlow"
	OuterGlow.Size = UDim2.new(1, 8, 1, 8)
	OuterGlow.Position = UDim2.new(0, -4, 0, -4)
	OuterGlow.BackgroundTransparency = 1
	OuterGlow.ZIndex = 0
	OuterGlow.Parent = MainWin
	addCorner(OuterGlow, 12)
	addStroke(OuterGlow, Color3.fromRGB(35, 40, 56), 2.0, 0.5)

	local BottomAccent = Instance.new("Frame")
	BottomAccent.Name = "BottomAccent"
	BottomAccent.Size = UDim2.new(0.75, 0, 0, 2)
	BottomAccent.Position = UDim2.new(0.125, 0, 1, -1)
	BottomAccent.BackgroundColor3 = Library.Theme.Accent
	BottomAccent.BackgroundTransparency = 0.2
	BottomAccent.BorderSizePixel = 0
	BottomAccent.ZIndex = 2
	BottomAccent.Parent = MainWin
	addCorner(BottomAccent, 1)

	local bGrad = Instance.new("UIGradient")
	bGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 1.0),
		NumberSequenceKeypoint.new(0.20, 0.2),
		NumberSequenceKeypoint.new(0.50, 0.0),
		NumberSequenceKeypoint.new(0.80, 0.2),
		NumberSequenceKeypoint.new(1.00, 1.0),
	})
	bGrad.Parent = BottomAccent

	local ContentWrap = Instance.new("Frame")
	ContentWrap.Name = "ContentWrap"
	ContentWrap.Size = UDim2.new(1, 0, 0, winHeight - 40)
	ContentWrap.Position = UDim2.new(0, 0, 0, 40)
	ContentWrap.BackgroundTransparency = 1
	ContentWrap.ZIndex = 2
	ContentWrap.Parent = MainWin

	local TitleBar = Instance.new("Frame")
	TitleBar.Name = "TitleBar"
	TitleBar.Size = UDim2.new(1, 0, 0, 40)
	TitleBar.BackgroundTransparency = 1
	TitleBar.ZIndex = 3
	TitleBar.Parent = MainWin

	local TitleDivider = Instance.new("Frame")
	TitleDivider.Name = "TitleDivider"
	TitleDivider.Size = UDim2.new(1, 0, 0, 1)
	TitleDivider.Position = UDim2.new(0, 0, 1, -1)
	TitleDivider.BackgroundColor3 = Color3.fromRGB(38, 42, 55)
	TitleDivider.BackgroundTransparency = 0.4
	TitleDivider.BorderSizePixel = 0
	TitleDivider.Parent = TitleBar

	local TitleLogo = Instance.new("ImageLabel")
	TitleLogo.Name = "TitleLogo"
	TitleLogo.Size = UDim2.new(0, 24, 0, 24)
	TitleLogo.Position = UDim2.new(0, 14, 0.5, -12)
	TitleLogo.BackgroundTransparency = 1
	TitleLogo.Image = LOGO_ASSET
	TitleLogo.ScaleType = Enum.ScaleType.Fit
	TitleLogo.ZIndex = 4
	TitleLogo.Parent = TitleBar

	local TitleText = Instance.new("TextLabel")
	TitleText.Name = "TitleText"
	TitleText.Size = UDim2.new(0.65, -36, 1, 0)
	TitleText.Position = UDim2.new(0, 44, 0, 0)
	TitleText.BackgroundTransparency = 1
	TitleText.Text = tostring(windowTitle)
	TitleText.TextColor3 = Color3.fromRGB(245, 248, 255)
	TitleText.Font = Enum.Font.GothamBold
	TitleText.TextSize = 15
	TitleText.TextXAlignment = Enum.TextXAlignment.Left
	TitleText.TextStrokeTransparency = 1
	TitleText.TextTruncate = Enum.TextTruncate.AtEnd
	TitleText.Parent = TitleBar

	local function createGlassControlBtn(iconType, rightOffset, isCloseBtn, callback)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 28, 0, 24)
		btn.Position = UDim2.new(1, rightOffset, 0.5, -12)
		btn.BackgroundColor3 = isCloseBtn and Color3.fromRGB(44, 30, 38) or Color3.fromRGB(30, 34, 46)
		btn.BackgroundTransparency = isCloseBtn and 0.15 or 0.20
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = TitleBar
		addCorner(btn, 6)

		local btnScale = Instance.new("UIScale")
		btnScale.Scale = 1
		btnScale.Parent = btn

		local stroke = addStroke(
			btn,
			isCloseBtn and Color3.fromRGB(205, 55, 75) or Color3.fromRGB(50, 56, 75),
			1.0,
			isCloseBtn and 0.20 or 0.25
		)

		local iconFrames = {}
		if iconType == "✙" or iconType == "cross" or isCloseBtn then
			local barV = Instance.new("Frame")
			barV.Size = UDim2.new(0, 4, 0, 13)
			barV.AnchorPoint = Vector2.new(0.5, 0.5)
			barV.Position = UDim2.new(0.5, 0, 0.5, 0)
			barV.BackgroundColor3 = Color3.fromRGB(255, 160, 175)
			barV.BorderSizePixel = 0
			barV.Parent = btn
			addCorner(barV, 1)
			table.insert(iconFrames, barV)

			local barH = Instance.new("Frame")
			barH.Size = UDim2.new(0, 13, 0, 4)
			barH.AnchorPoint = Vector2.new(0.5, 0.5)
			barH.Position = UDim2.new(0.5, 0, 0.5, 0)
			barH.BackgroundColor3 = Color3.fromRGB(255, 160, 175)
			barH.BorderSizePixel = 0
			barH.Parent = btn
			addCorner(barH, 1)
			table.insert(iconFrames, barH)
		elseif iconType == "☰" or iconType == "menu" then
			for i = -1, 1 do
				local bar = Instance.new("Frame")
				bar.Size = UDim2.new(0, 13, 0, 2)
				bar.AnchorPoint = Vector2.new(0.5, 0.5)
				bar.Position = UDim2.new(0.5, 0, 0.5, i * 4)
				bar.BackgroundColor3 = Color3.fromRGB(200, 210, 230)
				bar.BorderSizePixel = 0
				bar.Parent = btn
				addCorner(bar, 1)
				table.insert(iconFrames, bar)
			end
		elseif iconType == "−" or iconType == "minimize" then
			local bar = Instance.new("Frame")
			bar.Size = UDim2.new(0, 12, 0, 2)
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Position = UDim2.new(0.5, 0, 0.5, 0)
			bar.BackgroundColor3 = Color3.fromRGB(200, 210, 230)
			bar.BorderSizePixel = 0
			bar.Parent = btn
			addCorner(bar, 1)
			table.insert(iconFrames, bar)
		elseif iconType == "⛭" or iconType == "settings" or iconType == "gear" then
			local gearHolder = Instance.new("Frame")
			gearHolder.Name = "GearHolder"
			gearHolder.Size = UDim2.new(0, 14, 0, 14)
			gearHolder.AnchorPoint = Vector2.new(0.5, 0.5)
			gearHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
			gearHolder.BackgroundTransparency = 1
			gearHolder.Parent = btn

			local angles = { 0, 45, 90, 135 }
			for _, ang in ipairs(angles) do
				local bar = Instance.new("Frame")
				bar.Size = UDim2.new(1, 0, 0, 3)
				bar.AnchorPoint = Vector2.new(0.5, 0.5)
				bar.Position = UDim2.new(0.5, 0, 0.5, 0)
				bar.Rotation = ang
				bar.BackgroundColor3 = Color3.fromRGB(200, 210, 230)
				bar.BorderSizePixel = 0
				bar.Parent = gearHolder
				addCorner(bar, 1)
				table.insert(iconFrames, bar)
			end

			local gearCenter = Instance.new("Frame")
			gearCenter.Name = "GearCenter"
			gearCenter.Size = UDim2.new(0, 6, 0, 6)
			gearCenter.AnchorPoint = Vector2.new(0.5, 0.5)
			gearCenter.Position = UDim2.new(0.5, 0, 0.5, 0)
			gearCenter.BackgroundColor3 = btn.BackgroundColor3
			gearCenter.BorderSizePixel = 0
			gearCenter.ZIndex = 4
			gearCenter.Parent = gearHolder
			addCorner(gearCenter, 3)
		else
			btn.Text = tostring(iconType)
			btn.TextColor3 = Color3.fromRGB(200, 210, 230)
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 13
			btn.TextStrokeTransparency = 1
		end

		local function setVisual(hovered)
			if isCloseBtn then
				if hovered then
					btn.BackgroundColor3 = Color3.fromRGB(235, 60, 80)
					btn.BackgroundTransparency = 0
					stroke.Color = Color3.fromRGB(255, 120, 140)
					stroke.Transparency = 0
					for _, f in ipairs(iconFrames) do
						f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					end
				else
					btn.BackgroundColor3 = Color3.fromRGB(44, 30, 38)
					btn.BackgroundTransparency = 0.15
					stroke.Color = Color3.fromRGB(205, 55, 75)
					stroke.Transparency = 0.20
					for _, f in ipairs(iconFrames) do
						f.BackgroundColor3 = Color3.fromRGB(255, 160, 175)
					end
				end
			else
				if hovered then
					btn.BackgroundColor3 = Color3.fromRGB(48, 62, 105)
					btn.BackgroundTransparency = 0
					stroke.Color = Library.Theme.Accent
					stroke.Transparency = 0
					btn.TextColor3 = Color3.fromRGB(255, 255, 255)
					for _, f in ipairs(iconFrames) do
						f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					end
					local gh = btn:FindFirstChild("GearHolder")
					if gh then
						local gc = gh:FindFirstChild("GearCenter")
						if gc then gc.BackgroundColor3 = Color3.fromRGB(48, 62, 105) end
					end
				else
					btn.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
					btn.BackgroundTransparency = 0.20
					stroke.Color = Color3.fromRGB(50, 56, 75)
					stroke.Transparency = 0.35
					btn.TextColor3 = Color3.fromRGB(200, 210, 230)
					for _, f in ipairs(iconFrames) do
						f.BackgroundColor3 = Color3.fromRGB(200, 210, 230)
					end
					local gh = btn:FindFirstChild("GearHolder")
					if gh then
						local gc = gh:FindFirstChild("GearCenter")
						if gc then gc.BackgroundColor3 = Color3.fromRGB(30, 34, 46) end
					end
				end
			end
		end

		setVisual(false)

		btn.MouseEnter:Connect(function()
			setVisual(true)
			tween(btnScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 })
			local gh = btn:FindFirstChild("GearHolder")
			if gh then
				tween(gh, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = gh.Rotation + 45 })
			end
		end)
		btn.MouseLeave:Connect(function()
			setVisual(false)
			tween(btnScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 })
		end)
		btn.MouseButton1Down:Connect(function()
			tween(btnScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.92 })
		end)
		btn.MouseButton1Up:Connect(function()
			tween(btnScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 })
		end)
		btn.MouseButton1Click:Connect(callback)
		return btn
	end

	local isMinimized = false
	local isWindowOpen = false
	local isAnimatingWindow = false
	local currentScalePreset = 1
	local preMinimizePos = UDim2.new(0.5, 0, 0.5, 0)
	local pillPreMinimizePos = UDim2.new(0.5, 0, 0, 10)

	local pillWidth = math.clamp(#tostring(windowTitle) * 8 + 68, 140, 260)
	local MobileOpenPill = Instance.new("TextButton")
	MobileOpenPill.Name = "MobileOpenPill"
	MobileOpenPill.AnchorPoint = Vector2.new(0.5, 0)
	MobileOpenPill.Size = UDim2.new(0, pillWidth, 0, 30)
	MobileOpenPill.Position = UDim2.new(0.5, 0, 0, 10)
	MobileOpenPill.Text = tostring(windowTitle)
	MobileOpenPill.AutoButtonColor = false
	MobileOpenPill.Visible = false
	MobileOpenPill.ZIndex = 40
	MobileOpenPill.Parent = ScreenGui
	styleBrightButtonText(MobileOpenPill, 12)
	addCorner(MobileOpenPill, 15)
	local pillOpenStroke = addStroke(MobileOpenPill, Library.Theme.NeonBorder, 1.4, 0.1)
	applyButtonGradient(MobileOpenPill, false)
	attachButtonFX(MobileOpenPill, pillOpenStroke)

	local function updatePillLabel()
		if isWindowOpen then
			MobileOpenPill.Text = "Close " .. tostring(windowTitle)
		else
			MobileOpenPill.Text = "Open " .. tostring(windowTitle)
		end
	end

	local pillDragging = false
	local pillDragStart = nil
	local pillStartPos = nil
	local pillMoved = false

	MobileOpenPill.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pillDragging = true
			pillMoved = false
			pillDragStart = input.Position
			pillStartPos = MobileOpenPill.Position

			local endedConn
			endedConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					pillDragging = false
					if endedConn then endedConn:Disconnect() end
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if pillDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - pillDragStart
			if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
				pillMoved = true
			end
			MobileOpenPill.Position = UDim2.new(
				pillStartPos.X.Scale,
				pillStartPos.X.Offset + delta.X,
				pillStartPos.Y.Scale,
				pillStartPos.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pillDragging = false
		end
	end)

	local function closeWindowAnimated()
		if isAnimatingWindow or not isWindowOpen then return end
		isAnimatingWindow = true
		isWindowOpen = false
		updatePillLabel()
		if isMinimized then
			isMinimized = false
			MainWin.Size = UDim2.new(0, winWidth, 0, winHeight)
			MainWin.Position = preMinimizePos or UDim2.new(0.5, 0, 0.5, 0)
			MainWin.ClipsDescendants = false
			BottomAccent.Visible = true
		end
		tween(MobileOpenPill, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = pillPreMinimizePos or UDim2.new(0.5, 0, 0, 10)
		})

		local expandScale = userScale * 1.085
		local step1 = tween(WinScale, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = expandScale
		})
		step1.Completed:Connect(function()
			tween(MainWin, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 0.92
			})
			tween(MainStroke, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 0.95
			})
			local step2 = tween(WinScale, TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Scale = 0.01
			})
			step2.Completed:Connect(function()
				MainWin.Visible = false
				MobileOpenPill.Visible = true
				isAnimatingWindow = false
				if type(config.CloseCallback) == "function" then
					task.spawn(config.CloseCallback)
				end
			end)
		end)
	end

	local function openWindowAnimated()
		if isAnimatingWindow or isWindowOpen then return end
		isAnimatingWindow = true
		isWindowOpen = true
		updatePillLabel()
		MobileOpenPill.Visible = true

		WinScale.Scale = 0.02
		MainWin.BackgroundTransparency = 0.85
		MainStroke.Transparency = 0.85
		MainWin.Visible = true

		tween(MainWin, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = Library.Theme.Transparency
		})
		tween(MainStroke, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 0.08
		})

		local popScale = userScale * 1.06
		local step1 = tween(WinScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = popScale
		})
		step1.Completed:Connect(function()
			local step2 = tween(WinScale, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				Scale = userScale
			})
			step2.Completed:Connect(function()
				isAnimatingWindow = false
			end)
		end)
	end

	MobileOpenPill.MouseButton1Click:Connect(function()
		if pillMoved then
			pillMoved = false
			return
		end
		if isWindowOpen then
			closeWindowAnimated()
		else
			openWindowAnimated()
		end
	end)

	playPrettyLoader(ScreenGui, windowTitle, function()
		MobileOpenPill.Visible = true
		openWindowAnimated()
	end)

	local toggleSettingsWindow = nil
	createGlassControlBtn("⛭", -136, false, function()
		if toggleSettingsWindow then
			toggleSettingsWindow()
		end
	end)

	local function toggleMinimize()
		if isAnimatingWindow then return end
		if not isWindowOpen then
			openWindowAnimated()
			return
		end
		isMinimized = not isMinimized
		if isMinimized then
			preMinimizePos = MainWin.Position
			pillPreMinimizePos = MobileOpenPill.Position
			ContentWrap.Size = UDim2.new(1, 0, 0, winHeight - 36)
			MainWin.ClipsDescendants = true
			BottomAccent.Visible = false
			local minBarWidth = math.clamp(math.floor(winWidth * 0.64), 380, 450)
			tween(MainWin, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, minBarWidth, 0, 36),
				Position = UDim2.new(0.5, 0, 0, 18)
			})
			tween(MobileOpenPill, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, 0, 0, 40)
			})
		else
			local restorePos = preMinimizePos or UDim2.new(0.5, 0, 0.5, 0)
			local pillRestorePos = pillPreMinimizePos or UDim2.new(0.5, 0, 0, 10)
			local t = tween(MainWin, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, winWidth, 0, winHeight),
				Position = restorePos
			})
			tween(MobileOpenPill, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Position = pillRestorePos
			})
			t.Completed:Connect(function()
				if not isMinimized then
					MainWin.ClipsDescendants = false
					BottomAccent.Visible = true
				end
			end)
		end
	end

	createGlassControlBtn("−", -102, false, toggleMinimize)

	createGlassControlBtn("☰", -68, false, function()
		if isAnimatingWindow then return end
		if currentScalePreset == 1 then
			currentScalePreset = 2
			userScale = 0.82
		elseif currentScalePreset == 2 then
			currentScalePreset = 3
			userScale = 1.12
		else
			currentScalePreset = 1
			userScale = 1.0
		end
		tween(WinScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = userScale })
	end)

	createGlassControlBtn("✙", -34, true, function()
		closeWindowAnimated()
	end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.LeftControl then
			toggleMinimize()
		elseif input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.RightControl or (toggleKey and input.KeyCode == toggleKey and input.KeyCode ~= Enum.KeyCode.LeftControl) then
			if isWindowOpen then
				closeWindowAnimated()
			else
				openWindowAnimated()
			end
		end
	end)

	do
		local dragging, dragInput, dragStart, startPos
		TitleBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = MainWin.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
		TitleBar.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				dragInput = input
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if input == dragInput and dragging then
				local delta = input.Position - dragStart
				MainWin.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
				if isMinimized then
					MobileOpenPill.Position = UDim2.new(
						MainWin.Position.X.Scale,
						MainWin.Position.X.Offset,
						0,
						MainWin.Position.Y.Offset + 22
					)
				end
			end
		end)
	end

	local ResizeGrip = Instance.new("TextButton")
	ResizeGrip.Name = "ResizeGrip"
	ResizeGrip.Size = UDim2.new(0, 18, 0, 18)
	ResizeGrip.Position = UDim2.new(1, -18, 1, -18)
	ResizeGrip.BackgroundTransparency = 1
	ResizeGrip.Text = "◢"
	ResizeGrip.TextColor3 = Library.Theme.SubBorder
	ResizeGrip.TextTransparency = 0.35
	ResizeGrip.Font = Enum.Font.GothamBold
	ResizeGrip.TextSize = 12
	ResizeGrip.ZIndex = 10
	ResizeGrip.Parent = ContentWrap

	do
		local resizing = false
		local resizeStartPos = nil
		local startScale = 1
		local startWidth = winWidth
		local startHeight = winHeight

		ResizeGrip.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				resizing = true
				resizeStartPos = input.Position
				startScale = userScale
				startWidth = winWidth
				startHeight = winHeight
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						resizing = false
					end
				end)
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - resizeStartPos
				local desiredVisualW = math.clamp(startWidth * startScale + delta.X, 480, 1400)
				local desiredVisualH = math.clamp(startHeight * startScale + delta.Y, 300, 950)

				if desiredVisualW < BASE_WIDTH then
					userScale = math.clamp(desiredVisualW / BASE_WIDTH, 0.55, 1)
					WinScale.Scale = userScale
					winWidth = BASE_WIDTH
					winHeight = math.clamp(math.floor(desiredVisualH / userScale), 420, 850)
				else
					userScale = 1
					WinScale.Scale = 1
					winWidth = math.clamp(math.floor(desiredVisualW), BASE_WIDTH, 1300)
					winHeight = math.clamp(math.floor(desiredVisualH), 420, 850)
				end

				MainWin.Size = UDim2.new(0, winWidth, 0, winHeight)
				ContentWrap.Size = UDim2.new(1, 0, 0, winHeight - 36)
			end
		end)
	end

	local InnerBorderFrame = Instance.new("Frame")
	InnerBorderFrame.Name = "InnerBorderFrame"
	InnerBorderFrame.Size = UDim2.new(1, -164, 1, -16)
	InnerBorderFrame.Position = UDim2.new(0, 154, 0, 8)
	InnerBorderFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	InnerBorderFrame.BackgroundTransparency = 0
	InnerBorderFrame.BorderSizePixel = 0
	InnerBorderFrame.Parent = ContentWrap
	addCorner(InnerBorderFrame, 8)
	addStroke(InnerBorderFrame, Color3.fromRGB(42, 46, 62), 1.0, 0.35)

	local SideTabScroll = Instance.new("ScrollingFrame")
	SideTabScroll.Name = "SideTabScroll"
	SideTabScroll.Size = UDim2.new(0, 136, 1, -16)
	SideTabScroll.Position = UDim2.new(0, 10, 0, 8)
	SideTabScroll.BackgroundTransparency = 1
	SideTabScroll.BorderSizePixel = 0
	SideTabScroll.ScrollBarThickness = 0
	SideTabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	SideTabScroll.ZIndex = 3
	SideTabScroll.Parent = ContentWrap

	local SideTabLayout = Instance.new("UIListLayout")
	SideTabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	SideTabLayout.Padding = UDim.new(0, 5)
	SideTabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	SideTabLayout.Parent = SideTabScroll

	addPadding(SideTabScroll, 2, 4, 2, 2)

	SideTabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		SideTabScroll.CanvasSize = UDim2.new(0, 0, 0, SideTabLayout.AbsoluteContentSize.Y + 8)
	end)

	attachTouchScrollBarAndArrows(
		ContentWrap,
		SideTabScroll,
		SideTabLayout,
		UDim2.new(0, 147, 0, 8),
		UDim2.new(0, 6, 1, -16),
		85
	)

	local WindowObj = {
		ScreenGui = ScreenGui,
		MainFrame = MainWin,
		UIScale = WinScale,
		Tabs = {},
		ActiveTab = nil,
	}

	function WindowObj:SetOpacity(pct)
		pct = math.clamp(tonumber(pct) or 0.68, 0, 1)
		Library.Theme.Transparency = math.clamp(1 - pct * 0.85, 0.08, 0.78)
		MainWin.BackgroundTransparency = Library.Theme.Transparency
	end

	function WindowObj:SetScale(scale)
		userScale = math.clamp(tonumber(scale) or 1, 0.5, 1.5)
		tween(WinScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = userScale })
	end

	function WindowObj:SetToggleKey(newKey)
		local resolved = resolveKeyItem(newKey)
		if resolved then
			toggleKey = resolved
		end
	end

	function WindowObj:Toggle()
		if isWindowOpen then
			closeWindowAnimated()
		else
			openWindowAnimated()
		end
	end

	function WindowObj:Close()
		closeWindowAnimated()
	end

	function WindowObj:Open()
		openWindowAnimated()
	end

	function WindowObj:SetTitle(newTitle)
		windowTitle = tostring(newTitle)
		TitleText.Text = windowTitle
		MobileOpenPill.Size = UDim2.new(0, math.clamp(#windowTitle * 8 + 68, 140, 260), 0, 30)
		updatePillLabel()
	end

	function WindowObj:AddConstraints(minSize, maxSize, aspectRatio)
		local sc = addSizeConstraint(MainWin, minSize or Vector2.new(480, 36), maxSize or Vector2.new(1600, 1000))
		local arc = nil
		if aspectRatio then
			arc = Instance.new("UIAspectRatioConstraint")
			arc.AspectRatio = aspectRatio
			arc.Parent = MainWin
		end
		return sc, arc
	end

	function WindowObj:SelectTab(idxOrTab)
		local target = type(idxOrTab) == "number" and self.Tabs[idxOrTab] or idxOrTab
		if target then
			for _, t in ipairs(self.Tabs) do
				t._setVisual(t == target)
			end
			self.ActiveTab = target
		end
	end
	WindowObj.SwitchTab = WindowObj.SelectTab

	function WindowObj:Dialog(cfg)
		cfg = type(cfg) == "table" and cfg or { Title = "Dialog", Content = tostring(cfg or "") }
		Library:MakeNotification({
			Name = cfg.Title or cfg.Name or windowTitle,
			Content = cfg.Content or cfg.Text or "",
			Time = 5
		})
	end

	function WindowObj:Destroy()
		pcall(function() RunService:UnbindFromRenderStep("NightSystem_Aimbot") end)
		if ScreenGui and ScreenGui.Parent then
			ScreenGui:Destroy()
		end
	end
	WindowObj.Delete = WindowObj.Destroy

	function WindowObj.MakeTab(selfOrTabCfg, maybeTabCfg, optionalIcon)
		local tabConfig = (selfOrTabCfg == WindowObj) and maybeTabCfg or selfOrTabCfg
		if type(tabConfig) == "string" then
			tabConfig = { Name = tabConfig, Icon = optionalIcon }
		end
		tabConfig = tabConfig or {}
		local tabName = tabConfig.Name or tabConfig.Title or ("Tab " .. tostring(#WindowObj.Tabs + 1))

		local tabIndex = #WindowObj.Tabs + 1

		local TabBtn = Instance.new("TextButton")
		TabBtn.Name = tabName .. "_TabBtn"
		TabBtn.LayoutOrder = tabIndex
		TabBtn.Size = UDim2.new(1, 0, 0, 36)
		TabBtn.BorderSizePixel = 0
		TabBtn.Text = ""
		TabBtn.AutoButtonColor = false
		TabBtn.ZIndex = 4
		TabBtn.Parent = SideTabScroll
		addCorner(TabBtn, 7)

		local TabStroke = addStroke(TabBtn, Color3.fromRGB(36, 40, 52), 1.0, 0.6)
		local TabGrad = Instance.new("UIGradient")
		TabGrad.Parent = TabBtn

		local TabIndicator = Instance.new("Frame")
		TabIndicator.Name = "Indicator"
		TabIndicator.Size = UDim2.new(0, 3, 1, -10)
		TabIndicator.Position = UDim2.new(0, 4, 0, 5)
		TabIndicator.BackgroundColor3 = Library.Theme.Accent
		TabIndicator.BorderSizePixel = 0
		TabIndicator.Visible = false
		TabIndicator.ZIndex = 5
		TabIndicator.Parent = TabBtn
		addCorner(TabIndicator, 2)

		local TabLabel = Instance.new("TextLabel")
		TabLabel.Name = "TabLabel"
		TabLabel.Size = UDim2.new(1, -22, 1, 0)
		TabLabel.Position = UDim2.new(0, 16, 0, 0)
		TabLabel.BackgroundTransparency = 1
		TabLabel.Text = tabName
		styleBrightButtonText(TabLabel, 13)
		TabLabel.TextXAlignment = Enum.TextXAlignment.Left
		TabLabel.TextTruncate = Enum.TextTruncate.AtEnd
		TabLabel.ZIndex = 5
		TabLabel.Parent = TabBtn

		local TabPage = Instance.new("Frame")
		TabPage.Name = tabName .. "_Page"
		TabPage.Size = UDim2.new(1, -16, 1, -16)
		TabPage.Position = UDim2.new(0, 8, 0, 8)
		TabPage.BackgroundTransparency = 1
		TabPage.Visible = false
		TabPage.Parent = InnerBorderFrame

		local PageLayout = Instance.new("UIListLayout")
		PageLayout.FillDirection = Enum.FillDirection.Horizontal
		PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
		PageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		PageLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		PageLayout.Padding = UDim.new(0, 8)
		PageLayout.Parent = TabPage

		local Columns = {}
		local defaultSubTitles = {
			[1] = tabName,
			[2] = tabName .. " — Options",
			[3] = tabName .. " — Extra",
		}

		for colIdx = 1, 3 do
			local Card = Instance.new("Frame")
			Card.Name = "Column_" .. colIdx
			Card.LayoutOrder = colIdx
			Card.Size = UDim2.new(0.3333, -8, 1, 0)
			Card.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
			Card.BackgroundTransparency = 0
			Card.BorderSizePixel = 0
			Card.ClipsDescendants = true
			Card.Visible = (colIdx == 1)
			Card.Parent = TabPage
			addCorner(Card, 8)
			addStroke(Card, Color3.fromRGB(44, 48, 64), 1.0, 0.35)

			local Header = Instance.new("Frame")
			Header.Name = "Header"
			Header.Size = UDim2.new(1, 0, 0, 32)
			Header.BorderSizePixel = 0
			Header.Visible = false
			Header.Parent = Card
			addCorner(Header, 7)
			applyMetallicHeader(Header)

			local HeaderLine = Instance.new("Frame")
			HeaderLine.Size = UDim2.new(1, 0, 0, 1)
			HeaderLine.Position = UDim2.new(0, 0, 1, -1)
			HeaderLine.BackgroundColor3 = Color3.fromRGB(48, 52, 70)
			HeaderLine.BackgroundTransparency = 0.4
			HeaderLine.BorderSizePixel = 0
			HeaderLine.Parent = Header

			local HeaderTitle = Instance.new("TextLabel")
			HeaderTitle.Name = "HeaderTitle"
			HeaderTitle.Size = UDim2.new(1, -20, 1, 0)
			HeaderTitle.Position = UDim2.new(0, 12, 0, 0)
			HeaderTitle.BackgroundTransparency = 1
			HeaderTitle.Text = defaultSubTitles[colIdx]
			styleBrightButtonText(HeaderTitle, 14)
			HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
			HeaderTitle.TextTruncate = Enum.TextTruncate.AtEnd
			HeaderTitle.Parent = Header

			local ColScroll = Instance.new("ScrollingFrame")
			ColScroll.Name = "ColScroll"
			ColScroll.Size = UDim2.new(1, -12, 1, -12)
			ColScroll.Position = UDim2.new(0, 2, 0, 6)
			ColScroll.BackgroundTransparency = 1
			ColScroll.BorderSizePixel = 0
			ColScroll.ScrollBarThickness = 0
			ColScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
			ColScroll.Parent = Card

			local ColLayout = Instance.new("UIListLayout")
			ColLayout.SortOrder = Enum.SortOrder.LayoutOrder
			ColLayout.Padding = UDim.new(0, 6)
			ColLayout.Parent = ColScroll

			addPadding(ColScroll, 6, 6, 6, 6)

			ColLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				ColScroll.CanvasSize = UDim2.new(0, 0, 0, ColLayout.AbsoluteContentSize.Y + 16)
			end)

			local colRail = attachTouchScrollBarAndArrows(
				Card,
				ColScroll,
				ColLayout,
				UDim2.new(1, -10, 0, 6),
				UDim2.new(0, 6, 1, -12),
				95
			)

			Columns[colIdx] = {
				Card = Card,
				Header = Header,
				HeaderTitle = HeaderTitle,
				Scroll = ColScroll,
				Layout = ColLayout,
				Rail = colRail,
				HasCustomTitle = false,
				ItemCount = 0,
				Weight = 0,
			}
		end

		local function updateResponsiveColumns()
			local activeCols = {}
			for i = 1, 3 do
				if Columns[i].ItemCount > 0 or Columns[i].HasCustomTitle then
					Columns[i].Card.Visible = true
					table.insert(activeCols, Columns[i].Card)
				else
					Columns[i].Card.Visible = false
				end
			end

			if #activeCols == 0 then
				Columns[1].Card.Visible = true
				activeCols = { Columns[1].Card }
			end

			local count = #activeCols
			for _, card in ipairs(activeCols) do
				if count == 1 then
					card.Size = UDim2.new(1, 0, 1, 0)
				elseif count == 2 then
					card.Size = UDim2.new(0.5, -4, 1, 0)
				else
					card.Size = UDim2.new(0.3333, -6, 1, 0)
				end
			end
		end

		local function setTabVisual(isActive)
			if isActive then
				TabBtn.BackgroundColor3 = Color3.fromRGB(36, 44, 75)
				TabBtn.BackgroundTransparency = 0
				TabStroke.Color = Library.Theme.Accent
				TabStroke.Thickness = 1.2
				TabStroke.Transparency = 0.1
				TabIndicator.Visible = true
				TabLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				TabPage.Visible = true
			else
				TabBtn.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
				TabBtn.BackgroundTransparency = 0.85
				TabStroke.Color = Color3.fromRGB(36, 40, 52)
				TabStroke.Thickness = 1.0
				TabStroke.Transparency = 0.6
				TabIndicator.Visible = false
				TabLabel.TextColor3 = Color3.fromRGB(160, 170, 190)
				TabPage.Visible = false
			end
		end

		local currentColumnIndex = 1
		local sectionCounter = 0

		local function getShortestColumnIndex()
			local bestIdx = 1
			local bestWeight = Columns[1].Weight
			for i = 2, 3 do
				if Columns[i].Weight < bestWeight then
					bestWeight = Columns[i].Weight
					bestIdx = i
				end
			end
			return bestIdx
		end

		local function getTargetScroll(explicitCol, weightCost)
			weightCost = weightCost or 1
			local cIdx = explicitCol

			if not cIdx then
				if sectionCounter <= 1 then
					if Columns[1].Weight < 6.5 then
						cIdx = 1
					elseif Columns[2].Weight < 6.5 then
						cIdx = 2
					elseif Columns[3].Weight < 6.5 then
						cIdx = 3
					else
						cIdx = getShortestColumnIndex()
					end
				else
					cIdx = currentColumnIndex
				end
			end

			cIdx = math.clamp(tonumber(cIdx) or 1, 1, 3)
			local col = Columns[cIdx]
			col.ItemCount = col.ItemCount + 1
			col.Weight = col.Weight + weightCost
			updateResponsiveColumns()
			return col.Scroll, col.ItemCount
		end

		local function createMethodsForTarget(resolveScroll)
			local Methods = {}

			function Methods.AddToggle(selfOrA, a, b, c, d)
				local cfg = (selfOrA == Methods or type(selfOrA) == "table" and selfOrA.AddToggle)
					and normalizeArgs("Toggle", a, b, c, d)
					or normalizeArgs("Toggle", selfOrA, a, b, c)

				local name     = cfg.Name or cfg.Title or "Toggle"
				local default  = cfg.Default or cfg.CurrentValue or false
				local callback = cfg.Callback or function() end
				local flag     = cfg.Flag
				local usePill  = (cfg.Style == "Switch" or cfg.Pill == true)

				local savedKey = (flag and flag ~= "") and flag or name
				if savedKey and Library.ConfigStore[savedKey] ~= nil then
					default = not not Library.ConfigStore[savedKey]
				end

				local scroll, order = resolveScroll(cfg.Column, 1)

				local RowBtn = Instance.new("TextButton")
				RowBtn.Name = name .. "_Toggle"
				RowBtn.LayoutOrder = order
				RowBtn.Size = UDim2.new(1, 0, 0, 38)
				RowBtn.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
				RowBtn.BackgroundTransparency = 0.35
				RowBtn.Text = ""
				RowBtn.AutoButtonColor = false
				RowBtn.Parent = scroll
				addCorner(RowBtn, 7)
				local rowStroke = addStroke(RowBtn, Color3.fromRGB(46, 52, 70), 1.0, 0.40)

				local state = default
				local changedListeners = {}
				local ToggleObj = { Value = state, Type = "Toggle" }

				function ToggleObj:OnChanged(fn)
					if type(fn) == "function" then
						table.insert(changedListeners, fn)
					end
				end

				local function fireCallbacks(val)
					task.spawn(callback, val)
					for _, fn in ipairs(changedListeners) do
						task.spawn(fn, val)
					end
				end

				if usePill then
					local Lbl = Instance.new("TextLabel")
					Lbl.Size = UDim2.new(1, -58, 1, 0)
					Lbl.Position = UDim2.new(0, 12, 0, 0)
					Lbl.BackgroundTransparency = 1
					Lbl.Text = name
					Lbl.TextColor3 = Color3.fromRGB(240, 245, 255)
					Lbl.Font = Enum.Font.GothamMedium
					Lbl.TextSize = 13
					Lbl.TextXAlignment = Enum.TextXAlignment.Left
					Lbl.TextTruncate = Enum.TextTruncate.AtEnd
					Lbl.Parent = RowBtn

					local Pill = Instance.new("Frame")
					Pill.Size = UDim2.new(0, 38, 0, 20)
					Pill.Position = UDim2.new(1, -48, 0.5, -10)
					Pill.BorderSizePixel = 0
					Pill.Parent = RowBtn
					addCorner(Pill, 10)
					local pillStroke = addStroke(Pill, Color3.fromRGB(56, 62, 80), 1.0, 0.3)

					local Knob = Instance.new("Frame")
					Knob.Size = UDim2.new(0, 14, 0, 14)
					Knob.BorderSizePixel = 0
					Knob.Parent = Pill
					addCorner(Knob, 7)

					local function updatePill()
						if state then
							tween(Pill, nil, { BackgroundColor3 = Library.Theme.Accent, BackgroundTransparency = 0.1 })
							tween(Knob, nil, { Position = UDim2.new(1, -17, 0.5, -7), BackgroundColor3 = Color3.fromRGB(255, 255, 255) })
							pillStroke.Color = Library.Theme.AccentGlow
						else
							tween(Pill, nil, { BackgroundColor3 = Color3.fromRGB(42, 46, 60), BackgroundTransparency = 0.45 })
							tween(Knob, nil, { Position = UDim2.new(0, 3, 0.5, -7), BackgroundColor3 = Color3.fromRGB(160, 170, 190) })
							pillStroke.Color = Color3.fromRGB(56, 62, 80)
						end
					end

					function ToggleObj:Set(val)
						state = not not val
						ToggleObj.Value = state
						if savedKey then
							Library.ConfigStore[savedKey] = state
							scheduleAutoSave()
						end
						updatePill()
						fireCallbacks(state)
					end
					updatePill()
				else
					local Lbl = Instance.new("TextLabel")
					Lbl.Size = UDim2.new(1, -44, 1, 0)
					Lbl.Position = UDim2.new(0, 12, 0, 0)
					Lbl.BackgroundTransparency = 1
					Lbl.Text = name
					Lbl.TextColor3 = Color3.fromRGB(240, 245, 255)
					Lbl.Font = Enum.Font.GothamMedium
					Lbl.TextSize = 13
					Lbl.TextXAlignment = Enum.TextXAlignment.Left
					Lbl.TextTruncate = Enum.TextTruncate.AtEnd
					Lbl.Parent = RowBtn

					local Box = Instance.new("Frame")
					Box.Size = UDim2.new(0, 20, 0, 20)
					Box.Position = UDim2.new(1, -30, 0.5, -10)
					Box.BorderSizePixel = 0
					Box.Parent = RowBtn
					addCorner(Box, 5)
					local boxStroke = addStroke(Box, Color3.fromRGB(58, 66, 88), 1.1, 0.35)

					local CheckMark = Instance.new("TextLabel")
					CheckMark.Size = UDim2.new(1, 0, 1, 0)
					CheckMark.BackgroundTransparency = 1
					CheckMark.Text = "✓"
					CheckMark.TextColor3 = Color3.fromRGB(255, 255, 255)
					CheckMark.Font = Enum.Font.GothamBold
					CheckMark.TextSize = 12
					CheckMark.TextStrokeTransparency = 1
					CheckMark.Parent = Box

					local function updateBox()
						if state then
							tween(Box, nil, { BackgroundColor3 = Library.Theme.Accent, BackgroundTransparency = 0.05 })
							boxStroke.Color = Color3.fromRGB(130, 170, 255)
							boxStroke.Transparency = 0.0
							CheckMark.Visible = true
						else
							tween(Box, nil, { BackgroundColor3 = Color3.fromRGB(36, 40, 54), BackgroundTransparency = 0.40 })
							boxStroke.Color = Color3.fromRGB(58, 66, 88)
							boxStroke.Transparency = 0.35
							CheckMark.Visible = false
						end
					end

					function ToggleObj:Set(val)
						state = not not val
						ToggleObj.Value = state
						if savedKey then
							Library.ConfigStore[savedKey] = state
							scheduleAutoSave()
						end
						updateBox()
						fireCallbacks(state)
					end
					updateBox()
				end

				RowBtn.MouseEnter:Connect(function()
					tween(RowBtn, nil, { BackgroundColor3 = Color3.fromRGB(36, 42, 58), BackgroundTransparency = 0.20 })
					rowStroke.Color = Color3.fromRGB(65, 75, 105)
				end)
				RowBtn.MouseLeave:Connect(function()
					tween(RowBtn, nil, { BackgroundColor3 = Color3.fromRGB(30, 34, 46), BackgroundTransparency = 0.35 })
					rowStroke.Color = Color3.fromRGB(46, 52, 70)
				end)

				ToggleObj.SetValue     = ToggleObj.Set
				ToggleObj.UpdateToggle = ToggleObj.Set

				RowBtn.MouseButton1Click:Connect(function()
					ToggleObj:Set(not state)
				end)

				registerFlag(flag, name, ToggleObj)
				if default then
					fireCallbacks(default)
				end
				return ToggleObj
			end
			Methods.CreateToggle = Methods.AddToggle
			Methods.MakeToggle   = Methods.AddToggle
			Methods.NewToggle    = Methods.AddToggle
			Methods.AddCheckbox  = Methods.AddToggle
			Methods.Toggle       = Methods.AddToggle
			Methods.addToggle    = Methods.AddToggle

									function Methods.AddSlider(selfOrA, a, b, c, d, e)
				local cfg = (selfOrA == Methods or type(selfOrA) == "table" and selfOrA.AddSlider)
					and normalizeArgs("Slider", a, b, c, d, e)
					or normalizeArgs("Slider", selfOrA, a, b, c, d)

				local name      = cfg.Name or cfg.Title or "Slider"
				local minVal    = cfg.Min or (cfg.Range and cfg.Range[1]) or 0
				local maxVal    = cfg.Max or (cfg.Range and cfg.Range[2]) or 100
				local increment = cfg.Increment or 1
				local default   = cfg.Default or cfg.CurrentValue or minVal
				local suffix    = cfg.ValueName or cfg.Suffix or ""
				local callback  = cfg.Callback or function() end
				local flag      = cfg.Flag

				local savedKey = (flag and flag ~= "") and flag or name
				if savedKey and Library.ConfigStore[savedKey] ~= nil then
					default = tonumber(Library.ConfigStore[savedKey]) or default
				end

				local scroll, order = resolveScroll(cfg.Column, 1.35)

				local Container = Instance.new("Frame")
				Container.Name = name .. "_Slider"
				Container.LayoutOrder = order
				Container.Size = UDim2.new(1, 0, 0, 50)
				Container.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
				Container.BackgroundTransparency = 0.35
				Container.Active = true
				Container.Parent = scroll
				addCorner(Container, 7)
				local contStroke = addStroke(Container, Color3.fromRGB(46, 52, 70), 1.0, 0.40)

				local TitleLbl = Instance.new("TextLabel")
				TitleLbl.Size = UDim2.new(0.65, -12, 0, 16)
				TitleLbl.Position = UDim2.new(0, 12, 0, 6)
				TitleLbl.BackgroundTransparency = 1
				TitleLbl.Text = name
				TitleLbl.TextColor3 = Color3.fromRGB(240, 245, 255)
				TitleLbl.Font = Enum.Font.GothamMedium
				TitleLbl.TextSize = 13
				TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
				TitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
				TitleLbl.Active = false
				TitleLbl.Parent = Container

				local ValueLbl = Instance.new("TextLabel")
				ValueLbl.Size = UDim2.new(0.35, -12, 0, 16)
				ValueLbl.Position = UDim2.new(0.65, 0, 0, 6)
				ValueLbl.BackgroundTransparency = 1
				ValueLbl.TextColor3 = Color3.fromRGB(200, 205, 218)
				ValueLbl.Font = Enum.Font.GothamMedium
				ValueLbl.TextSize = 12
				ValueLbl.TextXAlignment = Enum.TextXAlignment.Right
				ValueLbl.TextTruncate = Enum.TextTruncate.AtEnd
				ValueLbl.Active = false
				ValueLbl.Parent = Container

				-- Abgerundeter, viereckiger Track (Höhe 14px, Corner 4px)
				local Track = Instance.new("Frame")
				Track.Name = "Track"
				Track.Size = UDim2.new(1, -24, 0, 14)
				Track.Position = UDim2.new(0, 12, 0, 26)
				Track.BackgroundColor3 = Color3.fromRGB(32, 33, 38)
				Track.BorderSizePixel = 0
				Track.ClipsDescendants = true
				Track.Active = false
				Track.Parent = Container
				addCorner(Track, 4)
				addStroke(Track, Color3.fromRGB(46, 48, 56), 1.0, 0.40)

				local fillColor = cfg.SliderColor or Library.Theme.SliderFill or Color3.fromRGB(64, 66, 75)
				local Fill = Instance.new("Frame")
				Fill.Name = "Fill"
				Fill.Size = UDim2.new(0, 0, 1, 0)
				Fill.BackgroundColor3 = fillColor
				Fill.BorderSizePixel = 0
				Fill.ZIndex = 1
				Fill.Active = false
				Fill.Parent = Track
				addCorner(Fill, 4)

				-- Punkte (9 Punkte bei 10% bis 90%)
				if cfg.Ticks ~= false then
					local Ticks = Instance.new("Frame")
					Ticks.Name = "Ticks"
					Ticks.Size = UDim2.new(1, 0, 1, 0)
					Ticks.BackgroundTransparency = 1
					Ticks.BorderSizePixel = 0
					Ticks.ZIndex = 2
					Ticks.Active = false
					Ticks.Parent = Track

					for i = 1, 9 do
						local dot = Instance.new("Frame")
						dot.Name = "Dot_" .. i
						dot.Size = UDim2.new(0, 3, 0, 3)
						dot.AnchorPoint = Vector2.new(0.5, 0.5)
						dot.Position = UDim2.new(i * 0.1, 0, 0.5, 0)
						dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
						dot.BackgroundTransparency = 0.65
						dot.BorderSizePixel = 0
						dot.ZIndex = 2
						dot.Active = false
						dot.Parent = Ticks
						addCorner(dot, 2)
					end
				end

				-- Vertikaler weißer Strich als Indikator / Thumb
				local Thumb = Instance.new("Frame")
				Thumb.Name = "Thumb"
				Thumb.Size = UDim2.new(0, 3, 0, 9)
				Thumb.AnchorPoint = Vector2.new(0.5, 0.5)
				Thumb.Position = UDim2.new(0, 0, 0.5, 0)
				Thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				Thumb.BorderSizePixel = 0
				Thumb.ZIndex = 3
				Thumb.Active = false
				Thumb.Parent = Track
				addCorner(Thumb, 1)

				local changedListeners = {}
				local SliderObj = { Value = default, Type = "Slider" }

				function SliderObj:OnChanged(fn)
					if type(fn) == "function" then
						table.insert(changedListeners, fn)
					end
				end

				local function roundToIncrement(val)
					local clamped = math.clamp(val, minVal, maxVal)
					local snapped = minVal + math.floor(((clamped - minVal) / increment) + 0.5) * increment
					local decimals = tostring(increment):match("%.(%d+)")
					if decimals then
						snapped = tonumber(string.format("%." .. #decimals .. "f", snapped)) or snapped
					else
						snapped = math.floor(snapped + 0.5)
					end
					return math.clamp(snapped, minVal, maxVal)
				end

				local lastReportedVal = nil
				function SliderObj:Set(val)
					local finalVal = roundToIncrement(tonumber(val) or minVal)
					SliderObj.Value = finalVal
					local pct = (maxVal > minVal) and ((finalVal - minVal) / (maxVal - minVal)) or 0
					Fill.Size = UDim2.new(pct, 0, 1, 0)
					Thumb.Position = UDim2.new(pct, math.clamp(math.floor((0.5 - pct) * 6), -2, 2), 0.5, 0)
					ValueLbl.Text = tostring(finalVal) .. (suffix ~= "" and (" " .. suffix) or "")

					if finalVal ~= lastReportedVal then
						lastReportedVal = finalVal
						if savedKey then
							Library.ConfigStore[savedKey] = finalVal
							scheduleAutoSave()
						end
						task.spawn(callback, finalVal)
						for _, fn in ipairs(changedListeners) do
							task.spawn(fn, finalVal)
						end
					end
				end
				SliderObj.SetValue     = SliderObj.Set
				SliderObj.UpdateSlider = SliderObj.Set

				-- Klicksystem & direktes, leichtes Verschieben
				local isSliding = false
				local lastTouchPos = nil
				local dragConn = nil

				local function stopSliding()
					if isSliding then
						isSliding = false
						lastTouchPos = nil
						if dragConn then
							dragConn:Disconnect()
							dragConn = nil
						end
					end
				end

				local function updateFromCoordinate(xPos)
					local trackX = Track.AbsolutePosition.X
					local trackW = Track.AbsoluteSize.X
					if trackW > 0 then
						local pct = math.clamp((xPos - trackX) / trackW, 0, 1)
						local raw = minVal + (maxVal - minVal) * pct
						SliderObj:Set(raw)
					end
				end

				local function startSliding(input)
					isSliding = true
					if input.UserInputType == Enum.UserInputType.Touch then
						lastTouchPos = input.Position.X
					end
					updateFromCoordinate(input.Position.X)

					if dragConn then
						dragConn:Disconnect()
					end

					dragConn = RunService.RenderStepped:Connect(function()
						if not isSliding or not Track or not Track.Parent then
							stopSliding()
							return
						end

						local isDown = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
						if not isDown and not lastTouchPos then
							stopSliding()
							return
						end

						local curX = lastTouchPos or Mouse.X
						updateFromCoordinate(curX)
					end)
				end

				-- Klick auf beliebige Stelle des Containers oder des Tracks startet sofort das Verschieben
				Container.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						startSliding(input)
					end
				end)

				UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						stopSliding()
					end
				end)

				UserInputService.InputChanged:Connect(function(input)
					if isSliding then
						if input.UserInputType == Enum.UserInputType.Touch then
							lastTouchPos = input.Position.X
							updateFromCoordinate(input.Position.X)
						elseif input.UserInputType == Enum.UserInputType.MouseMovement then
							updateFromCoordinate(input.Position.X)
						end
					end
				end)

				Container.MouseEnter:Connect(function()
					tween(Container, nil, { BackgroundColor3 = Color3.fromRGB(36, 42, 58), BackgroundTransparency = 0.20 })
					contStroke.Color = Color3.fromRGB(65, 75, 105)
				end)
				Container.MouseLeave:Connect(function()
					tween(Container, nil, { BackgroundColor3 = Color3.fromRGB(30, 34, 46), BackgroundTransparency = 0.35 })
					contStroke.Color = Color3.fromRGB(46, 52, 70)
				end)

				Container.Destroying:Connect(function()
					stopSliding()
				end)

				SliderObj:Set(default)
				registerFlag(flag, name, SliderObj)
				return SliderObj
			end
			Methods.CreateSlider = Methods.AddSlider
			Methods.MakeSlider   = Methods.AddSlider
			Methods.NewSlider    = Methods.AddSlider
			Methods.Slider       = Methods.AddSlider
			Methods.addSlider    = Methods.AddSlider

			function Methods.AddButton(selfOrA, a, b, c)
				local cfg = (selfOrA == Methods or type(selfOrA) == "table" and selfOrA.AddButton)
					and normalizeArgs("Button", a, b, c)
					or normalizeArgs("Button", selfOrA, a, b)

				local name     = cfg.Name or cfg.Title or "Button"
				local callback = cfg.Callback or function() end
				local isCircle = (cfg.Style == "Circle" or cfg.Circle == true)

				local scroll, order = resolveScroll(cfg.Column, isCircle and 2.2 or 1)

				if isCircle then
					local Holder = Instance.new("Frame")
					Holder.Name = name .. "_CircleHolder"
					Holder.LayoutOrder = order
					Holder.Size = UDim2.new(1, 0, 0, 96)
					Holder.BackgroundTransparency = 1
					Holder.Parent = scroll

					local CircleBtn = Instance.new("TextButton")
					CircleBtn.Size = UDim2.new(0, 90, 0, 90)
					CircleBtn.Position = UDim2.new(0, 14, 0.5, -45)
					CircleBtn.Text = name
					CircleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
					CircleBtn.Font = Enum.Font.GothamBold
					CircleBtn.TextSize = 13
					CircleBtn.TextStrokeTransparency = 1
					CircleBtn.AutoButtonColor = false
					CircleBtn.Parent = Holder
					addCorner(CircleBtn, 45)
					local cStroke = addStroke(CircleBtn, Library.Theme.Accent, 1.5, 0.10)
					applyButtonGradient(CircleBtn, false)
					attachButtonFX(CircleBtn, cStroke)

					CircleBtn.MouseButton1Click:Connect(function()
						task.spawn(callback)
					end)

					if cfg.ResetName or cfg.ResetCallback then
						local ResetBtn = Instance.new("TextButton")
						ResetBtn.Size = UDim2.new(0, 76, 0, 30)
						ResetBtn.Position = UDim2.new(0, 124, 0.5, -15)
						ResetBtn.Text = cfg.ResetName or "Reset"
						ResetBtn.TextColor3 = Color3.fromRGB(240, 245, 255)
						ResetBtn.Font = Enum.Font.GothamMedium
						ResetBtn.TextSize = 13
						ResetBtn.TextStrokeTransparency = 1
						ResetBtn.AutoButtonColor = false
						ResetBtn.Parent = Holder
						addCorner(ResetBtn, 6)
						local rStroke = addStroke(ResetBtn, Color3.fromRGB(50, 56, 76), 1.2, 0.3)
						applyButtonGradient(ResetBtn, false)
						attachButtonFX(ResetBtn, rStroke)
						ResetBtn.MouseButton1Click:Connect(function()
							if cfg.ResetCallback then task.spawn(cfg.ResetCallback) end
						end)
					end
					return CircleBtn
				end

				local Btn = Instance.new("TextButton")
				Btn.Name = name .. "_Button"
				Btn.LayoutOrder = order
				Btn.Size = UDim2.new(1, 0, 0, 38)
				Btn.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
				Btn.BackgroundTransparency = 0.35
				Btn.Text = ""
				Btn.AutoButtonColor = false
				Btn.Parent = scroll
				addCorner(Btn, 7)
				local btnStroke = addStroke(Btn, Color3.fromRGB(46, 52, 70), 1.0, 0.40)

				local TitleLbl = Instance.new("TextLabel")
				TitleLbl.Size = UDim2.new(1, -44, 1, 0)
				TitleLbl.Position = UDim2.new(0, 12, 0, 0)
				TitleLbl.BackgroundTransparency = 1
				TitleLbl.Text = name
				TitleLbl.TextColor3 = Color3.fromRGB(240, 245, 255)
				TitleLbl.Font = Enum.Font.GothamMedium
				TitleLbl.TextSize = 13
				TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
				TitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
				TitleLbl.Parent = Btn

				local IconPill = Instance.new("Frame")
				IconPill.Size = UDim2.new(0, 26, 0, 24)
				IconPill.Position = UDim2.new(1, -34, 0.5, -12)
				IconPill.BackgroundColor3 = Color3.fromRGB(38, 44, 64)
				IconPill.BackgroundTransparency = 0.2
				IconPill.BorderSizePixel = 0
				IconPill.Parent = Btn
				addCorner(IconPill, 5)
				local iconStroke = addStroke(IconPill, Library.Theme.Accent, 1, 0.4)

				local Arrow = Instance.new("TextLabel")
				Arrow.Size = UDim2.new(1, 0, 1, 0)
				Arrow.BackgroundTransparency = 1
				Arrow.Text = ">"
				Arrow.TextColor3 = Library.Theme.Accent
				Arrow.Font = Enum.Font.GothamBold
				Arrow.TextSize = 13
				Arrow.TextStrokeTransparency = 1
				Arrow.Parent = IconPill

				Btn.MouseEnter:Connect(function()
					tween(Btn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(36, 42, 58), BackgroundTransparency = 0.15 })
					btnStroke.Color = Library.Theme.Accent
					btnStroke.Transparency = 0.15
					tween(IconPill, TweenInfo.new(0.12), { BackgroundColor3 = Library.Theme.Accent, BackgroundTransparency = 0 })
					Arrow.TextColor3 = Color3.fromRGB(255, 255, 255)
				end)
				Btn.MouseLeave:Connect(function()
					tween(Btn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(30, 34, 46), BackgroundTransparency = 0.35 })
					btnStroke.Color = Color3.fromRGB(46, 52, 70)
					btnStroke.Transparency = 0.40
					tween(IconPill, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(38, 44, 64), BackgroundTransparency = 0.2 })
					Arrow.TextColor3 = Library.Theme.Accent
				end)

				Btn.MouseButton1Click:Connect(function()
					tween(Btn, TweenInfo.new(0.06), { BackgroundColor3 = Color3.fromRGB(48, 58, 86) })
					task.delay(0.08, function()
						tween(Btn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(36, 42, 58) })
					end)
					task.spawn(callback)
				end)

				local BtnObj = {}
				function BtnObj:Set(newText)
					TitleLbl.Text = tostring(newText)
				end
				BtnObj.UpdateButton = BtnObj.Set
				return BtnObj
			end
			Methods.CreateButton = Methods.AddButton
			Methods.MakeButton   = Methods.AddButton
			Methods.NewButton    = Methods.AddButton
			Methods.Button       = Methods.AddButton
			Methods.addButton    = Methods.AddButton

			function Methods:AddDualButton(cfg)
				cfg = cfg or {}
				local scroll, order = resolveScroll(cfg.Column, 1)

				local Row = Instance.new("Frame")
				Row.LayoutOrder = order
				Row.Size = UDim2.new(1, 0, 0, 38)
				Row.BackgroundTransparency = 1
				Row.Parent = scroll

				local function makeHalfBtn(txt, xScale, cb)
					local b = Instance.new("TextButton")
					b.Size = UDim2.new(0.485, 0, 1, 0)
					b.Position = UDim2.new(xScale, 0, 0, 0)
					b.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
					b.BackgroundTransparency = 0.35
					b.Text = txt
					b.TextColor3 = Color3.fromRGB(240, 245, 255)
					b.Font = Enum.Font.GothamMedium
					b.TextSize = 13
					b.TextStrokeTransparency = 1
					b.TextTruncate = Enum.TextTruncate.AtEnd
					b.AutoButtonColor = false
					b.Parent = Row
					addCorner(b, 7)
					local st = addStroke(b, Color3.fromRGB(46, 52, 70), 1.0, 0.40)

					b.MouseEnter:Connect(function()
						tween(b, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(36, 42, 58), BackgroundTransparency = 0.15 })
						st.Color = Library.Theme.Accent
						st.Transparency = 0.15
					end)
					b.MouseLeave:Connect(function()
						tween(b, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(30, 34, 46), BackgroundTransparency = 0.35 })
						st.Color = Color3.fromRGB(46, 52, 70)
						st.Transparency = 0.40
					end)
					b.MouseButton1Click:Connect(function()
						if cb then task.spawn(cb) end
					end)
					return b
				end

				local b1 = makeHalfBtn(cfg.Name1 or "Button 1", 0, cfg.Callback1)
				local b2 = makeHalfBtn(cfg.Name2 or "Button 2", 0.515, cfg.Callback2)
				return b1, b2
			end
			Methods.CreateDualButton = Methods.AddDualButton

			function Methods:AddApplyButton(cfg)
				cfg = cfg or {}
				cfg.Style = "Circle"
				cfg.Name = cfg.Name or "Apply\nSettings"
				cfg.ResetName = cfg.ResetName or "Reset"
				return self:AddButton(cfg)
			end
			Methods.CreateApplyButton = Methods.AddApplyButton

			function Methods.AddDropdown(selfOrA, a, b, c, d)
				local cfg = (selfOrA == Methods or type(selfOrA) == "table" and selfOrA.AddDropdown)
					and normalizeArgs("Dropdown", a, b, c, d)
					or normalizeArgs("Dropdown", selfOrA, a, b, c)

				local name     = cfg.Name or cfg.Title or "Dropdown"
				local options  = cfg.Options or cfg.List or cfg.Values or { "Option 1", "Option 2" }
				local rawDef   = cfg.Default or cfg.CurrentOption or options[1] or ""
				local default  = type(rawDef) == "table" and (rawDef[1] or "") or rawDef
				local callback = cfg.Callback or function() end
				local flag     = cfg.Flag

				local savedKey = (flag and flag ~= "") and flag or name
				if savedKey and Library.ConfigStore[savedKey] ~= nil then
					default = tostring(Library.ConfigStore[savedKey])
				end

				local scroll, order = resolveScroll(cfg.Column, 1.4)

				local Container = Instance.new("Frame")
				Container.Name = name .. "_Dropdown"
				Container.LayoutOrder = order
				Container.Size = UDim2.new(1, 0, 0, 38)
				Container.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
				Container.BackgroundTransparency = 0.35
				Container.ClipsDescendants = true
				Container.Parent = scroll
				addCorner(Container, 7)
				local contStroke = addStroke(Container, Color3.fromRGB(46, 52, 70), 1.0, 0.40)

				local TitleLbl = Instance.new("TextLabel")
				TitleLbl.Size = UDim2.new(0.48, -8, 0, 38)
				TitleLbl.Position = UDim2.new(0, 12, 0, 0)
				TitleLbl.BackgroundTransparency = 1
				TitleLbl.Text = name
				TitleLbl.TextColor3 = Color3.fromRGB(240, 245, 255)
				TitleLbl.Font = Enum.Font.GothamMedium
				TitleLbl.TextSize = 13
				TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
				TitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
				TitleLbl.Parent = Container

				local MainBox = Instance.new("TextButton")
				MainBox.Size = UDim2.new(0.48, 0, 0, 26)
				MainBox.Position = UDim2.new(0.52, -6, 0, 6)
				MainBox.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
				MainBox.BackgroundTransparency = 0.25
				MainBox.Text = ""
				MainBox.AutoButtonColor = false
				MainBox.Parent = Container
				addCorner(MainBox, 5)
				local boxStroke = addStroke(MainBox, Color3.fromRGB(46, 52, 70), 1.0, 0.35)

				local SelectedLbl = Instance.new("TextLabel")
				SelectedLbl.Size = UDim2.new(1, -22, 1, 0)
				SelectedLbl.Position = UDim2.new(0, 8, 0, 0)
				SelectedLbl.BackgroundTransparency = 1
				SelectedLbl.Text = tostring(default)
				SelectedLbl.TextColor3 = Color3.fromRGB(225, 235, 255)
				SelectedLbl.Font = Enum.Font.GothamMedium
				SelectedLbl.TextSize = 12
				SelectedLbl.TextXAlignment = Enum.TextXAlignment.Left
				SelectedLbl.TextTruncate = Enum.TextTruncate.AtEnd
				SelectedLbl.Parent = MainBox

				local ArrowLbl = Instance.new("TextLabel")
				ArrowLbl.Size = UDim2.new(0, 18, 1, 0)
				ArrowLbl.Position = UDim2.new(1, -20, 0, 0)
				ArrowLbl.BackgroundTransparency = 1
				ArrowLbl.Text = "v"
				ArrowLbl.TextColor3 = Library.Theme.Accent
				ArrowLbl.Font = Enum.Font.GothamBold
				ArrowLbl.TextSize = 11
				ArrowLbl.Parent = MainBox

				local OptionHolder = Instance.new("ScrollingFrame")
				OptionHolder.Size = UDim2.new(1, -16, 0, 96)
				OptionHolder.Position = UDim2.new(0, 8, 0, 40)
				OptionHolder.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
				OptionHolder.BackgroundTransparency = 0.15
				OptionHolder.BorderSizePixel = 0
				OptionHolder.ScrollBarThickness = 4
				OptionHolder.ScrollBarImageColor3 = Library.Theme.Accent
				OptionHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
				OptionHolder.Parent = Container
				addCorner(OptionHolder, 6)
				addStroke(OptionHolder, Color3.fromRGB(46, 52, 70), 1, 0.35)

				local OptLayout = Instance.new("UIListLayout")
				OptLayout.SortOrder = Enum.SortOrder.LayoutOrder
				OptLayout.Padding = UDim.new(0, 3)
				OptLayout.Parent = OptionHolder
				addPadding(OptionHolder, 4, 4, 4, 6)

				local isOpen = false
				local changedListeners = {}
				local DropdownObj = { Value = default, Options = options, Type = "Dropdown" }

				function DropdownObj:OnChanged(fn)
					if type(fn) == "function" then
						table.insert(changedListeners, fn)
					end
				end

				local function toggleOpen(state)
					isOpen = state
					local listH = math.min(#DropdownObj.Options * 27 + 8, 114)
					OptionHolder.Size = UDim2.new(1, -16, 0, listH)
					OptionHolder.CanvasSize = UDim2.new(0, 0, 0, #DropdownObj.Options * 27 + 8)
					ArrowLbl.Text = isOpen and "^" or "v"
					if isOpen then
						boxStroke.Color = Library.Theme.Accent
						boxStroke.Transparency = 0.1
					else
						boxStroke.Color = Color3.fromRGB(46, 52, 70)
						boxStroke.Transparency = 0.35
					end
					tween(Container, TweenInfo.new(0.18), {
						Size = UDim2.new(1, 0, 0, isOpen and (48 + listH) or 38)
					})
				end

				function DropdownObj:Set(val)
					if type(val) == "table" then val = val[1] end
					DropdownObj.Value = val
					if savedKey then
						Library.ConfigStore[savedKey] = tostring(val or "")
						scheduleAutoSave()
					end
					SelectedLbl.Text = tostring(val or "")
					task.spawn(callback, val)
					for _, fn in ipairs(changedListeners) do
						task.spawn(fn, val)
					end
				end
				DropdownObj.SetValue = DropdownObj.Set

				function DropdownObj:Refresh(newOptions, clearCurrent)
					DropdownObj.Options = newOptions or {}
					for _, ch in ipairs(OptionHolder:GetChildren()) do
						if ch:IsA("TextButton") then ch:Destroy() end
					end
					for i, opt in ipairs(DropdownObj.Options) do
						local OptBtn = Instance.new("TextButton")
						OptBtn.LayoutOrder = i
						OptBtn.Size = UDim2.new(1, 0, 0, 24)
						OptBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
						OptBtn.BackgroundTransparency = 0.3
						OptBtn.Text = tostring(opt)
						OptBtn.TextColor3 = Color3.fromRGB(220, 230, 250)
						OptBtn.Font = Enum.Font.GothamMedium
						OptBtn.TextSize = 12
						OptBtn.TextTruncate = Enum.TextTruncate.AtEnd
						OptBtn.AutoButtonColor = false
						OptBtn.Parent = OptionHolder
						addCorner(OptBtn, 4)

						OptBtn.MouseEnter:Connect(function()
							tween(OptBtn, TweenInfo.new(0.12), { BackgroundTransparency = 0, BackgroundColor3 = Library.Theme.Accent, TextColor3 = Color3.fromRGB(255, 255, 255) })
						end)
						OptBtn.MouseLeave:Connect(function()
							tween(OptBtn, TweenInfo.new(0.12), { BackgroundTransparency = 0.3, BackgroundColor3 = Color3.fromRGB(28, 32, 44), TextColor3 = Color3.fromRGB(220, 230, 250) })
						end)

						OptBtn.MouseButton1Click:Connect(function()
							DropdownObj:Set(opt)
							toggleOpen(false)
						end)
					end
					if clearCurrent then
						SelectedLbl.Text = "..."
						DropdownObj.Value = nil
					end
				end
				DropdownObj.SetValues = DropdownObj.Refresh

				MainBox.MouseButton1Click:Connect(function()
					toggleOpen(not isOpen)
				end)

				DropdownObj:Refresh(options, false)
				if default ~= "" then
					DropdownObj:Set(default)
				end
				registerFlag(flag, name, DropdownObj)
				return DropdownObj
			end
			Methods.CreateDropdown = Methods.AddDropdown
			Methods.MakeDropdown   = Methods.AddDropdown
			Methods.NewDropdown    = Methods.AddDropdown
			Methods.Dropdown       = Methods.AddDropdown
			Methods.addDropdown    = Methods.AddDropdown

			function Methods.AddColorpicker(selfOrA, a, b, c, d)
				local cfg = (selfOrA == Methods or type(selfOrA) == "table" and selfOrA.AddColorpicker)
					and normalizeArgs("Colorpicker", a, b, c, d)
					or normalizeArgs("Colorpicker", selfOrA, a, b, c)

				local name     = cfg.Name or cfg.Title or "Color Picker"
				local default  = cfg.Default or cfg.Color or Color3.fromRGB(85, 115, 250)
				local callback = cfg.Callback or function() end
				local flag     = cfg.Flag

				local savedKey = (flag and flag ~= "") and flag or name
				if savedKey and Library.ConfigStore[savedKey] ~= nil then
					default = deserializeValue(Library.ConfigStore[savedKey]) or default
				end

				local scroll, order = resolveScroll(cfg.Column, 1.2)

				local Container = Instance.new("Frame")
				Container.Name = name .. "_Colorpicker"
				Container.LayoutOrder = order
				Container.Size = UDim2.new(1, 0, 0, 38)
				Container.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
				Container.BackgroundTransparency = 0.35
				Container.ClipsDescendants = true
				Container.Parent = scroll
				addCorner(Container, 7)
				addStroke(Container, Color3.fromRGB(46, 52, 70), 1.0, 0.40)

				local TitleLbl = Instance.new("TextLabel")
				TitleLbl.Size = UDim2.new(1, -66, 0, 38)
				TitleLbl.Position = UDim2.new(0, 12, 0, 0)
				TitleLbl.BackgroundTransparency = 1
				TitleLbl.Text = name
				TitleLbl.TextColor3 = Color3.fromRGB(240, 245, 255)
				TitleLbl.Font = Enum.Font.GothamMedium
				TitleLbl.TextSize = 13
				TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
				TitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
				TitleLbl.Parent = Container

				local PreviewBtn = Instance.new("TextButton")
				PreviewBtn.Size = UDim2.new(0, 46, 0, 22)
				PreviewBtn.Position = UDim2.new(1, -56, 0, 8)
				PreviewBtn.BackgroundColor3 = default
				PreviewBtn.BackgroundTransparency = 0.05
				PreviewBtn.Text = ""
				PreviewBtn.AutoButtonColor = false
				PreviewBtn.Parent = Container
				addCorner(PreviewBtn, 5)
				local prevStroke = addStroke(PreviewBtn, Color3.fromRGB(255, 255, 255), 1.2, 0.25)

				local Drawer = Instance.new("Frame")
				Drawer.Size = UDim2.new(1, -20, 0, 56)
				Drawer.Position = UDim2.new(0, 10, 0, 40)
				Drawer.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
				Drawer.BackgroundTransparency = 0.2
				Drawer.Parent = Container
				addCorner(Drawer, 6)
				addStroke(Drawer, Color3.fromRGB(46, 52, 70), 1, 0.35)

				local RainbowTrack = Instance.new("TextButton")
				RainbowTrack.Size = UDim2.new(1, -20, 0, 14)
				RainbowTrack.Position = UDim2.new(0, 10, 0, 8)
				RainbowTrack.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				RainbowTrack.AutoButtonColor = false
				RainbowTrack.Text = ""
				RainbowTrack.Parent = Drawer
				addCorner(RainbowTrack, 7)
				addStroke(RainbowTrack, Color3.fromRGB(48, 54, 72), 1, 0.4)

				local RainbowGrad = Instance.new("UIGradient")
				RainbowGrad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
					ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
					ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
					ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
					ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
					ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
				})
				RainbowGrad.Parent = RainbowTrack

				local initH, _, _ = Color3.toHSV(default)
				local Knob = Instance.new("Frame")
				Knob.Size = UDim2.new(0, 16, 0, 16)
				Knob.AnchorPoint = Vector2.new(0.5, 0.5)
				Knob.Position = UDim2.new(initH, 0, 0.5, 0)
				Knob.BackgroundColor3 = default
				Knob.BorderSizePixel = 0
				Knob.ZIndex = 68
				Knob.Parent = RainbowTrack
				addCorner(Knob, 8)
				addStroke(Knob, Color3.fromRGB(255, 255, 255), 1.8, 0)

				local SwatchesFrame = Instance.new("Frame")
				SwatchesFrame.Size = UDim2.new(1, -20, 0, 20)
				SwatchesFrame.Position = UDim2.new(0, 10, 0, 28)
				SwatchesFrame.BackgroundTransparency = 1
				SwatchesFrame.Parent = Drawer

				local SwatchLayout = Instance.new("UIListLayout")
				SwatchLayout.FillDirection = Enum.FillDirection.Horizontal
				SwatchLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				SwatchLayout.VerticalAlignment = Enum.VerticalAlignment.Center
				SwatchLayout.SortOrder = Enum.SortOrder.LayoutOrder
				SwatchLayout.Padding = UDim.new(0, 6)
				SwatchLayout.Parent = SwatchesFrame

				local presets = {
					Color3.fromRGB(255, 255, 255),
					Color3.fromRGB(180, 185, 195),
					Color3.fromRGB(75, 80, 95),
					Color3.fromRGB(18, 20, 26),
					Color3.fromRGB(255, 60, 60),
					Color3.fromRGB(255, 150, 40),
					Color3.fromRGB(255, 220, 45),
					Color3.fromRGB(45, 215, 95),
					Color3.fromRGB(45, 200, 255),
					Color3.fromRGB(85, 115, 250),
					Color3.fromRGB(185, 75, 255),
				}

				local changedListeners = {}
				local ColorObj = { Value = default, Type = "Colorpicker" }

				function ColorObj:OnChanged(fn)
					if type(fn) == "function" then
						table.insert(changedListeners, fn)
					end
				end

				function ColorObj:Set(col)
					if typeof(col) == "Color3" then
						ColorObj.Value = col
						if savedKey then
							Library.ConfigStore[savedKey] = serializeValue(col)
							scheduleAutoSave()
						end
						PreviewBtn.BackgroundColor3 = col
						local h, s, v = Color3.toHSV(col)
						Knob.Position = UDim2.new(h, 0, 0.5, 0)
						Knob.BackgroundColor3 = col
						task.spawn(callback, col)
						for _, fn in ipairs(changedListeners) do
							task.spawn(fn, col)
						end
					end
				end
				ColorObj.SetValue = ColorObj.Set

				for i, pcol in ipairs(presets) do
					local SwatchBtn = Instance.new("TextButton")
					SwatchBtn.LayoutOrder = i
					SwatchBtn.Size = UDim2.new(0, 18, 0, 18)
					SwatchBtn.BackgroundColor3 = pcol
					SwatchBtn.Text = ""
					SwatchBtn.AutoButtonColor = false
					SwatchBtn.Parent = SwatchesFrame
					addCorner(SwatchBtn, 5)
					addStroke(SwatchBtn, Color3.fromRGB(255, 255, 255), 1, 0.4)

					SwatchBtn.MouseButton1Click:Connect(function()
						ColorObj:Set(pcol)
					end)
				end

				local draggingRainbow = false
				local function updateRainbow(inp)
					local p = math.clamp((inp.Position.X - RainbowTrack.AbsolutePosition.X) / math.max(1, RainbowTrack.AbsoluteSize.X), 0, 1)
					local newCol = Color3.fromHSV(p, 1, 1)
					ColorObj:Set(newCol)
				end

				RainbowTrack.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
						draggingRainbow = true
						updateRainbow(inp)
					end
				end)
				UserInputService.InputEnded:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
						draggingRainbow = false
					end
				end)
				UserInputService.InputChanged:Connect(function(inp)
					if draggingRainbow and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
						updateRainbow(inp)
					end
				end)

				local open = false
				local function toggleDrawer()
					open = not open
					tween(Container, TweenInfo.new(0.18), {
						Size = UDim2.new(1, 0, 0, open and 104 or 38)
					})
				end

				PreviewBtn.MouseButton1Click:Connect(toggleDrawer)

				registerFlag(flag, name, ColorObj)
				return ColorObj
			end
			Methods.AddColorPicker    = Methods.AddColorpicker
			Methods.CreateColorpicker = Methods.AddColorpicker
			Methods.CreateColorPicker = Methods.AddColorpicker
			Methods.NewColorPicker    = Methods.AddColorpicker
			Methods.Colorpicker       = Methods.AddColorpicker
			Methods.addColorPicker    = Methods.AddColorpicker

			function Methods.AddBind(selfOrA, a, b, c, d)
				local cfg = (selfOrA == Methods or type(selfOrA) == "table" and selfOrA.AddBind)
					and normalizeArgs("Bind", a, b, c, d)
					or normalizeArgs("Bind", selfOrA, a, b, c)

				local name     = cfg.Name or cfg.Title or "Keybind"
				local default  = resolveKeyItem(cfg.Default or cfg.CurrentKeybind) or Enum.KeyCode.X
				local hold     = cfg.Hold or cfg.HoldToInteract or false
				local callback = cfg.Callback or function() end
				local flag     = cfg.Flag

				local savedKey = (flag and flag ~= "") and flag or name
				if savedKey and Library.ConfigStore[savedKey] ~= nil then
					default = deserializeValue(Library.ConfigStore[savedKey]) or default
				end

				local scroll, order = resolveScroll(cfg.Column, 1)

				local Row = Instance.new("Frame")
				Row.Name = name .. "_Bind"
				Row.LayoutOrder = order
				Row.Size = UDim2.new(1, 0, 0, 38)
				Row.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
				Row.BackgroundTransparency = 0.35
				Row.Parent = scroll
				addCorner(Row, 7)
				local rowStroke = addStroke(Row, Color3.fromRGB(46, 52, 70), 1.0, 0.40)

				local Lbl = Instance.new("TextLabel")
				Lbl.Size = UDim2.new(1, -96, 1, 0)
				Lbl.Position = UDim2.new(0, 12, 0, 0)
				Lbl.BackgroundTransparency = 1
				Lbl.Text = name
				Lbl.TextColor3 = Color3.fromRGB(240, 245, 255)
				Lbl.Font = Enum.Font.GothamMedium
				Lbl.TextSize = 13
				Lbl.TextXAlignment = Enum.TextXAlignment.Left
				Lbl.TextTruncate = Enum.TextTruncate.AtEnd
				Lbl.Parent = Row

				local BindBtn = Instance.new("TextButton")
				BindBtn.Size = UDim2.new(0, 80, 0, 26)
				BindBtn.Position = UDim2.new(1, -88, 0.5, -13)
				BindBtn.BackgroundColor3 = Color3.fromRGB(44, 52, 76)
				BindBtn.BackgroundTransparency = 0.05
				BindBtn.Text = "[ " .. formatKeyName(default) .. " ]"
				BindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				BindBtn.Font = Enum.Font.GothamBold
				BindBtn.TextSize = 12
				BindBtn.TextStrokeTransparency = 1
				BindBtn.AutoButtonColor = false
				BindBtn.Parent = Row
				addCorner(BindBtn, 6)
				local bindStroke = addStroke(BindBtn, Color3.fromRGB(85, 120, 245), 1.2, 0.10)

				local currentKey = default
				local binding = false
				local changedListeners = {}
				local BindObj = { Value = currentKey, Type = "Bind" }

				function BindObj:OnChanged(fn)
					if type(fn) == "function" then
						table.insert(changedListeners, fn)
					end
				end

				function BindObj:Get()
					return currentKey
				end

				function BindObj:Set(newKey)
					currentKey = resolveKeyItem(newKey)
					BindObj.Value = currentKey
					if savedKey then
						Library.ConfigStore[savedKey] = serializeValue(currentKey)
						scheduleAutoSave()
					end
					BindBtn.Text = "[ " .. formatKeyName(currentKey) .. " ]"
					for _, fn in ipairs(changedListeners) do
						task.spawn(fn, currentKey)
					end
				end
				BindObj.SetValue = BindObj.Set

				BindBtn.MouseEnter:Connect(function()
					if not binding then
						tween(BindBtn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(56, 68, 98), BackgroundTransparency = 0 })
						bindStroke.Color = Color3.fromRGB(120, 160, 255)
						bindStroke.Transparency = 0.0
					end
				end)
				BindBtn.MouseLeave:Connect(function()
					if not binding then
						tween(BindBtn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(44, 52, 76), BackgroundTransparency = 0.05 })
						bindStroke.Color = Color3.fromRGB(85, 120, 245)
						bindStroke.Transparency = 0.10
					end
				end)

				BindBtn.MouseButton1Click:Connect(function()
					binding = true
					BindBtn.Text = "[ ... ]"
					BindBtn.BackgroundColor3 = Color3.fromRGB(65, 80, 120)
					bindStroke.Transparency = 0.0
					bindStroke.Color = Color3.fromRGB(160, 205, 255)
				end)

				UserInputService.InputBegan:Connect(function(input, gp)
					if binding then
						if input.UserInputType == Enum.UserInputType.Keyboard then
							binding = false
							tween(BindBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(44, 52, 76), BackgroundTransparency = 0.05 })
							bindStroke.Color = Color3.fromRGB(85, 120, 245)
							bindStroke.Transparency = 0.10
							if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
								BindObj:Set(nil)
							else
								BindObj:Set(input.KeyCode)
							end
						elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
							binding = false
							tween(BindBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(44, 52, 76), BackgroundTransparency = 0.05 })
							bindStroke.Color = Color3.fromRGB(85, 120, 245)
							bindStroke.Transparency = 0.10
							BindObj:Set(input.UserInputType)
						end
						return
					end
					if not gp and currentKey and (input.KeyCode == currentKey or input.UserInputType == currentKey) then
						if hold then
							task.spawn(callback, true)
						else
							task.spawn(callback, currentKey)
						end
					end
				end)

				UserInputService.InputEnded:Connect(function(input, gp)
					if not gp and hold and currentKey and (input.KeyCode == currentKey or input.UserInputType == currentKey) then
						task.spawn(callback, false)
					end
				end)

				registerFlag(flag, name, BindObj)
				return BindObj
			end
			Methods.CreateBind    = Methods.AddBind
			Methods.AddKeybind    = Methods.AddBind
			Methods.CreateKeybind = Methods.AddBind
			Methods.NewKeybind    = Methods.AddBind
			Methods.Bind          = Methods.AddBind
			Methods.Keybind       = Methods.AddBind
			Methods.addKeybind    = Methods.AddBind

			function Methods.AddTextbox(selfOrA, a, b, c, d)
				local cfg = (selfOrA == Methods or type(selfOrA) == "table" and selfOrA.AddTextbox)
					and normalizeArgs("Textbox", a, b, c, d)
					or normalizeArgs("Textbox", selfOrA, a, b, c)

				local name        = cfg.Name or cfg.Title or "Input"
				local default     = cfg.Default or ""
				local placeholder = cfg.Placeholder or cfg.PlaceholderText or "Text..."
				local disappear   = cfg.TextDisappear or cfg.RemoveTextAfterFocusLost or false
				local callback    = cfg.Callback or function() end
				local flag        = cfg.Flag

				local savedKey = (flag and flag ~= "") and flag or name
				if savedKey and Library.ConfigStore[savedKey] ~= nil then
					default = tostring(Library.ConfigStore[savedKey])
				end

				local scroll, order = resolveScroll(cfg.Column, 1.4)

				local Container = Instance.new("Frame")
				Container.Name = name .. "_Textbox"
				Container.LayoutOrder = order
				Container.Size = UDim2.new(1, 0, 0, 38)
				Container.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
				Container.BackgroundTransparency = 0.35
				Container.Parent = scroll
				addCorner(Container, 7)
				local contStroke = addStroke(Container, Color3.fromRGB(46, 52, 70), 1.0, 0.40)

				local Lbl = Instance.new("TextLabel")
				Lbl.Size = UDim2.new(0.48, -8, 1, 0)
				Lbl.Position = UDim2.new(0, 12, 0, 0)
				Lbl.BackgroundTransparency = 1
				Lbl.Text = name
				Lbl.TextColor3 = Color3.fromRGB(240, 245, 255)
				Lbl.Font = Enum.Font.GothamMedium
				Lbl.TextSize = 13
				Lbl.TextXAlignment = Enum.TextXAlignment.Left
				Lbl.TextTruncate = Enum.TextTruncate.AtEnd
				Lbl.Parent = Container

				local Box = Instance.new("TextBox")
				Box.Size = UDim2.new(0.48, 0, 0, 26)
				Box.Position = UDim2.new(0.52, -6, 0.5, -13)
				Box.BackgroundColor3 = Color3.fromRGB(20, 23, 31)
				Box.BackgroundTransparency = 0.25
				Box.Text = tostring(default)
				Box.PlaceholderText = placeholder
				Box.PlaceholderColor3 = Color3.fromRGB(120, 130, 150)
				Box.TextColor3 = Color3.fromRGB(255, 255, 255)
				Box.Font = Enum.Font.GothamMedium
				Box.TextSize = 12
				Box.TextXAlignment = Enum.TextXAlignment.Left
				Box.ClearTextOnFocus = false
				Box.Parent = Container
				addCorner(Box, 5)
				local boxStroke = addStroke(Box, Color3.fromRGB(46, 52, 70), 1.0, 0.35)
				addPadding(Box, 0, 0, 8, 8)

				local TextboxObj = { Value = default, Type = "Textbox" }

				function TextboxObj:Set(txt)
					Box.Text = tostring(txt)
					TextboxObj.Value = Box.Text
					if savedKey then
						Library.ConfigStore[savedKey] = Box.Text
						scheduleAutoSave()
					end
					task.spawn(callback, Box.Text)
				end
				TextboxObj.SetValue = TextboxObj.Set

				Box.Focused:Connect(function()
					boxStroke.Color = Library.Theme.Accent
					boxStroke.Transparency = 0.0
				end)
				Box.FocusLost:Connect(function()
					boxStroke.Color = Color3.fromRGB(46, 52, 70)
					boxStroke.Transparency = 0.35
					TextboxObj.Value = Box.Text
					if savedKey then
						Library.ConfigStore[savedKey] = Box.Text
						scheduleAutoSave()
					end
					task.spawn(callback, Box.Text)
					if disappear then
						Box.Text = ""
					end
				end)

				registerFlag(flag, name, TextboxObj)
				return TextboxObj
			end
			Methods.CreateTextbox = Methods.AddTextbox
			Methods.CreateInput   = Methods.AddTextbox
			Methods.AddInput      = Methods.AddTextbox
			Methods.NewTextBox    = Methods.AddTextbox
			Methods.Textbox       = Methods.AddTextbox
			Methods.Input         = Methods.AddTextbox
			Methods.addTextbox    = Methods.AddTextbox

			function Methods.AddLabel(selfOrText, maybeText)
				local text = (selfOrText == Methods or type(selfOrText) == "table" and selfOrText.AddLabel) and maybeText or selfOrText
				if type(text) == "table" then text = text.Name or text.Text or text.Title or "" end
				local scroll, order = resolveScroll(nil, 0.7)

				local Lbl = Instance.new("TextLabel")
				Lbl.LayoutOrder = order
				Lbl.Size = UDim2.new(1, 0, 0, 22)
				Lbl.BackgroundTransparency = 1
				Lbl.Text = tostring(text or "")
				Lbl.TextColor3 = Color3.fromRGB(190, 200, 220)
				Lbl.Font = Enum.Font.GothamMedium
				Lbl.TextSize = 13
				Lbl.TextXAlignment = Enum.TextXAlignment.Left
				Lbl.TextTruncate = Enum.TextTruncate.AtEnd
				Lbl.Parent = scroll
				addPadding(Lbl, 0, 0, 4, 4)

				local LabelObj = {}
				function LabelObj:Set(newText)
					Lbl.Text = tostring(newText)
				end
				LabelObj.UpdateLabel = LabelObj.Set
				LabelObj.SetText     = LabelObj.Set
				return LabelObj
			end
			Methods.CreateLabel = Methods.AddLabel
			Methods.NewLabel    = Methods.AddLabel
			Methods.Label       = Methods.AddLabel
			Methods.addLabel    = Methods.AddLabel

			function Methods.AddParagraph(selfOrTitle, a, b)
				local title, content
				if selfOrTitle == Methods or (type(selfOrTitle) == "table" and selfOrTitle.AddParagraph) then
					title, content = a, b
				else
					title, content = selfOrTitle, a
				end
				if type(title) == "table" then
					content = title.Content or title.Text or ""
					title = title.Title or title.Name or "Info"
				end
				local scroll, order = resolveScroll(nil, 1.5)

				local Box = Instance.new("Frame")
				Box.LayoutOrder = order
				Box.Size = UDim2.new(1, 0, 0, 56)
				Box.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
				Box.BackgroundTransparency = 0.35
				Box.Parent = scroll
				addCorner(Box, 7)
				addStroke(Box, Color3.fromRGB(46, 52, 70), 1.0, 0.40)

				local T = Instance.new("TextLabel")
				T.Size = UDim2.new(1, -20, 0, 18)
				T.Position = UDim2.new(0, 10, 0, 6)
				T.BackgroundTransparency = 1
				T.Text = tostring(title or "Info")
				T.TextColor3 = Color3.fromRGB(240, 245, 255)
				T.Font = Enum.Font.GothamBold
				T.TextSize = 13
				T.TextXAlignment = Enum.TextXAlignment.Left
				T.TextTruncate = Enum.TextTruncate.AtEnd
				T.Parent = Box

				local C = Instance.new("TextLabel")
				C.Size = UDim2.new(1, -20, 1, -28)
				C.Position = UDim2.new(0, 10, 0, 26)
				C.BackgroundTransparency = 1
				C.Text = tostring(content or "")
				C.TextColor3 = Color3.fromRGB(160, 170, 195)
				C.Font = Enum.Font.Gotham
				C.TextSize = 11
				C.TextWrapped = true
				C.TextXAlignment = Enum.TextXAlignment.Left
				C.TextYAlignment = Enum.TextYAlignment.Top
				C.Parent = Box

				local ParaObj = {}
				function ParaObj:Set(newTitle, newContent)
					if type(newTitle) == "table" then
						newContent = newTitle.Content or newTitle.Text
						newTitle = newTitle.Title or newTitle.Name
					end
					if newTitle then T.Text = tostring(newTitle) end
					if newContent then C.Text = tostring(newContent) end
				end
				return ParaObj
			end
			Methods.CreateParagraph = Methods.AddParagraph
			Methods.Paragraph       = Methods.AddParagraph

			function Methods:AddDivider()
				local scroll, order = resolveScroll(nil, 0.3)
				local Div = Instance.new("Frame")
				Div.LayoutOrder = order
				Div.Size = UDim2.new(1, 0, 0, 1)
				Div.BackgroundColor3 = Color3.fromRGB(46, 52, 70)
				Div.BackgroundTransparency = 0.5
				Div.BorderSizePixel = 0
				Div.Parent = scroll
				return Div
			end
			Methods.CreateDivider = Methods.AddDivider
			Methods.AddSeparator  = Methods.AddDivider

			return Methods
		end

		local TabObj = createMethodsForTarget(function(explicitCol, weightCost)
			return getTargetScroll(explicitCol, weightCost)
		end)

		local function addSectionInternal(secConfig, forcedColumn)
			if type(secConfig) == "string" then
				secConfig = { Name = secConfig }
			end
			secConfig = secConfig or {}
			local secName = secConfig.Name or secConfig.Title or ("Section " .. tostring(sectionCounter + 1))

			if sectionCounter == 0 and Columns[1].ItemCount > 0 then
				sectionCounter = 1
				Columns[1].HasCustomTitle = true
			end
			sectionCounter = sectionCounter + 1
			local targetColIdx = forcedColumn or secConfig.Column
			if not targetColIdx then
				if sectionCounter <= 3 then
					targetColIdx = sectionCounter
				else
					targetColIdx = getShortestColumnIndex()
				end
			end
			targetColIdx = math.clamp(targetColIdx, 1, 3)
			currentColumnIndex = targetColIdx

			local col = Columns[targetColIdx]
			if not col.HasCustomTitle and col.ItemCount == 0 then
				col.HeaderTitle.Text = secName
				col.HasCustomTitle = true
				col.Header.Visible = true
				col.Scroll.Size = UDim2.new(1, -14, 1, -42)
				col.Scroll.Position = UDim2.new(0, 2, 0, 36)
				if col.Rail then
					col.Rail.Position = UDim2.new(1, -12, 0, 36)
					col.Rail.Size = UDim2.new(0, 8, 1, -42)
				end
			else
				col.ItemCount = col.ItemCount + 1
				col.Weight = col.Weight + 0.9
				local SubHdr = Instance.new("Frame")
				SubHdr.LayoutOrder = col.ItemCount
				SubHdr.Size = UDim2.new(1, 0, 0, 24)
				SubHdr.BackgroundTransparency = 1
				SubHdr.BorderSizePixel = 0
				SubHdr.Parent = col.Scroll

				local AccentBar = Instance.new("Frame")
				AccentBar.Size = UDim2.new(0, 3, 0, 14)
				AccentBar.Position = UDim2.new(0, 4, 0.5, -7)
				AccentBar.BackgroundColor3 = Library.Theme.Accent
				AccentBar.BorderSizePixel = 0
				AccentBar.Parent = SubHdr
				addCorner(AccentBar, 2)

				local SubTxt = Instance.new("TextLabel")
				SubTxt.Size = UDim2.new(1, -18, 1, 0)
				SubTxt.Position = UDim2.new(0, 14, 0, 0)
				SubTxt.BackgroundTransparency = 1
				SubTxt.Text = string.upper(secName)
				SubTxt.TextColor3 = Color3.fromRGB(160, 175, 205)
				SubTxt.Font = Enum.Font.GothamBold
				SubTxt.TextSize = 11
				SubTxt.TextXAlignment = Enum.TextXAlignment.Left
				SubTxt.TextTruncate = Enum.TextTruncate.AtEnd
				SubTxt.Parent = SubHdr
			end

			updateResponsiveColumns()

			local SectionObj = createMethodsForTarget(function(explicitCol, weightCost)
				return getTargetScroll(explicitCol or targetColIdx, weightCost)
			end)
			return SectionObj
		end

		function TabObj.AddSection(selfOrSec, maybeSec)
			local cfg = (selfOrSec == TabObj) and maybeSec or selfOrSec
			return addSectionInternal(cfg, nil)
		end
		TabObj.CreateSection = TabObj.AddSection
		TabObj.MakeSection   = TabObj.AddSection
		TabObj.NewSection    = TabObj.AddSection
		TabObj.Section       = TabObj.AddSection
		TabObj.addSection    = TabObj.AddSection
		TabObj.AddGroupbox   = TabObj.AddSection

		function TabObj.AddLeftGroupbox(selfOrSec, maybeSec)
			local cfg = (selfOrSec == TabObj) and maybeSec or selfOrSec
			return addSectionInternal(cfg, 1)
		end
		function TabObj.AddRightGroupbox(selfOrSec, maybeSec)
			local cfg = (selfOrSec == TabObj) and maybeSec or selfOrSec
			local colIdx = (Columns[2].ItemCount <= Columns[3].ItemCount) and 2 or 3
			return addSectionInternal(cfg, colIdx)
		end

		TabObj._setVisual = setTabVisual

		TabBtn.MouseEnter:Connect(function()
			if WindowObj.ActiveTab ~= TabObj then
				tween(TabBtn, TweenInfo.new(0.12), { BackgroundTransparency = 0.35, BackgroundColor3 = Color3.fromRGB(30, 34, 48) })
				tween(TabStroke, TweenInfo.new(0.12), { Transparency = 0.25, Color = Library.Theme.Accent })
				tween(TabLabel, TweenInfo.new(0.12), { TextColor3 = Color3.fromRGB(240, 245, 255) })
			end
		end)
		TabBtn.MouseLeave:Connect(function()
			if WindowObj.ActiveTab ~= TabObj then
				tween(TabBtn, TweenInfo.new(0.12), { BackgroundTransparency = 0.85, BackgroundColor3 = Color3.fromRGB(22, 24, 32) })
				tween(TabStroke, TweenInfo.new(0.12), { Transparency = 0.6, Color = Color3.fromRGB(36, 40, 52) })
				tween(TabLabel, TweenInfo.new(0.12), { TextColor3 = Color3.fromRGB(160, 170, 190) })
			end
		end)

		TabBtn.MouseButton1Click:Connect(function()
			for _, t in ipairs(WindowObj.Tabs) do
				t._setVisual(t == TabObj)
			end
			WindowObj.ActiveTab = TabObj
		end)

		table.insert(WindowObj.Tabs, TabObj)
		if #WindowObj.Tabs == 1 then
			setTabVisual(true)
			WindowObj.ActiveTab = TabObj
		else
			setTabVisual(false)
		end

		return TabObj
	end

	function WindowObj:SelectTab(targetTab)
		if not targetTab then return end
		for _, t in ipairs(self.Tabs) do
			if t._setVisual then
				t._setVisual(t == targetTab)
			end
		end
		self.ActiveTab = targetTab
	end

	WindowObj.CreateTab = WindowObj.MakeTab
	WindowObj.AddTab    = WindowObj.MakeTab
	WindowObj.NewTab    = WindowObj.MakeTab
	WindowObj.Tab       = WindowObj.MakeTab
	WindowObj.addPage   = WindowObj.MakeTab
	WindowObj.AddPage   = WindowObj.MakeTab

	local function getOrMakeDefaultTab()
		if #WindowObj.Tabs == 0 then
			WindowObj:MakeTab({ Name = "Main" })
		end
		return WindowObj.Tabs[1]
	end
	for _, methodName in ipairs({
		"AddSection", "CreateSection", "NewSection",
		"AddToggle", "CreateToggle", "NewToggle",
		"AddSlider", "CreateSlider", "NewSlider",
		"AddButton", "CreateButton", "NewButton",
		"AddDropdown", "CreateDropdown", "NewDropdown",
		"AddColorpicker", "CreateColorPicker", "NewColorPicker",
		"AddBind", "CreateBind", "NewKeybind", "AddKeybind", "CreateKeybind",
		"AddTextbox", "CreateInput", "NewTextBox",
		"AddLabel", "CreateLabel", "NewLabel",
		"AddParagraph", "CreateParagraph"
	}) do
		if not WindowObj[methodName] then
			WindowObj[methodName] = function(self, ...)
				local tab = getOrMakeDefaultTab()
				return tab[methodName](tab, ...)
			end
		end
	end

	do
		local SettingsWin = Instance.new("Frame")
		SettingsWin.Name = "NightSystem_SettingsWindow"
		SettingsWin.AnchorPoint = Vector2.new(0.5, 0.5)
		SettingsWin.Size = UDim2.new(0, 500, 0, 440)
		SettingsWin.Position = UDim2.new(0.5, 25, 0.5, 15)
		SettingsWin.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
		SettingsWin.BackgroundTransparency = 0.04
		SettingsWin.BorderSizePixel = 0
		SettingsWin.ClipsDescendants = true
		SettingsWin.Visible = false
		SettingsWin.ZIndex = 60
		SettingsWin.Parent = ScreenGui
		addCorner(SettingsWin, 10)
		local setWinStroke = addStroke(SettingsWin, Color3.fromRGB(48, 52, 70), 1.2, 0.20)

		local SettingsScale = Instance.new("UIScale")
		SettingsScale.Scale = 0.01
		SettingsScale.Parent = SettingsWin

		local isSettingsOpen = false
		local isAnimatingSettings = false
		local currentSetTab = "General"
		local switchSetTab = nil

		local function openSettingsAnimated()
			if isAnimatingSettings or isSettingsOpen then return end
			isAnimatingSettings = true
			isSettingsOpen = true
			SettingsWin.Visible = true
			if switchSetTab then
				switchSetTab(currentSetTab or "General")
			end
			SettingsScale.Scale = 0.02
			SettingsWin.BackgroundTransparency = 0.8
			tween(SettingsWin, TweenInfo.new(0.20), { BackgroundTransparency = 0.04 })
			local step1 = tween(SettingsScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.05 })
			step1.Completed:Connect(function()
				local step2 = tween(SettingsScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Scale = 1.0 })
				step2.Completed:Connect(function()
					isAnimatingSettings = false
				end)
			end)
		end

		local function closeSettingsAnimated()
			if isAnimatingSettings or not isSettingsOpen then return end
			isAnimatingSettings = true
			isSettingsOpen = false
			local step1 = tween(SettingsScale, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.06 })
			step1.Completed:Connect(function()
				tween(SettingsWin, TweenInfo.new(0.24), { BackgroundTransparency = 0.9 })
				local step2 = tween(SettingsScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.01 })
				step2.Completed:Connect(function()
					SettingsWin.Visible = false
					isAnimatingSettings = false
				end)
			end)
		end

		local function toggleSettingsAnimated()
			if isSettingsOpen then
				closeSettingsAnimated()
			else
				openSettingsAnimated()
			end
		end

		toggleSettingsWindow = toggleSettingsAnimated
		WindowObj.ToggleSettings = toggleSettingsAnimated
		WindowObj.OpenSettings = openSettingsAnimated
		WindowObj.CloseSettings = closeSettingsAnimated
		WindowObj.SettingsWindow = SettingsWin

		local SetTitleBar = Instance.new("Frame")
		SetTitleBar.Name = "SetTitleBar"
		SetTitleBar.Size = UDim2.new(1, 0, 0, 40)
		SetTitleBar.BackgroundTransparency = 1
		SetTitleBar.ZIndex = 62
		SetTitleBar.Parent = SettingsWin

		local SetTitleDivider = Instance.new("Frame")
		SetTitleDivider.Size = UDim2.new(1, 0, 0, 1)
		SetTitleDivider.Position = UDim2.new(0, 0, 1, -1)
		SetTitleDivider.BackgroundColor3 = Color3.fromRGB(38, 42, 55)
		SetTitleDivider.BackgroundTransparency = 0.4
		SetTitleDivider.BorderSizePixel = 0
		SetTitleDivider.Parent = SetTitleBar

		local SetLogo = Instance.new("ImageLabel")
		SetLogo.Size = UDim2.new(0, 22, 0, 22)
		SetLogo.Position = UDim2.new(0, 12, 0.5, -11)
		SetLogo.BackgroundTransparency = 1
		SetLogo.Image = LOGO_ASSET
		SetLogo.ScaleType = Enum.ScaleType.Fit
		SetLogo.ZIndex = 63
		SetLogo.Parent = SetTitleBar

		local SetTitleText = Instance.new("TextLabel")
		SetTitleText.Size = UDim2.new(1, -160, 1, 0)
		SetTitleText.Position = UDim2.new(0, 40, 0, 0)
		SetTitleText.BackgroundTransparency = 1
		SetTitleText.Text = "NightSystem — Settings"
		SetTitleText.TextColor3 = Color3.fromRGB(245, 248, 255)
		SetTitleText.Font = Enum.Font.GothamBold
		SetTitleText.TextSize = 14
		SetTitleText.TextXAlignment = Enum.TextXAlignment.Left
		SetTitleText.TextStrokeTransparency = 1
		SetTitleText.ZIndex = 63
		SetTitleText.Parent = SetTitleBar

		local SetResetBtn = Instance.new("TextButton")
		SetResetBtn.Size = UDim2.new(0, 58, 0, 24)
		SetResetBtn.Position = UDim2.new(1, -98, 0.5, -12)
		SetResetBtn.BackgroundColor3 = Color3.fromRGB(54, 40, 78)
		SetResetBtn.BackgroundTransparency = 0.12
		SetResetBtn.BorderSizePixel = 0
		SetResetBtn.Text = "Reset"
		SetResetBtn.TextColor3 = Color3.fromRGB(235, 225, 255)
		SetResetBtn.Font = Enum.Font.GothamBold
		SetResetBtn.TextSize = 11
		SetResetBtn.AutoButtonColor = false
		SetResetBtn.ZIndex = 64
		SetResetBtn.Parent = SetTitleBar
		addCorner(SetResetBtn, 6)
		local setResetStroke = addStroke(SetResetBtn, Color3.fromRGB(155, 110, 235), 1.0, 0.20)

		local setResetScale = Instance.new("UIScale")
		setResetScale.Scale = 1
		setResetScale.Parent = SetResetBtn

		SetResetBtn.MouseEnter:Connect(function()
			tween(SetResetBtn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(88, 62, 135), BackgroundTransparency = 0 })
			setResetStroke.Color = Color3.fromRGB(200, 160, 255)
			setResetStroke.Transparency = 0
			tween(setResetScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.06 })
		end)
		SetResetBtn.MouseLeave:Connect(function()
			tween(SetResetBtn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(54, 40, 78), BackgroundTransparency = 0.12 })
			setResetStroke.Color = Color3.fromRGB(155, 110, 235)
			setResetStroke.Transparency = 0.20
			tween(setResetScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 })
		end)

		local SetCloseBtn = Instance.new("TextButton")
		SetCloseBtn.Size = UDim2.new(0, 28, 0, 24)
		SetCloseBtn.Position = UDim2.new(1, -34, 0.5, -12)
		SetCloseBtn.BackgroundColor3 = Color3.fromRGB(44, 30, 38)
		SetCloseBtn.BackgroundTransparency = 0.15
		SetCloseBtn.BorderSizePixel = 0
		SetCloseBtn.Text = ""
		SetCloseBtn.AutoButtonColor = false
		SetCloseBtn.ZIndex = 64
		SetCloseBtn.Parent = SetTitleBar
		addCorner(SetCloseBtn, 6)
		local setCloseStroke = addStroke(SetCloseBtn, Color3.fromRGB(205, 55, 75), 1.0, 0.20)

		local sBarV = Instance.new("Frame")
		sBarV.Size = UDim2.new(0, 4, 0, 13)
		sBarV.AnchorPoint = Vector2.new(0.5, 0.5)
		sBarV.Position = UDim2.new(0.5, 0, 0.5, 0)
		sBarV.BackgroundColor3 = Color3.fromRGB(255, 160, 175)
		sBarV.BorderSizePixel = 0
		sBarV.ZIndex = 65
		sBarV.Parent = SetCloseBtn
		addCorner(sBarV, 1)

		local sBarH = Instance.new("Frame")
		sBarH.Size = UDim2.new(0, 13, 0, 4)
		sBarH.AnchorPoint = Vector2.new(0.5, 0.5)
		sBarH.Position = UDim2.new(0.5, 0, 0.5, 0)
		sBarH.BackgroundColor3 = Color3.fromRGB(255, 160, 175)
		sBarH.BorderSizePixel = 0
		sBarH.ZIndex = 65
		sBarH.Parent = SetCloseBtn
		addCorner(sBarH, 1)

		local setCloseScale = Instance.new("UIScale")
		setCloseScale.Scale = 1
		setCloseScale.Parent = SetCloseBtn

		SetCloseBtn.MouseEnter:Connect(function()
			tween(SetCloseBtn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(235, 60, 80), BackgroundTransparency = 0 })
			setCloseStroke.Color = Color3.fromRGB(255, 120, 140)
			setCloseStroke.Transparency = 0
			sBarV.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			sBarH.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			tween(setCloseScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 })
		end)
		SetCloseBtn.MouseLeave:Connect(function()
			tween(SetCloseBtn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(44, 30, 38), BackgroundTransparency = 0.15 })
			setCloseStroke.Color = Color3.fromRGB(205, 55, 75)
			setCloseStroke.Transparency = 0.20
			sBarV.BackgroundColor3 = Color3.fromRGB(255, 160, 175)
			sBarH.BackgroundColor3 = Color3.fromRGB(255, 160, 175)
			tween(setCloseScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 })
		end)
		SetCloseBtn.MouseButton1Click:Connect(closeSettingsAnimated)

		do
			local draggingSet, dragInputSet, dragStartSet, startPosSet
			SetTitleBar.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingSet = true
					dragStartSet = input.Position
					startPosSet = SettingsWin.Position
					input.Changed:Connect(function()
						if input.UserInputState == Enum.UserInputState.End then
							draggingSet = false
						end
					end)
				end
			end)
			SetTitleBar.InputChanged:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					dragInputSet = input
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if input == dragInputSet and draggingSet then
					local delta = input.Position - dragStartSet
					SettingsWin.Position = UDim2.new(
						startPosSet.X.Scale,
						startPosSet.X.Offset + delta.X,
						startPosSet.Y.Scale,
						startPosSet.Y.Offset + delta.Y
					)
				end
			end)
		end

		local SetTabBar = Instance.new("Frame")
		SetTabBar.Name = "SetTabBar"
		SetTabBar.Size = UDim2.new(1, 0, 0, 36)
		SetTabBar.Position = UDim2.new(0, 0, 0, 40)
		SetTabBar.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
		SetTabBar.BackgroundTransparency = 0.4
		SetTabBar.BorderSizePixel = 0
		SetTabBar.ZIndex = 62
		SetTabBar.Parent = SettingsWin

		local SetTabDivider = Instance.new("Frame")
		SetTabDivider.Name = "SetTabDivider"
		SetTabDivider.Size = UDim2.new(1, 0, 0, 1)
		SetTabDivider.Position = UDim2.new(0, 0, 0, 76)
		SetTabDivider.BackgroundColor3 = Color3.fromRGB(38, 42, 55)
		SetTabDivider.BackgroundTransparency = 0.4
		SetTabDivider.BorderSizePixel = 0
		SetTabDivider.ZIndex = 62
		SetTabDivider.Parent = SettingsWin

		local SetTabLayout = Instance.new("UIListLayout")
		SetTabLayout.FillDirection = Enum.FillDirection.Horizontal
		SetTabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		SetTabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		SetTabLayout.Padding = UDim.new(0, 6)
		SetTabLayout.Parent = SetTabBar

		local SetContent = Instance.new("Frame")
		SetContent.Name = "SetContent"
		SetContent.Size = UDim2.new(1, -16, 1, -84)
		SetContent.Position = UDim2.new(0, 8, 0, 78)
		SetContent.BackgroundTransparency = 1
		SetContent.BorderSizePixel = 0
		SetContent.ZIndex = 62
		SetContent.Parent = SettingsWin

		currentSetTab = "General"
		local setTabs = {}
		local setScrolls = {}

		local function createSetTabScroll(name)
			local scroll = Instance.new("ScrollingFrame")
			scroll.Name = "SetScroll_" .. name
			scroll.Size = UDim2.new(1, 0, 1, 0)
			scroll.Position = UDim2.new(0, 0, 0, 0)
			scroll.BackgroundTransparency = 1
			scroll.BorderSizePixel = 0
			scroll.ScrollBarThickness = 4
			scroll.ScrollBarImageColor3 = Library.Theme.Accent
			scroll.CanvasSize = UDim2.new(0, 0, 0, 450)
			scroll.ZIndex = 62
			scroll.Visible = false
			scroll.Parent = SetContent

			local layout = Instance.new("UIListLayout")
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Padding = UDim.new(0, 6)
			layout.Parent = scroll

			addPadding(scroll, 4, 4, 4, 4)

			local function updateScrollCanvas()
				scroll.CanvasSize = UDim2.new(0, 0, 0, math.max(layout.AbsoluteContentSize.Y + 24, 450))
			end

			layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateScrollCanvas)

			setScrolls[name] = scroll
			return scroll
		end

		local generalScroll = createSetTabScroll("General")
		local crosshairScroll = createSetTabScroll("Crosshair")
		local aimFovScroll = createSetTabScroll("Aim FOV")
		local aimbotScroll = createSetTabScroll("Aimbot")

		switchSetTab = function(tabName)
			currentSetTab = tabName
			for name, btn in pairs(setTabs) do
				local isActive = (name == tabName)
				local stroke = btn:FindFirstChildOfClass("UIStroke")
				local scale = btn:FindFirstChildOfClass("UIScale")
				if isActive then
					tween(btn, TweenInfo.new(0.16), {
						BackgroundColor3 = Color3.fromRGB(52, 42, 78),
						TextColor3 = Color3.fromRGB(255, 255, 255)
					})
					if stroke then
						stroke.Color = Color3.fromRGB(160, 115, 245)
						stroke.Transparency = 0.1
					end
					if scale then
						tween(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.03 })
					end
				else
					tween(btn, TweenInfo.new(0.16), {
						BackgroundColor3 = Color3.fromRGB(28, 30, 40),
						TextColor3 = Color3.fromRGB(165, 175, 200)
					})
					if stroke then
						stroke.Color = Color3.fromRGB(45, 50, 68)
						stroke.Transparency = 0.35
					end
					if scale then
						tween(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 })
					end
				end
			end
			for name, scroll in pairs(setScrolls) do
				local isVis = (name == tabName)
				scroll.Visible = isVis
				if isVis then
					local l = scroll:FindFirstChildOfClass("UIListLayout")
					if l then
						scroll.CanvasSize = UDim2.new(0, 0, 0, math.max(l.AbsoluteContentSize.Y + 24, 420))
					end
				end
			end
		end

		local function createSetTabBtn(name, icon, label)
			local btn = Instance.new("TextButton")
			btn.Name = "TabBtn_" .. name
			btn.Size = UDim2.new(0, 114, 0, 26)
			btn.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
			btn.BackgroundTransparency = 0.25
			btn.BorderSizePixel = 0
			btn.Text = icon .. " " .. label
			btn.TextColor3 = Color3.fromRGB(165, 175, 200)
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 11
			btn.AutoButtonColor = false
			btn.ZIndex = 63
			btn.Parent = SetTabBar
			addCorner(btn, 6)
			local stroke = addStroke(btn, Color3.fromRGB(45, 50, 68), 1.0, 0.35)

			local scale = Instance.new("UIScale")
			scale.Scale = 1
			scale.Parent = btn

			btn.MouseEnter:Connect(function()
				if currentSetTab ~= name then
					tween(btn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(36, 40, 56), TextColor3 = Color3.fromRGB(210, 220, 245) })
					stroke.Color = Color3.fromRGB(65, 75, 105)
					tween(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.02 })
				end
			end)
			btn.MouseLeave:Connect(function()
				if currentSetTab ~= name then
					tween(btn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(28, 30, 40), TextColor3 = Color3.fromRGB(165, 175, 200) })
					stroke.Color = Color3.fromRGB(45, 50, 68)
					tween(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 })
				end
			end)

			btn.MouseButton1Click:Connect(function()
				switchSetTab(name)
			end)
			btn.Activated:Connect(function()
				switchSetTab(name)
			end)

			setTabs[name] = btn
			return btn
		end

		createSetTabBtn("General", "⚙", "General")
		createSetTabBtn("Crosshair", "⌖", "Crosshair")
		createSetTabBtn("Aim FOV", "◎", "Aim FOV")
		createSetTabBtn("Aimbot", "⚡", "Aimbot")

		switchSetTab("General")

		local setOrder = 0
		local function nextOrder()
			setOrder = setOrder + 1
			return setOrder
		end

		local function addSetSection(name, parent)
			local hdr = Instance.new("Frame")
			hdr.LayoutOrder = nextOrder()
			hdr.Size = UDim2.new(1, 0, 0, 24)
			hdr.BackgroundTransparency = 1
			hdr.BorderSizePixel = 0
			hdr.ZIndex = 63
			hdr.Parent = parent or generalScroll

			local bar = Instance.new("Frame")
			bar.Size = UDim2.new(0, 3, 0, 14)
			bar.Position = UDim2.new(0, 4, 0.5, -7)
			bar.BackgroundColor3 = Library.Theme.Accent
			bar.BorderSizePixel = 0
			bar.ZIndex = 63
			bar.Parent = hdr
			addCorner(bar, 2)

			local txt = Instance.new("TextLabel")
			txt.Size = UDim2.new(1, -18, 1, 0)
			txt.Position = UDim2.new(0, 14, 0, 0)
			txt.BackgroundTransparency = 1
			txt.Text = string.upper(name)
			txt.TextColor3 = Color3.fromRGB(160, 175, 205)
			txt.Font = Enum.Font.GothamBold
			txt.TextSize = 11
			txt.TextXAlignment = Enum.TextXAlignment.Left
			txt.TextTruncate = Enum.TextTruncate.AtEnd
			txt.ZIndex = 63
			txt.Parent = hdr
		end

		local function addSetToggle(name, default, callback, parent)
			local RowBtn = Instance.new("TextButton")
			RowBtn.LayoutOrder = nextOrder()
			RowBtn.Size = UDim2.new(1, 0, 0, 38)
			RowBtn.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
			RowBtn.BackgroundTransparency = 0.35
			RowBtn.Text = ""
			RowBtn.AutoButtonColor = false
			RowBtn.ZIndex = 63
			RowBtn.Parent = parent or generalScroll
			addCorner(RowBtn, 7)
			local rowStroke = addStroke(RowBtn, Color3.fromRGB(46, 52, 70), 1.0, 0.40)

			local Lbl = Instance.new("TextLabel")
			Lbl.Size = UDim2.new(1, -54, 1, 0)
			Lbl.Position = UDim2.new(0, 12, 0, 0)
			Lbl.BackgroundTransparency = 1
			Lbl.Text = name
			Lbl.TextColor3 = Color3.fromRGB(240, 245, 255)
			Lbl.Font = Enum.Font.GothamMedium
			Lbl.TextSize = 13
			Lbl.TextXAlignment = Enum.TextXAlignment.Left
			Lbl.TextTruncate = Enum.TextTruncate.AtEnd
			Lbl.ZIndex = 64
			Lbl.Parent = RowBtn

			local Pill = Instance.new("Frame")
			Pill.Size = UDim2.new(0, 36, 0, 20)
			Pill.Position = UDim2.new(1, -44, 0.5, -10)
			Pill.BorderSizePixel = 0
			Pill.ZIndex = 64
			Pill.Parent = RowBtn
			addCorner(Pill, 10)
			local pillStroke = addStroke(Pill, Color3.fromRGB(56, 62, 80), 1.0, 0.35)

			local Knob = Instance.new("Frame")
			Knob.Size = UDim2.new(0, 14, 0, 14)
			Knob.Position = UDim2.new(0, 3, 0.5, -7)
			Knob.BorderSizePixel = 0
			Knob.ZIndex = 65
			Knob.Parent = Pill
			addCorner(Knob, 7)

			local state = not not default
			local ToggleObj = { Value = state }

			local function updatePill()
				if state then
					tween(Pill, nil, { BackgroundColor3 = Library.Theme.Accent, BackgroundTransparency = 0.05 })
					tween(Knob, nil, { Position = UDim2.new(1, -17, 0.5, -7), BackgroundColor3 = Color3.fromRGB(255, 255, 255) })
					pillStroke.Color = Color3.fromRGB(120, 160, 255)
				else
					tween(Pill, nil, { BackgroundColor3 = Color3.fromRGB(42, 46, 60), BackgroundTransparency = 0.45 })
					tween(Knob, nil, { Position = UDim2.new(0, 3, 0.5, -7), BackgroundColor3 = Color3.fromRGB(160, 170, 190) })
					pillStroke.Color = Color3.fromRGB(56, 62, 80)
				end
			end

			function ToggleObj:Set(val)
				state = not not val
				ToggleObj.Value = state
				updatePill()
				if callback then task.spawn(callback, state) end
			end

			RowBtn.MouseEnter:Connect(function()
				tween(RowBtn, nil, { BackgroundColor3 = Color3.fromRGB(36, 42, 58), BackgroundTransparency = 0.20 })
				rowStroke.Color = Color3.fromRGB(65, 75, 105)
			end)
			RowBtn.MouseLeave:Connect(function()
				tween(RowBtn, nil, { BackgroundColor3 = Color3.fromRGB(30, 34, 46), BackgroundTransparency = 0.35 })
				rowStroke.Color = Color3.fromRGB(46, 52, 70)
			end)

			RowBtn.MouseButton1Click:Connect(function()
				ToggleObj:Set(not state)
			end)

			updatePill()
			if default and callback then task.spawn(callback, default) end
			return ToggleObj
		end

		local function addSetSlider(name, minVal, maxVal, defaultVal, callback, parent)
			local Container = Instance.new("Frame")
			Container.LayoutOrder = nextOrder()
			Container.Size = UDim2.new(1, 0, 0, 50)
			Container.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
			Container.BackgroundTransparency = 0.35
			Container.Active = true
			Container.ZIndex = 63
			Container.Parent = parent or generalScroll
			addCorner(Container, 7)
			local contStroke = addStroke(Container, Color3.fromRGB(46, 52, 70), 1.0, 0.40)

			local TitleLbl = Instance.new("TextLabel")
			TitleLbl.Size = UDim2.new(1, -76, 0, 16)
			TitleLbl.Position = UDim2.new(0, 12, 0, 6)
			TitleLbl.BackgroundTransparency = 1
			TitleLbl.Text = name
			TitleLbl.TextColor3 = Color3.fromRGB(240, 245, 255)
			TitleLbl.Font = Enum.Font.GothamMedium
			TitleLbl.TextSize = 13
			TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
			TitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
			TitleLbl.Active = false
			TitleLbl.ZIndex = 64
			TitleLbl.Parent = Container

			local ValBadge = Instance.new("TextLabel")
			ValBadge.Size = UDim2.new(0, 60, 0, 16)
			ValBadge.Position = UDim2.new(1, -72, 0, 6)
			ValBadge.BackgroundTransparency = 1
			ValBadge.Text = tostring(defaultVal)
			ValBadge.TextColor3 = Color3.fromRGB(200, 205, 218)
			ValBadge.Font = Enum.Font.GothamMedium
			ValBadge.TextSize = 12
			ValBadge.TextXAlignment = Enum.TextXAlignment.Right
			ValBadge.Active = false
			ValBadge.ZIndex = 64
			ValBadge.Parent = Container

			-- Abgerundeter, viereckiger Track (Höhe 14px, Corner 4px)
			local Track = Instance.new("Frame")
			Track.Size = UDim2.new(1, -24, 0, 14)
			Track.Position = UDim2.new(0, 12, 0, 26)
			Track.BackgroundColor3 = Color3.fromRGB(32, 33, 38)
			Track.BorderSizePixel = 0
			Track.ClipsDescendants = true
			Track.Active = false
			Track.ZIndex = 64
			Track.Parent = Container
			addCorner(Track, 4)
			addStroke(Track, Color3.fromRGB(46, 48, 56), 1.0, 0.40)

			local Fill = Instance.new("Frame")
			Fill.Size = UDim2.new(math.clamp((defaultVal - minVal) / math.max(1, maxVal - minVal), 0, 1), 0, 1, 0)
			Fill.BackgroundColor3 = Color3.fromRGB(64, 66, 75)
			Fill.BorderSizePixel = 0
			Fill.ZIndex = 65
			Fill.Active = false
			Fill.Parent = Track
			addCorner(Fill, 4)

			-- Punkte (9 Punkte)
			local Ticks = Instance.new("Frame")
			Ticks.Size = UDim2.new(1, 0, 1, 0)
			Ticks.BackgroundTransparency = 1
			Ticks.BorderSizePixel = 0
			Ticks.ZIndex = 66
			Ticks.Active = false
			Ticks.Parent = Track

			for i = 1, 9 do
				local dot = Instance.new("Frame")
				dot.Name = "Dot_" .. i
				dot.Size = UDim2.new(0, 3, 0, 3)
				dot.AnchorPoint = Vector2.new(0.5, 0.5)
				dot.Position = UDim2.new(i * 0.1, 0, 0.5, 0)
				dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				dot.BackgroundTransparency = 0.65
				dot.BorderSizePixel = 0
				dot.ZIndex = 66
				dot.Active = false
				dot.Parent = Ticks
				addCorner(dot, 2)
			end

			-- Vertikaler weißer Strich als Thumb
			local Thumb = Instance.new("Frame")
			Thumb.Size = UDim2.new(0, 3, 0, 9)
			Thumb.AnchorPoint = Vector2.new(0.5, 0.5)
			Thumb.Position = UDim2.new(0, 0, 0.5, 0)
			Thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			Thumb.BorderSizePixel = 0
			Thumb.ZIndex = 67
			Thumb.Active = false
			Thumb.Parent = Track
			addCorner(Thumb, 1)

			local currentVal = defaultVal
			local SliderObj = { Value = currentVal }
			local lastVal = nil

			function SliderObj:Set(val)
				local clamped = math.clamp(math.floor((tonumber(val) or minVal) + 0.5), minVal, maxVal)
				currentVal = clamped
				SliderObj.Value = clamped
				local p = (maxVal > minVal) and ((clamped - minVal) / (maxVal - minVal)) or 0
				Fill.Size = UDim2.new(p, 0, 1, 0)
				Thumb.Position = UDim2.new(p, math.clamp(math.floor((0.5 - p) * 6), -2, 2), 0.5, 0)
				ValBadge.Text = tostring(clamped)
				if clamped ~= lastVal then
					lastVal = clamped
					if callback then task.spawn(callback, clamped) end
				end
			end

			local isSliding = false
			local lastTouchPos = nil
			local dragConn = nil

			local function stopSliding()
				if isSliding then
					isSliding = false
					lastTouchPos = nil
					if dragConn then
						dragConn:Disconnect()
						dragConn = nil
					end
				end
			end

			local function updateFromCoordinate(xPos)
				local trackX = Track.AbsolutePosition.X
				local trackW = Track.AbsoluteSize.X
				if trackW > 0 then
					local p = math.clamp((xPos - trackX) / trackW, 0, 1)
					local val = math.floor(minVal + (maxVal - minVal) * p + 0.5)
					SliderObj:Set(val)
				end
			end

			local function startSliding(input)
				isSliding = true
				if input.UserInputType == Enum.UserInputType.Touch then
					lastTouchPos = input.Position.X
				end
				updateFromCoordinate(input.Position.X)

				if dragConn then dragConn:Disconnect() end
				dragConn = RunService.RenderStepped:Connect(function()
					if not isSliding or not Track or not Track.Parent then
						stopSliding()
						return
					end

					local isDown = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
					if not isDown and not lastTouchPos then
						stopSliding()
						return
					end

					local curX = lastTouchPos or Mouse.X
					updateFromCoordinate(curX)
				end)
			end

			Container.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					startSliding(input)
				end
			end)

			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					stopSliding()
				end
			end)

			UserInputService.InputChanged:Connect(function(input)
				if isSliding then
					if input.UserInputType == Enum.UserInputType.Touch then
						lastTouchPos = input.Position.X
						updateFromCoordinate(input.Position.X)
					elseif input.UserInputType == Enum.UserInputType.MouseMovement then
						updateFromCoordinate(input.Position.X)
					end
				end
			end)

			Container.Destroying:Connect(function()
				stopSliding()
			end)

			SliderObj:Set(defaultVal)
			return SliderObj
		end

		local function addSetDropdown(name, options, defaultVal, callback, parent)
			local Container = Instance.new("Frame")
			Container.LayoutOrder = nextOrder()
			Container.Size = UDim2.new(1, 0, 0, 38)
			Container.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
			Container.BackgroundTransparency = 0.35
			Container.ClipsDescendants = true
			Container.ZIndex = 63
			Container.Parent = parent or generalScroll
			addCorner(Container, 7)
			local contStroke = addStroke(Container, Color3.fromRGB(46, 52, 70), 1.0, 0.40)

			local TitleLbl = Instance.new("TextLabel")
			TitleLbl.Size = UDim2.new(0.48, -8, 0, 38)
			TitleLbl.Position = UDim2.new(0, 12, 0, 0)
			TitleLbl.BackgroundTransparency = 1
			TitleLbl.Text = name
			TitleLbl.TextColor3 = Color3.fromRGB(240, 245, 255)
			TitleLbl.Font = Enum.Font.GothamMedium
			TitleLbl.TextSize = 13
			TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
			TitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
			TitleLbl.ZIndex = 64
			TitleLbl.Parent = Container

			local MainBox = Instance.new("TextButton")
			MainBox.Size = UDim2.new(0.48, 0, 0, 26)
			MainBox.Position = UDim2.new(0.52, -6, 0, 6)
			MainBox.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
			MainBox.BackgroundTransparency = 0.25
			MainBox.Text = ""
			MainBox.AutoButtonColor = false
			MainBox.ZIndex = 64
			MainBox.Parent = Container
			addCorner(MainBox, 5)
			local boxStroke = addStroke(MainBox, Color3.fromRGB(46, 52, 70), 1.0, 0.35)

			local SelectedLbl = Instance.new("TextLabel")
			SelectedLbl.Size = UDim2.new(1, -22, 1, 0)
			SelectedLbl.Position = UDim2.new(0, 8, 0, 0)
			SelectedLbl.BackgroundTransparency = 1
			SelectedLbl.Text = tostring(defaultVal)
			SelectedLbl.TextColor3 = Color3.fromRGB(225, 235, 255)
			SelectedLbl.Font = Enum.Font.GothamMedium
			SelectedLbl.TextSize = 12
			SelectedLbl.TextXAlignment = Enum.TextXAlignment.Left
			SelectedLbl.TextTruncate = Enum.TextTruncate.AtEnd
			SelectedLbl.ZIndex = 65
			SelectedLbl.Parent = MainBox

			local ArrowLbl = Instance.new("TextLabel")
			ArrowLbl.Size = UDim2.new(0, 18, 1, 0)
			ArrowLbl.Position = UDim2.new(1, -20, 0, 0)
			ArrowLbl.BackgroundTransparency = 1
			ArrowLbl.Text = "v"
			ArrowLbl.TextColor3 = Library.Theme.Accent
			ArrowLbl.Font = Enum.Font.GothamBold
			ArrowLbl.TextSize = 11
			ArrowLbl.ZIndex = 65
			ArrowLbl.Parent = MainBox

			local OptionHolder = Instance.new("ScrollingFrame")
			OptionHolder.Size = UDim2.new(1, -16, 0, 96)
			OptionHolder.Position = UDim2.new(0, 8, 0, 40)
			OptionHolder.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
			OptionHolder.BackgroundTransparency = 0.15
			OptionHolder.BorderSizePixel = 0
			OptionHolder.ScrollBarThickness = 4
			OptionHolder.ScrollBarImageColor3 = Library.Theme.Accent
			OptionHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
			OptionHolder.ZIndex = 66
			OptionHolder.Parent = Container
			addCorner(OptionHolder, 6)
			addStroke(OptionHolder, Color3.fromRGB(46, 52, 70), 1, 0.35)

			local OptLayout = Instance.new("UIListLayout")
			OptLayout.SortOrder = Enum.SortOrder.LayoutOrder
			OptLayout.Padding = UDim.new(0, 3)
			OptLayout.Parent = OptionHolder
			addPadding(OptionHolder, 4, 4, 4, 6)

			local currentSelection = tostring(defaultVal)
			local DropdownObj = { Value = currentSelection }

			local isOpen = false
			local function toggleOpen(state)
				isOpen = state
				local listH = math.min(#options * 27 + 8, 114)
				OptionHolder.Size = UDim2.new(1, -16, 0, listH)
				OptionHolder.CanvasSize = UDim2.new(0, 0, 0, #options * 27 + 8)
				ArrowLbl.Text = isOpen and "^" or "v"
				boxStroke.Color = isOpen and Library.Theme.Accent or Color3.fromRGB(46, 52, 70)
				tween(Container, TweenInfo.new(0.18), {
					Size = UDim2.new(1, 0, 0, isOpen and (48 + listH) or 38)
				})
			end

			function DropdownObj:Set(opt)
				currentSelection = tostring(opt)
				DropdownObj.Value = currentSelection
				SelectedLbl.Text = currentSelection
				if callback then task.spawn(callback, currentSelection) end
			end

			for i, opt in ipairs(options) do
				local OptBtn = Instance.new("TextButton")
				OptBtn.LayoutOrder = i
				OptBtn.Size = UDim2.new(1, 0, 0, 24)
				OptBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
				OptBtn.BackgroundTransparency = 0.3
				OptBtn.Text = tostring(opt)
				OptBtn.TextColor3 = Color3.fromRGB(220, 230, 250)
				OptBtn.Font = Enum.Font.GothamMedium
				OptBtn.TextSize = 12
				OptBtn.TextTruncate = Enum.TextTruncate.AtEnd
				OptBtn.AutoButtonColor = false
				OptBtn.ZIndex = 67
				OptBtn.Parent = OptionHolder
				addCorner(OptBtn, 4)

				OptBtn.MouseEnter:Connect(function()
					tween(OptBtn, TweenInfo.new(0.12), { BackgroundTransparency = 0, BackgroundColor3 = Library.Theme.Accent, TextColor3 = Color3.fromRGB(255, 255, 255) })
				end)
				OptBtn.MouseLeave:Connect(function()
					tween(OptBtn, TweenInfo.new(0.12), { BackgroundTransparency = 0.3, BackgroundColor3 = Color3.fromRGB(28, 32, 44), TextColor3 = Color3.fromRGB(220, 230, 250) })
				end)
				OptBtn.MouseButton1Click:Connect(function()
					DropdownObj:Set(opt)
					toggleOpen(false)
				end)
			end

			MainBox.MouseButton1Click:Connect(function()
				toggleOpen(not isOpen)
			end)

			return DropdownObj
		end

		local function addSetColorpicker(name, defaultCol, callback, parent)
			local Container = Instance.new("Frame")
			Container.LayoutOrder = nextOrder()
			Container.Size = UDim2.new(1, 0, 0, 38)
			Container.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
			Container.BackgroundTransparency = 0.35
			Container.ClipsDescendants = true
			Container.ZIndex = 63
			Container.Parent = parent or generalScroll
			addCorner(Container, 7)
			addStroke(Container, Color3.fromRGB(46, 52, 70), 1.0, 0.40)

			local TitleLbl = Instance.new("TextLabel")
			TitleLbl.Size = UDim2.new(1, -66, 0, 38)
			TitleLbl.Position = UDim2.new(0, 12, 0, 0)
			TitleLbl.BackgroundTransparency = 1
			TitleLbl.Text = name
			TitleLbl.TextColor3 = Color3.fromRGB(240, 245, 255)
			TitleLbl.Font = Enum.Font.GothamMedium
			TitleLbl.TextSize = 13
			TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
			TitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
			TitleLbl.ZIndex = 64
			TitleLbl.Parent = Container

			local PreviewBtn = Instance.new("TextButton")
			PreviewBtn.Size = UDim2.new(0, 46, 0, 22)
			PreviewBtn.Position = UDim2.new(1, -56, 0, 8)
			PreviewBtn.BackgroundColor3 = defaultCol
			PreviewBtn.BackgroundTransparency = 0.05
			PreviewBtn.Text = ""
			PreviewBtn.AutoButtonColor = false
			PreviewBtn.ZIndex = 64
			PreviewBtn.Parent = Container
			addCorner(PreviewBtn, 5)
			addStroke(PreviewBtn, Color3.fromRGB(255, 255, 255), 1.2, 0.25)

			local Drawer = Instance.new("Frame")
			Drawer.Size = UDim2.new(1, -20, 0, 56)
			Drawer.Position = UDim2.new(0, 10, 0, 40)
			Drawer.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
			Drawer.BackgroundTransparency = 0.2
			Drawer.ZIndex = 64
			Drawer.Parent = Container
			addCorner(Drawer, 6)
			addStroke(Drawer, Color3.fromRGB(46, 52, 70), 1, 0.35)

			local RainbowTrack = Instance.new("TextButton")
			RainbowTrack.Size = UDim2.new(1, -20, 0, 14)
			RainbowTrack.Position = UDim2.new(0, 10, 0, 8)
			RainbowTrack.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			RainbowTrack.AutoButtonColor = false
			RainbowTrack.Text = ""
			RainbowTrack.ZIndex = 65
			RainbowTrack.Parent = Drawer
			addCorner(RainbowTrack, 7)
			addStroke(RainbowTrack, Color3.fromRGB(48, 54, 72), 1, 0.4)

			local RainbowGrad = Instance.new("UIGradient")
			RainbowGrad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
			})
			RainbowGrad.Parent = RainbowTrack

			local initH, _, _ = Color3.toHSV(defaultCol)
			local Knob = Instance.new("Frame")
			Knob.Size = UDim2.new(0, 16, 0, 16)
			Knob.AnchorPoint = Vector2.new(0.5, 0.5)
			Knob.Position = UDim2.new(initH, 0, 0.5, 0)
			Knob.BackgroundColor3 = defaultCol
			Knob.BorderSizePixel = 0
			Knob.ZIndex = 66
			Knob.Parent = RainbowTrack
			addCorner(Knob, 8)
			addStroke(Knob, Color3.fromRGB(255, 255, 255), 1.8, 0)

			local SwatchesFrame = Instance.new("Frame")
			SwatchesFrame.Size = UDim2.new(1, -20, 0, 20)
			SwatchesFrame.Position = UDim2.new(0, 10, 0, 28)
			SwatchesFrame.BackgroundTransparency = 1
			SwatchesFrame.ZIndex = 65
			SwatchesFrame.Parent = Drawer

			local SwatchLayout = Instance.new("UIListLayout")
			SwatchLayout.FillDirection = Enum.FillDirection.Horizontal
			SwatchLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			SwatchLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			SwatchLayout.SortOrder = Enum.SortOrder.LayoutOrder
			SwatchLayout.Padding = UDim.new(0, 6)
			SwatchLayout.Parent = SwatchesFrame

			local presets = {
				Color3.fromRGB(255, 255, 255),
				Color3.fromRGB(180, 185, 195),
				Color3.fromRGB(75, 80, 95),
				Color3.fromRGB(18, 20, 26),
				Color3.fromRGB(255, 60, 60),
				Color3.fromRGB(255, 150, 40),
				Color3.fromRGB(255, 220, 45),
				Color3.fromRGB(45, 215, 95),
				Color3.fromRGB(45, 200, 255),
				Color3.fromRGB(85, 115, 250),
				Color3.fromRGB(185, 75, 255),
			}

			local currentCol = defaultCol
			local ColorObj = { Value = currentCol }

			function ColorObj:Set(col)
				if typeof(col) == "Color3" then
					currentCol = col
					ColorObj.Value = col
					PreviewBtn.BackgroundColor3 = col
					local h, s, v = Color3.toHSV(col)
					Knob.Position = UDim2.new(h, 0, 0.5, 0)
					Knob.BackgroundColor3 = col
					if callback then task.spawn(callback, col) end
				end
			end

			for i, pcol in ipairs(presets) do
				local SwatchBtn = Instance.new("TextButton")
				SwatchBtn.LayoutOrder = i
				SwatchBtn.Size = UDim2.new(0, 18, 0, 18)
				SwatchBtn.BackgroundColor3 = pcol
				SwatchBtn.Text = ""
				SwatchBtn.AutoButtonColor = false
				SwatchBtn.ZIndex = 66
				SwatchBtn.Parent = SwatchesFrame
				addCorner(SwatchBtn, 5)
				addStroke(SwatchBtn, Color3.fromRGB(255, 255, 255), 1, 0.4)

				SwatchBtn.MouseButton1Click:Connect(function()
					ColorObj:Set(pcol)
				end)
			end

			local draggingRainbow = false
			local function updateRainbow(inp)
				local p = math.clamp((inp.Position.X - RainbowTrack.AbsolutePosition.X) / math.max(1, RainbowTrack.AbsoluteSize.X), 0, 1)
				local newCol = Color3.fromHSV(p, 1, 1)
				ColorObj:Set(newCol)
			end

			RainbowTrack.InputBegan:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
					draggingRainbow = true
					updateRainbow(inp)
				end
			end)
			UserInputService.InputEnded:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
					draggingRainbow = false
				end
			end)
			UserInputService.InputChanged:Connect(function(inp)
				if draggingRainbow and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
					updateRainbow(inp)
				end
			end)

			local openD = false
			PreviewBtn.MouseButton1Click:Connect(function()
				openD = not openD
				tween(Container, TweenInfo.new(0.18), {
					Size = UDim2.new(1, 0, 0, openD and 104 or 38)
				})
			end)

			return ColorObj
		end

		local function addSetKeybind(name, defaultKey, callback, parent)
			local Row = Instance.new("Frame")
			Row.LayoutOrder = nextOrder()
			Row.Size = UDim2.new(1, 0, 0, 38)
			Row.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
			Row.BackgroundTransparency = 0.35
			Row.BorderSizePixel = 0
			Row.ZIndex = 63
			Row.Parent = parent or generalScroll
			addCorner(Row, 7)
			local rowStroke = addStroke(Row, Color3.fromRGB(46, 52, 70), 1.0, 0.40)

			local Lbl = Instance.new("TextLabel")
			Lbl.Size = UDim2.new(1, -110, 1, 0)
			Lbl.Position = UDim2.new(0, 12, 0, 0)
			Lbl.BackgroundTransparency = 1
			Lbl.Text = name
			Lbl.TextColor3 = Color3.fromRGB(240, 245, 255)
			Lbl.Font = Enum.Font.GothamMedium
			Lbl.TextSize = 13
			Lbl.TextXAlignment = Enum.TextXAlignment.Left
			Lbl.TextTruncate = Enum.TextTruncate.AtEnd
			Lbl.ZIndex = 64
			Lbl.Parent = Row

			local BindBtn = Instance.new("TextButton")
			BindBtn.Size = UDim2.new(0, 88, 0, 24)
			BindBtn.Position = UDim2.new(1, -96, 0.5, -12)
			BindBtn.BackgroundColor3 = Color3.fromRGB(40, 46, 66)
			BindBtn.BackgroundTransparency = 0.10
			BindBtn.Text = "[ " .. formatKeyName(defaultKey) .. " ]"
			BindBtn.TextColor3 = Color3.fromRGB(240, 245, 255)
			BindBtn.Font = Enum.Font.GothamBold
			BindBtn.TextSize = 11
			BindBtn.AutoButtonColor = false
			BindBtn.ZIndex = 64
			BindBtn.Parent = Row
			addCorner(BindBtn, 6)
			local btnStroke = addStroke(BindBtn, Color3.fromRGB(75, 95, 160), 1.0, 0.25)

			local currentKey = defaultKey
			local binding = false

			local BindObj = { Value = currentKey }

			function BindObj:Get()
				return currentKey
			end

			function BindObj:Set(newKey)
				currentKey = resolveKeyItem(newKey) or Enum.KeyCode.P
				BindObj.Value = currentKey
				BindBtn.Text = "[ " .. formatKeyName(currentKey) .. " ]"
				if callback then task.spawn(callback, currentKey) end
			end

			BindBtn.MouseEnter:Connect(function()
				if not binding then
					tween(BindBtn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(54, 64, 92) })
					btnStroke.Color = Color3.fromRGB(110, 140, 240)
				end
			end)
			BindBtn.MouseLeave:Connect(function()
				if not binding then
					tween(BindBtn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(40, 46, 66) })
					btnStroke.Color = Color3.fromRGB(75, 95, 160)
				end
			end)

			BindBtn.MouseButton1Click:Connect(function()
				binding = true
				BindBtn.Text = "[ ... ]"
				BindBtn.BackgroundColor3 = Color3.fromRGB(65, 55, 95)
				btnStroke.Color = Color3.fromRGB(180, 140, 255)
			end)

			UserInputService.InputBegan:Connect(function(input, gp)
				if binding then
					if input.UserInputType == Enum.UserInputType.Keyboard then
						binding = false
						tween(BindBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(40, 46, 66) })
						btnStroke.Color = Color3.fromRGB(75, 95, 160)
						if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
							BindObj:Set(Enum.KeyCode.P)
						else
							BindObj:Set(input.KeyCode)
						end
					end
				end
			end)

			return BindObj
		end

		local savedAntiAfk = Library.ConfigStore["_NS_AntiAFK"]
		local antiAfkEnabled = (savedAntiAfk ~= nil) and (not not savedAntiAfk) or true

		local savedCustomFov = Library.ConfigStore["_NS_CustomFOV"]
		local customFovEnabled = (savedCustomFov ~= nil) and (not not savedCustomFov) or false

		local savedFovVal = tonumber(Library.ConfigStore["_NS_FOV"])
		local customFovValue = savedFovVal or 70

		local savedCrossEnabled = Library.ConfigStore["_NS_CrosshairEnabled"]
		local crosshairEnabled = (savedCrossEnabled ~= nil) and (not not savedCrossEnabled) or false

		local savedCrossStyle = Library.ConfigStore["_NS_CrosshairStyle"]
		local crosshairStyle = savedCrossStyle and tostring(savedCrossStyle) or "1: ⊹"

		local savedCrossSize = tonumber(Library.ConfigStore["_NS_CrosshairSize"])
		local crosshairSize = savedCrossSize or 22

		local savedCrossX = tonumber(Library.ConfigStore["_NS_CrosshairX"])
		local crosshairXOffset = savedCrossX or 0

		local savedCrossY = tonumber(Library.ConfigStore["_NS_CrosshairY"])
		local crosshairYOffset = savedCrossY or 0

		local savedCrossCol = Library.ConfigStore["_NS_CrosshairColor"]
		local crosshairColor = (savedCrossCol and deserializeValue(savedCrossCol)) or Color3.fromRGB(255, 255, 255)

		local savedCrossRainbow = Library.ConfigStore["_NS_CrosshairRainbow"]
		local crosshairRainbow = (savedCrossRainbow ~= nil) and (not not savedCrossRainbow) or false

		local CrosshairGui = Instance.new("ScreenGui")
		CrosshairGui.Name = "NightSystem_CrosshairGui"
		CrosshairGui.DisplayOrder = 999999
		CrosshairGui.ResetOnSpawn = false
		mountScreenGui(CrosshairGui, "NightSystem_CrosshairGui")

		local CrosshairLabel = Instance.new("TextLabel")
		CrosshairLabel.Name = "CrosshairLabel"
		CrosshairLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		CrosshairLabel.Position = UDim2.new(0.5, crosshairXOffset, 0.5, crosshairYOffset)
		CrosshairLabel.Size = UDim2.new(0, 60, 0, 60)
		CrosshairLabel.BackgroundTransparency = 1
		CrosshairLabel.Text = "卐"
		CrosshairLabel.TextColor3 = crosshairColor
		CrosshairLabel.Font = Enum.Font.Arial
		CrosshairLabel.TextSize = crosshairSize
		CrosshairLabel.Visible = crosshairEnabled
		CrosshairLabel.ZIndex = 100
		CrosshairLabel.Parent = CrosshairGui

		local function updateCrosshair()
			if not CrosshairLabel then return end
			CrosshairLabel.Visible = crosshairEnabled
			local symbol = "⊹"
			if string.find(crosshairStyle, "➕") or string.find(crosshairStyle, "+") then
				symbol = "➕"
			elseif string.find(crosshairStyle, "×") then
				symbol = "×"
			elseif string.find(crosshairStyle, "☉") then
				symbol = "☉"
			elseif string.find(crosshairStyle, "・") then
				symbol = "・"
			elseif string.find(crosshairStyle, "✠") then
				symbol = "✠"
			elseif string.find(crosshairStyle, "卐") then
				symbol = "卐"
			elseif string.find(crosshairStyle, "⊹") then
				symbol = "⊹"
			else
				symbol = "⊹"
			end
			CrosshairLabel.Text = symbol
			CrosshairLabel.TextSize = crosshairSize
			CrosshairLabel.Position = UDim2.new(0.5, crosshairXOffset, 0.5, crosshairYOffset)
			if not crosshairRainbow then
				CrosshairLabel.TextColor3 = crosshairColor
			end
		end

		updateCrosshair()

		RunService.RenderStepped:Connect(function()
			if crosshairEnabled and crosshairRainbow and CrosshairLabel then
				local h = (tick() * 0.4) % 1
				CrosshairLabel.TextColor3 = Color3.fromHSV(h, 0.9, 1)
			end
		end)

		local antiAfkConn = nil
		local function setAntiAfkState(state)
			antiAfkEnabled = state
			Library.ConfigStore["_NS_AntiAFK"] = state
			scheduleAutoSave()
			if state then
				if not antiAfkConn then
					antiAfkConn = LocalPlayer.Idled:Connect(function()
						pcall(function()
							local VirtualUser = game:GetService("VirtualUser")
							VirtualUser:CaptureController()
							VirtualUser:ClickButton2(Vector2.new())
						end)
					end)
				end
			else
				if antiAfkConn then
					antiAfkConn:Disconnect()
					antiAfkConn = nil
				end
			end
		end

		local defaultFov = 70
		pcall(function()
			local cam = workspace.CurrentCamera
			if cam then defaultFov = cam.FieldOfView end
		end)

		local function setCustomFovState(state)
			customFovEnabled = state
			Library.ConfigStore["_NS_CustomFOV"] = state
			scheduleAutoSave()
			local cam = workspace.CurrentCamera
			if cam then
				cam.FieldOfView = state and customFovValue or defaultFov
			end
		end

		local function setFovValue(val)
			customFovValue = val
			Library.ConfigStore["_NS_FOV"] = val
			scheduleAutoSave()
			if customFovEnabled then
				local cam = workspace.CurrentCamera
				if cam then cam.FieldOfView = val end
			end
		end

		RunService.RenderStepped:Connect(function()
			if customFovEnabled then
				local cam = workspace.CurrentCamera
				if cam and cam.FieldOfView ~= customFovValue then
					cam.FieldOfView = customFovValue
				end
			end
		end)

		addSetSection("General Settings", generalScroll)

		local setToggleAntiAfk = addSetToggle("Anti-AFK", antiAfkEnabled, setAntiAfkState, generalScroll)
		local setToggleAutoSave = addSetToggle("Auto-Save Config", Library.AutoSave, function(state)
			Library.AutoSave = state
			Library.ConfigStore["_NS_AutoSave"] = state
			if state then
				Library:SaveConfiguration()
			end
		end, generalScroll)
		local setToggleCustomFov = addSetToggle("Custom FOV", customFovEnabled, setCustomFovState, generalScroll)
		local setSliderFov = addSetSlider("Field of View", 60, 120, customFovValue, setFovValue, generalScroll)

		addSetSection("Crosshair Settings", crosshairScroll)

		local setToggleCrosshair = addSetToggle("Enable Crosshair", crosshairEnabled, function(state)
			crosshairEnabled = state
			Library.ConfigStore["_NS_CrosshairEnabled"] = state
			scheduleAutoSave()
			updateCrosshair()
		end, crosshairScroll)

		local setToggleCrosshairRainbow = addSetToggle("Rainbow Crosshair", crosshairRainbow, function(state)
			crosshairRainbow = state
			Library.ConfigStore["_NS_CrosshairRainbow"] = state
			scheduleAutoSave()
			updateCrosshair()
		end, crosshairScroll)

		local setDropCrosshairStyle = addSetDropdown("Crosshair Style", { "1: ⊹", "2: ➕", "3: ×", "4: ☉", "5: ・", "6: 卐" }, crosshairStyle, function(opt)
			crosshairStyle = tostring(opt)
			Library.ConfigStore["_NS_CrosshairStyle"] = crosshairStyle
			scheduleAutoSave()
			updateCrosshair()
		end, crosshairScroll)

		local setSliderCrosshairSize = addSetSlider("Crosshair Size", 10, 60, crosshairSize, function(val)
			crosshairSize = val
			Library.ConfigStore["_NS_CrosshairSize"] = crosshairSize
			scheduleAutoSave()
			updateCrosshair()
		end, crosshairScroll)

		local setSliderCrosshairX = addSetSlider("Crosshair X-Offset", -250, 250, crosshairXOffset, function(val)
			crosshairXOffset = val
			Library.ConfigStore["_NS_CrosshairX"] = crosshairXOffset
			scheduleAutoSave()
			updateCrosshair()
		end, crosshairScroll)

		local setSliderCrosshairY = addSetSlider("Crosshair Height (Y-Offset)", -250, 250, crosshairYOffset, function(val)
			crosshairYOffset = val
			Library.ConfigStore["_NS_CrosshairY"] = crosshairYOffset
			scheduleAutoSave()
			updateCrosshair()
		end, crosshairScroll)

		local setColorCrosshair = addSetColorpicker("Crosshair Color", crosshairColor, function(col)
			crosshairColor = col
			Library.ConfigStore["_NS_CrosshairColor"] = serializeValue(crosshairColor)
			scheduleAutoSave()
			updateCrosshair()
		end, crosshairScroll)

		local savedAimFovEnabled = Library.ConfigStore["_NS_AimFovEnabled"]
		local aimFovEnabled = (savedAimFovEnabled ~= nil) and (not not savedAimFovEnabled) or false

		local savedAimFovRadius = tonumber(Library.ConfigStore["_NS_AimFovRadius"])
		local aimFovRadius = savedAimFovRadius or 120

		local savedAimFovPos = Library.ConfigStore["_NS_AimFovPosMode"]
		local aimFovPosMode = savedAimFovPos and tostring(savedAimFovPos) or "Mouse Cursor"

		local savedAimFovThickness = tonumber(Library.ConfigStore["_NS_AimFovThickness"])
		local aimFovThickness = savedAimFovThickness or 2

		local savedAimFovFilled = Library.ConfigStore["_NS_AimFovFilled"]
		local aimFovFilled = (savedAimFovFilled ~= nil) and (not not savedAimFovFilled) or false

		local savedAimFovCol = Library.ConfigStore["_NS_AimFovColor"]
		local aimFovColor = (savedAimFovCol and deserializeValue(savedAimFovCol)) or Color3.fromRGB(85, 115, 250)

		local AimFovGui = Instance.new("ScreenGui")
		AimFovGui.Name = "NightSystem_AimFovGui"
		AimFovGui.DisplayOrder = 999998
		AimFovGui.ResetOnSpawn = false
		mountScreenGui(AimFovGui, "NightSystem_AimFovGui")

		local FovCircle = Instance.new("Frame")
		FovCircle.Name = "FovCircle"
		FovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
		FovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
		FovCircle.Size = UDim2.new(0, aimFovRadius * 2, 0, aimFovRadius * 2)
		FovCircle.BackgroundColor3 = aimFovColor
		FovCircle.BackgroundTransparency = aimFovFilled and 0.88 or 1
		FovCircle.BorderSizePixel = 0
		FovCircle.Visible = false
		FovCircle.ZIndex = 50
		FovCircle.Parent = AimFovGui
		addCorner(FovCircle, 9999)

		local fovStroke = addStroke(FovCircle, aimFovColor, aimFovThickness, 0.1)

		RunService.RenderStepped:Connect(function()
			if not FovCircle then return end
			if not aimFovEnabled then
				if FovCircle.Visible then FovCircle.Visible = false end
				return
			end
			FovCircle.Visible = true
			FovCircle.Size = UDim2.new(0, aimFovRadius * 2, 0, aimFovRadius * 2)
			fovStroke.Thickness = aimFovThickness
			fovStroke.Color = aimFovColor
			FovCircle.BackgroundColor3 = aimFovColor
			FovCircle.BackgroundTransparency = aimFovFilled and 0.88 or 1

			if aimFovPosMode == "Screen Center" then
				FovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
			else
				local mousePos = UserInputService:GetMouseLocation()
				FovCircle.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
			end
		end)

		addSetSection("Aim FOV Settings", aimFovScroll)

		local setToggleAimFov = addSetToggle("Enable Aim FOV", aimFovEnabled, function(state)
			aimFovEnabled = state
			Library.ConfigStore["_NS_AimFovEnabled"] = state
			scheduleAutoSave()
			if not state and FovCircle then
				FovCircle.Visible = false
			end
		end, aimFovScroll)

		local setSliderAimFovRadius = addSetSlider("Aim FOV Radius", 20, 500, aimFovRadius, function(val)
			aimFovRadius = val
			Library.ConfigStore["_NS_AimFovRadius"] = aimFovRadius
			scheduleAutoSave()
		end, aimFovScroll)

		local setDropAimFovPos = addSetDropdown("Aim FOV Position", { "Mouse Cursor", "Screen Center" }, aimFovPosMode, function(opt)
			aimFovPosMode = tostring(opt)
			Library.ConfigStore["_NS_AimFovPosMode"] = aimFovPosMode
			scheduleAutoSave()
		end, aimFovScroll)

		local setSliderAimFovThickness = addSetSlider("Aim FOV Thickness", 1, 6, aimFovThickness, function(val)
			aimFovThickness = val
			Library.ConfigStore["_NS_AimFovThickness"] = aimFovThickness
			scheduleAutoSave()
		end, aimFovScroll)

		local setToggleAimFovFilled = addSetToggle("Aim FOV Filled", aimFovFilled, function(state)
			aimFovFilled = state
			Library.ConfigStore["_NS_AimFovFilled"] = state
			scheduleAutoSave()
		end, aimFovScroll)

		local setColorAimFov = addSetColorpicker("Aim FOV Color", aimFovColor, function(col)
			aimFovColor = col
			Library.ConfigStore["_NS_AimFovColor"] = serializeValue(aimFovColor)
			scheduleAutoSave()
		end, aimFovScroll)

		local savedAimbotEnabled = Library.ConfigStore["_NS_AimbotEnabled"]
		local aimbotEnabled = (savedAimbotEnabled ~= nil) and (not not savedAimbotEnabled) or false

		local savedAimbotKey = Library.ConfigStore["_NS_AimbotKeybind"]
		local aimbotKeybind = savedAimbotKey and resolveKeyItem(savedAimbotKey) or Enum.KeyCode.P

		local savedAimbotStrength = tonumber(Library.ConfigStore["_NS_AimbotStrength"])
		local aimbotStrength = savedAimbotStrength or 70

		local savedAimbotPart = Library.ConfigStore["_NS_AimbotTargetPart"]
		local aimbotTargetPart = savedAimbotPart and tostring(savedAimbotPart) or "Head"

		local savedAimbotTeam = Library.ConfigStore["_NS_AimbotTeamCheck"]
		local aimbotTeamCheck = (savedAimbotTeam ~= nil) and (not not savedAimbotTeam) or true

		local savedAimbotFov = Library.ConfigStore["_NS_AimbotUseAimFov"]
		local aimbotUseAimFov = (savedAimbotFov ~= nil) and (not not savedAimbotFov) or true

		addSetSection("Aimbot Settings", aimbotScroll)

		local setToggleAimbot = addSetToggle("Enable Aimbot", aimbotEnabled, function(state)
			aimbotEnabled = state
			Library.ConfigStore["_NS_AimbotEnabled"] = state
			scheduleAutoSave()
		end, aimbotScroll)

		local setKeybindAimbot = addSetKeybind("Aimbot Keybind", aimbotKeybind, function(key)
			aimbotKeybind = key
			Library.ConfigStore["_NS_AimbotKeybind"] = key.Name
			scheduleAutoSave()
		end, aimbotScroll)

		local setSliderAimbotStrength = addSetSlider("Aimbot Strength", 5, 100, aimbotStrength, function(val)
			aimbotStrength = val
			Library.ConfigStore["_NS_AimbotStrength"] = aimbotStrength
			scheduleAutoSave()
		end, aimbotScroll)

		local setDropAimbotPart = addSetDropdown("Aimbot Target Part", { "Head", "HumanoidRootPart" }, aimbotTargetPart, function(opt)
			aimbotTargetPart = tostring(opt)
			Library.ConfigStore["_NS_AimbotTargetPart"] = aimbotTargetPart
			scheduleAutoSave()
		end, aimbotScroll)

		local setToggleAimbotTeam = addSetToggle("Aimbot Team Check", aimbotTeamCheck, function(state)
			aimbotTeamCheck = state
			Library.ConfigStore["_NS_AimbotTeamCheck"] = state
			scheduleAutoSave()
		end, aimbotScroll)

		local setToggleAimbotFov = addSetToggle("Aimbot Use Aim FOV", aimbotUseAimFov, function(state)
			aimbotUseAimFov = state
			Library.ConfigStore["_NS_AimbotUseAimFov"] = state
			scheduleAutoSave()
		end, aimbotScroll)

		UserInputService.InputBegan:Connect(function(input, gp)
			if gp then return end
			if aimbotKeybind and input.KeyCode == aimbotKeybind then
				aimbotEnabled = not aimbotEnabled
				Library.ConfigStore["_NS_AimbotEnabled"] = aimbotEnabled
				scheduleAutoSave()
				if setToggleAimbot then
					setToggleAimbot:Set(aimbotEnabled)
				end
				Library.MakeNotification({
					Title = "Aimbot",
					Content = "Aimbot: " .. (aimbotEnabled and "Enabled" or "Disabled"),
					Time = 2
				})
			end
		end)

		local function aimbotStep(deltaTime)
			if not aimbotEnabled then return end
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

			local cam = workspace.CurrentCamera
			if not cam then return end

			local screenCenter
			if aimFovPosMode == "Mouse Cursor" then
				local m = UserInputService:GetMouseLocation()
				screenCenter = Vector2.new(m.X, m.Y)
			else
				local vp = cam.ViewportSize
				screenCenter = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
			end

			local bestTargetPart = nil
			local shortestDist = math.huge
			local maxAllowedDist = (aimbotUseAimFov and aimFovEnabled) and aimFovRadius or 500

			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LocalPlayer and p.Character then
					if not (aimbotTeamCheck and p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team) then
						local char = p.Character
						local hum = char:FindFirstChildOfClass("Humanoid")
						if hum and hum.Health > 0 then
							local part = char:FindFirstChild(aimbotTargetPart) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
							if part then
								local pos3d = part.Position
								local screenPoint, onScreen = cam:WorldToViewportPoint(pos3d)
								if onScreen and screenPoint.Z > 0 then
									local dist = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Magnitude
									if dist <= maxAllowedDist and dist < shortestDist then
										shortestDist = dist
										bestTargetPart = part
									end
								end
							end
						end
					end
				end
			end

			if bestTargetPart then
				local targetPos = bestTargetPart.Position
				local currentCF = cam.CFrame
				local targetCF = CFrame.new(currentCF.Position, targetPos)
				local alpha = math.clamp((aimbotStrength / 100) * math.clamp((deltaTime or 0.016) * 60, 0.2, 3), 0.04, 1.0)
				cam.CFrame = currentCF:Lerp(targetCF, alpha)
			end
		end

		local boundOk = pcall(function()
			RunService:BindToRenderStep("NightSystem_Aimbot", Enum.RenderPriority.Camera.Value + 1, aimbotStep)
		end)
		if not boundOk then
			RunService.RenderStepped:Connect(aimbotStep)
		end

		local function doResetAllSettings()
			setToggleAntiAfk:Set(false)
			setToggleAutoSave:Set(true)
			setToggleCustomFov:Set(false)
			setSliderFov:Set(70)
			setToggleCrosshair:Set(false)
			setToggleCrosshairRainbow:Set(false)
			setDropCrosshairStyle:Set("1: ⊹")
			setSliderCrosshairSize:Set(22)
			setSliderCrosshairX:Set(0)
			setSliderCrosshairY:Set(0)
			setColorCrosshair:Set(Color3.fromRGB(255, 255, 255))
			setToggleAimFov:Set(false)
			setSliderAimFovRadius:Set(120)
			setDropAimFovPos:Set("Mouse Cursor")
			setSliderAimFovThickness:Set(2)
			setToggleAimFovFilled:Set(false)
			setColorAimFov:Set(Color3.fromRGB(85, 115, 250))
			if FovCircle then FovCircle.Visible = false end

			setToggleAimbot:Set(false)
			setKeybindAimbot:Set(Enum.KeyCode.P)
			setSliderAimbotStrength:Set(70)
			setDropAimbotPart:Set("Head")
			setToggleAimbotTeam:Set(true)
			setToggleAimbotFov:Set(true)

			local cam = workspace.CurrentCamera
			if cam then cam.FieldOfView = 70 end

			Library.AutoSave = true
			Library.ConfigStore["_NS_AutoSave"] = nil
			Library.ConfigStore["_NS_AntiAFK"] = nil
			Library.ConfigStore["_NS_CustomFOV"] = nil
			Library.ConfigStore["_NS_FOV"] = nil
			Library.ConfigStore["_NS_CrosshairEnabled"] = nil
			Library.ConfigStore["_NS_CrosshairRainbow"] = nil
			Library.ConfigStore["_NS_CrosshairStyle"] = nil
			Library.ConfigStore["_NS_CrosshairSize"] = nil
			Library.ConfigStore["_NS_CrosshairX"] = nil
			Library.ConfigStore["_NS_CrosshairY"] = nil
			Library.ConfigStore["_NS_CrosshairColor"] = nil
			Library.ConfigStore["_NS_AimFovEnabled"] = nil
			Library.ConfigStore["_NS_AimFovRadius"] = nil
			Library.ConfigStore["_NS_AimFovPosMode"] = nil
			Library.ConfigStore["_NS_AimFovThickness"] = nil
			Library.ConfigStore["_NS_AimFovFilled"] = nil
			Library.ConfigStore["_NS_AimFovColor"] = nil
			Library.ConfigStore["_NS_AimbotEnabled"] = nil
			Library.ConfigStore["_NS_AimbotKeybind"] = nil
			Library.ConfigStore["_NS_AimbotStrength"] = nil
			Library.ConfigStore["_NS_AimbotTargetPart"] = nil
			Library.ConfigStore["_NS_AimbotTeamCheck"] = nil
			Library.ConfigStore["_NS_AimbotUseAimFov"] = nil
			Library:SaveConfiguration()

			SetResetBtn.Text = "Done!"
			task.delay(1.2, function()
				if SetResetBtn then SetResetBtn.Text = "Reset" end
			end)
		end

		SetResetBtn.MouseButton1Click:Connect(doResetAllSettings)
	end

	table.insert(Library.Windows, WindowObj)
	return WindowObj
end

Library.CreateWindow = Library.MakeWindow
Library.Window       = Library.MakeWindow
Library.NewWindow    = Library.MakeWindow
Library.CreateLib    = Library.MakeWindow
Library.Load         = Library.MakeWindow

return Library
