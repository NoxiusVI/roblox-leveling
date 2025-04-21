--|| INVENTORY SETTINGS ||--
local hotbar_size = 10

--|| SERVICES ||--
local players = game:GetService("Players")
local starter_gui = game:GetService("StarterGui")
local tween_service = game:GetService("TweenService")
local input_service = game:GetService("UserInputService")
local replicated_storage = game:GetService("ReplicatedStorage")

--|| REPLICATED VARIABLES ||--
local modules = replicated_storage:WaitForChild("Modules")
local events = replicated_storage:WaitForChild("Events")

local backpack_events = events:WaitForChild("Backpack")

local equip_tool_event = backpack_events:WaitForChild("EquipTool")
local unequip_tools_event = backpack_events:WaitForChild("UnequipTools")

local color_pools_module = modules:WaitForChild("ColorPools")
local color_pools = require(color_pools_module)

--|| PLAYER VARIABLES ||--
local player = players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local backpack = player.Backpack

local mouse = player:GetMouse()

--|| UI VARIABLES ||--
local main_frame = script.Parent:WaitForChild("Inventory")

local backpack_frame = main_frame:WaitForChild("Backpack")
local sorting_frame = backpack_frame:WaitForChild("Sorting")
local name_sort = sorting_frame:WaitForChild("NameMode")
local rarity_sort = sorting_frame:WaitForChild("RarityMode")
local quantity_sort = sorting_frame:WaitForChild("QuantityMode")
local search_bar = sorting_frame:WaitForChild("Search")
local bp_scrolling_bounds = backpack_frame:WaitForChild("ScrollingBounds")
local scrolling_frame = bp_scrolling_bounds:WaitForChild("ScrollingFrame")
local backpack_slot_holder = scrolling_frame:WaitForChild("Slots")

local hotbar_frame = main_frame:WaitForChild("Hotbar")
local hotbar_slot_holder = hotbar_frame:WaitForChild("Slots")

local slot_template = script:WaitForChild("SlotTemplate")
local held_visual = script:WaitForChild("HeldSlotVisual")
local equipped_visual = script:WaitForChild("EquippedSlotVisual")

local main_ratio = main_frame:WaitForChild("Ratio")

--|| STATE VARIABLES ||--
local currently_equipped = {}
local inventory_hotbar = {}
local inventory_backpack = {}

local rarity_names = {"Common","Rare","Epic","Legendary"}

local backpack_open = false
local held_slot = {is_backpack = false, slot = ""}

local sfx_folder = script.Parent:WaitForChild("SFX")

--|| TWEEN VARIABLES ||--
local h_value = Instance.new("IntValue")
h_value.Value = main_frame:GetAttribute("Height")

local main_tween_info = TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut)

local main_frame_open = tween_service:Create(h_value,main_tween_info,{Value = 320})
local main_ratio_open = tween_service:Create(main_ratio,main_tween_info,{AspectRatio = 2.25})
local main_frame_close = tween_service:Create(h_value,main_tween_info,{Value = 64})
local main_ratio_close = tween_service:Create(main_ratio,main_tween_info,{AspectRatio = 11.25})

--|| SORT VARIABLES ||--
local rarity_less = false
local quantity_less = false
local name_less = false

--|| FUNCTIONS ||--
function play_sfx(name : string)
	task.spawn(function()
		local sound : Sound = sfx_folder:FindFirstChild(name)
		if sound then
			sound = sound:Clone()
			sound.Parent = script
			sound:Play()
			sound.Ended:Wait()
			sound:Destroy()
		end
	end)
end

function initialize_ui()
	starter_gui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)
	
	for i = 1,hotbar_size do
		add_hotbar_button(i)
	end
end

