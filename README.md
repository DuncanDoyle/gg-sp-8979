# Reproducer: grpcjson plugin passes invalid protoDescriptorBin to Envoy (solo-projects#8979)

**Issue**: https://github.com/solo-io/solo-projects/issues/8979
**Zendesk**: https://solo-io.zendesk.com/agent/tickets/8826
**Version**: Gloo Gateway Enterprise 1.20.5

## Bug Summary

When a Gloo `Upstream` with `grpcJsonTranscoder` has a corrupt or invalid `protoDescriptorBin`, the control plane:
1. Reports `status.state: Accepted` — a false positive; it should return `Error`
2. Pushes the bad config to Envoy, which NACKs the entire `RouteConfiguration` and retries ~10×/second indefinitely

This NACK storm blocks all subsequent xDS routing updates (new routes, timeout changes, header rules) and delays EDS updates, causing traffic to be sent to stale pod IPs during deployments. Setting `fullEnvoyValidation: true` does **not** prevent this in kubeGateway (HTTPRoute) mode.

## Expected Behavior

When `protoDescriptorBin` cannot be parsed as a valid `FileDescriptorSet`, Gloo should:
- Return an error from `ProcessUpstream` at translation time
- Set `status.state: Error` on the `Upstream`
- Exclude the Upstream from the xDS snapshot pushed to Envoy

## Actual Behavior

- `status.state: Accepted` (false positive)
- Envoy logs flood with `transcoding_filter: Unable to parse proto descriptor`
- xDS NACK counter for `RouteConfiguration` grows at ~10/second

## Prerequisites

- A running Kubernetes cluster with `kubectl` pointing at it
- `helm`
- Gloo EE license key in `$GLOO_GATEWAY_LICENSE_KEY`
- Gloo EE Helm repo: `helm repo add glooe https://storage.googleapis.com/gloo-ee-helm`

## Steps to Reproduce

**1. Install Gloo Gateway**

```sh
export GLOO_GATEWAY_LICENSE_KEY=<your-license-key>
cd install
./install-gloo-gateway-with-helm.sh
```

**2. Deploy resources**

```sh
./setup.sh
```

**3. Run the test**

```sh
cd ..
./test.sh
```

The test script:
- Verifies the healthy baseline (valid `protoDescriptorBin`, `insync=1`, no NACK)
- Patches the Upstream to a corrupt descriptor
- Shows that `status.state` still reads `Accepted` (the bug)
- Waits and then shows proxy log flooding and the NACK metric

## Resource Overview

| Resource | Namespace | Purpose |
|---|---|---|
| `Gateway` (grpc-nack-gw) | gloo-system | K8S Gateway API entry point |
| `Deployment/Service` (demo-backend) | grpc-demo | Stand-in backend; actual gRPC calls are not needed to trigger the bug |
| `Upstream` (demo-backend) | gloo-system | grpcJsonTranscoder config — corrupt `protoDescriptorBin` triggers the NACK |
| `ReferenceGrant` | gloo-system | Allows the HTTPRoute in grpc-demo to reference the Upstream in gloo-system |
| `HTTPRoute` (demo-backend-route) | grpc-demo | Routes all traffic to the Upstream |
