extends Node

# GameManager Autoload Singleton
# Manages overall application state, current mission selection, active spacecraft,
# and persists local high-score records.

signal mission_selected(mission: MissionConfig)
signal spacecraft_updated(spacecraft: SpacecraftConfig)
signal simulation_completed(result: MissionResult)

enum GameState {
	MAIN_MENU,
	MISSION_SELECT,
	BRIEFING,
	DESIGNER,
	SIMULATION,
	REPORT
}

var current_state: GameState = GameState.MAIN_MENU
var current_mission: MissionConfig = null
var current_spacecraft: SpacecraftConfig = null
var current_result: MissionResult = null

# Persistent mission record history: mission_id -> { "high_score": float, "runs_completed": int, "best_rating": String }
var mission_records: Dictionary = {}
const SAVE_PATH = "user://mission_records.json"

func _ready() -> void:
	current_spacecraft = SpacecraftConfig.new()
	load_records()

func select_mission(mission: MissionConfig) -> void:
	current_mission = mission
	# Initialize default spacecraft with baseline bus
	current_spacecraft.clear()
	if current_mission != null:
		# Provide intelligent starter component recommendations based on destination
		_apply_starter_template(current_mission)
	emit_signal("mission_selected", current_mission)
	emit_signal("spacecraft_updated", current_spacecraft)

func _apply_starter_template(mission: MissionConfig) -> void:
	if MissionManager == null:
		return
	# Give user standard structural bus
	if mission.destination == "Mars":
		var rover_bus = MissionManager.get_component("chassis_mars_rover")
		if rover_bus: current_spacecraft.add_component(rover_bus)
	else:
		var sat_bus = MissionManager.get_component("bus_medium_sat")
		if sat_bus: current_spacecraft.add_component(sat_bus)
		
	# Flight computer standard
	var comp = MissionManager.get_component("data_rad_computer")
	if comp: current_spacecraft.add_component(comp)

func set_mission_result(result: MissionResult) -> void:
	current_result = result
	if result != null and not result.mission_id.is_empty():
		var m_id = result.mission_id
		var prev = mission_records.get(m_id, { "high_score": 0.0, "runs_completed": 0, "best_rating": "None" })
		var is_new_high = result.final_score > prev.get("high_score", 0.0)
		prev["runs_completed"] = prev.get("runs_completed", 0) + 1
		if is_new_high:
			prev["high_score"] = snapped(result.final_score, 0.1)
			prev["best_rating"] = _get_rating_string(result.final_score)
		mission_records[m_id] = prev
		save_records()
	emit_signal("simulation_completed", current_result)

func _get_rating_string(score: float) -> String:
	if score >= 90.0: return "Exceptional (Prime Mission Success)"
	elif score >= 75.0: return "Nominal (Full Mission Objectives Met)"
	elif score >= 60.0: return "Satisfactory (Partial Mission Objectives)"
	elif score >= 40.0: return "Degraded (Limited Return)"
	else: return "Critical Mission Loss"

func save_records() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(mission_records, "\t"))

func load_records() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var text = file.get_as_text()
		var json = JSON.new()
		if json.parse(text) == OK and json.data is Dictionary:
			mission_records = json.data
