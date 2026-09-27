extends Node
class_name VeyraNetworkManager

## Multiplayer alpha coordinator.
## ENet host/client session, server-authoritative player movement, and LAN lobby UI.
## Host-authoritative gameplay: player movement, NPC simulation, and validated interactions.
## Clients receive state snapshots and never simulate authoritative NPC behavior.

const PORT: int = 24567
const MAX_PLAYERS: int = 4
const SNAPSHOT_INTERVAL: float = 0.08

var session_active: bool = false
var is_host: bool = false
var local_peer_id: int = 1
var peer_inputs: Dictionary = {}
var players: Dictionary = {}
var _server_interaction_locks: Dictionary = {}
var _snapshot_accumulator: float = 0.0
var _state_sync_accumulator: float = 0.0

var lobby_layer: CanvasLayer
var status_label: Label
var ip_field: LineEdit
var host_button: Button
var join_button: Button
var leave_button: Button

func _ready() -> void:
	add_to_group("network_manager")
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	call_deferred("_build_lobby_ui")

func _process(delta: float) -> void:
	if not session_active or not is_host:
		return
	_snapshot_accumulator += delta
	_state_sync_accumulator += delta
	if _snapshot_accumulator >= SNAPSHOT_INTERVAL:
		_snapshot_accumulator = 0.0
		_broadcast_snapshot()
	if _state_sync_accumulator >= 0.5:
		_state_sync_accumulator = 0.0
		_broadcast_game_state()

func host_game() -> bool:
	if session_active:
		return false
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(PORT, MAX_PLAYERS - 1)
	if result != OK:
		_set_status("HOST FAILED: %s" % error_string(result))
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	session_active = true
	local_peer_id = 1
	_configure_existing_player(1, true)
	_set_status("HOSTING • PORT %d\n%s" % [PORT, _get_lan_addresses()])
	return true

func join_game(address: String) -> bool:
	if session_active:
		return false
	var clean_address := address.strip_edges()
	if clean_address.is_empty():
		clean_address = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(clean_address, PORT)
	if result != OK:
		_set_status("JOIN FAILED: %s" % error_string(result))
		return false
	multiplayer.multiplayer_peer = peer
	is_host = false
	session_active = true
	local_peer_id = multiplayer.get_unique_id()
	_set_status("CONNECTING TO %s:%d..." % [clean_address, PORT])
	return true

func leave_game() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	session_active = false
	is_host = false
	peer_inputs.clear()
	_despawn_all_network_players()
	_set_status("OFFLINE • single-player mode")

func submit_local_input(input_vector: Vector2, yaw: float, pitch: float, jump: bool) -> void:
	if not session_active or is_host:
		return
	send_input.rpc_id(1, input_vector.limit_length(1.0), yaw, pitch, jump)

func submit_local_interaction(target: Node) -> void:
	if not session_active or is_host or not target:
		return
	request_interaction.rpc_id(1, target.get_path())

func submit_local_build(building_id: String, position: Vector3) -> void:
	if not session_active or is_host:
		return
	request_build.rpc_id(1, building_id, position)

func submit_local_craft(recipe_id: String) -> void:
	if not session_active or is_host:
		return
	request_craft.rpc_id(1, recipe_id)

@rpc("any_peer", "unreliable")
func send_input(input_vector: Vector2, yaw: float, pitch: float, jump: bool) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 1 or not players.has(peer_id):
		return
	peer_inputs[peer_id] = {
		"input": input_vector.limit_length(1.0),
		"yaw": yaw,
		"jump": jump
	}