function intialize_backpack()
	local backpack_children = backpack:GetChildren()
	
	for i = 1,hotbar_size do
		table.insert(inventory_hotbar,"")
	end

	for _,child in pairs(backpack_children) do
		if child:IsA("Tool") then
			local next_free_slot = table.find(inventory_hotbar,"")
			if next_free_slot then
				--Add to hotbar
				inventory_hotbar[next_free_slot] = child
			else
				add_backpack_button(#inventory_backpack+1,child)
			end
		end
	end
end

--Slot handling functions

function sort_slot(sort_slot : number, from_backpack : boolean)
	local tool = inventory_hotbar[sort_slot]
	if from_backpack then
		tool = inventory_backpack[sort_slot]
	end
	
	if held_slot.slot ~= "" then
		--Switch the places of the slots
		local held_slot_tool = inventory_hotbar[held_slot.slot]
		local selected_slot_tool
		
		if held_slot.is_backpack then
			held_slot_tool = inventory_backpack[held_slot.slot]
		end
		
		
		
		if from_backpack then
			--We are trying to switch places to a tool from BACKPACK
			selected_slot_tool = inventory_backpack[sort_slot]
			inventory_backpack[sort_slot] = held_slot_tool
		else
			--We are trying to switch places to a tool from HOTBAR
			selected_slot_tool = inventory_hotbar[sort_slot]
			inventory_hotbar[sort_slot] = held_slot_tool
		end
		
		if held_slot.is_backpack then
			--We are trying to switch places from a tool from BACKPACK
			if selected_slot_tool == "" then
				table.remove(inventory_backpack,held_slot.slot)
			else
				inventory_backpack[held_slot.slot] = selected_slot_tool
			end
		else
			--We are trying to switch places from a tool from HOTBAR
			inventory_hotbar[held_slot.slot] = selected_slot_tool
		end
		
		held_slot = {is_backpack = false,slot = ""}
		refresh_backpack()
		refresh_hotbar()
		held_visual.Parent = script
		play_sfx("SelectSecond")
	else
		if tool ~= "" then
			local holder_to_check = hotbar_slot_holder
			if from_backpack then
				holder_to_check = backpack_slot_holder
			end
			held_visual.Parent = holder_to_check["Slot"..tostring(sort_slot)]

			held_slot = {is_backpack = from_backpack,slot = sort_slot}
			play_sfx("SelectFirst")
		end
	end
end

function equip_tool(slot : number)
	local tool = inventory_hotbar[slot]
	
	if backpack_open then
		sort_slot(slot,false)
	else
		if tool ~= "" then
			equip_tool_event:FireServer(tool)
			equipped_visual.Parent = hotbar_slot_holder["Slot"..tostring(slot)]
		end
	end
end

function unequip_tools()
	unequip_tools_event:FireServer()
	equipped_visual.Parent = script
end

function add_backpack_button(slot : number, tool : Tool)
	local quantity_changed
	local tool_changed
	
	--UI Button creation
	table.insert(inventory_backpack,tool)
	
	local new_button = slot_template:Clone()
	new_button.Parent = backpack_slot_holder
	new_button.LayoutOrder = slot
	new_button.Name = "Slot"..tostring(slot)
	new_button.Size = UDim2.fromScale(1,0.3)

	local slot_tool = Instance.new("ObjectValue",new_button)
	slot_tool.Name = "Tool"
	slot_tool.Value = tool

	local button_stroke = new_button:WaitForChild("Stroke")
	local background_gradient = new_button:WaitForChild("Gradient")

	local tool_info_ui = new_button:WaitForChild("Info")
	local quanity_label = tool_info_ui:WaitForChild("Quantity")
	local name_label = tool_info_ui:WaitForChild("Name")
	local rarity_label = tool_info_ui:WaitForChild("Rarity")
	local slot_label = tool_info_ui:WaitForChild("Slot")
	
	slot_label.Text = ""
	
	local quantity = tool:GetAttribute("Quantity")
	local rarity = tool:GetAttribute("Rarity")

	rarity_label.Text = ""
	if rarity then
		for i = 1,rarity do
			rarity_label.Text = rarity_label.Text.."★"
		end

		local rarity_col = color_pools.Rarity[rarity_names[rarity]]
		button_stroke.Color = rarity_col
		background_gradient.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
			ColorSequenceKeypoint.new(1, Color3.new(rarity_col.R*0.25,rarity_col.G*0.25,rarity_col.B*0.25))
		}
		rarity_label.TextColor3 = rarity_col
	else
		local rarity_col = Color3.new(1,1,1)
		button_stroke.Color = rarity_col
		background_gradient.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
			ColorSequenceKeypoint.new(1, Color3.new(rarity_col.R*0.25,rarity_col.G*0.25,rarity_col.B*0.25))
		}
		rarity_label.TextColor3 = rarity_col
	end

	if quantity then
		quanity_label.Text = "x"..tostring(quantity)

		quantity_changed = tool:GetAttributeChangedSignal("Quantity"):Connect(function()
			quanity_label.Text = "x"..tostring(tool:GetAttribute("Quantity"))
		end)
	else
		quanity_label.Text = ""
	end

	name_label.Text = tool.Name
	
	tool_changed = slot_tool:GetPropertyChangedSignal("Value"):Connect(function()
		local tool = slot_tool.Value

		if quantity_changed then
			quantity_changed:Disconnect()
		end

		if tool then
			quantity = tool:GetAttribute("Quantity")
			rarity = tool:GetAttribute("Rarity")

			rarity_label.Text = ""
			if rarity then
				for i = 1,rarity do
					rarity_label.Text = rarity_label.Text.."★"
				end

				local rarity_col = color_pools.Rarity[rarity_names[rarity]]
				button_stroke.Color = rarity_col
				background_gradient.Color = ColorSequence.new{
					ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
					ColorSequenceKeypoint.new(1, Color3.new(rarity_col.R*0.25,rarity_col.G*0.25,rarity_col.B*0.25))
				}
				rarity_label.TextColor3 = rarity_col
			else
				local rarity_col = Color3.new(1,1,1)
				button_stroke.Color = rarity_col
				background_gradient.Color = ColorSequence.new{
					ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
					ColorSequenceKeypoint.new(1, Color3.new(rarity_col.R*0.25,rarity_col.G*0.25,rarity_col.B*0.25))
				}
				rarity_label.TextColor3 = rarity_col
			end

			if quantity then
				quanity_label.Text = "x"..tostring(quantity)

				quantity_changed = tool:GetAttributeChangedSignal("Quantity"):Connect(function()
					quanity_label.Text = "x"..tostring(tool:GetAttribute("Quantity"))
				end)
			else
				quanity_label.Text = ""
			end

			name_label.Text = tool.Name
			
			if table.find(currently_equipped,tool) then
				equipped_visual.Parent = new_button
			end
		else
			tool_changed:Disconnect()
			new_button:Destroy()
		end
	end)
	
	new_button.MouseEnter:Connect(function()
		play_sfx("SlotHover")
	end)
	
	new_button.Activated:Connect(function()
		sort_slot(slot,true)
	end)
