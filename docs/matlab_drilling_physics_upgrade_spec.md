# Technical Specification: Physics-Driven Drilling Diagnostics Upgrade

## 1. Purpose

This document defines the complete technical logic for upgrading the current MATLAB Drilling Diagnostics Tool from a rule-based synthetic demonstrator into a more physics-driven engineering simulation and diagnostic framework.

The goal is to guide a subsequent implementation task. The specification focuses on mathematical logic, physical process modeling, diagnostic feature design, and module-level behavior. It does not prescribe unit tests and does not require external libraries or MATLAB toolboxes.

## 2. Current System Summary

The current system already provides:

- Synthetic drilling data generation for 5 days with 15-minute sampling.
- Core drilling parameters: MD, TVD, ROP, WOB, RPM, Torque, Hookload, Standpipe Pressure, Flow Rate, Mud Weight, ECD, Pit Volume, Gas, Pore Pressure, Fracture Gradient.
- Modeled complications: kick, mud losses, pack-off, stuck pipe.
- Three-level detection architecture:
  - Level 1: heuristic rules.
  - Level 2: engineering calculations.
  - Level 3: statistical anomaly detection.
- Connection detection and filtering.
- Export to CSV, MAT, PNG, JSON, and TXT.

The main limitation is that complications are still largely injected by fixed time intervals and parameter symptoms. The next upgrade should make complications emerge from physical state variables and engineering thresholds.

## 3. Target Capability

The upgraded model should represent a causally linked drilling system:

```text
Formation properties + drilling parameters + hydraulics + hole cleaning
        ↓
Physical state variables
        ↓
Pressure margins, MSE, cuttings load, drag/torque state
        ↓
Complication triggers
        ↓
Observable sensor response
        ↓
Diagnostic detection and risk scoring
```

The system should still remain lightweight, deterministic enough for repeatable analysis, and readable by drilling engineers.

## 4. Core Design Principles

1. Model causes before symptoms.
2. Keep equations simple but physically meaningful.
3. Preserve interpretability over mathematical complexity.
4. Maintain modular MATLAB functions.
5. Keep each `.m` file focused and short.
6. Avoid external libraries and toolboxes.
7. Prefer engineering indices over black-box models.
8. Make thresholds configurable.
9. Separate simulation truth from diagnostic inference.
10. Preserve Russian-language comments and reports if code output is user-facing.

## 5. Proposed Module Structure

Add or update the following MATLAB modules:

```text
matlab_diagnostics/
├── get_default_config.m
├── generate_formation_model.m
├── calculate_hydraulics.m
├── calculate_mse.m
├── calculate_hole_cleaning.m
├── update_physical_state.m
├── trigger_complications.m
├── apply_sensor_response.m
├── calculate_diagnostic_features.m
├── detect_events_level1.m
├── detect_events_level2.m
├── detect_events_level3.m
├── aggregate_detections.m
├── run_full_diagnostics.m
└── plot_diagnostics.m
```

Existing modules may be refactored instead of replaced, but the logical responsibilities should follow this structure.

## 6. Configuration Model

Create `get_default_config.m` returning a struct:

```matlab
config.simulation.n_points = 480;
config.simulation.dt_minutes = 15;
config.simulation.start_md = 2000;
config.simulation.random_seed = 42;

config.geometry.bit_diameter_m = 0.2159;
config.geometry.hole_diameter_m = 0.2159;
config.geometry.pipe_od_m = 0.127;
config.geometry.pipe_id_m = 0.108;

config.fluid.mud_weight_base = 1.15;
config.fluid.pv = 25;
config.fluid.yp = 12;
config.fluid.rheology_factor = 1.0;

config.thresholds.kick_margin = 0.03;
config.thresholds.loss_margin = 0.03;
config.thresholds.packoff_index = 1.0;
config.thresholds.stuck_index = 1.0;

config.detectors.window = 20;
config.detectors.min_event_points = 4;
```

All numerical thresholds currently hard-coded in detection modules should be moved into this config.

## 7. Formation Model

Create a formation table with depth intervals and rock/fluid properties.

Required fields:

```text
TopMD
BottomMD
Lithology
UCS_MPa
Abrasiveness
Drillability
PorePressureGradient
FractureGradient
GasPotential
PermeabilityIndex
InstabilityIndex
```

Example logic:

```matlab
formations = table();
formations.TopMD = [2000; 2350; 2600; 3000; 3400];
formations.BottomMD = [2350; 2600; 3000; 3400; 5000];
formations.Lithology = {'shale'; 'sandstone'; 'carbonate'; 'shale'; 'sandstone'};
formations.UCS_MPa = [35; 55; 90; 45; 60];
formations.Drillability = [1.2; 0.9; 0.55; 1.0; 0.85];
formations.GasPotential = [0.2; 0.8; 0.3; 0.5; 0.9];
```

