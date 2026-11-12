class_name SimulationEngine
extends Node

# SimulationEngine
# Deterministic, multi-phase simulation of spacecraft mission operations.
# Implements a robust 7-state Finite State Machine (FSM), real-time physical telemetry,
# solid-state data pipeline, realistic mission duration time scaling,
# and in-flight interactive decision systems.

signal phase_changed(phase_index: int, phase_name: String)
signal telemetry_updated(telemetry: Dictionary)
signal event_occurred(event: Dictionary)
signal state_changed(old_state: int, new_state: int)
signal decision_requested(decision_data: Dictionary)
signal simulation_finished(result: MissionResult)

enum SimState {
	NOT_STARTED = 0,
	READY = 1,
	RUNNING = 2,
	PAUSED = 3,
	AWAITING_DECISION = 4,
	COMPLETED = 5,
	FAILED = 6
}

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
	"Phase 6: Mission Evaluation Wrap-up"
]

# Base durations for UI visual pacing per phase (seconds in real-time)
const BASE_PHASE_DURATIONS = [
	6.0,  # Launch
	7.0,  # Cruise
	7.0,  # Arrival / Landing
	9.0,  # Science Ops
	7.0,  # Downlink
	2.0   # Evaluation wrap-up
]

var spacecraft: SpacecraftConfig
var mission: MissionConfig

var current_state: SimState = SimState.NOT_STARTED
var current_phase: SimPhase = SimPhase.LAUNCH
var phase_progress: float = 0.0
var sim_speed: float = 1.0

# Software reliability guards
var _has_completed: bool = false
var _decision_pending: bool = false
var _pending_decision_type: String = ""
var _completed_decisions: Dictionary = {}

# Physical & Scientific Telemetry
var events_log: Array[Dictionary] = []
var data_collected_mb: float = 0.0
var data_buffered_mb: float = 0.0
var data_downlinked_mb: float = 0.0
var data_dropped_mb: float = 0.0
var storage_capacity_mb: float = 64000.0 # 64 GB baseline

# Electrical & Power Telemetry
var battery_stored_wh: float = 1200.0
var battery_capacity_wh: float = 1200.0
var battery_percent: float = 100.0
var instantaneous_power_net_w: float = 0.0

# Trajectory & Orbital Telemetry
var signal_margin_db: float = 24.0
var altitude_km: float = 0.0
var velocity_kms: float = 0.0
var mission_elapsed_days: float = 0.0
var total_mission_target_days: float = 365.0

# Propulsion consumption tracking
var remaining_propellant_kg: float = 0.0
var initial_propellant_kg: float = 0.0

# Mission status
var mission_failed: bool = false
var failure_cause: String = ""

# NASA Landing Site (for Moon showcase)
var selected_landing_site: String = "Peak of Eternal Light (Connecting Ridge)"

func start_simulation(sc: SpacecraftConfig, m: MissionConfig) -> void:
	if current_state == SimState.RUNNING:
		return

	spacecraft = sc
	mission = m
	events_log.clear()
	_has_completed = false
	_decision_pending = false
	_completed_decisions.clear()
	
	mission_failed = false
	failure_cause = ""
	
	total_mission_target_days = mission.duration_days if mission else 365.0
	mission_elapsed_days = 0.0
	
	# Initialize solid-state memory buffer
	data_collected_mb = 0.0
	data_buffered_mb = 0.0
	data_downlinked_mb = 0.0
	data_dropped_mb = 0.0
	storage_capacity_mb = max(32.0, spacecraft.total_storage_capacity_gb) * 1024.0
	
	# Initialize battery storage
	battery_capacity_wh = max(100.0, spacecraft.total_battery_capacity_wh)
	battery_stored_wh = battery_capacity_wh
	battery_percent = 100.0
	
	# Initialize propellant
	initial_propellant_kg = spacecraft.total_propellant_mass
	remaining_propellant_kg = initial_propellant_kg

	current_phase = SimPhase.LAUNCH
	phase_progress = 0.0
	sim_speed = 1.0
	
	_set_state(SimState.RUNNING)
	_trigger_phase_start(current_phase)

