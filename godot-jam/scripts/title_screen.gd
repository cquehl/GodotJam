extends Control

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		get_tree().change_scene_to_file("res://scenes/game_3d.tscn")
