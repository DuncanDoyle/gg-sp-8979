#!/bin/sh
#
# Deploys the Gloo Edge API VirtualService for the demo-backend Upstream.
#
# Run this AFTER reproducing the bug with test.sh.
#
# With fullEnvoyValidation: true, the validating webhook correctly blocks a corrupt
# protoDescriptorBin when a VirtualService routes to the Upstream. This is the contrast
# to the K8S Gateway API (HTTPRoute) mode where the webhook does NOT catch the corrupt
# descriptor and the NACK cascade occurs.
#
# Applying upstreams/demo-backend-upstream-corrupt.yaml while this VirtualService is active
# should result in status.state: Error on the Upstream (correct behavior, bug absent).

pushd ..

printf "\nDeploy VirtualService ...\n"
kubectl apply -f virtualservices/demo-backend-vs.yaml

printf "\nDone. The validating webhook should now block corrupt Upstream updates.\n"
printf "Try: kubectl apply -f upstreams/demo-backend-upstream-corrupt.yaml\n"

popd
