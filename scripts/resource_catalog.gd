extends RefCounted
class_name VeyraResourceCatalog

const RESOURCE_TYPES: Array[String] = ["Stone", "Wood", "Metal", "Vitreous Lux", "Echo-Stone"]

static func is_valid(resource_type: String) -> bool:
    return resource_type in RESOURCE_TYPES

static func display_name(resource_type: String) -> String:
    return resource_type

static func max_stack(resource_type: String) -> int:
    match resource_type:
        "Vitreous Lux":
            return 50
        "Echo-Stone":
            return 25
        _:
            return 99

static func weight(resource_type: String) -> float:
    match resource_type:
        "Stone":
            return 2.0
        "Wood":
            return 1.5
        "Metal":
            return 2.5
        "Vitreous Lux":
            return 0.75
        "Echo-Stone":
            return 3.0
        _:
            return 1.0

static func required_tool(resource_type: String) -> String:
    return "T00_HANDS"
