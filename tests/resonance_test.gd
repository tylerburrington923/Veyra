extends SceneTree

class DummyPlayer:
	extends Node
	var inventory: VeyraInventory
	var tool_id := "I02_STONE_PICK"
	var durability := 100.0
	var resonance := 0.0

	func _init() -> void:
		inventory = VeyraInventory.new()
		add_child(inventory)

	func get_tool_id() -> String:
		return tool_id

	func get_inventory() -> VeyraInventory:
		return inventory

	func can_use_tool(_cost: float = 1.0) -> bool:
		return durability > 0.0

	func use_tool(cost: float = 1.0) -> bool:
		durability = maxf(0.0, durability - cost)
		return true

	func add_resonance(amount: float) -> void:
		resonance += amount

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	if not VeyraResourceCatalog.is_valid("Echo-Stone"):
		failures.append("Echo-Stone missing from resource catalog")
	if not VeyraResourceCatalog.is_valid("Vitreous Lux"):
		failures.append("Vitreous Lux missing from resource catalog")
	if VeyraResourceCatalog.max_stack("Echo-Stone") != 25:
		failures.append("Echo-Stone stack contract changed")
	if VeyraResourceCatalog.weight("Vitreous Lux") != 0.75:
		failures.append("Vitreous Lux weight contract changed")

	var progression_player = load("res://scripts/player.gd").new()
	root.add_child(progression_player)
	progression_player.add_resonance(10.0)
	if progression_player.get_resonance_tier_name() != "SENSITIZED":
		failures.append("10 resonance should reach SENSITIZED tier")
	progression_player.add_resonance(15.0)
	if progression_player.get_resonance_tier_name() != "AWAKENED":
		failures.append("25 resonance should reach AWAKENED tier")
	progression_player.add_resonance(25.0)
	if progression_player.get_resonance_tier_name() != "ATTUNED":
		failures.append("50 resonance should reach ATTUNED tier")
	progression_player.add_resonance(50.0)
	if progression_player.get_resonance_tier_name() != "CONVERGENCE":
		failures.append("100 resonance should reach CONVERGENCE tier")

	var player := DummyPlayer.new()
	root.add_child(player)
	player.inventory.add_resource("Vitreous Lux", 1)

	var stone := VeyraEchoStone.new()
	stone.release_threshold = 6.0
	root.add_child(stone)

	if not stone.can_interact(player):
		failures.append("Echo-Stone should accept Stone Pick")
	stone.interact(player)
	if player.inventory.get_amount("Echo-Stone") != 2:
		failures.append("Lux attunement should yield 2 Echo-Stone")
	if player.inventory.get_amount("Vitreous Lux") != 0:
		failures.append("Lux catalyst was not consumed")

	await process_frame
	stone.interaction_cooldown = 0.0
	stone.interact(player)
	if player.inventory.get_amount("Echo-Stone") < 3:
		failures.append("Echo-Stone extraction did not continue")
	if player.resonance <= 0.0:
		failures.append("Echo-Stone did not award resonance")

	if not failures.is_empty():
		for failure in failures:
			push_error("RESONANCE TEST: " + failure)
		quit(1)
		return

	print("RESONANCE TEST PASS")
	quit(0)
