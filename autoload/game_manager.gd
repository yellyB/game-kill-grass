extends Node

const SCREEN_PADDING_H: float = 40.0
const SCREEN_PADDING_V: float = 60.0

var money: int = 0
var session_money: int = 0

var inventory: Dictionary = {}
var discovered_items: Array = []

var selected_world: int = 0
var unlocked_worlds: Array = [0]
var owned_keys: Array = []
var truck_assembled: bool = false
var prologue_seen: bool = false
const WORLD_UNLOCK_COSTS: Array = [0, 2000, 5000, 10000, 25000, 50000, 80000]

const WORLD_GRASS_HP_MULT: Array = [1.0, 1.3, 1.69, 2.2, 2.86, 3.71, 4.83]
const WORLD_GRASS_REWARD_MULT: Array = [1.0, 1.3, 1.69, 2.2, 2.86, 3.71, 4.83]

var world_strength_levels: Dictionary = {}
func is_world_cleared(world: int) -> bool:
  var next = world + 1
  var is_last = next >= WORLD_UNLOCK_COSTS.size()
  if is_last:
    return get_item_count("졸음 약") >= 1
  return next in unlocked_worlds or has_key(next)

func get_world_strength_level(world: int) -> int:
  return world_strength_levels.get(world, 0)

func get_strengthen_cost(world: int) -> int:
  var next = world + 1
  var base: int
  if next < WORLD_UNLOCK_COSTS.size():
    base = int(WORLD_UNLOCK_COSTS[next] * 1.2)
  else:
    base = int(WORLD_UNLOCK_COSTS[world] * 2.0)
  var level = get_world_strength_level(world)
  return int(base * pow(3, level))

func strengthen_world(world: int) -> bool:
  if not is_world_cleared(world):
    return false
  var cost = get_strengthen_cost(world)
  if money < cost:
    return false
  money -= cost
  world_strength_levels[world] = get_world_strength_level(world) + 1
  money_changed.emit(money)
  SaveManager.save_game()
  return true

func get_world_grass_hp_mult() -> float:
  var w = selected_world
  var base = WORLD_GRASS_HP_MULT[w] if w < WORLD_GRASS_HP_MULT.size() else 1.0
  var strength = get_world_strength_level(w)
  return base * (1.0 + strength * 0.3)

func get_world_grass_reward_mult() -> float:
  var w = selected_world
  var base = WORLD_GRASS_REWARD_MULT[w] if w < WORLD_GRASS_REWARD_MULT.size() else 1.0
  var strength = get_world_strength_level(w)
  return base * (1.0 + strength * 0.5)

signal world_unlocked(index: int)
signal key_acquired(world_index: int)

