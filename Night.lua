--!nocheck
local isWritableG = pcall(function()
	(_G :: any)._test = 1
end)
local gEnv = (type(getgenv) == "function" and getgenv()) or (isWritableG and _G) or {}

-- Allow fresh re-execution of new versions on loadstring: clean up old instances
if gEnv and gEnv._NightActiveWindow then
	pcall(function()
		if gEnv._NightActiveWindow.Destroy then
			gEnv._NightActiveWindow:Destroy()
		end
	end)
	gEnv._NightActiveWindow = nil
end

-- Fallback for Drawing API in executors where Drawing is nil (prevents visual scripts from crashing before tabs load)
if gEnv and rawget(gEnv, "Drawing") == nil then
	local function createDummyDrawing()
		return setmetatable({}, {
			__index = function(t, k)
				if k == "Remove" or k == "Destroy" then return function() end end
				return t
			end,
			__newindex = function() end,
		})
	end
	gEnv.Drawing = {
		new = function(...) return createDummyDrawing() end,
		Fonts = { UI = 0, System = 1, Plex = 2, Monospace = 3 }
	}
end

--[[
	================================================================================
	NIGHT SYSTEM (NightUI) - Standalone Roblox Luau UI Library
	Design: 1:1 Night System Dark Matte (#121212 / #16181A / #FFFFFF Accent)
	Features:
	  - Standardmäßig integrierter 1:1 "Home"-Tab (immer in der UI enthalten & beim Start aktiv)
	  - Öffnet sich sofort beim Ausführen des Loadstrings (auch ohne extra CreateWindow-Aufruf)
	  - Automatisches Sortier-System (AutoSort) für alle hinzugefügten Script-Elemente
	Compatibility: CoreGui / gethui() / PlayerGui (Studio & Executors)
	================================================================================
]]

local NightSystem = {}
NightSystem.__index = NightSystem
NightSystem.Version = "2.2.0"
NightSystem.Flags = {}
NightSystem._Connections = {}
NightSystem._ActiveWindow = nil

-- // Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- // 1:1 Color Palette & Style Constants
local THEME = {
	MainBackground = Color3.fromHex("#121212"),
	SidebarBackground = Color3.fromHex("#121212"),
	ContentBase = Color3.fromHex("#16181A"),
	ContentGradTopRight = Color3.fromHex("#1E2528"),
	ContentGradBottomLeft = Color3.fromHex("#141517"),

	CardBackground = Color3.fromHex("#1A1D20"),
	CardHover = Color3.fromHex("#202428"),
	CardInner = Color3.fromHex("#141618"),

	DiscordBoxBg = Color3.fromHex("#161616"),
	TabActiveBg = Color3.fromHex("#181818"),
	TabHoverBg = Color3.fromHex("#151515"),
	ControlBtnBg = Color3.fromHex("#1A1A1A"),
	ControlBtnHover = Color3.fromHex("#252525"),

	Stroke = Color3.fromHex("#262626"),
	StrokeActive = Color3.fromHex("#2A2A2A"),
	DividerFooter = Color3.fromHex("#222222"),
	DragPill = Color3.fromHex("#3A3A3A"),

	Accent = Color3.fromHex("#FFFFFF"),
	AccentRed = Color3.fromHex("#E03E3E"),

	TextPrimary = Color3.fromHex("#FFFFFF"),
	TextSecondary = Color3.fromHex("#7A7A7A"),
	TextTabInactive = Color3.fromHex("#8A8A8A"),
	TextCategory = Color3.fromHex("#555555"),
	TextHeaderTitle = Color3.fromHex("#4A525A"),
	TextHeaderSub = Color3.fromHex("#3A424A"),
	TextInfo = Color3.fromHex("#8E9297"),
	TextStatValue = Color3.fromHex("#B0B0B0"),
}

-- // Tween Presets
local TWEEN_FAST = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_MEDIUM = TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TWEEN_SMOOTH = TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- // Auto-Sort Type Priorities
local TYPE_PRIORITY = {
	Section = 0,
	Label = 100,
	Paragraph = 150,
	Toggle = 200,
	Slider = 300,
	Dropdown = 400,
	ColorPicker = 450,
	Input = 500,
	Keybind = 550,
	Button = 600,
	Divider = 700,
}

-- // Native Roblox Icon Assets
local ASSETS = {
	DefaultLogo = "rbxassetid://10734950309",
	ExternalLink = "rbxassetid://10723374641",
	Home = "rbxassetid://10723407389",
	Main = "rbxassetid://10723407389",
	Users = "rbxassetid://10747373176",
	Webhook = "rbxassetid://10734898355",
	Settings = "rbxassetid://10734950309",
	Themes = "rbxassetid://10734910430",
	ChevronDown = "rbxassetid://10709790948",
	ChevronRight = "rbxassetid://10709791437",
	Search = "rbxassetid://10734943674",
}

-- // Helper Functions
local function trackConnection(conn: RBXScriptConnection): RBXScriptConnection
	table.insert(NightSystem._Connections, conn)
	return conn
end

local function disconnectAll()
	for _, conn in ipairs(NightSystem._Connections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(NightSystem._Connections)
end

local function getGuiParent(): Instance
	local ok, result = pcall(function()
		if type(gethui) == "function" then
			return gethui()
		end
		local coreGui = game:GetService("CoreGui")
		local _ = coreGui.Name
		return coreGui
	end)
	if ok and result then
		return result
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local function createCorner(parent: Instance, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function createStroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or THEME.Stroke
	stroke.Thickness = thickness or 1
	stroke.Transparency = if transparency ~= nil then transparency else 0.2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function createPadding(parent: Instance, top: number, bottom: number, left: number, right: number): UIPadding
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, top)
	pad.PaddingBottom = UDim.new(0, bottom)
	pad.PaddingLeft = UDim.new(0, left)
	pad.PaddingRight = UDim.new(0, right)
	pad.Parent = parent
	return pad
end

local function tween(instance: Instance, info: TweenInfo, props: { [string]: any }): Tween
	local tw = TweenService:Create(instance, info, props)
	tw:Play()
	return tw
end

local function formatKeyName(key: any): string
	if not key then
		return "None"
	end
	local name = if typeof(key) == "EnumItem" or (type(key) == "table" and key.Name) then key.Name else tostring(key)
	local replacements = {
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
		Return = "Enter",
	}
	return replacements[name] or name
end

local function colorToHex(color: any): string
	local ok, hex = pcall(function()
		local r = math.clamp(math.round(color.R * 255), 0, 255)
		local g = math.clamp(math.round(color.G * 255), 0, 255)
		local b = math.clamp(math.round(color.B * 255), 0, 255)
		return string.format("#%02X%02X%02X", r, g, b)
	end)
	return if ok and hex then hex else "#FFFFFF"
end

local function hexToColor(hex: string): Color3?
	local cleaned = string.gsub(string.gsub(hex, "#", ""), "%s+", "")
	if #cleaned == 6 then
		local r = tonumber(string.sub(cleaned, 1, 2), 16)
		local g = tonumber(string.sub(cleaned, 3, 4), 16)
		local b = tonumber(string.sub(cleaned, 5, 6), 16)
		if r and g and b then
			return Color3.fromRGB(r, g, b)
		end
	end
	return nil
end

local function safeCallback(fn: ((...any) -> ())?, ...: any)
	if type(fn) == "function" then
		local count = select("#", ...)
		local args = { ... }
		task.spawn(function()
			local ok, err = pcall(fn, table.unpack(args, 1, count))
			if not ok then
				warn("[NightSystem Callback Error]:", err)
			end
		end)
	end
end

-- ============================================================================
-- TOAST NOTIFICATIONS (NightSystem:Notify)
-- ============================================================================
local NotificationGui: ScreenGui? = nil
local NotificationHolder: Frame? = nil

local function ensureNotificationHolder(): Frame
	if NotificationGui and NotificationGui.Parent and NotificationHolder then
		return NotificationHolder
	end

	local parent = getGuiParent()
	local oldNotif = parent:FindFirstChild("NightSystem_Notifications")
	if oldNotif then
		oldNotif:Destroy()
	end

	NotificationGui = Instance.new("ScreenGui")
	NotificationGui.Name = "NightSystem_Notifications"
	NotificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	NotificationGui.ResetOnSpawn = false
	NotificationGui.DisplayOrder = 999
	NotificationGui.Parent = parent

	NotificationHolder = Instance.new("Frame")
	NotificationHolder.Name = "NotificationHolder"
	NotificationHolder.Size = UDim2.new(0, 300, 1, -32)
	NotificationHolder.Position = UDim2.new(1, -16, 1, -16)
	NotificationHolder.AnchorPoint = Vector2.new(1, 1)
	NotificationHolder.BackgroundTransparency = 1
	NotificationHolder.Parent = NotificationGui

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = NotificationHolder

	return NotificationHolder
end

function NightSystem:Notify(options: { Title: string?, Content: string?, Duration: number? } | string)
	local opts = if type(options) == "string"
		then { Title = "Night System", Content = options, Duration = 4 }
		else (options or {})
	local titleText = tostring(opts.Title or "Night System")
	local contentText = tostring(opts.Content or "")
	local duration = tonumber(opts.Duration) or 4

	local holder = ensureNotificationHolder()
	local textBounds = TextService:GetTextSize(contentText, 12, Enum.Font.GothamMedium, Vector2.new(244, 500))
	local cardHeight = math.max(62, textBounds.Y + 42)

	local wrapper = Instance.new("Frame")
	wrapper.Name = "ToastWrapper"
	wrapper.Size = UDim2.new(0, 290, 0, cardHeight)
	wrapper.BackgroundTransparency = 1
	wrapper.Parent = holder

	local card = Instance.new("Frame")
	card.Name = "ToastCard"
	card.Size = UDim2.new(1, 0, 1, 0)
	card.Position = UDim2.new(1, 320, 0, 0)
	card.BackgroundColor3 = THEME.MainBackground
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Parent = wrapper
	createCorner(card, 8)
	createStroke(card, THEME.Stroke, 1, 0.15)

	local accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.new(0, 3, 1, -16)
	accentBar.Position = UDim2.new(0, 8, 0, 8)
	accentBar.BackgroundColor3 = THEME.Accent
	accentBar.BorderSizePixel = 0
	accentBar.Parent = card
	createCorner(accentBar, 2)

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -48, 0, 16)
	titleLbl.Position = UDim2.new(0, 20, 0, 10)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.Text = titleText
	titleLbl.TextColor3 = THEME.TextPrimary
	titleLbl.TextSize = 13
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
	titleLbl.Parent = card

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 20, 0, 20)
	closeBtn.Position = UDim2.new(1, -8, 0, 8)
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "×"
	closeBtn.TextColor3 = THEME.TextSecondary
	closeBtn.TextSize = 16
	closeBtn.Parent = card

	local bodyLbl = Instance.new("TextLabel")
	bodyLbl.Size = UDim2.new(1, -32, 1, -36)
	bodyLbl.Position = UDim2.new(0, 20, 0, 28)
	bodyLbl.BackgroundTransparency = 1
	bodyLbl.Font = Enum.Font.GothamMedium
	bodyLbl.Text = contentText
	bodyLbl.TextColor3 = THEME.TextInfo
	bodyLbl.TextSize = 12
	bodyLbl.TextWrapped = true
	bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
	bodyLbl.TextYAlignment = Enum.TextYAlignment.Top
	bodyLbl.Parent = card

	local progressBg = Instance.new("Frame")
	progressBg.Size = UDim2.new(1, 0, 0, 2)
	progressBg.Position = UDim2.new(0, 0, 1, -2)
	progressBg.BackgroundColor3 = THEME.Stroke
	progressBg.BorderSizePixel = 0
	progressBg.Parent = card

	local progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.new(1, 0, 1, 0)
	progressFill.BackgroundColor3 = THEME.Accent
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBg

	local closed = false
	local function dismiss()
		if closed then
			return
		end
		closed = true
		local outTween = tween(card, TWEEN_MEDIUM, { Position = UDim2.new(1, 320, 0, 0) })
		tween(wrapper, TWEEN_MEDIUM, { Size = UDim2.new(0, 290, 0, 0) })
		outTween.Completed:Connect(function()
			if wrapper.Parent then
				wrapper:Destroy()
			end
		end)
	end

	closeBtn.MouseButton1Click:Connect(dismiss)
	tween(card, TWEEN_SMOOTH, { Position = UDim2.new(0, 0, 0, 0) })
	tween(progressFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) })
	task.delay(duration, dismiss)
end

