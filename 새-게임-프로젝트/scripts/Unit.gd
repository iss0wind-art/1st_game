extends CharacterBody2D

enum UnitClass { SWORDMAN, SPEARMAN, ARCHER, CAVALRY, KNIGHT, PRIEST, CITIZEN, SIEGE }
enum CitizenType { MALE, FEMALE, CHILD, OLD }

@export var unit_class: UnitClass = UnitClass.SWORDMAN
@export var citizen_type: CitizenType = CitizenType.MALE
@export var team: int = 0 
@export var arrow_scene: PackedScene 

var safe_zone: Vector2 = Vector2.ZERO
var retreat_pos: Vector2 = Vector2.ZERO
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
var morale_type: int = 0 

# 일기토(Duel) 시스템
var is_dueling: bool = false
var duel_target: Node2D = null

# 애니메이션 변수
var walk_timer: float = 0.0
var walk_speed: float = 10.0
var attack_anim_progress: float = 0.0
var facing_right: bool = true

# 최적화
var cached_separation: Vector2 = Vector2.ZERO

func _ready():
	ai_update_timer = randf() * ai_update_interval
	setup_class_stats()
	if team == 0:
		retreat_pos = safe_zone + Vector2(-150, (randf()-0.5) * 200.0)
		color = Color.CORNFLOWER_BLUE
		facing_right = true
	else:
		retreat_pos = safe_zone + Vector2(150, (randf()-0.5) * 200.0)
		color = Color.INDIAN_RED
		facing_right = false
	if unit_class == UnitClass.CITIZEN and citizen_type == CitizenType.CHILD:
		scale = Vector2(0.6, 0.6)

func setup_class_stats():
	match unit_class:
		UnitClass.SWORDMAN:
			speed = 120.0; attack_range = 25.0; damage = 15.0; health = 100.0
		UnitClass.SPEARMAN:
			speed = 100.0; attack_range = 45.0; damage = 12.0; health = 110.0
		UnitClass.ARCHER:
			speed = 90.0; attack_range = 300.0; damage = 12.0; health = 80.0; attack_cooldown = 2.0
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
			speed = 40.0; attack_range = 350.0; damage = 50.0; health = 300.0; attack_cooldown = 3.5

func _draw():
	var f = 1.0 if facing_right else -1.0
	if rage_timer > 0: draw_circle(Vector2.ZERO, 20, Color(1, 0, 0, 0.2))
	if morale_type == 1: draw_circle(Vector2.ZERO, 20, Color(1, 0.8, 0, 0.3))
	elif morale_type == -1: draw_circle(Vector2.ZERO, 20, Color(0.5, 0.5, 0.5, 0.3))
	if is_dueling: draw_arc(Vector2(0, -25), 5, 0, TAU, 32, Color.GOLD, 1.0)
	var leg_swing = sin(walk_timer * walk_speed) * 8.0 if velocity.length() > 5 else 0.0
	var arm_swing = cos(walk_timer * walk_speed) * 6.0 if velocity.length() > 5 else 0.0
	var arm_origin = Vector2(0, -8)
	var left_arm_end = Vector2(-8 * f, -5) + Vector2(0, arm_swing)
	var right_arm_end = Vector2(8 * f, -5) - Vector2(0, arm_swing)
	var current_target = duel_target if is_dueling else target
	if current_target and attack_anim_progress > 0:
		var target_dir = (current_target.global_position - global_position).normalized()
		if unit_class == UnitClass.ARCHER:
			left_arm_end = target_dir * 10.0 + Vector2(0, -5)
			right_arm_end = -target_dir * 5.0 + Vector2(0, -5)
			right_arm_end.x -= sin(attack_anim_progress * PI) * 5 * f
		else:
			var swing = sin(attack_anim_progress * PI) * 15.0
			right_arm_end = target_dir * (12.0 + swing) + Vector2(0, -5)
	draw_line(Vector2(0, -10), Vector2(0, 5), color, 2.5)
	draw_circle(Vector2(0, -15), 5, color)
	draw_line(arm_origin, left_arm_end, color, 2.0)
	draw_line(arm_origin, right_arm_end, color, 2.0)
	draw_line(Vector2(0, 5), Vector2(0, 5) + Vector2((-6 + leg_swing) * f, 10), color, 2.0)
	draw_line(Vector2(0, 5), Vector2(0, 5) + Vector2((6 - leg_swing) * f, 10), color, 2.0)
	match unit_class:
		UnitClass.ARCHER:
			var bow_center = left_arm_end
			var bow_pull = sin(attack_anim_progress * PI) * 4
			var target_angle = (left_arm_end - arm_origin).angle()
			draw_set_transform(bow_center, target_angle, Vector2.ONE)
			draw_arc(Vector2.ZERO, 10, -PI/2, PI/2, 8, color, 1.5)
			draw_line(Vector2(0, -10), Vector2(-bow_pull, 0), color, 0.5)
			draw_line(Vector2(-bow_pull, 0), Vector2(0, 10), color, 0.5)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		UnitClass.SWORDMAN, UnitClass.KNIGHT:
			var sword_len = 12 if unit_class == UnitClass.SWORDMAN else 18
			var sword_dir = (right_arm_end - arm_origin).normalized()
			draw_line(right_arm_end, right_arm_end + sword_dir * sword_len, color, 2.0)
		UnitClass.CAVALRY:
			draw_line(Vector2(-15 * f, 10), Vector2(15 * f, 10), color, 3.0)
		UnitClass.CITIZEN:
			if citizen_type == CitizenType.FEMALE:
				draw_line(Vector2(-8, 5), Vector2(8, 5), color, 1.5)

