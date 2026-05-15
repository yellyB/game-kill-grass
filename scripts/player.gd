extends Node2D

signal input_direction_changed(direction: Vector2)
signal player_hit

const FloatingTextScene = preload("res://scenes/ui/floating_text.tscn")
const SFX_GRASS = preload("res://resources/sounds/effect/grass_swoosh.wav")
const SFX_COIN = preload("res://resources/sounds/effect/pick_coin.wav")

@export var move_speed: float = 300.0

var is_hit_debuffed: bool = false
var is_invincible: bool = false
var hit_debuff_timer: float = 0.0
var invincible_timer: float = 0.0
const HIT_DEBUFF_DURATION: float = 1.5
const INVINCIBLE_DURATION: float = 3.0
var _hit_overlay_canvas: CanvasLayer = null

@onready var player_visual: Node2D = $PlayerVisual
@onready var attack_timer: Timer = $AttackTimer
@onready var weapon_pivot: Node2D = $WeaponPivot

var blade: Node2D = null

const SPRITES = {
  "idle": preload("res://resources/images/player/idle.png"),
  "walk_a": preload("res://resources/images/player/walk_a.png"),
  "walk_b": preload("res://resources/images/player/walk_b.png"),
  "attack1": preload("res://resources/images/player/attack1.png"),
  "attack2": preload("res://resources/images/player/attack2.png"),
  "hit": preload("res://resources/images/player/hit.png"),
  "idle_back": preload("res://resources/images/player/idle_back.png"),
  "walk_a_back": preload("res://resources/images/player/walk_a_back.png"),
  "walk_b_back": preload("res://resources/images/player/walk_b_back.png"),
  "attack1_back": preload("res://resources/images/player/attack1_back.png"),
  "attack2_back": preload("res://resources/images/player/attack2_back.png"),
  "hit_back": preload("res://resources/images/player/hit_back.png"),
  "idle_flip": preload("res://resources/images/player/idle_flip.png"),
  "walk_a_flip": preload("res://resources/images/player/walk_a_flip.png"),
  "walk_b_flip": preload("res://resources/images/player/walk_b_flip.png"),
  "attack1_flip": preload("res://resources/images/player/attack1_flip.png"),
  "attack2_flip": preload("res://resources/images/player/attack2_flip.png"),
  "hit_flip": preload("res://resources/images/player/hit_flip.png"),
  "idle_back_flip": preload("res://resources/images/player/idle_back_flip.png"),
  "walk_a_back_flip": preload("res://resources/images/player/walk_a_back_flip.png"),
  "walk_b_back_flip": preload("res://resources/images/player/walk_b_back_flip.png"),
  "attack1_back_flip": preload("res://resources/images/player/attack1_back_flip.png"),
  "attack2_back_flip": preload("res://resources/images/player/attack2_back_flip.png"),
  "hit_back_flip": preload("res://resources/images/player/hit_back_flip.png"),
}
const WALK_FRAMES = ["idle", "walk_a", "idle", "walk_b"]
const WALK_FRAME_DURATION = 0.15
var sprite: Sprite2D = null
var current_anim_state: String = "idle"
var facing_back: bool = false
var facing_left: bool = false

var input_direction: Vector2 = Vector2.ZERO
var can_attack: bool = true
var target_weapon_angle: float = 0.0
var is_swinging: bool = false
var walk_time: float = 0.0
var weapon_base_scale: Vector2 = Vector2.ONE
var grass_spawner: Node2D = null
var attack_radius: float = 80.0
var attack_area: Area2D = null
var attack_shape: CollisionShape2D = null
var body_area: Area2D = null

const BATCH_TIMEOUT: float = 0.3
var batch_total: int = 0
var batch_timer: float = 0.0
var batch_active: bool = false
var batch_floating_text: Node2D = null
var sfx_grass_player: AudioStreamPlayer
var sfx_coin_player: AudioStreamPlayer