func pause_simulation() -> void:
	if current_state == SimState.RUNNING:
		_set_state(SimState.PAUSED)

func resume_simulation() -> void:
	if current_state == SimState.PAUSED:
		_set_state(SimState.RUNNING)

func set_speed(multiplier: float) -> void:
	sim_speed = clamp(multiplier, 0.5, 8.0)

func skip_to_end() -> void:
	if current_state != SimState.RUNNING and current_state != SimState.PAUSED and current_state != SimState.AWAITING_DECISION:
		return
	
	# Auto-resolve pending decision with conservative choice if skipping
	if current_state == SimState.AWAITING_DECISION:
		submit_decision(0)
		
	while current_phase < SimPhase.COMPLETED and not mission_failed and not _has_completed:
		_advance_phase()
		
	if not _has_completed:
		_complete_simulation()

func _set_state(new_state: SimState) -> void:
	if current_state == new_state:
		return
	var old = current_state
	current_state = new_state
	emit_signal("state_changed", int(old), int(new_state))

func _process(delta: float) -> void:
	if current_state != SimState.RUNNING:
		return

	var step = delta * sim_speed
	phase_progress += step

	_update_telemetry(step)

	# Check for interactive decision triggers
	_check_decision_triggers()

	if current_state != SimState.RUNNING:
		return

	var duration = BASE_PHASE_DURATIONS[current_phase]
	if phase_progress >= duration:
		if current_phase < SimPhase.COMPLETED:
			_advance_phase()
		else:
			_complete_simulation()

func _update_telemetry(delta: float) -> void:
	var progress_fraction = clamp(phase_progress / max(0.1, BASE_PHASE_DURATIONS[current_phase]), 0.0, 1.0)
	
	# 1. Trajectory & Orbit Kinematics
	match current_phase:
		SimPhase.LAUNCH:
			mission_elapsed_days = lerpf(0.0, 0.1, progress_fraction)
			altitude_km = lerpf(0.0, 300.0, progress_fraction)
			velocity_kms = lerpf(0.0, 7.8, progress_fraction)
			signal_margin_db = 35.0
			instantaneous_power_net_w = spacecraft.net_power

		SimPhase.CRUISE:
			match mission.destination:
				"Earth":
					mission_elapsed_days = lerpf(0.1, 1.0, progress_fraction)
					altitude_km = 705.0
					velocity_kms = 7.5
				"Moon":
					mission_elapsed_days = lerpf(0.1, 4.0, progress_fraction) # 3.5 days cis-lunar transit
					altitude_km = lerpf(300.0, 384400.0, progress_fraction)
					velocity_kms = lerpf(10.8, 1.6, progress_fraction)
				"Mars":
					mission_elapsed_days = lerpf(0.1, 210.0, progress_fraction) # 7-month cruise
					altitude_km = lerpf(300.0, 54600000.0, progress_fraction)
					velocity_kms = lerpf(11.2, 5.4, progress_fraction)
			signal_margin_db = lerpf(32.0, 18.0, progress_fraction)

		SimPhase.ARRIVAL:
			match mission.destination:
				"Earth":
					mission_elapsed_days = lerpf(1.0, 2.0, progress_fraction)
					altitude_km = 705.0
					velocity_kms = 7.5
				"Moon":
					mission_elapsed_days = lerpf(4.0, 4.5, progress_fraction) # PDI descent
					altitude_km = lerpf(100.0, 0.0, progress_fraction)
					velocity_kms = lerpf(1.6, 0.0, progress_fraction)
				"Mars":
					mission_elapsed_days = lerpf(210.0, 210.5, progress_fraction) # EDL
					altitude_km = lerpf(125.0, 0.0, progress_fraction)
					velocity_kms = lerpf(6.1, 0.0, progress_fraction)
			signal_margin_db = 16.0

		SimPhase.OPERATIONS:
			var ops_start = 2.0 if mission.destination == "Earth" else (4.5 if mission.destination == "Moon" else 210.5)
			var ops_end = total_mission_target_days * 0.90
			mission_elapsed_days = lerpf(ops_start, ops_end, progress_fraction)
			
			# Real scientific data generation pipeline
			var gen_rate = spacecraft.total_data_generation * (delta * (total_mission_target_days / 60.0))
			data_collected_mb += gen_rate
			
			# Store in solid-state memory buffer
			if (data_buffered_mb + gen_rate) <= storage_capacity_mb:
				data_buffered_mb += gen_rate
			else:
				var overflow = (data_buffered_mb + gen_rate) - storage_capacity_mb
				data_buffered_mb = storage_capacity_mb
				data_dropped_mb += overflow

		SimPhase.DOWNLINK:
			var dl_start = total_mission_target_days * 0.90
			mission_elapsed_days = lerpf(dl_start, total_mission_target_days, progress_fraction)
			
			# Downlink transmission through Deep Space Network or Ground Stations
			var dl_speed_mbs = max(5.0, spacecraft.comms_capacity) * 2.0 # compression & batch multiplier
			var tx_amount = dl_speed_mbs * delta * 15.0
			var chunk = min(data_buffered_mb, tx_amount)
			data_downlinked_mb += chunk
			data_buffered_mb -= chunk
			signal_margin_db = 22.0

	# 2. Environmental Power & Battery Physics
	_update_power_physics(delta)

	# 3. Publish Telemetry Stream
	var telemetry = {
		"state": int(current_state),
		"phase_index": int(current_phase),
		"phase_name": PHASE_NAMES[current_phase],
		"progress": progress_fraction,
		"altitude_km": altitude_km,
		"velocity_kms": velocity_kms,
		"battery_percent": battery_percent,
		"battery_wh": battery_stored_wh,
		"power_net_w": instantaneous_power_net_w,
		"signal_margin_db": signal_margin_db,
		"data_collected": data_collected_mb,
		"data_buffered": data_buffered_mb,
		"data_downlinked": data_downlinked_mb,
		"data_dropped": data_dropped_mb,
		"storage_capacity_mb": storage_capacity_mb,
		"mission_elapsed_days": snapped(mission_elapsed_days, 0.1),
		"remaining_propellant_kg": remaining_propellant_kg
	}
	emit_signal("telemetry_updated", telemetry)

