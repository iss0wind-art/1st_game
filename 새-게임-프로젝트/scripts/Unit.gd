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

# 사기(Morale) 시스템
var morale_timer: float = 0.0 
var morale_type: int = 0 # 1: Buff, -1: Debuff, 0: Normal

# 일기토(Duel) 시스템
var is_dueling: bool = false
var duel_target: Node2D = null

# 애니메이션 변수
var walk_timer: float = 0.0
var walk_speed: float = 10.0
var attack_anim_progress: float = 0.0

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
			speed = 130.0; attack_range = 30.0; damage = 25.0; health = 220.0; attack_cooldown = 0.8
		UnitClass.PRIEST:
			speed = 100.0; attack_range = 150.0; damage = -10.0; health = 80.0 
		UnitClass.CITIZEN:
			speed = 80.0; attack_range = 0.0; damage = 0.0; health = 50.0
			if citizen_type == CitizenType.CHILD: health = 30.0
		UnitClass.SIEGE:
			speed = 40.0; attack_range = 300.0; damage = 50.0; health = 300.0; attack_cooldown = 3.0

func _draw():
	# 상태에 따른 아우라 효과
	if rage_timer > 0:
		draw_circle(Vector2(0, 0), 20, Color(1, 0, 0, 0.2)) # 분노: 빨간 아우라
	if morale_type == 1:
		draw_circle(Vector2(0, 0), 20, Color(1, 0.8, 0, 0.3)) # 승리사기: 황금색 아우라
	elif morale_type == -1:
		draw_circle(Vector2(0, 0), 20, Color(0.5, 0.5, 0.5, 0.3)) # 패배사기: 회색 아우라
	if is_dueling:
		draw_arc(Vector2(0, -25), 5, 0, TAU, 32, Color.GOLD, 1.0) # 일기토 중: 머리 위 골든 링

	# 애니메이션 값 계산
	var leg_swing = sin(walk_timer * walk_speed) * 8.0 if velocity.length() > 5 else 0.0
	var arm_swing = cos(walk_timer * walk_speed) * 6.0 if velocity.length() > 5 else 0.0
	
	var attack_offset = Vector2.ZERO
	if attack_anim_progress > 0:
		attack_offset = Vector2(8, 0).rotated(rotation) * sin(attack_anim_progress * PI)

	var head_pos = Vector2(0, -15) + attack_offset * 0.2
	var body_top = Vector2(0, -10)
	var body_bottom = Vector2(0, 5)
	
	var tilt = attack_offset.x * 0.1
	draw_line(body_top, body_bottom + Vector2(tilt, 0), color, 2.5)
	draw_circle(head_pos, 5, color)
	
	var left_arm_end = Vector2(-8, -5) + Vector2(0, arm_swing)
	var right_arm_end = Vector2(8, -5) - Vector2(0, arm_swing)
	
	if attack_anim_progress > 0:
		if unit_class == UnitClass.ARCHER:
			left_arm_end = Vector2(10, -5)
			right_arm_end = Vector2(-5, -5)
			right_arm_end.x -= sin(attack_anim_progress * PI) * 5
		else:
			right_arm_end += attack_offset * 2.0
	
	draw_line(Vector2(0, -8), left_arm_end, color, 2.0)
	draw_line(Vector2(0, -8), right_arm_end, color, 2.0)
	draw_line(body_bottom, body_bottom + Vector2(-6 + leg_swing, 10), color, 2.0)
	draw_line(body_bottom, body_bottom + Vector2(6 - leg_swing, 10), color, 2.0)
	
	match unit_class:
		UnitClass.ARCHER:
			var bow_center = left_arm_end + Vector2(2, 0)
			var bow_pull = sin(attack_anim_progress * PI) * 4
			draw_arc(bow_center, 10, -PI/2, PI/2, 8, color, 1.5)
			draw_line(bow_center + Vector2(0, -10), bow_center + Vector2(-bow_pull, 0), color, 0.5)
			draw_line(bow_center + Vector2(-bow_pull, 0), bow_center + Vector2(0, 10), color, 0.5)
		UnitClass.SWORDMAN, UnitClass.KNIGHT:
			var sword_pos = right_arm_end
			var sword_len = 12 if unit_class == UnitClass.SWORDMAN else 18
			draw_line(sword_pos, sword_pos + Vector2(0, -sword_len).rotated(attack_anim_progress * PI), color, 2.0)
		UnitClass.KNIGHT:
			draw_rect(Rect2(-10, -20, 20, 25), color, false, 1.5)
		UnitClass.CAVALRY:
			draw_line(Vector2(-15, 10), Vector2(15, 10), color, 3.0)
		UnitClass.CITIZEN:
			if citizen_type == CitizenType.FEMALE:
				draw_line(Vector2(-8, 5), Vector2(8, 5), color, 1.5)