func _ready() -> void:
  sfx_grass_player = AudioStreamPlayer.new()
  sfx_grass_player.stream = SFX_GRASS
  sfx_grass_player.volume_db = -5.0
  add_child(sfx_grass_player)
  sfx_coin_player = AudioStreamPlayer.new()
  sfx_coin_player.stream = SFX_COIN
  sfx_coin_player.volume_db = -8.0
  add_child(sfx_coin_player)
  sprite = Sprite2D.new()
  sprite.texture = SPRITES["idle"]
  sprite.scale = Vector2(0.36, 0.36)
  player_visual.add_child(sprite)
  attack_area = Area2D.new()
  attack_area.collision_layer = 0
  attack_area.collision_mask = 8
  attack_shape = CollisionShape2D.new()
  var shape = CircleShape2D.new()
  shape.radius = attack_radius
  attack_shape.shape = shape
  attack_area.add_child(attack_shape)
  add_child(attack_area)
  body_area = Area2D.new()
  body_area.collision_layer = 0
  body_area.collision_mask = 8
  var body_shape = CollisionShape2D.new()
  var body_circle = CircleShape2D.new()
  body_circle.radius = 40.0
  body_shape.shape = body_circle
  body_area.add_child(body_shape)
  add_child(body_area)
  attack_timer.timeout.connect(_on_attack_timer_timeout)
  update_attack_range()
  create_weapon_visual()
  set_process(false)
  player_visual.visible = false
  weapon_pivot.visible = false
  await get_tree().process_frame
  player_visual.visible = true
  weapon_pivot.visible = true
  _play_drop_animation()
  GameManager.powerup_acquired.connect(_on_powerup_acquired)
  GameManager.timed_buff_started.connect(_on_timed_buff_changed)
  GameManager.timed_buff_ended.connect(_on_timed_buff_ended)
  WeaponManager.weapon_changed.connect(_on_weapon_changed)
  queue_redraw()
  call_deferred("find_grass_spawner")

func find_grass_spawner() -> void:
  grass_spawner = get_tree().get_first_node_in_group("grass_spawner")
  if not grass_spawner:
    var world_root = get_parent()
    if world_root:
      grass_spawner = world_root.get_node_or_null("GrassSpawner")

func _process(delta: float) -> void:
  _check_monster_collision()

  if is_hit_debuffed:
    hit_debuff_timer -= delta
    if hit_debuff_timer <= 0:
      is_hit_debuffed = false
      GameManager.hit_penalty_active = false
      _remove_hit_overlay()

  if is_invincible:
    invincible_timer -= delta
    if invincible_timer <= 0:
      is_invincible = false

  input_direction = get_input_direction()
  input_direction_changed.emit(input_direction)

  if input_direction != Vector2.ZERO:
    update_sprite_direction()
    update_weapon_direction(delta)
    update_walk_animation(delta)
  else:
    reset_walk_animation(delta)

  try_attack()

  if batch_active:
    batch_timer -= delta
    if batch_timer <= 0:
      _finish_batch()

func get_input_direction() -> Vector2:
  var direction = Vector2.ZERO
  direction.x = Input.get_axis("move_left", "move_right")
  direction.y = Input.get_axis("move_up", "move_down")
  if direction != Vector2.ZERO:
    return direction.normalized()

  return touch_direction

func update_sprite_direction() -> void:
  if input_direction.x < 0:
    facing_left = true
  elif input_direction.x > 0:
    facing_left = false

func update_walk_animation(delta: float) -> void:
  if input_direction.y < 0:
    facing_back = true
  else:
    facing_back = false
  if current_anim_state == "attack" or current_anim_state == "hit":
    return
  walk_time += delta
  var frame_index = int(walk_time / WALK_FRAME_DURATION) % 4
  _set_sprite(WALK_FRAMES[frame_index])

func reset_walk_animation(_delta: float) -> void:
  facing_back = false
  walk_time = 0.0
  if current_anim_state == "attack" or current_anim_state == "hit":
    return
  _set_sprite("idle")

func update_weapon_direction(delta: float) -> void:
  if is_swinging:
    return
  target_weapon_angle = input_direction.angle() + PI / 2
  weapon_pivot.rotation = lerp_angle(weapon_pivot.rotation, target_weapon_angle, delta * 15.0)

