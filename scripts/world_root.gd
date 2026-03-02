extends Node2D

@export var move_speed: float = 300.0

var player: CharacterBody2D = null
var background: ColorRect = null

const WORLD_BG_COLORS: Array = [
	Color(0.2, 0.4, 0.2, 1),
	Color(0.4, 0.35, 0.2, 1),
	Color(0.3, 0.35, 0.45, 1),
	Color(0.15, 0.18, 0.35, 1),
	Color(0.15, 0.3, 0.4, 1),
	Color(0.3, 0.3, 0.2, 1),
	Color(0.3, 0.18, 0.15, 1),
]

func _ready() -> void:
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	background = $Background
	if background:
		var world = GameManager.selected_world
		if world < WORLD_BG_COLORS.size():
			background.color = WORLD_BG_COLORS[world]
	if player:
		player.input_direction_changed.connect(_on_player_input_changed)

var current_direction: Vector2 = Vector2.ZERO

func _on_player_input_changed(direction: Vector2) -> void:
	current_direction = direction

func _process(delta: float) -> void:
	if current_direction != Vector2.ZERO:
		var effective_speed = move_speed * GameManager.get_session_move_speed_mult()
		position -= current_direction * effective_speed * delta

	if background:
		background.global_position = Vector2(-3000, -3000)
