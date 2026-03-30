extends CanvasLayer

@onready var continue_button = $Panel/VBoxContainer/Continue
@onready var retry_button = $Panel/VBoxContainer/Retry
@onready var settings_button = $Panel/VBoxContainer/Settings
@onready var exit_button = $Panel/VBoxContainer/ExitGame
@onready var settings_panel = $SettingsPanel
@onready var back_button = $SettingsPanel/VBoxContainer/BackButton
@onready var reset_button = $SettingsPanel/VBoxContainer/ResetButton
@onready var jsquad_check = $SettingsPanel/Jsquad
@onready var touch_controls_check = $SettingsPanel/TouchControlsCheck
@onready var touch_controls_layer = get_tree().root.get_node("Main/TouchButtons")  # adjust path as needed
var player
var touch_controls_disabled := false

var waiting_for_rebind = false
var action_to_rebind = ""
var button_being_rebound: Button = null

const jsquad_controls := {
	"move_left": [
		{ "type": "key", "keycode": KEY_A },
		{ "type": "key", "keycode": KEY_LEFT }
	],
	"move_right": [
		{ "type": "key", "keycode": KEY_D },
		{ "type": "key", "keycode": KEY_RIGHT }
	],
	"jump": [
		{ "type": "key", "keycode": KEY_W }
	],
	"ui_up": [
		{ "type": "key", "keycode": KEY_SPACE },
		{ "type": "key", "keycode": KEY_W }
	],
	"ui_down": [
		{ "type": "key", "keycode": KEY_S }
	],
	"dash": [
		{ "type": "mouse", "keycode": MOUSE_BUTTON_LEFT }
	],
	"climb": [
		{ "type": "mouse", "keycode": MOUSE_BUTTON_RIGHT }
	],
}

