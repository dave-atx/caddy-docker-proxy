#!/bin/bash
set -e

echo "Setting up Podman environment..."

# Install Podman (24.10 has a recent version)
sudo apt-get update
sudo apt-get install -y podman podman-docker systemd-container

# Check installed version
echo "Installed Podman version: $(podman --version)"

# Configure Podman for rootless
echo 'vscode:100000:65536' | sudo tee /etc/subuid
echo 'vscode:100000:65536' | sudo tee /etc/subgid

# Enable unprivileged ports
echo 'net.ipv4.ip_unprivileged_port_start=80' | sudo tee /etc/sysctl.d/99-rootless-ports.conf
sudo sysctl --system

# Create systemd user directory
mkdir -p ~/.config/containers/systemd
mkdir -p ~/.config/systemd/user

# Enable lingering for the user
sudo loginctl enable-linger vscode

# Start user systemd services
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
systemctl --user daemon-reload

# Create test environment file
cat > ~/.config/containers/systemd/caddy.env << 'EOF'
CLOUDFLARE_EMAIL=test@example.com
CLOUDFLARE_API_TOKEN=test-token
EOF

echo "Podman setup complete!"
