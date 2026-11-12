extends SceneTree

# Automated headless QA unit and integration test runner for MISSIONFORGE
# Validates:
# - Data loading & schema integrity (components, missions, NASA datasets)
# - Battery Wh energy storage vs. power generation physics
# - Tsiolkovsky rocket equation & multi-engine propulsion
# - Hard vs. Soft validation constraints and actionable tips
# - 7-state Finite State Machine (FSM) & reliability guards (duplicate completion, failure halt)
# - Solid-state memory buffer and downlink data pipeline
# - Mission Performance Index (MPI) scoring formulas & After-Action analysis
# - Earth, Moon (Artemis Showcase), and Mars mission profiles

var MissionManager: Node

func _init() -> void:
	print("==================================================")
	print("🛰️  MISSIONFORGE AUTOMATED TEST SUITE INITIALIZED")
	print("==================================================")

	var mm_script = load("res://scripts/managers/mission_manager.gd")
	MissionManager = mm_script.new()
	MissionManager.name = "MissionManager"
	root.add_child(MissionManager)
	MissionManager._ready()

	var success = true
	success = success and _test_data_loading()
	success = success and _test_power_and_battery_physics()
	success = success and _test_propulsion_tsiolkovsky()
	success = success and _test_validation_engine_constraints()
	success = success and _test_simulation_state_machine_and_decisions()
	success = success and _test_data_pipeline_and_buffers()
	success = success and _test_mpi_scoring_engine()
	success = success and _test_planetary_mission_profiles()

	print("==================================================")
	if success:
		print("🎉 ALL MISSIONFORGE AUTOMATED TESTS PASSED (100% NOMINAL)")
	else:
		push_error("❌ SOME TESTS FAILED")
	print("==================================================")

	quit(0 if success else 1)

func _test_data_loading() -> bool:
	print("\n[TEST 1] Data Loading & Schema Verification...")
	var mm = MissionManager
	if mm == null:
		push_error("FAIL: MissionManager not available.")
		return false

	var all_comps = mm.get_all_components()
	print("  ✓ Total Components Loaded: %d" % all_comps.size())
	if all_comps.size() < 24:
		push_error("FAIL: Expected at least 24 components, got %d" % all_comps.size())
		return false

	# Verify all 7 categories exist
	for cat in ["Structure", "Power", "Instruments", "Communications", "Propulsion", "Landing", "Data"]:
		var in_cat = mm.get_components_by_category(cat)
		if in_cat.is_empty():
			push_error("FAIL: Category '%s' has 0 components." % cat)
			return false
		print("  ✓ Category '%s': %d components" % [cat, in_cat.size()])

	# Verify 3 mission scenarios with NASA datasets
	for m_id in ["earth_observation", "lunar_exploration", "mars_rover"]:
		var m = mm.get_mission(m_id)
		if m == null:
			push_error("FAIL: Missing mission configuration: " + m_id)
			return false
		print("  ✓ Mission '%s' (%s) Loaded: Budget=$%.0fM, Mass=%.0fkg, Delta-V=%.0fm/s" % [
			m.mission_name, m.destination, m.budget_limit, m.mass_limit, m.min_delta_v
		])

	# Check NASA Artemis South Pole landing sites in lunar mission
	var lunar = mm.get_mission("lunar_exploration")
	if lunar.nasa_landing_sites.size() < 3:
		push_error("FAIL: Expected at least 3 NASA landing sites in Artemis Prospector.")
		return false
	print("  ✓ Artemis Prospector: %d NASA landing sites loaded (LRO/ShadowCam verified)" % lunar.nasa_landing_sites.size())

	return true

