extends Area2D

enum TerrainType { HILL, RIVER }
@export var terrain_type: TerrainType = TerrainType.HILL

var is_flooding: bool = false
var overlapping_units: Array = []

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta):
	# 범람 중일 때 강에 있는 유닛들에게 초당 데미지
	if terrain_type == TerrainType.RIVER and is_flooding:
		for unit in overlapping_units:
			if is_instance_valid(unit) and unit.has_method("take_damage"):
				unit.take_damage(10.0 * delta) # 초당 10 데미지

func set_flood(status: bool):
	is_flooding = status
	if is_flooding:
		modulate = Color(1, 0.5, 0.5, 1) # 범람 시 붉은 빛
	else:
		modulate = Color(1, 1, 1, 1)

func _on_body_entered(body):
	if body.has_method("setup_class_stats"): 
		overlapping_units.append(body)
		match terrain_type:
			TerrainType.HILL:
				body.current_elevation = 1
			TerrainType.RIVER:
				body.is_in_water = true
		body.queue_redraw()

func _on_body_exited(body):
	if body.has_method("setup_class_stats"):
		overlapping_units.erase(body)
		match terrain_type:
			TerrainType.HILL:
				body.current_elevation = 0
			TerrainType.RIVER:
				body.is_in_water = false
		body.queue_redraw()