const SKILL_DEFS: Array = [
  {"type": "attack_speed", "name": "공격 속도", "short_name": "공속", "sub_max": 5, "max_level": 12,
   "description": "풀을 베는 속도가 빨라집니다.\n공격 간격: 0.70초 → 0.10초 (틱당 -0.01초)\n단계 5 | 최대 Lv.12"},
  {"type": "attack_range", "name": "공격 범위", "short_name": "범위", "sub_max": 5, "max_level": 10,
   "description": "풀을 베는 범위가 넓어집니다.\n범위: 60 → 260 (틱당 +4)\n단계 5 | 최대 Lv.10"},
  {"type": "attack_count", "name": "공격 횟수", "short_name": "횟수", "sub_max": 5, "max_level": 8,
   "description": "한 번에 베는 풀의 수가 증가합니다.\n횟수: 1 → ~50 (지수적 증가)\n단계 5 | 최대 Lv.8"},
  {"type": "magnet_range", "name": "자석 범위", "short_name": "자석", "sub_max": 5, "max_level": 8,
   "description": "코인을 끌어당기는 범위가 넓어집니다.\n범위: 40 → 200 (틱당 +4)\n단계 5 | 최대 Lv.8"},
  {"type": "grass_density", "name": "풀 밀도", "short_name": "밀도", "sub_max": 10, "max_level": 10,
   "description": "맵에 풀이 더 빽빽하게 자랍니다.\n청크당 풀: 1 → 200 (지수 곡선)\n단계 10 | 최대 Lv.10"},
  {"type": "grass_quality", "name": "풀 등급", "short_name": "등급", "sub_max": 8, "max_level": 5,
   "description": "더 높은 등급의 풀이 등장할 확률이 증가합니다.\n유효 등급: 0.0 → 3.0 (8단계마다 레벨업)\n단계 8 | 최대 Lv.5"},
  {"type": "chest_chance", "name": "상자 확률", "short_name": "상자", "sub_max": 5, "max_level": 5,
   "description": "상자가 등장할 확률이 증가합니다.\n확률: 0% → 5% (틱당 +0.2%)\n단계 5 | 최대 Lv.5"},
  {"type": "crit_chance", "name": "치명타 확률", "short_name": "치확", "sub_max": 5, "max_level": 8,
   "description": "풀을 벨 때 치명타가 발생할 확률이 증가합니다.\n확률: 0% → 80% (틱당 +2%)\n단계 5 | 최대 Lv.8"},
  {"type": "crit_damage", "name": "치명타 피해", "short_name": "치피", "sub_max": 10, "max_level": 9,
   "description": "치명타 발생 시 추가 피해가 증가합니다.\n배율: 120% → 300% (틱당 +2%)\n단계 10 | 최대 Lv.9"},
  {"type": "weapon", "name": "무기", "short_name": "무기", "sub_max": 5, "max_level": 10,
   "description": "더 강력한 무기로 교체합니다.\n레벨당 공격력 +1, 완료 시 외형 변경\n단계 5 | 최대 Lv.10"},
  {"type": "monster_damage", "name": "몬스터 피해", "short_name": "몬피", "sub_max": 5, "max_level": 7,
   "description": "몬스터에게 주는 피해가 증가합니다.\n배율: 100% → 450% (틱당 +10%) (미정)\n단계 5 | 최대 Lv.7"},
  {"type": "fury_rate", "name": "분노 속도", "short_name": "분노", "sub_max": 4, "max_level": 4,
   "description": "몬스터분노 게이지가 더 빨리 찹니다.\n배율: 100% → 340% (틱당 +15%) (미정)\n단계 4 | 최대 Lv.4"},
  {"type": "golden_chance", "name": "황금풀 확률", "short_name": "황금", "sub_max": 2, "max_level": 5,
   "description": "황금풀이 등장할 확률이 증가합니다.\n확률: 0% → 1.0% (틱당 +0.1%)\n단계 2 | 최대 Lv.5"},
  {"type": "golden_reward", "name": "황금풀 보상", "short_name": "황보", "sub_max": 5, "max_level": 10,
   "description": "황금풀에서 떨어지는 코인이 증가합니다.\n배율: 100% → 600% (틱당 +10%) (미정)\n단계 5 | 최대 Lv.10"},
  {"type": "move_speed", "name": "이동 속도", "short_name": "이속", "sub_max": 6, "max_level": 10,
   "description": "플레이어의 이동 속도가 빨라집니다.\n속도: 300 → 600 (틱당 +5) (미정)\n단계 6 | 최대 Lv.10"},
]

const SKILL_GROUPS: Array = [
  {
    "name": "수확",
    "skills": ["grass_density", "grass_quality", "golden_chance", "golden_reward"],
    "columns": 2,
  },
  {
    "name": "무기",
    "skills": ["attack_speed", "attack_range", "crit_chance", "attack_count", "crit_damage", "monster_damage"],
    "columns": 2,
  },
  {
    "name": "탐험",
    "skills": ["move_speed", "magnet_range", "chest_chance", "fury_rate"],
    "columns": 2,
  },
]

var upgrade_levels: Dictionary = {}
var upgrade_sub_levels: Dictionary = {}
func get_skill_sub_max(type: String) -> int:
  var def = get_skill_def(type)
  return def.get("sub_max", 5)

var session_buff_attack_speed: int = 0
var session_buff_attack_range: int = 0
var session_buff_magnet_range: int = 0
var session_buff_move_speed: int = 0

var timed_buffs: Dictionary = {}

var hit_penalty_active: bool = false

const BASE_UPGRADE_COST: int = 100
const UPGRADE_COST_MULTIPLIER: float = 1.8

var base_magnet_range: float = 40.0

const GRASS_DROP_CHANCE: float = 1.0

var grass_data_list: Array[GrassData] = []

signal money_changed(new_amount: int)
signal session_money_changed(new_amount: int)
signal upgrade_purchased(upgrade_type: String, level: int)
signal item_added(item_id: String, count: int)
signal inventory_changed()
signal powerup_acquired(type: String, level: int)
signal timed_buff_started(type: String, duration: float)
signal timed_buff_ended(type: String)
signal extra_time_requested(seconds: float)
signal golden_bloom_requested()
signal field_clear_requested()
signal blackhole_requested()

signal fury_changed(value: float)
signal fury_boss_requested()
signal boss_key_collected(world_index: int)

var fury: float = 0.0
var session_key_acquired: int = -1
const FURY_MAX: float = 100.0