const gamecube_controls := {
	"move_left": [
		{ "type": "joypad", "button_index": 13, "device": 0 },
	],
	"move_right": [
		{ "type": "joypad", "button_index": 14, "device": 0 },
	],
	"ui_up": [
		{ "type": "joypad", "button_index": 11, "device": 0 },
	],
	"ui_down": [
		{ "type": "joypad", "button_index": 12, "device": 0 },
	],
	"jump": [
		{ "type": "joypad", "button_index": 1, "device": 0 },
		{ "type": "joypad", "button_index": 3, "device": 0 }
	],
	"dash": [
		{ "type": "joypad", "button_index": 0, "device": 0 },
		#{ "type": "joypad_axis", "axis": 5, "axis_value": 0.5, "device": 0 }
	],
	"climb": [
		{ "type": "joypad", "button_index": 2, "device": 0 },
		{ "type": "joypad_axis", "axis": 5, "axis_value": 0.5, "device": 0 },
		{ "type": "joypad_axis", "axis": 4, "axis_value": 0.5, "device": 0 }
	],
	"pause": [
		{ "type": "joypad", "button_index": 6, "device": 0 }
	],
	"ui_accept": [
	{ "type": "joypad", "button_index": 0, "device": 0 }
],
}
func _on_touch_controls_checked(is_on: bool) -> void:
	if touch_controls_layer:
		touch_controls_layer.visible = not is_on
		touch_controls_layer.touch_controls_shown = is_on
		touch_controls_disabled = is_on
		
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_controls()
	visible = false

	touch_controls_check.toggled.connect(_on_touch_controls_checked)
	# Main pause menu buttons
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	retry_button.pressed.connect(_on_retry_pressed)

	# Settings panel buttons
	back_button.pressed.connect(_on_back_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	jsquad_check.toggled.connect(_on_jsquad_checked)
	set_process_unhandled_input(true)

	# Connect rebinding buttons dynamically
	for button in settings_panel.get_node("VBoxContainer").get_children():
		if button != back_button and button != reset_button:
			button.pressed.connect(Callable(self, "_on_rebind_pressed").bind(button))


var just_closed := false
func _unhandled_input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if settings_panel.visible:
			_on_back_pressed()
		else:
			_on_continue_pressed()
		get_viewport().set_input_as_handled()
	#if event.is_action_pressed("pause"):
		#get_viewport().set_input_as_handled()
	

func open():
	visible = true
	$Panel.visible = true
	settings_panel.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	continue_button.grab_focus()

func close():
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player = get_tree().get_first_node_in_group("player")
	if player:
		#player.ignore_just_pressed = true
		player.sync_held_keys()

# --- Main PauseMenu buttons ---
func _on_continue_pressed():
	close()

func _on_retry_pressed():
	get_tree().get_first_node_in_group("player").die()
	close()

func _on_settings_pressed():
	$Panel.visible = false
	settings_panel.visible = true
	back_button.grab_focus()

func _on_exit_pressed():
	get_tree().quit()

# --- Settings menu buttons ---
func _on_back_pressed():
	settings_panel.visible = false
	$Panel.visible = true
	continue_button.grab_focus()
	
func _on_reset_pressed():
	if FileAccess.file_exists("user://controls.cfg"):
		DirAccess.remove_absolute("user://controls.cfg")
	waiting_for_rebind = false
	action_to_rebind = ""
	_load_controls()
	
func _on_jsquad_checked(is_on: bool):
	if is_on:
		apply_controls(jsquad_controls)
		if touch_controls_layer:
			touch_controls_layer.visible = false
			touch_controls_layer.touch_controls_shown = true
		touch_controls_disabled = true
		touch_controls_check.button_pressed = true
		touch_controls_check.disabled = true
	else:
		_load_controls()
		touch_controls_check.disabled = false 

func apply_controls(controls: Dictionary) -> void:
	for action_name in controls.keys():
		if not InputMap.has_action(action_name):
			continue

		# Don't erase existing events, just add new ones
		var existing_events = InputMap.action_get_events(action_name)
		
		var events := controls[action_name] as Array
		for event_dict in events:
			var ev: InputEvent = null

			match event_dict["type"]:
				"key":
					var key_ev := InputEventKey.new()
					key_ev.keycode = event_dict["keycode"] as Key
					ev = key_ev
				"joypad":
					var joy_ev := InputEventJoypadButton.new()
					joy_ev.button_index = int(event_dict["button_index"]) as JoyButton
					joy_ev.device = event_dict.get("device", 0)
					ev = joy_ev
				"joypad_axis":
					var axis_ev := InputEventJoypadMotion.new()
					axis_ev.axis = event_dict["axis"]
					axis_ev.axis_value = event_dict["axis_value"]
					axis_ev.device = event_dict.get("device", 0)
					ev = axis_ev
				"mouse":
					var mouse_ev := InputEventMouseButton.new()
					mouse_ev.button_index = event_dict["keycode"]
					ev = mouse_ev

			if ev:
				# Only add if not already bound
				var already_exists := false
				for existing in existing_events:
					if existing.get_class() == ev.get_class():
						if ev is InputEventJoypadButton and existing is InputEventJoypadButton:
							if existing.button_index == ev.button_index:
								already_exists = true
				if not already_exists:
					InputMap.action_add_event(action_name, ev)
	
#func apply_controls(controls: Dictionary) -> void:
	#for action_name in controls.keys():
		#if not InputMap.has_action(action_name):
			#continue
#
		#InputMap.action_erase_events(action_name)
#
		#var events := controls[action_name] as Array
		#for event_dict in events:
			#var ev: InputEvent = null
#
			#match event_dict["type"]:
				#"key":
					#var key_ev := InputEventKey.new()
					#key_ev.keycode = event_dict["keycode"] as Key
					#ev = key_ev
#
				#"joypad_axis":
					#var axis_ev := InputEventJoypadMotion.new()
					#axis_ev.axis = event_dict["axis"]
					#axis_ev.axis_value = event_dict["axis_value"]
					#axis_ev.device = event_dict.get("device", 0)
					#ev = axis_ev
					#
				#"joypad":
					#var joy_ev := InputEventJoypadButton.new()
					#joy_ev.button_index = int(event_dict["button_index"]) as JoyButton
					#joy_ev.device = event_dict.get("device", 0)
					#ev = joy_ev
					#
				#"mouse":
					#var mouse_ev := InputEventMouseButton.new()
					#mouse_ev.button_index = event_dict["keycode"]
					#ev = mouse_ev
#
			#if ev:
				#InputMap.action_add_event(action_name, ev)

func _on_rebind_pressed(button):
	button_being_rebound = button
	button.set_meta("original_text", button.text)
	waiting_for_rebind = true
	action_to_rebind = button.get_meta("bind_name")
	button.text = "Press any key..."
	

func update_bind_menu():
	var vbox = settings_panel.get_node("VBoxContainer")
	
	for button in vbox.get_children():
		if not button.has_meta("action_name"):
			continue
		var events = InputMap.get_actions()
		
		var display_texts := []
		for ev in events:
			if ev is InputEventKey:
				display_texts.append(ev.keycode.as_text())  # Shows key name
			elif ev is InputEventJoypadButton:
				display_texts.append("Joypad Button " + str(ev.button_index))
		
		# Combine multiple bindings with comma
		if display_texts.size() > 0:
			button.text = ", ".join(display_texts)
		else:
			button.text = "Unbound"
		
		# Store original text so we can revert after rebinding
		button.set_meta("original_text", button.text)

func _input(event):
	if waiting_for_rebind:
		if event is InputEventKey:
			# Ignore Escape
			if event.keycode == Key.KEY_ESCAPE:
				# Cancel rebinding instead
				if button_being_rebound and button_being_rebound.has_meta("original_text"):
					button_being_rebound.text = button_being_rebound.get_meta("original_text")
				waiting_for_rebind = false
				return  # stop processing
			_rebind_action(action_to_rebind, event)
		
			# Restore button text
			if button_being_rebound and button_being_rebound.has_meta("original_text"):
				button_being_rebound.text = button_being_rebound.get_meta("original_text")
		
		elif event is InputEventJoypadButton:
			_rebind_action(action_to_rebind, event)
			
			waiting_for_rebind = false


# --- Rebinding helper ---
func _rebind_action(action_name: String, event: InputEvent):
	for old_event in InputMap.action_get_events(action_name):
		InputMap.action_erase_event(action_name, old_event)
	InputMap.action_add_event(action_name, event)
	_save_controls()

# --- Save / Load ---
func _save_controls():
	var config := ConfigFile.new()

	for action_name in InputMap.get_actions():
		var events_array := []
		for ev in InputMap.action_get_events(action_name):
			if ev is InputEventKey:
				events_array.append({
					"type": "key",
					"keycode": ev.keycode,
					"physical_keycode": ev.physical_keycode,
					"shift": ev.shift_pressed,
					"ctrl": ev.ctrl_pressed,
					"alt": ev.alt_pressed
				})
			elif ev is InputEventJoypadButton:
				events_array.append({
					"type": "joypad",
					"button_index": ev.button_index,
					"device": ev.device
				})
			# add more types if needed
		config.set_value("controls", action_name, events_array)

	config.save("user://controls.cfg")

func _load_controls():
	# 1️⃣ Restore all default actions first
	InputMap.load_from_project_settings()

	# 2️⃣ Load the user config file
	var config := ConfigFile.new()
	if config.load("user://controls.cfg") != OK:
		# No config yet or failed to load — defaults remain
		return

	# 3️⃣ Iterate through all actions in the "controls" section
	for action_name in config.get_section_keys("controls"):
		if not InputMap.has_action(action_name):
			continue

		# Clear any existing events for this action
		InputMap.action_erase_events(action_name)

		var events: Array = config.get_value("controls", action_name, [])
		for event_dict: Dictionary in events:
			if not event_dict.has("type"):
				continue  # skip malformed entries

			var ev_type := str(event_dict["type"])

			if ev_type == "key" and event_dict.has("keycode"):
				var ev := InputEventKey.new()
				ev.keycode = int(event_dict["keycode"]) as Key
				ev.physical_keycode = int(event_dict.get("physical_keycode", 0)) as Key
				ev.shift_pressed = bool(event_dict.get("shift", false))
				ev.ctrl_pressed = bool(event_dict.get("ctrl", false))
				ev.alt_pressed = bool(event_dict.get("alt", false))
				InputMap.action_add_event(action_name, ev)

			elif ev_type == "joypad" and event_dict.has("button_index") and event_dict.has("device"):
				var ev := InputEventJoypadButton.new()
				ev.button_index = int(event_dict["button_index"]) as JoyButton
				ev.device = int(event_dict["device"])
				InputMap.action_add_event(action_name, ev)

func _load_level(level : String):
	$Main.load_level(level)
