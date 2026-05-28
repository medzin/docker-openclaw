ARG OPENCLAW_VERSION=latest
FROM ghcr.io/openclaw/openclaw:${OPENCLAW_VERSION}

USER root

RUN apt-get update \
  && apt-get install -y --no-install-recommends gosu ca-certificates passwd \
  && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENV HOME=/home/node \
    OPENCLAW_HOME=/home/node \
    OPENCLAW_STATE_DIR=/home/node/.openclaw \
    OPENCLAW_CONFIG_PATH=/home/node/.openclaw/openclaw.json \
    OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
    OPENCLAW_WORKSPACE_DIR=/home/node/.openclaw/workspace \
    TAILSCALE_STATE_DIR=/home/node/.openclaw/.tailscale_state \
    PUID=99 \
    PGID=100 \
    UMASK=022

ENTRYPOINT ["tini", "-s", "--", "/docker-entrypoint.sh"]
CMD ["node", "openclaw.mjs", "gateway", "run", "--allow-unconfigured", "--bind", "auto"]
