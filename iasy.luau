--!strict
--!native
--!optimize 2

--[[
	API:
	local schema = iasy.schema 
    Gets the schema. It is frozen (immutable)
	
	local core = iasy.get_context(schema.core)
    Gets an InputContext generated from the schema. It is also frozen

	local sprint_action = core.sprint
    Gets the InputAction generated from the the schema

	local sprint_bindings = iasy.get_binding_schema_for_action(sprint_action)
    Get a fresh (unfrozen) table of bindings for an action
	NB: Does not return InputBindings, only {[binding_name]: Enum.KeyCode} (same as schema). Call sprint_action:GetChildren()
	
    You can modify this returned schema (with intellisense on binding_name) and pass it into the below, for example.

	iasy.set_binding_schema_for_action(sprint_action, sprint_bindings)
    Clear all previous bindings and add these new bindings
	
    iasy.set_binding_for_action(sprint_action, "keyboard", Enum.KeyCode.B)
	Returns the InputBinding for further property changes if necessary

    iasy.get_keycode_for_binding(sprint_action, "keyboard") --> Enum.KeyCode.B
    Returns the Enum.KeyCode for a specific binding_name on an action.

    iasy.get_last_binding_type()
    Returns the last binding_name input type (i.e.: gamepad, keyboard, mobile). 
    Should ONLY be used with default binding_name config.
	
    iasy.wait_for_rebind(iasy.schema.core.sprint)
    YIELDS for the next valid input press. Should ONLY be used with default binding_name config
    Returns {binding_name: binding_name, keycode: Enum.KeyCode}. Times out after 5 seconds, returning nil

	iasy.set_action_ui_button(sprint_action, ui_button, true)
	Sets InputAction.UIButton. Last parameter is optional and subscribes the button for auto-hiding/showing (for touch-screens)
--]]


-- you can just set this to {[string]: Enum.KeyCode} if you think your binding_names will be inconsistent
-- otherwise, hint each known binding_name as "Enum.KeyCode?"
-- NB: certain functions expect this binding schema! See above for which ones cannot be used if you set a custom one.
export type binding_schema = {keyboard: Enum.KeyCode?, gamepad: Enum.KeyCode?, mobile: Enum.KeyCode?}

-- can be set to string for the same reasons as above; using new type solver, you could do keyof<binding_schema>
export type binding_name = "keyboard" | "gamepad" | "mobile" 

export type action_schema = {type: Enum.InputActionType, bindings: binding_schema, enabled: boolean?}; export type context_schema = {[string]: InputAction}; export type input_schema = {[string]: context_schema}
local function _create_binding(name: string, keycode: Enum.KeyCode?): InputBinding local b = Instance.new("InputBinding"); b.Name = name; b.KeyCode = keycode or Enum.KeyCode.Unknown; return b end
local function _create_action(schema: action_schema): InputAction local a = Instance.new("InputAction"); a.Type = schema.type; if schema.enabled == nil then a.Enabled = true else a.Enabled = schema.enabled end; local has_mobile_binding = false; for name: any, keycode: any in schema.bindings do if name == "mobile" then has_mobile_binding = true end; _create_binding(name, keycode).Parent=a end; if not has_mobile_binding then _create_binding("mobile",Enum.KeyCode.Unknown).Parent=a end; return a end

local schema = {
	-- contexts - must have at least 1 action in them
	core = {
		-- actions - you can leave bindings entirely empty, or just specific bindings, or add new ones
		-- a mobile binding is automatically created with Enum.KeyCode.Unknown
		sprint = _create_action {
			type = Enum.InputActionType.Bool,
			bindings = {keyboard = Enum.KeyCode.LeftShift, gamepad = Enum.KeyCode.ButtonR2}
		},
		mouse_trail = _create_action {
			type =  Enum.InputActionType.ViewportPosition,
			bindings = {}
		}
	}
}


local user_input_service = game:GetService("UserInputService")
local players = game:GetService("Players")
local player = players.LocalPlayer
local player_gui = player.PlayerGui

local contexts_folder = Instance.new("Folder"); contexts_folder.Name = "contexts"; contexts_folder.Parent = player_gui

local subscribed_buttons: {[GuiButton]: InputAction} = {}
local last_input_type: Enum.UserInputType

local function _create_context(name: string)

	local new_context = Instance.new("InputContext")
	new_context.Name = name
	new_context.Parent = contexts_folder

	return new_context

end 

for context_name, context_schema in schema :: input_schema do
	local new_context = _create_context(context_name)

	local non_empty_context = false
	for action_name, action in context_schema do
		non_empty_context = true
		action.Name = action_name
		action.Parent = new_context
	end
	table.freeze(context_schema)

	assert(non_empty_context, "cannot have empty context in schema: " .. context_name) -- contexts are indexed by action.Parent via next()
