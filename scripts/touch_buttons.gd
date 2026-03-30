extends CanvasLayer

var touch_controls_shown := false
@onready var pause_menu = get_tree().root.get_node("Main/PauseMenu")

func _unhandled_input(event):
	if event is InputEventScreenTouch and event.pressed and not touch_controls_shown and not get_tree().root.get_node("Main/PauseMenu").touch_controls_disabled:
		visible = true
		touch_controls_shown = true

# --- Jump ---
func _on_space_pressed() -> void:
	Input.action_press("jump")
func _on_space_released() -> void:
	Input.action_release("jump")

# --- Dash ---
func _on_shift_pressed() -> void:
	Input.action_press("dash")
func _on_shift_released() -> void:
	Input.action_release("dash")

# --- Climb ---
func _on_climb_pressed() -> void:
	Input.action_press("climb")
func _on_climb_released() -> void:
	Input.action_release("climb")

# --- Pause ---
func _on_escape_pressed() -> void:
	if get_tree().paused:
		pause_menu.close()
	else:
		pause_menu.open()
func _on_escape_released() -> void:
	pass
