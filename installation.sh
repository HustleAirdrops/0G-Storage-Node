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
git checkout v1.0.0
git submodule update --init

# Step 5: Build node
echo "⚙️ Building node..."
cargo build --release

# Step 6: Setup config file
rm -f "$HOME/0g-storage-node/run/config.toml"
mkdir -p "$HOME/0g-storage-node/run"
curl -o "$HOME/0g-storage-node/run/config.toml" https://raw.githubusercontent.com/Mayankgg01/0G-Storage-Node-Guide/main/config.toml

# Step 7: Get private key from user
validate_key() {
  local key=$1
  key=${key#0x}
  if [[ ${#key} -ne 64 ]]; then
    echo "❌ Invalid key length. Key must be 64 hex characters."
    return 1
  fi
 
  if ! [[ $key =~ ^[0-9a-fA-F]+$ ]]; then
    echo "❌ Key contains invalid characters. Only hex digits allowed."
    return 1
  fi
  
  return 0
}

while true; do
  echo -n "🔐 Enter your PRIVATE KEY (with or without 0x): "
  read -s PRIVATE_KEY
  echo
  if validate_key "$PRIVATE_KEY"; then
    break
  else
    echo "Please try again."
  fi
done
PRIVATE_KEY=${PRIVATE_KEY#0x}
KEY_START=${PRIVATE_KEY:0:4}
KEY_END=${PRIVATE_KEY: -4}
echo "${KEY_START}****${KEY_END}"
echo "✅ Private key inserted."
sed -i "s|miner_key = .*|miner_key = \"$PRIVATE_KEY\"|" "$HOME/0g-storage-node/run/config.toml"

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

# Done
echo ""
echo "🎉 Installation complete!"
echo "👉 To start your node, run:"
echo ""
echo "   sudo systemctl start zgs"
echo ""
echo "📄 To view logs:"
echo "   tail -f \$HOME/0g-storage-node/run/log/zgs.log.\$(TZ=UTC date +%Y-%m-%d)"
echo ""
echo "📊 To monitor sync progress:"
echo "   while true; do"
echo "     response=\$(curl -s -X POST http://localhost:5678 -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"zgs_getStatus\",\"params\":[],\"id\":1}');"
echo "     logSyncHeight=\$(echo \$response | jq '.result.logSyncHeight');"
echo "     connectedPeers=\$(echo \$response | jq '.result.connectedPeers');"
echo "     echo -e \"logSyncHeight: \033[32m\$logSyncHeight\033[0m, connectedPeers: \033[34m\$connectedPeers\033[0m\";"
echo "     sleep 5;"
echo "   done"
