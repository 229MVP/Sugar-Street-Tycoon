extends Control
## Title screen: Sugar Street Tycoon — Match & Build.
## Continue → Shop Hub | New Game → reset starter save → Shop Hub.

@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton
@onready var subtitle_label: Label = %SubtitleLabel
@onready var version_label: Label = %VersionLabel
@onready var confirm_host: Control = %ConfirmHost

var _confirm: ConfirmPopup


func _ready() -> void:
	_confirm = ConfirmPopup.new()
	confirm_host.add_child(_confirm)

	subtitle_label.text = "Match & Build"
	version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

	# Continue always available — loads current/default save into the Shop Hub.
	continue_button.disabled = false
	continue_button.pressed.connect(_on_continue)
	new_game_button.pressed.connect(_on_new_game)
	settings_button.pressed.connect(_on_settings)
	exit_button.pressed.connect(_on_exit)
	exit_button.visible = OS.has_feature("pc") or OS.get_name() in ["Windows", "Linux", "macOS"]

	AudioManager.play(AudioManager.Sfx.SHOP_OPENED)


func _on_continue() -> void:
	AudioManager.play_button()
	if GameState.has_save():
		GameState.continue_game()
	SceneRouter.go_shop()


func _on_new_game() -> void:
	AudioManager.play_button()
	if GameState.has_save():
		_confirm.show_confirm(
			"Start New Game?",
			"This will reset your starter save data (level, coins, orders). Are you sure?",
			"New Game",
			"Cancel"
		)
		if not _confirm.confirmed.is_connected(_do_new_game):
			_confirm.confirmed.connect(_do_new_game, CONNECT_ONE_SHOT)
	else:
		_do_new_game()


func _do_new_game() -> void:
	GameState.new_game()
	SceneRouter.go_shop()


func _on_settings() -> void:
	AudioManager.play_button()
	_confirm.show_confirm(
		"Settings",
		"Music and SFX toggles will expand here. Audio is handled by AudioManager.",
		"OK",
		"Close"
	)


func _on_exit() -> void:
	AudioManager.play_button()
	GameState.save_now()
	get_tree().quit()
