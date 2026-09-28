extends CharacterBody3D

## Veyra mobile-first first-person controller.
## Left side: dynamic movement joystick.
## Right side: camera look.
## Desktop: WASD + mouse.

@export_category("Movement")
@export var speed: float = 5.2
@export var acceleration: float = 22.0
@export var braking: float = 28.0
@export var gravity: float = 18.0
@export var jump_velocity: float = 7.0
@export var jump_forward_boost: float = 1.35
@export var ground_snap_distance: float = 0.35
@export var max_floor_angle_degrees: float = 48.0
@export var safe_spawn_height: float = 12.0

@export_category("Look")
@export var mouse_sensitivity: float = 0.003
@export var touch_look_multiplier: float = 2.0
@export var min_pitch_degrees: float = -70.0
@export var max_pitch_degrees: float = 55.0

@export_category("Camera")
@export var camera_distance: float = 0.0
@export var camera_height: float = 1.72
@export var camera_fov: float = 66.0
@export var camera_far: float = 140.0

@export_category("Mobile Joystick")
@export var joystick_radius: float = 70.0
@export_range(0.0, 0.5, 0.01) var joystick_deadzone: float = 0.12
@export_range(0.1, 0.9, 0.01) var left_screen_ratio: float = 0.48

var look_pitch: float = deg_to_rad(-5.0)
var target_yaw: float = 0.0
@export_range(0.0, 30.0, 0.5) var camera_yaw_smoothing: float = 18.0
var move_input: Vector2 = Vector2.ZERO
var jump_requested := false
var move_touch_id: int = -1
var look_touch_id: int = -1
var touch_start: Dictionary = {}

@onready var joystick_base: Control = get_node_or_null("MobileControls/JoystickBase") as Control
@onready var joystick_knob: Control = get_node_or_null("MobileControls/JoystickBase/JoystickKnob") as Control
@onready var interact_button: Button = get_node_or_null("MobileControls/InteractButton") as Button
@onready var jump_button: Button = get_node_or_null("MobileControls/JumpButton") as Button
@onready var camera: Camera3D = get_node_or_null("Camera3D") as Camera3D
@onready var left_leg: MeshInstance3D = get_node_or_null("LeftLeg") as MeshInstance3D
@onready var right_leg: MeshInstance3D = get_node_or_null("RightLeg") as MeshInstance3D
@onready var left_arm: MeshInstance3D = get_node_or_null("LeftArm") as MeshInstance3D
@onready var right_arm: MeshInstance3D = get_node_or_null("RightArm") as MeshInstance3D
@onready var torso: MeshInstance3D = get_node_or_null("Torso") as MeshInstance3D
@onready var head: MeshInstance3D = get_node_or_null("Head") as MeshInstance3D
@onready var hair: MeshInstance3D = get_node_or_null("Hair") as MeshInstance3D
@onready var left_eye: MeshInstance3D = get_node_or_null("LeftEye") as MeshInstance3D
@onready var right_eye: MeshInstance3D = get_node_or_null("RightEye") as MeshInstance3D
@onready var left_hand: MeshInstance3D = get_node_or_null("LeftHand") as MeshInstance3D
@onready var right_hand: MeshInstance3D = get_node_or_null("RightHand") as MeshInstance3D
@onready var left_leg_mesh: MeshInstance3D = get_node_or_null("LeftLeg") as MeshInstance3D
@onready var right_leg_mesh: MeshInstance3D = get_node_or_null("RightLeg") as MeshInstance3D
@onready var left_foot_mesh: MeshInstance3D = get_node_or_null("LeftFoot") as MeshInstance3D
@onready var right_foot_mesh: MeshInstance3D = get_node_or_null("RightFoot") as MeshInstance3D
@onready var fp_left_arm: MeshInstance3D = get_node_or_null("Camera3D/ViewModel/LeftArmFP") as MeshInstance3D
@onready var fp_right_arm: MeshInstance3D = get_node_or_null("Camera3D/ViewModel/RightArmFP") as MeshInstance3D
@onready var fp_left_sleeve: MeshInstance3D = get_node_or_null("Camera3D/ViewModel/LeftSleeveFP") as MeshInstance3D
@onready var fp_right_sleeve: MeshInstance3D = get_node_or_null("Camera3D/ViewModel/RightSleeveFP") as MeshInstance3D
@onready var fp_left_hand: MeshInstance3D = get_node_or_null("Camera3D/ViewModel/LeftHandFP") as MeshInstance3D
@onready var fp_right_hand: MeshInstance3D = get_node_or_null("Camera3D/ViewModel/RightHandFP") as MeshInstance3D
@onready var fp_left_cuff: MeshInstance3D = get_node_or_null("Camera3D/ViewModel/LeftCuffFP") as MeshInstance3D
@onready var fp_right_cuff: MeshInstance3D = get_node_or_null("Camera3D/ViewModel/RightCuffFP") as MeshInstance3D
@onready var fp_axe_lash_upper: MeshInstance3D = get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool/AxeLashUpper") as MeshInstance3D
@onready var fp_axe_lash_lower: MeshInstance3D = get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool/AxeLashLower") as MeshInstance3D
@onready var fp_pick_collar: MeshInstance3D = get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool/PickCollar") as MeshInstance3D
@onready var tool_holder: Node3D = get_node_or_null("Camera3D/ViewModel/ToolHolder") as Node3D
@onready var equipped_tool_visual: Node3D = get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool") as Node3D
var walk_time: float = 0.0
var _tool_swing_time: float = 0.0
var _tool_swing_duration: float = 0.28
var _tool_swing_active: bool = false
var _tool_base_rotation: Vector3 = Vector3.ZERO
var _punch_time: float = 0.0
var _punch_active: bool = false
const PUNCH_DURATION := 0.26
signal tool_changed(tool_id: String, durability: float)

