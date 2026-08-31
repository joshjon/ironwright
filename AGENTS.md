# Ironwright

Simulated GPU inference fleet (`ironwright`) and the control plane that manages
it (`anvil`). Plan in `BUILD-GUIDE.md`, vocabulary in `CONTEXT.md`, decisions in
`docs/adr/`.

## Layout

- `cmd/ironwright` and `cmd/anvil` are the two binaries
- `internal/sim/` is the simulator
- `internal/anvil/` is the control plane
- `internal/wire/` holds the wire types and fault identifiers, and is the only
  package both may import

## Writing

- Never use em dashes or semicolons. Use full stops, commas or brackets.
- Be succinct. Reserve low level detail for genuinely complex topics.
- Commit messages and PR descriptions are terse.

## Vocabulary

Use the terms in `CONTEXT.md` exactly. They are chosen, not incidental.

- `host`, never node, server or machine
- `deployment`, never workload, job or pod
- **physical state** (what the metal is doing) and **lifecycle state** (what the
  operator decided) are different concepts and never the same type
- **placement** (what anvil believes) and **occupancy** (what telemetry shows)
  are different concepts

When a new term is settled, add it to `CONTEXT.md` immediately rather than
batching. `CONTEXT.md` is a glossary only. No implementation detail.

## Boundaries

- `ironwright` must never import `anvil` packages. They share only wire types
  and fault identifiers. See ADR-0003.
- Anvil learns about hardware only through the exposed surfaces, Redfish out of
  band and the agent in band. Never through a shared type.
- Ironwright never reports what is placed on a host. A deployment exists only as
  observed load. See ADR-0005.
- Scope starts above the operating system. No OS install, PXE, firmware or cross
  host fabric. See ADR-0006.

## Determinism

The simulator core replays byte identically for a given config and seed.

- Sort map keys before iterating. Go randomises map iteration and this is the
  most common way determinism breaks.
- No `time.Now`, `time.Sleep` or real timers in the core. Use the virtual clock.
- No global RNG. Seeds derive hierarchically from a master seed, so adding a
  host does not shift another host's draws.
- Simulation mode is single threaded.

Determinism is scoped to the simulator, not to anvil. See ADR-0002.

## Faults

Every entry in `catalogue/` carries a citation to a real report. Never invent a
fault. Schema in `catalogue/README.md`.

## Decisions

Write an ADR only when a decision is hard to reverse, surprising without
context, and the result of a real trade off. Skip it otherwise.

## Checks

`scripts/check-boundaries.sh` enforces ADR-0003. It runs in CI and locally.
