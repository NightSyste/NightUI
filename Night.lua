local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local HttpService = game:GetService("HttpService")

local Library = {
	Elements = {},
	ThemeObjects = {},
	Connections = {},
	Flags = {},
	SearchRegistry = {},
	Themes = {
		Default = {
			Main = Color3.fromRGB(26, 26, 28),     -- Fenster / Content
			Second = Color3.fromRGB(28, 29, 30),   -- Element-Panel
			Sidebar = Color3.fromRGB(30, 30, 32),  -- linke Leiste
			Control = Color3.fromRGB(44, 44, 48),  -- Keybind / Textbox / Farbfeld
			Stroke = Color3.fromRGB(38, 38, 42),
			Divider = Color3.fromRGB(38, 38, 42),
			Text = Color3.fromRGB(220, 220, 224),
			TextDark = Color3.fromRGB(130, 130, 136),
			MainTransparency = 0.1,
			SecondTransparency = 0.15,
			FrameTransparency = 0.2
		}
	},
	SelectedTheme = "Default",
	Font = Enum.Font.Gotham
}

-- ╔══════════════════════════════════════════╗
-- ║   TRANSPARENZ (hier bequem anpassen)     ║
-- ╚══════════════════════════════════════════╝
-- 0 = deckend/grau, 1 = komplett unsichtbar
Library.Transparency = {
	Window  = 0.25, -- Fenster + Content-Bereich (durchscheinend wie im Bild)
	Sidebar = 0.12, -- linke Tab-Leiste
	Second  = 0,    -- Element-Panel (deckend)
	Control = 0.45, -- Keybind-Feld, Textbox-Feld, Farb-Vorschau
}

-- ╔══════════════════════════════════════════╗
-- ║        AKZENTFARBE (Lila / Purple)       ║
-- ╚══════════════════════════════════════════╝
Library.Accent     = Color3.fromRGB(121, 113, 192) -- Toggles, Slider (aus dem Screenshot)
Library.AccentText = Color3.fromRGB(150, 142, 230) -- aktiver Tab
Library.AccentSoft = Color3.fromRGB(128, 121, 190) -- Gruppen-Überschriften
local ACCENT       = Library.Accent
local ACCENT_TEXT  = Library.AccentText
local ACCENT_SOFT  = Library.AccentSoft

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

local function MakeResizable(ResizeButton, Main, MinSize, MaxSize, SetResizingCallback)
	pcall(function()
		local Resizing = false
		local StartSize, StartPos
		ResizeButton.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				Resizing = true
				if SetResizingCallback then SetResizingCallback(true) end
				StartSize = Main.Size
				StartPos = Vector2.new(Mouse.X, Mouse.Y)
			end
		end)
		ResizeButton.InputEnded:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				Resizing = false
				if SetResizingCallback then SetResizingCallback(false) end
			end
		end)
		UserInputService.InputChanged:Connect(function()
			if Resizing then
				local CurrentPos = Vector2.new(Mouse.X, Mouse.Y)
				local Delta = CurrentPos - StartPos
				local NewWidth = math.clamp(StartSize.X.Offset + Delta.X, MinSize.X, MaxSize.X)
				local NewHeight = math.clamp(StartSize.Y.Offset + Delta.Y, MinSize.Y, MaxSize.Y)
				Main.Size = UDim2.new(0, NewWidth, 0, NewHeight)
			end
		end)
	end)
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

-- Text eines Elements (fuer die Suche)
local function GetElementName(Frame)
	local Result = ""
	local Title = Frame:FindFirstChild("Title", true)
	if Title and Title:IsA("TextLabel") then Result = Result .. Title.Text .. " " end
	local Content = Frame:FindFirstChild("Content", true)
	if Content and Content:IsA("TextLabel") then Result = Result .. Content.Text end
	return Result
end

-- Element fuer die Suche registrieren + ggf. ins Panel einfuegen
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

local function SetTheme()
	for Name, Type in pairs(Library.ThemeObjects) do
		for _, Object in pairs(Type) do
			Object[ReturnProperty(Object)] = Library.Themes[Library.SelectedTheme][Name]
		end
	end
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
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://6895079853"
		sound.Volume = 0.5
		sound.Parent = game:GetService("SoundService")
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 1)
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