var selected_tool_id: String = "T00_HANDS"
var tool_durability: float = 100.0
var resonance_charge: float = 0.0
var resonance_discovered: bool = false

signal resonance_changed(charge: float, discovered: bool)
signal resonance_tier_changed(tier: int, tier_name: String)

func get_resonance() -> float:
	return resonance_charge

func get_resonance_discovered() -> bool:
	return resonance_discovered

func get_resonance_tier() -> int:
	if resonance_charge >= 100.0:
		return 5
	if resonance_charge >= 75.0:
		return 4
	if resonance_charge >= 50.0:
		return 3
	if resonance_charge >= 25.0:
		return 2
	if resonance_charge >= 10.0:
		return 1
	return 0

func get_resonance_tier_name() -> String:
	match get_resonance_tier():
		5:
			return "CONVERGENCE"
		4:
			return "RESONANT"
		3:
			return "ATTUNED"
		2:
			return "AWAKENED"
		1:
			return "SENSITIZED"
		_:
			return "DORMANT"

func add_resonance(amount: float) -> void:
	if amount <= 0.0:
		return
	var previous_tier := get_resonance_tier()
	resonance_charge = clampf(resonance_charge + amount, 0.0, 100.0)
	if not resonance_discovered:
		resonance_discovered = true
	var new_tier := get_resonance_tier()
	resonance_changed.emit(resonance_charge, resonance_discovered)
	if new_tier != previous_tier:
		resonance_tier_changed.emit(new_tier, get_resonance_tier_name())

func set_resonance_state(charge: float, discovered: bool) -> void:
	var previous_tier := get_resonance_tier()
	resonance_charge = clampf(charge, 0.0, 100.0)
	resonance_discovered = discovered
	resonance_changed.emit(resonance_charge, resonance_discovered)
	var new_tier := get_resonance_tier()
	if new_tier != previous_tier:
		resonance_tier_changed.emit(new_tier, get_resonance_tier_name())

# Multiplayer alpha: the server owns movement state; clients send input and
# receive authoritative transforms. Offline play remains unchanged.
var _network_mode: bool = false
var _network_local: bool = true
var _network_peer_id: int = 1
var _network_input: Vector2 = Vector2.ZERO
var _network_jump: bool = false
var _network_target_position: Vector3 = Vector3.ZERO
var _network_target_yaw: float = 0.0
var _network_input_accumulator: float = 0.0
var _network_input_interval: float = 0.05


func get_tool_id() -> String:
	return selected_tool_id

func set_tool(tool_id: String) -> bool:
	var next_tool := tool_id if tool_id != "" else VeyraItemCatalog.HANDS_ID
	if not VeyraItemCatalog.is_valid_tool(next_tool):
		return false
	if next_tool != VeyraItemCatalog.HANDS_ID:
		var inventory := get_inventory()
		if not inventory or not inventory.has_item(next_tool):
			return false
	if next_tool == selected_tool_id:
		return true
	selected_tool_id = next_tool
	tool_durability = 100.0
	tool_changed.emit(selected_tool_id, tool_durability)
	_update_equipped_tool_visual()
	return true

func can_use_tool(durability_cost: float = 1.0) -> bool:
	return selected_tool_id == "T00_HANDS" or (tool_durability > 0.0 and durability_cost >= 0.0)

func use_tool(durability_cost: float = 1.0) -> bool:
	if not can_use_tool(durability_cost):
		return false
	if selected_tool_id != "T00_HANDS":
		tool_durability = maxf(0.0, tool_durability - maxf(0.0, durability_cost))
		if tool_durability <= 0.0:
			selected_tool_id = "T00_HANDS"
		tool_changed.emit(selected_tool_id, tool_durability)
		_update_equipped_tool_visual()
	return true

