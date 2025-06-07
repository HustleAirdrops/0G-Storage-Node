#!/bin/bash

set -e

echo "🚀 Starting 0G Storage Node Auto Installer..."

# Step 1: Update & install dependencies
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install -y curl iptables build-essential git wget lz4 jq make cmake gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip screen ufw

# Step 2: Install Rust
curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env

# Step 3: Install Go
wget https://go.dev/dl/go1.24.3.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.24.3.linux-amd64.tar.gz
rm go1.24.3.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# Step 4: Clone and build node
git clone https://github.com/0glabs/0g-storage-node.git
cd 0g-storage-node
git checkout v1.0.0
git submodule update --init
cargo build --release

# Step 5: Get config file
rm -rf $HOME/0g-storage-node/run/config.toml
curl -o $HOME/0g-storage-node/run/config.toml https://raw.githubusercontent.com/Mayankgg01/0G-Storage-Node-Guide/main/config.toml

# Step 6: Ask user for private key
echo ""
echo "🔐 Enter your PRIVATE KEY (with or without 0x):"
read -s PRIVATE_KEY
PRIVATE_KEY=${PRIVATE_KEY#0x}  # remove 0x if present

# Step 7: Inject private key into config.toml
CONFIG_PATH="$HOME/0g-storage-node/run/config.toml"
sed -i "s/miner_key = .*/miner_key = \"$PRIVATE_KEY\"/" "$CONFIG_PATH"
echo "✅ Private key inserted into config.toml"

# Step 8: Create systemd service (but don't start yet)
sudo tee /etc/systemd/system/zgs.service > /dev/null <<EOF
[Unit]
Description=ZGS Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/0g-storage-node/run
ExecStart=$HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config.toml
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable zgs

# Done
echo ""
echo "🎉 Installation complete!"
echo "👉 Run this command to start your node:"
echo ""
echo "   sudo systemctl start zgs"
echo ""
echo "📄 To view logs:"
echo "   tail -f \$HOME/0g-storage-node/run/log/zgs.log.\$(TZ=UTC date +%Y-%m-%d)"
echo ""
echo "📊 To monitor sync progress:"
echo "   while true; do response=\$(curl -s -X POST http://localhost:5678 -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"zgs_getStatus\",\"params\":[],\"id\":1}'); logSyncHeight=\$(echo \$response | jq '.result.logSyncHeight'); connectedPeers=\$(echo \$response | jq '.result.connectedPeers'); echo -e \"logSyncHeight: \033[32m\$logSyncHeight\033[0m, connectedPeers: \033[34m\$connectedPeers\033[0m\"; sleep 5; done"
