#!/bin/bash

set -e

# Step 0: Go to home directory to keep everything relative to home
cd "$HOME"

if [ -d "0g-storage-node" ]; then
    echo "✅ 0g-storage-node is already installed. Exiting installer."
    return 0 2>/dev/null || exit 0
fi

echo "🚀 Starting 0G Storage Node Auto Installer..."

# Step 1: Update & install dependencies
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install -y curl iptables build-essential git wget lz4 jq make cmake gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip screen ufw xdotool

# Step 2: Install Rust (if not installed)
if ! command -v rustc &> /dev/null; then
    echo "🔧 Installing Rust..."
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# Step 3: Install Go (if not installed)
if ! command -v go &> /dev/null; then
    echo "🔧 Installing Go..."
    wget https://go.dev/dl/go1.24.3.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.24.3.linux-amd64.tar.gz
    rm go1.24.3.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> "$HOME/.bashrc"
    source "$HOME/.bashrc"
fi

# Step 4: Clone repo (already in $HOME)
echo "📁 Cloning 0g-storage-node repository..."
git clone https://github.com/0glabs/0g-storage-node.git
cd 0g-storage-node
git checkout v1.1.0
git submodule update --init

# Step 5: Build node
sudo apt install -y protobuf-compiler
echo "⚙️ Building node..."
cargo build --release

# Step 6: Setup config file
rm -f "$HOME/0g-storage-node/run/config.toml"
mkdir -p "$HOME/0g-storage-node/run"
curl -o "$HOME/0g-storage-node/run/config.toml" https://raw.githubusercontent.com/HustleAirdrops/0G-Storage-Node/main/config.toml

# Step 7: Get private key and rpc from user
read -e -p "🔐 Enter PRIVATE KEY (with or without 0x): " k; k=${k#0x}; printf "\033[A\033[K"; [[ ${#k} -eq 64 && "$k" =~ ^[0-9a-fA-F]+$ ]] && sed -i "s|miner_key = .*|miner_key = \"$k\"|" "$HOME/0g-storage-node/run/config.toml" && echo "✅ Private key updated: ${k:0:4}****${k: -4}" || echo "❌ Invalid key! Must be 64 hex chars."
read -e -p "🌐 Enter new blockchain_rpc_endpoint URL: " r; echo; if [[ -z "$r" ]]; then echo "❌ Error: URL cannot be empty."; else sed -i "s|blockchain_rpc_endpoint = .*|blockchain_rpc_endpoint = \"$r\"|" "$HOME/0g-storage-node/run/config.toml" && echo "✅ blockchain_rpc_endpoint updated to: $r"; fi

# Step 8: Create systemd service
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

echo ""
echo "⚡ Starting node ..."
sudo systemctl start zgs

# Final Message
echo ""
echo "🎉 Installation complete with fast sync!"
echo "👉 To start your node manually (already started):"
echo ""
echo "   sudo systemctl start zgs"
echo ""
echo "📄 To view logs:"
echo "   tail -f \$HOME/0g-storage-node/run/log/zgs.log.\$(TZ=UTC date +%Y-%m-%d)"
echo ""
echo "📊 To monitor sync progress:"
echo "   bash <(curl -s https://raw.githubusercontent.com/HustleAirdrops/0G-Storage-Node/main/logs.sh)"
