extends CharacterBody2D

enum UnitClass { SWORDMAN, ARCHER }

@export var unit_class: UnitClass = UnitClass.SWORDMAN
@export var speed: float = 100.0
@export var health: float = 100.0
@export var attack_range: float = 20.0
@export var damage: float = 10.0
@export var team: int = 0 # 0 for Player, 1 for Enemy

var target: Node2D = null
var color: Color = Color.WHITE
var attack_timer: float = 0.0
var attack_cooldown: float = 1.0

# 최적화용 변수
var ai_update_timer: float = 0.0
var ai_update_interval: float = 0.2 # 0.2초마다 AI 갱신

func _ready():
	# AI 업데이트 주기를 랜덤하게 분산 (중요!)
	ai_update_timer = randf() * ai_update_interval
	
	if team == 0:
		color = Color.CORNFLOWER_BLUE
	else:
		color = Color.INDIAN_RED
	
	# 병종별 속성 설정
	match unit_class:
		UnitClass.SWORDMAN:
			speed = 120.0
			attack_range = 25.0
			damage = 15.0
		UnitClass.ARCHER:
			speed = 90.0
			attack_range = 250.0
			damage = 8.0
			attack_cooldown = 1.5

func _draw():
	# 졸라맨 그리기
	var head_pos = Vector2(0, -15)
	var body_top = Vector2(0, -10)
	var body_bottom = Vector2(0, 5)
	
	# 머리
	draw_circle(head_pos, 5, color)
	# 몸통
	draw_line(body_top, body_bottom, color, 2.0)
	# 팔 (간단히)
	draw_line(Vector2(-8, -5), Vector2(8, -5), color, 2.0)
	# 다리
	draw_line(body_bottom, Vector2(-6, 15), color, 2.0)
	draw_line(body_bottom, Vector2(6, 15), color, 2.0)
	
	# 병종 표시 (무기 등)
	if unit_class == UnitClass.ARCHER:
		draw_arc(Vector2(5, -5), 8, -PI/2, PI/2, 8, color, 1.5) # 활 모양

func _physics_process(delta):
	if health <= 0:
		queue_free()
		return

	attack_timer -= delta
	ai_update_timer -= delta
	
	# AI 무거운 연산들은 일정 주기마다 처리
	if ai_update_timer <= 0:
		ai_update_timer = ai_update_interval
		if target == null or not is_instance_valid(target):
			find_closest_target()
		
		# 분리 벡터 미리 계산 (이동 시 활용)
		cached_separation = get_separation_vector()
	
	if target:
		var distance = global_position.distance_to(target.global_position)
		var direction = (target.global_position - global_position).normalized()
		
		# 캐싱된 분리 벡터 적용
		direction = (direction + cached_separation * 1.5).normalized()
		
		if distance > attack_range:
			velocity = direction * speed
			move_and_slide()
		else:
			# 공격 중에도 살짝 비켜주기
			velocity = cached_separation * (speed * 0.5)
			move_and_slide()
			if attack_timer <= 0:
				perform_attack()
				attack_timer = attack_cooldown

var cached_separation: Vector2 = Vector2.ZERO

func get_separation_vector() -> Vector2:
	var separation_vector = Vector2.ZERO
	# 모든 유닛 대신 근처 그룹만 검색하는 것이 좋지만, 현재는 간단히 제한만 둠
	var neighbors = get_tree().get_nodes_in_group("players" if team == 0 else "enemies")
	var neighbor_count = 0
	
	for neighbor in neighbors:
		if neighbor == self: continue
		var dist = global_position.distance_to(neighbor.global_position)
		if dist < 25.0: # 범위를 약간 줄임
			separation_vector += (global_position - neighbor.global_position).normalized() / (max(0.1, dist) / 25.0)
			neighbor_count += 1
			if neighbor_count > 3: break # 더 줄임
			
	return separation_vector.normalized()

func perform_attack():
	if not target or not is_instance_valid(target): return
	
	if unit_class == UnitClass.SWORDMAN:
		if target.has_method("take_damage"):
			target.take_damage(damage)
	elif unit_class == UnitClass.ARCHER:
		# 화살 발사 시각화 대신 즉시 데미지 (나중에 투사체 추가)
		if target.has_method("take_damage"):
			target.take_damage(damage)

func find_closest_target():
	var groups = ["enemies"] if team == 0 else ["players"]
	var closest_dist = INF
	var closest_target = null
	
	for group in groups:
		for member in get_tree().get_nodes_in_group(group):
			var dist = global_position.distance_to(member.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_target = member
	
	# 적군(Team 1)의 경우, 플레이어 유닛이 없으면 성벽을 타겟으로 잡음
	if team == 1 and closest_target == null:
		for wall in get_tree().get_nodes_in_group("walls"):
			var dist = global_position.distance_to(wall.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_target = wall
	
	target = closest_target

func take_damage(amount):
	health -= amount
	# 데미지 입을 때 살짝 깜빡임 효과 등 추가 가능