var _sfx_click: AudioStreamPlayer
var _sfx_confirm: AudioStreamPlayer
var _sfx_craft: AudioStreamPlayer
var _sfx_weapon_upgrade: AudioStreamPlayer
var _sfx_skill_upgrade: AudioStreamPlayer
var _sfx_unlock: AudioStreamPlayer

func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS
  for def in SKILL_DEFS:
    if not upgrade_levels.has(def.type):
      upgrade_levels[def.type] = 0
    if not upgrade_sub_levels.has(def.type):
      upgrade_sub_levels[def.type] = 0
  upgrade_levels["weapon"] = WeaponManager.current_weapon_level
  WeaponManager.weapon_changed.connect(func(lvl: int): upgrade_levels["weapon"] = lvl)
  _init_grass_data()
  _sfx_click = AudioStreamPlayer.new()
  _sfx_click.stream = preload("res://resources/sounds/effect/button_click.wav")
  _sfx_click.volume_db = -5.0
  add_child(_sfx_click)
  _sfx_confirm = AudioStreamPlayer.new()
  _sfx_confirm.stream = preload("res://resources/sounds/effect/confirm_button_click.wav")
  _sfx_confirm.volume_db = -3.0
  add_child(_sfx_confirm)
  _sfx_craft = AudioStreamPlayer.new()
  _sfx_craft.stream = preload("res://resources/sounds/effect/item_craft_short_hammer.wav")
  _sfx_craft.volume_db = -3.0
  add_child(_sfx_craft)
  _sfx_weapon_upgrade = AudioStreamPlayer.new()
  _sfx_weapon_upgrade.stream = preload("res://resources/sounds/effect/weapon_upgrade_success.wav")
  _sfx_weapon_upgrade.volume_db = -3.0
  add_child(_sfx_weapon_upgrade)
  _sfx_skill_upgrade = AudioStreamPlayer.new()
  _sfx_skill_upgrade.stream = preload("res://resources/sounds/effect/skill_upgrade_success.wav")
  _sfx_skill_upgrade.volume_db = -3.0
  add_child(_sfx_skill_upgrade)
  _sfx_unlock = AudioStreamPlayer.new()
  _sfx_unlock.stream = preload("res://resources/sounds/effect/unlock_world.wav")
  _sfx_unlock.volume_db = -3.0
  add_child(_sfx_unlock)

func play_button_click() -> void:
  _sfx_click.play()

func play_confirm_click() -> void:
  _sfx_confirm.play()

func play_craft_sound() -> void:
  _sfx_craft.play()

func play_weapon_upgrade_sound() -> void:
  _sfx_weapon_upgrade.play()

func play_skill_upgrade_sound() -> void:
  _sfx_skill_upgrade.play()

func play_unlock_sound() -> void:
  _sfx_unlock.play()

const BUTTON_COLORS = {
  "main": Color(0.3, 0.75, 0.45),
  "muted": Color(0.45, 0.45, 0.5),
  "sub": Color(0.45, 0.62, 0.78),
}

const COIN_TEXTURE = preload("res://resources/images/coin.png")

func format_number(num: int) -> String:
  var str_num = str(num)
  var result = ""
  var count = 0
  for i in range(str_num.length() - 1, -1, -1):
    if count > 0 and count % 3 == 0:
      result = "," + result
    result = str_num[i] + result
    count += 1
  return result

func create_coin_label(amount_text: String, font_size: int = 30,
    font_color: Color = Color(1, 0.9, 0.3), outline_size: int = 0,
    center: bool = false) -> HBoxContainer:
  var icon_size = int(font_size * 0.85)
  var hbox = HBoxContainer.new()
  hbox.add_theme_constant_override("separation", int(font_size * 0.2))
  hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
  if center:
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER

  var icon = TextureRect.new()
  icon.texture = COIN_TEXTURE
  icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
  icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon.custom_minimum_size = Vector2(icon_size, icon_size)
  icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
  hbox.add_child(icon)

  var label = Label.new()
  label.text = amount_text
  label.add_theme_font_size_override("font_size", font_size)
  label.add_theme_color_override("font_color", font_color)
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  if outline_size > 0:
    label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    label.add_theme_constant_override("outline_size", outline_size)
  hbox.add_child(label)

  return hbox

