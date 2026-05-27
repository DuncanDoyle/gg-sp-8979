#!/bin/sh

export GLOO_GATEWAY_VERSION="1.20.5"
export GLOO_GATEWAY_HELM_VALUES_FILE="gloo-gateway-helm-values.yaml"

if [ -z "$GLOO_GATEWAY_LICENSE_KEY" ]
then
   echo "Gloo Gateway License Key not specified. Please configure the environment variable 'GLOO_GATEWAY_LICENSE_KEY' with your Gloo Gateway License Key."
   exit 1
fi

# Install the Kubernetes Gateway API CRDs (v1.1.0 as used in the issue report)
printf "\nApply K8S Gateway CRDs ...\n"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

# Install Gloo Gateway EE in kubeGateway mode with the classic proxy disabled
printf "\nInstall Gloo Gateway ...\n"
helm upgrade --install gloo glooe/gloo-ee \
  --namespace gloo-system --create-namespace \
  --set-string license_key=$GLOO_GATEWAY_LICENSE_KEY \
  -f $GLOO_GATEWAY_HELM_VALUES_FILE \
  --version $GLOO_GATEWAY_VERSION \
  --wait --timeout 5m
