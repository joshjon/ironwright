# Determinism is the simulator's property, not the system's

Ironwright replays byte identically for a given config and seed. Anvil does not,
and we do not claim it does. It runs against Temporal, which has its own
persistence, timers and task queues.

These are two separate guarantees and both are real. Ironwright offers
deterministic simulation. Anvil offers durable execution with Temporal's own
workflow replay. Stated separately they survive scrutiny. Blended into a whole
system claim they would not.

## Consequences

Anvil's event bus sits on the non-deterministic side of the boundary. Temporal
never constrains the simulator's design. The byte identical replay test targets
the simulator alone and is written in slice 0, because retrofitting determinism
costs far more than starting with it.