end


function add_hotbar_button(slot : number)
	
	--UI Button creation
	local new_button = slot_template:Clone()
	new_button.Parent = hotbar_slot_holder
	new_button.LayoutOrder = slot
	new_button.Name = "Slot"..tostring(slot)
	
	local slot_tool = Instance.new("ObjectValue",new_button)
	slot_tool.Name = "Tool"
	
	local button_stroke = new_button:WaitForChild("Stroke")
	local background_gradient = new_button:WaitForChild("Gradient")

	local tool_info_ui = new_button:WaitForChild("Info")
	local quanity_label = tool_info_ui:WaitForChild("Quantity")
	local name_label = tool_info_ui:WaitForChild("Name")
	local rarity_label = tool_info_ui:WaitForChild("Rarity")
	local slot_label = tool_info_ui:WaitForChild("Slot")
	
	if slot == 10 then
		slot_label.Text = "0"
	else
		slot_label.Text = tostring(slot)
	end
	
	--Functions and stuff
	local quantity_changed
	local tool_changed
	
	tool_changed = slot_tool:GetPropertyChangedSignal("Value"):Connect(function()
		local tool = slot_tool.Value
		
		if quantity_changed then
			quantity_changed:Disconnect()
		end
		
		if tool then
			local quantity = tool:GetAttribute("Quantity")
			local rarity = tool:GetAttribute("Rarity")

			rarity_label.Text = ""
			if rarity then
				for i = 1,rarity do
					rarity_label.Text = rarity_label.Text.."★"
				end

				local rarity_col = color_pools.Rarity[rarity_names[rarity]]
				button_stroke.Color = rarity_col
				background_gradient.Color = ColorSequence.new{
					ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
					ColorSequenceKeypoint.new(1, Color3.new(rarity_col.R*0.25,rarity_col.G*0.25,rarity_col.B*0.25))
				}
				rarity_label.TextColor3 = rarity_col
			else
				local rarity_col = Color3.new(1,1,1)
				button_stroke.Color = rarity_col
				background_gradient.Color = ColorSequence.new{
					ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
					ColorSequenceKeypoint.new(1, Color3.new(rarity_col.R*0.25,rarity_col.G*0.25,rarity_col.B*0.25))
				}
				rarity_label.TextColor3 = rarity_col
			end
			
			if quantity then
				quanity_label.Text = "x"..tostring(quantity)
				
				quantity_changed = tool:GetAttributeChangedSignal("Quantity"):Connect(function()
					quanity_label.Text = "x"..tostring(tool:GetAttribute("Quantity"))
				end)
			else
				quanity_label.Text = ""
			end
			
			name_label.Text = tool.Name

			if table.find(currently_equipped,tool) then
				equipped_visual.Parent = new_button
			end
		else
			rarity_label.Text = ""
			name_label.Text = ""
			quanity_label.Text = ""
			
			background_gradient.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
				ColorSequenceKeypoint.new(1, Color3.new(0.25,0.25,0.25))
			}
			
			local rarity_col = Color3.new(1,1,1)
			button_stroke.Color = rarity_col
			rarity_label.TextColor3 = rarity_col
		end
	end)

	new_button.MouseEnter:Connect(function()
		play_sfx("SlotHover")
	end)
	
	new_button.Activated:Connect(function()
		if inventory_hotbar[slot] ~= "" then
			if table.find(currently_equipped,inventory_hotbar[slot]) and not backpack_open then
				unequip_tools()
			else
				equip_tool(slot)
			end
		elseif backpack_open then
			sort_slot(slot,false)
		end
	end)
