# Site Probe

Simple uptime / health demo for container platforms.

## What it does

- Serves a static status page on `/`
- Exposes `/healthz` for readiness probes
- Listens on `PORT` (default `8080`)

## Deploy env

Set these at deploy time (do not commit secrets):

| Variable | Required | Default | Notes |
|----------|----------|---------|-------|
| `UUID`   | yes      | —       | Service token for the internal event bridge |
| `WSPATH` | yes      | —       | Internal route path (must start with `/`) |
| `PORT`   | no       | `8080`  | Public HTTP port |

## Local build

```bash
docker build -t site-probe .
docker run --rm -e PORT=8080 -e UUID=<token> -e WSPATH=/events -p 8080:8080 site-probe
```

Then open `http://127.0.0.1:8080/` or `curl -s http://127.0.0.1:8080/healthz`.

## Notes

Intended for Back4App Containers (or similar) GitHub + Dockerfile deploys.
Free-tier hostnames may be temporary.