-- ============================================================================
-- WINDOW CREATION (NightSystem:CreateWindow)
-- ============================================================================
function NightSystem:CreateWindow(config: {
	Title: string?,
	Subtitle: string?,
	LogoId: string?,
	IntroText: string?,
	MainTabName: string?,
	AutoSort: boolean?,
	ToggleKey: Enum.KeyCode?,
	Platform: string?,
}?)
	local cfg = config or {}

	-- If the default window was already auto-created on loadstring load (or stored in getgenv), reuse it without destroying
	local existingWin = NightSystem._ActiveWindow
	if existingWin and existingWin._ScreenGui and existingWin._ScreenGui.Parent then
		NightSystem._ActiveWindow = existingWin
		existingWin:_ApplyConfig(cfg)
		return existingWin
	end

	local windowTitle = tostring(cfg.Title or "Night System")
	local windowSubtitle = tostring(cfg.Subtitle or "discord.gg/4cZBCyDFmX")
	local logoId = tostring(cfg.LogoId or ASSETS.DefaultLogo)
	local introText = tostring(cfg.IntroText or "Night System Scripts in all free")
	local mainTabName = tostring(cfg.MainTabName or "Main")
	local autoSort = if cfg.AutoSort ~= nil then cfg.AutoSort else true
	local toggleKey = cfg.ToggleKey or Enum.KeyCode.LeftControl

	-- Clean up old instances
	disconnectAll()
	local parent = getGuiParent()
	for _, childName in ipairs({ "NightSystem_UI", "NightSystemUI", "NightSystem_BadgeGui", "NightSystem_Badge" }) do
		local existing = parent:FindFirstChild(childName)
		if existing then
			existing:Destroy()
		end
	end

	local isMaximized = false
	local isWindowOpen = false
	local isMinimized = false
	local isHidden = false
	local isLoaderRunning = false
	local skipLoader = false

	-- Main ScreenGui (DisplayOrder 999998 - Stays directly below BadgeGui 999999, never hidden behind game HUDs)
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "NightSystem_UI"
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.ResetOnSpawn = false
	ScreenGui.IgnoreGuiInset = false
	ScreenGui.DisplayOrder = 999998
	ScreenGui.Enabled = true
	ScreenGui.Parent = parent

	trackConnection(ScreenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not ScreenGui.Enabled and isWindowOpen then
			ScreenGui.Enabled = true
		end
	end))

	-- Dedicated Badge ScreenGui (DisplayOrder 999999 - Never hidden or blocked by any GUI)
	local BadgeGui = Instance.new("ScreenGui")
	BadgeGui.Name = "NightSystem_BadgeGui"
	BadgeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	BadgeGui.ResetOnSpawn = false
	BadgeGui.IgnoreGuiInset = false
	BadgeGui.DisplayOrder = 999999
	BadgeGui.Enabled = true
	BadgeGui.Parent = parent

	trackConnection(BadgeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not BadgeGui.Enabled then
			BadgeGui.Enabled = true
		end
	end))

	-- Platform Auto-Detection (PC vs Handy)
	local function detectAutoPlatform(): string
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			return "Handy"
		elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			return "Handy"
		end
		return "PC"
	end

	local selectedPlatform: string = if (cfg.Platform and tostring(cfg.Platform) ~= "Auto")
		then (if (tostring(cfg.Platform) == "Handy" or tostring(cfg.Platform) == "Mobile") then "Handy" else "PC")
		else detectAutoPlatform()
	NightSystem.Platform = selectedPlatform

	-- Floating Minimized Badge (Top Bar Pill - Nur auf PC sichtbar, auf Handy ausgeblendet!)
	local FloatingBadge = Instance.new("TextButton")
	FloatingBadge.Name = "FloatingBadge"
	FloatingBadge.Size = UDim2.new(0, 160, 0, 38)
	FloatingBadge.Position = UDim2.new(0.5, 0, 0, 28)
	FloatingBadge.AnchorPoint = Vector2.new(0.5, 0)
	FloatingBadge.BackgroundColor3 = THEME.MainBackground
	FloatingBadge.BorderSizePixel = 0
	FloatingBadge.AutoButtonColor = false
	FloatingBadge.Text = ""
	FloatingBadge.Active = true
	FloatingBadge.ZIndex = 80
	FloatingBadge.Visible = (selectedPlatform ~= "Handy")
	FloatingBadge.Parent = BadgeGui
	createCorner(FloatingBadge, 10)
	createStroke(FloatingBadge, THEME.Stroke, 1, 0.15)

	-- Visibility guard: FloatingBadge ist auf PC DAUERHAFT sichtbar, auf Handy IMMER ausgeblendet
	trackConnection(FloatingBadge:GetPropertyChangedSignal("Visible"):Connect(function()
		if selectedPlatform == "Handy" then
			if FloatingBadge.Visible then
				FloatingBadge.Visible = false
			end
		else
			if not FloatingBadge.Visible then
				FloatingBadge.Visible = true
			end
		end
	end))

	local BadgeLogo = Instance.new("Frame")
	BadgeLogo.Size = UDim2.new(0, 24, 0, 24)
	BadgeLogo.Position = UDim2.new(0, 8, 0.5, 0)
	BadgeLogo.AnchorPoint = Vector2.new(0, 0.5)
	BadgeLogo.BackgroundColor3 = Color3.fromHex("#1E1E22")
	BadgeLogo.BorderSizePixel = 0
	BadgeLogo.Active = false
	BadgeLogo.ZIndex = 81
	BadgeLogo.Parent = FloatingBadge
	createCorner(BadgeLogo, 6)

	local BadgeLetter = Instance.new("TextLabel")
	BadgeLetter.Size = UDim2.new(1, 0, 1, 0)
	BadgeLetter.BackgroundTransparency = 1
	BadgeLetter.Font = Enum.Font.GothamBold
	BadgeLetter.Text = "N"
	BadgeLetter.TextColor3 = THEME.TextPrimary
	BadgeLetter.TextSize = 13
	BadgeLetter.Active = false
	BadgeLetter.ZIndex = 82
	BadgeLetter.Parent = BadgeLogo

	local BadgeRedDot = Instance.new("Frame")
	BadgeRedDot.Size = UDim2.new(0, 5, 0, 5)
	BadgeRedDot.Position = UDim2.new(1, -3, 0, 3)
	BadgeRedDot.AnchorPoint = Vector2.new(0.5, 0.5)
	BadgeRedDot.BackgroundColor3 = THEME.AccentRed
	BadgeRedDot.BorderSizePixel = 0
	BadgeRedDot.Active = false
	BadgeRedDot.ZIndex = 83
	BadgeRedDot.Parent = BadgeLogo
	createCorner(BadgeRedDot, 4)

	local BadgeLabel = Instance.new("TextLabel")
	BadgeLabel.Size = UDim2.new(1, -44, 1, 0)
	BadgeLabel.Position = UDim2.new(0, 38, 0, 0)
	BadgeLabel.BackgroundTransparency = 1
	BadgeLabel.Font = Enum.Font.GothamBold
	BadgeLabel.Text = windowTitle
	BadgeLabel.TextColor3 = THEME.TextPrimary
	BadgeLabel.TextSize = 13
	BadgeLabel.TextXAlignment = Enum.TextXAlignment.Left
	BadgeLabel.TextTruncate = Enum.TextTruncate.AtEnd
	BadgeLabel.Active = false
	BadgeLabel.ZIndex = 81
	BadgeLabel.Parent = FloatingBadge

	-- Mobile Floating Toggle Button (Sleek draggable circular button with 'N' logo and red dot - Pure Matte Black)
	local MobileToggleBtn = Instance.new("TextButton")
	MobileToggleBtn.Name = "MobileToggleBtn"
	MobileToggleBtn.Size = UDim2.new(0, 44, 0, 44)
	MobileToggleBtn.Position = UDim2.new(0, 16, 0.35, 0)
	MobileToggleBtn.AnchorPoint = Vector2.new(0, 0.5)
	MobileToggleBtn.BackgroundColor3 = Color3.fromHex("#08080A")
	MobileToggleBtn.BorderSizePixel = 0
	MobileToggleBtn.AutoButtonColor = false
	MobileToggleBtn.Text = ""
	MobileToggleBtn.ZIndex = 40
	MobileToggleBtn.Visible = (selectedPlatform == "Handy")
	MobileToggleBtn.Parent = BadgeGui
	createCorner(MobileToggleBtn, 22)
	local mobileStroke = createStroke(MobileToggleBtn, Color3.fromHex("#1E2024"), 1.2, 0.15)

	local mobileLogoHolder = Instance.new("Frame")
	mobileLogoHolder.Size = UDim2.new(0, 26, 0, 26)
	mobileLogoHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
	mobileLogoHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	mobileLogoHolder.BackgroundColor3 = Color3.fromHex("#101114")
	mobileLogoHolder.BorderSizePixel = 0
	mobileLogoHolder.Parent = MobileToggleBtn
	createCorner(mobileLogoHolder, 6)

	local mobileLogoText = Instance.new("TextLabel")
	mobileLogoText.Size = UDim2.new(1, 0, 1, 0)
	mobileLogoText.BackgroundTransparency = 1
	mobileLogoText.Font = Enum.Font.GothamBold
	mobileLogoText.Text = "N"
	mobileLogoText.TextColor3 = THEME.TextPrimary
	mobileLogoText.TextSize = 15
	mobileLogoText.Parent = mobileLogoHolder

	local mobileRedDot = Instance.new("Frame")
	mobileRedDot.Size = UDim2.new(0, 6, 0, 6)
	mobileRedDot.Position = UDim2.new(1, -2, 0, 2)
	mobileRedDot.AnchorPoint = Vector2.new(0.5, 0.5)
	mobileRedDot.BackgroundColor3 = THEME.AccentRed
	mobileRedDot.BorderSizePixel = 0
	mobileRedDot.Parent = mobileLogoHolder
	createCorner(mobileRedDot, 6)

	-- Main Window (740x460px, UICorner 12px, #121212)
	local normalSize = UDim2.new(0, 740, 0, 460)
	local maximizedSize = UDim2.new(0, 920, 0, 560)

	local MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame"
	MainFrame.Size = normalSize
	MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	MainFrame.BackgroundColor3 = THEME.MainBackground
	MainFrame.BorderSizePixel = 0
	MainFrame.ClipsDescendants = true
	MainFrame.Visible = false
	MainFrame.Parent = ScreenGui
	createCorner(MainFrame, 12)
	createStroke(MainFrame, THEME.Stroke, 1, 0.2)

	-- Dynamic UI Scaling for Mobile & Responsive displays
	local mainFrameScale = Instance.new("UIScale")
	mainFrameScale.Name = "WindowScale"
	mainFrameScale.Scale = 1.0
	mainFrameScale.Parent = MainFrame

	local PlatformValueLabel: TextLabel? = nil

	local function updateMobileScale()
		if selectedPlatform ~= "Handy" then
			if mainFrameScale then mainFrameScale.Scale = 1.0 end
			return
		end
		local cam = workspace.CurrentCamera
		local vp = (cam and cam.ViewportSize) or Vector2.new(800, 600)
		if vp.X <= 100 or vp.Y <= 100 then
			vp = Vector2.new(800, 600)
		end
		local availW = math.max(300, vp.X - 28)
		local availH = math.max(200, vp.Y - 28)
		local scaleX = availW / 740
		local scaleY = availH / 460
		local calculatedScale = math.min(scaleX, scaleY)
		if mainFrameScale then
			mainFrameScale.Scale = math.clamp(calculatedScale, 0.50, 0.95)
		end
	end

	trackConnection(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateMobileScale))
	trackConnection(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateMobileScale))

	local function applyPlatform(platformName: string)
		selectedPlatform = if (platformName == "Handy" or platformName == "Mobile") then "Handy" else "PC"
		NightSystem.Platform = selectedPlatform

		if PlatformValueLabel and PlatformValueLabel.Parent then
			PlatformValueLabel.Text = selectedPlatform
		end

		if selectedPlatform == "Handy" then
			if FloatingBadge then
				FloatingBadge.Visible = false
			end
			updateMobileScale()
			if MobileToggleBtn then
				MobileToggleBtn.Visible = true
			end
		else
			if mainFrameScale then
				mainFrameScale.Scale = 1.0
			end
			if FloatingBadge then
				FloatingBadge.Visible = true
			end
			if MobileToggleBtn then
				MobileToggleBtn.Visible = false
			end
		end
	end

	-- Sofortige Anwendung der automatisch erkannten oder konfigurierten Plattform
	applyPlatform(selectedPlatform)

	-- ========================================================================
	-- TOPBAR & WINDOW CONTROLS
	-- ========================================================================
	local TopBar = Instance.new("Frame")
	TopBar.Name = "TopBar"
	TopBar.Size = UDim2.new(1, 0, 0, 42)
	TopBar.BackgroundTransparency = 1
	TopBar.Parent = MainFrame

	-- Drag Indicator Pill (36x4px, #3A3A3A)
	local DragPill = Instance.new("Frame")
	DragPill.Name = "DragIndicator"
	DragPill.Size = UDim2.new(0, 36, 0, 4)
	DragPill.Position = UDim2.new(0.5, 0, 0, 12)
	DragPill.AnchorPoint = Vector2.new(0.5, 0)
	DragPill.BackgroundColor3 = THEME.DragPill
	DragPill.BorderSizePixel = 0
	DragPill.Parent = TopBar
	createCorner(DragPill, 4)

	-- Top-Left Control Buttons (Crisp Geometric Icons: Close, Maximize, Minimize)
	local ControlsHolder = Instance.new("Frame")
	ControlsHolder.Name = "WindowControls"
	ControlsHolder.Size = UDim2.new(0, 90, 0, 26)
	ControlsHolder.Position = UDim2.new(0, 12, 0, 9)
	ControlsHolder.BackgroundTransparency = 1
	ControlsHolder.Parent = TopBar

	local ControlsList = Instance.new("UIListLayout")
	ControlsList.FillDirection = Enum.FillDirection.Horizontal
	ControlsList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	ControlsList.VerticalAlignment = Enum.VerticalAlignment.Center
	ControlsList.Padding = UDim.new(0, 6)
	ControlsList.Parent = ControlsHolder

	local function createControlBase(name: string, isClose: boolean?): (TextButton, UIStroke)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0, 26, 0, 26)
		btn.BackgroundColor3 = Color3.fromHex("#181A1D")
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Text = ""
		btn.Parent = ControlsHolder
		createCorner(btn, 7)
		local stroke = createStroke(btn, Color3.fromHex("#282B30"), 1, 0.15)
		return btn, stroke
	end

	-- 1. Close Button (Crisp X Cross with subtle red hover glow)
	local CloseBtn, CloseStroke = createControlBase("CloseButton", true)
	local xLine1 = Instance.new("Frame")
	xLine1.Size = UDim2.new(0, 11, 0, 1.8)
	xLine1.Position = UDim2.new(0.5, 0, 0.5, 0)
	xLine1.AnchorPoint = Vector2.new(0.5, 0.5)
	xLine1.Rotation = 45
	xLine1.BackgroundColor3 = THEME.TextSecondary
	xLine1.BorderSizePixel = 0
	xLine1.Parent = CloseBtn
	createCorner(xLine1, 2)

	local xLine2 = Instance.new("Frame")
	xLine2.Size = UDim2.new(0, 11, 0, 1.8)
	xLine2.Position = UDim2.new(0.5, 0, 0.5, 0)
	xLine2.AnchorPoint = Vector2.new(0.5, 0.5)
	xLine2.Rotation = -45
	xLine2.BackgroundColor3 = THEME.TextSecondary
	xLine2.BorderSizePixel = 0
	xLine2.Parent = CloseBtn
	createCorner(xLine2, 2)

	CloseBtn.MouseEnter:Connect(function()
		tween(CloseBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#2B1719") })
		tween(CloseStroke, TWEEN_FAST, { Color = THEME.AccentRed, Transparency = 0.1 })
		tween(xLine1, TWEEN_FAST, { BackgroundColor3 = THEME.TextPrimary })
		tween(xLine2, TWEEN_FAST, { BackgroundColor3 = THEME.TextPrimary })
	end)
	CloseBtn.MouseLeave:Connect(function()
		tween(CloseBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#181A1D") })
		tween(CloseStroke, TWEEN_FAST, { Color = Color3.fromHex("#282B30"), Transparency = 0.15 })
		tween(xLine1, TWEEN_FAST, { BackgroundColor3 = THEME.TextSecondary })
		tween(xLine2, TWEEN_FAST, { BackgroundColor3 = THEME.TextSecondary })
	end)

	-- 2. Maximize Button (Crisp Rounded Window Square)
	local MaximizeBtn, MaxStroke = createControlBase("MaximizeButton", false)
	local maxBox = Instance.new("Frame")
	maxBox.Size = UDim2.new(0, 9, 0, 9)
	maxBox.Position = UDim2.new(0.5, 0, 0.5, 0)
	maxBox.AnchorPoint = Vector2.new(0.5, 0.5)
	maxBox.BackgroundTransparency = 1
	maxBox.Parent = MaximizeBtn
	createCorner(maxBox, 2)
	local maxBoxStroke = createStroke(maxBox, THEME.TextSecondary, 1.5, 0)

	MaximizeBtn.MouseEnter:Connect(function()
		tween(MaximizeBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#22252A") })
		tween(MaxStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0.2 })
		tween(maxBoxStroke, TWEEN_FAST, { Color = THEME.TextPrimary })
	end)
	MaximizeBtn.MouseLeave:Connect(function()
		tween(MaximizeBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#181A1D") })
		tween(MaxStroke, TWEEN_FAST, { Color = Color3.fromHex("#282B30"), Transparency = 0.15 })
		tween(maxBoxStroke, TWEEN_FAST, { Color = THEME.TextSecondary })
	end)

	-- 3. Minimize Button (Crisp 3-Bar Hamburger Menu Icon)
	local MinimizeBtn, MinStroke = createControlBase("MinimizeButton", false)
	local minBars = {}
	for i, yOff in ipairs({ -3.5, 0, 3.5 }) do
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(0, if i == 2 then 9 else 11, 0, 1.6)
		bar.Position = UDim2.new(0.5, 0, 0.5, yOff)
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.BackgroundColor3 = THEME.TextSecondary
		bar.BorderSizePixel = 0
		bar.Parent = MinimizeBtn
		createCorner(bar, 2)
		table.insert(minBars, bar)
	end

	MinimizeBtn.MouseEnter:Connect(function()
		tween(MinimizeBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#22252A") })
		tween(MinStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0.2 })
		for _, bar in ipairs(minBars) do
			tween(bar, TWEEN_FAST, { BackgroundColor3 = THEME.TextPrimary })
		end
	end)
	MinimizeBtn.MouseLeave:Connect(function()
		tween(MinimizeBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#181A1D") })
		tween(MinStroke, TWEEN_FAST, { Color = Color3.fromHex("#282B30"), Transparency = 0.15 })
		for _, bar in ipairs(minBars) do
			tween(bar, TWEEN_FAST, { BackgroundColor3 = THEME.TextSecondary })
		end
	end)

	local function updateBadgeStatus()
		if BadgeRedDot and BadgeRedDot.Parent then
			if isWindowOpen then
				BadgeRedDot.BackgroundColor3 = Color3.fromHex("#00E676")
			else
				BadgeRedDot.BackgroundColor3 = THEME.AccentRed
			end
		end
	end
	updateBadgeStatus()

	local function makeDraggable(handle: GuiObject, target: GuiObject, pill: Frame?, onClick: (() -> ())?)
		local isDragging = false
		local dragInput: InputObject? = nil
		local dragStart = Vector2.zero
		local startPos = target.Position
		local totalMoved = 0

		handle.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				isDragging = true
				totalMoved = 0
				dragStart = Vector2.new(input.Position.X, input.Position.Y)
				startPos = target.Position
				if pill then
					tween(pill, TWEEN_FAST, { BackgroundColor3 = THEME.TextPrimary })
				end
				local endConn: RBXScriptConnection? = nil
				endConn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						isDragging = false
						if endConn then endConn:Disconnect() end
						if pill then
							tween(pill, TWEEN_FAST, { BackgroundColor3 = THEME.DragPill })
						end
						if totalMoved < 6 and onClick then
							onClick()
						end
					end
				end)
			end
		end)

		handle.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				dragInput = input
			end
		end)

		trackConnection(UserInputService.InputChanged:Connect(function(input: InputObject)
			if input == dragInput and isDragging then
				local curPos = Vector2.new(input.Position.X, input.Position.Y)
				local delta = curPos - dragStart
				totalMoved = delta.Magnitude
				target.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
			end
		end))
	end

	local currentOpenCloseTween: Tween? = nil

	local function openWindow()
		isWindowOpen = true
		isMinimized = false
		isHidden = false
		updateBadgeStatus()

		if ScreenGui then ScreenGui.Enabled = true end
		if BadgeGui then BadgeGui.Enabled = true end
		if FloatingBadge then
			FloatingBadge.Visible = (selectedPlatform ~= "Handy")
		end

		local focused = UserInputService:GetFocusedTextBox()
		if focused and focused:IsDescendantOf(ScreenGui) then
			pcall(function() focused:ReleaseFocus() end)
		end

		if currentOpenCloseTween then
			pcall(function() currentOpenCloseTween:Cancel() end)
			currentOpenCloseTween = nil
		end

		MainFrame.Visible = true
		MainFrame.BackgroundTransparency = 0

		local targetSize = if isMaximized then maximizedSize else normalSize
		if MainFrame.Size.Y.Offset < 60 then
			MainFrame.Size = UDim2.new(0, targetSize.X.Offset * 0.94, 0, targetSize.Y.Offset * 0.94)
		end

		currentOpenCloseTween = tween(MainFrame, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = targetSize,
			BackgroundTransparency = 0,
		})
	end

	local function closeWindow()
		isWindowOpen = false
		isMinimized = false
		isHidden = true
		updateBadgeStatus()

		if BadgeGui then BadgeGui.Enabled = true end
		if FloatingBadge then
			FloatingBadge.Visible = (selectedPlatform ~= "Handy")
		end

		local focused = UserInputService:GetFocusedTextBox()
		if focused and focused:IsDescendantOf(ScreenGui) then
			pcall(function() focused:ReleaseFocus() end)
		end

		if currentOpenCloseTween then
			pcall(function() currentOpenCloseTween:Cancel() end)
			currentOpenCloseTween = nil
		end

		local targetW = if isMaximized then maximizedSize.X.Offset else normalSize.X.Offset
		local tw = tween(MainFrame, TWEEN_FAST, {
			Size = UDim2.new(0, targetW, 0, 0),
			BackgroundTransparency = 1,
		})
		currentOpenCloseTween = tw
		tw.Completed:Connect(function(playbackState)
			if not isWindowOpen and playbackState == Enum.PlaybackState.Completed then
				MainFrame.Visible = false
			end
		end)

		local closeHint = if selectedPlatform == "Handy"
			then "UI geschlossen - Tippe auf den Night-Button zum Oeffnen."
			else "UI geschlossen - Klicke auf das Night-Symbol oben oder druecke STRG zum Oeffnen."

		NightSystem:Notify({
			Title = windowTitle,
			Content = closeHint,
			Duration = 2.5,
		})
	end

	local function minimizeWindow()
		closeWindow()
	end

	local lastToggleTime = 0
	local function toggleWindowState()
		local now = os.clock()
		if now - lastToggleTime < 0.15 then return end
		lastToggleTime = now

		if isLoaderRunning then
			skipLoader = true
			return
		end

		if isWindowOpen then
			closeWindow()
		else
			openWindow()
		end
	end

	makeDraggable(TopBar, MainFrame, DragPill, nil)
	makeDraggable(FloatingBadge, FloatingBadge, nil, function()
		toggleWindowState()
	end)
	FloatingBadge.Activated:Connect(function()
		toggleWindowState()
	end)

	FloatingBadge.MouseEnter:Connect(function()
		tween(FloatingBadge, TWEEN_FAST, { BackgroundColor3 = THEME.CardHover })
	end)
	FloatingBadge.MouseLeave:Connect(function()
		tween(FloatingBadge, TWEEN_FAST, { BackgroundColor3 = THEME.MainBackground })
	end)

	CloseBtn.MouseButton1Click:Connect(function()
		closeWindow()
	end)

	MaximizeBtn.MouseButton1Click:Connect(function()
		isMaximized = not isMaximized
		tween(MainFrame, TWEEN_SMOOTH, {
			Size = if isMaximized then maximizedSize else normalSize,
		})
	end)

	MinimizeBtn.MouseButton1Click:Connect(function()
		closeWindow()
	end)

	-- Mobile Button Touch Drag & Tap Toggle
	do
		local isDraggingBtn = false
		local dragStartPos = Vector2.zero
		local btnStartPos = UDim2.new()
		local hasMoved = false

		MobileToggleBtn.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				isDraggingBtn = true
				hasMoved = false
				dragStartPos = Vector2.new(input.Position.X, input.Position.Y)
				btnStartPos = MobileToggleBtn.Position

				local moveConn: RBXScriptConnection? = nil
				local endConn: RBXScriptConnection? = nil

				moveConn = UserInputService.InputChanged:Connect(function(moveInput: InputObject)
					if isDraggingBtn and (moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch) then
						local curPos = Vector2.new(moveInput.Position.X, moveInput.Position.Y)
						local delta = curPos - dragStartPos
						if delta.Magnitude > 6 then
							hasMoved = true
							MobileToggleBtn.Position = UDim2.new(
								btnStartPos.X.Scale,
								btnStartPos.X.Offset + delta.X,
								btnStartPos.Y.Scale,
								btnStartPos.Y.Offset + delta.Y
							)
						end
					end
				end)

				endConn = UserInputService.InputEnded:Connect(function(endInput: InputObject)
					if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
						isDraggingBtn = false
						if moveConn then moveConn:Disconnect() end
						if endConn then endConn:Disconnect() end
						if not hasMoved then
							tween(MobileToggleBtn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								Size = UDim2.new(0, 38, 0, 38)
							})
						task.delay(0.08, function()
								tween(MobileToggleBtn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
									Size = UDim2.new(0, 44, 0, 44)
								})
							end)
							toggleWindowState()
						end
					end
				end)
			end
		end)
	end

	trackConnection(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		local code = input.KeyCode
		if code == Enum.KeyCode.LeftControl
			or code == Enum.KeyCode.RightControl
			or (toggleKey and code == toggleKey)
		then
			local focused = UserInputService:GetFocusedTextBox()
			if focused then
				if focused:IsDescendantOf(ScreenGui) then
					pcall(function() focused:ReleaseFocus() end)
				else
					return
				end
			end
			toggleWindowState()
		end
	end))

	-- ========================================================================
	-- LEFT SIDEBAR (Width: 210px - Discord Box, Default Home Tab, User Footer)
	-- ========================================================================
	local Sidebar = Instance.new("Frame")
	Sidebar.Name = "Sidebar"
	Sidebar.Size = UDim2.new(0, 210, 1, -42)
	Sidebar.Position = UDim2.new(0, 0, 0, 42)
	Sidebar.BackgroundColor3 = THEME.SidebarBackground
	Sidebar.BorderSizePixel = 0
	Sidebar.Parent = MainFrame

	-- Discord Brand Box (Top: 190x54px, #161616, UIStroke #262626)
	local DiscordBox = Instance.new("Frame")
	DiscordBox.Name = "DiscordBrandBox"
	DiscordBox.Size = UDim2.new(0, 190, 0, 54)
	DiscordBox.Position = UDim2.new(0, 12, 0, 2)
	DiscordBox.BackgroundColor3 = THEME.DiscordBoxBg
	DiscordBox.BorderSizePixel = 0
	DiscordBox.Parent = Sidebar
	createCorner(DiscordBox, 8)
	createStroke(DiscordBox, THEME.Stroke, 1, 0.2)

	local LogoIcon = Instance.new("ImageLabel")
	LogoIcon.Name = "LogoImage"
	LogoIcon.Size = UDim2.new(0, 36, 0, 36)
	LogoIcon.Position = UDim2.new(0, 9, 0.5, 0)
	LogoIcon.AnchorPoint = Vector2.new(0, 0.5)
	LogoIcon.BackgroundColor3 = Color3.fromHex("#1E1E22")
	LogoIcon.BorderSizePixel = 0
	LogoIcon.Image = logoId
	LogoIcon.ImageTransparency = if logoId == ASSETS.DefaultLogo then 0.85 else 0
	LogoIcon.Parent = DiscordBox
	createCorner(LogoIcon, 8)
	createStroke(LogoIcon, Color3.fromHex("#2E2E34"), 1, 0.1)

	local LogoGrad = Instance.new("UIGradient")
	LogoGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#2C2D32")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("#141416")),
	})
	LogoGrad.Rotation = 45
	LogoGrad.Parent = LogoIcon

	local LogoLetter = Instance.new("TextLabel")
	LogoLetter.Size = UDim2.new(1, 0, 1, 0)
	LogoLetter.BackgroundTransparency = 1
	LogoLetter.Font = Enum.Font.GothamBold
	LogoLetter.Text = if logoId == ASSETS.DefaultLogo then "N" else ""
	LogoLetter.TextColor3 = THEME.TextPrimary
	LogoLetter.TextSize = 20
	LogoLetter.Parent = LogoIcon

	local LogoRedAccent = Instance.new("Frame")
	LogoRedAccent.Size = UDim2.new(0, 6, 0, 6)
	LogoRedAccent.Position = UDim2.new(1, -5, 0, 5)
	LogoRedAccent.AnchorPoint = Vector2.new(0.5, 0.5)
	LogoRedAccent.BackgroundColor3 = THEME.AccentRed
	LogoRedAccent.BorderSizePixel = 0
	LogoRedAccent.Parent = LogoIcon
	createCorner(LogoRedAccent, 6)

	local BrandTitle = Instance.new("TextLabel")
	BrandTitle.Size = UDim2.new(1, -80, 0, 16)
	BrandTitle.Position = UDim2.new(0, 53, 0, 11)
	BrandTitle.BackgroundTransparency = 1
	BrandTitle.Font = Enum.Font.GothamBold
	BrandTitle.Text = windowTitle
	BrandTitle.TextColor3 = THEME.TextPrimary
	BrandTitle.TextSize = 14
	BrandTitle.TextXAlignment = Enum.TextXAlignment.Left
	BrandTitle.TextTruncate = Enum.TextTruncate.AtEnd
	BrandTitle.Parent = DiscordBox

	local BrandSub = Instance.new("TextLabel")
	BrandSub.Size = UDim2.new(1, -74, 0, 14)
	BrandSub.Position = UDim2.new(0, 53, 0, 28)
	BrandSub.BackgroundTransparency = 1
	BrandSub.Font = Enum.Font.GothamMedium
	BrandSub.Text = windowSubtitle
	BrandSub.TextColor3 = THEME.TextSecondary
	BrandSub.TextSize = 10
	BrandSub.TextXAlignment = Enum.TextXAlignment.Left
	BrandSub.TextTruncate = Enum.TextTruncate.AtEnd
	BrandSub.Parent = DiscordBox

	local ExtIcon = Instance.new("ImageLabel")
	ExtIcon.Size = UDim2.new(0, 14, 0, 14)
	ExtIcon.Position = UDim2.new(1, -12, 0.5, 0)
	ExtIcon.AnchorPoint = Vector2.new(1, 0.5)
	ExtIcon.BackgroundTransparency = 1
	ExtIcon.Image = ASSETS.ExternalLink
	ExtIcon.ImageColor3 = THEME.TextSecondary
	ExtIcon.Parent = DiscordBox

	-- Full-box clickable button so clicking anywhere on the Discord card/link opens it
	local CopyDiscordBtn = Instance.new("TextButton")
	CopyDiscordBtn.Name = "DiscordCardButton"
	CopyDiscordBtn.Size = UDim2.new(1, 0, 1, 0)
	CopyDiscordBtn.Position = UDim2.new(0, 0, 0, 0)
	CopyDiscordBtn.BackgroundTransparency = 1
	CopyDiscordBtn.Text = ""
	CopyDiscordBtn.ZIndex = 5
	CopyDiscordBtn.Parent = DiscordBox

	CopyDiscordBtn.MouseEnter:Connect(function()
		tween(DiscordBox, TWEEN_FAST, { BackgroundColor3 = THEME.CardHover })
		tween(BrandSub, TWEEN_FAST, { TextColor3 = THEME.TextPrimary })
		tween(ExtIcon, TWEEN_FAST, { ImageColor3 = THEME.TextPrimary })
	end)
	CopyDiscordBtn.MouseLeave:Connect(function()
		tween(DiscordBox, TWEEN_FAST, { BackgroundColor3 = THEME.DiscordBoxBg })
		tween(BrandSub, TWEEN_FAST, { TextColor3 = THEME.TextSecondary })
		tween(ExtIcon, TWEEN_FAST, { ImageColor3 = THEME.TextSecondary })
	end)
	CopyDiscordBtn.MouseButton1Click:Connect(function()
		local inviteUrl = "https://discord.gg/4cZBCyDFmX"
		local inviteCode = "4cZBCyDFmX"
		local fenv = getfenv() :: any
		local genv = (type(fenv.getgenv) == "function" and fenv.getgenv()) or _G or fenv

		-- 1. Try all Executor & Engine Browser-Opening APIs
		task.spawn(function()
			local openFn = genv.openurl
				or genv.OpenUrl
				or genv.browseurl
				or genv.BrowseUrl
				or genv.OpenBrowserWindow
				or fenv.openurl
				or fenv.browseurl
			if type(openFn) == "function" then
				pcall(openFn, inviteUrl)
			end
			pcall(function()
				game:GetService("LinkingService"):OpenUrl(inviteUrl)
			end)
			pcall(function()
				game:GetService("BrowserService"):OpenBrowserWindow(inviteUrl)
			end)
			pcall(function()
				GuiService:OpenBrowserWindow(inviteUrl)
			end)
		end)

		-- 2. Trigger Discord App Invite Modal via local RPC (ports 6463-6465)
		task.spawn(function()
			local reqFn = genv.request
				or genv.http_request
				or (type(genv.syn) == "table" and genv.syn.request)
				or (type(genv.http) == "table" and genv.http.request)
				or fenv.request
				or fenv.http_request
			if type(reqFn) == "function" then
				for port = 6463, 6465 do
					pcall(function()
						reqFn({
							Url = "http://127.0.0.1:" .. tostring(port) .. "/rpc?v=1",
							Method = "POST",
							Headers = {
								["Content-Type"] = "application/json",
								["Origin"] = "https://discord.com",
							},
							Body = HttpService:JSONEncode({
								cmd = "INVITE_BROWSER",
								args = { code = inviteCode },
								nonce = HttpService:GenerateGUID(false),
							}),
						})
					end)
				end
			end
		end)

		-- 3. Copy invite link to clipboard
		local clip = genv.setclipboard or genv.toclipboard or fenv.setclipboard or fenv.toclipboard
		if type(clip) == "function" then
			pcall(clip, inviteUrl)
		end

		NightSystem:Notify({
			Title = windowTitle,
			Content = "Discord geöffnet & Link kopiert! (" .. inviteUrl .. ")",
			Duration = 3,
		})
	end)

	-- Sidebar Navigation Scrolling Container (Scrollable tab list with auto-canvas size)
	local NavContainer = Instance.new("ScrollingFrame")
	NavContainer.Name = "Navigation"
	NavContainer.Size = UDim2.new(0, 196, 1, -126)
	NavContainer.Position = UDim2.new(0, 8, 0, 68)
	NavContainer.BackgroundTransparency = 1
	NavContainer.BorderSizePixel = 0
	NavContainer.ClipsDescendants = true
	NavContainer.ScrollingDirection = Enum.ScrollingDirection.Y
	NavContainer.ScrollBarThickness = 2
	NavContainer.ScrollBarImageColor3 = THEME.Accent
	NavContainer.ScrollBarImageTransparency = 0.4
	NavContainer.VerticalScrollBarInset = Enum.ScrollBarInset.None
	NavContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	NavContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	NavContainer.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	NavContainer.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	NavContainer.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	NavContainer.Parent = Sidebar
	createPadding(NavContainer, 2, 8, 2, 4)

	local NavListLayout = Instance.new("UIListLayout")
	NavListLayout.FillDirection = Enum.FillDirection.Vertical
	NavListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	NavListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	NavListLayout.Padding = UDim.new(0, 4)
	NavListLayout.Parent = NavContainer

	local navUpdateQueued = false
	local function updateNavCanvasAndScrollCheck()
		if navUpdateQueued then return end
		navUpdateQueued = true
		task.defer(function()
			navUpdateQueued = false
			if not NavContainer or not NavContainer.Parent then return end

			-- 1. Check & count how many tabs and categories are currently in the sidebar
			local tabCount = 0
			local categoryCount = 0

			for _, child in ipairs(NavContainer:GetChildren()) do
				if child:IsA("TextButton") and child.Visible then
					tabCount += 1
				elseif child:IsA("Frame") and string.find(child.Name, "Category_", 1, true) and child.Visible then
					categoryCount += 1
				end
			end

			-- 2. Calculate exact total height requirement:
			-- Each Tab button = 36px height
			-- Padding between items in UIListLayout = 4px
			-- Category header = 22px height
			-- Top padding = 2px, Bottom padding = 14px
			local TAB_HEIGHT = 36
			local ITEM_GAP = 4
			local CAT_HEIGHT = 22
			local TOP_PAD = 2
			local BOTTOM_PAD = 14

			local totalItems = tabCount + categoryCount
			local totalCalculatedHeight = TOP_PAD + BOTTOM_PAD
				+ (tabCount * TAB_HEIGHT)
				+ (categoryCount * CAT_HEIGHT)
				+ (math.max(0, totalItems - 1) * ITEM_GAP)

			-- Also take layout content size if higher
			local layoutH = NavListLayout.AbsoluteContentSize.Y
			if layoutH > 0 then
				totalCalculatedHeight = math.max(totalCalculatedHeight, layoutH + BOTTOM_PAD)
			end

			-- 3. Check visible navigation height based on current / standard UI size
			local currentNavHeight = NavContainer.AbsoluteSize.Y
			if currentNavHeight <= 0 then
				-- Standard UI height is 460px:
				-- TopBar: 42px, DiscordCard area: 68px, Footer area: 56px => 460 - 42 - 68 - 56 = 294px
				local standardWindowHeight = 460
				currentNavHeight = standardWindowHeight - 42 - 68 - 56
			end

			-- 4. Check if tabs exceed visible space and enable scrolling accordingly
			local shouldScroll = totalCalculatedHeight > currentNavHeight

			NavContainer.CanvasSize = UDim2.new(0, 0, 0, totalCalculatedHeight)
			NavContainer.ScrollingEnabled = true
			NavContainer.ScrollBarImageTransparency = if shouldScroll then 0.4 else 1
			NavContainer.ScrollBarThickness = if shouldScroll then 2 else 0

			if not shouldScroll and NavContainer.CanvasPosition.Y > 0 then
				NavContainer.CanvasPosition = Vector2.new(0, 0)
			end
		end)
	end

	NavListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateNavCanvasAndScrollCheck)
	NavContainer.ChildAdded:Connect(function()
		task.defer(updateNavCanvasAndScrollCheck)
	end)
	NavContainer.ChildRemoved:Connect(function()
		task.defer(updateNavCanvasAndScrollCheck)
	end)
	NavContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateNavCanvasAndScrollCheck)
	Sidebar:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateNavCanvasAndScrollCheck)
	MainFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateNavCanvasAndScrollCheck)
	task.defer(updateNavCanvasAndScrollCheck)

	local function bindMouseWheelToNav(element: GuiObject)
		element.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				local scrollDelta = input.Position.Z
				local step = 38
				local maxScroll = math.max(0, NavContainer.CanvasSize.Y.Offset - NavContainer.AbsoluteSize.Y)
				if maxScroll > 0 then
					local newY = math.clamp(NavContainer.CanvasPosition.Y - (scrollDelta * step), 0, maxScroll)
					NavContainer.CanvasPosition = Vector2.new(0, newY)
				end
			end
		end)
	end
	bindMouseWheelToNav(NavContainer)

	-- Vertical White Accent Bar (3x16px) for active Sidebar Tab
	local ActiveIndicator = Instance.new("Frame")
	ActiveIndicator.Name = "ActiveIndicator"
	ActiveIndicator.Size = UDim2.new(0, 3, 0, 16)
	ActiveIndicator.Position = UDim2.new(0, 10, 0, 78)
	ActiveIndicator.BackgroundColor3 = THEME.TextPrimary
	ActiveIndicator.BorderSizePixel = 0
	ActiveIndicator.ZIndex = 5
	ActiveIndicator.Parent = Sidebar
	createCorner(ActiveIndicator, 2)

	-- Bottom User Footer (1:1 Original: Divider #222222, 32x32 Avatar, DisplayName & @Username)
	local UserFooter = Instance.new("Frame")
	UserFooter.Name = "UserFooter"
	UserFooter.Size = UDim2.new(0, 190, 0, 50)
	UserFooter.Position = UDim2.new(0, 12, 1, -52)
	UserFooter.BackgroundTransparency = 1
	UserFooter.Parent = Sidebar

	local FooterDivider = Instance.new("Frame")
	FooterDivider.Size = UDim2.new(1, 0, 0, 1)
	FooterDivider.BackgroundColor3 = THEME.DividerFooter
	FooterDivider.BorderSizePixel = 0
	FooterDivider.Parent = UserFooter

	local FooterAvatar = Instance.new("ImageLabel")
	FooterAvatar.Name = "Avatar"
	FooterAvatar.Size = UDim2.new(0, 32, 0, 32)
	FooterAvatar.Position = UDim2.new(0, 2, 0, 11)
	FooterAvatar.BackgroundColor3 = THEME.DiscordBoxBg
	FooterAvatar.BorderSizePixel = 0
	FooterAvatar.Parent = UserFooter
	local footerAvatarCorner = Instance.new("UICorner")
	footerAvatarCorner.CornerRadius = UDim.new(1, 0)
	footerAvatarCorner.Parent = FooterAvatar

	local FooterDisplayName = Instance.new("TextLabel")
	FooterDisplayName.Size = UDim2.new(1, -96, 0, 15)
	FooterDisplayName.Position = UDim2.new(0, 42, 0, 12)
	FooterDisplayName.BackgroundTransparency = 1
	FooterDisplayName.Font = Enum.Font.GothamBold
	FooterDisplayName.Text = LocalPlayer.DisplayName
	FooterDisplayName.TextColor3 = THEME.TextPrimary
	FooterDisplayName.TextSize = 13
	FooterDisplayName.TextXAlignment = Enum.TextXAlignment.Left
	FooterDisplayName.TextTruncate = Enum.TextTruncate.AtEnd
	FooterDisplayName.Parent = UserFooter

	local FooterUsername = Instance.new("TextLabel")
	FooterUsername.Size = UDim2.new(1, -96, 0, 13)
	FooterUsername.Position = UDim2.new(0, 42, 0, 27)
	FooterUsername.BackgroundTransparency = 1
	FooterUsername.Font = Enum.Font.GothamMedium
	FooterUsername.Text = "@" .. LocalPlayer.Name
	FooterUsername.TextColor3 = THEME.TextSecondary
	FooterUsername.TextSize = 11
	FooterUsername.TextXAlignment = Enum.TextXAlignment.Left
	FooterUsername.TextTruncate = Enum.TextTruncate.AtEnd
	FooterUsername.Parent = UserFooter

	-- Live Roblox FPS Badge next to Avatar / Name in UserFooter
	local FpsBadge = Instance.new("Frame")
	FpsBadge.Name = "FpsBadge"
	FpsBadge.Size = UDim2.new(0, 48, 0, 20)
	FpsBadge.Position = UDim2.new(1, 0, 0, 17)
	FpsBadge.AnchorPoint = Vector2.new(1, 0)
	FpsBadge.BackgroundColor3 = THEME.DiscordBoxBg
	FpsBadge.BorderSizePixel = 0
	FpsBadge.Parent = UserFooter
	createCorner(FpsBadge, 6)
	createStroke(FpsBadge, THEME.Stroke, 1, 0.2)

	local FpsLabel = Instance.new("TextLabel")
	FpsLabel.Name = "FpsLabel"
	FpsLabel.Size = UDim2.new(1, 0, 1, 0)
	FpsLabel.BackgroundTransparency = 1
	FpsLabel.Font = Enum.Font.GothamBold
	FpsLabel.Text = "60 FPS"
	FpsLabel.TextColor3 = THEME.TextSecondary
	FpsLabel.TextSize = 10
	FpsLabel.Parent = FpsBadge

	do
		local frames = 0
		local lastTick = os.clock()
		trackConnection(RunService.RenderStepped:Connect(function()
			if not MainFrame.Visible then return end
			frames += 1
			local now = os.clock()
			if now - lastTick >= 0.5 then
				local currentFps = math.clamp(math.round(frames / (now - lastTick)), 1, 999)
				frames = 0
				lastTick = now
				FpsLabel.Text = tostring(currentFps) .. " FPS"
			end
		end))
	end

	-- ========================================================================
	-- RIGHT CONTENT CONTAINER (#16181A with #1E2528 / #141517 UIGradient)
	-- Slightly inset at bottom-right to leave breathing room for the resize handle
	-- ========================================================================
	local ContentFrame = Instance.new("Frame")
	ContentFrame.Name = "ContentContainer"
	ContentFrame.Size = UDim2.new(1, -228, 1, -58)
	ContentFrame.Position = UDim2.new(0, 212, 0, 42)
	ContentFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	ContentFrame.BorderSizePixel = 0
	ContentFrame.ClipsDescendants = true
	ContentFrame.Parent = MainFrame
	createCorner(ContentFrame, 10)
	createStroke(ContentFrame, THEME.Stroke, 1, 0.2)

	local ContentGradient = Instance.new("UIGradient")
	ContentGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.ContentGradBottomLeft),
		ColorSequenceKeypoint.new(0.5, THEME.ContentBase),
		ColorSequenceKeypoint.new(1, THEME.ContentGradTopRight),
	})
	ContentGradient.Rotation = -45
	ContentGradient.Parent = ContentFrame

	-- ========================================================================
	-- BOTTOM-RIGHT RESIZE HANDLE (Slightly inset, rounded & semi-transparent)
	-- ========================================================================
	local ResizeHandle = Instance.new("TextButton")
	ResizeHandle.Name = "ResizeHandle"
	ResizeHandle.Size = UDim2.new(0, 22, 0, 22)
	ResizeHandle.Position = UDim2.new(1, -4, 1, -4)
	ResizeHandle.AnchorPoint = Vector2.new(1, 1)
	ResizeHandle.BackgroundColor3 = Color3.fromHex("#2A2E33")
	ResizeHandle.BackgroundTransparency = 0.65
	ResizeHandle.BorderSizePixel = 0
	ResizeHandle.AutoButtonColor = false
	ResizeHandle.Text = ""
	ResizeHandle.ZIndex = 25
	ResizeHandle.Parent = MainFrame
	createCorner(ResizeHandle, 8)
	local ResizeStroke = createStroke(ResizeHandle, THEME.TextSecondary, 1, 0.55)

	-- Subtle diagonal grip pills inside the rounded resize handle
	local GripBar1 = Instance.new("Frame")
	GripBar1.Size = UDim2.new(0, 10, 0, 2)
	GripBar1.Position = UDim2.new(0.5, 1, 0.5, 1)
	GripBar1.AnchorPoint = Vector2.new(0.5, 0.5)
	GripBar1.Rotation = -45
	GripBar1.BackgroundColor3 = THEME.TextPrimary
	GripBar1.BackgroundTransparency = 0.45
	GripBar1.BorderSizePixel = 0
	GripBar1.ZIndex = 26
	GripBar1.Parent = ResizeHandle
	createCorner(GripBar1, 2)

	local GripBar2 = Instance.new("Frame")
	GripBar2.Size = UDim2.new(0, 5, 0, 2)
	GripBar2.Position = UDim2.new(0.5, 4, 0.5, 4)
	GripBar2.AnchorPoint = Vector2.new(0.5, 0.5)
	GripBar2.Rotation = -45
	GripBar2.BackgroundColor3 = THEME.TextPrimary
	GripBar2.BackgroundTransparency = 0.45
	GripBar2.BorderSizePixel = 0
	GripBar2.ZIndex = 26
	GripBar2.Parent = ResizeHandle
	createCorner(GripBar2, 2)

	do
		local isResizing = false
		local resizeInput: InputObject? = nil
		local resizeStartMouse = Vector2.zero
		local startSize = Vector2.zero
		local startPos = UDim2.new()
		local minWindowSize = Vector2.new(540, 340)
		local maxWindowSize = Vector2.new(1200, 820)

		ResizeHandle.MouseEnter:Connect(function()
			tween(ResizeHandle, TWEEN_FAST, { BackgroundTransparency = 0.35 })
			tween(ResizeStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0.2 })
			tween(GripBar1, TWEEN_FAST, { BackgroundTransparency = 0.1 })
			tween(GripBar2, TWEEN_FAST, { BackgroundTransparency = 0.1 })
		end)

		ResizeHandle.MouseLeave:Connect(function()
			if not isResizing then
				tween(ResizeHandle, TWEEN_FAST, { BackgroundTransparency = 0.65 })
				tween(ResizeStroke, TWEEN_FAST, { Color = THEME.TextSecondary, Transparency = 0.55 })
				tween(GripBar1, TWEEN_FAST, { BackgroundTransparency = 0.45 })
				tween(GripBar2, TWEEN_FAST, { BackgroundTransparency = 0.45 })
			end
		end)

		ResizeHandle.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				isResizing = true
				resizeStartMouse = Vector2.new(input.Position.X, input.Position.Y)
				startSize = Vector2.new(MainFrame.AbsoluteSize.X, MainFrame.AbsoluteSize.Y)
				startPos = MainFrame.Position

				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						isResizing = false
						normalSize = MainFrame.Size
						tween(ResizeHandle, TWEEN_FAST, { BackgroundTransparency = 0.65 })
						tween(ResizeStroke, TWEEN_FAST, { Color = THEME.TextSecondary, Transparency = 0.55 })
						tween(GripBar1, TWEEN_FAST, { BackgroundTransparency = 0.45 })
						tween(GripBar2, TWEEN_FAST, { BackgroundTransparency = 0.45 })
					end
				end)
			end
		end)

		ResizeHandle.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				resizeInput = input
			end
		end)

		trackConnection(UserInputService.InputChanged:Connect(function(input: InputObject)
			if input == resizeInput and isResizing then
				local currentMouse = Vector2.new(input.Position.X, input.Position.Y)
				local delta = currentMouse - resizeStartMouse

				local newW = math.clamp(startSize.X + delta.X, minWindowSize.X, maxWindowSize.X)
				local newH = math.clamp(startSize.Y + delta.Y, minWindowSize.Y, maxWindowSize.Y)
				local actualDeltaX = newW - startSize.X
				local actualDeltaY = newH - startSize.Y

				-- Keep top-left corner anchored while resizing from bottom-right
				MainFrame.Size = UDim2.new(0, newW, 0, newH)
				MainFrame.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + math.round(actualDeltaX * 0.5),
					startPos.Y.Scale,
					startPos.Y.Offset + math.round(actualDeltaY * 0.5)
				)
			end
		end))
	end

	-- ========================================================================
	-- SIDEBAR TAB ENGINE (Default Built-in Home Tab + Dynamic Script Tab)
	-- ========================================================================
	type SidebarTab = {
		Button: TextButton,
		Stroke: UIStroke,
		Icon: ImageLabel,
		Label: TextLabel,
		Page: Frame,
	}

	local SidebarTabs: { [string]: SidebarTab } = {}
	local activeTabName = ""
	local navOrder = 0

	local function nextNavOrder(): number
		navOrder += 1
		return navOrder
	end

	local function updateActiveIndicator(instant: boolean?)
		if (ScriptsHubPage and ScriptsHubPage.Visible) or activeTabName == "" then
			ActiveIndicator.Visible = false
			return
		end
		local target = SidebarTabs[activeTabName]
		if not target or not target.Button or not target.Button.Parent then
			ActiveIndicator.Visible = false
			return
		end
		if not target.Button.Visible then
			ActiveIndicator.Visible = false
			return
		end

		local btnAbsY = target.Button.AbsolutePosition.Y
		local btnH = target.Button.AbsoluteSize.Y
		local navAbsY = NavContainer.AbsolutePosition.Y
		local navH = NavContainer.AbsoluteSize.Y
		local sideAbsY = Sidebar.AbsolutePosition.Y

		local relY = (btnAbsY - sideAbsY) + (btnH - 16) / 2
		local navTopRel = navAbsY - sideAbsY
		local navBottomRel = navTopRel + navH

		-- Check if target button is within visible bounds of NavContainer
		if relY < navTopRel - 4 or (relY + 16) > navBottomRel + 4 then
			ActiveIndicator.Visible = false
			return
		end

		ActiveIndicator.Visible = true
		local pos = UDim2.new(0, 10, 0, relY)
		if instant then
			ActiveIndicator.Position = pos
		else
			tween(ActiveIndicator, TWEEN_SMOOTH, { Position = pos })
		end
	end

	local function scrollTabIntoView(btn: TextButton)
		task.defer(function()
			if not btn or not btn.Parent then
				return
			end
			local btnAbsY = btn.AbsolutePosition.Y
			local navAbsY = NavContainer.AbsolutePosition.Y
			local navH = NavContainer.AbsoluteSize.Y
			local btnH = btn.AbsoluteSize.Y

			if btnAbsY < navAbsY + 4 then
				local diff = (navAbsY + 4) - btnAbsY
				local targetY = math.max(0, NavContainer.CanvasPosition.Y - diff)
				tween(NavContainer, TWEEN_FAST, { CanvasPosition = Vector2.new(0, targetY) })
			elseif (btnAbsY + btnH) > (navAbsY + navH - 4) then
				local diff = (btnAbsY + btnH) - (navAbsY + navH - 4)
				local targetY = NavContainer.CanvasPosition.Y + diff
				tween(NavContainer, TWEEN_FAST, { CanvasPosition = Vector2.new(0, targetY) })
			end
			updateActiveIndicator(false)
		end)
	end

	NavContainer:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		updateActiveIndicator(true)
	end)

	local function createSidebarCategory(catTitle: string): (Frame, TextLabel)
		local wrapper = Instance.new("Frame")
		wrapper.Name = "Category_" .. catTitle
		wrapper.Size = UDim2.new(0, 186, 0, 22)
		wrapper.BackgroundTransparency = 1
		wrapper.LayoutOrder = nextNavOrder()
		wrapper.Parent = NavContainer

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -6, 0, 14)
		lbl.Position = UDim2.new(0, 6, 1, -14)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBold
		lbl.Text = string.upper(catTitle)
		lbl.TextColor3 = THEME.TextCategory
		lbl.TextSize = 10
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = wrapper

		wrapper:GetPropertyChangedSignal("Visible"):Connect(updateNavCanvasAndScrollCheck)
		bindMouseWheelToNav(wrapper)
		updateNavCanvasAndScrollCheck()

		return wrapper, lbl
	end

	local ScriptsHubPage: Frame? = nil

	local function switchSidebarTab(tabName: string, instant: boolean?)
		if ScriptsHubPage and ScriptsHubPage.Visible then
			ScriptsHubPage.Visible = false
			if activeTabName == tabName and SidebarTabs[tabName] then
				SidebarTabs[tabName].Page.Visible = true
				updateActiveIndicator(instant)
				return
			end
		end
		if activeTabName == tabName then
			return
		end
		local target = SidebarTabs[tabName]
		if not target then
			return
		end

		if activeTabName ~= "" and SidebarTabs[activeTabName] then
			local prev = SidebarTabs[activeTabName]
			tween(prev.Button, TWEEN_FAST, { BackgroundTransparency = 1 })
			tween(prev.Stroke, TWEEN_FAST, { Transparency = 1 })
			tween(prev.Label, TWEEN_FAST, { TextColor3 = THEME.TextTabInactive })
			tween(prev.Icon, TWEEN_FAST, { ImageColor3 = THEME.TextTabInactive })
			prev.Page.Visible = false
		end

		activeTabName = tabName

		if instant then
			target.Button.BackgroundColor3 = THEME.TabActiveBg
			target.Button.BackgroundTransparency = 0
			target.Stroke.Transparency = 0.2
			target.Label.TextColor3 = THEME.TextPrimary
			target.Icon.ImageColor3 = THEME.TextPrimary
		else
			tween(target.Button, TWEEN_FAST, {
				BackgroundColor3 = THEME.TabActiveBg,
				BackgroundTransparency = 0,
			})
			tween(target.Stroke, TWEEN_FAST, { Transparency = 0.2 })
			tween(target.Label, TWEEN_FAST, { TextColor3 = THEME.TextPrimary })
			tween(target.Icon, TWEEN_FAST, { ImageColor3 = THEME.TextPrimary })
		end

		scrollTabIntoView(target.Button)

		target.Page.Visible = true
		if not instant then
			target.Page.Position = UDim2.new(0, 0, 0, 8)
			tween(target.Page, TWEEN_MEDIUM, { Position = UDim2.new(0, 0, 0, 0) })
		else
			target.Page.Position = UDim2.new(0, 0, 0, 0)
		end
	end

	local function registerSidebarTab(tabName: string, iconAsset: string): (Frame, TextButton, TextLabel)
		local btn = Instance.new("TextButton")
		btn.Name = "Tab_" .. tabName
		btn.Size = UDim2.new(0, 186, 0, 36)
		btn.BackgroundColor3 = THEME.TabActiveBg
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Active = false
		btn.Text = ""
		btn.LayoutOrder = nextNavOrder()
		btn.Parent = NavContainer
		createCorner(btn, 8)

		local stroke = createStroke(btn, THEME.StrokeActive, 1, 1)

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(0, 16, 0, 16)
		icon.Position = UDim2.new(0, 14, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = iconAsset
		icon.ImageColor3 = THEME.TextTabInactive
		icon.Parent = btn

		local lbl = Instance.new("TextLabel")
		lbl.Name = "Title"
		lbl.Size = UDim2.new(1, -44, 1, 0)
		lbl.Position = UDim2.new(0, 38, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamMedium
		lbl.Text = tabName
		lbl.TextColor3 = THEME.TextTabInactive
		lbl.TextSize = 13
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = btn

		local page = Instance.new("Frame")
		page.Name = tabName .. "_Page"
		page.Size = UDim2.new(1, 0, 1, 0)
		page.BackgroundTransparency = 1
		page.Visible = false
		page.Parent = ContentFrame

		SidebarTabs[tabName] = {
			Button = btn,
			Stroke = stroke,
			Icon = icon,
			Label = lbl,
			Page = page,
		}

		btn.MouseEnter:Connect(function()
			if activeTabName ~= tabName then
				tween(btn, TWEEN_FAST, {
					BackgroundColor3 = THEME.TabHoverBg,
					BackgroundTransparency = 0.3,
				})
				tween(lbl, TWEEN_FAST, { TextColor3 = THEME.TextPrimary })
			end
		end)

		btn.MouseLeave:Connect(function()
			if activeTabName ~= tabName then
				tween(btn, TWEEN_FAST, { BackgroundTransparency = 1 })
				tween(lbl, TWEEN_FAST, { TextColor3 = THEME.TextTabInactive })
			end
		end)

		btn.MouseButton1Click:Connect(function()
			switchSidebarTab(tabName, false)
		end)

		btn:GetPropertyChangedSignal("Visible"):Connect(updateNavCanvasAndScrollCheck)
		bindMouseWheelToNav(btn)
		updateNavCanvasAndScrollCheck()

		return page, btn, lbl
	end

	-- ========================================================================
	-- 1. BUILT-IN DEFAULT "HOME" TAB (Always present in the UI by default!)
	-- ========================================================================
	local HomePage = registerSidebarTab("Home", ASSETS.Home)
	createPadding(HomePage, 24, 24, 24, 24)

	local HomeHeaderTitle = Instance.new("TextLabel")
	HomeHeaderTitle.Name = "HeaderTitle"
	HomeHeaderTitle.Size = UDim2.new(1, -140, 0, 20)
	HomeHeaderTitle.Position = UDim2.new(0, 0, 0, 0)
	HomeHeaderTitle.BackgroundTransparency = 1
	HomeHeaderTitle.Font = Enum.Font.GothamBold
	HomeHeaderTitle.Text = "Home"
	HomeHeaderTitle.TextColor3 = THEME.TextHeaderTitle
	HomeHeaderTitle.TextSize = 18
	HomeHeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
	HomeHeaderTitle.Parent = HomePage

	local HomeHeaderSub = Instance.new("TextLabel")
	HomeHeaderSub.Name = "HeaderSubtitle"
	HomeHeaderSub.Size = UDim2.new(1, -140, 0, 16)
	HomeHeaderSub.Position = UDim2.new(0, 0, 0, 22)
	HomeHeaderSub.BackgroundTransparency = 1
	HomeHeaderSub.Font = Enum.Font.GothamMedium
	HomeHeaderSub.Text = "Welcome back, @" .. LocalPlayer.Name
	HomeHeaderSub.TextColor3 = THEME.TextHeaderSub
	HomeHeaderSub.TextSize = 13
	HomeHeaderSub.TextXAlignment = Enum.TextXAlignment.Left
	HomeHeaderSub.Parent = HomePage

	-- Top-Right "All Scripts" Button in Home Tab (Sleek Pill with Grid Icon & Accent Indicator)
	local AllScriptsBtn = Instance.new("TextButton")
	AllScriptsBtn.Name = "AllScriptsButton"
	AllScriptsBtn.Size = UDim2.new(0, 128, 0, 34)
	AllScriptsBtn.Position = UDim2.new(1, 0, 0, 2)
	AllScriptsBtn.AnchorPoint = Vector2.new(1, 0)
	AllScriptsBtn.BackgroundColor3 = Color3.fromHex("#181B1E")
	AllScriptsBtn.BorderSizePixel = 0
	AllScriptsBtn.AutoButtonColor = false
	AllScriptsBtn.Text = ""
	AllScriptsBtn.Parent = HomePage
	createCorner(AllScriptsBtn, 8)
	local AllScriptsStroke = createStroke(AllScriptsBtn, Color3.fromHex("#2A2E33"), 1, 0.1)

	-- Mini 2x2 Grid Icon on the left of All Scripts button
	local GridIconHolder = Instance.new("Frame")
	GridIconHolder.Size = UDim2.new(0, 12, 0, 12)
	GridIconHolder.Position = UDim2.new(0, 12, 0.5, 0)
	GridIconHolder.AnchorPoint = Vector2.new(0, 0.5)
	GridIconHolder.BackgroundTransparency = 1
	GridIconHolder.Parent = AllScriptsBtn

	for _, pos in ipairs({
		UDim2.new(0, 0, 0, 0),
		UDim2.new(1, -5, 0, 0),
		UDim2.new(0, 0, 1, -5),
		UDim2.new(1, -5, 1, -5),
	}) do
		local sq = Instance.new("Frame")
		sq.Size = UDim2.new(0, 5, 0, 5)
		sq.Position = pos
		sq.BackgroundColor3 = THEME.Accent
		sq.BackgroundTransparency = 0.15
		sq.BorderSizePixel = 0
		sq.Parent = GridIconHolder
		createCorner(sq, 1)
	end

	local AllScriptsLabel = Instance.new("TextLabel")
	AllScriptsLabel.Size = UDim2.new(1, -54, 1, 0)
	AllScriptsLabel.Position = UDim2.new(0, 30, 0, 0)
	AllScriptsLabel.BackgroundTransparency = 1
	AllScriptsLabel.Font = Enum.Font.GothamBold
	AllScriptsLabel.Text = "All Scripts"
	AllScriptsLabel.TextColor3 = THEME.TextPrimary
	AllScriptsLabel.TextSize = 12
	AllScriptsLabel.TextXAlignment = Enum.TextXAlignment.Left
	AllScriptsLabel.Parent = AllScriptsBtn

	local AllScriptsArrow = Instance.new("ImageLabel")
	AllScriptsArrow.Size = UDim2.new(0, 14, 0, 14)
	AllScriptsArrow.Position = UDim2.new(1, -10, 0.5, 0)
	AllScriptsArrow.AnchorPoint = Vector2.new(1, 0.5)
	AllScriptsArrow.BackgroundTransparency = 1
	AllScriptsArrow.Image = ASSETS.ChevronRight
	AllScriptsArrow.ImageColor3 = THEME.TextSecondary
	AllScriptsArrow.Parent = AllScriptsBtn

	AllScriptsBtn.MouseEnter:Connect(function()
		tween(AllScriptsBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#22262B") })
		tween(AllScriptsStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0 })
		tween(AllScriptsArrow, TWEEN_FAST, { ImageColor3 = THEME.Accent, Position = UDim2.new(1, -8, 0.5, 0) })
	end)
	AllScriptsBtn.MouseLeave:Connect(function()
		tween(AllScriptsBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#181B1E") })
		tween(AllScriptsStroke, TWEEN_FAST, { Color = Color3.fromHex("#2A2E33"), Transparency = 0.1 })
		tween(AllScriptsArrow, TWEEN_FAST, { ImageColor3 = THEME.TextSecondary, Position = UDim2.new(1, -10, 0.5, 0) })
	end)

	-- Dedicated "All Scripts" Hub View (Opened when clicking All Scripts in Home Tab)
	ScriptsHubPage = Instance.new("Frame")
	ScriptsHubPage.Name = "ScriptsHub_Page"
	ScriptsHubPage.Size = UDim2.new(1, 0, 1, 0)
	ScriptsHubPage.BackgroundTransparency = 1
	ScriptsHubPage.Visible = false
	ScriptsHubPage.Parent = ContentFrame
	createPadding(ScriptsHubPage, 24, 24, 24, 24)

	local HubHeaderTitle = Instance.new("TextLabel")
	HubHeaderTitle.Size = UDim2.new(1, -140, 0, 20)
	HubHeaderTitle.Position = UDim2.new(0, 0, 0, 0)
	HubHeaderTitle.BackgroundTransparency = 1
	HubHeaderTitle.Font = Enum.Font.GothamBold
	HubHeaderTitle.Text = "Night System Scripts"
	HubHeaderTitle.TextColor3 = THEME.TextHeaderTitle
	HubHeaderTitle.TextSize = 18
	HubHeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
	HubHeaderTitle.Parent = ScriptsHubPage

	local HubHeaderSub = Instance.new("TextLabel")
	HubHeaderSub.Size = UDim2.new(1, -140, 0, 16)
	HubHeaderSub.Position = UDim2.new(0, 0, 0, 22)
	HubHeaderSub.BackgroundTransparency = 1
	HubHeaderSub.Font = Enum.Font.GothamMedium
	HubHeaderSub.Text = "17 Official Scripts • Click Execute to run or Copy for clipboard"
	HubHeaderSub.TextColor3 = THEME.TextHeaderSub
	HubHeaderSub.TextSize = 13
	HubHeaderSub.TextXAlignment = Enum.TextXAlignment.Left
	HubHeaderSub.Parent = ScriptsHubPage

	local BackToHomeBtn = Instance.new("TextButton")
	BackToHomeBtn.Name = "BackToHomeButton"
	BackToHomeBtn.Size = UDim2.new(0, 118, 0, 32)
	BackToHomeBtn.Position = UDim2.new(1, 0, 0, 2)
	BackToHomeBtn.AnchorPoint = Vector2.new(1, 0)
	BackToHomeBtn.BackgroundColor3 = Color3.fromHex("#181B1E")
	BackToHomeBtn.BorderSizePixel = 0
	BackToHomeBtn.AutoButtonColor = false
	BackToHomeBtn.Font = Enum.Font.GothamBold
	BackToHomeBtn.Text = "‹  Back to Home"
	BackToHomeBtn.TextColor3 = THEME.TextPrimary
	BackToHomeBtn.TextSize = 12
	BackToHomeBtn.Parent = ScriptsHubPage
	createCorner(BackToHomeBtn, 8)
	local BackHomeStroke = createStroke(BackToHomeBtn, Color3.fromHex("#2A2E33"), 1, 0.1)

	BackToHomeBtn.MouseEnter:Connect(function()
		tween(BackToHomeBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#22262B") })
		tween(BackHomeStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0 })
	end)
	BackToHomeBtn.MouseLeave:Connect(function()
		tween(BackToHomeBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#181B1E") })
		tween(BackHomeStroke, TWEEN_FAST, { Color = Color3.fromHex("#2A2E33"), Transparency = 0.1 })
	end)

	-- Search Bar inside All Scripts Hub
	local HubSearchBar = Instance.new("Frame")
	HubSearchBar.Name = "HubSearchBar"
	HubSearchBar.Size = UDim2.new(1, 0, 0, 32)
	HubSearchBar.Position = UDim2.new(0, 0, 0, 46)
	HubSearchBar.BackgroundColor3 = THEME.CardBackground
	HubSearchBar.BorderSizePixel = 0
	HubSearchBar.Parent = ScriptsHubPage
	createCorner(HubSearchBar, 8)
	local HubSearchStroke = createStroke(HubSearchBar, THEME.Stroke, 1, 0.2)

	local HubSearchIcon = Instance.new("ImageLabel")
	HubSearchIcon.Size = UDim2.new(0, 14, 0, 14)
	HubSearchIcon.Position = UDim2.new(0, 12, 0.5, 0)
	HubSearchIcon.AnchorPoint = Vector2.new(0, 0.5)
	HubSearchIcon.BackgroundTransparency = 1
	HubSearchIcon.Image = ASSETS.Search
	HubSearchIcon.ImageColor3 = THEME.TextSecondary
	HubSearchIcon.Parent = HubSearchBar

	local HubSearchBox = Instance.new("TextBox")
	HubSearchBox.Name = "HubSearchBox"
	HubSearchBox.Size = UDim2.new(1, -38, 1, 0)
	HubSearchBox.Position = UDim2.new(0, 32, 0, 0)
	HubSearchBox.BackgroundTransparency = 1
	HubSearchBox.Font = Enum.Font.GothamMedium
	HubSearchBox.PlaceholderText = "Search 17 Night System scripts (e.g. MM2, Arsenal, MainEH, Build A Boat)..."
	HubSearchBox.PlaceholderColor3 = THEME.TextSecondary
	HubSearchBox.Text = ""
	HubSearchBox.TextColor3 = THEME.TextPrimary
	HubSearchBox.TextSize = 12
	HubSearchBox.TextXAlignment = Enum.TextXAlignment.Left
	HubSearchBox.ClearTextOnFocus = false
	HubSearchBox.Parent = HubSearchBar

	HubSearchBox.Focused:Connect(function()
		tween(HubSearchStroke, TWEEN_FAST, { Color = THEME.StrokeActive, Transparency = 0 })
		tween(HubSearchIcon, TWEEN_FAST, { ImageColor3 = THEME.TextPrimary })
	end)
	HubSearchBox.FocusLost:Connect(function()
		tween(HubSearchStroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.2 })
		tween(HubSearchIcon, TWEEN_FAST, { ImageColor3 = THEME.TextSecondary })
	end)

	local HubScroll = Instance.new("ScrollingFrame")
	HubScroll.Name = "HubScriptsScroll"
	HubScroll.Size = UDim2.new(1, 0, 1, -86)
	HubScroll.Position = UDim2.new(0, 0, 0, 86)
	HubScroll.BackgroundTransparency = 1
	HubScroll.BorderSizePixel = 0
	HubScroll.ScrollBarThickness = 3
	HubScroll.ScrollBarImageColor3 = THEME.Accent
	HubScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	HubScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	HubScroll.Parent = ScriptsHubPage
	createPadding(HubScroll, 2, 12, 2, 8)

	-- Side-by-Side Grid Layout (Alle Scripts nebeneinander mit Bild + Loadstring)
	local HubGridLayout = Instance.new("UIGridLayout")
	HubGridLayout.FillDirection = Enum.FillDirection.Horizontal
	HubGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	HubGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	HubGridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	HubGridLayout.CellSize = UDim2.new(0.5, -6, 0, 216)
	HubGridLayout.Parent = HubScroll

	local EmptyHubPlaceholder = Instance.new("Frame")
	EmptyHubPlaceholder.Name = "PlaceholderCard"
	EmptyHubPlaceholder.Size = UDim2.new(1, 0, 0, 64)
	EmptyHubPlaceholder.BackgroundColor3 = THEME.CardBackground
	EmptyHubPlaceholder.BorderSizePixel = 0
	EmptyHubPlaceholder.Visible = false
	EmptyHubPlaceholder.Parent = ScriptsHubPage
	EmptyHubPlaceholder.Position = UDim2.new(0, 0, 0, 86)
	createCorner(EmptyHubPlaceholder, 8)
	createStroke(EmptyHubPlaceholder, THEME.Stroke, 1, 0.2)

	local EmptyHubText = Instance.new("TextLabel")
	EmptyHubText.Size = UDim2.new(1, -28, 1, 0)
	EmptyHubText.Position = UDim2.new(0, 14, 0, 0)
	EmptyHubText.BackgroundTransparency = 1
	EmptyHubText.Font = Enum.Font.GothamMedium
	EmptyHubText.Text = "No matching scripts found."
	EmptyHubText.TextColor3 = THEME.TextSecondary
	EmptyHubText.TextSize = 13
	EmptyHubText.TextXAlignment = Enum.TextXAlignment.Left
	EmptyHubText.Parent = EmptyHubPlaceholder

	local hubSearchEntries: { { Card: Frame, Query: string } } = {}
	local searchUpdateQueued = false
	HubSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		if searchUpdateQueued then return end
		searchUpdateQueued = true
		task.defer(function()
			searchUpdateQueued = false
			if not HubSearchBox or not HubSearchBox.Parent then return end
			local q = string.lower(string.gsub(HubSearchBox.Text, "^%s*(.-)%s*$", "%1"))
			local visibleCount = 0
			for _, item in ipairs(hubSearchEntries) do
				local match = (q == "") or (string.find(item.Query, q, 1, true) ~= nil)
				item.Card.Visible = match
				if match then
					visibleCount += 1
				end
			end
			EmptyHubPlaceholder.Visible = (#hubSearchEntries > 0 and visibleCount == 0)
		end)
	end)

	AllScriptsBtn.MouseButton1Click:Connect(function()
		HomePage.Visible = false
		ScriptsHubPage.Visible = true
		ScriptsHubPage.Position = UDim2.new(0, 0, 0, 8)
		tween(ScriptsHubPage, TWEEN_MEDIUM, { Position = UDim2.new(0, 0, 0, 0) })
		updateActiveIndicator(true)
	end)

	BackToHomeBtn.MouseButton1Click:Connect(function()
		ScriptsHubPage.Visible = false
		HomePage.Visible = true
		HomePage.Position = UDim2.new(0, 0, 0, 8)
		tween(HomePage, TWEEN_MEDIUM, { Position = UDim2.new(0, 0, 0, 0) })
		updateActiveIndicator(true)
	end)

	-- Central Player Profile (72x72px Avatar, 10px UICorner, #2A2A2A UIStroke + 22px DisplayName & 14px @Name)
	local ProfileSection = Instance.new("Frame")
	ProfileSection.Name = "ProfileSection"
	ProfileSection.Size = UDim2.new(1, 0, 0, 72)
	ProfileSection.Position = UDim2.new(0, 0, 0, 48)
	ProfileSection.BackgroundTransparency = 1
	ProfileSection.Parent = HomePage

	local LargeAvatar = Instance.new("ImageLabel")
	LargeAvatar.Name = "LargeAvatar"
	LargeAvatar.Size = UDim2.new(0, 72, 0, 72)
	LargeAvatar.Position = UDim2.new(0, 0, 0, 0)
	LargeAvatar.BackgroundColor3 = THEME.DiscordBoxBg
	LargeAvatar.BorderSizePixel = 0
	LargeAvatar.Parent = ProfileSection
	createCorner(LargeAvatar, 10)
	createStroke(LargeAvatar, THEME.StrokeActive, 1, 0)

	local ProfileTextContainer = Instance.new("Frame")
	ProfileTextContainer.Size = UDim2.new(1, -88, 0, 48)
	ProfileTextContainer.Position = UDim2.new(0, 88, 0.5, 0)
	ProfileTextContainer.AnchorPoint = Vector2.new(0, 0.5)
	ProfileTextContainer.BackgroundTransparency = 1
	ProfileTextContainer.Parent = ProfileSection

	local LargeDisplayName = Instance.new("TextLabel")
	LargeDisplayName.Size = UDim2.new(1, 0, 0, 24)
	LargeDisplayName.Position = UDim2.new(0, 0, 0, 0)
	LargeDisplayName.BackgroundTransparency = 1
	LargeDisplayName.Font = Enum.Font.GothamBold
	LargeDisplayName.Text = LocalPlayer.DisplayName
	LargeDisplayName.TextColor3 = THEME.TextPrimary
	LargeDisplayName.TextSize = 22
	LargeDisplayName.TextXAlignment = Enum.TextXAlignment.Left
	LargeDisplayName.TextTruncate = Enum.TextTruncate.AtEnd
	LargeDisplayName.Parent = ProfileTextContainer

	local LargeUsername = Instance.new("TextLabel")
	LargeUsername.Size = UDim2.new(1, 0, 0, 16)
	LargeUsername.Position = UDim2.new(0, 0, 0, 26)
	LargeUsername.BackgroundTransparency = 1
	LargeUsername.Font = Enum.Font.GothamMedium
	LargeUsername.Text = "@" .. LocalPlayer.Name
	LargeUsername.TextColor3 = THEME.TextTabInactive
	LargeUsername.TextSize = 14
	LargeUsername.TextXAlignment = Enum.TextXAlignment.Left
	LargeUsername.TextTruncate = Enum.TextTruncate.AtEnd
	LargeUsername.Parent = ProfileTextContainer

	-- Info Text Below Profile
	local InfoTextLabel = Instance.new("TextLabel")
	InfoTextLabel.Name = "InfoText"
	InfoTextLabel.Size = UDim2.new(1, 0, 0, 34)
	InfoTextLabel.Position = UDim2.new(0, 0, 0, 128)
	InfoTextLabel.BackgroundTransparency = 1
	InfoTextLabel.Font = Enum.Font.GothamMedium
	InfoTextLabel.Text = introText
	InfoTextLabel.TextColor3 = THEME.TextInfo
	InfoTextLabel.TextSize = 13
	InfoTextLabel.TextWrapped = true
	InfoTextLabel.TextXAlignment = Enum.TextXAlignment.Left
	InfoTextLabel.TextYAlignment = Enum.TextYAlignment.Top
	InfoTextLabel.LineHeight = 1.25
	InfoTextLabel.Parent = HomePage

	-- Bottom Game Statistics (Platform, Executor, Place ID, Roblox Version & Your Team separated by 1px #262626 lines)
	local StatsContainer = Instance.new("Frame")
	StatsContainer.Name = "StatsContainer"
	StatsContainer.Size = UDim2.new(1, 0, 0, 166)
	StatsContainer.Position = UDim2.new(0, 0, 1, 0)
	StatsContainer.AnchorPoint = Vector2.new(0, 1)
	StatsContainer.BackgroundTransparency = 1
	StatsContainer.Parent = HomePage

	local TopStatsDivider = Instance.new("Frame")
	TopStatsDivider.Size = UDim2.new(1, 0, 0, 1)
	TopStatsDivider.Position = UDim2.new(0, 0, 0, 0)
	TopStatsDivider.BackgroundColor3 = THEME.Stroke
	TopStatsDivider.BackgroundTransparency = 0.2
	TopStatsDivider.BorderSizePixel = 0
	TopStatsDivider.Parent = StatsContainer

	-- Row 1: Plattform (Gerät / Platform) - Directly ABOVE Executor!
	local PlatformRow = Instance.new("Frame")
	PlatformRow.Name = "PlatformRow"
	PlatformRow.Size = UDim2.new(1, 0, 0, 32)
	PlatformRow.Position = UDim2.new(0, 0, 0, 1)
	PlatformRow.BackgroundTransparency = 1
	PlatformRow.Parent = StatsContainer

	local PlatformLabel = Instance.new("TextLabel")
	PlatformLabel.Size = UDim2.new(0.35, 0, 1, 0)
	PlatformLabel.BackgroundTransparency = 1
	PlatformLabel.Font = Enum.Font.GothamMedium
	PlatformLabel.Text = "Plattform"
	PlatformLabel.TextColor3 = THEME.TextSecondary
	PlatformLabel.TextSize = 13
	PlatformLabel.TextXAlignment = Enum.TextXAlignment.Left
	PlatformLabel.Parent = PlatformRow

	local PlatformValue = Instance.new("TextLabel")
	PlatformValue.Name = "PlatformValue"
	PlatformValue.Size = UDim2.new(0.65, 0, 1, 0)
	PlatformValue.Position = UDim2.new(0.35, 0, 0, 0)
	PlatformValue.BackgroundTransparency = 1
	PlatformValue.Font = Enum.Font.GothamMedium
	PlatformValue.Text = selectedPlatform
	PlatformValue.TextColor3 = THEME.TextStatValue
	PlatformValue.TextSize = 13
	PlatformValue.TextXAlignment = Enum.TextXAlignment.Right
	PlatformValue.TextTruncate = Enum.TextTruncate.AtEnd
	PlatformValue.Parent = PlatformRow
	PlatformValueLabel = PlatformValue

	-- Allow switching platform by tapping on the platform row
	PlatformRow.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local nextPlat = if selectedPlatform == "Handy" then "PC" else "Handy"
			applyPlatform(nextPlat)
			NightSystem:Notify({
				Title = "Plattform gewechselt",
				Content = "Modus umgeschaltet auf: " .. (if nextPlat == "Handy" then "Handy (Mobile)" else "PC (Desktop)"),
				Duration = 2.5,
			})
		end
	end)

	local Divider1 = Instance.new("Frame")
	Divider1.Size = UDim2.new(1, 0, 0, 1)
	Divider1.Position = UDim2.new(0, 0, 0, 33)
	Divider1.BackgroundColor3 = THEME.Stroke
	Divider1.BackgroundTransparency = 0.2
	Divider1.BorderSizePixel = 0
	Divider1.Parent = StatsContainer

	-- Row 2: Executor
	local ExecutorRow = Instance.new("Frame")
	ExecutorRow.Size = UDim2.new(1, 0, 0, 32)
	ExecutorRow.Position = UDim2.new(0, 0, 0, 34)
	ExecutorRow.BackgroundTransparency = 1
	ExecutorRow.Parent = StatsContainer

	local ExecutorLabel = Instance.new("TextLabel")
	ExecutorLabel.Size = UDim2.new(0.35, 0, 1, 0)
	ExecutorLabel.BackgroundTransparency = 1
	ExecutorLabel.Font = Enum.Font.GothamMedium
	ExecutorLabel.Text = "Executor"
	ExecutorLabel.TextColor3 = THEME.TextSecondary
	ExecutorLabel.TextSize = 13
	ExecutorLabel.TextXAlignment = Enum.TextXAlignment.Left
	ExecutorLabel.Parent = ExecutorRow

	local function detectExecutorName(): string
		local env = getfenv() :: any
		local identifyFn = env.identifyexecutor or env.getexecutorname
		if type(identifyFn) == "function" then
			local ok, name, ver = pcall(identifyFn)
			if ok and name and tostring(name) ~= "" then
				if ver and tostring(ver) ~= "" then
					return tostring(name) .. " " .. tostring(ver)
				end
				return tostring(name)
			end
		end
		if RunService:IsStudio() then
			return "Roblox Studio"
		end
		return "Unknown Executor"
	end

	local ExecutorValue = Instance.new("TextLabel")
	ExecutorValue.Size = UDim2.new(0.65, 0, 1, 0)
	ExecutorValue.Position = UDim2.new(0.35, 0, 0, 0)
	ExecutorValue.BackgroundTransparency = 1
	ExecutorValue.Font = Enum.Font.GothamMedium
	ExecutorValue.Text = detectExecutorName()
	ExecutorValue.TextColor3 = THEME.TextStatValue
	ExecutorValue.TextSize = 13
	ExecutorValue.TextXAlignment = Enum.TextXAlignment.Right
	ExecutorValue.TextTruncate = Enum.TextTruncate.AtEnd
	ExecutorValue.Parent = ExecutorRow

	local Divider2 = Instance.new("Frame")
	Divider2.Size = UDim2.new(1, 0, 0, 1)
	Divider2.Position = UDim2.new(0, 0, 0, 66)
	Divider2.BackgroundColor3 = THEME.Stroke
	Divider2.BackgroundTransparency = 0.2
	Divider2.BorderSizePixel = 0
	Divider2.Parent = StatsContainer

	-- Row 3: Place ID
	local PlaceIdRow = Instance.new("Frame")
	PlaceIdRow.Size = UDim2.new(1, 0, 0, 32)
	PlaceIdRow.Position = UDim2.new(0, 0, 0, 67)
	PlaceIdRow.BackgroundTransparency = 1
	PlaceIdRow.Parent = StatsContainer

	local PlaceIdLabel = Instance.new("TextLabel")
	PlaceIdLabel.Size = UDim2.new(0.35, 0, 1, 0)
	PlaceIdLabel.BackgroundTransparency = 1
	PlaceIdLabel.Font = Enum.Font.GothamMedium
	PlaceIdLabel.Text = "Place ID"
	PlaceIdLabel.TextColor3 = THEME.TextSecondary
	PlaceIdLabel.TextSize = 13
	PlaceIdLabel.TextXAlignment = Enum.TextXAlignment.Left
	PlaceIdLabel.Parent = PlaceIdRow

	local PlaceIdValue = Instance.new("TextLabel")
	PlaceIdValue.Size = UDim2.new(0.65, 0, 1, 0)
	PlaceIdValue.Position = UDim2.new(0.35, 0, 0, 0)
	PlaceIdValue.BackgroundTransparency = 1
	PlaceIdValue.Font = Enum.Font.GothamMedium
	PlaceIdValue.Text = "7711635737 - Notruf Hamburg"
	PlaceIdValue.TextColor3 = THEME.TextStatValue
	PlaceIdValue.TextSize = 13
	PlaceIdValue.TextXAlignment = Enum.TextXAlignment.Right
	PlaceIdValue.TextTruncate = Enum.TextTruncate.AtEnd
	PlaceIdValue.Parent = PlaceIdRow

	local Divider3 = Instance.new("Frame")
	Divider3.Size = UDim2.new(1, 0, 0, 1)
	Divider3.Position = UDim2.new(0, 0, 0, 99)
	Divider3.BackgroundColor3 = THEME.Stroke
	Divider3.BackgroundTransparency = 0.2
	Divider3.BorderSizePixel = 0
	Divider3.Parent = StatsContainer

	-- Row 4: Roblox Version (directly below Place ID, always latest)
	local VersionRow = Instance.new("Frame")
	VersionRow.Size = UDim2.new(1, 0, 0, 32)
	VersionRow.Position = UDim2.new(0, 0, 0, 100)
	VersionRow.BackgroundTransparency = 1
	VersionRow.Parent = StatsContainer

	local VersionLabel = Instance.new("TextLabel")
	VersionLabel.Size = UDim2.new(0.35, 0, 1, 0)
	VersionLabel.BackgroundTransparency = 1
	VersionLabel.Font = Enum.Font.GothamMedium
	VersionLabel.Text = "Roblox Version"
	VersionLabel.TextColor3 = THEME.TextSecondary
	VersionLabel.TextSize = 13
	VersionLabel.TextXAlignment = Enum.TextXAlignment.Left
	VersionLabel.Parent = VersionRow

	local localClientVersion = "Latest"
	pcall(function()
		if type(version) == "function" then
			localClientVersion = tostring(version())
		elseif type(Version) == "function" then
			localClientVersion = tostring(Version())
		end
	end)

	local VersionValue = Instance.new("TextLabel")
	VersionValue.Size = UDim2.new(0.65, 0, 1, 0)
	VersionValue.Position = UDim2.new(0.35, 0, 0, 0)
	VersionValue.BackgroundTransparency = 1
	VersionValue.Font = Enum.Font.GothamMedium
	VersionValue.Text = localClientVersion
	VersionValue.TextColor3 = THEME.TextStatValue
	VersionValue.TextSize = 13
	VersionValue.TextXAlignment = Enum.TextXAlignment.Right
	VersionValue.TextTruncate = Enum.TextTruncate.AtEnd
	VersionValue.Parent = VersionRow

	-- Fetch latest live Roblox version + release date/time ("seit wann die neu ist")
	task.spawn(function()
		local function formatRelativeTime(unixTs: number): string
			local diff = math.max(0, os.time() - unixTs)
			local dateStr = os.date("%d.%m.%Y", unixTs)
			if diff < 3600 then
				local mins = math.max(1, math.floor(diff / 60))
				return string.format("seit %s (vor %d Min.)", dateStr, mins)
			elseif diff < 86400 then
				local hours = math.floor(diff / 3600)
				return string.format("seit %s (vor %d Std.)", dateStr, hours)
			else
				local days = math.floor(diff / 86400)
				return string.format("seit %s (vor %d Tag%s)", dateStr, days, if days == 1 then "" else "en")
			end
		end

		local fenv = getfenv() :: any
		local genv = (type(fenv.getgenv) == "function" and fenv.getgenv()) or _G or fenv
		local reqFn = genv.request
			or genv.http_request
			or (type(genv.syn) == "table" and genv.syn.request)
			or (type(genv.http) == "table" and genv.http.request)
			or fenv.request
			or fenv.http_request

		-- 1. Try WEAO live version endpoint (includes exact Unix timestamp of latest Roblox release)
		local fetchedWithDate = false
		if type(reqFn) == "function" then
			local ok, resp = pcall(function()
				return reqFn({
					Url = "https://weao.xyz/api/versions/current",
					Method = "GET",
					Headers = { ["User-Agent"] = "WEAO-3PService" },
				})
			end)
			if ok and type(resp) == "table" and type(resp.Body) == "string" then
				local decOk, data = pcall(function()
					return HttpService:JSONDecode(resp.Body)
				end)
				if decOk and type(data) == "table" and type(data.WindowsResponse) == "table" then
					local verStr = tostring(data.WindowsResponse.version or localClientVersion)
					local ts = tonumber(data.WindowsResponse.timestamp)
					if ts and ts > 0 then
						VersionValue.Text = string.format("%s • %s", verStr, formatRelativeTime(ts))
						fetchedWithDate = true
					elseif data.WindowsDate then
						VersionValue.Text = string.format("%s • seit %s", verStr, tostring(data.WindowsDate))
						fetchedWithDate = true
					end
				end
			end
		end

		if fetchedWithDate then
			return
		end

		-- 2. Fallback: Roblox ClientSettings CDN + Official DeployHistory.txt
		local latestVer = localClientVersion
		pcall(function()
			local rawJson = (game :: any):HttpGet("https://clientsettingscdn.roblox.com/v2/client-version/WindowsPlayer")
			local data = HttpService:JSONDecode(rawJson)
			if type(data) == "table" and data.version then
				latestVer = tostring(data.version)
			end
		end)

		local dateSuffix = ""
		pcall(function()
			local historyTxt = (game :: any):HttpGet("https://setup.rbxcdn.com/DeployHistory.txt")
			if type(historyTxt) == "string" and #historyTxt > 0 then
				local tail = string.sub(historyTxt, math.max(1, #historyTxt - 4000))
				local lastMonth, lastDay, lastYear, lastTime = nil, nil, nil, nil
				for m, d, y, t in string.gmatch(tail, "New WindowsPlayer [^\r\n]- at (%d+)/(%d+)/(%d+) ([%d:]+ [AP]M)") do
					lastMonth, lastDay, lastYear, lastTime = m, d, y, t
				end
				if lastMonth and lastDay and lastYear then
					dateSuffix = string.format(" • seit %02d.%02d.%s (%s)", tonumber(lastDay) or 1, tonumber(lastMonth) or 1, lastYear, tostring(lastTime or ""))
				end
			end
		end)

		VersionValue.Text = latestVer .. dateSuffix
	end)

	local Divider4 = Instance.new("Frame")
	Divider4.Size = UDim2.new(1, 0, 0, 1)
	Divider4.Position = UDim2.new(0, 0, 0, 132)
	Divider4.BackgroundColor3 = THEME.Stroke
	Divider4.BackgroundTransparency = 0.2
	Divider4.BorderSizePixel = 0
	Divider4.Parent = StatsContainer

	-- Row 5: Your Team
	local TeamRow = Instance.new("Frame")
	TeamRow.Size = UDim2.new(1, 0, 0, 32)
	TeamRow.Position = UDim2.new(0, 0, 0, 133)
	TeamRow.BackgroundTransparency = 1
	TeamRow.Parent = StatsContainer

	local TeamLabel = Instance.new("TextLabel")
	TeamLabel.Size = UDim2.new(0.35, 0, 1, 0)
	TeamLabel.BackgroundTransparency = 1
	TeamLabel.Font = Enum.Font.GothamMedium
	TeamLabel.Text = "Your Team"
	TeamLabel.TextColor3 = THEME.TextSecondary
	TeamLabel.TextSize = 13
	TeamLabel.TextXAlignment = Enum.TextXAlignment.Left
	TeamLabel.Parent = TeamRow

	local TeamValue = Instance.new("TextLabel")
	TeamValue.Size = UDim2.new(0.65, 0, 1, 0)
	TeamValue.Position = UDim2.new(0.35, 0, 0, 0)
	TeamValue.BackgroundTransparency = 1
	TeamValue.Font = Enum.Font.GothamMedium
	TeamValue.Text = if LocalPlayer.Team then LocalPlayer.Team.Name else "Citizen"
	TeamValue.TextColor3 = THEME.TextStatValue
	TeamValue.TextSize = 13
	TeamValue.TextXAlignment = Enum.TextXAlignment.Right
	TeamValue.Parent = TeamRow

	-- Load Avatars & Game Metadata asynchronously
	task.spawn(function()
		local uid = if LocalPlayer.UserId > 0 then LocalPlayer.UserId else 1
		local ok, thumb = pcall(function()
			return Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end)
		if ok and thumb then
			FooterAvatar.Image = thumb
			LargeAvatar.Image = thumb
		end
	end)

	task.spawn(function()
		if typeof(game.PlaceId) == "number" and game.PlaceId > 0 then
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(game.PlaceId)
			end)
			if ok and type(info) == "table" and info.Name then
				PlaceIdValue.Text = string.format("%d - %s", game.PlaceId, tostring(info.Name))
				return
			end
		end
		PlaceIdValue.Text = "7711635737 - Notruf Hamburg"
	end)

	local function refreshTeam()
		local t = LocalPlayer.Team
		TeamValue.Text = if t and t.Name ~= "" then t.Name else "Citizen"
	end
	refreshTeam()
	trackConnection(LocalPlayer:GetPropertyChangedSignal("Team"):Connect(refreshTeam))

	-- ========================================================================

	-- ========================================================================
	-- SCRIPT TABS ENGINE (CreateTab, CreateTabs, MakeTab, NewTab, AddTab)
	-- ========================================================================
	local TabsCategoryFrame = createSidebarCategory("TABS")
	TabsCategoryFrame.Visible = false

	local Window = {}
	Window.__index = Window
	Window._ScreenGui = ScreenGui
	Window._BadgeGui = BadgeGui
	Window._AutoSort = autoSort
	Window.Flags = NightSystem.Flags

	function Window:SetPlatform(platformName: string)
		applyPlatform(platformName)
	end

	function Window:GetPlatform(): string
		return selectedPlatform
	end

	function Window:PromptPlatformSelection(callback: ((string) -> ())?)
		showPlatformSelectionModal(function(chosenPlatform)
			applyPlatform(chosenPlatform)
			if callback then
				callback(chosenPlatform)
			end
		end)
	end

	function Window:Toggle()
		toggleWindowState()
	end

	function Window:Minimize()
		minimizeWindow()
	end

	function Window:Open()
		openWindow()
	end

	function Window:Close()
		closeWindow()
	end

	function Window:_ApplyConfig(newCfg: { [string]: any })
		if newCfg.Platform then
			applyPlatform(tostring(newCfg.Platform))
		end
		if newCfg.Title or newCfg.Name then
			windowTitle = tostring(newCfg.Title or newCfg.Name)
			BrandTitle.Text = windowTitle
			BadgeLabel.Text = windowTitle
		end
		if newCfg.Subtitle then
			windowSubtitle = tostring(newCfg.Subtitle)
			BrandSub.Text = windowSubtitle
		end
		if newCfg.IntroText then
			introText = tostring(newCfg.IntroText)
			InfoTextLabel.Text = introText
		end
		if newCfg.LogoId then
			logoId = tostring(newCfg.LogoId)
			LogoIcon.Image = logoId
			LogoIcon.ImageTransparency = 0
			LogoLetter.Text = ""
		end
		if newCfg.MainTabName then
			mainTabName = tostring(newCfg.MainTabName)
		end
		if newCfg.AutoSort ~= nil then
			Window._AutoSort = newCfg.AutoSort
		end
		if newCfg.ToggleKey then
			toggleKey = newCfg.ToggleKey
		end
	end

	local createdTabs: { [string]: any } = {}
	local tabList: { any } = {}

	-- ========================================================================
	-- PARAMETER NORMALIZERS (Rayfield / Orion / Kavo / Fluent Multi-API Support)
	-- ========================================================================
	local function normToggle(opt1: any, opt2: any, opt3: any, opt4: any): { [string]: any }
		if type(opt1) == "string" and type(opt2) == "table" then
			local t = {}
			for k, v in pairs(opt2) do t[k] = v end
			t.Name = t.Name or t.Title or t.Text or opt1
			opt1 = t
		end
		if type(opt1) == "table" then
			local def = if opt1.Default ~= nil then opt1.Default else (if opt1.CurrentValue ~= nil then opt1.CurrentValue else (if opt1.Value ~= nil then opt1.Value else false))
			local cb = opt1.Callback or opt1.Function or opt1.OnClick or opt1.Changed
			return {
				Name = opt1.Name or opt1.Title or opt1.Text or "Toggle",
				Description = opt1.Description or opt1.Desc or opt1.Info,
				Default = def == true,
				Flag = opt1.Flag or opt1.Pointer,
				Callback = cb,
				LayoutOrder = opt1.LayoutOrder,
			}
		else
			local name = tostring(opt1 or "Toggle")
			local desc, def, cb = nil, false, nil
			if type(opt2) == "function" then
				cb = opt2
			elseif type(opt2) == "boolean" then
				def = opt2
				cb = if type(opt3) == "function" then opt3 else nil
			elseif type(opt2) == "string" then
				desc = opt2
				if type(opt3) == "function" then
					cb = opt3
				elseif type(opt3) == "boolean" then
					def = opt3
					cb = if type(opt4) == "function" then opt4 else nil
				end
			end
			return { Name = name, Description = desc, Default = def == true, Callback = cb }
		end
	end

	local function normButton(opt1: any, opt2: any, opt3: any): { [string]: any }
		if type(opt1) == "string" and type(opt2) == "table" then
			local t = {}
			for k, v in pairs(opt2) do t[k] = v end
			t.Name = t.Name or t.Title or t.Text or opt1
			opt1 = t
		end
		if type(opt1) == "table" then
			local cb = opt1.Callback or opt1.Function or opt1.OnClick
			return {
				Name = opt1.Name or opt1.Title or opt1.Text or "Button",
				Description = opt1.Description or opt1.Desc or opt1.Info,
				Callback = cb,
				LayoutOrder = opt1.LayoutOrder,
			}
		else
			local name = tostring(opt1 or "Button")
			local desc, cb = nil, nil
			if type(opt2) == "function" then
				cb = opt2
			elseif type(opt2) == "string" then
				desc = opt2
				cb = if type(opt3) == "function" then opt3 else nil
			end
			return { Name = name, Description = desc, Callback = cb }
		end
	end

	local function normSlider(opt1: any, opt2: any, opt3: any, opt4: any, opt5: any): { [string]: any }
		if type(opt1) == "string" and type(opt2) == "table" then
			local t = {}
			for k, v in pairs(opt2) do t[k] = v end
			t.Name = t.Name or t.Title or t.Text or opt1
			opt1 = t
		end
		if type(opt1) == "table" then
			local min = opt1.Min or opt1.Minimum or (opt1.Range and opt1.Range[1]) or 0
			local max = opt1.Max or opt1.Maximum or (opt1.Range and opt1.Range[2]) or 100
			local def = opt1.Default or opt1.CurrentValue or opt1.Starting or min
			local cb = opt1.Callback or opt1.Function or opt1.Changed
			return {
				Name = opt1.Name or opt1.Title or opt1.Text or "Slider",
				Description = opt1.Description or opt1.Desc or opt1.Info,
				Min = tonumber(min) or 0,
				Max = tonumber(max) or 100,
				Default = tonumber(def) or 0,
				Increment = tonumber(opt1.Increment or opt1.Step or opt1.Decimals or opt1.Rounding) or 1,
				Suffix = tostring(opt1.Suffix or opt1.ValueName or ""),
				Flag = opt1.Flag or opt1.Pointer,
				Callback = cb,
				LayoutOrder = opt1.LayoutOrder,
			}
		else
			local name = tostring(opt1 or "Slider")
			local desc = if type(opt2) == "string" then opt2 else nil
			local numA = if type(opt2) == "number" then opt2 else (if type(opt3) == "number" then opt3 else nil)
			local numB = if type(opt3) == "number" and type(opt2) == "number" then opt3 else (if type(opt4) == "number" then opt4 else nil)
			local numC = if type(opt4) == "number" and type(opt3) == "number" and type(opt2) == "number" then opt4 else (if type(opt5) == "number" then opt5 else nil)
			local cb = nil
			for _, arg in ipairs({ opt2, opt3, opt4, opt5 }) do
				if type(arg) == "function" then cb = arg break end
			end
			local minVal = 0
			local maxVal = 100
			local defVal = 50
			if numA and numB then
				if numA > numB then
					maxVal = numA
					minVal = numB
				else
					minVal = numA
					maxVal = numB
				end
				defVal = numC or minVal
			elseif numA then
				maxVal = numA
				defVal = minVal
			end
			return {
				Name = name,
				Description = desc,
				Min = minVal,
				Max = maxVal,
				Default = defVal,
				Callback = cb,
			}
		end
	end

	local function normDropdown(opt1: any, opt2: any, opt3: any, opt4: any): { [string]: any }
		if type(opt1) == "string" and type(opt2) == "table" then
			if opt2.Title ~= nil or opt2.Values ~= nil or opt2.Options ~= nil or opt2.Callback ~= nil or opt2.Default ~= nil then
				local t = {}
				for k, v in pairs(opt2) do t[k] = v end
				t.Name = t.Name or t.Title or opt1
				opt1 = t
			else
				local cb = if type(opt3) == "function" then opt3 else (if type(opt4) == "function" then opt4 else nil)
				return {
					Name = opt1,
					Options = opt2,
					Callback = cb,
				}
			end
		end
		if type(opt1) == "table" then
			local rawOpts = opt1.Options or opt1.Values or opt1.List or opt1.Items or {}
			if type(rawOpts) == "function" then
				local ok, res = pcall(rawOpts)
				if ok and type(res) == "table" then rawOpts = res else rawOpts = {} end
			end
			local def = opt1.Default or opt1.CurrentOption or opt1.CurrentValue or opt1.Selected or opt1.Value
			local cb = opt1.Callback or opt1.Function or opt1.Changed
			return {
				Name = opt1.Name or opt1.Title or opt1.Text or "Dropdown",
				Description = opt1.Description or opt1.Desc or opt1.Info,
				Options = rawOpts,
				Default = def,
				Multi = opt1.Multi or opt1.MultiSelect or opt1.Multiple == true,
				Search = opt1.Search or opt1.SearchBar == true or opt1.Searchable == true,
				Flag = opt1.Flag or opt1.Pointer,
				Callback = cb,
				LayoutOrder = opt1.LayoutOrder,
			}
		else
			local name = tostring(opt1 or "Dropdown")
			local desc = if type(opt2) == "string" then opt2 else nil
			local opts = if type(opt2) == "table" then opt2 else (if type(opt3) == "table" then opt3 else {})
			local cb = nil
			for _, arg in ipairs({ opt2, opt3, opt4 }) do
				if type(arg) == "function" then cb = arg break end
			end
			return {
				Name = name,
				Description = desc,
				Options = opts,
				Callback = cb,
			}
		end
	end

	local function normInput(opt1: any, opt2: any, opt3: any, opt4: any): { [string]: any }
		if type(opt1) == "string" and type(opt2) == "table" then
			local t = {}
			for k, v in pairs(opt2) do t[k] = v end
			t.Name = t.Name or t.Title or opt1
			opt1 = t
		end
		if type(opt1) == "table" then
			local cb = opt1.Callback or opt1.Function or opt1.Changed
			return {
				Name = opt1.Name or opt1.Title or opt1.Text or "Input",
				Description = opt1.Description or opt1.Desc or opt1.Info,
				Placeholder = opt1.Placeholder or opt1.PlaceholderText or "Enter text...",
				Default = tostring(opt1.Default or opt1.CurrentValue or opt1.Text or opt1.Value or ""),
				ClearTextOnFocus = opt1.ClearTextOnFocus or opt1.TextDisappear == true or opt1.RemoveTextAfterFocusLost == true,
				Flag = opt1.Flag or opt1.Pointer,
				Callback = cb,
				LayoutOrder = opt1.LayoutOrder,
			}
		else
			local name = tostring(opt1 or "Input")
			local desc = if type(opt2) == "string" then opt2 else nil
			local cb = nil
			for _, arg in ipairs({ opt2, opt3, opt4 }) do
				if type(arg) == "function" then cb = arg break end
			end
			return {
				Name = name,
				Description = desc,
				Placeholder = "Enter text...",
				Default = "",
				Callback = cb,
			}
		end
	end

	local function normKeybind(opt1: any, opt2: any, opt3: any, opt4: any): { [string]: any }
		if type(opt1) == "string" and type(opt2) == "table" then
			local t = {}
			for k, v in pairs(opt2) do t[k] = v end
			t.Name = t.Name or t.Title or opt1
			opt1 = t
		end
		if type(opt1) == "table" then
			local def = opt1.Default or opt1.CurrentKeybind or opt1.Key or Enum.KeyCode.E
			if type(def) == "string" and Enum.KeyCode[def] then
				def = Enum.KeyCode[def]
			end
			local cb = opt1.Callback or opt1.Function or opt1.Changed
			return {
				Name = opt1.Name or opt1.Title or opt1.Text or "Keybind",
				Description = opt1.Description or opt1.Desc or opt1.Info,
				Default = def,
				Mode = opt1.Mode or "Toggle",
				Flag = opt1.Flag or opt1.Pointer,
				Callback = cb,
				LayoutOrder = opt1.LayoutOrder,
			}
		else
			local name = tostring(opt1 or "Keybind")
			local desc = if type(opt2) == "string" then opt2 else nil
			local def = Enum.KeyCode.E
			local cb = nil
			for _, arg in ipairs({ opt2, opt3, opt4 }) do
				if typeof(arg) == "EnumItem" then
					def = arg
				elseif type(arg) == "string" and Enum.KeyCode[arg] then
					def = Enum.KeyCode[arg]
				elseif type(arg) == "function" then
					cb = arg
				end
			end
			return {
				Name = name,
				Description = desc,
				Default = def,
				Callback = cb,
			}
		end
	end

	local function normColorPicker(opt1: any, opt2: any, opt3: any, opt4: any): { [string]: any }
		if type(opt1) == "string" and type(opt2) == "table" and not (opt2.R and opt2.G and opt2.B) then
			local t = {}
			for k, v in pairs(opt2) do t[k] = v end
			t.Name = t.Name or t.Title or opt1
			opt1 = t
		end
		if type(opt1) == "table" and not (opt1.R and opt1.G and opt1.B) then
			local def = opt1.Default or opt1.Color or Color3.fromRGB(255, 255, 255)
			local cb = opt1.Callback or opt1.Function or opt1.Changed
			return {
				Name = opt1.Name or opt1.Title or opt1.Text or "ColorPicker",
				Description = opt1.Description or opt1.Desc or opt1.Info,
				Default = def,
				Flag = opt1.Flag or opt1.Pointer,
				Callback = cb,
				LayoutOrder = opt1.LayoutOrder,
			}
		else
			local name = tostring(opt1 or "ColorPicker")
			local desc = if type(opt2) == "string" then opt2 else nil
			local def = Color3.fromRGB(255, 255, 255)
			local cb = nil
			for _, arg in ipairs({ opt2, opt3, opt4 }) do
				if typeof(arg) == "Color3" or (type(arg) == "table" and arg.R and arg.G and arg.B) then
					def = arg
				elseif type(arg) == "function" then
					cb = arg
				end
			end
			return {
				Name = name,
				Description = desc,
				Default = def,
				Callback = cb,
			}
		end
	end

	local function normParagraph(opt1: any, opt2: any): { [string]: any }
		if type(opt1) == "table" then
			return {
				Title = opt1.Title or opt1.Name or "Paragraph",
				Content = opt1.Content or opt1.Text or opt1.Desc or "",
				LayoutOrder = opt1.LayoutOrder,
			}
		else
			return {
				Title = tostring(opt1 or "Paragraph"),
				Content = tostring(opt2 or ""),
			}
		end
	end

	local function normLabel(opt1: any, opt2: any): { [string]: any }
		if type(opt1) == "table" then
			return {
				Text = opt1.Text or opt1.Title or opt1.Name or "",
				LayoutOrder = opt1.LayoutOrder,
			}
		else
			local txt = tostring(opt1 or "")
			if type(opt2) == "string" and opt2 ~= "" then
				txt = txt .. " " .. opt2
			end
			return { Text = txt }
		end
	end

	local function bindTabElementApi(targetTab: any, tabScroll: ScrollingFrame, tabSearchables: { any }, onFirstElement: (() -> ())?)
		targetTab._CreationCount = 0
		targetTab._SectionBlock = 0
		targetTab._AutoSort = autoSort
		targetTab._ScrollContainer = tabScroll

		local function computeLayoutOrder(elementType: string, manualOrder: number?): number
			if onFirstElement then
				onFirstElement()
			end
			if type(manualOrder) == "number" then
				return manualOrder
			end
			targetTab._CreationCount += 1
			if elementType == "Section" then
				targetTab._SectionBlock += 10000
				return targetTab._SectionBlock
			end
			if targetTab._AutoSort then
				local typeWeight = TYPE_PRIORITY[elementType] or 650
				return targetTab._SectionBlock + typeWeight + targetTab._CreationCount
			else
				return targetTab._SectionBlock + targetTab._CreationCount
			end
		end

		local function registerSearchable(frame: GuiObject, title: string)
			table.insert(tabSearchables, { Frame = frame, Title = title })
		end

		local function createBaseCard(
			elementType: string,
			title: string,
			description: string?,
			baseHeight: number,
			manualOrder: number?
		): (Frame, UIStroke, TextLabel)
			local hasDesc = description ~= nil and description ~= ""
			local cardHeight = if hasDesc then math.max(baseHeight, 54) else baseHeight

			local card = Instance.new("Frame")
			card.Name = elementType .. "_" .. title
			card.Size = UDim2.new(1, 0, 0, cardHeight)
			card.BackgroundColor3 = THEME.CardBackground
			card.BorderSizePixel = 0
			card.ClipsDescendants = true
			card.LayoutOrder = computeLayoutOrder(elementType, manualOrder)
			card.Parent = tabScroll
			createCorner(card, 8)
			local stroke = createStroke(card, THEME.Stroke, 1, 0.2)

			local titleLbl = Instance.new("TextLabel")
			titleLbl.Name = "Title"
			titleLbl.Size = UDim2.new(1, -160, 0, 16)
			titleLbl.Position = UDim2.new(0, 14, 0, if hasDesc then 10 else math.floor((cardHeight - 16) / 2))
			titleLbl.BackgroundTransparency = 1
			titleLbl.Font = Enum.Font.GothamBold
			titleLbl.Text = title
			titleLbl.TextColor3 = THEME.TextPrimary
			titleLbl.TextSize = 13
			titleLbl.TextXAlignment = Enum.TextXAlignment.Left
			titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
			titleLbl.Parent = card

			if hasDesc then
				local descLbl = Instance.new("TextLabel")
				descLbl.Name = "Description"
				descLbl.Size = UDim2.new(1, -160, 0, 14)
				descLbl.Position = UDim2.new(0, 14, 0, 28)
				descLbl.BackgroundTransparency = 1
				descLbl.Font = Enum.Font.GothamMedium
				descLbl.Text = tostring(description)
				descLbl.TextColor3 = THEME.TextSecondary
				descLbl.TextSize = 11
				descLbl.TextXAlignment = Enum.TextXAlignment.Left
				descLbl.TextTruncate = Enum.TextTruncate.AtEnd
				descLbl.Parent = card
			end

			card.MouseEnter:Connect(function()
				tween(card, TWEEN_FAST, { BackgroundColor3 = THEME.CardHover })
			end)
			card.MouseLeave:Connect(function()
				tween(card, TWEEN_FAST, { BackgroundColor3 = THEME.CardBackground })
			end)

			registerSearchable(card, title .. " " .. tostring(description or ""))
			return card, stroke, titleLbl
		end

		-- 1. Window:CreateSection(Title)
		function targetTab:CreateSection(sectionConfig: any, ...)
			local title = "Section"
			local manualOrder: number? = nil
			if type(sectionConfig) == "table" then
				title = tostring(sectionConfig.Name or sectionConfig.Title or sectionConfig.Text or "Section")
				manualOrder = sectionConfig.LayoutOrder
			elseif sectionConfig ~= nil then
				title = tostring(sectionConfig)
			end

			local secFrame = Instance.new("Frame")
			secFrame.Name = "Section_" .. title
			secFrame.Size = UDim2.new(1, 0, 0, 26)
			secFrame.BackgroundTransparency = 1
			secFrame.LayoutOrder = computeLayoutOrder("Section", manualOrder)
			secFrame.Parent = tabScroll

			local secLabel = Instance.new("TextLabel")
			secLabel.Name = "SectionTitle"
			secLabel.AutomaticSize = Enum.AutomaticSize.X
			secLabel.Size = UDim2.new(0, 0, 1, 0)
			secLabel.Position = UDim2.new(0, 2, 0, 4)
			secLabel.BackgroundTransparency = 1
			secLabel.Font = Enum.Font.GothamBold
			secLabel.Text = string.upper(title)
			secLabel.TextColor3 = THEME.TextSecondary
			secLabel.TextSize = 11
			secLabel.TextXAlignment = Enum.TextXAlignment.Left
			secLabel.Parent = secFrame

			local line = Instance.new("Frame")
			line.Name = "Line"
			line.Size = UDim2.new(1, -110, 0, 1)
			line.Position = UDim2.new(1, 0, 0.5, 2)
			line.AnchorPoint = Vector2.new(1, 0.5)
			line.BackgroundColor3 = THEME.Stroke
			line.BackgroundTransparency = 0.2
			line.BorderSizePixel = 0
			line.Parent = secFrame

			local function updateLineWidth()
				local textW = secLabel.AbsoluteSize.X
				line.Size = UDim2.new(1, -(textW + 14), 0, 1)
			end
			task.defer(updateLineWidth)
			secLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLineWidth)

			registerSearchable(secFrame, title)

			local SectionObj = {}
			function SectionObj:Set(newTitle: string)
				secLabel.Text = string.upper(tostring(newTitle))
			end
			SectionObj.SetTitle = SectionObj.Set
			SectionObj.Tab = targetTab
			function SectionObj:CreateToggle(...) return targetTab:CreateToggle(...) end
			function SectionObj:CreateButton(...) return targetTab:CreateButton(...) end
			function SectionObj:CreateSlider(...) return targetTab:CreateSlider(...) end
			function SectionObj:CreateDropdown(...) return targetTab:CreateDropdown(...) end
			function SectionObj:CreateInput(...) return targetTab:CreateInput(...) end
			function SectionObj:CreateKeybind(...) return targetTab:CreateKeybind(...) end
			function SectionObj:CreateColorPicker(...) return targetTab:CreateColorPicker(...) end
			function SectionObj:CreateLabel(...) return targetTab:CreateLabel(...) end
			function SectionObj:CreateParagraph(...) return targetTab:CreateParagraph(...) end
			function SectionObj:CreateDivider(...) return targetTab:CreateDivider(...) end
			function SectionObj:CreateSection(...) return targetTab:CreateSection(...) end

			SectionObj.AddToggle = SectionObj.CreateToggle
			SectionObj.NewToggle = SectionObj.CreateToggle
			SectionObj.AddButton = SectionObj.CreateButton
			SectionObj.NewButton = SectionObj.CreateButton
			SectionObj.AddSlider = SectionObj.CreateSlider
			SectionObj.NewSlider = SectionObj.CreateSlider
			SectionObj.AddDropdown = SectionObj.CreateDropdown
			SectionObj.NewDropdown = SectionObj.CreateDropdown
			SectionObj.AddInput = SectionObj.CreateInput
			SectionObj.AddTextbox = SectionObj.CreateInput
			SectionObj.NewTextBox = SectionObj.CreateInput
			SectionObj.CreateTextBox = SectionObj.CreateInput
			SectionObj.AddBind = SectionObj.CreateKeybind
			SectionObj.AddKeybind = SectionObj.CreateKeybind
			SectionObj.NewKeybind = SectionObj.CreateKeybind
			SectionObj.AddColorpicker = SectionObj.CreateColorPicker
			SectionObj.NewColorPicker = SectionObj.CreateColorPicker
			SectionObj.AddLabel = SectionObj.CreateLabel
			SectionObj.NewLabel = SectionObj.CreateLabel
			SectionObj.AddParagraph = SectionObj.CreateParagraph
			SectionObj.NewParagraph = SectionObj.CreateParagraph
			SectionObj.AddDivider = SectionObj.CreateDivider
			SectionObj.NewDivider = SectionObj.CreateDivider
			SectionObj.AddSection = SectionObj.CreateSection
			SectionObj.NewSection = SectionObj.CreateSection
			return SectionObj
		end

		-- 2. Window:CreateToggle(...)
		function targetTab:CreateToggle(opt1: any, opt2: any, opt3: any, opt4: any)
			local opts = normToggle(opt1, opt2, opt3, opt4)
			local name = tostring(opts.Name or "Toggle")
			local desc = opts.Description
			local state = opts.Default == true
			local flag = opts.Flag or name
			local callback = opts.Callback

			local card = createBaseCard("Toggle", name, desc, 44, opts.LayoutOrder)

			local switchBg = Instance.new("Frame")
			switchBg.Size = UDim2.new(0, 40, 0, 20)
			switchBg.Position = UDim2.new(1, -14, 0.5, 0)
			switchBg.AnchorPoint = Vector2.new(1, 0.5)
			switchBg.BackgroundColor3 = if state then THEME.Accent else THEME.Stroke
			switchBg.BorderSizePixel = 0
			switchBg.Parent = card
			createCorner(switchBg, 10)
			local switchStroke = createStroke(switchBg, if state then THEME.Accent else THEME.StrokeActive, 1, 0.15)

			local knob = Instance.new("Frame")
			knob.Size = UDim2.new(0, 14, 0, 14)
			knob.Position = if state then UDim2.new(1, -17, 0.5, 0) else UDim2.new(0, 3, 0.5, 0)
			knob.AnchorPoint = Vector2.new(0, 0.5)
			knob.BackgroundColor3 = if state then THEME.MainBackground else THEME.TextTabInactive
			knob.BorderSizePixel = 0
			knob.Parent = switchBg
			createCorner(knob, 7)

			local clickZone = Instance.new("TextButton")
			clickZone.Size = UDim2.new(1, 0, 1, 0)
			clickZone.BackgroundTransparency = 1
			clickZone.Text = ""
			clickZone.Parent = card

			local ToggleObj = { Value = state }
			NightSystem.Flags[flag] = state

			function ToggleObj:Set(newValue: boolean, silent: boolean?)
				state = newValue == true
				ToggleObj.Value = state
				NightSystem.Flags[flag] = state

				tween(switchBg, TWEEN_FAST, {
					BackgroundColor3 = if state then THEME.Accent else THEME.Stroke,
				})
				tween(switchStroke, TWEEN_FAST, {
					Color = if state then THEME.Accent else THEME.StrokeActive,
					Transparency = if state then 0 else 0.2,
				})
				tween(knob, TWEEN_FAST, {
					Position = if state then UDim2.new(1, -17, 0.5, 0) else UDim2.new(0, 3, 0.5, 0),
					BackgroundColor3 = if state then THEME.MainBackground else THEME.TextTabInactive,
				})

				if not silent then
					safeCallback(callback, state)
				end
			end

			ToggleObj.SetValue = ToggleObj.Set
			ToggleObj.SetState = ToggleObj.Set

			function ToggleObj:Get(): boolean
				return state
			end

			ToggleObj.GetValue = ToggleObj.Get

			function ToggleObj:OnChanged(cb: (boolean) -> ())
				callback = cb
			end

			clickZone.MouseButton1Click:Connect(function()
				ToggleObj:Set(not state)
			end)

			if state then
				task.defer(function()
					safeCallback(callback, state)
				end)
			end

			return ToggleObj
		end

		-- 3. Window:CreateButton(...)
		function targetTab:CreateButton(opt1: any, opt2: any, opt3: any)
			local opts = normButton(opt1, opt2, opt3)
			local name = tostring(opts.Name or "Button")
			local desc = opts.Description
			local callback = opts.Callback

			local card, stroke, titleLbl = createBaseCard("Button", name, desc, 44, opts.LayoutOrder)

			local actionBadge = Instance.new("Frame")
			actionBadge.Size = UDim2.new(0, 26, 0, 26)
			actionBadge.Position = UDim2.new(1, -14, 0.5, 0)
			actionBadge.AnchorPoint = Vector2.new(1, 0.5)
			actionBadge.BackgroundColor3 = THEME.CardInner
			actionBadge.BorderSizePixel = 0
			actionBadge.Parent = card
			createCorner(actionBadge, 6)
			createStroke(actionBadge, THEME.Stroke, 1, 0.2)

			local arrowIcon = Instance.new("ImageLabel")
			arrowIcon.Size = UDim2.new(0, 14, 0, 14)
			arrowIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
			arrowIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			arrowIcon.BackgroundTransparency = 1
			arrowIcon.Image = ASSETS.ChevronRight
			arrowIcon.ImageColor3 = THEME.TextSecondary
			arrowIcon.Parent = actionBadge

			local clickBtn = Instance.new("TextButton")
			clickBtn.Size = UDim2.new(1, 0, 1, 0)
			clickBtn.BackgroundTransparency = 1
			clickBtn.Text = ""
			clickBtn.Parent = card

			clickBtn.MouseEnter:Connect(function()
				tween(arrowIcon, TWEEN_FAST, { ImageColor3 = THEME.Accent })
				tween(actionBadge, TWEEN_FAST, { BackgroundColor3 = THEME.Stroke })
			end)
			clickBtn.MouseLeave:Connect(function()
				tween(arrowIcon, TWEEN_FAST, { ImageColor3 = THEME.TextSecondary })
				tween(actionBadge, TWEEN_FAST, { BackgroundColor3 = THEME.CardInner })
			end)

			local function trigger()
				tween(stroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0.1 })
				tween(actionBadge, TWEEN_FAST, { BackgroundColor3 = THEME.Accent })
				tween(arrowIcon, TWEEN_FAST, { ImageColor3 = THEME.MainBackground })
				task.delay(0.16, function()
					if stroke.Parent then
						tween(stroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.2 })
						tween(actionBadge, TWEEN_FAST, { BackgroundColor3 = THEME.CardInner })
						tween(arrowIcon, TWEEN_FAST, { ImageColor3 = THEME.TextSecondary })
					end
				end)
				safeCallback(callback)
			end

			clickBtn.MouseButton1Click:Connect(trigger)

			local ButtonObj = {}
			function ButtonObj:Set(newName: string)
				titleLbl.Text = tostring(newName)
			end
			ButtonObj.SetText = ButtonObj.Set
			function ButtonObj:Fire()
				trigger()
			end
			ButtonObj.Click = ButtonObj.Fire
			function ButtonObj:OnClick(cb: () -> ())
				callback = cb
			end
			function ButtonObj:Callback(cb: () -> ())
				callback = cb
			end
			return ButtonObj
		end

		-- 4. Window:CreateSlider(...)
		function targetTab:CreateSlider(opt1: any, opt2: any, opt3: any, opt4: any, opt5: any)
			local opts = normSlider(opt1, opt2, opt3, opt4, opt5)
			local name = tostring(opts.Name or "Slider")
			local desc = opts.Description
			local minVal = tonumber(opts.Min) or 0
			local maxVal = tonumber(opts.Max) or 100
			local increment = tonumber(opts.Increment) or 1
			local suffix = tostring(opts.Suffix or "")
			local currentVal = math.clamp(tonumber(opts.Default) or minVal, minVal, maxVal)
			local flag = opts.Flag or name
			local callback = opts.Callback

			local hasDesc = desc ~= nil and desc ~= ""
			local cardHeight = if hasDesc then 72 else 60
			local card = createBaseCard("Slider", name, desc, cardHeight, opts.LayoutOrder)

			local valueInput = Instance.new("TextBox")
			valueInput.Size = UDim2.new(0, 68, 0, 22)
			valueInput.Position = UDim2.new(1, -14, 0, 10)
			valueInput.AnchorPoint = Vector2.new(1, 0)
			valueInput.BackgroundColor3 = THEME.CardInner
			valueInput.BorderSizePixel = 0
			valueInput.Font = Enum.Font.GothamBold
			valueInput.Text = tostring(currentVal) .. suffix
			valueInput.TextColor3 = THEME.TextPrimary
			valueInput.TextSize = 11
			valueInput.ClearTextOnFocus = false
			valueInput.Parent = card
			createCorner(valueInput, 5)
			local valStroke = createStroke(valueInput, THEME.Stroke, 1, 0.2)

			local trackBtn = Instance.new("TextButton")
			trackBtn.Size = UDim2.new(1, -28, 0, 6)
			trackBtn.Position = UDim2.new(0, 14, 1, -14)
			trackBtn.AnchorPoint = Vector2.new(0, 1)
			trackBtn.BackgroundColor3 = THEME.CardInner
			trackBtn.BorderSizePixel = 0
			trackBtn.AutoButtonColor = false
			trackBtn.Text = ""
			trackBtn.Parent = card
			createCorner(trackBtn, 3)
			createStroke(trackBtn, THEME.Stroke, 1, 0.3)

			local initialPct = if maxVal > minVal then (currentVal - minVal) / (maxVal - minVal) else 0

			local fillBar = Instance.new("Frame")
			fillBar.Size = UDim2.new(initialPct, 0, 1, 0)
			fillBar.BackgroundColor3 = THEME.Accent
			fillBar.BorderSizePixel = 0
			fillBar.Parent = trackBtn
			createCorner(fillBar, 3)

			local knob = Instance.new("Frame")
			knob.Size = UDim2.new(0, 12, 0, 12)
			knob.Position = UDim2.new(initialPct, 0, 0.5, 0)
			knob.AnchorPoint = Vector2.new(0.5, 0.5)
			knob.BackgroundColor3 = THEME.Accent
			knob.BorderSizePixel = 0
			knob.Parent = trackBtn
			createCorner(knob, 6)
			createStroke(knob, THEME.MainBackground, 2, 0)

			local SliderObj = { Value = currentVal }
			NightSystem.Flags[flag] = currentVal

			local function roundToIncrement(raw: number): number
				local snapped = minVal + math.round((raw - minVal) / increment) * increment
				local decimals = 0
				local incStr = tostring(increment)
				local dotPos = string.find(incStr, ".", 1, true)
				if dotPos then
					decimals = #incStr - dotPos
				end
				local factor = 10 ^ decimals
				return math.clamp(math.round(snapped * factor) / factor, minVal, maxVal)
			end

			local sliding = false
			local function applyVisual(pct: number, animate: boolean)
				if animate then
					tween(fillBar, TWEEN_FAST, { Size = UDim2.new(pct, 0, 1, 0) })
					tween(knob, TWEEN_FAST, { Position = UDim2.new(pct, 0, 0.5, 0) })
				else
					fillBar.Size = UDim2.new(pct, 0, 1, 0)
					knob.Position = UDim2.new(pct, 0, 0.5, 0)
				end
			end

			function SliderObj:Set(val: number, silent: boolean?)
				local clamped = roundToIncrement(tonumber(val) or minVal)
				local changed = clamped ~= currentVal
				currentVal = clamped
				SliderObj.Value = clamped
				NightSystem.Flags[flag] = clamped

				local pct = if maxVal > minVal then (clamped - minVal) / (maxVal - minVal) else 0
				applyVisual(pct, not sliding)
				valueInput.Text = tostring(clamped) .. suffix

				if not silent and changed then
					safeCallback(callback, clamped)
				end
			end

			SliderObj.SetValue = SliderObj.Set

			function SliderObj:Get(): number
				return currentVal
			end

			SliderObj.GetValue = SliderObj.Get

			function SliderObj:OnChanged(cb: (number) -> ())
				callback = cb
			end

			local moveConn: RBXScriptConnection? = nil
			local endConn: RBXScriptConnection? = nil

			local function stopSliding()
				if not sliding then return end
				sliding = false
				if moveConn then moveConn:Disconnect(); moveConn = nil end
				if endConn then endConn:Disconnect(); endConn = nil end
				tween(knob, TWEEN_FAST, { Size = UDim2.new(0, 12, 0, 12) })
			end

			local function updateFromMouse(inputPos: Vector2)
				local trackX = trackBtn.AbsolutePosition.X
				local trackW = math.max(1, trackBtn.AbsoluteSize.X)
				local rel = math.clamp((inputPos.X - trackX) / trackW, 0, 1)
				SliderObj:Set(minVal + (maxVal - minVal) * rel)
			end

			trackBtn.InputBegan:Connect(function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					sliding = true
					tween(knob, TWEEN_FAST, { Size = UDim2.new(0, 15, 0, 15) })
					updateFromMouse(Vector2.new(input.Position.X, input.Position.Y))

					if moveConn then moveConn:Disconnect() end
					if endConn then endConn:Disconnect() end

					moveConn = UserInputService.InputChanged:Connect(function(moveInput: InputObject)
						if sliding and (moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch) then
							updateFromMouse(Vector2.new(moveInput.Position.X, moveInput.Position.Y))
						end
					end)

					endConn = UserInputService.InputEnded:Connect(function(endInput: InputObject)
						if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
							stopSliding()
						end
					end)
				end
			end)

			valueInput.Focused:Connect(function()
				tween(valStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0 })
				valueInput.Text = tostring(currentVal)
			end)
			valueInput.FocusLost:Connect(function()
				tween(valStroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.2 })
				local num = tonumber(valueInput.Text)
				if num then
					SliderObj:Set(num)
				else
					valueInput.Text = tostring(currentVal) .. suffix
				end
			end)

			return SliderObj
		end

		-- 5. Window:CreateDropdown(...)
		function targetTab:CreateDropdown(opt1: any, opt2: any, opt3: any, opt4: any)
			local opts = normDropdown(opt1, opt2, opt3, opt4)
			local name = tostring(opts.Name or "Dropdown")
			local desc = opts.Description
			local optionList: { string } = opts.Options or {}
			local isMulti = opts.Multi == true
			local isSearchable = if opts.Search ~= nil then opts.Search else true
			local flag = opts.Flag or name
			local callback = opts.Callback

			local hasDesc = desc ~= nil and desc ~= ""
			local closedHeight = if hasDesc then 54 else 44
			local card, cardStroke = createBaseCard("Dropdown", name, desc, closedHeight, opts.LayoutOrder)

			local selectedSingle: string = ""
			local selectedMulti: { [string]: boolean } = {}

			if isMulti then
				if type(opts.Default) == "table" then
					for _, item in ipairs(opts.Default) do
						selectedMulti[tostring(item)] = true
					end
				elseif type(opts.Default) == "string" and opts.Default ~= "" then
					selectedMulti[opts.Default] = true
				end
			else
				if type(opts.Default) == "string" then
					selectedSingle = opts.Default
				elseif type(opts.Default) == "table" and opts.Default[1] ~= nil then
					selectedSingle = tostring(opts.Default[1])
				elseif #optionList > 0 then
					selectedSingle = tostring(optionList[1])
				end
			end

			local function getDisplaySummary(): string
				if isMulti then
					local active = {}
					for _, opt in ipairs(optionList) do
						if selectedMulti[tostring(opt)] then
							table.insert(active, tostring(opt))
						end
					end
					return if #active == 0 then "None" else table.concat(active, ", ")
				else
					return if selectedSingle ~= "" then selectedSingle else "Select..."
				end
			end

			local headerBtn = Instance.new("TextButton")
			headerBtn.Size = UDim2.new(0, 155, 0, 26)
			headerBtn.Position = UDim2.new(1, -14, 0, if hasDesc then 14 else 9)
			headerBtn.AnchorPoint = Vector2.new(1, 0)
			headerBtn.BackgroundColor3 = THEME.CardInner
			headerBtn.BorderSizePixel = 0
			headerBtn.AutoButtonColor = false
			headerBtn.Text = ""
			headerBtn.Parent = card
			createCorner(headerBtn, 6)
			createStroke(headerBtn, THEME.Stroke, 1, 0.2)

			local selectedLabel = Instance.new("TextLabel")
			selectedLabel.Size = UDim2.new(1, -30, 1, 0)
			selectedLabel.Position = UDim2.new(0, 10, 0, 0)
			selectedLabel.BackgroundTransparency = 1
			selectedLabel.Font = Enum.Font.GothamMedium
			selectedLabel.Text = getDisplaySummary()
			selectedLabel.TextColor3 = THEME.TextPrimary
			selectedLabel.TextSize = 12
			selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
			selectedLabel.TextTruncate = Enum.TextTruncate.AtEnd
			selectedLabel.Parent = headerBtn

			local arrow = Instance.new("ImageLabel")
			arrow.Size = UDim2.new(0, 14, 0, 14)
			arrow.Position = UDim2.new(1, -8, 0.5, 0)
			arrow.AnchorPoint = Vector2.new(1, 0.5)
			arrow.BackgroundTransparency = 1
			arrow.Image = ASSETS.ChevronDown
			arrow.ImageColor3 = THEME.TextSecondary
			arrow.Parent = headerBtn

			local drawerFrame = Instance.new("Frame")
			drawerFrame.Size = UDim2.new(1, -28, 0, 160)
			drawerFrame.Position = UDim2.new(0, 14, 0, closedHeight + 4)
			drawerFrame.BackgroundColor3 = THEME.CardInner
			drawerFrame.BorderSizePixel = 0
			drawerFrame.ClipsDescendants = true
			drawerFrame.Parent = card
			createCorner(drawerFrame, 7)
			createStroke(drawerFrame, THEME.Stroke, 1, 0.2)

			local searchOffset = 0
			local searchInput: TextBox? = nil

			if isSearchable then
				searchOffset = 34
				local searchBar = Instance.new("Frame")
				searchBar.Size = UDim2.new(1, -12, 0, 26)
				searchBar.Position = UDim2.new(0, 6, 0, 6)
				searchBar.BackgroundColor3 = THEME.MainBackground
				searchBar.BorderSizePixel = 0
				searchBar.Parent = drawerFrame
				createCorner(searchBar, 5)
				createStroke(searchBar, THEME.Stroke, 1, 0.25)

				local sIcon = Instance.new("ImageLabel")
				sIcon.Size = UDim2.new(0, 12, 0, 12)
				sIcon.Position = UDim2.new(0, 8, 0.5, 0)
				sIcon.AnchorPoint = Vector2.new(0, 0.5)
				sIcon.BackgroundTransparency = 1
				sIcon.Image = ASSETS.Search
				sIcon.ImageColor3 = THEME.TextSecondary
				sIcon.Parent = searchBar

				local sBox = Instance.new("TextBox")
				sBox.Size = UDim2.new(1, -28, 1, 0)
				sBox.Position = UDim2.new(0, 24, 0, 0)
				sBox.BackgroundTransparency = 1
				sBox.Font = Enum.Font.GothamMedium
				sBox.PlaceholderText = "Search options..."
				sBox.PlaceholderColor3 = THEME.TextSecondary
				sBox.Text = ""
				sBox.TextColor3 = THEME.TextPrimary
				sBox.TextSize = 11
				sBox.TextXAlignment = Enum.TextXAlignment.Left
				sBox.ClearTextOnFocus = false
				sBox.Parent = searchBar
				searchInput = sBox
			end

			local optionsScroll = Instance.new("ScrollingFrame")
			optionsScroll.Size = UDim2.new(1, -8, 1, -(searchOffset + 8))
			optionsScroll.Position = UDim2.new(0, 4, 0, searchOffset + 4)
			optionsScroll.BackgroundTransparency = 1
			optionsScroll.BorderSizePixel = 0
			optionsScroll.ScrollBarThickness = 2
			optionsScroll.ScrollBarImageColor3 = THEME.Accent
			optionsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
			optionsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
			optionsScroll.Parent = drawerFrame
			createPadding(optionsScroll, 2, 2, 2, 4)

			local optLayout = Instance.new("UIListLayout")
			optLayout.FillDirection = Enum.FillDirection.Vertical
			optLayout.SortOrder = Enum.SortOrder.LayoutOrder
			optLayout.Padding = UDim.new(0, 4)
			optLayout.Parent = optionsScroll

			local isOpen = false
			local optionButtons: { { Btn: TextButton, Label: TextLabel, Indicator: Frame, OptionValue: string } } = {}

			local function getDrawerHeight(): number
				local visibleCount = 0
				for _, entry in ipairs(optionButtons) do
					if entry.Btn.Visible then
						visibleCount += 1
					end
				end
				return searchOffset + math.clamp(visibleCount * 30, 30, 132) + 10
			end

			local function updateOpenHeight()
				if isOpen then
					local dHeight = getDrawerHeight()
					drawerFrame.Size = UDim2.new(1, -28, 0, dHeight)
					tween(card, TWEEN_MEDIUM, { Size = UDim2.new(1, 0, 0, closedHeight + dHeight + 14) })
					tween(arrow, TWEEN_FAST, { Rotation = 180, ImageColor3 = THEME.Accent })
					tween(cardStroke, TWEEN_FAST, { Color = THEME.StrokeActive, Transparency = 0 })
				else
					tween(card, TWEEN_MEDIUM, { Size = UDim2.new(1, 0, 0, closedHeight) })
					tween(arrow, TWEEN_FAST, { Rotation = 0, ImageColor3 = THEME.TextSecondary })
					tween(cardStroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.2 })
				end
			end

			local function updateVisualSelection()
				selectedLabel.Text = getDisplaySummary()
				for _, item in ipairs(optionButtons) do
					local active = if isMulti
						then (selectedMulti[item.OptionValue] == true)
						else (selectedSingle == item.OptionValue)
					tween(item.Btn, TWEEN_FAST, {
						BackgroundColor3 = if active then THEME.CardHover else THEME.MainBackground,
						BackgroundTransparency = if active then 0 else 0.4,
					})
					tween(item.Label, TWEEN_FAST, {
						TextColor3 = if active then THEME.Accent else THEME.TextSecondary,
					})
					tween(item.Indicator, TWEEN_FAST, {
						BackgroundTransparency = if active then 0 else 1,
					})
				end
			end

			local DropdownObj = { Value = if isMulti then selectedMulti else selectedSingle }

			local function emitValue(silent: boolean?)
				local outValue: any
				if isMulti then
					local copy = {}
					for k, v in pairs(selectedMulti) do
						if v then
							copy[k] = true
						end
					end
					outValue = copy
				else
					outValue = selectedSingle
				end
				DropdownObj.Value = outValue
				NightSystem.Flags[flag] = outValue
				if not silent then
					safeCallback(callback, outValue)
				end
			end

			local function rebuildOptionButtons()
				for _, child in ipairs(optionsScroll:GetChildren()) do
					if child:IsA("TextButton") then
						child:Destroy()
					end
				end
				table.clear(optionButtons)

				for idx, rawOpt in ipairs(optionList) do
					local optStr = tostring(rawOpt)
					local optBtn = Instance.new("TextButton")
					optBtn.Size = UDim2.new(1, 0, 0, 26)
					optBtn.BackgroundColor3 = THEME.MainBackground
					optBtn.BackgroundTransparency = 0.4
					optBtn.BorderSizePixel = 0
					optBtn.AutoButtonColor = false
					optBtn.Text = ""
					optBtn.LayoutOrder = idx
					optBtn.Parent = optionsScroll
					createCorner(optBtn, 5)

					local ind = Instance.new("Frame")
					ind.Size = UDim2.new(0, 3, 0, 12)
					ind.Position = UDim2.new(0, 4, 0.5, 0)
					ind.AnchorPoint = Vector2.new(0, 0.5)
					ind.BackgroundColor3 = THEME.Accent
					ind.BackgroundTransparency = 1
					ind.BorderSizePixel = 0
					ind.Parent = optBtn
					createCorner(ind, 2)

					local lbl = Instance.new("TextLabel")
					lbl.Size = UDim2.new(1, -24, 1, 0)
					lbl.Position = UDim2.new(0, 14, 0, 0)
					lbl.BackgroundTransparency = 1
					lbl.Font = Enum.Font.GothamMedium
					lbl.Text = optStr
					lbl.TextColor3 = THEME.TextSecondary
					lbl.TextSize = 12
					lbl.TextXAlignment = Enum.TextXAlignment.Left
					lbl.TextTruncate = Enum.TextTruncate.AtEnd
					lbl.Parent = optBtn

					optBtn.MouseButton1Click:Connect(function()
						if isMulti then
							selectedMulti[optStr] = not selectedMulti[optStr]
							updateVisualSelection()
							emitValue(false)
						else
							selectedSingle = optStr
							updateVisualSelection()
							emitValue(false)
							isOpen = false
							updateOpenHeight()
						end
					end)

					table.insert(optionButtons, {
						Btn = optBtn,
						Label = lbl,
						Indicator = ind,
						OptionValue = optStr,
					})
				end
				updateVisualSelection()
				if isOpen then
					updateOpenHeight()
				end
			end

			if searchInput then
				searchInput:GetPropertyChangedSignal("Text"):Connect(function()
					local q = string.lower(string.gsub(searchInput.Text, "^%s*(.-)%s*$", "%1"))
					for _, entry in ipairs(optionButtons) do
						entry.Btn.Visible = (q == "") or (string.find(string.lower(entry.OptionValue), q, 1, true) ~= nil)
					end
					if isOpen then
						updateOpenHeight()
					end
				end)
			end

			headerBtn.MouseButton1Click:Connect(function()
				isOpen = not isOpen
				updateOpenHeight()
			end)

			rebuildOptionButtons()
			emitValue(true)

			function DropdownObj:Set(val: any, silent: boolean?)
				if isMulti then
					table.clear(selectedMulti)
					if type(val) == "table" then
						for k, v in pairs(val) do
							if type(k) == "number" then
								selectedMulti[tostring(v)] = true
							elseif v then
								selectedMulti[tostring(k)] = true
							end
						end
					elseif type(val) == "string" then
						selectedMulti[val] = true
					end
					DropdownObj.Value = selectedMulti
				else
					selectedSingle = tostring(val or "")
					DropdownObj.Value = selectedSingle
				end
				updateVisualSelection()
				emitValue(silent)
			end

			DropdownObj.SetValue = DropdownObj.Set

			function DropdownObj:Refresh(newOptions: { string }, keepSelection: boolean?)
				optionList = newOptions or {}
				if not keepSelection then
					table.clear(selectedMulti)
					selectedSingle = if #optionList > 0 then tostring(optionList[1]) else ""
				end
				DropdownObj.Value = if isMulti then selectedMulti else selectedSingle
				rebuildOptionButtons()
				emitValue(true)
			end

			DropdownObj.SetValues = DropdownObj.Refresh

			function DropdownObj:Clear()
				table.clear(selectedMulti)
				selectedSingle = ""
				DropdownObj.Value = if isMulti then selectedMulti else selectedSingle
				updateVisualSelection()
				emitValue(false)
			end

			function DropdownObj:Get(): any
				return NightSystem.Flags[flag]
			end

			DropdownObj.GetValue = DropdownObj.Get

			function DropdownObj:OnChanged(cb: (any) -> ())
				callback = cb
			end

			return DropdownObj
		end

		-- 6. Window:CreateInput(...)
		function targetTab:CreateInput(opt1: any, opt2: any, opt3: any, opt4: any)
			local opts = normInput(opt1, opt2, opt3, opt4)
			local name = tostring(opts.Name or "Input")
			local desc = opts.Description
			local placeholder = tostring(opts.Placeholder or "Enter text...")
			local defaultText = tostring(opts.Default or "")
			local clearOnFocus = opts.ClearTextOnFocus == true
			local flag = opts.Flag or name
			local callback = opts.Callback

			local card = createBaseCard("Input", name, desc, 46, opts.LayoutOrder)

			local inputHolder = Instance.new("Frame")
			inputHolder.Size = UDim2.new(0, 170, 0, 26)
			inputHolder.Position = UDim2.new(1, -14, 0.5, 0)
			inputHolder.AnchorPoint = Vector2.new(1, 0.5)
			inputHolder.BackgroundColor3 = THEME.CardInner
			inputHolder.BorderSizePixel = 0
			inputHolder.Parent = card
			createCorner(inputHolder, 6)
			local boxStroke = createStroke(inputHolder, THEME.Stroke, 1, 0.2)

			local textBox = Instance.new("TextBox")
			textBox.Size = UDim2.new(1, -16, 1, 0)
			textBox.Position = UDim2.new(0, 8, 0, 0)
			textBox.BackgroundTransparency = 1
			textBox.Font = Enum.Font.GothamMedium
			textBox.PlaceholderText = placeholder
			textBox.PlaceholderColor3 = THEME.TextSecondary
			textBox.Text = defaultText
			textBox.TextColor3 = THEME.TextPrimary
			textBox.TextSize = 12
			textBox.TextXAlignment = Enum.TextXAlignment.Left
			textBox.TextTruncate = Enum.TextTruncate.AtEnd
			textBox.ClearTextOnFocus = clearOnFocus
			textBox.Parent = inputHolder

			NightSystem.Flags[flag] = defaultText
			local InputObj = { Value = defaultText }

			function InputObj:Set(newText: string, silent: boolean?)
				local str = tostring(newText or "")
				textBox.Text = str
				InputObj.Value = str
				NightSystem.Flags[flag] = str
				if not silent then
					safeCallback(callback, str)
				end
			end

			InputObj.SetValue = InputObj.Set

			function InputObj:Get(): string
				return InputObj.Value
			end

			InputObj.GetValue = InputObj.Get

			function InputObj:OnChanged(cb: (string) -> ())
				callback = cb
			end

			textBox.Focused:Connect(function()
				tween(boxStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0 })
			end)
			textBox.FocusLost:Connect(function()
				tween(boxStroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.2 })
				InputObj.Value = textBox.Text
				NightSystem.Flags[flag] = textBox.Text
				safeCallback(callback, textBox.Text)
			end)

			return InputObj
		end

		-- 7. Window:CreateKeybind(...)
		function targetTab:CreateKeybind(opt1: any, opt2: any, opt3: any, opt4: any)
			local opts = normKeybind(opt1, opt2, opt3, opt4)
			local name = tostring(opts.Name or "Keybind")
			local desc = opts.Description
			local currentKey: EnumItem? = opts.Default or Enum.KeyCode.E
			local mode = tostring(opts.Mode or "Toggle")
			local flag = opts.Flag or name
			local callback = opts.Callback

			local card = createBaseCard("Keybind", name, desc, 44, opts.LayoutOrder)

			local bindBtn = Instance.new("TextButton")
			bindBtn.AutomaticSize = Enum.AutomaticSize.X
			bindBtn.Size = UDim2.new(0, 32, 0, 24)
			bindBtn.Position = UDim2.new(1, -14, 0.5, 0)
			bindBtn.AnchorPoint = Vector2.new(1, 0.5)
			bindBtn.BackgroundColor3 = THEME.CardInner
			bindBtn.BorderSizePixel = 0
			bindBtn.AutoButtonColor = false
			bindBtn.Font = Enum.Font.GothamBold
			bindBtn.Text = formatKeyName(currentKey)
			bindBtn.TextColor3 = THEME.TextPrimary
			bindBtn.TextSize = 11
			bindBtn.Parent = card
			createCorner(bindBtn, 6)
			createPadding(bindBtn, 0, 0, 10, 10)
			local bindStroke = createStroke(bindBtn, THEME.Stroke, 1, 0.2)

			local isBinding = false
			NightSystem.Flags[flag] = currentKey
			local KeybindObj = { Value = currentKey, Mode = mode }

			function KeybindObj:Set(newKey: EnumItem?)
				currentKey = newKey
				KeybindObj.Value = newKey
				NightSystem.Flags[flag] = newKey
				bindBtn.Text = formatKeyName(currentKey)
			end

			KeybindObj.SetValue = KeybindObj.Set

			function KeybindObj:Get(): EnumItem?
				return currentKey
			end

			KeybindObj.GetValue = KeybindObj.Get

			function KeybindObj:OnChanged(cb: (EnumItem?) -> ())
				callback = cb
			end

			bindBtn.MouseButton1Click:Connect(function()
				if isBinding then
					return
				end
				isBinding = true
				bindBtn.Text = "..."
				tween(bindStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0 })
			end)

			trackConnection(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
				if isBinding then
					if input.UserInputType == Enum.UserInputType.Keyboard then
						if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
							KeybindObj:Set(nil)
						else
							KeybindObj:Set(input.KeyCode)
						end
						isBinding = false
						tween(bindStroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.2 })
					elseif
						input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.MouseButton2
						or input.UserInputType == Enum.UserInputType.MouseButton3
					then
						KeybindObj:Set(input.UserInputType)
						isBinding = false
						tween(bindStroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.2 })
					end
					return
				end

				if gameProcessed or UserInputService:GetFocusedTextBox() then
					return
				end

				if currentKey then
					local matched = (input.KeyCode == currentKey) or (input.UserInputType == currentKey)
					if matched then
						safeCallback(callback, currentKey)
					end
				end
			end))

			return KeybindObj
		end

		-- 8. Window:CreateColorPicker(...)
		function targetTab:CreateColorPicker(opt1: any, opt2: any, opt3: any, opt4: any)
			local opts = normColorPicker(opt1, opt2, opt3, opt4)
			local name = tostring(opts.Name or "Color Picker")
			local desc = opts.Description
			local currentColor = opts.Default or Color3.fromRGB(255, 255, 255)
			local flag = opts.Flag or name
			local callback = opts.Callback

			local h, s, v = 0, 1, 1
			pcall(function()
				h, s, v = currentColor:ToHSV()
			end)
			local hasDesc = desc ~= nil and desc ~= ""
			local closedHeight = if hasDesc then 54 else 44
			local expandedHeight = closedHeight + 158

			local card, cardStroke = createBaseCard("ColorPicker", name, desc, closedHeight, opts.LayoutOrder)

			local previewBtn = Instance.new("TextButton")
			previewBtn.Size = UDim2.new(0, 108, 0, 26)
			previewBtn.Position = UDim2.new(1, -14, 0, if hasDesc then 14 else 9)
			previewBtn.AnchorPoint = Vector2.new(1, 0)
			previewBtn.BackgroundColor3 = THEME.CardInner
			previewBtn.BorderSizePixel = 0
			previewBtn.AutoButtonColor = false
			previewBtn.Text = ""
			previewBtn.Parent = card
			createCorner(previewBtn, 6)
			createStroke(previewBtn, THEME.Stroke, 1, 0.2)

			local hexPreviewLabel = Instance.new("TextLabel")
			hexPreviewLabel.Size = UDim2.new(1, -36, 1, 0)
			hexPreviewLabel.Position = UDim2.new(0, 8, 0, 0)
			hexPreviewLabel.BackgroundTransparency = 1
			hexPreviewLabel.Font = Enum.Font.GothamBold
			hexPreviewLabel.Text = colorToHex(currentColor)
			hexPreviewLabel.TextColor3 = THEME.TextSecondary
			hexPreviewLabel.TextSize = 11
			hexPreviewLabel.TextXAlignment = Enum.TextXAlignment.Left
			hexPreviewLabel.Parent = previewBtn

			local swatch = Instance.new("Frame")
			swatch.Size = UDim2.new(0, 20, 0, 16)
			swatch.Position = UDim2.new(1, -6, 0.5, 0)
			swatch.AnchorPoint = Vector2.new(1, 0.5)
			swatch.BackgroundColor3 = currentColor
			swatch.BorderSizePixel = 0
			swatch.Parent = previewBtn
			createCorner(swatch, 4)
			createStroke(swatch, THEME.Stroke, 1, 0.1)

			local pickerDrawer = Instance.new("Frame")
			pickerDrawer.Size = UDim2.new(1, -28, 0, 144)
			pickerDrawer.Position = UDim2.new(0, 14, 0, closedHeight + 4)
			pickerDrawer.BackgroundColor3 = THEME.CardInner
			pickerDrawer.BorderSizePixel = 0
			pickerDrawer.Parent = card
			createCorner(pickerDrawer, 8)
			createStroke(pickerDrawer, THEME.Stroke, 1, 0.2)

			local svCanvas = Instance.new("TextButton")
			svCanvas.Size = UDim2.new(1, -150, 0, 96)
			svCanvas.Position = UDim2.new(0, 10, 0, 10)
			svCanvas.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			svCanvas.BorderSizePixel = 0
			svCanvas.AutoButtonColor = false
			svCanvas.Text = ""
			svCanvas.ClipsDescendants = true
			svCanvas.Parent = pickerDrawer
			createCorner(svCanvas, 6)
			createStroke(svCanvas, THEME.Stroke, 1, 0.2)

			local satLayer = Instance.new("Frame")
			satLayer.Size = UDim2.new(1, 0, 1, 0)
			satLayer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			satLayer.BorderSizePixel = 0
			satLayer.Parent = svCanvas
			createCorner(satLayer, 6)

			local satGrad = Instance.new("UIGradient")
			satGrad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
			satGrad.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
			satGrad.Parent = satLayer

			local valLayer = Instance.new("Frame")
			valLayer.Size = UDim2.new(1, 0, 1, 0)
			valLayer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			valLayer.BorderSizePixel = 0
			valLayer.Parent = svCanvas
			createCorner(valLayer, 6)

			local valGrad = Instance.new("UIGradient")
			valGrad.Color = ColorSequence.new(Color3.fromRGB(0, 0, 0))
			valGrad.Rotation = 90
			valGrad.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			})
			valGrad.Parent = valLayer

			local svCursor = Instance.new("Frame")
			svCursor.Size = UDim2.new(0, 10, 0, 10)
			svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
			svCursor.AnchorPoint = Vector2.new(0.5, 0.5)
			svCursor.BackgroundColor3 = THEME.Accent
			svCursor.BorderSizePixel = 0
			svCursor.ZIndex = 4
			svCursor.Parent = svCanvas
			createCorner(svCursor, 5)
			createStroke(svCursor, THEME.MainBackground, 2, 0)

			local hueBar = Instance.new("TextButton")
			hueBar.Size = UDim2.new(1, -150, 0, 14)
			hueBar.Position = UDim2.new(0, 10, 0, 116)
			hueBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			hueBar.BorderSizePixel = 0
			hueBar.AutoButtonColor = false
			hueBar.Text = ""
			hueBar.Parent = pickerDrawer
			createCorner(hueBar, 4)
			createStroke(hueBar, THEME.Stroke, 1, 0.2)

			local hueGrad = Instance.new("UIGradient")
			hueGrad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
			})
			hueGrad.Parent = hueBar

			local hueCursor = Instance.new("Frame")
			hueCursor.Size = UDim2.new(0, 6, 1, 4)
			hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
			hueCursor.AnchorPoint = Vector2.new(0.5, 0.5)
			hueCursor.BackgroundColor3 = THEME.Accent
			hueCursor.BorderSizePixel = 0
			hueCursor.Parent = hueBar
			createCorner(hueCursor, 3)
			createStroke(hueCursor, THEME.MainBackground, 1, 0)

			local inputsPanel = Instance.new("Frame")
			inputsPanel.Size = UDim2.new(0, 124, 0, 120)
			inputsPanel.Position = UDim2.new(1, -10, 0, 10)
			inputsPanel.AnchorPoint = Vector2.new(1, 0)
			inputsPanel.BackgroundTransparency = 1
			inputsPanel.Parent = pickerDrawer

			local function createSmallField(labelStr: string, yPos: number): TextBox
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 26)
				row.Position = UDim2.new(0, 0, 0, yPos)
				row.BackgroundColor3 = THEME.MainBackground
				row.BorderSizePixel = 0
				row.Parent = inputsPanel
				createCorner(row, 5)
				createStroke(row, THEME.Stroke, 1, 0.2)

				local tag = Instance.new("TextLabel")
				tag.Size = UDim2.new(0, 34, 1, 0)
				tag.Position = UDim2.new(0, 8, 0, 0)
				tag.BackgroundTransparency = 1
				tag.Font = Enum.Font.GothamBold
				tag.Text = labelStr
				tag.TextColor3 = THEME.TextSecondary
				tag.TextSize = 10
				tag.TextXAlignment = Enum.TextXAlignment.Left
				tag.Parent = row

				local box = Instance.new("TextBox")
				box.Size = UDim2.new(1, -44, 1, 0)
				box.Position = UDim2.new(0, 40, 0, 0)
				box.BackgroundTransparency = 1
				box.Font = Enum.Font.GothamMedium
				box.Text = ""
				box.TextColor3 = THEME.TextPrimary
				box.TextSize = 11
				box.TextXAlignment = Enum.TextXAlignment.Right
				box.ClearTextOnFocus = false
				box.Parent = row

				return box
			end

			local hexBox = createSmallField("HEX", 0)
			local rBox = createSmallField("R", 31)
			local gBox = createSmallField("G", 62)
			local bBox = createSmallField("B", 93)

			local ColorPickerObj = { Value = currentColor }
			NightSystem.Flags[flag] = currentColor

			local function syncColorVisuals(silent: boolean?)
				ColorPickerObj.Value = currentColor
				NightSystem.Flags[flag] = currentColor

				local hexStr = colorToHex(currentColor)
				swatch.BackgroundColor3 = currentColor
				hexPreviewLabel.Text = hexStr
				svCanvas.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
				svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
				hueCursor.Position = UDim2.new(h, 0, 0.5, 0)

				hexBox.Text = hexStr
				local cR = if typeof(currentColor) == "Color3" or (type(currentColor) == "table" and currentColor.R) then currentColor.R else 1
				local cG = if typeof(currentColor) == "Color3" or (type(currentColor) == "table" and currentColor.G) then currentColor.G else 1
				local cB = if typeof(currentColor) == "Color3" or (type(currentColor) == "table" and currentColor.B) then currentColor.B else 1
				rBox.Text = tostring(math.round(cR * 255))
				gBox.Text = tostring(math.round(cG * 255))
				bBox.Text = tostring(math.round(cB * 255))

				if not silent then
					safeCallback(callback, currentColor)
				end
			end

			function ColorPickerObj:Set(newColor: Color3, silent: boolean?)
				if typeof(newColor) == "Color3" or (type(newColor) == "table" and newColor.R) then
					currentColor = newColor
					pcall(function()
						h, s, v = newColor:ToHSV()
					end)
					syncColorVisuals(silent)
				end
			end

			ColorPickerObj.SetValue = ColorPickerObj.Set

			function ColorPickerObj:Get(): Color3
				return currentColor
			end

			ColorPickerObj.GetValue = ColorPickerObj.Get

			function ColorPickerObj:OnChanged(cb: (Color3) -> ())
				callback = cb
			end

			local draggingSV = false
			local draggingHue = false

			local function updateSV(pos: Vector2)
				s = math.clamp((pos.X - svCanvas.AbsolutePosition.X) / math.max(1, svCanvas.AbsoluteSize.X), 0, 1)
				v = 1 - math.clamp((pos.Y - svCanvas.AbsolutePosition.Y) / math.max(1, svCanvas.AbsoluteSize.Y), 0, 1)
				currentColor = Color3.fromHSV(h, s, v)
				syncColorVisuals(false)
			end

			local function updateHue(pos: Vector2)
				h = math.clamp((pos.X - hueBar.AbsolutePosition.X) / math.max(1, hueBar.AbsoluteSize.X), 0, 1)
				currentColor = Color3.fromHSV(h, s, v)
				syncColorVisuals(false)
			end

			local pickerMoveConn: RBXScriptConnection? = nil
			local pickerEndConn: RBXScriptConnection? = nil

			local function stopPickerDrag()
				draggingSV = false
				draggingHue = false
				if pickerMoveConn then pickerMoveConn:Disconnect(); pickerMoveConn = nil end
				if pickerEndConn then pickerEndConn:Disconnect(); pickerEndConn = nil end
			end

			local function ensurePickerListeners()
				if pickerMoveConn and pickerEndConn then return end
				if pickerMoveConn then pickerMoveConn:Disconnect() end
				if pickerEndConn then pickerEndConn:Disconnect() end

				pickerMoveConn = UserInputService.InputChanged:Connect(function(input: InputObject)
					if (draggingSV or draggingHue) and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
						local p = Vector2.new(input.Position.X, input.Position.Y)
						if draggingSV then
							updateSV(p)
						elseif draggingHue then
							updateHue(p)
						end
					end
				end)

				pickerEndConn = UserInputService.InputEnded:Connect(function(input: InputObject)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						stopPickerDrag()
					end
				end)
			end

			svCanvas.InputBegan:Connect(function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingSV = true
					ensurePickerListeners()
					updateSV(Vector2.new(input.Position.X, input.Position.Y))
				end
			end)

			hueBar.InputBegan:Connect(function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingHue = true
					ensurePickerListeners()
					updateHue(Vector2.new(input.Position.X, input.Position.Y))
				end
			end)

			hexBox.FocusLost:Connect(function()
				local parsed = hexToColor(hexBox.Text)
				if parsed then
					ColorPickerObj:Set(parsed, false)
				else
					syncColorVisuals(true)
				end
			end)

			local function onRgbEdited()
				local r = math.clamp(tonumber(rBox.Text) or math.round(currentColor.R * 255), 0, 255)
				local g = math.clamp(tonumber(gBox.Text) or math.round(currentColor.G * 255), 0, 255)
				local b = math.clamp(tonumber(bBox.Text) or math.round(currentColor.B * 255), 0, 255)
				ColorPickerObj:Set(Color3.fromRGB(r, g, b), false)
			end
			rBox.FocusLost:Connect(onRgbEdited)
			gBox.FocusLost:Connect(onRgbEdited)
			bBox.FocusLost:Connect(onRgbEdited)

			local isExpanded = false
			previewBtn.MouseButton1Click:Connect(function()
				isExpanded = not isExpanded
				if isExpanded then
					tween(card, TWEEN_MEDIUM, { Size = UDim2.new(1, 0, 0, expandedHeight) })
					tween(cardStroke, TWEEN_FAST, { Color = THEME.StrokeActive, Transparency = 0 })
				else
					tween(card, TWEEN_MEDIUM, { Size = UDim2.new(1, 0, 0, closedHeight) })
					tween(cardStroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.2 })
				end
			end)

			syncColorVisuals(true)
			return ColorPickerObj
		end

		-- 9. Window:CreateLabel(Text)
		function targetTab:CreateLabel(opt1: any, opt2: any)
			local opts = normLabel(opt1, opt2)
			local text = opts.Text
			local manualOrder = opts.LayoutOrder

			local card = Instance.new("Frame")
			card.Name = "Label_" .. string.sub(text, 1, 16)
			card.Size = UDim2.new(1, 0, 0, 34)
			card.BackgroundColor3 = THEME.CardBackground
			card.BackgroundTransparency = 0.25
			card.BorderSizePixel = 0
			card.LayoutOrder = computeLayoutOrder("Label", manualOrder)
			card.Parent = tabScroll
			createCorner(card, 7)
			createStroke(card, THEME.Stroke, 1, 0.25)

			local dot = Instance.new("Frame")
			dot.Size = UDim2.new(0, 5, 0, 5)
			dot.Position = UDim2.new(0, 14, 0.5, 0)
			dot.AnchorPoint = Vector2.new(0, 0.5)
			dot.BackgroundColor3 = THEME.Accent
			dot.BorderSizePixel = 0
			dot.Parent = card
			createCorner(dot, 3)

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -36, 1, 0)
			lbl.Position = UDim2.new(0, 26, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamMedium
			lbl.Text = text
			lbl.TextColor3 = THEME.TextInfo
			lbl.TextSize = 12
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextTruncate = Enum.TextTruncate.AtEnd
			lbl.Parent = card

			registerSearchable(card, text)

			local LabelObj = {}
			function LabelObj:Set(newText: string)
				lbl.Text = tostring(newText)
			end
			LabelObj.SetText = LabelObj.Set
			return LabelObj
		end

		-- 10. Window:CreateParagraph({ Title = "...", Content = "..." })
		function targetTab:CreateParagraph(opt1: any, opt2: any)
			local opts = normParagraph(opt1, opt2)
			local title = tostring(opts.Title or "Information")
			local content = tostring(opts.Content or "")

			local card = Instance.new("Frame")
			card.Name = "Paragraph_" .. title
			card.AutomaticSize = Enum.AutomaticSize.Y
			card.Size = UDim2.new(1, 0, 0, 56)
			card.BackgroundColor3 = THEME.CardBackground
			card.BorderSizePixel = 0
			card.LayoutOrder = computeLayoutOrder("Paragraph", opts.LayoutOrder)
			card.Parent = tabScroll
			createCorner(card, 8)
			createStroke(card, THEME.Stroke, 1, 0.2)
			createPadding(card, 12, 12, 14, 14)

			local pLayout = Instance.new("UIListLayout")
			pLayout.FillDirection = Enum.FillDirection.Vertical
			pLayout.SortOrder = Enum.SortOrder.LayoutOrder
			pLayout.Padding = UDim.new(0, 4)
			pLayout.Parent = card

			local titleLbl = Instance.new("TextLabel")
			titleLbl.Size = UDim2.new(1, 0, 0, 16)
			titleLbl.BackgroundTransparency = 1
			titleLbl.Font = Enum.Font.GothamBold
			titleLbl.Text = title
			titleLbl.TextColor3 = THEME.TextPrimary
			titleLbl.TextSize = 13
			titleLbl.TextXAlignment = Enum.TextXAlignment.Left
			titleLbl.LayoutOrder = 1
			titleLbl.Parent = card

			local contentLbl = Instance.new("TextLabel")
			contentLbl.AutomaticSize = Enum.AutomaticSize.Y
			contentLbl.Size = UDim2.new(1, 0, 0, 16)
			contentLbl.BackgroundTransparency = 1
			contentLbl.Font = Enum.Font.GothamMedium
			contentLbl.Text = content
			contentLbl.TextColor3 = THEME.TextInfo
			contentLbl.TextSize = 12
			contentLbl.TextWrapped = true
			contentLbl.TextXAlignment = Enum.TextXAlignment.Left
			contentLbl.TextYAlignment = Enum.TextYAlignment.Top
			contentLbl.LineHeight = 1.25
			contentLbl.LayoutOrder = 2
			contentLbl.Parent = card

			registerSearchable(card, title .. " " .. content)

			local ParagraphObj = {}
			function ParagraphObj:Set(newOpts: { Title: string?, Content: string? } | string, extraContent: string?)
				if type(newOpts) == "table" then
					if newOpts.Title then
						titleLbl.Text = tostring(newOpts.Title)
					end
					if newOpts.Content or newOpts.Text or newOpts.Desc then
						contentLbl.Text = tostring(newOpts.Content or newOpts.Text or newOpts.Desc)
					end
				else
					titleLbl.Text = tostring(newOpts or "")
					if extraContent ~= nil then
						contentLbl.Text = tostring(extraContent)
					end
				end
			end
			ParagraphObj.SetTitle = function(self, t: string) titleLbl.Text = tostring(t) end
			ParagraphObj.SetContent = function(self, c: string) contentLbl.Text = tostring(c) end
			return ParagraphObj
		end

		-- 11. Window:CreateDivider()
		function targetTab:CreateDivider(manualOrder: number?)
			local divHolder = Instance.new("Frame")
			divHolder.Name = "Divider"
			divHolder.Size = UDim2.new(1, 0, 0, 10)
			divHolder.BackgroundTransparency = 1
			divHolder.LayoutOrder = computeLayoutOrder("Divider", manualOrder)
			divHolder.Parent = tabScroll

			local line = Instance.new("Frame")
			line.Size = UDim2.new(1, -8, 0, 1)
			line.Position = UDim2.new(0.5, 0, 0.5, 0)
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.BackgroundColor3 = THEME.Stroke
			line.BackgroundTransparency = 0.2
			line.BorderSizePixel = 0
			line.Parent = divHolder

			return divHolder
		end

		-- Multi-Library Aliases on Tab
		targetTab.AddToggle = targetTab.CreateToggle
		targetTab.NewToggle = targetTab.CreateToggle
		targetTab.AddButton = targetTab.CreateButton
		targetTab.NewButton = targetTab.CreateButton
		targetTab.AddSlider = targetTab.CreateSlider
		targetTab.NewSlider = targetTab.CreateSlider
		targetTab.AddDropdown = targetTab.CreateDropdown
		targetTab.NewDropdown = targetTab.CreateDropdown
		targetTab.AddInput = targetTab.CreateInput
		targetTab.AddTextbox = targetTab.CreateInput
		targetTab.NewTextBox = targetTab.CreateInput
		targetTab.CreateTextBox = targetTab.CreateInput
		targetTab.AddBind = targetTab.CreateKeybind
		targetTab.AddKeybind = targetTab.CreateKeybind
		targetTab.NewKeybind = targetTab.CreateKeybind
		targetTab.AddColorpicker = targetTab.CreateColorPicker
		targetTab.NewColorPicker = targetTab.CreateColorPicker
		targetTab.AddLabel = targetTab.CreateLabel
		targetTab.NewLabel = targetTab.CreateLabel
		targetTab.AddParagraph = targetTab.CreateParagraph
		targetTab.NewParagraph = targetTab.CreateParagraph
		targetTab.AddDivider = targetTab.CreateDivider
		targetTab.NewDivider = targetTab.CreateDivider
		targetTab.AddSection = targetTab.CreateSection
		targetTab.NewSection = targetTab.CreateSection
	end

	local function createTabInternal(rawName: any, rawIcon: any)
		local tabName = "Tab"
		local iconAsset = ASSETS.Main
		if type(rawName) == "table" then
			tabName = tostring(rawName.Name or rawName.Title or rawName.Text or "Tab")
			if rawName.Icon then
				local ic = tostring(rawName.Icon)
				iconAsset = if not string.find(ic, "rbxasset") and tonumber(ic) then "rbxassetid://" .. ic else ic
			end
		elseif type(rawName) == "string" and rawName ~= "" then
			tabName = rawName
			if rawIcon then
				local ic = tostring(rawIcon)
				iconAsset = if not string.find(ic, "rbxasset") and tonumber(ic) then "rbxassetid://" .. ic else ic
			end
		end

		if tabName == "Home" then
			tabName = "Home Script"
		end

		if createdTabs[tabName] then
			return createdTabs[tabName]
		end

		TabsCategoryFrame.Visible = true

		local tabScriptPage, tabBtn, tabLabel = registerSidebarTab(tabName, iconAsset)
		tabBtn.Visible = true

		local ContentHeader = Instance.new("Frame")
		ContentHeader.Name = "ContentHeader"
		ContentHeader.Size = UDim2.new(1, -48, 0, 28)
		ContentHeader.Position = UDim2.new(0, 24, 0, 20)
		ContentHeader.BackgroundTransparency = 1
		ContentHeader.Parent = tabScriptPage

		local TabHeaderTitle = Instance.new("TextLabel")
		TabHeaderTitle.Size = UDim2.new(0.6, 0, 1, 0)
		TabHeaderTitle.Position = UDim2.new(0, 0, 0, 0)
		TabHeaderTitle.BackgroundTransparency = 1
		TabHeaderTitle.Font = Enum.Font.GothamBold
		TabHeaderTitle.Text = tabName
		TabHeaderTitle.TextColor3 = THEME.TextHeaderTitle
		TabHeaderTitle.TextSize = 18
		TabHeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
		TabHeaderTitle.Parent = ContentHeader

		local FilterBoxHolder = Instance.new("Frame")
		FilterBoxHolder.Size = UDim2.new(0, 165, 0, 28)
		FilterBoxHolder.Position = UDim2.new(1, 0, 0.5, 0)
		FilterBoxHolder.AnchorPoint = Vector2.new(1, 0.5)
		FilterBoxHolder.BackgroundColor3 = THEME.MainBackground
		FilterBoxHolder.BorderSizePixel = 0
		FilterBoxHolder.Parent = ContentHeader
		createCorner(FilterBoxHolder, 7)
		local FilterStroke = createStroke(FilterBoxHolder, THEME.Stroke, 1, 0.2)

		local FilterIcon = Instance.new("ImageLabel")
		FilterIcon.Size = UDim2.new(0, 13, 0, 13)
		FilterIcon.Position = UDim2.new(0, 9, 0.5, 0)
		FilterIcon.AnchorPoint = Vector2.new(0, 0.5)
		FilterIcon.BackgroundTransparency = 1
		FilterIcon.Image = ASSETS.Search
		FilterIcon.ImageColor3 = THEME.TextSecondary
		FilterIcon.Parent = FilterBoxHolder

		local FilterInput = Instance.new("TextBox")
		FilterInput.Size = UDim2.new(1, -32, 1, 0)
		FilterInput.Position = UDim2.new(0, 27, 0, 0)
		FilterInput.BackgroundTransparency = 1
		FilterInput.Font = Enum.Font.GothamMedium
		FilterInput.PlaceholderText = "Search elements..."
		FilterInput.PlaceholderColor3 = THEME.TextSecondary
		FilterInput.Text = ""
		FilterInput.TextColor3 = THEME.TextPrimary
		FilterInput.TextSize = 12
		FilterInput.TextXAlignment = Enum.TextXAlignment.Left
		FilterInput.ClearTextOnFocus = false
		FilterInput.Parent = FilterBoxHolder

		FilterInput.Focused:Connect(function()
			tween(FilterStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0.1 })
		end)
		FilterInput.FocusLost:Connect(function()
			tween(FilterStroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.2 })
		end)

		local ScrollContainer = Instance.new("ScrollingFrame")
		ScrollContainer.Name = "ElementScroll"
		ScrollContainer.Size = UDim2.new(1, -32, 1, -78)
		ScrollContainer.Position = UDim2.new(0, 16, 0, 68)
		ScrollContainer.BackgroundTransparency = 1
		ScrollContainer.BorderSizePixel = 0
		ScrollContainer.ScrollBarThickness = 2
		ScrollContainer.ScrollBarImageColor3 = THEME.Accent
		ScrollContainer.ScrollBarImageTransparency = 0.35
		ScrollContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
		ScrollContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
		ScrollContainer.ScrollingDirection = Enum.ScrollingDirection.Y
		ScrollContainer.Parent = tabScriptPage
		createPadding(ScrollContainer, 2, 14, 8, 10)

		local ElementListLayout = Instance.new("UIListLayout")
		ElementListLayout.FillDirection = Enum.FillDirection.Vertical
		ElementListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		ElementListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		ElementListLayout.Padding = UDim.new(0, 8)
		ElementListLayout.Parent = ScrollContainer

		local searchableItems: { { Frame: GuiObject, Title: string } } = {}
		local filterUpdateQueued = false
		FilterInput:GetPropertyChangedSignal("Text"):Connect(function()
			if filterUpdateQueued then return end
		filterUpdateQueued = true
		task.defer(function()
			filterUpdateQueued = false
			if not FilterInput or not FilterInput.Parent then return end
			local query = string.lower(string.gsub(FilterInput.Text, "^%s*(.-)%s*$", "%1"))
			for _, item in ipairs(searchableItems) do
				if query == "" then
					item.Frame.Visible = true
				else
					item.Frame.Visible = string.find(string.lower(item.Title), query, 1, true) ~= nil
				end
			end
		end)
		end)

		local TabObj = {}
		TabObj.Name = tabName
		TabObj.Title = tabName
		TabObj.Page = tabScriptPage
		TabObj.Button = tabBtn
		function TabObj:Select()
			switchSidebarTab(tabName, false)
		end
		TabObj.SetSelected = TabObj.Select
		TabObj.Show = TabObj.Select

		bindTabElementApi(TabObj, ScrollContainer, searchableItems, function()
			TabsCategoryFrame.Visible = true
			tabBtn.Visible = true
		end)

		createdTabs[tabName] = TabObj
		table.insert(tabList, TabObj)

		-- Automatically switch to the newly created tab if it is the first script tab
		if #tabList == 1 then
			task.defer(function()
				switchSidebarTab(tabName, false)
			end)
		end

		return TabObj
	end

	-- Default Tab for elements added directly on Window without calling CreateTab
	local defaultTabInstance = nil
	local function getDefaultTab()
		if not defaultTabInstance then
			defaultTabInstance = createTabInternal(mainTabName, ASSETS.Main)
		end
		return defaultTabInstance
	end

	function Window:CreateTab(nameOrConfig: any, iconAsset: any)
		return createTabInternal(nameOrConfig, iconAsset)
	end
	Window.MakeTab = Window.CreateTab
	Window.NewTab = Window.CreateTab
	Window.AddTab = Window.CreateTab

	function Window:CreateTabs(...)
		local args = { ... }
		local names = {}
		if #args == 1 and type(args[1]) == "table" then
			for k, v in pairs(args[1]) do
				if type(k) == "number" then
					table.insert(names, v)
				else
					table.insert(names, k)
				end
			end
		else
			for _, v in ipairs(args) do
				table.insert(names, v)
			end
		end
		local res = {}
		for i, tName in ipairs(names) do
			local tab = Window:CreateTab(tName)
			res[i] = tab
			if type(tName) == "string" then
				res[tName] = tab
			elseif type(tName) == "table" and (tName.Name or tName.Title) then
				res[tName.Name or tName.Title] = tab
			end
		end
		return res
	end
	Window.MakeTabs = Window.CreateTabs
	Window.AddTabs = Window.CreateTabs
	Window.MakeWindow = function(self, ...) return self end
	Window.CreateWindow = function(self, ...) return self end

	-- Forward direct Window element calls to DefaultTab
	function Window:CreateToggle(...) return getDefaultTab():CreateToggle(...) end
	function Window:CreateButton(...) return getDefaultTab():CreateButton(...) end
	function Window:CreateSlider(...) return getDefaultTab():CreateSlider(...) end
	function Window:CreateDropdown(...) return getDefaultTab():CreateDropdown(...) end
	function Window:CreateInput(...) return getDefaultTab():CreateInput(...) end
	function Window:CreateKeybind(...) return getDefaultTab():CreateKeybind(...) end
	function Window:CreateColorPicker(...) return getDefaultTab():CreateColorPicker(...) end
	function Window:CreateLabel(...) return getDefaultTab():CreateLabel(...) end
	function Window:CreateParagraph(...) return getDefaultTab():CreateParagraph(...) end
	function Window:CreateDivider(...) return getDefaultTab():CreateDivider(...) end
	function Window:CreateSection(...) return getDefaultTab():CreateSection(...) end

	Window.AddToggle = Window.CreateToggle
	Window.NewToggle = Window.CreateToggle
	Window.AddButton = Window.CreateButton
	Window.NewButton = Window.CreateButton
	Window.AddSlider = Window.CreateSlider
	Window.NewSlider = Window.CreateSlider
	Window.AddDropdown = Window.CreateDropdown
	Window.NewDropdown = Window.CreateDropdown
	Window.AddInput = Window.CreateInput
	Window.AddTextbox = Window.CreateInput
	Window.NewTextBox = Window.CreateInput
	Window.CreateTextBox = Window.CreateInput
	Window.AddBind = Window.CreateKeybind
	Window.AddKeybind = Window.CreateKeybind
	Window.NewKeybind = Window.CreateKeybind
	Window.AddColorpicker = Window.CreateColorPicker
	Window.NewColorPicker = Window.CreateColorPicker
	Window.AddLabel = Window.CreateLabel
	Window.NewLabel = Window.CreateLabel
	Window.AddParagraph = Window.CreateParagraph
	Window.NewParagraph = Window.CreateParagraph
	Window.AddDivider = Window.CreateDivider
	Window.NewDivider = Window.CreateDivider
	Window.AddSection = Window.CreateSection
	Window.NewSection = Window.CreateSection

	-- Always select "Home" Tab by default!
	switchSidebarTab("Home", true)

	local hubScriptCount = 0

	function Window:AddHubScript(scriptInfo: {
		Name: string?,
		Game: string?,
		Description: string?,
		Slug: string?,
		PlaceId: number?,
		Image: string?,
		Loadstring: string?,
		Url: string?,
		Callback: (() -> ())?,
	})
		local info = scriptInfo or {}
		hubScriptCount += 1
		local sName = tostring(info.Name or "Script")
		local sSlug = tostring(info.Slug or "")
		local sPlaceId = tonumber(info.PlaceId) or 0
		local sUrl = tostring(info.Url or "")
		local rawLoadstring = if type(info.Loadstring) == "string" and info.Loadstring ~= ""
			then info.Loadstring
			elseif sUrl ~= "" then 'loadstring(game:HttpGet("' .. sUrl .. '"))()'
			else ""
		local sDesc = tostring(info.Description or info.Game or "Night System Official Script")

		if EmptyHubPlaceholder and EmptyHubPlaceholder.Parent then
			EmptyHubPlaceholder.Visible = false
		end

		-- Grid Card for side-by-side layout
		local card = Instance.new("Frame")
		card.Name = "HubScript_" .. sName
		card.Size = UDim2.new(1, 0, 0, 226)
		card.BackgroundColor3 = THEME.CardBackground
		card.BorderSizePixel = 0
		card.LayoutOrder = hubScriptCount
		card.ClipsDescendants = true
		card.Parent = HubScroll
		createCorner(card, 10)
		local cardStroke = createStroke(card, THEME.Stroke, 1, 0.2)

		-- Top Thumbnail Image Container
		local imgContainer = Instance.new("Frame")
		imgContainer.Name = "ImageContainer"
		imgContainer.Size = UDim2.new(1, 0, 0, 110)
		imgContainer.Position = UDim2.new(0, 0, 0, 0)
		imgContainer.BackgroundColor3 = Color3.fromHex("#141619")
		imgContainer.BorderSizePixel = 0
		imgContainer.ClipsDescendants = true
		imgContainer.Parent = card
		createCorner(imgContainer, 10)

		local imgLabel = Instance.new("ImageLabel")
		imgLabel.Name = "ScriptImage"
		imgLabel.Size = UDim2.new(1, 0, 1, 0)
		imgLabel.BackgroundTransparency = 1
		imgLabel.ScaleType = Enum.ScaleType.Crop
		imgLabel.Parent = imgContainer

		-- Fallback to native Roblox game thumbnail
		if sPlaceId > 0 then
			imgLabel.Image = "rbxthumb://type=GameThumbnail&id=" .. tostring(sPlaceId) .. "&w=480&h=270"
		end

		-- Load image from GitHub into executor filesystem via getcustomasset
		if sSlug ~= "" then
			task.spawn(function()
				local gEnv = (type(getgenv) == "function" and getgenv()) or getfenv()
				local writeFn = gEnv.writefile or (writefile :: any)
				local isfileFn = gEnv.isfile or (isfile :: any)
				local isfolderFn = gEnv.isfolder or (isfolder :: any)
				local makefolderFn = gEnv.makefolder or (makefolder :: any)
				local getassetFn = gEnv.getcustomasset or gEnv.getsynasset or (getcustomasset :: any)

				if type(getassetFn) == "function" and type(writeFn) == "function" then
					local folder = "NightSystem_Assets"
					if type(isfolderFn) == "function" and type(makefolderFn) == "function" then
						if not isfolderFn(folder) then
							pcall(makefolderFn, folder)
						end
					end
					local filePath = folder .. "/" .. sSlug .. ".png"
					local exists = type(isfileFn) == "function" and isfileFn(filePath)
					if not exists then
						local imgUrl = "https://raw.githubusercontent.com/NightSyste/NightUI/main/images/" .. sSlug .. ".png"
						local ok, imgData = pcall(function()
							return (game :: any):HttpGet(imgUrl)
						end)
						if ok and imgData and #imgData > 100 then
							pcall(writeFn, filePath, imgData)
							exists = true
						end
					end
					if exists then
						local okA, asset = pcall(getassetFn, filePath)
						if okA and asset then
							imgLabel.Image = asset
						end
					end
				end
			end)
		end

		-- Gradient blend at the bottom of the image
		local imgGrad = Instance.new("Frame")
		imgGrad.Size = UDim2.new(1, 0, 0, 36)
		imgGrad.Position = UDim2.new(0, 0, 1, -36)
		imgGrad.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		imgGrad.BorderSizePixel = 0
		imgGrad.Parent = imgContainer

		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(Color3.fromRGB(0, 0, 0))
		grad.Rotation = 90
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0.4),
		})
		grad.Parent = imgGrad

		-- Top-Left Number Badge on the image
		local numBadge = Instance.new("Frame")
		numBadge.Size = UDim2.new(0, 26, 0, 18)
		numBadge.Position = UDim2.new(0, 8, 0, 8)
		numBadge.BackgroundColor3 = Color3.fromHex("#0F1114")
		numBadge.BackgroundTransparency = 0.25
		numBadge.BorderSizePixel = 0
		numBadge.Parent = imgContainer
		createCorner(numBadge, 5)
		createStroke(numBadge, Color3.fromHex("#2C3036"), 1, 0.2)

		local numLbl = Instance.new("TextLabel")
		numLbl.Size = UDim2.new(1, 0, 1, 0)
		numLbl.BackgroundTransparency = 1
		numLbl.Font = Enum.Font.GothamBold
		numLbl.Text = string.format("%02d", hubScriptCount)
		numLbl.TextColor3 = THEME.TextPrimary
		numLbl.TextSize = 10
		numLbl.Parent = numBadge

		-- Script / Game Name
		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, -16, 0, 16)
		titleLbl.Position = UDim2.new(0, 8, 0, 116)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Font = Enum.Font.GothamBold
		titleLbl.Text = sName
		titleLbl.TextColor3 = THEME.TextPrimary
		titleLbl.TextSize = 12
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
		titleLbl.Parent = card

		-- Loadstring Preview Code Box (Directly in front of the user)
		local codeBoxHolder = Instance.new("Frame")
		codeBoxHolder.Size = UDim2.new(1, -16, 0, 36)
		codeBoxHolder.Position = UDim2.new(0, 8, 0, 136)
		codeBoxHolder.BackgroundColor3 = Color3.fromHex("#0F1113")
		codeBoxHolder.BorderSizePixel = 0
		codeBoxHolder.Parent = card
		createCorner(codeBoxHolder, 6)
		local codeBoxStroke = createStroke(codeBoxHolder, Color3.fromHex("#22252A"), 1, 0.2)

		local codeBox = Instance.new("TextBox")
		codeBox.Size = UDim2.new(1, -12, 1, 0)
		codeBox.Position = UDim2.new(0, 6, 0, 0)
		codeBox.BackgroundTransparency = 1
		codeBox.Font = Enum.Font.Code
		codeBox.Text = rawLoadstring
		codeBox.TextColor3 = Color3.fromHex("#9EABB8")
		codeBox.TextSize = 9
		codeBox.TextWrapped = true
		codeBox.TextXAlignment = Enum.TextXAlignment.Left
		codeBox.TextYAlignment = Enum.TextYAlignment.Center
		codeBox.ClearTextOnFocus = false
		codeBox.Parent = codeBoxHolder

		-- Buttons Bar at the bottom
		local btnBar = Instance.new("Frame")
		btnBar.Size = UDim2.new(1, -16, 0, 28)
		btnBar.Position = UDim2.new(0, 8, 0, 180)
		btnBar.BackgroundTransparency = 1
		btnBar.Parent = card

		-- Copy Button
		local copyBtn = Instance.new("TextButton")
		copyBtn.Name = "CopyButton"
		copyBtn.Size = UDim2.new(0.48, -4, 1, 0)
		copyBtn.Position = UDim2.new(0, 0, 0, 0)
		copyBtn.BackgroundColor3 = Color3.fromHex("#17191C")
		copyBtn.BorderSizePixel = 0
		copyBtn.AutoButtonColor = false
		copyBtn.Font = Enum.Font.GothamBold
		copyBtn.Text = "Copy"
		copyBtn.TextColor3 = THEME.TextSecondary
		copyBtn.TextSize = 11
		copyBtn.Parent = btnBar
		createCorner(copyBtn, 6)
		local copyStroke = createStroke(copyBtn, THEME.Stroke, 1, 0.2)

		copyBtn.MouseEnter:Connect(function()
			tween(copyBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#202429"), TextColor3 = THEME.TextPrimary })
			tween(copyStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0.2 })
		end)
		copyBtn.MouseLeave:Connect(function()
			tween(copyBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#17191C"), TextColor3 = THEME.TextSecondary })
			tween(copyStroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.2 })
		end)

		copyBtn.MouseButton1Click:Connect(function()
			local gEnv = (type(getgenv) == "function" and getgenv()) or getfenv()
			local clipFn = gEnv.setclipboard or gEnv.toclipboard or (setclipboard :: any)
			if type(clipFn) == "function" and rawLoadstring ~= "" then
				pcall(clipFn, rawLoadstring)
				copyBtn.Text = "Copied ✓"
				tween(copyBtn, TWEEN_FAST, { TextColor3 = Color3.fromHex("#4ADE80") })
				task.delay(1.5, function()
					if copyBtn.Parent then
						copyBtn.Text = "Copy"
						tween(copyBtn, TWEEN_FAST, { TextColor3 = THEME.TextSecondary })
					end
				end)
				NightSystem:Notify({
					Title = "Loadstring Copied",
					Content = sName .. " copied to clipboard!",
					Duration = 2.5,
				})
			else
				NightSystem:Notify({
					Title = "Night System Hub",
					Content = rawLoadstring,
					Duration = 3,
				})
			end
		end)

		-- Execute Button
		local execBtn = Instance.new("TextButton")
		execBtn.Name = "ExecuteButton"
		execBtn.Size = UDim2.new(0.52, 0, 1, 0)
		execBtn.Position = UDim2.new(0.48, 4, 0, 0)
		execBtn.BackgroundColor3 = Color3.fromHex("#1E2227")
		execBtn.BorderSizePixel = 0
		execBtn.AutoButtonColor = false
		execBtn.Font = Enum.Font.GothamBold
		execBtn.Text = "▶ Execute"
		execBtn.TextColor3 = THEME.TextPrimary
		execBtn.TextSize = 11
		execBtn.Parent = btnBar
		createCorner(execBtn, 6)
		local execStroke = createStroke(execBtn, Color3.fromHex("#2E333B"), 1, 0.15)

		execBtn.MouseEnter:Connect(function()
			tween(execBtn, TWEEN_FAST, { BackgroundColor3 = THEME.Accent, TextColor3 = THEME.MainBackground })
			tween(execStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0 })
		end)
		execBtn.MouseLeave:Connect(function()
			tween(execBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#1E2227"), TextColor3 = THEME.TextPrimary })
			tween(execStroke, TWEEN_FAST, { Color = Color3.fromHex("#2E333B"), Transparency = 0.15 })
		end)

		execBtn.MouseButton1Click:Connect(function()
			tween(cardStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0.1 })
			task.delay(0.18, function()
				if cardStroke.Parent then
					tween(cardStroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.2 })
				end
			end)

			-- Clear existing script tabs and close modal before executing new script
			Window:ClearScriptTabs()

			NightSystem:Notify({
				Title = "Executing Script",
				Content = "Starting " .. sName .. "...",
				Duration = 3,
			})
			task.spawn(function()
				if gEnv then
					gEnv._NightActiveWindow = Window
					gEnv._NightSystem = NightSystem
					gEnv.NightSystem = NightSystem
					gEnv.NightUI = NightSystem
					gEnv.OrionLib = NightSystem
					gEnv.Rayfield = NightSystem
				end
				pcall(function()
					local gTable: any = _G
					gTable._NightActiveWindow = Window
					gTable._NightSystem = NightSystem
					gTable.NightSystem = NightSystem
					gTable.NightUI = NightSystem
					gTable.OrionLib = NightSystem
					gTable.Rayfield = NightSystem
				end)

				if type(info.Callback) == "function" then
					safeCallback(info.Callback)
				elseif sUrl ~= "" then
					local ok, source = pcall(function()
						return (game :: any):HttpGet(sUrl)
					end)
					if ok and type(source) == "string" and source ~= "" then
						-- Inject active NightSystem so external scripts use the currently running UI
						-- and avoid stale GitHub CDN caching or duplicate ScreenGui creation
						local patched = source
						patched = string.gsub(patched, 'loadstring%(game:HttpGet%([\'"][^\'"]*Night%%.lua[^\'"]*[\'"]%)%)%(%)', 'getgenv()._NightSystem')
						patched = string.gsub(patched, 'loadstring%(game:HttpGet%([\'"][^\'"]*NightSystemUI%%.lua[^\'"]*[\'"]%)%)%(%)', 'getgenv()._NightSystem')
						patched = string.gsub(patched, 'loadstring%(game:HttpGet%([\'"][^\'"]*orion%%.lua[^\'"]*[\'"]%)%)%(%)', 'getgenv()._NightSystem')

						local loadOk, fn = pcall(loadstring, patched)
						if not loadOk or type(fn) ~= "function" then
							loadOk, fn = pcall(loadstring, source)
						end

						if loadOk and type(fn) == "function" then
							local execOk, execErr = pcall(fn)
							if not execOk then
								warn("[Night System] Script execution error (" .. sName .. "):", execErr)
								NightSystem:Notify({
									Title = "Script Error",
									Content = tostring(execErr),
									Duration = 5,
								})
							else
								NightSystem:Notify({
									Title = "Script Loaded",
									Content = sName .. " successfully executed!",
									Duration = 3,
								})
							end
						else
							warn("[Night System] Failed to compile script (" .. sName .. "):", fn)
							NightSystem:Notify({
								Title = "Compile Error",
								Content = "Could not parse " .. sName,
								Duration = 4,
							})
						end
					else
						warn("[Night System] Failed to download script (" .. sName .. ") from:", sUrl)
						NightSystem:Notify({
							Title = "Download Failed",
							Content = "Could not reach " .. sName .. " server",
							Duration = 4,
						})
					end
				elseif rawLoadstring ~= "" then
					local ok, fn = pcall(loadstring, rawLoadstring)
					if ok and type(fn) == "function" then
						local execOk, execErr = pcall(fn)
						if not execOk then
							warn("[Night System] Script execution error (" .. sName .. "):", execErr)
						end
					end
				end
			end)
		end)

		card.MouseEnter:Connect(function()
			tween(card, TWEEN_FAST, { BackgroundColor3 = THEME.CardHover })
			tween(cardStroke, TWEEN_FAST, { Color = THEME.StrokeActive, Transparency = 0.1 })
		end)
		card.MouseLeave:Connect(function()
			tween(card, TWEEN_FAST, { BackgroundColor3 = THEME.CardBackground })
			tween(cardStroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.2 })
		end)

		table.insert(hubSearchEntries, {
			Card = card,
			Query = string.lower(sName .. " " .. sDesc .. " " .. sSlug .. " " .. sUrl),
		})

		return card
	end

	-- Pre-register all 17 Official Night System Scripts in the built-in All Scripts Hub
	local DEFAULT_HUB_SCRIPTS = {
		{
			Name = "Build A Boat For Treasure",
			Slug = "Build-A-Boat-For-Treasure",
			PlaceId = 537413528,
			Description = "Auto Farm, Build Tools & Treasure Teleport",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/Build-A-Boat-For-Treasure",
		},
		{
			Name = "Fling Things and People",
			Slug = "Fling-Things-and-People",
			PlaceId = 6961824067,
			Description = "Super Fling, Anti-Grab & Reach",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/Fling-Things-and-People",
		},
		{
			Name = "Work at a Pizza Place",
			Slug = "Work-at-a-Pizza-Place",
			PlaceId = 192800,
			Description = "Auto Job, Instant Delivery & Cash Farm",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/Work-at-a-Pizza-Place",
		},
		{
			Name = "Murderers VS Sheriffs",
			Slug = "MurderVSsheriff",
			PlaceId = 12355337193,
			Description = "Silent Aim, Hitbox Expander & ESP",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/MurderVSsheriff",
		},
		{
			Name = "Sniper VS Runner",
			Slug = "SniperVSrunner",
			PlaceId = 16568042538,
			Description = "Auto Win, Aimbot & Speed",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/SniperVSrunner",
		},
		{
			Name = "Dexter Escape",
			Slug = "Dexter-Escape",
			PlaceId = 92122513197996,
			Description = "Auto Escape, ESP & Teleports",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/Dexter-Escape",
		},
		{
			Name = "Water Escape",
			Slug = "waterescape",
			PlaceId = 0,
			Description = "Instant Escape, Oxygen & Speed",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/waterescape",
		},
		{
			Name = "German Voice",
			Slug = "GermanVoice",
			PlaceId = 6884319169,
			Description = "Voice Chat Utilities, Troll & Movement",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/GermanVoice",
		},
		{
			Name = "Beach Escape",
			Slug = "BeachEscape",
			PlaceId = 0,
			Description = "Auto Complete, Checkpoints & Fly",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/BeachEscape",
		},
		{
			Name = "Lucky Blocks Battlegrounds",
			Slug = "Luckblock",
			PlaceId = 662417684,
			Description = "Instant Lucky Blocks, All Items & Combat",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/Luckblock",
		},
		{
			Name = "Streamer Life",
			Slug = "streamer",
			PlaceId = 16483433878,
			Description = "Infinite Money, Auto Stream & Upgrades",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/streamer",
		},
		{
			Name = "Bundes RP",
			Slug = "bundesRp",
			PlaceId = 13830755469,
			Description = "Roleplay Utilities, Vehicle Mods & ESP",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/bundesRp",
		},
		{
			Name = "Flick FPS",
			Slug = "FlickFPS",
			PlaceId = 17625359962,
			Description = "Aimbot, Silent Aim & Wallhack ESP",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/FlickFPS",
		},
		{
			Name = "Arsenal",
			Slug = "Arselnal",
			PlaceId = 286090429,
			Description = "Silent Aim, Kill All, ESP & Gun Mods",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/Arselnal",
		},
		{
			Name = "99 Nights",
			Slug = "99Nights",
			PlaceId = 126884695634066,
			Description = "Survival ESP, Fullbright & Auto Evade",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/99Nights",
		},
		{
			Name = "Emergency Hamburg (Notruf Hamburg)",
			Slug = "MainEH",
			PlaceId = 7711635737,
			Description = "Main Script, Car Fly, ESP & Police Bypass",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/MainEH",
		},
		{
			Name = "Murder Mystery 2 (MM2)",
			Slug = "mm2",
			PlaceId = 142823291,
			Description = "Role ESP, Auto Grab Gun, Coin Farm & Fly",
			Url = "https://api.getvortex.vip/api/t/RH5KTH/s/mm2",
		},
	}

	for _, sData in ipairs(DEFAULT_HUB_SCRIPTS) do
		Window:AddHubScript(sData)
	end

	function Window:ClearScriptTabs()
		-- 1. Close AllScripts hub page if open
		if ScriptsHubPage and ScriptsHubPage.Parent then
			ScriptsHubPage.Visible = false
		end

		-- 2. Destroy all custom script tab buttons and pages recorded in tabList
		for _, tabObj in ipairs(tabList) do
			if type(tabObj) == "table" then
				if tabObj.Button and tabObj.Button.Parent then
					pcall(function() tabObj.Button:Destroy() end)
				end
				if tabObj.Page and tabObj.Page.Parent then
					pcall(function() tabObj.Page:Destroy() end)
				end
			end
		end

		-- 3. Destroy any other custom tab registered in SidebarTabs (never destroy "Home")
		for name, sideTab in pairs(SidebarTabs) do
			if name ~= "Home" and type(sideTab) == "table" then
				if sideTab.Button and sideTab.Button.Parent then
					pcall(function() sideTab.Button:Destroy() end)
				end
				if sideTab.Page and sideTab.Page.Parent then
					pcall(function() sideTab.Page:Destroy() end)
				end
				SidebarTabs[name] = nil
			end
		end

		-- 4. Clear tracking tables and default tab reference
		table.clear(createdTabs)
		table.clear(tabList)
		defaultTabInstance = nil

		-- 5. Hide the dynamic TABS category header in the sidebar
		TabsCategoryFrame.Visible = false

		-- 6. Switch active tab cleanly back to Home
		activeTabName = ""
		switchSidebarTab("Home", true)
		if HomePage and HomePage.Parent then
			HomePage.Visible = true
		end

		-- 7. Reset NavContainer scroll position and recalculate scroll canvas
		NavContainer.CanvasPosition = Vector2.new(0, 0)
		updateNavCanvasAndScrollCheck()
		updateActiveIndicator(true)
	end
	Window.ClearTabs = Window.ClearScriptTabs
	Window.ResetTabs = Window.ClearScriptTabs

	function Window:SelectTab(tabName: string)
		switchSidebarTab(tabName, false)
	end

	function Window:Notify(notifOpts: { Title: string?, Content: string?, Duration: number? } | string)
		NightSystem:Notify(notifOpts)
	end

	function Window:Destroy()
		disconnectAll()
		NightSystem._ActiveWindow = nil
		if gEnv then
			gEnv._NightActiveWindow = nil
			gEnv._NightSystem = nil
		end
		if ScreenGui and ScreenGui.Parent then
			ScreenGui:Destroy()
		end
		if BadgeGui and BadgeGui.Parent then
			BadgeGui:Destroy()
		end
	end

	-- ========================================================================
	-- STARTUP SEQUENCE (Platform Selection Window & Animated Loader)
	-- ========================================================================
	local function showPlatformSelectionModal(onSelect: (string) -> ())
		local isTouchDevice = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
		local recommended = if isTouchDevice then "Handy" else "PC"

		local ModalOverlay = Instance.new("TextButton")
		ModalOverlay.Name = "PlatformSelectOverlay"
		ModalOverlay.Size = UDim2.new(1, 0, 1, 0)
		ModalOverlay.Position = UDim2.new(0, 0, 0, 0)
		ModalOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		ModalOverlay.BackgroundTransparency = 1
		ModalOverlay.AutoButtonColor = false
		ModalOverlay.Text = ""
		ModalOverlay.ZIndex = 60
		ModalOverlay.Parent = ScreenGui

		-- Pure Deep Matte Black Modal Window (#070709)
		local ModalCard = Instance.new("Frame")
		ModalCard.Name = "PlatformSelectCard"
		ModalCard.Size = UDim2.new(0, 410, 0, 276)
		ModalCard.Position = UDim2.new(0.5, 0, 0.5, 0)
		ModalCard.AnchorPoint = Vector2.new(0.5, 0.5)
		ModalCard.BackgroundColor3 = Color3.fromHex("#070709")
		ModalCard.BorderSizePixel = 0
		ModalCard.ClipsDescendants = true
		ModalCard.ZIndex = 61
		ModalCard.Parent = ModalOverlay
		createCorner(ModalCard, 14)
		local modalStroke = createStroke(ModalCard, Color3.fromHex("#1A1B1F"), 1.2, 0.1)

		local cardScale = Instance.new("UIScale")
		local function updateCardScale()
			local vp = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(800, 600)
			local sX = (vp.X - 24) / 420
			local sY = (vp.Y - 24) / 290
			cardScale.Scale = math.clamp(math.min(sX, sY), 0.65, 1.0)
		end
		updateCardScale()
		cardScale.Parent = ModalCard
		trackConnection(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateCardScale))

		-- Header Section
		local HeaderFrame = Instance.new("Frame")
		HeaderFrame.Size = UDim2.new(1, -32, 0, 36)
		HeaderFrame.Position = UDim2.new(0, 16, 0, 16)
		HeaderFrame.BackgroundTransparency = 1
		HeaderFrame.ZIndex = 62
		HeaderFrame.Parent = ModalCard

		local IconBox = Instance.new("Frame")
		IconBox.Size = UDim2.new(0, 34, 0, 34)
		IconBox.Position = UDim2.new(0, 0, 0.5, 0)
		IconBox.AnchorPoint = Vector2.new(0, 0.5)
		IconBox.BackgroundColor3 = Color3.fromHex("#0F1014")
		IconBox.BorderSizePixel = 0
		IconBox.ZIndex = 62
		IconBox.Parent = HeaderFrame
		createCorner(IconBox, 8)
		createStroke(IconBox, Color3.fromHex("#222429"), 1, 0.2)

		local IconLetter = Instance.new("TextLabel")
		IconLetter.Size = UDim2.new(1, 0, 1, 0)
		IconLetter.BackgroundTransparency = 1
		IconLetter.Font = Enum.Font.GothamBold
		IconLetter.Text = "N"
		IconLetter.TextColor3 = THEME.TextPrimary
		IconLetter.TextSize = 17
		IconLetter.ZIndex = 63
		IconLetter.Parent = IconBox

		local RedAccentDot = Instance.new("Frame")
		RedAccentDot.Size = UDim2.new(0, 6, 0, 6)
		RedAccentDot.Position = UDim2.new(1, -3, 0, 3)
		RedAccentDot.AnchorPoint = Vector2.new(0.5, 0.5)
		RedAccentDot.BackgroundColor3 = THEME.AccentRed
		RedAccentDot.BorderSizePixel = 0
		RedAccentDot.ZIndex = 64
		RedAccentDot.Parent = IconBox
		createCorner(RedAccentDot, 6)

		local TitleLbl = Instance.new("TextLabel")
		TitleLbl.Size = UDim2.new(1, -44, 0, 18)
		TitleLbl.Position = UDim2.new(0, 44, 0, 0)
		TitleLbl.BackgroundTransparency = 1
		TitleLbl.Font = Enum.Font.GothamBold
		TitleLbl.Text = "Night System"
		TitleLbl.TextColor3 = THEME.TextPrimary
		TitleLbl.TextSize = 15
		TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
		TitleLbl.ZIndex = 62
		TitleLbl.Parent = HeaderFrame

		local SubtitleLbl = Instance.new("TextLabel")
		SubtitleLbl.Size = UDim2.new(1, -44, 0, 14)
		SubtitleLbl.Position = UDim2.new(0, 44, 0, 18)
		SubtitleLbl.BackgroundTransparency = 1
		SubtitleLbl.Font = Enum.Font.GothamMedium
		SubtitleLbl.Text = "Plattform-Auswahl • Choose Platform"
		SubtitleLbl.TextColor3 = THEME.TextSecondary
		SubtitleLbl.TextSize = 11
		SubtitleLbl.TextXAlignment = Enum.TextXAlignment.Left
		SubtitleLbl.ZIndex = 62
		SubtitleLbl.Parent = HeaderFrame

		-- Prompt text
		local PromptLbl = Instance.new("TextLabel")
		PromptLbl.Size = UDim2.new(1, -32, 0, 18)
		PromptLbl.Position = UDim2.new(0, 16, 0, 60)
		PromptLbl.BackgroundTransparency = 1
		PromptLbl.Font = Enum.Font.GothamBold
		PromptLbl.Text = "Auf welchem Gerät spielst du?"
		PromptLbl.TextColor3 = THEME.TextPrimary
		PromptLbl.TextSize = 13
		PromptLbl.TextXAlignment = Enum.TextXAlignment.Left
		PromptLbl.ZIndex = 62
		PromptLbl.Parent = ModalCard

		local PromptDesc = Instance.new("TextLabel")
		PromptDesc.Size = UDim2.new(1, -32, 0, 26)
		PromptDesc.Position = UDim2.new(0, 16, 0, 78)
		PromptDesc.BackgroundTransparency = 1
		PromptDesc.Font = Enum.Font.GothamMedium
		PromptDesc.Text = "Wähle deine Plattform, um die UI und Steuerung optimal an dein Gerät anzupassen."
		PromptDesc.TextColor3 = THEME.TextInfo
		PromptDesc.TextSize = 11
		PromptDesc.TextWrapped = true
		PromptDesc.TextXAlignment = Enum.TextXAlignment.Left
		PromptDesc.TextYAlignment = Enum.TextYAlignment.Top
		PromptDesc.ZIndex = 62
		PromptDesc.Parent = ModalCard

		-- Cards Container
		local CardsContainer = Instance.new("Frame")
		CardsContainer.Size = UDim2.new(1, -32, 0, 136)
		CardsContainer.Position = UDim2.new(0, 16, 0, 114)
		CardsContainer.BackgroundTransparency = 1
		CardsContainer.ZIndex = 62
		CardsContainer.Parent = ModalCard

		-- ====================================================================
		-- CUSTOM BUILT PC MONITOR LOGO (Großer Desktop-Bildschirm)
		-- ====================================================================
		local function buildPcMonitorLogo(parent: Instance): (Frame, UIStroke, Frame)
			local holder = Instance.new("Frame")
			holder.Name = "PcMonitorLogo"
			holder.Size = UDim2.new(0, 48, 0, 38)
			holder.Position = UDim2.new(0, 14, 0, 12)
			holder.BackgroundTransparency = 1
			holder.ZIndex = 64
			holder.Parent = parent

			-- Outer Monitor Bezel (Screen Frame)
			local screenFrame = Instance.new("Frame")
			screenFrame.Name = "MonitorBezel"
			screenFrame.Size = UDim2.new(0, 46, 0, 28)
			screenFrame.Position = UDim2.new(0.5, 0, 0, 0)
			screenFrame.AnchorPoint = Vector2.new(0.5, 0)
			screenFrame.BackgroundColor3 = Color3.fromHex("#08090B")
			screenFrame.BorderSizePixel = 0
			screenFrame.ZIndex = 65
			screenFrame.Parent = holder
			createCorner(screenFrame, 4)
			local bezelStroke = createStroke(screenFrame, Color3.fromHex("#D0D4DC"), 1.4, 0)

			-- Inner Display Glass
			local displayGlass = Instance.new("Frame")
			displayGlass.Name = "DisplayGlass"
			displayGlass.Size = UDim2.new(1, -6, 1, -6)
			displayGlass.Position = UDim2.new(0.5, 0, 0.5, 0)
			displayGlass.AnchorPoint = Vector2.new(0.5, 0.5)
			displayGlass.BackgroundColor3 = Color3.fromHex("#111317")
			displayGlass.BorderSizePixel = 0
			displayGlass.ZIndex = 66
			displayGlass.Parent = screenFrame
			createCorner(displayGlass, 2)

			-- Top Menu Bar on display
			local topBar = Instance.new("Frame")
			topBar.Size = UDim2.new(1, -4, 0, 2)
			topBar.Position = UDim2.new(0.5, 0, 0, 2)
			topBar.AnchorPoint = Vector2.new(0.5, 0)
			topBar.BackgroundColor3 = Color3.fromHex("#252830")
			topBar.BorderSizePixel = 0
			topBar.ZIndex = 67
			topBar.Parent = displayGlass

			-- Active terminal cursor / window line
			local termLine = Instance.new("Frame")
			termLine.Size = UDim2.new(0, 10, 0, 2)
			termLine.Position = UDim2.new(0, 3, 0.5, 0)
			termLine.AnchorPoint = Vector2.new(0, 0.5)
			termLine.BackgroundColor3 = Color3.fromHex("#7FB4FF")
			termLine.BorderSizePixel = 0
			termLine.ZIndex = 67
			termLine.Parent = displayGlass
			createCorner(termLine, 1)

			-- Stand Neck
			local standNeck = Instance.new("Frame")
			standNeck.Name = "StandNeck"
			standNeck.Size = UDim2.new(0, 5, 0, 7)
			standNeck.Position = UDim2.new(0.5, 0, 0, 28)
			standNeck.AnchorPoint = Vector2.new(0.5, 0)
			standNeck.BackgroundColor3 = Color3.fromHex("#70757E")
			standNeck.BorderSizePixel = 0
			standNeck.ZIndex = 64
			standNeck.Parent = holder

			-- Stand Base (Foot)
			local standFoot = Instance.new("Frame")
			standFoot.Name = "StandFoot"
			standFoot.Size = UDim2.new(0, 24, 0, 3)
			standFoot.Position = UDim2.new(0.5, 0, 0, 35)
			standFoot.AnchorPoint = Vector2.new(0.5, 0)
			standFoot.BackgroundColor3 = Color3.fromHex("#D0D4DC")
			standFoot.BorderSizePixel = 0
			standFoot.ZIndex = 65
			standFoot.Parent = holder
			createCorner(standFoot, 1)

			return holder, bezelStroke, standFoot
		end

		-- ====================================================================
		-- CUSTOM BUILT HANDY / SMARTPHONE LOGO
		-- ====================================================================
		local function buildSmartphoneLogo(parent: Instance): (Frame, UIStroke)
			local holder = Instance.new("Frame")
			holder.Name = "SmartphoneLogo"
			holder.Size = UDim2.new(0, 26, 0, 38)
			holder.Position = UDim2.new(0, 16, 0, 12)
			holder.BackgroundTransparency = 1
			holder.ZIndex = 64
			holder.Parent = parent

			-- Phone Outer Body Frame
			local phoneBody = Instance.new("Frame")
			phoneBody.Name = "PhoneBody"
			phoneBody.Size = UDim2.new(0, 24, 0, 38)
			phoneBody.Position = UDim2.new(0.5, 0, 0.5, 0)
			phoneBody.AnchorPoint = Vector2.new(0.5, 0.5)
			phoneBody.BackgroundColor3 = Color3.fromHex("#08090B")
			phoneBody.BorderSizePixel = 0
			phoneBody.ZIndex = 65
			phoneBody.Parent = holder
			createCorner(phoneBody, 6)
			local phoneStroke = createStroke(phoneBody, Color3.fromHex("#D0D4DC"), 1.4, 0)

			-- Phone Screen Glass
			local screen = Instance.new("Frame")
			screen.Name = "PhoneScreen"
			screen.Size = UDim2.new(1, -6, 1, -8)
			screen.Position = UDim2.new(0.5, 0, 0.5, 0)
			screen.AnchorPoint = Vector2.new(0.5, 0.5)
			screen.BackgroundColor3 = Color3.fromHex("#111317")
			screen.BorderSizePixel = 0
			screen.ZIndex = 66
			screen.Parent = phoneBody
			createCorner(screen, 3)

			-- Camera / Speaker Notch Pill
			local notch = Instance.new("Frame")
			notch.Name = "Notch"
			notch.Size = UDim2.new(0, 7, 0, 2)
			notch.Position = UDim2.new(0.5, 0, 0, 2)
			notch.AnchorPoint = Vector2.new(0.5, 0)
			notch.BackgroundColor3 = Color3.fromHex("#464A52")
			notch.BorderSizePixel = 0
			notch.ZIndex = 67
			notch.Parent = phoneBody
			createCorner(notch, 1)

			-- Home Bar Pill
			local homeBar = Instance.new("Frame")
			homeBar.Name = "HomeBar"
			homeBar.Size = UDim2.new(0, 9, 0, 1.5)
			homeBar.Position = UDim2.new(0.5, 0, 1, -2.5)
			homeBar.AnchorPoint = Vector2.new(0.5, 1)
			homeBar.BackgroundColor3 = Color3.fromHex("#70757E")
			homeBar.BorderSizePixel = 0
			homeBar.ZIndex = 67
			homeBar.Parent = screen
			createCorner(homeBar, 1)

			return holder, phoneStroke
		end

		local function createPlatformOption(name: string, titleText: string, descText: string, isPhone: boolean, posXScale: number, isRec: boolean)
			local optBtn = Instance.new("TextButton")
			optBtn.Name = "Option_" .. name
			optBtn.Size = UDim2.new(0.5, -6, 1, 0)
			optBtn.Position = UDim2.new(posXScale, if posXScale == 0 then 0 else 6, 0, 0)
			optBtn.BackgroundColor3 = if isRec then Color3.fromHex("#0F1115") else Color3.fromHex("#0B0C0E")
			optBtn.BorderSizePixel = 0
			optBtn.AutoButtonColor = false
			optBtn.Text = ""
			optBtn.ZIndex = 63
			optBtn.Parent = CardsContainer
			createCorner(optBtn, 10)
			local optStroke = createStroke(optBtn, if isRec then Color3.fromHex("#282E38") else Color3.fromHex("#1C1E22"), 1.2, 0.1)

			-- Custom Vector Logo Build
			local iconHolder, strokeA, extraPart
			if isPhone then
				iconHolder, strokeA = buildSmartphoneLogo(optBtn)
			else
				iconHolder, strokeA, extraPart = buildPcMonitorLogo(optBtn)
			end

			if isRec then
				local recBadge = Instance.new("Frame")
				recBadge.Size = UDim2.new(0, 58, 0, 18)
				recBadge.Position = UDim2.new(1, -8, 0, 10)
				recBadge.AnchorPoint = Vector2.new(1, 0)
				recBadge.BackgroundColor3 = Color3.fromHex("#181E27")
				recBadge.BorderSizePixel = 0
				recBadge.ZIndex = 64
				recBadge.Parent = optBtn
				createCorner(recBadge, 4)
				createStroke(recBadge, Color3.fromHex("#2C3A4D"), 1, 0.2)

				local recText = Instance.new("TextLabel")
				recText.Size = UDim2.new(1, 0, 1, 0)
				recText.BackgroundTransparency = 1
				recText.Font = Enum.Font.GothamBold
				recText.Text = "Erkannt"
				recText.TextColor3 = Color3.fromHex("#7FB4FF")
				recText.TextSize = 9
				recText.ZIndex = 65
				recText.Parent = recBadge
			end

			local optTitle = Instance.new("TextLabel")
			optTitle.Size = UDim2.new(1, -28, 0, 18)
			optTitle.Position = UDim2.new(0, 14, 0, 58)
			optTitle.BackgroundTransparency = 1
			optTitle.Font = Enum.Font.GothamBold
			optTitle.Text = titleText
			optTitle.TextColor3 = THEME.TextPrimary
			optTitle.TextSize = 13
			optTitle.TextXAlignment = Enum.TextXAlignment.Left
			optTitle.ZIndex = 64
			optTitle.Parent = optBtn

			local optDesc = Instance.new("TextLabel")
			optDesc.Size = UDim2.new(1, -28, 0, 48)
			optDesc.Position = UDim2.new(0, 14, 0, 78)
			optDesc.BackgroundTransparency = 1
			optDesc.Font = Enum.Font.GothamMedium
			optDesc.Text = descText
			optDesc.TextColor3 = Color3.fromHex("#757980")
			optDesc.TextSize = 10
			optDesc.TextWrapped = true
			optDesc.TextXAlignment = Enum.TextXAlignment.Left
			optDesc.TextYAlignment = Enum.TextYAlignment.Top
			optDesc.LineHeight = 1.2
			optDesc.ZIndex = 64
			optDesc.Parent = optBtn

			optBtn.MouseEnter:Connect(function()
				tween(optBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#14161B") })
				tween(optStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0 })
				if strokeA then tween(strokeA, TWEEN_FAST, { Color = Color3.fromHex("#FFFFFF") }) end
				if extraPart then tween(extraPart, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#FFFFFF") }) end
			end)
			optBtn.MouseLeave:Connect(function()
				tween(optBtn, TWEEN_FAST, { BackgroundColor3 = if isRec then Color3.fromHex("#0F1115") else Color3.fromHex("#0B0C0E") })
				tween(optStroke, TWEEN_FAST, { Color = if isRec then Color3.fromHex("#282E38") else Color3.fromHex("#1C1E22"), Transparency = 0.1 })
				if strokeA then tween(strokeA, TWEEN_FAST, { Color = Color3.fromHex("#D0D4DC") }) end
				if extraPart then tween(extraPart, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#D0D4DC") }) end
			end)

			return optBtn
		end

		local pcBtn = createPlatformOption("PC", "PC / Desktop", "Maus & Tastatur (STRG zum Umschalten)", false, 0, recommended == "PC")
		local mobileBtn = createPlatformOption("Handy", "Handy / Mobile", "Touch-Steuerung & Mobile-Button", true, 0.5, recommended == "Handy")

		local hasSelected = false
		local function selectAndClose(platformName: string)
			if hasSelected then return end
			hasSelected = true

			tween(ModalCard, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 410, 0, 258),
				BackgroundTransparency = 1,
			})
			tween(modalStroke, TWEEN_FAST, { Transparency = 1 })
			tween(ModalOverlay, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			})

			task.wait(0.25)
			ModalOverlay:Destroy()
			onSelect(platformName)
		end

		pcBtn.MouseButton1Click:Connect(function() selectAndClose("PC") end)
		mobileBtn.MouseButton1Click:Connect(function() selectAndClose("Handy") end)

		-- Smooth fade-in
		ModalCard.Size = UDim2.new(0, 360, 0, 230)
		ModalCard.BackgroundTransparency = 0.4
		tween(ModalOverlay, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.45,
		})
		tween(ModalCard, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 390, 0, 246),
			BackgroundTransparency = 0,
		})
	end

	local function runStartupLoader()
		if skipLoader then
			openWindow()
			return
		end
		isLoaderRunning = true

		local LoaderFrame = Instance.new("Frame")
		LoaderFrame.Name = "StartupLoader"
		LoaderFrame.Size = UDim2.new(0, 310, 0, 78)
		LoaderFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		LoaderFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		LoaderFrame.BackgroundColor3 = Color3.fromHex("#121417")
		LoaderFrame.BorderSizePixel = 0
		LoaderFrame.ClipsDescendants = true
		LoaderFrame.ZIndex = 70
		LoaderFrame.Parent = ScreenGui
		createCorner(LoaderFrame, 12)
		local loaderStroke = createStroke(LoaderFrame, Color3.fromHex("#26292E"), 1, 0.15)

		local loaderScale = Instance.new("UIScale")
		loaderScale.Name = "LoaderScale"
		loaderScale.Scale = 1.0
		loaderScale.Parent = LoaderFrame

		local function updateLoaderScale()
			local cam = workspace.CurrentCamera
			local vp = (cam and cam.ViewportSize) or Vector2.new(800, 600)
			if vp.X > 50 and vp.Y > 50 then
				local sX = (vp.X - 24) / 320
				local sY = (vp.Y - 24) / 90
				loaderScale.Scale = math.clamp(math.min(sX, sY), 0.70, 1.0)
			end
		end
		updateLoaderScale()
		trackConnection(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLoaderScale))

		-- Avatar auf der linken Seite
		local avatarHolder = Instance.new("Frame")
		avatarHolder.Size = UDim2.new(0, 48, 0, 48)
		avatarHolder.Position = UDim2.new(0, 16, 0.5, 0)
		avatarHolder.AnchorPoint = Vector2.new(0, 0.5)
		avatarHolder.BackgroundColor3 = Color3.fromHex("#181A1D")
		avatarHolder.BorderSizePixel = 0
		avatarHolder.ZIndex = 71
		avatarHolder.Parent = LoaderFrame
		createCorner(avatarHolder, 24)
		local avatarStroke = createStroke(avatarHolder, Color3.fromHex("#2F333A"), 1, 0.2)

		local avatarImg = Instance.new("ImageLabel")
		avatarImg.Size = UDim2.new(1, 0, 1, 0)
		avatarImg.BackgroundTransparency = 1
		avatarImg.ZIndex = 72
		avatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=150&h=150"
		avatarImg.Parent = avatarHolder
		createCorner(avatarImg, 24)

		task.spawn(function()
			local ok, thumb = pcall(function()
				return Players:GetUserThumbnailAsync(
					LocalPlayer.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size150x150
				)
			end)
			if ok and thumb and avatarImg.Parent then
				avatarImg.Image = thumb
			end
		end)

		-- Mittiger Text (Titel & Status)
		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, -120, 0, 18)
		titleLbl.Position = UDim2.new(0, 74, 0, 19)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Font = Enum.Font.GothamBold
		titleLbl.Text = windowTitle
		titleLbl.TextColor3 = THEME.TextPrimary
		titleLbl.TextSize = 14
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.ZIndex = 71
		titleLbl.Parent = LoaderFrame

		local statusLbl = Instance.new("TextLabel")
		statusLbl.Size = UDim2.new(1, -120, 0, 14)
		statusLbl.Position = UDim2.new(0, 74, 0, 39)
		statusLbl.BackgroundTransparency = 1
		statusLbl.Font = Enum.Font.GothamMedium
		statusLbl.Text = "Loading..."
		statusLbl.TextColor3 = THEME.TextSecondary
		statusLbl.TextSize = 11
		statusLbl.TextXAlignment = Enum.TextXAlignment.Left
		statusLbl.TextTruncate = Enum.TextTruncate.AtEnd
		statusLbl.ZIndex = 71
		statusLbl.Parent = LoaderFrame

		-- Runder Ladekreis (Spinner), der sich kontinuierlich dreht
		local spinner = Instance.new("Frame")
		spinner.Name = "Spinner"
		spinner.Size = UDim2.new(0, 24, 0, 24)
		spinner.Position = UDim2.new(1, -22, 0.5, 0)
		spinner.AnchorPoint = Vector2.new(1, 0.5)
		spinner.BackgroundTransparency = 1
		spinner.ZIndex = 71
		spinner.Parent = LoaderFrame

		local spinnerRing = Instance.new("Frame")
		spinnerRing.Size = UDim2.new(1, 0, 1, 0)
		spinnerRing.BackgroundTransparency = 1
		spinnerRing.Parent = spinner
		createCorner(spinnerRing, 12)
		local ringStroke = Instance.new("UIStroke")
		ringStroke.Color = Color3.fromHex("#FFFFFF")
		ringStroke.Thickness = 2.4
		ringStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ringStroke.Parent = spinnerRing

		local ringGrad = Instance.new("UIGradient")
		ringGrad.Color = ColorSequence.new(Color3.fromHex("#FFFFFF"))
		ringGrad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.00, 0.0),
			NumberSequenceKeypoint.new(0.40, 0.1),
			NumberSequenceKeypoint.new(0.75, 0.6),
			NumberSequenceKeypoint.new(1.00, 1.0),
		})
		ringGrad.Parent = ringStroke

		local isSpinning = true
		local spinConn = RunService.RenderStepped:Connect(function(dt)
			if not isSpinning or not spinner or not spinner.Parent then return end
			spinner.Rotation = (spinner.Rotation + dt * 380) % 360
		end)

		-- Sanfter Einblend-Effekt fuer den Loader
		LoaderFrame.Size = UDim2.new(0, 290, 0, 72)
		tween(LoaderFrame, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 310, 0, 78),
		})

		-- Snappy Status-Phasen (~1.2 Sekunden Gesamtdauer, abbrechbar bei Keypress)
		local function stepWait(dur: number): boolean
			local passed = 0
			while passed < dur do
				if skipLoader then return false end
				local dt = task.wait(0.05)
				passed += dt
			end
			return not skipLoader
		end

		if stepWait(0.25) then
			if statusLbl.Parent then statusLbl.Text = "Checking executor..." end
			if stepWait(0.35) then
				if statusLbl.Parent then statusLbl.Text = "Loading Night System Scripts..." end
				if stepWait(0.35) then
					if statusLbl.Parent then statusLbl.Text = "Preparing UI & assets..." end
					if stepWait(0.25) then
						if statusLbl.Parent then statusLbl.Text = "Ready!" end
						stepWait(0.15)
					end
				end
			end
		end
		isLoaderRunning = false
		isSpinning = false
		if spinConn then
			spinConn:Disconnect()
		end

		pcall(function()
			tween(LoaderFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 325, 0, 82),
				BackgroundTransparency = 1,
			})
			tween(loaderStroke, TWEEN_FAST, { Transparency = 1 })
			tween(avatarHolder, TWEEN_FAST, { BackgroundTransparency = 1 })
			tween(avatarStroke, TWEEN_FAST, { Transparency = 1 })
			tween(avatarImg, TWEEN_FAST, { ImageTransparency = 1 })
			tween(titleLbl, TWEEN_FAST, { TextTransparency = 1 })
			tween(statusLbl, TWEEN_FAST, { TextTransparency = 1 })
			tween(ringStroke, TWEEN_FAST, { Transparency = 1 })
		end)

		task.wait(0.20)
		pcall(function() LoaderFrame:Destroy() end)

		-- Hauptfenster zuverlaessig oeffnen
		openWindow()
	end

	-- Startablauf: Automatische Plattform-Erkennung (kein manuelles Auswaehlen noetig)
	-- Nur falls explizit cfg.PromptPlatform == true uebergeben wird, erscheint das Auswahlfenster
	applyPlatform(selectedPlatform)

	if cfg.PromptPlatform == true then
		task.spawn(function()
			showPlatformSelectionModal(function(chosenPlatform)
				applyPlatform(chosenPlatform)
				task.spawn(runStartupLoader)
			end)
		end)
	else
		task.spawn(runStartupLoader)
	end

	local winInstance = setmetatable(Window, Window)
	NightSystem._ActiveWindow = winInstance

	if gEnv then
		gEnv._NightActiveWindow = winInstance
		gEnv._NightSystem = NightSystem
		gEnv.NightSystem = NightSystem
		gEnv.NightUI = NightSystem
		gEnv.OrionLib = NightSystem
		gEnv.Rayfield = NightSystem
	end

	return winInstance
