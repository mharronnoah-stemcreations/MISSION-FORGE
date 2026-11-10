class_name SimulationEngine
extends Node

# SimulationEngine
# Deterministic, multi-phase simulation of spacecraft mission operations.
# Evaluates engineering trade-offs dynamically and generates real-time telemetry.

signal phase_changed(phase_index: int, phase_name: String)
signal telemetry_updated(telemetry: Dictionary)
signal event_occurred(event: Dictionary)
signal simulation_finished(result: MissionResult)

enum SimPhase {
	LAUNCH = 0,
	CRUISE = 1,
	ARRIVAL = 2,
	OPERATIONS = 3,
	DOWNLINK = 4,
	COMPLETED = 5
}

const PHASE_NAMES = [
	"Phase 1: Launch & Ascent",
	"Phase 2: Orbital Insertion / Cruise",
	"Phase 3: Destination Arrival & Descent",
	"Phase 4: Scientific Operations",
	"Phase 5: Earth Data Downlink",
	"Phase 6: Mission Evaluation"
]

const PHASE_DURATIONS = [
	5.0,  # Launch
	6.0,  # Cruise
	6.0,  # Arrival / Landing
	8.0,  # Science Ops
	6.0,  # Telemetry Downlink
	2.0   # Evaluation wrap-up
]

var spacecraft: SpacecraftConfig
var mission: MissionConfig

var is_running: bool = false
var is_paused: bool = false
var current_phase: SimPhase = SimPhase.LAUNCH
var phase_progress: float = 0.0
var sim_speed: float = 1.0

var events_log: Array[Dictionary] = []
var data_collected: float = 0.0
var data_downlinked: float = 0.0
var battery_percent: float = 100.0
var signal_margin_db: float = 24.0
var altitude_km: float = 0.0
var velocity_kms: float = 0.0
var mission_elapsed_days: float = 0.0
var mission_failed: bool = false
var failure_cause: String = ""

func start_simulation(sc: SpacecraftConfig, m: MissionConfig) -> void:
	spacecraft = sc
	mission = m
	events_log.clear()
	data_collected = 0.0
	data_downlinked = 0.0
	battery_percent = 100.0
	mission_elapsed_days = 0.0
	mission_failed = false
	failure_cause = ""
	
	current_phase = SimPhase.LAUNCH
	phase_progress = 0.0
	sim_speed = 1.0
	is_running = true
	is_paused = false
	
	_trigger_phase_start(current_phase)

func pause_simulation() -> void:
	is_paused = true

func resume_simulation() -> void:
	is_paused = false

func set_speed(multiplier: float) -> void:
	sim_speed = clamp(multiplier, 0.5, 8.0)

func skip_to_end() -> void:
	if not is_running:
		return
	while current_phase < SimPhase.COMPLETED and not mission_failed:
		_advance_phase()
	_complete_simulation()

func _process(delta: float) -> void:
	if not is_running or is_paused:
		return

	var step = delta * sim_speed
	phase_progress += step

	_update_telemetry(step)

	var duration = PHASE_DURATIONS[current_phase]
	if phase_progress >= duration:
		if current_phase < SimPhase.COMPLETED:
			_advance_phase()
		else:
			_complete_simulation()

