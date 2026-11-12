class_name MissionConfig
extends Resource

@export var mission_id: String = ""
@export var mission_name: String = ""
@export var subtitle: String = ""
@export var destination: String = "Earth"      # "Earth", "Moon", "Mars"
@export var difficulty: String = "Standard"     # "Standard", "Challenging", "Complex"

@export var budget_limit: float = 300.0        # $ Millions
@export var mass_limit: float = 1200.0          # kg
@export var power_requirement: float = 250.0    # Watts
@export var communication_requirement: float = 10.0 # Mbps
@export var duration_days: float = 365.0
@export var scientific_target: float = 100.0    # Required science score points
@export var min_delta_v: float = 800.0         # Minimum m/s delta-v for trajectory maneuvers

@export var required_components: Array[String] = []  # IDs or category checks
@export var recommended_components: Array[String] = []
@export var brief_overview: String = ""
@export var objectives: Array[String] = []
@export var engineering_constraints: Array[String] = []
@export var educational_context: String = ""
@export var nasa_reference_title: String = ""
@export var nasa_reference_url: String = ""

# NASA Authoritative Data
@export var nasa_landing_sites: Array[Dictionary] = []
@export var nasa_flight_parameters: Dictionary = {}

static func from_dict(dict: Dictionary) -> MissionConfig:
	var cfg = MissionConfig.new()
	cfg.mission_id = dict.get("mission_id", "")
	cfg.mission_name = dict.get("mission_name", "")
	cfg.subtitle = dict.get("subtitle", "")
	cfg.destination = dict.get("destination", "Earth")
	cfg.difficulty = dict.get("difficulty", "Standard")
	cfg.budget_limit = float(dict.get("budget_limit", 300.0))
	cfg.mass_limit = float(dict.get("mass_limit", 1200.0))
	cfg.power_requirement = float(dict.get("power_requirement", 250.0))
	cfg.communication_requirement = float(dict.get("communication_requirement", 10.0))
	cfg.duration_days = float(dict.get("duration_days", 365.0))
	cfg.scientific_target = float(dict.get("scientific_target", 100.0))
	cfg.min_delta_v = float(dict.get("min_delta_v", 800.0))
	
	cfg.required_components.clear()
	for item in dict.get("required_components", []):
		cfg.required_components.append(str(item))
		
	cfg.recommended_components.clear()
	for item in dict.get("recommended_components", []):
		cfg.recommended_components.append(str(item))
		
	cfg.objectives.clear()
	for obj in dict.get("objectives", []):
		cfg.objectives.append(str(obj))
		
	cfg.engineering_constraints.clear()
	for c in dict.get("engineering_constraints", []):
		cfg.engineering_constraints.append(str(c))
		
	cfg.brief_overview = dict.get("brief_overview", "")
	cfg.educational_context = dict.get("educational_context", "")
	cfg.nasa_reference_title = dict.get("nasa_reference_title", "")
	cfg.nasa_reference_url = dict.get("nasa_reference_url", "")
	
	cfg.nasa_landing_sites.clear()
	for site in dict.get("nasa_landing_sites", []):
		if site is Dictionary:
			cfg.nasa_landing_sites.append(site)
			
	cfg.nasa_flight_parameters = dict.get("nasa_flight_parameters", {})
	return cfg
