extends Node
class_name VeyraMerchantManager

signal trade_completed(direction: String, item_id: String, amount: int, coins: int)

const SAVE_VERSION := 1

const BUY_OFFERS := {
	"Food": {"price": 4, "amount": 3},
	"Meat": {"price": 3, "amount": 3},
	"Stone": {"price": 2, "amount": 5},
	"Wood": {"price": 2, "amount": 5},
	"Metal": {"price": 10, "amount": 2},
	"Leather": {"price": 12, "amount": 2},
	"Refined Metal": {"price": 18, "amount": 1},
	"I01_STONE_AXE": {"price": 24, "amount": 1},
	"I02_STONE_PICK": {"price": 28, "amount": 1},
	"I04_METAL_AXE": {"price": 70, "amount": 1},
	"I05_METAL_PICK": {"price": 78, "amount": 1},
	"I08_HUNTER_KNIFE": {"price": 32, "amount": 1},
	"I09_STONE_SPEAR": {"price": 36, "amount": 1}
}

const SELL_OFFERS := {
	"Stone": 1,
	"Wood": 1,
	"Metal": 5,
	"Meat": 2,
	"Hide": 3,
	"Leather": 7,
	"Food": 3,
	"Refined Metal": 9,
	"Vitreous Lux": 8,
	"Echo-Stone": 12,
	"I01_STONE_AXE": 12,
	"I02_STONE_PICK": 14,
	"I04_METAL_AXE": 35,
	"I05_METAL_PICK": 39,
	"I08_HUNTER_KNIFE": 16,
	"I09_STONE_SPEAR": 18,
	"A01_HIDE_CAP": 12,
	"A02_HIDE_VEST": 24,
	"A03_LEATHER_ARMOR": 55
}

func request_buy(player: Node, item_id: String) -> bool:
	if _is_authoritative():
		return buy(player, item_id)
	var network := get_node_or_null("/root/NetworkManager")
	if network and bool(network.get("session_active")):
		network.submit_local_merchant_trade("BUY", item_id, 1)
		return true
	return false

func request_sell(player: Node, item_id: String, amount: int = 1) -> bool:
	if _is_authoritative():
		return sell(player, item_id, amount)
	var network := get_node_or_null("/root/NetworkManager")
	if network and bool(network.get("session_active")):
		network.submit_local_merchant_trade("SELL", item_id, amount)
		return true
	return false

func buy(player: Node, item_id: String) -> bool:
	if not _is_authoritative() or not player or not player.has_method("get_inventory") or not BUY_OFFERS.has(item_id):
		return false
	var inventory: VeyraInventory = player.get_inventory()
	var offer: Dictionary = BUY_OFFERS[item_id]
	var price := int(offer["price"])
	var amount := int(offer["amount"])
	if inventory.get_coins() < price:
		return false
	var accepted := _add_item_or_resource(inventory, item_id, amount)
	if accepted < amount:
		return false
	if not inventory.spend_coins(price):
		_remove_item_or_resource(inventory, item_id, amount)
		return false
	trade_completed.emit("BUY", item_id, amount, price)
	return true

func sell(player: Node, item_id: String, amount: int = 1) -> bool:
	if not player or not player.has_method("get_inventory") or not SELL_OFFERS.has(item_id) or amount <= 0:
		return false
	var inventory: VeyraInventory = player.get_inventory()
	if not _has_item_or_resource(inventory, item_id, amount):
		return false
	var removed := _remove_item_or_resource(inventory, item_id, amount)
	if removed < amount:
		return false
	var payout := int(SELL_OFFERS[item_id]) * amount
	inventory.add_coins(payout)
	trade_completed.emit("SELL", item_id, amount, payout)
	return true

func get_buy_offers() -> Dictionary:
	return BUY_OFFERS.duplicate(true)

func get_sell_offers() -> Dictionary:
	return SELL_OFFERS.duplicate(true)

func _add_item_or_resource(inventory: VeyraInventory, id: String, amount: int) -> int:
	if VeyraResourceCatalog.is_valid(id):
		return inventory.add_resource(id, amount)
	if VeyraItemCatalog.is_valid(id):
		return inventory.add_item(id, amount)
	return 0

func _remove_item_or_resource(inventory: VeyraInventory, id: String, amount: int) -> int:
	if VeyraResourceCatalog.is_valid(id):
		return inventory.remove_resource(id, amount)
	if VeyraItemCatalog.is_valid(id):
		return inventory.remove_item(id, amount)
	return 0

func _has_item_or_resource(inventory: VeyraInventory, id: String, amount: int) -> bool:
	if VeyraResourceCatalog.is_valid(id):
		return inventory.has_resource(id, amount)
	if VeyraItemCatalog.is_valid(id):
		return inventory.has_item(id, amount)
	return false


func _is_authoritative() -> bool:
	var network := get_node_or_null("/root/NetworkManager")
	return network == null or not bool(network.get("session_active")) or bool(network.get("is_host"))