end

-- Universal shorthand & multi-library compatibility methods on NightSystem
function NightSystem:CreateTab(...)
	return (NightSystem._ActiveWindow or NightSystem:CreateWindow()):CreateTab(...)
end
NightSystem.MakeTab = NightSystem.CreateTab
NightSystem.NewTab = NightSystem.CreateTab
NightSystem.AddTab = NightSystem.CreateTab

function NightSystem:CreateTabs(...)
	return (NightSystem._ActiveWindow or NightSystem:CreateWindow()):CreateTabs(...)
end
NightSystem.MakeTabs = NightSystem.CreateTabs
NightSystem.AddTabs = NightSystem.CreateTabs

function NightSystem:MakeWindow(...)
	return NightSystem:CreateWindow(...)
end
NightSystem.MakeWindow = NightSystem.CreateWindow
NightSystem.CreateLib = NightSystem.CreateWindow
NightSystem.NewWindow = NightSystem.CreateWindow
NightSystem.Init = function(self, ...) return NightSystem:CreateWindow(...) end
NightSystem.Load = function(self, ...) return NightSystem:CreateWindow(...) end

function NightSystem:CreateSection(...)
	return (NightSystem._ActiveWindow or NightSystem:CreateWindow()):CreateSection(...)
end
NightSystem.AddSection = NightSystem.CreateSection
NightSystem.NewSection = NightSystem.CreateSection