func _physics_process(delta):
	if health <= 0:
		handle_death()
		return

	# 각종 타이머 처리
	if velocity.length() > 5: walk_timer += delta
	else: walk_timer = 0
	
	if attack_anim_progress > 0: attack_anim_progress -= delta * 2.0
	if rage_timer > 0: rage_timer -= delta
	if morale_timer > 0: 
		morale_timer -= delta
		if morale_timer <= 0: morale_type = 0
	
	if unit_class == UnitClass.CITIZEN and citizen_type == CitizenType.CHILD:
		aging_timer -= delta
		if aging_timer <= 0: grow_up()

	attack_timer -= delta
	ai_update_timer -= delta
	
	if ai_update_timer <= 0:
		ai_update_timer = ai_update_interval
		if not is_dueling:
			find_closest_target()
		cached_separation = get_separation_vector()
	
	# 일기토 중인 경우 타겟 고정
	if is_dueling and (not is_instance_valid(duel_target) or duel_target.health <= 0):
		is_dueling = false
		duel_target = null
	
	var current_target = duel_target if is_dueling else target
	
	if current_target:
		var distance = global_position.distance_to(current_target.global_position)
		var direction = (current_target.global_position - global_position).normalized()
		
		# 버프 적용된 최종 스피드
		var final_speed = speed
		if rage_timer > 0: final_speed *= 1.5
		if morale_type == 1: final_speed *= 1.2
		elif morale_type == -1: final_speed *= 0.7
		if is_dueling: final_speed *= 1.3 # 일기토 시 돌진
		
		# 분리 로직 적용 (일기토 중엔 살짝 약화)
		var sep_strength = 0.5 if is_dueling else 1.5
		direction = (direction + cached_separation * sep_strength).normalized()
		
		if distance > attack_range:
			velocity = direction * final_speed
			move_and_slide()
		else:
			velocity = cached_separation * (final_speed * 0.5)
			move_and_slide()
			if attack_timer <= 0 and attack_range > 0:
				perform_attack()
				attack_timer = attack_cooldown
				if rage_timer > 0 or morale_type == 1: attack_timer *= 0.7
				attack_anim_progress = 1.0
	
	queue_redraw()

func handle_death():
	if is_dueling: # 일기토 중 사망 시 팀 사기 저하
		apply_team_morale(team, -1)
		# 승리한 기사에게 보상
		if is_instance_valid(duel_target) and duel_target.has_method("win_duel"):
			duel_target.win_duel()

	if unit_class == UnitClass.CITIZEN and (citizen_type == CitizenType.CHILD or citizen_type == CitizenType.OLD):
		trigger_rage_for_allies()
	
	queue_free()

func win_duel():
	print("Knight [", name, "] WON THE DUEL!")
	is_dueling = false
	duel_target = null
	apply_team_morale(team, 1) # 아군 사기 충천

func apply_team_morale(t: int, type: int):
	var group = "players" if t == 0 else "enemies"
	var duration = 15.0 # 사기 버프 15초
	for member in get_tree().get_nodes_in_group(group):
		if member.has_method("apply_morale"):
			member.apply_morale(type, duration)

func apply_morale(type: int, duration: float):
	morale_type = type
	morale_timer = duration

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
	var current_target = duel_target if is_dueling else target
	if not current_target or not is_instance_valid(current_target): return
	
	var final_damage = damage
	if rage_timer > 0: final_damage *= 1.5
	if morale_type == 1: final_damage *= 1.3
	elif morale_type == -1: final_damage *= 0.8
	
	if current_target.has_method("take_damage"):
		current_target.take_damage(final_damage)

func find_closest_target():
	if unit_class == UnitClass.CITIZEN: 
		target = null
		return

	# 기사의 특수 로직: 적 기사를 우선 탐색 (일기토)
	if unit_class == UnitClass.KNIGHT and not is_dueling:
		var enemy_group = "enemies" if team == 0 else "players"
		for enemy in get_tree().get_nodes_in_group(enemy_group):
			if enemy.unit_class == UnitClass.KNIGHT and not enemy.is_dueling:
				if global_position.distance_to(enemy.global_position) < 400.0:
					start_duel(enemy)
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

func start_duel(enemy):
	is_dueling = true
	duel_target = enemy
	if enemy.has_method("accept_duel"):
		enemy.accept_duel(self)
	print("Knight [", name, "] started a DUEL with [", enemy.name, "]!")

func accept_duel(enemy):
	is_dueling = true
	duel_target = enemy

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
