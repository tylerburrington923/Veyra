extends RayCast3D

## Camera-centered interaction selector.
## Direct camera hits are preferred. Fallback candidates are selected by
## screen-space relevance, distance, and line of sight so large world objects
## do not require the player to stand on an exact invisible interaction point.

const INTERACTION_LAYER_MASK := 2 | 4
const RAY_DISTANCE := 6.0
const MAX_TARGET_DISTANCE := 5.0
const MAX_SCREEN_RADIUS := 0.30
const NEAR_TARGET_ASSIST_DISTANCE := 2.25
const NEAR_TARGET_SCREEN_RADIUS := 0.42
const TARGET_SCORE_DISTANCE_WEIGHT := 0.05
const MAX_HANDLER_DEPTH := 8

@export var interact_distance: float = MAX_TARGET_DISTANCE
@export var resonance_strength: float = 1.8
@export var target_update_interval: float = 0.12

var target_label: Label
var target_panel: PanelContainer
var target_action: Label
var target_detail: Label
var interact_button: Button
var last_target_name: String = ""
var last_target_type: String = "NONE"
var last_handler_name: String = ""
var last_requirement: String = ""
var last_collision_point: Vector3 = Vector3.ZERO
var _target_update_accumulator := 0.0

func _ready() -> void:
	interact_distance = MAX_TARGET_DISTANCE
	target_position = Vector3(0, 0, -RAY_DISTANCE)
	collision_mask = INTERACTION_LAYER_MASK
	collide_with_bodies = true
	collide_with_areas = true
	enabled = true

	target_label = get_node_or_null("../../MobileControls/TargetHUD") as Label
	target_panel = get_node_or_null("../../MobileControls/InteractionHUD") as PanelContainer
	target_action = get_node_or_null("../../MobileControls/InteractionHUD/Action") as Label
	target_detail = get_node_or_null("../../MobileControls/InteractionHUD/Detail") as Label
	_interaction_hud_style()
	interact_button = get_node_or_null("../../MobileControls/InteractButton") as Button
	_update_target_debug()

func _physics_process(delta: float) -> void:
	if _is_modal_ui_open():
		_set_target_state("NONE", "", "", Vector3.ZERO, false)
		return
	_target_update_accumulator += delta
	if _target_update_accumulator < target_update_interval:
		return
	_target_update_accumulator = 0.0
	_update_target_debug()

func _unhandled_input(event: InputEvent) -> void:
	if _is_modal_ui_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		try_interact()

