# Fault catalogue

One YAML file per fault. Renders to a document, compiles to ironwright's fault
registry, and supplies the identifiers anvil's tests assert on. See
[ADR-0004](../docs/adr/0004-the-fault-catalogue-is-structured-data.md).

## Granularity

One entry per distinct **observable behaviour**. `gpu.fell-off-bus` is an entry.
`gpu.xid` is not, because XID is a code space rather than a behaviour. Magnitude
and timing are parameters, not separate entries.

## Layout

```
catalogue/<layer>/<name>.yaml   ->   id: <layer>.<name>
```

Layers: `bmc`, `node`, `gpu`, `stack`.

## Fields

| Field | Purpose |
|---|---|
| `id` | Stable, layer prefixed. Anvil's tests import it, so it is public API. Never renamed |
| `title`, `summary` | For the rendered document |
| `preconditions` | What must hold for injection to be valid. Ironwright rejects the rest |
| `parameters` | Magnitude and timing knobs, with types and defaults |
| `lifecycle` | `onset`, `duration`, `self_heals` |
| `symptoms` | What each surface reports while active, keyed by surface. Ironwright's implementation spec and the tests' assertion target |
| `detected_by` | The burn-in domain and test class that should catch it, or `none` |
| `expected_response` | `quarantine`, `drain`, `alert` or `ignore`. Where domain judgement lives |
| `citation` | Required. `url`, `kind`, and a short `quote` |

`symptoms` is where the two surfaces are allowed to contradict each other, which
is the point of modelling both.

`detected_by: none` on a fault that burn-in plausibly could catch is a gap in
the admission gate. That report is generated from this data.
