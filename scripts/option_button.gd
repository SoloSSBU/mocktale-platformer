extends OptionButton

func _ready():
	select(0)  # selects item at index 1
	# Fires whenever the selected item changes
	item_selected.connect(_on_item_selected)
	
func _on_item_selected(index: int) -> void:
	var selected_text := get_item_text(index).to_lower()
	var main := get_node("/root/Main")
	main.load_level(selected_text)
