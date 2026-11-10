--!nocheck
local isWritableG = pcall(function()
	(_G :: any)._test = 1
end)
local gEnv = (type(getgenv) == "function" and getgenv()) or (isWritableG and _G) or {}
local NIGHT_BUILD_ID = "2026.11.10-b3"

-- Schutz vor mehrfacher Ausfuehrung (Single-Instance Guard mit automatischem Update-Replace)
if gEnv and (gEnv._NightLoaded or gEnv._NightSystem or gEnv._NightActiveWindow) then
	local existingSys = gEnv._NightSystem
	local existingWin = gEnv._NightActiveWindow or (existingSys and existingSys._ActiveWindow)
	local existingBuild = gEnv._NightBuildId
	local isAlive = false
	if existingWin and existingWin._ScreenGui then
		local p = existingWin._ScreenGui.Parent
		if p and p ~= game and p:IsDescendantOf(game) then
			isAlive = true
		end
	end

	local Players = game:GetService("Players")
	local lp = Players.LocalPlayer
	local hui = type(gethui) == "function" and pcall(gethui) and gethui() or nil
	local coreGui = pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui") or nil
	local pg = lp and lp:FindFirstChild("PlayerGui")

	if not isAlive then
		for _, parentObj in ipairs({ hui, coreGui, pg }) do
			if parentObj and (parentObj:FindFirstChild("NightSystem_UI") or parentObj:FindFirstChild("NightSystem_BadgeGui")) then
				isAlive = true
				break
			end
		end
	end

	if isAlive and existingBuild == NIGHT_BUILD_ID then
		print("[NightSystem] Bereits ausgefuehrt! Night UI (" .. NIGHT_BUILD_ID .. ") ist schon geladen und aktiv.")
		if existingWin then
			pcall(function()
				if existingWin.Open then
					existingWin:Open()
				elseif existingWin._ScreenGui then
					existingWin._ScreenGui.Enabled = true
				end
				if existingWin.Notify then
					existingWin:Notify({
						Title = "Night System",
						Content = "Bereits ausgefuehrt und aktiv!",
						Duration = 2.5,
					})
				end
			end)
			return existingSys or existingWin
		end
		return existingSys or {}
	elseif isAlive or gEnv._NightLoaded or existingSys or existingWin then
		print("[NightSystem] Veraltete UI-Instanz (" .. tostring(existingBuild or "legacy") .. ") gefunden -> Upgrade auf Build " .. NIGHT_BUILD_ID)
		if existingWin and existingWin.Destroy then
			pcall(function() existingWin:Destroy() end)
		end
		if type(existingSys) == "table" and type(existingSys._Connections) == "table" then
			for _, conn in ipairs(existingSys._Connections) do
				pcall(function()
					if conn and conn.Connected then conn:Disconnect() end
				end)
			end
			pcall(function() table.clear(existingSys._Connections) end)
		end
		for _, parentObj in ipairs({ hui, coreGui, pg }) do
			if parentObj then
				for _, guiName in ipairs({ "NightSystem_UI", "NightSystem_BadgeGui" }) do
					for _, child in ipairs(parentObj:GetChildren()) do
						if child.Name == guiName then
							pcall(function() child:Destroy() end)
						end
					end
				end
			end
		end
		gEnv._NightLoaded = nil
		gEnv._NightActiveWindow = nil
		gEnv._NightSystem = nil
		gEnv._NightBuildId = nil
	end
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
	VoiceChat = "rbxasset://textures/ui/VoiceChat/MicLight/Unmuted0.png",
	VoiceChatMuted = "rbxasset://textures/ui/VoiceChat/MicLight/Muted.png",
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
-- Pre-defined static datasets (Module-Level to prevent function register limits)
local EMOTES_DATA = {
{ name = "MJ - P.Y.T.", id = 137234266130963 },
{ name = "Kawaii Anime Tanz OG", id = 130855166586798 },
{ name = "BEST Party-Rock-Hymne", id = 98918840942712 },
{ name = "Michael Jackson Mondgang", id = 90850139979211 },
{ name = "Niedliches Sitzen", id = 72947568152049 },
{ name = "Needy V-Sit Split Drop", id = 100354575525671 },
{ name = "Umarmung", id = 125491951751014 },
{ name = "Popstar Bewegungen", id = 87757463565936 },
{ name = "Zero Two Tanz V3", id = 124963840388798 },
{ name = "Party-Rock-Hymne", id = 105248382902194 },
{ name = "MJ - Billie Jean", id = 98915045016286 },
{ name = "Griddy Tanz", id = 129149402922241 },
{ name = "Cupid (Fifty Fifty)", id = 86132602394818 },
{ name = "Never Gonna Give You Up (Rickroll)", id = 94960135681008 },
{ name = "Rambunctious", id = 108128682361404 },
{ name = "Godlike Schwebung", id = 3823158750 },
{ name = "Schläfrig (Sleepy)", id = 114701975807821 },
{ name = "d4vd - Backflip Salto", id = 15694504637 },
}

local DEFAULT_HUB_SCRIPTS = {
{
Name = "Murderers VS Sheriffs",
Slug = "MurderVSsheriff",
PlaceId = 12355337193,
Description = "Silent Aim, Hitbox Expander & ESP",
Url = "https://nightsystem-dashboard-2ysp.onrender.com/api/t/ns_789663/s/MurderVSsheriff",
},
{
Name = "Murder Mystery 2 (MM2)",
Slug = "mm2",
PlaceId = 142823291,
Description = "Role ESP, Auto Grab Gun, Coin Farm & Fly",
Url = "https://nightsystem-dashboard-2ysp.onrender.com/api/t/ns_789663/s/mm2",
},
{
Name = "Sniper VS Runner",
Slug = "SniperVSrunner",
PlaceId = 16568042538,
Description = "Auto Win, Aimbot & Speed",
Url = "https://nightsystem-dashboard-2ysp.onrender.com/api/t/ns_789663/s/SNIPERvsRUNNER",
},
{
Name = "German Voice",
Slug = "GermanVoice",
PlaceId = 6884319169,
Description = "Voice Chat Utilities, Troll & Movement",
Url = "https://nightsystem-dashboard-2ysp.onrender.com/api/t/ns_789663/s/GermanVC",
},
{
Name = "Lucky Blocks Battlegrounds",
Slug = "Luckblock",
PlaceId = 662417684,
Description = "Instant Lucky Blocks, All Items & Combat",
Url = "https://nightsystem-dashboard-2ysp.onrender.com/api/t/ns_789663/s/LuckyBlock",
},
{
Name = "Streamer Life",
Slug = "streamer",
PlaceId = 16483433878,
Description = "Infinite Money, Auto Stream & Upgrades",
Url = "https://nightsystem-dashboard-2ysp.onrender.com/api/t/ns_789663/s/Streamer",
},
{
Name = "Bundes RP",
Slug = "bundesRp",
PlaceId = 13830755469,
Description = "Roleplay Utilities, Vehicle Mods & ESP",
Url = "https://nightsystem-dashboard-2ysp.onrender.com/api/t/ns_789663/s/BundesRP",
},
{
Name = "Flick FPS",
Slug = "FlickFPS",
PlaceId = 17625359962,
Description = "Aimbot, Silent Aim & Wallhack ESP",
Url = "https://nightsystem-dashboard-2ysp.onrender.com/api/t/ns_789663/s/FlickFPS",
},
{
Name = "Fling Things and People",
Slug = "Fling-Things-and-People",
PlaceId = 6961824067,
Description = "Super Fling, Anti-Grab & Reach",
Url = "https://nightsystem-dashboard-2ysp.onrender.com/api/t/ns_789663/s/FlingThingsPeople",
},
{
Name = "Work at a Pizza Place",
Slug = "Work-at-a-Pizza-Place",
PlaceId = 192800,
Description = "Auto Job, Instant Delivery & Cash Farm",
Url = "https://nightsystem-dashboard-2ysp.onrender.com/api/t/ns_789663/s/PizzaPlace",
},
{
Name = "99 Nights",
Slug = "99Nights",
PlaceId = 126884695634066,
Description = "Survival ESP, Fullbright & Auto Evade",
Url = "https://nightsystem-dashboard-2ysp.onrender.com/api/t/ns_789663/s/99Nights",
},
{
Name = "Arsenal",
Slug = "Arselnal",
PlaceId = 286090429,
Description = "Silent Aim, Kill All, ESP & Gun Mods",
Url = "https://nightsystem-dashboard-2ysp.onrender.com/api/t/ns_789663/s/Arsenal",
},
{
Name = "Emergency Hamburg (Notruf Hamburg)",
Slug = "MainEH",
PlaceId = 7711635737,
Description = "Main Script, Car Fly, ESP & Police Bypass",
Url = "https://nightsystem-dashboard-2ysp.onrender.com/api/t/ns_789663/s/EmergencyHamurg",
},
{
Name = "Emergency Hamburg (Auto Rob)",
Slug = "AutoRob",
PlaceId = 7711635737,
Description = "Auto Rob, ATM Robbery, Store Rob & Teleport",
Url = "https://nightsystem-dashboard-2ysp.onrender.com/api/t/ns_789663/s/EHAutoRob",
},
{
Name = "Military Tycoon",
Slug = "MillitaryTycoon",
PlaceId = 7180042682,
Description = "Auto Farm, Base Upgrades, Gun Mods & Vehicle Speed",
Url = "https://nightsystem-dashboard-2ysp.onrender.com/api/t/ns_789663/s/MillitaryTycoon",
},
}

-- Modular UI Builder functions (Extracted to keep CreateWindow below the 200 local register limit)
local function setupScriptsHub(ContentFrame: Frame, HomePage: Frame, getActiveTabIndicatorUpdater: () -> ((boolean?) -> ()))
	local ScriptsHubPage = Instance.new("Frame")
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
	HubHeaderSub.Size = UDim2.new(1, -134, 0, 16)
	HubHeaderSub.Position = UDim2.new(0, 0, 0, 22)
	HubHeaderSub.BackgroundTransparency = 1
	HubHeaderSub.Font = Enum.Font.GothamMedium
	HubHeaderSub.TextTruncate = Enum.TextTruncate.AtEnd
	HubHeaderSub.Text = tostring(#DEFAULT_HUB_SCRIPTS) .. " Official Scripts • Execute or Copy"
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

	local HubSearchBar = Instance.new("Frame")
	HubSearchBar.Name = "HubSearchBar"
	HubSearchBar.Size = UDim2.new(1, 0, 0, 38)
	HubSearchBar.Position = UDim2.new(0, 0, 0, 48)
	HubSearchBar.BackgroundColor3 = THEME.CardBackground
	HubSearchBar.BorderSizePixel = 0
	HubSearchBar.Parent = ScriptsHubPage
	createCorner(HubSearchBar, 8)
	local HubSearchStroke = createStroke(HubSearchBar, THEME.Stroke, 1, 0.2)

	local HubSearchIcon = Instance.new("ImageLabel")
	HubSearchIcon.Size = UDim2.new(0, 16, 0, 16)
	HubSearchIcon.Position = UDim2.new(0, 10, 0.5, 0)
	HubSearchIcon.AnchorPoint = Vector2.new(0, 0.5)
	HubSearchIcon.BackgroundTransparency = 1
	HubSearchIcon.Image = ASSETS.Search
	HubSearchIcon.ImageColor3 = THEME.TextSecondary
	HubSearchIcon.Parent = HubSearchBar

	local HubSearchBox = Instance.new("TextBox")
	HubSearchBox.Name = "HubSearchBox"
	HubSearchBar.ClipsDescendants = true
	HubSearchBox.Size = UDim2.new(1, -42, 1, 0)
	HubSearchBox.Position = UDim2.new(0, 32, 0, 0)
	HubSearchBox.BackgroundTransparency = 1
	HubSearchBox.ClipsDescendants = true
	HubSearchBox.Font = Enum.Font.GothamMedium
	HubSearchBox.PlaceholderText = "Search " .. tostring(#DEFAULT_HUB_SCRIPTS) .. " scripts (e.g. Auto Rob, MM2, Arsenal)..."
	HubSearchBox.PlaceholderColor3 = THEME.TextSecondary
	HubSearchBox.Text = ""
	HubSearchBox.TextColor3 = THEME.TextPrimary
	HubSearchBox.TextSize = 13
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
	HubScroll.Size = UDim2.new(1, 0, 1, -98)
	HubScroll.Position = UDim2.new(0, 0, 0, 96)
	HubScroll.BackgroundTransparency = 1
	HubScroll.BorderSizePixel = 0
	HubScroll.ScrollBarThickness = 3
	HubScroll.ScrollBarImageColor3 = THEME.Accent
	HubScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	HubScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	HubScroll.Parent = ScriptsHubPage
	createPadding(HubScroll, 2, 12, 2, 8)

	local HubGridLayout = Instance.new("UIGridLayout")
	HubGridLayout.CellSize = UDim2.new(0, 145, 0, 195)
	HubGridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	HubGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	HubGridLayout.Parent = HubScroll

	local function updateHubGrid()
		local mf = ContentFrame and ContentFrame.Parent
		local scObj = mf and mf:FindFirstChild("WindowScale")
		local sc = if scObj and scObj:IsA("UIScale") and scObj.Scale > 0 then scObj.Scale else 1
		local availableW = (HubScroll.AbsoluteSize.X / sc) - 16
		if availableW > 80 then
			local gap = 10
			local cols = if availableW >= 620 then 4 else 3
			local cardW = math.max(120, math.floor((availableW - (gap * (cols - 1))) / cols))
			HubGridLayout.CellSize = UDim2.new(0, cardW, 0, 195)
		end
	end
	HubScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateHubGrid)
	task.defer(updateHubGrid)

	local EmptyHubPlaceholder = Instance.new("Frame")
	EmptyHubPlaceholder.Name = "PlaceholderCard"
	EmptyHubPlaceholder.Size = UDim2.new(1, 0, 0, 64)
	EmptyHubPlaceholder.BackgroundColor3 = THEME.CardBackground
	EmptyHubPlaceholder.BorderSizePixel = 0
	EmptyHubPlaceholder.Visible = false
	EmptyHubPlaceholder.Parent = ScriptsHubPage
	EmptyHubPlaceholder.Position = UDim2.new(0, 0, 0, 96)
	createCorner(EmptyHubPlaceholder, 8)
	createStroke(EmptyHubPlaceholder, THEME.Stroke, 1, 0.2)

	local EmptyHubText = Instance.new("TextLabel")
	EmptyHubText.Size = UDim2.new(1, -28, 1, 0)
	EmptyHubText.Position = UDim2.new(0, 14, 0, 0)
	EmptyHubText.BackgroundTransparency = 1
	EmptyHubText.Font = Enum.Font.GothamMedium
	EmptyHubText.Text = "No scripts match your search. Try another keyword!"
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
				if match then visibleCount += 1 end
			end
			EmptyHubPlaceholder.Visible = (#hubSearchEntries > 0 and visibleCount == 0)
		end)
	end)

	BackToHomeBtn.MouseButton1Click:Connect(function()
		ScriptsHubPage.Visible = false
		HomePage.Visible = true
		HomePage.Position = UDim2.new(0, 0, 0, 8)
		tween(HomePage, TWEEN_MEDIUM, { Position = UDim2.new(0, 0, 0, 0) })
		local updateInd = getActiveTabIndicatorUpdater()
		if updateInd then updateInd(true) end
	end)

	return ScriptsHubPage, HubScroll, EmptyHubPlaceholder, hubSearchEntries
end

