extends CanvasLayer

const RESOURCE_TYPES: Array[String] = ["Stone", "Wood", "Metal", "Vitreous Lux"]

@onready var inventory: Node = get_parent().get_node_or_null("Inventory")
@onready var hotbar_label: Label = get_node_or_null("Hotbar/Label") as Label
@onready var inventory_panel: Panel = get_node_or_null("InventoryPanel") as Panel
@onready var inventory_label: Label = get_node_or_null("InventoryPanel/Label") as Label
@onready var toast: Label = get_node_or_null("PickupToast") as Label

var toast_time: float = 0.0
var last_snapshot: Dictionary = {}

func _ready() -> void:
    if inventory and inventory.has_signal("inventory_changed"):
        inventory.inventory_changed.connect(_on_inventory_changed)
    if inventory and inventory.has_method("get_snapshot"):
        last_snapshot = inventory.get_snapshot()
    _refresh()
    if inventory_panel:
        inventory_panel.visible = false

func _process(delta: float) -> void:
    if toast_time <= 0.0:
        if toast:
            toast.visible = false
        return
    toast_time -= delta
    if toast_time <= 0.0 and toast:
        toast.visible = false

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
        _toggle_inventory()

func _on_inventory_changed(snapshot: Dictionary, changed_type: String, changed_amount: int) -> void:
    _refresh()
    if changed_amount > 0:
        _show_toast("Picked up %s x%d" % [changed_type, changed_amount])

func _refresh() -> void:
    if not inventory or not inventory.has_method("get_snapshot"):
        return
    var snapshot: Dictionary = inventory.get_snapshot()
    if hotbar_label:
        hotbar_label.text = _format_hotbar(snapshot)
    if inventory_label:
        inventory_label.text = _format_inventory(snapshot)

func _format_hotbar(snapshot: Dictionary) -> String:
    var parts: Array[String] = []
    for resource_type in RESOURCE_TYPES:
        parts.append("%s  %d" % [_short_name(resource_type), int(snapshot.get(resource_type, 0))])
    return "  |  ".join(parts)

func _format_inventory(snapshot: Dictionary) -> String:
    var lines: Array[String] = ["INVENTORY"]
    for resource_type in RESOURCE_TYPES:
        lines.append("%-14s %d" % [resource_type, int(snapshot.get(resource_type, 0))])
    var total: int = 0
    for value in snapshot.values():
        total += int(value)
    var capacity := inventory.get_capacity_state() if inventory.has_method("get_capacity_state") else {}
    lines.append("")
    lines.append("TOTAL ITEMS: %d" % total)
    if not capacity.is_empty():
        lines.append("WEIGHT: %.1f / %.1f" % [float(capacity.get("weight", 0.0)), float(capacity.get("weight_max", 0.0))])
        lines.append("SLOTS: %d / %d" % [int(capacity.get("slots_used", 0)), int(capacity.get("slots_max", 0))])
    lines.append("Press I to close")
    return "\n".join(lines)

func _short_name(resource_type: String) -> String:
    match resource_type:
        "Vitreous Lux":
            return "LUX"
        _:
            return resource_type.to_upper()

func _show_toast(message: String) -> void:
    if not toast:
        return
    toast.text = message
    toast.visible = true
    toast_time = 2.0

func _toggle_inventory() -> void:
    if inventory_panel:
        inventory_panel.visible = not inventory_panel.visible
