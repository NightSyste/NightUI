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

local Library = {
	Elements = {},
	ThemeObjects = {},
	Connections = {},
	Flags = {},
	SearchRegistry = {},
	Themes = {
		Default = {
			Main = Color3.fromRGB(18, 14, 25),      -- Tiefes Dunkel-Lila / Midnight Violet
			Second = Color3.fromRGB(25, 20, 36),    -- Elegantes Element-Panel
			Sidebar = Color3.fromRGB(20, 16, 30),   -- Dunkle samtige Tab-Leiste
			Control = Color3.fromRGB(38, 30, 54),   -- Keybind / Textbox / Regler-Feld
			Stroke = Color3.fromRGB(60, 46, 84),    -- Sanfte lila Konturen
			Divider = Color3.fromRGB(44, 34, 62),   -- Trennlinien
			Text = Color3.fromRGB(240, 235, 250),   -- Heller Text mit leichtem Lila-Schimmer
			TextDark = Color3.fromRGB(155, 140, 180),-- Gedämpfter Text
			MainTransparency = 0.22,
			SecondTransparency = 0.15,
			FrameTransparency = 0.2
		}
	},
	SelectedTheme = "Default",
	Font = Enum.Font.Gotham,
	SoundsEnabled = true,
	RainbowEnabled = false,
	BlurEnabled = false,
	WatermarkEnabled = true,
	AntiAfkEnabled = false,
	FullbrightEnabled = false,
	PotatoModeEnabled = false,
	TargetFps = 60
}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║   CUSTOM LOGO, SETTINGS & HINTERGRUND-BILD LINKS             ║
-- ╚══════════════════════════════════════════════════════════════╝
Library.CustomLogoUrl         = "https://i.ibb.co/B2kt592w/Night-removebg-preview.png"
Library.CustomSettingsUrl     = "https://s1.directupload.eu/images/260911/4fywabml.png"
Library.CustomSettingsIconUrl = "https://s1.directupload.eu/images/260911/4fywabml.png"
Library.ActiveSettingsUrl     = "https://s1.directupload.eu/images/260911/4fywabml.png"
Library.CustomBackgroundUrl   = "https://s1.directupload.eu/images/260904/3m9x7lao.jpg"
Library.BackgroundUrls = {
	["Frau 1"] = "https://s1.directupload.eu/images/260904/3m9x7lao.jpg",
	["Frau 2"] = "https://s1.directupload.eu/images/260904/soqw6y3k.jpg",
	["Frau 3"] = "https://s1.directupload.eu/images/260904/qqkkxxbc.jpg",
	["Frau 4"] = "https://s1.directupload.eu/images/260904/n75cgpa4.jpg"
}
Library.SelectedBackground = "Frau 1"
Library.ActiveBackgroundUrl = "https://s1.directupload.eu/images/260904/3m9x7lao.jpg"
Library.BackgroundTransparency = 0.35

-- ╔══════════════════════════════════════════════════════════════╗
-- ║   TRANSPARENZ (Dunkel-Lila Glas-Optik)                       ║
-- ╚══════════════════════════════════════════════════════════════╝
Library.Transparency = {
	Window  = 0.22,
	Sidebar = 0.14,
	Second  = 0,
	Control = 0.40,
}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║        AKZENTFARBE (Neon / Cyber Lila)                       ║
-- ╚══════════════════════════════════════════════════════════════╝
Library.Accent     = Color3.fromRGB(145, 115, 245)
Library.AccentText = Color3.fromRGB(185, 165, 255)
Library.AccentSoft = Color3.fromRGB(155, 135, 220)
local ACCENT       = Library.Accent
local ACCENT_TEXT  = Library.AccentText
local ACCENT_SOFT  = Library.AccentSoft

Library.FixedIconId         = "rbxassetid://71392308711379"
Library.FixedSettingsIconId = "rbxassetid://89652930608206"

-- ╔══════════════════════════════════════════════════════════════╗
-- ║   ROBUSTER WEB-IMAGE LOADER (HTTP -> Custom Asset)           ║
-- ╚══════════════════════════════════════════════════════════════╝
local function LoadCustomAsset(urlOrAsset, fallback)
	if not urlOrAsset or urlOrAsset == "" then
		return fallback or Library.FixedIconId
	end
	local str = tostring(urlOrAsset)
	if string.sub(str, 1, 13) == "rbxassetid://" or tonumber(str) then
		return (tonumber(str) and ("rbxassetid://" .. str)) or str
	end
	if string.find(str, "roblox.com") then
		return str
	end
	if string.sub(str, 1, 4) == "http" then
		local success, result = pcall(function()
			if not (isfile and writefile and getcustomasset) then
				return str
			end
			local hash = 0
			for i = 1, #str do
				hash = (hash * 31 + string.byte(str, i)) % 2147483647
			end
			local fileName = "NightLogo_" .. tostring(hash) .. ".png"
			
			if isfile(fileName) then
				return getcustomasset(fileName)
			end
			
			local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
			if requestFunc then
				local res = requestFunc({Url = str, Method = "GET"})
				if res and (res.StatusCode == 200 or res.StatusMessage == "OK" or res.Success) and res.Body then
					local body = res.Body
					if string.find(str, "4fywabml") then
						local pltePos = string.find(body, "PLTE", 1, true)
						if pltePos then
							local len = 765
							local whitePlte = "PLTE" .. string.rep("\255", len) .. string.char(0x52, 0x92, 0xc4, 0x9b)
							body = string.sub(body, 1, pltePos - 1) .. whitePlte .. string.sub(body, pltePos + 4 + len + 4)
						end
					end
					writefile(fileName, body)
					return getcustomasset(fileName)
				end
			end
			return str
		end)
		if success and result then return result end
		return str
	end
	return urlOrAsset
end

local function PlayClickSound()
	if not Library.SoundsEnabled then return end
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://6895079853"
		sound.Volume = 0.45
		sound.Parent = game:GetService("SoundService")
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 1)
	end)
end

local function CopyToClipboard(text, notifName)
	local setclip = setclipboard or toclipboard or (syn and syn.write_clipboard) or (Clipboard and Clipboard.set)
	if setclip then
		setclip(tostring(text))
		Library:MakeNotification({
			Name = notifName or "Kopiert",
			Content = tostring(text):sub(1, 38) .. (string.len(tostring(text)) > 38 and "..." or ""),
			Time = 2.5
		})
	else
		Library:MakeNotification({
			Name = "Hinweis",
			Content = tostring(text),
			Time = 4
		})
	end
end

local function PackColor(Color)
	return {R = Color.R * 255, G = Color.G * 255, B = Color.B * 255}
end

local function UnpackColor(Color)
	return Color3.fromRGB(Color.R, Color.G, Color.B)
end

local function LoadCfg(Config)
	local Success, Data = pcall(function()
		return HttpService:JSONDecode(Config)
	end)
	if not Success then return end
	for a, b in pairs(Data) do
		if Library.Flags[a] then
			task.spawn(function()
				if Library.Flags[a].Type == "Colorpicker" then
					Library.Flags[a]:Set(UnpackColor(b))
				else
					Library.Flags[a]:Set(b)
				end
			end)
		end
	end
end

local function SaveCfg(Name)
	if not Library.SaveCfg then return end
	local Data = {}
	for i, v in pairs(Library.Flags) do
		if v.Save then
			if v.Type == "Colorpicker" then
				Data[i] = PackColor(v.Value)
			else
				Data[i] = v.Value
			end
		end
	end
	pcall(function()
		writefile(Library.Folder .. "/" .. Name .. ".txt", tostring(HttpService:JSONEncode(Data)))
	end)
end

-- ╔══════════════════════════════════════════════════════════════╗
-- ║   UI-EINSTELLUNGEN SPEICHERN & LADEN (PERSISTENZ)            ║
-- ╚══════════════════════════════════════════════════════════════╝
local UI_CONFIG_FILE = "NightSystem_UI_Settings.json"

local function LoadUIConfig()
	local success, result = pcall(function()
		if not (readfile and isfile and HttpService) then return nil end
		if isfile(UI_CONFIG_FILE) then
			local raw = readfile(UI_CONFIG_FILE)
			if raw and raw ~= "" then
				return HttpService:JSONDecode(raw)
			end
		end
		return nil
	end)
	if success and result and type(result) == "table" then
		return result
	end
	return nil
end

local function SaveUIConfig()
	pcall(function()
		if not (writefile and HttpService) then return end
		local data = {
			SelectedBackground     = Library.SelectedBackground or "Frau 1",
			BackgroundUrl          = Library.ActiveBackgroundUrl or "https://s1.directupload.eu/images/260904/3m9x7lao.jpg",
			BackgroundTransparency = Library.BackgroundTransparency or 0.35,
			SettingsUrl            = Library.ActiveSettingsUrl or Library.CustomSettingsUrl or "https://s1.directupload.eu/images/260911/4fywabml.png",
			CustomLogoUrl          = Library.CustomLogoUrl or "https://i.ibb.co/B2kt592w/Night-removebg-preview.png",
			RainbowEnabled         = Library.RainbowEnabled or false,
			BlurEnabled            = Library.BlurEnabled or false,
			WatermarkEnabled       = Library.WatermarkEnabled or false,
			AntiAfkEnabled         = Library.AntiAfkEnabled or false,
			FullbrightEnabled      = Library.FullbrightEnabled or false,
			PotatoModeEnabled      = Library.PotatoModeEnabled or false,
			TargetFps              = Library.TargetFps or 60,
			SoundsEnabled          = (Library.SoundsEnabled ~= false),
			WindowTransparency     = Library.Transparency.Window or 0.22,
			SidebarTransparency    = Library.Transparency.Sidebar or 0.14,
			ReopenMode             = (Library.MinimizeSettings and Library.MinimizeSettings.ReopenMode) or "DoubleClick",
			ToggleKey              = (typeof(Library.ToggleKey) == "EnumItem" and Library.ToggleKey.Name) or (typeof(Library.ToggleKey) == "string" and Library.ToggleKey) or "LeftControl",
			AccentColor            = {
				R = math.floor((Library.Accent.R or 1) * 255 + 0.5),
				G = math.floor((Library.Accent.G or 1) * 255 + 0.5),
				B = math.floor((Library.Accent.B or 1) * 255 + 0.5)
			}
		}
		writefile(UI_CONFIG_FILE, HttpService:JSONEncode(data))
	end)
end

local savedUI = LoadUIConfig()
if savedUI then
	if savedUI.SelectedBackground then
		Library.SelectedBackground = savedUI.SelectedBackground
		if savedUI.SelectedBackground == "Kein Hintergrund (Aus)" then
			Library.ActiveBackgroundUrl = nil
		elseif Library.BackgroundUrls and Library.BackgroundUrls[savedUI.SelectedBackground] then
			Library.ActiveBackgroundUrl = Library.BackgroundUrls[savedUI.SelectedBackground]
		elseif savedUI.BackgroundUrl then
			Library.ActiveBackgroundUrl = savedUI.BackgroundUrl
		end
	end
	if savedUI.BackgroundTransparency then
		Library.BackgroundTransparency = savedUI.BackgroundTransparency
	end
	if savedUI.SettingsUrl then
		Library.ActiveSettingsUrl = savedUI.SettingsUrl
		Library.CustomSettingsUrl = savedUI.SettingsUrl
		Library.CustomSettingsIconUrl = savedUI.SettingsUrl
	end
	if savedUI.CustomLogoUrl then
		Library.CustomLogoUrl = savedUI.CustomLogoUrl
	end
	if savedUI.WindowTransparency then
		Library.Transparency.Window = savedUI.WindowTransparency
	end
	if savedUI.SidebarTransparency then
		Library.Transparency.Sidebar = savedUI.SidebarTransparency
	end
	if savedUI.RainbowEnabled ~= nil then Library.RainbowEnabled = savedUI.RainbowEnabled end
	if savedUI.BlurEnabled ~= nil then Library.BlurEnabled = savedUI.BlurEnabled end
	if savedUI.WatermarkEnabled ~= nil then
		Library.WatermarkEnabled = savedUI.WatermarkEnabled
	else
		Library.WatermarkEnabled = true
	end
	if savedUI.AntiAfkEnabled ~= nil then Library.AntiAfkEnabled = savedUI.AntiAfkEnabled end
	if savedUI.FullbrightEnabled ~= nil then Library.FullbrightEnabled = savedUI.FullbrightEnabled end
	if savedUI.PotatoModeEnabled ~= nil then Library.PotatoModeEnabled = savedUI.PotatoModeEnabled end
	if savedUI.TargetFps ~= nil then Library.TargetFps = savedUI.TargetFps end
	if savedUI.SoundsEnabled ~= nil then Library.SoundsEnabled = savedUI.SoundsEnabled end
	if savedUI.AccentColor and type(savedUI.AccentColor) == "table" then
		local c = Color3.fromRGB(savedUI.AccentColor.R or 145, savedUI.AccentColor.G or 115, savedUI.AccentColor.B or 245)
		Library.Accent = c
		Library.AccentText = c:Lerp(Color3.fromRGB(255,255,255), 0.20)
		Library.AccentSoft = c:Lerp(Color3.fromRGB(255,255,255), 0.08)
		ACCENT = Library.Accent
		ACCENT_TEXT = Library.AccentText
		ACCENT_SOFT = Library.AccentSoft
	end
end

function Library:Init()
	if not Library.SaveCfg then return end
	task.defer(function()
		pcall(function()
			local path = Library.Folder .. "/" .. tostring(game.GameId) .. ".txt"
			if isfile(path) then
				local raw = readfile(path)
				if raw and raw ~= "" then
					LoadCfg(raw)
					Library:MakeNotification({
						Name = "Config loaded",
						Content = "Your settings were restored.",
						Time = 4
					})
				end
			end
		end)
	end)
end

local function GetIcon(IconName)
	return nil
end

function Library:CleanupInstance()
	for _, instance in pairs(game:GetService("CoreGui"):GetChildren()) do
		if instance:IsA("ScreenGui") and instance.Name:match("^[A-Z]%d%d%d$") then
			instance:Destroy()
		end
	end
end

Library:CleanupInstance()
local Container = Instance.new("ScreenGui")
Container.Name = string.char(math.random(65, 90))..tostring(math.random(100, 999))
Container.DisplayOrder = 2147483647
Container.ResetOnSpawn = false
Container.Parent = game:GetService("CoreGui")

function Library:IsRunning()
	return Container and Container.Parent == game:GetService("CoreGui")
end

local function AddConnection(Signal, Function)
	if not Library:IsRunning() then return end
	local SignalConnect = Signal:Connect(Function)
	table.insert(Library.Connections, SignalConnect)
	return SignalConnect
end

task.spawn(function()
	while Library:IsRunning() do wait() end
	for _, Connection in next, Library.Connections do
		Connection:Disconnect()
	end
end)

local function MakeDraggable(DragPoint, Main)
	local IsResizing = false
	pcall(function()
		local Dragging, DragInput, MousePos, FramePos = false
		DragPoint.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				if not IsResizing then
					Dragging = true
					MousePos = Input.Position
					FramePos = Main.Position
				end
				Input.Changed:Connect(function()
					if Input.UserInputState == Enum.UserInputState.End then Dragging = false end
				end)
			end
		end)
		DragPoint.InputChanged:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
				DragInput = Input
			end
		end)
		UserInputService.InputChanged:Connect(function(Input)
			if Input == DragInput and Dragging and not IsResizing then
				local Delta = Input.Position - MousePos
				TweenService:Create(Main, TweenInfo.new(0.65, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
					Position = UDim2.new(FramePos.X.Scale, FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)
				}):Play()
			end
		end)
	end)
	return function(resizing)
		IsResizing = resizing
	end
end

local function Create(Name, Properties, Children)
	local Object = Instance.new(Name)
	for i, v in next, Properties or {} do Object[i] = v end
	for i, v in next, Children or {} do v.Parent = Object end
	return Object
end

local function CreateElement(ElementName, ElementFunction)
	Library.Elements[ElementName] = function(...) return ElementFunction(...) end
end

local function MakeElement(ElementName, ...)
	return Library.Elements[ElementName](...)
end

local function SetProps(Element, Props)
	for Property, Value in pairs(Props) do Element[Property] = Value end
	return Element
end

local function SetChildren(Element, Children)
	for _, Child in pairs(Children) do Child.Parent = Element end
	return Element
end

local function Round(Number, Factor)
	if not Factor or Factor == 0 then return Number end
	local Result = math.floor(Number / Factor + (math.sign(Number) * 0.5)) * Factor
	if Result < 0 then Result = Result + Factor end
	return Result
end

local function ReturnProperty(Object)
	if Object:IsA("Frame") or Object:IsA("TextButton") then return "BackgroundColor3" end
	if Object:IsA("ScrollingFrame") then return "ScrollBarImageColor3" end
	if Object:IsA("UIStroke") then return "Color" end
	if Object:IsA("TextLabel") or Object:IsA("TextBox") then return "TextColor3" end
	if Object:IsA("ImageLabel") or Object:IsA("ImageButton") then return "ImageColor3" end
end

local function AddThemeObject(Object, Type)
	if not Library.ThemeObjects[Type] then Library.ThemeObjects[Type] = {} end
	table.insert(Library.ThemeObjects[Type], Object)
	Object[ReturnProperty(Object)] = Library.Themes[Library.SelectedTheme][Type]
	local Trans = Library.Transparency[Type]
	if Trans and (Object:IsA("Frame") or Object:IsA("TextButton")) then
		Object.BackgroundTransparency = Trans
	end
	return Object
end

local function GetElementName(Frame)
	local Result = ""
	local Title = Frame:FindFirstChild("Title", true)
	if Title and Title:IsA("TextLabel") then Result = Result .. Title.Text .. " " end
	local Content = Frame:FindFirstChild("Content", true)
	if Content and Content:IsA("TextLabel") then Result = Result .. Content.Text end
	return Result
end

local function SetupElement(Frame, InPanel, Container, Activate, ItemParent)
	table.insert(Library.SearchRegistry, {
		Frame = Frame,
		Container = Container,
		Activate = Activate,
		Section = (ItemParent and Container and ItemParent ~= Container) and ItemParent.Parent or nil
	})
	if not InPanel then return Frame end
	Frame.BackgroundTransparency = 1
	Frame.Position = UDim2.new(0, 0, 0, 0)
	Frame.Size = UDim2.new(1, 0, 0, Frame.Size.Y.Offset)
	local Corner = Frame:FindFirstChildOfClass("UICorner")
	if Corner then Corner.CornerRadius = UDim.new(0, 0) end
	local Stroke = Frame:FindFirstChildOfClass("UIStroke")
	if Stroke then Stroke.Transparency = 1 end
	AddThemeObject(Create("Frame", {
		Name = "RowLine",
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = Frame
	}), "Divider")
	local Btn = Frame:FindFirstChildOfClass("TextButton")
	if Btn then
		AddConnection(Btn.MouseEnter, function()
			TweenService:Create(Frame, TweenInfo.new(0.15), {BackgroundTransparency = 0.93}):Play()
		end)
		AddConnection(Btn.MouseLeave, function()
			TweenService:Create(Frame, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
		end)
	end
	return Frame
end

local WhitelistedMouse = {Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3, Enum.UserInputType.Touch}
local BlacklistedKeys = {Enum.KeyCode.Unknown, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Left, Enum.KeyCode.Down, Enum.KeyCode.Right, Enum.KeyCode.Slash, Enum.KeyCode.Tab, Enum.KeyCode.Backspace, Enum.KeyCode.Escape}

local function CheckKey(Table, Key)
	for _, v in next, Table do
		if v == Key then return true end
	end
end

CreateElement("Corner", function(Scale, Offset)
	return Create("UICorner", {CornerRadius = UDim.new(Scale or 0, Offset or 12)})
end)

CreateElement("Stroke", function(Color, Thickness)
	return Create("UIStroke", {Color = Color or Color3.fromRGB(255,255,255), Thickness = Thickness or 0.5})
end)

CreateElement("List", function(Scale, Offset)
	return Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(Scale or 0, Offset or 0)})
end)

CreateElement("Padding", function(Bottom, Left, Right, Top)
	return Create("UIPadding", {
		PaddingBottom = UDim.new(0, Bottom or 4),
		PaddingLeft   = UDim.new(0, Left   or 4),
		PaddingRight  = UDim.new(0, Right  or 4),
		PaddingTop    = UDim.new(0, Top    or 4)
	})
end)

CreateElement("TFrame", function()
	return Create("Frame", {BackgroundTransparency = 1})
end)

CreateElement("Frame", function(Color)
	return Create("Frame", {BackgroundColor3 = Color or Color3.fromRGB(255,255,255), BorderSizePixel = 0})
end)

CreateElement("RoundFrame", function(Color, Scale, Offset)
	return Create("Frame", {BackgroundColor3 = Color or Color3.fromRGB(255,255,255), BorderSizePixel = 0}, {
		Create("UICorner", {CornerRadius = UDim.new(Scale, Offset)})
	})
end)

