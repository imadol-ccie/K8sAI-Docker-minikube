FROM python:3.12-slim

# Pin kubectl for reproducible builds; bump on purpose.
ARG KUBECTL_VERSION=v1.30.5

# 1) Runtime deps + kubectl, all in one layer, with apt cache cleaned.
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates \
    && curl -fsSLo /usr/local/bin/kubectl \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && curl -fsSLo /tmp/kubectl.sha256 \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256" \
    && echo "$(cat /tmp/kubectl.sha256)  /usr/local/bin/kubectl" | sha256sum -c - \
    && chmod +x /usr/local/bin/kubectl \
    && rm -f /tmp/kubectl.sha256 \
    && rm -rf /var/lib/apt/lists/*

# 2) Deterministic UID/GID with a real home. Build args let consumers override
#    if their host kubeconfig is owned by a different UID.
ARG APP_UID=1000
ARG APP_GID=1000
RUN groupadd -g ${APP_GID} appuser \
 && useradd  -u ${APP_UID} -g ${APP_GID} -m -s /usr/sbin/nologin appuser

WORKDIR /app

# 3) Build wheels as root, then strip the toolchain so it doesn't ship.
COPY requirements.txt .
RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
    && pip install --no-cache-dir -r requirements.txt \
    && apt-get purge -y build-essential \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# 4) App code owned by appuser so the runtime can write /app if it needs to
#    (caches, temp YAML like the /tmp/tmp*.yaml the agent already creates).
COPY --chown=appuser:appuser . .

# 5) Explicit env so kubectl's lookup is unambiguous, even when the agent
#    spawns kubectl via subprocess with a partially cleared environment.
ENV HOME=/home/appuser \
    KUBECONFIG=/home/appuser/.kube/config

# 6) Self-document the expected mount.
LABEL org.opencontainers.image.documentation="\
Mount kubeconfig at /home/appuser/.kube/config (chown 1000:1000, mode 0600). \
Run with: -v /path/to/kubeconfig:/home/appuser/.kube/config:ro --network host"

USER appuser:appuser

CMD ["python", "app.py"]