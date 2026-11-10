class_name MissionResult
extends Resource

@export var mission_id: String = ""
@export var mission_name: String = ""
@export var destination: String = ""
@export var spacecraft_name: String = ""
@export var mission_completed: bool = false
@export var reached_phase: int = 0
@export var phase_name: String = ""

# Category Scores normalized 0.0 - 100.0
@export var scientific_score: float = 0.0
@export var reliability_score: float = 0.0
@export var efficiency_score: float = 0.0
@export var budget_score: float = 0.0
@export var completion_score: float = 0.0
@export var final_score: float = 0.0

# Engineering telemetry summary
@export var total_mass: float = 0.0
@export var total_cost: float = 0.0
@export var power_margin: float = 0.0
@export var data_transmitted: float = 0.0
@export var data_target: float = 0.0

# Logs and explanations
@export var events: Array[Dictionary] = [] # { "time_day": float, "title": String, "message": String, "severity": String }
@export var strengths: Array[String] = []
@export var weaknesses: Array[String] = []
@export var recommendations: Array[String] = []
@export var educational_takeaways: Array[String] = []
