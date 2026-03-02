extends Node2D

@export var unit_scene: PackedScene
@export var siege_wall_scene: PackedScene
@export var arrow_scene: PackedScene # 화살 씬 추가
@export var player_spawn_center: Vector2 = Vector2(250, 324)
@export var enemy_spawn_center: Vector2 = Vector2(900, 324)
@export var spawn_radius: float = 300.0
@export var unit_count_per_team: int = 200

func _ready():
	print("Spawner: Starting to spawn diverse units with arrows...")
	spawn_siege_walls()
	spawn_units(0, player_spawn_center, "players")
	spawn_units(1, enemy_spawn_center, "enemies")
	print("Spawner: Finished spawning.")

func spawn_siege_walls():
	var screen_height = 648
	var wall_count = 7
	var spacing = screen_height / wall_count
	
	for i in range(wall_count):
		var wall = siege_wall_scene.instantiate()
		wall.global_position = Vector2(576, i * spacing + spacing/2)
		if i == 3: # 중앙 성문(Gate) 설정
			wall.is_gate = true
			wall.health = 5000.0 # 성문은 더 튼튼함
		add_child(wall)

func spawn_units(team: int, center: Vector2, group_name: String):
	for i in range(unit_count_per_team):
		var unit = unit_scene.instantiate()
		unit.team = team
		unit.safe_zone = center 
		unit.arrow_scene = arrow_scene # 화살 씬 전달
		unit.add_to_group(group_name)
		
		# 유닛 비율 조정 (한명당 200명 기준)
		var roll = randf()
		if roll < 0.45: # 45% 전투병 (전투 비중 상향)
			var combat_roll = randf()
			if combat_roll < 0.5: unit.unit_class = 0 # Swordman
			elif combat_roll < 0.7: unit.unit_class = 1 # Spearman
			else: unit.unit_class = 2 # Archer
		elif roll < 0.60: # 15% 엘리트, 보급 및 중기계
			var elite_roll = randf()
			if elite_roll < 0.2: unit.unit_class = 3 # Cavalry
			elif elite_roll < 0.3: unit.unit_class = 4 # HERO KNIGHT
			elif elite_roll < 0.5: unit.unit_class = 5 # Priest
			elif elite_roll < 0.8: unit.unit_class = 8 # SUPPLY WAGON (보급 수레)
			else: unit.unit_class = 7 # Siege Engine
		else: # 40% 시민 및 노동력
			unit.unit_class = 6 # Citizen
			var citizen_roll = randf()
			if citizen_roll < 0.3: unit.citizen_type = 0 # Male
			elif citizen_roll < 0.6: unit.citizen_type = 1 # Female
			elif citizen_roll < 0.8: unit.citizen_type = 2 # Child
			else: unit.citizen_type = 3 # Old
		
		# 랜덤 위치 배치
		var angle = randf() * 2.0 * PI
		var dist = randf() * spawn_radius
		var spawn_pos = center + Vector2(cos(angle), sin(angle)) * dist
		
		unit.global_position = spawn_pos
		add_child(unit)
