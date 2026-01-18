extends Control

@onready var powerups_toggle: CheckButton = $VBox/PowerupsRow/PowerupsToggle

func _ready() -> void:
	# Initialize toggle to match current setting
	powerups_toggle.button_pressed = GameManager.gold_powerups_enabled
	powerups_toggle.toggled.connect(_on_powerups_toggled)

func _on_powerups_toggled(enabled: bool) -> void:
	GameManager.gold_powerups_enabled = enabled

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