func _query_target() -> Dictionary:
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	var camera := get_viewport().get_camera_3d()
	if not player or not camera:
		return {}

	# First choice: exactly what the camera is pointing at.
	force_raycast_update()
	if is_colliding():
		var ray_collider := get_collider() as Node
		var ray_handler := _find_handler(ray_collider, "interact")
		if not ray_handler:
			ray_handler = _find_handler(ray_collider, "resonate")
		if ray_handler:
			var point := _get_interaction_point(ray_handler, get_collision_point())
			var direct_distance := player.global_position.distance_to(point)
			# An aimed-but-unavailable object must not block fallback selection.
			if direct_distance <= MAX_TARGET_DISTANCE and _is_handler_eligible(ray_handler, player):
				return {
					"collider": ray_collider,
					"handler": ray_handler,
					"position": point,
					"distance": direct_distance,
					"screen_score": 0.0,
					"eligible": true
				}

	# Fallback: gather interactables around the player, but choose by where
	# they appear on screen instead of by raw world-space angle.
	var shape := SphereShape3D.new()
	shape.radius = MAX_TARGET_DISTANCE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, player.global_position)
	query.collision_mask = INTERACTION_LAYER_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = true
	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]

	var hits := get_world_3d().direct_space_state.intersect_shape(query, 16)
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_center := viewport_size * 0.5
	var best_eligible := {}
	var best_eligible_score := INF
	var best_ineligible := {}
	var best_ineligible_score := INF
	var seen_handlers: Dictionary = {}

	for hit in hits:
		var collider := hit.get("collider") as Node
		if not collider:
			continue

		var handler := _find_handler(collider, "interact")
		if not handler:
			handler = _find_handler(collider, "resonate")
		if not handler or seen_handlers.has(handler.get_instance_id()):
			continue
		seen_handlers[handler.get_instance_id()] = true

		var point := _get_interaction_point(handler, Vector3.ZERO)
		var distance := player.global_position.distance_to(point)
		if distance <= 0.05 or distance > MAX_TARGET_DISTANCE:
			continue
		if camera.is_position_behind(point):
			continue

		var screen_position := camera.unproject_position(point)
		var screen_offset := screen_position.distance_to(screen_center)
		var normalized_screen_offset := screen_offset / maxf(1.0, viewport_size.y)
		var allowed_screen_radius := NEAR_TARGET_SCREEN_RADIUS if distance <= NEAR_TARGET_ASSIST_DISTANCE else MAX_SCREEN_RADIUS
		if normalized_screen_offset > allowed_screen_radius:
			continue

		# Screen center dominates. Distance breaks ties without forcing
		# the player into an exact interaction position. Score first so the
		# fallback does not perform line-of-sight raycasts for candidates that
		# cannot beat the current best target.
		var score := normalized_screen_offset + distance * TARGET_SCORE_DISTANCE_WEIGHT
		if distance <= NEAR_TARGET_ASSIST_DISTANCE:
			score -= 0.06

		var eligible := _is_handler_eligible(handler, player)
		var current_best_score := best_eligible_score if eligible else best_ineligible_score
		if score >= current_best_score:
			continue
		if not _has_line_of_sight(camera.global_position, point, player, handler):
			continue
		var candidate := {
			"collider": collider,
			"handler": handler,
			"position": point,
			"distance": distance,
			"screen_score": normalized_screen_offset,
			"eligible": eligible
		}

		if eligible:
			if score < best_eligible_score:
				best_eligible_score = score
				best_eligible = candidate
		elif score < best_ineligible_score:
			best_ineligible_score = score
			best_ineligible = candidate

	# Never let an unavailable object consume the interaction request when a
	# valid candidate is visible. If nothing valid is available, retain the
	# best ineligible target so the HUD can still explain the requirement.
	return best_eligible if not best_eligible.is_empty() else best_ineligible

func try_interact() -> void:
	var hit := _query_target()
	if hit.is_empty():
		_set_target_state("NONE", "", "", Vector3.ZERO)
		return

	var handler := hit.get("handler") as Node
	if not bool(hit.get("eligible", true)):
		return
	var collision_point: Vector3 = hit.get("position", Vector3.ZERO)
	if not handler:
		_set_target_state("UNKNOWN", "", "", collision_point)
		return

	if handler.has_method("interact"):
		var network_manager := get_tree().get_first_node_in_group("network_manager")
		var network_active: bool = network_manager != null and network_manager.has_method("submit_local_interaction") and bool(network_manager.session_active) and not bool(network_manager.is_host)
		if network_active:
			network_manager.submit_local_interaction(handler)
		else:
			handler.interact()
		var player := get_tree().get_first_node_in_group("local_player")
		if player and player.has_method("play_tool_use"):
			player.play_tool_use()
		_set_target_state(_classify_target(handler), handler.name, "interact()", collision_point)
		if target_label and handler.has_method("get_interaction_feedback"):
			var feedback := str(handler.get_interaction_feedback())
			if not feedback.is_empty():
				target_label.text = feedback
		return

	if handler.has_method("resonate"):
		handler.resonate(resonance_strength)
		_set_target_state(_classify_target(handler), handler.name, "resonate()", collision_point)

func _update_target_debug() -> void:
	var hit := _query_target()
	if hit.is_empty():
		_set_target_state("NONE", "", "", Vector3.ZERO, false)
		return

	var handler := hit.get("handler") as Node
	var point: Vector3 = hit.get("position", Vector3.ZERO)
	if not handler:
		_set_target_state("UNKNOWN", "", "", point, false)
		return

	var action := "interact()" if handler.has_method("interact") else "resonate()" if handler.has_method("resonate") else ""
	_set_target_state(_classify_target(handler), handler.name, action, point, bool(hit.get("eligible", false)))

