extends Node2D

@onready var base_label: Label = $BaseLabel
@onready var combo_label: Label = $ComboLabel

var float_speed: float = 80.0
var fade_duration: float = 1.0
var spread_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	animate()

func _process(delta: float) -> void:
	position.y -= float_speed * delta
	position += spread_offset * delta

func setup(base_amount: int, combo_bonus: int) -> void:
	if base_label:
		base_label.text = "+%d" % base_amount
		base_label.modulate = Color(1, 0.9, 0.3)

	if combo_label:
		if combo_bonus > 0:
			combo_label.text = "+%d" % combo_bonus
			combo_label.modulate = Color(0.3, 1, 0.5)
			combo_label.visible = true
		else:
			combo_label.visible = false

func animate() -> void:
	scale = Vector2(0.5, 0.5)

	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_ease(Tween.EASE_OUT)

	await tween.finished

	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	tween2.tween_property(self, "modulate:a", 0.0, fade_duration).set_delay(0.3)

	await tween2.finished
	queue_free()
