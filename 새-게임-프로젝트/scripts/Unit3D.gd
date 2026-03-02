extends CharacterBody3D

enum UnitClass { SWORDMAN, SPEARMAN, ARCHER, CAVALRY, KNIGHT, PRIEST, CITIZEN, SIEGE, SUPPLY_WAGON }

@export var unit_class: UnitClass = UnitClass.SWORDMAN
@export var team: int = 0
@export var arrow_scene: PackedScene
@export var speed: float = 5.0 
@export var health: float = 100.0
@export var attack_range: float = 2.0
@export var damage: float = 10.0
@export var attack_cooldown: float = 1.0

# RTS 및 전술 변수 (2D에서 이식)
var is_selected: bool = false
var command_pos: Vector3 = Vector3.ZERO
var has_command: bool = false
var command_target_unit: Node3D = null

# 지형 효과 변수 (Phase 15)
var is_in_water: bool = false
var elevation: int = 0
var water_speed_mult: float = 0.5

var is_supplied: bool = true
var supply_timer: float = 15.0
var stamina: float = 100.0
var stationary_timer: float = 0.0
var is_ambushing: bool = false
var rage_timer: float = 0.0
var morale_type: int = 0
var morale_timer: float = 0.0

var target: Node3D = null
var attack_timer: float = 0.0
var ai_update_timer: float = 0.0
var ai_update_interval: float = 0.2
var cached_separation: Vector3 = Vector3.ZERO
var surrounding_enemies_count: int = 0

@onready var mesh_instance = $MeshInstance3D 
@onready var selection_circle = $SelectionCircle 
@onready var sword = $Sword
@onready var bow = $Bow

var attack_anim_time: float = 0.0

func _ready():
	ai_update_timer = randf() * ai_update_interval
	setup_class_stats()
	add_to_group("units")
	add_to_group("players" if team == 0 else "enemies")
	if unit_class == UnitClass.SUPPLY_WAGON:
		add_to_group("supply_sources")
	
	setup_visuals()

func setup_visuals():
	# 팀 색상 설정
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.CORNFLOWER_BLUE if team == 0 else Color.INDIAN_RED
	mesh_instance.set_surface_override_material(0, mat)
	selection_circle.visible = false
	
	# 무기 보이기/숨기기
	sword.visible = (unit_class == UnitClass.SWORDMAN or unit_class == UnitClass.KNIGHT or unit_class == UnitClass.CAVALRY)
	bow.visible = (unit_class == UnitClass.ARCHER)
	
	if sword.visible:
		var s_mat = StandardMaterial3D.new()
		s_mat.albedo_color = Color.SILVER
		sword.set_surface_override_material(0, s_mat)
	
	if bow.visible:
		var b_mat = StandardMaterial3D.new()
		b_mat.albedo_color = Color.SADDLE_BROWN
		$Bow/BowMesh.set_surface_override_material(0, b_mat)

func setup_class_stats():
	match unit_class:
		UnitClass.SWORDMAN:
			speed = 6.0; attack_range = 2.5; damage = 22.0; health = 160.0
		UnitClass.SPEARMAN:
			speed = 5.0; attack_range = 4.0; damage = 12.0; health = 110.0
		UnitClass.ARCHER:
			speed = 4.5; attack_range = 15.0; damage = 12.0; health = 80.0; attack_cooldown = 2.0
		UnitClass.CAVALRY:
			speed = 10.0; attack_range = 3.0; damage = 20.0; health = 150.0; attack_cooldown = 1.2
		UnitClass.KNIGHT:
			speed = 7.0; attack_range = 3.5; damage = 50.0; health = 1000.0; attack_cooldown = 0.4
		UnitClass.SUPPLY_WAGON:
			speed = 4.0; health = 200.0

func _physics_process(delta):
	if health <= 0:
		queue_free()
		return
		
	# RTS 선택 비주얼
	selection_circle.visible = is_selected

	# [Phase 11: 피로도 및 상태 관리]
	update_state(delta)
	
	# [Phase 16: 무기 애니메이션]
	if attack_anim_time > 0:
		attack_anim_time -= delta * 3.0
		update_weapon_animation()
	else:
		reset_weapon_pose()
	
	ai_update_timer -= delta
	if ai_update_timer <= 0:
		ai_update_timer = ai_update_interval
		find_closest_target()
		check_supply()
		update_surrounding_count()
	
	attack_timer -= delta
	
	var current_speed = speed
	apply_modifiers(current_speed)
	
	handle_movement(delta, current_speed)

func update_state(delta):
	# 스태미너
	if velocity.length() > 1.0 or attack_timer > 0:
		stamina = max(0, stamina - 2.0 * delta)
	else:
		stamina = min(100.0, stamina + 5.0 * delta)
		
	# 매복
	if velocity.length() < 0.5:
		stationary_timer += delta
		if stationary_timer >= 10.0: is_ambushing = true
	else:
		stationary_timer = 0; is_ambushing = false
	
	# 보급
	if not is_supplied: supply_timer -= delta
	else: supply_timer = min(15.0, supply_timer + delta * 2.0)

