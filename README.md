Automatically builds a Docker image including [Caddy][1], [caddy-docker-proxy][2],
and the [Cloudflare DNS plugin][3].

[1]: https://github.com/caddyserver/caddy
[2]: https://github.com/lucaslorentz/caddy-docker-proxy
[3]: https://github.com/caddy-dns/cloudflare

A daily check rebuilds the image when any of them publishes a new release.
Base image updates come in as Dependabot PRs and rebuild the image when merged.
It's published for `linux/amd64` and `linux/arm64` as:

```
ghcr.io/dave-atx/caddy-docker-proxy/caddy-proxy
```

## Tags and versions

| Tag | Meaning |
| --- | --- |
| `latest` | The most recent build. |
| `YYYYMMDD` | The build from that date. |
| `caddy-2.11.9` | The most recent build of that Caddy version. Moves when a plugin updates. |
| `caddy-2.11.9-proxy-2.13.1-cloudflare-0.2.4` | One exact set of component versions. |

The [package page][pkg] shows the component versions in the description and
the tag list, and each workflow run's summary lists what it published. To read
them from an image you've already pulled:

```sh
docker image inspect ghcr.io/dave-atx/caddy-docker-proxy/caddy-proxy:latest \
  --format '{{range $k, $v := .Config.Labels}}{{$k}}={{$v}}{{"\n"}}{{end}}' | grep version
```

(`podman image inspect` takes the same arguments.)

[pkg]: https://github.com/dave-atx/caddy-docker-proxy/pkgs/container/caddy-docker-proxy%2Fcaddy-proxy

## Running with Docker

Caddy watches the Docker socket and builds its config from labels on your
other containers, which need to share a network with it:

```sh
docker network create caddy

docker run -d --name caddy --restart unless-stopped \
  --network caddy \
  -p 80:80 -p 443:443 -p 443:443/udp \
  -e CADDY_INGRESS_NETWORKS=caddy \
  -e CLOUDFLARE_API_TOKEN=your-token \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v caddy_data:/root/.local/share/caddy \
  ghcr.io/dave-atx/caddy-docker-proxy/caddy-proxy:latest

docker run -d --name whoami --network caddy \
  --label caddy=whoami.example.com \
  --label 'caddy.reverse_proxy={{upstreams 80}}' \
  --label 'caddy.tls.dns=cloudflare {env.CLOUDFLARE_API_TOKEN}' \
  traefik/whoami
```

Or with Compose:

```yaml
services:
  caddy:
    image: ghcr.io/dave-atx/caddy-docker-proxy/caddy-proxy:latest
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    environment:
      CADDY_INGRESS_NETWORKS: caddy
      CLOUDFLARE_API_TOKEN: ${CLOUDFLARE_API_TOKEN}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - caddy_data:/root/.local/share/caddy
    networks:
      - caddy

  whoami:
    image: traefik/whoami
    networks:
      - caddy
    labels:
      caddy: whoami.example.com
      caddy.reverse_proxy: "{{upstreams 80}}"
      caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

networks:
  caddy:
    name: caddy

volumes:
  caddy_data:
```

The `caddy_data` volume holds certificates and ACME account keys. Keep it
around across upgrades, or Caddy will request new certificates every time.

## Running with Podman

caddy-docker-proxy works with Podman's Docker-compatible API socket. These
steps assume rootless Podman.

1. Enable the API socket:

   ```sh
   systemctl --user enable --now podman.socket
   ```

2. Rootless containers can't bind ports below 1024 by default. Either lower
   the limit (as root):

   ```sh
   echo 'net.ipv4.ip_unprivileged_port_start=80' | sudo tee /etc/sysctl.d/99-unprivileged-ports.conf
   sudo sysctl --system
   ```

   or publish high ports (`-p 8080:80 -p 8443:443`) and forward to them.

3. Mount the Podman socket where Caddy expects the Docker socket.
   `--security-opt label=disable` is only needed on SELinux hosts:

   ```sh
   podman network create caddy

   podman run -d --name caddy --restart unless-stopped \
     --network caddy \
     -p 80:80 -p 443:443 -p 443:443/udp \
     -e CADDY_INGRESS_NETWORKS=caddy \
     -e CLOUDFLARE_API_TOKEN=your-token \
     -v "$XDG_RUNTIME_DIR/podman/podman.sock:/var/run/docker.sock:ro" \
     --security-opt label=disable \
     -v caddy_data:/root/.local/share/caddy \
     ghcr.io/dave-atx/caddy-docker-proxy/caddy-proxy:latest

   podman run -d --name whoami --network caddy \
     --label caddy=whoami.example.com \
     --label 'caddy.reverse_proxy={{upstreams 80}}' \
     --label 'caddy.tls.dns=cloudflare {env.CLOUDFLARE_API_TOKEN}' \
     docker.io/traefik/whoami
   ```

On Podman 4.9 (and probably other versions), caddy-docker-proxy can't follow
the event stream and logs `Docker events error: EOF`. It falls back to polling,
so label changes can take up to 30 seconds to show up. Set
`-e CADDY_DOCKER_POLLING_INTERVAL=5s` if that's too slow.

Podman has no daemon, so `--restart unless-stopped` won't bring the containers
back after a reboot. Run them as systemd services with Quadlet instead (see
`man podman-systemd.unit`).

## Building locally

The Dockerfile needs the component versions as build args:

```sh
docker build \
  --build-arg CADDY_VERSION=v2.11.9 \
  --build-arg PROXY_VERSION=v2.13.1 \
  --build-arg CLOUDFLARE_VERSION=v0.2.4 \
  -t caddy-proxy .
```

`podman build` takes the same arguments.
