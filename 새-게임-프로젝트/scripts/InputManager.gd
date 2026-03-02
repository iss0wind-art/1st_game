extends Node2D

var dragging = false
var start_pos = Vector2.ZERO
var end_pos = Vector2.ZERO
var selected_units = []

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				start_pos = get_global_mouse_position()
				end_pos = start_pos
			else:
				dragging = false
				select_units_in_box()
				queue_redraw()
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			issue_command(get_global_mouse_position())

	if event is InputEventMouseMotion and dragging:
		end_pos = get_global_mouse_position()
		queue_redraw()

func _draw():
	if dragging:
		var rect = Rect2(start_pos, end_pos - start_pos)
		draw_rect(rect, Color(0.1, 0.8, 0.1, 0.2), true) # 반투명 박스
		draw_rect(rect, Color(0.1, 1.0, 0.1, 0.6), false, 2.0) # 테두리

func select_units_in_box():
	# 기존 선택 해제
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.is_selected = false
	selected_units.clear()
	
	var select_rect = Rect2(start_pos, end_pos - start_pos).abs()
	
	# 드래그 거리가 너무 짧으면 단일 클릭으로 처리
	if select_rect.size.length() < 5.0:
		select_single_unit(start_pos)
		return

	# 박스 안의 아군(Team 0) 유닛 찾기
	for unit in get_tree().get_nodes_in_group("players"):
		if select_rect.has_point(unit.global_position):
			unit.is_selected = true
			selected_units.append(unit)

func select_single_unit(pos):
	var closest_unit = null
	var min_dist = 30.0 # 클릭 반경
	
	for unit in get_tree().get_nodes_in_group("players"):
		var dist = unit.global_position.distance_to(pos)
		if dist < min_dist:
			min_dist = dist
			closest_unit = unit
			
	if closest_unit:
		closest_unit.is_selected = true
		selected_units.append(closest_unit)

func issue_command(pos):
	if selected_units.size() == 0: return
	
	# 우클릭 지점에 적이 있는지 확인 (강제 공격)
	var target_enemy = find_enemy_at_pos(pos)
	
	# 유닛들에게 분산 이동 좌표 계산 (겹치지 않게)
	var formation_spacing = 30.0
	var cols = ceil(sqrt(selected_units.size()))
	
	for i in range(selected_units.size()):
		var unit = selected_units[i]
		if not is_instance_valid(unit): continue
		
		if target_enemy:
			unit.give_attack_command(target_enemy)
		else:
			# 대열 형태로 이동 좌표 부여
			var offset = Vector2((i % int(cols)) * formation_spacing, (i / int(cols)) * formation_spacing)
			unit.give_move_command(pos + offset)

func find_enemy_at_pos(pos):
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(pos) < 30.0:
			return enemy
	for wall in get_tree().get_nodes_in_group("walls"):
		if wall.global_position.distance_to(pos) < 50.0:
			return wall
	return null
