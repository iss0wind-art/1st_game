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
		draw_rect(rect, Color.ORANGE, false, 2.0)
		# 성문 문양 (X자)
		draw_line(Vector2(-10, -20), Vector2(10, 20), Color.BLACK, 1.0)
		draw_line(Vector2(10, -20), Vector2(-10, 20), Color.BLACK, 1.0)
	else:
		draw_rect(rect, Color.DIM_GRAY)
		draw_rect(rect, Color.GRAY, false, 2.0)
	
	# 체력바 표시
	var max_hp = 5000.0 if is_gate else 2000.0
	var health_pct = clamp(health / max_hp, 0.0, 1.0)
	draw_line(Vector2(-15, -60), Vector2(15, -60), Color.RED, 4.0)
	draw_line(Vector2(-15, -60), Vector2(-15 + 30 * health_pct, -60), Color.GREEN, 4.0)

func update_visuals():
	queue_redraw()