func _update_telemetry(delta: float) -> void:
	var progress_fraction = clamp(phase_progress / max(0.1, PHASE_DURATIONS[current_phase]), 0.0, 1.0)
	
	match current_phase:
		SimPhase.LAUNCH:
			altitude_km = lerpf(0.0, 300.0, progress_fraction)
			velocity_kms = lerpf(0.0, 7.8, progress_fraction)
			signal_margin_db = 35.0
			battery_percent = 100.0
			
		SimPhase.CRUISE:
			match mission.destination:
				"Earth":
					altitude_km = 705.0
					velocity_kms = 7.5
				"Moon":
					altitude_km = lerpf(300.0, 384400.0, progress_fraction)
					velocity_kms = lerpf(10.8, 1.6, progress_fraction)
				"Mars":
					altitude_km = lerpf(300.0, 54600000.0, progress_fraction)
					velocity_kms = lerpf(11.2, 5.4, progress_fraction)
			signal_margin_db = lerpf(32.0, 18.0, progress_fraction)
			
		SimPhase.ARRIVAL:
			match mission.destination:
				"Earth":
					altitude_km = 705.0
					velocity_kms = 7.5
				"Moon":
					altitude_km = lerpf(100.0, 0.0, progress_fraction)
					velocity_kms = lerpf(1.6, 0.0, progress_fraction)
				"Mars":
					altitude_km = lerpf(125.0, 0.0, progress_fraction)
					velocity_kms = lerpf(6.1, 0.0, progress_fraction)
			signal_margin_db = 16.0
			
		SimPhase.OPERATIONS:
			mission_elapsed_days += delta * 15.0
			var gen_rate = spacecraft.total_data_generation * (delta / 2.0)
			data_collected += gen_rate
			
			# Power balance effect
			if spacecraft.net_power < 0.0:
				battery_percent = max(0.0, battery_percent - (delta * 6.0))
			else:
				battery_percent = min(100.0, battery_percent + (delta * 2.0))
				
		SimPhase.DOWNLINK:
			mission_elapsed_days += delta * 10.0
			var dl_rate = spacecraft.comms_capacity * 4.0 * delta
			data_downlinked = min(data_collected, data_downlinked + dl_rate)
			signal_margin_db = 22.0

	var telemetry = {
		"phase_index": int(current_phase),
		"phase_name": PHASE_NAMES[current_phase],
		"progress": progress_fraction,
		"altitude_km": altitude_km,
		"velocity_kms": velocity_kms,
		"battery_percent": battery_percent,
		"signal_margin_db": signal_margin_db,
		"data_collected": data_collected,
		"data_downlinked": data_downlinked,
		"mission_elapsed_days": snapped(mission_elapsed_days, 0.1)
	}
	emit_signal("telemetry_updated", telemetry)

func _advance_phase() -> void:
	phase_progress = 0.0
	current_phase = SimPhase(int(current_phase) + 1)
	if current_phase <= SimPhase.COMPLETED:
		_trigger_phase_start(current_phase)