func get_save_state() -> Dictionary:
	return {
		"tool_id": selected_tool_id,
		"tool_durability": clampf(tool_durability, 0.0, 100.0),
		"resonance_charge": resonance_charge,
		"resonance_discovered": resonance_discovered,
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y,
		"pitch": look_pitch
	}

func load_save_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	var saved_position = state.get("position", [])
	if saved_position is Array and saved_position.size() >= 3:
		global_position = Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))
		velocity = Vector3.ZERO
	rotation.y = float(state.get("yaw", rotation.y))
	target_yaw = rotation.y
	look_pitch = clampf(float(state.get("pitch", look_pitch)), deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	if camera:
		camera.rotation.x = look_pitch
	var tool_id := str(state.get("tool_id", "T00_HANDS"))
	var inventory := get_inventory()
	if tool_id != "T00_HANDS" and (not inventory or not inventory.has_item(tool_id)):
		tool_id = "T00_HANDS"
	selected_tool_id = tool_id
	tool_durability = clampf(float(state.get("tool_durability", 100.0)), 0.0, 100.0)
	resonance_charge = clampf(float(state.get("resonance_charge", 0.0)), 0.0, 100.0)
	resonance_discovered = bool(state.get("resonance_discovered", resonance_charge > 0.0))
	if selected_tool_id == "T00_HANDS":
		tool_durability = 100.0
	tool_changed.emit(selected_tool_id, tool_durability)
	_update_equipped_tool_visual()

func _update_equipped_tool_visual() -> void:
	var tool_visual := equipped_tool_visual
	if not tool_visual:
		return
	tool_visual.visible = selected_tool_id != "T00_HANDS"
	_tool_swing_active = false
	_tool_swing_time = 0.0
	if not tool_visual.visible:
		if fp_left_hand:
			fp_left_hand.position = Vector3(-0.22, -1.10, -1.04)
		if fp_right_hand:
			fp_right_hand.position = Vector3(0.22, -1.10, -1.04)
		return
	# Tools are held at the lower handle rather than floating in front of the camera.
	if fp_left_hand:
		fp_left_hand.position = Vector3(0.03, -0.78, -1.10)
	if fp_right_hand:
		fp_right_hand.position = Vector3(0.28, -0.62, -1.10)
	var axe_head := get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool/AxeHead") as MeshInstance3D
	var axe_blade := get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool/AxeBlade") as MeshInstance3D
	var axe_collar := get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool/AxeCollar") as MeshInstance3D
	var pick_head := get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool/PickHead") as MeshInstance3D
	var pick_spike_left := get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool/PickSpikeLeft") as MeshInstance3D
	var pick_spike_right := get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool/PickSpikeRight") as MeshInstance3D
	var axe_equipped := selected_tool_id == "I01_STONE_AXE"
	var pick_equipped := selected_tool_id == "I02_STONE_PICK"
	if axe_head:
		axe_head.visible = axe_equipped
	if axe_blade:
		axe_blade.visible = axe_equipped
	if axe_collar:
		axe_collar.visible = axe_equipped
	if fp_axe_lash_upper:
		fp_axe_lash_upper.visible = axe_equipped
	if fp_axe_lash_lower:
		fp_axe_lash_lower.visible = axe_equipped
	if fp_pick_collar:
		fp_pick_collar.visible = pick_equipped
	if pick_head:
		pick_head.visible = pick_equipped
	if pick_spike_left:
		pick_spike_left.visible = pick_equipped
	if pick_spike_right:
		pick_spike_right.visible = pick_equipped
	match selected_tool_id:
		"I01_STONE_AXE":
			tool_visual.rotation_degrees = Vector3(0, 0, -12)
			tool_visual.scale = Vector3(0.68, 0.68, 0.68)
		"I02_STONE_PICK":
			tool_visual.rotation_degrees = Vector3(0, 0, 12)
			tool_visual.scale = Vector3(0.76, 0.76, 0.76)
		_:
			tool_visual.visible = false

func get_inventory() -> VeyraInventory:
	return get_node_or_null("Inventory") as VeyraInventory

func add_resource(resource_type: String, amount: int) -> void:
	var inventory := get_inventory()
	if inventory:
		inventory.add_resource(resource_type, amount)


func _ready() -> void:
	# Gameplay input/physics must remain alive even while modal UI layers are ALWAYS.
	# UI owns touch regions; the player owns gameplay input outside those regions.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("player")
	_network_mode = bool(get_meta("network_mode", false))
	_network_local = bool(get_meta("network_local", true))
	_network_peer_id = int(get_meta("network_peer_id", 1))
	if _network_local:
		add_to_group("local_player")
	if _network_mode and not _network_local:
		_disable_local_presentation()

	# Give a brand-new save a generous starter cache so the beta loop is testable
	# immediately. Loaded saves are left untouched.
	if GameManager and GameManager.get_loaded_save().is_empty():
		var starter_inventory := get_inventory()
		if starter_inventory:
			# New saves begin empty. Early-game materials must be gathered, not granted.
	up_direction = Vector3.UP
	floor_snap_length = ground_snap_distance
	floor_max_angle = deg_to_rad(max_floor_angle_degrees)
	call_deferred("_stabilize_spawn")

	if interact_button and not interact_button.pressed.is_connected(_on_interact_pressed):
		interact_button.pressed.connect(_on_interact_pressed)
	if jump_button and not jump_button.pressed.is_connected(_on_jump_pressed):
		jump_button.pressed.connect(_on_jump_pressed)

	if _network_local:
		_configure_camera()
		_configure_first_person_view()
		_hide_joystick()
	else:
		_disable_local_presentation()
	_update_equipped_tool_visual()
	_tool_base_rotation = Vector3(-14.0, -12.0, -8.0)
	if tool_holder:
		tool_holder.rotation_degrees = _tool_base_rotation


func _configure_camera() -> void:
	if not camera:
		return

	camera.current = true
	camera.fov = camera_fov
	camera.far = camera_far
	camera.position = Vector3(0.0, camera_height, 0.08 + camera_distance)
	camera.rotation = Vector3(look_pitch, 0.0, 0.0)
	look_pitch = camera.rotation.x
	target_yaw = rotation.y


func _configure_first_person_view() -> void:
	# Preserve the real body for shadows, third-person presentation, and the future multiplayer/NPC
	# character pipeline. Only the head/face is hidden from the near-camera view; the lower body
	# remains coherent beneath the camera instead of being replaced by a disconnected FPS body.
	for mesh in [torso, head, hair, left_eye, right_eye, left_arm, right_arm, left_hand, right_hand, left_leg_mesh, right_leg_mesh, left_foot_mesh, right_foot_mesh]:
		if mesh:
			mesh.visible = false
	for mesh in [fp_left_arm, fp_right_arm, fp_left_hand, fp_right_hand, fp_left_sleeve, fp_right_sleeve, fp_left_cuff, fp_right_cuff]:
		if mesh:
			mesh.visible = true
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var viewmodel := get_node_or_null("Camera3D/ViewModel") as Node3D
	if viewmodel:
		for child in viewmodel.get_children():
			if child is GeometryInstance3D:
				(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The authoritative body remains present for remote-player instances; the local copy is hidden
	# so the camera never intersects its torso or legs.

func _stabilize_spawn() -> void:
	var world_generator := get_parent().get_node_or_null("WorldGenerator")
	if world_generator and world_generator.has_method("is_generated") and world_generator.is_generated():
		var terrain_y: float = world_generator.get_height_at_world(global_position.x, global_position.z)
		global_position.y = maxf(global_position.y, terrain_y + 1.5)
		velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if _is_modal_ui_open():
		velocity.x = 0.0
		velocity.z = 0.0
		jump_requested = false
		move_input = Vector2.ZERO
		return
	if _network_mode:
		_network_physics(delta)
		return

	_recover_from_fall()
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-camera_yaw_smoothing * delta))
	var input_vector: Vector2 = _get_local_move_input()

	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	var direction: Vector3 = _camera_relative_direction(input_vector)

	if direction.length_squared() > 0.001:
		direction = direction.normalized()

		velocity.x = move_toward(
			velocity.x,
			direction.x * speed,
			acceleration * delta
		)
		velocity.z = move_toward(
			velocity.z,
			direction.z * speed,
			acceleration * delta
		)
	else:
		velocity.x = move_toward(velocity.x, 0.0, braking * delta)
		velocity.z = move_toward(velocity.z, 0.0, braking * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif jump_requested:
		velocity.y = jump_velocity
		var jump_direction := direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO
		if jump_direction != Vector3.ZERO:
			velocity.x += jump_direction.x * jump_forward_boost
			velocity.z += jump_direction.z * jump_forward_boost
	else:
		velocity.y = 0.0

	jump_requested = false

	move_and_slide()
	_update_player_visuals(delta, direction)
	_update_tool_animation(delta)

func configure_network_role(peer_id: int, local_control: bool) -> void:
	_network_mode = true
	_network_peer_id = peer_id
	_network_local = local_control
	set_meta("network_mode", true)
	set_meta("network_local", local_control)
	set_meta("network_peer_id", peer_id)
	set_multiplayer_authority(peer_id, true)
	if local_control:
		add_to_group("local_player")
		_configure_camera()
		_configure_first_person_view()
		_hide_joystick()
	else:
		remove_from_group("local_player")
		_disable_local_presentation()

func configure_offline_role() -> void:
	_network_mode = false
	_network_local = true
	_network_peer_id = 1
	_network_input = Vector2.ZERO
	_network_jump = false
	set_meta("network_mode", false)
	set_meta("network_local", true)
	set_multiplayer_authority(1, true)
	add_to_group("local_player")
	_configure_camera()
	_configure_first_person_view()
	_hide_joystick()
	var controls := get_node_or_null("MobileControls") as CanvasLayer
	if controls:
		controls.visible = true
	var craft_ui := get_node_or_null("CraftBuildUI") as CanvasLayer
	if craft_ui:
		craft_ui.visible = true
	var inventory_ui := get_node_or_null("HUDInventory") as CanvasLayer
	if inventory_ui:
		inventory_ui.visible = true
	var viewmodel := get_node_or_null("Camera3D/ViewModel") as Node3D
	if viewmodel:
		viewmodel.visible = true
		for child in viewmodel.get_children():
			if child is GeometryInstance3D:
				(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func set_network_input(input_vector: Vector2, jump: bool, yaw: float) -> void:
	_network_input = input_vector.limit_length(1.0)
	_network_jump = jump
	_network_target_yaw = yaw

func apply_network_state(position_value: Vector3, yaw: float) -> void:
	_network_target_position = position_value
	_network_target_yaw = yaw
	if not _network_mode:
		return
	if _network_local:
		if global_position.distance_to(position_value) > 4.0:
			global_position = position_value
	else:
		if global_position == Vector3.ZERO:
			global_position = position_value

func get_network_state() -> Dictionary:
	return {
		"peer_id": _network_peer_id,
		"position": global_position,
		"yaw": rotation.y
	}

func _network_physics(delta: float) -> void:
	# Never strand the local controller during network startup/peer teardown.
	# If the multiplayer peer is not active yet, use the normal local simulation.
	if not multiplayer.has_multiplayer_peer():
		if _network_local:
			_recover_from_fall()
			rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-camera_yaw_smoothing * delta))
			var input_vector := _get_local_move_input()
			_simulate_movement(delta, input_vector, jump_requested)
			jump_requested = false
			_update_player_visuals(delta, _camera_relative_direction(input_vector))
		return

	if multiplayer.is_server():
		var input_vector := _network_input
		var jump := _network_jump
		if _network_local:
			input_vector = _get_local_move_input()
			jump = jump_requested
			rotation.y = target_yaw
		else:
			rotation.y = _network_target_yaw

		_simulate_movement(delta, input_vector, jump)
		_network_jump = false
		jump_requested = false
		_update_player_visuals(delta, _camera_relative_direction(input_vector))
		return

	if _network_local:
		_network_input_accumulator += delta
		if _network_input_accumulator >= _network_input_interval:
			_network_input_accumulator = 0.0
			var jump_to_send := jump_requested
			jump_requested = false
			NetworkManager.submit_local_input(
				_get_local_move_input(),
				target_yaw,
				look_pitch,
				jump_to_send
			)
		rotation.y = lerp_angle(rotation.y, _network_target_yaw, 1.0 - exp(-12.0 * delta))
		global_position = global_position.lerp(_network_target_position, 1.0 - exp(-9.0 * delta))
	else:
		global_position = global_position.lerp(_network_target_position, 1.0 - exp(-12.0 * delta))
		rotation.y = lerp_angle(rotation.y, _network_target_yaw, 1.0 - exp(-12.0 * delta))

	# Presentation is updated on interpolated network clients too. This keeps
	# first-person hand actions responsive and remote bodies visually animated
	# without changing authoritative movement.
	var visual_input := _get_local_move_input() if _network_local else _network_input
	var visual_direction := _camera_relative_direction(visual_input) if _network_local else _yaw_relative_direction(rotation.y, visual_input)
	_update_player_visuals(delta, visual_direction)
	_update_tool_animation(delta)