func style_button(btn: Button, color_type: String = "main", btn_size: Vector2 = Vector2.ZERO) -> void:
  var main_color = BUTTON_COLORS.get(color_type, BUTTON_COLORS["main"])
  if btn_size != Vector2.ZERO:
    var font_size = int(btn_size.y * 35.0 / 75.0)
    btn.custom_minimum_size = btn_size
    btn.add_theme_font_size_override("font_size", font_size)
    if btn.icon:
      var aspect = float(btn.icon.get_width()) / float(btn.icon.get_height())
      btn.add_theme_constant_override("icon_max_width", int(font_size * aspect))
    else:
      btn.add_theme_constant_override("icon_max_width", font_size)
  var shadow_color = main_color.darkened(0.3)

  var style_n = StyleBoxFlat.new()
  style_n.bg_color = main_color
  style_n.corner_radius_top_left = 18
  style_n.corner_radius_top_right = 18
  style_n.corner_radius_bottom_left = 18
  style_n.corner_radius_bottom_right = 18
  style_n.border_width_bottom = 6
  style_n.border_color = shadow_color
  style_n.content_margin_left = 48
  style_n.content_margin_right = 48
  style_n.content_margin_top = 12
  style_n.content_margin_bottom = 14
  btn.add_theme_stylebox_override("normal", style_n)

  var style_h = style_n.duplicate()
  style_h.bg_color = main_color.lightened(0.1)
  btn.add_theme_stylebox_override("hover", style_h)

  var style_p = StyleBoxFlat.new()
  style_p.bg_color = main_color.darkened(0.1)
  style_p.corner_radius_top_left = 18
  style_p.corner_radius_top_right = 18
  style_p.corner_radius_bottom_left = 18
  style_p.corner_radius_bottom_right = 18
  style_p.border_width_bottom = 2
  style_p.border_color = shadow_color
  style_p.content_margin_left = 48
  style_p.content_margin_right = 48
  style_p.content_margin_top = 16
  style_p.content_margin_bottom = 10
  btn.add_theme_stylebox_override("pressed", style_p)

  var style_d = style_n.duplicate()
  style_d.bg_color = main_color.darkened(0.4)
  style_d.border_color = shadow_color.darkened(0.4)
  btn.add_theme_stylebox_override("disabled", style_d)

  var style_f = StyleBoxEmpty.new()
  btn.add_theme_stylebox_override("focus", style_f)

  btn.add_theme_color_override("font_color", Color.WHITE)
  btn.add_theme_color_override("font_hover_color", Color.WHITE)
  btn.add_theme_color_override("font_pressed_color", Color.WHITE)
  btn.add_theme_color_override("font_disabled_color", Color(0.65, 0.65, 0.7))

func _process(delta: float) -> void:
  if get_tree().paused:
    return
  var expired: Array = []
  for buff_type in timed_buffs:
    timed_buffs[buff_type] -= delta
    if timed_buffs[buff_type] <= 0:
      expired.append(buff_type)
  for buff_type in expired:
    timed_buffs.erase(buff_type)
    timed_buff_ended.emit(buff_type)

func _init_grass_data() -> void:
  var normal_grass = GrassData.new()
  normal_grass.grass_name = "기본풀"
  normal_grass.max_health = 4
  normal_grass.regen_time = 22.0
  normal_grass.min_drop_value = 1
  normal_grass.max_drop_value = 1
  normal_grass.drop_chance = GRASS_DROP_CHANCE
  normal_grass.color = Color(0.3, 0.7, 0.3)
  normal_grass.cut_color = Color(0.5, 0.4, 0.2)

  var tough_grass = GrassData.new()
  tough_grass.grass_name = "강한풀"
  tough_grass.max_health = 12
  tough_grass.regen_time = 23.0
  tough_grass.min_drop_value = 5
  tough_grass.max_drop_value = 5
  tough_grass.drop_chance = GRASS_DROP_CHANCE
  tough_grass.color = Color(0.15, 0.5, 0.35)
  tough_grass.cut_color = Color(0.3, 0.35, 0.25)

  var strong_grass = GrassData.new()
  strong_grass.grass_name = "완전 센풀"
  strong_grass.max_health = 24
  strong_grass.regen_time = 24.0
  strong_grass.min_drop_value = 30
  strong_grass.max_drop_value = 30
  strong_grass.drop_chance = GRASS_DROP_CHANCE
  strong_grass.color = Color(0.1, 0.35, 0.5)
  strong_grass.cut_color = Color(0.2, 0.3, 0.35)

  var golden_grass = GrassData.new()
  golden_grass.grass_name = "황금풀"
  golden_grass.max_health = 160
  golden_grass.regen_time = 25.0
  golden_grass.min_drop_value = 300
  golden_grass.max_drop_value = 300
  golden_grass.guaranteed_drop = true
  golden_grass.color = Color(1.0, 0.85, 0.1)
  golden_grass.cut_color = Color(0.7, 0.6, 0.1)

  grass_data_list.append(normal_grass)
  grass_data_list.append(tough_grass)
  grass_data_list.append(strong_grass)
  grass_data_list.append(golden_grass)