local function setupEmotesHub(ContentFrame: Frame, HomePage: Frame, getActiveTabIndicatorUpdater: () -> ((boolean?) -> ()))
	local animCache: { [number]: Animation } = {}

	local function getEmoteAnimation(emoteId: number): Animation
		if animCache[emoteId] then
			return animCache[emoteId]
		end

		local success, objs = pcall(function()
			return game:GetObjects("rbxassetid://" .. tostring(emoteId))
		end)

		if success and objs and objs[1] then
			local asset = objs[1]
			if asset:IsA("Animation") then
				animCache[emoteId] = asset
				return asset
			end
			local anim = asset:FindFirstChildWhichIsA("Animation", true)
			if anim then
				animCache[emoteId] = anim
				return anim
			end
		end

		local fallbackAnim = Instance.new("Animation")
		fallbackAnim.AnimationId = "rbxassetid://" .. tostring(emoteId)
		animCache[emoteId] = fallbackAnim
		return fallbackAnim
	end

	local EmotesHubPage = Instance.new("Frame")
	EmotesHubPage.Name = "EmotesHub_Page"
	EmotesHubPage.Size = UDim2.new(1, 0, 1, 0)
	EmotesHubPage.BackgroundTransparency = 1
	EmotesHubPage.Visible = false
	EmotesHubPage.Parent = ContentFrame
	createPadding(EmotesHubPage, 24, 24, 24, 24)

	local EmotesHeaderTitle = Instance.new("TextLabel")
	EmotesHeaderTitle.Size = UDim2.new(1, -260, 0, 20)
	EmotesHeaderTitle.Position = UDim2.new(0, 0, 0, 0)
	EmotesHeaderTitle.BackgroundTransparency = 1
	EmotesHeaderTitle.Font = Enum.Font.GothamBold
	EmotesHeaderTitle.Text = "Free Emotes (" .. tostring(#EMOTES_DATA) .. ")"
	EmotesHeaderTitle.TextColor3 = THEME.TextHeaderTitle
	EmotesHeaderTitle.TextSize = 18
	EmotesHeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
	EmotesHeaderTitle.Parent = EmotesHubPage

	local EmotesHeaderSub = Instance.new("TextLabel")
	EmotesHeaderSub.Size = UDim2.new(1, -260, 0, 16)
	EmotesHeaderSub.Position = UDim2.new(0, 0, 0, 22)
	EmotesHeaderSub.BackgroundTransparency = 1
	EmotesHeaderSub.Font = Enum.Font.GothamMedium
	EmotesHeaderSub.Text = "[V] Stopp • Klicken zum Aktivieren/Deaktivieren"
	EmotesHeaderSub.TextColor3 = THEME.TextHeaderSub
	EmotesHeaderSub.TextSize = 13
	EmotesHeaderSub.TextXAlignment = Enum.TextXAlignment.Left
	EmotesHeaderSub.Parent = EmotesHubPage

	local EmotesBackToHomeBtn = Instance.new("TextButton")
	EmotesBackToHomeBtn.Name = "EmotesBackToHomeButton"
	EmotesBackToHomeBtn.Size = UDim2.new(0, 118, 0, 32)
	EmotesBackToHomeBtn.Position = UDim2.new(1, 0, 0, 2)
	EmotesBackToHomeBtn.AnchorPoint = Vector2.new(1, 0)
	EmotesBackToHomeBtn.BackgroundColor3 = Color3.fromHex("#181B1E")
	EmotesBackToHomeBtn.BorderSizePixel = 0
	EmotesBackToHomeBtn.AutoButtonColor = false
	EmotesBackToHomeBtn.Font = Enum.Font.GothamBold
	EmotesBackToHomeBtn.Text = "‹  Back to Home"
	EmotesBackToHomeBtn.TextColor3 = THEME.TextPrimary
	EmotesBackToHomeBtn.TextSize = 12
	EmotesBackToHomeBtn.Parent = EmotesHubPage
	createCorner(EmotesBackToHomeBtn, 8)
	local EmotesBackHomeStroke = createStroke(EmotesBackToHomeBtn, Color3.fromHex("#2A2E33"), 1, 0.1)

	EmotesBackToHomeBtn.MouseEnter:Connect(function()
		tween(EmotesBackToHomeBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#22262B") })
		tween(EmotesBackHomeStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0 })
	end)
	EmotesBackToHomeBtn.MouseLeave:Connect(function()
		tween(EmotesBackToHomeBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#181B1E") })
		tween(EmotesBackHomeStroke, TWEEN_FAST, { Color = Color3.fromHex("#2A2E33"), Transparency = 0.1 })
	end)

	local EmotesQuickStopBtn = Instance.new("TextButton")
	EmotesQuickStopBtn.Name = "EmotesQuickStopButton"
	EmotesQuickStopBtn.Size = UDim2.new(0, 96, 0, 32)
	EmotesQuickStopBtn.Position = UDim2.new(1, -126, 0, 2)
	EmotesQuickStopBtn.AnchorPoint = Vector2.new(1, 0)
	EmotesQuickStopBtn.BackgroundColor3 = Color3.fromHex("#181B1E")
	EmotesQuickStopBtn.BorderSizePixel = 0
	EmotesQuickStopBtn.AutoButtonColor = false
	EmotesQuickStopBtn.Font = Enum.Font.GothamBold
	EmotesQuickStopBtn.Text = "■  Stop [V]"
	EmotesQuickStopBtn.TextColor3 = Color3.fromRGB(255, 95, 95)
	EmotesQuickStopBtn.TextSize = 12
	EmotesQuickStopBtn.Parent = EmotesHubPage
	createCorner(EmotesQuickStopBtn, 8)
	local QuickStopStroke = createStroke(EmotesQuickStopBtn, Color3.fromHex("#2A2E33"), 1, 0.1)

	EmotesQuickStopBtn.MouseEnter:Connect(function()
		tween(EmotesQuickStopBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#2B1A1A") })
		tween(QuickStopStroke, TWEEN_FAST, { Color = Color3.fromRGB(255, 95, 95), Transparency = 0 })
	end)
	EmotesQuickStopBtn.MouseLeave:Connect(function()
		tween(EmotesQuickStopBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#181B1E") })
		tween(QuickStopStroke, TWEEN_FAST, { Color = Color3.fromHex("#2A2E33"), Transparency = 0.1 })
	end)

	local EmotesSearchBar = Instance.new("Frame")
	EmotesSearchBar.Name = "EmotesSearchBar"
	EmotesSearchBar.Size = UDim2.new(1, 0, 0, 38)
	EmotesSearchBar.Position = UDim2.new(0, 0, 0, 42)
	EmotesSearchBar.BackgroundColor3 = THEME.CardBackground
	EmotesSearchBar.BorderSizePixel = 0
	EmotesSearchBar.Parent = EmotesHubPage
	createCorner(EmotesSearchBar, 8)
	local EmotesSearchStroke = createStroke(EmotesSearchBar, THEME.Stroke, 1, 0.2)

	local EmotesSearchIcon = Instance.new("ImageLabel")
	EmotesSearchIcon.Size = UDim2.new(0, 16, 0, 16)
	EmotesSearchIcon.Position = UDim2.new(0, 10, 0.5, 0)
	EmotesSearchIcon.AnchorPoint = Vector2.new(0, 0.5)
	EmotesSearchIcon.BackgroundTransparency = 1
	EmotesSearchIcon.Image = ASSETS.Search
	EmotesSearchIcon.ImageColor3 = THEME.TextSecondary
	EmotesSearchIcon.Parent = EmotesSearchBar

	local EmotesSearchBox = Instance.new("TextBox")
	EmotesSearchBox.Name = "EmotesSearchBox"
	EmotesSearchBox.Size = UDim2.new(1, -40, 1, 0)
	EmotesSearchBox.Position = UDim2.new(0, 32, 0, 0)
	EmotesSearchBox.BackgroundTransparency = 1
	EmotesSearchBox.Font = Enum.Font.GothamMedium
	EmotesSearchBox.PlaceholderText = "Search 18 free emotes (e.g. Griddy, MJ, Cupid, Rickroll)..."
	EmotesSearchBox.PlaceholderColor3 = THEME.TextSecondary
	EmotesSearchBox.Text = ""
	EmotesSearchBox.TextColor3 = THEME.TextPrimary
	EmotesSearchBox.TextSize = 12
	EmotesSearchBox.TextXAlignment = Enum.TextXAlignment.Left
	EmotesSearchBox.ClearTextOnFocus = false
	EmotesSearchBox.Parent = EmotesSearchBar

	EmotesSearchBox.Focused:Connect(function()
		tween(EmotesSearchStroke, TWEEN_FAST, { Color = THEME.StrokeActive, Transparency = 0 })
		tween(EmotesSearchIcon, TWEEN_FAST, { ImageColor3 = THEME.TextPrimary })
	end)
	EmotesSearchBox.FocusLost:Connect(function()
		tween(EmotesSearchStroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.2 })
		tween(EmotesSearchIcon, TWEEN_FAST, { ImageColor3 = THEME.TextSecondary })
	end)

	local EmotesScroll = Instance.new("ScrollingFrame")
	EmotesScroll.Name = "EmotesScroll"
	EmotesScroll.Size = UDim2.new(1, 0, 1, -86)
	EmotesScroll.Position = UDim2.new(0, 0, 0, 86)
	EmotesScroll.BackgroundTransparency = 1
	EmotesScroll.BorderSizePixel = 0
	EmotesScroll.ScrollBarThickness = 3
	EmotesScroll.ScrollBarImageColor3 = THEME.Accent
	EmotesScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	EmotesScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	EmotesScroll.Parent = EmotesHubPage
	createPadding(EmotesScroll, 2, 12, 2, 8)

	local EmotesGridLayout = Instance.new("UIGridLayout")
	EmotesGridLayout.CellSize = UDim2.new(0, 145, 0, 52)
	EmotesGridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	EmotesGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	EmotesGridLayout.Parent = EmotesScroll

	local function updateEmotesGrid()
		local mf = ContentFrame and ContentFrame.Parent
		local scObj = mf and mf:FindFirstChild("WindowScale")
		local sc = if scObj and scObj:IsA("UIScale") and scObj.Scale > 0 then scObj.Scale else 1
		local availableW = (EmotesScroll.AbsoluteSize.X / sc) - 16
		if availableW > 80 then
			local gap = 8
			local cols = if availableW >= 620 then 4 else 3
			local cardW = math.max(120, math.floor((availableW - (gap * (cols - 1))) / cols))
			EmotesGridLayout.CellSize = UDim2.new(0, cardW, 0, 52)
		end
	end
	EmotesScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateEmotesGrid)
	task.defer(updateEmotesGrid)

	local EmptyEmotesPlaceholder = Instance.new("Frame")
	EmptyEmotesPlaceholder.Name = "EmptyEmotesPlaceholder"
	EmptyEmotesPlaceholder.Size = UDim2.new(1, 0, 0, 64)
	EmptyEmotesPlaceholder.BackgroundColor3 = THEME.CardBackground
	EmptyEmotesPlaceholder.BorderSizePixel = 0
	EmptyEmotesPlaceholder.Visible = false
	EmptyEmotesPlaceholder.Parent = EmotesHubPage
	EmptyEmotesPlaceholder.Position = UDim2.new(0, 0, 0, 86)
	createCorner(EmptyEmotesPlaceholder, 8)
	createStroke(EmptyEmotesPlaceholder, THEME.Stroke, 1, 0.2)

	local EmptyEmotesText = Instance.new("TextLabel")
	EmptyEmotesText.Size = UDim2.new(1, -28, 1, 0)
	EmptyEmotesText.Position = UDim2.new(0, 14, 0, 0)
	EmptyEmotesText.BackgroundTransparency = 1
	EmptyEmotesText.Font = Enum.Font.GothamMedium
	EmptyEmotesText.Text = "Kein passendes Emote gefunden."
	EmptyEmotesText.TextColor3 = THEME.TextSecondary
	EmptyEmotesText.TextSize = 13
	EmptyEmotesText.TextXAlignment = Enum.TextXAlignment.Left
	EmptyEmotesText.Parent = EmptyEmotesPlaceholder

	local currentEmoteTrack: AnimationTrack? = nil
	local activeEmoteId: number? = nil
	local emoteCards = {}

	local function updateEmoteVisual(emoteId: number, isPlaying: boolean)
		local item = emoteCards[emoteId]
		if not item then return end

		if isPlaying then
			tween(item.Card, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#171D1B") })
			tween(item.Stroke, TWEEN_FAST, { Color = Color3.fromRGB(60, 220, 130), Transparency = 0.2 })
			tween(item.SwitchBg, TWEEN_FAST, { BackgroundColor3 = Color3.fromRGB(60, 220, 130) })
			tween(item.SwitchStroke, TWEEN_FAST, { Color = Color3.fromRGB(60, 220, 130), Transparency = 0 })
			tween(item.Knob, TWEEN_FAST, {
				Position = UDim2.new(1, -14, 0.5, 0),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			})
			item.SubLabel.Text = "▶ Aktiv"
			item.SubLabel.TextColor3 = Color3.fromRGB(80, 235, 145)
		else
			tween(item.Card, TWEEN_FAST, { BackgroundColor3 = THEME.CardBackground })
			tween(item.Stroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.2 })
			tween(item.SwitchBg, TWEEN_FAST, { BackgroundColor3 = THEME.Stroke })
			tween(item.SwitchStroke, TWEEN_FAST, { Color = THEME.StrokeActive, Transparency = 0.15 })
			tween(item.Knob, TWEEN_FAST, {
				Position = UDim2.new(0, 2, 0.5, 0),
				BackgroundColor3 = THEME.TextTabInactive,
			})
			item.SubLabel.Text = "Play"
			item.SubLabel.TextColor3 = THEME.TextSecondary
		end
	end

	local function stopAllEmotes()
		if currentEmoteTrack then
			pcall(function()
				currentEmoteTrack:Stop(0.2)
				currentEmoteTrack:Destroy()
			end)
			currentEmoteTrack = nil
		end
		if activeEmoteId then
			local oldId = activeEmoteId
			activeEmoteId = nil
			updateEmoteVisual(oldId, false)
		end
	end

	local function toggleEmote(emoteId: number)
		if activeEmoteId == emoteId then
			stopAllEmotes()
			return
		end

		stopAllEmotes()

		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or humanoid)
		if not animator then
			NightSystem:Notify({
				Title = "Emote Fehler",
				Content = "Humanoid / Animator nicht gefunden!",
				Duration = 2,
			})
			return
		end

		local animInstance = getEmoteAnimation(emoteId)
		local ok, track = pcall(function()
			return (animator :: any):LoadAnimation(animInstance)
		end)

		if ok and track then
			currentEmoteTrack = track
			track.Priority = Enum.AnimationPriority.Action4
			track.Looped = true
			track:Play(0.2)

			activeEmoteId = emoteId
			updateEmoteVisual(emoteId, true)
		else
			NightSystem:Notify({
				Title = "Animation Fehler",
				Content = "Konnte Animation nicht laden.",
				Duration = 2,
			})
		end
	end

	EmotesBackToHomeBtn.MouseButton1Click:Connect(function()
		EmotesHubPage.Visible = false
		HomePage.Visible = true
		HomePage.Position = UDim2.new(0, 0, 0, 8)
		tween(HomePage, TWEEN_MEDIUM, { Position = UDim2.new(0, 0, 0, 0) })
		local updateInd = getActiveTabIndicatorUpdater()
		if updateInd then updateInd(true) end
	end)

	EmotesQuickStopBtn.MouseButton1Click:Connect(function()
		stopAllEmotes()
	end)

	local emotesSearchList: { { Card: Frame, Query: string } } = {}

	for index, emote in ipairs(EMOTES_DATA) do
		local card = Instance.new("Frame")
		card.Name = "EmoteCard_" .. tostring(emote.id)
		card.Size = UDim2.new(0, 145, 0, 52)
		card.BackgroundColor3 = THEME.CardBackground
		card.BorderSizePixel = 0
		card.ClipsDescendants = true
		card.LayoutOrder = index
		card.Parent = EmotesScroll
		createCorner(card, 8)
		local cardStroke = createStroke(card, THEME.Stroke, 1, 0.2)

		local iconHolder = Instance.new("Frame")
		iconHolder.Size = UDim2.new(0, 28, 0, 28)
		iconHolder.Position = UDim2.new(0, 6, 0.5, 0)
		iconHolder.AnchorPoint = Vector2.new(0, 0.5)
		iconHolder.BackgroundColor3 = THEME.CardInner
		iconHolder.BorderSizePixel = 0
		iconHolder.Parent = card
		createCorner(iconHolder, 6)
		createStroke(iconHolder, THEME.Stroke, 1, 0.2)

		local iconImg = Instance.new("ImageLabel")
		iconImg.Size = UDim2.new(0, 15, 0, 15)
		iconImg.Position = UDim2.new(0.5, 0, 0.5, 0)
		iconImg.AnchorPoint = Vector2.new(0.5, 0.5)
		iconImg.BackgroundTransparency = 1
		iconImg.Image = ASSETS.Users
		iconImg.ImageColor3 = THEME.TextSecondary
		iconImg.Parent = iconHolder

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -74, 0, 15)
		nameLabel.Position = UDim2.new(0, 38, 0, 8)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = emote.name
		nameLabel.TextColor3 = THEME.TextPrimary
		nameLabel.TextSize = 11
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = card

		local subLabel = Instance.new("TextLabel")
		subLabel.Size = UDim2.new(1, -74, 0, 14)
		subLabel.Position = UDim2.new(0, 38, 0, 26)
		subLabel.BackgroundTransparency = 1
		subLabel.Font = Enum.Font.GothamMedium
		subLabel.Text = "Play"
		subLabel.TextColor3 = THEME.TextSecondary
		subLabel.TextSize = 9
		subLabel.TextXAlignment = Enum.TextXAlignment.Left
		subLabel.TextTruncate = Enum.TextTruncate.AtEnd
		subLabel.Parent = card

		local switchBg = Instance.new("Frame")
		switchBg.Size = UDim2.new(0, 28, 0, 16)
		switchBg.Position = UDim2.new(1, -6, 0.5, 0)
		switchBg.AnchorPoint = Vector2.new(1, 0.5)
		switchBg.BackgroundColor3 = THEME.Stroke
		switchBg.BorderSizePixel = 0
		switchBg.Parent = card
		createCorner(switchBg, 8)
		local switchStroke = createStroke(switchBg, THEME.StrokeActive, 1, 0.15)

		local knob = Instance.new("Frame")
		knob.Size = UDim2.new(0, 12, 0, 12)
		knob.Position = UDim2.new(0, 2, 0.5, 0)
		knob.AnchorPoint = Vector2.new(0, 0.5)
		knob.BackgroundColor3 = THEME.TextTabInactive
		knob.BorderSizePixel = 0
		knob.Parent = switchBg
		createCorner(knob, 6)

		local clickZone = Instance.new("TextButton")
		clickZone.Size = UDim2.new(1, 0, 1, 0)
		clickZone.BackgroundTransparency = 1
		clickZone.Text = ""
		clickZone.Parent = card

		emoteCards[emote.id] = {
			Card = card,
			Stroke = cardStroke,
			SwitchBg = switchBg,
			SwitchStroke = switchStroke,
			Knob = knob,
			SubLabel = subLabel,
			Name = emote.name,
			Id = emote.id,
		}

		table.insert(emotesSearchList, {
			Card = card,
			Query = string.lower(emote.name) .. " " .. tostring(emote.id),
		})

		clickZone.MouseEnter:Connect(function()
			if activeEmoteId ~= emote.id then
				tween(card, TWEEN_FAST, { BackgroundColor3 = THEME.CardHover })
				tween(iconImg, TWEEN_FAST, { ImageColor3 = THEME.TextPrimary })
			end
		end)
		clickZone.MouseLeave:Connect(function()
			if activeEmoteId ~= emote.id then
				tween(card, TWEEN_FAST, { BackgroundColor3 = THEME.CardBackground })
				tween(iconImg, TWEEN_FAST, { ImageColor3 = THEME.TextSecondary })
			end
		end)

		clickZone.MouseButton1Click:Connect(function()
			toggleEmote(emote.id)
		end)
	end

	local emotesSearchQueued = false
	EmotesSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		if emotesSearchQueued then return end
		emotesSearchQueued = true
		task.defer(function()
			emotesSearchQueued = false
			if not EmotesSearchBox or not EmotesSearchBox.Parent then return end
			local q = string.lower(string.gsub(EmotesSearchBox.Text, "^%s*(.-)%s*$", "%1"))
			local visibleCount = 0
			for _, item in ipairs(emotesSearchList) do
				local match = (q == "") or (string.find(item.Query, q, 1, true) ~= nil)
				item.Card.Visible = match
				if match then
					visibleCount += 1
				end
			end
			EmptyEmotesPlaceholder.Visible = (#emotesSearchList > 0 and visibleCount == 0)
		end)
	end)

	trackConnection(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.V then
			stopAllEmotes()
		end
	end))

	trackConnection(LocalPlayer.CharacterAdded:Connect(function()
		stopAllEmotes()
	end))

	return EmotesHubPage, stopAllEmotes
end

