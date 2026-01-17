extends Label

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	_update_text()

func _on_score_changed(_new_score: int) -> void:
	_update_text()

func _update_text() -> void:
	text = "Score: %d" % GameManager.score
