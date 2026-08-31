# The live and simulation seam is an HTTP RoundTripper

Anvil always holds an `*http.Client`. In live mode it carries a real transport.
In simulation mode it carries a `RoundTripper` that synchronously invokes the
simulator's `http.Handler` and returns the recorded response. No listener, no
sockets, no goroutines.

This keeps the full wire contract (status codes, headers, ETags, JSON round
trip) while staying single threaded enough to replay byte identically.

## Considered options

**A Go interface above Redfish**, backed by the fleet model in simulation mode.
Rejected because simulation mode would never run the real client or serialise
JSON, so every bug class the simulator exists to catch would be invisible in CI.

**An in-memory `net.Conn`.** Rejected because `http.Server` and `http.Transport`
run their own goroutines and timers, so the Go scheduler still decides
interleaving.

## Consequences

The seam covers every surface the simulator exposes, since all are HTTP. Adding
a surface costs a handler, not an architecture. TLS and listeners become a thin
live mode wrapper rather than a design concern.