func _simulate_movement(delta: float, input_vector: Vector2, jump: bool) -> void:
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	var direction := _yaw_relative_direction(rotation.y, input_vector) if _network_mode and not _network_local else _camera_relative_direction(input_vector)
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, braking * delta)
		velocity.z = move_toward(velocity.z, 0.0, braking * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif jump:
		velocity.y = jump_velocity
		var jump_direction := direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO
		if jump_direction != Vector3.ZERO:
			velocity.x += jump_direction.x * jump_forward_boost
			velocity.z += jump_direction.z * jump_forward_boost
	else:
		velocity.y = 0.0

	move_and_slide()

func _is_modal_ui_open() -> bool:
	for ui in get_tree().get_nodes_in_group("building_ui"):
		if ui and ui.has_method("is_modal_open") and bool(ui.is_modal_open()):
			return true
	for ui in get_tree().get_nodes_in_group("modal_ui"):
		if ui and ui.has_method("is_modal_open") and bool(ui.is_modal_open()):
			return true
	return false

func _get_local_move_input() -> Vector2:
	var input_vector := move_input
	if input_vector.length_squared() < 0.0001:
		input_vector = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_back", "move_forward")
		)
	return input_vector.limit_length(1.0)

func _disable_local_presentation() -> void:
	var camera_node := get_node_or_null("Camera3D") as Camera3D
	if camera_node:
		camera_node.current = false
	var controls := get_node_or_null("MobileControls") as CanvasLayer
	if controls:
		controls.visible = false
	var craft_ui := get_node_or_null("CraftBuildUI") as CanvasLayer
	if craft_ui:
		craft_ui.visible = false
	var inventory_ui := get_node_or_null("HUDInventory") as CanvasLayer
	if inventory_ui:
		inventory_ui.visible = false
	var viewmodel := get_node_or_null("Camera3D/ViewModel") as Node3D
	if viewmodel:
		viewmodel.visible = false

