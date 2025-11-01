--!strict
--!native
--!optimize 2

--[[
	API:
	local schema = iasy.schema -- this is the schema. it is frozen (immutable)
	
	local core = iasy.get_context(schema.core) -- this is an InputContext generated from the schema. it is also frozen.
	local sprint_action = core.sprint -- this is an InputAction in the schema
	local sprint_bindings = iasy.get_binding_schema_for_action(sprint_action) -- this is a fresh table of bindings for the action. 
	NB: this does not return InputBindings, only {[string]: Enum.KeyCode} (same as schema)
	
	iasy.set_binding_schema_for_action(sprint_action, sprint_bindings) -- apply the "new" bindings
	iasy.set_binding_for_action(sprint_action, "keyboard", Enum.KeyCode.B) -- set the binding for keyboard to B. set to Enum.KeyCode.Unknown to disable it.
	Returns the InputBinding for further property changes if necessary.
	
	iasy.set_action_ui_button(sprint_action, ui_button, true) -- set the ui button for the action. 
	last param is optional for auto-hiding/showing for touch-screen
--]]

export type binding_schema = {[string]: Enum.KeyCode}
export type action_schema = {type: Enum.InputActionType, bindings: binding_schema, enabled: boolean?}
export type context_schema = {[string]: InputAction}
export type input_schema = {[string]: context_schema}

local function _create_binding(name: string, keycode: Enum.KeyCode?): InputBinding local b = Instance.new("InputBinding"); b.Name = name; b.KeyCode = keycode or Enum.KeyCode.Unknown; return b end
local function _create_action(schema: action_schema): InputAction local a = Instance.new("InputAction"); a.Type = schema.type; if schema.enabled == nil then a.Enabled = true else a.Enabled = schema.enabled end; for name, keycode in schema.bindings do assert(name~="mobile","cannot name binding as mobile!"); _create_binding(name,keycode).Parent=a end; _create_binding("mobile",Enum.KeyCode.Unknown).Parent=a; return a end

local schema = {
	-- contexts - must have at least 1 action in them
	core = {
		-- actions - use Enum.KeyCode.Unknown if you wish to leave a binding blank. You can also leave bindings entirely empty.
		-- no binding can be named "mobile", though you can get it yourself with set_binding_for_action.
		sprint = _create_action {
			type = Enum.InputActionType.Bool,
			bindings = {keyboard = Enum.KeyCode.LeftShift, gamepad = Enum.KeyCode.ButtonR2}
		},
		mouse_trail = _create_action {
			type =  Enum.InputActionType.ViewportPosition,
			bindings = {}
		}
	},
}

local user_input_service = game:GetService("UserInputService")
local players = game:GetService("Players")
local player = players.LocalPlayer
local player_gui = player.PlayerGui

local contexts_folder = Instance.new("Folder"); contexts_folder.Name = "contexts"; contexts_folder.Parent = player_gui

local subscribed_buttons: {[GuiButton]: InputAction} = {}

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

local function set_binding_for_action(action: InputAction, binding_name: string, keycode: Enum.KeyCode)
	local binding = action:FindFirstChild(binding_name) :: InputBinding
	if not binding then binding = _create_binding(binding_name, keycode); (binding::any).Parent = action else binding.KeyCode = keycode end
	return binding -- to allow set properties
end

local function get_binding_schema_for_action(action: InputAction): binding_schema
	local t = {}
	for _, v in action:GetChildren() do if v:IsA("InputBinding") then t[v.Name] = v.KeyCode end end
	return t
end

local function set_binding_schema_for_action(action: InputAction, bindings: binding_schema)
	for _, v in action:GetChildren() do if v.Name == "mobile" then continue end; v:Destroy() end -- clear old bindings
	for binding_name, keycode in bindings do
		set_binding_for_action(action, binding_name, keycode)
	end
end


local function get_context(schema: context_schema): InputContext
	local _, any_action = next(schema)
	return any_action.Parent :: InputContext
end


local function on_last_input_type_changed(last_input_type: Enum.UserInputType)
	if last_input_type == Enum.UserInputType.Focus then return end
	for button, action in subscribed_buttons do 
		button.Visible = 
			last_input_type == Enum.UserInputType.Touch and 
			action.Enabled and 
			(action.Parent :: InputContext).Enabled 
	end
end
on_last_input_type_changed(user_input_service:GetLastInputType())
user_input_service.LastInputTypeChanged:Connect(on_last_input_type_changed)

return {
	schema = schema,
	set_action_ui_button = set_action_ui_button,

	set_binding_for_action = set_binding_for_action,
	set_binding_schema_for_action = set_binding_schema_for_action,
	get_binding_schema_for_action = get_binding_schema_for_action,

	get_context = get_context,

	-- these are supposed to be private but might as well return them for easier mutability of the schema
	_create_binding = _create_binding,
	_create_action = _create_action,
	_create_context = _create_context
}