extends Area2D

@export var speed: float = 400.0
@export var damage: float = 10.0
var target_team: int = -1
var direction: Vector2 = Vector2.ZERO

func _ready():
	# 화살이 생성되면 5초 후 자동 제거
	get_tree().create_timer(5.0).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _draw():
	# 화살 시각화 (간단한 선과 화살표 머리)
	draw_line(Vector2(-5, 0), Vector2(5, 0), Color.WHITE, 1.0)
	draw_line(Vector2(5, 0), Vector2(2, -2), Color.WHITE, 1.0)
	draw_line(Vector2(5, 0), Vector2(2, 2), Color.WHITE, 1.0)

var attacker_pos: Vector2 = Vector2.ZERO

func _physics_process(delta):
	position += direction * speed * delta
	rotation = direction.angle()

func _on_body_entered(body):
	if body.has_method("take_damage_from") or body.has_method("take_damage"):
		if body.get("team") != null and body.team != target_team:
			return 
		
		if body.has_method("take_damage_from"):
			body.take_damage_from(damage, attacker_pos)
		else:
			body.take_damage(damage)
			
		queue_free()

func setup(start_pos: Vector2, target_pos: Vector2, team_id: int, dmg: float, fire_pos: Vector2):
	global_position = start_pos
	attacker_pos = fire_pos
	direction = (target_pos - start_pos).normalized()
	target_team = 1 if team_id == 0 else 0
	damage = dmg
	rotation = direction.angle()