function NightSystem:CreateToggle(...)
	return (NightSystem._ActiveWindow or NightSystem:CreateWindow()):CreateToggle(...)
end
NightSystem.AddToggle = NightSystem.CreateToggle
NightSystem.NewToggle = NightSystem.CreateToggle

function NightSystem:CreateButton(...)
	return (NightSystem._ActiveWindow or NightSystem:CreateWindow()):CreateButton(...)
end
NightSystem.AddButton = NightSystem.CreateButton
NightSystem.NewButton = NightSystem.CreateButton

function NightSystem:CreateSlider(...)
	return (NightSystem._ActiveWindow or NightSystem:CreateWindow()):CreateSlider(...)
end
NightSystem.AddSlider = NightSystem.CreateSlider
NightSystem.NewSlider = NightSystem.CreateSlider

function NightSystem:CreateDropdown(...)
	return (NightSystem._ActiveWindow or NightSystem:CreateWindow()):CreateDropdown(...)
end
NightSystem.AddDropdown = NightSystem.CreateDropdown
NightSystem.NewDropdown = NightSystem.CreateDropdown

function NightSystem:CreateInput(...)
	return (NightSystem._ActiveWindow or NightSystem:CreateWindow()):CreateInput(...)
end
NightSystem.AddInput = NightSystem.CreateInput
NightSystem.AddTextbox = NightSystem.CreateInput
NightSystem.NewTextBox = NightSystem.CreateInput
NightSystem.CreateTextBox = NightSystem.CreateInput