func play_tool_use() -> void:
	if selected_tool_id == VeyraItemCatalog.HANDS_ID:
		_punch_time = 0.0
		_punch_active = true
		return
	if not equipped_tool_visual or not equipped_tool_visual.visible:
		return
	_tool_swing_time = 0.0
	_tool_swing_active = true

func _update_tool_animation(delta: float) -> void:
	_update_punch_animation(delta)
	if not tool_holder:
		return
	if not _tool_swing_active:
		tool_holder.rotation_degrees = tool_holder.rotation_degrees.lerp(_tool_base_rotation, minf(1.0, delta * 14.0))
		return

	_tool_swing_time += delta
	var progress := clampf(_tool_swing_time / _tool_swing_duration, 0.0, 1.0)
	var arc := sin(progress * PI)
	var lift := -48.0 * arc
	var side := 12.0 * arc
	tool_holder.rotation_degrees = _tool_base_rotation + Vector3(lift, side, -7.0 * arc)
	tool_holder.position = Vector3(0.30 + 0.035 * arc, -0.78 - 0.04 * arc, -1.10 + 0.12 * arc)
	if fp_right_hand:
		fp_right_hand.position = Vector3(0.30, -0.73 - 0.05 * arc, -1.06 + 0.10 * arc)
	if fp_left_hand:
		fp_left_hand.position = Vector3(0.08, -0.86 - 0.03 * arc, -1.02 + 0.06 * arc)
	if progress >= 1.0:
		_tool_swing_active = false
		tool_holder.position = Vector3(0.30, -0.78, -1.10)
		tool_holder.rotation_degrees = _tool_base_rotation
		_update_equipped_tool_visual()

