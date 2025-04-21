--|| SERVICES ||--
local replicated_storage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

--|| REPLICATED VARIABLES ||--
local events = replicated_storage:WaitForChild("Events")
local backpack_events = events:WaitForChild("Backpack")

local equip_tool_event = backpack_events:WaitForChild("EquipTool")
local unequip_tool_event = backpack_events:WaitForChild("UnequipTools")

--|| FUNCTIONS ||--
function on_equip_tool(player, tool)
	local character = player.Character
	local humanoid = character:FindFirstChild("Humanoid")
	
	if tool.Parent == player.Backpack then
		if humanoid and humanoid.Health > 0 then
			--Player is alive and owns the tool, equip it.
			humanoid:UnequipTools()
			tool.Parent = character
		end
	end
end

function on_unequip_tools(player)
	local character = player.Character
	local humanoid = character:FindFirstChild("Humanoid")
	
	if humanoid and humanoid.Health > 0 then
		--Player is alive and owns the tool, equip it.
		humanoid:UnequipTools()
	end
end

--|| CONNECTIONS ||--
equip_tool_event.OnServerEvent:Connect(on_equip_tool)
unequip_tool_event.OnServerEvent:Connect(on_unequip_tools)