# Ironwright

A simulated GPU inference fleet, and a control plane that keeps it healthy and
efficiently packed.

Vocabulary: [CONTEXT.md](CONTEXT.md). Decisions: [docs/adr/](docs/adr/).

---

# 1. In one paragraph

Running a GPU inference fleet means answering two questions continuously. Is
this hardware healthy enough to serve, and is the capacity we own actually being
used. Both are handled today by software nobody can test, because testing needs
a fleet that is busy, degraded and fragmented on demand. This project builds
both halves together. `ironwright` is a deterministic simulated fleet that
breaks in catalogued, cited ways. `anvil` is a Kubernetes native control plane
that validates hosts before admitting them, remediates without a human, and
keeps deployments packed tightly enough that expensive GPUs are not idle.

---

# 2. The problem

## 2.1 Health

At 8 GPUs, mean time between failures is roughly 47 days. At 1,024 it is about 8
hours. At 16,384 it is under 2. Failure stops being an event and becomes a
background condition, so admission and remediation have to be automatic.

Operators who own metal have published how they handle it. Crusoe runs up to 30
validation tests on every node before a customer sees it, across node, GPU and
fabric domains, escalating through sanity, validation, performance and stress.
When they find a new failure mode in production they add a test that would have
caught it. Nebius describes factory tests, deployment tests, pre-provisioning
cluster tests, and passive and active health checks.

That loop, where a failure teaches the fleet a new test, is what this project
automates.

## 2.2 Utilisation

GPUs are the most expensive thing in the building, and a fleet that churns
deployments fragments. Twelve free GPUs spread across four hosts will not host
an 8 GPU model, because a model split across hosts pays a network hop per token.
The capacity exists and cannot be sold.

Fixing it means relocating live deployments. Every relocation costs a drain, a
reload of tens of gigabytes of weights, and a re-warm. So the decision is never
"can this be consolidated" but "is it worth the disruption".

## 2.3 Neither is testable

Health scoring, remediation, placement and defragmentation are written
carefully, deployed nervously, and validated in production.

| Layer | How you test it |
|---|---|
| Application | Unit tests, in process |
| Kubernetes controller | envtest, fake clients |
| Cloud provisioning | LocalStack, test accounts |
| Distributed database | Jepsen, deterministic simulation |
| **GPU fleet management** | **Production** |

A lab does not fix this. A lab gives you machines that work and a fleet that is
empty. It cannot make a GPU report XID 48 on request, hold memory hostage after
a container dies, or hand you a fleet that has been churning for a month.

These are one problem. Fleet management is manual because automating it means
handling failure and contention, and nobody can verify handling they cannot
reproduce.

---

# 3. What exists

| Thing | What it is | Gap |
|---|---|---|
| **Metal3, Ironic, Tinkerbell** | Bare metal provisioning | Provisioning, not fleet health. GPU unaware. Out of scope here, see ADR-0006 |
| **NVIDIA GPU Operator, DCGM** | Driver lifecycle and telemetry | Reports health, decides nothing |
| **Kubernetes scheduler, Kueue, Volcano** | Placement and gang scheduling | No hardware health input, no defragmentation of live deployments |
| **The large GPU clouds** | All built this internally | All private. They publish blog posts, not code |
| **sushy-tools** | Redfish emulator over libvirt | Dev only, no GPU concept, no fault injection, no determinism, no load |

Nothing open source lets you run a GPU fleet forward in time, degrade it
deliberately, and test what your control plane does about it.

**Who this is for.** Not the large operators, who build their own with dedicated
teams. The long tail of smaller and sovereign operators, on-prem and research
clusters, and anyone writing control plane code who would like to test it.

---

# 4. The two components

Ironwright is a fake fleet. Anvil is its flagship consumer. They share no domain
types, only the wire. See ADR-0003.

```
anvil                                        ironwright
  |-- GET /redfish/v1/Systems/1 ------------->|  out of band: power, presence
  |<-- {"PowerState":"On"} -------------------|
  |-- GET /agent/v1/stack ------------------->|  in band: driver, CUDA, NCCL
  |<-- {"driver":"580.65.06", ...} -----------|
  |-- GET /metrics -------------------------->|  in band: DCGM shaped telemetry
  |<-- DCGM_FI_DEV_FB_USED{gpu="3"} 74.2e9 ---|  occupancy, inferred not declared
```

| Piece | Anvil | Ironwright |
|---|---|---|
| Language | Go | Go |
| Durable execution | Temporal, embedded dev server by default | none |
| Declarative surface | controller-runtime, CRDs | none |
| Events | NATS, embedded by default | emits only |
| API | Protobuf and Connect | `net/http` and a router |
| State | Kubernetes and Temporal. No datastore until a query forces one | In-memory fleet model |
| Observability | OpenTelemetry, Prometheus | Prometheus, in DCGM shape |