local function createVoiceChatBackend(trackConn: (RBXScriptConnection) -> RBXScriptConnection, notifyFn: (string, string, number?) -> ())
	local clonerefFn = (typeof(cloneref) == "function" and cloneref) or function(obj) return obj end
	local vc = {
		version = 1,
		executed = false,
		running = false,
		mode = _G._nvVcbMode,
		muted = false,
		boosterEnabled = (_G._nvVcEnabled == true),
		gain = math.clamp(tonumber(_G._nvVcGain) or 3, 0.1, 3),
		selected = _G._nvVcSel or {},
		boosted = _G._nvVcBoost or {},
		listenConn = nil :: RBXScriptConnection?,
		playConn = nil :: RBXScriptConnection?,
		listeners = {} :: { () -> () },
		commands = {} :: { [string]: any },
	}
	_G._nvVcSel = vc.selected
	_G._nvVcBoost = vc.boosted
	_G._nvVcGain = vc.gain
	_G._nvVcEnabled = vc.boosterEnabled

	local function emitState()
		for _, fn in ipairs(vc.listeners) do
			pcall(fn)
		end
	end

	function vc.onStateChanged(fn: () -> ())
		table.insert(vc.listeners, fn)
	end

	local function nvRef(obj: any)
		if obj == nil then return nil end
		local ok, res = pcall(clonerefFn, obj)
		return if ok and res ~= nil then res else obj
	end

	function vc.findPlayers(q: string): { Player }
		if not q or q == "" then return {} end
		if q == "me" or q == "." then return { LocalPlayer } end
		if q == "all" then return Players:GetPlayers() end
		if q == "others" then
			local o = {}
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LocalPlayer then table.insert(o, p) end
			end
			return o
		end
		local lower = string.lower(q)
		for _, p in ipairs(Players:GetPlayers()) do
			if string.lower(p.Name) == lower or string.lower(p.DisplayName) == lower then
				return { p }
			end
		end
		local out = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if string.sub(string.lower(p.Name), 1, #lower) == lower or string.sub(string.lower(p.DisplayName), 1, #lower) == lower then
				table.insert(out, p)
			end
		end
		if #out == 0 then
			for _, p in ipairs(Players:GetPlayers()) do
				if string.find(string.lower(p.Name), lower, 1, true) or string.find(string.lower(p.DisplayName), lower, 1, true) then
					table.insert(out, p)
				end
			end
		end
		return out
	end

	local function syncMicHudVisual()
		pcall(function()
			local cg = nvRef(game:GetService("CoreGui"))
			local sg = cg and cg:FindFirstChild("NV_MicToggleGUI")
			local sf = sg and sg:FindFirstChild("StatusFrame")
			local ico = sf and sf:FindFirstChildOfClass("ImageLabel")
			if ico then
				ico.Image = vc.muted and ASSETS.VoiceChatMuted or ASSETS.VoiceChat
				ico.ImageColor3 = vc.muted and Color3.fromRGB(255, 96, 96) or Color3.new(1, 1, 1)
			end
		end)
	end

	local function publishMute()
		pcall(function()
			nvRef(game:GetService("VoiceChatInternal")):PublishPause(vc.muted)
		end)
	end

	function vc.setMicMuted(muted: boolean)
		vc.muted = muted == true
		if vc.mode == "v2" and type(_G._nvVcb2SetMuted) == "function" then
			pcall(_G._nvVcb2SetMuted, vc.muted)
		else
			syncMicHudVisual()
			publishMute()
		end
		emitState()
	end

	_G._nvVcbSyncMuted = function(muted: boolean)
		vc.muted = muted == true
		syncMicHudVisual()
		emitState()
	end

	local function ensureMicHudV1()
		local cg = nvRef(game:GetService("CoreGui"))
		if not cg or cg:FindFirstChild("NV_MicToggleGUI") then return end
		local topOrder = 49
		pcall(function()
			local tba = cg:FindFirstChild("TopBarApp")
			if tba and tba:IsA("ScreenGui") then topOrder = tba.DisplayOrder end
		end)
		local micSG = Instance.new("ScreenGui")
		micSG.Name = "NV_MicToggleGUI"
		micSG.ResetOnSpawn = false
		micSG.DisplayOrder = topOrder + 1
		micSG.Parent = cg

		local micFrame = Instance.new("Frame")
		micFrame.Name = "StatusFrame"
		micFrame.Position = UDim2.new(0, 165, 0, -45)
		micFrame.Size = UDim2.new(0, 40, 0, 40)
		micFrame.BackgroundColor3 = THEME.MainBackground
		micFrame.BackgroundTransparency = 0.08
		micFrame.BorderSizePixel = 0
		micFrame.Active = true
		micFrame.Parent = micSG
		createCorner(micFrame, 20)
		createStroke(micFrame, THEME.Stroke, 1, 0.15)

		local micIcon = Instance.new("ImageLabel")
		micIcon.BackgroundTransparency = 1
		micIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		micIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
		micIcon.Size = UDim2.new(0, 20, 0, 20)
		micIcon.Image = vc.muted and ASSETS.VoiceChatMuted or ASSETS.VoiceChat
		micIcon.ImageColor3 = vc.muted and Color3.fromRGB(255, 96, 96) or Color3.new(1, 1, 1)
		micIcon.ScaleType = Enum.ScaleType.Fit
		micIcon.Parent = micFrame

		local micBtn = Instance.new("TextButton")
		micBtn.BackgroundTransparency = 1
		micBtn.Size = UDim2.new(1, 0, 1, 0)
		micBtn.Text = ""
		micBtn.ZIndex = 2
		micBtn.Parent = micFrame

		micBtn.MouseButton1Click:Connect(function()
			vc.setMicMuted(not vc.muted)
		end)
	end

	local function waitMicUnmuted()
		local m = "rbxasset://textures/ui/VoiceChat/MicLight/Muted.png"
		local tba = game:GetService("CoreGui"):WaitForChild("TopBarApp", 5)
		tba = tba and tba:WaitForChild("TopBarApp", 5)
		local lf = tba and tba:WaitForChild("UnibarLeftFrame", 5)
		local um = lf and lf:WaitForChild("UnibarMenu", 5)
		local n2 = um and um:WaitForChild("2", 5)
		local n3 = n2 and n2:WaitForChild("3", 5)
		local tmi = n3 and n3:FindFirstChild("toggle_mic_mute", true)
		if not tmi then return end
		local function getIcon(b)
			return b:WaitForChild("IntegrationIconFrame", 5):WaitForChild("IntegrationIcon", 5)["1"]
		end
		repeat task.wait(1) until getIcon(tmi).Image ~= m
	end

	function vc.setVersion(ver: number)
		if vc.mode or _G._nvVcbMode then
			notifyFn("VC Bypasser", "Bypass bereits aktiv. Rejoin zum Wechseln der Version.", 3)
			return false
		end
		vc.version = if ver == 2 then 2 else 1
		emitState()
		return true
	end

	function vc.runBypassV1()
		if vc.mode or _G._nvVcbMode then
			notifyFn("VC Bypasser", if vc.executed then "Bypass ist bereits aktiv." else "Bypass läuft bereits.", 3)
			return
		end
		vc.version = 1
		vc.mode = "v1"
		_G._nvVcbMode = "v1"
		vc.running = true
		emitState()
		task.spawn(function()
			local ok, err = pcall(function()
				local v = nvRef(game:GetService("VoiceChatService"))
				local vi = nvRef(game:GetService("VoiceChatInternal"))
				local gc = getconnections
				notifyFn("VC Bypasser V1", "Mikrofon entmuten, um Bypass fortzusetzen...", 5)
				pcall(waitMicUnmuted)
				v:leaveVoice()
				task.wait(3)
				if type(gc) == "function" then
					local h = gc(vi.StateChanged)
					for y = 7, #h do
						if h[y] then h[y]:Disable() end
					end
				end
				task.wait(3)
				v:joinVoice()
				vi:PublishPause(vc.muted)
			end)
			vc.running = false
			if ok then
				vc.executed = true
				pcall(ensureMicHudV1)
				pcall(syncMicHudVisual)
				notifyFn("VC Bypasser V1", "Bypass aktiv! Nutze den Mic-Button zum Muten/Entmuten.", 5)
			else
				vc.mode = nil
				_G._nvVcbMode = nil
				notifyFn("VC Bypasser V1", "Bypass fehlgeschlagen: " .. tostring(err), 5)
			end
			emitState()
		end)
	end

	function vc.runBypassV2()
		if vc.mode or _G._nvVcbMode then
			notifyFn("VC Bypasser", if vc.executed then "Bypass ist bereits aktiv." else "Bypass läuft bereits.", 3)
			return
		end
		vc.version = 2
		vc.mode = "v2"
		_G._nvVcbMode = "v2"
		vc.running = true
		emitState()
		task.spawn(function()
			local ok, err = pcall(function()
				local a, b, c = 14, 13, 35
				local g = nvRef(game:GetService("VoiceChatService"))
				local h = nvRef(game:GetService("VoiceChatInternal"))
				local j = nvRef(game:GetService("CoreGui"))
				local l = LocalPlayer:WaitForChild("PlayerGui")
				local m = if type(getconnections) == "function" then getconnections else nil
				local o = "rbxasset://textures/ui/VoiceChat/MicLight/Muted.png"
				local p = "rbxasset://textures/ui/VoiceChat/MicLight/Talking0.png"
				local q, r, s, t = nil, nil, nil, nil
				local function u()
					for _, v in ipairs(j:GetDescendants()) do
						if v.Name == "toggle_mic_mute" then
							q = v
						elseif v.Name == "RedVoiceDot" and v:IsA("GuiObject") then
							t = v
						end
					end
					if q then
						r = q:FindFirstChild("IntegrationIconFrame", true)
						if r then s = r:FindFirstChild("IntegrationIcon", true) end
					end
				end
				u()
				if not q then
					task.spawn(function() g:joinVoice() end)
					task.wait(1.5)
					u()
				end
				notifyFn("VC Bypasser V2", "Mikrofon entmuten, um fortzufahren.", 5)
				local function readImg()
					if s and s:FindFirstChild("1") then return s["1"].Image end
					return nil
				end
				local w = false
				while not w do
					local x = readImg()
					if x and x ~= o and x ~= "" then
						p = x
						w = true
					end
					if not w then task.wait(0.5) end
				end
				task.wait(1)
				task.spawn(function() g:leaveVoice() end)
				task.wait(2)
				if m then
					task.spawn(function()
						local y = m(h.StateChanged)
						for z, aa in ipairs(y) do
							if z >= 7 and aa then aa:Disable() end
						end
					end)
				end
				task.wait(2)
				task.spawn(function() g:joinVoice() end)
				task.wait(1)
				u()
				if q then
					task.spawn(function()
						for _, ab in ipairs(q:GetDescendants()) do
							if ab:IsA("ImageLabel") or ab:IsA("ImageButton") then
								ab.ImageTransparency = 1
							elseif ab:IsA("TextLabel") or ab:IsA("TextButton") then
								ab.TextTransparency = 1
							end
						end
					end)
				end
				local ac = getGuiParent() or j or l
				local ad = ac:FindFirstChild("CustomVoiceController")
				if ad then ad:Destroy() end
				local ae = Instance.new("ScreenGui")
				ae.Name = "CustomVoiceController"
				ae.ResetOnSpawn = false
				ae.IgnoreGuiInset = true
				ae.DisplayOrder = 999999
				ae.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
				ae.Parent = ac
				local af = Instance.new("TextButton")
				af.Name = "MicHitArea"
				af.Size = UDim2.new(0, c, 0, c)
				af.Position = UDim2.new(0, 150 + a, 0, 4 + b)
				af.BackgroundTransparency = 1
				af.Text = ""
				af.Active = true
				af.ZIndex = 10000
				af.Parent = ae
				local ag = Instance.new("ImageLabel")
				ag.Name = "MicIcon"
				ag.Size = UDim2.new(1, 0, 1, 0)
				ag.BackgroundTransparency = 1
				ag.Image = o
				ag.ScaleType = Enum.ScaleType.Fit
				ag.ZIndex = 10001
				ag.Parent = af
				local ah = false
				pcall(function() ah = h:IsPublishPaused() end)
				local function ai(aj: boolean)
					ag.Image = if aj then o else p
					if t and t.Parent then t.Visible = not aj end
					task.spawn(function() h:PublishPause(aj) end)
				end
				af.MouseButton1Click:Connect(function()
					ah = not ah
					ai(ah)
					vc.muted = ah
					emitState()
				end)
				_G._nvVcb2SetMuted = function(muted: boolean)
					ah = muted == true
					ai(ah)
				end
				ai(true)
				ah = true
				vc.muted = true
				local function ak()
					if not s or not s.Parent then u() end
					if s and s.AbsolutePosition.X > 50 then
						return s.AbsolutePosition, s.AbsoluteSize
					elseif q and q.AbsolutePosition.X > 50 then
						return q.AbsolutePosition, q.AbsoluteSize
					end
					return nil, nil
				end
				local al = ak()
				if al and al.X > 0 and al.Y >= 0 then
					af.Position = UDim2.new(0, al.X + a, 0, al.Y + b)
				end
				if t and t:IsA("GuiObject") then t.Visible = not ah end
				trackConn(h.StateChanged:Connect(function()
					pcall(function() ah = h:IsPublishPaused() end)
					if t and t.Parent then t.Visible = not ah end
					vc.muted = ah
					emitState()
				end))
			end)
			vc.running = false
			if ok then
				vc.executed = true
				vc.muted = true
				notifyFn("VC Bypasser V2", "Bypass aktiv! CustomVoiceController bereit.", 5)
			else
				vc.mode = nil
				_G._nvVcbMode = nil
				notifyFn("VC Bypasser V2", "Bypass fehlgeschlagen: " .. tostring(err), 5)
			end
			emitState()
		end)
	end

	_G._nvRunVcb2 = vc.runBypassV2

	function vc.executeBypass()
		if vc.version == 2 then
			vc.runBypassV2()
		else
			vc.runBypassV1()
		end
	end

	function vc.muteAll(paused: boolean)
		local count = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then
				local ok = pcall(function()
					game:GetService("VoiceChatInternal"):SubscribePause(p.UserId, paused)
				end)
				if ok then count += 1 end
			end
		end
		notifyFn("Voice Chat", if paused then ("Alle Spieler stummgeschaltet (" .. tostring(count) .. ")") else ("Stummschaltung für alle aufgehoben (" .. tostring(count) .. ")"), 3)
	end

	function vc.muteTarget(query: string, paused: boolean)
		local targets = vc.findPlayers(query)
		if #targets == 0 then
			notifyFn("Voice Chat", "Spieler nicht gefunden.", 3)
			return
		end
		local names = {}
		for _, p in ipairs(targets) do
			if p ~= LocalPlayer then
				local ok = pcall(function()
					game:GetService("VoiceChatInternal"):SubscribePause(p.UserId, paused)
				end)
				if ok then table.insert(names, p.Name) end
			end
		end
		if #names == 0 then
			notifyFn("Voice Chat", "Kein gültiger Zielspieler gefunden.", 3)
			return
		end
		local prefix = if paused then "Stummgeschaltet: " else "Entmutet: "
		notifyFn("Voice Chat", prefix .. (if #names == 1 then names[1] else (tostring(#names) .. " Spieler")), 3)
	end

	local function getBestListenPart(char: Model?): BasePart?
		if not char then return nil end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.RootPart then return hum.RootPart end
		if char.PrimaryPart then return char.PrimaryPart end
		for _, name in ipairs({ "HumanoidRootPart", "UpperTorso", "Torso", "Head" }) do
			local p = char:FindFirstChild(name)
			if p and p:IsA("BasePart") then return p end
		end
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then return d end
		end
		return nil
	end

	function vc.listenTo(query: string)
		if vc.listenConn then
			pcall(function() vc.listenConn:Disconnect() end)
			vc.listenConn = nil
		end
		local targets = vc.findPlayers(query)
		if #targets == 0 then
			notifyFn("Listen", "Spieler nicht gefunden.", 3)
			return
		end
		local plr = targets[1]
		local ss = game:GetService("SoundService")
		vc.listenConn = trackConn(RunService.Heartbeat:Connect(function()
			pcall(function()
				local part = getBestListenPart(plr.Character)
				if part then ss:SetListener(Enum.ListenerType.ObjectPosition, part) end
			end)
		end))
		notifyFn("Listen", "Höre jetzt auf: " .. plr.DisplayName, 3)
	end

	function vc.unlisten()
		if vc.listenConn then
			pcall(function() vc.listenConn:Disconnect() end)
			vc.listenConn = nil
		end
		pcall(function()
			game:GetService("SoundService"):SetListener(Enum.ListenerType.Camera)
		end)
		notifyFn("Listen", "Listener auf Kamera zurückgesetzt.", 3)
	end

	local function findInput(plr: Player?): any
		if not plr then return nil end
		local function scan(root: Instance?): any
			if not root then return nil end
			local inp = nil
			pcall(function() inp = root:FindFirstChildWhichIsA("AudioDeviceInput", true) end)
			return if inp then nvRef(inp) else nil
		end
		return scan(plr) or scan(plr.Character)
	end

	local function useAudioApi(): boolean?
		local result: boolean? = nil
		pcall(function()
			local vcs = nvRef(game:GetService("VoiceChatService"))
			if vcs then
				local use = vcs.UseAudioApi
				local roll = Enum.AudioApiRollout
				if use == roll.Disabled then result = false
				elseif use == roll.Enabled then result = true end
			end
		end)
		return result
	end

	local function anyInput(): boolean
		local found = false
		pcall(function()
			for _, p in ipairs(Players:GetPlayers()) do
				if findInput(p) then found = true; return end
			end
		end)
		return found
	end

	local function playbackWorks(): boolean
		local ok = false
		pcall(function()
			local p = LocalPlayer or Players:GetPlayers()[1]
			if not p then return end
			local cur = (p :: any).VoiceChatVolume
			;(p :: any).VoiceChatVolume = cur
			ok = true
		end)
		return ok
	end

	local toldNoApi = false
	function vc.warnIfUnsupported(): boolean
		if useAudioApi() == true or anyInput() or playbackWorks() then
			return false
		end
		if not toldNoApi then
			toldNoApi = true
			notifyFn("VC Booster", "Dieses Spiel nutzt nur internen Voice-Chat ohne Audio-API.", 4)
		end
		return true
	end

	local function syncPlayLoop()
		local need = false
		for _, e in pairs(vc.boosted) do
			if e.mode == "playback" then need = true; break end
		end
		if need then
			if not vc.playConn then
				vc.playConn = trackConn(RunService.Heartbeat:Connect(function()
					local playVol = math.clamp(vc.gain * 10, 1, 30)
					for _, e in pairs(vc.boosted) do
						if e.mode == "playback" and e.plr then
							pcall(function() e.plr.VoiceChatVolume = playVol end)
						end
					end
				end))
			end
		elseif vc.playConn then
			pcall(function() vc.playConn:Disconnect() end)
			vc.playConn = nil
		end
	end

	function vc.clearBoost(uid: number)
		local e = vc.boosted[uid]
		if not e then return end
		pcall(function() if e.input and e.origVol ~= nil then e.input.Volume = e.origVol end end)
		pcall(function() if e.plr and e.origPlayback ~= nil then e.plr.VoiceChatVolume = e.origPlayback end end)
		pcall(function() if e.folder then e.folder:Destroy() end end)
		pcall(function() if e.leaveConn then e.leaveConn:Disconnect() end end)
		vc.boosted[uid] = nil
	end

	function vc.boostPlayer(plr: Player)
		if not plr or plr == LocalPlayer then return false, "self" end
		vc.clearBoost(plr.UserId)
		pcall(function() game:GetService("VoiceChatInternal"):SubscribePause(plr.UserId, false) end)
		local input = findInput(plr)
		local leaveConn = nil
		pcall(function()
			leaveConn = Players.PlayerRemoving:Connect(function(leaving)
				if leaving == plr then
					vc.clearBoost(plr.UserId)
					vc.selected[plr.UserId] = nil
					syncPlayLoop()
					emitState()
				end
			end)
		end)
		if not input then
			local origPlayback = nil
			pcall(function() origPlayback = (plr :: any).VoiceChatVolume end)
			local okWrite = pcall(function() (plr :: any).VoiceChatVolume = math.clamp(vc.gain * 10, 1, 30) end)
			if not okWrite then
				if leaveConn then pcall(function() leaveConn:Disconnect() end) end
				return false, "noapi"
			end
			vc.boosted[plr.UserId] = { plr = plr, mode = "playback", origPlayback = origPlayback, leaveConn = leaveConn }
			syncPlayLoop()
			return true
		end
		local origVol = 1
		pcall(function() origVol = input.Volume end)
		pcall(function() input.Volume = vc.gain end)
		pcall(function() input.Muted = false end)
		local host = LocalPlayer:FindFirstChildOfClass("PlayerGui") or workspace
		local folder = Instance.new("Folder")
		folder.Name = "NVVCBoost_" .. tostring(plr.UserId)
		folder.Parent = host
		local fader = Instance.new("AudioFader")
		fader.Name = "Fader"
		fader.Volume = vc.gain
		fader.Parent = folder
		local output = Instance.new("AudioDeviceOutput")
		output.Name = "Out"
		pcall(function() output.Player = LocalPlayer end)
		output.Parent = folder
		local w1 = Instance.new("Wire")
		w1.SourceInstance = input
		w1.SourceName = "Output"
		w1.TargetInstance = fader
		w1.TargetName = "Input"
		w1.Parent = folder
		local w2 = Instance.new("Wire")
		w2.SourceInstance = fader
		w2.SourceName = "Output"
		w2.TargetInstance = output
		w2.TargetName = "Input"
		w2.Parent = folder
		vc.boosted[plr.UserId] = { input = input, origVol = origVol, folder = folder, fader = fader, leaveConn = leaveConn }
		syncPlayLoop()
		return true
	end

	function vc.setGain(newGain: number)
		vc.gain = math.clamp(tonumber(newGain) or 3, 0.1, 3)
		_G._nvVcGain = vc.gain
		local playVol = math.clamp(vc.gain * 10, 1, 30)
		for _, e in pairs(vc.boosted) do
			pcall(function()
				if e.fader then e.fader.Volume = vc.gain end
				if e.input then e.input.Volume = vc.gain end
				if e.mode == "playback" and e.plr then e.plr.VoiceChatVolume = playVol end
			end)
		end
		emitState()
	end

	function vc.setBoosterEnabled(on: boolean)
		vc.boosterEnabled = on == true
		_G._nvVcEnabled = vc.boosterEnabled
		if vc.boosterEnabled then
			vc.warnIfUnsupported()
			for uid in pairs(vc.selected) do
				local plr = Players:GetPlayerByUserId(uid)
				if plr then vc.boostPlayer(plr) end
			end
		else
			local uids = {}
			for uid in pairs(vc.boosted) do table.insert(uids, uid) end
			for _, uid in ipairs(uids) do vc.clearBoost(uid) end
			syncPlayLoop()
		end
		emitState()
	end

	function vc.setBoostTarget(plr: Player, on: boolean)
		if not plr or plr == LocalPlayer then return end
		if on then
			vc.selected[plr.UserId] = true
			if vc.boosterEnabled then vc.boostPlayer(plr) end
		else
			vc.selected[plr.UserId] = nil
			vc.clearBoost(plr.UserId)
			syncPlayLoop()
		end
		emitState()
	end

	function vc.stopAll()
		if vc.listenConn then pcall(function() vc.listenConn:Disconnect() end); vc.listenConn = nil end
		if vc.playConn then pcall(function() vc.playConn:Disconnect() end); vc.playConn = nil end
		local uids = {}
		for uid in pairs(vc.boosted) do table.insert(uids, uid) end
		for _, uid in ipairs(uids) do vc.clearBoost(uid) end
		vc.boosterEnabled = false
		_G._nvVcEnabled = false
	end

	return vc
end

local function setupExternalVCOverlay(
	BadgeGui: ScreenGui,
	vc: any,
	makeDraggableFn: (GuiObject, GuiObject, Frame?, (() -> ())?) -> (),
	openMainAndVCHub: () -> (),
	trackConn: (RBXScriptConnection) -> RBXScriptConnection,
	extraTrigger: { Host: GuiObject?, Button: GuiObject?, Icon: ImageLabel?, Dot: Frame? }?
)
	local TriggerBtn = Instance.new("TextButton")
	TriggerBtn.Name = "VCQuickTrigger"
	TriggerBtn.Size = UDim2.new(0, 146, 0, 38)
	TriggerBtn.Position = UDim2.new(0, 22, 1, -24)
	TriggerBtn.AnchorPoint = Vector2.new(0, 1)
	TriggerBtn.BackgroundColor3 = THEME.MainBackground
	TriggerBtn.BorderSizePixel = 0
	TriggerBtn.AutoButtonColor = false
	TriggerBtn.Text = ""
	TriggerBtn.Active = true
	TriggerBtn.ZIndex = 85
	TriggerBtn.Visible = true
	TriggerBtn.Parent = BadgeGui
	createCorner(TriggerBtn, 10)
	local trigStroke = createStroke(TriggerBtn, THEME.Stroke, 1, 0.15)

	local TrigBadge = Instance.new("Frame")
	TrigBadge.Size = UDim2.new(0, 24, 0, 24)
	TrigBadge.Position = UDim2.new(0, 8, 0.5, 0)
	TrigBadge.AnchorPoint = Vector2.new(0, 0.5)
	TrigBadge.BackgroundColor3 = Color3.fromHex("#1E1E22")
	TrigBadge.BorderSizePixel = 0
	TrigBadge.Active = false
	TrigBadge.ZIndex = 86
	TrigBadge.Parent = TriggerBtn
	createCorner(TrigBadge, 6)

	local TrigIcon = Instance.new("ImageLabel")
	TrigIcon.Size = UDim2.new(0, 14, 0, 14)
	TrigIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	TrigIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	TrigIcon.BackgroundTransparency = 1
	TrigIcon.Image = ASSETS.VoiceChat
	TrigIcon.ImageColor3 = THEME.TextPrimary
	TrigIcon.ScaleType = Enum.ScaleType.Fit
	TrigIcon.Active = false
	TrigIcon.ZIndex = 87
	TrigIcon.Parent = TrigBadge

	local TrigDot = Instance.new("Frame")
	TrigDot.Size = UDim2.new(0, 6, 0, 6)
	TrigDot.Position = UDim2.new(1, -2, 0, 2)
	TrigDot.AnchorPoint = Vector2.new(0.5, 0.5)
	TrigDot.BackgroundColor3 = THEME.TextSecondary
	TrigDot.BorderSizePixel = 0
	TrigDot.Active = false
	TrigDot.ZIndex = 88
	TrigDot.Parent = TrigBadge
	createCorner(TrigDot, 4)

	local TrigLabel = Instance.new("TextLabel")
	TrigLabel.Size = UDim2.new(1, -44, 1, 0)
	TrigLabel.Position = UDim2.new(0, 38, 0, 0)
	TrigLabel.BackgroundTransparency = 1
	TrigLabel.Font = Enum.Font.GothamBold
	TrigLabel.Text = "Voice Chat"
	TrigLabel.TextColor3 = THEME.TextPrimary
	TrigLabel.TextSize = 13
	TrigLabel.TextXAlignment = Enum.TextXAlignment.Left
	TrigLabel.TextTruncate = Enum.TextTruncate.AtEnd
	TrigLabel.Active = false
	TrigLabel.ZIndex = 86
	TrigLabel.Parent = TriggerBtn

	TriggerBtn.MouseEnter:Connect(function()
		tween(TriggerBtn, TWEEN_FAST, { BackgroundColor3 = THEME.CardHover })
		tween(trigStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0 })
	end)
	TriggerBtn.MouseLeave:Connect(function()
		tween(TriggerBtn, TWEEN_FAST, { BackgroundColor3 = THEME.MainBackground })
		tween(trigStroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.15 })
	end)

	-- Compact Standalone Extra VC Panel (Outside Main NightUI Window)
	local ExtraPanel = Instance.new("Frame")
	ExtraPanel.Name = "VCExtraOverlay"
	ExtraPanel.Size = UDim2.new(0, 326, 0, 286)
	ExtraPanel.Position = UDim2.new(0, 22, 1, -70)
	ExtraPanel.AnchorPoint = Vector2.new(0, 1)
	ExtraPanel.BackgroundColor3 = THEME.MainBackground
	ExtraPanel.BorderSizePixel = 0
	ExtraPanel.ClipsDescendants = true
	ExtraPanel.Visible = false
	ExtraPanel.Active = true
	ExtraPanel.ZIndex = 90
	ExtraPanel.Parent = BadgeGui
	createCorner(ExtraPanel, 12)
	createStroke(ExtraPanel, THEME.Stroke, 1, 0.2)

	local ExtraTopBar = Instance.new("Frame")
	ExtraTopBar.Size = UDim2.new(1, 0, 0, 38)
	ExtraTopBar.BackgroundTransparency = 1
	ExtraTopBar.Active = true
	ExtraTopBar.ZIndex = 91
	ExtraTopBar.Parent = ExtraPanel

	local ExtraTitle = Instance.new("TextLabel")
	ExtraTitle.Size = UDim2.new(0, 96, 1, 0)
	ExtraTitle.Position = UDim2.new(0, 14, 0, 0)
	ExtraTitle.BackgroundTransparency = 1
	ExtraTitle.Font = Enum.Font.GothamBold
	ExtraTitle.Text = "Night VC"
	ExtraTitle.TextColor3 = THEME.TextPrimary
	ExtraTitle.TextSize = 14
	ExtraTitle.TextXAlignment = Enum.TextXAlignment.Left
	ExtraTitle.ZIndex = 92
	ExtraTitle.Parent = ExtraTopBar

	local ExtraStatus = Instance.new("TextLabel")
	ExtraStatus.Size = UDim2.new(0, 96, 0, 20)
	ExtraStatus.Position = UDim2.new(0, 90, 0.5, 0)
	ExtraStatus.AnchorPoint = Vector2.new(0, 0.5)
	ExtraStatus.BackgroundColor3 = THEME.CardBackground
	ExtraStatus.Font = Enum.Font.GothamBold
	ExtraStatus.Text = "Idle"
	ExtraStatus.TextColor3 = THEME.TextSecondary
	ExtraStatus.TextSize = 11
	ExtraStatus.ZIndex = 92
	ExtraStatus.Parent = ExtraTopBar
	createCorner(ExtraStatus, 6)
	createStroke(ExtraStatus, THEME.Stroke, 1, 0.25)

	local ExtraClose = Instance.new("TextButton")
	ExtraClose.Size = UDim2.new(0, 24, 0, 24)
	ExtraClose.Position = UDim2.new(1, -10, 0.5, 0)
	ExtraClose.AnchorPoint = Vector2.new(1, 0.5)
	ExtraClose.BackgroundColor3 = Color3.fromHex("#181A1D")
	ExtraClose.BorderSizePixel = 0
	ExtraClose.AutoButtonColor = false
	ExtraClose.Font = Enum.Font.GothamBold
	ExtraClose.Text = "×"
	ExtraClose.TextColor3 = THEME.TextSecondary
	ExtraClose.TextSize = 14
	ExtraClose.ZIndex = 92
	ExtraClose.Parent = ExtraTopBar
	createCorner(ExtraClose, 7)
	createStroke(ExtraClose, Color3.fromHex("#282B30"), 1, 0.15)

	local ExtraInner = Instance.new("Frame")
	ExtraInner.Size = UDim2.new(1, -16, 1, -46)
	ExtraInner.Position = UDim2.new(0, 8, 0, 38)
	ExtraInner.BackgroundColor3 = THEME.ContentBase
	ExtraInner.BorderSizePixel = 0
	ExtraInner.ZIndex = 91
	ExtraInner.Parent = ExtraPanel
	createCorner(ExtraInner, 10)
	createStroke(ExtraInner, THEME.Stroke, 1, 0.2)

	local ExtraGrad = Instance.new("UIGradient")
	ExtraGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.ContentGradBottomLeft),
		ColorSequenceKeypoint.new(0.5, THEME.ContentBase),
		ColorSequenceKeypoint.new(1, THEME.ContentGradTopRight),
	})
	ExtraGrad.Rotation = -45
	ExtraGrad.Parent = ExtraInner

	local ExtraPad = Instance.new("Frame")
	ExtraPad.Size = UDim2.new(1, -20, 1, -20)
	ExtraPad.Position = UDim2.new(0, 10, 0, 10)
	ExtraPad.BackgroundTransparency = 1
	ExtraPad.ZIndex = 92
	ExtraPad.Parent = ExtraInner

	local function makeMiniBtn(parent: Instance, size: UDim2, pos: UDim2, text: string)
		local b = Instance.new("TextButton")
		b.Size = size
		b.Position = pos
		b.BackgroundColor3 = THEME.CardBackground
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Font = Enum.Font.GothamBold
		b.Text = text
		b.TextColor3 = THEME.TextPrimary
		b.TextSize = 11
		b.ZIndex = 93
		b.Parent = parent
		createCorner(b, 7)
		local st = createStroke(b, THEME.Stroke, 1, 0.2)
		b.MouseEnter:Connect(function() tween(b, TWEEN_FAST, { BackgroundColor3 = THEME.CardHover }) end)
		b.MouseLeave:Connect(function() tween(b, TWEEN_FAST, { BackgroundColor3 = THEME.CardBackground }) end)
		return b, st
	end

	-- Row 1: V1 / V2
	local V1Btn, V1Stroke = makeMiniBtn(ExtraPad, UDim2.new(0.5, -3, 0, 30), UDim2.new(0, 0, 0, 0), "Bypass V1")
	local V2Btn, V2Stroke = makeMiniBtn(ExtraPad, UDim2.new(0.5, -3, 0, 30), UDim2.new(0.5, 3, 0, 0), "Bypass V2")

	-- Row 2: Execute Bypass + Mic Toggle
	local ExecBtn, ExecStroke = makeMiniBtn(ExtraPad, UDim2.new(0.62, -3, 0, 32), UDim2.new(0, 0, 0, 38), "Execute Bypass")
	local MicBtn, MicStroke = makeMiniBtn(ExtraPad, UDim2.new(0.38, -3, 0, 32), UDim2.new(0.62, 3, 0, 38), "Mic: Live")

	-- Row 3: Mute All + Unmute All + Booster Toggle
	local MuteAllBtn = makeMiniBtn(ExtraPad, UDim2.new(0.333, -4, 0, 30), UDim2.new(0, 0, 0, 78), "Mute All")
	local UnmuteAllBtn = makeMiniBtn(ExtraPad, UDim2.new(0.333, -4, 0, 30), UDim2.new(0.333, 2, 0, 78), "Unmute All")
	local BoostBtn, BoostStroke = makeMiniBtn(ExtraPad, UDim2.new(0.334, -2, 0, 30), UDim2.new(0.666, 4, 0, 78), "Booster: OFF")

	-- Row 4: Gain Slider Card
	local GainCard = Instance.new("Frame")
	GainCard.Size = UDim2.new(1, 0, 0, 56)
	GainCard.Position = UDim2.new(0, 0, 0, 116)
	GainCard.BackgroundColor3 = THEME.CardBackground
	GainCard.BorderSizePixel = 0
	GainCard.ZIndex = 93
	GainCard.Parent = ExtraPad
	createCorner(GainCard, 8)
	createStroke(GainCard, THEME.Stroke, 1, 0.2)

	local GainTitle = Instance.new("TextLabel")
	GainTitle.Size = UDim2.new(1, -76, 0, 18)
	GainTitle.Position = UDim2.new(0, 10, 0, 8)
	GainTitle.BackgroundTransparency = 1
	GainTitle.Font = Enum.Font.GothamBold
	GainTitle.Text = "VC Booster Gain"
	GainTitle.TextColor3 = THEME.TextPrimary
	GainTitle.TextSize = 11
	GainTitle.TextXAlignment = Enum.TextXAlignment.Left
	GainTitle.ZIndex = 94
	GainTitle.Parent = GainCard

	local GainVal = Instance.new("TextLabel")
	GainVal.Size = UDim2.new(0, 52, 0, 20)
	GainVal.Position = UDim2.new(1, -10, 0, 7)
	GainVal.AnchorPoint = Vector2.new(1, 0)
	GainVal.BackgroundColor3 = THEME.CardInner
	GainVal.Font = Enum.Font.GothamBold
	GainVal.Text = string.format("%.1fx", vc.gain)
	GainVal.TextColor3 = THEME.TextPrimary
	GainVal.TextSize = 11
	GainVal.ZIndex = 94
	GainVal.Parent = GainCard
	createCorner(GainVal, 5)

	local GainTrack = Instance.new("TextButton")
	GainTrack.Size = UDim2.new(1, -20, 0, 6)
	GainTrack.Position = UDim2.new(0, 10, 1, -12)
	GainTrack.AnchorPoint = Vector2.new(0, 1)
	GainTrack.BackgroundColor3 = THEME.CardInner
	GainTrack.BorderSizePixel = 0
	GainTrack.AutoButtonColor = false
	GainTrack.Text = ""
	GainTrack.ZIndex = 94
	GainTrack.Parent = GainCard
	createCorner(GainTrack, 3)

	local GainFill = Instance.new("Frame")
	GainFill.Size = UDim2.new((vc.gain - 0.1) / 2.9, 0, 1, 0)
	GainFill.BackgroundColor3 = THEME.Accent
	GainFill.BorderSizePixel = 0
	GainFill.ZIndex = 95
	GainFill.Parent = GainTrack
	createCorner(GainFill, 3)

	local GainKnob = Instance.new("Frame")
	GainKnob.Size = UDim2.new(0, 12, 0, 12)
	GainKnob.Position = UDim2.new((vc.gain - 0.1) / 2.9, 0, 0.5, 0)
	GainKnob.AnchorPoint = Vector2.new(0.5, 0.5)
	GainKnob.BackgroundColor3 = THEME.Accent
	GainKnob.BorderSizePixel = 0
	GainKnob.ZIndex = 96
	GainKnob.Parent = GainTrack
	createCorner(GainKnob, 6)

	do
		local sliding = false
		local function applyX(px: number)
			local w = math.max(1, GainTrack.AbsoluteSize.X)
			local pct = math.clamp((px - GainTrack.AbsolutePosition.X) / w, 0, 1)
			vc.setGain(math.clamp(math.round((0.1 + pct * 2.9) * 10) / 10, 0.1, 3))
		end
		GainTrack.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
				sliding = true
				applyX(inp.Position.X)
			end
		end)
		trackConn(UserInputService.InputChanged:Connect(function(inp)
			if sliding and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
				applyX(inp.Position.X)
			end
		end))
		trackConn(UserInputService.InputEnded:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
				sliding = false
			end
		end))
	end

	-- Row 5: Open Full Player List / Hub
	local FullHubBtn = makeMiniBtn(ExtraPad, UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 0, 182), "Open Full VC & Player Booster List  ›")

	local extraOpen = false
	local currentAnchor: GuiObject? = nil
	local function setExtraOpen(want: boolean, anchorGui: GuiObject?, preferBelow: boolean?)
		extraOpen = want == true
		ExtraPanel.Visible = extraOpen
		if extraOpen then
			local targetAnchor = anchorGui or TriggerBtn
			currentAnchor = targetAnchor
			local cam = workspace.CurrentCamera
			local vp = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
			if vp.X < 100 or vp.Y < 100 then
				vp = Vector2.new(1280, 720)
			end
			local aPos = targetAnchor.AbsolutePosition
			local aSize = targetAnchor.AbsoluteSize
			local pw, ph = 326, 286
			local px = math.clamp(aPos.X, 12, math.max(12, vp.X - pw - 12))
			local py
			if preferBelow then
				py = aPos.Y + aSize.Y + 8
				if py + ph > vp.Y - 12 then
					py = math.max(12, aPos.Y - ph - 8)
				end
			else
				py = aPos.Y - ph - 8
				if py < 12 then
					py = math.min(math.max(12, vp.Y - ph - 12), aPos.Y + aSize.Y + 8)
				end
			end
			ExtraPanel.AnchorPoint = Vector2.new(0, 0)
			ExtraPanel.Position = UDim2.new(0, math.round(px), 0, math.round(py))
		else
			currentAnchor = nil
		end
	end

	local function toggleExtraFrom(anchorGui: GuiObject, preferBelow: boolean)
		if extraOpen and currentAnchor == anchorGui then
			setExtraOpen(false, nil, nil)
		else
			setExtraOpen(true, anchorGui, preferBelow)
		end
	end

	makeDraggableFn(TriggerBtn, TriggerBtn, nil, function()
		toggleExtraFrom(TriggerBtn, false)
	end)
	if extraTrigger and extraTrigger.Button and extraTrigger.Host then
		makeDraggableFn(extraTrigger.Button, extraTrigger.Host, nil, function()
			toggleExtraFrom(extraTrigger.Host, true)
		end)
	end
	makeDraggableFn(ExtraTopBar, ExtraPanel, nil, nil)
	ExtraClose.MouseButton1Click:Connect(function()
		setExtraOpen(false, nil, nil)
	end)

	V1Btn.MouseButton1Click:Connect(function() vc.setVersion(1) end)
	V2Btn.MouseButton1Click:Connect(function() vc.setVersion(2) end)
	ExecBtn.MouseButton1Click:Connect(function() vc.executeBypass() end)
	MicBtn.MouseButton1Click:Connect(function()
		if not vc.executed then
			NightSystem:Notify({ Title = "VC Bypasser", Content = "Bitte zuerst Execute Bypass ausführen.", Duration = 3 })
			return
		end
		vc.setMicMuted(not vc.muted)
	end)
	MuteAllBtn.MouseButton1Click:Connect(function() vc.muteAll(true) end)
	UnmuteAllBtn.MouseButton1Click:Connect(function() vc.muteAll(false) end)
	BoostBtn.MouseButton1Click:Connect(function() vc.setBoosterEnabled(not vc.boosterEnabled) end)
	FullHubBtn.MouseButton1Click:Connect(function()
		setExtraOpen(false, nil, nil)
		openMainAndVCHub()
	end)

	local function refreshOverlay()
		local v1 = vc.version == 1
		V1Btn.TextColor3 = if v1 then THEME.Accent else THEME.TextSecondary
		V1Stroke.Color = if v1 then THEME.Accent else THEME.Stroke
		V2Btn.TextColor3 = if not v1 then THEME.Accent else THEME.TextSecondary
		V2Stroke.Color = if not v1 then THEME.Accent else THEME.Stroke

		if vc.running then
			ExtraStatus.Text = "Bypassing..."
			ExtraStatus.TextColor3 = Color3.fromRGB(255, 190, 60)
			ExecBtn.Text = "Bypassing..."
			TrigDot.BackgroundColor3 = Color3.fromRGB(255, 190, 60)
		elseif vc.executed then
			ExtraStatus.Text = "Bypassed " .. string.upper(tostring(vc.mode or "v1"))
			ExtraStatus.TextColor3 = Color3.fromRGB(60, 220, 130)
			ExecBtn.Text = "Bypassed"
			ExecStroke.Color = Color3.fromRGB(60, 220, 130)
			TrigDot.BackgroundColor3 = if vc.muted then Color3.fromRGB(255, 96, 96) else Color3.fromRGB(60, 220, 130)
		else
			ExtraStatus.Text = "Idle"
			ExtraStatus.TextColor3 = THEME.TextSecondary
			ExecBtn.Text = "Execute Bypass"
			ExecStroke.Color = THEME.Stroke
			TrigDot.BackgroundColor3 = THEME.TextSecondary
		end

		TrigIcon.Image = if vc.muted then ASSETS.VoiceChatMuted else ASSETS.VoiceChat
		if extraTrigger then
			if extraTrigger.Icon then
				extraTrigger.Icon.Image = if vc.muted then ASSETS.VoiceChatMuted else ASSETS.VoiceChat
				extraTrigger.Icon.ImageColor3 = if vc.muted then Color3.fromRGB(255, 96, 96) elseif vc.executed then Color3.fromRGB(60, 220, 130) else THEME.TextPrimary
			end
			if extraTrigger.Dot then
				extraTrigger.Dot.BackgroundColor3 = TrigDot.BackgroundColor3
			end
		end
		MicBtn.Text = if vc.muted then "Mic: Muted" else "Mic: Live"
		MicBtn.TextColor3 = if vc.muted then Color3.fromRGB(255, 96, 96) else THEME.TextPrimary
		MicStroke.Color = if vc.muted then Color3.fromRGB(255, 96, 96) else THEME.Stroke

		BoostBtn.Text = if vc.boosterEnabled then "Booster: ON" else "Booster: OFF"
		BoostBtn.TextColor3 = if vc.boosterEnabled then Color3.fromRGB(60, 220, 130) else THEME.TextPrimary
		BoostStroke.Color = if vc.boosterEnabled then Color3.fromRGB(60, 220, 130) else THEME.Stroke

		local pct = math.clamp((vc.gain - 0.1) / 2.9, 0, 1)
		GainFill.Size = UDim2.new(pct, 0, 1, 0)
		GainKnob.Position = UDim2.new(pct, 0, 0.5, 0)
		GainVal.Text = string.format("%.1fx", vc.gain)
	end

	vc.onStateChanged(refreshOverlay)
	refreshOverlay()
	return TriggerBtn, ExtraPanel
