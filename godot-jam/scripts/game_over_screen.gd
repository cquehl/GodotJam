extends Control

@onready var message_label: Label = $VBox/Message
@onready var score_label: Label = $VBox/Score
@onready var high_score_label: Label = $VBox/HighScore
@onready var continue_label: Label = $VBox/Continue

func _ready() -> void:
	var score := GameManager.last_score

	# Set the score displays
	score_label.text = "Your Score: %d" % score
	high_score_label.text = "High Score: %d" % GameManager.high_score

	# Set message and color based on score
	var message: String
	var color: Color

	if score == 0:
		message = "Were you paying attention?"
		color = Color.GREEN
	elif score <= 3:
		message = "Watch out!"
		color = Color.LIME
	elif score <= 7:
		message = "I hope you had fun!"
		color = Color.YELLOW
	elif score <= 12:
		message = "Wow, that's impressive!"
		color = Color.ORANGE
	elif score <= 20:
		message = "Seriously, you are impressive!"
		color = Color.CORAL
	elif score <= 29:
		message = "You're on fire! Literally!"
		color = Color.HOT_PINK
	else:
		message = "You win! I didn't think this was possible. GGz"
		color = Color.CYAN

	message_label.text = message
	message_label.add_theme_color_override("font_color", color)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
