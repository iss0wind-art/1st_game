extends Node2D

@export var unit_scene: PackedScene
@export var siege_wall_scene: PackedScene
@export var player_spawn_center: Vector2 = Vector2(250, 324)
@export var enemy_spawn_center: Vector2 = Vector2(900, 324)
@export var spawn_radius: float = 300.0
@export var unit_count_per_team: int = 200

func _ready():
	print("Spawner: Starting to spawn diverse units and walls...")
	spawn_siege_walls()
	spawn_units(0, player_spawn_center, "players")
	spawn_units(1, enemy_spawn_center, "enemies")
	print("Spawner: Finished spawning.")

func spawn_siege_walls():
	var screen_height = 648
	var wall_count = 7
	var spacing = screen_height / wall_count
	
	for i in range(wall_count):
		if i == 3: continue # 중앙 성문(Gate)은 열어서 통로 확보
		var wall = siege_wall_scene.instantiate()
		wall.global_position = Vector2(576, i * spacing + spacing/2)
		add_child(wall)

func spawn_units(team: int, center: Vector2, group_name: String):
	for i in range(unit_count_per_team):
		var unit = unit_scene.instantiate()
		unit.team = team
		unit.safe_zone = center # 본능적으로 돌아갈 안전구역 설정
		unit.add_to_group(group_name)
		
		# 유닛 비율 설정
		var roll = randf()
		if roll < 0.3: # 30% 전투병 (Sword, Spear, Archer)
			var combat_roll = randf()
			if combat_roll < 0.4: unit.unit_class = 0 # Sword
			elif combat_roll < 0.7: unit.unit_class = 1 # Spear
			else: unit.unit_class = 2 # Archer
		elif roll < 0.4: # 10% 기병/기사/성직자
			var elite_roll = randf()
			if elite_roll < 0.3: unit.unit_class = 3 # Cavalry
			elif elite_roll < 0.8: unit.unit_class = 4 # Knight (비율 증가)
			else: unit.unit_class = 5 # Priest
		else: # 60% 시민 (남, 여, 아이, 노인)
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