end

local function setupVoiceChatHub(ContentFrame: Frame, HomePage: Frame, vc: any, getActiveTabIndicatorUpdater: () -> ((boolean?) -> ()), trackConn: (RBXScriptConnection) -> RBXScriptConnection)
	local VCHubPage = Instance.new("Frame")
	VCHubPage.Name = "VCHub_Page"
	VCHubPage.Size = UDim2.new(1, 0, 1, 0)
	VCHubPage.BackgroundTransparency = 1
	VCHubPage.Visible = false
	VCHubPage.Parent = ContentFrame
	createPadding(VCHubPage, 24, 24, 24, 24)

	local HeaderTitle = Instance.new("TextLabel")
	HeaderTitle.Size = UDim2.new(1, -140, 0, 20)
	HeaderTitle.BackgroundTransparency = 1
	HeaderTitle.Font = Enum.Font.GothamBold
	HeaderTitle.Text = "Voice Chat"
	HeaderTitle.TextColor3 = THEME.TextHeaderTitle
	HeaderTitle.TextSize = 18
	HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
	HeaderTitle.Parent = VCHubPage

	local HeaderSub = Instance.new("TextLabel")
	HeaderSub.Size = UDim2.new(1, -140, 0, 16)
	HeaderSub.Position = UDim2.new(0, 0, 0, 22)
	HeaderSub.BackgroundTransparency = 1
	HeaderSub.Font = Enum.Font.GothamMedium
	HeaderSub.Text = "VC Bypasser V1/V2 • Mic Controls • Mute/Listen • VC Booster"
	HeaderSub.TextColor3 = THEME.TextHeaderSub
	HeaderSub.TextSize = 13
	HeaderSub.TextXAlignment = Enum.TextXAlignment.Left
	HeaderSub.Parent = VCHubPage

	local BackBtn = Instance.new("TextButton")
	BackBtn.Name = "VCBackToHomeButton"
	BackBtn.Size = UDim2.new(0, 118, 0, 32)
	BackBtn.Position = UDim2.new(1, 0, 0, 2)
	BackBtn.AnchorPoint = Vector2.new(1, 0)
	BackBtn.BackgroundColor3 = Color3.fromHex("#181B1E")
	BackBtn.BorderSizePixel = 0
	BackBtn.AutoButtonColor = false
	BackBtn.Font = Enum.Font.GothamBold
	BackBtn.Text = "‹  Back to Home"
	BackBtn.TextColor3 = THEME.TextPrimary
	BackBtn.TextSize = 12
	BackBtn.Parent = VCHubPage
	createCorner(BackBtn, 8)
	local backStroke = createStroke(BackBtn, Color3.fromHex("#2A2E33"), 1, 0.1)
	BackBtn.MouseEnter:Connect(function()
		tween(BackBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#22262B") })
		tween(backStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0 })
	end)
	BackBtn.MouseLeave:Connect(function()
		tween(BackBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#181B1E") })
		tween(backStroke, TWEEN_FAST, { Color = Color3.fromHex("#2A2E33"), Transparency = 0.1 })
	end)
	BackBtn.MouseButton1Click:Connect(function()
		VCHubPage.Visible = false
		HomePage.Visible = true
		HomePage.Position = UDim2.new(0, 0, 0, 8)
		tween(HomePage, TWEEN_MEDIUM, { Position = UDim2.new(0, 0, 0, 0) })
		local updateInd = getActiveTabIndicatorUpdater()
		if updateInd then updateInd(true) end
	end)

	local VCScroll = Instance.new("ScrollingFrame")
	VCScroll.Name = "VCScroll"
	VCScroll.Size = UDim2.new(1, 0, 1, -48)
	VCScroll.Position = UDim2.new(0, 0, 0, 48)
	VCScroll.BackgroundTransparency = 1
	VCScroll.BorderSizePixel = 0
	VCScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	VCScroll.ScrollBarThickness = 3
	VCScroll.ScrollBarImageColor3 = THEME.Accent
	VCScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	VCScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	VCScroll.Parent = VCHubPage

	local VCInner = Instance.new("Frame")
	VCInner.Name = "VCInner"
	VCInner.Size = UDim2.new(1, -10, 0, 0)
	VCInner.Position = UDim2.new(0, 0, 0, 0)
	VCInner.AutomaticSize = Enum.AutomaticSize.Y
	VCInner.BackgroundTransparency = 1
	VCInner.Parent = VCScroll
	createPadding(VCInner, 2, 12, 2, 2)

	local VCList = Instance.new("UIListLayout")
	VCList.SortOrder = Enum.SortOrder.LayoutOrder
	VCList.Padding = UDim.new(0, 8)
	VCList.Parent = VCInner

	local nextOrder = 0
	local function ord(): number
		nextOrder += 1
		return nextOrder
	end

	local function addSectionHeader(title: string)
		local sec = Instance.new("Frame")
		sec.Size = UDim2.new(1, 0, 0, 22)
		sec.BackgroundTransparency = 1
		sec.LayoutOrder = ord()
		sec.Parent = VCInner
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBold
		lbl.Text = string.upper(title)
		lbl.TextColor3 = THEME.TextSecondary
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = sec
	end

	local function makeBtn(parent: Instance, size: UDim2, pos: UDim2, text: string)
		local b = Instance.new("TextButton")
		b.Size = size
		b.Position = pos
		b.BackgroundColor3 = THEME.CardInner
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Font = Enum.Font.GothamBold
		b.Text = text
		b.TextColor3 = THEME.TextPrimary
		b.TextSize = 12
		b.Parent = parent
		createCorner(b, 6)
		local st = createStroke(b, THEME.Stroke, 1, 0.2)
		b.MouseEnter:Connect(function() tween(b, TWEEN_FAST, { BackgroundColor3 = THEME.CardHover }) end)
		b.MouseLeave:Connect(function() tween(b, TWEEN_FAST, { BackgroundColor3 = THEME.CardInner }) end)
		return b, st
	end

	-- 1. BYPASSER SECTION
	addSectionHeader("Voice Chat Bypasser")

	local BypassCard = Instance.new("Frame")
	BypassCard.Size = UDim2.new(1, 0, 0, 114)
	BypassCard.BackgroundColor3 = THEME.CardBackground
	BypassCard.BorderSizePixel = 0
	BypassCard.LayoutOrder = ord()
	BypassCard.Parent = VCInner
	createCorner(BypassCard, 8)
	createStroke(BypassCard, THEME.Stroke, 1, 0.2)

	local VerRow = Instance.new("Frame")
	VerRow.Size = UDim2.new(1, -24, 0, 32)
	VerRow.Position = UDim2.new(0, 12, 0, 12)
	VerRow.BackgroundTransparency = 1
	VerRow.Parent = BypassCard

	local V1Btn, V1Stroke = makeBtn(VerRow, UDim2.new(0.5, -4, 1, 0), UDim2.new(0, 0, 0, 0), "Bypass V1 (Standard)")
	local V2Btn, V2Stroke = makeBtn(VerRow, UDim2.new(0.5, -4, 1, 0), UDim2.new(0.5, 4, 0, 0), "Bypass V2 (Overlay)")

	local ActionRow = Instance.new("Frame")
	ActionRow.Size = UDim2.new(1, -24, 0, 34)
	ActionRow.Position = UDim2.new(0, 12, 0, 52)
	ActionRow.BackgroundTransparency = 1
	ActionRow.Parent = BypassCard

	local ExecBtn, ExecStroke = makeBtn(ActionRow, UDim2.new(0.65, -4, 1, 0), UDim2.new(0, 0, 0, 0), "Execute Bypass")
	local MicBtn, MicStroke = makeBtn(ActionRow, UDim2.new(0.35, -4, 1, 0), UDim2.new(0.65, 4, 0, 0), "Mic: Live")

	local NoteLbl = Instance.new("TextLabel")
	NoteLbl.Size = UDim2.new(1, -24, 0, 16)
	NoteLbl.Position = UDim2.new(0, 12, 0, 92)
	NoteLbl.BackgroundTransparency = 1
	NoteLbl.Font = Enum.Font.GothamMedium
	NoteLbl.Text = "V1: Not supported on Xeno/Solara  |  Status: Idle"
	NoteLbl.TextColor3 = THEME.TextSecondary
	NoteLbl.TextSize = 11
	NoteLbl.TextXAlignment = Enum.TextXAlignment.Left
	NoteLbl.Parent = BypassCard

	V1Btn.MouseButton1Click:Connect(function() vc.setVersion(1) end)
	V2Btn.MouseButton1Click:Connect(function() vc.setVersion(2) end)
	ExecBtn.MouseButton1Click:Connect(function() vc.executeBypass() end)
	MicBtn.MouseButton1Click:Connect(function()
		if not vc.executed then
			NightSystem:Notify({ Title = "VC Bypasser", Content = "Bitte zuerst Execute Bypass ausführen.", Duration = 3 })
			return
		end
		vc.setMicMuted(not vc.muted)
	end)

	-- 2. VOICE CONTROLS & LISTENER
	addSectionHeader("Mute & Listen Controls")

	local CtrlCard = Instance.new("Frame")
	CtrlCard.Size = UDim2.new(1, 0, 0, 118)
	CtrlCard.BackgroundColor3 = THEME.CardBackground
	CtrlCard.BorderSizePixel = 0
	CtrlCard.LayoutOrder = ord()
	CtrlCard.Parent = VCInner
	createCorner(CtrlCard, 8)
	createStroke(CtrlCard, THEME.Stroke, 1, 0.2)

	local GlobalRow = Instance.new("Frame")
	GlobalRow.Size = UDim2.new(1, -24, 0, 32)
	GlobalRow.Position = UDim2.new(0, 12, 0, 10)
	GlobalRow.BackgroundTransparency = 1
	GlobalRow.Parent = CtrlCard

	local MuteAllBtn = makeBtn(GlobalRow, UDim2.new(0.5, -4, 1, 0), UDim2.new(0, 0, 0, 0), "Mute All VC")
	local UnmuteAllBtn = makeBtn(GlobalRow, UDim2.new(0.5, -4, 1, 0), UDim2.new(0.5, 4, 0, 0), "Unmute All VC")
	MuteAllBtn.MouseButton1Click:Connect(function() vc.muteAll(true) end)
	UnmuteAllBtn.MouseButton1Click:Connect(function() vc.muteAll(false) end)

	local TargetInput = Instance.new("TextBox")
	TargetInput.Size = UDim2.new(1, -24, 0, 30)
	TargetInput.Position = UDim2.new(0, 12, 0, 48)
	TargetInput.BackgroundColor3 = THEME.CardInner
	TargetInput.BorderSizePixel = 0
	TargetInput.Font = Enum.Font.GothamMedium
	TargetInput.PlaceholderText = "Zielspieler eingeben (Name, all, others)..."
	TargetInput.PlaceholderColor3 = THEME.TextSecondary
	TargetInput.Text = ""
	TargetInput.TextColor3 = THEME.TextPrimary
	TargetInput.TextSize = 12
	TargetInput.TextXAlignment = Enum.TextXAlignment.Left
	TargetInput.ClearTextOnFocus = false
	TargetInput.Parent = CtrlCard
	createCorner(TargetInput, 6)
	createPadding(TargetInput, 0, 0, 10, 10)
	createStroke(TargetInput, THEME.Stroke, 1, 0.2)

	local TargetRow = Instance.new("Frame")
	TargetRow.Size = UDim2.new(1, -24, 0, 28)
	TargetRow.Position = UDim2.new(0, 12, 0, 84)
	TargetRow.BackgroundTransparency = 1
	TargetRow.Parent = CtrlCard

	local MutePlrBtn = makeBtn(TargetRow, UDim2.new(0.25, -4, 1, 0), UDim2.new(0, 0, 0, 0), "Mute")
	local UnmutePlrBtn = makeBtn(TargetRow, UDim2.new(0.25, -4, 1, 0), UDim2.new(0.25, 2, 0, 0), "Unmute")
	local ListenBtn = makeBtn(TargetRow, UDim2.new(0.25, -4, 1, 0), UDim2.new(0.50, 4, 0, 0), "Listen")
	local UnlistenBtn = makeBtn(TargetRow, UDim2.new(0.25, -2, 1, 0), UDim2.new(0.75, 6, 0, 0), "Unlisten")

	MutePlrBtn.MouseButton1Click:Connect(function() vc.muteTarget(TargetInput.Text, true) end)
	UnmutePlrBtn.MouseButton1Click:Connect(function() vc.muteTarget(TargetInput.Text, false) end)
	ListenBtn.MouseButton1Click:Connect(function() vc.listenTo(TargetInput.Text) end)
	UnlistenBtn.MouseButton1Click:Connect(function() vc.unlisten() end)

	-- 3. VC BOOSTER SECTION
	addSectionHeader("VC Booster (Audio API / Volume)")

	local BoostToggleCard = Instance.new("Frame")
	BoostToggleCard.Size = UDim2.new(1, 0, 0, 44)
	BoostToggleCard.BackgroundColor3 = THEME.CardBackground
	BoostToggleCard.BorderSizePixel = 0
	BoostToggleCard.LayoutOrder = ord()
	BoostToggleCard.Parent = VCInner
	createCorner(BoostToggleCard, 8)
	createStroke(BoostToggleCard, THEME.Stroke, 1, 0.2)

	local BoostTitle = Instance.new("TextLabel")
	BoostTitle.Size = UDim2.new(1, -76, 1, 0)
	BoostTitle.Position = UDim2.new(0, 14, 0, 0)
	BoostTitle.BackgroundTransparency = 1
	BoostTitle.Font = Enum.Font.GothamBold
	BoostTitle.Text = "Enable VC Booster"
	BoostTitle.TextColor3 = THEME.TextPrimary
	BoostTitle.TextSize = 13
	BoostTitle.TextXAlignment = Enum.TextXAlignment.Left
	BoostTitle.Parent = BoostToggleCard

	local SwitchBg = Instance.new("Frame")
	SwitchBg.Size = UDim2.new(0, 40, 0, 20)
	SwitchBg.Position = UDim2.new(1, -14, 0.5, 0)
	SwitchBg.AnchorPoint = Vector2.new(1, 0.5)
	SwitchBg.BackgroundColor3 = THEME.Stroke
	SwitchBg.BorderSizePixel = 0
	SwitchBg.Parent = BoostToggleCard
	createCorner(SwitchBg, 10)
	local SwitchStroke = createStroke(SwitchBg, THEME.StrokeActive, 1, 0.15)

	local SwitchKnob = Instance.new("Frame")
	SwitchKnob.Size = UDim2.new(0, 14, 0, 14)
	SwitchKnob.Position = UDim2.new(0, 3, 0.5, 0)
	SwitchKnob.AnchorPoint = Vector2.new(0, 0.5)
	SwitchKnob.BackgroundColor3 = THEME.TextTabInactive
	SwitchKnob.BorderSizePixel = 0
	SwitchKnob.Parent = SwitchBg
	createCorner(SwitchKnob, 7)

	local BoostHit = Instance.new("TextButton")
	BoostHit.Size = UDim2.new(1, 0, 1, 0)
	BoostHit.BackgroundTransparency = 1
	BoostHit.Text = ""
	BoostHit.Parent = BoostToggleCard
	BoostHit.MouseButton1Click:Connect(function()
		vc.setBoosterEnabled(not vc.boosterEnabled)
	end)

	-- Gain Slider Card
	local SliderCard = Instance.new("Frame")
	SliderCard.Size = UDim2.new(1, 0, 0, 60)
	SliderCard.BackgroundColor3 = THEME.CardBackground
	SliderCard.BorderSizePixel = 0
	SliderCard.LayoutOrder = ord()
	SliderCard.Parent = VCInner
	createCorner(SliderCard, 8)
	createStroke(SliderCard, THEME.Stroke, 1, 0.2)

	local GainLbl = Instance.new("TextLabel")
	GainLbl.Size = UDim2.new(1, -90, 0, 18)
	GainLbl.Position = UDim2.new(0, 14, 0, 10)
	GainLbl.BackgroundTransparency = 1
	GainLbl.Font = Enum.Font.GothamBold
	GainLbl.Text = "Boost Volume Gain"
	GainLbl.TextColor3 = THEME.TextPrimary
	GainLbl.TextSize = 13
	GainLbl.TextXAlignment = Enum.TextXAlignment.Left
	GainLbl.Parent = SliderCard

	local GainValLbl = Instance.new("TextLabel")
	GainValLbl.Size = UDim2.new(0, 64, 0, 22)
	GainValLbl.Position = UDim2.new(1, -14, 0, 8)
	GainValLbl.AnchorPoint = Vector2.new(1, 0)
	GainValLbl.BackgroundColor3 = THEME.CardInner
	GainValLbl.Font = Enum.Font.GothamBold
	GainValLbl.Text = string.format("%.1fx", vc.gain)
	GainValLbl.TextColor3 = THEME.TextPrimary
	GainValLbl.TextSize = 11
	GainValLbl.Parent = SliderCard
	createCorner(GainValLbl, 5)
	createStroke(GainValLbl, THEME.Stroke, 1, 0.2)

	local TrackBtn = Instance.new("TextButton")
	TrackBtn.Size = UDim2.new(1, -28, 0, 6)
	TrackBtn.Position = UDim2.new(0, 14, 1, -14)
	TrackBtn.AnchorPoint = Vector2.new(0, 1)
	TrackBtn.BackgroundColor3 = THEME.CardInner
	TrackBtn.BorderSizePixel = 0
	TrackBtn.AutoButtonColor = false
	TrackBtn.Text = ""
	TrackBtn.Parent = SliderCard
	createCorner(TrackBtn, 3)
	createStroke(TrackBtn, THEME.Stroke, 1, 0.3)

	local FillBar = Instance.new("Frame")
	FillBar.Size = UDim2.new((vc.gain - 0.1) / 2.9, 0, 1, 0)
	FillBar.BackgroundColor3 = THEME.Accent
	FillBar.BorderSizePixel = 0
	FillBar.Parent = TrackBtn
	createCorner(FillBar, 3)

	local SliderKnob = Instance.new("Frame")
	SliderKnob.Size = UDim2.new(0, 12, 0, 12)
	SliderKnob.Position = UDim2.new((vc.gain - 0.1) / 2.9, 0, 0.5, 0)
	SliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
	SliderKnob.BackgroundColor3 = THEME.Accent
	SliderKnob.BorderSizePixel = 0
	SliderKnob.Parent = TrackBtn
	createCorner(SliderKnob, 6)
	createStroke(SliderKnob, THEME.MainBackground, 2, 0)

	do
		local sliding = false
		local function applyX(px: number)
			local w = math.max(1, TrackBtn.AbsoluteSize.X)
			local pct = math.clamp((px - TrackBtn.AbsolutePosition.X) / w, 0, 1)
			local g = math.clamp(math.round((0.1 + pct * 2.9) * 10) / 10, 0.1, 3)
			vc.setGain(g)
		end
		TrackBtn.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
				sliding = true
				applyX(inp.Position.X)
			end
		end)
		trackConn(UserInputService.InputChanged:Connect(function(inp)
			if sliding and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
				applyX(inp.Position.X)
			end
		end))
		trackConn(UserInputService.InputEnded:Connect(function(inp)
			if sliding and (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
				sliding = false
			end
		end))
	end

	-- Search & Player Roster
	local SearchBar = Instance.new("Frame")
	SearchBar.Size = UDim2.new(1, 0, 0, 34)
	SearchBar.BackgroundColor3 = THEME.CardBackground
	SearchBar.BorderSizePixel = 0
	SearchBar.LayoutOrder = ord()
	SearchBar.Parent = VCInner
	createCorner(SearchBar, 8)
	createStroke(SearchBar, THEME.Stroke, 1, 0.2)

	local SearchIcon = Instance.new("ImageLabel")
	SearchIcon.Size = UDim2.new(0, 15, 0, 15)
	SearchIcon.Position = UDim2.new(0, 10, 0.5, 0)
	SearchIcon.AnchorPoint = Vector2.new(0, 0.5)
	SearchIcon.BackgroundTransparency = 1
	SearchIcon.Image = ASSETS.Search
	SearchIcon.ImageColor3 = THEME.TextSecondary
	SearchIcon.Parent = SearchBar

	local SearchBox = Instance.new("TextBox")
	SearchBox.Size = UDim2.new(1, -38, 1, 0)
	SearchBox.Position = UDim2.new(0, 32, 0, 0)
	SearchBox.BackgroundTransparency = 1
	SearchBox.Font = Enum.Font.GothamMedium
	SearchBox.PlaceholderText = "Spieler für VC Booster suchen..."
	SearchBox.PlaceholderColor3 = THEME.TextSecondary
	SearchBox.Text = ""
	SearchBox.TextColor3 = THEME.TextPrimary
	SearchBox.TextSize = 12
	SearchBox.TextXAlignment = Enum.TextXAlignment.Left
	SearchBox.ClearTextOnFocus = false
	SearchBox.Parent = SearchBar

	local RosterHolder = Instance.new("Frame")
	RosterHolder.Size = UDim2.new(1, 0, 0, 0)
	RosterHolder.AutomaticSize = Enum.AutomaticSize.Y
	RosterHolder.BackgroundTransparency = 1
	RosterHolder.LayoutOrder = ord()
	RosterHolder.Parent = VCInner

	local RosterLayout = Instance.new("UIListLayout")
	RosterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	RosterLayout.Padding = UDim.new(0, 6)
	RosterLayout.Parent = RosterHolder

	local playerRows = {} :: { { Frame: Frame, Query: string, Refresh: () -> () } }

	local function filterRoster()
		local q = string.lower(string.gsub(SearchBox.Text or "", "^%s*(.-)%s*$", "%1"))
		for _, r in ipairs(playerRows) do
			r.Frame.Visible = (q == "") or (string.find(r.Query, q, 1, true) ~= nil)
		end
	end

	local function rebuildRoster()
		for _, r in ipairs(playerRows) do
			if r.Frame and r.Frame.Parent then r.Frame:Destroy() end
		end
		table.clear(playerRows)

		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then table.insert(list, p) end
		end
		table.sort(list, function(a, b)
			return string.lower(a.DisplayName or a.Name) < string.lower(b.DisplayName or b.Name)
		end)

		for idx, plr in ipairs(list) do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 46)
			row.BackgroundColor3 = THEME.CardBackground
			row.BorderSizePixel = 0
			row.LayoutOrder = idx
			row.Parent = RosterHolder
			createCorner(row, 8)
			local rStroke = createStroke(row, THEME.Stroke, 1, 0.2)

			local av = Instance.new("ImageLabel")
			av.Size = UDim2.new(0, 30, 0, 30)
			av.Position = UDim2.new(0, 10, 0.5, 0)
			av.AnchorPoint = Vector2.new(0, 0.5)
			av.BackgroundColor3 = THEME.CardInner
			av.BorderSizePixel = 0
			av.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(plr.UserId) .. "&w=48&h=48"
			av.Parent = row
			createCorner(av, 15)

			local dLbl = Instance.new("TextLabel")
			dLbl.Size = UDim2.new(1, -134, 0, 16)
			dLbl.Position = UDim2.new(0, 48, 0, 7)
			dLbl.BackgroundTransparency = 1
			dLbl.Font = Enum.Font.GothamBold
			dLbl.Text = plr.DisplayName or plr.Name
			dLbl.TextColor3 = THEME.TextPrimary
			dLbl.TextSize = 12
			dLbl.TextXAlignment = Enum.TextXAlignment.Left
			dLbl.TextTruncate = Enum.TextTruncate.AtEnd
			dLbl.Parent = row

			local uLbl = Instance.new("TextLabel")
			uLbl.Size = UDim2.new(1, -134, 0, 14)
			uLbl.Position = UDim2.new(0, 48, 0, 24)
			uLbl.BackgroundTransparency = 1
			uLbl.Font = Enum.Font.GothamMedium
			uLbl.Text = "@" .. plr.Name
			uLbl.TextColor3 = THEME.TextSecondary
			uLbl.TextSize = 11
			uLbl.TextXAlignment = Enum.TextXAlignment.Left
			uLbl.TextTruncate = Enum.TextTruncate.AtEnd
			uLbl.Parent = row

			local badge = Instance.new("TextLabel")
			badge.Size = UDim2.new(0, 70, 0, 24)
			badge.Position = UDim2.new(1, -12, 0.5, 0)
			badge.AnchorPoint = Vector2.new(1, 0.5)
			badge.BackgroundColor3 = THEME.CardInner
			badge.Font = Enum.Font.GothamBold
			badge.TextSize = 11
			badge.Parent = row
			createCorner(badge, 6)

			local hit = Instance.new("TextButton")
			hit.Size = UDim2.new(1, 0, 1, 0)
			hit.BackgroundTransparency = 1
			hit.Text = ""
			hit.Parent = row

			local function refreshRow()
				local sel = vc.selected[plr.UserId] == true
				badge.Text = if sel then "Boosted" else "Boost"
				badge.TextColor3 = if sel then Color3.fromRGB(60, 220, 130) else THEME.TextSecondary
				badge.BackgroundColor3 = if sel then Color3.fromHex("#171D1B") else THEME.CardInner
				rStroke.Color = if sel then Color3.fromRGB(60, 220, 130) else THEME.Stroke
			end

			hit.MouseButton1Click:Connect(function()
				vc.setBoostTarget(plr, not (vc.selected[plr.UserId] == true))
			end)
			refreshRow()
			table.insert(playerRows, {
				Frame = row,
				Query = string.lower((plr.DisplayName or "") .. " " .. (plr.Name or "")),
				Refresh = refreshRow,
			})
		end
		filterRoster()
	end

	SearchBox:GetPropertyChangedSignal("Text"):Connect(filterRoster)
	trackConn(Players.PlayerAdded:Connect(function() task.defer(rebuildRoster) end))
	trackConn(Players.PlayerRemoving:Connect(function() task.defer(rebuildRoster) end))
	rebuildRoster()

	local function refreshVCPage()
		local v1 = vc.version == 1
		V1Btn.TextColor3 = if v1 then THEME.Accent else THEME.TextSecondary
		V1Stroke.Color = if v1 then THEME.Accent else THEME.Stroke
		V2Btn.TextColor3 = if not v1 then THEME.Accent else THEME.TextSecondary
		V2Stroke.Color = if not v1 then THEME.Accent else THEME.Stroke

		if vc.running then
			ExecBtn.Text = "BYPASSING..."
			NoteLbl.Text = "Bypass wird ausgeführt..."
		elseif vc.executed then
			ExecBtn.Text = "BYPASSED"
			ExecStroke.Color = Color3.fromRGB(60, 220, 130)
			NoteLbl.Text = "Status: Aktiv (" .. string.upper(tostring(vc.mode or "v1")) .. ")"
		else
			ExecBtn.Text = "Execute Bypass"
			ExecStroke.Color = THEME.Stroke
			NoteLbl.Text = if v1 then "V1: Standard Bypass (Xeno/Solara unsupported)" else "V2: CustomVoiceController Overlay"
		end

		MicBtn.Text = if vc.muted then "Mic: Muted" else "Mic: Live"
		MicBtn.TextColor3 = if vc.muted then Color3.fromRGB(255, 96, 96) else THEME.TextPrimary
		MicStroke.Color = if vc.muted then Color3.fromRGB(255, 96, 96) else THEME.Stroke

		tween(SwitchBg, TWEEN_FAST, { BackgroundColor3 = if vc.boosterEnabled then Color3.fromRGB(60, 220, 130) else THEME.Stroke })
		tween(SwitchStroke, TWEEN_FAST, { Color = if vc.boosterEnabled then Color3.fromRGB(60, 220, 130) else THEME.StrokeActive })
		tween(SwitchKnob, TWEEN_FAST, {
			Position = if vc.boosterEnabled then UDim2.new(1, -17, 0.5, 0) else UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = if vc.boosterEnabled then THEME.MainBackground else THEME.TextTabInactive,
		})

		local pct = math.clamp((vc.gain - 0.1) / 2.9, 0, 1)
		FillBar.Size = UDim2.new(pct, 0, 1, 0)
		SliderKnob.Position = UDim2.new(pct, 0, 0.5, 0)
		GainValLbl.Text = string.format("%.1fx", vc.gain)

		for _, r in ipairs(playerRows) do
			r.Refresh()
		end
	end

	vc.onStateChanged(refreshVCPage)
	refreshVCPage()

	return VCHubPage