func _update_punch_animation(delta: float) -> void:
	if not _punch_active:
		return
	_punch_time += delta
	var progress := clampf(_punch_time / PUNCH_DURATION, 0.0, 1.0)
	var arc := sin(progress * PI)
	var thrust := sin(progress * PI * 0.5)
	if fp_left_arm:
		fp_left_arm.rotation = Vector3(deg_to_rad(-18.0 - 42.0 * arc), deg_to_rad(-8.0), deg_to_rad(-7.0 + 12.0 * arc))
		fp_left_arm.position = Vector3(-0.24, -0.48 - 0.07 * thrust, -0.66 - 0.42 * thrust)
	if fp_left_sleeve:
		fp_left_sleeve.rotation = fp_left_arm.rotation if fp_left_arm else Vector3(deg_to_rad(-18.0), deg_to_rad(-8.0), deg_to_rad(-7.0))
		fp_left_sleeve.position = Vector3(-0.24, -0.58 - 0.07 * thrust, -0.78 - 0.42 * thrust)
	if fp_right_arm:
		fp_right_arm.rotation = Vector3(deg_to_rad(-18.0 - 86.0 * arc), deg_to_rad(6.0), deg_to_rad(8.0 - 24.0 * arc))
		fp_right_arm.position = Vector3(0.24, -0.48 - 0.10 * thrust, -0.66 - 0.58 * thrust)
	if fp_right_sleeve:
		fp_right_sleeve.rotation = fp_right_arm.rotation if fp_right_arm else Vector3(deg_to_rad(-18.0), deg_to_rad(6.0), deg_to_rad(8.0))
		fp_right_sleeve.position = Vector3(0.24, -0.58 - 0.10 * thrust, -0.78 - 0.58 * thrust)
	if fp_left_hand:
		fp_left_hand.position = Vector3(-0.24, -0.93 - 0.05 * thrust, -0.94 - 0.45 * thrust)
	if fp_left_cuff:
		fp_left_cuff.position = Vector3(-0.22, -0.94 - 0.04 * thrust, -1.00 - 0.25 * thrust)
	if fp_right_hand:
		fp_right_hand.position = Vector3(0.24, -0.93 - 0.08 * thrust, -0.96 - 0.62 * thrust)
	if fp_right_cuff:
		fp_right_cuff.position = Vector3(0.22, -0.94 - 0.06 * thrust, -1.00 - 0.32 * thrust)
	if progress >= 1.0:
		_punch_active = false
		if fp_left_arm:
			fp_left_arm.position = Vector3(-0.24, -0.48, -0.66)
		if fp_left_sleeve:
			fp_left_sleeve.position = Vector3(-0.24, -0.58, -0.78)
			fp_left_sleeve.rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(-8.0), deg_to_rad(-7.0))
			fp_left_arm.rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(-8.0), deg_to_rad(-7.0))
		if fp_right_arm:
			fp_right_arm.position = Vector3(0.24, -0.48, -0.66)
		if fp_right_sleeve:
			fp_right_sleeve.position = Vector3(0.24, -0.58, -0.78)
			fp_right_sleeve.rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(6.0), deg_to_rad(8.0))
			fp_right_arm.rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(6.0), deg_to_rad(8.0))
		if fp_left_hand:
			fp_left_hand.position = Vector3(-0.24, -0.93, -0.94)
		if fp_left_cuff:
			fp_left_cuff.position = Vector3(-0.22, -0.94, -1.00)
		if fp_right_hand:
			fp_right_hand.position = Vector3(0.24, -0.93, -0.96)
		if fp_right_cuff:
			fp_right_cuff.position = Vector3(0.22, -0.94, -1.00)

