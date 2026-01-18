extends Label

func _ready() -> void:
	text = "High Score: %d\nLast Score: %d" % [GameManager.high_score, GameManager.last_score]
