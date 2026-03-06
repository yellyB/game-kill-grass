extends Node2D

const MonsterScene = preload("res://scenes/world/monster.tscn")
const ChestScene = preload("res://scenes/world/chest.tscn")

const FURY_BOSS_TYPES: Dictionary = {
  0: {
    "type": "slime",
    "sprite_path": "res://resources/images/monster/slime/",
    "max_health": 60,
    "wander_speed": 50,
    "sprite_scale": 0.96,
    "effect_scene": "res://scenes/effects/lightning_effect.tscn",
    "penalty_min": 0,
    "penalty_max": 0,
    "spawn_weight": 1,
    "collision_shape": "res://resources/collision/slime.tres",
    "collision_base_scale": 0.24,
    "collision_rotation": PI / 2.0,
  },
  1: {
    "type": "boar",
    "sprite_path": "res://resources/images/monster/boar/",
    "max_health": 140,
    "wander_speed": 60,
    "sprite_scale": 0.84,
    "effect_scene": "res://scenes/effects/dust_cloud_effect.tscn",
    "penalty_min": 0,
    "penalty_max": 0,
    "spawn_weight": 1,
    "collision_shape": "res://resources/collision/boar.tres",
    "collision_base_scale": 0.36,
    "collision_rotation": PI / 2.0,
  },
  2: {
    "type": "knight",
    "sprite_path": "res://resources/images/monster/knight/",
    "max_health": 350,
    "wander_speed": 48,
    "sprite_scale": 0.84,
    "effect_scene": "res://scenes/effects/spark_effect.tscn",
    "penalty_min": 0,
    "penalty_max": 0,
    "spawn_weight": 1,
    "collision_shape": "res://resources/collision/knight.tres",
    "collision_base_scale": 0.36,
  },
  3: {
    "type": "mage",
    "sprite_path": "res://resources/images/monster/mage/",
    "max_health": 700,
    "wander_speed": 54,
    "sprite_scale": 0.96,
    "effect_scene": "res://scenes/effects/spore_effect.tscn",
    "penalty_min": 0,
    "penalty_max": 0,
    "spawn_weight": 1,
    "collision_shape": "res://resources/collision/mage.tres",
    "collision_base_scale": 0.24,
  },
  4: {
    "type": "deer",
    "sprite_path": "res://resources/images/monster/deer/",
    "max_health": 1200,
    "wander_speed": 72,
    "sprite_scale": 0.84,
    "effect_scene": "res://scenes/effects/crystal_shimmer_effect.tscn",
    "penalty_min": 0,
    "penalty_max": 0,
    "spawn_weight": 1,
    "collision_shape": "res://resources/collision/deer.tres",
    "collision_base_scale": 0.36,
  },
  5: {
    "type": "golem",
    "sprite_path": "res://resources/images/monster/golem/",
    "max_health": 2000,
    "wander_speed": 40,
    "sprite_scale": 0.96,
    "effect_scene": "res://scenes/effects/rock_debris_effect.tscn",
    "penalty_min": 0,
    "penalty_max": 0,
    "spawn_weight": 1,
    "collision_shape": "res://resources/collision/golem.tres",
    "collision_base_scale": 0.48,
  },
  6: {
    "type": "dragon",
    "sprite_path": "res://resources/images/monster/dragon/",
    "max_health": 3500,
    "wander_speed": 80,
    "sprite_scale": 0.96,
    "effect_scene": "res://scenes/effects/fire_wisp_effect.tscn",
    "penalty_min": 0,
    "penalty_max": 0,
    "spawn_weight": 1,
    "collision_shape": "res://resources/collision/dragon.tres",
    "collision_base_scale": 0.48,
  },
}

const CHEST_CHUNK_CHANCE: float = 0.0
var fury_boss_alive: bool = false

var player: Node2D = null
var grass_spawner: Node2D = null

func _ready() -> void:
  grass_spawner = get_tree().get_first_node_in_group("grass_spawner")
  if not grass_spawner:
    grass_spawner = get_parent().get_node_or_null("GrassSpawner")
  if grass_spawner and grass_spawner.has_signal("new_chunk_entered"):
    grass_spawner.new_chunk_entered.connect(_on_new_chunk_entered)
  call_deferred("_find_player")
  GameManager.fury_boss_requested.connect(_on_fury_boss_requested)

func _find_player() -> void:
  player = get_tree().get_first_node_in_group("player")

func _on_new_chunk_entered(chunk_coord: Vector2i) -> void:
  var chest_chance = GameManager.get_chest_spawn_chance()
  if chest_chance <= 0.0 or randf() > chest_chance:
    return
  _spawn_chest_at_chunk(chunk_coord)

func _spawn_chest_at_chunk(chunk_coord: Vector2i) -> void:
  var chunk_size = 400.0
  if grass_spawner:
    chunk_size = grass_spawner.chunk_size
  var chunk_origin = Vector2(chunk_coord.x * chunk_size, chunk_coord.y * chunk_size)
  var pos = chunk_origin + Vector2(randf() * chunk_size, randf() * chunk_size)

  var chest = ChestScene.instantiate()
  chest.position = pos
  get_parent().add_child(chest)

const BOSS_CLEAR_REWARDS: Array = [30, 300, 1000, 3000, 10000, 30000, 60000]

const LAST_WORLD_POTION: String = "졸음 약"

func _is_world_cleared(world: int) -> bool:
  return GameManager.is_world_cleared(world)

func _on_fury_boss_requested() -> void:
  if fury_boss_alive:
    return
  var world = GameManager.selected_world
  if not FURY_BOSS_TYPES.has(world):
    return
  var config = FURY_BOSS_TYPES[world].duplicate()
  config["is_fury_boss"] = true
  var is_last = world + 1 >= GameManager.WORLD_UNLOCK_COSTS.size()
  if _is_world_cleared(world):
    var reward = BOSS_CLEAR_REWARDS[world] if world < BOSS_CLEAR_REWARDS.size() else 0
    config["boss_reward"] = reward
    var strength = GameManager.get_world_strength_level(world)
    if strength > 0:
      config["boss_gems"] = strength
  elif is_last:
    config["boss_potion"] = LAST_WORLD_POTION
  elif world + 1 < GameManager.WORLD_UNLOCK_COSTS.size():
    config["key_world_index"] = world + 1
  var monster = MonsterScene.instantiate()
  monster.setup(config)
  var player_local = get_parent().to_local(player.global_position) if player else Vector2.ZERO
  var viewport_size = get_viewport().get_visible_rect().size
  var boss_y_offset = -viewport_size.y * 0.3
  monster.position = player_local + Vector2(0, boss_y_offset)
  monster.is_boss_entering = true
  monster.visible = false
  fury_boss_alive = true
  GameManager.fury_boss_alive = true
  monster.tree_exited.connect(func():
    fury_boss_alive = false
    GameManager.fury_boss_alive = false
  )
  get_parent().add_child(monster)
  _play_boss_entrance(monster)

func _play_boss_entrance(monster: Node2D) -> void:
  get_tree().paused = true
  monster.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
  await GameManager.fury_gauge_dismissed
  monster.visible = true
  monster.play_boss_entrance()
  await get_tree().create_timer(0.6).timeout
  await get_tree().create_timer(1.0).timeout
  monster.is_boss_entering = false
  monster.process_mode = Node.PROCESS_MODE_INHERIT
  get_tree().paused = false
