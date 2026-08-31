# Scope is the fleet above the operating system

The project starts at a host that is already booted and reachable, as one
arrives from a colocation partner or a rented pool. Anvil owns everything above
that line: discovery, inventory, the driver and CUDA stack, burn-in, admission,
placement, health, remediation and decommission.

Deliberately out of scope, because each would otherwise read as an oversight:

- **OS install, PXE and virtual media.** Commoditised by Metal3, Ironic and
  Tinkerbell. Building it means a long stretch of work to reach parity.
- **Firmware.** Same reasoning, and it is the least observable part of the
  domain.
- **Cross host fabric (InfiniBand, RoCE, rail optimisation).** These set the
  speed of distributed training. This is an inference fleet, where a deployment
  fits inside one host's NVLink domain, so the interconnect that matters is
  intra host.
- **Multiple hardware providers behind one interface.** An abstraction is only
  demonstrated by two real implementations. One fleet modelled well beats two
  modelled shallowly.
- **Ironic and Metal3 compatibility.** Those are provisioning clients. Nothing
  above the OS is expressible to them.

Redfish stays at proportionate depth for the two jobs nothing else does: power
control, and telling a dead machine from a wedged OS when the agent goes quiet.