func _trigger_phase_start(phase: SimPhase) -> void:
	emit_signal("phase_changed", int(phase), PHASE_NAMES[phase])

	match phase:
		SimPhase.LAUNCH:
			_log_event("T-0: Liftoff", "Main engines ignition. Vehicle cleared the launch pad.", "info")
			# Check launch mass limit
			if spacecraft.total_mass > mission.mass_limit:
				var excess = spacecraft.total_mass - mission.mass_limit
				if excess > (mission.mass_limit * 0.3):
					_log_event("Launch Abort", "Mass exceeds booster lift capability by %.1f kg. Trajectory degraded." % excess, "critical")
					mission_failed = true
					failure_cause = "Launch vehicle over-capacity failure."
				else:
					_log_event("Heavy Payload Warning", "Booster second stage propellant margins reduced due to heavy payload.", "warning")
			else:
				_log_event("Max-Q Passed", "Spacecraft aerodynamic loads nominal. Stage separation confirmed.", "success")

		SimPhase.CRUISE:
			if mission_failed: return
			_log_event("Orbit Insertion", "Initial injection orbit established. Spacecraft systems online.", "info")
			
			if spacecraft.has_category("Power"):
				_log_event("Solar / RTG Deployment", "Power bus energized: %.0f Watts generated." % spacecraft.total_power_generation, "success")
			else:
				_log_event("Power Failure", "No power generation online. Operating solely on emergency reserves.", "critical")

			# Propulsion delta-v check
			if spacecraft.total_delta_v < (mission.min_delta_v * 0.7):
				_log_event("Propulsion Deficit", "Delta-V budget (%.0f m/s) insufficient for interplanetary trajectory." % spacecraft.total_delta_v, "critical")
			else:
				_log_event("Trajectory Trim Complete", "Mid-course correction burn executed with high precision.", "info")

		SimPhase.ARRIVAL:
			if mission_failed: return
			match mission.destination:
				"Earth":
					_log_event("Sun-Synchronous Orbit Trim", "Circular orbit at 705 km achieved. Inclination 98.2° nominal.", "success")
				"Moon":
					_log_event("Lunar Orbit Capture", "De-orbit burn complete. Terminal descent initiated.", "info")
					if spacecraft.has_component("land_lunar_legs"):
						_log_event("Touchdown Confirmed", "Soft touchdown at Shackleton Crater rim! All 4 landing gear deployed.", "success")
					else:
						_log_event("Hard Surface Impact", "No landing legs installed! Lander suffered fatal surface collision.", "critical")
						mission_failed = true
						failure_cause = "Lunar crash: missing landing gear."
				"Mars":
					_log_event("Atmospheric Entry (EDL)", "Aeroshell encountered peak heating at Mach 24. PICA shield nominal.", "info")
					if not spacecraft.has_component("land_mars_entry"):
						_log_event("Structural Breakup", "Landed without heat shield! Spacecraft disintegrated in upper atmosphere.", "critical")
						mission_failed = true
						failure_cause = "Aeroshell missing during hypersonic Mars entry."
					elif spacecraft.has_component("land_skycrane"):
						_log_event("Sky Crane Flyaway", "Rover lowered gently onto wheels in Jezero Crater paleolake delta!", "success")
					else:
						_log_event("Rough Touchdown", "Touchdown completed without Sky Crane. Chassis suspension damaged.", "warning")

		SimPhase.OPERATIONS:
			if mission_failed: return
			_log_event("Science Commenced", "Sensor payload activated. Scientific survey initiated.", "info")
			
			if spacecraft.net_power < 0.0:
				_log_event("Power Brownout", "Electrical consumption exceeds supply! Duty-cycle reduction activated.", "warning")

			# Collect raw science baseline
			data_collected = spacecraft.total_data_generation * 1.5
			var sc_val = spacecraft.total_science_value
			_log_event("Observations Collected", "Sensors acquired primary mission telemetry (%.0f Science Pts baseline)." % sc_val, "success")

		SimPhase.DOWNLINK:
			if mission_failed: return
			_log_event("Earth Station Acquisition", "NASA Deep Space Network lock acquired.", "info")
			
			if not spacecraft.has_category("Communications"):
				_log_event("Downlink Failure", "No communication antenna installed! Zero scientific data transmitted to Earth.", "critical")
			elif spacecraft.comms_capacity < mission.communication_requirement:
				_log_event("Bandwidth Throttled", "Antenna bitrate (%.1f Mbps) bottlenecked. Only partial datasets downlinked." % spacecraft.comms_capacity, "warning")
			else:
				_log_event("High-Throughput Downlink", "All imagery and spectrometer packets safely downlinked to Earth archives.", "success")

		SimPhase.COMPLETED:
			_complete_simulation()

func _log_event(title: String, message: String, severity: String) -> void:
	var ev = MissionEvents.create_event(mission_elapsed_days, PHASE_NAMES[current_phase], title, message, severity)
	events_log.append(ev)
	emit_signal("event_occurred", ev)

func _complete_simulation() -> void:
	is_running = false
	var completed_phase_count = int(current_phase)
	if mission_failed:
		completed_phase_count = max(1, completed_phase_count - 1)
	else:
		completed_phase_count = 6
		
	var target_data = max(100.0, spacecraft.total_data_generation * 1.5)
	if data_downlinked <= 0.0 and not mission_failed and spacecraft.has_category("Communications"):
		data_downlinked = min(data_collected, spacecraft.comms_capacity * 10.0)

	var result = ScoringEngine.calculate_score(
		spacecraft,
		mission,
		completed_phase_count,
		6,
		data_downlinked,
		target_data,
		events_log
	)
	result.events = events_log
	if mission_failed:
		result.weaknesses.append("Catastrophic mission loss: " + failure_cause)
		
	GameManager.set_mission_result(result)
	emit_signal("simulation_finished", result)
