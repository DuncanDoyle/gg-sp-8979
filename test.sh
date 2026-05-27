#!/bin/sh
#
# Reproducer for solo-projects#8979:
#   grpcjson plugin silently passes invalid protoDescriptorBin to Envoy,
#   causing an xDS RouteConfiguration NACK cascade.
#
# Steps:
#   1. Confirm healthy baseline with the valid descriptor
#   2. Patch the Upstream to a corrupt descriptor
#   3. Show the false-positive Accepted status (the bug)
#   4. Show the NACK storm in proxy logs and xDS metrics

set -e

GLOO_POD=$(kubectl get pod -n gloo-system -l gloo=gloo -o jsonpath='{.items[0].metadata.name}')
PROXY_POD=$(kubectl get pod -n gloo-system \
  -l "gateway.networking.k8s.io/gateway-name=grpc-nack-gw" \
  -o jsonpath='{.items[0].metadata.name}')

# ---------------------------------------------------------------------------
# Step 1 — Healthy baseline
# ---------------------------------------------------------------------------
printf "\n=== Step 1: Verify healthy baseline (valid protoDescriptorBin) ===\n"

printf "\nUpstream status (expect: Accepted):\n"
kubectl get upstream -n gloo-system demo-backend \
  -o jsonpath='{.status.statuses.gloo-system.state}{"\n"}'

printf "\nxDS insync / NACK metrics for RouteConfiguration (expect: insync=1, no nack line):\n"
kubectl exec -n gloo-system "$GLOO_POD" -- \
  wget -qO- http://localhost:9091/metrics \
  | grep -E "xds_nack|xds_insync" | grep -i "Route" || true

# ---------------------------------------------------------------------------
# Step 2 — Inject corrupt descriptor
# ---------------------------------------------------------------------------
printf "\n=== Step 2: Apply Upstream with corrupt protoDescriptorBin ===\n"
kubectl apply -f upstreams/demo-backend-upstream-corrupt.yaml

# ---------------------------------------------------------------------------
# Step 3 — Upstream status: false positive
# ---------------------------------------------------------------------------
printf "\n=== Step 3: Upstream status after corrupt patch ===\n"
printf "\nExpected: Error\n"
printf "Actual (bug — should be Error but reports Accepted):\n"
kubectl get upstream -n gloo-system demo-backend \
  -o jsonpath='{.status.statuses.gloo-system.state}{"\n"}'

# ---------------------------------------------------------------------------
# Step 4 — NACK storm evidence
# ---------------------------------------------------------------------------
printf "\n=== Step 4: Wait 15 seconds for NACK storm to build up ===\n"
sleep 15

printf "\nProxy logs (expect repeated 'Unable to parse proto descriptor'):\n"
kubectl logs -n gloo-system "$PROXY_POD" --tail=10 | grep -i "transcod" || true

printf "\nxDS insync / NACK metrics (expect: insync=0, nack=1):\n"
kubectl exec -n gloo-system "$GLOO_POD" -- \
  wget -qO- http://localhost:9091/metrics \
  | grep -E "xds_nack|xds_insync" | grep -i "Route" || true

printf "\nEnvoy RDS rejected counter (expect a large and still-growing number):\n"
kubectl exec -n gloo-system "$PROXY_POD" -- \
  wget -qO- http://localhost:19000/stats \
  | grep "rds.*rejected" || true

printf "\nReproducer complete.\n"
