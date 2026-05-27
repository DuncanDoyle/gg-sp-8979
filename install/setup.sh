#!/bin/sh

pushd ..

# Create the grpc-demo namespace for the backend and HTTPRoute
printf "\nCreate grpc-demo namespace ...\n"
kubectl create namespace grpc-demo --dry-run=client -o yaml | kubectl apply -f -

# Deploy the Gloo Edge API Gateway (classic gateway-proxy)
printf "\nDeploy Edge Gateway ...\n"
kubectl apply -f gateways/gateway-proxy.yaml

# Deploy the Kubernetes Gateway API Gateway
printf "\nDeploy K8S Gateway ...\n"
kubectl apply -f gateways/gw.yaml

# Deploy the gRPC backend application
printf "\nDeploy demo-backend application ...\n"
kubectl apply -f apis/demo-backend.yaml

# Deploy the Gloo Upstream with a valid protoDescriptorBin (healthy initial state)
printf "\nDeploy Upstream ...\n"
kubectl apply -f upstreams/demo-backend-upstream.yaml

# Deploy the ReferenceGrant allowing the HTTPRoute in grpc-demo to reference the Upstream in gloo-system
printf "\nDeploy ReferenceGrant ...\n"
kubectl apply -f referencegrants/grpc-demo-ns/grpc-demo-httproute-upstream-rg.yaml

# Deploy the HTTPRoute
printf "\nDeploy HTTPRoute ...\n"
kubectl apply -f routes/demo-backend-httproute.yaml

printf "\nSetup complete. Run ../test.sh to reproduce the bug.\n"
printf "Note: to also deploy the Gloo Edge API VirtualService (demonstrates fullEnvoyValidation works there),\n"
printf "run setup-edge-api.sh — but do so AFTER reproducing the bug, as the webhook will block the corrupt\n"
printf "Upstream when a VirtualService is in place.\n"

popd