At every time step, the active formation should be selected from MD.

## 8. Normal Drilling Physics

### 8.1 ROP Model

Replace the current simplified ROP formula with a formation-aware model:

```text
ROP = Krop × Drillability × (WOB / WOBref)^a × (RPM / RPMref)^b × HydraulicFactor × BitWearFactor × DifferentialPressureFactor
```

Suggested simplified MATLAB form:

```matlab
wob_term = (WOB / config.refs.WOB)^0.8;
rpm_term = (RPM / config.refs.RPM)^0.6;
formation_term = activeFormation.Drillability;
hydraulic_term = min(1.2, max(0.6, HSI / config.refs.HSI));
dp_term = max(0.5, 1 - 0.15 * max(0, ECD - PorePressure));
wear_term = max(0.6, 1 - bit_wear);

ROP = config.refs.ROP * wob_term * rpm_term * formation_term * hydraulic_term * dp_term * wear_term;
```

### 8.2 Torque Model

Torque should depend on WOB, RPM, formation abrasiveness, cuttings load, and wellbore friction:

```text
Torque = BaseTorque × WOBFactor × RPMFactor × FormationFactor × CleaningPenalty × FrictionPenalty
```

Suggested logic:

```matlab
torque = base_torque * ...
         (WOB / WOBref)^0.9 * ...
         (RPM / RPMref)^0.4 * ...
         (1 + activeFormation.Abrasiveness * 0.2) * ...
         (1 + cuttings_load * 0.4) * ...
         (1 + friction_index * 0.3);
```

### 8.3 Hookload Model

Hookload should represent string weight, buoyancy, WOB, drag, and sticking forces:

```text
Hookload = StringWeight × BuoyancyFactor - WOB + DragForce + StickingForce
```

Suggested logic:

```matlab
string_weight = base_bha_weight + MD * pipe_weight_per_m;
buoyancy = 1 - MudWeight / steel_density_equiv;
drag = friction_index * MD * drag_coeff;
hookload = string_weight * buoyancy - WOB + drag + sticking_force;
```

## 9. Hydraulics Model

Create `calculate_hydraulics.m`.

### 9.1 Annular Velocity

```matlab
annular_area = pi/4 * (hole_diameter^2 - pipe_od^2);
flow_m3s = FlowRate_lpm / 1000 / 60;
annular_velocity = flow_m3s / annular_area;
```

### 9.2 Annular Pressure Loss

Use a simplified empirical relationship:

```matlab
pressure_loss_annulus = k_hyd * (flow_m3s^1.8) * TVD * rheology_factor / annular_area^2;
```

### 9.3 Cuttings Pressure Loss

```matlab
cuttings_pressure_loss = k_cuttings * cuttings_load * TVD;
```

### 9.4 ECD

```matlab
ECD = MudWeight + (pressure_loss_annulus + cuttings_pressure_loss) / (rho_scale * TVD);
```

The constants should be calibrated for plausible synthetic values, not field-grade precision.

## 10. Mechanical Specific Energy

Create `calculate_mse.m`.

MSE is a key drilling efficiency indicator:

```text
MSE = WOB / BitArea + (120 × π × RPM × Torque) / (BitArea × ROP)
```

Use safe denominator handling:

```matlab
bit_area = pi/4 * bit_diameter^2;
rop_safe = max(ROP, 0.1);
MSE = WOB ./ bit_area + mse_coeff .* RPM .* Torque ./ (bit_area .* rop_safe);
```

Diagnostic interpretation:

- Rising MSE with stable WOB/RPM suggests bit dulling, dysfunction, or harder formation.
- High MSE + high torque + low ROP supports pack-off or stuck pipe risk.
- MSE spikes during connections should be ignored.

## 11. Hole Cleaning Model

Create `calculate_hole_cleaning.m`.

Introduce hidden physical state variables:

```text
cuttings_generation
transport_capacity
cuttings_load
cleaning_efficiency
packoff_index
```

### 11.1 Cuttings Generation

```matlab
hole_area = pi/4 * hole_diameter^2;
cuttings_generation = ROP * hole_area * dt_hours;
```

### 11.2 Transport Capacity

```matlab
transport_capacity = k_transport * annular_velocity * cleaning_efficiency * dt_hours;
```

Cleaning efficiency should decrease with low flow, low RPM, high inclination, and high ROP:

```matlab
cleaning_efficiency = min(1, ...
    0.4 + 0.3 * FlowRate / FlowRef + 0.2 * RPM / RPMRef - 0.1 * InclinationFactor);
```

### 11.3 Cuttings Load Update

```matlab
cuttings_load(t) = max(0, cuttings_load(t-1) + cuttings_generation - transport_capacity);
```

### 11.4 Pack-off Index

```matlab
packoff_index = cuttings_load / cuttings_threshold;
```

Pack-off risk should increase when:

```text
packoff_index > 1
SPP trend positive
Torque rising
ROP falling
```

## 12. Complication Trigger Logic

Create `trigger_complications.m`.

Complications should be triggered by physical conditions, not fixed intervals only. For synthetic coverage, optional planned perturbations may push the system toward thresholds, but the event should start only when physical criteria are met.

### 12.1 Kick Trigger

```matlab
kick_drawdown = PorePressure - ECD;
if kick_drawdown > config.thresholds.kick_margin
    kick_active = true;
    influx_rate = k_influx * kick_drawdown^1.5 * permeability_index;
end
```

Sensor response:

```matlab
PitVolume += influx_rate * dt;
Gas += gas_potential * influx_rate;
MudWeight -= dilution_factor * influx_rate;
SPP += pressure_response_factor * influx_rate;
```

### 12.2 Losses Trigger

```matlab
loss_overpressure = ECD - FractureGradient;
if loss_overpressure > config.thresholds.loss_margin
    losses_active = true;
    loss_rate = k_loss * loss_overpressure^1.3;
end
```

Sensor response:

```matlab
PitVolume -= loss_rate * dt;
SPP -= pressure_drop_factor * loss_rate;
ECD -= hydraulic_response_factor * loss_rate;
```

### 12.3 Pack-off Trigger

```matlab
if packoff_index > threshold && SPP_trend > 0 && Torque_trend > 0
    packoff_active = true;
end
```

Sensor response:

```matlab
SPP += packoff_index * spp_gain;
Torque += packoff_index * torque_gain;
ROP *= max(0.2, 1 - packoff_index * rop_penalty);
FlowRate *= max(0.7, 1 - packoff_index * flow_penalty);
```

### 12.4 Stuck Pipe Trigger

Split stuck pipe into mechanisms.

#### Mechanical Sticking

```matlab
if packoff_index > 1.2 && Torque high && ROP falling
    mechanical_sticking_active = true;
end
```

#### Differential Sticking

```matlab
stationary_pipe = ROP < 0.5 && RPM < 5;
high_overbalance = ECD - PorePressure > diff_stick_margin;
permeable_zone = permeability_index > threshold;

if stationary_pipe && high_overbalance && permeable_zone
    differential_sticking_active = true;
end
```

Sensor response:

```matlab
ROP = 0;
Hookload += sticking_force;
Torque += sticking_torque;
```

## 13. Diagnostic Feature Set

Extend `calculate_diagnostic_features.m` to include:

```text
ecd_vs_pp
fg_vs_ecd
mud_window
critical_pressure
mse
mse_zscore
annular_velocity
cuttings_load
cleaning_efficiency
packoff_index
pit_volume_trend
pit_volume_rate
gas_zscore
spp_deviation
spp_trend
torque_zscore
hookload_zscore
rop_trend
flow_deviation
connection_mask
```

All statistical baselines should exclude connection intervals.

## 14. Detector Logic

### 14.1 Level 1: Fast Heuristics

Purpose: detect obvious symptoms quickly.

Rules:

```text
Kick: pit volume up + gas up + SPP anomaly
Losses: pit volume down + SPP down
Pack-off: SPP up + torque up + ROP down
Stuck: ROP zero + hookload anomaly + torque anomaly
```

Connection intervals must be ignored.

### 14.2 Level 2: Engineering Physics

Purpose: confirm events using physical margins.

Rules:

```text
Kick: ECD close to or below PP + influx symptoms
Losses: ECD close to or above FG + loss symptoms
Pack-off: packoff_index > threshold + SPP/Torque response
Stuck: mechanical or differential sticking index exceeds threshold
```

### 14.3 Level 3: Statistical Anomaly Detection

Purpose: detect early anomalies before hard thresholds.

Use:

- Z-score relative to rolling baseline.
- Trend persistence.
- Rate of change.
- Multi-parameter anomaly voting.

Example voting logic:

```matlab
votes = 0;
if gas_zscore > 2, votes = votes + 1; end
if pit_volume_trend > threshold, votes = votes + 1; end
if spp_deviation > threshold, votes = votes + 1; end
if ecd_vs_pp < margin, votes = votes + 1; end

if votes >= 3
    event = kick;
end
```