func _update_power_physics(delta: float) -> void:
	var available_gen_w = spacecraft.total_power_generation
	var active_con_w = spacecraft.total_power_consumption

	# Environmental flux scaling
	match mission.destination:
		"Mars":
			# Mars receives ~43% solar flux (1 / 1.524^2)
			if not spacecraft.has_component("power_rtg") and not spacecraft.has_component("power_dual_rtg"):
				available_gen_w *= 0.43
		"Moon":
			# Shackleton Crater interior: 0% solar
			if current_phase == SimPhase.OPERATIONS and selected_landing_site.contains("Interior"):
				if not spacecraft.has_component("power_rtg") and not spacecraft.has_component("power_dual_rtg"):
					available_gen_w = 0.0

	var net_w = available_gen_w - active_con_w
	instantaneous_power_net_w = net_w

	if net_w >= 0.0:
		# Battery charging (efficiency ~92%)
		var charge_step = net_w * (delta / 3600.0) * 0.92 * 120.0 # accelerated time factor
		battery_stored_wh = min(battery_capacity_wh, battery_stored_wh + charge_step)
	else:
		# Battery discharging (efficiency ~96%)
		var discharge_step = abs(net_w) * (delta / 3600.0) * (1.0 / 0.96) * 120.0
		battery_stored_wh = max(0.0, battery_stored_wh - discharge_step)
		if battery_stored_wh <= 0.0:
			_log_event("Power Brownout Critical", "Battery storage depleted! Instruments entering cold shutdown.", "critical")

	battery_percent = clamp((battery_stored_wh / max(1.0, battery_capacity_wh)) * 100.0, 0.0, 100.0)

func _advance_phase() -> void:
	phase_progress = 0.0
	current_phase = ((int(current_phase) + 1) as SimPhase)
	if current_phase <= SimPhase.COMPLETED:
		_trigger_phase_start(current_phase)

