# AGENTS.md

Notes for changing this repo. See the README for using the image.

## How the build decides what to do

`check-updates` looks up the latest Caddy, caddy-docker-proxy, and
caddy-dns/cloudflare versions, then reads the `org.marquard.*.version` labels
off the `:latest` image in ghcr. Scheduled runs only build when those differ;
pushes, PRs, and manual runs always build.

- Don't rename the `org.marquard.caddy.version`,
  `org.marquard.caddy-docker-proxy.version`, or
  `org.marquard.caddy-dns-cloudflare.version` labels. The check would see a
  mismatch on every run and rebuild daily.
- caddy-dns/cloudflare publishes tags but no GitHub releases, and the tags API
  isn't ordered, so its version is the highest stable semver tag.

## Dockerfile

- `CADDY_VERSION`, `PROXY_VERSION`, and `CLOUDFLARE_VERSION` are required build
  args. xcaddy builds exactly those versions and the labels come from the same
  args, so the labels can't drift from the binary. Passing them is also what
  busts the gha layer cache when only a plugin updates.
- Both base images are pinned by digest. Dependabot updates the pins; don't go
  back to floating tags, since Dependabot can't bump those and the cache would
  hide upstream changes.
- No HEALTHCHECK on purpose. Distroless has no curl / wget, and
  `caddy version` always exits 0. A real check would need an extra binary in
  the image.
- Port 2019 (admin API) is deliberately not exposed.

## Showing versions on GitHub

ghcr's package page only shows index-level annotations; it ignores image labels
entirely. The versions get there through the `org.opencontainers.image.description`
annotation and the `caddy-*` tags. Two settings make the annotation stick, and
removing either drops it without an error:

- `oci-mediatypes=true` on the per-arch pushes (a Docker manifest list can't
  carry annotations).
- `DOCKER_METADATA_ANNOTATIONS_LEVELS: index` in the merge job.

## Testing locally

```sh
podman build \
  --build-arg CADDY_VERSION=v2.11.9 \
  --build-arg PROXY_VERSION=v2.13.1 \
  --build-arg CLOUDFLARE_VERSION=v0.2.4 \
  -t localhost/caddy-proxy:test .
```

The build takes 10 - 15 minutes. To check proxying, run it with the rootless
Podman socket mounted at `/var/run/docker.sock` alongside a `traefik/whoami`
container labeled `caddy=http://whoami.localhost`, then
`curl -H 'Host: whoami.localhost'` the published port. Podman 4.9 logs
`Docker events error: EOF` and new routes take up to 30 seconds to appear
(caddy-docker-proxy falls back to polling); that's expected.

## Linting

`actionlint` flags the `ubuntu-26.04` / `ubuntu-26.04-arm` runner labels as
unknown. Its label list is out of date; those runners work.
