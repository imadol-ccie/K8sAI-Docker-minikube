#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-balkanbgboy/k8s-ai-agent-minikube:v1.0}"

kubectl config view --flatten --minify \
  | sed -E "s|server: https?://[^ ]+|server: https://$(minikube ip):8443|" \
  > ./kubeconfig.flat
chmod 600 ./kubeconfig.flat

mkdir -p ./k8s

docker run --rm -it \
  --network minikube \
  -v "$PWD/kubeconfig.flat:/home/appuser/.kube/config:ro" \
  -v "$PWD/k8s:/app/k8s" \
  --env-file .env \
  "$IMAGE"