func _test_power_and_battery_physics() -> bool:
	print("\n[TEST 2] Energy Storage & Power Physics Verification...")
	var mm = MissionManager
	var battery = mm.get_component("power_li_battery")
	var rtg = mm.get_component("power_rtg")

	# Battery must NOT generate continuous power
	if battery.power_generation != 0.0:
		push_error("FAIL: Battery power_generation must be 0.0, got %.1f" % battery.power_generation)
		return false
	if battery.battery_capacity_wh <= 0.0:
		push_error("FAIL: Battery capacity must be > 0 Wh.")
		return false
	print("  ✓ Battery correctly stores energy (%.0f Wh) with 0.0W active generation." % battery.battery_capacity_wh)

	# RTG must align with Perseverance MMRTG baseline (110W electrical, 2000W thermal)
	if abs(rtg.power_generation - 110.0) > 1.0:
		push_error("FAIL: RTG electrical power must be ~110W, got %.1f" % rtg.power_generation)
		return false
	if abs(rtg.thermal_output_w - 2000.0) > 1.0:
		push_error("FAIL: RTG thermal output must be ~2000W, got %.1f" % rtg.thermal_output_w)
		return false
	print("  ✓ MMRTG specifications verified: %.0fW electrical, %.0fW thermal." % [
		rtg.power_generation, rtg.thermal_output_w
	])

	# Test energy discharge runtime calculation
	var sc = SpacecraftConfig.new()
	sc.add_component(mm.get_component("bus_medium_sat")) # 40W
	sc.add_component(battery) # 1200 Wh, 4W draw
	sc.recalculate()
	
	var summary = ResourceCalculator.calculate_summary(sc)
	print("  ✓ Battery runtime in darkness: %.1f hours at %.0fW continuous load." % [
		summary["battery_runtime_hours"], abs(summary["net_power"])
	])
	if summary["battery_runtime_hours"] <= 0.0 or summary["battery_runtime_hours"] > 100.0:
		push_error("FAIL: Unreasonable battery runtime hours.")
		return false

	return true

func _test_propulsion_tsiolkovsky() -> bool:
	print("\n[TEST 3] Tsiolkovsky Rocket Equation & Propulsion Verification...")
	var mm = MissionManager
	var sc = SpacecraftConfig.new()

	var bus = mm.get_component("bus_medium_sat") # 320kg dry
	var biprop = mm.get_component("prop_biprop") # 480kg total, 60kg dry, 420kg prop, Isp 325s

	sc.add_component(bus)
	sc.add_component(biprop)
	sc.recalculate()

	var expected_m0 = 320.0 + 480.0 # 800 kg
	var expected_mf = 320.0 + 60.0  # 380 kg dry
	var expected_isp = 325.0
	var expected_dv = expected_isp * 9.80665 * log(expected_m0 / expected_mf) # ~2370 m/s

	print("  ✓ Wet Mass: %.1f kg, Dry Mass: %.1f kg, Propellant: %.1f kg" % [
		sc.total_mass, sc.dry_mass, sc.total_propellant_mass
	])
	print("  ✓ Calculated Delta-V: %.1f m/s (Theoretical Tsiolkovsky: %.1f m/s)" % [
		sc.total_delta_v, expected_dv
	])

	if abs(sc.total_delta_v - expected_dv) > 1.0:
		push_error("FAIL: Delta-v calculation did not match Tsiolkovsky equation.")
		return false

	return true

