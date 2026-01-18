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
	
	if randi() % 6 == 0:
		message = "Did you even jump?"
		color = Color(0.983, 0.372, 0.692, 1.0)
	elif randi() % 12 == 0:
		message = "You gotta jump!"
		color = Color(0.184, 0.961, 0.859, 1.0)
	elif score == 0:
		message = "Were you paying attention?"
		color = Color.RED
	elif score <= 3:
		message = "Watch out next time!"
		color = Color.ORANGE
	elif score <= 7:
		message = "I hope you had fun!"
		color = Color.YELLOW
	elif score <= 14:
		message = "Wow, that's impressive!"
		color = Color.BLUE
	elif score <= 20:
		message = "Seriously!!! You are impressive!"
		color = Color.INDIGO
	elif score <= 29:
		message = "You're on fire! Literally!"
		color = Color.LAWN_GREEN
	else:
		message = "You win! I didn't think this was possible. GGz"
		color = Color.VIOLET

	message_label.text = message
	message_label.add_theme_color_override("font_color", color)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