function Library:MakeNotification(NotificationConfig)
	spawn(function()
		NotificationConfig.Name    = NotificationConfig.Name    or "Notification"
		NotificationConfig.Content = NotificationConfig.Content or "Test"
		NotificationConfig.Image   = NotificationConfig.Image   or "rbxassetid://4384403532"
		NotificationConfig.Time    = NotificationConfig.Time    or 15

		local NotificationParent = SetProps(MakeElement("TFrame"), {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = NotificationHolder
		})

		local NotificationFrame = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(25,25,25), 0, 10), {
			Parent = NotificationParent,
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 0.15,
			AutomaticSize = Enum.AutomaticSize.Y
		}), {
			MakeElement("Stroke", Color3.fromRGB(93,93,93), 1.2),
			MakeElement("Padding", 12, 12, 12, 12),
			SetProps(MakeElement("Image", NotificationConfig.Image), {
				Size = UDim2.new(0, 20, 0, 20),
				ImageColor3 = Color3.fromRGB(240,240,240),
				Name = "Icon"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Name, 15), {
				Size = UDim2.new(1, -30, 0, 20),
				Position = UDim2.new(0, 30, 0, 0),
				Font = Enum.Font.GothamSemibold,
				Name = "Title"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Content, 14), {
				Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.new(0, 0, 0, 25),
				Font = Enum.Font.GothamSemibold,
				Name = "Content",
				AutomaticSize = Enum.AutomaticSize.Y,
				TextColor3 = Color3.fromRGB(200,200,200),
				TextWrapped = true
			})
		})

		TweenService:Create(NotificationFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0,0,0,0)}):Play()
		wait(NotificationConfig.Time)
		TweenService:Create(NotificationFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Position = UDim2.new(1,0,0,0)}):Play()
		wait(0.8)
		NotificationParent:Destroy()
	end)
end