const QUALITY_EFFECTIVE: Array = [0.0, 0.2, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]

func get_random_grass_data() -> GrassData:
  var raw_level = upgrade_levels.get("grass_quality", 0)
  var quality_level = QUALITY_EFFECTIVE[clampi(raw_level, 0, QUALITY_EFFECTIVE.size() - 1)]

  var roll = randf()
  if roll < get_golden_grass_chance():
    return grass_data_list[3]

  var normal_w: float
  if quality_level >= 7.0:
    normal_w = 0.0
  else:
    normal_w = pow((7.0 - quality_level) / 7.0, 1.8)

  var strong_w: float
  if quality_level <= 2.0:
    strong_w = 0.0
  else:
    strong_w = pow((quality_level - 2.0) / 6.0, 1.8)

  var tough_w = max(0.0, 1.0 - normal_w - strong_w)

  var remaining_roll = randf()
  if remaining_roll < normal_w:
    return grass_data_list[0]
  elif remaining_roll < normal_w + tough_w:
    return grass_data_list[1]
  else:
    return grass_data_list[2]

func add_fury(amount: float) -> void:
  fury = minf(fury + amount * get_fury_rate_mult(), FURY_MAX)
  fury_changed.emit(fury)
  if fury >= FURY_MAX:
    fury_boss_requested.emit()
    fury = 0.0
    fury_changed.emit(fury)

func add_money(amount: int) -> void:
  session_money = max(0, session_money + amount)
  session_money_changed.emit(session_money)

func get_skill_total_progress(type: String) -> int:
  var level = upgrade_levels.get(type, 0)
  var sub = upgrade_sub_levels.get(type, 0)
  var def = get_skill_def(type)
  var sub_max = def.get("sub_max", 5)
  return level * sub_max + sub

func get_attack_interval() -> float:
  var ticks = get_skill_total_progress("attack_speed")
  return maxf(0.1, 0.7 - ticks * 0.01)

func get_attack_range() -> float:
  var ticks = get_skill_total_progress("attack_range")
  return 60.0 + ticks * 4.0

func get_attack_count() -> int:
  var ticks = get_skill_total_progress("attack_count")
  if ticks <= 0:
    return 1
  return maxi(1, roundi(1.0 + 49.0 * pow(float(ticks) / 40.0, 2.0)))

func get_base_magnet_range() -> float:
  var ticks = get_skill_total_progress("magnet_range")
  return 40.0 + ticks * 4.0

func get_grass_density_value() -> int:
  var ticks = get_skill_total_progress("grass_density")
  if ticks <= 0:
    return 1
  return maxi(1, roundi(200.0 * pow(float(ticks) / 100.0, 3.0)))

func get_grass_quality_level() -> int:
  return upgrade_levels.get("grass_quality", 0)

func get_chest_spawn_chance() -> float:
  var ticks = get_skill_total_progress("chest_chance")
  return ticks * 0.002

func get_crit_chance() -> float:
  var ticks = get_skill_total_progress("crit_chance")
  return minf(ticks * 0.02, 0.8)

func get_crit_damage_mult() -> float:
  var ticks = get_skill_total_progress("crit_damage")
  return 1.2 + ticks * 0.02

func get_monster_damage_mult() -> float:
  var ticks = get_skill_total_progress("monster_damage")
  return 1.0 + ticks * 0.1

func get_fury_rate_mult() -> float:
  var ticks = get_skill_total_progress("fury_rate")
  return 1.0 + ticks * 0.15

func get_golden_grass_chance() -> float:
  var ticks = get_skill_total_progress("golden_chance")
  if ticks <= 0:
    return 0.0
  return ticks * 0.001

func get_golden_reward_mult() -> float:
  var ticks = get_skill_total_progress("golden_reward")
  return 1.0 + ticks * 0.1

func get_base_move_speed() -> float:
  var ticks = get_skill_total_progress("move_speed")
  return 300.0 + ticks * 5.0

func get_grass_density_level() -> int:
  return upgrade_levels.get("grass_density", 0)

func get_magnet_range() -> float:
  var base = get_base_magnet_range()
  var mult = 1.0 + session_buff_magnet_range * 0.5
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  mult += get_part_count("강화 유리 모듈", 6) * 0.15
  return base * mult

func get_session_attack_speed_mult() -> float:
  var mult = 1.0 + session_buff_attack_speed * 0.25
  mult += get_part_count("운전기사", 1) * 0.2
  if timed_buffs.has("overdrive"):
    mult *= 2.0
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  if hit_penalty_active:
    mult *= 0.5
  return mult

