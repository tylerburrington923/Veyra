class_name AnimalDefinition
extends RefCounted

var id: String = ""
var display_name: String = ""
var species: String = "generic"
var movement_speed: float = 3.0
var max_health: float = 50.0
var hunger_rate: float = 0.05
var thirst_rate: float = 0.08
var behavior_archetype: String = "HERBIVORE"
var maturity_age_seconds: float = 120.0
var reproduction_cooldown_seconds: float = 180.0
var max_age_seconds: float = 3600.0

func _init(p_id: String = "", p_display_name: String = "", p_species: String = "generic", p_movement_speed: float = 3.0, p_max_health: float = 50.0, p_hunger_rate: float = 0.05, p_thirst_rate: float = 0.08, p_behavior_archetype: String = "HERBIVORE") -> void:
	id = p_id
	display_name = p_display_name
	species = p_species
	movement_speed = p_movement_speed
	max_health = p_max_health
	hunger_rate = p_hunger_rate
	thirst_rate = p_thirst_rate
	behavior_archetype = p_behavior_archetype

func is_valid() -> bool:
	return not id.strip_edges().is_empty() and not display_name.strip_edges().is_empty() and movement_speed >= 0.0 and max_health > 0.0 and hunger_rate >= 0.0 and thirst_rate >= 0.0 and maturity_age_seconds >= 0.0 and reproduction_cooldown_seconds >= 0.0 and max_age_seconds > 0.0

func to_dict() -> Dictionary:
	return {"id": id, "display_name": display_name, "species": species, "movement_speed": movement_speed, "max_health": max_health, "hunger_rate": hunger_rate, "thirst_rate": thirst_rate, "behavior_archetype": behavior_archetype, "maturity_age_seconds": maturity_age_seconds, "reproduction_cooldown_seconds": reproduction_cooldown_seconds, "max_age_seconds": max_age_seconds}

static func from_dict(data: Dictionary) -> AnimalDefinition:
	var definition := AnimalDefinition.new()
	definition.id = str(data.get("id", ""))
	definition.display_name = str(data.get("display_name", ""))
	definition.species = str(data.get("species", "generic"))
	definition.movement_speed = float(data.get("movement_speed", 3.0))
	definition.max_health = float(data.get("max_health", 50.0))
	definition.hunger_rate = float(data.get("hunger_rate", 0.05))
	definition.thirst_rate = float(data.get("thirst_rate", 0.08))
	definition.behavior_archetype = str(data.get("behavior_archetype", "HERBIVORE"))
	definition.maturity_age_seconds = maxf(0.0, float(data.get("maturity_age_seconds", 120.0)))
	definition.reproduction_cooldown_seconds = maxf(0.0, float(data.get("reproduction_cooldown_seconds", 180.0)))
	definition.max_age_seconds = maxf(1.0, float(data.get("max_age_seconds", 3600.0)))
	return definition