CreateElement("Button", function()
	local Button = Create("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0})
	Button.MouseButton1Click:Connect(function()
		PlayClickSound()
	end)
	return Button
end)

CreateElement("ScrollFrame", function(Color, Width)
	return Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		MidImage = "rbxassetid://7445543667",
		BottomImage = "rbxassetid://7445543667",
		TopImage = "rbxassetid://7445543667",
		ScrollBarImageColor3 = Color,
		BorderSizePixel = 0,
		ScrollBarThickness = Width,
		CanvasSize = UDim2.new(0,0,0,0)
	})
end)

CreateElement("Image", function(ImageID)
	local ImageNew = Create("ImageLabel", {Image = ImageID, BackgroundTransparency = 1})
	if GetIcon(ImageID) ~= nil then ImageNew.Image = GetIcon(ImageID) end
	return ImageNew
end)

CreateElement("ImageButton", function(ImageID)
	return Create("ImageButton", {Image = ImageID, BackgroundTransparency = 1})
end)

CreateElement("Label", function(Text, TextSize, Transparency)
	return Create("TextLabel", {
		Text = Text or "",
		TextColor3 = Color3.fromRGB(240,240,240),
		TextTransparency = Transparency or 0,
		TextSize = TextSize or 15,
		Font = Enum.Font.GothamSemibold,
		RichText = true,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left
	})
end)

local NotificationHolder = SetProps(SetChildren(MakeElement("TFrame"), {
	SetProps(MakeElement("List"), {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 5)
	})
}), {
	Position = UDim2.new(1, -25, 1, -25),
	Size = UDim2.new(0, 300, 1, -25),
	AnchorPoint = Vector2.new(1, 1),
	Parent = Container
})

-- ╔══════════════════════════════════════════════════════════════╗
-- ║   UNIVERSAL ALIAS & ARGUMENT RESOLVER                        ║
-- ╚══════════════════════════════════════════════════════════════╝
local function ResolveArgs(callerTbl, signatureKey, a1, a2, ...)
	if a1 == callerTbl or (type(a1) == "table" and signatureKey and rawget(a1, signatureKey) ~= nil) then
		return a2, ...
	end
	return a1, a2, ...
end

local function ParseWindowArgs(...)
	local cfg = ...
	if type(cfg) == "string" then return { Name = cfg }
	elseif type(cfg) == "table" then return cfg end
	return { Name = "NightSystem" }
end

local function ParseNotifArgs(...)
	local cfg, content, time, img = ...
	if type(cfg) == "string" then
		return { Name = cfg, Content = content or "", Time = tonumber(time) or 5, Image = img or "rbxassetid://4384403532" }
	elseif type(cfg) == "table" then
		return {
			Name = cfg.Name or cfg.name or cfg.Title or cfg.title or "Notification",
			Content = cfg.Content or cfg.content or cfg.Text or cfg.text or cfg.Desc or cfg.desc or content or "",
			Time = tonumber(cfg.Time or cfg.time or cfg.Duration or cfg.duration or time) or 5,
			Image = cfg.Image or cfg.image or cfg.Icon or cfg.icon or img or "rbxassetid://4384403532"
		}
	end
	return { Name = "Notification", Content = "", Time = 5, Image = "rbxassetid://4384403532" }
end

local function ParseTabArgs(...)
	local cfg, ico, prem = ...
	if type(cfg) == "string" then
		return { Name = cfg, Icon = ico or "", PremiumOnly = (prem == true) }
	elseif type(cfg) == "table" then
		return {
			Name = cfg.Name or cfg.name or cfg.Title or cfg.title or "Tab",
			Icon = cfg.Icon or cfg.icon or cfg.Image or cfg.image or ico or "",
			PremiumOnly = (cfg.PremiumOnly ~= nil and cfg.PremiumOnly) or (cfg.premiumOnly ~= nil and cfg.premiumOnly) or (cfg.Premium ~= nil and cfg.Premium) or (cfg.premium ~= nil and cfg.premium) or (prem == true)
		}
	end
	return { Name = "Tab", Icon = "", PremiumOnly = false }
end

local function ParseGroupArgs(...)
	local cfg, col = ...
	if type(cfg) == "string" then
		return { Name = cfg, Collapsed = (col == true) }
	elseif type(cfg) == "table" then
		return {
			Name = cfg.Name or cfg.name or cfg.Title or cfg.title or "Group",
			Collapsed = (cfg.Collapsed ~= nil and cfg.Collapsed) or (cfg.collapsed ~= nil and cfg.collapsed) or (col == true)
		}
	end
	return { Name = "Group", Collapsed = false }
end

local function ParseButtonArgs(...)
	local cfg, cb, ico = ...
	if type(cfg) == "string" then
		return { Name = cfg, Callback = cb or function() end, Icon = ico or "rbxassetid://3944703587" }
	elseif type(cfg) == "table" then
		return {
			Name = cfg.Name or cfg.name or cfg.Title or cfg.title or cfg.Text or cfg.text or "Button",
			Callback = cfg.Callback or cfg.callback or cfg.Func or cfg.func or cb or function() end,
			Icon = cfg.Icon or cfg.icon or cfg.Image or cfg.image or ico or "rbxassetid://3944703587"
		}
	end
	return { Name = "Button", Callback = function() end, Icon = "rbxassetid://3944703587" }
end

local function ParseToggleArgs(...)
	local cfg, def, cb, col, flag, save = ...
	if type(cfg) == "string" then
		if type(def) == "function" then cb = def; def = false end
		return { Name = cfg, Default = (def == true), Callback = cb or function() end, Color = col or ACCENT, Flag = flag, Save = (save == true) }
	elseif type(cfg) == "table" then
		local d = cfg.Default
		if d == nil then d = cfg.default end
		if d == nil then d = cfg.Value end
		if d == nil then d = cfg.value end
		if d == nil then d = cfg.State end
		if d == nil then d = cfg.state end
		if d == nil then d = false end
		return {
			Name = cfg.Name or cfg.name or cfg.Title or cfg.title or cfg.Text or cfg.text or "Toggle",
			Default = (d == true),
			Callback = cfg.Callback or cfg.callback or cfg.Func or cfg.func or cb or function() end,
			Color = cfg.Color or cfg.color or col or ACCENT,
			Flag = cfg.Flag or cfg.flag or flag,
			Save = (cfg.Save ~= nil and cfg.Save) or (cfg.save ~= nil and cfg.save) or (save == true)
		}
	end
	return { Name = "Toggle", Default = false, Callback = function() end, Color = ACCENT }
end

local function ParseSliderArgs(...)
	local cfg, min, max, def, inc, cb, valName = ...
	if type(cfg) == "string" then
		if type(inc) == "function" then cb = inc; inc = 1 end
		return { Name = cfg, Min = tonumber(min) or 0, Max = tonumber(max) or 100, Default = tonumber(def) or tonumber(min) or 0, Increment = tonumber(inc) or 1, Callback = cb or function() end, ValueName = valName or "" }
	elseif type(cfg) == "table" then
		local minV = cfg.Min or cfg.min or 0
		local maxV = cfg.Max or cfg.max or 100
		local defV = cfg.Default or cfg.default or cfg.Value or cfg.value or minV
		local incV = cfg.Increment or cfg.increment or cfg.Step or cfg.step or cfg.Precise or cfg.precise or 1
		return {
			Name = cfg.Name or cfg.name or cfg.Title or cfg.title or "Slider",
			Min = tonumber(minV) or 0,
			Max = tonumber(maxV) or 100,
			Default = tonumber(defV) or tonumber(minV) or 0,
			Increment = tonumber(incV) or 1,
			ValueName = cfg.ValueName or cfg.valueName or cfg.Suffix or cfg.suffix or valName or "",
			Callback = cfg.Callback or cfg.callback or cfg.Func or cfg.func or cb or function() end,
			Color = cfg.Color or cfg.color or ACCENT,
			Flag = cfg.Flag or cfg.flag,
			Save = (cfg.Save ~= nil and cfg.Save) or (cfg.save ~= nil and cfg.save) or false
		}
	end
	return { Name = "Slider", Min = 0, Max = 100, Default = 0, Increment = 1, Callback = function() end }
end

local function ParseDropdownArgs(...)
	local cfg, opts, def, cb = ...
	if type(cfg) == "string" then
		opts = opts or {}
		return { Name = cfg, Options = opts, Default = def or opts[1] or "", Callback = cb or function() end }
	elseif type(cfg) == "table" then
		local optsT = cfg.Options or cfg.options or cfg.List or cfg.list or opts or {}
		return {
			Name = cfg.Name or cfg.name or cfg.Title or cfg.title or "Dropdown",
			Options = optsT,
			Default = cfg.Default or cfg.default or cfg.Value or cfg.value or def or optsT[1] or "",
			Callback = cfg.Callback or cfg.callback or cfg.Func or cfg.func or cb or function() end,
			Flag = cfg.Flag or cfg.flag,
			Save = (cfg.Save ~= nil and cfg.Save) or (cfg.save ~= nil and cfg.save) or false
		}
	end
	return { Name = "Dropdown", Options = {}, Default = "", Callback = function() end }
end

local function ParseBindArgs(...)
	local cfg, def, hold, cb = ...
	if type(cfg) == "string" then
		if type(hold) == "function" then cb = hold; hold = false end
		return { Name = cfg, Default = def or Enum.KeyCode.Unknown, Hold = (hold == true), Callback = cb or function() end }
	elseif type(cfg) == "table" then
		return {
			Name = cfg.Name or cfg.name or cfg.Title or cfg.title or "Bind",
			Default = cfg.Default or cfg.default or cfg.Key or cfg.key or cfg.Bind or cfg.bind or def or Enum.KeyCode.Unknown,
			Hold = (cfg.Hold ~= nil and cfg.Hold) or (cfg.hold ~= nil and cfg.hold) or (hold == true),
			Callback = cfg.Callback or cfg.callback or cfg.Func or cfg.func or cb or function() end,
			Flag = cfg.Flag or cfg.flag,
			Save = (cfg.Save ~= nil and cfg.Save) or (cfg.save ~= nil and cfg.save) or false
		}
	end
	return { Name = "Bind", Default = Enum.KeyCode.Unknown, Hold = false, Callback = function() end }
end

local function ParseTextboxArgs(...)
	local cfg, def, dis, cb = ...
	if type(cfg) == "string" then
		if type(dis) == "function" then cb = dis; dis = false end
		return { Name = cfg, Default = def or "", TextDisappear = (dis == true), Callback = cb or function() end }
	elseif type(cfg) == "table" then
		return {
			Name = cfg.Name or cfg.name or cfg.Title or cfg.title or cfg.Placeholder or cfg.placeholder or "Textbox",
			Default = cfg.Default or cfg.default or cfg.Text or cfg.text or cfg.Value or cfg.value or def or "",
			TextDisappear = (cfg.TextDisappear ~= nil and cfg.TextDisappear) or (cfg.textDisappear ~= nil and cfg.textDisappear) or (cfg.ClearText ~= nil and cfg.ClearText) or (cfg.clearText ~= nil and cfg.clearText) or (dis == true),
			Callback = cfg.Callback or cfg.callback or cfg.Func or cfg.func or cb or function() end
		}
	end
	return { Name = "Textbox", Default = "", TextDisappear = false, Callback = function() end }
end

local function ParseColorpickerArgs(...)
	local cfg, def, cb = ...
	if type(cfg) == "string" then
		return { Name = cfg, Default = def or Color3.fromRGB(255, 255, 255), Callback = cb or function() end }
	elseif type(cfg) == "table" then
		return {
			Name = cfg.Name or cfg.name or cfg.Title or cfg.title or "Colorpicker",
			Default = cfg.Default or cfg.default or cfg.Color or cfg.color or def or Color3.fromRGB(255, 255, 255),
			Callback = cfg.Callback or cfg.callback or cfg.Func or cfg.func or cb or function() end,
			Flag = cfg.Flag or cfg.flag,
			Save = (cfg.Save ~= nil and cfg.Save) or (cfg.save ~= nil and cfg.save) or false
		}
	end
	return { Name = "Colorpicker", Default = Color3.fromRGB(255, 255, 255), Callback = function() end }
end

local function ParseLabelArgs(...)
	local text = ...
	if type(text) == "table" then
		return tostring(text.Text or text.text or text.Content or text.content or text.Name or text.name or text.Title or text.title or "")
	end
	return tostring(text or "")
end

local function ParseParagraphArgs(...)
	local title, content = ...
	if type(title) == "table" then
		local c = title.Content or title.content or title.Body or title.body or title.Desc or title.desc or title.Description or title.description or content or ""
		local t = title.Title or title.title or title.Text or title.text or title.Name or title.name or "Title"
		return tostring(t), tostring(c)
	end
	return tostring(title or "Title"), tostring(content or "Content")
end

local function ParseSectionArgs(...)
	local cfg = ...
	if type(cfg) == "string" then
		return { Name = cfg }
	elseif type(cfg) == "table" then
		return { Name = cfg.Name or cfg.name or cfg.Title or cfg.title or cfg.Text or cfg.text or "Section" }
	end
	return { Name = "Section" }
end

local function AttachElementAliases(target)
	local aliases = {
		AddButton      = {"CreateButton", "MakeButton", "NewButton", "Button"},
		AddToggle      = {"CreateToggle", "MakeToggle", "NewToggle", "Toggle"},
		AddSlider      = {"CreateSlider", "MakeSlider", "NewSlider", "Slider"},
		AddDropdown    = {"CreateDropdown", "MakeDropdown", "NewDropdown", "Dropdown"},
		AddBind        = {"CreateBind", "MakeBind", "NewBind", "Bind", "AddKeybind", "CreateKeybind", "MakeKeybind", "NewKeybind", "Keybind"},
		AddTextbox     = {"CreateTextbox", "MakeTextbox", "NewTextbox", "Textbox", "AddTextBox", "CreateTextBox", "MakeTextBox", "NewTextBox", "TextBox", "AddInput", "CreateInput", "MakeInput", "NewInput", "Input"},
		AddColorpicker = {"CreateColorpicker", "MakeColorpicker", "NewColorpicker", "Colorpicker", "AddColorPicker", "CreateColorPicker", "MakeColorPicker", "NewColorPicker", "ColorPicker"},
		AddLabel       = {"CreateLabel", "MakeLabel", "NewLabel", "Label"},
		AddParagraph   = {"CreateParagraph", "MakeParagraph", "NewParagraph", "Paragraph"},
		AddSection     = {"CreateSection", "MakeSection", "NewSection", "Section"}
	}
	for base, list in pairs(aliases) do
		local fn = rawget(target, base)
		if fn then
			for _, alias in ipairs(list) do target[alias] = fn end
		end
	end
	local mt = getmetatable(target) or {}
	local oldIndex = mt.__index
	mt.__index = function(t, key)
		if type(key) == "string" then
			local clean = key:lower():gsub("^make", ""):gsub("^create", ""):gsub("^new", ""):gsub("^add", "")
			for base, list in pairs(aliases) do
				if base:lower():find(clean, 1, true) then return rawget(t, base) end
				for _, a in ipairs(list) do
					if a:lower():find(clean, 1, true) then return rawget(t, base) end
				end
			end
		end
		if type(oldIndex) == "function" then return oldIndex(t, key) elseif type(oldIndex) == "table" then return oldIndex[key] end
		return rawget(t, key)
	end
	setmetatable(target, mt)
	return target
end

local function AttachWindowAliases(target)
	local aliases = {
		MakeTab      = {"CreateTab", "NewTab", "AddTab", "Tab"},
		MakeTabGroup = {"CreateTabGroup", "NewTabGroup", "AddTabGroup", "TabGroup", "MakeGroup", "CreateGroup", "NewGroup", "AddGroup", "Group"}
	}
	for base, list in pairs(aliases) do
		local fn = rawget(target, base)
		if fn then
			for _, alias in ipairs(list) do target[alias] = fn end
		end
	end
	local mt = getmetatable(target) or {}
	local oldIndex = mt.__index
	mt.__index = function(t, key)
		if type(key) == "string" then
			local lk = key:lower()
			if lk:find("group") then return rawget(t, "MakeTabGroup")
			elseif lk:find("tab") then return rawget(t, "MakeTab") end
		end
		if type(oldIndex) == "function" then return oldIndex(t, key) elseif type(oldIndex) == "table" then return oldIndex[key] end
		return rawget(t, key)
	end
	setmetatable(target, mt)
	return target
end

local function AttachGroupAliases(target)
	local aliases = {
		MakeTab = {"CreateTab", "NewTab", "AddTab", "Tab"}
	}
	for base, list in pairs(aliases) do
		local fn = rawget(target, base)
		if fn then
			for _, alias in ipairs(list) do target[alias] = fn end
		end
	end
	local mt = getmetatable(target) or {}
	local oldIndex = mt.__index
	mt.__index = function(t, key)
		if type(key) == "string" and key:lower():find("tab") then
			return rawget(t, "MakeTab")
		end
		if type(oldIndex) == "function" then return oldIndex(t, key) elseif type(oldIndex) == "table" then return oldIndex[key] end
		return rawget(t, key)
	end
	setmetatable(target, mt)
	return target
end

function Library:MakeNotification(...)
	local NotificationConfig = ParseNotifArgs(ResolveArgs(Library, "MakeNotification", ...))
	task.spawn(function()
		NotificationConfig.Name    = NotificationConfig.Name    or "Notification"
		NotificationConfig.Content = NotificationConfig.Content or "Test"
		NotificationConfig.Image   = NotificationConfig.Image   or "rbxassetid://4384403532"
		NotificationConfig.Time    = NotificationConfig.Time    or 5

		local NotificationParent = SetProps(MakeElement("TFrame"), {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = NotificationHolder
		})

		local NotificationFrame = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(22, 17, 30), 0, 10), {
			Parent = NotificationParent,
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 0.15,
			AutomaticSize = Enum.AutomaticSize.Y
		}), {
			MakeElement("Stroke", ACCENT, 1.2),
			MakeElement("Padding", 12, 12, 12, 12),
			SetProps(MakeElement("Image", NotificationConfig.Image), {
				Size = UDim2.new(0, 20, 0, 20),
				ImageColor3 = ACCENT_TEXT,
				Name = "Icon"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Name, 15), {
				Size = UDim2.new(1, -30, 0, 20),
				Position = UDim2.new(0, 30, 0, 0),
				Font = Enum.Font.GothamBold,
				TextColor3 = Color3.fromRGB(245, 240, 255),
				Name = "Title"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Content, 14), {
				Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.new(0, 0, 0, 25),
				Font = Enum.Font.GothamSemibold,
				Name = "Content",
				AutomaticSize = Enum.AutomaticSize.Y,
				TextColor3 = Color3.fromRGB(200, 190, 220),
				TextWrapped = true
			})
		})

		TweenService:Create(NotificationFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0,0,0,0)}):Play()
		task.wait(NotificationConfig.Time)
		TweenService:Create(NotificationFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Position = UDim2.new(1,0,0,0)}):Play()
		task.wait(0.8)
		NotificationParent:Destroy()
	end)
end

