# Research

Everything needed to judge whether this project is worth building, collated from
primary sources so you do not have to read them. References are inline. Read in
order, roughly 90 minutes total.

| | | Time |
|---|---|---|
| [01](01-primer.md) | **The domain primer.** BMC, Redfish, in band versus out of band, the GPU software stack, NVLink domains, DCGM | 20 min |
| [02](02-gpu-failures.md) | **How GPUs actually fail.** XID codes, ECC, row remapping, the RMA rules, silent faults | 25 min |
| [03](03-evidence.md) | **What the failure data says.** Meta, ByteDance and Crusoe production numbers | 20 min |
| [04](04-operator-practice.md) | **How operators handle it today.** Burn-in, detection, remediation | 10 min |
| [05](05-utilisation.md) | **The other half.** Fragmentation, packing, and the public traces | 15 min |
| [06](06-prior-art.md) | **What already exists.** A deliberate attempt to make this project redundant | 15 min |
| [07](07-verdict.md) | **Verdict.** Whether to proceed, and what changes | 10 min |

## The short version

The problem is real and heavily documented. Meta logged 419 unexpected
interruptions in 54 days on 16,384 GPUs, 78% traced to hardware. ByteDance
logged 44,184 failures over three months, of which 5,948 were silent. Both then
built software to absorb them automatically, and both published how.

**Chapter 6 is the one that matters.** Going in, the project's premise was "none
of this can be tested". That premise is wrong in two specific ways, and the
honest version of the claim is narrower than what the build guide currently
says. Read chapter 6 before deciding anything.

The verdict is still proceed, but for a different reason than the one we
started with.
