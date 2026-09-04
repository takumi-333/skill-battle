# Task List

## Phase 1: Plan and baseline

- [x] Read issue-21 and relevant UI/game specifications.
- [x] Inspect current trace input, scoring, scene, and test structure.
- [x] Record baseline Godot headless result.

## Phase 2: Evaluator

- [x] Implement configurable reusable Polyline evaluator.
- [x] Add noise removal, resampling, point-to-segment metrics, gap detection, percentiles, length penalty, and non-linear score.
- [x] Add deterministic evaluator verification cases.

## Phase 3: Game integration

- [x] Route local and remote trace submissions through the shared evaluator.
- [x] Preserve challenge pass/fail and network behavior while exposing result metrics.
- [x] Add trace result details to the challenge UI.

## Phase 4: Standalone debug tool

- [x] Add independent trace debug scene and script.
- [x] Add runtime controls for evaluator tuning and visual target/user stroke comparison.
- [x] Show score, NG reason, error statistics, coverage, and length metrics.

## Phase 5: Verification and reflection

- [x] Run evaluator tests and Godot headless checks; fix detected errors.
- [x] Perform manual/debug-scene verification where available.
- [x] Record implementation results and follow-up tuning notes below.

## Implementation reflection

Implemented `TraceEvaluator` and routed both local and remote trace submissions through it. The evaluator removes noise, resamples at 2px, uses point-to-segment distance, tracks consecutive target gaps, computes error percentiles and length penalty, and maps normalized error through the exponential score curve. Added deterministic evaluator tests and an independent debug scene. Headless checks passed; Godot emitted only environment warnings about the user log directory and root certificate store. Playtests should tune sigma and pass thresholds together.

Follow-up fix: a local gap is no longer an automatic zero. It becomes NG only when the gap threshold is exceeded and the aggregate coverage error is at least `NG_DISTANCE`; this preserves strict failure for substantial omissions while allowing small corner/sampling gaps to retain their calculated score.

Follow-up tuning: set the normalization scale to 55% of the Target bounding-box size so large canvases do not dilute visible tracing errors while small positional offsets remain usable.