@rpc("authority", "call_local", "reliable")
func network_spawn_player(peer_id: int) -> void:
	if not session_active:
		return
	if players.has(peer_id):
		return
	var world := get_tree().current_scene
	if not world:
		return
	var existing := world.get_node_or_null("Player") as CharacterBody3D
	if peer_id == local_peer_id and existing:
		existing.configure_network_role(peer_id, true)
		players[peer_id] = existing
		return
	var scene := load("res://scenes/player.tscn") as PackedScene
	if not scene:
		return
	var player := scene.instantiate() as CharacterBody3D
	if not player:
		return
	player.set_meta("network_mode", true)
	player.set_meta("network_local", peer_id == local_peer_id)
	player.set_meta("network_peer_id", peer_id)
	player.name = "NetworkPlayer_%d" % peer_id
	var container := world.get_node_or_null("NetworkPlayers") as Node3D
	if not container:
		container = Node3D.new()
		container.name = "NetworkPlayers"
		world.add_child(container)
	container.add_child(player)
	player.configure_network_role(peer_id, peer_id == local_peer_id)
	players[peer_id] = player

@rpc("authority", "call_local", "reliable")
func network_despawn_player(peer_id: int) -> void:
	var player: Node = players.get(peer_id)
	if player:
		player.queue_free()
	players.erase(peer_id)
	peer_inputs.erase(peer_id)

@rpc("authority", "unreliable")
func receive_snapshot(snapshot: Array) -> void:
	if is_host:
		return
	for state_value in snapshot:
		if not state_value is Dictionary:
			continue
		var peer_id := int(state_value.get("peer_id", 0))
		var player := players.get(peer_id) as CharacterBody3D
		if not player:
			continue
		var position_data = state_value.get("position", {})
		if not position_data is Dictionary:
			continue
		var position := Vector3(
			float(position_data.get("x", 0.0)),
			float(position_data.get("y", 0.0)),
			float(position_data.get("z", 0.0))
		)
		player.apply_network_state(position, float(state_value.get("yaw", 0.0)))

func _physics_process(_delta: float) -> void:
	if not session_active or not is_host:
		return
	for peer_id in players.keys():
		var id := int(peer_id)
		var player := players[id] as CharacterBody3D
		if not player or id == 1:
			continue
		var input_data: Dictionary = peer_inputs.get(id, {})
		var input_value: Vector2 = input_data.get("input", Vector2.ZERO)
		var jump_value: bool = bool(input_data.get("jump", false))
		var yaw_value: float = float(input_data.get("yaw", player.rotation.y))
		player.set_network_input(input_value, jump_value, yaw_value)

func _broadcast_snapshot() -> void:
	if not multiplayer.is_server():
		return
	var snapshot: Array = []
	for peer_id in players.keys():
		var player := players[peer_id] as CharacterBody3D
		if not player or not is_instance_valid(player):
			continue
		var state: Dictionary = player.get_network_state()
		snapshot.append({
			"peer_id": int(peer_id),
			"position": {
				"x": state.position.x,
				"y": state.position.y,
				"z": state.position.z
			},
			"yaw": float(state.yaw)
		})
	receive_snapshot.rpc(snapshot)
	var npc_manager := get_tree().current_scene.get_node_or_null("NPCManager")
	if npc_manager and npc_manager.has_method("get_network_snapshot"):
		receive_npc_snapshot.rpc(npc_manager.get_network_snapshot())
	var animal_manager := get_tree().current_scene.get_node_or_null("AnimalManager")
	if animal_manager and animal_manager.has_method("get_network_snapshot"):
		receive_animal_snapshot.rpc(animal_manager.get_network_snapshot())

@rpc("authority", "unreliable")
func receive_npc_snapshot(snapshot: Array) -> void:
	if is_host:
		return
	var npc_manager := get_tree().current_scene.get_node_or_null("NPCManager")
	if npc_manager and npc_manager.has_method("apply_network_snapshot"):
		npc_manager.apply_network_snapshot(snapshot)

@rpc("authority", "unreliable")
func receive_animal_snapshot(snapshot: Array) -> void:
	if is_host:
		return
	var animal_manager := get_tree().current_scene.get_node_or_null("AnimalManager")
	if animal_manager and animal_manager.has_method("apply_network_snapshot"):
		animal_manager.apply_network_snapshot(snapshot)

