extends Node2D

const SESSION_TIME: float = 10.0
const BONUS_COINS: int = 100

@onready var world_root: Node2D = $WorldRoot
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/GameCamera
@onready var upgrade_panel: Control = $UpgradePanel/Control
@onready var weapon_shop: Control = $WeaponShop/Control
@onready var back_to_menu_btn: Button = $BackToMenuUI/BackToMenuBtn
@onready var confirm_dialog: Control = $BackToMenuUI/ConfirmDialog
@onready var confirm_btn: Button = $BackToMenuUI/ConfirmDialog/DialogPanel/ConfirmBtn
@onready var cancel_btn: Button = $BackToMenuUI/ConfirmDialog/DialogPanel/CancelBtn
@onready var session_end_overlay: Control = $BackToMenuUI/SessionEndOverlay
@onready var touch_button: Button = $BackToMenuUI/SessionEndOverlay/TouchButton
@onready var session_earnings_label: Label = $BackToMenuUI/SessionEndOverlay/SessionEarningsLabel
@onready var bonus_label: Label = $BackToMenuUI/SessionEndOverlay/BonusLabel
@onready var tap_to_return_label: Label = $BackToMenuUI/SessionEndOverlay/TapToReturnLabel
@onready var timer_label: Label = $HUD/TimerLabel

var session_time_remaining: float = SESSION_TIME
var session_ended: bool = false

func _ready() -> void:
	SessionManager.start_session()
	camera.add_to_group("camera")

	upgrade_panel.set_toggle_button_visible(false)
	weapon_shop.set_toggle_button_visible(false)

	back_to_menu_btn.pressed.connect(_on_back_to_menu_pressed)
	confirm_btn.pressed.connect(_on_confirm_back_to_menu)
	cancel_btn.pressed.connect(_on_cancel_back_to_menu)

	touch_button.pressed.connect(_on_session_end_touch)

	update_timer_display()

func _process(delta: float) -> void:
	if session_ended:
		return

	session_time_remaining -= delta
	if session_time_remaining <= 0:
		session_time_remaining = 0
		end_session()

	update_timer_display()

func update_timer_display() -> void:
	var seconds = int(ceil(session_time_remaining))
	timer_label.text = str(seconds)

	if seconds <= 10:
		timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 1, 1))

func end_session() -> void:
	session_ended = true
	get_tree().paused = true
	back_to_menu_btn.visible = false

	var earnings = GameManager.session_money

	GameManager.add_money(BONUS_COINS)

	await animate_coins_disappear()

	show_session_end_overlay(earnings)

func animate_coins_disappear() -> void:
	var coins = get_tree().get_nodes_in_group("coins")

	if coins.is_empty():
		await get_tree().create_timer(0.3).timeout
		return

	coins.shuffle()
	var total_duration = min(2.0, coins.size() * 0.05)
	var pop_interval = total_duration / coins.size()

	for i in coins.size():
		var coin = coins[i]
		if not is_instance_valid(coin):
			continue

		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(i * pop_interval)
		tween.tween_property(coin, "scale", Vector2(1.8, 1.8), 0.08)
		tween.tween_property(coin, "scale", Vector2(0, 0), 0.12)
		tween.tween_callback(coin.queue_free)

	await get_tree().create_timer(total_duration + 0.3).timeout

func show_session_end_overlay(earnings: int) -> void:
	session_earnings_label.modulate = Color(1, 1, 1, 0)
	bonus_label.modulate = Color(1, 1, 1, 0)
	tap_to_return_label.modulate = Color(1, 1, 1, 0)
	touch_button.disabled = true

	session_earnings_label.text = "획득: $%d" % earnings
	bonus_label.text = "세션 완료 보너스 +$%d" % BONUS_COINS

	session_end_overlay.visible = true

	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(session_earnings_label, "modulate:a", 1.0, 0.4)

	tween.tween_interval(0.6)
	tween.tween_property(bonus_label, "modulate:a", 1.0, 0.5)

	tween.tween_interval(0.3)
	tween.tween_property(tap_to_return_label, "modulate:a", 1.0, 0.3)
	tween.tween_callback(func():
		touch_button.disabled = false
		animate_tap_label()
	)

func animate_tap_label() -> void:
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_loops()
	tween.tween_property(tap_to_return_label, "modulate:a", 0.3, 0.7)
	tween.tween_property(tap_to_return_label, "modulate:a", 1.0, 0.7)

func _on_session_end_touch() -> void:
	get_tree().paused = false
	SessionManager.quit_to_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if session_ended:
			_on_session_end_touch()
		elif confirm_dialog.visible:
			_on_cancel_back_to_menu()
		else:
			_on_back_to_menu_pressed()

func _on_back_to_menu_pressed() -> void:
	confirm_dialog.visible = true
	get_tree().paused = true

func _on_confirm_back_to_menu() -> void:
	get_tree().paused = false
	SessionManager.quit_to_menu()

func _on_cancel_back_to_menu() -> void:
	confirm_dialog.visible = false
	get_tree().paused = false