One repo, one Go module, two binaries, a one way dependency enforced in CI.

---

# 5. Scope

In: everything above a booted, reachable host. Discovery, inventory, driver and
CUDA stack, burn-in, admission, placement, health, remediation, decommission.

Out: OS install and PXE, firmware, cross host fabric, multi provider
abstraction, Ironic and Metal3 compatibility. Reasons in
[ADR-0006](docs/adr/0006-scope-boundary.md).

---

# 6. The two surfaces

**Out of band, via Redfish.** The BMC is a small always-on computer on the
motherboard with its own network port, reachable when the host is powered off.
It reports power state, physical presence, temperature, serial, and GPUs as
`Processors` and `PCIeDevices`. It knows nothing about software.

Behaviours worth modelling: transitional power states, actions that are not
idempotent, structured errors, ETags, sessions that expire. Every activity is
written check then act, which is what makes Temporal's at-least-once execution
safe.

**In band, via the agent.** Stack inventory (driver, CUDA, NCCL) and
`dcgm-exporter` shaped telemetry. Silent when the host is off or the OS wedged.

| Field | Carries |
|---|---|
| `DCGM_FI_DEV_FB_USED`, `..._FB_FREE` | Framebuffer, how occupancy is observed |
| `DCGM_FI_DEV_GPU_UTIL` | Utilisation |
| `DCGM_FI_DEV_GPU_TEMP`, `..._POWER_USAGE` | Thermal and power |
| `DCGM_FI_DEV_ECC_SBE_VOL_TOTAL`, `..._DBE_...` | Correctable and uncorrectable ECC |
| `DCGM_FI_DEV_XID_ERRORS` | Last XID code |
| `DCGM_FI_DEV_ROW_REMAP_PENDING`, `..._FAILURE` | Row remapping, Ampere onward |
| `DCGM_FI_DEV_CLOCK_THROTTLE_REASONS` | Thermal, power brake, sync boost |
| `DCGM_FI_DEV_PCIE_LINK_WIDTH`, `..._GEN` | Link width and generation |

Model both and let them disagree. A GPU present in PCIe enumeration but absent
from the driver is XID 79, and the contradiction is what makes it confusing in
real life.

---

# 7. Anvil's design

## 7.1 Manifests

```yaml
apiVersion: anvil/v1
kind: Host
spec:
  serial: SN-4417
  stack: { driver: "580", cuda: "13.0", nccl: "2.28" }
---
apiVersion: anvil/v1
kind: Deployment
spec:
  model: llama-3.3-70b
  gpus: 4          # must fit one NVLink domain
  replicas: 6
```

Typed with protobuf, versioned, generated clients. Not YAML parsed at runtime.

## 7.2 Temporal and controller split

| Concern | Owner |
|---|---|
| Desired state, watching, drift detection | Controller |
| Deciding that something must happen | Controller |
| Any multi step, long running, partially failing process | Temporal workflow |
| Reflecting progress back to the user | Controller, reading workflow status |

`Reconcile` never blocks and never works inline. Deterministic workflow IDs make
it idempotent for free.

```go
workflowID := fmt.Sprintf("host-%s-%s-%d", serial, op, generation)
```

Start on every reconcile and let Temporal's duplicate policy deduplicate. When
something changes mid flight, signal the running workflow rather than starting
another.

## 7.3 Event driven, not polling

Health signals reach remediation as events. Redfish `EventService` and the agent
both emit, NATS carries them, remediation controllers subscribe. Reconcile loops
handle desired state. Events handle things that happen.

## 7.4 Host lifecycle

Explicit, versioned, data rather than code, with every legal and illegal
transition tested.

```
Discovered -> Inventoried -> Staged -> Validating -> Available -> Allocated
                                          |              ^            |
                                          v              |            v
                                     Quarantined <-------+-------- Draining
                                          |
                                          v
                                    Decommissioned / RMA
```

Orthogonal to it: physical state, owned by the simulator, and health, which is
independent of both. A host can be `Allocated` and unhealthy at once, which is
the case that makes remediation hard.

Three properties from the start. Every transition timestamped and logged.
Quarantine memory keyed by serial, surviving reimage. Illegal transitions are
errors, not no-ops.

## 7.5 Burn-in and admission

A host may not hold deployments until it passes burn-in. Structured after
published operator practice: domains (node, GPU) crossed with test classes
(sanity, validation, performance, stress).

Each catalogued fault records the test class that should catch it. A fault the
catalogue contains and no test detects is a gap in the gate, and that is a report
the project can generate about itself.

---

# 8. Placement and defragmentation

A deployment occupies a whole number of GPUs within one NVLink domain. That
constraint is the entire source of difficulty.

