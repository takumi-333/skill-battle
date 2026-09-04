# Design

1. Add `scripts/trace_evaluator.gd` as a pure reusable evaluator. It will own configuration, polyline cleanup/resampling, point-to-segment distance, gap detection, robust percentiles, length penalty, normalized error, score, and result serialization.
2. Replace `MatchPrototype.evaluate_trace()` with a call to the evaluator. Keep the existing pass/fail thresholds and RPC behavior, but use one result for local and remote submissions.
3. Extend the trace challenge UI with a compact result panel driven by the returned metrics. Keep it hidden outside trace evaluation.
4. Add a standalone Godot debug scene/script under `scenes/debug` and `scripts/debug` that renders target/user strokes, accepts pointer input, and exposes evaluator settings and metrics without depending on match state.
5. Add deterministic headless verification for the evaluator, then run Godot headless and the debug scene to catch parse/runtime errors.