func _on_peer_connected(peer_id: int) -> void:
	if not is_host:
		return
	# Existing players are announced to the new peer, then the new peer is announced to all.
	for existing_id in players.keys():
		rpc_id(peer_id, "network_spawn_player", int(existing_id))
	network_spawn_player.rpc(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host:
		return
	peer_inputs.erase(peer_id)
	_server_interaction_locks.erase(peer_id)
	network_despawn_player.rpc(peer_id)

@rpc("any_peer", "reliable")
func request_interaction(resource_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var player := players.get(peer_id) as Node
	if not player or not is_instance_valid(player):
		return
	var target := get_tree().current_scene.get_node_or_null(resource_path) as Node
	if not target or not target.is_inside_tree():
		return
	if not (target.is_in_group("resource_node") or target.is_in_group("interactable")):
		return
	var target_3d := target as Node3D
	if not target_3d:
		return
	if player.global_position.distance_to(target_3d.global_position) > 5.5:
		return
	if _server_interaction_locks.get(peer_id, false):
		return
	_server_interaction_locks[peer_id] = true
	if target.has_method("can_interact") and not target.can_interact(player):
		_server_interaction_locks.erase(peer_id)
		return
	if target.has_method("interact"):
		target.interact(player)
		broadcast_interaction_feedback.rpc(peer_id, str(target.name))
	_server_interaction_locks.erase(peer_id)

@rpc("any_peer", "reliable")
func request_build(building_id: String, position: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var player := players.get(peer_id) as Node3D
	var manager := get_node_or_null("/root/BuildingManager")
	var inventory: VeyraInventory = player.get_inventory() if player and player.has_method("get_inventory") else null
	if not player or not manager or not inventory:
		return
	if manager.select_building(building_id) and manager.evaluate_placement(player, position, inventory):
		manager.confirm_build(player, inventory)
	manager.cancel_placement()

@rpc("any_peer", "reliable")
func request_craft(recipe_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var player := players.get(peer_id) as Node
	var manager := get_node_or_null("/root/CraftingManager")
	var inventory: VeyraInventory = player.get_inventory() if player and player.has_method("get_inventory") else null
	if manager and inventory:
		manager.craft(recipe_id, inventory)

@rpc("authority", "reliable")
func broadcast_interaction_feedback(peer_id: int, target_name: String) -> void:
	if status_label and peer_id == local_peer_id:
		_set_status("USED %s" % target_name)

func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	_set_status("CONNECTED • waiting for host snapshot")

func _on_connection_failed() -> void:
	leave_game()
	_set_status("CONNECTION FAILED • check host IP and LAN")

func _on_server_disconnected() -> void:
	leave_game()
	_set_status("HOST DISCONNECTED")

func _configure_existing_player(peer_id: int, local_control: bool) -> void:
	var world := get_tree().current_scene
	if not world:
		return
	var player := world.get_node_or_null("Player") as CharacterBody3D
	if not player:
		return
	player.configure_network_role(peer_id, local_control)
	players[peer_id] = player

func _despawn_all_network_players() -> void:
	var local_player: CharacterBody3D = players.get(local_peer_id) as CharacterBody3D
	for peer_id in players.keys():
		var player: Node = players[peer_id]
		if player and player.name != "Player":
			player.queue_free()
	players.clear()
	peer_inputs.clear()
	if local_player and local_player.has_method("configure_offline_role"):
		local_player.configure_offline_role()

func _build_lobby_ui() -> void:
	if lobby_layer:
		return
	lobby_layer = CanvasLayer.new()
	lobby_layer.layer = 40
	lobby_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(lobby_layer)
	lobby_layer.visible = false

	var panel := Panel.new()
	panel.name = "MultiplayerPanel"
	panel.position = Vector2(24, 24)
	panel.size = Vector2(360, 190)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	lobby_layer.add_child(panel)

	var title := Label.new()
	title.text = "VEYRA MULTIPLAYER"
	title.position = Vector2(16, 10)
	title.size = Vector2(320, 28)
	title.add_theme_font_size_override("font_size", 20)
	panel.add_child(title)

	status_label = Label.new()
	status_label.text = "OFFLINE • single-player mode"
	status_label.position = Vector2(16, 42)
	status_label.size = Vector2(328, 44)
	panel.add_child(status_label)

	ip_field = LineEdit.new()
	ip_field.placeholder_text = "Host IP address"
	ip_field.text = "127.0.0.1"
	ip_field.position = Vector2(16, 88)
	ip_field.size = Vector2(210, 42)
	ip_field.add_to_group("camera_blocking_ui")
	panel.add_child(ip_field)

	host_button = Button.new()
	host_button.text = "HOST"
	host_button.position = Vector2(236, 88)
	host_button.size = Vector2(100, 42)
	host_button.add_to_group("camera_blocking_ui")
	host_button.pressed.connect(host_game)
	panel.add_child(host_button)

	join_button = Button.new()
	join_button.text = "JOIN"
	join_button.position = Vector2(16, 138)
	join_button.size = Vector2(150, 38)
	join_button.add_to_group("camera_blocking_ui")
	join_button.pressed.connect(func() -> void: join_game(ip_field.text))
	panel.add_child(join_button)

	leave_button = Button.new()
	leave_button.text = "LEAVE"
	leave_button.position = Vector2(182, 138)
	leave_button.size = Vector2(154, 38)
	leave_button.add_to_group("camera_blocking_ui")
	leave_button.pressed.connect(leave_game)
	panel.add_child(leave_button)

func _set_status(message: String) -> void:
	if status_label:
		status_label.text = message

func _get_lan_addresses() -> String:
	var addresses: Array[String] = []
	for address_value in IP.get_local_addresses():
		var address := str(address_value).strip_edges()
		if _is_private_ipv4(address):
			addresses.append(address)
	addresses.sort()
	if addresses.is_empty():
		return "HOTSPOT/LAN IP: unavailable"
	return "HOTSPOT/LAN IP: " + ", ".join(addresses) + ":%d" % PORT

func _is_private_ipv4(address: String) -> bool:
	var octets := address.split(".")
	if octets.size() != 4:
		return false
	var values: Array[int] = []
	for octet in octets:
		if not octet.is_valid_int():
			return false
		var value := int(octet)
		if value < 0 or value > 255:
			return false
		values.append(value)
	return values[0] == 10 or values[0] == 192 and values[1] == 168 or values[0] == 172 and values[1] >= 16 and values[1] <= 31


func _broadcast_game_state() -> void:
	if not multiplayer.is_server():
		return
	var inventories: Dictionary = {}
	for peer_id in players.keys():
		var player := players[peer_id] as Node
		if player and player.has_method("get_inventory"):
			inventories[int(peer_id)] = player.get_inventory().get_snapshot()
	var world := get_tree().current_scene
	var generator := world.get_node_or_null("WorldGenerator") if world else null
	var resources: Dictionary = generator.get_resource_state() if generator and generator.has_method("get_resource_state") else {}
	var settlement := get_node_or_null("/root/SettlementManager")
	var settlement_state: Dictionary = settlement.get_settlement_state() if settlement and settlement.has_method("get_settlement_state") else {}
	receive_game_state.rpc(inventories, resources, settlement_state)

@rpc("authority", "reliable")
func receive_game_state(inventories: Dictionary, resources: Dictionary, settlement_state: Dictionary) -> void:
	if is_host:
		return
	var local_player := get_tree().current_scene.get_node_or_null("Player")
	if local_player and local_player.has_method("get_inventory"):
		var snapshot = inventories.get(local_peer_id, {})
		if snapshot is Dictionary:
			local_player.get_inventory().load_snapshot(snapshot)
	var world := get_tree().current_scene
	var generator := world.get_node_or_null("WorldGenerator") if world else null
	if generator and generator.has_method("apply_resource_state"):
		generator.apply_resource_state(resources)
	var settlement := get_node_or_null("/root/SettlementManager")
	if settlement and settlement.has_method("load_settlement_state"):
		settlement.load_settlement_state(settlement_state)
	var building_manager := get_node_or_null("/root/BuildingManager")
	if building_manager and building_manager.has_method("restore_from_settlement"):
		building_manager.restore_from_settlement()
