extends Node

const SCREEN_PADDING_H: float = 40.0
const SCREEN_PADDING_V: float = 60.0

var money: int = 0
var session_money: int = 0

var selected_world: int = 0
var unlocked_worlds: Array = [0]
var owned_keys: Array = []
var has_potion: bool = false
const WORLD_UNLOCK_COSTS: Array = [0, 100, 3000, 10000, 25000, 50000, 100000]

const WORLD_GRASS_HP_MULT: Array = [1.0, 1.3, 1.69, 2.2, 2.86, 3.71, 4.83]
const WORLD_GRASS_REWARD_MULT: Array = [1.0, 1.3, 1.69, 2.2, 2.86, 3.71, 4.83]

var world_strength_levels: Dictionary = {}
func is_world_cleared(world: int) -> bool:
  var next = world + 1
  var is_last = next >= WORLD_UNLOCK_COSTS.size()
  if is_last:
    return has_potion
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
   "description": "다음 공격까지의 대기 시간이 짧아집니다.\n공격 간격: 0.70초 → 0.10초 (틱당 -0.01초)\n단계 5 | 최대 Lv.12"},
  {"type": "attack_range", "name": "공격 범위", "short_name": "범위", "sub_max": 5, "max_level": 10,
   "description": "공격 범위가 넓어집니다.\n범위: 60 → 260 (틱당 +4)\n단계 5 | 최대 Lv.10"},
  {"type": "attack_count", "name": "공격 개수", "short_name": "개수", "sub_max": 3, "max_level": 5,
   "description": "한 번에 베는 풀의 개수가 증가합니다.\n횟수: 1 → 46 (레벨별 +1/+2/+3/+4/+5)\n단계 3 | 최대 Lv.5"},
  {"type": "magnet_range", "name": "수집 범위", "short_name": "수집", "sub_max": 5, "max_level": 8,
   "description": "코인을 끌어당기는 범위가 넓어집니다.\n범위: 40 → 200 (틱당 +4)\n단계 5 | 최대 Lv.8"},
  {"type": "grass_density", "name": "풀 밀도", "short_name": "밀도", "sub_max": 5, "max_level": 8,
   "description": "맵 구획당 자라는 풀의 수가 증가합니다.\n구획당 풀: 1개 → 181개 (Lv별 틱당 +1/+2/.../+8)\n단계 5 | 최대 Lv.8"},
  {"type": "grass_quality", "name": "풀 등급", "short_name": "등급", "sub_max": 8, "max_level": 8,
   "description": "높은 등급 풀이 등장할 확률이 높아집니다.\n홀수 레벨: 다음 등급 50%까지\n짝수 레벨: 다음 등급 100%까지\n단계 8 | 최대 Lv.8"},
  {"type": "chest_chance", "name": "상자 확률", "short_name": "상자", "sub_max": 5, "max_level": 5,
   "description": "맵 구획당 상자 등장 확률이 높아집니다.\n확률: 0% → 5% (틱당 +0.2%)\n단계 5 | 최대 Lv.5"},
  {"type": "crit_chance", "name": "치명타 확률", "short_name": "치확", "sub_max": 5, "max_level": 8,
   "description": "치명타 발생 확률이 높아집니다.\n확률: 0% → 80% (틱당 +2%)\n단계 5 | 최대 Lv.8"},
  {"type": "crit_damage", "name": "치명타 피해", "short_name": "치피", "sub_max": 5, "max_level": 6,
   "description": "치명타 피해량이 증가합니다.\n배율: 120% → 300% (틱당 +6%)\n단계 5 | 최대 Lv.6"},
  {"type": "attack_power", "name": "공격력", "short_name": "공격력", "sub_max": 5, "max_level": 9,
   "description": "공격력이 증가합니다.\nLv.1~3: +1/틱, Lv.4~5: +2/틱\nLv.6~7: +3/틱, Lv.8~9: +4/틱\n단계 5 | 최대 Lv.9"},
  {"type": "monster_damage", "name": "몬스터 피해", "short_name": "몬피", "sub_max": 5, "max_level": 7,
   "description": "몬스터에게 주는 피해가 증가합니다.\n배율: 100% → 450% (틱당 +10%) (미정)\n단계 5 | 최대 Lv.7"},
  {"type": "fury_rate", "name": "분노 속도", "short_name": "분노", "sub_max": 4, "max_level": 4,
   "description": "몬스터 분노 게이지가 더 빨리 찹니다.\n배율: 100% → 340% (틱당 +15%) (미정)\n단계 4 | 최대 Lv.4"},
  {"type": "golden_chance", "name": "황금풀 확률", "short_name": "황금", "sub_max": 2, "max_level": 5,
   "description": "풀이 황금풀로 자라날 확률이 높아집니다.\n확률: 0% → 1.0% (틱당 +0.1%)\n단계 2 | 최대 Lv.5"},
  {"type": "golden_reward", "name": "황금풀 보상", "short_name": "황보", "sub_max": 5, "max_level": 5,
   "description": "황금풀에서 떨어지는 코인이 증가합니다.\n보상: 100원 → ~1,696원 (단계별 10~14% 복리)\n단계 5 | 최대 Lv.5"},
  {"type": "move_speed", "name": "이동 속도", "short_name": "이속", "sub_max": 6, "max_level": 5,
   "description": "플레이어의 이동 속도가 빨라집니다.\n속도: 300 → 600 (틱당 +10)\n단계 6 | 최대 Lv.5"},
  {"type": "session_time", "name": "세션 시간", "short_name": "시간", "sub_max": 3, "max_level": 5,
   "description": "세션 시간이 증가합니다.\n+3초\n단계 3 | 최대 Lv.5"},
]

