extends CharacterBody2D

enum UnitClass { SWORDMAN, SPEARMAN, ARCHER, CAVALRY, KNIGHT, PRIEST, CITIZEN, SIEGE }
enum CitizenType { MALE, FEMALE, CHILD, OLD }

@export var unit_class: UnitClass = UnitClass.SWORDMAN
@export var citizen_type: CitizenType = CitizenType.MALE
@export var team: int = 0 # 0 for Player, 1 for Enemy

# 기본 속성
var speed: float = 100.0
var health: float = 100.0
var attack_range: float = 20.0
var damage: float = 10.0
var attack_cooldown: float = 1.0

# 상태 및 타이머
var target: Node2D = null
var color: Color = Color.WHITE
var attack_timer: float = 0.0
var ai_update_timer: float = 0.0
var ai_update_interval: float = 0.2
var aging_timer: float = 30.0 # 아이가 어른이 되는 시간 (30초)
var rage_timer: float = 0.0 # 분노 버프 지속 시간

# 최적화
var cached_separation: Vector2 = Vector2.ZERO

func _ready():
	ai_update_timer = randf() * ai_update_interval
	setup_class_stats()
	
	if team == 0:
		color = Color.CORNFLOWER_BLUE
	else:
		color = Color.INDIAN_RED
	
	# 아이 유닛의 경우 크기를 작게 (임시)
	if unit_class == UnitClass.CITIZEN and citizen_type == CitizenType.CHILD:
		scale = Vector2(0.6, 0.6)

func setup_class_stats():
	match unit_class:
		UnitClass.SWORDMAN:
			speed = 120.0; attack_range = 25.0; damage = 15.0; health = 100.0
		UnitClass.SPEARMAN:
			speed = 100.0; attack_range = 45.0; damage = 12.0; health = 110.0
		UnitClass.ARCHER:
			speed = 90.0; attack_range = 250.0; damage = 8.0; health = 80.0; attack_cooldown = 1.5
		UnitClass.CAVALRY:
			speed = 220.0; attack_range = 35.0; damage = 20.0; health = 150.0; attack_cooldown = 1.2
		UnitClass.KNIGHT:
			speed = 130.0; attack_range = 30.0; damage = 25.0; health = 200.0; attack_cooldown = 0.8
		UnitClass.PRIEST:
			speed = 100.0; attack_range = 150.0; damage = -10.0; health = 80.0 # 데미지 음수는 힐
		UnitClass.CITIZEN:
			speed = 80.0; attack_range = 0.0; damage = 0.0; health = 50.0
			if citizen_type == CitizenType.CHILD: health = 30.0
		UnitClass.SIEGE:
			speed = 40.0; attack_range = 300.0; damage = 50.0; health = 300.0; attack_cooldown = 3.0

func _draw():
	# 졸라맨 기본 그리기
	var head_pos = Vector2(0, -15)
	var body_top = Vector2(0, -10)
	var body_bottom = Vector2(0, 5)
	
	# 머리
	draw_circle(head_pos, 5, color)
	# 몸통
	draw_line(body_top, body_bottom, color, 2.0)
	# 팔
	draw_line(Vector2(-8, -5), Vector2(8, -5), color, 2.0)
	# 다리
	draw_line(body_bottom, Vector2(-6, 15), color, 2.0)
	draw_line(body_bottom, Vector2(6, 15), color, 2.0)
	
	# 병종별 시각적 구분 (임시)
	match unit_class:
		UnitClass.ARCHER:
			draw_arc(Vector2(5, -5), 8, -PI/2, PI/2, 8, color, 1.5)
		UnitClass.KNIGHT:
			draw_rect(Rect2(-10, -20, 20, 25), color, false, 1.5) # 갑옷 느낌
		UnitClass.CAVALRY:
			draw_line(Vector2(-15, 10), Vector2(15, 10), color, 3.0) # 말 느낌
		UnitClass.CITIZEN:
			if citizen_type == CitizenType.FEMALE:
				draw_line(Vector2(-8, 5), Vector2(8, 5), color, 1.5) # 치마 느낌

