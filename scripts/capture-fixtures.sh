#!/usr/bin/env bash
# Captures golden telemetry from a real NVIDIA GPU host.
#
# Run on a rented H100 box. Copy the resulting fixtures/ directory back and
# commit it. Every capture is optional, failures are recorded rather than fatal.
#
#   curl -sSL <raw url of this file> | bash
#
set -uo pipefail

OUT="${1:-fixtures/$(hostname)-$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$OUT"
echo "capturing into $OUT"

cap() {
  local name="$1"; shift
  if "$@" > "$OUT/$name" 2> "$OUT/$name.err"; then
    rm -f "$OUT/$name.err"
    echo "  ok    $name"
  else
    echo "FAILED: $*" > "$OUT/$name"
    echo "  fail  $name"
  fi
}

# Driver level, in band
cap nvidia-smi-q.txt              nvidia-smi -q
cap nvidia-smi-ecc.txt            nvidia-smi -q -d ECC
cap nvidia-smi-row-remapper.txt   nvidia-smi -q -d ROW_REMAPPER
cap nvidia-smi-performance.txt    nvidia-smi -q -d PERFORMANCE
cap nvidia-smi-page-retirement.txt nvidia-smi -q -d PAGE_RETIREMENT
cap nvidia-smi-topo.txt           nvidia-smi topo -m
cap nvidia-smi-query.csv          nvidia-smi --query-gpu=index,name,uuid,serial,pci.bus_id,pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max,memory.total,memory.used,temperature.gpu,power.draw,clocks_throttle_reasons.active,ecc.errors.corrected.volatile.total,ecc.errors.uncorrected.volatile.total --format=csv

# Hardware enumeration, for the out of band comparison
cap lspci-nvidia.txt              bash -c "lspci -vvv -d 10de: 2>/dev/null || lspci -d 10de:"
cap nvidia-smi-version.txt        nvidia-smi --version
cap dmesg-xid.txt                 bash -c "dmesg 2>/dev/null | grep -i xid || echo 'no XID entries'"

# DCGM, the shape ironwright emits
cap dcgmi-discovery.txt           dcgmi discovery -l
cap dcgmi-dmon.txt                bash -c "timeout 10 dcgmi dmon -c 5"

echo "starting dcgm-exporter for a metrics scrape"
if command -v docker >/dev/null 2>&1; then
  docker run -d --rm --gpus all --name dcgm-exp -p 9400:9400 \
    nvcr.io/nvidia/k8s/dcgm-exporter:latest >/dev/null 2>&1 || true
  sleep 20
  cap dcgm-exporter-metrics.prom curl -sf http://localhost:9400/metrics
  docker stop dcgm-exp >/dev/null 2>&1 || true
else
  echo "FAILED: docker not available" > "$OUT/dcgm-exporter-metrics.prom"
  echo "  fail  dcgm-exporter-metrics.prom"
fi

# Provenance
{
  echo "captured_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "host: $(hostname)"
  echo "kernel: $(uname -r)"
  nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | sort -u | sed 's/^/gpu: /'
} > "$OUT/provenance.txt"

echo
echo "done. Copy $OUT back and commit it."