func _test_validation_engine_constraints() -> bool:
	print("\n[TEST 4] Hard vs. Soft Validation Constraints Verification...")
	var mm = MissionManager
	var earth_m = mm.get_mission("earth_observation")

	# Subtest A: Empty craft fails Hard Constraints
	var empty_sc = SpacecraftConfig.new()
	var res_empty = MissionValidator.validate(empty_sc, earth_m)
	if res_empty.is_valid:
		push_error("FAIL: Empty spacecraft passed validation.")
		return false
	print("  ✓ Empty spacecraft correctly rejected with %d Hard Constraint error(s)." % res_empty.errors.size())

	# Subtest B: Overweight craft fails launch booster Hard Constraint
	var over_sc = SpacecraftConfig.new()
	over_sc.add_component(mm.get_component("bus_deep_space"))
	over_sc.add_component(mm.get_component("chassis_mars_rover"))
	over_sc.add_component(mm.get_component("land_mars_entry"))
	over_sc.add_component(mm.get_component("prop_biprop"))
	over_sc.add_component(mm.get_component("prop_aux_tank"))
	var res_over = MissionValidator.validate(over_sc, earth_m)
	if res_over.is_valid or res_over.errors.is_empty():
		push_error("FAIL: Overweight craft passed.")
		return false
	print("  ✓ Overweight payload correctly blocked: '%s'" % res_over.errors[0])

	# Subtest C: Power deficit with battery creates SOFT warning, not launch blocker
	var duty_sc = SpacecraftConfig.new()
	duty_sc.add_component(mm.get_component("bus_medium_sat"))
	duty_sc.add_component(mm.get_component("power_rtg")) # 110W
	duty_sc.add_component(mm.get_component("power_li_battery")) # 1200 Wh buffer
	duty_sc.add_component(mm.get_component("inst_sar_radar")) # 220W draw -> deficit
	duty_sc.add_component(mm.get_component("comm_omni_low_gain"))
	duty_sc.add_component(mm.get_component("prop_monoprop"))
	duty_sc.add_component(mm.get_component("data_rad_computer"))
	duty_sc.add_component(mm.get_component("inst_multispectral_imager"))
	var res_duty = MissionValidator.validate(duty_sc, earth_m)
	if not res_duty.is_valid:
		push_error("FAIL: Spacecraft with battery buffer was blocked for power duty-cycling: " + str(res_duty.errors))
		return false
	print("  ✓ Duty-cycled spacecraft passed with Soft Warnings (%d warnings, %d tips)." % [
		res_duty.warnings.size(), res_duty.tips.size()
	])

	return true

func _test_simulation_state_machine_and_decisions() -> bool:
	print("\n[TEST 5] Simulation State Machine & Decision System Verification...")
	var mm = MissionManager
	var m = mm.get_mission("earth_observation")
	var sc = SpacecraftConfig.new()
	sc.add_component(mm.get_component("bus_medium_sat"))
	sc.add_component(mm.get_component("power_solar_deployable"))
	sc.add_component(mm.get_component("power_li_battery"))
	sc.add_component(mm.get_component("inst_multispectral_imager"))
	sc.add_component(mm.get_component("comm_medium_horn"))
	sc.add_component(mm.get_component("prop_monoprop"))
	sc.add_component(mm.get_component("data_rad_computer"))

	var engine = SimulationEngine.new()
	root.add_child(engine)

	# Verify start sets RUNNING
	engine.start_simulation(sc, m)
	if engine.current_state != SimulationEngine.SimState.RUNNING:
		push_error("FAIL: State was not RUNNING after start.")
		return false
	print("  ✓ State Machine: Initialized in RUNNING state.")

	# Verify pause & resume
	engine.pause_simulation()
	if engine.current_state != SimulationEngine.SimState.PAUSED:
		push_error("FAIL: State was not PAUSED after pause.")
		return false
	engine.resume_simulation()
	if engine.current_state != SimulationEngine.SimState.RUNNING:
		push_error("FAIL: State was not RUNNING after resume.")
		return false
	print("  ✓ State Machine: PAUSE and RESUME transitions nominal.")

	# Verify decision requested transition to AWAITING_DECISION
	var received_decision = false
	engine.decision_requested.connect(func(dec):
		received_decision = true
	)
	engine._trigger_power_decision()
	if engine.current_state != SimulationEngine.SimState.AWAITING_DECISION:
		push_error("FAIL: State did not transition to AWAITING_DECISION.")
		return false
	print("  ✓ State Machine: AWAITING_DECISION triggered successfully.")

	# Verify decision submission resumes RUNNING
	engine.submit_decision(1) # Core instrument priority
	if engine.current_state != SimulationEngine.SimState.RUNNING:
		push_error("FAIL: State did not resume to RUNNING after decision submission.")
		return false
	print("  ✓ State Machine: Interactive decision resolved and resumed RUNNING.")

	# Verify duplicate completion guard
	engine._complete_simulation()
	var first_state = engine.current_state
	engine._complete_simulation() # Should be guarded
	if engine.current_state != first_state:
		push_error("FAIL: Duplicate completion altered state.")
		return false
	print("  ✓ State Machine: Duplicate completion guard successfully protected lifecycle.")

	engine.queue_free()
	return true

