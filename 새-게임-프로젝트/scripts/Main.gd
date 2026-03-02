extends Node2D

var flood_timer: float = 0.0
var flood_interval: float = 20.0 # 20초마다 범람 시도
var is_flooding: bool = false
var flood_duration: float = 5.0 # 5초간 지속

func _process(delta):
	flood_timer += delta
	if not is_flooding and flood_timer >= flood_interval:
		start_flood()
	elif is_flooding and flood_timer >= flood_duration:
		stop_flood()

func start_flood():
	is_flooding = true
	flood_timer = 0
	print("!!! FLOODING STARTED !!!")
	# 강 유닛들에게 범람 알림
	for river in get_tree().get_nodes_in_group("rivers"):
		if river.has_method("set_flood"):
			river.set_flood(true)

func stop_flood():
	is_flooding = false
	flood_timer = 0
	print("Flood subsided.")
	for river in get_tree().get_nodes_in_group("rivers"):
		if river.has_method("set_flood"):
			river.set_flood(false)
