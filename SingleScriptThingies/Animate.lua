--|| SERVICES ||--
local players = game:GetService("Players")
local tween_service = game:GetService("TweenService")
local run_service = game:GetService("RunService")
local text_chat_service = game:GetService("TextChatService")

--|| PLAYER VARIABLES ||--
local player = players.LocalPlayer
local camera = workspace.CurrentCamera

--|| TEXT CHAT VARIABLES ||--
local commands = text_chat_service:WaitForChild("TextChatCommands")
local channels = text_chat_service:WaitForChild("TextChannels")

local general_channel = channels:WaitForChild("RBXGeneral")
local emote_command = commands:WaitForChild("NoxEmoteCommand")

--|| HUMANOID VARIABLES ||--
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local root_part = character:WaitForChild("HumanoidRootPart")
local torso = character:WaitForChild("Torso")

local root_joint = root_part:WaitForChild("RootJoint")
local right_shoulder = torso:WaitForChild("Right Shoulder")
local left_shoulder = torso:WaitForChild("Left Shoulder")
local right_hip = torso:WaitForChild("Right Hip")
local left_hip = torso:WaitForChild("Left Hip")
local neck = torso:WaitForChild("Neck")

local original_root_joint = root_joint.C0
local original_right_shoulder = right_shoulder.C0
local original_left_shoulder = left_shoulder.C0
local original_right_hip = right_hip.C0
local original_left_hip = left_hip.C0
local original_neck = neck.C0

--|| ANIMATION VARIABLES ||--
local animation_module = script:WaitForChild("Animations")
local animation_variables = require(animation_module)
local animation_list = animation_variables.R6.Core
local emote_list = animation_variables.R6.Emotes

local animations = {}

local movement_direction = 1

local current_anim = ""
local current_track = nil
local current_speed = 1
local running_is_walk = true

local current_pose = ""
local jump_pose_duration = 0.3
local land_pose_duration = 0.3

local emote_sound_fade_length = 0.25

local torso_angle_alpha = 0.5
local shoulder_angle_alpha = 0.25

--|| MISC VARIABLES ||--
local id_prefix = "rbxassetid://"

local jump_pose_timer = 0
local land_pose_timer = 0

--|| FUNCTIONS ||--
function initialize() : nil
	initialize_animations()
	initialize_to_idle()
end

function initialize_to_idle() : nil
	play_animation("idle",0.1)
end

function initialize_animations() : nil
	for name,info in pairs(animation_list) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id_prefix..tostring(info.Id)

		local track = humanoid:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Core

		animations[string.lower(name)] = track
	end
	
	for name,info in pairs(emote_list) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id_prefix..tostring(info.Id)

		local track = humanoid:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Core

		animations[string.lower(name)] = track
	end
end

function stop_all_animations() : nil
	if current_track then
		current_track:Stop()
		current_track = nil
	end
end

function set_animation_speed(new_speed : number) : nil
	if new_speed ~= current_speed then
		current_speed = new_speed
		current_track:AdjustSpeed(new_speed)
	end
end

function play_animation(anim_name : string, transition_time : number) : nil
	if current_anim ~= anim_name then
		if current_track then
			current_track:Stop(transition_time)
			current_track = nil
		end

		current_track = animations[anim_name]
		current_track:Play(transition_time)
		if animation_list[anim_name] then
			current_track:AdjustSpeed(animation_list[anim_name].Speed)
		elseif emote_list[anim_name] then
			current_track:AdjustSpeed(emote_list[anim_name].AnimationSpeed)
		end

		current_anim = anim_name
	end
end

function play_emote_sound(emote_name : string) : nil
	local emote = emote_list[string.lower(emote_name)]
	if emote.Sound then
		local new_audio = Instance.new("Sound",root_part)
		new_audio.RollOffMaxDistance = 20
		new_audio.RollOffMode = Enum.RollOffMode.LinearSquare
		new_audio.Volume = 0
		
		tween_service:Create(new_audio,TweenInfo.new(emote_sound_fade_length,Enum.EasingStyle.Linear),{Volume = 0.5}):Play()
		
		new_audio.SoundId = id_prefix..tostring(emote.Sound)
		task.wait()
		new_audio:Play()
		repeat task.wait() until current_anim ~= emote_name
		tween_service:Create(new_audio,TweenInfo.new(emote_sound_fade_length,Enum.EasingStyle.Linear),{Volume = 0}):Play()
		task.wait(emote_sound_fade_length)
		new_audio:Destroy()
	end
end

function on_running() : nil
	play_animation("walk",0.3)
end

function on_swimming() : nil
	play_animation("swim",0.3)
end

function on_climbing() : nil
	play_animation("climb", 0.1)
end

function on_falling() : nil
	play_animation("fall", 0.3)
end

function on_standing() : nil
	play_animation("idle", 0.3)
end

function on_floating() : nil
	play_animation("float", 0.1)

end

function on_jumping() : nil
	play_animation("jump", 0.1)
	jump_pose_timer = 0
end

function on_landing() : nil
	play_animation("land",0.1)
	land_pose_timer = 0
end

------------------------------------------------------
------------------------------------------------------

function update_speed() : nil
	local base_speed = animation_variables.BaseSpeeds[current_anim]
	if base_speed then
		set_animation_speed(root_part.AssemblyLinearVelocity.Magnitude/base_speed*movement_direction)
	end
