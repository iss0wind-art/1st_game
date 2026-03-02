extends Node3D

@onready var camera = get_viewport().get_camera_3d()

var dragging = false
var start_pos = Vector2.ZERO
var end_pos = Vector2.ZERO
var selected_units = []

var last_click_time = 0.0
var double_click_threshold = 0.3
var is_attack_mode = false

func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_A and event.pressed:
			is_attack_mode = true
			print("Attack Mode Activated - Select Target")

	if event is InputEventMouseButton:
		# [Phase 18: 마우스 휠 확대/축소]
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(-1.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(1.5)

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				handle_left_click(event.position)
				dragging = true
				start_pos = event.position
				end_pos = start_pos
			else:
				dragging = false
				if start_pos.distance_to(event.position) > 10:
					select_units_in_box()
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			is_attack_mode = false
			var target_data = get_raycast_result(event.position)
			if target_data.has("position"):
				issue_command(target_data.position, target_data.get("collider"))

	if event is InputEventMouseMotion and dragging:
		end_pos = event.position

func zoom_camera(delta):
	if not camera: camera = get_viewport().get_camera_3d()
	if camera:
		var new_y = clamp(camera.position.y + delta, 5.0, 60.0)
		var ratio = new_y / camera.position.y
		camera.position.y = new_y
		camera.position.z *= ratio # 높이에 맞춰 거리도 비례 조절
		print("Camera Zoom Level (Y): ", new_y)

func handle_left_click(mouse_pos):
	var now = Time.get_ticks_msec() / 1000.0
	var is_double = (now - last_click_time) < double_click_threshold
	last_click_time = now
	
	var target_data = get_raycast_result(mouse_pos)
	var collider = target_data.get("collider")
	
	# [Phase 18: 집중 공격(A+클릭)]
	if is_attack_mode:
		if collider and collider.is_in_group("enemies"):
			issue_command(target_data.position, collider)
			is_attack_mode = false
			return
		is_attack_mode = false # 적을 안 눌렀으면 해제

	# [Phase 18: 스마트 선택(더블클릭/Ctrl+클릭)]
	if collider and collider.is_in_group("players"):
		if is_double or Input.is_key_pressed(KEY_CTRL):
			select_same_class_units(collider.get("unit_class"))
			return
		
		# 단일 선택
		clear_selection()
		collider.is_selected = true
		selected_units.append(collider)

func select_same_class_units(u_class):
	clear_selection()
	for unit in get_tree().get_nodes_in_group("players"):
		if unit.get("unit_class") == u_class:
			unit.is_selected = true
			selected_units.append(unit)
	print("Selected All: ", u_class)

func clear_selection():
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.is_selected = false
	selected_units.clear()

func select_units_in_box():
	clear_selection()
	
	var rect = Rect2(start_pos, end_pos - start_pos).abs()
	
	# 드래그 거리가 짧으면 클릭으로 처리 (여기서는 단순화)
	for unit in get_tree().get_nodes_in_group("players"):
		var screen_pos = camera.unproject_position(unit.global_position)
		if rect.has_point(screen_pos):
			unit.is_selected = true
			selected_units.append(unit)

func get_raycast_result(mouse_pos):
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	return space_state.intersect_ray(query)

func issue_command(pos, collider):
	if selected_units.size() == 0: return
	
	var target_unit = null
	if collider and collider.is_in_group("enemies"):
		target_unit = collider
		
	for i in range(selected_units.size()):
		var unit = selected_units[i]
		if not is_instance_valid(unit): continue
		
		if target_unit:
			unit.give_attack_command(target_unit)
		else:
			# 대열 간격 (3D 스케일에 맞게 조정)
			var offset = Vector3((i % 7) * 2.0, 0, (i / 7) * 2.0)
			unit.give_move_command(pos + offset)