func _set_target_state(target_type: String, target_name: String, handler: String, collision_point: Vector3, eligible: bool = false) -> void:
	last_target_type = target_type
	last_target_name = target_name
	last_handler_name = handler
	last_requirement = ""
	last_collision_point = collision_point
	var handler_node := _find_handler_from_name(handler)
	if handler_node and not eligible and handler_node.has_method("get_interaction_requirement"):
		last_requirement = str(handler_node.get_interaction_requirement(get_tree().get_first_node_in_group("local_player")))

	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	var actionable := handler != "" and eligible
	var action_label := _get_action_label(target_type)
	if handler_node and handler_node.has_method("get_interaction_text"):
		var custom_action := str(handler_node.get_interaction_text())
		if not custom_action.is_empty():
			action_label = custom_action

	if interact_button:
		interact_button.disabled = not actionable
		interact_button.text = action_label

	if target_label:
		target_label.visible = false
		if target_panel:
			target_panel.visible = true
		if target_action:
			target_action.text = action_label.to_upper() if handler != "" else "LOOK TO INTERACT"
		if target_detail:
			if handler == "":
				target_detail.text = "CENTER YOUR VIEW"
			else:
				var distance_text := "--"
				if player:
					distance_text = "%.1f m" % player.global_position.distance_to(collision_point)
				var detail := target_name if target_name != "" else "UNKNOWN"
				if not eligible and last_requirement != "":
					detail += "  •  REQUIRES " + last_requirement.to_upper()
				detail += "  •  " + distance_text
				target_detail.text = detail

func _find_handler_from_name(handler_name: String) -> Node:
	if handler_name == "":
		return null
	var player := get_tree().get_first_node_in_group("local_player")
	if not player:
		return null
	for group_name in ["resource_node", "interactable"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node.name == handler_name:
				return node
	return null

func _get_action_label(target_type: String) -> String:
	match target_type:
		"RESOURCE":
			return "GATHER"
		"ANOMALY":
			return "RESONATE"
		_:
			return "USE"

func _get_interaction_point(handler: Node, fallback: Vector3) -> Vector3:
	if handler.has_method("get_interaction_point"):
		return handler.get_interaction_point()
	if handler is Node3D:
		return (handler as Node3D).global_position + Vector3.UP * 0.6
	return fallback

func _has_line_of_sight(origin: Vector3, target: Vector3, player: Node3D, handler: Node) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, target, INTERACTION_LAYER_MASK)
	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var blocker := result.get("collider") as Node
	return blocker == handler or _find_handler(blocker, "interact") == handler or _find_handler(blocker, "resonate") == handler

func _is_handler_eligible(handler: Node, player: Node) -> bool:
	if handler.has_method("can_interact"):
		return bool(handler.can_interact(player))
	return true

func _classify_target(node: Node) -> String:
	if not node:
		return "UNKNOWN"
	if node.is_in_group("resource_node"):
		return "RESOURCE"
	if node.is_in_group("anomaly"):
		return "ANOMALY"
	var lower := node.name.to_lower()
	if lower.contains("terrain"):
		return "TERRAIN"
	if lower.contains("tree"):
		return "TREE"
	if lower.contains("rock"):
		return "ROCK"
	if lower.contains("mineral"):
		return "MINERAL"
	return "INTERACTABLE"

func _find_handler(start: Node, method_name: String) -> Node:
	var current: Node = start
	var depth := 0
	while current and depth < MAX_HANDLER_DEPTH:
		if current.has_method(method_name):
			return current
		current = current.get_parent()
		depth += 1
	return null


func _is_modal_ui_open() -> bool:
	for group_name in ["building_ui", "modal_ui", "craft_build_ui"]:
		for ui in get_tree().get_nodes_in_group(group_name):
			if ui and ui.has_method("is_modal_open") and bool(ui.is_modal_open()):
				return true
	return false


func _interaction_hud_style() -> void:
	if not target_panel:
		return
	target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.025, 0.035, 0.90)
	panel_style.border_color = Color(0.20, 0.68, 0.72, 0.70)
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 7
	panel_style.corner_radius_top_right = 7
	panel_style.corner_radius_bottom_left = 7
	panel_style.corner_radius_bottom_right = 7
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_right = 12.0
	target_panel.add_theme_stylebox_override("panel", panel_style)
	target_panel.custom_minimum_size = Vector2(300.0, 68.0)
	target_panel.add_theme_constant_override("separation", 2)
	if target_action:
		target_action.add_theme_font_size_override("font_size", 13)
		target_action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		target_action.add_theme_color_override("font_color", Color(0.42, 0.88, 0.90, 1.0))
		target_action.add_theme_constant_override("outline_size", 4)
		target_action.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	if target_detail:
		target_detail.add_theme_font_size_override("font_size", 10)
		target_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		target_detail.add_theme_color_override("font_color", Color(0.78, 0.84, 0.86, 1.0))
