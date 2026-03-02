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

# 지형 및 공성 변수
var current_elevation: int = 0 
var is_in_water: bool = false
var blocked_by_wall: bool = false

# 상태 및 타이머
var target: Node2D = null
var color: Color = Color.WHITE
var attack_timer: float = 0.0
var ai_update_timer: float = 0.0
var ai_update_interval: float = 0.2
var aging_timer: float = 30.0 
var rage_timer: float = 0.0 

# 사기(Morale) 및 일기토
var morale_timer: float = 0.0 
var morale_type: int = 0 
var is_dueling: bool = false
var duel_target: Node2D = null

# 애니메이션
var walk_timer: float = 0.0
var walk_speed: float = 10.0
var attack_anim_progress: float = 0.0
var facing_right: bool = true
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
			speed = 130.0; attack_range = 35.0; damage = 25.0; health = 220.0; attack_cooldown = 0.8
		UnitClass.PRIEST:
			speed = 100.0; attack_range = 150.0; damage = -10.0; health = 80.0 
		UnitClass.CITIZEN:
			speed = 80.0; attack_range = 0.0; damage = 0.0; health = 50.0
			if citizen_type == CitizenType.CHILD: health = 30.0
		UnitClass.SIEGE:
			speed = 50.0; attack_range = 50.0; damage = 100.0; health = 500.0; attack_cooldown = 4.0

func _draw():
	var f = 1.0 if facing_right else -1.0
	var alpha = 0.5 if is_in_water else 1.0
	var current_color = Color(color.r, color.g, color.b, alpha)
	
	if current_elevation > 0:
		draw_colored_polygon([Vector2(-3, -25), Vector2(3, -25), Vector2(0, -30)], Color.YELLOW)
	if rage_timer > 0: draw_circle(Vector2.ZERO, 20, Color(1, 0, 0, 0.2))
	if morale_type == 1: draw_circle(Vector2.ZERO, 20, Color(1, 0.8, 0, 0.3))
	elif morale_type == -1: draw_circle(Vector2.ZERO, 20, Color(0.5, 0.5, 0.5, 0.3))
	if is_dueling: draw_arc(Vector2(0, -25), 5, 0, TAU, 32, Color.GOLD, 1.0)
	
	var leg_swing = sin(walk_timer * walk_speed) * 8.0 if velocity.length() > 5 else 0.0
	var arm_swing = cos(walk_timer * walk_speed) * 6.0 if velocity.length() > 5 else 0.0
	
	# [SIEGE: 공성추 비주얼]
	if unit_class == UnitClass.SIEGE:
		var thrust = sin(attack_anim_progress * PI) * 15.0
		draw_rect(Rect2(-20*f, -5, 40*f, 15), Color.DARK_SLATE_GRAY)
		draw_rect(Rect2(-25*f, -10, 50*f, 8), Color.SADDLE_BROWN)
		draw_line(Vector2(-30*f + thrust*f, -15), Vector2(20*f + thrust*f, -15), Color.GRAY, 5.0)
		return

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
			
	draw_line(Vector2(0, -10), Vector2(0, 5), current_color, 2.5)
	draw_circle(Vector2(0, -15), 5, current_color)
	draw_line(arm_origin, left_arm_end, current_color, 2.0)
	draw_line(arm_origin, right_arm_end, current_color, 2.0)
	draw_line(Vector2(0, 5), Vector2(0, 5) + Vector2((-6 + leg_swing) * f, 10), current_color, 2.0)
	draw_line(Vector2(0, 5), Vector2(0, 5) + Vector2((6 - leg_swing) * f, 10), current_color, 2.0)
	
	match unit_class:
		UnitClass.ARCHER:
			var bow_center = left_arm_end
			var bow_pull = sin(attack_anim_progress * PI) * 4
			var target_angle = (left_arm_end - arm_origin).angle()
			draw_set_transform(bow_center, target_angle, Vector2.ONE)
			draw_arc(Vector2.ZERO, 10, -PI/2, PI/2, 8, current_color, 1.5)
			draw_line(Vector2(0, -10), Vector2(-bow_pull, 0), current_color, 0.5)
			draw_line(Vector2(-bow_pull, 0), Vector2(0, 10), current_color, 0.5)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		UnitClass.SWORDMAN, UnitClass.KNIGHT:
			var sword_len = 12 if unit_class == UnitClass.SWORDMAN else 18
			var sword_dir = (right_arm_end - arm_origin).normalized()
			draw_line(right_arm_end, right_arm_end + sword_dir * sword_len, current_color, 2.0)
		UnitClass.CAVALRY:
			draw_line(Vector2(-15 * f, 10), Vector2(15 * f, 10), current_color, 3.0)

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
	attack_timer -= delta
	ai_update_timer -= delta
	
	if ai_update_timer <= 0:
		ai_update_timer = ai_update_interval
		if not is_dueling: find_closest_target()
		cached_separation = get_separation_vector()
	
	var current_target = duel_target if is_dueling else target
	var current_speed = speed
	if rage_timer > 0: current_speed *= 2.2 
	if morale_type == 1: current_speed *= 1.5
	elif morale_type == -1: current_speed *= 0.6
	if is_in_water: current_speed *= 0.5

	if unit_class == UnitClass.CITIZEN:
		var move_direction = (retreat_pos - global_position).normalized()
		velocity = (move_direction + cached_separation * 1.0).normalized() * current_speed * 0.8
	elif current_target:
		var distance = global_position.distance_to(current_target.global_position)
		var actual_attack_range = attack_range
		if current_elevation > 0 and unit_class == UnitClass.ARCHER:
			actual_attack_range *= 1.4
		
		var move_direction = (current_target.global_position - global_position).normalized()
		facing_right = move_direction.x > 0
		
		if distance > actual_attack_range:
			velocity = (move_direction + cached_separation * 1.5).normalized() * current_speed
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
	queue_free()

