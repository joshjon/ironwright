# 6. What already exists

This chapter is a deliberate attempt to make the project redundant. The premise
going in was "none of this can be tested". That premise turned out to be wrong
in two specific ways, and this is the chapter to read before committing time.

## 6.1 NVIDIA already ships GPU fault injection

**This is the finding that most narrows the project.**

DCGM contains an error injection framework [1]. Against the `nv-hostengine`
daemon, `dcgmi test --inject` can inject:

- PCIe replay errors
- ECC errors, single and double bit
- Power excursions
- Thermal excursions
- **XID errors**
- NVLink errors

That is most of our GPU catalogue layer, shipped by the vendor, documented.

So the claim "you cannot make a GPU report XID 48 on demand" is **false**. With
a real GPU and DCGM running, you can. Any pitch built on that sentence would be
corrected in public by the first person who has read the DCGM docs.

What it does not do:

| | |
|---|---|
| **Needs real GPUs** | It injects into a daemon managing physical hardware |
| **Injects into DCGM's state** | Consumers of the DCGM API see the error. The driver is not actually failing, and out of band is untouched |
| **One machine** | No fleet, no second host, no topology |
| **No determinism** | No virtual clock, no seed, no replay |
| **No out of band surface** | Redfish does not exist in its world |
| **No occupancy** | It has no concept of what is running on the card |

## 6.2 Fleet scale placement simulation also already exists

The *Beware of Fragmentation* authors open sourced their evaluation harness [2],
and it is closer to half of this project than anything else found.

It is an **event driven Kubernetes scheduler simulator**. It ingests Alibaba
production traces, manages node and pod lifecycle through the API server, and
runs "high-fidelity simulation... in a large cluster consisting of tens of
thousands of GPUs within a few hours". It implements FGD plus best-fit,
dot-product, GPU packing, GPU clustering and random-fit baselines. It also has a
real deployment mode that can drive an actual cluster.

What it does not do, and this is explicit: **no hardware health, no GPU
failures, no telemetry, no network model.** It is a placement policy evaluator.
Nodes never degrade. GPUs never fail. Nothing is ever unhealthy.

127 stars, a research artifact rather than production software.

## 6.3 A GPU datacenter simulator exists, for humans

`dc-lab-sim` [3] simulates an 8 node DGX SuperPOD with 64 GPUs across six
hardware generations. It injects faults, and the description is uncomfortably
close to ours: when a scenario says GPU 3 has an XID 48 error, every simulated
tool shows it. React and TypeScript, 749 commits, nearly 4,000 tests.

It is a **training environment for humans sitting the NCP-AII certification
exam**. It simulates the terminal output an engineer would see, through 40
narrative scenarios and spaced repetition flashcards. There is no API for
software to consume, no CI integration, no Redfish (it emulates legacy
`ipmitool`), and no stated software testing use case.

It proves people want simulated GPU fleets. It does not test control plane
software, and it could not.

## 6.4 The rest

**sushy-tools** is the Redfish emulator Metal3 and Ironic test against. Backed by
libvirt, one VM per BMC, documented as development use only. No GPU concept, no
fault injection, no determinism.

**NVBitFI and SASSIFI** inject faults into GPU program execution at the
instruction level, for neural network reliability research. A different layer
entirely, concerned with whether a model's output survives a bit flip, not with
fleet management.

**FoundationDB, TigerBeetle's VOPR, Antithesis** established deterministic
simulation testing as a technique: virtual clock, seeded RNG, single process,
time compressed by orders of magnitude. All applied to storage and network, none
to hardware fleets. This is where our determinism design comes from, and it is
borrowed rather than invented.

## 6.5 The coverage map

| Capability | DCGM inject | k8s sched sim | dc-lab-sim | sushy-tools | This project |
|---|---|---|---|---|---|
| Injects GPU faults | yes | no | yes | no | yes |
| Needs no real hardware | **no** | yes | yes | yes | yes |
| Fleet scale | no | yes | 8 nodes | no | yes |
| Models placement and occupancy | no | yes | no | no | yes |
| Models hardware health | yes | **no** | yes | no | yes |
| **Health and occupancy together** | **no** | **no** | **no** | **no** | **yes** |
| Deterministic replay | no | partial | no | no | yes |
| Out of band surface | no | no | IPMI only | yes | yes |
| Consumable by software | yes | yes | **no** | yes | yes |

## 6.6 The honest conclusion

**Every individual capability this project needs already exists somewhere.**
Fault injection exists. Fleet scale placement simulation exists. Redfish
emulation exists. Deterministic simulation exists as a technique.

What does not exist anywhere is **a fleet that is simultaneously occupied and
degrading**.

That gap is not cosmetic. Every genuinely difficult decision in fleet management
lives precisely at that intersection:

- Do I place this model onto a card whose ECC rate is climbing?
- This host needs draining. Where do its six deployments go, and is there room?
- Consolidating these two deployments frees a host, but one of them sits on a
  GPU with a pending row remap. Do I move it, or wait for the reset it needs
  anyway?
- The scheduler says this GPU is free. Telemetry says 40GB is still allocated.
  Which do I believe?

None of those questions can even be *asked* of a simulator that models health
without occupancy, or occupancy without health. That is the project.

---

**References**

1. DCGM error injection framework, NVIDIA.
   https://docs.nvidia.com/datacenter/dcgm/3.0/user-guide/dcgm-error-injection.html
2. Kubernetes scheduler simulator, HKUST ADSL.
   https://github.com/hkust-adsl/kubernetes-scheduler-simulator
3. dc-lab-sim. https://github.com/Seanbo5386/dc-lab-sim
4. TigerBeetle VOPR.
   https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/internals/vopr.md
5. Deterministic simulation testing, overview.
   https://notes.eatonphil.com/2024-08-20-deterministic-simulation-testing.html
