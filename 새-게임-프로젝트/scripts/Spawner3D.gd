extends Node3D

@export var unit_scene: PackedScene = preload("res://scenes/Unit3D.tscn")
@export var hill_scene: PackedScene = preload("res://scenes/Hill3D.tscn")
@export var river_scene: PackedScene = preload("res://scenes/River3D.tscn")
@export var spawn_count: int = 50

func _ready():
	spawn_terrain()
	spawn_battle()

func spawn_terrain():
	# 강 배치 (중앙 관통)
	if river_scene:
		var river = river_scene.instantiate()
		river.position = Vector3(0, 0, 0)
		add_child(river)
		
	# 언덕 배치 (랜덤 3~4개)
	if hill_scene:
		for i in range(3 + randi() % 2):
			var hill = hill_scene.instantiate()
			hill.position = Vector3(randf_range(-30, 30), 0, randf_range(-20, 20))
			add_child(hill)

func spawn_battle():
	# Team 0 (Blue) - Left Side
	for i in range(spawn_count):
		var unit = unit_scene.instantiate()
		unit.team = 0
		unit.position = Vector3(-20 - randf() * 10, 0, (randf() - 0.5) * 30)
		# 랜덤 병종 부여 (전투병 중심)
		var roll = randf()
		if roll < 0.6: unit.unit_class = 0 # Swordman
		elif roll < 0.9: unit.unit_class = 2 # Archer
		else: unit.unit_class = 8 # Supply Wagon
		add_child(unit)
		
	# Team 1 (Red) - Right Side
	for i in range(spawn_count):
		var unit = unit_scene.instantiate()
		unit.team = 1
		unit.position = Vector3(20 + randf() * 10, 0, (randf() - 0.5) * 30)
		var roll = randf()
		if roll < 0.6: unit.unit_class = 0
		elif roll < 0.9: unit.unit_class = 2
		else: unit.unit_class = 8
		add_child(unit)
