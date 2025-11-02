# iasy: schema-based InputActionSystem. 
### Usage:

```lua
-- in the module iasy.luau
-- you can just set this to {[string]: Enum.KeyCode} if you think your binding_names will be inconsistent
-- otherwise, hint each known binding_name as "Enum.KeyCode?"
export type binding_schema = {keyboard: Enum.KeyCode?, gamepad: Enum.KeyCode?, mobile: Enum.KeyCode?}

-- can be set to string for the same reasons as above; using new type solver, you could do keyof<binding_schema>
export type binding_name = "keyboard" | "gamepad" | "mobile"

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
```

having set up your schema, you can use it as follows:

```lua
local iasy = require(path.to.iasy)

local ui_button = path.to.ui.button

local sprint_action = iasy.schema.core.sprint
sprint_action.Pressed:Connect(function() print("client is sprinting!") end)

iasy.set_action_ui_button(sprint_action, ui_button, false)

task.wait(5); print("disabled keyboard sprint")
local sprint_bindings = iasy.get_binding_schema_for_action(sprint_action) -- NB: this is a fresh table and is not deep-frozen like schema is.
sprint_bindings.keyboard = nil -- remove keyboard binding from schema
iasy.set_binding_schema_for_action(sprint_action, sprint_bindings) -- pass that here in order to update the actual InputBindings

task.wait(5); print("switched sprint to B")
iasy.set_binding_for_action(sprint_action, "keyboard", Enum.KeyCode.B)

task.wait(5); print("waiting for user to rebind") -- rebind appropriate platform binding
ui_button.Text = "Waiting for input..."

local previous_input_type = iasy.get_last_binding_type() 
local result = iasy.wait_for_rebind(iasy.schema.core.sprint) -- only use this if you are using the default binding_name type

-- a use case for actually processing result would be to set custom console icons for keybind hints, for example.
if not result then 
	print("client did not send any valid input for >5s! did not set any bindings")
	local previous_keycode = iasy.get_keycode_for_binding(sprint_action, previous_input_type)
	ui_button.Text = previous_input_type .. " " .. if previous_keycode then previous_keycode.Name else "none!"
else 
	print("successfully set ".. result.binding_name .." to ".. result.keycode.Name)
	if result.binding_name == "keyboard" then ui_button.Text = "Keyboard " .. result.keycode.Name
	else ui_button.Text = "Console " .. result.keycode.Name	
	end
end

task.wait(5); print("disabled core context")
iasy.get_context(iasy.schema.core).Enabled = false

```