func try_attack() -> void:
  if not can_attack:
    return
  if not grass_spawner:
    return

  var attack_center = global_position

  if not _has_targets_in_range(attack_center, attack_radius):
    return

  can_attack = false
  var base_interval = GameManager.get_attack_interval()
  var speed_mult = GameManager.get_session_attack_speed_mult()
  var wait = base_interval / speed_mult
  attack_timer.wait_time = wait
  attack_timer.start()

  _attack_monsters_in_area(attack_center, attack_radius)

  var local_attack_center = attack_center - grass_spawner.global_position
  var result = grass_spawner.attack_grass_in_area(local_attack_center, attack_radius)

  if result.fury > 0:
    GameManager.add_fury(result.fury)

  if result.hit and GameManager.sfx_enabled:
    sfx_grass_player.play()

  if result.crit:
    _spawn_crit_effect(input_direction)

  var target_pos = attack_center + input_direction * 30
  swing_weapon(target_pos)

  _spawn_weapon_effect(input_direction)

func _has_targets_in_range(center: Vector2, radius: float) -> bool:
  if attack_area.get_overlapping_areas().size() > 0:
    return true
  var local_center = center - grass_spawner.global_position
  var min_chunk = grass_spawner.get_chunk_coord(local_center - Vector2(radius, radius))
  var max_chunk = grass_spawner.get_chunk_coord(local_center + Vector2(radius, radius))
  var radius_sq = radius * radius
  for cx in range(min_chunk.x, max_chunk.x + 1):
    for cy in range(min_chunk.y, max_chunk.y + 1):
      var chunk_coord = Vector2i(cx, cy)
      if not grass_spawner.loaded_chunks.has(chunk_coord):
        continue
      for grid_pos in grass_spawner.loaded_chunks[chunk_coord]:
        if not grass_spawner.grass_data.has(grid_pos):
          continue
        var data = grass_spawner.grass_data[grid_pos]
        if data.cut:
          continue
        var world_pos = Vector2(grid_pos.x, grid_pos.y)
        if local_center.distance_squared_to(world_pos) <= radius_sq:
          return true
  return false

func swing_weapon(target_pos: Vector2) -> void:
  is_swinging = true

  current_anim_state = "attack"
  _set_sprite("attack2")
  var sprite_tween = create_tween()
  sprite_tween.tween_callback(func():
    if current_anim_state == "attack":
      _set_sprite("attack1")
  ).set_delay(0.05)
  sprite_tween.tween_callback(func():
    if current_anim_state == "attack":
      current_anim_state = "idle"
      _set_sprite("idle")
  ).set_delay(0.1)

  var direction_to_target = (target_pos - global_position).normalized()
  var target_angle = direction_to_target.angle() + PI / 2

  var swing_start = target_angle - PI / 3
  var swing_end = target_angle + PI / 3

  weapon_pivot.rotation = swing_start

  var tween = create_tween()
  tween.set_ease(Tween.EASE_OUT)
  tween.set_trans(Tween.TRANS_QUART)
  tween.tween_property(weapon_pivot, "rotation", swing_end, 0.1)

  if blade:
    blade.scale = weapon_base_scale * 1.3
    tween.parallel().tween_property(blade, "scale", weapon_base_scale, 0.1)

  await tween.finished
  is_swinging = false

func update_attack_range() -> void:
  var base_range = GameManager.get_attack_range()
  var session_mult = GameManager.get_session_attack_range_mult()
  attack_radius = base_range * session_mult
  if attack_shape and attack_shape.shape:
    (attack_shape.shape as CircleShape2D).radius = attack_radius
  _update_weapon_scale()

func create_weapon_visual() -> void:
  if blade:
    blade.queue_free()
    blade = null

  blade = create_weapon_sprite()
  if blade:
    weapon_pivot.add_child(blade)

func create_weapon_sprite() -> Sprite2D:
  var sprite = Sprite2D.new()
  var texture = WeaponManager.get_weapon_texture()
  if texture == null:
    push_warning("Weapon texture not loaded!")
    return sprite
  sprite.texture = texture
  var target_size = attack_radius
  var max_dimension = max(texture.get_width(), texture.get_height())
  var scale_factor = target_size / max_dimension
  weapon_base_scale = Vector2(scale_factor, scale_factor)
  sprite.scale = weapon_base_scale
  sprite.offset = Vector2(0, -texture.get_height() / 2.0)
  return sprite


