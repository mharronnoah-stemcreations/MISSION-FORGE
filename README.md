# MISSIONFORGE 🚀
### 3D Educational Space Mission Design & Systems Engineering Simulator

> **Event:** NASA Space Apps Challenge 2026 — *Space Mission Design Game*  
> **Team:** Developed by Team J.A.I.M.E.  
> **Tagline:** *Design. Launch. Survive. Discover.*  
> **Engine:** Godot 4.7+ (Forward+ Desktop / Mobile Compatible)  
> **Primary Technology:** GDScript 2.0 with Procedural 3D Visuals & Synthesized Audio  

---

## ⚡ Quick Start & How to Play

### Option 1: Direct Play (Windows Standalone)
1. Download or extract `MF ver. 1.0.0 (Windows Build).zip` (available in the root repository or under [Releases](https://github.com/mharronnoah-stemcreations/MISSION-FORGE/releases)).
2. Extract the archive contents into a folder.
3. Launch `MISSION_FORGE.exe` to start the game directly. No engine installation required!

### Option 2: Running from Source (Godot Developers)
1. Install **Godot Engine 4.3+ (.NET / C# Edition)** and **.NET 8.0 SDK**.
2. Clone this repository:
   ```bash
   git clone https://github.com/mharronnoah-stemcreations/MISSION-FORGE.git
   ```
3. Open Godot, click **Import**, and select `project.godot`.
4. Build the project C# solution and click **Run (F5)**.

---

## 1. Executive Summary & Aerospace Philosophy

**MISSIONFORGE** is a scientifically defensible, interactive 3D aerospace systems engineering simulation game built for the **NASA Space Apps Challenge 2026**. Players step into the shoes of a NASA Flight Director and Chief Systems Engineer to design, validate, launch, and actively command interplanetary robotic missions.

Spacecraft engineering is fundamentally an exercise in interconnected trade-offs:
- Adding scientific payloads increases mission discovery, but demands greater **mass**, **electrical power**, **memory storage**, and **budget**.
- **Rocket Propulsion** is governed by the **Tsiolkovsky Rocket Equation** ($\Delta v = I_{sp} \cdot g_0 \cdot \ln(m_0 / m_f)$): every kilogram of payload demands exponential propellant mass.
- Deep space destinations like Mars reduce solar flux by 57% via the inverse-square law (\(1/r^2\)) and introduce 4-to-20 minute light delays, requiring nuclear Multi-Mission RTGs (MMRTGs), high-gain parabolic Ka-band dishes, and 100% autonomous Entry, Descent, and Landing (EDL).
- Low Earth Orbit (LEO) satellites enter 35-minute orbital eclipses every 98-minute orbit, demanding rechargeable Li-ion energy storage buffers (Wh) and drag-compensation propulsion.
- Lunar south pole landers at Shackleton Crater must survive pitch-black 40 Kelvin (-233°C) Permanently Shadowed Regions (PSRs), demanding throttleable descent engines, touchdown landing gear, and deployable autonomous micro-rovers.

MISSIONFORGE unites authentic aerospace physics, real NASA planetary science datasets, and interactive in-flight mission control decisions into an accessible educational experience.

---

## 2. Real-World Engineering & Scientific Models

### 2.1 Energy Storage (Wh) vs. Power Generation (W)
- **Battery Storage Buffer (`power_li_battery`)**: Accurately models energy storage in Watt-hours (1200 Wh capacity, 350W max charge rate, 500W max discharge rate, 92% charge efficiency, 96% discharge efficiency). Correctly eliminates the misconception of batteries as infinite power generators.
- **Multi-Mission RTG (`power_rtg`)**: Traceable to NASA's *Perseverance* and *Curiosity* rover baseline specifications: **110 W electrical output at Beginning of Life (BOL)**, **45 kg dry mass**, and **2000 W thermal waste heat** to protect avionics from cryogenic freezing.
- **Dual MMRTG Package (`power_dual_rtg`)**: 220W electrical / 4000W thermal for high-power deep-space outer planet missions.
- **Environmental Irradiance Scaling**: Solar panel output dynamically adjusts based on destination distance (Earth 100%, Mars 43%, Moon illuminated rim 86% vs. PSR crater interior 0%).

### 2.2 Tsiolkovsky Rocket Equation & Propulsion Mechanics
Spacecraft velocity change is computed dynamically using the exact rocket equation:
$$\Delta v = I_{sp, eff} \cdot g_0 \cdot \ln\left(\frac{m_{wet}}{m_{dry}}\right)$$
Where:
- $m_{wet} = \text{Total Spacecraft Wet Mass}$ (Structure + Subsystems + Propellant)
- $m_{dry} = m_{wet} - m_{propellant}$ (Total dry mass without propellant)
- $g_0 = 9.80665 \text{ m/s}^2$ (Standard Earth gravitational acceleration)
- $I_{sp, eff} = \frac{\sum (m_{prop, i} \cdot I_{sp, i})}{\sum m_{prop, i}}$ (Weighted composite specific impulse across active thrusters)

Components model realistic mass fractions:
- `prop_monoprop`: 140kg total (30kg dry, 110kg hydrazine, $I_{sp} = 235$s, 400N thrust)
- `prop_biprop`: 480kg total (60kg dry, 420kg bipropellant, $I_{sp} = 325$s, 450N thrust)
- `prop_next_ion`: 170kg total (70kg dry, 100kg Xenon, $I_{sp} = 4190$s, 0.236N thrust)
- `land_lunar_legs`: 350kg total (110kg dry, 240kg descent propellant, $I_{sp} = 315$s, 3000N throttleable thrust)
- `land_skycrane`: 380kg total (120kg dry, 260kg descent propellant, $I_{sp} = 305$s, 3200N hovering thrust)
- `prop_aux_tank`: 280kg total (30kg COPV dry, 250kg auxiliary propellant, $I_{sp} = 325$s)

### 2.3 Solid-State Memory Buffer & Telemetry Downlink Pipeline
- Instruments continuously generate raw science data (MB/day).
- Onboard radiation-hardened solid-state memory recorders (`data_solid_state_recorder` 1 TB SSD, `data_rad_computer` 64 GB) buffer scientific observations when out of line-of-sight of ground stations.
- If memory buffers overflow before a downlink pass, newly collected data is permanently dropped (`data_dropped_mb`), penalizing mission discovery return.
- Downlink passes transfer data to the **NASA Deep Space Network (DSN)** or Near Space Network based on antenna bandwidth (`comms_bandwidth` in Mbps).

### 2.4 Lunar Surface Mobility (`mobility_lunar_rover`)
- Artemis Prospector features the **Autonomous Lunar Micro-Rover (Shadow Explorer)**: a 38 kg 4-wheeled cold-tolerant rover with 350 Wh battery storage and neutron spectrometers.
- Solves the physical impossibility of a stationary rim lander sampling water ice deep in the 4.2 km deep Shackleton Crater interior.

---

## 3. NASA Mission Scenarios & Authoritative Datasets

| Scenario | Destination | NASA Program Baseline | Key Scientific & Environmental Parameters |
|---|---|---|---|
| **TerraPulse-1** | **Earth (LEO)** | NASA Earth Science / Landsat 8-9 & EOS | 705 km Sun-synchronous orbit, 98.2° inclination, 98.8 min orbital period, 35 min eclipse, 16-day repeat ground track |
| **Artemis Prospector** | **Moon (South Pole)** | NASA Artemis & Lunar Discovery (LRO/ShadowCam) | Shackleton Crater (89.9°S, 21 km dia, 4.2 km depth), 40 Kelvin cold trap, 1.5%–5.5% water-ice equivalent by weight, 1.8 km/s landing $\Delta v$ |
| **Ares Pathfinder** | **Mars** | NASA Mars 2020 Perseverance Rover | Jezero Crater Delta (18.38°N, 77.58°E), 20,000 km/h hypersonic atmospheric entry, 14.2 min one-way light delay, 43% solar flux |

### NASA Artemis Lunar Landing Sites
1. **Site Alpha: Connecting Ridge (Peak of Eternal Light)** (89.9°S, 0.0°E): 86% annual solar illumination, 9.2° slope, 92% Earth line-of-sight. High safety, requires deployable micro-rover for PSR exploration.
2. **Site Beta: Shackleton Crater Rim Saddle** (89.7°S, 120.0°W): 68% illumination, 14.5° slope, 81% Earth line-of-sight. Proximity to volatile deposits.
3. **Site Gamma: Permanently Shadowed Crater Interior (PSR Floor)** (89.9°S, 180.0°E): 0% solar illumination, 40 Kelvin (-233°C), 5.5 wt% water ice. Requires RTG/battery power and communications relay.

---

## 4. Interactive In-Flight Decision Systems

Unlike passive viewers, MISSIONFORGE pauses at critical mission junctures and prompts the player for flight director decisions:

1. **Power Management Event (Eclipse / Crater Shadow / Dust Storm)**:
   - *Option A: Power-Shedding Safe Mode* — Sheds non-essential sensors; preserves battery at 100% reserve; pauses science temporarily.
   - *Option B: Core Instrument Priority* — Maintains primary multispectral or spectrometer payload on duty-cycle; moderate battery drain (35% DoD).
   - *Option C: High-Power Survey Override* — Overrides duty-cycling for +30% Science bonus; risks deep battery brownout if battery capacity < 1000 Wh.
2. **Autonomous Operational Hazard (Touchdown / Entry Divert)**:
   - *Moon*: LiDAR detects 22° slope and boulder field -> Divert to Ridge Flat (consumes 80 m/s propellant), deploy Micro-Rover ahead for surface recon, or risk direct slope touchdown.
   - *Mars*: IMU detects supersonic atmospheric shear -> Deploy supersonic parachute 3s early, maintain autonomous radar trigger, or throttle Sky Crane hover (+15m height).
   - *Earth*: Space Command tracks orbital debris conjunction within 380m corridor -> Collision avoidance burn (15 m/s), aerodynamic edge-on orientation, or maintain track.
3. **DSN Telecom & Data Scheduling**:
   - *Option A: Prioritize Raw Spectroscopy* — Maximum science score; consumes 90% of ground pass window.
   - *Option B: Lossless Onboard Compression Pipeline* — Clears memory buffer completely; downlinks 100% of telemetry.
   - *Option C: Buffer to Solid-State Memory* — Postpones downlink to next pass to conserve spacecraft attitude thrusters.

---

## 5. Systems Engineering Validation: Hard vs. Soft Constraints

The validation engine categorizes issues into:
- **Hard Constraints (Blocks Launch)**:
  - Spacecraft lacks a primary structural bus or rover chassis.
  - Launch vehicle capacity exceeded (Total mass > Booster payload limit).
  - Congressional cost ceiling exceeded (Total cost > Mission budget limit).
  - Zero electrical power generation installed.
  - Continuous power deficit with ZERO battery buffer installed.
  - Missing mandatory hardware (e.g. Landing gear for Moon, Heat shield for Mars).
  - Insufficient rocket propulsion ($\Delta v < 70\%$ of trajectory requirement).
  - Zero scientific instruments installed.
  - Zero communications antenna installed.
- **Soft Constraints (Educational Warnings & Actionable Tips)**:
  - Tight mass margin (> 95% of booster limit).
  - Tight budget contingency (< 8% contingency funding remaining).
  - Intermittent power deficit (duty-cycle warning with battery Wh buffer).
  - Low solar irradiance or planetary eclipse warning.
  - Telemetry bandwidth bottleneck below target.
  - Marginal propulsion delta-v ($70\% \le \Delta v < 100\%$).
  - Missing surface mobility micro-rover for Shackleton Crater PSR exploration.

---

## 6. Transparent Scoring: Mission Performance Index (MPI)

The post-flight evaluation calculates the **Mission Performance Index (MPI)** on a 0–100 scale:

$$\text{MPI} = 0.30 \cdot A + 0.25 \cdot R + 0.20 \cdot E + 0.15 \cdot B + 0.10 \cdot C$$

| Sub-Index | Weight | Description |
|---|---|---|
| **Scientific Achievement (\(A\))** | **30%** | Raw science points collected and successfully downlinked to Earth archives vs. mission target. |
| **Subsystem Reliability (\(R\))** | **25%** | Product of component reliability ratings, minus penalties for critical flight anomalies. |
| **Resource Efficiency (\(E\))** | **20%** | Optimal payload mass fraction, rocket delta-v margins, and power/battery sizing. |
| **Budget Performance (\(B\))** | **15%** | Fiscal stewardship; science return per million dollars invested. |
| **Mission Completion (\(C\))** | **10%** | Operational flight phases successfully completed out of 6 phases. |

The resulting **After-Action Report** provides:
- Engineering Strengths identified
- Engineering Weaknesses & Anomalies diagnosed
- Actionable Recommendations for vehicle redesign
- Authentic NASA Educational Takeaways

---

## 7. Software Architecture & State Machine

### 7.1 Finite State Machine (FSM)
The simulation is governed by a 7-state FSM:
`NOT_STARTED` ➔ `READY` ➔ `RUNNING` ➔ `PAUSED` ➔ `AWAITING_DECISION` ➔ `COMPLETED` / `FAILED`.

Guards enforce:
- **Duplicate Completion Guard**: Prevents race conditions or double score evaluations (`_has_completed` guard).
- **Terminal Failure Halt**: When a fatal event occurs (e.g. entry breakup or lunar crash), the state transitions immediately to `FAILED`, stops all advancement, logs root cause, and generates failure debriefing.

### 7.2 Directory Structure
```text
mission-forge/
├── project.godot                     # Godot 4.7 engine configuration & autoloads
├── data/
│   ├── components/components.json    # 27 authentic aerospace components across 7 categories
│   └── missions/                     # 3 NASA mission scenarios with authoritative datasets
├── docs/
│   ├── TECHNICAL_AUDIT.md            # Comprehensive aerospace systems audit
│   └── DEVELOPMENT_LOG.md            # Engineering development & implementation log
├── scenes/
│   ├── main/main_menu.tscn           # Title screen & mission launchpad
│   ├── missions/
│   │   ├── mission_selection.tscn    # 3D planetary scenario selector
│   │   └── briefing.tscn             # NASA flight directive & landing site viewer
│   ├── spacecraft/
│   │   └── spacecraft_designer.tscn  # 3D assembly bay, live meters & validator
│   ├── simulation/
│   │   └── simulation_scene.tscn     # 3D Mission Control HUD, telemetry & decision modal
│   └── ui/
│       └── mission_report.tscn       # Mission Performance Index & After-Action Report
└── scripts/
    ├── autoload/                     # GameManager, MissionManager, SceneManager, AudioManager
    ├── spacecraft/                   # SpaceComponent, MissionConfig, SpacecraftConfig, ResourceCalculator
    ├── validation/                   # MissionValidator, ValidationResult
    ├── simulation/                   # SimulationEngine, MissionEvents, MissionResult
    ├── scoring/                      # ScoringEngine (Mission Performance Index)
    ├── visuals/                      # PlanetVisualizer, SpacecraftPreview (procedural 3D)
    └── test_missionforge.gd          # Headless automated QA test suite (8 test suites)
```

---

## 8. Automated Testing & Verification

MISSIONFORGE contains a headless QA test suite covering all scientific formulas, validation logic, and state transitions.

### Running Headless Tests
To execute the automated test suite without a window or GPU requirement:
```powershell
& "<path_to_godot_console.exe>" --headless -s "res://scripts/test_missionforge.gd" --path "<path_to_mission_forge>"
```

### Test Suite Output (8 Comprehensive Tests):
- `[TEST 1] Data Loading & Schema Verification`: 27 components, 7 categories, 3 missions, NASA landing sites.
- `[TEST 2] Energy Storage & Power Physics`: 1200 Wh battery buffer, 0W battery generation, 110W MMRTG baseline, discharge runtime.
- `[TEST 3] Tsiolkovsky Rocket Equation`: Non-linear mass ratio logarithmic calculation verification.
- `[TEST 4] Hard vs. Soft Validation Constraints`: Empty craft rejection, overweight payload blocking, duty-cycle warnings.
- `[TEST 5] Simulation State Machine & Decisions`: FSM transitions, AWAITING_DECISION modal, duplicate completion protection.
- `[TEST 6] Solid-State Memory Buffer Pipeline`: Science data generation, buffer overflow tracking, DSN downlink.
- `[TEST 7] Mission Performance Index (MPI)`: Weighted scoring formula & After-Action debriefing.
- `[TEST 8] Planetary Mission Profiles`: Full end-to-end nominal validation of Earth, Moon (with micro-rover), and Mars rovers.

---

## 9. NASA Space Apps Challenge 2026 Credits & Heritage
- **NASA Earth Science Division**: Landsat 8/9 Operational Land Imager (OLI-2), EOS Terra/Aqua, NISAR.
- **NASA Planetary Science Division**: Lunar Reconnaissance Orbiter (LRO LOLA & Diviner), KPLO ShadowCam, VIPER TRIDENT drill, CADRE autonomous micro-rovers.
- **NASA Jet Propulsion Laboratory (JPL)**: Mars 2020 *Perseverance* Rover, *Curiosity* Sky Crane EDL system, Deep Space Network (DSN).
- **Aerojet Rocketdyne & BAE Systems**: R-4D bipropellant engines, RAD750 rad-hardened flight processors, NEXT-C gridded ion thrusters.