func apply_team_morale(t: int, type: int):
	var group = "players" if t == 0 else "enemies"
	for member in get_tree().get_nodes_in_group(group):
		if member.has_method("apply_morale"):
			member.apply_morale(type, 15.0)

func apply_morale(type: int, duration: float):
	morale_type = type
	morale_timer = duration

func perform_attack():
	var current_target = duel_target if is_dueling else target
	if not current_target or not is_instance_valid(current_target): return
	
	var final_damage = damage
	if rage_timer > 0: final_damage *= 1.5
	if current_elevation > 0: final_damage *= 1.2
	
	if unit_class == UnitClass.ARCHER and arrow_scene:
		var arrow = arrow_scene.instantiate()
		get_parent().add_child(arrow)
		arrow.setup(global_position + Vector2(0, -10), current_target.global_position, team, final_damage, global_position)
	elif current_target.is_in_group("walls"):
		# [공성 데미지 보정]
		var struct_dmg = final_damage
		if unit_class == UnitClass.SIEGE: struct_dmg *= 10.0 # 공성추는 10배
		elif unit_class == UnitClass.KNIGHT: struct_dmg *= 2.0 # 기사는 2배
		
		if current_target.has_method("take_damage"):
			current_target.take_damage(struct_dmg)
	else:
		if current_target.has_method("take_damage_from"):
			current_target.take_damage_from(final_damage, global_position)
		else:
			current_target.take_damage(final_damage)

func take_damage_from(amount, attacker_pos):
	var final_amount = amount
	var dir_to_attacker = (attacker_pos - global_position).normalized()
	var facing_dir = Vector2.RIGHT if facing_right else Vector2.LEFT
	if facing_dir.dot(dir_to_attacker) > 0.4: final_amount *= 1.5
	health -= final_amount

func take_damage(amount):
	health -= amount

func find_closest_target():
	if unit_class == UnitClass.CITIZEN: return
	
	var enemy_group = "enemies" if team == 0 else "players"
	var closest_dist = INF
	var closest_target = null
	
	# 1. 유닛 탐색
	for member in get_tree().get_nodes_in_group(enemy_group):
		var dist = global_position.distance_to(member.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_target = member
			
	# 2. breakthrough AI (적군 한정)
	if team == 1:
		# 가는 길이 막혀있거나 적이 성벽 너머에 있다면 성벽/성문을 타겟팅
		if closest_target:
			var dist_to_enemy = global_position.distance_to(closest_target.global_position)
			# 성벽 근처(x=576)인데 적은 왼쪽에 있고 나는 오른쪽에 있다면
			if global_position.x > 580 and closest_target.global_position.x < 570:
				# 가장 가까운 성벽/성문 찾기
				var closest_wall = null
				var wall_dist = INF
				for wall in get_tree().get_nodes_in_group("walls"):
					var d = global_position.distance_to(wall.global_position)
					if d < wall_dist:
						wall_dist = d
						closest_wall = wall
				if closest_wall:
					closest_target = closest_wall
	
	target = closest_target

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