function Library:MakeWindow(WindowConfig)
	local FirstTab = true
	local Minimized = false
	local Loaded = false
	local UIHidden = false

	WindowConfig = WindowConfig or {}
	WindowConfig.Name            = WindowConfig.Name            or "NightSystem"
	WindowConfig.HidePremium     = WindowConfig.HidePremium     or false
	WindowConfig.ConfigFolder    = WindowConfig.ConfigFolder     or WindowConfig.Name
	WindowConfig.SaveConfig      = WindowConfig.SaveConfig      or false
	if WindowConfig.IntroEnabled == nil then WindowConfig.IntroEnabled = true end
	WindowConfig.IntroToggleIcon = WindowConfig.IntroToggleIcon or "rbxassetid://8834748103"
	WindowConfig.IntroText       = WindowConfig.IntroText       or "Starting NightSystem..."
	WindowConfig.CloseCallback   = WindowConfig.CloseCallback   or function() end
	WindowConfig.ShowIcon        = WindowConfig.ShowIcon        or false
	WindowConfig.Icon            = WindowConfig.Icon            or "rbxassetid://8834748103"
	WindowConfig.IntroIcon       = WindowConfig.IntroIcon       or "rbxassetid://8834748103"
	WindowConfig.SearchCallback  = WindowConfig.SearchCallback  or function() end
	WindowConfig.ToggleKey       = WindowConfig.ToggleKey       or Enum.KeyCode.RightShift

	Library.SearchRegistry = {}
	local ToggleKeyName = (typeof(WindowConfig.ToggleKey) == "EnumItem" and WindowConfig.ToggleKey.Name or tostring(WindowConfig.ToggleKey)):gsub("(%l)(%u)", "%1 %2")

	Library.Folder  = WindowConfig.ConfigFolder
	Library.SaveCfg = WindowConfig.SaveConfig
	if WindowConfig.SaveConfig then
		pcall(function()
			if not isfolder(WindowConfig.ConfigFolder) then
				makefolder(WindowConfig.ConfigFolder)
			end
		end)
	end

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

	-- Lupe (als Vektor gezeichnet, braucht kein Asset)
	local SearchBtn = SetChildren(TopIcon(-133), {
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

	-- Chevron: Fenster ein-/ausklappen
	local MinimizeBtn = SetChildren(TopIcon(-101), {
		AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072706796"), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 18, 0, 18),
			Rotation = 180,
			Name = "Ico"
		}), "TextDark")
	})

	-- Minus: UI verstecken
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

	for _, Btn in pairs({SearchBtn, MinimizeBtn, HideBtn, CloseBtn}) do
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

	local WindowStuff = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 10), {
		Size = UDim2.new(0, 150, 1, -50),
		Position = UDim2.new(0, 0, 0, 50)
	}), {
		AddThemeObject(SetProps(MakeElement("Frame"), {Size = UDim2.new(1,0,0,10), Position = UDim2.new(0,0,0,0)}), "Sidebar"),
		AddThemeObject(SetProps(MakeElement("Frame"), {Size = UDim2.new(0,10,1,0), Position = UDim2.new(1,-10,0,0)}), "Sidebar"),
		AddThemeObject(SetProps(MakeElement("Frame"), {Size = UDim2.new(0,1,1,0), Position = UDim2.new(1,-1,0,0)}), "Stroke"),
		TabHolder,
		SetChildren(SetProps(MakeElement("TFrame"), {Size = UDim2.new(1,0,0,50), Position = UDim2.new(0,0,1,-50)}), {
			AddThemeObject(SetProps(MakeElement("Frame"), {Size = UDim2.new(1,0,0,1)}), "Stroke"),
			AddThemeObject(SetChildren(SetProps(MakeElement("Frame"), {
				AnchorPoint = Vector2.new(0,0.5),
				Size = UDim2.new(0,32,0,32),
				Position = UDim2.new(0,10,0.5,0),
				BackgroundTransparency = 0.2
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
				ClipsDescendants = true
			}), "Text"),
			SetProps(MakeElement("Label", ".gg/DjvzXcqd5m ", 12), {
				Size = UDim2.new(1,-60,0,12),
				Position = UDim2.new(0,50,1,-25),
				Visible = not WindowConfig.HidePremium,
				TextColor3 = ACCENT
			})
		}),
	}), "Sidebar")

	local WindowIcon = SetProps(MakeElement("Image", WindowConfig.Icon), {
		Size = UDim2.new(0,22,0,22),
		Position = UDim2.new(0,16,0,14),
		ImageColor3 = ACCENT,
		Visible = WindowConfig.ShowIcon and true or false,
		Name = "WindowIcon"
	})

	local WindowName = AddThemeObject(SetProps(MakeElement("Label", WindowConfig.Name, 18), {
		Size = UDim2.new(1,-140,0,50),
		Position = UDim2.new(0, WindowConfig.ShowIcon and 48 or 18, 0, 0),
		Font = Enum.Font.GothamBold,
		TextYAlignment = Enum.TextYAlignment.Center
	}), "Text")

	local SearchBox = AddThemeObject(Create("TextBox", {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = "Search...",
		PlaceholderColor3 = Color3.fromRGB(120, 120, 126),
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

	local MainWindow = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 10), {
		Parent = Container,
		Position = UDim2.new(0.5,-320,0.5,-169),
		Size = UDim2.new(0,640,0,338),
		ClipsDescendants = true,
		BackgroundTransparency = Library.Transparency.Window
	}), {
		SetChildren(SetProps(MakeElement("TFrame"), {Size = UDim2.new(1,0,0,50), Name = "TopBar"}), {
			WindowIcon,
			WindowName,
			SearchFrame,
			WindowTopBarLine,
			SearchBtn,
			MinimizeBtn,
			HideBtn,
			CloseBtn
		}),
		DragPoint,
		WindowStuff
	}), "Main")

	local SetResizingCallback = MakeDraggable(DragPoint, MainWindow)

	local MobileReopenButton = SetChildren(SetProps(MakeElement("Button"), {
		Parent = Container,
		Size = UDim2.new(0,40,0,40),
		Position = UDim2.new(0.5,-20,0,20),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Library.Themes[Library.SelectedTheme].Main,
		Visible = false
	}), {
		AddThemeObject(SetProps(MakeElement("Image", WindowConfig.IntroToggleIcon or "http://www.roblox.com/asset/?id=8834748103"), {
			AnchorPoint = Vector2.new(0.5,0.5),
			Position = UDim2.new(0.5,0,0.5,0),
			Size = UDim2.new(0.7,0,0.7,0),
		}), "Text"),
		MakeElement("Corner", 1)
	})

	local function HideUI()
		MainWindow.Visible = false
		if UserInputService.TouchEnabled then MobileReopenButton.Visible = true end
		UIHidden = true
		Library:MakeNotification({
			Name = "Interface Hidden",
			Content = UserInputService.TouchEnabled and ("Tap the button or press " .. ToggleKeyName .. " to reopen the interface") or ("Press " .. ToggleKeyName .. " to reopen the interface"),
			Time = 5
		})
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
		UIHidden = false
	end)

	AddConnection(MinimizeBtn.MouseButton1Up, function()
		if Minimized then
			TweenService:Create(MainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0,640,0,338)}):Play()
			MinimizeBtn.Ico.Rotation = 180
			wait(.02)
			MainWindow.ClipsDescendants = false
			WindowStuff.Visible = true
			WindowTopBarLine.Visible = true
		else
			MainWindow.ClipsDescendants = true
			WindowTopBarLine.Visible = false
			MinimizeBtn.Ico.Rotation = 0
			TweenService:Create(MainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, math.max(WindowName.TextBounds.X + 210, 320), 0, 50)}):Play()
			wait(0.1)
			WindowStuff.Visible = false
		end
		Minimized = not Minimized
	end)

	-- ╔══════════════════════════════════════════╗
	-- ║           NEUER LOADER (2025)            ║
	-- ╚══════════════════════════════════════════╝
	local function LoadSequence()
		MainWindow.Visible = false

		-- Haupt-Container: kompakt, zentriert, halbtransparent
		local LoaderFrame = Create("Frame", {
			Parent = Container,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.53, 0),
			Size = UDim2.new(0, 230, 0, 68),
			BackgroundColor3 = Color3.fromRGB(15, 15, 17),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 10
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = LoaderFrame})

		-- Äußerer Stroke (blau, leicht transparent)
		local FrameStroke = Create("UIStroke", {
			Parent = LoaderFrame,
			Color = ACCENT,
			Thickness = 0.8,
			Transparency = 0.5
		})

		-- Icon links
		local LogoIcon = Create("ImageLabel", {
			Parent = LoaderFrame,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, -8),
			Size = UDim2.new(0, 22, 0, 22),
			Image = WindowConfig.IntroIcon,
			BackgroundTransparency = 1,
			ImageColor3 = ACCENT,
			ImageTransparency = 1,
			ZIndex = 11
		})

		-- Titeltext (Name des Scripts)
		local TitleLabel = Create("TextLabel", {
			Parent = LoaderFrame,
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 44, 0, 9),
			Size = UDim2.new(1, -54, 0, 18),
			Text = WindowConfig.Name,
			TextColor3 = Color3.fromRGB(235, 235, 240),
			TextTransparency = 1,
			TextSize = 15,
			Font = Enum.Font.GothamBlack,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11
		})

		-- Statustext (wechselt während des Ladens)
		local StatusLabel = Create("TextLabel", {
			Parent = LoaderFrame,
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 44, 0, 30),
			Size = UDim2.new(1, -54, 0, 14),
			Text = "Initializing...",
			TextColor3 = ACCENT,
			TextTransparency = 1,
			TextSize = 11,
			Font = Enum.Font.GothamSemibold,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11
		})

		-- Fortschrittsleiste Hintergrund
		local BarBG = Create("Frame", {
			Parent = LoaderFrame,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -28, 0, 2),
			BackgroundColor3 = Color3.fromRGB(50, 50, 55),
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			ZIndex = 11
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = BarBG})

		-- Fortschrittsleiste Fill (der blaue Balken)
		local BarFill = Create("Frame", {
			Parent = BarBG,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = ACCENT,
			BorderSizePixel = 0,
			ZIndex = 12
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = BarFill})

		-- ── Einblend-Animation ──
		TweenService:Create(LoaderFrame, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundTransparency = 0.25
		}):Play()
		TweenService:Create(LogoIcon, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			ImageTransparency = 0
		}):Play()
		wait(0.15)
		TweenService:Create(TitleLabel,  TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
		TweenService:Create(StatusLabel, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()

		-- ── Fortschritts-Schritte ──
		local steps = {
			{ text = "Loading modules...",  progress = 0.25, delay = 0.30 },
			{ text = "Building UI...",      progress = 0.55, delay = 0.45 },
			{ text = "Applying themes...",  progress = 0.78, delay = 0.35 },
			{ text = "Almost ready...",     progress = 0.95, delay = 0.30 },
		}

		for _, step in ipairs(steps) do
			wait(step.delay)
			StatusLabel.Text = step.text
			TweenService:Create(BarFill, TweenInfo.new(step.delay + 0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Size = UDim2.new(step.progress, 0, 1, 0)
			}):Play()
			-- Stroke kurz aufleuchten lassen
			TweenService:Create(FrameStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Transparency = 0.05}):Play()
			wait(0.15)
			TweenService:Create(FrameStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Transparency = 0.5}):Play()
		end

		-- ── Abschluss: Bar auf 100% ──
		wait(0.2)
		StatusLabel.Text = "Done!"
		TweenService:Create(BarFill, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 1, 0)
		}):Play()
		TweenService:Create(FrameStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Transparency = 0}):Play()
		wait(0.45)

		-- ── Ausblend-Animation (nach oben gleiten) ──
		TweenService:Create(LoaderFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.47, 0)
		}):Play()
		TweenService:Create(LogoIcon,    TweenInfo.new(0.25, Enum.EasingStyle.Quad), {ImageTransparency = 1}):Play()
		TweenService:Create(TitleLabel,  TweenInfo.new(0.25, Enum.EasingStyle.Quad), {TextTransparency  = 1}):Play()
		TweenService:Create(StatusLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {TextTransparency  = 1}):Play()
		TweenService:Create(FrameStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Transparency      = 1}):Play()
		wait(0.4)

		LoaderFrame:Destroy()
		MainWindow.Visible = true
	end

	if WindowConfig.IntroEnabled then LoadSequence() end

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
			TweenService:Create(TabFrame.Ico,   TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0, ImageColor3 = ACCENT_TEXT}):Play()
			TweenService:Create(TabFrame.Title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency  = 0, TextColor3  = ACCENT_TEXT}):Play()
			TabFrame.Title.Font = Enum.Font.GothamBold
			TabItemContainer.Visible = true
		end

		AddConnection(TabFrame.MouseButton1Click, function()
			local sound = Instance.new("Sound") sound.SoundId = "rbxassetid://6895079853" sound.Volume = 0.5 sound.Parent = game:GetService("SoundService") sound:Play() game:GetService("Debris"):AddItem(sound, 1)
			ActivateTab()
		end)

		local function GetElements(ItemParent, InPanel)
			local ElementFunction = {}

			function ElementFunction:AddLabel(Text)
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
					if LabelFrame:FindFirstChild("Content") then LabelFrame.Content.Text = ToChange end
				end
				return LabelFunction
			end

			function ElementFunction:AddParagraph(Text, Content)
				Text    = Text    or "Text"
				Content = Content or "Content"
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
				function ParagraphFunction:Set(ToChange) ParagraphFrame.Content.Text = ToChange end
				return ParagraphFunction
			end

			function ElementFunction:AddButton(ButtonConfig)
				ButtonConfig = ButtonConfig or {}
				ButtonConfig.Name     = ButtonConfig.Name     or "Button"
				ButtonConfig.Callback = ButtonConfig.Callback or function() end
				ButtonConfig.Icon     = ButtonConfig.Icon     or "rbxassetid://3944703587"
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
				AddConnection(Click.MouseEnter,      function() TweenService:Create(ButtonFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+3, Library.Themes[Library.SelectedTheme].Second.G*255+3, Library.Themes[Library.SelectedTheme].Second.B*255+3)}):Play() end)
				AddConnection(Click.MouseLeave,      function() TweenService:Create(ButtonFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Library.Themes[Library.SelectedTheme].Second}):Play() end)
				AddConnection(Click.MouseButton1Up,  function()
					local sound = Instance.new("Sound") sound.SoundId = "rbxassetid://6895079853" sound.Volume = 0.5 sound.Parent = game:GetService("SoundService") sound:Play() game:GetService("Debris"):AddItem(sound, 1)
					TweenService:Create(ButtonFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+3, Library.Themes[Library.SelectedTheme].Second.G*255+3, Library.Themes[Library.SelectedTheme].Second.B*255+3)}):Play()
					spawn(function() ButtonConfig.Callback() end)
				end)
				AddConnection(Click.MouseButton1Down, function() TweenService:Create(ButtonFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+6, Library.Themes[Library.SelectedTheme].Second.G*255+6, Library.Themes[Library.SelectedTheme].Second.B*255+6)}):Play() end)
				function Button:Set(ButtonText) ButtonFrame.Content.Text = ButtonText end
				return Button
			end

			function ElementFunction:AddToggle(ToggleConfig)
				ToggleConfig = ToggleConfig or {}
				ToggleConfig.Name     = ToggleConfig.Name     or "Toggle"
				ToggleConfig.Default  = ToggleConfig.Default  or false
				ToggleConfig.Callback = ToggleConfig.Callback or function() end
				ToggleConfig.Color    = ToggleConfig.Color    or ACCENT
				ToggleConfig.Flag     = ToggleConfig.Flag     or nil
				ToggleConfig.Save     = ToggleConfig.Save     or false

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
				AddConnection(Click.MouseEnter,       function() TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+3, Library.Themes[Library.SelectedTheme].Second.G*255+3, Library.Themes[Library.SelectedTheme].Second.B*255+3)}):Play() end)
				AddConnection(Click.MouseLeave,       function() TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Library.Themes[Library.SelectedTheme].Second}):Play() end)
				AddConnection(Click.MouseButton1Up,   function()
					local sound = Instance.new("Sound") sound.SoundId = "rbxassetid://6895079853" sound.Volume = 0.5 sound.Parent = game:GetService("SoundService") sound:Play() game:GetService("Debris"):AddItem(sound, 1)
					TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+3, Library.Themes[Library.SelectedTheme].Second.G*255+3, Library.Themes[Library.SelectedTheme].Second.B*255+3)}):Play()
					Toggle:Set(not Toggle.Value)
					SaveCfg(game.GameId)
				end)
				AddConnection(Click.MouseButton1Down, function() TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+6, Library.Themes[Library.SelectedTheme].Second.G*255+6, Library.Themes[Library.SelectedTheme].Second.B*255+6)}):Play() end)

				if ToggleConfig.Flag then Library.Flags[ToggleConfig.Flag] = Toggle end
				return Toggle
			end

			function ElementFunction:AddSlider(SliderConfig)
				SliderConfig = SliderConfig or {}
				SliderConfig.Name      = SliderConfig.Name      or "Slider"
				SliderConfig.Min       = SliderConfig.Min       or 0
				SliderConfig.Max       = SliderConfig.Max       or 100
				SliderConfig.Increment = SliderConfig.Increment or 1
				SliderConfig.Default   = SliderConfig.Default   or 50
				SliderConfig.Callback  = SliderConfig.Callback  or function() end
				SliderConfig.ValueName = SliderConfig.ValueName or ""
				SliderConfig.Color     = SliderConfig.Color     or ACCENT
				SliderConfig.Flag      = SliderConfig.Flag      or nil
				SliderConfig.Save      = SliderConfig.Save      or false

				local Slider = {Value = SliderConfig.Default, Save = SliderConfig.Save, Type = "Slider"}
				local Dragging = false

				local SliderDrag = SetChildren(SetProps(MakeElement("RoundFrame", SliderConfig.Color, 0, 5), {
					Size = UDim2.new(0,0,1,0),
					BackgroundTransparency = 0.3,
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
						local sound = Instance.new("Sound") sound.SoundId = "rbxassetid://6895079853" sound.Volume = 0.5 sound.Parent = game:GetService("SoundService") sound:Play() game:GetService("Debris"):AddItem(sound, 1)
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

			function ElementFunction:AddDropdown(DropdownConfig)
				DropdownConfig = DropdownConfig or {}
				DropdownConfig.Name     = DropdownConfig.Name     or "Dropdown"
				DropdownConfig.Options  = DropdownConfig.Options  or {}
				DropdownConfig.Default  = DropdownConfig.Default  or ""
				DropdownConfig.Callback = DropdownConfig.Callback or function() end
				DropdownConfig.Flag     = DropdownConfig.Flag     or nil
				DropdownConfig.Save     = DropdownConfig.Save     or false

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
							local sound = Instance.new("Sound") sound.SoundId = "rbxassetid://6895079853" sound.Volume = 0.5 sound.Parent = game:GetService("SoundService") sound:Play() game:GetService("Debris"):AddItem(sound, 1)
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
					local sound = Instance.new("Sound") sound.SoundId = "rbxassetid://6895079853" sound.Volume = 0.5 sound.Parent = game:GetService("SoundService") sound:Play() game:GetService("Debris"):AddItem(sound, 1)
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

			function ElementFunction:AddBind(BindConfig)
				BindConfig = BindConfig or {}
				BindConfig.Name     = BindConfig.Name     or "Bind"
				BindConfig.Default  = BindConfig.Default  or Enum.KeyCode.Unknown
				BindConfig.Hold     = BindConfig.Hold     or false
				BindConfig.Callback = BindConfig.Callback or function() end
				BindConfig.Flag     = BindConfig.Flag     or nil
				BindConfig.Save     = BindConfig.Save     or false

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
						BindBox.Value.Text = ""
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
				AddConnection(Click.MouseEnter,       function() TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+3, Library.Themes[Library.SelectedTheme].Second.G*255+3, Library.Themes[Library.SelectedTheme].Second.B*255+3)}):Play() end)
				AddConnection(Click.MouseLeave,       function() TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Library.Themes[Library.SelectedTheme].Second}):Play() end)
				AddConnection(Click.MouseButton1Up,   function() TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+3, Library.Themes[Library.SelectedTheme].Second.G*255+3, Library.Themes[Library.SelectedTheme].Second.B*255+3)}):Play() end)
				AddConnection(Click.MouseButton1Down, function() TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+6, Library.Themes[Library.SelectedTheme].Second.G*255+6, Library.Themes[Library.SelectedTheme].Second.B*255+6)}):Play() end)

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

			function ElementFunction:AddTextbox(TextboxConfig)
				TextboxConfig = TextboxConfig or {}
				TextboxConfig.Name          = TextboxConfig.Name          or "Textbox"
				TextboxConfig.Default       = TextboxConfig.Default       or ""
				TextboxConfig.TextDisappear = TextboxConfig.TextDisappear or false
				TextboxConfig.Callback      = TextboxConfig.Callback      or function() end

				local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1,0,1,0)})
				local TextboxActual = AddThemeObject(Create("TextBox", {
					Size = UDim2.new(1,0,1,0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255,255,255),
					PlaceholderColor3 = Color3.fromRGB(210,210,210),
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
				AddConnection(Click.MouseEnter,       function() TweenService:Create(TextboxFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+3, Library.Themes[Library.SelectedTheme].Second.G*255+3, Library.Themes[Library.SelectedTheme].Second.B*255+3)}):Play() end)
				AddConnection(Click.MouseLeave,       function() TweenService:Create(TextboxFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Library.Themes[Library.SelectedTheme].Second}):Play() end)
				AddConnection(Click.MouseButton1Up,   function()
					TweenService:Create(TextboxFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+3, Library.Themes[Library.SelectedTheme].Second.G*255+3, Library.Themes[Library.SelectedTheme].Second.B*255+3)}):Play()
					TextboxActual:CaptureFocus()
				end)
				AddConnection(Click.MouseButton1Down, function() TweenService:Create(TextboxFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(Library.Themes[Library.SelectedTheme].Second.R*255+6, Library.Themes[Library.SelectedTheme].Second.G*255+6, Library.Themes[Library.SelectedTheme].Second.B*255+6)}):Play() end)
			end

			function ElementFunction:AddColorpicker(ColorpickerConfig)
				ColorpickerConfig = ColorpickerConfig or {}
				ColorpickerConfig.Name     = ColorpickerConfig.Name     or "Colorpicker"
				ColorpickerConfig.Default  = ColorpickerConfig.Default  or Color3.fromRGB(255,255,255)
				ColorpickerConfig.Callback = ColorpickerConfig.Callback or function() end
				ColorpickerConfig.Flag     = ColorpickerConfig.Flag     or nil
				ColorpickerConfig.Save     = ColorpickerConfig.Save     or false

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
					local sound = Instance.new("Sound") sound.SoundId = "rbxassetid://6895079853" sound.Volume = 0.5 sound.Parent = game:GetService("SoundService") sound:Play() game:GetService("Debris"):AddItem(sound, 1)
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

			return ElementFunction
		end

		local ElementFunction = {}

		function ElementFunction:AddSection(SectionConfig)
			SectionConfig = SectionConfig or {}
			SectionConfig.Name = SectionConfig.Name or "Section"
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
			return SectionFunction
		end

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
		return ElementFunction, TabFrame
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

	function TabFunction:MakeTab(TabConfig)
		local ef, frame = BuildTab(TabConfig, TabHolder)
		if frame then
			frame.LayoutOrder = NextOrder()
			AttachDrag(frame)
		end
		return ef
	end

	function TabFunction:MakeTabGroup(GroupConfig)
		GroupConfig = GroupConfig or {}
		GroupConfig.Name      = GroupConfig.Name      or "Group"
		GroupConfig.Collapsed = GroupConfig.Collapsed or false

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
		function GroupFunction:MakeTab(TabConfig)
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
		return GroupFunction
	end

	return TabFunction
