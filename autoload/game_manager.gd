extends Node

var money: int = 0

var upgrade_grass_density: int = 0
var upgrade_magnet_range: int = 0
var upgrade_grass_quality: int = 0

const BASE_UPGRADE_COST: int = 100
const UPGRADE_COST_MULTIPLIER: float = 1.5

var base_magnet_range: float = 75.0

const MAX_DENSITY_LEVEL: int = 10
const BASE_GRASS_PER_CHUNK: int = 8
const BASE_MIN_SPACING: float = 60.0

var grass_data_list: Array[GrassData] = []

signal money_changed(new_amount: int)
signal upgrade_purchased(upgrade_type: String, level: int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_grass_data()

func _init_grass_data() -> void:
	var normal_grass = GrassData.new()
	normal_grass.grass_name = "기본풀"
	normal_grass.max_health = 1
	normal_grass.regen_time = 3.0
	normal_grass.min_drop_value = 1
	normal_grass.max_drop_value = 2
	normal_grass.drop_chance = 1.0
	normal_grass.color = Color(0.3, 0.7, 0.3)
	normal_grass.cut_color = Color(0.5, 0.4, 0.2)

	var tough_grass = GrassData.new()
	tough_grass.grass_name = "강한풀"
	tough_grass.max_health = 3
	tough_grass.regen_time = 5.0
	tough_grass.min_drop_value = 5
	tough_grass.max_drop_value = 10
	tough_grass.drop_chance = 1.0
	tough_grass.color = Color(0.15, 0.5, 0.35)
	tough_grass.cut_color = Color(0.3, 0.35, 0.25)

	var strong_grass = GrassData.new()
	strong_grass.grass_name = "완전 센풀"
	strong_grass.max_health = 6
	strong_grass.regen_time = 8.0
	strong_grass.min_drop_value = 15
	strong_grass.max_drop_value = 30
	strong_grass.drop_chance = 1.0
	strong_grass.color = Color(0.1, 0.35, 0.5)
	strong_grass.cut_color = Color(0.2, 0.3, 0.35)

	var golden_grass = GrassData.new()
	golden_grass.grass_name = "황금풀"
	golden_grass.max_health = 15
	golden_grass.regen_time = 30.0
	golden_grass.min_drop_value = 100
	golden_grass.max_drop_value = 500
	golden_grass.drop_chance = 1.0
	golden_grass.color = Color(1.0, 0.85, 0.1)
	golden_grass.cut_color = Color(0.7, 0.6, 0.1)

	grass_data_list.append(normal_grass)
	grass_data_list.append(tough_grass)
	grass_data_list.append(strong_grass)
	grass_data_list.append(golden_grass)

func get_random_grass_data() -> GrassData:
	var quality_level = upgrade_grass_quality

	const GOLDEN_CHANCE = 0.02

	var roll = randf()
	if roll < GOLDEN_CHANCE:
		return grass_data_list[3]

	var progress = min(quality_level / 27.0, 1.0)

	var normal_chance: float
	var tough_chance: float

	if progress < 0.5:
		var t = progress * 2.0
		normal_chance = 1.0 - t
		tough_chance = t
	else:
		var t = (progress - 0.5) * 2.0
		normal_chance = 0.0
		tough_chance = 1.0 - t

	var remaining_roll = randf()
	if remaining_roll < normal_chance:
		return grass_data_list[0]
	elif remaining_roll < normal_chance + tough_chance:
		return grass_data_list[1]
	else:
		return grass_data_list[2]

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

func get_grass_quality_level() -> int:
	return upgrade_grass_quality

func get_grass_per_chunk() -> int:
	return int(BASE_GRASS_PER_CHUNK * (1.0 + upgrade_grass_density * 0.9))

func get_grass_min_spacing() -> float:
	return BASE_MIN_SPACING / (1.0 + upgrade_grass_density * 0.4)

func get_grass_density_level() -> int:
	return upgrade_grass_density

func get_magnet_range() -> float:
	return base_magnet_range * (1.0 + upgrade_magnet_range * 0.3)

func get_upgrade_cost(current_level: int) -> int:
	return int(BASE_UPGRADE_COST * pow(UPGRADE_COST_MULTIPLIER, current_level))

func purchase_upgrade(upgrade_type: String) -> bool:
	var current_level: int
	var max_level: int = -1
	match upgrade_type:
		"grass_density":
			current_level = upgrade_grass_density
			max_level = MAX_DENSITY_LEVEL
		"magnet_range":
			current_level = upgrade_magnet_range
		"grass_quality":
			current_level = upgrade_grass_quality
		_:
			return false

	if max_level >= 0 and current_level >= max_level:
		return false

	var cost = get_upgrade_cost(current_level)
	if money < cost:
		return false

	money -= cost
	money_changed.emit(money)

	match upgrade_type:
		"grass_density":
			upgrade_grass_density += 1
		"magnet_range":
			upgrade_magnet_range += 1
		"grass_quality":
			upgrade_grass_quality += 1

	upgrade_purchased.emit(upgrade_type, current_level + 1)
	return true

func get_save_data() -> Dictionary:
	return {
		"money": money,
		"upgrade_grass_density": upgrade_grass_density,
		"upgrade_magnet_range": upgrade_magnet_range,
		"upgrade_grass_quality": upgrade_grass_quality
	}

func load_save_data(data: Dictionary) -> void:
	money = data.get("money", 0)
	upgrade_grass_density = data.get("upgrade_grass_density", 0)
	upgrade_magnet_range = data.get("upgrade_magnet_range", 0)
	upgrade_grass_quality = data.get("upgrade_grass_quality", 0)
	money_changed.emit(money)

func reset_session_data() -> void:
	pass