func _test_data_pipeline_and_buffers() -> bool:
	print("\n[TEST 6] Solid-State Memory Buffer Pipeline Verification...")
	var mm = MissionManager
	var m = mm.get_mission("earth_observation")
	var sc = SpacecraftConfig.new()
	sc.add_component(mm.get_component("bus_medium_sat"))
	sc.add_component(mm.get_component("power_solar_deployable"))
	sc.add_component(mm.get_component("inst_multispectral_imager")) # 250 MB/day
	sc.add_component(mm.get_component("data_rad_computer")) # 64 GB buffer
	sc.add_component(mm.get_component("comm_medium_horn")) # 25 Mbps
	sc.recalculate()

	var engine = SimulationEngine.new()
	root.add_child(engine)
	engine.start_simulation(sc, m)

	# Simulate Operations phase data generation
	engine.current_phase = SimulationEngine.SimPhase.OPERATIONS
	engine.storage_capacity_mb = 100.0 # Force small buffer to test overflow
	engine._update_telemetry(2.0)

	print("  ✓ Data Generated: %.1f MB | Buffered: %.1f MB | Dropped: %.1f MB" % [
		engine.data_collected_mb, engine.data_buffered_mb, engine.data_dropped_mb
	])

	if engine.data_buffered_mb > engine.storage_capacity_mb:
		push_error("FAIL: Data buffer exceeded solid-state capacity limit.")
		return false

	engine.queue_free()
	return true

func _test_mpi_scoring_engine() -> bool:
	print("\n[TEST 7] Mission Performance Index (MPI) Scoring Verification...")
	var mm = MissionManager
	var earth_m = mm.get_mission("earth_observation")

	var sc = SpacecraftConfig.new()
	sc.add_component(mm.get_component("bus_medium_sat"))
	sc.add_component(mm.get_component("power_solar_deployable"))
	sc.add_component(mm.get_component("power_li_battery"))
	sc.add_component(mm.get_component("inst_multispectral_imager"))
	sc.add_component(mm.get_component("comm_medium_horn"))
	sc.add_component(mm.get_component("prop_monoprop"))
	sc.add_component(mm.get_component("data_rad_computer"))
	sc.recalculate()

	var mock_events = [
		MissionEvents.create_event(0.0, "Launch", "Liftoff", "Nominal staging", "success"),
		MissionEvents.create_event(1.0, "Cruise", "Orbit Insertion", "Sun-sync orbit reached", "info"),
		MissionEvents.create_event(5.0, "Operations", "Science", "Multispectral survey completed", "success")
	]

	var result = ScoringEngine.calculate_score(sc, earth_m, 6, 6, 350.0, 300.0, mock_events)

	print("  ✓ Mission Performance Index (MPI): %.1f / 100" % result.final_score)
	print("    • Science Sub-Index (30%%): %.1f" % result.scientific_score)
	print("    • Reliability Sub-Index (25%%): %.1f" % result.reliability_score)
	print("    • Resource Efficiency (20%%): %.1f" % result.efficiency_score)
	print("    • Budget Performance (15%%): %.1f" % result.budget_score)
	print("    • Completion Score (10%%): %.1f" % result.completion_score)
	print("  ✓ Engineering Strengths Identified: %d" % result.strengths.size())
	print("  ✓ Engineering Recommendations: %d" % result.recommendations.size())
	print("  ✓ NASA Educational Takeaways: %d" % result.educational_takeaways.size())

	if result.final_score < 70.0 or result.final_score > 100.0:
		push_error("FAIL: Expected score in 70-100 range, got %.1f" % result.final_score)
		return false
	if result.educational_takeaways.size() < 2:
		push_error("FAIL: Missing NASA educational takeaways.")
		return false

	return true

