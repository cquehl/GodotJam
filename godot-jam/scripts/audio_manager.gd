extends Node

# =============================================================================
# AUDIO MANAGER
# Handles background music and sound effects with smooth transitions
# =============================================================================

# Music tracks
const MENU_MUSIC := "res://audio/music/_menue_music.mp3"
const GAMEPLAY_TRACKS := [
	"res://audio/music/_game_music.mp3",
]

# Sound effects (.wav for low-latency playback)
const SFX := {
	"collect": "res://audio/sfx/collect.wav",
	"hit": "res://audio/sfx/hit.wav",
	"powerup": "res://audio/sfx/powerup.wav",
	"powerup_end": "res://audio/sfx/powerup_end.wav",
	"jump": "res://audio/sfx/jump.wav",
	"game_over": "res://audio/sfx/game_over.wav",
}

# Audio buses
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

# Settings
var music_volume: float = 0.7:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_update_music_volume()

var sfx_volume: float = 0.8:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)

var music_enabled: bool = true
var sfx_enabled: bool = true

# Music state
var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _current_track_index: int = -1
var _is_crossfading: bool = false
var _crossfade_duration: float = 2.0
var _crossfade_progress: float = 0.0

# SFX pool
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 8

# Cached audio streams
var _cached_music: Dictionary = {}
var _cached_sfx: Dictionary = {}

# Track what type of music is playing
var _playing_menu_music: bool = false

func _ready() -> void:
	_setup_audio_buses()
	_setup_music_players()
	_setup_sfx_pool()
	_preload_audio()
	_connect_game_signals()

	# Start music after a short delay
	call_deferred("_start_music")

func _setup_audio_buses() -> void:
	# Create audio buses if they don't exist
	# Check if Music bus exists
	var music_bus_idx := AudioServer.get_bus_index(MUSIC_BUS)
	if music_bus_idx == -1:
		AudioServer.add_bus()
		music_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_bus_idx, MUSIC_BUS)
		AudioServer.set_bus_send(music_bus_idx, "Master")

	# Check if SFX bus exists
	var sfx_bus_idx := AudioServer.get_bus_index(SFX_BUS)
	if sfx_bus_idx == -1:
		AudioServer.add_bus()
		sfx_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_bus_idx, SFX_BUS)
		AudioServer.set_bus_send(sfx_bus_idx, "Master")

func _setup_music_players() -> void:
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = MUSIC_BUS
	_music_player_a.volume_db = linear_to_db(music_volume)
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = MUSIC_BUS
	_music_player_b.volume_db = linear_to_db(0.0)
	add_child(_music_player_b)

	_active_player = _music_player_a

	# Connect finished signals for looping/track changes
	_music_player_a.finished.connect(_on_music_finished.bind(_music_player_a))
	_music_player_b.finished.connect(_on_music_finished.bind(_music_player_b))

func _setup_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)

func _preload_audio() -> void:
	# Only preload small SFX synchronously - music is loaded on-demand
	for sfx_name in SFX:
		var sfx_path: String = SFX[sfx_name]
		if ResourceLoader.exists(sfx_path):
			_cached_sfx[sfx_name] = load(sfx_path)

	# Start loading menu music in background (non-blocking)
	if ResourceLoader.exists(MENU_MUSIC):
		ResourceLoader.load_threaded_request(MENU_MUSIC)

	# DON'T preload gameplay music - it's 12MB and not needed until game starts

func _connect_game_signals() -> void:
	# Connect to game events for automatic SFX
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.power_up_started.connect(_on_power_up_started)
	GameManager.power_up_ended.connect(_on_power_up_ended)
	GameManager.game_over_triggered.connect(_on_game_over)

func _start_music() -> void:
	# Don't auto-start music - let scenes control what plays
	pass

func _process(delta: float) -> void:
	if _is_crossfading:
		_process_crossfade(delta)

func _process_crossfade(delta: float) -> void:
	_crossfade_progress += delta / _crossfade_duration

	if _crossfade_progress >= 1.0:
		_crossfade_progress = 1.0
		_is_crossfading = false

		# Fully switch to new player
		var inactive_player := _music_player_a if _active_player == _music_player_b else _music_player_b
		inactive_player.stop()
		inactive_player.volume_db = linear_to_db(0.0)
		_active_player.volume_db = linear_to_db(music_volume)
	else:
		# Smooth crossfade using ease
		var t := ease(_crossfade_progress, 0.5)
		_active_player.volume_db = linear_to_db(music_volume * t)

		var inactive_player := _music_player_a if _active_player == _music_player_b else _music_player_b
		inactive_player.volume_db = linear_to_db(music_volume * (1.0 - t))

func _update_music_volume() -> void:
	if not _is_crossfading:
		_active_player.volume_db = linear_to_db(music_volume)

