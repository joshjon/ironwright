# Ironwright

A simulated GPU inference fleet that breaks in catalogued, citable ways on
demand, and a control plane that keeps it healthy and efficiently packed. The
simulator exists because fleet management software cannot otherwise be tested.

## Language

### The system

**Ironwright**:
The simulator. Serves the surfaces a real GPU host serves, backed by a fleet
model that changes over time and fails on demand.
_Avoid_: Emulator, mock, stub

**Anvil**:
The control plane. Drives a fleet toward declared intent and keeps it there.
Ironwright's flagship consumer, not its owner.
_Avoid_: Orchestrator, provisioner, scheduler (it contains one, it is not one)

**Fleet**:
The set of hosts in one simulator instance, and everything placed on them.

**Mode**:
Whether the simulator is reached over real HTTP listeners (*live mode*) or by an
in-process transport (*simulation mode*). The fleet model is identical in both.
Only the transport and the clock differ.

**Run**:
One execution of the simulator, identified by its configuration and seed. Two
runs with the same identity produce identical output.
_Avoid_: Session (means something specific in Redfish), execution

### Hardware

**Host**:
One physical machine, carrying some number of GPUs. The unit of identity, state,
health and admission.
_Avoid_: Node, server, machine, box

**Serial**:
A host's durable identity. Survives reimaging and re-enrolment, which is what
makes quarantine memory meaningful.

**GPU**:
An accelerator in a host. Visible twice and independently: out of band as a
Redfish `Processor` and `PCIeDevice`, in band as driver-level telemetry. The two
are allowed to disagree.

**NVLink domain**:
The set of GPUs within a host connected by NVLink. The boundary a single
deployment must fit inside, and therefore the unit placement cares about.

**BMC**:
The always-on management computer inside a host, reachable over the network even
when the host is powered off. What Redfish is served by.
_Avoid_: iDRAC, iLO, management controller

**Redfish**:
The DMTF standard REST API a BMC exposes. Carries power control and physical
inventory, and answers the question in-band cannot: is this machine dead, or
only its operating system?

**Out of band**:
Reached via the BMC, independent of the host's operating system. Sees physical
presence, power and temperature. Cannot see software.

**In band**:
Reached via software running on the host. Sees the driver stack and detailed GPU
telemetry. Silent when the host is off or the OS has wedged.

**Agent**:
The in-band surface of a host: its software stack inventory and its DCGM-shaped
telemetry.

**XID**:
An NVIDIA driver error code identifying a specific GPU fault. Some indicate
application bugs and some indicate dead hardware. telling them apart is a domain
decision, not a threshold.

**DCGM**:
NVIDIA's in-band GPU telemetry surface. The shape fleet monitoring actually
scrapes, and therefore the shape the simulator emits.

### Capacity

**Deployment**:
A model placed on a host, occupying a whole number of GPUs within one NVLink
domain. The unit of demand.
_Avoid_: Workload, job, pod, tenant

**Placement**:
The decision assigning a deployment to specific GPUs on a specific host, and the
record of that assignment. Held by the control plane. hardware never knows it.

**Occupancy**:
The GPU capacity a fleet is currently using, as *observed*, framebuffer
consumed, utilisation, power drawn. Distinct from placement, which is what the
control plane believes.

**Ghost allocation**:
Placement and occupancy disagreeing. A deployment the record says is running
that consumes nothing, or memory still held by something that died. Only
observable because occupancy is inferred rather than declared.

**Utilisation**:
The fraction of fleet GPUs doing useful work. The number the whole control plane
exists to keep high.

**Fragmentation**:
Free GPUs distributed such that a deployment cannot be placed despite sufficient
total capacity. Twelve free GPUs across four hosts will not host an eight-GPU
model.

**Defragmentation**:
Relocating deployments to consolidate free capacity. Always costs a restart and
a reload, so the decision is whether a move is worth its disruption, not whether
it is possible.

**Bin-packing**:
The placement policy that resists fragmentation by packing new deployments
tightly rather than spreading them.

### State

**Physical state**:
What the metal is currently doing, off, powering on, running. Owned by the
simulator, observable out of band.
_Avoid_: Power state (one axis of it), status

**Lifecycle state**:
What the operator has decided about a host, discovered, inventoried, staged,
validating, available, allocated, draining, quarantined, decommissioned. Owned
by the control plane, versioned, never visible to hardware.
_Avoid_: Host state (ambiguous between this and physical state)

**Health**:
An axis orthogonal to lifecycle state. A host can be allocated and unhealthy
simultaneously, which is the situation that makes fleet management hard.

**Burn-in**:
The validation a host passes before it may hold deployments. Structured as
escalating test classes across node and GPU domains.

**Test class**:
The stage a burn-in test belongs to: sanity, validation, performance, stress.
Each escalates in cost and in what it can detect.

**Admission**:
Permitting a host to hold deployments. The gate burn-in guards.

**Drain**:
Relocating every deployment off a host so it can be worked on, without dropping
capacity the fleet still owes.

**Quarantine**:
Exclusion from the available pool, keyed by serial, surviving reimaging. A lemon
with a fresh OS is still a lemon.

### Faults

**Fault**:
One distinct way a fleet misbehaves as observed from outside, sourced from a
real report and carrying its citation. The unit of the catalogue, of injection,
and of test assertions.
_Avoid_: Failure, error, chaos event, bug

**Fault catalogue**:
The complete set of faults, held as structured data, keyed by layer. Renders to
a document and compiles to the simulator's fault registry.

**Layer**:
The subsystem a fault belongs to: management plane, node, GPU, or software
stack. The catalogue's organising key, and the unit in which it is researched
and time-boxed.

**Fault parameters**:
The magnitude and timing knobs on a fault. `gpu.fell-off-bus` is a fault.
Whether it arrives instantly or over an hour is a parameter, not a second one.

**Injection**:
Causing a fault to occur. *Direct* injection names a host and a fault for a
specific test. *policy* injection describes a distribution over a fleet for a
chaos run.

**Fault lifecycle**:
A fault's onset, whether it arrives gradually, how long it lasts, and whether it
self-heals. A fault that clears in 200ms is a different test from one that
stays.

**Silent fault**:
A fault that passes every health check while degrading the host. The hardest
class to detect, and the reason passive health scoring is insufficient.
