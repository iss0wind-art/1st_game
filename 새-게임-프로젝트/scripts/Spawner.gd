extends Node2D

@export var unit_scene: PackedScene
@export var siege_wall_scene: PackedScene # 새 성벽 씬
@export var player_spawn_center: Vector2 = Vector2(250, 324)
@export var enemy_spawn_center: Vector2 = Vector2(900, 324)
@export var spawn_radius: float = 300.0
@export var unit_count_per_team: int = 200

func _ready():
	print("Spawner: Starting to spawn units and walls...")
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
		if i == 3: # 중앙은 성문(Gate)으로 설정
			wall.is_gate = true
		add_child(wall)

func spawn_units(team: int, center: Vector2, group_name: String):
	for i in range(unit_count_per_team):
		var unit = unit_scene.instantiate()
		unit.team = team
		unit.add_to_group(group_name)
		
		# 70% 검사, 30% 궁수 비율로 생성
		if randf() > 0.7:
			unit.unit_class = 1 # Archer
		else:
			unit.unit_class = 0 # Swordman
		
		# 랜덤한 위치에 배치
		var angle = randf() * 2.0 * PI
		var dist = randf() * spawn_radius
		var spawn_pos = center + Vector2(cos(angle), sin(angle)) * dist
		
		unit.global_position = spawn_pos
		add_child(unit)
