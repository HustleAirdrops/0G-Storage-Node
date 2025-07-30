#!/bin/bash

# Graceful exit on Ctrl+C
trap ctrl_c INT

function ctrl_c() {
  echo -e "\n🚪 Exit requested. Goodbye!"
  exit 0
}

show_menu() {
  echo "=============================="
  echo "     0G Storage Node Menu     "
  echo "=============================="
  echo "1. Install Node"
  echo "2. Apply Fast Sync Snapshot"
  echo "3. Exit"
  echo "=============================="
  read -p "Choose an option [1-3]: " choice
  handle_choice $choice
}

handle_choice() {
  case $1 in
    1)
      echo "🚀 Starting Installation..."
      bash <(curl -s https://raw.githubusercontent.com/HustleAirdrops/0G-Storage-Node/main/installation.sh)
      echo "✅ Installation Complete. Press Enter to return to menu..."
      read
      show_menu
      ;;
    2)
      echo "🛑 Stopping node to apply fast sync..."
      sudo systemctl stop zgs
      rm -rf "$HOME/0g-storage-node/run/db/flow_db"

      echo "⬇️ Downloading and Extracting fast sync database..."
      wget https://github.com/HustleAirdrops/0G-Storage-Node/releases/download/latest/flow_db.tar.gz \
        -O "$HOME/0g-storage-node/run/db/flow_db.tar.gz"

      tar -xzvf "$HOME/0g-storage-node/run/db/flow_db.tar.gz" -C "$HOME/0g-storage-node/run/db/"

      echo "🚀 Restarting node with fast sync data..."
      sudo systemctl restart zgs
      echo "✅ Snapshot applied. Press Enter to return to menu..."
      read
      show_menu
      ;;
    3)
      echo "👋 Exiting. Goodbye!"
      exit 0
      ;;
    *)
      echo "❌ Invalid option. Try again."
      show_menu
      ;;
  esac
}

# Start the menu
show_menu
