extends CharacterBody2D

enum UnitClass { SWORDMAN, SPEARMAN, ARCHER, CAVALRY, KNIGHT, PRIEST, CITIZEN, SIEGE }
enum CitizenType { MALE, FEMALE, CHILD, OLD }

@export var unit_class: UnitClass = UnitClass.SWORDMAN
@export var citizen_type: CitizenType = CitizenType.MALE
@export var team: int = 0 

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
var aging_timer: float = 30.0 
var rage_timer: float = 0.0 

# 애니메이션 변수
var walk_timer: float = 0.0
var walk_speed: float = 10.0
var attack_anim_progress: float = 0.0 # 0.0 to 1.0

# 최적화
var cached_separation: Vector2 = Vector2.ZERO

func _ready():
	ai_update_timer = randf() * ai_update_interval
	setup_class_stats()
	
	if team == 0:
		color = Color.CORNFLOWER_BLUE
	else:
		color = Color.INDIAN_RED
	
	if unit_class == UnitClass.CITIZEN and citizen_type == CitizenType.CHILD:
		scale = Vector2(0.6, 0.6)

func setup_class_stats():
	match unit_class:
		UnitClass.SWORDMAN:
			speed = 120.0; attack_range = 25.0; damage = 15.0; health = 100.0
		UnitClass.SPEARMAN:
			speed = 100.0; attack_range = 45.0; damage = 12.0; health = 110.0
		UnitClass.ARCHER:
			speed = 90.0; attack_range = 250.0; damage = 8.0; health = 80.0; attack_cooldown = 1.8
		UnitClass.CAVALRY:
			speed = 220.0; attack_range = 35.0; damage = 20.0; health = 150.0; attack_cooldown = 1.2
		UnitClass.KNIGHT:
			speed = 130.0; attack_range = 30.0; damage = 25.0; health = 200.0; attack_cooldown = 0.8
		UnitClass.PRIEST:
			speed = 100.0; attack_range = 150.0; damage = -10.0; health = 80.0 
		UnitClass.CITIZEN:
			speed = 80.0; attack_range = 0.0; damage = 0.0; health = 50.0
			if citizen_type == CitizenType.CHILD: health = 30.0
		UnitClass.SIEGE:
			speed = 40.0; attack_range = 300.0; damage = 50.0; health = 300.0; attack_cooldown = 3.0

func _draw():
	# 애니메이션 값 계산
	var leg_swing = sin(walk_timer * walk_speed) * 8.0 if velocity.length() > 5 else 0.0
	var arm_swing = cos(walk_timer * walk_speed) * 6.0 if velocity.length() > 5 else 0.0
	
	# 공격 애니메이션 보정
	var attack_offset = Vector2.ZERO
	if attack_anim_progress > 0:
		attack_offset = Vector2(8, 0).rotated(rotation) * sin(attack_anim_progress * PI)

	var head_pos = Vector2(0, -15) + attack_offset * 0.2
	var body_top = Vector2(0, -10)
	var body_bottom = Vector2(0, 5)
	
	# 몸통 (공격 시 살짝 기울어짐)
	var tilt = attack_offset.x * 0.1
	draw_line(body_top, body_bottom + Vector2(tilt, 0), color, 2.5)
	
	# 머리
	draw_circle(head_pos, 5, color)
	
	# 팔 그리기
	var left_arm_end = Vector2(-8, -5) + Vector2(0, arm_swing)
	var right_arm_end = Vector2(8, -5) - Vector2(0, arm_swing)
	
	if attack_anim_progress > 0:
		if unit_class == UnitClass.ARCHER:
			# 활 쏘는 자세
			left_arm_end = Vector2(10, -5) # 활 잡은 손
			right_arm_end = Vector2(-5, -5) # 시위 당기는 손 (당겨지는 표현)
			right_arm_end.x -= sin(attack_anim_progress * PI) * 5
		else:
			# 휘두르는 자세
			right_arm_end += attack_offset * 2.0
	
	draw_line(Vector2(0, -8), left_arm_end, color, 2.0)
	draw_line(Vector2(0, -8), right_arm_end, color, 2.0)
	
	# 다리 그리기
	draw_line(body_bottom, body_bottom + Vector2(-6 + leg_swing, 10), color, 2.0)
	draw_line(body_bottom, body_bottom + Vector2(6 - leg_swing, 10), color, 2.0)
	
	# 무기/특징 그리기
	match unit_class:
		UnitClass.ARCHER:
			var bow_center = left_arm_end + Vector2(2, 0)
			var bow_pull = sin(attack_anim_progress * PI) * 4
			draw_arc(bow_center, 10, -PI/2, PI/2, 8, color, 1.5) # 활
			# 시위
			draw_line(bow_center + Vector2(0, -10), bow_center + Vector2(-bow_pull, 0), color, 0.5)
			draw_line(bow_center + Vector2(-bow_pull, 0), bow_center + Vector2(0, 10), color, 0.5)
		UnitClass.SWORDMAN, UnitClass.KNIGHT:
			var sword_pos = right_arm_end
			draw_line(sword_pos, sword_pos + Vector2(0, -12).rotated(attack_anim_progress * PI), color, 2.0) # 검
		UnitClass.CITIZEN:
			if citizen_type == CitizenType.FEMALE:
				draw_line(Vector2(-8, 5), Vector2(8, 5), color, 1.5)

func _physics_process(delta):
	if health <= 0:
		handle_death()
		return

	# 애니메이션 타이머
	if velocity.length() > 5:
		walk_timer += delta
	else:
		walk_timer = 0
	
	if attack_anim_progress > 0:
		attack_anim_progress -= delta * 2.0 # 애니메이션 속도
	
	# 성장 시스템
	if unit_class == UnitClass.CITIZEN and citizen_type == CitizenType.CHILD:
		aging_timer -= delta
		if aging_timer <= 0:
			grow_up()

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
				attack_anim_progress = 1.0 # 애니메이션 시작
	
	queue_redraw() # 매 프레임 다시 그리기 (애니메이션을 위해)

func handle_death():
	if unit_class == UnitClass.CITIZEN and (citizen_type == CitizenType.CHILD or citizen_type == CitizenType.OLD):
		trigger_rage_for_allies()
	queue_free()

func trigger_rage_for_allies():
	var group = "players" if team == 0 else "enemies"
	for ally in get_tree().get_nodes_in_group(group):
		if ally.has_method("apply_rage"):
			ally.apply_rage(10.0) 

func apply_rage(duration):
	rage_timer = duration

func grow_up():
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
