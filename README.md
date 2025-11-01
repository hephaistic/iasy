# iasy: schema-based InputActionSystem. 
### Usage:

```lua
-- in the module iasy.luau
local schema = {
	-- contexts - must have at least 1 action in them
	core = {
		-- actions - you can leave bindings entirely empty.
		-- no binding may be named "mobile", though you can get it yourself with set_binding_for_action.
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
--!strict
--!native
--!optimize 2

local iasy = require(path.to.iasy)

local ui_button = path.to.ui.button

local sprint_action = iasy.schema.core.sprint -- this is all autocompleted!
sprint_action.Pressed:Connect(function() print("client is sprinting!") end)

iasy.set_action_ui_button(sprint_action, ui_button, true)

task.wait(5); print("disabled keyboard sprint")
local sprint_bindings = iasy.get_binding_schema_for_action(sprint_action) -- NB: this is a fresh table and is not deep-frozen like schema is.
sprint_bindings["keyboard"] = nil -- remove keyboard binding.

iasy.set_binding_schema_for_action(sprint_action, sprint_bindings) -- you can pass any valid binding_schema to this.

task.wait(5); print("switched sprint to B")
iasy.set_binding_for_action(sprint_action, "keyboard", Enum.KeyCode.B)

task.wait(5); print("disabled core context")
iasy.get_context(iasy.schema.core).Enabled = false
```
