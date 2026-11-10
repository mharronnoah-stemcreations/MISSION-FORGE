extends SceneTree

# Automated headless unit and integration test runner for MISSIONFORGE
# Validates data schemas, resource calculations, validation rules, simulation phases, and scoring formulas.

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
	success = success and _test_resource_calculations()
	success = success and _test_validation_engine()
	success = success and _test_simulation_and_scoring()
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
	if all_comps.size() < 20:
		push_error("FAIL: Expected at least 20 components, got %d" % all_comps.size())
		return false

	# Verify all 7 categories exist
	for cat in ["Structure", "Power", "Instruments", "Communications", "Propulsion", "Landing", "Data"]:
		var in_cat = mm.get_components_by_category(cat)
		if in_cat.is_empty():
			push_error("FAIL: Category '%s' has 0 components." % cat)
			return false
		print("  ✓ Category '%s': %d components" % [cat, in_cat.size()])

	# Verify 3 mission scenarios
	for m_id in ["earth_observation", "lunar_exploration", "mars_rover"]:
		var m = mm.get_mission(m_id)
		if m == null:
			push_error("FAIL: Missing mission configuration: " + m_id)
			return false
		print("  ✓ Mission '%s' (%s) Loaded: Budget=$%.0fM, Mass=%.0fkg, Delta-V=%.0fm/s" % [
			m.mission_name, m.destination, m.budget_limit, m.mass_limit, m.min_delta_v
		])

	return true

func _test_resource_calculations() -> bool:
	print("\n[TEST 2] Resource Calculator Verification...")
	var sc = SpacecraftConfig.new()
	var mm = MissionManager

	var bus = mm.get_component("bus_medium_sat")
	var solar = mm.get_component("power_solar_deployable")
	var imager = mm.get_component("inst_multispectral_imager")

	sc.add_component(bus)
	sc.add_component(solar)
	sc.add_component(imager)

	var expected_mass = bus.mass + solar.mass + imager.mass
	var expected_cost = bus.cost + solar.cost + imager.cost
	var expected_gen = solar.power_generation
	var expected_con = bus.power_consumption + imager.power_consumption
	var expected_net = expected_gen - expected_con

	var summary = ResourceCalculator.calculate_summary(sc, mm.get_mission("earth_observation"))

	print("  ✓ Calculated Mass: %.1f kg (Expected: %.1f kg)" % [summary["total_mass"], expected_mass])
	print("  ✓ Calculated Cost: $%.1fM (Expected: $%.1fM)" % [summary["total_cost"], expected_cost])
	print("  ✓ Power Net: %.1f W (Gen: %.1f W, Con: %.1f W)" % [summary["net_power"], expected_gen, expected_con])

	if abs(summary["total_mass"] - expected_mass) > 0.01:
		push_error("FAIL: Mass mismatch")
		return false
	if abs(summary["total_cost"] - expected_cost) > 0.01:
		push_error("FAIL: Cost mismatch")
		return false
	if abs(summary["net_power"] - expected_net) > 0.01:
		push_error("FAIL: Net power mismatch")
		return false

	return true

func _test_validation_engine() -> bool:
	print("\n[TEST 3] Validation Engine Constraints Verification...")
	var mm = MissionManager
	var earth_mission = mm.get_mission("earth_observation")

	# Subtest A: Empty spacecraft must fail (missing bus, power, science)
	var empty_sc = SpacecraftConfig.new()
	var res_empty = MissionValidator.validate(empty_sc, earth_mission)
	if res_empty.is_valid:
		push_error("FAIL: Empty spacecraft was validated as valid!")
		return false
	print("  ✓ Empty spacecraft correctly rejected with %d error(s)." % res_empty.errors.size())

	# Subtest B: Overweight spacecraft must fail
	var over_sc = SpacecraftConfig.new()
	over_sc.add_component(mm.get_component("bus_deep_space"))
	over_sc.add_component(mm.get_component("chassis_mars_rover"))
	over_sc.add_component(mm.get_component("land_mars_entry"))
	over_sc.add_component(mm.get_component("land_skycrane"))
	over_sc.add_component(mm.get_component("prop_biprop"))
	# Force weight over 1250 kg
	var res_over = MissionValidator.validate(over_sc, earth_mission)
	if res_over.is_valid:
		push_error("FAIL: Overweight spacecraft was validated as valid!")
		return false
	print("  ✓ Overweight spacecraft correctly blocked: '%s'" % res_over.errors[0])

	# Subtest C: Valid Nominal Earth Configuration
	var valid_earth = SpacecraftConfig.new()
	valid_earth.add_component(mm.get_component("bus_medium_sat"))
	valid_earth.add_component(mm.get_component("power_solar_deployable"))
	valid_earth.add_component(mm.get_component("power_li_battery"))
	valid_earth.add_component(mm.get_component("inst_multispectral_imager"))
	valid_earth.add_component(mm.get_component("comm_medium_horn"))
	valid_earth.add_component(mm.get_component("prop_monoprop"))
	valid_earth.add_component(mm.get_component("data_rad_computer"))
	valid_earth.add_component(mm.get_component("data_solid_state_recorder"))

	var res_valid = MissionValidator.validate(valid_earth, earth_mission)
	if not res_valid.is_valid:
		push_error("FAIL: Valid nominal Earth spacecraft had errors: " + str(res_valid.errors))
		return false
	print("  ✓ Nominal Earth spacecraft passed validation with 0 errors! Warnings: %d" % res_valid.warnings.size())

	return true