func get_session_attack_range_mult() -> float:
  var mult = 1.0 + session_buff_attack_range * 0.25
  mult += get_part_count("폭발하는 엔진 코어", 10) * 0.1
  if timed_buffs.has("harvest_madness"):
    mult *= 1.5
  return mult

func get_session_move_speed_mult() -> float:
  var mult = 1.0 + session_buff_move_speed * 0.5
  mult += get_part_count("개념상 바퀴", 4) * 0.08
  if timed_buffs.has("overdrive"):
    mult *= 0.5
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  if hit_penalty_active:
    mult *= 0.5
  return mult

func get_coin_multiplier() -> int:
  if timed_buffs.has("gold_rush"):
    return 2
  return 1

func get_timed_buff_remaining(type: String) -> float:
  return timed_buffs.get(type, 0.0)

func apply_powerup(type: String) -> void:
  match type:
    "attack_speed":
      session_buff_attack_speed += 1
      powerup_acquired.emit(type, session_buff_attack_speed)
    "attack_range":
      session_buff_attack_range += 1
      powerup_acquired.emit(type, session_buff_attack_range)
    "magnet_range":
      session_buff_magnet_range += 1
      powerup_acquired.emit(type, session_buff_magnet_range)
    "move_speed":
      session_buff_move_speed += 1
      powerup_acquired.emit(type, session_buff_move_speed)
    "overdrive":
      _start_timed_buff("overdrive", 10.0)
      powerup_acquired.emit(type, 1)
    "extra_time":
      extra_time_requested.emit(5.0)
      powerup_acquired.emit(type, 0)
    "gold_rush":
      _start_timed_buff("gold_rush", 10.0)
      powerup_acquired.emit(type, 0)
    "golden_bloom":
      golden_bloom_requested.emit()
      powerup_acquired.emit(type, 0)
    "double_or_dust":
      _apply_double_or_dust()
    "beast_rush":
      add_fury(10.0)
      powerup_acquired.emit(type, 0)
    "harvest_madness":
      _start_timed_buff("harvest_madness", 5.0)
      powerup_acquired.emit(type, 0)
    "field_clear":
      field_clear_requested.emit()
      powerup_acquired.emit(type, 0)
    "blackhole":
      blackhole_requested.emit()
      powerup_acquired.emit(type, 0)

func _start_timed_buff(type: String, duration: float) -> void:
  timed_buffs[type] = duration
  timed_buff_started.emit(type, duration)

func _apply_double_or_dust() -> void:
  if randf() < 0.5:
    var bonus = session_money
    add_money(bonus)
    powerup_acquired.emit("double_or_dust", 1)
  else:
    var lost = session_money
    add_money(-lost)
    powerup_acquired.emit("double_or_dust", 0)

const BASE_KNOCKBACK: float = 120.0
const KNOCKBACK_PER_LEVEL: float = 120.0

func get_monster_knockback_strength() -> float:
  return BASE_KNOCKBACK + get_part_count("충격 무시 범퍼", 2) * KNOCKBACK_PER_LEVEL

func get_grass_drop_chance() -> float:
  return GRASS_DROP_CHANCE + upgrade_levels.get("grass_drop", 0) * 0.06

func get_total_skill_level() -> int:
  var total = 0
  for type in upgrade_levels:
    if type == "weapon":
      continue
    total += upgrade_levels[type]
  return total

func get_grass_reward_multiplier() -> float:
  return 1.0 + upgrade_levels.get("grass_reward", 0) * 0.4

const WEAPON_SKILL_REQUIREMENTS = [0, 0, 2, 4, 7, 11, 16, 21, 27, 34]

const SKILL_PREREQS = {
  "attack_range:1": [{"type": "attack_speed", "level": 1}],
  "crit_chance:1": [{"type": "attack_speed", "level": 1}],
  "attack_count:1": [{"type": "attack_range", "level": 1}],
  "crit_damage:1": [{"type": "crit_chance", "level": 1}],
  "monster_damage:1": [{"type": "crit_damage", "level": 1}],
  "grass_quality:1": [{"type": "grass_density", "level": 1}],
  "golden_chance:1": [{"type": "grass_density", "level": 1}],
  "golden_reward:1": [{"type": "golden_chance", "level": 1}],
  "magnet_range:1": [{"type": "move_speed", "level": 1}],
  "chest_chance:1": [{"type": "move_speed", "level": 1}],
  "fury_rate:1": [{"type": "magnet_range_or_chest_chance", "level": 1}],
}

