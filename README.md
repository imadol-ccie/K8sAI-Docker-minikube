# Kubernetes AI Agent

A Python AI agent powered by Google Gemini that creates Kubernetes Deployments and Services via natural language. Generated YAML is written to `./k8s/` on the host so you can review, edit, or commit it.

## Prerequisites

- Docker
- `minikube` and `kubectl` on the host
- A Google Gemini API key

## Quick Start

```bash
# 1. Clone
git clone https://github.com/balkanbgboy/k8s-ai-agent K8sAI-Docker-minikube
cd K8sAI-Docker-minikube

# 2. Create .env with your API key
echo "GOOGLE_API_KEY=your_key_here" > .env

# 3. Start minikube on the docker driver (run.sh assumes this)
minikube start --driver=docker

# 4. Build the image (or pull from Docker Hub)
docker build -t balkanbgboy/k8s-ai-agent-minikube:v1.0 .
# docker pull balkanbgboy/k8s-ai-agent-minikube:v1.0

# 5. Run
chmod +x ./run.sh
./run.sh
```

`run.sh` handles the kubeconfig flattening, the docker network, volume mounts, and `--env-file`. It regenerates `kubeconfig.flat` on every run, so context switches and minikube IP changes are picked up automatically.

## Usage

```
🤖 Kubernetes AI Agent Initialized

💡 What should I do? (or 'exit'): create a deployment named web-app with nginx image and 3 replicas
```

The agent supports:
- Creating Deployments: `create a deployment named <name> with <image> image and <n> replicas`
- Creating Services: `create a service for <name> on port <port>`

Each successful apply writes a manifest to `./k8s/<name>-deployment.yaml` or `./k8s/<name>-service.yaml`.

## How it Works

`run.sh` does three things the container can't do itself:

1. **Flattens your kubeconfig** with `kubectl config view --flatten --minify` so the cluster CA and client certs are embedded inline (minikube's default kubeconfig references files under `~/.minikube/`, which don't exist inside the container).
2. **Rewrites the API server URL** to `https://$(minikube ip):8443` so the container can reach minikube directly instead of via a forwarded localhost port.
3. **Joins the `minikube` docker network** with `--network minikube` so `192.168.49.2:8443` is routable from inside the container.

## Notes and Caveats

- **Driver assumption.** `run.sh` joins the `minikube` docker network. If you use `--driver=virtualbox`, `hyperv`, or others, you'll need to adapt the `--network` flag and the IP/port substitution.
- **UID 1000.** The container runs as `appuser` (UID 1000). If your host user isn't UID 1000, writes into `./k8s` will fail with a permission error — fix with `chown 1000:1000 ./k8s` (or `chmod 777 ./k8s` for quick testing).
- **Sensitive files.** `kubeconfig.flat` embeds your cluster certs and `.env` holds your API key — both are in `.gitignore` and should stay there.
- **Image override.** `run.sh` defaults to `balkanbgboy/k8s-ai-agent-minikube:v1.0`. Use a different tag with `IMAGE=mytag ./run.sh`.

## Manual Run (without run.sh)

If you'd rather not use the script:

```bash
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
  balkanbgboy/k8s-ai-agent-minikube:v1.0
```

## Contributors

- balkanbgboy
