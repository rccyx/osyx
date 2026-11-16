# Bluetooth helper: connect/disconnect from terminal
bth() {
  if ! command -v bluetoothctl >/dev/null 2>&1; then
    echo -e "\e[1;31m❌ bluetoothctl not found. Install it.\e[0m"
    return 1
  fi

  local action="$1"

  if [[ "$action" == "disconnect" ]]; then
    echo -e "\e[1;35m🔌 Disconnecting all connected Bluetooth devices...\e[0m"
    bluetoothctl info | grep -B1 "Connected: yes" | grep Device | awk '{print $2}' | while read -r connected_mac; do
      bluetoothctl disconnect "$connected_mac" >/dev/null
      echo -e "\e[1;33m⛔ Disconnected $connected_mac\e[0m"
    done
    echo -e "\e[1;32mAll active devices disconnected.\e[0m"
    return 0
  fi

  if [[ "$action" != "connect" ]]; then
    echo -e "\e[1;33mUsage: bth {connect|disconnect}\e[0m"
    return 1
  fi

  trap 'echo -e "\n\e[1;31m⚠️ Aborted.\e[0m"; return 130' INT

  echo -e "\n\e[1;34m🔍 Scanning for Bluetooth devices...\e[0m"
  bluetoothctl power on >/dev/null
  bluetoothctl scan on >/dev/null &
  local scan_pid=$!
  sleep 5
  kill "$scan_pid" 2>/dev/null
  bluetoothctl scan off >/dev/null

  local devices=$(bluetoothctl devices | sort | awk '{$1=$2=""; print substr($0,3)}' | nl -w2 -s'. ')
  if [[ -z "$devices" ]]; then
    echo -e "\e[1;31m❌ No Bluetooth devices found.\e[0m"
    return 1
  fi

  echo -e "\n\e[1;36m📡 Nearby Bluetooth Devices:\e[0m"
  echo "$devices"

  echo -ne "\n\e[1;33m🔍 Enter device name (or partial match): \e[0m"
  read -r query

  local full_line=$(bluetoothctl devices | grep -i "$query" | head -n 1)
  local mac=$(echo "$full_line" | awk '{print $2}')
  local name=$(echo "$full_line" | cut -d ' ' -f3-)

  if [[ -z "$mac" ]]; then
    echo -e "\e[1;31m❌ No match found for '$query'.\e[0m"
    return 1
  fi

  echo -e "\n\e[1;35m🔌 Disconnecting all other devices first...\e[0m"
  bluetoothctl info | grep -B1 "Connected: yes" | grep Device | awk '{print $2}' | while read -r connected_mac; do
    bluetoothctl disconnect "$connected_mac" >/dev/null
    echo -e "\e[1;33m⛔ Disconnected $connected_mac\e[0m"
  done

  echo -e "\n\e[1;34m🔗 Pairing and connecting to: $name [$mac]...\e[0m"
  bluetoothctl trust "$mac"
  bluetoothctl pair "$mac"
  bluetoothctl connect "$mac"

  if [[ $? -eq 0 ]]; then
    echo -e "\e[1;32mConnected to '$name' successfully.\e[0m"
  else
    echo -e "\e[1;31m❌ Failed to connect to '$name'.\e[0m"
  fi
} 