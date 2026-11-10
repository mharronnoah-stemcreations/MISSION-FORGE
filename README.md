# MISSIONFORGE 🚀
### 3D Educational Space Mission Design & Systems Engineering Simulator

> **Tagline:** *Design. Launch. Survive. Discover.*  
> **Target Event:** NASA Space Apps Challenge 2026  
> **Engine:** Godot 4.x (Forward+ / Jolt Physics)  
> **Primary Language:** GDScript  

---

## 1. Executive Summary

**MISSIONFORGE** is an interactive 3D educational aerospace systems engineering simulation game. Players step into the role of a NASA Mission Director tasked with designing, validating, launching, and managing complex space exploration missions.

Spacecraft engineering is fundamentally an exercise in interconnected trade-offs:
- Adding scientific sensors increases mission discovery value, but raises **mass**, **power consumption**, **data generation**, and **costs**.
- Deep-space destinations like Mars drastically reduce available solar irradiance (\(1/r^2\) drop) and introduce 4-to-20 minute communication light-delays, necessitating nuclear RTGs, high-gain parabolic reflectors, and autonomous landing architectures.
- Low Earth Orbit (LEO) satellites experience 35-minute orbital eclipses every 98 minutes, requiring battery storage sizing and drag-makeup propulsion.
- Lunar landers have no atmosphere to brake against, demanding dedicated high-impulse chemical descent engines and touchdown landing gear.

MISSIONFORGE unites these concepts into an intuitive, visually stunning 3D simulation where engineering choices directly dictate mission success or failure.

---

## 2. Mission Scenarios

All three scenarios operate on a unified, deterministic systems simulation engine:

| Scenario | Destination | Mission Concept | Primary Challenge | Target Duration |
|---|---|---|---|---|
| **TerraPulse-1** | **Earth (LEO)** | Global remote-sensing sentinel in 705 km Sun-synchronous orbit | Orbital eclipse power cycles & massive multispectral data downlink rates | 1095 Days (3 yrs) |
| **Artemis Prospector** | **Moon** | Polar robotic lander touching down on Shackleton Crater rim | 1.7 km/s vacuum landing delta-v, cryogenic permanently shadowed regions, water ice coring | 180 Days |
| **Ares Pathfinder** | **Mars** | 6-wheeled robotic astrobiology laboratory rover to Jezero Crater | "Seven Minutes of Terror" hypersonic entry (EDL), Sky Crane rocket descent, solar dust storms | 687 Days (1 Martian yr) |

---

## 3. Core Gameplay Loop

```
[1. Mission Briefing] ➔ [2. Spacecraft Designer] ➔ [3. Validation Engine] ➔ [4. 3D Simulation] ➔ [5. Evaluation Report]
```

1. **Mission Briefing:** Review target destination parameters, launch vehicle mass caps, budget allocations, telemetry requirements, and authentic NASA science background.
2. **Spacecraft Designer:** Assemble a custom spacecraft in an interactive 3D viewport. Select components across 7 aerospace subsystems (Structure, Power, Instruments, Communications, Propulsion, Landing, Data). Watch the 3D vehicle model adapt dynamically in real-time.
3. **Validation Engine:** Real-time checking against real-world engineering constraints:
   - Launch vehicle payload mass margins
   - Electrical power budget (generation vs consumption)
   - Fiscal budget ceiling
   - Mandatory destination systems (e.g. Heat shield + Sky Crane for Mars, Landing legs for Moon)
   - Telemetry link margin for planetary distance
4. **3D Mission Control Simulation:** Watch the spacecraft traverse 6 distinct operational flight phases:
   - Phase 1: Launch & Ascent
   - Phase 2: Orbital Insertion / Interplanetary Cruise
   - Phase 3: Destination Arrival & Descent / Touchdown
   - Phase 4: Scientific Operations & Sensor Activation
   - Phase 5: Earth Data Downlink (Deep Space Network)
   - Phase 6: Mission Evaluation Wrap-up
5. **Mission Report & Engineering Evaluation:** Transparent multi-criteria score breakdown with root-cause engineering debriefs explaining *why* decisions worked, subsystem bottlenecks, and future recommendations.

---

## 4. Transparent Scoring Formula

In accordance with PRD Section 15.5, final scores are computed transparently on a 0–100 scale:

\[
\text{Final Score } (S) = 0.30 A + 0.25 R + 0.20 E + 0.15 B + 0.10 C
\]

Where:
- **\(A\) — Scientific Achievement (30%):** Data collected and successfully downlinked vs mission discovery target.
- **\(R\) — Mission Reliability (25%):** Component reliability product and in-flight anomaly penalties.
- **\(E\) — Resource Efficiency (20%):** Optimal mass fraction utilization and electrical power margins.
- **\(B\) — Budget Performance (15%):** Science return per dollar and cost conservation.
- **\(C\) — Mission Completion (10%):** Operational flight phases successfully completed.

---

## 5. Software Architecture

