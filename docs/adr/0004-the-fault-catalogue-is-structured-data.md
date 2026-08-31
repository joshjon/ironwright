# The fault catalogue is structured data

Every fault is a YAML entry carrying its identifier, layer, preconditions,
symptoms per surface, parameters, lifecycle, expected response and a citation.
The catalogue renders to a document and compiles to the simulator's fault
registry. It is not a document that a registry is written against separately.

A simulator is only as trustworthy as its failure modes are real. Prose beside a
separately written registry would let the two drift, and ironwright would
accumulate plausible but invented faults. Its audience has operated real fleets
and will recognise fiction.

## Consequences

The catalogue is written before the code it describes. Every fault carries its
citation in the code, so "that is not realistic" is answered with a link.
