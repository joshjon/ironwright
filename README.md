# Ironwright

A simulated GPU inference fleet, and a control plane that keeps it healthy and
efficiently packed.

**Status: early.** The design is settled and documented. No code yet.

## Why

Running a GPU fleet means answering two questions continuously. Is this hardware
healthy enough to serve, and is the capacity we own actually being used.

Both are handled today by software nobody can test. Testing needs a fleet that
is busy, degraded and fragmented on demand, which no lab provides. So health
scoring, remediation, placement and defragmentation get written carefully,
deployed nervously, and validated in production.

## What

Two binaries, built together.

**`ironwright`** simulates a GPU fleet. Hosts, GPUs, their software stack and
their telemetry, breaking in catalogued ways sourced from real incident reports.
Deterministic, so any run replays byte identically.

**`anvil`** is a Kubernetes native control plane. Controllers reconcile declared
intent, Temporal runs long lived host lifecycles, health and remediation are
event driven, and a placement engine keeps utilisation high and fragmentation
low.

## Docs

| | |
|---|---|
| [BUILD-GUIDE.md](BUILD-GUIDE.md) | The plan, in slices |
| [CONTEXT.md](CONTEXT.md) | Domain glossary |
| [docs/adr/](docs/adr/) | Architecture decisions |
| [catalogue/](catalogue/) | Fault catalogue and its schema |

## Licence

Apache-2.0.