func _trigger_phase_start(phase: SimPhase) -> void:
	emit_signal("phase_changed", int(phase), PHASE_NAMES[phase])

	match phase:
		SimPhase.LAUNCH:
			_log_event("T-0: Ignition", "Main stage rocket booster ignition. Spacecraft cleared the launch pad.", "info")
			if spacecraft.total_mass > mission.mass_limit:
				var excess = spacecraft.total_mass - mission.mass_limit
				if excess > (mission.mass_limit * 0.25):
					_log_event("Booster Underperformance Abort", "Mass exceeds launch vehicle rating by %.1f kg. Trajectory degraded." % excess, "critical")
					_trigger_terminal_failure("Launch vehicle over-capacity abort.")
				else:
					_log_event("Heavy Payload Warning", "Booster propellant reserves diminished due to payload mass margin.", "warning")
			else:
				_log_event("Max-Q Passed", "Aerodynamic max dynamic pressure nominal. Stage separation confirmed.", "success")

		SimPhase.CRUISE:
			if mission_failed: return
			_log_event("Injection Burn Complete", "Trans-destination injection trajectory established. Solar arrays / RTG energized.", "info")
			if spacecraft.total_delta_v < (mission.min_delta_v * 0.70):
				_log_event("Propulsion Deficit", "Delta-v budget (%.0f m/s) insufficient for course insertion." % spacecraft.total_delta_v, "critical")
				_trigger_terminal_failure("Insufficient propulsion delta-v for destination capture.")
			else:
				_log_event("Mid-Course Correction", "Trajectory trim burn executed nominally.", "success")

		SimPhase.ARRIVAL:
			if mission_failed: return
			match mission.destination:
				"Earth":
					_log_event("Sun-Synchronous Orbit Trim", "Circular 705 km Sun-synchronous orbit trimmed. Inclination 98.2° nominal.", "success")
				"Moon":
					_log_event("Lunar Orbit Capture Burn", "LOI burn executed. Entering powered descent toward Shackleton Crater.", "info")
					if not spacecraft.has_component("land_lunar_legs"):
						_log_event("Hard Surface Collision", "No landing legs installed! Lander suffered fatal touchdown impact.", "critical")
						_trigger_terminal_failure("Lunar surface crash: missing landing gear.")
					else:
						_log_event("Touchdown Confirmed", "Soft touchdown confirmed at %s!" % selected_landing_site, "success")
				"Mars":
					_log_event("Hypersonic Entry (EDL)", "Atmospheric entry interface at Mach 24. PICA heat shield nominal.", "info")
					if not spacecraft.has_component("land_mars_entry"):
						_log_event("Hypersonic Disintegration", "Spacecraft entered Mars atmosphere without Heat Shield! Disintegrated.", "critical")
						_trigger_terminal_failure("Aeroshell missing during hypersonic Mars EDL.")
					elif spacecraft.has_component("land_skycrane"):
						_log_event("Sky Crane Flyaway", "Rover lowered gently onto wheels in Jezero Crater ancient river delta!", "success")
					else:
						_log_event("Rough Touchdown", "Touchdown completed without Sky Crane. Chassis suspension stress recorded.", "warning")

		SimPhase.OPERATIONS:
			if mission_failed: return
			_log_event("Science Payload Active", "Scientific payload initialized. Surface and orbital surveys begun.", "info")
			if spacecraft.has_component("mobility_lunar_rover"):
				_log_event("Micro-Rover Deployed", "Shadow Explorer micro-rover deployed into Shackleton Crater PSR to core water ice!", "success")

		SimPhase.DOWNLINK:
			if mission_failed: return
			_log_event("NASA DSN Lock Acquired", "NASA Deep Space Network 70-meter antenna lock established.", "info")
			if not spacecraft.has_category("Communications"):
				_log_event("Downlink Failure", "No antenna installed! Zero scientific data transmitted to Earth.", "critical")
			elif spacecraft.comms_capacity < mission.communication_requirement:
				_log_event("Bandwidth Bottleneck", "Telemetry rate (%.1f Mbps) bottlenecked below mission target." % spacecraft.comms_capacity, "warning")
			else:
				_log_event("Downlink Pipeline Nominal", "Calibrated scientific telemetry downlinked to NASA archives.", "success")

		SimPhase.COMPLETED:
			_complete_simulation()