const SKILL_GROUPS: Array = [
  {
    "name": "무기",
    "skills": ["attack_power", "attack_speed", "attack_range", "crit_chance", "monster_damage", "crit_damage"],
    "columns": 2,
  },
  {
    "name": "수확",
    "skills": ["grass_density", "grass_quality", "magnet_range", "golden_chance", "attack_count", "golden_reward"],
    "columns": 2,
  },
  {
    "name": "탐험",
    "skills": ["move_speed", "session_time", "chest_chance", "fury_rate"],
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

var base_magnet_range: float = 40.0

const GRASS_DROP_CHANCE: float = 1.0

var grass_data_list: Array[GrassData] = []

signal money_changed(new_amount: int)
signal session_money_changed(new_amount: int)
signal upgrade_purchased(upgrade_type: String, level: int)
signal powerup_acquired(type: String, level: int)
signal timed_buff_started(type: String, duration: float)
signal timed_buff_ended(type: String)
signal extra_time_requested(seconds: float)
signal golden_bloom_requested()
signal field_clear_requested()
signal blackhole_requested()

signal fury_changed(value: float)
signal fury_boss_requested()
signal fury_gauge_dismissed()
signal boss_key_collected(world_index: int)

var fury: float = 0.0
var session_key_acquired: int = -1
const FURY_THRESHOLDS: Array = [250.0, 600.0, 1500.0, 4000.0]

func get_fury_max() -> float:
  var idx = clampi(selected_world, 0, FURY_THRESHOLDS.size() - 1)
  return FURY_THRESHOLDS[idx]

var _sfx_click: AudioStreamPlayer
var _sfx_confirm: AudioStreamPlayer
var _sfx_skill_upgrade: AudioStreamPlayer
var _sfx_unlock: AudioStreamPlayer
var _sfx_skill_click: AudioStreamPlayer

func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS
  for def in SKILL_DEFS:
    if not upgrade_levels.has(def.type):
      upgrade_levels[def.type] = 0
    if not upgrade_sub_levels.has(def.type):
      upgrade_sub_levels[def.type] = 0
  WeaponManager.current_weapon_level = upgrade_levels.get("attack_power", 0)
  _init_grass_data()
  _sfx_click = AudioStreamPlayer.new()
  _sfx_click.stream = preload("res://resources/sounds/effect/button_click.wav")
  _sfx_click.volume_db = -5.0
  add_child(_sfx_click)
  _sfx_confirm = AudioStreamPlayer.new()
  _sfx_confirm.stream = preload("res://resources/sounds/effect/confirm_button_click.wav")
  _sfx_confirm.volume_db = -3.0
  add_child(_sfx_confirm)
  _sfx_skill_upgrade = AudioStreamPlayer.new()
  _sfx_skill_upgrade.stream = preload("res://resources/sounds/effect/skill_upgrade_success.wav")
  _sfx_skill_upgrade.volume_db = -3.0
  add_child(_sfx_skill_upgrade)
  _sfx_unlock = AudioStreamPlayer.new()
  _sfx_unlock.stream = preload("res://resources/sounds/effect/unlock_world.wav")
  _sfx_unlock.volume_db = -3.0
  add_child(_sfx_unlock)
  _sfx_skill_click = AudioStreamPlayer.new()
  _sfx_skill_click.stream = preload("res://resources/sounds/effect/skill_click.wav")
  _sfx_skill_click.volume_db = -5.0
  add_child(_sfx_skill_click)

func play_skill_click() -> void:
  _sfx_skill_click.play()

func play_button_click() -> void:
  _sfx_click.play()

func play_confirm_click() -> void:
  _sfx_confirm.play()

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
  var g0 = GrassData.new()
  g0.grass_name = "새싹"
  g0.max_health = 4
  g0.regen_time = 22.0
  g0.min_drop_value = 1
  g0.max_drop_value = 1
  g0.drop_chance = GRASS_DROP_CHANCE
  g0.color = Color(0.3, 0.7, 0.3)
  g0.cut_color = Color(0.5, 0.4, 0.2)

  var g1 = GrassData.new()
  g1.grass_name = "잔디"
  g1.max_health = 18
  g1.regen_time = 23.0
  g1.min_drop_value = 5
  g1.max_drop_value = 5
  g1.drop_chance = GRASS_DROP_CHANCE
  g1.color = Color(0.15, 0.5, 0.35)
  g1.cut_color = Color(0.3, 0.35, 0.25)

  var g2 = GrassData.new()
  g2.grass_name = "여린풀"
  g2.max_health = 38
  g2.regen_time = 24.0
  g2.min_drop_value = 30
  g2.max_drop_value = 30
  g2.drop_chance = GRASS_DROP_CHANCE
  g2.color = Color(0.1, 0.35, 0.5)
  g2.cut_color = Color(0.2, 0.3, 0.35)

  var g3 = GrassData.new()
  g3.grass_name = "강한풀"
  g3.max_health = 75
  g3.regen_time = 25.0
  g3.min_drop_value = 80
  g3.max_drop_value = 80
  g3.drop_chance = GRASS_DROP_CHANCE
  g3.color = Color(0.1, 0.25, 0.55)
  g3.cut_color = Color(0.15, 0.25, 0.4)

  var g4 = GrassData.new()
  g4.grass_name = "초강풀"
  g4.max_health = 130
  g4.regen_time = 26.0
  g4.min_drop_value = 200
  g4.max_drop_value = 200
  g4.drop_chance = GRASS_DROP_CHANCE
  g4.color = Color(0.15, 0.2, 0.55)
  g4.cut_color = Color(0.12, 0.2, 0.4)

  var g5 = GrassData.new()
  g5.grass_name = "황금풀"
  g5.max_health = 80
  g5.regen_time = 25.0
  g5.min_drop_value = 100
  g5.max_drop_value = 100
  g5.guaranteed_drop = true
  g5.color = Color(1.0, 0.85, 0.1)
  g5.cut_color = Color(0.7, 0.6, 0.1)

  grass_data_list.append(g0)
  grass_data_list.append(g1)
  grass_data_list.append(g2)
  grass_data_list.append(g3)
  grass_data_list.append(g4)
  grass_data_list.append(g5)

const GRASS_TYPE_NAMES: Array = ["새싹", "잔디", "여린풀", "강한풀", "초강풀"]

func get_random_grass_data() -> GrassData:
  if randf() < get_golden_grass_chance():
    return grass_data_list[5]

  var level = upgrade_levels.get("grass_quality", 0)
  var sub = upgrade_sub_levels.get("grass_quality", 0)

  var base_type = mini(level / 2, 4)

  if level >= 8:
    return grass_data_list[4]

  var is_first_half = (level % 2 == 0)
  var half_transition = float(sub) / 8.0 * 0.5

  if is_first_half:
    var next_chance = half_transition
    if randf() < next_chance:
      return grass_data_list[mini(base_type + 1, 4)]
    return grass_data_list[base_type]
  else:
    var next_chance = 0.5 + half_transition
    if randf() < next_chance:
      return grass_data_list[mini(base_type + 1, 4)]
    return grass_data_list[base_type]

func add_fury(amount: float) -> void:
  var fury_max = get_fury_max()
  fury = minf(fury + amount * get_fury_rate_mult(), fury_max)
  fury_changed.emit(fury)
  if fury >= fury_max:
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
  var level = upgrade_levels.get("attack_count", 0)
  var sub = upgrade_sub_levels.get("attack_count", 0)
  var sub_max = 3
  var count = 1
  for lv in range(level):
    count += (lv + 1) * sub_max
  if level < 5:
    count += (level + 1) * sub
  return count

func get_base_magnet_range() -> float:
  var ticks = get_skill_total_progress("magnet_range")
  return 40.0 + ticks * 4.0

func get_grass_density_value() -> int:
  var ticks = get_skill_total_progress("grass_density")
  if ticks <= 0:
    return 1
  var value = 0
  var remaining = ticks
  for lv in range(1, 9):
    var t = mini(remaining, 5)
    value += t * lv
    remaining -= t
    if remaining <= 0:
      break
  return 1 + value

func get_chest_spawn_chance() -> float:
  var ticks = get_skill_total_progress("chest_chance")
  return ticks * 0.002

func get_crit_chance() -> float:
  var ticks = get_skill_total_progress("crit_chance")
  return minf(ticks * 0.02, 0.8)

func get_crit_damage_mult() -> float:
  var ticks = get_skill_total_progress("crit_damage")
  return 1.2 + ticks * 0.06

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
  var level = upgrade_levels.get("golden_reward", 0)
  var sub = upgrade_sub_levels.get("golden_reward", 0)
  var sub_max = 5
  var mult = 1.0
  for lv in range(level):
    mult *= pow(1.0 + 0.10 + lv * 0.01, sub_max)
  if level < 5:
    mult *= pow(1.0 + 0.10 + level * 0.01, sub)
  return mult

func get_base_move_speed() -> float:
  var ticks = get_skill_total_progress("move_speed")
  return 300.0 + ticks * 10.0

func get_grass_density_level() -> int:
  return upgrade_levels.get("grass_density", 0)

func get_magnet_range() -> float:
  var base = get_base_magnet_range()
  var mult = 1.0 + session_buff_magnet_range * 0.5
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  return base * mult

func get_session_attack_speed_mult() -> float:
  var mult = 1.0 + session_buff_attack_speed * 0.25
  if timed_buffs.has("overdrive"):
    mult *= 2.0
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  if hit_penalty_active:
    mult *= 0.5
  return mult

func get_session_attack_range_mult() -> float:
  var mult = 1.0 + session_buff_attack_range * 0.25
  if timed_buffs.has("harvest_madness"):
    mult *= 1.5
  return mult

func get_session_move_speed_mult() -> float:
  var mult = 1.0 + session_buff_move_speed * 0.5
  if timed_buffs.has("overdrive"):
    mult *= 0.5
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  if hit_penalty_active:
    mult *= 0.5
  return mult

func get_session_time_bonus() -> float:
  return get_skill_total_progress("session_time") * 3.0

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

func get_monster_knockback_strength() -> float:
  return BASE_KNOCKBACK

func get_grass_drop_chance() -> float:
  return GRASS_DROP_CHANCE + upgrade_levels.get("grass_drop", 0) * 0.06

func get_total_skill_level() -> int:
  var total = 0
  for type in upgrade_levels:
    if type == "attack_power":
      continue
    total += upgrade_levels[type]
  return total

func get_grass_reward_multiplier() -> float:
  return 1.0 + upgrade_levels.get("grass_reward", 0) * 0.4

const WEAPON_SKILL_REQUIREMENTS = [0, 0, 2, 4, 7, 11, 16, 21, 27, 34]

const SKILL_PREREQS = {
  "attack_speed:1": [{"type": "attack_power", "level": 1}],
  "attack_range:1": [{"type": "attack_power", "level": 1}],
  "crit_chance:1": [{"type": "attack_speed", "level": 1}],
  "monster_damage:1": [{"type": "attack_range", "level": 1}],
  "crit_damage:1": [{"type": "crit_chance", "level": 1}],
  "grass_quality:1": [{"type": "grass_density", "level": 1}],
  "magnet_range:1": [{"type": "grass_density", "level": 1}],
  "golden_chance:1": [{"type": "grass_quality", "level": 1}],
  "attack_count:1": [{"type": "magnet_range", "level": 1}],
  "golden_reward:1": [{"type": "golden_chance", "level": 1}],
  "session_time:1": [{"type": "move_speed", "level": 1}],
  "chest_chance:1": [{"type": "move_speed", "level": 1}],
  "fury_rate:1": [{"type": "session_time_or_chest_chance", "level": 1}],
}

const SKILL_REQUIRED_TOTAL = {
  "attack_count:2": 3,
  "crit_damage:2": 3,
  "monster_damage:1": 20,
  "monster_damage:2": 3,
  "golden_reward:2": 3,
  "move_speed:2": 2,
  "chest_chance:1": 12,
  "fury_rate:1": 30,
  "fury_rate:2": 3,
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

const ROOT_TICK_COSTS: Array = [
  [1, 1],
  [12, 3],
  [300, 20],
  [80, 8],
  [150, 12],
  [280, 18],
  [500, 28],
  [850, 42],
  [1400, 65],
]
const DENSITY_TICK_COSTS: Array = [
  [0, 0],
  [15, 2],
  [300, 20],
  [180, 12],
  [300, 18],
  [500, 28],
  [850, 42],
  [1400, 65],
  [2300, 100],
  [3800, 150],
]
const QUALITY_COSTS: Array = [15, 35, 60, 400, 1000, 2500, 6000, 15000]
const ROW2_TICK_COSTS: Array = [
  [15, 2],
  [40, 5],
  [80, 8],
  [150, 12],
  [280, 20],
  [500, 35],
  [850, 55],
  [1400, 85],
  [2200, 130],
  [3500, 200],
  [5500, 300],
  [8500, 450],
]
const ROW3_TICK_COSTS: Array = [
  [50, 6],
  [120, 10],
  [220, 18],
  [400, 30],
  [700, 50],
  [1200, 80],
  [2000, 120],
  [3300, 190],
]
const GOLDEN_CHANCE_TICK_COSTS: Array = [
  [20, 2],
  [150, 30],
  [400, 60],
  [900, 120],
  [2000, 250],
]
const ROW4_TICK_COSTS: Array = [
  [50, 5],
  [100, 8],
  [180, 14],
  [320, 22],
  [550, 35],
  [950, 55],
  [1600, 85],
  [2700, 130],
  [4500, 200],
]
const TIER_ROOT: Array = ["attack_power", "move_speed"]
const TIER_DENSITY: Array = ["grass_density"]
const TIER_ROW2: Array = ["attack_speed", "attack_range", "magnet_range", "session_time", "chest_chance"]
const TIER_ROW3: Array = ["crit_chance", "monster_damage", "attack_count", "fury_rate"]

func get_upgrade_cost(current_level: int, upgrade_type: String = "") -> int:
  var cost = _get_raw_upgrade_cost(current_level, upgrade_type)
  var max_lvl = get_skill_max_level(upgrade_type)
  if max_lvl > 0:
    var threshold = int(max_lvl * 0.8)
    var user_level = current_level + 1
    if user_level >= threshold:
      var levels_over = user_level - threshold
      var base = int(5000 * pow(1.6, levels_over))
      var sub = upgrade_sub_levels.get(upgrade_type, 0)
      var sub_inc = int(base * 0.06)
      cost = maxi(cost, base + sub * sub_inc)
  return cost

func _get_raw_upgrade_cost(current_level: int, upgrade_type: String = "") -> int:
  var sub = upgrade_sub_levels.get(upgrade_type, 0)

  if current_level == 0 and upgrade_type == "grass_density":
    return sub / 2 + 1

  if upgrade_type == "grass_quality":
    if current_level == 0:
      return 15 + sub
    if current_level == 1:
      return 20 + sub
    if current_level == 2:
      return 80 + sub * 5
    if current_level == 3:
      return 400 + sub * 30
    if current_level == 4:
      return 1000 + sub * 80
    if current_level == 5:
      return 2500 + sub * 200
    if current_level == 6:
      return 6000 + sub * 500
    if current_level == 7:
      return 15000 + sub * 1200
    return 15000 + sub * 1200

  if upgrade_type == "move_speed" and current_level == 1:
    return 10 + sub

  if upgrade_type == "attack_range":
    if current_level == 0:
      return 10 + sub
    if current_level == 1:
      return 25 + sub * 2
    if current_level == 2:
      return 60 + sub * 3

  if upgrade_type == "attack_speed" and current_level == 2:
    return 120 + sub * 10

  if upgrade_type == "crit_chance" and current_level == 0:
    return 20 + sub * 2

  if upgrade_type == "attack_count" and current_level == 1:
    return 200 + sub * 20

  if upgrade_type == "session_time":
    if current_level == 0:
      return 20 + sub * 5
    if current_level == 1:
      return 200 + sub * 30

  var tier_costs: Array
  if upgrade_type == "golden_chance":
    tier_costs = GOLDEN_CHANCE_TICK_COSTS
  elif upgrade_type in TIER_DENSITY:
    tier_costs = DENSITY_TICK_COSTS
  elif upgrade_type in TIER_ROOT:
    tier_costs = ROOT_TICK_COSTS
  elif upgrade_type in TIER_ROW2:
    tier_costs = ROW2_TICK_COSTS
  elif upgrade_type in TIER_ROW3:
    tier_costs = ROW3_TICK_COSTS
  else:
    tier_costs = ROW4_TICK_COSTS

  if current_level < tier_costs.size():
    return tier_costs[current_level][0] + sub * tier_costs[current_level][1]
  var last = tier_costs[-1]
  var extra = current_level - tier_costs.size() + 1
  return int((last[0] + sub * last[1]) * pow(1.6, extra))

func purchase_upgrade(upgrade_type: String) -> bool:
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
    if upgrade_type == "attack_power":
      WeaponManager.current_weapon_level = next_level
      WeaponManager.weapon_changed.emit(next_level)
  upgrade_purchased.emit(upgrade_type, next_level)
  return true

func get_part_penalty_mult() -> float:
  return 1.0 - upgrade_levels.get("penalty_reduce", 0) * 0.25

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
    "selected_world": selected_world,
    "unlocked_worlds": unlocked_worlds,
    "owned_keys": owned_keys,
    "has_potion": has_potion,
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
  selected_world = data.get("selected_world", 0)
  var saved_worlds = data.get("unlocked_worlds", [0])
  unlocked_worlds = []
  for w in saved_worlds:
    unlocked_worlds.append(int(w))
  if 0 not in unlocked_worlds:
    unlocked_worlds.append(0)
  has_potion = data.get("has_potion", false)
  var saved_keys = data.get("owned_keys", [])
  owned_keys = []
  for k in saved_keys:
    owned_keys.append(int(k))
  world_strength_levels = {}
  var saved_strength = data.get("world_strength_levels", {})
  for k in saved_strength:
    world_strength_levels[int(k)] = int(saved_strength[k])
  money_changed.emit(money)
  WeaponManager.current_weapon_level = upgrade_levels.get("attack_power", 0)
  WeaponManager.weapon_changed.emit(WeaponManager.current_weapon_level)

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
