extends Node2D

@export var unit_scene: PackedScene
@export var player_spawn_center: Vector2 = Vector2(200, 300)
@export var enemy_spawn_center: Vector2 = Vector2(800, 300)
@export var spawn_radius: float = 300.0 # 반경도 조금 늘림
@export var unit_count_per_team: int = 600

func _ready():
	print("Spawner: Starting to spawn mixed units...")
	spawn_units(0, player_spawn_center, "players")
	spawn_units(1, enemy_spawn_center, "enemies")
	print("Spawner: Finished spawning units.")

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