func _check_decision_triggers() -> void:
	if _decision_pending or mission_failed:
		return

	# Decision 1: Power Management Event during Cruise / Insertion (at 50% progress)
	if current_phase == SimPhase.CRUISE and phase_progress >= (BASE_PHASE_DURATIONS[SimPhase.CRUISE] * 0.45):
		if not _completed_decisions.has("power_event"):
			_trigger_power_decision()
			return

	# Decision 2: Operational Hazard Event during Arrival (at 50% progress)
	if current_phase == SimPhase.ARRIVAL and phase_progress >= (BASE_PHASE_DURATIONS[SimPhase.ARRIVAL] * 0.45):
		if not _completed_decisions.has("hazard_event"):
			_trigger_hazard_decision()
			return

	# Decision 3: Telecom / Data Scheduling Event during Operations (at 50% progress)
	if current_phase == SimPhase.OPERATIONS and phase_progress >= (BASE_PHASE_DURATIONS[SimPhase.OPERATIONS] * 0.50):
		if not _completed_decisions.has("telecom_event"):
			_trigger_telecom_decision()
			return

func _trigger_power_decision() -> void:
	_decision_pending = true
	_pending_decision_type = "power_event"
	_set_state(SimState.AWAITING_DECISION)

	var title = "POWER MANAGEMENT // ECLIPSE ENERGY ALLOCATION"
	var context = ""
	match mission.destination:
		"Earth":
			context = "TerraPulse-1 is entering an orbital eclipse (35 minutes in Earth's shadow). Solar arrays produce 0W. Current battery capacity: %.0f Wh." % battery_capacity_wh
		"Moon":
			context = "Artemis Prospector is transiting across the Shackleton Crater shadow boundary. Thermal heaters and instrument draw must be balanced against battery reserves."
		"Mars":
			context = "A local Martian regional dust storm has reduced atmospheric optical depth (Tau = 1.8), cutting solar irradiance by 60%."

	var options = [
		{
			"title": "A: Power-Shedding Safe Mode",
			"desc": "Shut down non-essential scientific instruments. Keep only thermal survival heaters and command receiver active.",
			"effect": "Battery safely preserved at 100%. Zero brownout risk. Science collection temporarily paused."
		},
		{
			"title": "B: Prioritize Primary Science Payload",
			"desc": "Keep primary multispectral imager or spectrometer running; throttle secondary sensors and high-rate telemetry.",
			"effect": "Maintains 75% science collection rate. Discharges battery moderately (DoD ~35%)."
		},
		{
			"title": "C: Max Continuous High-Power Survey",
			"desc": "Override duty-cycling and run all instruments at 100% capacity using battery energy storage buffer.",
			"effect": "+30% Science bonus! Warning: If battery capacity is under 1000 Wh, risks battery depletion!"
		}
	]

	emit_signal("decision_requested", {
		"type": "power_event",
		"title": title,
		"context": context,
		"options": options
	})

