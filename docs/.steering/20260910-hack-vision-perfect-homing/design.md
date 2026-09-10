# Design

Hack Vision is specified as a guaranteed-homing interference projectile.  On each projectile update, calculate the direction from the projectile to its current target, retain its current speed, and assign the velocity to that direction.  Do not apply the Typist turning-speed or maximum-angle limits.

Use a five-second lifetime when the projectile is spawned.  Mirror this behavior in `scripts/network/match_simulation.gd` and `scripts/match_prototype.gd` so online authority and local behavior remain aligned.

Extend the network simulation test to confirm the five-second lifetime and that a target moving perpendicular to the initial trajectory causes the projectile velocity to point to the target after an update.