end

local Configs_HUB = {
	Cor_Hub      = Color3.fromRGB(15,15,15),
	Cor_Options  = Color3.fromRGB(15,15,15),
	Cor_Stroke   = Color3.fromRGB(60,60,60),
	Cor_Text     = Color3.fromRGB(240,240,240),
	Cor_DarkText = Color3.fromRGB(140,140,140),
	Corner_Radius = UDim.new(0, 4),
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

function Library:MakeNotifi(Configs)
	local Title    = Configs.Title or "Title!"
	local text     = Configs.Text  or "Notification content... what will it say??"
	local timewait = Configs.Time  or 5

	local Frame1 = Create2("Frame", Menu_Notifi, {Size=UDim2.new(2,0,0,0), BackgroundTransparency=1, AutomaticSize="Y", Name="Title"})
	local Frame2 = Create2("Frame", Frame1, {
		Size=UDim2.new(0, Menu_Notifi.Size.X.Offset-50, 0, 0),
		BackgroundColor3=Configs_HUB.Cor_Hub,
		Position=UDim2.new(0, Menu_Notifi.Size.X.Offset, 0, 0),
		AutomaticSize="Y",
		BackgroundTransparency=0.15
	}) Corner2(Frame2)

	local TextLabel = Create2("TextLabel", Frame2, {
		Size=UDim2.new(1,0,0,25), Font=Configs_HUB.Text_Font,
		BackgroundTransparency=1, Text=Title, TextSize=20,
		Position=UDim2.new(0,20,0,5), TextXAlignment="Left", TextColor3=Configs_HUB.Cor_Text
	})
	local TextButton = Create2("TextButton", Frame2, {
		Text="X", Font=Configs_HUB.Text_Font, TextSize=20,
		BackgroundTransparency=1, TextColor3=Color3.fromRGB(200,200,200),
		Position=UDim2.new(1,-5,0,5), AnchorPoint=Vector2.new(1,0), Size=UDim2.new(0,25,0,25)
	})
	local TextLabel2 = Create2("TextLabel", Frame2, {
		Size=UDim2.new(1,-30,0,0),
		Position=UDim2.new(0,20,0,TextButton.Size.Y.Offset+10),
		TextSize=15, TextColor3=Configs_HUB.Cor_DarkText,
		TextXAlignment="Left", TextYAlignment="Top",
		AutomaticSize=Enum.AutomaticSize.Y, Text=text,
		Font=Configs_HUB.Text_Font, BackgroundTransparency=1, TextWrapped=true
	})

	local FrameSize = Create2("Frame", Frame2, {
		Size=UDim2.new(1,0,0,2), BackgroundColor3=Configs_HUB.Cor_Stroke,
		Position=UDim2.new(0,2,0,30), BorderSizePixel=0
	}) Corner2(FrameSize)
	Create2("Frame", Frame2, {Size=UDim2.new(0,0,0,5), Position=UDim2.new(0,0,1,5), BackgroundTransparency=1})

	task.spawn(function() CreateTween(FrameSize, "Size", UDim2.new(0,0,0,2), timewait, true) end)

	TextButton.MouseButton1Click:Connect(function()
		CreateTween(Frame2, "Position", UDim2.new(0,-20,0,0), 0.1, true)
		CreateTween(Frame2, "Position", UDim2.new(0,Menu_Notifi.Size.X.Offset,0,0), 0.5, true)
		Frame1:Destroy()
	end)

	task.spawn(function()
		CreateTween(Frame2, "Position", UDim2.new(0,-20,0,0), 0.5, true)
		CreateTween(Frame2, "Position", UDim2.new(), 0.1, true)
		task.wait(timewait)
		if Frame2 then
			CreateTween(Frame2, "Position", UDim2.new(0,-20,0,0), 0.1, true)
			CreateTween(Frame2, "Position", UDim2.new(0,Menu_Notifi.Size.X.Offset,0,0), 0.5, true)
			Frame1:Destroy()
		end
	end)
end

function Library:Destroy()
	Library.SearchRegistry = {}
	Container:Destroy()
end

return Library