func _trigger_hazard_decision() -> void:
	_decision_pending = true
	_pending_decision_type = "hazard_event"
	_set_state(SimState.AWAITING_DECISION)

	var title = "AUTONOMOUS OPERATIONAL HAZARD // DESCENT DIVERT"
	var context = ""
	var options = []

	match mission.destination:
		"Moon":
			title = "SHACKLETON CRATER TOPOGRAPHY // TOUCHDOWN HAZARD"
			context = "Lander LiDAR detects 22° boulder-strewn slope at prime touchdown footprint on Shackleton Crater rim."
			options = [
				{
					"title": "A: Autonomous LiDAR Divert to Flat Ridge",
					"desc": "Burn descent thrusters for 6 seconds to translate 300m toward the Peak of Eternal Light connecting ridge.",
					"effect": "Consumes 80 m/s delta-v. Guarantees 100% nominal upright touchdown."
				},
				{
					"title": "B: Deploy Micro-Rover Ahead for Surface Recon",
					"desc": "If micro-rover is equipped, deploy tether to verify footpad stability before engine shutdown.",
					"effect": "Optimal if Micro-Rover installed! Validates regolith bearing strength."
				},
				{
					"title": "C: Direct Touchdown on Slope",
					"desc": "Conserve fuel and land directly on slope using crushable landing leg honeycomb struts.",
					"effect": "Zero extra propellant consumed, but 35% risk of leg structural fatigue."
				}
			]
		"Mars":
			title = "MARS EDL // ATMOSPHERIC DENSITY DISPERSION"
			context = "Inertial measurement unit (IMU) reports supersonic atmospheric density anomaly at 11 km altitude."
			options = [
				{
					"title": "A: Deploy Supersonic Parachute 3 Seconds Early",
					"desc": "Deploy disk-gap-band parachute at higher dynamic pressure to bleed excess velocity.",
					"effect": "Increases deceleration margin. Eliminates risk of late terminal trigger."
				},
				{
					"title": "B: Maintain Nominal Radar Doppler Trigger",
					"desc": "Follow autonomous flight software baseline without manual ground override.",
					"effect": "Nominal flight profile. Standard mechanical bridle loads."
				},
				{
					"title": "C: Throttle Sky Crane Rockets for +15m Hover",
					"desc": "Extend terminal hover altitude to prevent rocket plume dust recirculation into rover cameras.",
					"effect": "Protects science lenses from dust; consumes 45 m/s extra descent fuel."
				}
			]
		"Earth":
			title = "ORBITAL CONJUNCTION // SPACE DEBRIS WARNING"
			context = "Space Command radar flags a defunct upper-stage rocket fragment passing within 380 meters of satellite track."
			options = [
				{
					"title": "A: Execute Collision Avoidance Burn",
					"desc": "Fire hydrazine RCS thrusters to adjust orbital altitude by +2.5 km.",
					"effect": "Consumes 15 m/s propellant. Reduces collision probability to 0.000%."
				},
				{
					"title": "B: Orient Minimum Cross-Section Area",
					"desc": "Rotate satellite solar arrays edge-on toward debris vector to minimize radar cross-section.",
					"effect": "Zero propellant consumed. Lowers impact cross-section by 85%."
				},
				{
					"title": "C: Maintain Orbit Track & Sensor Pointing",
					"desc": "Maintain Earth-pointing observation mode to prevent interruption of multispectral pass.",
					"effect": "Science collection continues uninterrupted; minor statistical debris risk."
				}
			]

	emit_signal("decision_requested", {
		"type": "hazard_event",
		"title": title,
		"context": context,
		"options": options
	})

func _trigger_telecom_decision() -> void:
	_decision_pending = true
	_pending_decision_type = "telecom_event"
	_set_state(SimState.AWAITING_DECISION)

	var title = "TELECOM & MEMORY // DSN PASS SCHEDULING"
	var context = "Spacecraft has a 25-minute line-of-sight window with NASA Deep Space Network. Solid-state buffer contains %.0f MB of raw observations." % data_buffered_mb
	var options = [
		{
			"title": "A: Prioritize High-Resolution Spectroscopy Data",
			"desc": "Downlink raw high-value geochemical and spectral datasets first without compression.",
			"effect": "+20 Science Rating bonus! Consumes 90% of ground station pass window."
		},
		{
			"title": "B: Run Lossless Onboard Data Compression",
			"desc": "Execute onboard compression pipeline before transmission. Reduces dataset size by 50%.",
			"effect": "Downlinks 100% of collected survey telemetry! Clears solid-state memory buffer."
		},
		{
			"title": "C: Buffer Observations in Solid-State Memory",
			"desc": "Store data on 1 TB recorder and wait for next high-elevation ground pass.",
			"effect": "Saves transmitter RF power; depends on recorder buffer capacity."
		}
	]

	emit_signal("decision_requested", {
		"type": "telecom_event",
		"title": title,
		"context": context,
		"options": options
	})

