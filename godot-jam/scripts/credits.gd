extends Control

func _ready() -> void:
	# Keep menu music playing
	pass

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