end


local function setupProfileAndStats(HomePage: Frame, selectedPlatform: string)
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
	ProfileTextContainer.Size = UDim2.new(1, -226, 0, 48)
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
	LargeUsername.TextColor3 = THEME.TextSecondary
	LargeUsername.TextSize = 14
	LargeUsername.TextXAlignment = Enum.TextXAlignment.Left
	LargeUsername.TextTruncate = Enum.TextTruncate.AtEnd
	LargeUsername.Parent = ProfileTextContainer

	local InfoTextLabel = Instance.new("TextLabel")
	InfoTextLabel.Name = "InfoTextLabel"
	InfoTextLabel.Size = UDim2.new(1, 0, 0, 18)
	InfoTextLabel.Position = UDim2.new(0, 0, 0, 128)
	InfoTextLabel.BackgroundTransparency = 1
	InfoTextLabel.Font = Enum.Font.GothamMedium
	InfoTextLabel.Text = "Night System Scripts in all free"
	InfoTextLabel.TextColor3 = THEME.TextSecondary
	InfoTextLabel.TextSize = 13
	InfoTextLabel.TextXAlignment = Enum.TextXAlignment.Left
	InfoTextLabel.Parent = HomePage

	local StatsContainer = Instance.new("Frame")
	StatsContainer.Name = "StatsContainer"
	StatsContainer.Size = UDim2.new(0.86, 0, 1, -188)
	StatsContainer.Position = UDim2.new(0, 0, 0, 152)
	StatsContainer.BackgroundColor3 = THEME.CardBackground
	StatsContainer.BorderSizePixel = 0
	StatsContainer.ClipsDescendants = true
	StatsContainer.Parent = HomePage
	createCorner(StatsContainer, 8)
	createStroke(StatsContainer, THEME.Stroke, 1, 0.2)

	local statsSizeLimit = Instance.new("UISizeConstraint")
	statsSizeLimit.MinSize = Vector2.new(260, 174)
	statsSizeLimit.MaxSize = Vector2.new(860, 460)
	statsSizeLimit.Parent = StatsContainer

	local statRowCount = 0
	local function addStatRow(labelText: string, initValue: string, labelW: number?): (Frame, TextLabel)
		local idx = statRowCount
		if idx > 0 then
			local div = Instance.new("Frame")
			div.Size = UDim2.new(1, -20, 0, 1)
			div.Position = UDim2.new(0, 10, idx / 6, 0)
			div.BackgroundColor3 = THEME.Stroke
			div.BackgroundTransparency = 0.25
			div.BorderSizePixel = 0
			div.Parent = StatsContainer
		end
		statRowCount += 1

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -20, 1 / 6, -4)
		row.Position = UDim2.new(0, 10, idx / 6, 2)
		row.BackgroundTransparency = 1
		row.Parent = StatsContainer

		local lw = labelW or 98
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0, lw, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamMedium
		lbl.Text = labelText
		lbl.TextColor3 = THEME.TextSecondary
		lbl.TextSize = 12
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = row

		local val = Instance.new("TextLabel")
		val.Size = UDim2.new(1, -(lw + 8), 1, 0)
		val.Position = UDim2.new(0, lw + 8, 0, 0)
		val.BackgroundTransparency = 1
		val.Font = Enum.Font.GothamBold
		val.Text = initValue
		val.TextColor3 = THEME.TextPrimary
		val.TextSize = 12
		val.TextXAlignment = Enum.TextXAlignment.Right
		val.TextTruncate = Enum.TextTruncate.AtEnd
		val.Parent = row

		return row, val
	end

	local _, PlatformValue = addStatRow("Platform", selectedPlatform)

	local function getExecutorName(): string
		local ok, name = pcall(function()
			if type(identifyexecutor) == "function" then
				local n, v = identifyexecutor()
				return if v then (tostring(n) .. " " .. tostring(v)) else tostring(n)
			elseif type(getexecutorname) == "function" then
				return tostring(getexecutorname())
			end
			return "Unknown"
		end)
		return if ok and name and name ~= "" then name else "Unknown"
	end
	addStatRow("Executor", getExecutorName())

	local _, PlaceIdValue = addStatRow("PlaceId", tostring(game.PlaceId))

	local localRobloxVersion = "Latest"
	pcall(function()
		if type(version) == "function" then
			localRobloxVersion = tostring(version())
		elseif type(Version) == "function" then
			localRobloxVersion = tostring(Version())
		end
	end)
	local _, RobloxVersionValue = addStatRow("Roblox Version", localRobloxVersion)

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
		local genv = (type(getgenv) == "function" and getgenv()) or _G or fenv
		local reqFn = (type(genv) == "table" and (genv.request or genv.http_request or (type(genv.syn) == "table" and genv.syn.request) or (type(genv.http) == "table" and genv.http.request)))
			or fenv.request
			or fenv.http_request

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
					local verStr = tostring(data.WindowsResponse.version or localRobloxVersion)
					local ts = tonumber(data.WindowsResponse.timestamp)
					if ts and ts > 0 then
						RobloxVersionValue.Text = string.format("%s • %s", verStr, formatRelativeTime(ts))
						fetchedWithDate = true
					elseif data.WindowsDate then
						RobloxVersionValue.Text = string.format("%s • seit %s", verStr, tostring(data.WindowsDate))
						fetchedWithDate = true
					end
				end
			end
		end

		if fetchedWithDate then
			return
		end

		local latestVer = localRobloxVersion
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

		RobloxVersionValue.Text = latestVer .. dateSuffix
	end)

	local localClientVersion = "1.0.0"
	local _, VersionValue = addStatRow("Version", localClientVersion)

	task.spawn(function()
		local vUrl = "https://raw.githubusercontent.com/NightSyste/NightUI/main/Version.json"
		local success, body = pcall(function()
			return game:HttpGet(vUrl)
		end)
		if success and body then
			local parseOk, parsed = pcall(function()
				return HttpService:JSONDecode(body)
			end)
			if parseOk and type(parsed) == "table" and parsed.Version then
				local remoteV = tostring(parsed.Version)
				if remoteV ~= localClientVersion then
					VersionValue.Text = localClientVersion .. " (Update: " .. remoteV .. ")"
					VersionValue.TextColor3 = Color3.fromRGB(255, 170, 0)
				else
					VersionValue.Text = localClientVersion .. " (Latest)"
					VersionValue.TextColor3 = Color3.fromRGB(60, 220, 130)
				end
			end
		end
	end)

	local _, TeamValue = addStatRow("Team", if LocalPlayer.Team then LocalPlayer.Team.Name else "Citizen")

	task.spawn(function()
		local uid = if LocalPlayer.UserId > 0 then LocalPlayer.UserId else 1
		local thumbUrl = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(uid) .. "&w=150&h=150"
		LargeAvatar.Image = thumbUrl
	end)

	task.spawn(function()
		local MarketplaceService = game:GetService("MarketplaceService")
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(game.PlaceId)
		end)
		if ok and info and info.Name then
			PlaceIdValue.Text = tostring(game.PlaceId) .. " - " .. tostring(info.Name)
			return
		end
		PlaceIdValue.Text = "7711635737 - Notruf Hamburg"
	end)

	local function refreshTeam()
		local t = LocalPlayer.Team
		TeamValue.Text = if t and t.Name ~= "" then t.Name else "Citizen"
	end
	refreshTeam()
	trackConnection(LocalPlayer:GetPropertyChangedSignal("Team"):Connect(refreshTeam))

	return ProfileSection, InfoTextLabel, PlatformValue