**Placement** picks GPUs for a new deployment. Bin pack rather than spread, and
never place onto a GPU whose health is degrading.

**Fragmentation** is total free capacity exceeding a request while no single
domain can satisfy it. Anvil must detect it from observed occupancy rather than
its own records, per ADR-0005.

**Defragmentation** plans relocations, weighed against disruption. Start with a
scored heuristic. A constraint solver is a later refinement, possibly never.

Three interesting failure modes, all producible by the simulator. Placement and
occupancy disagreeing. A consolidation that costs more than the capacity it
recovers. A defragmentation that races a health event and relocates onto a host
about to be drained.

---

# 9. Determinism and the two modes

| Mode | Transport | Clock | Determinism | Use |
|---|---|---|---|---|
| **Live** | Real HTTP listeners | Wall clock, scalable | Fault schedule only | Demos, real Prometheus |
| **Simulation** | In-process `RoundTripper` | Virtual | Byte identical | CI, chaos runs, a month in seconds |

The fleet model, state machines and fault engine are identical in both. Seam is
ADR-0001. Determinism is scoped to the simulator by ADR-0002.

Rules. Sort keys before iterating maps, since randomised iteration is the most
common source of accidental nondeterminism. No `time.Now`, no `time.Sleep`, no
real timers in the core. Hierarchical seeding, so adding a host does not shift
every other host's draws. Event queue ordered by `(virtualTime, sequence)`.
Simulation mode is single threaded. A run is identified by `(configHash, seed)`
and must be byte identical on repeat, written as a test in slice 0.

Live mode takes a time scale factor so a twenty minute operation can be demoed.
Anvil's Temporal timers are wall clock regardless, so the two are configured
together.

---

# 10. The fault catalogue

## 10.1 Sources

Faults are not invented. Every one comes from someone who ran a fleet and wrote
it down, and carries its citation in the code. See ADR-0004.

1. **Neocloud engineering blogs.** Crusoe on burn-in and AutoClusters, Nebius on
   health checks, SemiAnalysis ClusterMAX reviews. Recent and specific.
2. **NVIDIA's XID list, DCGM field reference, GPU Memory Error Management
   guide.** The definitive account of ECC, retirement and row remapping.
3. **Ironic, Metal3 and Tinkerbell issue trackers.** Search `timeout`, `stuck`,
   `race`, `retry`, `vendor`. Best source for management plane faults.
4. Public postmortems and large scale reliability papers.

## 10.2 Shape

One entry per distinct observable behaviour, parameterised over magnitude and
timing, keyed by layer, with stable identifiers like `gpu.fell-off-bus`. Schema
and examples in [catalogue/](catalogue/).

## 10.3 Layers

**Management plane.** Unreachable. Slow at configurable percentiles. Returns 200
with stale data. Intermittent 500s. Session expiry mid operation. ETag mismatch
under concurrent writers.

**GPU.** XID 13 and 31, application caused, must not trigger RMA. XID 48, double
bit ECC. XID 63 and 64, row remapping. XID 74, NVLink. XID 79, fallen off the
bus. Correctable ECC rate climbing. Row remap pending then failed. GPU missing
from enumeration after reboot. Thermal throttle. PCIe link downgraded.

**Software stack.** Driver version drifts out of band. Driver loaded but GPU
absent from the device list while present in PCIe. CUDA and driver mismatch.
Agent reachable but reporting stale telemetry. Agent silent while the host is up.

**Node and occupancy.** Redundant PSU loss, degraded not dead. Fan failure into
thermal throttle. DIMM correctable errors rising. Memory held after a deployment
dies. A GPU reporting free that is not. Silent slowness, passes every check and
serves 8% slow.

## 10.4 Injection

Direct injection by API on a separate admin port, never as Redfish OEM
extensions, which would pollute the surface being claimed as faithful. Policy
injection by distribution for chaos runs. Faults have onset, duration, and
whether they self heal.

---

# 11. The slices

The simulator leads by about two days, repeatedly. Each slice extends it just
enough, extends anvil to use it, then adds the fault that breaks it. Every slice
ends demoable.

## Slice R, the catalogue

Research before code. Management plane and GPU layers only, time boxed per
layer. Entries land as YAML, the document is a rendering.

Also here: rent a real H100 for an hour and capture golden fixtures. Full
`dcgm-exporter` scrape, `nvidia-smi -q`, `nvidia-smi -q -d ECC,ROW_REMAPPER`,
`nvidia-smi topo -m`, PCIe link state. Single digit dollars, and it makes the
telemetry surface verifiable rather than imagined.

## Slice 0, a host that exists