func _physics_process(delta):
	if health <= 0:
		handle_death()
		return

	# 성장 시스템 (아이 -> 성인)
	if unit_class == UnitClass.CITIZEN and citizen_type == CitizenType.CHILD:
		aging_timer -= delta
		if aging_timer <= 0:
			grow_up()

	# 분노 버프 처리
	if rage_timer > 0:
		rage_timer -= delta
		# 버프 효과는 일시적으로 스피드/공격력 상승 (간단히 적용)

	attack_timer -= delta
	ai_update_timer -= delta
	
	if ai_update_timer <= 0:
		ai_update_timer = ai_update_interval
		if target == null or not is_instance_valid(target):
			find_closest_target()
		cached_separation = get_separation_vector()
	
	if target:
		var distance = global_position.distance_to(target.global_position)
		var direction = (target.global_position - global_position).normalized()
		
		# 분노 시 이속 증가
		var current_speed = speed * (1.5 if rage_timer > 0 else 1.0)
		
		# 분리 로직 적용
		direction = (direction + cached_separation * 1.5).normalized()
		
		if distance > attack_range:
			velocity = direction * current_speed
			move_and_slide()
		else:
			velocity = cached_separation * (current_speed * 0.5)
			move_and_slide()
			if attack_timer <= 0 and attack_range > 0:
				perform_attack()
				attack_timer = attack_cooldown * (0.7 if rage_timer > 0 else 1.0)

func handle_death():
	# 아이나 노인이 죽으면 주변 아군 분노 유발
	if unit_class == UnitClass.CITIZEN and (citizen_type == CitizenType.CHILD or citizen_type == CitizenType.OLD):
		trigger_rage_for_allies()
	
	queue_free()

func trigger_rage_for_allies():
	var group = "players" if team == 0 else "enemies"
	for ally in get_tree().get_nodes_in_group(group):
		if ally.has_method("apply_rage"):
			ally.apply_rage(10.0) # 10초간 분노

func apply_rage(duration):
	rage_timer = duration
	print("Unit [", name, "] is ENRAGED!")

func grow_up():
	print("A child grew up into an adult!")
	unit_class = UnitClass.CITIZEN
	citizen_type = CitizenType.MALE if randf() > 0.5 else CitizenType.FEMALE
	scale = Vector2(1.0, 1.0)
	setup_class_stats()
	queue_redraw()

func perform_attack():
	if not target or not is_instance_valid(target): return
	
	var final_damage = damage * (1.5 if rage_timer > 0 else 1.0)
	
	if target.has_method("take_damage"):
		target.take_damage(final_damage)

func find_closest_target():
	if unit_class == UnitClass.CITIZEN: 
		# 시민은 공격 타겟을 잡지 않음 (나중에 도망가는 로직 추가 가능)
		target = null
		return

	var groups = ["enemies"] if team == 0 else ["players"]
	var closest_dist = INF
	var closest_target = null
	
	for group in groups:
		for member in get_tree().get_nodes_in_group(group):
			var dist = global_position.distance_to(member.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_target = member
	
	# 플레이어 유닛 없으면 성벽 공격
	if team == 1 and closest_target == null:
		for wall in get_tree().get_nodes_in_group("walls"):
			var dist = global_position.distance_to(wall.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_target = wall
	
	target = closest_target

func take_damage(amount):
	health -= amount

func get_separation_vector() -> Vector2:
	var separation_vector = Vector2.ZERO
	var neighbors = get_tree().get_nodes_in_group("players" if team == 0 else "enemies")
	var neighbor_count = 0
	
	for neighbor in neighbors:
		if neighbor == self: continue
		var dist = global_position.distance_to(neighbor.global_position)
		if dist < 25.0:
			separation_vector += (global_position - neighbor.global_position).normalized() / (max(0.1, dist) / 25.0)
			neighbor_count += 1
			if neighbor_count > 3: break
			
	return separation_vector.normalized()
