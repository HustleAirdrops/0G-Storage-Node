#!/bin/bash

LOCAL_RPC="http://localhost:5678"
EXPLORER_API="https://chainscan-galileo.0g.ai/stat/gasprice/tracker"

prevHeight=0
prevTime=0

while true; do
  response=$(curl -s -X POST "$LOCAL_RPC" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"zgs_getStatus","params":[],"id":1}')
  
  localHeight=$(echo "$response" | jq '.result.logSyncHeight // 0')
  peers=$(echo "$response" | jq '.result.connectedPeers // 0')
  now=$(date +"%s")
  
  if (( prevHeight > 0 )); then
    diffHeight=$((localHeight - prevHeight))
    diffTime=$((now - prevTime))
    if (( diffTime > 0 )); then
      speed=$((diffHeight / diffTime))
    else
      speed=0
    fi
  else
    speed=0
  fi

  prevHeight=$localHeight
  prevTime=$now

  explorerResp=$(curl -s "$EXPLORER_API")
  explorerHeight=$(echo "$explorerResp" | jq '.result.blockHeight // 0')

  diff=$((explorerHeight - localHeight))

  if (( diff > 50 )); then
    status="🔴 BEHIND: $diff"
    printf "🧱 Logs Block:%7d | 🌍 Live Block:%7d | 🤝 Peers:%3d | 🚀 Speed: %3d blocks/sec | %s\n" "$localHeight" "$explorerHeight" "$peers" "$speed" "$status"
  else
    status="🟢 SYNCED"
    printf "🧱 Logs Block:%7d | 🌍 Live Block:%7d | 🤝 Peers:%3d | %s\n" "$localHeight" "$explorerHeight" "$peers" "$status"
  fi

  sleep 5
done