| | |
|---|---|
| **Ironwright** | Fleet model, one host, physical state machine, virtual clock, seeded RNG. The RoundTripper seam. Redfish: ServiceRoot, Systems, `PowerState`, `Reset`, auth. Agent: stack inventory, `/metrics`, 8 healthy GPUs |
| **Anvil** | Redfish client, agent client, `Host` domain object, discovery and inventory. CLI |
| **Also** | The byte identical replay test. Here, not later |
| **Demo** | `anvil inventory` shows a host, its stack, its 8 GPUs, live telemetry |

## Slice 1, health and admission

| | |
|---|---|
| **Ironwright** | Fault engine, direct injection on the admin port. Management plane and GPU faults |
| **Anvil** | First Temporal workflow. Retry, backoff, check then act. Burn-in across domains and test classes. Health scoring. Admission gate. Quarantine keyed by serial |
| **Demo** | A host with a degrading GPU fails burn-in and is quarantined, while the BMC fails half its requests and the workflow converges anyway |

## Slice 2, declarative

| | |
|---|---|
| **Ironwright** | Out of band mutation, so drift is injectable |
| **Anvil** | controller-runtime. `Host` CRD. Deterministic workflow IDs, signals for mid flight change. Drift detection on stack and health |
| **Demo** | Declare a driver version and watch it converge. Change it out of band and watch it repair |

## Slice 3, placement

| | |
|---|---|
| **Ironwright** | Occupancy as load. A placed deployment shows as framebuffer, utilisation, power and heat. Multiple hosts |
| **Anvil** | `Deployment` CRD. Placement engine, bin packing within NVLink domains. Never place onto degrading health |
| **Demo** | Eight hosts, deployments packed tightly, one host degrades and is excluded |

## Slice 4, event driven remediation

| | |
|---|---|
| **Ironwright** | Redfish `EventService` and agent events. Degradation emits rather than waiting to be noticed |
| **Anvil** | NATS embedded. Health events drive remediation with no polling in the path. Safe drain, relocation, repair workflow, re-admission after revalidation |
| **Demo** | A GPU degrades mid serving. The event fires, deployments relocate, the host drains, no capacity is lost |

## Slice 5, fragmentation and defragmentation

| | |
|---|---|
| **Ironwright** | Policy injection. N hosts. A simulated month of churn in seconds |
| **Anvil** | Fragmentation detected from observed occupancy. Defragmentation planner weighing consolidation against disruption |
| **Demo** | 64 GPUs, a simulated month of deployments arriving and leaving and hardware degrading. Utilisation held high, nothing placed on sick hardware. Then replay the month byte for byte with one fault changed |

If nothing else ships, ship this.

## Slice 6, the lemon

| | |
|---|---|
| **Ironwright** | Gradual degradation. Silent slowness. Lemon behaviour: fails, passes a health check, fails again |
| **Anvil** | Active probes alongside passive signals. Serial keyed quarantine memory |
| **Demo** | A host that passes every check and serves 8% slow is caught, drained, and does not come back |

## Stopping points

| Stop after | You have |
|---|---|
| Slice 2 | A control plane that validates hardware and reconciles it declaratively |
| Slice 5 | The full argument working, and a demo nobody else can run |
| Slice 6 | A complete system, plus a simulator worth spinning out |

---

# 12. Proving fidelity

1. **Golden fixtures from real hardware.** An hour on a rented H100 in slice R.
   Diff emitted telemetry against captured output, field by field, in CI.
2. **Every fault carries a citation.** The catalogue is the fidelity argument.
3. **Real consumers.** Point genuine Prometheus and Grafana at the fleet. If
   `dcgm-exporter` dashboards work unmodified, the shape is right.
4. **DMTF Redfish Service Validator** on the out of band surface.

---

# 13. Risks

| Risk | Mitigation |
|---|---|
| Catalogue is not credible | Every fault cited to an operator blog, XID doc, issue report or postmortem, in the code |
| Telemetry does not match real hardware | Golden fixtures from a rented H100, diffed in CI |
| Fragmentation modelling is naive | The one part with no public source. Keep the heuristic simple and say so |
| Determinism quietly breaks | Byte identical replay as a CI test from slice 0. Map iteration is the usual culprit |
| Scope creep into provisioning | ADR-0006. The slices define the contract |
| Simulator drifts from the catalogue | The catalogue compiles to the fault registry, so they cannot diverge silently |

---

# 14. Reading, in order

**The operators.** Crusoe on burn-in and AutoClusters. Nebius via ClusterMAX.
SemiAnalysis ClusterMAX methodology. This shapes the catalogue.

**The GPU.** NVIDIA XID list. DCGM field reference. GPU Memory Error Management
guide, for ECC, retirement and row remapping.

**The failures.** Ironic, Metal3 and Tinkerbell issue trackers, for the
management plane layer.

**The consumers.** controller-runtime. Temporal on workflow ID reuse and
signals. The Kubernetes scheduler's bin packing plugins, for prior art.
