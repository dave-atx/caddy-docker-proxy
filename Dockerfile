FROM caddy:builder AS builder

# Build Caddy with plugins
RUN xcaddy build \
    --with github.com/lucaslorentz/caddy-docker-proxy/v2 \
    --with github.com/caddy-dns/cloudflare

# Final stage - use distroless
FROM gcr.io/distroless/static-debian12:nonroot

# Copy Caddy binary from builder
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# Copy CA certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Use nonroot user
USER nonroot:nonroot

# Expose ports
EXPOSE 80 443 2019

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD ["/usr/bin/caddy", "version"]

ENTRYPOINT ["/usr/bin/caddy"]
CMD ["docker-proxy"]