end

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
	local FloatingBadge = Instance.new("Frame")
	FloatingBadge.Name = "FloatingBadge"
	FloatingBadge.Size = UDim2.new(0, 206, 0, 38)
	FloatingBadge.Position = UDim2.new(0.5, 0, 0, 28)
	FloatingBadge.AnchorPoint = Vector2.new(0.5, 0)
	FloatingBadge.BackgroundColor3 = THEME.MainBackground
	FloatingBadge.BorderSizePixel = 0
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

	local badgeVcUi: { Host: GuiObject?, MainButton: GuiObject?, Button: GuiObject?, Icon: ImageLabel?, Dot: Frame? } = {
		Host = FloatingBadge,
	}

	local BadgeLogo = Instance.new("Frame")
	local BadgeLetter = Instance.new("TextLabel")
	local BadgeRedDot = Instance.new("Frame")
	local BadgeLabel = Instance.new("TextLabel")

	do
		local BadgeMainBtn = Instance.new("TextButton")
		BadgeMainBtn.Name = "FloatingBadgeMainButton"
		BadgeMainBtn.Size = UDim2.new(1, -44, 1, 0)
		BadgeMainBtn.Position = UDim2.new(0, 0, 0, 0)
		BadgeMainBtn.BackgroundTransparency = 1
		BadgeMainBtn.AutoButtonColor = false
		BadgeMainBtn.Text = ""
		BadgeMainBtn.Active = true
		BadgeMainBtn.ZIndex = 81
		BadgeMainBtn.Parent = FloatingBadge
		badgeVcUi.MainButton = BadgeMainBtn

		BadgeLogo.Size = UDim2.new(0, 24, 0, 24)
		BadgeLogo.Position = UDim2.new(0, 8, 0.5, 0)
		BadgeLogo.AnchorPoint = Vector2.new(0, 0.5)
		BadgeLogo.BackgroundColor3 = Color3.fromHex("#1E1E22")
		BadgeLogo.BorderSizePixel = 0
		BadgeLogo.Active = false
		BadgeLogo.ZIndex = 82
		BadgeLogo.Parent = BadgeMainBtn
		createCorner(BadgeLogo, 6)

		BadgeLetter.Size = UDim2.new(1, 0, 1, 0)
		BadgeLetter.BackgroundTransparency = 1
		BadgeLetter.Font = Enum.Font.GothamBold
		BadgeLetter.Text = "N"
		BadgeLetter.TextColor3 = THEME.TextPrimary
		BadgeLetter.TextSize = 13
		BadgeLetter.Active = false
		BadgeLetter.ZIndex = 83
		BadgeLetter.Parent = BadgeLogo

		BadgeRedDot.Size = UDim2.new(0, 5, 0, 5)
		BadgeRedDot.Position = UDim2.new(1, -3, 0, 3)
		BadgeRedDot.AnchorPoint = Vector2.new(0.5, 0.5)
		BadgeRedDot.BackgroundColor3 = THEME.AccentRed
		BadgeRedDot.BorderSizePixel = 0
		BadgeRedDot.Active = false
		BadgeRedDot.ZIndex = 84
		BadgeRedDot.Parent = BadgeLogo
		createCorner(BadgeRedDot, 4)

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
		BadgeLabel.ZIndex = 82
		BadgeLabel.Parent = BadgeMainBtn

		local BadgeDivider = Instance.new("Frame")
		BadgeDivider.Size = UDim2.new(0, 1, 0, 20)
		BadgeDivider.Position = UDim2.new(1, -43, 0.5, 0)
		BadgeDivider.AnchorPoint = Vector2.new(0, 0.5)
		BadgeDivider.BackgroundColor3 = THEME.Stroke
		BadgeDivider.BorderSizePixel = 0
		BadgeDivider.ZIndex = 82
		BadgeDivider.Parent = FloatingBadge

		local BadgeVCBtn = Instance.new("TextButton")
		BadgeVCBtn.Name = "FloatingBadgeVCButton"
		BadgeVCBtn.Size = UDim2.new(0, 32, 0, 28)
		BadgeVCBtn.Position = UDim2.new(1, -5, 0.5, 0)
		BadgeVCBtn.AnchorPoint = Vector2.new(1, 0.5)
		BadgeVCBtn.BackgroundColor3 = Color3.fromHex("#181A1D")
		BadgeVCBtn.BorderSizePixel = 0
		BadgeVCBtn.AutoButtonColor = false
		BadgeVCBtn.Text = ""
		BadgeVCBtn.Active = true
		BadgeVCBtn.ZIndex = 82
		BadgeVCBtn.Parent = FloatingBadge
		createCorner(BadgeVCBtn, 7)
		local badgeVCStroke = createStroke(BadgeVCBtn, THEME.Stroke, 1, 0.25)

		local BadgeVCIcon = Instance.new("ImageLabel")
		BadgeVCIcon.Size = UDim2.new(0, 15, 0, 15)
		BadgeVCIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
		BadgeVCIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		BadgeVCIcon.BackgroundTransparency = 1
		BadgeVCIcon.Image = ASSETS.VoiceChat
		BadgeVCIcon.ImageColor3 = THEME.TextPrimary
		BadgeVCIcon.ScaleType = Enum.ScaleType.Fit
		BadgeVCIcon.Active = false
		BadgeVCIcon.ZIndex = 83
		BadgeVCIcon.Parent = BadgeVCBtn

		local BadgeVCDot = Instance.new("Frame")
		BadgeVCDot.Size = UDim2.new(0, 6, 0, 6)
		BadgeVCDot.Position = UDim2.new(1, -3, 0, 3)
		BadgeVCDot.AnchorPoint = Vector2.new(0.5, 0.5)
		BadgeVCDot.BackgroundColor3 = THEME.TextSecondary
		BadgeVCDot.BorderSizePixel = 0
		BadgeVCDot.Active = false
		BadgeVCDot.ZIndex = 84
		BadgeVCDot.Parent = BadgeVCBtn
		createCorner(BadgeVCDot, 4)

		BadgeVCBtn.MouseEnter:Connect(function()
			tween(BadgeVCBtn, TWEEN_FAST, { BackgroundColor3 = THEME.CardHover })
			tween(badgeVCStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0 })
		end)
		BadgeVCBtn.MouseLeave:Connect(function()
			tween(BadgeVCBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#181A1D") })
			tween(badgeVCStroke, TWEEN_FAST, { Color = THEME.Stroke, Transparency = 0.25 })
		end)

		badgeVcUi.Button = BadgeVCBtn
		badgeVcUi.Icon = BadgeVCIcon
		badgeVcUi.Dot = BadgeVCDot
	end

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
	local mainFrameStroke = createStroke(MainFrame, THEME.Stroke, 1, 0.2)

	-- Dynamic UI Scaling for Mobile & Responsive displays
	local mainFrameScale = Instance.new("UIScale")
	mainFrameScale.Name = "WindowScale"
	mainFrameScale.Scale = 1.0
	mainFrameScale.Parent = MainFrame

	local PlatformValueLabel: TextLabel? = nil
	local openCloseState = { Gen = 0, ScaleTw = nil :: Tween?, NormalW = 740, NormalH = 460 }

	local function getMaxScreenDims(): (number, number)
		local cam = workspace.CurrentCamera
		local vp = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
		if vp.X < 200 or vp.Y < 200 then vp = Vector2.new(1280, 720) end
		return math.clamp(math.round(vp.X - 60), 740, 1480), math.clamp(math.round(vp.Y - 80), 460, 920)
	end

	local function getScaledLayoutForScreen(reqW: number, reqH: number): (number, UDim2)
		if selectedPlatform == "Handy" then
			local cam = workspace.CurrentCamera
			local vp = (cam and cam.ViewportSize) or Vector2.new(800, 600)
			if vp.X <= 100 or vp.Y <= 100 then vp = Vector2.new(800, 600) end
			local sFit = math.clamp(math.min(math.max(300, vp.X - 28) / 740, math.max(200, vp.Y - 28) / 460), 0.50, 0.95)
			return sFit, UDim2.new(0, 740, 0, 460)
		end
		local w = math.max(460, reqW)
		local h = math.max(300, reqH)
		local s = math.clamp(math.min(w / 740, h / 460), 0.65, 2.50)
		return s, UDim2.new(0, math.max(740, math.round(w / s)), 0, math.max(460, math.round(h / s)))
	end

	local function updateMobileScale()
		if not isWindowOpen and MainFrame and MainFrame.Visible then
			return
		end
		local targetW, targetH
		if isMaximized then
			targetW, targetH = getMaxScreenDims()
		else
			targetW, targetH = openCloseState.NormalW, openCloseState.NormalH
		end
		local sc, sz = getScaledLayoutForScreen(targetW, targetH)
		if mainFrameScale then mainFrameScale.Scale = sc end
		if MainFrame then MainFrame.Size = sz end
	end

	trackConnection(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateMobileScale))
	trackConnection(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateMobileScale))

	local function applyPlatform(platformName: string)
		selectedPlatform = if (platformName == "Handy" or platformName == "Mobile") then "Handy" else "PC"
		NightSystem.Platform = selectedPlatform

		if PlatformValueLabel and PlatformValueLabel.Parent then
			PlatformValueLabel.Text = selectedPlatform
		end

		updateMobileScale()
		if selectedPlatform == "Handy" then
			if FloatingBadge then
				FloatingBadge.Visible = false
			end
			if MobileToggleBtn then
				MobileToggleBtn.Visible = true
			end
		else
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
		local dragTouchInput: InputObject? = nil
		local dragStart = Vector2.zero
		local startPos = target.Position
		local totalMoved = 0
		local endConn1: RBXScriptConnection? = nil
		local endConn2: RBXScriptConnection? = nil

		handle.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if endConn1 then endConn1:Disconnect(); endConn1 = nil end
				if endConn2 then endConn2:Disconnect(); endConn2 = nil end
				isDragging = true
				dragTouchInput = if input.UserInputType == Enum.UserInputType.Touch then input else nil
				totalMoved = 0
				dragStart = Vector2.new(input.Position.X, input.Position.Y)
				startPos = target.Position
				if pill then
					tween(pill, TWEEN_FAST, { BackgroundColor3 = THEME.TextPrimary })
				end
				local finished = false
				local function finishDrag()
					if finished then return end
					finished = true
					isDragging = false
					dragTouchInput = nil
					if endConn1 then endConn1:Disconnect(); endConn1 = nil end
					if endConn2 then endConn2:Disconnect(); endConn2 = nil end
					if pill then
						tween(pill, TWEEN_FAST, { BackgroundColor3 = THEME.DragPill })
					end
					if totalMoved < 6 and onClick then
						onClick()
					end
				end
				endConn1 = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						finishDrag()
					end
				end)
				endConn2 = UserInputService.InputEnded:Connect(function(endInp: InputObject)
					if (dragTouchInput and endInp == dragTouchInput) or (not dragTouchInput and endInp.UserInputType == Enum.UserInputType.MouseButton1) then
						finishDrag()
					end
				end)
			end
		end)

		trackConnection(UserInputService.InputChanged:Connect(function(input: InputObject)
			if not isDragging then return end
			local matches = if dragTouchInput
				then (input == dragTouchInput)
				else (input.UserInputType == Enum.UserInputType.MouseMovement)
			if matches then
				local curPos = Vector2.new(input.Position.X, input.Position.Y)
				local delta = curPos - dragStart
				if delta.Magnitude > totalMoved then
					totalMoved = delta.Magnitude
				end
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
	local currentOpenCloseStrokeTween: Tween? = nil

	local function cancelWindowTweens()
		if currentOpenCloseTween then
			pcall(function() currentOpenCloseTween:Cancel() end)
			currentOpenCloseTween = nil
		end
		if currentOpenCloseStrokeTween then
			pcall(function() currentOpenCloseStrokeTween:Cancel() end)
			currentOpenCloseStrokeTween = nil
		end
		if openCloseState.ScaleTw then
			pcall(function() openCloseState.ScaleTw:Cancel() end)
			openCloseState.ScaleTw = nil
		end
	end

	local function openWindow()
		openCloseState.Gen += 1
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

		cancelWindowTweens()

		local tw, th
		if isMaximized then
			tw, th = getMaxScreenDims()
		else
			tw, th = openCloseState.NormalW, openCloseState.NormalH
		end
		local targetScale, targetSize = getScaledLayoutForScreen(tw, th)

		if not MainFrame.Visible then
			mainFrameScale.Scale = targetScale * 0.94
		end
		MainFrame.Size = targetSize
		MainFrame.Visible = true
		MainFrame.BackgroundTransparency = 0
		if mainFrameStroke then
			mainFrameStroke.Transparency = 0.2
		end

		openCloseState.ScaleTw = tween(mainFrameScale, TweenInfo.new(0.20, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Scale = targetScale,
		})
	end

	local function closeWindow()
		openCloseState.Gen += 1
		local myGen = openCloseState.Gen
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

		cancelWindowTweens()

		local cw, ch
		if isMaximized then
			cw, ch = getMaxScreenDims()
		else
			cw, ch = openCloseState.NormalW, openCloseState.NormalH
		end
		local targetScale, targetSize = getScaledLayoutForScreen(cw, ch)
		MainFrame.Size = targetSize

		local tw = tween(MainFrame, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		currentOpenCloseTween = tw
		openCloseState.ScaleTw = tween(mainFrameScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = targetScale * 0.92,
		})
		if mainFrameStroke then
			currentOpenCloseStrokeTween = tween(mainFrameStroke, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
			})
		end
		tw.Completed:Connect(function(playbackState)
			if myGen == openCloseState.Gen and not isWindowOpen and playbackState == Enum.PlaybackState.Completed then
				MainFrame.Visible = false
			end
		end)
		task.delay(0.18, function()
			if myGen == openCloseState.Gen and not isWindowOpen and MainFrame and MainFrame.Parent then
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
	if badgeVcUi and badgeVcUi.MainButton then
		makeDraggable(badgeVcUi.MainButton, FloatingBadge, nil, function()
			toggleWindowState()
		end)
		badgeVcUi.MainButton.MouseEnter:Connect(function()
			tween(FloatingBadge, TWEEN_FAST, { BackgroundColor3 = THEME.CardHover })
		end)
		badgeVcUi.MainButton.MouseLeave:Connect(function()
			tween(FloatingBadge, TWEEN_FAST, { BackgroundColor3 = THEME.MainBackground })
		end)
	end

	CloseBtn.MouseButton1Click:Connect(function()
		closeWindow()
	end)

	MaximizeBtn.MouseButton1Click:Connect(function()
		isMaximized = not isMaximized
		local mw, mh
		if isMaximized then
			mw, mh = getMaxScreenDims()
		else
			mw, mh = openCloseState.NormalW, openCloseState.NormalH
		end
		local sc, sz = getScaledLayoutForScreen(mw, mh)
		cancelWindowTweens()
		currentOpenCloseTween = tween(MainFrame, TWEEN_SMOOTH, { Size = sz })
		openCloseState.ScaleTw = tween(mainFrameScale, TWEEN_SMOOTH, { Scale = sc })
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

			local s = if mainFrameScale and mainFrameScale.Scale > 0 then mainFrameScale.Scale else 1
			-- Also take layout content size if higher
			local layoutH = NavListLayout.AbsoluteContentSize.Y / s
			if layoutH > 0 then
				totalCalculatedHeight = math.max(totalCalculatedHeight, layoutH + BOTTOM_PAD)
			end

			-- 3. Check visible navigation height based on current / standard UI size
			local currentNavHeight = NavContainer.AbsoluteSize.Y / s
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
	trackConnection(mainFrameScale:GetPropertyChangedSignal("Scale"):Connect(updateNavCanvasAndScrollCheck))
	task.defer(updateNavCanvasAndScrollCheck)

	local function bindMouseWheelToNav(element: GuiObject)
		element.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				local scrollDelta = input.Position.Z
				local step = 38
				local s = if mainFrameScale and mainFrameScale.Scale > 0 then mainFrameScale.Scale else 1
				local maxScroll = math.max(0, NavContainer.CanvasSize.Y.Offset - (NavContainer.AbsoluteSize.Y / s))
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

		local resizeEndConn1: RBXScriptConnection? = nil
		local resizeEndConn2: RBXScriptConnection? = nil
		local function endResizeDrag()
			if resizeEndConn1 then resizeEndConn1:Disconnect(); resizeEndConn1 = nil end
			if resizeEndConn2 then resizeEndConn2:Disconnect(); resizeEndConn2 = nil end
			resizeInput = nil
			if isResizing then
				isResizing = false
				if selectedPlatform ~= "Handy" and MainFrame.AbsoluteSize.X >= minWindowSize.X and MainFrame.AbsoluteSize.Y >= minWindowSize.Y then
					openCloseState.NormalW = math.round(MainFrame.AbsoluteSize.X)
					openCloseState.NormalH = math.round(MainFrame.AbsoluteSize.Y)
				end
			end
			tween(ResizeHandle, TWEEN_FAST, { BackgroundTransparency = 0.65 })
			tween(ResizeStroke, TWEEN_FAST, { Color = THEME.TextSecondary, Transparency = 0.55 })
			tween(GripBar1, TWEEN_FAST, { BackgroundTransparency = 0.45 })
			tween(GripBar2, TWEEN_FAST, { BackgroundTransparency = 0.45 })
		end

		ResizeHandle.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if resizeEndConn1 then resizeEndConn1:Disconnect(); resizeEndConn1 = nil end
				if resizeEndConn2 then resizeEndConn2:Disconnect(); resizeEndConn2 = nil end
				cancelWindowTweens()
				isMaximized = false
				isResizing = true
				resizeInput = if input.UserInputType == Enum.UserInputType.Touch then input else nil
				resizeStartMouse = Vector2.new(input.Position.X, input.Position.Y)
				startSize = Vector2.new(MainFrame.AbsoluteSize.X, MainFrame.AbsoluteSize.Y)
				startPos = MainFrame.Position

				resizeEndConn1 = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						endResizeDrag()
					end
				end)
				resizeEndConn2 = UserInputService.InputEnded:Connect(function(endInp: InputObject)
					if (resizeInput and endInp == resizeInput) or (not resizeInput and endInp.UserInputType == Enum.UserInputType.MouseButton1) then
						endResizeDrag()
					end
				end)
			end
		end)

		trackConnection(UserInputService.InputChanged:Connect(function(input: InputObject)
			if not isResizing then return end
			if not ScreenGui or not ScreenGui.Parent or not MainFrame or not MainFrame.Parent then
				endResizeDrag()
				return
			end
			local matches = if resizeInput then (input == resizeInput) else (input.UserInputType == Enum.UserInputType.MouseMovement)
			if matches then
				local cam = workspace.CurrentCamera
				local vp = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
				local dynMaxW = math.max(maxWindowSize.X, vp.X - 24)
				local dynMaxH = math.max(maxWindowSize.Y, vp.Y - 24)

				local currentMouse = Vector2.new(input.Position.X, input.Position.Y)
				local delta = currentMouse - resizeStartMouse

				local newW = math.clamp(startSize.X + delta.X, minWindowSize.X, dynMaxW)
				local newH = math.clamp(startSize.Y + delta.Y, minWindowSize.Y, dynMaxH)
				local actualDeltaX = newW - startSize.X
				local actualDeltaY = newH - startSize.Y

				if selectedPlatform == "Handy" then
					MainFrame.Size = UDim2.new(0, newW, 0, newH)
				else
					local newScale, newLayoutSize = getScaledLayoutForScreen(newW, newH)
					mainFrameScale.Scale = newScale
					MainFrame.Size = newLayoutSize
					openCloseState.NormalW = math.round(newW)
					openCloseState.NormalH = math.round(newH)
				end
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
		if (ScriptsHubPage and ScriptsHubPage.Visible) or (EmotesHubPage and EmotesHubPage.Visible) or (VCHubPage and VCHubPage.Visible) or activeTabName == "" then
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

		local s = if mainFrameScale and mainFrameScale.Scale > 0 then mainFrameScale.Scale else 1
		local btnAbsY = target.Button.AbsolutePosition.Y
		local btnH = target.Button.AbsoluteSize.Y / s
		local navAbsY = NavContainer.AbsolutePosition.Y
		local navH = NavContainer.AbsoluteSize.Y / s
		local sideAbsY = Sidebar.AbsolutePosition.Y

		local relY = ((btnAbsY - sideAbsY) / s) + (btnH - 16) / 2
		local navTopRel = (navAbsY - sideAbsY) / s
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
			local s = if mainFrameScale and mainFrameScale.Scale > 0 then mainFrameScale.Scale else 1
			local btnAbsY = btn.AbsolutePosition.Y
			local navAbsY = NavContainer.AbsolutePosition.Y
			local navH = NavContainer.AbsoluteSize.Y
			local btnH = btn.AbsoluteSize.Y

			if btnAbsY < navAbsY + (4 * s) then
				local diff = ((navAbsY + (4 * s)) - btnAbsY) / s
				local targetY = math.max(0, NavContainer.CanvasPosition.Y - diff)
				tween(NavContainer, TWEEN_FAST, { CanvasPosition = Vector2.new(0, targetY) })
			elseif (btnAbsY + btnH) > (navAbsY + navH - (4 * s)) then
				local diff = ((btnAbsY + btnH) - (navAbsY + navH - (4 * s))) / s
				local targetY = NavContainer.CanvasPosition.Y + diff
				tween(NavContainer, TWEEN_FAST, { CanvasPosition = Vector2.new(0, targetY) })
			end
			updateActiveIndicator(false)
		end)
	end

	NavContainer:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if updateActiveIndicator then updateActiveIndicator(true) end
	end)
	trackConnection(mainFrameScale:GetPropertyChangedSignal("Scale"):Connect(function()
		if not ScreenGui or not ScreenGui.Parent then return end
		if updateActiveIndicator then updateActiveIndicator(true) end
	end))

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
	local EmotesHubPage: Frame? = nil
	local VCHubPage: Frame? = nil
	local stopAllEmotes: (() -> ())? = nil
	local HubScroll: ScrollingFrame? = nil
	local EmptyHubPlaceholder: Frame? = nil
	local hubSearchEntries: { { Card: Frame, Query: string } } = {}
	local InfoTextLabel: TextLabel? = nil

	local function switchSidebarTab(tabName: string, instant: boolean?)
		if ScriptsHubPage and ScriptsHubPage.Visible then
			ScriptsHubPage.Visible = false
			if activeTabName == tabName and SidebarTabs[tabName] then
				SidebarTabs[tabName].Page.Visible = true
				updateActiveIndicator(instant)
				return
			end
		end
		if EmotesHubPage and EmotesHubPage.Visible then
			EmotesHubPage.Visible = false
			if activeTabName == tabName and SidebarTabs[tabName] then
				SidebarTabs[tabName].Page.Visible = true
				updateActiveIndicator(instant)
				return
			end
		end
		if VCHubPage and VCHubPage.Visible then
			VCHubPage.Visible = false
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

	-- Top-Right "Free Emotes" Button in Home Tab (Directly below All Scripts button)
	local FreeEmotesBtn = Instance.new("TextButton")
	FreeEmotesBtn.Name = "FreeEmotesButton"
	FreeEmotesBtn.Size = UDim2.new(0, 128, 0, 34)
	FreeEmotesBtn.Position = UDim2.new(1, 0, 0, 42)
	FreeEmotesBtn.AnchorPoint = Vector2.new(1, 0)
	FreeEmotesBtn.BackgroundColor3 = Color3.fromHex("#181B1E")
	FreeEmotesBtn.BorderSizePixel = 0
	FreeEmotesBtn.AutoButtonColor = false
	FreeEmotesBtn.Text = ""
	FreeEmotesBtn.Parent = HomePage
	createCorner(FreeEmotesBtn, 8)
	local FreeEmotesStroke = createStroke(FreeEmotesBtn, Color3.fromHex("#2A2E33"), 1, 0.1)

	local FreeEmotesIcon = Instance.new("ImageLabel")
	FreeEmotesIcon.Size = UDim2.new(0, 14, 0, 14)
	FreeEmotesIcon.Position = UDim2.new(0, 11, 0.5, 0)
	FreeEmotesIcon.AnchorPoint = Vector2.new(0, 0.5)
	FreeEmotesIcon.BackgroundTransparency = 1
	FreeEmotesIcon.Image = ASSETS.Users
	FreeEmotesIcon.ImageColor3 = THEME.Accent
	FreeEmotesIcon.Parent = FreeEmotesBtn

	local FreeEmotesLabel = Instance.new("TextLabel")
	FreeEmotesLabel.Size = UDim2.new(1, -54, 1, 0)
	FreeEmotesLabel.Position = UDim2.new(0, 30, 0, 0)
	FreeEmotesLabel.BackgroundTransparency = 1
	FreeEmotesLabel.Font = Enum.Font.GothamBold
	FreeEmotesLabel.Text = "Free Emotes"
	FreeEmotesLabel.TextColor3 = THEME.TextPrimary
	FreeEmotesLabel.TextSize = 12
	FreeEmotesLabel.TextXAlignment = Enum.TextXAlignment.Left
	FreeEmotesLabel.Parent = FreeEmotesBtn

	local FreeEmotesArrow = Instance.new("ImageLabel")
	FreeEmotesArrow.Size = UDim2.new(0, 14, 0, 14)
	FreeEmotesArrow.Position = UDim2.new(1, -10, 0.5, 0)
	FreeEmotesArrow.AnchorPoint = Vector2.new(1, 0.5)
	FreeEmotesArrow.BackgroundTransparency = 1
	FreeEmotesArrow.Image = ASSETS.ChevronRight
	FreeEmotesArrow.ImageColor3 = THEME.TextSecondary
	FreeEmotesArrow.Parent = FreeEmotesBtn

	FreeEmotesBtn.MouseEnter:Connect(function()
		tween(FreeEmotesBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#22262B") })
		tween(FreeEmotesStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0 })
		tween(FreeEmotesArrow, TWEEN_FAST, { ImageColor3 = THEME.Accent, Position = UDim2.new(1, -8, 0.5, 0) })
	end)
	FreeEmotesBtn.MouseLeave:Connect(function()
		tween(FreeEmotesBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#181B1E") })
		tween(FreeEmotesStroke, TWEEN_FAST, { Color = Color3.fromHex("#2A2E33"), Transparency = 0.1 })
		tween(FreeEmotesArrow, TWEEN_FAST, { ImageColor3 = THEME.TextSecondary, Position = UDim2.new(1, -10, 0.5, 0) })
	end)

	-- Initialize Modular Sub-Views (Scripts Hub, Emotes Hub, Profile & Stats)
	local _sHub, _hScroll, _ePlaceholder, _hEntries = setupScriptsHub(ContentFrame, HomePage, function()
		return updateActiveIndicator
	end)
	ScriptsHubPage = _sHub
	HubScroll = _hScroll
	EmptyHubPlaceholder = _ePlaceholder
	hubSearchEntries = _hEntries

	local _eHub, _stopEmotes = setupEmotesHub(ContentFrame, HomePage, function()
		return updateActiveIndicator
	end)
	EmotesHubPage = _eHub
	stopAllEmotes = _stopEmotes

	local vcCtrl = createVoiceChatBackend(trackConnection, function(t, msg, dur)
		NightSystem:Notify({ Title = t, Content = msg, Duration = dur or 4 })
	end)
	VCHubPage = setupVoiceChatHub(ContentFrame, HomePage, vcCtrl, function()
		return updateActiveIndicator
	end, trackConnection)

	local function openVCHub()
		HomePage.Visible = false
		if ScriptsHubPage then ScriptsHubPage.Visible = false end
		if EmotesHubPage then EmotesHubPage.Visible = false end
		if VCHubPage then
			VCHubPage.Visible = true
			VCHubPage.Position = UDim2.new(0, 0, 0, 8)
			tween(VCHubPage, TWEEN_MEDIUM, { Position = UDim2.new(0, 0, 0, 0) })
			updateActiveIndicator(true)
		end
	end

	setupExternalVCOverlay(BadgeGui, vcCtrl, makeDraggable, function()
		if not isWindowOpen then
			openWindow()
		end
		switchSidebarTab("Home", true)
		openVCHub()
	end, trackConnection, badgeVcUi)

	do
		local VoiceChatBtn = Instance.new("TextButton")
		VoiceChatBtn.Name = "VoiceChatButton"
		VoiceChatBtn.Size = UDim2.new(0, 128, 0, 34)
		VoiceChatBtn.Position = UDim2.new(1, 0, 0, 82)
		VoiceChatBtn.AnchorPoint = Vector2.new(1, 0)
		VoiceChatBtn.BackgroundColor3 = Color3.fromHex("#181B1E")
		VoiceChatBtn.BorderSizePixel = 0
		VoiceChatBtn.AutoButtonColor = false
		VoiceChatBtn.Text = ""
		VoiceChatBtn.Parent = HomePage
		createCorner(VoiceChatBtn, 8)
		local vcBtnStroke = createStroke(VoiceChatBtn, Color3.fromHex("#2A2E33"), 1, 0.1)

		local vcBtnIcon = Instance.new("ImageLabel")
		vcBtnIcon.Size = UDim2.new(0, 14, 0, 14)
		vcBtnIcon.Position = UDim2.new(0, 11, 0.5, 0)
		vcBtnIcon.AnchorPoint = Vector2.new(0, 0.5)
		vcBtnIcon.BackgroundTransparency = 1
		vcBtnIcon.Image = ASSETS.VoiceChat
		vcBtnIcon.ImageColor3 = THEME.Accent
		vcBtnIcon.ScaleType = Enum.ScaleType.Fit
		vcBtnIcon.Parent = VoiceChatBtn

		local vcBtnLbl = Instance.new("TextLabel")
		vcBtnLbl.Size = UDim2.new(1, -54, 1, 0)
		vcBtnLbl.Position = UDim2.new(0, 30, 0, 0)
		vcBtnLbl.BackgroundTransparency = 1
		vcBtnLbl.Font = Enum.Font.GothamBold
		vcBtnLbl.Text = "Voice Chat"
		vcBtnLbl.TextColor3 = THEME.TextPrimary
		vcBtnLbl.TextSize = 12
		vcBtnLbl.TextXAlignment = Enum.TextXAlignment.Left
		vcBtnLbl.Parent = VoiceChatBtn

		local vcBtnArrow = Instance.new("ImageLabel")
		vcBtnArrow.Size = UDim2.new(0, 14, 0, 14)
		vcBtnArrow.Position = UDim2.new(1, -10, 0.5, 0)
		vcBtnArrow.AnchorPoint = Vector2.new(1, 0.5)
		vcBtnArrow.BackgroundTransparency = 1
		vcBtnArrow.Image = ASSETS.ChevronRight
		vcBtnArrow.ImageColor3 = THEME.TextSecondary
		vcBtnArrow.Parent = VoiceChatBtn

		VoiceChatBtn.MouseEnter:Connect(function()
			tween(VoiceChatBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#22262B") })
			tween(vcBtnStroke, TWEEN_FAST, { Color = THEME.Accent, Transparency = 0 })
			tween(vcBtnArrow, TWEEN_FAST, { ImageColor3 = THEME.Accent, Position = UDim2.new(1, -8, 0.5, 0) })
		end)
		VoiceChatBtn.MouseLeave:Connect(function()
			tween(VoiceChatBtn, TWEEN_FAST, { BackgroundColor3 = Color3.fromHex("#181B1E") })
			tween(vcBtnStroke, TWEEN_FAST, { Color = Color3.fromHex("#2A2E33"), Transparency = 0.1 })
			tween(vcBtnArrow, TWEEN_FAST, { ImageColor3 = THEME.TextSecondary, Position = UDim2.new(1, -10, 0.5, 0) })
		end)
		VoiceChatBtn.MouseButton1Click:Connect(openVCHub)
	end

	AllScriptsBtn.MouseButton1Click:Connect(function()
		HomePage.Visible = false
		if EmotesHubPage then EmotesHubPage.Visible = false end
		if VCHubPage then VCHubPage.Visible = false end
		ScriptsHubPage.Visible = true
		ScriptsHubPage.Position = UDim2.new(0, 0, 0, 8)
		tween(ScriptsHubPage, TWEEN_MEDIUM, { Position = UDim2.new(0, 0, 0, 0) })
		updateActiveIndicator(true)
	end)

	FreeEmotesBtn.MouseButton1Click:Connect(function()
		HomePage.Visible = false
		if ScriptsHubPage then ScriptsHubPage.Visible = false end
		if VCHubPage then VCHubPage.Visible = false end
		EmotesHubPage.Visible = true
		EmotesHubPage.Position = UDim2.new(0, 0, 0, 8)
		tween(EmotesHubPage, TWEEN_MEDIUM, { Position = UDim2.new(0, 0, 0, 0) })
		updateActiveIndicator(true)
	end)

	local _profSec, _infoLbl, _platVal = setupProfileAndStats(HomePage, selectedPlatform)
	InfoTextLabel = _infoLbl
	PlatformValueLabel = _platVal

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

	local showPlatformSelectionModal: ((onSelect: (string) -> ()) -> ())
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
				local s = if mainFrameScale and mainFrameScale.Scale > 0 then mainFrameScale.Scale else 1
				local textW = secLabel.AbsoluteSize.X / s
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

		-- Top Thumbnail Image Container (Optimized for 3-Column Grid)
		local imgContainer = Instance.new("Frame")
		imgContainer.Name = "ImageContainer"
		imgContainer.Size = UDim2.new(1, 0, 0, 85)
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

		-- Script / Game Name (Optimized for 3-Column Grid)
		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, -16, 0, 16)
		titleLbl.Position = UDim2.new(0, 8, 0, 90)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Font = Enum.Font.GothamBold
		titleLbl.Text = sName
		titleLbl.TextColor3 = THEME.TextPrimary
		titleLbl.TextSize = 11
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
		titleLbl.Parent = card

		-- Loadstring Preview Code Box (Directly in front of the user)
		local codeBoxHolder = Instance.new("Frame")
		codeBoxHolder.Size = UDim2.new(1, -16, 0, 32)
		codeBoxHolder.Position = UDim2.new(0, 8, 0, 110)
		codeBoxHolder.BackgroundColor3 = Color3.fromHex("#0F1113")
		codeBoxHolder.BorderSizePixel = 0
		codeBoxHolder.ClipsDescendants = true
		codeBoxHolder.Parent = card
		createCorner(codeBoxHolder, 6)
		local codeBoxStroke = createStroke(codeBoxHolder, Color3.fromHex("#22252A"), 1, 0.2)

		local codeBox = Instance.new("TextBox")
		codeBox.Size = UDim2.new(1, -10, 1, 0)
		codeBox.Position = UDim2.new(0, 5, 0, 0)
		codeBox.BackgroundTransparency = 1
		codeBox.ClipsDescendants = true
		codeBox.Font = Enum.Font.Code
		codeBox.Text = rawLoadstring
		codeBox.TextColor3 = Color3.fromHex("#9EABB8")
		codeBox.TextSize = 8
		codeBox.TextWrapped = true
		codeBox.TextXAlignment = Enum.TextXAlignment.Left
		codeBox.TextYAlignment = Enum.TextYAlignment.Center
		codeBox.ClearTextOnFocus = false
		codeBox.Parent = codeBoxHolder

		-- Buttons Bar at the bottom
		local btnBar = Instance.new("Frame")
		btnBar.Size = UDim2.new(1, -16, 0, 28)
		btnBar.Position = UDim2.new(0, 8, 0, 150)
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

	-- Pre-register all Official Night System Scripts from module dataset

	for _, sData in ipairs(DEFAULT_HUB_SCRIPTS) do
		Window:AddHubScript(sData)
	end

	function Window:ClearScriptTabs()
		-- 1. Close AllScripts and FreeEmotes hub pages if open
		if ScriptsHubPage and ScriptsHubPage.Parent then
			ScriptsHubPage.Visible = false
		end
		if EmotesHubPage and EmotesHubPage.Parent then
			EmotesHubPage.Visible = false
		end
		if stopAllEmotes then
			pcall(stopAllEmotes)
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

	function Window:OpenFreeEmotes()
		HomePage.Visible = false
		if ScriptsHubPage then ScriptsHubPage.Visible = false end
		if VCHubPage then VCHubPage.Visible = false end
		if EmotesHubPage then
			EmotesHubPage.Visible = true
			EmotesHubPage.Position = UDim2.new(0, 0, 0, 8)
			tween(EmotesHubPage, TWEEN_MEDIUM, { Position = UDim2.new(0, 0, 0, 0) })
			updateActiveIndicator(true)
		end
	end
	Window.OpenEmotes = Window.OpenFreeEmotes

	function Window:OpenVoiceChat()
		openVCHub()
	end
	Window.OpenVC = Window.OpenVoiceChat

	do
		local function handleVcChat(raw: string)
			if type(raw) ~= "string" then return end
			local msg = raw:match("^%s*(.-)%s*$") or ""
			local pfx = msg:sub(1, 1)
			if pfx ~= ";" and pfx ~= "/" and pfx ~= "!" then return end
			local parts = {}
			for w in msg:sub(2):gmatch("%S+") do table.insert(parts, w) end
			local cmd = parts[1] and string.lower(parts[1])
			if cmd == "vcb" or cmd == "vcbypasser" then openVCHub()
			elseif cmd == "vcb2" then vcCtrl.runBypassV2()
			elseif cmd == "muteallvc" or cmd == "mavc" then vcCtrl.muteAll(true)
			elseif cmd == "unmuteallvc" or cmd == "umavc" then vcCtrl.muteAll(false)
			elseif cmd == "mutevc" or cmd == "mvc" then vcCtrl.muteTarget(parts[2] or "", true)
			elseif cmd == "unmutevc" or cmd == "umvc" then vcCtrl.muteTarget(parts[2] or "", false)
			elseif cmd == "listen" then vcCtrl.listenTo(parts[2] or "")
			elseif cmd == "unlisten" then vcCtrl.unlisten()
			elseif cmd == "vcbooster" or cmd == "vcboost" or cmd == "boostvc" then
				local q = table.concat(parts, " ", 2)
				if q ~= "" then
					for _, plr in ipairs(vcCtrl.findPlayers(q)) do vcCtrl.setBoostTarget(plr, true) end
					vcCtrl.setBoosterEnabled(true)
				else
					openVCHub()
				end
			elseif cmd == "unvcbooster" or cmd == "unvcboost" or cmd == "unboostvc" then
				local q = table.concat(parts, " ", 2)
				if q == "" then
					vcCtrl.setBoosterEnabled(false)
				else
					for _, plr in ipairs(vcCtrl.findPlayers(q)) do vcCtrl.setBoostTarget(plr, false) end
				end
			end
		end
		pcall(function()
			trackConnection(LocalPlayer.Chatted:Connect(handleVcChat))
		end)
		pcall(function()
			local tcs = game:GetService("TextChatService")
			if tcs then
				trackConnection(tcs.SendingMessage:Connect(function(m)
					if m and m.Text then handleVcChat(m.Text) end
				end))
			end
		end)
	end

	function Window:StopEmotes()
		if stopAllEmotes then
			stopAllEmotes()
		end
	end

	function Window:SelectTab(tabName: string)
		switchSidebarTab(tabName, false)
	end

	function Window:Notify(notifOpts: { Title: string?, Content: string?, Duration: number? } | string)
		NightSystem:Notify(notifOpts)
	end

	function Window:Destroy()
		if stopAllEmotes then
			pcall(stopAllEmotes)
		end
		if vcCtrl and vcCtrl.stopAll then
			pcall(vcCtrl.stopAll)
		end
		disconnectAll()
		NightSystem._ActiveWindow = nil
		if gEnv then
			gEnv._NightLoaded = nil
			gEnv._NightActiveWindow = nil
			gEnv._NightSystem = nil
			gEnv._NightBuildId = nil
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
	showPlatformSelectionModal = function(onSelect: (string) -> ())
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
		local spinConn = trackConnection(RunService.RenderStepped:Connect(function(dt)
			if not isSpinning or not spinner or not spinner.Parent then return end
			spinner.Rotation = (spinner.Rotation + dt * 380) % 360
		end))

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
		gEnv._NightLoaded = true
		gEnv._NightBuildId = NIGHT_BUILD_ID
		gEnv._NightActiveWindow = winInstance
		gEnv._NightSystem = NightSystem
		gEnv.NightSystem = NightSystem
		gEnv.NightUI = NightSystem
		gEnv.OrionLib = NightSystem
		gEnv.Rayfield = NightSystem
	end
	print("[NightSystem] Active Build: " .. NIGHT_BUILD_ID)

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

function NightSystem:OpenFreeEmotes()
	if NightSystem._ActiveWindow then
		return NightSystem._ActiveWindow:OpenFreeEmotes()
	end
end
NightSystem.OpenEmotes = NightSystem.OpenFreeEmotes

function NightSystem:StopEmotes()
	if NightSystem._ActiveWindow then
		return NightSystem._ActiveWindow:StopEmotes()
	end
end

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
