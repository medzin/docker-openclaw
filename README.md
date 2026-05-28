# OpenClaw Docker Image for Unraid

This repository provides a custom Docker image for
[OpenClaw](https://openclaw.ai/), designed for Unraid and other systems where
file permissions on mounted volumes need to match a host UID and GID.

## Key Features

- **User/Group ID Mapping:** Supports `PUID` and `PGID` environment variables
  so OpenClaw writes appdata files as the expected host user.
- **Root Entrypoint:** Starts as root so setup and Unraid's Tailscale container
  hook can run, then drops to the mapped `node` user with `gosu`.
- **Tailscale State:** Defaults the Unraid Tailscale hook state directory to a
  persistent path under OpenClaw appdata.
- **Automated Updates:** A workflow checks upstream OpenClaw image tags on GHCR
  and builds missing Docker Hub tags.

## Usage

```bash
docker run -d \
  --name openclaw \
  -e PUID=99 \
  -e PGID=100 \
  -e UMASK=022 \
  -e OPENCLAW_GATEWAY_TOKEN=change-me \
  -p 18789:18789 \
  -p 18790:18790 \
  -v /mnt/user/appdata/openclaw:/home/node/.openclaw \
  -v /mnt/user/appdata/openclaw/auth-profile-secrets:/home/node/.config/openclaw \
  medzin/openclaw:latest
```

OpenClaw refuses to bind its gateway to a container-published address without
authentication. Set `OPENCLAW_GATEWAY_TOKEN` or `OPENCLAW_GATEWAY_PASSWORD`
before exposing the WebUI port.

## Environment Variables

| Variable | Description | Default |
| :------- | :---------- | :------ |
| `PUID` | User ID to run the OpenClaw process as. | `99` |
| `PGID` | Group ID to run the OpenClaw process as. | `100` |
| `UMASK` | Umask for file creation. | `022` |
| `OPENCLAW_GATEWAY_TOKEN` | Shared token required by the gateway. | unset |
| `OPENCLAW_GATEWAY_PASSWORD` | Password required by the gateway. | unset |
| `TAILSCALE_STATE_DIR` | Persistent Tailscale hook state directory. | `/home/node/.openclaw/.tailscale_state` |

The image follows the upstream OpenClaw container paths:

- OpenClaw state and config: `/home/node/.openclaw`
- OpenClaw workspace: `/home/node/.openclaw/workspace`
- Auth profile secrets: `/home/node/.config/openclaw`

The image also honors OpenClaw path override variables such as
`OPENCLAW_HOME`, `OPENCLAW_STATE_DIR`, `OPENCLAW_CONFIG_PATH`,
`OPENCLAW_CONFIG_DIR`, and `OPENCLAW_WORKSPACE_DIR`, but the Unraid template
intentionally does not expose them. If you override an internal path, update the
matching volume mount yourself.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE)
file for details.
