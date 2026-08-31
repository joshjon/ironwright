# Occupancy is observed, not declared

Ironwright never reports what is placed on a host. A deployment exists only as
its effects: framebuffer consumed, utilisation, power, heat. Anvil holds the
authoritative placement record and must infer occupancy from telemetry.

This mirrors reality, since a GPU has no idea what a scheduler decided. It also
upholds ADR-0003.

## Consequences

Fragmentation becomes something anvil must detect, which is the honest version
of the problem. It also makes an entire fault class expressible: placement and
occupancy disagreeing. Memory held after a container died, a GPU believed free
that is not, a deployment the record says is running that consumes nothing. All
are real incidents and none can be represented if the simulator simply reports
what is placed.