function Library:MakeWindow(...)
	local FirstTab = true
	local Minimized = false
	local UIHidden = false

	local WindowConfig = ParseWindowArgs(ResolveArgs(Library, "MakeWindow", ...))
	WindowConfig = WindowConfig or {}
	WindowConfig.Name            = WindowConfig.Name or WindowConfig.name or WindowConfig.Title or WindowConfig.title or "NightSystem"
	WindowConfig.HidePremium     = WindowConfig.HidePremium or WindowConfig.hidePremium or false
	WindowConfig.ConfigFolder    = WindowConfig.ConfigFolder or WindowConfig.configFolder or WindowConfig.Folder or WindowConfig.folder or WindowConfig.Name
	WindowConfig.SaveConfig      = (WindowConfig.SaveConfig ~= nil and WindowConfig.SaveConfig) or (WindowConfig.saveConfig ~= nil and WindowConfig.saveConfig) or false
	if WindowConfig.IntroEnabled == nil and WindowConfig.introEnabled == nil then WindowConfig.IntroEnabled = true else WindowConfig.IntroEnabled = (WindowConfig.IntroEnabled or WindowConfig.introEnabled) end
	WindowConfig.CloseCallback   = WindowConfig.CloseCallback or WindowConfig.closeCallback or function() end
	if WindowConfig.ShowIcon == nil and WindowConfig.showIcon == nil then WindowConfig.ShowIcon = true else WindowConfig.ShowIcon = (WindowConfig.ShowIcon or WindowConfig.showIcon) end
	
	local activeLogoUrl = WindowConfig.CustomLogo or WindowConfig.customLogo or (Library.CustomLogoUrl ~= "" and Library.CustomLogoUrl) or WindowConfig.Icon or WindowConfig.icon or Library.FixedIconId
	local ResolvedLogo = LoadCustomAsset(activeLogoUrl, Library.FixedIconId)

	local activeBgUrl = (Library.SelectedBackground == "Kein Hintergrund (Aus)" and nil) or Library.ActiveBackgroundUrl or WindowConfig.CustomBackground or WindowConfig.customBackground or (Library.CustomBackgroundUrl ~= "" and Library.CustomBackgroundUrl)
	local ResolvedBackground = activeBgUrl and LoadCustomAsset(activeBgUrl, nil) or nil

	local activeSettingsUrl = WindowConfig.CustomSettingsIcon or WindowConfig.CustomSettings or WindowConfig.customSettingsIcon or WindowConfig.CustomSettingsUrl or Library.ActiveSettingsUrl or (Library.CustomSettingsUrl ~= "" and Library.CustomSettingsUrl) or (Library.CustomSettingsIconUrl ~= "" and Library.CustomSettingsIconUrl) or WindowConfig.SettingsIcon or WindowConfig.settingsIcon or Library.FixedSettingsIconId
	local ResolvedSettingsIcon = LoadCustomAsset(activeSettingsUrl, Library.FixedSettingsIconId)

	if savedUI and savedUI.ToggleKey and Enum.KeyCode[savedUI.ToggleKey] then
		WindowConfig.ToggleKey = Enum.KeyCode[savedUI.ToggleKey]
	end
	Library.ToggleKey = WindowConfig.ToggleKey or WindowConfig.toggleKey or Enum.KeyCode.LeftControl

	WindowConfig.Icon            = ResolvedLogo
	WindowConfig.IntroIcon       = ResolvedLogo
	WindowConfig.IntroToggleIcon = ResolvedLogo
	WindowConfig.SearchCallback  = WindowConfig.SearchCallback or WindowConfig.searchCallback or function() end
	WindowConfig.ToggleKey       = WindowConfig.ToggleKey or Enum.KeyCode.LeftControl

	Library.SearchRegistry = {}
	local ToggleKeyName = (typeof(WindowConfig.ToggleKey) == "EnumItem" and WindowConfig.ToggleKey.Name or tostring(WindowConfig.ToggleKey))

	Library.Folder  = WindowConfig.ConfigFolder
	Library.SaveCfg = WindowConfig.SaveConfig
	if WindowConfig.SaveConfig then
		pcall(function()
			if not isfolder(WindowConfig.ConfigFolder) then
				makefolder(WindowConfig.ConfigFolder)
			end
		end)
	end

	-- ╔══════════════════════════════════════════════════════════════╗
	-- ║   GLOBAL FEATURES (Anti-AFK, Fullbright, Potato, etc.)       ║
	-- ╚══════════════════════════════════════════════════════════════╝
	local AntiAfkConnection = nil
	local function SetAntiAfk(state)
		Library.AntiAfkEnabled = state
		if state then
			if not AntiAfkConnection then
				pcall(function()
					local VirtualUser = game:GetService("VirtualUser")
					AntiAfkConnection = LocalPlayer.Idled:Connect(function()
						VirtualUser:CaptureController()
						VirtualUser:ClickButton2(Vector2.new())
					end)
				end)
			end
		else
			if AntiAfkConnection then
				AntiAfkConnection:Disconnect()
				AntiAfkConnection = nil
			end
		end
	end
	if Library.AntiAfkEnabled then SetAntiAfk(true) end

	local FullbrightConnection = nil
	local origAmbient = Lighting.Ambient
	local origOutdoor = Lighting.OutdoorAmbient
	local origBrightness = Lighting.Brightness
	local origClockTime = Lighting.ClockTime
	local function SetFullbright(state)
		Library.FullbrightEnabled = state
		if state then
			if not FullbrightConnection then
				FullbrightConnection = RunService.RenderStepped:Connect(function()
					Lighting.Ambient = Color3.fromRGB(255, 255, 255)
					Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
					Lighting.Brightness = 2
					Lighting.ClockTime = 14
				end)
			end
		else
			if FullbrightConnection then
				FullbrightConnection:Disconnect()
				FullbrightConnection = nil
				Lighting.Ambient = origAmbient
				Lighting.OutdoorAmbient = origOutdoor
				Lighting.Brightness = origBrightness
				Lighting.ClockTime = origClockTime
			end
		end
	end
	if Library.FullbrightEnabled then SetFullbright(true) end

	local function SetPotatoMode(state)
		Library.PotatoModeEnabled = state
		pcall(function()
			Lighting.GlobalShadows = not state
			for _, v in pairs(game:GetService("Workspace"):GetDescendants()) do
				if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
					v.Enabled = not state
				end
			end
		end)
	end
	if Library.PotatoModeEnabled then SetPotatoMode(true) end

	local function ApplyFpsCap(cap)
		Library.TargetFps = cap
		pcall(function()
			if setfpscap then setfpscap(cap) end
		end)
	end
	if Library.TargetFps and Library.TargetFps ~= 60 then ApplyFpsCap(Library.TargetFps) end

	local BlurEffect = nil
	local function SetBlurState(enabled)
		if enabled then
			if not BlurEffect then
				BlurEffect = Instance.new("BlurEffect")
				BlurEffect.Size = 14
				BlurEffect.Parent = Lighting
			end
		else
			if BlurEffect then
				BlurEffect:Destroy()
				BlurEffect = nil
			end
		end
	end

	-- Live Watermark HUD
	local WatermarkFrame = nil
	local WatermarkConn = nil
	local function SetWatermarkState(enabled)
		Library.WatermarkEnabled = enabled
		if enabled then
			if not WatermarkFrame then
				WatermarkFrame = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(16, 12, 22), 0, 8), {
					Parent = Container,
					Size = UDim2.new(0, 240, 0, 26),
					Position = UDim2.new(1, -260, 0, 15),
					BackgroundTransparency = 0.25,
					ZIndex = 999
				}), {
					MakeElement("Stroke", ACCENT, 1),
					SetProps(MakeElement("Label", "NightSystem | FPS: ... | Ping: ...", 12), {
						Size = UDim2.new(1, -12, 1, 0),
						Position = UDim2.new(0, 10, 0, 0),
						TextColor3 = Color3.fromRGB(240, 235, 250),
						Name = "HUDText"
					})
				})
				local lastT = tick()
				local frames = 0
				WatermarkConn = RunService.RenderStepped:Connect(function()
					frames = frames + 1
					local now = tick()
					if now - lastT >= 0.5 then
						local fps = math.floor(frames / (now - lastT))
						frames = 0
						lastT = now
						local ping = 0
						pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
						if WatermarkFrame and WatermarkFrame:FindFirstChild("HUDText") then
							WatermarkFrame.HUDText.Text = "NightSystem | " .. tostring(fps) .. " FPS | " .. tostring(ping) .. " ms"
						end
					end
				end)
			end
		else
			if WatermarkConn then WatermarkConn:Disconnect(); WatermarkConn = nil end
			if WatermarkFrame then WatermarkFrame:Destroy(); WatermarkFrame = nil end
		end
	end
	if Library.WatermarkEnabled ~= false then SetWatermarkState(true) end

	local TabHolder = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255,255,255), 4), {
		Size = UDim2.new(1, 0, 1, -50)
	}), {
		MakeElement("List"),
		MakeElement("Padding", 8, 0, 0, 8)
	}), "Divider")

	AddConnection(TabHolder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		TabHolder.CanvasSize = UDim2.new(0, 0, 0, TabHolder.UIListLayout.AbsoluteContentSize.Y + 16)
	end)

	local function TopIcon(xOffset)
		return SetProps(MakeElement("Button"), {
			Size = UDim2.new(0, 28, 0, 28),
			Position = UDim2.new(1, xOffset, 0, 11),
			BackgroundTransparency = 1
		})
	end

	local SearchBtn = SetChildren(TopIcon(-165), {
		SetChildren(SetProps(MakeElement("TFrame"), {
			Size = UDim2.new(0, 12, 0, 12),
			Position = UDim2.new(0, 6, 0, 6),
			Name = "Glass"
		}), {
			MakeElement("Corner", 1),
			AddThemeObject(SetProps(MakeElement("Stroke"), {Thickness = 1.6}), "TextDark")
		}),
		AddThemeObject(SetProps(MakeElement("Frame"), {
			Size = UDim2.new(0, 7, 0, 1.6),
			Position = UDim2.new(0, 16, 0, 18),
			Rotation = 45,
			Name = "Handle"
		}), "TextDark")
	})

	local SettingsBtn = SetChildren(TopIcon(-133), {
		AddThemeObject(SetProps(MakeElement("Image", ResolvedSettingsIcon), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 18, 0, 18),
			Name = "Ico"
		}), "TextDark")
	})

	local MinimizeBtn = SetChildren(TopIcon(-101), {
		AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072706796"), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 18, 0, 18),
			Rotation = 180,
			Name = "Ico"
		}), "TextDark")
	})

	local HideBtn = SetChildren(TopIcon(-69), {
		AddThemeObject(SetProps(MakeElement("Frame"), {
			Size = UDim2.new(0, 13, 0, 1.6),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Name = "Ico"
		}), "TextDark")
	})

	local CloseBtn = SetChildren(TopIcon(-37), {
		AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072725342"), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 17, 0, 17),
			Name = "Ico"
		}), "TextDark")
	})

	for _, Btn in pairs({SearchBtn, SettingsBtn, MinimizeBtn, HideBtn, CloseBtn}) do
		Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = Btn})
		Btn.BackgroundColor3 = Library.Themes[Library.SelectedTheme].Control
		AddConnection(Btn.MouseEnter, function()
			TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.55}):Play()
		end)
		AddConnection(Btn.MouseLeave, function()
			TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
		end)
	end

	local DragPoint = SetProps(MakeElement("TFrame"), {Size = UDim2.new(1, 0, 0, 50)})

	-- ╔══════════════════════════════════════════════════════════════╗
	-- ║   BOTTOM AVATAR & NIGHTSYSTEM PROFILE BUTTON                 ║
	-- ╚══════════════════════════════════════════════════════════════╝
	local ProfileBg = AddThemeObject(SetProps(MakeElement("Frame"), {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1
	}), "Control")

	local ProfileButton = SetChildren(SetProps(MakeElement("Button"), {
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.new(0, 0, 1, -50),
		BackgroundTransparency = 1,
		Name = "ProfileButton"
	}), {
		ProfileBg,
		AddThemeObject(SetProps(MakeElement("Frame"), {Size = UDim2.new(1,0,0,1)}), "Stroke"),
		AddThemeObject(SetChildren(SetProps(MakeElement("Frame"), {
			AnchorPoint = Vector2.new(0,0.5),
			Size = UDim2.new(0,32,0,32),
			Position = UDim2.new(0,10,0.5,0),
			BackgroundTransparency = 0.2,
			Name = "AvatarFrame"
		}), {
			SetProps(MakeElement("Image", "https://www.roblox.com/headshot-thumbnail/image?userId="..(LocalPlayer and LocalPlayer.UserId or 0).."&width=420&height=420&format=png"), {Size = UDim2.new(1,0,1,0)}),
			AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://4031889928"), {Size = UDim2.new(1,0,1,0)}), "Sidebar"),
			MakeElement("Corner", 1)
		}), "Divider"),
		SetChildren(SetProps(MakeElement("TFrame"), {
			AnchorPoint = Vector2.new(0,0.5),
			Size = UDim2.new(0,32,0,32),
			Position = UDim2.new(0,10,0.5,0)
		}), {
			AddThemeObject(MakeElement("Stroke"), "Stroke"),
			MakeElement("Corner", 1)
		}),
		AddThemeObject(SetProps(MakeElement("Label", "NightSystem", WindowConfig.HidePremium and 14 or 13), {
			Size = UDim2.new(1,-60,0,13),
			Position = WindowConfig.HidePremium and UDim2.new(0,50,0,19) or UDim2.new(0,50,0,12),
			Font = Enum.Font.GothamSemibold,
			ClipsDescendants = true,
			Name = "LabelTitle"
		}), "Text"),
		SetProps(MakeElement("Label", ".gg/8nKxKcerCv", 12), {
			Size = UDim2.new(1,-60,0,12),
			Position = UDim2.new(0,50,1,-25),
			Visible = not WindowConfig.HidePremium,
			TextColor3 = ACCENT,
			Name = "LabelLink"
		})
	})

	AddConnection(ProfileButton.MouseEnter, function()
		TweenService:Create(ProfileBg, TweenInfo.new(0.18), {BackgroundTransparency = 0.6}):Play()
	end)
	AddConnection(ProfileButton.MouseLeave, function()
		TweenService:Create(ProfileBg, TweenInfo.new(0.18), {BackgroundTransparency = 1}):Play()
	end)

	local WindowStuff = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 10), {
		Size = UDim2.new(0, 150, 1, -50),
		Position = UDim2.new(0, 0, 0, 50)
	}), {
		AddThemeObject(SetProps(MakeElement("Frame"), {Size = UDim2.new(1,0,0,10), Position = UDim2.new(0,0,0,0)}), "Sidebar"),
		AddThemeObject(SetProps(MakeElement("Frame"), {Size = UDim2.new(0,10,1,0), Position = UDim2.new(1,-10,0,0)}), "Sidebar"),
		AddThemeObject(SetProps(MakeElement("Frame"), {Size = UDim2.new(0,1,1,0), Position = UDim2.new(1,-1,0,0)}), "Stroke"),
		TabHolder,
		ProfileButton
	}), "Sidebar")

	local WindowIcon = SetProps(MakeElement("Image", ResolvedLogo), {
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(0, 14, 0, 9),
		ImageColor3 = Color3.fromRGB(255, 255, 255),
		Visible = WindowConfig.ShowIcon and true or false,
		Name = "WindowIcon"
	})
	Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = WindowIcon})

	local WindowName = AddThemeObject(SetProps(MakeElement("Label", WindowConfig.Name, 18), {
		Size = UDim2.new(1,-180,0,50),
		Position = UDim2.new(0, WindowConfig.ShowIcon and 54 or 18, 0, 0),
		Font = Enum.Font.GothamBold,
		TextYAlignment = Enum.TextYAlignment.Center
	}), "Text")

	local SearchBox = AddThemeObject(Create("TextBox", {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = "Search...",
		PlaceholderColor3 = Color3.fromRGB(130, 120, 150),
		Font = Enum.Font.GothamSemibold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Name = "Input"
	}), "Text")

	local SearchFrame = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 7), {
		Size = UDim2.new(0, 250, 0, 26),
		Position = UDim2.new(0, 168, 0, 12),
		BackgroundColor3 = Library.Themes[Library.SelectedTheme].Control,
		BackgroundTransparency = 0.35,
		Visible = false,
		Name = "SearchFrame"
	}), {
		AddThemeObject(MakeElement("Stroke"), "Stroke"),
		SearchBox
	})

	local WindowTopBarLine = AddThemeObject(SetProps(MakeElement("Frame"), {
		Size = UDim2.new(1,0,0,1),
		Position = UDim2.new(0,0,1,-1)
	}), "Stroke")

	local WindowBackgroundImage = Create("ImageLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		Image = ResolvedBackground or "",
		ScaleType = Enum.ScaleType.Crop,
		ImageTransparency = Library.BackgroundTransparency or 0.35,
		Visible = (ResolvedBackground ~= nil and ResolvedBackground ~= ""),
		ZIndex = 1,
		Name = "WindowBackgroundImage"
	})
	Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = WindowBackgroundImage})

	local MainWindow = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 10), {
		Parent = Container,
		Position = UDim2.new(0.5,-320,0.5,-169),
		Size = UDim2.new(0,640,0,338),
		ClipsDescendants = true,
		BackgroundTransparency = Library.Transparency.Window
	}), {
		WindowBackgroundImage,
		SetChildren(SetProps(MakeElement("TFrame"), {Size = UDim2.new(1,0,0,50), Name = "TopBar"}), {
			WindowIcon,
			WindowName,
			SearchFrame,
			WindowTopBarLine,
			SearchBtn,
			SettingsBtn,
			MinimizeBtn,
			HideBtn,
			CloseBtn
		}),
		DragPoint,
		WindowStuff
	}), "Main")

	local SetResizingCallback = MakeDraggable(DragPoint, MainWindow)

	Library.MinimizeSettings = {
		ReopenMode = "DoubleClick",
		IconSize   = 46,
	}

	local MiniIcon = Create("Frame", {
		Parent = Container,
		Size = UDim2.new(0, Library.MinimizeSettings.IconSize, 0, Library.MinimizeSettings.IconSize),
		Position = UDim2.new(0.5, -23, 0, 20),
		BackgroundColor3 = Library.Themes[Library.SelectedTheme].Main,
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 50,
		Name = "MiniIcon"
	})
	Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = MiniIcon})
	local MiniStroke = Create("UIStroke", {Color = ACCENT, Thickness = 1.4, Transparency = 0.2, Parent = MiniIcon})

	local MiniIconBadge = Create("ImageLabel", {
		Parent = MiniIcon,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -3, 0, 3),
		Size = UDim2.new(0, 16, 0, 16),
		BackgroundTransparency = 1,
		Image = ResolvedLogo,
		ZIndex = 52
	})
	Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = MiniIconBadge})

	local MiniLogo = Create("TextLabel", {
		Parent = MiniIcon,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "N",
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = ACCENT_TEXT,
		ZIndex = 51,
		Name = "FixedLogo"
	})

	local PulseRing = Create("UIStroke", {Color = ACCENT, Thickness = 1, Transparency = 0.7, Parent = MiniIcon})
	task.spawn(function()
		while Library:IsRunning() do
			TweenService:Create(PulseRing, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {Transparency = 0.95}):Play()
			task.wait(1.2)
			if not Library:IsRunning() then break end
			TweenService:Create(PulseRing, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {Transparency = 0.7}):Play()
			task.wait(1.2)
		end
	end)

	do
		local Dragging, DragStart, StartPos = false, nil, nil
		local MovedSinceDown = false

		AddConnection(MiniIcon.InputBegan, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				Dragging = true
				MovedSinceDown = false
				DragStart = Input.Position
				StartPos = MiniIcon.Position
			end
		end)

		AddConnection(UserInputService.InputChanged, function(Input)
			if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
				local Delta = Input.Position - DragStart
				if Delta.Magnitude > 3 then MovedSinceDown = true end
				MiniIcon.Position = UDim2.new(
					StartPos.X.Scale, StartPos.X.Offset + Delta.X,
					StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y
				)
			end
		end)

		AddConnection(UserInputService.InputEnded, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				Dragging = false
			end
		end)

		local LastClick = 0
		AddConnection(MiniIcon.InputEnded, function(Input)
			if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
			if MovedSinceDown then return end

			if Library.MinimizeSettings.ReopenMode == "Click" then
				Library:ShowFromMini(MainWindow, MiniIcon)
				return
			end

			local Now = tick()
			if Now - LastClick < 0.35 then
				Library:ShowFromMini(MainWindow, MiniIcon)
				LastClick = 0
			else
				LastClick = Now
			end
		end)
	end

	function Library:ShowFromMini(TargetWindow, TargetIcon)
		TargetIcon.Visible = false
		TargetWindow.Visible = true
		TargetWindow.Size = UDim2.new(0, 0, 0, 0)
		TargetWindow.Position = UDim2.new(0.5, -320, 0.5, -169)
		TweenService:Create(TargetWindow, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 640, 0, 338)
		}):Play()
		UIHidden = false
		if Library.BlurEnabled then SetBlurState(true) end
	end

	local MobileReopenButton = SetChildren(SetProps(MakeElement("Button"), {
		Parent = Container,
		Size = UDim2.new(0,40,0,40),
		Position = UDim2.new(0.5,-20,0,20),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Library.Themes[Library.SelectedTheme].Main,
		Visible = false
	}), {
		AddThemeObject(SetProps(MakeElement("Image", ResolvedLogo), {
			AnchorPoint = Vector2.new(0.5,0.5),
			Position = UDim2.new(0.5,0,0.5,0),
			Size = UDim2.new(0.7,0,0.7,0),
		}), "Text"),
		MakeElement("Corner", 1)
	})

	local function HideUI()
		MainWindow.Visible = false
		MiniIcon.Visible = true
		UIHidden = true
		if Library.BlurEnabled then SetBlurState(false) end
		if UserInputService.TouchEnabled then MobileReopenButton.Visible = false end
	end

	AddConnection(CloseBtn.MouseButton1Up, function()
		HideUI()
		WindowConfig.CloseCallback()
	end)

	AddConnection(HideBtn.MouseButton1Up, function()
		HideUI()
	end)

	local function ResetSearch()
		for _, Entry in ipairs(Library.SearchRegistry) do
			if Entry.Frame and Entry.Frame.Parent then
				Entry.Frame.Visible = true
				if Entry.Section then Entry.Section.Visible = true end
			end
		end
	end

	local function DoSearch(Query)
		Query = string.lower(Query or "")
		if Query == "" then ResetSearch() return end
		local Sections, FirstHit = {}, nil
		for _, Entry in ipairs(Library.SearchRegistry) do
			if Entry.Frame and Entry.Frame.Parent then
				local Match = string.find(string.lower(GetElementName(Entry.Frame)), Query, 1, true) ~= nil
				Entry.Frame.Visible = Match
				if Match then
					FirstHit = FirstHit or Entry
					if Entry.Section then Sections[Entry.Section] = true end
				end
			end
		end
		for _, Entry in ipairs(Library.SearchRegistry) do
			if Entry.Section and Entry.Section.Parent then
				Entry.Section.Visible = Sections[Entry.Section] == true
			end
		end
		if FirstHit and FirstHit.Container and not FirstHit.Container.Visible and FirstHit.Activate then
			FirstHit.Activate()
		end
	end

	AddConnection(SearchBox:GetPropertyChangedSignal("Text"), function()
		DoSearch(SearchBox.Text)
	end)

	AddConnection(SearchBtn.MouseButton1Up, function()
		SearchFrame.Visible = not SearchFrame.Visible
		if SearchFrame.Visible then
			SearchBox:CaptureFocus()
		else
			SearchBox.Text = ""
			SearchBox:ReleaseFocus()
			ResetSearch()
		end
		WindowConfig.SearchCallback(SearchFrame.Visible)
	end)

	local function SetUIVisible(State)
		UIHidden = not State
		MainWindow.Visible = State
		MiniIcon.Visible = false
		if Library.BlurEnabled then SetBlurState(State) end
		if UserInputService.TouchEnabled then MobileReopenButton.Visible = not State end
	end

	AddConnection(UserInputService.InputBegan, function(Input, Processed)
		if Processed then return end
		if UserInputService:GetFocusedTextBox() then return end
		if Input.KeyCode == WindowConfig.ToggleKey then
			SetUIVisible(UIHidden)
		end
	end)

	AddConnection(MobileReopenButton.Activated, function()
		MainWindow.Visible = true
		MobileReopenButton.Visible = false
		MiniIcon.Visible = false
		UIHidden = false
		if Library.BlurEnabled then SetBlurState(true) end
	end)

	AddConnection(MinimizeBtn.MouseButton1Up, function()
		if Minimized then
			TweenService:Create(MainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0,640,0,338)}):Play()
			MinimizeBtn.Ico.Rotation = 180
			task.wait(.02)
			MainWindow.ClipsDescendants = false
			WindowStuff.Visible = true
			WindowTopBarLine.Visible = true
		else
			MainWindow.ClipsDescendants = true
			WindowTopBarLine.Visible = false
			MinimizeBtn.Ico.Rotation = 0
			TweenService:Create(MainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, math.max(WindowName.TextBounds.X + 210, 320), 0, 50)}):Play()
			task.wait(0.1)
			WindowStuff.Visible = false
		end
		Minimized = not Minimized
	end)

	local function LoadSequence()
		MainWindow.Visible = false

		local LoaderFrame = Create("Frame", {
			Parent = Container,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.53, 0),
			Size = UDim2.new(0, 260, 0, 74),
			BackgroundColor3 = Color3.fromRGB(16, 12, 22),
			BackgroundTransparency = 0.20,
			BorderSizePixel = 0,
			ZIndex = 10
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = LoaderFrame})

		local FrameStroke = Create("UIStroke", {
			Parent = LoaderFrame,
			Color = ACCENT,
			Thickness = 1.0,
			Transparency = 0.4
		})

		local LogoIcon = Create("ImageLabel", {
			Parent = LoaderFrame,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, -6),
			Size = UDim2.new(0, 38, 0, 38),
			Image = ResolvedLogo,
			BackgroundTransparency = 1,
			ImageTransparency = 1,
			ZIndex = 11
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = LogoIcon})

		local TitleLabel = Create("TextLabel", {
			Parent = LoaderFrame,
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 58, 0, 11),
			Size = UDim2.new(1, -68, 0, 18),
			Text = WindowConfig.Name,
			TextColor3 = Color3.fromRGB(245, 240, 255),
			TextTransparency = 1,
			TextSize = 15,
			Font = Enum.Font.GothamBlack,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11
		})

		local StatusLabel = Create("TextLabel", {
			Parent = LoaderFrame,
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 58, 0, 32),
			Size = UDim2.new(1, -68, 0, 14),
			Text = "Initializing...",
			TextColor3 = ACCENT_TEXT,
			TextTransparency = 1,
			TextSize = 11,
			Font = Enum.Font.GothamSemibold,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11
		})

		local BarBG = Create("Frame", {
			Parent = LoaderFrame,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -28, 0, 3),
			BackgroundColor3 = Color3.fromRGB(35, 26, 50),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			ZIndex = 11
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = BarBG})

		local BarFill = Create("Frame", {
			Parent = BarBG,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = ACCENT,
			BorderSizePixel = 0,
			ZIndex = 12
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = BarFill})

		TweenService:Create(LoaderFrame, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundTransparency = 0.20
		}):Play()
		TweenService:Create(LogoIcon, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			ImageTransparency = 0
		}):Play()
		task.wait(0.15)
		TweenService:Create(TitleLabel,  TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
		TweenService:Create(StatusLabel, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()

		local steps = {
			{ text = "Loading modules...",  progress = 0.25, delay = 0.25 },
			{ text = "Building UI...",      progress = 0.55, delay = 0.35 },
			{ text = "Applying violet...",  progress = 0.80, delay = 0.30 },
			{ text = "Almost ready...",     progress = 0.95, delay = 0.25 },
		}

		for _, step in ipairs(steps) do
			task.wait(step.delay)
			StatusLabel.Text = step.text
			TweenService:Create(BarFill, TweenInfo.new(step.delay + 0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Size = UDim2.new(step.progress, 0, 1, 0)
			}):Play()
			TweenService:Create(FrameStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Transparency = 0.1}):Play()
			task.wait(0.15)
			TweenService:Create(FrameStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Transparency = 0.4}):Play()
		end

		task.wait(0.15)
		StatusLabel.Text = "Ready!"
		TweenService:Create(BarFill, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 1, 0)
		}):Play()
		TweenService:Create(FrameStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Transparency = 0}):Play()
		task.wait(0.35)

		TweenService:Create(LoaderFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.47, 0)
		}):Play()
		TweenService:Create(LogoIcon,    TweenInfo.new(0.25, Enum.EasingStyle.Quad), {ImageTransparency = 1}):Play()
		TweenService:Create(TitleLabel,  TweenInfo.new(0.25, Enum.EasingStyle.Quad), {TextTransparency  = 1}):Play()
		TweenService:Create(StatusLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {TextTransparency  = 1}):Play()
		TweenService:Create(FrameStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Transparency      = 1}):Play()
		task.wait(0.35)

		LoaderFrame:Destroy()
		MainWindow.Visible = true
		if Library.BlurEnabled then SetBlurState(true) end
	end

	if WindowConfig.IntroEnabled then LoadSequence() end

	-- ╔══════════════════════════════════════════════════════════════╗
	-- ║   KRASSE CHARAKTER & SPIEL STATUS KARTE (INSPECTOR OVERLAY)  ║
	-- ╚══════════════════════════════════════════════════════════════╝
	local UISettingsPanel
	local ProfileCard = AddThemeObject(SetProps(MakeElement("RoundFrame", Color3.fromRGB(20, 15, 28), 0, 10), {
		Parent = MainWindow,
		Position = UDim2.new(0, 155, 0, 54),
		Size = UDim2.new(1, -160, 1, -58),
		Visible = false,
		ZIndex = 40,
		Name = "ProfileCard",
		BackgroundTransparency = 0.05
	}), "Second")

	local ProfileCardStroke = Create("UIStroke", {
		Color = ACCENT,
		Thickness = 1.3,
		Transparency = 0.2,
		Parent = ProfileCard
	})

	local CardTopBar = SetChildren(SetProps(MakeElement("TFrame"), {
		Size = UDim2.new(1, 0, 0, 32),
		Parent = ProfileCard,
		Name = "Top"
	}), {
		SetProps(MakeElement("Label", "⚡ STATUS & INSPECTOR", 13), {
			Size = UDim2.new(1, -50, 1, 0),
			Position = UDim2.new(0, 12, 0, 0),
			Font = Enum.Font.GothamBold,
			TextColor3 = ACCENT_TEXT
		}),
		AddThemeObject(SetProps(MakeElement("Frame"), {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 1, -1)
		}), "Stroke")
	})

	local CardCloseBtn = SetChildren(SetProps(MakeElement("Button"), {
		Size = UDim2.new(0, 24, 0, 24),
		Position = UDim2.new(1, -28, 0, 4),
		Parent = CardTopBar,
		BackgroundColor3 = Color3.fromRGB(45, 35, 60),
		BackgroundTransparency = 0.5
	}), {
		MakeElement("Corner", 0, 6),
		SetProps(MakeElement("Label", "✕", 12), {
			Size = UDim2.new(1, 0, 1, 0),
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.fromRGB(220, 210, 240),
			TextXAlignment = Enum.TextXAlignment.Center
		})
	})

	-- Linker Bereich: Cybernetic ESP & Skeleton Box
	local EspBoxHolder = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(15, 11, 22), 0, 8), {
		Parent = ProfileCard,
		Position = UDim2.new(0, 10, 0, 38),
		Size = UDim2.new(0, 150, 1, -48),
		BackgroundTransparency = 0.2,
		Name = "EspBox"
	}), {
		Create("UIStroke", {Color = ACCENT, Thickness = 1.2, Transparency = 0.3})
	})

	local function Bracket(pos, rot)
		local b = Create("Frame", {
			Parent = EspBoxHolder,
			Size = UDim2.new(0, 10, 0, 10),
			Position = pos,
			BackgroundTransparency = 1,
			ZIndex = 5
		})
		Create("Frame", {Parent = b, Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = ACCENT, BorderSizePixel = 0})
		Create("Frame", {Parent = b, Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = ACCENT, BorderSizePixel = 0})
		if rot then b.Rotation = rot end
		return b
	end
	Bracket(UDim2.new(0, 3, 0, 3), 0)
	Bracket(UDim2.new(1, -13, 0, 3), 90)
	Bracket(UDim2.new(1, -13, 1, -13), 180)
	Bracket(UDim2.new(0, 3, 1, -13), 270)

	Create("ImageLabel", {
		Parent = EspBoxHolder,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.48, 0),
		Size = UDim2.new(0, 130, 0, 165),
		BackgroundTransparency = 1,
		Image = "https://www.roblox.com/avatar-thumbnail/image?userId="..(LocalPlayer and LocalPlayer.UserId or 0).."&width=420&height=420&format=png",
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2
	})

	local SkeletonContainer = Create("Frame", {
		Parent = EspBoxHolder,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Name = "Skeleton"
	})

	local function SkeleJoint(x, y, r)
		local j = Create("Frame", {
			Parent = SkeletonContainer,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, 0, y, 0),
			Size = UDim2.new(0, r or 5, 0, r or 5),
			BackgroundColor3 = ACCENT,
			BorderSizePixel = 0,
			ZIndex = 8
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = j})
		return j
	end

	local function SkeleBone(x1, y1, x2, y2, thick)
		local bone = Create("Frame", {
			Parent = SkeletonContainer,
			BackgroundColor3 = ACCENT,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			ZIndex = 7
		})
		local function updateBone()
			local p1 = Vector2.new(x1 * EspBoxHolder.AbsoluteSize.X, y1 * EspBoxHolder.AbsoluteSize.Y)
			local p2 = Vector2.new(x2 * EspBoxHolder.AbsoluteSize.X, y2 * EspBoxHolder.AbsoluteSize.Y)
			local dist = (p2 - p1).Magnitude
			local angle = math.deg(math.atan2(p2.Y - p1.Y, p2.X - p1.X))
			local mid = (p1 + p2) / 2
			bone.Size = UDim2.new(0, dist, 0, thick or 1.6)
			bone.Position = UDim2.new(0, mid.X, 0, mid.Y)
			bone.AnchorPoint = Vector2.new(0.5, 0.5)
			bone.Rotation = angle
		end
		task.defer(updateBone)
		AddConnection(EspBoxHolder:GetPropertyChangedSignal("AbsoluteSize"), updateBone)
		return bone
	end

	local SkeleHead = Create("Frame", {
		Parent = SkeletonContainer,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.22, 0),
		Size = UDim2.new(0, 22, 0, 22),
		BackgroundTransparency = 1,
		ZIndex = 8
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = SkeleHead})
	Create("UIStroke", {Color = ACCENT, Thickness = 1.4, Parent = SkeleHead})

	SkeleBone(0.5, 0.27, 0.5, 0.52, 1.8)
	SkeleBone(0.34, 0.33, 0.66, 0.33, 1.6)
	SkeleBone(0.34, 0.33, 0.25, 0.46, 1.5)
	SkeleBone(0.25, 0.46, 0.21, 0.58, 1.5)
	SkeleBone(0.66, 0.33, 0.75, 0.46, 1.5)
	SkeleBone(0.75, 0.46, 0.79, 0.58, 1.5)
	SkeleBone(0.40, 0.52, 0.60, 0.52, 1.6)
	SkeleBone(0.40, 0.52, 0.37, 0.68, 1.5)
	SkeleBone(0.37, 0.68, 0.35, 0.85, 1.5)
	SkeleBone(0.60, 0.52, 0.63, 0.68, 1.5)
	SkeleBone(0.63, 0.68, 0.65, 0.85, 1.5)

	SkeleJoint(0.34, 0.33, 5)
	SkeleJoint(0.66, 0.33, 5)
	SkeleJoint(0.25, 0.46, 4)
	SkeleJoint(0.75, 0.46, 4)
	SkeleJoint(0.21, 0.58, 4)
	SkeleJoint(0.79, 0.58, 4)
	SkeleJoint(0.37, 0.68, 4)
	SkeleJoint(0.63, 0.68, 4)
	SkeleJoint(0.35, 0.85, 4)
	SkeleJoint(0.65, 0.85, 4)

	local EspTagTop = SetProps(MakeElement("Label", "[ STATUS: ACTIVE ]", 10), {
		Parent = EspBoxHolder,
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 0, 4),
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(0, 255, 170),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 9
	})

	local EspTagBottom = SetProps(MakeElement("Label", "HP: 100/100 | DIST: 0m", 9), {
		Parent = EspBoxHolder,
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -16),
		Font = Enum.Font.GothamBold,
		TextColor3 = ACCENT_TEXT,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 9
	})

	local HealthBarBG = Create("Frame", {
		Parent = EspBoxHolder,
		Size = UDim2.new(0, 3, 0.65, 0),
		Position = UDim2.new(0, 5, 0.20, 0),
		BackgroundColor3 = Color3.fromRGB(30, 20, 40),
		BorderSizePixel = 0,
		ZIndex = 8
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = HealthBarBG})

	local HealthBarFill = Create("Frame", {
		Parent = HealthBarBG,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(0, 255, 140),
		BorderSizePixel = 0,
		ZIndex = 9
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = HealthBarFill})

	-- Rechter Bereich: Detaillierte Live-Statistiken
	local StatsScroll = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255,255,255), 4), {
		Parent = ProfileCard,
		Position = UDim2.new(0, 168, 0, 38),
		Size = UDim2.new(1, -178, 1, -48),
		ClipsDescendants = true
	}), {
		MakeElement("List", 0, 6),
		MakeElement("Padding", 4, 4, 4, 4)
	}), "Divider")

	AddConnection(StatsScroll.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		StatsScroll.CanvasSize = UDim2.new(0, 0, 0, StatsScroll.UIListLayout.AbsoluteContentSize.Y + 12)
	end)

	local function InfoRow(label, value, copyable)
		local row = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 6), {
			Parent = StatsScroll,
			Size = UDim2.new(1, 0, 0, 28)
		}), {
			AddThemeObject(SetProps(MakeElement("Label", label, 12), {
				Size = UDim2.new(0, 100, 1, 0),
				Position = UDim2.new(0, 8, 0, 0),
				Font = Enum.Font.GothamSemibold
			}), "TextDark"),
			SetProps(MakeElement("Label", tostring(value or "?"), 12), {
				Size = UDim2.new(1, copyable and -150 or -110, 1, 0),
				Position = UDim2.new(0, 105, 0, 0),
				Font = Enum.Font.GothamBold,
				TextColor3 = Color3.fromRGB(245, 240, 255),
				Name = "ValText",
				ClipsDescendants = true
			}),
			AddThemeObject(MakeElement("Stroke"), "Stroke")
		}), "Control")

		if copyable then
			local cBtn = Create("TextButton", {
				Parent = row,
				Size = UDim2.new(0, 42, 0, 20),
				Position = UDim2.new(1, -48, 0.5, -10),
				BackgroundColor3 = ACCENT,
				Text = "Kopie",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				AutoButtonColor = false
			})
			Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = cBtn})
			cBtn.MouseButton1Click:Connect(function()
				PlayClickSound()
				CopyToClipboard(value, label)
			end)
		end
		return row
	end

	local GameTitleName = "Roblox Experience"
	pcall(function()
		local Info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
		if Info and Info.Name then GameTitleName = Info.Name end
	end)

	local RowPlayerName = InfoRow("Name:", (LocalPlayer and LocalPlayer.Name or "?") .. " (@" .. (LocalPlayer and LocalPlayer.DisplayName or "?") .. ")")
	local RowPlayerId   = InfoRow("User ID:", tostring(LocalPlayer and LocalPlayer.UserId or "?"), true)
	local RowAccAge     = InfoRow("Account-Alter:", tostring(LocalPlayer and LocalPlayer.AccountAge or 0) .. " Tage")
	local RowHealth     = InfoRow("Gesundheit:", "100 / 100")
	local RowWalkSpeed  = InfoRow("Speed / Jump:", "16 / 50")
	local RowGameName   = InfoRow("Spiel:", GameTitleName)
	local RowPlaceId    = InfoRow("Place ID:", tostring(game.PlaceId), true)
	local RowJobId      = InfoRow("Job ID:", tostring(game.JobId), true)
	local RowPing       = InfoRow("Server Ping:", "... ms")
	local RowFps        = InfoRow("Server FPS:", "... FPS")
	local RowPlayers    = InfoRow("Spieler:", tostring(#Players:GetPlayers()) .. " Spieler")

	local ActionRow = Create("Frame", {
		Parent = StatsScroll,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1
	})
	Create("UIListLayout", {
		Parent = ActionRow,
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6)
	})

	local function ActionBtn(text, color, cb)
		local b = Create("TextButton", {
			Parent = ActionRow,
			Size = UDim2.new(0.32, -4, 1, 0),
			BackgroundColor3 = color or ACCENT,
			Text = text,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			AutoButtonColor = false
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = b})
		b.MouseButton1Click:Connect(function()
			PlayClickSound()
			cb()
		end)
		return b
	end

	ActionBtn("Rejoin", Color3.fromRGB(130, 95, 215), function()
		if #Players:GetPlayers() <= 1 then
			LocalPlayer:Kick("\n[NightSystem] Rejoining...")
			task.wait(0.2)
			TeleportService:Teleport(game.PlaceId, LocalPlayer)
		else
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
		end
	end)

	ActionBtn("Server Hop", Color3.fromRGB(60, 140, 220), function()
		Library:MakeNotification({Name = "Server Hop", Content = "Suche Server...", Time = 3})
		task.spawn(function()
			pcall(function()
				local raw = game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")
				local servers = HttpService:JSONDecode(raw)
				for _, s in ipairs(servers.data) do
					if s.playing < s.maxPlayers and s.id ~= game.JobId then
						TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
						break
					end
				end
			end)
		end)
	end)

	ActionBtn("Discord", Color3.fromRGB(88, 101, 242), function()
		CopyToClipboard("https://discord.gg/8nKxKcerCv", "Discord-Link kopiert")
	end)

	task.spawn(function()
		local fCount = 0
		local lTime = tick()
		while Library:IsRunning() do
			fCount = fCount + 1
			local cur = tick()
			if cur - lTime >= 0.5 then
				local fps = math.floor(fCount / (cur - lTime))
				fCount = 0
				lTime = cur
				local ping = 0
				pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
				if ProfileCard.Visible then
					if RowPing:FindFirstChild("ValText") then RowPing.ValText.Text = tostring(ping) .. " ms" end
					if RowFps:FindFirstChild("ValText") then RowFps.ValText.Text = tostring(fps) .. " FPS" end
					if RowPlayers:FindFirstChild("ValText") then RowPlayers.ValText.Text = tostring(#Players:GetPlayers()) .. " Spieler" end

					pcall(function()
						local char = LocalPlayer.Character
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						if hum then
							local hp = math.floor(hum.Health)
							local maxHp = math.floor(hum.MaxHealth)
							local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
							HealthBarFill.Size = UDim2.new(1, 0, ratio, 0)
							HealthBarFill.BackgroundColor3 = Color3.fromHSV(ratio * 0.33, 0.9, 1)
							if RowHealth:FindFirstChild("ValText") then RowHealth.ValText.Text = tostring(hp) .. " / " .. tostring(maxHp) end
							if RowWalkSpeed:FindFirstChild("ValText") then RowWalkSpeed.ValText.Text = tostring(math.floor(hum.WalkSpeed)) .. " / " .. tostring(math.floor(hum.JumpPower or hum.JumpHeight or 50)) end
							EspTagBottom.Text = "HP: " .. tostring(hp) .. "/" .. tostring(maxHp) .. " | DIST: 0m"
						end
					end)
				end
			end
			task.wait(0.25)
		end
	end)

	local ProfileCardOpen = false
	local function ToggleProfileCard()
		ProfileCardOpen = not ProfileCardOpen
		PlayClickSound()
		if ProfileCardOpen then
			if UISettingsPanel then UISettingsPanel.Visible = false end
			for _, ItemContainer in next, MainWindow:GetChildren() do
				if ItemContainer.Name == "ItemContainer" then ItemContainer.Visible = false end
			end
			ProfileCard.Visible = true
			ProfileCard.Size = UDim2.new(1, -170, 1, -68)
			ProfileCard.Position = UDim2.new(0, 160, 0, 59)
			ProfileCard.BackgroundTransparency = 0.5
			TweenService:Create(ProfileCard, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, -160, 1, -58),
				Position = UDim2.new(0, 155, 0, 54),
				BackgroundTransparency = 0.05
			}):Play()
		else
			TweenService:Create(ProfileCard, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
				Size = UDim2.new(1, -170, 1, -68),
				Position = UDim2.new(0, 160, 0, 59),
				BackgroundTransparency = 1
			}):Play()
			task.delay(0.2, function()
				if not ProfileCardOpen then
					ProfileCard.Visible = false
					for _, Tab in next, TabHolder:GetChildren() do
						if Tab:IsA("TextButton") and Tab:FindFirstChild("Title") and Tab.Title.Font == Enum.Font.GothamBold then
							for _, ic in next, MainWindow:GetChildren() do
								if ic.Name == "ItemContainer" then ic.Visible = true break end
							end
							break
						end
					end
				end
			end)
		end
	end

	AddConnection(ProfileButton.MouseButton1Click, ToggleProfileCard)
	AddConnection(CardCloseBtn.MouseButton1Click, ToggleProfileCard)

	-- ╔══════════════════════════════════════════════════════════════╗
	-- ║   MASSIV ERWEITERTES UI-EINSTELLUNGSPANEL                    ║
	-- ╚══════════════════════════════════════════════════════════════╝
	UISettingsPanel = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255,255,255), 5), {
		Size = UDim2.new(1, -150, 1, -50),
		Position = UDim2.new(0, 150, 0, 50),
		Parent = MainWindow,
		Visible = false,
		Name = "UISettingsPanel"
	}), {
		MakeElement("List", 0, 8),
		MakeElement("Padding", 14, 8, 14, 10)
	}), "Divider")

	AddConnection(UISettingsPanel.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		UISettingsPanel.CanvasSize = UDim2.new(0, 0, 0, UISettingsPanel.UIListLayout.AbsoluteContentSize.Y + 30)
	end)

	local function BuildUISettings()
		local function Row(name, height)
			return AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), {
				Size = UDim2.new(1, 0, 0, height or 38),
				Parent = UISettingsPanel
			}), {
				AddThemeObject(SetProps(MakeElement("Label", name, 15), {
					Size = UDim2.new(1, -12, 0, 20), Position = UDim2.new(0, 12, 0, 8),
					Font = Enum.Font.GothamSemibold
				}), "Text"),
				AddThemeObject(MakeElement("Stroke"), "Stroke")
			}), "Second")
		end

		local function Header(title)
			AddThemeObject(SetProps(MakeElement("Label", string.upper(title), 11), {
				Size = UDim2.new(1, -12, 0, 16),
				Position = UDim2.new(0, 6, 0, 0),
				Font = Enum.Font.GothamBold,
				Parent = UISettingsPanel,
				TextColor3 = ACCENT_SOFT
			}), "TextDark")
		end

		Header("Account & Spiel")

		local AccountRow = Row("Benutzer", 100)
		Create("ImageLabel", {
			Parent = AccountRow,
			Position = UDim2.new(0, 12, 0, 30),
			Size = UDim2.new(0, 42, 0, 42),
			BackgroundTransparency = 1,
			Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..(LocalPlayer and LocalPlayer.UserId or 0).."&width=150&height=150&format=png"
		})
		local AvatarCorner = Create("UICorner", {CornerRadius = UDim.new(1, 0)})
		AvatarCorner.Parent = AccountRow:GetChildren()[#AccountRow:GetChildren()]

		AddThemeObject(SetProps(MakeElement("Label", "Name: " .. (LocalPlayer and LocalPlayer.Name or "?") .. " (@" .. (LocalPlayer and LocalPlayer.DisplayName or "?") .. ")", 13), {
			Size = UDim2.new(1, -70, 0, 16), Position = UDim2.new(0, 64, 0, 28),
			Font = Enum.Font.GothamSemibold, Parent = AccountRow
		}), "Text")
		AddThemeObject(SetProps(MakeElement("Label", "ID: " .. (LocalPlayer and tostring(LocalPlayer.UserId) or "?"), 12), {
			Size = UDim2.new(1, -70, 0, 16), Position = UDim2.new(0, 64, 0, 48),
			Font = Enum.Font.GothamSemibold, Parent = AccountRow
		}), "TextDark")
		AddThemeObject(SetProps(MakeElement("Label", "Spiel: " .. GameTitleName, 12), {
			Size = UDim2.new(1, -70, 0, 16), Position = UDim2.new(0, 64, 0, 68),
			Font = Enum.Font.GothamSemibold, Parent = AccountRow
		}), "TextDark")

		Header("Performance, Grafik & FPS")

		local AfkRow = Row("Anti-AFK (Disconnect-Schutz)", 38)
		local AfkBtn = Create("TextButton", {
			Parent = AfkRow, Size = UDim2.new(0, 100, 0, 24), Position = UDim2.new(1, -112, 0, 7),
			BackgroundColor3 = Library.AntiAfkEnabled and ACCENT or Library.Themes[Library.SelectedTheme].Control,
			Text = Library.AntiAfkEnabled and "AN" or "Aus",
			TextColor3 = Color3.fromRGB(220, 210, 240), Font = Enum.Font.GothamSemibold, TextSize = 12, AutoButtonColor = false
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = AfkBtn})
		AfkBtn.MouseButton1Click:Connect(function()
			PlayClickSound()
			SetAntiAfk(not Library.AntiAfkEnabled)
			AfkBtn.Text = Library.AntiAfkEnabled and "AN" or "Aus"
			AfkBtn.BackgroundColor3 = Library.AntiAfkEnabled and ACCENT or Library.Themes[Library.SelectedTheme].Control
			SaveUIConfig()
			Library:MakeNotification({Name = "Anti-AFK", Content = Library.AntiAfkEnabled and "Aktiviert (Kein Kick)" or "Deaktiviert", Time = 2.5})
		end)

		local FbRow = Row("Nachtsicht / Fullbright", 38)
		local FbBtn = Create("TextButton", {
			Parent = FbRow, Size = UDim2.new(0, 100, 0, 24), Position = UDim2.new(1, -112, 0, 7),
			BackgroundColor3 = Library.FullbrightEnabled and ACCENT or Library.Themes[Library.SelectedTheme].Control,
			Text = Library.FullbrightEnabled and "AN" or "Aus",
			TextColor3 = Color3.fromRGB(220, 210, 240), Font = Enum.Font.GothamSemibold, TextSize = 12, AutoButtonColor = false
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = FbBtn})
		FbBtn.MouseButton1Click:Connect(function()
			PlayClickSound()
			SetFullbright(not Library.FullbrightEnabled)
			FbBtn.Text = Library.FullbrightEnabled and "AN" or "Aus"
			FbBtn.BackgroundColor3 = Library.FullbrightEnabled and ACCENT or Library.Themes[Library.SelectedTheme].Control
			SaveUIConfig()
		end)

		local PotatoRow = Row("Potato Mode (FPS-Boost)", 38)
		local PotatoBtn = Create("TextButton", {
			Parent = PotatoRow, Size = UDim2.new(0, 100, 0, 24), Position = UDim2.new(1, -112, 0, 7),
			BackgroundColor3 = Library.PotatoModeEnabled and ACCENT or Library.Themes[Library.SelectedTheme].Control,
			Text = Library.PotatoModeEnabled and "AN" or "Aus",
			TextColor3 = Color3.fromRGB(220, 210, 240), Font = Enum.Font.GothamSemibold, TextSize = 12, AutoButtonColor = false
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = PotatoBtn})
		PotatoBtn.MouseButton1Click:Connect(function()
			PlayClickSound()
			SetPotatoMode(not Library.PotatoModeEnabled)
			PotatoBtn.Text = Library.PotatoModeEnabled and "AN" or "Aus"
			PotatoBtn.BackgroundColor3 = Library.PotatoModeEnabled and ACCENT or Library.Themes[Library.SelectedTheme].Control
			SaveUIConfig()
			Library:MakeNotification({Name = "Potato Mode", Content = Library.PotatoModeEnabled and "Partikel & Schatten aus" or "Normal", Time = 2.5})
		end)

		local FpsRow = Row("FPS-Begrenzung (" .. tostring(Library.TargetFps) .. " FPS)", 60)
		local FpsSlider = Create("Frame", {
			Parent = FpsRow, Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 12, 0, 32),
			BackgroundColor3 = Library.Themes[Library.SelectedTheme].Control
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = FpsSlider})
		local FpsFill = Create("Frame", {
			Parent = FpsSlider, Size = UDim2.new((Library.TargetFps - 30) / 210, 0, 1, 0),
			BackgroundColor3 = ACCENT
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = FpsFill})
		local DraggingFps = false
		AddConnection(FpsSlider.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then DraggingFps = true end end)
		AddConnection(UserInputService.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 and DraggingFps then DraggingFps = false; SaveUIConfig() end end)
		AddConnection(UserInputService.InputChanged, function(i)
			if DraggingFps and i.UserInputType == Enum.UserInputType.MouseMovement then
				local Rel = math.clamp((Mouse.X - FpsSlider.AbsolutePosition.X) / FpsSlider.AbsoluteSize.X, 0, 1)
				FpsFill.Size = UDim2.new(Rel, 0, 1, 0)
				local target = math.floor(30 + (Rel * 210) + 0.5)
				ApplyFpsCap(target)
				if FpsRow:FindFirstChild("Title") then FpsRow.Title.Text = "FPS-Begrenzung (" .. tostring(target) .. " FPS)" end
			end
		end)

		Header("Design, Farben & Custom Media")

		local BgOptions = {
			{ Name = "Frau 1",                 Url = "https://s1.directupload.eu/images/260904/3m9x7lao.jpg" },
			{ Name = "Frau 2",                 Url = "https://s1.directupload.eu/images/260904/soqw6y3k.jpg" },
			{ Name = "Frau 3",                 Url = "https://s1.directupload.eu/images/260904/qqkkxxbc.jpg" },
			{ Name = "Frau 4",                 Url = "https://s1.directupload.eu/images/260904/n75cgpa4.jpg" },
			{ Name = "Kein Hintergrund (Aus)", Url = nil }
		}
		local CurrentBgOption = Library.SelectedBackground or "Frau 1"

		local BgDropdownList = MakeElement("List")
		local BgDropdownContainer = AddThemeObject(SetProps(SetChildren(MakeElement("ScrollFrame", Color3.fromRGB(255,255,255), 4), {BgDropdownList}), {
			Position = UDim2.new(0, 0, 0, 38),
			Size = UDim2.new(1, 0, 1, -38),
			ClipsDescendants = true
		}), "Divider")

		local BgClick = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})
		local BgIco = AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072706796"), {
			Size = UDim2.new(0, 20, 0, 20), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -30, 0.5, 0),
			ImageColor3 = Color3.fromRGB(240, 240, 240), Name = "Ico"
		}), "TextDark")
		local BgSelected = AddThemeObject(SetProps(MakeElement("Label", CurrentBgOption, 13), {
			Size = UDim2.new(1, -40, 1, 0), Font = Enum.Font.GothamSemibold, Name = "Selected", TextXAlignment = Enum.TextXAlignment.Right
		}), "TextDark")
		local BgLine = AddThemeObject(SetProps(MakeElement("Frame"), {
			Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), Name = "Line", Visible = false
		}), "Stroke")

		local BgDropdownFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), {
			Size = UDim2.new(1, 0, 0, 38), Parent = UISettingsPanel, ClipsDescendants = true, Name = "BgDropdownFrame"
		}), {
			BgDropdownContainer,
			SetProps(SetChildren(MakeElement("TFrame"), {
				AddThemeObject(SetProps(MakeElement("Label", "Hintergrundbild", 15), {
					Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 12, 0, 0), Font = Enum.Font.GothamSemibold, Name = "Content"
				}), "Text"),
				BgIco, BgSelected, BgLine, BgClick
			}), {Size = UDim2.new(1, 0, 0, 38), ClipsDescendants = true, Name = "F"}),
			AddThemeObject(MakeElement("Stroke"), "Stroke"),
			MakeElement("Corner")
		}), "Second")

		local BgToggled = false
		local BgButtons = {}

		local function SetBackgroundByOption(opt)
			CurrentBgOption = opt.Name
			Library.SelectedBackground = opt.Name
			Library.ActiveBackgroundUrl = opt.Url
			BgSelected.Text = opt.Name
			for name, btn in pairs(BgButtons) do
				local isSel = (name == opt.Name)
				TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = isSel and 0 or 0.2}):Play()
				if btn:FindFirstChild("Title") then TweenService:Create(btn.Title, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = isSel and 0 or 0.4}):Play() end
			end
			if opt.Url and opt.Url ~= "" then
				task.spawn(function()
					local asset = LoadCustomAsset(opt.Url, nil)
					if asset then
						WindowBackgroundImage.Image = asset
						WindowBackgroundImage.Visible = true
					end
				end)
			else
				WindowBackgroundImage.Visible = false
			end
			SaveUIConfig()
			Library:MakeNotification({Name = "Hintergrund gewechselt", Content = opt.Name, Time = 2.5})
		end

		for _, opt in ipairs(BgOptions) do
			local optBtn = AddThemeObject(SetChildren(SetProps(MakeElement("Button"), {
				Parent = BgDropdownContainer, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = (opt.Name == CurrentBgOption) and 0 or 0.2, ClipsDescendants = true
			}), {
				MakeElement("Corner", 0, 6),
				AddThemeObject(SetProps(MakeElement("Label", opt.Name, 13, (opt.Name == CurrentBgOption) and 0 or 0.4), {
					Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -8, 1, 0), Name = "Title"
				}), "Text")
			}), "Second")

			AddConnection(optBtn.MouseButton1Click, function()
				PlayClickSound()
				SetBackgroundByOption(opt)
				BgToggled = false
				BgLine.Visible = false
				TweenService:Create(BgIco, TweenInfo.new(0.15), {Rotation = 0}):Play()
				TweenService:Create(BgDropdownFrame, TweenInfo.new(0.15), {Size = UDim2.new(1, 0, 0, 38)}):Play()
			end)
			BgButtons[opt.Name] = optBtn
		end

		AddConnection(BgDropdownList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
			BgDropdownContainer.CanvasSize = UDim2.new(0, 0, 0, BgDropdownList.AbsoluteContentSize.Y)
		end)

		AddConnection(BgClick.MouseButton1Click, function()
			PlayClickSound()
			BgToggled = not BgToggled
			BgLine.Visible = BgToggled
			TweenService:Create(BgIco, TweenInfo.new(0.15), {Rotation = BgToggled and 180 or 0}):Play()
			local targetH = BgToggled and (38 + (#BgOptions * 28)) or 38
			TweenService:Create(BgDropdownFrame, TweenInfo.new(0.15), {Size = UDim2.new(1, 0, 0, targetH)}):Play()
		end)

		local BgTransRow = Row("Hintergrund-Transparenz", 60)
		local BgTransSlider = Create("Frame", {
			Parent = BgTransRow, Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 12, 0, 32),
			BackgroundColor3 = Library.Themes[Library.SelectedTheme].Control
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = BgTransSlider})
		local BgTransFill = Create("Frame", {
			Parent = BgTransSlider, Size = UDim2.new(Library.BackgroundTransparency, 0, 1, 0),
			BackgroundColor3 = ACCENT
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = BgTransFill})
		local DraggingBgT = false
		AddConnection(BgTransSlider.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then DraggingBgT = true end end)
		AddConnection(UserInputService.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 and DraggingBgT then DraggingBgT = false; SaveUIConfig() end end)
		AddConnection(UserInputService.InputChanged, function(i)
			if DraggingBgT and i.UserInputType == Enum.UserInputType.MouseMovement then
				local Rel = math.clamp((Mouse.X - BgTransSlider.AbsolutePosition.X) / BgTransSlider.AbsoluteSize.X, 0, 1)
				BgTransFill.Size = UDim2.new(Rel, 0, 1, 0)
				Library.BackgroundTransparency = Rel
				WindowBackgroundImage.ImageTransparency = Rel
			end
		end)

		local ColorRow = Row("Akzentfarbe", 66)
		local ColorBar = Create("Frame", {
			Parent = ColorRow, Size = UDim2.new(1, -24, 0, 22),
			Position = UDim2.new(0, 12, 0, 32), BackgroundColor3 = Color3.fromRGB(255,255,255)
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ColorBar})
		Create("UIGradient", {
			Parent = ColorBar, Rotation = 0,
			Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(145,115,245)),
				ColorSequenceKeypoint.new(0.18, Color3.fromRGB(0,200,255)),
				ColorSequenceKeypoint.new(0.36, Color3.fromRGB(0,255,170)),
				ColorSequenceKeypoint.new(0.54, Color3.fromRGB(255,220,0)),
				ColorSequenceKeypoint.new(0.72, Color3.fromRGB(255,60,100)),
				ColorSequenceKeypoint.new(0.88, Color3.fromRGB(255,0,230)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(145,115,245))
			}
		})
		local Picker = Create("Frame", {
			Parent = ColorBar, Size = UDim2.new(0, 4, 1, 4), Position = UDim2.new(0, 0, 0, -2),
			BackgroundColor3 = Color3.fromRGB(255,255,255), BorderSizePixel = 0
		})

		local function ApplyAccent(NewColor)
			ACCENT = NewColor
			ACCENT_TEXT = NewColor:Lerp(Color3.fromRGB(255,255,255), 0.20)
			ACCENT_SOFT = NewColor:Lerp(Color3.fromRGB(255,255,255), 0.08)
			Library.Accent, Library.AccentText, Library.AccentSoft = ACCENT, ACCENT_TEXT, ACCENT_SOFT
			MiniStroke.Color = ACCENT
			PulseRing.Color = ACCENT
			ProfileCardStroke.Color = ACCENT
			for _, Tab in next, TabHolder:GetChildren() do
				if Tab:IsA("TextButton") and Tab:FindFirstChild("Ico") and Tab:FindFirstChild("Title") then
					if Tab.Title.Font == Enum.Font.GothamBold then
						Tab.Ico.ImageColor3, Tab.Title.TextColor3 = ACCENT_TEXT, ACCENT_TEXT
					end
				end
			end
			MiniLogo.TextColor3 = ACCENT_TEXT
		end

		local DraggingColor = false
		AddConnection(ColorBar.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then DraggingColor = true end end)
		AddConnection(UserInputService.InputEnded, function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 and DraggingColor then
				DraggingColor = false
				SaveUIConfig()
			end
		end)
		AddConnection(UserInputService.InputChanged, function(i)
			if DraggingColor and i.UserInputType == Enum.UserInputType.MouseMovement then
				local Rel = math.clamp((Mouse.X - ColorBar.AbsolutePosition.X) / ColorBar.AbsoluteSize.X, 0, 1)
				Picker.Position = UDim2.new(Rel, -2, 0, -2)
				local NewColor = Color3.fromHSV(Rel, 0.75, 1)
				ApplyAccent(NewColor)
			end
		end)

		local RainbowRow = Row("Rainbow Chroma-Modus", 38)
		local RainbowBtn = Create("TextButton", {
			Parent = RainbowRow, Size = UDim2.new(0, 100, 0, 24), Position = UDim2.new(1, -112, 0, 7),
			BackgroundColor3 = Library.RainbowEnabled and ACCENT or Library.Themes[Library.SelectedTheme].Control,
			Text = Library.RainbowEnabled and "AN" or "Aus",
			TextColor3 = Color3.fromRGB(220, 210, 240), Font = Enum.Font.GothamSemibold, TextSize = 12, AutoButtonColor = false
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = RainbowBtn})
		
		task.spawn(function()
			local hue = 0
			while Library:IsRunning() do
				if Library.RainbowEnabled then
					hue = (hue + 0.005) % 1
					local c = Color3.fromHSV(hue, 0.8, 1)
					ApplyAccent(c)
				end
				task.wait(0.03)
			end
		end)

		RainbowBtn.MouseButton1Click:Connect(function()
			PlayClickSound()
			Library.RainbowEnabled = not Library.RainbowEnabled
			RainbowBtn.Text = Library.RainbowEnabled and "AN" or "Aus"
			RainbowBtn.BackgroundColor3 = Library.RainbowEnabled and ACCENT or Library.Themes[Library.SelectedTheme].Control
			SaveUIConfig()
		end)

		Header("HUD & Transparenz")

		local WatermarkRow = Row("Live Watermark HUD (FPS & Ping)", 38)
		local WatermarkBtn = Create("TextButton", {
			Parent = WatermarkRow, Size = UDim2.new(0, 100, 0, 24), Position = UDim2.new(1, -112, 0, 7),
			BackgroundColor3 = Library.WatermarkEnabled and ACCENT or Library.Themes[Library.SelectedTheme].Control,
			Text = Library.WatermarkEnabled and "AN" or "Aus",
			TextColor3 = Color3.fromRGB(220, 210, 240), Font = Enum.Font.GothamSemibold, TextSize = 12, AutoButtonColor = false
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = WatermarkBtn})
		WatermarkBtn.MouseButton1Click:Connect(function()
			PlayClickSound()
			SetWatermarkState(not Library.WatermarkEnabled)
			WatermarkBtn.Text = Library.WatermarkEnabled and "AN" or "Aus"
			WatermarkBtn.BackgroundColor3 = Library.WatermarkEnabled and ACCENT or Library.Themes[Library.SelectedTheme].Control
			SaveUIConfig()
		end)

		local TransRow = Row("Fenster-Transparenz", 60)
		local TSlider = Create("Frame", {
			Parent = TransRow, Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 12, 0, 32),
			BackgroundColor3 = Library.Themes[Library.SelectedTheme].Control
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = TSlider})
		local TFill = Create("Frame", {
			Parent = TSlider, Size = UDim2.new(1 - Library.Transparency.Window, 0, 1, 0),
			BackgroundColor3 = ACCENT
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = TFill})
		local DraggingT = false
		AddConnection(TSlider.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then DraggingT = true end end)
		AddConnection(UserInputService.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 and DraggingT then DraggingT = false; SaveUIConfig() end end)
		AddConnection(UserInputService.InputChanged, function(i)
			if DraggingT and i.UserInputType == Enum.UserInputType.MouseMovement then
				local Rel = math.clamp((Mouse.X - TSlider.AbsolutePosition.X) / TSlider.AbsoluteSize.X, 0, 1)
				TFill.Size = UDim2.new(Rel, 0, 1, 0)
				Library.Transparency.Window = 1 - Rel
				MainWindow.BackgroundTransparency = Library.Transparency.Window
			end
		end)

		local SideRow = Row("Sidebar-Transparenz", 60)
		local SSlider = Create("Frame", {
			Parent = SideRow, Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 12, 0, 32),
			BackgroundColor3 = Library.Themes[Library.SelectedTheme].Control
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = SSlider})
		local SFill = Create("Frame", {
			Parent = SSlider, Size = UDim2.new(1 - Library.Transparency.Sidebar, 0, 1, 0),
			BackgroundColor3 = ACCENT
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = SFill})
		local DraggingS = false
		AddConnection(SSlider.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then DraggingS = true end end)
		AddConnection(UserInputService.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 and DraggingS then DraggingS = false; SaveUIConfig() end end)
		AddConnection(UserInputService.InputChanged, function(i)
			if DraggingS and i.UserInputType == Enum.UserInputType.MouseMovement then
				local Rel = math.clamp((Mouse.X - SSlider.AbsolutePosition.X) / SSlider.AbsoluteSize.X, 0, 1)
				SFill.Size = UDim2.new(Rel, 0, 1, 0)
				Library.Transparency.Sidebar = 1 - Rel
				WindowStuff.BackgroundTransparency = Library.Transparency.Sidebar
			end
		end)

		local BlurRow = Row("Hintergrund-Unschärfe (Blur)", 38)
		local BlurBtn = Create("TextButton", {
			Parent = BlurRow, Size = UDim2.new(0, 100, 0, 24), Position = UDim2.new(1, -112, 0, 7),
			BackgroundColor3 = Library.BlurEnabled and ACCENT or Library.Themes[Library.SelectedTheme].Control,
			Text = Library.BlurEnabled and "AN" or "Aus",
			TextColor3 = Color3.fromRGB(220, 210, 240), Font = Enum.Font.GothamSemibold, TextSize = 12, AutoButtonColor = false
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = BlurBtn})
		BlurBtn.MouseButton1Click:Connect(function()
			PlayClickSound()
			Library.BlurEnabled = not Library.BlurEnabled
			BlurBtn.Text = Library.BlurEnabled and "AN" or "Aus"
			BlurBtn.BackgroundColor3 = Library.BlurEnabled and ACCENT or Library.Themes[Library.SelectedTheme].Control
			SetBlurState(Library.BlurEnabled and MainWindow.Visible)
			SaveUIConfig()
		end)

		Header("Steuerung & Tastenkürzel")

		local ToggleKeyRow = Row("Menü-Taste ändern", 38)
		local KeybindBtn = Create("TextButton", {
			Parent = ToggleKeyRow, Size = UDim2.new(0, 120, 0, 24), Position = UDim2.new(1, -132, 0, 7),
			BackgroundColor3 = Library.Themes[Library.SelectedTheme].Control, Text = ToggleKeyName,
			TextColor3 = Color3.fromRGB(230,225,245), Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = KeybindBtn})
		
		local ListeningForKey = false
		KeybindBtn.MouseButton1Click:Connect(function()
			PlayClickSound()
			if ListeningForKey then return end
			ListeningForKey = true
			KeybindBtn.Text = "Drücke Taste..."
			local conn
			conn = UserInputService.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Keyboard and not CheckKey(BlacklistedKeys, input.KeyCode) then
					WindowConfig.ToggleKey = input.KeyCode
					Library.ToggleKey = input.KeyCode
					ToggleKeyName = input.KeyCode.Name
					KeybindBtn.Text = ToggleKeyName
					ListeningForKey = false
					conn:Disconnect()
					SaveUIConfig()
					Library:MakeNotification({Name = "Taste geändert", Content = "Neue Menü-Taste: " .. ToggleKeyName, Time = 3})
				end
			end)
		end)

		local SoundRow = Row("Klick-Soundeffekte", 38)
		local SoundBtn = Create("TextButton", {
			Parent = SoundRow, Size = UDim2.new(0, 100, 0, 24), Position = UDim2.new(1, -112, 0, 7),
			BackgroundColor3 = Library.SoundsEnabled and ACCENT or Library.Themes[Library.SelectedTheme].Control,
			Text = Library.SoundsEnabled and "AN" or "Aus",
			TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = SoundBtn})
		SoundBtn.MouseButton1Click:Connect(function()
			Library.SoundsEnabled = not Library.SoundsEnabled
			SoundBtn.Text = Library.SoundsEnabled and "AN" or "Aus"
			SoundBtn.BackgroundColor3 = Library.SoundsEnabled and ACCENT or Library.Themes[Library.SelectedTheme].Control
			PlayClickSound()
			SaveUIConfig()
		end)

		local ModeRow = Row("Wieder öffnen per", 38)
		local ModeBtn = Create("TextButton", {
			Parent = ModeRow, Size = UDim2.new(0, 120, 0, 24), Position = UDim2.new(1, -132, 0, 7),
			BackgroundColor3 = Library.Themes[Library.SelectedTheme].Control,
			Text = (Library.MinimizeSettings.ReopenMode == "Click" and "Einfachklick" or "Doppelklick"),
			TextColor3 = Color3.fromRGB(230,225,245), Font = Enum.Font.GothamSemibold, TextSize = 12, AutoButtonColor = false
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ModeBtn})
		AddConnection(ModeBtn.MouseButton1Click, function()
			PlayClickSound()
			if Library.MinimizeSettings.ReopenMode == "DoubleClick" then
				Library.MinimizeSettings.ReopenMode = "Click"
				ModeBtn.Text = "Einfachklick"
			else
				Library.MinimizeSettings.ReopenMode = "DoubleClick"
				ModeBtn.Text = "Doppelklick"
			end
			SaveUIConfig()
		end)

		Header("Verwaltung & Schnelltools")

		local RejoinRow = Row("Server Rejoin", 38)
		local RejoinBtn = Create("TextButton", {
			Parent = RejoinRow, Size = UDim2.new(0, 100, 0, 24), Position = UDim2.new(1, -112, 0, 7),
			BackgroundColor3 = ACCENT, Text = "Rejoin",
			TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = RejoinBtn})
		RejoinBtn.MouseButton1Click:Connect(function()
			PlayClickSound()
			if #Players:GetPlayers() <= 1 then
				LocalPlayer:Kick("\n[NightSystem] Rejoining...")
				task.wait(0.2)
				TeleportService:Teleport(game.PlaceId, LocalPlayer)
			else
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
			end
		end)

		local HopRow = Row("Server Hop (Neuer Server)", 38)
		local HopBtn = Create("TextButton", {
			Parent = HopRow, Size = UDim2.new(0, 100, 0, 24), Position = UDim2.new(1, -112, 0, 7),
			BackgroundColor3 = Color3.fromRGB(60, 140, 220), Text = "Hop",
			TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = HopBtn})
		HopBtn.MouseButton1Click:Connect(function()
			PlayClickSound()
			Library:MakeNotification({Name = "Server Hop", Content = "Suche Server...", Time = 3})
			task.spawn(function()
				pcall(function()
					local raw = game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")
					local servers = HttpService:JSONDecode(raw)
					for _, s in ipairs(servers.data) do
						if s.playing < s.maxPlayers and s.id ~= game.JobId then
							TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
							break
						end
					end
				end)
			end)
		end)

		local ResetRow = Row("Farbe & Theme zurücksetzen", 38)
		local ResetBtn = Create("TextButton", {
			Parent = ResetRow, Size = UDim2.new(0, 100, 0, 24), Position = UDim2.new(1, -112, 0, 7),
			BackgroundColor3 = Library.Themes[Library.SelectedTheme].Control, Text = "Reset",
			TextColor3 = Color3.fromRGB(230,225,245), Font = Enum.Font.GothamSemibold, TextSize = 12, AutoButtonColor = false
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ResetBtn})
		AddConnection(ResetBtn.MouseButton1Click, function()
			PlayClickSound()
			local Default = Color3.fromRGB(145, 115, 245)
			Picker.Position = UDim2.new(select(1, Color3.toHSV(Default)), -2, 0, -2)
			ApplyAccent(Default)
			MainWindow.BackgroundTransparency = 0.22
			WindowStuff.BackgroundTransparency = 0.14
			Library.Transparency.Window = 0.22
			Library.Transparency.Sidebar = 0.14
			SaveUIConfig()
		end)

		local UnloadRow = Row("UI komplett entladen", 38)
		local UnloadBtn = Create("TextButton", {
			Parent = UnloadRow, Size = UDim2.new(0, 100, 0, 24), Position = UDim2.new(1, -112, 0, 7),
			BackgroundColor3 = Color3.fromRGB(180, 40, 50), Text = "Entladen",
			TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = UnloadBtn})
		UnloadBtn.MouseButton1Click:Connect(function()
			PlayClickSound()
			SetBlurState(false)
			SetWatermarkState(false)
			SetAntiAfk(false)
			SetFullbright(false)
			Library:Destroy()
		end)
	end
	BuildUISettings()

	AddConnection(SettingsBtn.MouseButton1Up, function()
		PlayClickSound()
		TweenService:Create(SettingsBtn.Ico, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Rotation = SettingsBtn.Ico.Rotation + 60}):Play()
		ProfileCard.Visible = false
		ProfileCardOpen = false
		local ShowSettings = not UISettingsPanel.Visible
		UISettingsPanel.Visible = ShowSettings
		for _, ItemContainer in next, MainWindow:GetChildren() do
			if ItemContainer.Name == "ItemContainer" and ShowSettings then ItemContainer.Visible = false end
		end
	end)

	local function BuildTab(TabConfig, ParentHolder)
		TabConfig = TabConfig or {}
		TabConfig.Name        = TabConfig.Name        or "Tab"
		TabConfig.Icon        = TabConfig.Icon        or ""
		TabConfig.PremiumOnly = TabConfig.PremiumOnly or false

		local TabFrame = SetChildren(SetProps(MakeElement("Button"), {
			Size = UDim2.new(1, 0, 0, 30),
			Parent = ParentHolder
		}), {
			AddThemeObject(SetProps(MakeElement("Image", TabConfig.Icon), {
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0,18,0,18),
				Position = UDim2.new(0,10,0.5,0),
				ImageTransparency = 0.4,
				Name = "Ico"
			}), "Text"),
			AddThemeObject(SetProps(MakeElement("Label", TabConfig.Name, 14), {
				Size = UDim2.new(1,-35,1,0),
				Position = UDim2.new(0,35,0,0),
				Font = Enum.Font.GothamSemibold,
				TextTransparency = 0.4,
				Name = "Title"
			}), "Text")
		})

		if GetIcon(TabConfig.Icon) ~= nil then TabFrame.Ico.Image = GetIcon(TabConfig.Icon) end

		local TabItemContainer = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255,255,255), 5), {
			Size = UDim2.new(1,-150,1,-50),
			Position = UDim2.new(0,150,0,50),
			Parent = MainWindow,
			Visible = false,
			Name = "ItemContainer"
		}), {
			MakeElement("List", 0, 8),
			MakeElement("Padding", 14, 8, 14, 10)
		}), "Divider")

		AddConnection(TabItemContainer.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
			TabItemContainer.CanvasSize = UDim2.new(0, 0, 0, TabItemContainer.UIListLayout.AbsoluteContentSize.Y + 30)
		end)

		if FirstTab then
			FirstTab = false
			TabFrame.Ico.ImageTransparency = 0
			TabFrame.Title.TextTransparency = 0
			TabFrame.Title.Font = Enum.Font.GothamBold
			TabFrame.Ico.ImageColor3 = ACCENT_TEXT
			TabFrame.Title.TextColor3 = ACCENT_TEXT
			TabItemContainer.Visible = true
		end

		local function ActivateTab()
			ProfileCard.Visible = false
			ProfileCardOpen = false
			for _, Tab in next, TabHolder:GetChildren() do
				if Tab:IsA("TextButton") and Tab:FindFirstChild("Ico") and Tab:FindFirstChild("Title") then
					Tab.Title.Font = Enum.Font.GothamSemibold
					TweenService:Create(Tab.Ico,   TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0.4, ImageColor3 = Color3.fromRGB(240,240,240)}):Play()
					TweenService:Create(Tab.Title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency  = 0.4, TextColor3  = Color3.fromRGB(240,240,240)}):Play()
				end
			end
			for _, ItemContainer in next, MainWindow:GetChildren() do
				if ItemContainer.Name == "ItemContainer" then ItemContainer.Visible = false end
			end
			UISettingsPanel.Visible = false
			TweenService:Create(TabFrame.Ico,   TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0, ImageColor3 = ACCENT_TEXT}):Play()
			TweenService:Create(TabFrame.Title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency  = 0, TextColor3  = ACCENT_TEXT}):Play()
			TabFrame.Title.Font = Enum.Font.GothamBold
			TabItemContainer.Visible = true
		end

		AddConnection(TabFrame.MouseButton1Click, function()
			PlayClickSound()
			ActivateTab()
		end)

		local function GetElements(ItemParent, InPanel)
			local ElementFunction = {}

			function ElementFunction:AddLabel(...)
				local Text = ParseLabelArgs(ResolveArgs(ElementFunction, "AddButton", ...))
				local LabelFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), {
					Size = UDim2.new(1,-16,0,30),
					Position = UDim2.new(0,8,0,0),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", Text, 15), {
						Size = UDim2.new(1,-12,1,0),
						Position = UDim2.new(0,12,0,0),
						Font = Enum.Font.GothamSemibold,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Second")
				SetupElement(LabelFrame, InPanel, TabItemContainer, ActivateTab, ItemParent)
				local LabelFunction = {}
				function LabelFunction:Set(ToChange)
					if LabelFrame:FindFirstChild("Content") then LabelFrame.Content.Text = tostring(ToChange or "") end
				end
				return LabelFunction
			end

			function ElementFunction:AddParagraph(...)
				local Text, Content = ParseParagraphArgs(ResolveArgs(ElementFunction, "AddButton", ...))
				local ParagraphFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), {
					Size = UDim2.new(1,-16,0,30),
					Position = UDim2.new(0,8,0,0),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", Text, 15), {
						Size = UDim2.new(1,-24,0,14),
						Position = UDim2.new(0,12,0,11),
						Font = Enum.Font.GothamSemibold,
						Name = "Title"
					}), "Text"),
					AddThemeObject(SetProps(MakeElement("Label", "", 13), {
						Size = UDim2.new(1,-28,0,0),
						Position = UDim2.new(0,12,0,30),
						Font = Enum.Font.GothamSemibold,
						Name = "Content",
						TextWrapped = true
					}), "TextDark"),
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Second")
				SetupElement(ParagraphFrame, InPanel, TabItemContainer, ActivateTab, ItemParent)
				AddConnection(ParagraphFrame.Content:GetPropertyChangedSignal("Text"), function()
					ParagraphFrame.Content.Size = UDim2.new(1,-28,0,ParagraphFrame.Content.TextBounds.Y)
					ParagraphFrame.Size = UDim2.new(1,0,0,ParagraphFrame.Content.TextBounds.Y + 46)
				end)
				ParagraphFrame.Content.Text = Content
				local ParagraphFunction = {}
				function ParagraphFunction:Set(ToChange) ParagraphFrame.Content.Text = tostring(ToChange or "") end
				return ParagraphFunction
			end

			function ElementFunction:AddButton(...)
				local ButtonConfig = ParseButtonArgs(ResolveArgs(ElementFunction, "AddButton", ...))
				local Button = {}
				local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1,0,1,0)})
				local ButtonFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), {
					Size = UDim2.new(1,0,0,33),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", ButtonConfig.Name, 15), {
						Size = UDim2.new(1,-12,1,0),
						Position = UDim2.new(0,12,0,0),
						Font = Enum.Font.GothamSemibold,
						Name = "Content"
					}), "Text"),
					AddThemeObject(SetProps(MakeElement("Image", ButtonConfig.Icon), {
						Size = UDim2.new(0,20,0,20),
						Position = UDim2.new(1,-30,0,7),
					}), "TextDark"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					Click
				}), "Second")
				SetupElement(ButtonFrame, InPanel, TabItemContainer, ActivateTab, ItemParent)
				AddConnection(Click.MouseEnter,      function() TweenService:Create(ButtonFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+4, Library.Themes[Library.SelectedTheme].Second.G*255+4, Library.Themes[Library.SelectedTheme].Second.B*255+4)}):Play() end)
				AddConnection(Click.MouseLeave,      function() TweenService:Create(ButtonFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Library.Themes[Library.SelectedTheme].Second}):Play() end)
				AddConnection(Click.MouseButton1Up,  function()
					PlayClickSound()
					TweenService:Create(ButtonFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+4, Library.Themes[Library.SelectedTheme].Second.G*255+4, Library.Themes[Library.SelectedTheme].Second.B*255+4)}):Play()
					task.spawn(function() ButtonConfig.Callback() end)
				end)
				AddConnection(Click.MouseButton1Down, function() TweenService:Create(ButtonFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+8, Library.Themes[Library.SelectedTheme].Second.G*255+8, Library.Themes[Library.SelectedTheme].Second.B*255+8)}):Play() end)
				function Button:Set(ButtonText) ButtonFrame.Content.Text = tostring(ButtonText or "") end
				return Button
			end

			function ElementFunction:AddToggle(...)
				local ToggleConfig = ParseToggleArgs(ResolveArgs(ElementFunction, "AddButton", ...))
				local Toggle = {Value = ToggleConfig.Default, Save = ToggleConfig.Save, Type = "Toggle"}
				local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1,0,1,0)})
				local ToggleBox = SetChildren(SetProps(MakeElement("RoundFrame", ToggleConfig.Color, 0, 7), {
					Size = UDim2.new(0,26,0,26),
					Position = UDim2.new(1,-26,0.5,0),
					AnchorPoint = Vector2.new(0.5,0.5),
					BackgroundTransparency = 0
				}), {
					SetProps(MakeElement("Stroke"), {Color = ToggleConfig.Color, Name = "Stroke", Transparency = 0.7, Thickness = 1}),
					SetProps(MakeElement("Image", "rbxassetid://3944680095"), {
						Size = UDim2.new(0,20,0,20),
						AnchorPoint = Vector2.new(0.5,0.5),
						Position = UDim2.new(0.5,0,0.5,0),
						ImageColor3 = Color3.fromRGB(255,255,255),
						Name = "Ico"
					}),
				})
				local ToggleFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), {
					Size = UDim2.new(1,0,0,38),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", ToggleConfig.Name, 15), {
						Size = UDim2.new(1,-12,1,0),
						Position = UDim2.new(0,12,0,0),
						Font = Enum.Font.GothamSemibold,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					ToggleBox,
					Click
				}), "Second")
				SetupElement(ToggleFrame, InPanel, TabItemContainer, ActivateTab, ItemParent)

				function Toggle:Set(Value)
					Toggle.Value = Value
					TweenService:Create(ToggleBox,        TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Toggle.Value and ToggleConfig.Color or Library.Themes.Default.Divider}):Play()
					TweenService:Create(ToggleBox.Stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color            = Toggle.Value and ToggleConfig.Color or Library.Themes.Default.Stroke}):Play()
					TweenService:Create(ToggleBox.Ico,    TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = Toggle.Value and 0 or 1, Size = Toggle.Value and UDim2.new(0,20,0,20) or UDim2.new(0,8,0,8)}):Play()
					ToggleConfig.Callback(Toggle.Value)
				end

				Toggle:Set(Toggle.Value)
				AddConnection(Click.MouseEnter,       function() TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+4, Library.Themes[Library.SelectedTheme].Second.G*255+4, Library.Themes[Library.SelectedTheme].Second.B*255+4)}):Play() end)
				AddConnection(Click.MouseLeave,       function() TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Library.Themes[Library.SelectedTheme].Second}):Play() end)
				AddConnection(Click.MouseButton1Up,   function()
					PlayClickSound()
					TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+4, Library.Themes[Library.SelectedTheme].Second.G*255+4, Library.Themes[Library.SelectedTheme].Second.B*255+4)}):Play()
					Toggle:Set(not Toggle.Value)
					SaveCfg(game.GameId)
				end)
				AddConnection(Click.MouseButton1Down, function() TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+8, Library.Themes[Library.SelectedTheme].Second.G*255+8, Library.Themes[Library.SelectedTheme].Second.B*255+8)}):Play() end)

				if ToggleConfig.Flag then Library.Flags[ToggleConfig.Flag] = Toggle end
				return Toggle
			end

			function ElementFunction:AddSlider(...)
				local SliderConfig = ParseSliderArgs(ResolveArgs(ElementFunction, "AddButton", ...))
				local Slider = {Value = SliderConfig.Default, Save = SliderConfig.Save, Type = "Slider"}
				local Dragging = false

				local SliderDrag = SetChildren(SetProps(MakeElement("RoundFrame", SliderConfig.Color, 0, 5), {
					Size = UDim2.new(0,0,1,0),
					BackgroundTransparency = 0.25,
					ClipsDescendants = true
				}), {
					AddThemeObject(SetProps(MakeElement("Label", "value", 13), {
						Size = UDim2.new(1,-12,0,14),
						Position = UDim2.new(0,12,0,6),
						Font = Enum.Font.GothamSemibold,
						Name = "Value",
						TextTransparency = 0
					}), "Text")
				})

				local SliderBar = SetChildren(SetProps(MakeElement("RoundFrame", SliderConfig.Color, 0, 5), {
					Size = UDim2.new(1,-24,0,26),
					Position = UDim2.new(0,12,0,30),
					BackgroundTransparency = 0.9
				}), {
					SetProps(MakeElement("Stroke"), {Color = SliderConfig.Color}),
					AddThemeObject(SetProps(MakeElement("Label", "value", 13), {
						Size = UDim2.new(1,-12,0,14),
						Position = UDim2.new(0,12,0,6),
						Font = Enum.Font.GothamSemibold,
						Name = "Value",
						TextTransparency = 0.8
					}), "Text"),
					SliderDrag
				})

				local SliderFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 7), {
					Size = UDim2.new(1,0,0,65),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", SliderConfig.Name, 15), {
						Size = UDim2.new(1,-12,0,14),
						Position = UDim2.new(0,12,0,10),
						Font = Enum.Font.GothamSemibold,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					SliderBar
				}), "Second")
				SetupElement(SliderFrame, InPanel, TabItemContainer, ActivateTab, ItemParent)

				SliderBar.InputBegan:Connect(function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
						Dragging = true
						PlayClickSound()
					end
				end)
				SliderBar.InputEnded:Connect(function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
						Dragging = false
						SaveCfg(game.GameId)
					end
				end)
				UserInputService.InputChanged:Connect(function(Input)
					if Dragging then
						local SizeScale = math.clamp((Mouse.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
						Slider:Set(SliderConfig.Min + ((SliderConfig.Max - SliderConfig.Min) * SizeScale))
					end
				end)

				function Slider:Set(Value)
					local inc = SliderConfig.Increment
					if type(inc) ~= "number" or inc <= 0 then inc = 1 end
					self.Value = math.clamp(Round(Value, inc), SliderConfig.Min, SliderConfig.Max)
					TweenService:Create(SliderDrag, TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromScale((self.Value - SliderConfig.Min) / (SliderConfig.Max - SliderConfig.Min), 1)}):Play()
					SliderBar.Value.Text   = tostring(self.Value).." "..SliderConfig.ValueName
					SliderDrag.Value.Text  = tostring(self.Value).." "..SliderConfig.ValueName
					SliderConfig.Callback(self.Value)
				end

				Slider:Set(Slider.Value)
				if SliderConfig.Flag then Library.Flags[SliderConfig.Flag] = Slider end
				return Slider
			end

			function ElementFunction:AddDropdown(...)
				local DropdownConfig = ParseDropdownArgs(ResolveArgs(ElementFunction, "AddButton", ...))
				local Dropdown = {Value = DropdownConfig.Default, Options = DropdownConfig.Options, Buttons = {}, Toggled = false, Type = "Dropdown", Save = DropdownConfig.Save}
				local MaxElements = 5

				if not table.find(Dropdown.Options, Dropdown.Value) then Dropdown.Value = "..." end

				local DropdownList = MakeElement("List")
				local DropdownContainer = AddThemeObject(SetProps(SetChildren(MakeElement("ScrollFrame", Color3.fromRGB(255,255,255), 4), {DropdownList}), {
					Parent = ItemParent,
					Position = UDim2.new(0,0,0,38),
					Size = UDim2.new(1,0,1,-38),
					ClipsDescendants = true
				}), "Divider")

				local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1,0,1,0)})
				local DropdownFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), {
					Size = UDim2.new(1,0,0,38),
					Parent = ItemParent,
					ClipsDescendants = true
				}), {
					DropdownContainer,
					SetProps(SetChildren(MakeElement("TFrame"), {
						AddThemeObject(SetProps(MakeElement("Label", DropdownConfig.Name, 15), {Size = UDim2.new(1,-12,1,0), Position = UDim2.new(0,12,0,0), Font = Enum.Font.GothamSemibold, Name = "Content"}), "Text"),
						AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072706796"), {Size = UDim2.new(0,20,0,20), AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(1,-30,0.5,0), ImageColor3 = Color3.fromRGB(240,240,240), Name = "Ico"}), "TextDark"),
						AddThemeObject(SetProps(MakeElement("Label", "Selected", 13), {Size = UDim2.new(1,-40,1,0), Font = Enum.Font.GothamSemibold, Name = "Selected", TextXAlignment = Enum.TextXAlignment.Right}), "TextDark"),
						AddThemeObject(SetProps(MakeElement("Frame"), {Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1), Name = "Line", Visible = false}), "Stroke"),
						Click
					}), {Size = UDim2.new(1,0,0,38), ClipsDescendants = true, Name = "F"}),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					MakeElement("Corner")
				}), "Second")
				SetupElement(DropdownFrame, InPanel, TabItemContainer, ActivateTab, ItemParent)

				AddConnection(DropdownList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
					DropdownContainer.CanvasSize = UDim2.new(0,0,0,DropdownList.AbsoluteContentSize.Y)
				end)

				local function AddOptions(Options)
					for _, Option in pairs(Options) do
						local OptionBtn = AddThemeObject(SetChildren(SetProps(MakeElement("Button"), {
							Parent = DropdownContainer,
							Size = UDim2.new(1,0,0,28),
							BackgroundTransparency = 0.2,
							ClipsDescendants = true
						}), {
							MakeElement("Corner", 0, 6),
							AddThemeObject(SetProps(MakeElement("Label", Option, 13, 0.4), {Position = UDim2.new(0,8,0,0), Size = UDim2.new(1,-8,1,0), Name = "Title"}), "Text")
						}), "Second")
						AddConnection(OptionBtn.MouseButton1Click, function()
							PlayClickSound()
							Dropdown:Set(Option)
							SaveCfg(game.GameId)
						end)
						Dropdown.Buttons[Option] = OptionBtn
					end
				end

				function Dropdown:Refresh(Options, Delete)
					if Delete then
						for _,v in pairs(Dropdown.Buttons) do v:Destroy() end
						table.clear(Dropdown.Options)
						table.clear(Dropdown.Buttons)
					end
					Dropdown.Options = Options
					AddOptions(Dropdown.Options)
				end

				function Dropdown:Set(Value)
					if not table.find(Dropdown.Options, Value) then
						Dropdown.Value = "..."
						DropdownFrame.F.Selected.Text = Dropdown.Value
						for _, v in pairs(Dropdown.Buttons) do
							TweenService:Create(v,       TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.2}):Play()
							TweenService:Create(v.Title, TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency       = 0.4}):Play()
						end
						return
					end
					Dropdown.Value = Value
					DropdownFrame.F.Selected.Text = Dropdown.Value
					for _, v in pairs(Dropdown.Buttons) do
						TweenService:Create(v,       TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.2}):Play()
						TweenService:Create(v.Title, TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency       = 0.4}):Play()
					end
					TweenService:Create(Dropdown.Buttons[Value],       TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
					TweenService:Create(Dropdown.Buttons[Value].Title, TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency       = 0}):Play()
					return DropdownConfig.Callback(Dropdown.Value)
				end

				AddConnection(Click.MouseButton1Click, function()
					PlayClickSound()
					Dropdown.Toggled = not Dropdown.Toggled
					DropdownFrame.F.Line.Visible = Dropdown.Toggled
					TweenService:Create(DropdownFrame.F.Ico, TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = Dropdown.Toggled and 180 or 0}):Play()
					if #Dropdown.Options > MaxElements then
						TweenService:Create(DropdownFrame, TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Dropdown.Toggled and UDim2.new(1,0,0,38+(MaxElements*28)) or UDim2.new(1,0,0,38)}):Play()
					else
						TweenService:Create(DropdownFrame, TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Dropdown.Toggled and UDim2.new(1,0,0,DropdownList.AbsoluteContentSize.Y+38) or UDim2.new(1,0,0,38)}):Play()
					end
				end)

				Dropdown:Refresh(Dropdown.Options, false)
				Dropdown:Set(Dropdown.Value)
				if DropdownConfig.Flag then Library.Flags[DropdownConfig.Flag] = Dropdown end
				return Dropdown
			end

			function ElementFunction:AddBind(...)
				local BindConfig = ParseBindArgs(ResolveArgs(ElementFunction, "AddButton", ...))
				local Bind = {Value = nil, Binding = false, Type = "Bind", Save = BindConfig.Save}
				local Holding = false
				local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1,0,1,0)})

				local BindBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 7), {
					Size = UDim2.new(0,24,0,24),
					Position = UDim2.new(1,-12,0.5,0),
					AnchorPoint = Vector2.new(1,0.5),
					BackgroundTransparency = 0.2
				}), {
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					AddThemeObject(SetProps(MakeElement("Label", BindConfig.Name, 14), {
						Size = UDim2.new(1,0,1,0),
						Font = Enum.Font.GothamSemibold,
						TextXAlignment = Enum.TextXAlignment.Center,
						Name = "Value"
					}), "Text")
				}), "Control")

				local BindFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), {
					Size = UDim2.new(1,0,0,38),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", BindConfig.Name, 15), {
						Size = UDim2.new(1,-12,1,0),
						Position = UDim2.new(0,12,0,0),
						Font = Enum.Font.GothamSemibold,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					BindBox,
					Click
				}), "Second")
				SetupElement(BindFrame, InPanel, TabItemContainer, ActivateTab, ItemParent)

				AddConnection(BindBox.Value:GetPropertyChangedSignal("Text"), function()
					TweenService:Create(BindBox, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, BindBox.Value.TextBounds.X + 16, 0, 24)}):Play()
				end)
				AddConnection(Click.InputEnded, function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
						if Bind.Binding then return end
						Bind.Binding = true
						BindBox.Value.Text = "..."
					end
				end)
				AddConnection(UserInputService.InputBegan, function(Input)
					if UserInputService:GetFocusedTextBox() then return end
					if (Input.KeyCode.Name == Bind.Value or Input.UserInputType.Name == Bind.Value) and not Bind.Binding then
						if BindConfig.Hold then
							Holding = true
							BindConfig.Callback(Holding)
						else
							BindConfig.Callback()
						end
					elseif Bind.Binding then
						local Key
						pcall(function() if not CheckKey(BlacklistedKeys, Input.KeyCode) then Key = Input.KeyCode end end)
						pcall(function() if CheckKey(WhitelistedMouse, Input.UserInputType) and not Key then Key = Input.UserInputType end end)
						Key = Key or Bind.Value
						Bind:Set(Key)
						SaveCfg(game.GameId)
					end
				end)
				AddConnection(UserInputService.InputEnded, function(Input)
					if Input.KeyCode.Name == Bind.Value or Input.UserInputType.Name == Bind.Value then
						if BindConfig.Hold and Holding then
							Holding = false
							BindConfig.Callback(Holding)
						end
					end
				end)
				AddConnection(Click.MouseEnter,       function() TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+4, Library.Themes[Library.SelectedTheme].Second.G*255+4, Library.Themes[Library.SelectedTheme].Second.B*255+4)}):Play() end)
				AddConnection(Click.MouseLeave,       function() TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Library.Themes[Library.SelectedTheme].Second}):Play() end)
				AddConnection(Click.MouseButton1Up,   function() PlayClickSound(); TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+4, Library.Themes[Library.SelectedTheme].Second.G*255+4, Library.Themes[Library.SelectedTheme].Second.B*255+4)}):Play() end)
				AddConnection(Click.MouseButton1Down, function() TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+8, Library.Themes[Library.SelectedTheme].Second.G*255+8, Library.Themes[Library.SelectedTheme].Second.B*255+8)}):Play() end)

				function Bind:Set(Key)
					Bind.Binding = false
					Bind.Value = Key or Bind.Value
					Bind.Value = Bind.Value.Name or Bind.Value
					BindBox.Value.Text = Bind.Value
				end

				Bind:Set(BindConfig.Default)
				if BindConfig.Flag then Library.Flags[BindConfig.Flag] = Bind end
				return Bind
			end

			function ElementFunction:AddTextbox(...)
				local TextboxConfig = ParseTextboxArgs(ResolveArgs(ElementFunction, "AddButton", ...))
				local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1,0,1,0)})
				local TextboxActual = AddThemeObject(Create("TextBox", {
					Size = UDim2.new(1,0,1,0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255,255,255),
					PlaceholderColor3 = Color3.fromRGB(150,140,170),
					PlaceholderText = "Input",
					Font = Enum.Font.GothamSemibold,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextSize = 14,
					ClearTextOnFocus = false
				}), "Text")

				local TextContainer = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 7), {
					Size = UDim2.new(0,24,0,24),
					Position = UDim2.new(1,-12,0.5,0),
					AnchorPoint = Vector2.new(1,0.5),
					BackgroundTransparency = 0.2
				}), {
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					TextboxActual
				}), "Control")

				local TextboxFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), {
					Size = UDim2.new(1,0,0,38),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", TextboxConfig.Name, 15), {
						Size = UDim2.new(1,-12,1,0),
						Position = UDim2.new(0,12,0,0),
						Font = Enum.Font.GothamSemibold,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					TextContainer,
					Click
				}), "Second")
				SetupElement(TextboxFrame, InPanel, TabItemContainer, ActivateTab, ItemParent)

				AddConnection(TextboxActual:GetPropertyChangedSignal("Text"), function()
					TweenService:Create(TextContainer, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, TextboxActual.TextBounds.X+16, 0, 24)}):Play()
				end)
				AddConnection(TextboxActual.FocusLost, function()
					TextboxConfig.Callback(TextboxActual.Text)
					if TextboxConfig.TextDisappear then TextboxActual.Text = "" end
				end)
				TextboxActual.Text = TextboxConfig.Default
				AddConnection(Click.MouseEnter,       function() TweenService:Create(TextboxFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+4, Library.Themes[Library.SelectedTheme].Second.G*255+4, Library.Themes[Library.SelectedTheme].Second.B*255+4)}):Play() end)
				AddConnection(Click.MouseLeave,       function() TweenService:Create(TextboxFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Library.Themes[Library.SelectedTheme].Second}):Play() end)
				AddConnection(Click.MouseButton1Up,   function()
					PlayClickSound()
					TweenService:Create(TextboxFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+4, Library.Themes[Library.SelectedTheme].Second.G*255+4, Library.Themes[Library.SelectedTheme].Second.B*255+4)}):Play()
					TextboxActual:CaptureFocus()
				end)
				AddConnection(Click.MouseButton1Down, function() TweenService:Create(TextboxFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+8, Library.Themes[Library.SelectedTheme].Second.G*255+8, Library.Themes[Library.SelectedTheme].Second.B*255+8)}):Play() end)
			end

			function ElementFunction:AddColorpicker(...)
				local ColorpickerConfig = ParseColorpickerArgs(ResolveArgs(ElementFunction, "AddButton", ...))
				local ColorH, ColorS, ColorV = 1, 1, 1
				local ColorInput, HueInput
				local Colorpicker = {Value = ColorpickerConfig.Default, Toggled = false, Type = "Colorpicker", Save = ColorpickerConfig.Save}

				local ColorSelection = Create("ImageLabel", {
					Size = UDim2.new(0,18,0,18),
					Position = UDim2.new(select(3, Color3.toHSV(Colorpicker.Value))),
					ScaleType = Enum.ScaleType.Fit,
					AnchorPoint = Vector2.new(0.5,0.5),
					BackgroundTransparency = 1,
					Image = "http://www.roblox.com/asset/?id=4805639000"
				})
				local HueSelection = Create("ImageLabel", {
					Size = UDim2.new(0,18,0,18),
					Position = UDim2.new(0.5,0,1-select(1, Color3.toHSV(Colorpicker.Value))),
					ScaleType = Enum.ScaleType.Fit,
					AnchorPoint = Vector2.new(0.5,0.5),
					BackgroundTransparency = 1,
					Image = "http://www.roblox.com/asset/?id=4805639000"
				})
				local Color = Create("ImageLabel", {Size = UDim2.new(1,-26,1,0), Visible = false, Image = "rbxassetid://4155801252"}, {
					Create("UICorner", {CornerRadius = UDim.new(0,5)}),
					ColorSelection
				})
				local Hue = Create("Frame", {Size = UDim2.new(0,16,1,0), Position = UDim2.new(1,-16,0,0), Visible = false, BackgroundTransparency = 0.2}, {
					Create("UIGradient", {Rotation = 270, Color = ColorSequence.new{
						ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,0,4)),
						ColorSequenceKeypoint.new(0.20, Color3.fromRGB(234,255,0)),
						ColorSequenceKeypoint.new(0.40, Color3.fromRGB(21,255,0)),
						ColorSequenceKeypoint.new(0.60, Color3.fromRGB(0,255,255)),
						ColorSequenceKeypoint.new(0.80, Color3.fromRGB(0,17,255)),
						ColorSequenceKeypoint.new(0.90, Color3.fromRGB(255,0,251)),
						ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255,0,4))
					}}),
					Create("UICorner", {CornerRadius = UDim.new(0,5)}),
					HueSelection
				})
				local ColorpickerContainer = Create("Frame", {
					Position = UDim2.new(0,0,0,38),
					Size = UDim2.new(1,0,1,-38),
					BackgroundTransparency = 1,
					ClipsDescendants = true
				}, {
					Hue, Color,
					Create("UIPadding", {PaddingLeft=UDim.new(0,12), PaddingRight=UDim.new(0,12), PaddingBottom=UDim.new(0,12), PaddingTop=UDim.new(0,8)})
				})

				local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1,0,1,0)})
				local ColorpickerBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 7), {
					Size = UDim2.new(0,24,0,24),
					Position = UDim2.new(1,-12,0.5,0),
					AnchorPoint = Vector2.new(1,0.5),
					BackgroundTransparency = 0.2
				}), {AddThemeObject(MakeElement("Stroke"), "Stroke")}), "Control")

				local ColorpickerFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), {
					Size = UDim2.new(1,0,0,38),
					Parent = ItemParent
				}), {
					SetProps(SetChildren(MakeElement("TFrame"), {
						AddThemeObject(SetProps(MakeElement("Label", ColorpickerConfig.Name, 15), {Size=UDim2.new(1,-12,1,0), Position=UDim2.new(0,12,0,0), Font=Enum.Font.GothamSemibold, Name="Content"}), "Text"),
						ColorpickerBox,
						Click,
						AddThemeObject(SetProps(MakeElement("Frame"), {Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-1), Name="Line", Visible=false}), "Stroke"),
					}), {Size=UDim2.new(1,0,0,38), ClipsDescendants=true, Name="F"}),
					ColorpickerContainer,
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
				}), "Second")
				SetupElement(ColorpickerFrame, InPanel, TabItemContainer, ActivateTab, ItemParent)

				AddConnection(Click.MouseButton1Click, function()
					PlayClickSound()
					Colorpicker.Toggled = not Colorpicker.Toggled
					TweenService:Create(ColorpickerFrame, TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Colorpicker.Toggled and UDim2.new(1,0,0,168) or UDim2.new(1,0,0,38)}):Play()
					Color.Visible = Colorpicker.Toggled
					Hue.Visible   = Colorpicker.Toggled
					ColorpickerFrame.F.Line.Visible = Colorpicker.Toggled
				end)

				local function UpdateColorPicker()
					ColorpickerBox.BackgroundColor3 = Color3.fromHSV(ColorH, ColorS, ColorV)
					Color.BackgroundColor3 = Color3.fromHSV(ColorH, 1, 1)
					Colorpicker:Set(ColorpickerBox.BackgroundColor3)
					SaveCfg(game.GameId)
				end

				ColorH = 1 - (math.clamp(HueSelection.AbsolutePosition.Y - Hue.AbsolutePosition.Y, 0, Hue.AbsoluteSize.Y) / Hue.AbsoluteSize.Y)
				ColorS = (math.clamp(ColorSelection.AbsolutePosition.X - Color.AbsolutePosition.X, 0, Color.AbsoluteSize.X) / Color.AbsoluteSize.X)
				ColorV = 1 - (math.clamp(ColorSelection.AbsolutePosition.Y - Color.AbsolutePosition.Y, 0, Color.AbsoluteSize.Y) / Color.AbsoluteSize.Y)

				AddConnection(Color.InputBegan, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						if ColorInput then ColorInput:Disconnect() end
						ColorInput = AddConnection(RunService.RenderStepped, function()
							local ColorX = math.clamp(Mouse.X - Color.AbsolutePosition.X, 0, Color.AbsoluteSize.X) / Color.AbsoluteSize.X
							local ColorY = math.clamp(Mouse.Y - Color.AbsolutePosition.Y, 0, Color.AbsoluteSize.Y) / Color.AbsoluteSize.Y
							ColorSelection.Position = UDim2.new(ColorX, 0, ColorY, 0)
							ColorS = ColorX; ColorV = 1 - ColorY
							UpdateColorPicker()
						end)
					end
				end)
				AddConnection(Color.InputEnded, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						if ColorInput then ColorInput:Disconnect() end
					end
				end)
				AddConnection(Hue.InputBegan, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						if HueInput then HueInput:Disconnect() end
						HueInput = AddConnection(RunService.RenderStepped, function()
							local HueY = math.clamp(Mouse.Y - Hue.AbsolutePosition.Y, 0, Hue.AbsoluteSize.Y) / Hue.AbsoluteSize.Y
							HueSelection.Position = UDim2.new(0.5, 0, HueY, 0)
							ColorH = 1 - HueY
							UpdateColorPicker()
						end)
					end
				end)
				AddConnection(Hue.InputEnded, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						if HueInput then HueInput:Disconnect() end
					end
				end)

				function Colorpicker:Set(Value)
					Colorpicker.Value = Value
					ColorpickerBox.BackgroundColor3 = Colorpicker.Value
					ColorpickerConfig.Callback(Colorpicker.Value)
				end

				Colorpicker:Set(Colorpicker.Value)
				if ColorpickerConfig.Flag then Library.Flags[ColorpickerConfig.Flag] = Colorpicker end
				return Colorpicker
			end

			function ElementFunction:AddSection(...)
				local SectionConfig = ParseSectionArgs(ResolveArgs(ElementFunction, "AddButton", ...))
				local SectionFrame = SetChildren(SetProps(MakeElement("TFrame"), {
					Size = UDim2.new(1,0,0,26),
					Parent = TabItemContainer
				}), {
					AddThemeObject(SetProps(MakeElement("Label", SectionConfig.Name, 12), {
						Size = UDim2.new(1,-12,0,14),
						Position = UDim2.new(0,6,0,2),
						Font = Enum.Font.GothamSemibold
					}), "TextDark"),
					AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), {
						AnchorPoint = Vector2.new(0,0),
						Size = UDim2.new(1,0,1,-24),
						Position = UDim2.new(0,0,0,22),
						ClipsDescendants = true,
						Name = "Holder"
					}), {
						MakeElement("List", 0, 0),
						AddThemeObject(MakeElement("Stroke"), "Stroke")
					}), "Second"),
				})
				AddConnection(SectionFrame.Holder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
					SectionFrame.Size        = UDim2.new(1, 0, 0, SectionFrame.Holder.UIListLayout.AbsoluteContentSize.Y + 31)
					SectionFrame.Holder.Size = UDim2.new(1, 0, 0, SectionFrame.Holder.UIListLayout.AbsoluteContentSize.Y)
				end)
				local SectionFunction = {}
				for i, v in next, GetElements(SectionFrame.Holder, true) do SectionFunction[i] = v end
				return AttachElementAliases(SectionFunction)
			end

			return AttachElementAliases(ElementFunction)
		end

		local ElementFunction = {}
		for i, v in next, GetElements(TabItemContainer) do ElementFunction[i] = v end

		if TabConfig.PremiumOnly then
			for i, v in next, ElementFunction do ElementFunction[i] = function() end end
			TabItemContainer:FindFirstChild("UIListLayout"):Destroy()
			TabItemContainer:FindFirstChild("UIPadding"):Destroy()
			SetChildren(SetProps(MakeElement("TFrame"), {Size = UDim2.new(1,0,1,0), Parent = TabItemContainer}), {
				AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://3610239960"), {Size=UDim2.new(0,18,0,18), Position=UDim2.new(0,15,0,15), ImageTransparency=0.4}), "Text"),
				AddThemeObject(SetProps(MakeElement("Label", "Unauthorised Access", 14), {Size=UDim2.new(1,-38,0,14), Position=UDim2.new(0,38,0,18), TextTransparency=0.4}), "Text"),
			})
		end
		return AttachElementAliases(ElementFunction), TabFrame
	end

	local TabFunction    = {}
	local tabLayoutOrder = 0
	local tabGroupRegistry = {}
	local allGroups = {}

	local function NextOrder()
		tabLayoutOrder = tabLayoutOrder + 1
		return tabLayoutOrder
	end

	local Drag = {active = false, src = nil, ghost = nil}

	local function GetOrderedTabs()
		local t = {}
		for _, c in ipairs(TabHolder:GetChildren()) do
			if c:IsA("TextButton") and c:FindFirstChild("Ico") and c:FindFirstChild("Title") then
				table.insert(t, c)
			end
		end
		table.sort(t, function(a,b) return a.LayoutOrder < b.LayoutOrder end)
		return t
	end

	local function TabUnderMouse(exclude)
		for _, c in ipairs(TabHolder:GetChildren()) do
			if c:IsA("TextButton") and c:FindFirstChild("Ico") and c:FindFirstChild("Title") and c ~= exclude then
				local p, s = c.AbsolutePosition, c.AbsoluteSize
				if Mouse.X >= p.X and Mouse.X <= p.X+s.X and Mouse.Y >= p.Y and Mouse.Y <= p.Y+s.Y then return c end
			end
		end
	end

	local function GroupHeaderUnderMouse()
		for _, g in ipairs(allGroups) do
			local h = g.header
			if h then
				local p, s = h.AbsolutePosition, h.AbsoluteSize
				if Mouse.X >= p.X and Mouse.X <= p.X+s.X and Mouse.Y >= p.Y and Mouse.Y <= p.Y+s.Y then return g end
			end
		end
	end

	local function RemoveFromGroup(tabBtn)
		local reg = tabGroupRegistry[tabBtn]
		if not reg then return end
		for i, v in ipairs(reg.frames) do
			if v == tabBtn then table.remove(reg.frames, i) break end
		end
		tabGroupRegistry[tabBtn] = nil
	end

	local function AddToGroup(tabBtn, groupData)
		RemoveFromGroup(tabBtn)
		table.insert(groupData.frames, tabBtn)
		tabGroupRegistry[tabBtn] = groupData
		tabBtn.Visible = not groupData.collapsed
		local pad = tabBtn:FindFirstChildOfClass("UIPadding")
		if not pad then pad = Instance.new("UIPadding"); pad.Parent = tabBtn end
		pad.PaddingLeft = UDim.new(0, 0)
	end

	local function RemoveIndent(tabBtn)
		local pad = tabBtn:FindFirstChildOfClass("UIPadding")
		if pad then pad.PaddingLeft = UDim.new(0, 0) end
	end

	local function EndDrag()
		Drag.active = false
		if Drag.ghost then Drag.ghost:Destroy(); Drag.ghost = nil end
		if Drag.src then
			TweenService:Create(Drag.src, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
			Drag.src = nil
		end
		for _, c in ipairs(TabHolder:GetChildren()) do
			if c:IsA("TextButton") then
				TweenService:Create(c, TweenInfo.new(0.1), {BackgroundTransparency = 1}):Play()
			end
		end
	end

	local function StartDrag(tabFrame)
		Drag.active = true
		Drag.src    = tabFrame
		tabFrame.BackgroundColor3       = ACCENT
		tabFrame.BackgroundTransparency = 0.6

		local ghost = Instance.new("Frame")
		ghost.Size                   = UDim2.new(0, tabFrame.AbsoluteSize.X-8, 0, tabFrame.AbsoluteSize.Y-4)
		ghost.BackgroundColor3       = ACCENT
		ghost.BackgroundTransparency = 0.4
		ghost.BorderSizePixel        = 0
		ghost.ZIndex                 = 20
		Instance.new("UICorner",ghost).CornerRadius = UDim.new(0,5)
		local gl = Instance.new("TextLabel", ghost)
		gl.Size=UDim2.new(1,-8,1,0); gl.Position=UDim2.new(0,8,0,0)
		gl.BackgroundTransparency=1; gl.Text=tabFrame.Title.Text
		gl.TextColor3=Color3.fromRGB(255,255,255); gl.Font=Enum.Font.GothamBlack
		gl.TextSize=13; gl.TextXAlignment=Enum.TextXAlignment.Left; gl.ZIndex=21
		ghost.Parent = Container
		Drag.ghost = ghost

		local dragConn
		dragConn = RunService.RenderStepped:Connect(function()
			if not Drag.active then
				dragConn:Disconnect()
				return
			end
			local rx = Mouse.X - TabHolder.AbsolutePosition.X
			local ry = Mouse.Y - TabHolder.AbsolutePosition.Y - 15
			if Drag.ghost then Drag.ghost.Position = UDim2.new(0,rx,0,ry) end
			local hovered = TabUnderMouse(tabFrame)
			local hgroup  = GroupHeaderUnderMouse()
			for _, c in ipairs(TabHolder:GetChildren()) do
				if c:IsA("TextButton") and c ~= tabFrame then
					local isTarget = (c == hovered) or (hgroup and c == hgroup.header)
					c.BackgroundTransparency = isTarget and 0.6 or 1
					if isTarget then c.BackgroundColor3 = ACCENT end
				end
			end
		end)
	end

	local function AttachDrag(tabFrame)
		local timer, dragging = nil, false
		tabFrame.InputBegan:Connect(function(inp)
			if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			dragging = false
			timer = task.delay(0.25, function()
				if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
					dragging = true; StartDrag(tabFrame)
				end
			end)
		end)
		tabFrame.InputEnded:Connect(function(inp)
			if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			if timer then task.cancel(timer); timer = nil end
			if not dragging then return end
			dragging = false
			if not (Drag.active and Drag.src == tabFrame) then return end

			local targetTab   = TabUnderMouse(tabFrame)
			local targetGroup = GroupHeaderUnderMouse()

			if targetGroup then
				RemoveFromGroup(tabFrame)
				local lastOrder = targetGroup.header.LayoutOrder
				for _, f in ipairs(targetGroup.frames) do
					if f.LayoutOrder > lastOrder then lastOrder = f.LayoutOrder end
				end
				tabLayoutOrder = tabLayoutOrder + 1
				tabFrame.LayoutOrder = lastOrder + 0.5
				local sorted = GetOrderedTabs()
				for i, btn in ipairs(sorted) do btn.LayoutOrder = i * 10 end
				tabLayoutOrder = #sorted * 10
				AddToGroup(tabFrame, targetGroup)
			elseif targetTab then
				local srcOrder = tabFrame.LayoutOrder
				tabFrame.LayoutOrder = targetTab.LayoutOrder
				targetTab.LayoutOrder = srcOrder
				local tg = tabGroupRegistry[targetTab]
				if tg then
					AddToGroup(tabFrame, tg)
				elseif tabGroupRegistry[tabFrame] then
					RemoveFromGroup(tabFrame)
					RemoveIndent(tabFrame)
					tabFrame.Visible = true
				end
			end
			EndDrag()
		end)
	end

	function TabFunction:MakeTab(...)
		local TabConfig = ParseTabArgs(ResolveArgs(TabFunction, "MakeTab", ...))
		local ef, frame = BuildTab(TabConfig, TabHolder)
		if frame then
			frame.LayoutOrder = NextOrder()
			AttachDrag(frame)
		end
		return ef
	end

	function TabFunction:MakeTabGroup(...)
		local GroupConfig = ParseGroupArgs(ResolveArgs(TabFunction, "MakeTabGroup", ...))
		local collapsed     = GroupConfig.Collapsed
		local groupFrames   = {}
		local headerCreated = false
		local AccentLine, GroupLabel
		local headerBtn

		local groupData = {frames = groupFrames, header = nil, collapsed = collapsed}
		table.insert(allGroups, groupData)

		local function SetCollapsed(state)
			collapsed = state
			groupData.collapsed = state
			for _, tf in ipairs(groupFrames) do tf.Visible = not collapsed end
			if AccentLine then
				TweenService:Create(AccentLine, TweenInfo.new(0.2), {BackgroundColor3 = collapsed and Color3.fromRGB(80,80,85) or ACCENT}):Play()
			end
			if GroupLabel then
				TweenService:Create(GroupLabel, TweenInfo.new(0.2), {TextColor3 = collapsed and Color3.fromRGB(95,95,105) or ACCENT_SOFT}):Play()
			end
		end

		local function EnsureHeader()
			if headerCreated then return end
			headerCreated = true
			headerBtn = Create("TextButton", {
				Size=UDim2.new(1,0,0,26), BackgroundTransparency=1,
				BorderSizePixel=0, Text="", AutoButtonColor=false,
				LayoutOrder=NextOrder(), Parent=TabHolder,
			})
			groupData.header = headerBtn
			GroupLabel = Create("TextLabel", {
				Size=UDim2.new(1,-16,1,0), Position=UDim2.new(0,12,0,0),
				BackgroundTransparency=1, Text=string.upper(GroupConfig.Name),
				TextColor3 = collapsed and Color3.fromRGB(95,95,105) or ACCENT_SOFT,
				TextSize=11, Font=Enum.Font.GothamBold,
				TextXAlignment=Enum.TextXAlignment.Left, Parent=headerBtn,
			})
			headerBtn.MouseButton1Click:Connect(function() SetCollapsed(not collapsed) end)
			headerBtn.MouseEnter:Connect(function() TweenService:Create(GroupLabel,TweenInfo.new(0.15),{TextColor3=Color3.fromRGB(214,204,255)}):Play() end)
			headerBtn.MouseLeave:Connect(function() TweenService:Create(GroupLabel,TweenInfo.new(0.15),{TextColor3=collapsed and Color3.fromRGB(95,95,105) or ACCENT_SOFT}):Play() end)
		end

		local GroupFunction = {}
		function GroupFunction:MakeTab(...)
			local TabConfig = ParseTabArgs(ResolveArgs(GroupFunction, "MakeTab", ...))
			EnsureHeader()
			local tabEF, tabBtn = BuildTab(TabConfig, TabHolder)
			if tabBtn then
				tabBtn.LayoutOrder = NextOrder()
				local pad = tabBtn:FindFirstChildOfClass("UIPadding")
				if not pad then pad = Instance.new("UIPadding"); pad.Parent = tabBtn end
				pad.PaddingLeft = UDim.new(0, 0)
				table.insert(groupFrames, tabBtn)
				tabGroupRegistry[tabBtn] = groupData
				tabBtn.Visible = not collapsed
				AttachDrag(tabBtn)
			end
			return tabEF
		end
		return AttachGroupAliases(GroupFunction)
	end

	return AttachWindowAliases(TabFunction)
end

local Configs_HUB = {
	Cor_Hub      = Color3.fromRGB(18,14,25),
	Cor_Options  = Color3.fromRGB(18,14,25),
	Cor_Stroke   = Color3.fromRGB(60,46,84),
	Cor_Text     = Color3.fromRGB(240,235,250),
	Cor_DarkText = Color3.fromRGB(155,140,180),
	Corner_Radius = UDim.new(0, 6),
	Text_Font    = Library.Font
}

local function Create2(instance, parent, props)
	local new = Instance.new(instance, parent)
	if props then for prop, value in pairs(props) do new[prop] = value end end
	return new
end

local function SetProps2(instance, props)
	if instance and props then for prop, value in pairs(props) do instance[prop] = value end end
	return instance
end

local function Corner2(parent, props)
	local new = Create2("UICorner", parent)
	new.CornerRadius = Configs_HUB.Corner_Radius
	if props then SetProps2(new, props) end
	return new
end

local function Stroke2(parent, props)
	local new = Create2("UIStroke", parent)
	new.Color = Configs_HUB.Cor_Stroke
	new.ApplyStrokeMode = "Border"
	if props then SetProps2(new, props) end
	return new
end

local function CreateTween(instance, prop, value, time, tweenWait)
	local tween = TweenService:Create(instance, TweenInfo.new(time, Enum.EasingStyle.Linear), {[prop] = value})
	tween:Play()
	if tweenWait then tween.Completed:Wait() end
end

local ScreenGui = Create2("ScreenGui", Container)

local Menu_Notifi = Create2("Frame", ScreenGui, {
	Size = UDim2.new(0,300,1,0),
	Position = UDim2.new(1,0,0,0),
	AnchorPoint = Vector2.new(1,0),
	BackgroundTransparency = 1
})

local Padding = Create2("UIPadding", Menu_Notifi, {
	PaddingLeft   = UDim.new(0,25),
	PaddingTop    = UDim.new(0,25),
	PaddingBottom = UDim.new(0,50)
})

local ListLayout = Create2("UIListLayout", Menu_Notifi, {
	Padding = UDim.new(0,15),
	VerticalAlignment = "Bottom"
})

function Library:MakeNotifi(...)
	return self:MakeNotification(...)
end

function Library:Destroy()
	Library.SearchRegistry = {}
	Container:Destroy()
end

-- ╔══════════════════════════════════════════════════════════════╗
-- ║   LIBRARY-LEVEL ALIASES & COMPATIBILITY LAYER                ║
-- ╚══════════════════════════════════════════════════════════════╝
local windowAliases = {"CreateWindow", "NewWindow", "AddWindow", "Window", "InitWindow", "CreateLib", "Create"}
for _, alias in ipairs(windowAliases) do
	Library[alias] = function(self, ...)
		return self:MakeWindow(...)
	end
end

local notifAliases = {"CreateNotification", "Notify", "Notification", "SendNotification", "AddNotification", "Alert"}
for _, alias in ipairs(notifAliases) do
	Library[alias] = function(self, ...)
		return self:MakeNotification(...)
	end
end

local destroyAliases = {"Unload", "Close", "Stop"}
for _, alias in ipairs(destroyAliases) do
	Library[alias] = function(self, ...)
		return self:Destroy(...)
	end
end

local libMt = getmetatable(Library) or {}
local oldLibIndex = libMt.__index
libMt.__index = function(t, key)
	if type(key) == "string" then
		local lk = key:lower()
		if lk:find("window") or lk:find("lib") then
			return rawget(t, "MakeWindow")
		elseif lk:find("notif") or lk:find("notify") or lk:find("alert") then
			return rawget(t, "MakeNotification")
		elseif lk:find("destroy") or lk:find("unload") or lk:find("close") then
			return rawget(t, "Destroy")
		end
	end
	if type(oldLibIndex) == "function" then return oldLibIndex(t, key) elseif type(oldLibIndex) == "table" then return oldLibIndex[key] end
	return rawget(t, key)
end
setmetatable(Library, libMt)

return Library
