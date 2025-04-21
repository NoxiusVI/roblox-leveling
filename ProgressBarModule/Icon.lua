--THIS SCRIPT IS INSIDE OF THE MAIN.LUA SCRIPT
local icon_bar = {}
icon_bar.__index = icon_bar

-- || SERVICES ||--
local players = game:GetService("Players")
local tween_service = game:GetService("TweenService")

--|| PLAYER VARIABLES ||--
local player = players.LocalPlayer
local player_ui = player:WaitForChild("PlayerGui")

--|| UI VARIABLES ||--
local progress_ui = player_ui:WaitForChild("ProgressUI")
local progress_holder = progress_ui:WaitForChild("IconProgressHolder")

--|| TWEEN VARIABLES ||--
local def_t_style = Enum.EasingStyle.Linear
local def_t_dir = Enum.EasingDirection.InOut

--|| MISC VARAIBLES ||--
local unused_holder = script.Parent:WaitForChild("UI_Holder")

--|| FUNCTIONS ||--
function create_ui(icon_id : string)
	local background_image = Instance.new("ImageLabel",unused_holder)
	local fill_frame = Instance.new("Frame", background_image)
	local fill_image = Instance.new("ImageLabel", fill_frame)

	background_image.BackgroundTransparency = 1
	fill_frame.BackgroundTransparency = 1
	fill_image.BackgroundTransparency = 1

	background_image.Size = UDim2.fromOffset(30,30)
	background_image.ImageTransparency = 0.5
	background_image.ImageColor3 = Color3.new(0.7,0.7,0.7)

	fill_frame.Size = UDim2.fromScale(1,1)
	fill_frame.ClipsDescendants = true
	fill_frame.Position = UDim2.fromScale(0,1)
	fill_frame.AnchorPoint = Vector2.new(0,1)

	fill_image.Size = background_image.Size
	fill_image.Position = UDim2.fromScale(0,1)
	fill_image.AnchorPoint = Vector2.new(0,1)

	background_image.Image = icon_id
	fill_image.Image = icon_id

	fill_frame.Name = "Fill"
	fill_image.Name = "FillImage"

	return background_image
end

function icon_bar.new(icon_id : string, length : number)
	local new_bar = {}
	setmetatable(new_bar,icon_bar)
	
	new_bar.ui = create_ui(icon_id)
	new_bar.tween = tween_service:Create(new_bar.ui.Fill,TweenInfo.new(length,Enum.EasingStyle.Linear),{Size = UDim2.fromScale(1,1)})
	
	return new_bar
end

function icon_bar:Play()
	task.spawn(function()
		self.ui.Parent = progress_holder
		self.ui.Fill.Size = UDim2.fromScale(1,0)
		self.tween:Play()
		self.tween.Completed:Wait()
		self.ui.Parent = unused_holder
	end)
end

return icon_bar