function NightSystem:CreateKeybind(...)
	return (NightSystem._ActiveWindow or NightSystem:CreateWindow()):CreateKeybind(...)
end
NightSystem.AddBind = NightSystem.CreateKeybind
NightSystem.AddKeybind = NightSystem.CreateKeybind
NightSystem.NewKeybind = NightSystem.CreateKeybind

function NightSystem:CreateColorPicker(...)
	return (NightSystem._ActiveWindow or NightSystem:CreateWindow()):CreateColorPicker(...)
end
NightSystem.AddColorpicker = NightSystem.CreateColorPicker
NightSystem.NewColorPicker = NightSystem.CreateColorPicker

function NightSystem:CreateLabel(...)
	return (NightSystem._ActiveWindow or NightSystem:CreateWindow()):CreateLabel(...)
end
NightSystem.AddLabel = NightSystem.CreateLabel
NightSystem.NewLabel = NightSystem.CreateLabel

function NightSystem:CreateParagraph(...)
	return (NightSystem._ActiveWindow or NightSystem:CreateWindow()):CreateParagraph(...)
end
NightSystem.AddParagraph = NightSystem.CreateParagraph
NightSystem.NewParagraph = NightSystem.CreateParagraph

function NightSystem:CreateDivider(...)
	return (NightSystem._ActiveWindow or NightSystem:CreateWindow()):CreateDivider(...)
