class_name SpaceComponent
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var category: String = "Structure" # "Structure", "Power", "Instruments", "Communications", "Propulsion", "Landing", "Data"

@export var mass: float = 0.0                # kg
@export var power_consumption: float = 0.0   # Watts
@export var power_generation: float = 0.0    # Watts
@export var cost: float = 0.0                # $ Millions

@export var reliability: float = 0.95        # 0.0 to 1.0
@export var science_value: float = 0.0       # Science points
@export var data_generation: float = 0.0     # MB/day
@export var comms_bandwidth: float = 0.0     # Mbps capacity
@export var delta_v_impulse: float = 0.0     # m/s theoretical impulse

@export var description: String = ""
@export var visual_type: String = "bus"      # Visual mesh identifier
@export var tech_notes: String = ""
@export var nasa_heritage: String = ""

static func from_dict(dict: Dictionary) -> SpaceComponent:
	var comp = SpaceComponent.new()
	comp.id = dict.get("id", "")
	comp.display_name = dict.get("display_name", "")
	comp.category = dict.get("category", "Structure")
	comp.mass = float(dict.get("mass", 0.0))
	comp.power_consumption = float(dict.get("power_consumption", 0.0))
	comp.power_generation = float(dict.get("power_generation", 0.0))
	comp.cost = float(dict.get("cost", 0.0))
	comp.reliability = float(dict.get("reliability", 0.95))
	comp.science_value = float(dict.get("science_value", 0.0))
	comp.data_generation = float(dict.get("data_generation", 0.0))
	comp.comms_bandwidth = float(dict.get("comms_bandwidth", 0.0))
	comp.delta_v_impulse = float(dict.get("delta_v_impulse", 0.0))
	comp.description = dict.get("description", "")
	comp.visual_type = dict.get("visual_type", "bus")
	comp.tech_notes = dict.get("tech_notes", "")
	comp.nasa_heritage = dict.get("nasa_heritage", "")
	return comp