# =============================================================================
# PUBLIC API - MUSIC
# =============================================================================

## Get music from cache, or load it (checking threaded loader first)
func _get_or_load_music(path: String) -> AudioStream:
	# Already cached
	if _cached_music.has(path):
		return _cached_music[path]

	# Check if threaded load is complete
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var stream := ResourceLoader.load_threaded_get(path) as AudioStream
		_cached_music[path] = stream
		return stream

	# Not loaded yet - load synchronously (fallback)
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		_cached_music[path] = stream
		return stream

	return null

func play_track(index: int) -> void:
	if not music_enabled:
		return

	if index < 0 or index >= GAMEPLAY_TRACKS.size():
		return

	var track_path: String = GAMEPLAY_TRACKS[index]
	var stream := _get_or_load_music(track_path)
	if stream == null:
		return

	_current_track_index = index

	if _active_player.playing:
		# Crossfade to new track
		var new_player := _music_player_a if _active_player == _music_player_b else _music_player_b
		new_player.stream = stream
		new_player.volume_db = linear_to_db(0.0)
		new_player.play()

		_active_player = new_player
		_is_crossfading = true
		_crossfade_progress = 0.0
	else:
		# Start fresh
		_active_player.stream = stream
		_active_player.volume_db = linear_to_db(music_volume)
		_active_player.play()

func play_random_track() -> void:
	if GAMEPLAY_TRACKS.is_empty():
		return

	# Pick any track except the current one (if possible)
	if GAMEPLAY_TRACKS.size() == 1:
		play_track(0)
		return

	var available_tracks: Array[int] = []
	for i in GAMEPLAY_TRACKS.size():
		if i != _current_track_index:
			available_tracks.append(i)

	var random_index: int = available_tracks[randi() % available_tracks.size()]
	play_track(random_index)

func play_next_track() -> void:
	var next_index := (_current_track_index + 1) % GAMEPLAY_TRACKS.size()
	play_track(next_index)

func play_menu_music() -> void:
	if not music_enabled:
		return

	_playing_menu_music = true

	# Get or load menu music (handles threaded loading)
	var stream := _get_or_load_music(MENU_MUSIC)
	if stream == null:
		return

	if _active_player.playing:
		# Crossfade to menu music
		var new_player := _music_player_a if _active_player == _music_player_b else _music_player_b
		new_player.stream = stream
		new_player.volume_db = linear_to_db(0.0)
		new_player.play()

		_active_player = new_player
		_is_crossfading = true
		_crossfade_progress = 0.0
	else:
		_active_player.stream = stream
		_active_player.volume_db = linear_to_db(music_volume)
		_active_player.play()

func play_gameplay_music() -> void:
	if not music_enabled:
		return

	_playing_menu_music = false
	play_random_track()

func stop_music(fade_out: float = 1.0) -> void:
	if fade_out <= 0:
		_music_player_a.stop()
		_music_player_b.stop()
	else:
		var tween := create_tween()
		tween.tween_property(_active_player, "volume_db", linear_to_db(0.0), fade_out)
		tween.tween_callback(_active_player.stop)

func pause_music() -> void:
	_music_player_a.stream_paused = true
	_music_player_b.stream_paused = true

func resume_music() -> void:
	_music_player_a.stream_paused = false
	_music_player_b.stream_paused = false

# =============================================================================
# PUBLIC API - SOUND EFFECTS
# =============================================================================

func play_sfx(sfx_name: String, pitch_variation: float = 0.0) -> void:
	if not sfx_enabled:
		return

	if not _cached_sfx.has(sfx_name):
		return

	var player := _get_available_sfx_player()
	if player == null:
		return

	player.stream = _cached_sfx[sfx_name]
	player.volume_db = linear_to_db(sfx_volume)

	if pitch_variation > 0:
		player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	else:
		player.pitch_scale = 1.0

	player.play()

func play_collect() -> void:
	play_sfx("collect", 0.1)

func play_hit() -> void:
	play_sfx("hit", 0.05)

func play_powerup() -> void:
	play_sfx("powerup")

func play_powerup_end() -> void:
	play_sfx("powerup_end")

func play_jump() -> void:
	play_sfx("jump", 0.15)

func play_game_over() -> void:
	play_sfx("game_over")

func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player

	# All players busy, return the first one (will interrupt oldest sound)
	return _sfx_players[0]

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_music_finished(player: AudioStreamPlayer) -> void:
	if player == _active_player:
		if _playing_menu_music:
			# Loop menu music
			play_menu_music()
		else:
			# Play next gameplay track
			play_random_track()

func _on_score_changed(new_score: int) -> void:
	if new_score > 0:
		play_collect()

func _on_power_up_started() -> void:
	play_powerup()

func _on_power_up_ended() -> void:
	play_powerup_end()

func _on_game_over() -> void:
	play_game_over()