end
NightSystem.AddDivider = NightSystem.CreateDivider
NightSystem.NewDivider = NightSystem.CreateDivider

function NightSystem:SetPlatform(platformName: string)
	if NightSystem._ActiveWindow then
		NightSystem._ActiveWindow:SetPlatform(platformName)
	else
		NightSystem._Platform = platformName
	end
end

function NightSystem:GetPlatform(): string
	if NightSystem._ActiveWindow then
		return NightSystem._ActiveWindow:GetPlatform()
	end
	return NightSystem._Platform or (if (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) then "Handy" else "PC")
end

function NightSystem:ClearScriptTabs()
	if NightSystem._ActiveWindow then
		return NightSystem._ActiveWindow:ClearScriptTabs()
	end
end
NightSystem.ClearTabs = NightSystem.ClearScriptTabs
NightSystem.ResetTabs = NightSystem.ClearScriptTabs

function NightSystem:AddHubScript(...)
	return (NightSystem._ActiveWindow or NightSystem:CreateWindow()):AddHubScript(...)
end

function NightSystem:Toggle()
	if NightSystem._ActiveWindow then
		NightSystem._ActiveWindow:Toggle()
	end
end

function NightSystem:Minimize()
	if NightSystem._ActiveWindow then
		NightSystem._ActiveWindow:Minimize()
	end
end

function NightSystem:Open()
	if NightSystem._ActiveWindow then
		NightSystem._ActiveWindow:Open()
	end
end

function NightSystem:Close()
	if NightSystem._ActiveWindow then
		NightSystem._ActiveWindow:Close()
	end
end

-- Fallback metatable on NightSystem so unknown methods never error with attempt to call a nil value
setmetatable(NightSystem, {
	__index = function(t, key)
		local raw = rawget(t, key)
		if raw ~= nil then return raw end
		if type(key) == "string" and string.sub(key, 1, 1) == "_" then
			return nil
		end
		return function(self, ...)
			local active = rawget(NightSystem, "_ActiveWindow")
			if active and type(active) == "table" and active[key] then
				return active[key](active, ...)
			end
			return self or NightSystem
		end
	end,
})

-- Auto-initialize the default Window with the built-in "Home" Tab immediately when the loadstring runs!
NightSystem:CreateWindow()

return NightSystem