## 15. Risk Score Model

Replace simple averaging with a weighted score:

```matlab
risk_score = 100 * ( ...
    0.25 * level1_confidence + ...
    0.40 * level2_confidence + ...
    0.20 * level3_confidence + ...
    0.15 * severity_index );
```

Severity index should depend on physics:

```text
Kick severity: drawdown magnitude + influx rate + gas increase
Loss severity: loss rate + fracture margin violation
Pack-off severity: packoff_index + SPP increase + torque increase
Stuck severity: stuck duration + hookload anomaly + torque anomaly
```

Confidence level:

```text
risk < 40: low
40 <= risk < 65: medium
65 <= risk < 80: high
risk >= 80: critical/high confidence
```

## 16. Synthetic Report Text Logic

Text explanations should be generated from active diagnostic evidence.

Example:

```text
Обнаружен pack-off: устойчивый рост SPP (+42 бар относительно базовой линии), torque z-score = 3.1, ROP снизилась до 35% от базового уровня. Интервал не совпадает с соединением свечи, поэтому событие классифицировано как эксплуатационное осложнение, а не технологическая операция.
```

Each event explanation should include:

- event type;
- start/end time;
- depth;
- strongest evidence;
- excluded false-positive explanation if applicable;
- risk score;
- confidence level.

## 17. Visualization Requirements

Update plotting to include:

1. Main diagnostic time series:
   - MD / ROP
   - Pit Volume / Gas
   - SPP / Torque
   - WOB / Hookload
   - ECD / PP / FG
   - connection intervals shaded in gray
   - complications shaded by event type

2. Risk timeline:
   - total risk score
   - per-event risk bars
   - event labels

3. Optional advanced figure:
   - MSE timeline
   - packoff_index timeline
   - cuttings_load timeline
   - ECD margin timeline

## 18. Output Files

The pipeline must generate:

```text
raw_drilling_data.csv
diagnostic_features.csv
detected_events.csv
drilling_diagnostics_results.mat
diagnostic_summary.txt
diagnostic_timeseries.png
risk_timeline.png
events_for_web.json
```

Additional optional outputs:

```text
physical_state.csv
formation_model.csv
advanced_diagnostics.png
```

## 19. Acceptance Criteria

The upgraded implementation is acceptable if:

1. `run_full_diagnostics` completes without manual intervention.
2. All required output files are generated.
3. MATLAB execution does not hang during plot saving.
4. Connection intervals are detected and excluded from event detection.
5. At least 4 complication types are detected in synthetic scenario.
6. Detected event explanations include physical evidence.
7. ROP average is within a plausible range, target 18-30 m/h during drilling intervals.
8. ECD remains mostly between PP and FG during normal drilling.
9. Kick/losses are triggered by pressure margin logic.
10. Pack-off and stuck pipe are linked to hole cleaning or sticking indices.

## 20. Expected Quality Improvement

Current subject-matter score: approximately 6.5/10.

Expected score after implementation:

```text
Normal drilling physics: 8/10
Hydraulics and ECD: 8/10
ROP / MSE mechanics: 8/10
Kick/losses causality: 8.5/10
Pack-off / hole cleaning: 8.5/10
Stuck pipe mechanisms: 8/10
Diagnostic interpretability: 9/10
Overall subject-matter score: 8.5-9/10
```

## 21. Implementation Sequence

Recommended order:

1. Add `get_default_config.m`.
2. Add `generate_formation_model.m`.
3. Refactor `generate_synthetic_drilling.m` to use config and formation table.
4. Add `calculate_hydraulics.m`.
5. Add `calculate_mse.m`.
6. Add `calculate_hole_cleaning.m`.
7. Replace fixed complication injection with `trigger_complications.m`.
8. Update `calculate_diagnostic_features.m`.
9. Update Level 1, Level 2, and Level 3 detectors.
10. Update `aggregate_detections.m` with weighted risk model.
11. Update `plot_diagnostics.m`.
12. Update `generate_report.m`.
13. Run full verification via `run_full_diagnostics`.
14. Confirm all required files and plots are generated.

## 22. Non-Goals

Do not implement in this phase:

- Unit tests.
- External MATLAB toolboxes.
- Python dependency.
- Machine learning models requiring training data.
- Real-time data streaming.
- Web interface integration.

## 23. Summary

The next implementation should move the system from symptom injection to physics-driven scenario generation. The central additions are ECD hydraulics, MSE, hole-cleaning state, formation properties, and causal event triggers. The diagnostic architecture should remain interpretable and modular, while the synthetic data should become more realistic and valuable for analytics evaluation.
