extends Node

# MissionManager Autoload Singleton
# Manages loading, caching, and querying of missions and spacecraft components.

signal missions_loaded
signal components_loaded

var missions: Dictionary = {} # mission_id -> MissionConfig
var components: Dictionary = {} # component_id -> SpaceComponent
var categories: Array[String] = [
	"Structure",
	"Power",
	"Instruments",
	"Communications",
	"Propulsion",
	"Landing",
	"Data"
]

func _ready() -> void:
	load_all_components()
	load_all_missions()

func load_all_components() -> void:
	components.clear()
	var path = "res://data/components/components.json"
	if not FileAccess.file_exists(path):
		push_warning("Components JSON not found at: " + path)
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.new()
	var err = json.parse(content)
	if err == OK and json.data is Array:
		for item in json.data:
			if item is Dictionary:
				var comp = SpaceComponent.from_dict(item)
				components[comp.id] = comp
		print("[MissionManager] Loaded %d components successfully." % components.size())
		emit_signal("components_loaded")
	else:
		push_error("[MissionManager] Failed to parse components.json: " + str(err))

func load_all_missions() -> void:
	missions.clear()
	var mission_files = [
		"res://data/missions/earth_observation.json",
		"res://data/missions/lunar_exploration.json",
		"res://data/missions/mars_rover.json"
	]
	
	for path in mission_files:
		if FileAccess.file_exists(path):
			var file = FileAccess.open(path, FileAccess.READ)
			var content = file.get_as_text()
			var json = JSON.new()
			if json.parse(content) == OK and json.data is Dictionary:
				var m_cfg = MissionConfig.from_dict(json.data)
				missions[m_cfg.mission_id] = m_cfg
				print("[MissionManager] Loaded mission: %s (%s)" % [m_cfg.mission_name, m_cfg.mission_id])
			else:
				push_error("[MissionManager] Error parsing mission JSON at: " + path)
		else:
			push_warning("[MissionManager] Mission file missing: " + path)
			
	emit_signal("missions_loaded")

func get_mission(mission_id: String) -> MissionConfig:
	return missions.get(mission_id, null)

func get_all_missions() -> Array[MissionConfig]:
	var list: Array[MissionConfig] = []
	for m_id in ["earth_observation", "lunar_exploration", "mars_rover"]:
		if missions.has(m_id):
			list.append(missions[m_id])
	return list

func get_component(comp_id: String) -> SpaceComponent:
	return components.get(comp_id, null)

func get_components_by_category(cat: String) -> Array[SpaceComponent]:
	var list: Array[SpaceComponent] = []
	for comp in components.values():
		if comp.category == cat:
			list.append(comp)
	return list

func get_all_components() -> Array[SpaceComponent]:
	var list: Array[SpaceComponent] = []
	for comp in components.values():
		list.append(comp)
	return list
