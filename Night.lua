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
			Main = Color3.fromRGB(20, 20, 22),
			Second = Color3.fromRGB(30, 30, 32),
			Stroke = Color3.fromRGB(60, 60, 65),
			Divider = Color3.fromRGB(40, 40, 45),
			Text = Color3.fromRGB(240, 240, 245),
			TextDark = Color3.fromRGB(160, 160, 165),
			MainTransparency = 0.1,
			SecondTransparency = 0.15,
			FrameTransparency = 0.2
		}
	},
	SelectedTheme = "Default",
	Font = Enum.Font.Gotham
}

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
	table.foreach(Data, function(a, b)
		if Library.Flags[a] then
			spawn(function()
				if Library.Flags[a].Type == "Colorpicker" then
					Library.Flags[a]:Set(UnpackColor(b))
				else
					Library.Flags[a]:Set(b)
				end
			end)
		end
	end)
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
		if resizing then Dragging = false end
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
	table.foreach(Props, function(Property, Value) Element[Property] = Value end)
	return Element
end

local function SetChildren(Element, Children)
	table.foreach(Children, function(_, Child) Child.Parent = Element end)
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
	return Object
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
				Font = Enum.Font.FredokaOne,
				Name = "Title"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Content, 14), {
				Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.new(0, 0, 0, 25),
				Font = Enum.Font.FredokaOne,
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

	local CloseBtn = SetChildren(SetProps(MakeElement("Button"), {
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		BackgroundTransparency = 1
	}), {
		AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072725342"), {
			Position = UDim2.new(0, 9, 0, 6),
			Size = UDim2.new(0, 18, 0, 18)
		}), "Text")
	})

	local MinimizeBtn = SetChildren(SetProps(MakeElement("Button"), {
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1
	}), {
		AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072719338"), {
			Position = UDim2.new(0, 9, 0, 6),
			Size = UDim2.new(0, 18, 0, 18),
			Name = "Ico"
		}), "Text")
	})

	local DragPoint = SetProps(MakeElement("TFrame"), {Size = UDim2.new(1, 0, 0, 50)})

	local WindowStuff = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 10), {
		Size = UDim2.new(0, 150, 1, -50),
		Position = UDim2.new(0, 0, 0, 50),
		BackgroundTransparency = 0.15
	}), {
		AddThemeObject(SetProps(MakeElement("Frame"), {Size = UDim2.new(1,0,0,10), Position = UDim2.new(0,0,0,0), BackgroundTransparency = 0.15}), "Second"),
		AddThemeObject(SetProps(MakeElement("Frame"), {Size = UDim2.new(0,10,1,0), Position = UDim2.new(1,-10,0,0), BackgroundTransparency = 0.15}), "Second"),
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
				AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://4031889928"), {Size = UDim2.new(1,0,1,0)}), "Second"),
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
				Font = Enum.Font.FredokaOne,
				ClipsDescendants = true
			}), "Text"),
			SetProps(MakeElement("Label", ".gg/DjvzXcqd5m ", 12), {
				Size = UDim2.new(1,-60,0,12),
				Position = UDim2.new(0,50,1,-25),
				Visible = not WindowConfig.HidePremium,
				TextColor3 = Color3.fromRGB(135, 206, 250)
			})
		}),
	}), "Second")

	local WindowName = AddThemeObject(SetProps(MakeElement("Label", WindowConfig.Name, 14), {
		Size = UDim2.new(1,-30,2,0),
		Position = UDim2.new(0,25,0,-24),
		Font = Enum.Font.GothamBlack,
		TextSize = 20
	}), "Text")

	local WindowTopBarLine = AddThemeObject(SetProps(MakeElement("Frame"), {
		Size = UDim2.new(1,0,0,1),
		Position = UDim2.new(0,0,1,-1)
	}), "Stroke")

	local MainWindow = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 10), {
		Parent = Container,
		Position = UDim2.new(0.5,-307,0.5,-172),
		Size = UDim2.new(0,615,0,344),
		ClipsDescendants = true,
		BackgroundTransparency = 0.1
	}), {
		SetChildren(SetProps(MakeElement("TFrame"), {Size = UDim2.new(1,0,0,50), Name = "TopBar"}), {
			WindowName,
			WindowTopBarLine,
			AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 7), {
				Size = UDim2.new(0,70,0,30),
				Position = UDim2.new(1,-85,0,10),
				BackgroundTransparency = 0.15
			}), {
				AddThemeObject(MakeElement("Stroke"), "Stroke"),
				AddThemeObject(SetProps(MakeElement("Frame"), {Size = UDim2.new(0,1,1,0), Position = UDim2.new(0.5,0,0,0)}), "Stroke"),
				MinimizeBtn,
				CloseBtn
			}), "Second"),
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

	AddConnection(CloseBtn.MouseButton1Up, function()
		MainWindow.Visible = false
		if UserInputService.TouchEnabled then MobileReopenButton.Visible = true end
		UIHidden = true
		Library:MakeNotification({
			Name = "Interface Hidden",
			Content = UserInputService.TouchEnabled and "Tap the button or Left Control to reopen the interface" or "Press Left Control to reopen the interface",
			Time = 5
		})
		WindowConfig.CloseCallback()
	end)

	AddConnection(UserInputService.InputBegan, function(Input)
		if Input.KeyCode == Enum.KeyCode.LeftControl and UIHidden == true then
			MainWindow.Visible = true
			MobileReopenButton.Visible = false
		end
	end)

	AddConnection(MobileReopenButton.Activated, function()
		MainWindow.Visible = true
		MobileReopenButton.Visible = false
	end)

	AddConnection(MinimizeBtn.MouseButton1Up, function()
		if Minimized then
			TweenService:Create(MainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0,615,0,344)}):Play()
			MinimizeBtn.Ico.Image = "rbxassetid://7072719338"
			wait(.02)
			MainWindow.ClipsDescendants = false
			WindowStuff.Visible = true
			WindowTopBarLine.Visible = true
		else
			MainWindow.ClipsDescendants = true
			WindowTopBarLine.Visible = false
			MinimizeBtn.Ico.Image = "rbxassetid://7072720870"
			TweenService:Create(MainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, WindowName.TextBounds.X + 140, 0, 50)}):Play()
			wait(0.1)
			WindowStuff.Visible = false
		end
		Minimized = not Minimized
	end)

	-- =============================================
	-- NEUER LOADER (ersetzt die alte LoadSequence)
	-- =============================================
	local function LoadSequence()
		MainWindow.Visible = false

		-- Dunkler Vollbild-Hintergrund
		local LoadBG = Create("Frame", {
			Parent = Container,
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = Color3.fromRGB(10, 10, 12),
			BorderSizePixel = 0,
			ZIndex = 100
		})

		-- Subtiles Punkte-Grid
		local GridFrame = Create("Frame", {
			Parent = LoadBG,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 101
		})
		for row = 0, 20 do
			for col = 0, 35 do
				local dot = Create("Frame", {
					Parent = GridFrame,
					Size = UDim2.new(0, 1, 0, 1),
					Position = UDim2.new(0, col * 38, 0, row * 38),
					BackgroundColor3 = Color3.fromRGB(135, 206, 250),
					BackgroundTransparency = 0.92,
					BorderSizePixel = 0,
					ZIndex = 101
				})
			end
		end

		-- Äußerer Ring (langsam, CW)
		local Ring1 = Create("Frame", {
			Parent = LoadBG,
			Size = UDim2.new(0, 110, 0, 110),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -90),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 102
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Ring1})
		Create("UIStroke", {
			Parent = Ring1,
			Color = Color3.fromRGB(135, 206, 250),
			Thickness = 2,
			Transparency = 0.15
		})

		-- Mittlerer Ring (mittel, CCW)
		local Ring2 = Create("Frame", {
			Parent = LoadBG,
			Size = UDim2.new(0, 84, 0, 84),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -90),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 102
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Ring2})
		Create("UIStroke", {
			Parent = Ring2,
			Color = Color3.fromRGB(135, 206, 250),
			Thickness = 1.5,
			Transparency = 0.45
		})

		-- Innerer Ring (schnell, CW)
		local Ring3 = Create("Frame", {
			Parent = LoadBG,
			Size = UDim2.new(0, 60, 0, 60),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -90),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 102
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Ring3})
		Create("UIStroke", {
			Parent = Ring3,
			Color = Color3.fromRGB(135, 206, 250),
			Thickness = 1,
			Transparency = 0.65
		})

		-- Logo-Box in der Mitte der Ringe
		local LogoBox = Create("Frame", {
			Parent = LoadBG,
			Size = UDim2.new(0, 34, 0, 34),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -90),
			BackgroundColor3 = Color3.fromRGB(135, 206, 250),
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			ZIndex = 103
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = LogoBox})
		Create("UIStroke", {
			Parent = LogoBox,
			Color = Color3.fromRGB(135, 206, 250),
			Thickness = 1,
			Transparency = 0.4
		})

		-- Kreuz-Icon in der Logo-Box
		local IconH = Create("Frame", {
			Parent = LogoBox,
			Size = UDim2.new(0, 14, 0, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundColor3 = Color3.fromRGB(135, 206, 250),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 104
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = IconH})
		local IconV = Create("Frame", {
			Parent = LogoBox,
			Size = UDim2.new(0, 2, 0, 14),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundColor3 = Color3.fromRGB(135, 206, 250),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 104
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = IconV})

		-- Haupt-Titel (NIGHTSYSTEM)
		local TitleLabel = Create("TextLabel", {
			Parent = LoadBG,
			Size = UDim2.new(0, 320, 0, 32),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -20),
			BackgroundTransparency = 1,
			Text = string.upper(WindowConfig.Name),
			TextColor3 = Color3.fromRGB(232, 232, 236),
			TextSize = 22,
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTransparency = 1,
			ZIndex = 103
		})

		-- Untertitel (LOADING)
		local SubLabel = Create("TextLabel", {
			Parent = LoadBG,
			Size = UDim2.new(0, 320, 0, 16),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 5),
			BackgroundTransparency = 1,
			Text = "LOADING",
			TextColor3 = Color3.fromRGB(135, 206, 250),
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTransparency = 1,
			ZIndex = 103
		})

		-- Progress Bar Hintergrund
		local ProgressBG = Create("Frame", {
			Parent = LoadBG,
			Size = UDim2.new(0, 260, 0, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 30),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.92,
			BorderSizePixel = 0,
			ZIndex = 103
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ProgressBG})

		-- Progress Bar Fill
		local ProgressFill = Create("Frame", {
			Parent = ProgressBG,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(135, 206, 250),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 104
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ProgressFill})

		-- Status Text (links)
		local StatusLabel = Create("TextLabel", {
			Parent = LoadBG,
			Size = UDim2.new(0, 200, 0, 14),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.5, -130, 0.5, 45),
			BackgroundTransparency = 1,
			Text = "Initialisiere...",
			TextColor3 = Color3.fromRGB(135, 206, 250),
			TextSize = 10,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 0.4,
			ZIndex = 103
		})

		-- Prozent (rechts)
		local PctLabel = Create("TextLabel", {
			Parent = LoadBG,
			Size = UDim2.new(0, 60, 0, 14),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(0.5, 130, 0.5, 45),
			BackgroundTransparency = 1,
			Text = "0%",
			TextColor3 = Color3.fromRGB(135, 206, 250),
			TextSize = 10,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTransparency = 0.25,
			ZIndex = 103
		})

		-- Step-Dots + Labels
		local stepNames = {"System Check", "Interface", "Themes", "Config", "Bereit"}
		local stepDots  = {}
		local stepLabels = {}
		local totalSteps = 5
		local dotSpacing = 52
		local startX = -(dotSpacing * (totalSteps - 1) / 2)

		for i = 1, totalSteps do
			local dot = Create("Frame", {
				Parent = LoadBG,
				Size = UDim2.new(0, 5, 0, 5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, startX + (i-1)*dotSpacing, 0.5, 65),
				BackgroundColor3 = Color3.fromRGB(135, 206, 250),
				BackgroundTransparency = 0.8,
				BorderSizePixel = 0,
				ZIndex = 103
			})
			Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = dot})
			stepDots[i] = dot

			local lbl = Create("TextLabel", {
				Parent = LoadBG,
				Size = UDim2.new(0, 60, 0, 12),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, startX + (i-1)*dotSpacing, 0.5, 80),
				BackgroundTransparency = 1,
				Text = stepNames[i],
				TextColor3 = Color3.fromRGB(135, 206, 250),
				TextSize = 8,
				Font = Enum.Font.Gotham,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTransparency = 0.7,
				ZIndex = 103
			})
			stepLabels[i] = lbl
		end

		-- Spin-Verbindungen
		local spinConn
		local a1, a2, a3 = 0, 0, 0
		spinConn = RunService.RenderStepped:Connect(function(dt)
			a1 = a1 + dt * 90
			a2 = a2 - dt * 140
			a3 = a3 + dt * 220
			Ring1.Rotation = a1
			Ring2.Rotation = a2
			Ring3.Rotation = a3
		end)

		-- Hilfsfunktion: Progress animieren
		local currentPct = 0
		local function AnimateProgress(targetPct, duration)
			local startP = currentPct
			local elapsed = 0
			local conn2
			conn2 = RunService.RenderStepped:Connect(function(dt)
				elapsed = elapsed + dt
				local t = math.min(elapsed / duration, 1)
				local ease = 1 - math.pow(1 - t, 3)
				local val = math.floor(startP + (targetPct - startP) * ease)
				currentPct = val
				ProgressFill.Size = UDim2.new(val / 100, 0, 1, 0)
				PctLabel.Text = val .. "%"
				if t >= 1 then conn2:Disconnect() end
			end)
		end

		-- Hilfsfunktion: Steps aktualisieren
		local function SetStep(idx)
			for i = 1, totalSteps do
				local dot = stepDots[i]
				local lbl = stepLabels[i]
				if i < idx then
					TweenService:Create(dot, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.05, BackgroundColor3 = Color3.fromRGB(135,206,250)}):Play()
					TweenService:Create(lbl, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0.15, TextColor3 = Color3.fromRGB(135,206,250)}):Play()
				elseif i == idx then
					TweenService:Create(dot, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.3}):Play()
					TweenService:Create(lbl, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0.35}):Play()
				else
					TweenService:Create(dot, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.82}):Play()
					TweenService:Create(lbl, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0.72}):Play()
				end
			end
		end

		-- Elemente einblenden
		TweenService:Create(TitleLabel, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
		TweenService:Create(SubLabel,   TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.3}):Play()

		wait(0.4)

		-- Schritt 1: System Check
		SetStep(1)
		StatusLabel.Text = "System Check..."
		AnimateProgress(20, 0.45)
		wait(0.55)

		-- Schritt 2: Interface laden
		SetStep(2)
		StatusLabel.Text = "Interface laden..."
		AnimateProgress(45, 0.4)
		wait(0.5)

		-- Schritt 3: Themes anwenden
		SetStep(3)
		StatusLabel.Text = "Themes anwenden..."
		AnimateProgress(72, 0.4)
		wait(0.55)

		-- Schritt 4: Config lesen
		SetStep(4)
		StatusLabel.Text = "Config lesen..."
		AnimateProgress(90, 0.3)
		wait(0.4)

		-- Schritt 5: Bereit
		SetStep(5)
		StatusLabel.Text = "Abgeschlossen!"
		AnimateProgress(100, 0.25)
		wait(0.55)

		-- Alles ausblenden
		spinConn:Disconnect()

		TweenService:Create(LoadBG, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
		TweenService:Create(TitleLabel,  TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
		TweenService:Create(SubLabel,    TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
		TweenService:Create(StatusLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
		TweenService:Create(PctLabel,    TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
		TweenService:Create(ProgressBG,  TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
		TweenService:Create(ProgressFill,TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
		TweenService:Create(Ring1, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
		TweenService:Create(Ring2, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
		TweenService:Create(Ring3, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
		TweenService:Create(LogoBox, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
		for i = 1, totalSteps do
			TweenService:Create(stepDots[i],   TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
			TweenService:Create(stepLabels[i], TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
		end

		wait(0.65)
		LoadBG:Destroy()
		MainWindow.Visible = true
		Library:Init()
	end
	-- =============================================
	-- ENDE NEUER LOADER
	-- =============================================

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
				Font = Enum.Font.GothamBlack,
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
			MakeElement("List", 0, 6),
			MakeElement("Padding", 15, 10, 10, 15)
		}), "Divider")

		AddConnection(TabItemContainer.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
			TabItemContainer.CanvasSize = UDim2.new(0, 0, 0, TabItemContainer.UIListLayout.AbsoluteContentSize.Y + 30)
		end)

		if FirstTab then
			FirstTab = false
			TabFrame.Ico.ImageTransparency = 0
			TabFrame.Title.TextTransparency = 0
			TabFrame.Title.Font = Enum.Font.GothamBlack
			TabFrame.Ico.ImageColor3 = Color3.fromRGB(135, 206, 250)
			TabFrame.Title.TextColor3 = Color3.fromRGB(135, 206, 250)
			TabItemContainer.Visible = true
		end

		AddConnection(TabFrame.MouseButton1Click, function()
			local sound = Instance.new("Sound") sound.SoundId = "rbxassetid://6895079853" sound.Volume = 0.5 sound.Parent = game:GetService("SoundService") sound:Play() game:GetService("Debris"):AddItem(sound, 1)
			for _, Tab in next, TabHolder:GetChildren() do
				if Tab:IsA("TextButton") and Tab:FindFirstChild("Ico") and Tab:FindFirstChild("Title") then
					Tab.Title.Font = Enum.Font.GothamBlack
					TweenService:Create(Tab.Ico,   TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0.4, ImageColor3 = Color3.fromRGB(240,240,240)}):Play()
					TweenService:Create(Tab.Title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency  = 0.4, TextColor3  = Color3.fromRGB(240,240,240)}):Play()
				end
			end
			for _, ItemContainer in next, MainWindow:GetChildren() do
				if ItemContainer.Name == "ItemContainer" then ItemContainer.Visible = false end
			end
			TweenService:Create(TabFrame.Ico,   TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0, ImageColor3 = Color3.fromRGB(135, 206, 250)}):Play()
			TweenService:Create(TabFrame.Title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency  = 0, TextColor3  = Color3.fromRGB(135, 206, 250)}):Play()
			TabFrame.Title.Font = Enum.Font.GothamBlack
			TabItemContainer.Visible = true
		end)

		local function GetElements(ItemParent)
			local ElementFunction = {}

			function ElementFunction:AddLabel(Text)
				local LabelFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 5), {
					Size = UDim2.new(1,-16,0,30),
					Position = UDim2.new(0,8,0,0),
					BackgroundTransparency = 0.2,
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", Text, 15), {
						Size = UDim2.new(1,-12,1,0),
						Position = UDim2.new(0,12,0,0),
						Font = Enum.Font.FredokaOne,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Second")
				local LabelFunction = {}
				function LabelFunction:Set(ToChange)
					if LabelFrame:FindFirstChild("Content") then LabelFrame.Content.Text = ToChange end
				end
				return LabelFunction
			end

			function ElementFunction:AddParagraph(Text, Content)
				Text    = Text    or "Text"
				Content = Content or "Content"
				local ParagraphFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 5), {
					Size = UDim2.new(1,-16,0,30),
					Position = UDim2.new(0,8,0,0),
					BackgroundTransparency = 0.2,
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", Text, 15), {
						Size = UDim2.new(1,-24,0,14),
						Position = UDim2.new(0,12,0,11),
						Font = Enum.Font.FredokaOne,
						Name = "Title"
					}), "Text"),
					AddThemeObject(SetProps(MakeElement("Label", "", 13), {
						Size = UDim2.new(1,-28,0,0),
						Position = UDim2.new(0,12,0,30),
						Font = Enum.Font.FredokaOne,
						Name = "Content",
						TextWrapped = true
					}), "TextDark"),
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Second")
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
				local ButtonFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 5), {
					Size = UDim2.new(1,0,0,33),
					Parent = ItemParent,
					BackgroundTransparency = 0.2
				}), {
					AddThemeObject(SetProps(MakeElement("Label", ButtonConfig.Name, 15), {
						Size = UDim2.new(1,-12,1,0),
						Position = UDim2.new(0,12,0,0),
						Font = Enum.Font.FredokaOne,
						Name = "Content"
					}), "Text"),
					AddThemeObject(SetProps(MakeElement("Image", ButtonConfig.Icon), {
						Size = UDim2.new(0,20,0,20),
						Position = UDim2.new(1,-30,0,7),
					}), "TextDark"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					Click
				}), "Second")
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
				ToggleConfig.Color    = ToggleConfig.Color    or Color3.fromRGB(135, 206, 250)
				ToggleConfig.Flag     = ToggleConfig.Flag     or nil
				ToggleConfig.Save     = ToggleConfig.Save     or false

				local Toggle = {Value = ToggleConfig.Default, Save = ToggleConfig.Save, Type = "Toggle"}
				local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1,0,1,0)})
				local ToggleBox = SetChildren(SetProps(MakeElement("RoundFrame", ToggleConfig.Color, 0, 4), {
					Size = UDim2.new(0,24,0,24),
					Position = UDim2.new(1,-24,0.5,0),
					AnchorPoint = Vector2.new(0.5,0.5),
					BackgroundTransparency = 0.2
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
				local ToggleFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 5), {
					Size = UDim2.new(1,0,0,38),
					Parent = ItemParent,
					BackgroundTransparency = 0.2
				}), {
					AddThemeObject(SetProps(MakeElement("Label", ToggleConfig.Name, 15), {
						Size = UDim2.new(1,-12,1,0),
						Position = UDim2.new(0,12,0,0),
						Font = Enum.Font.FredokaOne,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					ToggleBox,
					Click
				}), "Second")

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
				SliderConfig.Color     = SliderConfig.Color     or Color3.fromRGB(135, 206, 250)
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
						Font = Enum.Font.FredokaOne,
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
						Font = Enum.Font.FredokaOne,
						Name = "Value",
						TextTransparency = 0.8
					}), "Text"),
					SliderDrag
				})

				local SliderFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 4), {
					Size = UDim2.new(1,0,0,65),
					Parent = ItemParent,
					BackgroundTransparency = 0.2
				}), {
					AddThemeObject(SetProps(MakeElement("Label", SliderConfig.Name, 15), {
						Size = UDim2.new(1,-12,0,14),
						Position = UDim2.new(0,12,0,10),
						Font = Enum.Font.FredokaOne,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					SliderBar
				}), "Second")

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
				local DropdownFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 5), {
					Size = UDim2.new(1,0,0,38),
					Parent = ItemParent,
					ClipsDescendants = true,
					BackgroundTransparency = 0.2
				}), {
					DropdownContainer,
					SetProps(SetChildren(MakeElement("TFrame"), {
						AddThemeObject(SetProps(MakeElement("Label", DropdownConfig.Name, 15), {Size = UDim2.new(1,-12,1,0), Position = UDim2.new(0,12,0,0), Font = Enum.Font.FredokaOne, Name = "Content"}), "Text"),
						AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072706796"), {Size = UDim2.new(0,20,0,20), AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(1,-30,0.5,0), ImageColor3 = Color3.fromRGB(240,240,240), Name = "Ico"}), "TextDark"),
						AddThemeObject(SetProps(MakeElement("Label", "Selected", 13), {Size = UDim2.new(1,-40,1,0), Font = Enum.Font.FredokaOne, Name = "Selected", TextXAlignment = Enum.TextXAlignment.Right}), "TextDark"),
						AddThemeObject(SetProps(MakeElement("Frame"), {Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1), Name = "Line", Visible = false}), "Stroke"),
						Click
					}), {Size = UDim2.new(1,0,0,38), ClipsDescendants = true, Name = "F"}),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					MakeElement("Corner")
				}), "Second")

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
				BindConfig.Name     = BindConfig.Name     or "Bind"
				BindConfig.Default  = BindConfig.Default  or Enum.KeyCode.Unknown
				BindConfig.Hold     = BindConfig.Hold     or false
				BindConfig.Callback = BindConfig.Callback or function() end
				BindConfig.Flag     = BindConfig.Flag     or nil
				BindConfig.Save     = BindConfig.Save     or false

				local Bind = {Value = nil, Binding = false, Type = "Bind", Save = BindConfig.Save}
				local Holding = false
				local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1,0,1,0)})

				local BindBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 4), {
					Size = UDim2.new(0,24,0,24),
					Position = UDim2.new(1,-12,0.5,0),
					AnchorPoint = Vector2.new(1,0.5),
					BackgroundTransparency = 0.2
				}), {
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					AddThemeObject(SetProps(MakeElement("Label", BindConfig.Name, 14), {
						Size = UDim2.new(1,0,1,0),
						Font = Enum.Font.FredokaOne,
						TextXAlignment = Enum.TextXAlignment.Center,
						Name = "Value"
					}), "Text")
				}), "Main")

				local BindFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 5), {
					Size = UDim2.new(1,0,0,38),
					Parent = ItemParent,
					BackgroundTransparency = 0.2
				}), {
					AddThemeObject(SetProps(MakeElement("Label", BindConfig.Name, 15), {
						Size = UDim2.new(1,-12,1,0),
						Position = UDim2.new(0,12,0,0),
						Font = Enum.Font.FredokaOne,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					BindBox,
					Click
				}), "Second")

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

				local TextContainer = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 4), {
					Size = UDim2.new(0,24,0,24),
					Position = UDim2.new(1,-12,0.5,0),
					AnchorPoint = Vector2.new(1,0.5),
					BackgroundTransparency = 0.2
				}), {
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					TextboxActual
				}), "Main")

				local TextboxFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 5), {
					Size = UDim2.new(1,0,0,38),
					Parent = ItemParent,
					BackgroundTransparency = 0.2
				}), {
					AddThemeObject(SetProps(MakeElement("Label", TextboxConfig.Name, 15), {
						Size = UDim2.new(1,-12,1,0),
						Position = UDim2.new(0,12,0,0),
						Font = Enum.Font.FredokaOne,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					TextContainer,
					Click
				}), "Second")

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
				local Color = Create("ImageLabel", {Size = UDim2.new(1,-25,1,0), Visible = false, Image = "rbxassetid://4155801252"}, {
					Create("UICorner", {CornerRadius = UDim.new(0,5)}),
					ColorSelection
				})
				local Hue = Create("Frame", {Size = UDim2.new(0,20,1,0), Position = UDim2.new(1,-20,0,0), Visible = false, BackgroundTransparency = 0.2}, {
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
					Position = UDim2.new(0,0,0,32),
					Size = UDim2.new(1,0,1,-32),
					BackgroundTransparency = 1,
					ClipsDescendants = true
				}, {
					Hue, Color,
					Create("UIPadding", {PaddingLeft=UDim.new(0,35), PaddingRight=UDim.new(0,35), PaddingBottom=UDim.new(0,10), PaddingTop=UDim.new(0,17)})
				})

				local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1,0,1,0)})
				local ColorpickerBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 4), {
					Size = UDim2.new(0,24,0,24),
					Position = UDim2.new(1,-12,0.5,0),
					AnchorPoint = Vector2.new(1,0.5),
					BackgroundTransparency = 0.2
				}), {AddThemeObject(MakeElement("Stroke"), "Stroke")}), "Main")

				local ColorpickerFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 5), {
					Size = UDim2.new(1,0,0,38),
					Parent = ItemParent,
					BackgroundTransparency = 0.2
				}), {
					SetProps(SetChildren(MakeElement("TFrame"), {
						AddThemeObject(SetProps(MakeElement("Label", ColorpickerConfig.Name, 15), {Size=UDim2.new(1,-12,1,0), Position=UDim2.new(0,12,0,0), Font=Enum.Font.FredokaOne, Name="Content"}), "Text"),
						ColorpickerBox,
						Click,
						AddThemeObject(SetProps(MakeElement("Frame"), {Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-1), Name="Line", Visible=false}), "Stroke"),
					}), {Size=UDim2.new(1,0,0,38), ClipsDescendants=true, Name="F"}),
					ColorpickerContainer,
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
				}), "Second")

				AddConnection(Click.MouseButton1Click, function()
					local sound = Instance.new("Sound") sound.SoundId = "rbxassetid://6895079853" sound.Volume = 0.5 sound.Parent = game:GetService("SoundService") sound:Play() game:GetService("Debris"):AddItem(sound, 1)
					Colorpicker.Toggled = not Colorpicker.Toggled
					TweenService:Create(ColorpickerFrame, TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Colorpicker.Toggled and UDim2.new(1,0,0,148) or UDim2.new(1,0,0,38)}):Play()
					Color.Visible = Colorpicker.Toggled
					Hue.Visible   = Colorpicker.Toggled
					ColorpickerFrame.F.Line.Visible = Colorpicker.Toggled
				end)

				local function UpdateColorPicker()
					ColorpickerBox.BackgroundColor3 = Color3.fromHSV(ColorH, ColorS, ColorV)
					Color.BackgroundColor3 = Color3.fromHSV(ColorH, 1, 1)
					Colorpicker:Set(ColorpickerBox.BackgroundColor3)
					ColorpickerConfig.Callback(ColorpickerBox.BackgroundColor3)
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
			SectionConfig.Name = SectionConfig.Name or "Section"
			local SectionFrame = SetChildren(SetProps(MakeElement("TFrame"), {
				Size = UDim2.new(1,0,0,26),
				Parent = TabItemContainer
			}), {
				(function()
					local line = Create("Frame", {
						Size = UDim2.new(0,2,0,14), Position = UDim2.new(0,0,0,5),
						BackgroundColor3 = Color3.fromRGB(135, 206, 250), BorderSizePixel = 0, Parent = SectionFrame,
					})
					Create("UICorner", {CornerRadius = UDim.new(0,2), Parent = line})
					return line
				end)(),
				AddThemeObject(SetProps(MakeElement("Label", SectionConfig.Name, 14), {
					Size = UDim2.new(1,-12,0,16),
					Position = UDim2.new(0,10,0,3),
					Font = Enum.Font.FredokaOne
				}), "TextDark"),
				SetChildren(SetProps(MakeElement("TFrame"), {
					AnchorPoint = Vector2.new(0,0),
					Size = UDim2.new(1,0,1,-24),
					Position = UDim2.new(0,0,0,23),
					Name = "Holder"
				}), {MakeElement("List", 0, 6)}),
			})
			AddConnection(SectionFrame.Holder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
				SectionFrame.Size        = UDim2.new(1, 0, 0, SectionFrame.Holder.UIListLayout.AbsoluteContentSize.Y + 31)
				SectionFrame.Holder.Size = UDim2.new(1, 0, 0, SectionFrame.Holder.UIListLayout.AbsoluteContentSize.Y)
			end)
			local SectionFunction = {}
			for i, v in next, GetElements(SectionFrame.Holder) do SectionFunction[i] = v end
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
		tabFrame.BackgroundColor3       = Color3.fromRGB(135, 206, 250)
		tabFrame.BackgroundTransparency = 0.6

		local ghost = Instance.new("Frame")
		ghost.Size                   = UDim2.new(0, tabFrame.AbsoluteSize.X-8, 0, tabFrame.AbsoluteSize.Y-4)
		ghost.BackgroundColor3       = Color3.fromRGB(135, 206, 250)
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
					if isTarget then c.BackgroundColor3 = Color3.fromRGB(135, 206, 250) end
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
				TweenService:Create(AccentLine, TweenInfo.new(0.2), {BackgroundColor3 = collapsed and Color3.fromRGB(80,80,85) or Color3.fromRGB(135, 206, 250)}):Play()
			end
			if GroupLabel then
				TweenService:Create(GroupLabel, TweenInfo.new(0.2), {TextColor3 = collapsed and Color3.fromRGB(100,100,105) or Color3.fromRGB(135, 206, 250)}):Play()
			end
		end

		local function EnsureHeader()
			if headerCreated then return end
			headerCreated = true
			headerBtn = Create("TextButton", {
				Size=UDim2.new(1,0,0,22), BackgroundTransparency=1,
				BorderSizePixel=0, Text="", AutoButtonColor=false,
				LayoutOrder=NextOrder(), Parent=TabHolder,
			})
			groupData.header = headerBtn
			AccentLine = Create("Frame", {
				Size=UDim2.new(0,2,0,10), Position=UDim2.new(0,6,0.5,-5),
				BackgroundColor3 = collapsed and Color3.fromRGB(80,80,85) or Color3.fromRGB(135, 206, 250),
				BorderSizePixel=0, Parent=headerBtn,
			})
			Create("UICorner",{CornerRadius=UDim.new(0,2),Parent=AccentLine})
			GroupLabel = Create("TextLabel", {
				Size=UDim2.new(1,-16,1,0), Position=UDim2.new(0,14,0,0),
				BackgroundTransparency=1, Text=string.upper(GroupConfig.Name),
				TextColor3 = collapsed and Color3.fromRGB(100,100,105) or Color3.fromRGB(135, 206, 250),
				TextSize=10, Font=Enum.Font.GothamBold,
				TextXAlignment=Enum.TextXAlignment.Left, Parent=headerBtn,
			})
			headerBtn.MouseButton1Click:Connect(function() SetCollapsed(not collapsed) end)
			headerBtn.MouseEnter:Connect(function() TweenService:Create(GroupLabel,TweenInfo.new(0.15),{TextColor3=Color3.fromRGB(200,230,255)}):Play() end)
			headerBtn.MouseLeave:Connect(function() TweenService:Create(GroupLabel,TweenInfo.new(0.15),{TextColor3=collapsed and Color3.fromRGB(100,100,105) or Color3.fromRGB(135, 206, 250)}):Play() end)
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
	if props then table.foreach(props, function(prop, value) new[prop] = value end) end
	return new
end

local function SetProps2(instance, props)
	if instance and props then table.foreach(props, function(prop, value) instance[prop] = value end) end
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
	Container:Destroy()
end

return Library
