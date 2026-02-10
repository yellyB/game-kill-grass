shader_type canvas_item;

uniform float sway_speed : hint_range(0.5, 5.0) = 2.0;
uniform float sway_amount : hint_range(0.0, 0.2) = 0.08;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	vec2 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;

	float phase = world_pos.x * 0.02 + world_pos.y * 0.01;

	float height_factor = clamp(-VERTEX.y / 50.0, 0.0, 1.0);

	float sway = sin(TIME * sway_speed + phase) * sway_amount;
	sway += sin(TIME * sway_speed * 1.7 + phase * 1.3) * sway_amount * 0.5;
	sway *= wind_strength;

	VERTEX.x += sway * height_factor * 50.0;
}

void fragment() {
	COLOR.a = 1.0;
}