func _update_player_visuals(delta: float, direction: Vector3) -> void:
	var moving := direction.length_squared() > 0.001 and is_on_floor()
	if moving:
		walk_time += delta * 9.5
	else:
		walk_time = move_toward(walk_time, 0.0, delta * 7.0)

	var stride := sin(walk_time) if moving else 0.0
	var opposite_stride := -stride
	var lift := maxf(0.0, stride) * 0.035 if moving else 0.0
	var opposite_lift := maxf(0.0, opposite_stride) * 0.035 if moving else 0.0
	var arm_swing := stride * 0.18 if moving else 0.0

	if left_leg:
		left_leg.rotation.x = stride * 0.32
		left_leg.position.y = 0.48 + lift
	if right_leg:
		right_leg.rotation.x = opposite_stride * 0.32
		right_leg.position.y = 0.48 + opposite_lift

	# Keep the visible body aligned with the camera's facing direction.
	# The body already follows target_yaw, so pitch is the only extra axis needed.
	var hand_pitch := deg_to_rad(-62.0) + look_pitch * 0.42
	var hand_reach := 0.46
	if fp_left_sleeve:
		fp_left_sleeve.rotation = fp_left_arm.rotation
		fp_left_sleeve.position = Vector3(-0.24, -0.58, -0.78)
	if fp_right_sleeve:
		fp_right_sleeve.rotation = fp_right_arm.rotation
		fp_right_sleeve.position = Vector3(0.24, -0.58, -0.78)

	if left_arm:
		left_arm.rotation.x = hand_pitch - arm_swing * 0.35
		left_arm.rotation.z = deg_to_rad(-10.0) + absf(stride) * 0.035
		left_arm.position = Vector3(-0.37, 1.10, -0.16)
	if right_arm:
		right_arm.rotation.x = hand_pitch + arm_swing * 0.35
		right_arm.rotation.z = deg_to_rad(10.0) - absf(stride) * 0.035
		right_arm.position = Vector3(0.37, 1.10, -0.16)
	if left_hand:
		left_hand.position = Vector3(-0.40, 0.93, -hand_reach) + Vector3(0.0, maxf(0.0, -stride) * 0.035, 0.0)
	if right_hand:
		right_hand.position = Vector3(0.40, 0.93, -hand_reach) + Vector3(0.0, maxf(0.0, stride) * 0.035, 0.0)

	if torso:
		var target_y := 1.15 + (absf(stride) * 0.025 if moving else 0.0)
		torso.position.y = move_toward(torso.position.y, target_y, delta * 2.5)


func _recover_from_fall() -> void:
	var world_generator := get_parent().get_node_or_null("WorldGenerator")
	if not world_generator or not world_generator.has_method("get_height_at_world"):
		return
	var terrain_y: float = world_generator.get_height_at_world(global_position.x, global_position.z)
	if global_position.y < terrain_y - 6.0:
		global_position.y = terrain_y + 1.5
		velocity = Vector3.ZERO


func _yaw_relative_direction(yaw: float, input_vector: Vector2) -> Vector3:
	if input_vector.length_squared() < 0.0001:
		return Vector3.ZERO
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	return right * input_vector.x + forward * input_vector.y

func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector.length_squared() < 0.0001:
		return Vector3.ZERO

	var forward: Vector3 = -global_transform.basis.z

	if camera:
		forward = -camera.global_transform.basis.z

	forward.y = 0.0

	if forward.length_squared() < 0.0001:
		forward = Vector3(0.0, 0.0, -1.0)
	else:
		forward = forward.normalized()

	var right: Vector3 = forward.cross(Vector3.UP)

	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()

	return right * input_vector.x + forward * input_vector.y


