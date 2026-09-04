# Requirements

## Goal

Replace the tracing prototype's endpoint-biased scoring with a reusable Polyline evaluator and expose it through a standalone debug tool.

## Functional requirements

- Record a stroke from MouseDown through MouseMotion and finalize it once on MouseUp. Cancelled strokes are evaluated up to the cancellation point.
- Remove input noise, resample target and user polylines at a fixed interval, and use point-to-segment distance for coverage and deviation.
- Detect target-to-user gaps and fail when a gap reaches the configured threshold.
- Calculate MeanError, P90Error, P95Error, P99Error, CoverageError, TargetLength, UserLength, LengthRatio, and LengthPenalty.
- Normalize distance error by the target stroke size and calculate a clamped 0–100 score with the specified non-linear formula.
- Keep small and big trace challenges on the same evaluator and make the evaluator callable by the game and debug tool.
- Show trace result details in the debug tool and allow adjustment of the relevant thresholds, sampling interval, stroke size, and score parameters.
- Add deterministic verification for translated/rotated/equivalent strokes, omissions, gaps, noisy input, and target length differences.

## Constraints

- Preserve the existing challenge UI and network flow.
- Keep tuning values centralized and configurable.
- Do not make endpoint distance the primary score component.