func apply_modifiers(ref_speed):
	if stamina < 20.0: ref_speed *= 0.6
	if supply_timer <= 0: ref_speed *= 0.5
	if morale_type == 1: ref_speed *= 1.5
	elif morale_type == -1: ref_speed *= 0.6
	if is_in_water: ref_speed *= water_speed_mult

func set_elevation(val):
	elevation = val
	if elevation > 0:
		print("Elevation Bonus Activated for: ", name)

func handle_movement(delta, move_speed):
	var move_dir = Vector3.ZERO
	var current_range = attack_range
	if elevation > 0 and unit_class == UnitClass.ARCHER:
		current_range *= 1.5
	
	if has_command:
		var to_pos = command_pos - global_position
		to_pos.y = 0
		if to_pos.length() > 1.0:
			move_dir = to_pos.normalized()
		else:
			has_command = false
	elif is_instance_valid(command_target_unit):
		var to_target = command_target_unit.global_position - global_position
		to_target.y = 0
		if to_target.length() > current_range:
			move_dir = to_target.normalized()
		else:
			if attack_timer <= 0: perform_attack()
	elif is_instance_valid(target):
		var to_target = target.global_position - global_position
		to_target.y = 0
		if to_target.length() > current_range:
			move_dir = to_target.normalized()
		else:
			if attack_timer <= 0: perform_attack()
			
	if move_dir != Vector3.ZERO:
		velocity = move_dir * move_speed
		# 회전
		var target_basis = Basis.looking_at(move_dir)
		basis = basis.slerp(target_basis, 0.1)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, 0.5)
		
	move_and_slide()

func perform_attack():
	var cur_target = command_target_unit if is_instance_valid(command_target_unit) else target
	if not cur_target: return
	
	var final_dmg = damage
	if elevation > 0:
		final_dmg *= 1.2
			
	# 상성 및 전술 보너스 (2D 로직 기반)
	if is_ambushing: final_dmg *= 3.0; is_ambushing = false
	
	if stamina < 20.0: attack_timer = attack_cooldown * 1.5
	else: attack_timer = attack_cooldown
	
	# [Phase 16: 애니메이션 시작]
	attack_anim_time = 1.0
	
	if unit_class == UnitClass.ARCHER and arrow_scene:
		var arrow = arrow_scene.instantiate()
		get_parent().add_child(arrow)
		arrow.setup(global_position + Vector3(0, 1.5, 0), cur_target.global_position, team, final_dmg, global_position)
	else:
		if cur_target.has_method("take_damage"):
			cur_target.take_damage(final_dmg)

func update_weapon_animation():
	var t = attack_anim_time
	if unit_class == UnitClass.ARCHER:
		# 활 당기기: Z축으로 살짝 뒤로 밀림
		bow.position.z = -0.2 + (sin(t * PI) * -0.2)
	else:
		# 칼 휘두르기: X축 회전
		var swing = sin(t * PI) * PI / 2.0
		sword.rotation.x = deg_to_rad(-30.0) + swing

func reset_weapon_pose():
	if unit_class == UnitClass.ARCHER:
		bow.position = Vector3(0.6, 1.2, -0.2)
		bow.rotation = Vector3.ZERO
	else:
		sword.position = Vector3(0.6, 1.2, -0.4)
		sword.rotation = Vector3(deg_to_rad(-30.0), 0, 0)

func take_damage(amount, hit_pos: Vector3 = Vector3.ZERO):
	var final_amount = amount
	
	# [Phase 17: 헤드샷 판정]
	# 유닛의 높이가 2.0인데, hit_pos.y가 로컬 좌표에서 1.6 이상이면 머리로 간주
	if hit_pos != Vector3.ZERO:
		var local_hit_pos = to_local(hit_pos)
		if local_hit_pos.y > 1.6:
			final_amount *= 2.5
			print("Critical Headshot! Damage x2.5: ", final_amount)
			flash_head_color()
			
	health -= final_amount

func flash_head_color():
	var head = get_node_or_null("MeshInstance3D/Head")
	if head:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.GOLD
		head.set_surface_override_material(0, mat)
		await get_tree().create_timer(0.2).timeout
		head.set_surface_override_material(0, null)

func check_supply():
	var dist_limit = 15.0 # 3D 스케일
	var found = false
	for source in get_tree().get_nodes_in_group("supply_sources"):
		if source.team == self.team and global_position.distance_to(source.global_position) < dist_limit:
			found = true; break
	is_supplied = found

func find_closest_target():
	var enemy_group = "enemies" if team == 0 else "players"
	var enemies = get_tree().get_nodes_in_group(enemy_group)
	var min_dist = INF
	var found_target = null
	for e in enemies:
		var d = global_position.distance_to(e.global_position)
		if d < min_dist:
			min_dist = d; found_target = e
	target = found_target

func update_surrounding_count():
	var enemy_group = "enemies" if team == 0 else "players"
	var count = 0
	for enemy in get_tree().get_nodes_in_group(enemy_group):
		if global_position.distance_to(enemy.global_position) < 5.0:
			count += 1
	surrounding_enemies_count = count

func give_move_command(pos: Vector3):
	command_pos = pos; has_command = true; command_target_unit = null
func give_attack_command(node: Node3D):
	command_target_unit = node; has_command = false