```text
mission-forge/
├── project.godot                     # Godot 4.7 engine configuration & autoloads
├── data/
│   ├── components/
│   │   └── components.json           # 24 authentic NASA-inspired components
│   └── missions/
│       ├── earth_observation.json    # Earth Sentinel scenario configuration
│       ├── lunar_exploration.json    # Artemis Prospector scenario configuration
│       └── mars_rover.json           # Ares Pathfinder scenario configuration
├── scenes/
│   ├── main/
│   │   └── main_menu.tscn            # 3D interactive main menu & records viewer
│   ├── missions/
│   │   ├── mission_selection.tscn    # 3D planetary destination selector
│   │   └── briefing.tscn             # Detailed NASA pre-flight directive
│   ├── spacecraft/
│   │   └── spacecraft_designer.tscn  # 3D assembly studio & resource dashboard
│   ├── simulation/
│   │   └── simulation_scene.tscn     # 3D Mission Control & telemetry stream
│   └── ui/
│       └── mission_report.tscn       # Post-flight evaluation & recommendations
├── scripts/
│   ├── managers/
│   │   ├── game_manager.gd           # State machine & local flight records
│   │   ├── mission_manager.gd        # Dynamic JSON loader & catalog query
│   │   ├── scene_manager.gd          # Transition coordinator with visual fades
│   │   └── audio_manager.gd          # Procedural sound synthesizer (zero asset deps)
│   ├── spacecraft/
│   │   ├── space_component.gd        # Component data model & deserializer
│   │   ├── mission_config.gd         # Mission specification resource
│   │   ├── spacecraft_config.gd      # Spacecraft configuration & inventory
│   │   └── resource_calculator.gd    # Real-time physical & electrical calculator
│   ├── validation/
│   │   ├── validation_result.gd      # Structured validation outcome
│   │   └── mission_validator.gd      # Aerospace constraint validation engine
│   ├── simulation/
│   │   ├── simulation_engine.gd      # 6-phase deterministic simulation engine
│   │   ├── mission_events.gd         # Event factory & severity classifier
│   │   └── mission_result.gd         # Debriefing telemetry dataset
│   ├── scoring/
│   │   └── scoring_engine.gd         # Multi-criteria scoring & recommendations
│   ├── visuals/
│   │   ├── planet_visualizer.gd      # Procedural 3D Earth, Moon, and Mars shaders
│   │   └── spacecraft_preview.gd     # Modular 3D spacecraft mesh assembler
│   └── ui/
│       ├── ui_theme.gd               # NASA Mission Control design system
│       ├── main_menu.gd              # Main menu controller
│       ├── mission_selection.gd      # Destination selector controller
│       ├── briefing.gd               # Briefing screen controller
│       ├── designer_ui.gd            # Assembly studio controller
│       ├── simulation_scene.gd       # Simulation HUD controller
│       └── mission_report.gd         # Evaluation report controller
└── test/
    └── scripts/test_missionforge.gd  # Automated unit & integration test suite
```

---

## 6. NASA Data & Educational Attributions

MISSIONFORGE incorporates authentic mission design concepts and data models referenced from official NASA programs:

1. **Earth Science Division & Landsat Program (NASA/USGS):**
   - Sun-synchronous orbit geometry (705 km, 98.2° inclination, 16-day repeat cycle).
   - Operational Land Imager (OLI-2) multispectral pushbroom sensor.
   - Synthetic Aperture Radar (SAR) remote-sensing principles (NISAR heritage).
   - Reference: https://science.nasa.gov/earth-science/

2. **Artemis Program & Lunar Exploration (NASA GSFC/JPL):**
   - South Pole Shackleton Crater permanently shadowed regions (PSRs).
   - Water ice prospecting and In-Situ Resource Utilization (ISRU) coring drills (TRIDENT/VIPER heritage).
   - Passive Seismic Experiment & Lunar Heat Flow probes.
   - Reference: https://www.nasa.gov/artemis-program/

3. **Mars 2020 & Curiosity Rover Missions (NASA JPL):**
   - Entry, Descent, and Landing (EDL) sequence: Hypersonic PICA aeroshell heat shield, supersonic disk-gap-band parachute, and terminal Sky Crane flyaway.
   - Multi-Mission Radioisotope Thermoelectric Generator (MMRTG) Plutonium-238 power decay characteristics.
   - Mastcam-Z multispectral stereo cameras and SuperCam laser-induced breakdown spectroscopy (LIBS).
   - Deep Space Network (DSN) ground tracking facilities at Goldstone, Madrid, and Canberra.
   - Reference: https://mars.nasa.gov/mars2020/

---

## 7. Running & Testing

### Running the Game in Godot 4:
Open the project directory in Godot Engine 4.x or launch directly from the command line:
```bash
godot --path .
```

### Running the Headless Test Suite:
MISSIONFORGE includes a built-in automated test suite verifying components, resource calculations, validation rules, simulation state machine, and scoring formulas:
```bash
godot --headless -s res://scripts/test_missionforge.gd --path .
```
Expected output:
```text
==================================================
🛰️  MISSIONFORGE AUTOMATED TEST SUITE INITIALIZED
==================================================
[TEST 1] Data Loading & Schema Verification...  [PASSED]
[TEST 2] Resource Calculator Verification...    [PASSED]
[TEST 3] Validation Engine Constraints...       [PASSED]
[TEST 4] Simulation & Scoring Engine...         [PASSED]
[TEST 5] Lunar & Mars Scenario Validation...    [PASSED]
==================================================
🎉 ALL MISSIONFORGE AUTOMATED TESTS PASSED (100% NOMINAL)
==================================================
```

---

*Designed and engineered for the NASA Space Apps Challenge 2026.*
