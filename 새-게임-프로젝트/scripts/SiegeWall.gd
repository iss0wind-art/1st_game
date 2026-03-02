extends StaticBody2D

@export var health: float = 2000.0
@export var is_gate: bool = false

func _ready():
	add_to_group("walls")
	update_visuals()

func take_damage(amount):
	health -= amount
	if health <= 0:
		die()

func die():
	# 성벽이 무너질 때 효과 (나중에 추가)
	queue_free()

func _draw():
	var size = Vector2(40, 100)
	var rect = Rect2(-size/2, size)
	
	if is_gate:
		draw_rect(rect, Color.SADDLE_BROWN)
		draw_rect(rect, Color.BLACK, false, 2.0)
	else:
		draw_rect(rect, Color.DIM_GRAY)
		draw_rect(rect, Color.GRAY, false, 2.0)

func update_visuals():
	queue_redraw()
