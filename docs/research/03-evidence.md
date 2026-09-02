# 3. What the failure data says

Three organisations have published production numbers. This chapter is the
evidence the whole project rests on.

## 3.1 Meta, Llama 3, 16,384 GPUs, 54 days

Meta published reliability data from training Llama 3 405B [1]. The cluster was
16,384 H100s at 700W each with 80GB HBM3, on a three layer Clos network.

**466 job interruptions in 54 days.** 47 were planned maintenance. **419 were
unexpected.** That is roughly one unplanned interruption every three hours,
continuously, for two months.

The root cause breakdown:

| Root cause | Category | Count | Share |
|---|---|---|---|
| Faulty GPU | GPU | 148 | 30.1% |
| GPU HBM3 memory | GPU | 72 | 17.2% |
| Software bug | Dependency | 54 | 12.9% |
| Network switch or cable | Network | 35 | 8.4% |
| Host maintenance | Unplanned | 32 | 7.6% |
| GPU SRAM memory | GPU | 19 | 4.5% |
| GPU system processor | GPU | 17 | 4.1% |
| Other, 11 categories | Mixed | 92 | 13.2% |

Three numbers to take from this.

**GPU related causes were 55.9%** of unexpected interruptions once you add the
four GPU rows. **78% of unexpected interruptions were attributed to confirmed or
suspected hardware issues.** And despite all of it, Meta achieved **over 90%
effective training time**.

The number that most justifies this project is a different one:

> "Significant manual intervention was required only three times" in 54 days.

419 unexpected interruptions, three human interventions. That ratio is the
entire argument for automating fleet health. Meta did not have better hardware
than anyone else. They had software that absorbed failure without a person.

## 3.2 ByteDance, three months, 778,135 jobs

ByteDance published a far larger operational dataset in 2025 describing
ByteRobust, their training infrastructure management system [2]. It covers
**778,135 LLM training jobs over three months**.

Their taxonomy is the most useful part, and it is a distinction the original
build guide did not have:

**Explicit failures** are "characterized by clear diagnostic indicators, such as
error messages in stdout or stderr logs or specific exit codes". Something told
you.

**Implicit failures** "often manifest as job hang-ups, performance degradation,
or anomalous training trajectories, whose root causes are often elusive".
Nothing told you.

| Class | Symptom | Count | Share |
|---|---|---|---|
| Explicit | CUDA error | 19,968 | 36.1% |
| Explicit | CPU overload | 6,095 | 11.0% |
| Explicit | CPU OOM | 5,567 | 10.1% |
| Explicit | Insufficient disk | 2,755 | 5.0% |
| Explicit | InfiniBand error | 1,599 | 2.9% |
| **Implicit** | **Job hang** | **5,506** | **9.9%** |
| **Implicit** | **MFU decline** | **442** | **0.8%** |
| **Implicit** | **NaN values** | **148** | **0.3%** |
| Manual | Code or data adjustment | 9,582 | 17.3% |

Cumulatively they detected **38,236 explicit and 5,948 implicit failures**. GPU
related causes were roughly 36.4% of explicit failures.

Three findings matter to this project.

**Silent failure is about one in eight.** 5,948 of 44,184 total failures gave no
diagnostic indicator. Any health system built only on error counters misses that
fraction entirely. This is the citation for silent faults being real at scale.

**The same symptom has different causes.** For jobs over 2,000 GPUs in one
month, job hangs traced to 21 infrastructure causes and 5 user code causes.
Illegal memory access traced to 21 infrastructure and **41 user code** causes.
Their conclusion: "under the same symptoms, the root cause of failures can be
tangled among different aspects." You cannot pattern match a symptom to a
response. This is exactly the XID 13 versus XID 48 problem generalised.

**Detection time is where the value is.** Their real time inspection reduced
detection dramatically compared to waiting for timeouts:

| Failure | With inspection | Without |
|---|---|---|
| OS kernel fault | 2 seconds | timeout, 10 to 30 min |
| GPU driver hang | 10 seconds | timeout |
| NIC crash | 30 seconds | timeout |
| Port flapping | 30 seconds | timeout |
| Switch down | 60 seconds | timeout |

Their resolution strategy is also instructive. **Direct eviction via real time
checks resolved 32.52%** of failures, reattempts for transient faults recovered
22.70%, code rollbacks 9.20%, and expensive dual phase replay was needed for
only 1.23%. A cheap check applied first handles a third of everything.

The system achieved **97% effective training time ratio on 9,600 GPUs**.

## 3.3 Failure rate scales with fleet size

Crusoe publishes mean time between failures by cluster size [3]:

| GPUs | MTBF |
|---|---|
| 8 | 47 days |
| 1,024 | 8 hours |
| 16,384 | 1.8 hours |

This is the number that turns fleet health from a nice-to-have into
infrastructure. At eight GPUs a human handles failures as they arise. At sixteen
thousand, something fails every two hours forever, and there is no arrangement
of humans that keeps up.

## 3.4 What this establishes, and what it does not

**Established beyond argument.** Hardware failure at fleet scale is frequent,
GPU dominated, and a meaningful fraction of it is silent. Operators respond by
automating detection and remediation, and the ones who do it well report over
90% effective utilisation despite constant failure.

**Not established here.** That any of it is hard to *test*. Every source in this
chapter describes handling failures in production, not developing the software
that handles them. That gap is chapter 6.

---

**References**

1. The Llama 3 Herd of Models, Meta, 2024. Training infrastructure and
   reliability. https://arxiv.org/abs/2407.21783
   HTML: https://ar5iv.labs.arxiv.org/html/2407.21783
2. Robust LLM Training Infrastructure at ByteDance, SOSP '25.
   https://arxiv.org/abs/2509.16293
3. Crusoe, how we burn-in test every node.
   https://www.crusoe.ai/resources/blog/how-crusoe-burn-in-tests-every-node-before-it-reaches-you
