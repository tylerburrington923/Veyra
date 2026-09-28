extends Node
class_name VeyraProgressionManager

## Authoritative player progression for the alpha gameplay loop.
## Actions award discipline XP, level-ups grant research points, and quests consume
## the same action stream so progression cannot drift away from actual gameplay.

signal xp_changed(discipline: String, xp: int, level: int)
signal level_up(discipline: String, level: int, skill_points_awarded: int)
signal quest_changed(quest_id: String, completed: bool)
signal skill_unlocked(skill_id: String)

const SAVE_VERSION := 2
const DISCIPLINES := ["EXTRACTION", "HUNTING", "CRAFTING", "SETTLEMENT", "EXPLORATION", "SCIENCE", "ARCHAEOLOGY"]
const SKILLS := {
	"FIELDCRAFT": {"name": "Fieldcraft", "cost": 1, "description": "Improves basic gathering output."},
	"HUNTSMAN": {"name": "Huntsman", "cost": 1, "description": "Improves hunting knowledge."},
	"METALLURGY": {"name": "Metallurgy", "cost": 2, "description": "Unlocks advanced metalworking knowledge."},
	"RESONANCE_STUDY": {"name": "Resonance Study", "cost": 2, "description": "Unlocks deeper study of Veyra materials."},
	"ARCHAEOLOGY": {"name": "Archaeology", "cost": 2, "description": "Unlocks ancient-site research."}
}
const QUESTS := {
	"FIRST_STEPS": {
		"title": "First Steps",
		"description": "Learn to survive with what Veyra gives you.",
		"objectives": {"GATHER:Wood": 3, "GATHER:Stone": 3, "CRAFT:I01_STONE_AXE": 1}
	},
	"HUNT_AND_HIDE": {
		"title": "Hunt and Preserve",
		"description": "Make the first hunt useful beyond food.",
		"objectives": {"HUNT:Meat": 3, "HUNT:Hide": 2}
	},
	"FORGE_AHEAD": {
		"title": "Forge Ahead",
		"description": "Turn raw metal into durable tools.",
		"objectives": {"GATHER:Metal": 2, "CRAFT:I04_METAL_AXE": 1}
	},
	"RESONANT_TOOLS": {
		"title": "Resonant Tools",
		"description": "Begin working with materials that do not behave like ordinary matter.",
		"objectives": {"GATHER:Echo-Stone": 1, "GATHER:Vitreous Lux": 1, "CRAFT:I06_ECHO_AXE": 1}
	},
	"EXPLORATION": {
		"title": "First Horizons",
		"description": "Find the places Veyra is trying to show you.",
		"objectives": {"EXPLORE:ANCIENT_LANDMARK": 1}
	},
	"RESONANCE_STUDY": {
		"title": "Listen to the Stone",
		"description": "Learn that Echo-Stone remembers more than its shape.",
		"objectives": {"RESONANCE:ECHO_STONE_RELEASE": 1}
	},
	"ANCIENT_TRACE": {
		"title": "Ancient Trace",
		"description": "Examine an old site closely enough to record what remains.",
		"objectives": {"ARCHAEOLOGY:ANCIENT_LANDMARK": 1}
	},
	"SETTLEMENT": {
		"title": "Make It Permanent",
		"description": "Turn a temporary camp into a functioning settlement.",
		"objectives": {"BUILD:B01_CAMPFIRE": 1, "BUILD:B02_STORAGE": 1}
	}
}

var xp: Dictionary = {}
var levels: Dictionary = {}
var skill_points: int = 0
var unlocked_skills: Array[String] = []
var quest_progress: Dictionary = {}
var discovered_events: Dictionary = {}

func _ready() -> void:
	for discipline in DISCIPLINES:
		xp[discipline] = 0
		levels[discipline] = 1
	for quest_id in QUESTS:
		quest_progress[quest_id] = {}
	add_to_group("progression_manager")

func record_unique_action(action: String, subject: String, unique_id: String) -> bool:
	var clean_id := unique_id.strip_edges()
	if clean_id.is_empty():
		return false
	var key := action.to_upper() + ":" + clean_id
	if bool(discovered_events.get(key, false)):
		return false
	discovered_events[key] = true
	record_action(action, 1, subject)
	return true

func has_discovered(unique_id: String, action: String = "") -> bool:
	var key := action.to_upper() + ":" + unique_id if not action.is_empty() else unique_id
	return bool(discovered_events.get(key, false))

func record_action(action: String, amount: int = 1, subject: String = "") -> void:
	if amount <= 0:
		return
	var key := action.to_upper()
	var category := _category_for_action(key)
	var awarded_xp := _xp_for_action(key, amount)
	if category.is_empty() or awarded_xp <= 0:
		return
	_add_xp(category, awarded_xp)
	var objective_key := key
	if not subject.is_empty():
		objective_key += ":" + subject
	_update_quests(objective_key, amount)

