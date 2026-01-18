extends Control

const GAME_SCENE_PATH := "res://scenes/game_3d.tscn"

var is_loading := false
@onready var start_prompt: Label = $VBox/StartPrompt

func _process(_delta: float) -> void:
	if is_loading:
		var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene := ResourceLoader.load_threaded_get(GAME_SCENE_PATH) as PackedScene
			get_tree().change_scene_to_packed(scene)
		return

	if Input.is_action_just_pressed("jump"):
		is_loading = true
		start_prompt.text = "Loading..."
		ResourceLoader.load_threaded_request(GAME_SCENE_PATH)
