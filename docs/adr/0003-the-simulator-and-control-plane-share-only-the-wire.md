# Ironwright and anvil share only the wire

One repo, one Go module, two binaries. Ironwright may never import anvil
packages. The two share no domain types, only the wire types of the exposed
surfaces and fault identifiers. Enforced in CI from the first commit.

Anvil must learn everything through those surfaces, Redfish out of band and the
agent in band, exactly as it would from real hardware, including the cases where
the two disagree. A shared `Host` type would hand it knowledge no real fleet
provides. Fault identifiers are the one exception, so tests can say "inject this
fault, assert anvil converges".

## Consequences

Physical state and lifecycle state are necessarily separate types in separate
packages. `Allocated` is meaningless to hardware. The rule also keeps ironwright
spinnable out at no cost.
