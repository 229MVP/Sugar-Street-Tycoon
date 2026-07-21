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
}

var enabled: bool = true
var _players: Dictionary = {}


func _ready() -> void:
	for sfx in Sfx.values():
		var player := AudioStreamPlayer.new()
		player.name = "Sfx_%s" % str(sfx)
		add_child(player)
		_players[sfx] = player


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