end

table.freeze(schema)


local function set_action_ui_button(action: InputAction, button: GuiButton, subscribed: boolean?)
	local binding = action:FindFirstChild("mobile") :: InputBinding
	assert(binding, "unable to find mobile binding for action: ".. action.Name)
	if binding.UIButton then subscribed_buttons[binding.UIButton] = nil end -- for a pre-existing uibutton that was subscribed
	binding.UIButton = button
	if subscribed then subscribed_buttons[button] = action :: InputAction else subscribed_buttons[button] = nil end
end

local function set_binding_for_action(action: InputAction, binding_name: binding_name, keycode: Enum.KeyCode)
	local binding = action:FindFirstChild(binding_name) :: InputBinding
	if not binding then binding = _create_binding(binding_name, keycode); (binding::any).Parent = action else binding.KeyCode = keycode end
	return binding -- to allow set properties
end

local function get_binding_schema_for_action(action: InputAction): binding_schema
	local t = {}
	for _, v in action:GetChildren() do if v:IsA("InputBinding") then t[(v.Name) :: any] = v.KeyCode end end
	return t
end

local function get_keycode_for_binding(action: InputAction, binding_name: string): Enum.KeyCode?
	local input_binding = action:FindFirstChild(binding_name) :: InputBinding
	return if input_binding then input_binding.KeyCode else nil
end

local function set_binding_schema_for_action(action: InputAction, bindings: binding_schema)
	for _, v in action:GetChildren() do if v.Name == "mobile" then continue end; v:Destroy() end -- clear old bindings
	for binding_name, keycode in bindings do
		set_binding_for_action(action, binding_name :: binding_name, keycode :: Enum.KeyCode)
	end
end


local function get_context(schema: context_schema): InputContext
	local _, any_action = next(schema)
	return any_action.Parent :: InputContext
end


local function on_last_input_type_changed(new_input_type: Enum.UserInputType)
	if new_input_type == Enum.UserInputType.Focus then return end
	for button, action in subscribed_buttons do 
		button.Visible = 
			new_input_type == Enum.UserInputType.Touch and 
			action.Enabled and 
			(action.Parent :: InputContext).Enabled 
	end
	last_input_type = new_input_type
end
on_last_input_type_changed(user_input_service:GetLastInputType())
user_input_service.LastInputTypeChanged:Connect(on_last_input_type_changed)

local function get_last_binding_type(user_input_type: Enum.UserInputType?): binding_name
	user_input_type = user_input_type or last_input_type
	local value = last_input_type.Value
	if (value >= 0 and value < 5) or value == 8 then return "keyboard"
	elseif value > 11 and value < 20 then return "gamepad"
	end
	return "mobile" -- everything else is mobile lol
end

-- you should only use this if your binding_name is set to {keyboard: Enum.KeyCode?, gamepad: Enum.KeyCode?, ...}
-- nil return means that the client timed out and did not enter an input (>5s)
local function wait_for_rebind(action: InputAction): {binding_name: binding_name, keycode: Enum.KeyCode}?
	local user_input_service = game:GetService("UserInputService")

	local result_binding_name: binding_name = nil
	local result_keycode: Enum.KeyCode = nil

	local connection
	connection = user_input_service.InputBegan:Connect(function(input_object, game_processed_event)
		-- 2 upvalues
		if game_processed_event then return end

		local user_input_type = input_object.UserInputType
		local last_binding_type = get_last_binding_type(user_input_type)
		if last_binding_type == "keyboard" or last_binding_type == "gamepad" then
			result_binding_name = last_binding_type
			result_keycode = input_object.KeyCode :: Enum.KeyCode
			if connection and connection.Connected then connection:Disconnect(); connection = nil :: any end
		end
	end)

	local elapsed = 0
	while not result_binding_name and elapsed < 5 do elapsed += task.wait() end

	if connection and connection.Connected then
		connection:Disconnect()
	end

	if result_binding_name == "gamepad" or result_binding_name == "keyboard" then
		set_binding_for_action(action, result_binding_name, result_keycode)
		return {binding_name = result_binding_name, keycode = result_keycode}
	end

	return nil
end


return {
	schema = schema,
	set_action_ui_button = set_action_ui_button,

	set_binding_for_action = set_binding_for_action,
	set_binding_schema_for_action = set_binding_schema_for_action,
	get_binding_schema_for_action = get_binding_schema_for_action,
	get_keycode_for_binding = get_keycode_for_binding,

	get_last_binding_type = get_last_binding_type,
	wait_for_rebind = wait_for_rebind,

	get_context = get_context,

	-- these are supposed to be private but might as well return them for easier mutability of the IAS
	_create_binding = _create_binding,
	_create_action = _create_action,
	_create_context = _create_context
}

