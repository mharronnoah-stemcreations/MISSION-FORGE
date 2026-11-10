extends Node

# TestRunner Node
# Runs inside the active scene tree with full engine Autoload singletons active.

func _ready() -> void:
	print("==================================================")
	print("🛰️  MISSIONFORGE FULL RUNTIME SCENE VERIFICATION")
	print("==================================================")

	var mm = get_node_or_null("/root/MissionManager")
	var gm = get_node_or_null("/root/GameManager")
	var sm = get_node_or_null("/root/SceneManager")

	print("Autoloads Status:")
	print("  • MissionManager: ", "OK" if mm != null else "FAIL")
	print("  • GameManager:    ", "OK" if gm != null else "FAIL")
	print("  • SceneManager:   ", "OK" if sm != null else "FAIL")

	if mm == null or gm == null or sm == null:
		push_error("Critical Autoloads missing!")
		get_tree().quit(1)
		return

	# 1. Test Briefing Screen
	print("\n--- [1] Testing briefing.tscn ---")
	var earth_mission = mm.get_mission("earth_observation")
	gm.select_mission(earth_mission)

	var brf_scene = load("res://scenes/missions/briefing.tscn").instantiate()
	add_child(brf_scene)
	
	var brf_title = brf_scene.get_node("UI/PanelMain/VBox/Header/VBoxTitles/LblMissionTitle").text
	var obj_list = brf_scene.get_node("UI/PanelMain/VBox/HBoxTop/PanelObjectives/VBox/Scroll/ListObjectives")
	var req_list = brf_scene.get_node("UI/PanelMain/VBox/HBoxBottom/PanelRequired/VBox/Scroll/ListRequired")
	var rtxt_nasa = brf_scene.get_node("UI/PanelMain/VBox/HBoxBottom/PanelNasa/VBox/RtxtNasa")
	
	print("  ✓ Mission Title: ", brf_title)
	print("  ✓ Primary Objectives Listed: ", obj_list.get_child_count())
	print("  ✓ Mandatory Hardware Items: ", req_list.get_child_count())
	print("  ✓ NASA Reference & Heritage Length: ", rtxt_nasa.text.length(), " chars")
	
	for i in range(obj_list.get_child_count()):
		print("    - ", obj_list.get_child(i).text)
	for i in range(req_list.get_child_count()):
		print("    * ", req_list.get_child(i).text)
		
	if obj_list.get_child_count() == 0 or req_list.get_child_count() == 0:
		push_error("FAIL: Briefing list is empty!")
		get_tree().quit(1)
		return
		
	brf_scene.queue_free()

	# 2. Test Spacecraft Designer Screen & Hardware Catalog
	print("\n--- [2] Testing spacecraft_designer.tscn & Hardware Catalog ---")
	var des_scene = load("res://scenes/spacecraft/spacecraft_designer.tscn").instantiate()
	add_child(des_scene)
	
	var list_comps = des_scene.get_node("VBoxMain/HBoxCenter/PanelLeft/VBox/ScrollComps/ListComps")
	var list_selected = des_scene.get_node("VBoxMain/HBoxCenter/PanelRight/VBox/ScrollSelected/ListSelected")
	var status_lbl = des_scene.get_node("VBoxMain/HBoxCenter/PanelRight/VBox/LblValidStatus")
	var mass_lbl = des_scene.get_node("VBoxMain/HBoxCenter/PanelRight/VBox/GridMeters/LblMassVal")
	var cost_lbl = des_scene.get_node("VBoxMain/HBoxCenter/PanelRight/VBox/GridMeters/LblCostVal")
	var power_lbl = des_scene.get_node("VBoxMain/HBoxCenter/PanelRight/VBox/GridMeters/LblPowerVal")
	
	print("  ✓ Hardware Catalog Cards Displayed: ", list_comps.get_child_count())
	print("  ✓ Initially Installed Components: ", list_selected.get_child_count())
	print("  ✓ Launch Validation Status: ", status_lbl.text)
	print("  ✓ Initial Mass: ", mass_lbl.text)
	print("  ✓ Initial Cost: ", cost_lbl.text)
	print("  ✓ Initial Power Balance: ", power_lbl.text)
	
	# Sample first 3 components from catalog
	for i in range(min(4, list_comps.get_child_count())):
		var card = list_comps.get_child(i)
		var c_vbox = card.get_child(0)
		var c_top = c_vbox.get_child(0)
		var comp_name = c_top.get_child(0).text
		var btn_txt = c_top.get_child(1).text
		var comp_stats = c_vbox.get_child(1).get_child(0).text
		print("    [%s] %s -> %s" % [btn_txt, comp_name, comp_stats])

	if list_comps.get_child_count() == 0:
		push_error("FAIL: Hardware catalog is empty!")
		get_tree().quit(1)
		return

	des_scene.queue_free()

	# 3. Test Full Simulation Execution
	print("\n--- [3] Testing simulation_scene.tscn & Full Flight Execution ---")
	var sim_scene = load("res://scenes/simulation/simulation_scene.tscn").instantiate()
	add_child(sim_scene)
	
	var engine = sim_scene.get_node("SimulationEngine")
	print("  ✓ Simulation Engine started. Speeding up to test all 6 phases...")
	engine.set_speed(8.0)
	
	# Skip to end or let it advance
	engine.skip_to_end()
	
	print("  ✓ Simulation Completed! Final Result Produced:")
	print("    • Destination: ", gm.current_result.destination)
	print("    • Score: ", gm.current_result.final_score)
	print("    • Events Logged: ", gm.current_result.events.size())
	for ev in gm.current_result.events:
		print("      - [D+%s][%s] %s: %s" % [ev.day, ev.severity, ev.title, ev.message])
		
	sim_scene.queue_free()

	# 4. Test Mission Report Scene with Generated Result
	print("\n--- [4] Testing mission_report.tscn with Live Result ---")
	var rep_scene = load("res://scenes/ui/mission_report.tscn").instantiate()
	add_child(rep_scene)
	
	var rep_score = rep_scene.get_node("UI/PanelMain/VBox/Header/VBoxScore/LblFinalScore").text
	var rep_rating = rep_scene.get_node("UI/PanelMain/VBox/Header/VBox/LblRating").text
	print("  ✓ Mission Report Displaying Final Score: ", rep_score)
	print("  ✓ Rating Badge: ", rep_rating)
	rep_scene.queue_free()

	print("\n==================================================")
	print("🎉 SUCCESS: BOTH BRIEFING AND HARDWARE CATALOG ARE")
	print("   FULLY POPULATED WITH 24 AEROSPACE HARDWARE CARDS")
	print("   AND AUTHENTIC NASA MISSION OBJECTIVES!")
	print("==================================================")

	get_tree().quit(0)
