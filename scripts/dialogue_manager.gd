extends CanvasLayer
@onready var panel := $Panel
@onready var label := $Panel/Label
@onready var avatar := $Panel/Avatar
var npc_position: Vector2 = Vector2.ZERO
var active := false
var can_talk := false
var full_text := ""
var char_index := 0
var char_speed := 0.036
var timer := 0.0
var typing := false
@onready var continue_arrow := $Panel/ContinueArrow
var arrow_base_y := 0.0
var arrow_time := 0.0
var arrow_bounce_speed := 6.0
var arrow_bounce_height := 1.0
@export var avatars := {
	"kiwi_happy": preload("res://assets/Characters/Avatars/kiwi/kiwi happy.png"),
	"kiwi_eye": preload("res://assets/Characters/Avatars/kiwi/kiwi eye1.png"),
	"kiwi_angry": preload("res://assets/Characters/Avatars/kiwi/kiwi angry.png"),
	"mock_sad": preload("res://assets/Characters/Avatars/mock/mock sad.png"),
	"mock_unsure": preload("res://assets/Characters/Avatars/mock/mock unsure.png"),
	"mock_cry": preload("res://assets/Characters/Avatars/mock/mock cry.png")
}

func _ready():
	panel.visible = false
	continue_arrow.visible = false
	avatar.visible = false
	arrow_base_y = continue_arrow.position.y

func _process(delta):
	if waiting_for_zoom:
		continue_arrow.visible = false
		return
	if not typing:
		continue_arrow.visible = true
		arrow_time += delta * arrow_bounce_speed
		continue_arrow.position.y = arrow_base_y + sin(arrow_time) * arrow_bounce_height
		return
	timer += delta
	if timer >= char_speed:
		timer = 0.0
		char_index += 1
		update_label()
		if char_index >= full_text.length():
			typing = false
			return
		# Check the character that was just revealed
		var current_char := full_text.substr(char_index - 1, 1)
		if current_char == ".":
			timer = -0.3  # adds a 0.3s pause after periods
		elif current_char == ",":
			timer = -0.15  # adds a 0.15s pause after commas
		elif current_char in ["!", "?"]:
			timer = -0.3

# Reveals chars up to char_index, hides the rest with a transparent color tag
func update_label():
	var visible_part := full_text.substr(0, char_index)
	var hidden_part := full_text.substr(char_index)
	label.text = visible_part + "[color=#00000000]" + hidden_part + "[/color]"

var zoom_delay := 0.7  # should match your camera tween duration
var waiting_for_zoom := false
var pending_line: Dictionary = {}

var is_first_message := true

func show_text(line: Dictionary):
	active = true
	avatar.texture = avatars[line["avatar"]]
	avatar.flip_h = line.get("flip_h", false)
	continue_arrow.visible = false

	if is_first_message:
		is_first_message = false
		panel.visible = false  # keep hidden during zoom
		avatar.visible = false
		waiting_for_zoom = true
		typing = false
		label.text = ""

		await get_tree().create_timer(zoom_delay).timeout

		panel.visible = true
		avatar.visible = true
		waiting_for_zoom = false

	full_text = line["text"]
	char_index = 0
	timer = 0.0
	typing = true
	update_label()

func hide_dialogue():
	active = false
	is_first_message = true  # reset for next conversation
	panel.visible = false

func advance():
	if typing:
		label.text = full_text
		typing = false
		continue_arrow.visible = true
