extends Node2D

@onready var amount_label: Label = $AmountLabel

var float_speed: float = 80.0
var fade_duration: float = 1.0
var spread_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	animate()

func _process(delta: float) -> void:
	position.y -= float_speed * delta
	position += spread_offset * delta

func setup(amount: int) -> void:
	if amount_label:
		amount_label.text = "+%d" % amount
		if amount >= 10:
			amount_label.modulate = Color(1, 0.85, 0.0)
		elif amount >= 5:
			amount_label.modulate = Color(0.75, 0.75, 0.85)
		else:
			amount_label.modulate = Color(1, 0.9, 0.3)

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