const SKILL_REQUIRED_TOTAL = {
  "attack_range": 3, "attack_count": 3,
  "crit_chance": 3, "crit_damage": 3,
  "monster_damage": 3,
  "grass_quality": 3, "golden_chance": 3,
  "golden_reward": 3,
  "move_speed": 3, "chest_chance": 3,
  "fury_rate": 3,
  "attack_range:2": 10,
}

func check_skill_prereqs(type: String, level: int) -> Dictionary:
  var missing: Array = []
  var total_key = "%s:%d" % [type, level]
  var required = -1
  if SKILL_REQUIRED_TOTAL.has(total_key):
    required = SKILL_REQUIRED_TOTAL[total_key]
  elif SKILL_REQUIRED_TOTAL.has(type):
    required = SKILL_REQUIRED_TOTAL[type]
  if required >= 0:
    var total = get_total_skill_level()
    if total < required:
      missing.append({"type": "_total", "level": required, "current": total})
  var key = "%s:%d" % [type, level]
  if SKILL_PREREQS.has(key):
    for req in SKILL_PREREQS[key]:
      if "_or_" in req.type:
        var or_types = req.type.split("_or_")
        var any_met = false
        for ot in or_types:
          if get_upgrade_level(ot) >= req.level:
            any_met = true
            break
        if not any_met:
          var names = []
          for ot in or_types:
            names.append(get_skill_def(ot).get("short_name", ot))
          missing.append({"type": req.type, "level": req.level, "current": 0, "or_names": names})
      else:
        var current = get_upgrade_level(req.type)
        if current < req.level:
          missing.append({"type": req.type, "level": req.level, "current": current})
  return {"met": missing.is_empty(), "missing": missing}

func get_upgrade_level(type: String) -> int:
  return upgrade_levels.get(type, 0)

func get_upgrade_sub_level(type: String) -> int:
  return upgrade_sub_levels.get(type, 0)

func get_skill_max_level(type: String) -> int:
  for def in SKILL_DEFS:
    if def.type == type:
      return def.max_level
  return -1

func get_skill_def(type: String) -> Dictionary:
  for def in SKILL_DEFS:
    if def.type == type:
      return def
  return {}

func get_weapon_skill_requirement(weapon_level: int) -> int:
  if weapon_level < 0 or weapon_level >= WEAPON_SKILL_REQUIREMENTS.size():
    return 0
  return WEAPON_SKILL_REQUIREMENTS[weapon_level]

func get_grass_regen_time(base_time: float) -> float:
  var level = upgrade_levels.get("grass_regen", 0)
  if level == 0:
    return base_time
  elif level == 1:
    return 13.0
  else:
    return 4.0

const DENSITY_COSTS: Array = [15, 60, 150, 400, 900, 2000, 4500, 10000, 22000, 50000]
const QUALITY_COSTS: Array = [15, 60, 150, 400, 900, 2000, 4500, 10000, 22000, 50000]

func get_upgrade_cost(current_level: int, upgrade_type: String = "") -> int:
  if upgrade_type == "weapon":
    var next = WeaponManager.get_next_weapon()
    if next.is_empty():
      return 0
    return next.price
  if upgrade_type == "grass_density" and current_level < DENSITY_COSTS.size():
    return DENSITY_COSTS[current_level]
  if upgrade_type == "grass_quality" and current_level < QUALITY_COSTS.size():
    return QUALITY_COSTS[current_level]
  var base = int(BASE_UPGRADE_COST * pow(UPGRADE_COST_MULTIPLIER, current_level))
  if upgrade_type == "golden_chance":
    return int(base * (30.0 + current_level * 65.0))
  if current_level > 0:
    return int(base * (1.0 + current_level * 0.4))
  return base

func purchase_upgrade(upgrade_type: String) -> bool:
  if upgrade_type == "weapon":
    var wep_next = upgrade_levels.get("weapon", 0) + 1
    var wep_prereq = check_skill_prereqs("weapon", wep_next)
    if not wep_prereq.met:
      return false
    if not WeaponManager.purchase_next_weapon():
      return false
    upgrade_levels["weapon"] = WeaponManager.current_weapon_level
    upgrade_purchased.emit(upgrade_type, upgrade_levels["weapon"])
    return true

  var current_level = upgrade_levels.get(upgrade_type, -1)
  if current_level < 0:
    return false
  var max_level = get_skill_max_level(upgrade_type)
  if max_level >= 0 and current_level >= max_level:
    return false

  var next_level = current_level + 1
  var prereq_result = check_skill_prereqs(upgrade_type, next_level)
  if not prereq_result.met:
    return false

  var cost = get_upgrade_cost(current_level, upgrade_type)
  if money < cost:
    return false

  money -= cost
  money_changed.emit(money)
  upgrade_sub_levels[upgrade_type] = upgrade_sub_levels.get(upgrade_type, 0) + 1
  if upgrade_sub_levels[upgrade_type] >= get_skill_sub_max(upgrade_type):
    upgrade_levels[upgrade_type] = next_level
    upgrade_sub_levels[upgrade_type] = 0
  upgrade_purchased.emit(upgrade_type, next_level)
  return true