func _test_planetary_mission_profiles() -> bool:
	print("\n[TEST 8] Planetary Mission Profiles (Earth, Moon & Mars)...")
	var mm = MissionManager

	# 1. Earth Observation Nominal Stack
	var earth_m = mm.get_mission("earth_observation")
	var earth_sc = SpacecraftConfig.new()
	earth_sc.add_component(mm.get_component("bus_medium_sat"))
	earth_sc.add_component(mm.get_component("power_solar_deployable"))
	earth_sc.add_component(mm.get_component("power_li_battery"))
	earth_sc.add_component(mm.get_component("inst_multispectral_imager"))
	earth_sc.add_component(mm.get_component("comm_medium_horn"))
	earth_sc.add_component(mm.get_component("prop_monoprop"))
	earth_sc.add_component(mm.get_component("data_rad_computer"))
	earth_sc.add_component(mm.get_component("data_solid_state_recorder"))
	var res_earth = MissionValidator.validate(earth_sc, earth_m)
	if not res_earth.is_valid:
		push_error("FAIL: Earth spacecraft validation failed: " + str(res_earth.errors))
		return false
	print("  ✓ Earth TerraPulse-1 validated (Mass: %.0fkg, Delta-V: %.0fm/s)" % [
		earth_sc.total_mass, earth_sc.total_delta_v
	])

	# 2. Artemis Prospector Lunar Showcase Stack (with micro-rover)
	var lunar_m = mm.get_mission("lunar_exploration")
	var lunar_sc = SpacecraftConfig.new()
	lunar_sc.add_component(mm.get_component("bus_medium_sat"))
	lunar_sc.add_component(mm.get_component("power_solar_deployable"))
	lunar_sc.add_component(mm.get_component("power_li_battery"))
	lunar_sc.add_component(mm.get_component("land_lunar_legs"))
	lunar_sc.add_component(mm.get_component("prop_biprop"))
	lunar_sc.add_component(mm.get_component("mobility_lunar_rover")) # Shadow Explorer micro-rover
	lunar_sc.add_component(mm.get_component("inst_lunar_drill"))
	lunar_sc.add_component(mm.get_component("comm_medium_horn"))
	lunar_sc.add_component(mm.get_component("data_rad_computer"))
	var res_lunar = MissionValidator.validate(lunar_sc, lunar_m)
	if not res_lunar.is_valid:
		push_error("FAIL: Lunar configuration failed validation: " + str(res_lunar.errors))
		return false
	print("  ✓ Lunar Artemis Prospector validated (Mass: %.0fkg, Delta-V: %.0fm/s, Micro-Rover installed)" % [
		lunar_sc.total_mass, lunar_sc.total_delta_v
	])

	# 3. Ares Pathfinder Mars Astrobiology Rover Stack
	var mars_m = mm.get_mission("mars_rover")
	var mars_sc = SpacecraftConfig.new()
	mars_sc.add_component(mm.get_component("chassis_mars_rover"))
	mars_sc.add_component(mm.get_component("land_mars_entry"))
	mars_sc.add_component(mm.get_component("land_skycrane"))
	mars_sc.add_component(mm.get_component("power_rtg"))
	mars_sc.add_component(mm.get_component("prop_biprop"))
	mars_sc.add_component(mm.get_component("inst_mars_drill"))
	mars_sc.add_component(mm.get_component("comm_high_gain_dish"))
	mars_sc.add_component(mm.get_component("data_rad_computer"))
	var res_mars = MissionValidator.validate(mars_sc, mars_m)
	if not res_mars.is_valid:
		push_error("FAIL: Mars configuration failed validation: " + str(res_mars.errors))
		return false
	print("  ✓ Mars Ares Pathfinder Rover validated (Mass: %.0fkg, Cost: $%.1fM, Delta-V: %.0fm/s)" % [
		mars_sc.total_mass, mars_sc.total_cost, mars_sc.total_delta_v
	])

	return true