func submit_decision(option_idx: int) -> void:
	if not _decision_pending:
		return

	var dec_type = _pending_decision_type
	_completed_decisions[dec_type] = option_idx
	_decision_pending = false
	_pending_decision_type = ""

	match dec_type:
		"power_event":
			match option_idx:
				0:
					_log_event("Flight Order: Safe Mode", "Non-essential sensors shed. Power bus stabilized at 100% reserve.", "info")
				1:
					_log_event("Flight Order: Core Science Active", "Primary instruments maintained on duty cycle. Battery buffered at %.0f%%." % battery_percent, "success")
					data_collected_mb += spacecraft.total_data_generation * 0.5
				2:
					if battery_capacity_wh >= 1000.0:
						_log_event("Flight Order: Max Science Survey", "High-power survey sustained by heavy battery buffer! +30% Science bonus.", "success")
						data_collected_mb += spacecraft.total_data_generation * 1.2
					else:
						_log_event("Battery Warning: Deep Discharge", "Battery drained below 15% DoD during survey. Minor brownout warning.", "warning")
						battery_stored_wh = max(10.0, battery_stored_wh - 250.0)

		"hazard_event":
			match option_idx:
				0:
					_log_event("Flight Order: Divert Maneuver", "Avoidance maneuver executed nominally. Target cleared safely.", "success")
					remaining_propellant_kg = max(0.0, remaining_propellant_kg - 25.0)
				1:
					if mission.destination == "Moon" and spacecraft.has_component("mobility_lunar_rover"):
						_log_event("Rover Surface Recon", "Micro-rover deployed ahead! Verified firm regolith at touchdown site.", "success")
					else:
						_log_event("Flight Order: Adjusted Attitude", "Spacecraft sliced orientation edge-on. Minimal impact risk.", "info")
				2:
					_log_event("Flight Order: Maintained Track", "Nominal flight profile maintained without propellant penalty.", "info")

		"telecom_event":
			match option_idx:
				0:
					_log_event("Flight Order: High-Res Downlink", "Raw high-precision spectroscopy stream prioritized across DSN.", "success")
					data_downlinked_mb += min(data_buffered_mb, 450.0)
				1:
					_log_event("Flight Order: Onboard Compression", "Lossless data compression cleared solid-state buffer completely.", "success")
					data_downlinked_mb += data_buffered_mb
					data_buffered_mb = 0.0
				2:
					_log_event("Flight Order: Buffered to SSD", "Science data safely preserved in onboard rad-hard flash recorder.", "info")

	_set_state(SimState.RUNNING)

func _trigger_terminal_failure(cause: String) -> void:
	mission_failed = true
	failure_cause = cause
	_set_state(SimState.FAILED)
	_complete_simulation()

func _log_event(title: String, message: String, severity: String) -> void:
	var ev = MissionEvents.create_event(mission_elapsed_days, PHASE_NAMES[current_phase], title, message, severity)
	events_log.append(ev)
	emit_signal("event_occurred", ev)

func _complete_simulation() -> void:
	# Software reliability guard against duplicate completion
	if _has_completed:
		return
	_has_completed = true

	if not mission_failed:
		_set_state(SimState.COMPLETED)

	var completed_phase_count = int(current_phase)
	if mission_failed:
		completed_phase_count = max(1, completed_phase_count - 1)
	else:
		completed_phase_count = 6
		
	var target_data = max(100.0, spacecraft.total_data_generation * 1.5)
	if data_downlinked_mb <= 0.0 and not mission_failed and spacecraft.has_category("Communications"):
		data_downlinked_mb = min(data_collected_mb, spacecraft.comms_capacity * 10.0)

	var result = ScoringEngine.calculate_score(
		spacecraft,
		mission,
		completed_phase_count,
		6,
		data_downlinked_mb,
		target_data,
		events_log
	)
	result.events = events_log
	if mission_failed:
		result.weaknesses.append("Catastrophic mission loss: " + failure_cause)
		
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root and loop.root.has_node("GameManager"):
		loop.root.get_node("GameManager").set_mission_result(result)
	emit_signal("simulation_finished", result)
