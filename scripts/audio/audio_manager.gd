extends Node
## Centralized SFX hooks. Silent placeholders until real audio is added.

enum Sfx {
	BUTTON,
	ORDER_SELECTED,
	ORDER_COMPLETED,
	COINS,
	RECIPE_UNLOCKED,
	EQUIPMENT_UPGRADED,
	LEVEL_UP,
	SHOP_OPENED,
	POPUP_OPENED,
	WORKER_HIRED,
	WORKER_UPGRADED,
	WORKER_ASSIGNED,
	WORKER_REMOVED,
	PASSIVE_COLLECTED,
	OFFLINE_EARNINGS,
	CUSTOMER_ENTER,
	CUSTOMER_LEAVE,
	WORKER_NOTIFICATION,
	DECOR_SCREEN_OPENED,
	DECOR_PURCHASED,
	DECOR_PLACED,
	DECOR_REMOVED,
	DECOR_REPLACED,
	SHOP_LEVEL_UPGRADED,
	SLOT_UNLOCKED,
	APPEAL_TIER_UP,
	EDIT_MODE_OPENED,
	EDIT_MODE_SAVED,
}

var enabled: bool = true
var music_enabled: bool = true
var sfx_volume: float = 0.9
var music_volume: float = 0.8
var _players: Dictionary = {}
var _music_player: AudioStreamPlayer


func _ready() -> void:
	for sfx in Sfx.values():
		var player := AudioStreamPlayer.new()
		player.name = "Sfx_%s" % str(sfx)
		add_child(player)
		_players[sfx] = player
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	var db := linear_to_db(maxf(sfx_volume, 0.0001))
	for player in _players.values():
		(player as AudioStreamPlayer).volume_db = db if sfx_volume > 0.0 else -80.0


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	if _music_player:
		_music_player.volume_db = linear_to_db(maxf(music_volume, 0.0001)) if music_volume > 0.0 else -80.0


func set_music_enabled(value: bool) -> void:
	music_enabled = value
	if _music_player and not music_enabled:
		_music_player.stop()


func play(sfx: Sfx) -> void:
	if not enabled:
		return
	var player: AudioStreamPlayer = _players.get(sfx)
	if player and player.stream:
		player.play()


func play_button() -> void:
	play(Sfx.BUTTON)


func play_popup() -> void:
	play(Sfx.POPUP_OPENED)