end

function update_direction(angle : number, dt : number) : nil
	local pre_root_joint = original_root_joint
	local pre_left_shoulder = original_left_shoulder
	local pre_right_shoulder = original_right_shoulder
	local pre_left_hip = original_left_hip
	local pre_right_hip = original_right_hip
	local pre_neck = original_neck

	if angle ~= 0 and tostring(angle) ~= "nan" then
		local moving_direction = root_part.CFrame:VectorToObjectSpace(humanoid.MoveDirection)
		local direction = Vector3.new(moving_direction.X, 0, moving_direction.Z).Unit
		local angle = math.acos(direction.X) - math.pi/2

		if math.round(direction.Z) > 0 then
			angle *= -1
		end

		local torso_angle = angle * 0.5
		local shoulder_angle = (angle - torso_angle) * 0.25
		local hip_angle = angle - torso_angle
		
		local true_torso_cframe = torso.CFrame
		local torso_difference = root_part.CFrame:ToObjectSpace(true_torso_cframe)
		local torso_inverse = torso_difference:inverse()

		pre_root_joint = CFrame.Angles(0,torso_angle,0) * pre_root_joint
		pre_left_hip = torso_inverse * CFrame.new(-0.25 * math.abs(angle),0,0) * CFrame.Angles(0, hip_angle, 0) * torso_difference * pre_left_hip
		pre_right_hip = torso_inverse * CFrame.new(0.25 * math.abs(angle),0,0) * CFrame.Angles(0, hip_angle, 0) * torso_difference * pre_right_hip
		pre_left_shoulder = CFrame.Angles(0,shoulder_angle,0) * pre_left_shoulder
		pre_right_shoulder = CFrame.Angles(0,shoulder_angle,0) * pre_right_shoulder
		pre_neck = CFrame.Angles(0,-torso_angle,0) * pre_neck
	end

	local alpha = math.clamp(dt*10,0,1)

	root_joint.C0 = root_joint.C0:Lerp(pre_root_joint,alpha)
	left_hip.C0 = left_hip.C0:Lerp(pre_left_hip,alpha)
	right_hip.C0 = right_hip.C0:Lerp(pre_right_hip,alpha)
	left_shoulder.C0 = left_shoulder.C0:Lerp(pre_left_shoulder,alpha)
	right_shoulder.C0 = right_shoulder.C0:Lerp(pre_right_shoulder,alpha)
	neck.C0 = neck.C0:Lerp(pre_neck,alpha)
end

function update_pose(new_pose : string) : nil
	if jump_pose_timer < jump_pose_duration or land_pose_timer < land_pose_duration then
		return
	end

	current_pose = new_pose
	if new_pose == "Running" then
		on_running()
	elseif new_pose == "Swimming" then
		on_swimming()
	elseif new_pose == "Climbing" then
		on_climbing()
	elseif new_pose == "Falling" then
		on_falling()
	elseif new_pose == "Standing" then
		on_standing()
	elseif new_pose == "Floating" then
		on_floating()
	elseif new_pose == "Jump" then
		on_jumping()
	elseif new_pose == "Land" then
		on_landing()
	end
end

function on_update(dt : number)
	jump_pose_timer += dt
	land_pose_timer += dt
	
	local move_angle = 0
	movement_direction = 1

	if current_pose == "Running" then
		local moving_direction = root_part.CFrame:VectorToObjectSpace(humanoid.MoveDirection)
		local direction = Vector3.new(moving_direction.X, 0, moving_direction.Z).Unit
		move_angle = math.acos(direction.X) - math.pi/2

		if math.round(direction.Z) > 0 then
			move_angle *= -1
			movement_direction = -1
		end
	else
		movement_direction = 1
	end

	
	local character_pose = character:GetAttribute("Pose")
	if current_pose ~= character_pose then
		update_pose(character_pose)
	else
		if current_pose == "Running" then
			--We make sure that we're either walking or running accordingly!
			local sprinting = (math.floor(root_part.AssemblyLinearVelocity.Magnitude+0.1) >= animation_variables.BaseSpeeds.run)
			if sprinting and current_anim == "walk" then
				play_animation("run")
			elseif not sprinting and current_anim == "run" then
				play_animation("walk",0.3)
			end
		end
		update_speed()
	end

	update_direction(move_angle, dt)
end

function on_emote(text_source : TextSource, text : string)
	if text_source.UserId == player.UserId then
		local emote_name = ""
		
		if (string.sub(text, 1, 3) == "/e ") then
			emote_name = string.sub(text, 4)
		elseif (string.sub(text, 1, 7) == "/emote ") then
			emote_name = string.sub(text, 8)
		end

		local message = ""
		
		if current_pose == "Standing" then
			local emote = emote_list[string.lower(emote_name)]
			if emote ~= nil then
				play_animation(emote_name, 0.1)
				play_emote_sound(emote_name)
			else
				message = "That emote doesn't exist!"
			end
		else
			message = "You may not play emotes at this time!"
		end
		
		if message ~= "" then
			general_channel:DisplaySystemMessage('<font color="#ff4a4a">'..message.."</font>")
		end
	end
end

--|| CONNECTIONS ||--
run_service.PreAnimation:Connect(on_update)
emote_command.Triggered:Connect(on_emote)

--|| INITIALIZATION ||--
initialize()