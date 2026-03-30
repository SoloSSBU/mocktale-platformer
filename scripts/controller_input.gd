extends Node

var threshold = 0.5

var _was_left := false
var _was_right := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta):
	if Input.get_connected_joypads().is_empty():
		return

	var axis_x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)

	_handle_ui_action("ui_left", axis_x < -threshold, _was_left)
	_was_left = axis_x < -threshold
	_handle_ui_action("ui_right", axis_x > threshold, _was_right)
	_was_right = axis_x > threshold

func _handle_ui_action(action: String, is_pressed: bool, was_pressed: bool):
	if is_pressed and not was_pressed:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = true
		Input.parse_input_event(ev)
	elif not is_pressed and was_pressed:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = false
		Input.parse_input_event(ev)