func _update_weapon_scale() -> void:
  if not blade or not blade.texture:
    return
  var target_size = attack_radius
  var max_dimension = max(blade.texture.get_width(), blade.texture.get_height())
  var scale_factor = target_size / max_dimension
  weapon_base_scale = Vector2(scale_factor, scale_factor)
  if not is_swinging:
    blade.scale = weapon_base_scale

func _attack_monsters_in_area(_center: Vector2, _radius: float) -> void:
  var base_damage = WeaponManager.get_weapon_damage()
  var monster_mult = GameManager.get_monster_damage_mult()
  var is_crit = randf() < GameManager.get_crit_chance()
  var damage = roundi(base_damage * monster_mult)
  if is_crit:
    damage = roundi(damage * GameManager.get_crit_damage_mult())
  for area in attack_area.get_overlapping_areas():
    var target = area.get_parent()
    if is_instance_valid(target) and target.has_method("take_damage"):
      target.take_damage(damage, global_position)

func _play_drop_animation() -> void:
  var start_offset = -800.0
  player_visual.position.y = start_offset
  weapon_pivot.position.y = start_offset
  var shadow = Sprite2D.new()
  shadow.texture = PlaceholderTexture2D.new()
  shadow.texture.size = Vector2(60, 16)
  shadow.position = Vector2(0, 28)
  shadow.modulate = Color(0, 0, 0, 0.15)
  shadow.scale = Vector2(0.3, 0.3)
  add_child(shadow)
  var tween = create_tween()
  tween.set_parallel(true)
  tween.tween_property(player_visual, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
  tween.tween_property(weapon_pivot, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
  tween.tween_property(shadow, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  tween.tween_property(shadow, "modulate:a", 0.3, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  var shadow_tween = create_tween()
  shadow_tween.tween_property(shadow, "modulate:a", 0.0, 0.3).set_delay(0.7)
  shadow_tween.tween_callback(shadow.queue_free)
  shadow_tween.tween_callback(func(): set_process(true))

func _on_attack_timer_timeout() -> void:
  can_attack = true

func _on_powerup_acquired(type: String, _level: int) -> void:
  if type == "attack_range":
    update_attack_range()
  if type == "magnet_range":
    queue_redraw()

func _on_timed_buff_changed(_type: String, _duration: float) -> void:
  update_attack_range()
  queue_redraw()

func _on_timed_buff_ended(_type: String) -> void:
  update_attack_range()
  queue_redraw()

func _on_weapon_changed(_level: int) -> void:
  update_attack_range()
  create_weapon_visual()

func _on_magnet_range_changed() -> void:
  queue_redraw()

var touch_start_pos: Vector2 = Vector2.ZERO
var touch_direction: Vector2 = Vector2.ZERO
var is_touching: bool = false

func _unhandled_input(event: InputEvent) -> void:
  if event is InputEventScreenTouch:
    if event.pressed:
      is_touching = true
      touch_start_pos = event.position
      touch_direction = Vector2.ZERO
    else:
      is_touching = false
      touch_direction = Vector2.ZERO
  elif event is InputEventScreenDrag:
    if is_touching:
      var drag_vector = event.position - touch_start_pos
      if drag_vector.length() > 20:
        touch_direction = drag_vector.normalized()
      else:
        touch_direction = Vector2.ZERO

func accumulate_coin_text(value: int) -> void:
  if GameManager.sfx_enabled:
    sfx_coin_player.play()
  if batch_active and is_instance_valid(batch_floating_text):
    batch_total += value
    batch_timer = BATCH_TIMEOUT
    batch_floating_text.update_batch(batch_total)
  else:
    batch_total = value
    batch_timer = BATCH_TIMEOUT
    batch_active = true
    _spawn_batch_text()

func _spawn_batch_text() -> void:
  batch_floating_text = FloatingTextScene.instantiate()
  batch_floating_text.position = Vector2(0, -70)
  add_child(batch_floating_text)
  batch_floating_text.start_batch(batch_total)

func _finish_batch() -> void:
  batch_active = false
  if is_instance_valid(batch_floating_text):
    batch_floating_text.finish_batch()
  batch_floating_text = null
  batch_total = 0

func _check_monster_collision() -> void:
  if is_invincible:
    return
  for area in body_area.get_overlapping_areas():
    var monster = area.get_parent()
    if is_instance_valid(monster) and monster.is_in_group("monsters"):
      _on_monster_hit(monster)
      return

func _on_monster_hit(monster: Node2D) -> void:
  is_hit_debuffed = true
  is_invincible = true
  hit_debuff_timer = HIT_DEBUFF_DURATION
  invincible_timer = INVINCIBLE_DURATION
  GameManager.hit_penalty_active = true
  player_hit.emit()
  current_anim_state = "hit"
  _set_sprite("hit")
  var hit_tween = create_tween()
  hit_tween.tween_callback(func():
    if current_anim_state == "hit":
      current_anim_state = "idle"
      _set_sprite("idle")
  ).set_delay(0.3)
  _show_hit_overlay()

func _show_hit_overlay() -> void:
  _remove_hit_overlay()
  _hit_overlay_canvas = CanvasLayer.new()
  _hit_overlay_canvas.layer = 90
  get_tree().root.add_child(_hit_overlay_canvas)
  var overlay = ColorRect.new()
  overlay.color = Color(1, 0, 0, 0.15)
  overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
  overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _hit_overlay_canvas.add_child(overlay)

func _remove_hit_overlay() -> void:
  if is_instance_valid(_hit_overlay_canvas):
    _hit_overlay_canvas.queue_free()
    _hit_overlay_canvas = null

func _spawn_crit_effect(dir: Vector2) -> void:
  var effective_dir = dir if dir != Vector2.ZERO else Vector2.from_angle(weapon_pivot.rotation - PI / 2)
  var fx_offset = effective_dir * (attack_radius * 0.5)

  for i in 2:
    var ring = Line2D.new()
    ring.position = fx_offset
    ring.width = 3.0
    ring.default_color = Color(1.0, 0.9, 0.2, 0.9)
    var ring_radius = 20.0
    for j in range(17):
      var a = TAU / 16.0 * j
      ring.add_point(Vector2(cos(a), sin(a)) * ring_radius)
    add_child(ring)
    var tw = create_tween()
    var delay = i * 0.05
    tw.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.2).set_delay(delay)
    tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.2).set_delay(delay)
    tw.tween_callback(ring.queue_free)

  var label = Label.new()
  label.text = "CRIT!"
  label.add_theme_font_size_override("font_size", 36)
  label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
  label.add_theme_color_override("font_outline_color", Color(0.7, 0.25, 0.0))
  label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 0.6, 0.5))
  label.add_theme_constant_override("outline_size", 6)
  label.add_theme_constant_override("shadow_offset_x", 0)
  label.add_theme_constant_override("shadow_offset_y", 2)
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  label.position = Vector2(-40, -90)
  label.scale = Vector2(0.3, 0.3)
  label.pivot_offset = Vector2(40, 14)
  add_child(label)
  var tw_label = create_tween()
  tw_label.tween_property(label, "scale", Vector2(1.4, 1.4), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
  tw_label.tween_property(label, "scale", Vector2(1.0, 1.0), 0.08).set_ease(Tween.EASE_IN_OUT)
  var tw_float = create_tween().set_parallel(true)
  tw_float.tween_property(label, "position:y", -140.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
  tw_float.tween_property(label, "modulate:a", 0.0, 0.2).set_delay(0.35)
  tw_float.chain().tween_callback(label.queue_free)



func _spawn_weapon_effect(dir: Vector2) -> void:
  var level = WeaponManager.current_weapon_level
  var effective_dir = dir if dir != Vector2.ZERO else Vector2.from_angle(weapon_pivot.rotation - PI / 2)
  var fx_offset = effective_dir * (attack_radius * 0.5)
  match level:
    0: pass
    1: _fx_slash_arc(fx_offset, effective_dir)
    2: _fx_spin_circle(fx_offset)
    3: _fx_electric_flash(fx_offset)
    4: _fx_heat_glow(fx_offset)
    5: _fx_scratch_lines(fx_offset, effective_dir)
    6: _fx_chainsaw_blur(fx_offset, effective_dir)
    7: _fx_magic_orb(fx_offset, effective_dir)
    8: _fx_wind_beam(fx_offset, effective_dir)
    9: _fx_satellite_laser(fx_offset)

func _fx_slash_arc(pos: Vector2, dir: Vector2) -> void:
  var line = Line2D.new()
  line.position = pos
  line.width = 4.0
  line.default_color = Color(1, 1, 1, 0.8)
  var base_angle = dir.angle()
  var arc_radius = 40.0
  for i in range(9):
    var a = base_angle - PI / 6 + (PI / 3) * (float(i) / 8.0)
    line.add_point(Vector2(cos(a), sin(a)) * arc_radius)
  add_child(line)
  var tw = create_tween()
  tw.tween_property(line, "modulate:a", 0.0, 0.15)
  tw.tween_callback(line.queue_free)

func _fx_spin_circle(pos: Vector2) -> void:
  var line = Line2D.new()
  line.position = pos
  line.width = 3.0
  line.default_color = Color(0.8, 0.8, 0.85, 0.8)
  var radius = 35.0
  for i in range(17):
    var a = TAU / 16.0 * i
    line.add_point(Vector2(cos(a), sin(a)) * radius)
  add_child(line)
  var tw = create_tween()
  tw.tween_property(line, "rotation", TAU, 0.2)
  tw.parallel().tween_property(line, "modulate:a", 0.0, 0.2)
  tw.tween_callback(line.queue_free)

func _fx_electric_flash(pos: Vector2) -> void:
  var electric_color = Color(0.3, 0.6, 1.0, 0.9)
  for i in range(4):
    var line = Line2D.new()
    line.position = pos
    line.width = 2.0
    line.default_color = electric_color
    var angle = randf() * TAU
    var length = randf_range(30, 60)
    var p = Vector2.ZERO
    line.add_point(p)
    var segs = randi_range(3, 5)
    for j in range(segs):
      var step = length / segs
      p += Vector2(cos(angle), sin(angle)) * step
      p += Vector2(randf_range(-8, 8), randf_range(-8, 8))
      line.add_point(p)
    add_child(line)
    var tw = create_tween()
    tw.tween_property(line, "modulate:a", 0.0, 0.12)
    tw.tween_callback(line.queue_free)
  var flash = _create_circle_polygon(15.0, 12)
  flash.position = pos
  flash.color = Color(0.3, 0.6, 1.0, 0.6)
  add_child(flash)
  var tw2 = create_tween()
  tw2.tween_property(flash, "scale", Vector2(2.5, 2.5), 0.1)
  tw2.parallel().tween_property(flash, "modulate:a", 0.0, 0.1)
  tw2.tween_callback(flash.queue_free)

func _fx_heat_glow(pos: Vector2) -> void:
  var glow = _create_circle_polygon(30.0, 16)
  glow.position = pos
  glow.color = Color(1.0, 0.2, 0.1, 0.4)
  add_child(glow)
  var tw = create_tween()
  tw.tween_property(glow, "scale", Vector2(1.5, 1.5), 0.2)
  tw.parallel().tween_property(glow, "modulate:a", 0.0, 0.2)
  tw.tween_callback(glow.queue_free)
  var cam = get_viewport().get_camera_2d()
  if cam and cam.has_method("shake"):
    cam.shake(0.15)

func _fx_scratch_lines(pos: Vector2, dir: Vector2) -> void:
  var perp = Vector2(-dir.y, dir.x)
  for i in range(3):
    var line = Line2D.new()
    line.position = pos
    line.width = 3.0
    line.default_color = Color(1, 1, 1, 0.9)
    var base_angle = dir.angle() + PI / 4 + randf_range(-0.2, 0.2)
    var offset_perp = perp * (i - 1) * 12.0
    var start_p = offset_perp + Vector2(cos(base_angle), sin(base_angle)) * -25.0
    var end_p = offset_perp + Vector2(cos(base_angle), sin(base_angle)) * 25.0
    line.add_point(start_p)
    line.add_point(end_p)
    add_child(line)
    var tw = create_tween()
    tw.tween_property(line, "modulate:a", 0.0, 0.12)
    tw.tween_callback(line.queue_free)

func _fx_chainsaw_blur(pos: Vector2, dir: Vector2) -> void:
  var orange = Color(1.0, 0.6, 0.2, 0.7)
  var perp = Vector2(-dir.y, dir.x)
  for i in range(3):
    var line = Line2D.new()
    line.position = pos
    line.width = 4.0
    line.default_color = orange
    var p = perp * (i - 1) * 8.0
    line.add_point(p)
    line.add_point(p + dir * randf_range(40, 70))
    add_child(line)
    var tw = create_tween()
    tw.tween_property(line, "modulate:a", 0.0, 0.15)
    tw.tween_callback(line.queue_free)

func _fx_magic_orb(pos: Vector2, dir: Vector2) -> void:
  var purple = Color(0.6, 0.2, 1.0, 0.8)
  var container = Node2D.new()
  container.position = pos
  add_child(container)
  var orb = _create_circle_polygon(10.0, 10)
  orb.color = purple
  container.add_child(orb)
  for i in range(3):
    var trail = _create_circle_polygon(7.0 - i * 2.0, 8)
    trail.color = Color(0.6, 0.2, 1.0, 0.5 - i * 0.15)
    trail.position = -dir * (i + 1) * 15.0
    container.add_child(trail)
  var tw = create_tween()
  tw.tween_property(container, "position", pos + dir * 150.0, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
  tw.parallel().tween_property(container, "modulate:a", 0.0, 0.2).set_delay(0.1)
  tw.tween_callback(container.queue_free)

func _fx_wind_beam(pos: Vector2, dir: Vector2) -> void:
  var beam = Line2D.new()
  beam.width = attack_radius * 2.0
  beam.end_cap_mode = Line2D.LINE_CAP_ROUND
  beam.add_point(Vector2.ZERO)
  beam.add_point(pos + dir * attack_radius)
  var grad = Gradient.new()
  grad.set_color(0, Color(0.4, 0.9, 1.0, 0.35))
  grad.set_color(1, Color(0.4, 0.9, 1.0, 0.0))
  beam.gradient = grad
  add_child(beam)
  var tw = create_tween()
  tw.tween_property(beam, "modulate:a", 0.0, 0.2)
  tw.tween_callback(beam.queue_free)

func _fx_satellite_laser(pos: Vector2) -> void:
  var beam = Line2D.new()
  beam.position = pos
  beam.width = attack_radius * 2.0
  beam.end_cap_mode = Line2D.LINE_CAP_ROUND
  beam.add_point(Vector2(0, -500))
  beam.add_point(Vector2.ZERO)
  var grad = Gradient.new()
  grad.set_color(0, Color(1.0, 0.15, 0.1, 0.0))
  grad.set_color(1, Color(1.0, 0.15, 0.1, 0.35))
  beam.gradient = grad
  add_child(beam)

  var tw = create_tween()
  tw.tween_property(beam, "modulate:a", 0.0, 0.2)
  tw.tween_callback(beam.queue_free)

func _create_circle_polygon(radius: float, segments: int) -> Polygon2D:
  var poly = Polygon2D.new()
  var points: PackedVector2Array = []
  for i in range(segments):
    var a = TAU / segments * i
    points.append(Vector2(cos(a), sin(a)) * radius)
  poly.polygon = points
  return poly

func _get_sprite_key(base: String) -> String:
  var key = base
  if facing_back:
    key += "_back"
  if facing_left:
    key += "_flip"
  return key

func _set_sprite(base: String) -> void:
  var key = _get_sprite_key(base)
  if SPRITES.has(key):
    sprite.texture = SPRITES[key]

func _draw() -> void:
  if not GameManager.debug_mode:
    return

  var body_radius = 40.0
  draw_arc(Vector2.ZERO, body_radius, 0, TAU, 32, Color(1.0, 1.0, 0.0, 0.5), 2.0)

  var magnet_range = GameManager.get_magnet_range()
  draw_arc(Vector2.ZERO, magnet_range, 0, TAU, 32, Color(0.0, 1.0, 1.0, 0.5), 2.0)

  var attack_offset = Vector2.ZERO
  if input_direction != Vector2.ZERO:
    attack_offset = input_direction * (attack_radius * 0.5)
  draw_arc(attack_offset, attack_radius, 0, TAU, 32, Color(1.0, 0.3, 0.3, 0.5), 2.0)