func _physics_process(delta):
	if health <= 0:
		handle_death()
		return
	if velocity.length() > 5: walk_timer += delta
	else: walk_timer = 0
	if attack_anim_progress > 0: attack_anim_progress -= delta * 2.5
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
		if not is_dueling: find_closest_target()
		cached_separation = get_separation_vector()
	if is_dueling and (not is_instance_valid(duel_target) or duel_target.health <= 0):
		is_dueling = false
		duel_target = null
	var current_target = duel_target if is_dueling else target
	var current_speed = speed
	# [스팀팩 효과] 버프 시 이동 속도 비약적 상승
	if rage_timer > 0: current_speed *= 2.2 
	if morale_type == 1: current_speed *= 1.5
	elif morale_type == -1: current_speed *= 0.6
	if is_dueling: current_speed *= 1.3
	if unit_class == UnitClass.CITIZEN:
		var dist_to_retreat = global_position.distance_to(retreat_pos)
		if dist_to_retreat > 30.0:
			var move_direction = (retreat_pos - global_position).normalized()
			velocity = (move_direction + cached_separation * 1.0).normalized() * current_speed * 0.8
		else:
			velocity = cached_separation * 20.0
	elif current_target:
		var distance = global_position.distance_to(current_target.global_position)
		var move_direction = (current_target.global_position - global_position).normalized()
		facing_right = move_direction.x > 0
		var sep_strength = 0.3 if is_dueling else 1.5
		move_direction = (move_direction + cached_separation * sep_strength).normalized()
		if distance > attack_range:
			velocity = move_direction * current_speed
		else:
			velocity = cached_separation * (current_speed * 0.3)
			facing_right = (current_target.global_position.x - global_position.x) > 0
			if attack_timer <= 0:
				perform_attack()
				attack_timer = attack_cooldown
				if is_dueling or rage_timer > 0 or morale_type == 1: attack_timer *= 0.6
				attack_anim_progress = 1.0
	else:
		velocity = cached_separation * 20.0
	if velocity.length() > 0:
		move_and_slide()
	queue_redraw()

func handle_death():
	if is_dueling:
		apply_team_morale(team, -1)
		if is_instance_valid(duel_target) and duel_target.has_method("win_duel"):
			duel_target.win_duel()
	if unit_class == UnitClass.CITIZEN and (citizen_type == CitizenType.CHILD or citizen_type == CitizenType.OLD):
		trigger_rage_for_allies()
	queue_free()

func win_duel():
	is_dueling = false
	duel_target = null
	apply_team_morale(team, 1)

func apply_team_morale(t: int, type: int):
	var group = "players" if t == 0 else "enemies"
	for member in get_tree().get_nodes_in_group(group):
		if member.has_method("apply_morale"):
			member.apply_morale(type, 15.0)

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
	if unit_class == UnitClass.ARCHER and arrow_scene:
		var arrow = arrow_scene.instantiate()
		get_parent().add_child(arrow)
		var shoot_dmg = damage
		if rage_timer > 0: shoot_dmg *= 1.5
		if morale_type == 1: shoot_dmg *= 1.3
		arrow.setup(global_position + Vector2(0, -10), current_target.global_position, team, shoot_dmg, global_position)
	else:
		var final_damage = damage
		if rage_timer > 0: final_damage *= 1.5
		if morale_type == 1: final_damage *= 1.3
		elif morale_type == -1: final_damage *= 0.8
		if current_target.has_method("take_damage_from"):
			current_target.take_damage_from(final_damage, global_position)
		else:
			current_target.take_damage(final_damage)

func take_damage_from(amount, attacker_pos):
	var final_amount = amount
	# [백스탭 판정] 뒤에서 맞으면 피해량 1.5배
	var dir_to_attacker = (attacker_pos - global_position).normalized()
	var facing_dir = Vector2.RIGHT if facing_right else Vector2.LEFT
	if facing_dir.dot(dir_to_attacker) > 0.4: # 뒤에서 공격받음
		final_amount *= 1.5
	health -= final_amount

func take_damage(amount):
	health -= amount

func find_closest_target():
	if unit_class == UnitClass.CITIZEN: 
		target = null
		return
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

func accept_duel(enemy):
	is_dueling = true
	duel_target = enemy

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
