# 7. Verdict

## 7.1 Proceed, but the claim changes

The problem is real and the evidence for it is strong. Chapters 3 and 4 are
backed by production numbers from Meta, ByteDance and Crusoe, and none of it is
seriously disputable.

The *novelty* claim needed rewriting, because chapter 6 falsified the one we
started with.

**Retire this claim.** "Nobody can make hardware fail on demand, so provisioning
and fleet code cannot be tested." NVIDIA ships fault injection in DCGM. Stating
this publicly would get the project corrected by the first reader who knows the
tooling.

**Use this one instead.**

> Every capability exists in isolation. Fault injection needs real hardware and
> covers one machine. Fleet simulation covers placement but models no hardware
> health. Nothing simulates a fleet that is simultaneously occupied and
> degrading, which is where every hard decision in fleet management lives.

It is a narrower claim. It is also more interesting, because the interaction is
the actual difficulty rather than either half alone.

## 7.2 What this changes about the build

Four concrete changes fall out of the research.

**1. Use the Alibaba traces. Do not synthesise workloads.** Four public GPU
cluster traces exist, including an inference serving trace with 20,000+
instances and a six month trace covering 155,410 GPUs. Driving arrivals and
departures from real production data answers "your workload is made up" for the
cost of a download, and removes a whole category of work.

**2. State the DCGM overlap in the README.** Being first to say "DCGM already
injects GPU faults on real hardware, here is what we add" converts the weakness
into evidence of rigour. Being second to say it is embarrassing.

**3. The proof point moves later than slice 1.** The differentiator only exists
once health and occupancy are both present and interacting. Slice 1 alone is a
worse DCGM. The first genuinely novel demo is the one where a degrading GPU
forces a placement decision, which is slice 3 into 4.

**4. Read the scheduler simulator before writing placement.** It implements six
placement policies against real traces and is open source. Borrow the
formulation rather than reinventing it, and spend the effort on the health
interaction that it lacks.

## 7.3 Risks, honestly

**Fragmentation is the weakest half.** The literature studies fractional GPU
sharing. We model whole GPU allocation in an NVLink domain, a simpler case. The
problem is real, its severity in our shape is unproven. If one thing gets
derisked first, this is it.

**The differentiator is an intersection, not a feature.** "Nobody combines these
two" is a weaker position than "nobody does this at all". It is defensible, but
it depends on the combination genuinely producing decisions neither half can
express. If the interaction turns out to be shallow, the project is two existing
things stapled together.

**Adoption remains unlikely.** Nothing in this research changes that. Build it
because the problem is interesting and the skills are real, not because
operators will switch.

## 7.4 The checkpoint

Build to **slice 4**, where a health event forces a placement decision, and
reassess there.

That is the first point at which the thing does something no existing tool can
do, and it is much earlier than the full seven slice plan. If the interaction
feels thin when you get there, stop, and you will have spent a fraction of the
budget finding out.

## 7.5 What to do next

1. Read chapters 1 and 2 properly. They are the domain knowledge, and everything
   after depends on them.
2. Skim chapter 6's references, particularly the DCGM injection docs and the
   scheduler simulator, and confirm the coverage map independently.
3. Download `cluster-trace-gpu-v2025` and look at its shape. It is the workload
   model.
4. Then slice 0.
