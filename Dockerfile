# Base images are pinned by digest so builds are reproducible; Dependabot
# opens a PR when either digest changes, and merging it triggers a rebuild.
FROM caddy:2-builder@sha256:3db11aead97f1fdff9c563d0dd8e7fba2e4c7031bef40f3e44fd1982f3e8366b AS builder

# Component versions (e.g. v2.11.9). CI passes the latest upstream releases;
# pinning them here makes the build match the labels and busts the layer
# cache whenever any one of them changes.
ARG CADDY_VERSION
ARG PROXY_VERSION
ARG CLOUDFLARE_VERSION

RUN : "${CADDY_VERSION:?build arg required}" \
      "${PROXY_VERSION:?build arg required}" \
      "${CLOUDFLARE_VERSION:?build arg required}" \
 && xcaddy build "${CADDY_VERSION}" \
      --with "github.com/lucaslorentz/caddy-docker-proxy/v2@${PROXY_VERSION}" \
      --with "github.com/caddy-dns/cloudflare@${CLOUDFLARE_VERSION}"

FROM gcr.io/distroless/static-debian13:latest@sha256:1a64f46364620465ef9e9a8f5413757dfdf22695e050bbfd7303eeaf17a59383

ARG CADDY_VERSION
ARG PROXY_VERSION
ARG CLOUDFLARE_VERSION
LABEL org.marquard.caddy.version="${CADDY_VERSION}" \
      org.marquard.caddy-docker-proxy.version="${PROXY_VERSION}" \
      org.marquard.caddy-dns-cloudflare.version="${CLOUDFLARE_VERSION}"

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# HTTP, HTTPS, and HTTP/3. The admin API (2019) is deliberately not exposed.
EXPOSE 80 443 443/udp

ENTRYPOINT ["/usr/bin/caddy"]
CMD ["docker-proxy"]
