extends Node2D

@export var dialogue: Array[Dictionary] = [
	{"text": "Ah! You made it.", "avatar": "kiwi_happy"},
	{"text": "Told ya all it took was a little climbing.", "avatar": "kiwi_eye"},
	{"text":"I made it? That’s debatable.", "avatar": "mock_unsure"},
	{"text":"I think I just fell in the right directions.", "avatar": "mock_unsure"},
	{"text": "Same thing, featherbrain…", "avatar": "kiwi_eye"},
	{"text": "Sky above you really remind me of my son, Kip..", "avatar": "kiwi_happy"},
	{"text": "Is he also stuck in a cave?", "avatar": "mock_unsure"},
	{"text":"No, no, no he’s not in a cave.", "avatar": "kiwi_happy"},
	{"text": "I’ve checked every blasted cave from here to the coast.", "avatar": "kiwi_angry"},
	{"text": "You think I enjoy spelunking?", "avatar": "kiwi_angry"},
	{"text": "I’m a kiwi, not a mountain goat!", "avatar": "kiwi_angry"},
	{"text": "Right..", "avatar": "mock_unsure"},
	{"text": "No time to waste, you’re almost out.", "avatar": "kiwi_happy"},
]
@export var talk_position: float = position.x - 50  # set this in the editor
@onready var arrow := $Arrow
var arrow_base_y := 0.0
var arrow_time := 0.0

var dialogue_index := 0
var player_in_range := false

func _ready():
	$TalkBox.body_entered.connect(_on_body_entered)
	$TalkBox.body_exited.connect(_on_body_exited)
	arrow.visible = false
	arrow_base_y = arrow.position.y

func _process(delta):
	if player_in_range and Input.is_action_just_pressed("dash"):
		talk_trigger(get_tree().get_first_node_in_group("player"))
	if arrow.visible:
		arrow_time += delta * 6.0
		arrow.position.y = arrow_base_y + sin(arrow_time) * 4.0
		
func talk():
	if DialogueManager.typing:
		DialogueManager.advance()
		return

	if dialogue_index < dialogue.size():
		DialogueManager.show_text(dialogue[dialogue_index])
		dialogue_index += 1
		arrow.visible = false
	else:
		DialogueManager.hide_dialogue()
		dialogue_index = 0
		arrow.modulate.a = 0.25
		arrow.visible = true


func _on_body_entered(body):
	if body.name == "Player":
		player_in_range = true
		DialogueManager.can_talk = true
		arrow.visible = true
		arrow_time = 0.0

func _on_body_exited(body):
	if body.name == "Player":
		player_in_range = false
		dialogue_index = 0
		DialogueManager.hide_dialogue()
		DialogueManager.can_talk = false
		arrow.visible = false

func talk_trigger(player):
	DialogueManager.npc_position = global_position
	player.walk_to_position(talk_position)
	player.reached_target.connect(
	_on_player_at_talk_position.bind(player),
	CONNECT_ONE_SHOT
)
	
func _on_player_at_talk_position(player):
	# Make the player face the NPC
	var direction = global_position.x - player.global_position.x
	player.facing_right = direction >= 0   # or however you track facing
	# Start the dialogue
	talk()   # your normal function that calls DialogueManager.show_text()