func add_item(item_id: String, count: int = 1) -> void:
  if item_id not in discovered_items:
    discovered_items.append(item_id)
  if inventory.has(item_id):
    inventory[item_id] += count
  else:
    inventory[item_id] = count
  item_added.emit(item_id, inventory[item_id])
  inventory_changed.emit()

func remove_item(item_id: String, count: int = 1) -> bool:
  var current = inventory.get(item_id, 0)
  if current < count:
    return false
  inventory[item_id] = current - count
  inventory_changed.emit()
  return true

func get_item_count(item_id: String) -> int:
  return inventory.get(item_id, 0)

func get_part_count(part_id: String, max_count: int) -> int:
  return mini(get_item_count(part_id), max_count)

func get_part_penalty_mult() -> float:
  return 1.0 - upgrade_levels.get("penalty_reduce", 0) * 0.25

func is_item_discovered(item_id: String) -> bool:
  return item_id in discovered_items

func add_key(world_index: int) -> void:
  if world_index not in owned_keys:
    owned_keys.append(world_index)
    key_acquired.emit(world_index)
    SaveManager.save_game()

func has_key(world_index: int) -> bool:
  return world_index in owned_keys

func unlock_world(index: int) -> bool:
  if index < 0 or index >= WORLD_UNLOCK_COSTS.size():
    return false
  if index in unlocked_worlds:
    return false
  var cost = WORLD_UNLOCK_COSTS[index]
  if money < cost:
    return false
  if not has_key(index):
    return false
  money -= cost
  owned_keys.erase(index)
  unlocked_worlds.append(index)
  money_changed.emit(money)
  world_unlocked.emit(index)
  SaveManager.save_game()
  return true

func get_save_data() -> Dictionary:
  return {
    "money": money,
    "upgrade_levels": upgrade_levels.duplicate(),
    "upgrade_sub_levels": upgrade_sub_levels.duplicate(),
    "inventory": inventory,
    "discovered_items": discovered_items,
    "selected_world": selected_world,
    "unlocked_worlds": unlocked_worlds,
    "owned_keys": owned_keys,
    "truck_assembled": truck_assembled,
    "prologue_seen": prologue_seen,
    "world_strength_levels": world_strength_levels.duplicate(),
  }

func load_save_data(data: Dictionary) -> void:
  money = data.get("money", 0)
  if data.has("upgrade_levels"):
    for type in data.upgrade_levels:
      upgrade_levels[type] = int(data.upgrade_levels[type])
  else:
    for def in SKILL_DEFS:
      upgrade_levels[def.type] = int(data.get("upgrade_%s" % def.type, 0))
  var saved_sub = data.get("upgrade_sub_levels", {})
  for type in saved_sub:
    upgrade_sub_levels[type] = int(saved_sub[type])
  inventory = data.get("inventory", {})
  discovered_items = data.get("discovered_items", [])
  selected_world = data.get("selected_world", 0)
  var saved_worlds = data.get("unlocked_worlds", [0])
  unlocked_worlds = []
  for w in saved_worlds:
    unlocked_worlds.append(int(w))
  if 0 not in unlocked_worlds:
    unlocked_worlds.append(0)
  truck_assembled = data.get("truck_assembled", false)
  prologue_seen = data.get("prologue_seen", false)
  var saved_keys = data.get("owned_keys", [])
  owned_keys = []
  for k in saved_keys:
    owned_keys.append(int(k))
  world_strength_levels = {}
  var saved_strength = data.get("world_strength_levels", {})
  for k in saved_strength:
    world_strength_levels[int(k)] = int(saved_strength[k])
  money_changed.emit(money)
  inventory_changed.emit()

func finalize_session() -> void:
  money += session_money
  session_money = 0
  money_changed.emit(money)

func reset_session_data() -> void:
  session_money = 0
  session_buff_attack_speed = 0
  session_buff_attack_range = 0
  session_buff_magnet_range = 0
  session_buff_move_speed = 0
  timed_buffs.clear()
  hit_penalty_active = false
  fury = 0.0
  session_key_acquired = -1
  session_money_changed.emit(0)