func _input(event: InputEvent) -> void:
	# Modal menus own the entire touch surface. Do not let the first-person camera,
	# joystick, or look state continue underneath a crafting/building/pause overlay.
	if _is_modal_ui_open():
		if event is InputEventScreenTouch and event.pressed:
			_clear_touch_state()
			return
		if event is InputEventScreenDrag:
			return
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
			return
		if event is InputEventMouseMotion:
			return
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		jump_requested = true
	elif event is InputEventMouseMotion:
		# Ignore synthetic mouse events generated by touch emulation.
		if event.device == InputEvent.DEVICE_ID_MOUSE:
			_apply_look(event.relative)


func _clear_touch_state() -> void:
	move_touch_id = -1
	look_touch_id = -1
	move_input = Vector2.ZERO
	touch_start.clear()
	_hide_joystick()

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	# Always release touch ownership before checking UI regions. Android may report
	# the finger-up outside the original joystick region.
	if not event.pressed:
		_release_touch(event.index)
		return
	if event.is_canceled():
		_release_touch(event.index)
		return
	if _is_camera_blocking_ui_touch(event.position):
		return

	if event.pressed:
		var screen_width: float = get_viewport().get_visible_rect().size.x

		if (
			event.position.x < screen_width * left_screen_ratio
			and move_touch_id == -1
		):
			move_touch_id = event.index
			touch_start[event.index] = event.position
			move_input = Vector2.ZERO
			_show_joystick(event.position)

		elif (
			event.position.x >= screen_width * left_screen_ratio
			and look_touch_id == -1
		):
			look_touch_id = event.index
			touch_start[event.index] = event.position
	else:
		_release_touch(event.index)


func _is_camera_blocking_ui_touch(position: Vector2) -> bool:
	if interact_button and interact_button.get_global_rect().has_point(position):
		return true
	if jump_button and jump_button.get_global_rect().has_point(position):
		return true
	for control in get_tree().get_nodes_in_group("camera_blocking_ui"):
		if control is Control and control.visible and control.get_global_rect().has_point(position):
			return true
	return false

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == move_touch_id:
		var origin: Vector2 = touch_start.get(event.index, event.position)
		var offset: Vector2 = event.position - origin

		move_input = _joystick_vector(offset)
		_update_joystick(event.position)

	elif event.index == look_touch_id:
		# screen_relative is not affected by content scaling.
		_apply_look(event.screen_relative * touch_look_multiplier)


func _release_touch(index: int) -> void:
	if index == move_touch_id:
		move_touch_id = -1
		move_input = Vector2.ZERO
		_hide_joystick()

	if index == look_touch_id:
		look_touch_id = -1

	touch_start.erase(index)


func _joystick_vector(offset: Vector2) -> Vector2:
	var distance: float = offset.length()

	if distance <= joystick_deadzone * joystick_radius:
		return Vector2.ZERO

	var clamped := offset.limit_length(joystick_radius)

	return Vector2(
		clamped.x / joystick_radius,
		-clamped.y / joystick_radius
	)


func _apply_look(delta: Vector2) -> void:
	target_yaw -= delta.x * mouse_sensitivity

	look_pitch = clamp(
		look_pitch - delta.y * mouse_sensitivity,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)

	if camera:
		camera.rotation.x = look_pitch


func _show_joystick(pos: Vector2) -> void:
	if not joystick_base or not joystick_knob:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var base_size := joystick_base.size
	var half_size := base_size * 0.5
	var min_pos := half_size
	var max_pos := viewport_size - half_size

	var center := Vector2(
		clamp(pos.x, min_pos.x, max_pos.x),
		clamp(pos.y, min_pos.y, max_pos.y)
	)

	joystick_base.position = center - half_size
	joystick_base.visible = true

	joystick_knob.position = (base_size - joystick_knob.size) * 0.5
	joystick_knob.visible = true


func _update_joystick(pos: Vector2) -> void:
	if not joystick_base or not joystick_knob:
		return

	var base_center := joystick_base.position + joystick_base.size * 0.5
	var offset: Vector2 = (pos - base_center).limit_length(joystick_radius)
	var knob_center := joystick_base.size * 0.5 + offset

	joystick_knob.position = knob_center - joystick_knob.size * 0.5


func _hide_joystick() -> void:
	if joystick_base:
		joystick_base.visible = false

	if joystick_knob:
		joystick_knob.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		move_touch_id = -1
		look_touch_id = -1
		move_input = Vector2.ZERO
		touch_start.clear()
		_hide_joystick()



func _on_jump_pressed() -> void:
	jump_requested = true


func _on_interact_pressed() -> void:
	var ray := get_node_or_null("Camera3D/InteractionRay")

	if ray and ray.has_method("try_interact"):
		ray.try_interact()
