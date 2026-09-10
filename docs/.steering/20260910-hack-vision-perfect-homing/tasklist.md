# Task List

- [x] Update Hack Vision projectile spawning and per-tick homing in the authoritative simulation.
- [x] Mirror the lifetime and full-homing behavior in the local prototype.
- [x] Add a regression test for the authoritative projectile behavior.
- [x] Run the network simulation test and a headless Godot startup check.
- [x] Record the five-second, full-homing behavior in the skill specification.

## Implementation Review

- Date: 2026-09-10
- Changed Hack Vision from gradual steering to immediate, per-update target alignment, and extended its lifetime from 4.0 to 5.0 seconds.
- The Typist's limited homing behavior remains unchanged.
- Verification: `godot --headless --path . --script res://tests/network/match_simulation_test.gd` passed; `godot --headless --path . --quit-after 3` started and exited successfully. Godot emitted environment-level log-file and root-certificate warnings only.