func _category_for_action(action: String) -> String:
	match action:
		"GATHER":
			return "EXTRACTION"
		"HUNT":
			return "HUNTING"
		"CRAFT":
			return "CRAFTING"
		"BUILD":
			return "SETTLEMENT"
		"EXPLORE":
			return "EXPLORATION"
		"RESONANCE":
			return "SCIENCE"
		"ARCHAEOLOGY":
			return "ARCHAEOLOGY"
		_:
			return ""

func _xp_for_action(action: String, amount: int) -> int:
	var base := 0
	match action:
		"GATHER":
			base = 5
		"HUNT":
			base = 12
		"CRAFT":
			base = 10
		"BUILD":
			base = 20
		"EXPLORE":
			base = 8
		"RESONANCE":
			base = 18
		"ARCHAEOLOGY":
			base = 25
		_:
			return 0
	return base * amount

func _add_xp(discipline: String, amount: int) -> void:
	var current_level := get_level(discipline)
	var current_xp := maxi(0, int(xp.get(discipline, 0))) + amount
	var points_awarded := 0
	while current_xp >= xp_to_next_level(current_level):
		current_xp -= xp_to_next_level(current_level)
		current_level += 1
		points_awarded += 1
	xp[discipline] = current_xp
	levels[discipline] = current_level
	xp_changed.emit(discipline, current_xp, current_level)
	if points_awarded > 0:
		skill_points += points_awarded
		level_up.emit(discipline, current_level, points_awarded)

func xp_to_next_level(level: int) -> int:
	return 100 + maxi(0, level - 1) * 75

func get_level(discipline: String) -> int:
	return maxi(1, int(levels.get(discipline, 1)))

func get_xp(discipline: String) -> int:
	return maxi(0, int(xp.get(discipline, 0)))

func can_unlock_skill(skill_id: String) -> bool:
	if not SKILLS.has(skill_id) or skill_id in unlocked_skills:
		return false
	return skill_points >= int(SKILLS[skill_id].get("cost", 1))

func unlock_skill(skill_id: String) -> bool:
	if not can_unlock_skill(skill_id):
		return false
	skill_points -= int(SKILLS[skill_id].get("cost", 1))
	unlocked_skills.append(skill_id)
	skill_unlocked.emit(skill_id)
	return true

func has_skill(skill_id: String) -> bool:
	return skill_id in unlocked_skills

func get_quest_state(quest_id: String) -> Dictionary:
	var definition: Dictionary = QUESTS.get(quest_id, {})
	if definition.is_empty():
		return {}
	var progress: Dictionary = quest_progress.get(quest_id, {})
	var objectives: Dictionary = definition.get("objectives", {})
	var completed := true
	var result := {"quest_id": quest_id, "title": definition.get("title", quest_id), "description": definition.get("description", ""), "objectives": {}}
	for objective_key in objectives:
		var required := int(objectives[objective_key])
		var current := mini(required, int(progress.get(objective_key, 0)))
		if current < required:
			completed = false
		result["objectives"][objective_key] = {"current": current, "required": required}
	result["completed"] = completed
	return result

func _update_quests(objective_key: String, amount: int) -> void:
	for quest_id in QUESTS:
		var definition: Dictionary = QUESTS[quest_id]
		var objectives: Dictionary = definition.get("objectives", {})
		if not objectives.has(objective_key):
			continue
		var progress: Dictionary = quest_progress.get(quest_id, {})
		progress[objective_key] = int(progress.get(objective_key, 0)) + amount
		quest_progress[quest_id] = progress
		var state := get_quest_state(quest_id)
		if bool(state.get("completed", false)) and not bool(progress.get("_rewarded", false)):
			progress["_rewarded"] = true
			skill_points += 1
			quest_changed.emit(quest_id, true)
		else:
			quest_changed.emit(quest_id, false)

func get_save_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"xp": xp.duplicate(true),
		"levels": levels.duplicate(true),
		"skill_points": skill_points,
		"unlocked_skills": unlocked_skills.duplicate(),
		"quest_progress": quest_progress.duplicate(true),
		"discovered_events": discovered_events.duplicate(true)
	}

func load_save_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	for discipline in DISCIPLINES:
		xp[discipline] = maxi(0, int(state.get("xp", {}).get(discipline, 0)))
		levels[discipline] = maxi(1, int(state.get("levels", {}).get(discipline, 1)))
	skill_points = maxi(0, int(state.get("skill_points", 0)))
	unlocked_skills.clear()
	for skill_id in state.get("unlocked_skills", []):
		if SKILLS.has(str(skill_id)):
			unlocked_skills.append(str(skill_id))
	discovered_events = {}
	var saved_discoveries = state.get("discovered_events", {})
	if saved_discoveries is Dictionary:
		for key in saved_discoveries:
			if bool(saved_discoveries[key]):
				discovered_events[str(key)] = true
	quest_progress = {}
	for quest_id in QUESTS:
		var saved = state.get("quest_progress", {}).get(quest_id, {})
		quest_progress[quest_id] = saved.duplicate(true) if saved is Dictionary else {}