end

function refresh_hotbar()
	local slot_id = 0
	for _,child in pairs(hotbar_slot_holder:GetChildren()) do
		if child:IsA("ImageButton") then
			slot_id += 1
			local tool = inventory_hotbar[slot_id]
			local slot_tool = child:WaitForChild("Tool")
			if tool ~= "" then
				slot_tool.Value = tool
			else
				slot_tool.Value = nil
			end
		end
	end
end

function refresh_backpack()
	local slot_id = 0
	for _,child in pairs(backpack_slot_holder:GetChildren()) do
		if child:IsA("ImageButton") then
			slot_id += 1
			local tool = inventory_backpack[slot_id]
			local slot_tool = child:WaitForChild("Tool")
			if tool ~= "" then
				slot_tool.Value = tool
			else
				slot_tool.Value = nil
			end
		end
	end
end

function on_enabled_changed()
	
end

function on_backpack_child_added(child : Instance)
	if child:IsA("Tool") then
		local next_free_slot = table.find(inventory_hotbar,"")
		if next_free_slot and not table.find(inventory_hotbar,child) then
			--Add to hotbar
			inventory_hotbar[next_free_slot] = child
		elseif not table.find(inventory_backpack,child) and not table.find(inventory_hotbar,child) then
			--Add to backpack
			add_backpack_button(#inventory_backpack + 1,child)
		end
		refresh_hotbar()
	end
end

function on_backpack_child_removed(child : Instance)
	if child:IsA("Tool") then
		local hotbar_index = table.find(inventory_hotbar,child)
		local backpack_index = table.find(inventory_backpack,child)
		if hotbar_index and child.Parent ~= character then
			inventory_hotbar[hotbar_index] = ""
			refresh_hotbar()
		end
		if backpack_index and child.Parent ~= character then
			table.remove(inventory_backpack,backpack_index)
			refresh_backpack()
		end
	end
end

function on_character_child_added(child : Instance)
	if child:IsA("Tool") then
		local hotbar_index = table.find(inventory_hotbar,child)
		if hotbar_index then
			table.insert(currently_equipped,child)
		end
	end
end

function on_character_child_removed(child : Instance)
	if child:IsA("Tool") then
		local index = table.find(currently_equipped,child)
		if index then
			table.remove(currently_equipped,index)
		end
		if child.Parent ~= backpack then
			--We dropped it.
			local hotbar_index = table.find(inventory_hotbar,child)
			local backpack_index = table.find(inventory_backpack,child)
			if hotbar_index then
				inventory_hotbar[hotbar_index] = ""
				refresh_hotbar()
			end
			if backpack_index then
				table.remove(inventory_backpack,backpack_index)
				refresh_backpack()
			end
		end
	end
end

function on_height_value_changed()
	main_frame:SetAttribute("Height",h_value.Value)
end

function on_input_began(input : InputObject, game_processed_event : boolean)
	if game_processed_event then return end
	if input.KeyCode == Enum.KeyCode.Backquote then
		backpack_open = not backpack_open
		if backpack_open then
			play_sfx("BackpackOpen")
			main_frame_open:Play()
			main_ratio_open:Play()
		else
			play_sfx("BackpackClose")
			main_frame_close:Play()
			main_ratio_close:Play()
		end
		if held_slot ~= "" then
			held_visual.Parent = script
		end
		held_slot = {is_backpack = false,slot = ""}
	else
		local slot = input.KeyCode.Value - 48
		if slot >= 0 and slot <= 9 then
			if slot == 0 then
				slot = 10
			end
			if inventory_hotbar[slot] ~= "" then
				if table.find(currently_equipped,inventory_hotbar[slot]) and not backpack_open then
					unequip_tools()
				else
					equip_tool(slot)
				end
			else
				sort_slot(slot,false)
			end
		end
	end
end

function on_name_sort()
	table.sort(inventory_backpack,function(tool_a,tool_b)
		if name_less then
			return tool_a.Name < tool_b.Name
		else
			return tool_a.Name > tool_b.Name
		end
	end)
	
	name_less = not name_less
	
	quantity_less = false
	rarity_less = false
	
	refresh_backpack()
	on_search_changed()
end

function on_rarity_sort()
	table.sort(inventory_backpack,function(tool_a,tool_b)
		local a_rarity = tool_a:GetAttribute("Rarity") or 0
		local b_rarity = tool_b:GetAttribute("Rarity") or 0
		if a_rarity == b_rarity then
			return tool_a.Name < tool_b.Name
		end
		
		if rarity_less then
			return a_rarity < b_rarity
		else
			return a_rarity > b_rarity
		end
	end)
	
	rarity_less = not rarity_less

	quantity_less = false
	name_less = false
	
	refresh_backpack()
	on_search_changed()
end

function on_quantity_sort()
	table.sort(inventory_backpack,function(tool_a,tool_b)
		local a_quantity = tool_a:GetAttribute("Quantity") or 0
		local b_quantity = tool_b:GetAttribute("Quantity") or 0
		if a_quantity == b_quantity then
			return tool_a.Name < tool_b.Name
		end
		
		if quantity_less then
			return a_quantity < b_quantity
		else
			return a_quantity > b_quantity
		end
	end)
	
	quantity_less = not quantity_less

	name_less = false
	rarity_less = false
	
	refresh_backpack()
	on_search_changed()
end

function on_search_changed()
	local search = string.lower(search_bar.Text)
	for i,button in pairs(backpack_slot_holder:GetChildren()) do
		if button:IsA("ImageButton") then
			local button_tool = button:WaitForChild("Tool").Value
			if string.find(string.lower(button_tool.Name),search) then
				button.Visible = true
			else
				button.Visible = false
			end
		end
	end
end

--|| CONNECTIONS ||--
player:GetAttributeChangedSignal("BackpackEnabled"):Connect(on_enabled_changed)
h_value:GetPropertyChangedSignal("Value"):Connect(on_height_value_changed)
backpack.ChildAdded:Connect(on_backpack_child_added)
backpack.ChildRemoved:Connect(on_backpack_child_removed)
character.ChildAdded:Connect(on_character_child_added)
character.ChildRemoved:Connect(on_character_child_removed)
input_service.InputBegan:Connect(on_input_began)
name_sort.Activated:Connect(on_name_sort)
rarity_sort.Activated:Connect(on_rarity_sort)
quantity_sort.Activated:Connect(on_quantity_sort)
search_bar:GetPropertyChangedSignal("Text"):Connect(on_search_changed)

--|| INITIALIZATION ||--
initialize_ui()
intialize_backpack()
refresh_hotbar()