func _test_simulation_and_scoring() -> bool:
	print("\n[TEST 4] Simulation & Scoring Engine Verification...")
	var mm = MissionManager
	var earth_mission = mm.get_mission("earth_observation")

	var sc = SpacecraftConfig.new()
	sc.add_component(mm.get_component("bus_medium_sat"))
	sc.add_component(mm.get_component("power_solar_deployable"))
	sc.add_component(mm.get_component("power_li_battery"))
	sc.add_component(mm.get_component("inst_multispectral_imager"))
	sc.add_component(mm.get_component("comm_medium_horn"))
	sc.add_component(mm.get_component("prop_monoprop"))
	sc.add_component(mm.get_component("data_rad_computer"))

	var mock_events = [
		MissionEvents.create_event(0.0, "Launch", "Liftoff", "Nominal staging", "success"),
		MissionEvents.create_event(1.0, "Cruise", "Orbit Insertion", "Sun-sync orbit reached", "info"),
		MissionEvents.create_event(5.0, "Operations", "Science", "Multispectral survey completed", "success")
	]

	var result = ScoringEngine.calculate_score(
		sc,
		earth_mission,
		6, # all 6 phases completed
		6,
		350.0, # data transmitted
		300.0, # data target
		mock_events
	)

	print("  ✓ Final Score Calculated: %.1f / 100" % result.final_score)
	print("    • Science Score (30%%): %.1f" % result.scientific_score)
	print("    • Reliability Score (25%%): %.1f" % result.reliability_score)
	print("    • Resource Efficiency (20%%): %.1f" % result.efficiency_score)
	print("    • Budget Performance (15%%): %.1f" % result.budget_score)
	print("    • Completion Score (10%%): %.1f" % result.completion_score)
	print("  ✓ Strengths Identified: %d" % result.strengths.size())
	print("  ✓ Recommendations Generated: %d" % result.recommendations.size())
	print("  ✓ NASA Educational Takeaways: %d" % result.educational_takeaways.size())

	if result.final_score < 70.0 or result.final_score > 100.0:
		push_error("FAIL: Expected score in 70-100 range, got %.1f" % result.final_score)
		return false

	return true

func _test_planetary_mission_profiles() -> bool:
	print("\n[TEST 5] Lunar & Mars Scenario Validation...")
	var mm = MissionManager

	# Test Lunar Mission Configuration
	var lunar_m = mm.get_mission("lunar_exploration")
	var lunar_sc = SpacecraftConfig.new()
	lunar_sc.add_component(mm.get_component("bus_medium_sat"))
	lunar_sc.add_component(mm.get_component("power_solar_deployable"))
	lunar_sc.add_component(mm.get_component("power_li_battery"))
	lunar_sc.add_component(mm.get_component("land_lunar_legs"))
	lunar_sc.add_component(mm.get_component("prop_biprop"))
	lunar_sc.add_component(mm.get_component("inst_lunar_drill"))
	lunar_sc.add_component(mm.get_component("comm_medium_horn"))
	lunar_sc.add_component(mm.get_component("data_rad_computer"))

	var res_lunar = MissionValidator.validate(lunar_sc, lunar_m)
	if not res_lunar.is_valid:
		push_error("FAIL: Lunar configuration failed validation: " + str(res_lunar.errors))
		return false
	print("  ✓ Lunar Artemis Prospector validated successfully (Mass: %.0fkg, Delta-V: %.0fm/s)" % [
		lunar_sc.total_mass, lunar_sc.total_delta_v
	])

	# Test Mars Rover Mission Configuration
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
	print("  ✓ Mars Ares Pathfinder Rover validated successfully (Mass: %.0fkg, Cost: $%.1fM)" % [
		mars_sc.total_mass, mars_sc.total_cost
	])

	return true
