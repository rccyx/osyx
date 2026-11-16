# -------------------------------------------------
# Wi-Fi utilities (robust SSID handling)
# -------------------------------------------------

wifi() {
  local interface ssid password entry wifi_list
  interface=$(nmcli device | awk '/wifi|wl/ {print $1; exit}')
  [[ -z "$interface" ]] && echo -e "\e[1;31m❌ No Wi-Fi interface found.\e[0m" && return 1

  echo -e "\e[1;34m📡 Scanning Wi-Fi networks...\e[0m"
  nmcli device wifi rescan >/dev/null 2>&1
  sleep 1

  # Use tab as a hard delimiter so SSIDs with spaces survive selection
  wifi_list=$(
    nmcli --terse --escape no -f SSID,SIGNAL,SECURITY device wifi list \
    | awk -F: 'length($1){printf "%s\t[%3s%%]\t%s\n",$1,$2,($3=="--"?"OPEN":"🔒 "$3)}'
  )
  [[ -z "$wifi_list" ]] && echo -e "\e[1;31m❌ No networks found.\e[0m" && return 1

  entry=$(printf "%s\n" "$wifi_list" \
    | fzf --prompt="📶 Select Wi-Fi ⇢ " --height=60% --border --reverse \
          --header="SSID\tSIGNAL  SECURITY" -d $'\t' --with-nth=1..3)
  [[ -z "$entry" ]] && echo -e "\e[1;31m❌ Cancelled.\e[0m" && return 1

  ssid=$(printf "%s" "$entry" | cut -f1)
  [[ -z "$ssid" ]] && echo -e "\e[1;31m❌ Failed to parse SSID.\e[0m" && return 1

  # If a saved connection with the exact name exists, bring it up
  if nmcli -g NAME connection show | grep -Fxq "$ssid"; then
    echo -e "\e[1;34m🔁 Connecting to saved network: \e[1;33m$ssid\e[0m"
    if nmcli connection up "$ssid"; then
      echo -e "\e[1;32m✅ Connected to $ssid\e[0m"; return 0
    fi
    echo -e "\e[1;31m❌ Failed to connect to $ssid.\e[0m"; return 1
  fi

  echo -ne "\e[1;33m🔑 Password for '$ssid' (blank to try open): \e[0m"
  read -sr password; echo

  if [[ -z "$password" ]]; then
    echo -e "\e[1;34m⏳ Trying open connect...\e[0m"
    nmcli device wifi connect "$ssid"
  else
    echo -e "\e[1;34m🔗 Connecting to '$ssid'...\e[0m"
    nmcli device wifi connect "$ssid" password "$password"
  fi

  if [[ $? -eq 0 ]]; then
    echo -e "\e[1;32m✅ Connected to '$ssid'\e[0m"
  else
    echo -e "\e[1;31m❌ Failed to connect to '$ssid'.\e[0m"
  fi
}

# ---- minimal Wi-Fi toolkit ----

iface(){ nmcli device | awk '/wifi|wl/ {print $1; exit}'; }

_sel_ssid(){
  local list choice
  list=$(
    nmcli --terse --escape no -f SSID,SIGNAL dev wifi list \
    | awk -F: 'length($1){printf "%s\t[%s%%]\n",$1,$2}' \
    | sort -t$'\t' -k2 -nr
  )
  if [[ -z $list ]]; then _err "no networks found" >&2; return 1; fi
  choice=$(printf "%s\n" "$list" | fzf --prompt="📶 SSID ➜ " --no-multi -d $'\t' --with-nth=1..2)
  if [[ -z $choice ]]; then _err "no ssid chosen" >&2; return 1; fi
  printf "%s" "$(echo "$choice" | cut -f1)"
}

wifikill(){ nmcli radio wifi off && _ok "wifi radio off"; }
wifiresume(){ nmcli radio wifi on  && _ok "wifi radio on";  }

wifireconnect(){
  local ssid; ssid="$(_sel_ssid)" || return 1
  _note "reconnecting to $ssid…"
  if nmcli connection up "$ssid" 2>/dev/null || nmcli device wifi connect "$ssid" 2>/dev/null; then
    _ok "connected to $ssid"
  else
    _err "failed to connect to $ssid"
  fi
}
wifipass(){
  local ssid pw
  ssid=$(nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes"{print $2}')
  
  if [[ -z "$ssid" ]]; then
    _err "Not connected to any Wi-Fi" && return 1
  fi

  # Extract the PSK using the show connection command
  # -s (show-secrets) is required to actually pull the password field
  pw=$(nmcli -s -g 802-11-wireless-security.psk connection show "$ssid" 2>/dev/null)

  if [[ -z "$pw" ]]; then
    _note "Open network or key not stored in NetworkManager"; return 0
  fi

  # Output and Clipboard Logic
  if command -v xclip >/dev/null; then
    echo -n "$pw" | xclip -selection clipboard
    _ok "Password for '$ssid' copied to clipboard."
  elif command -v wl-copy >/dev/null; then
    echo -n "$pw" | wl-copy
    _ok "Password for '$ssid' copied to clipboard (Wayland)."
  fi
  
  echo -e "SSID: \e[1;36m$ssid\e[0m"
  echo -e "PSK:  \e[1;33m$pw\e[0m"
}

_wifi_ssids(){
  local -a ssids
  mapfile -t ssids < <(nmcli --terse --escape no -f SSID dev wifi | awk 'length($0)')
  _describe 'ssid' ssids
}


netspeed() {
  if ! command -v speedtest &>/dev/null; then
    echo -e "\e[1;31mspeedtest-cli not found. Install it with:\e[0m pip install speedtest-cli"
    return 1
  fi
  echo -e "\e[1;34m⏳ Testing internet speed...\e[0m"
  local output; output=$(speedtest --secure --simple 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    echo -e "\e[1;31m❌ Failed to test speed. Check connection.\e[0m"
    return 1
  fi
  local ping download upload
  ping=$(echo "$output" | grep "Ping" | awk '{print $2 " " $3}')
  download=$(echo "$output" | grep "Download" | awk '{print $2 " " $3}')
  upload=$(echo "$output" | grep "Upload" | awk '{print $2 " " $3}')
  echo -e "\e[1;36m📡 Ping:\e[0m     $ping"
  echo -e "\e[1;36m⬇️  Download:\e[0m $download"
  echo -e "\e[1;36m⬆️  Upload:\e[0m   $upload"
  if command -v xclip >/dev/null; then
    printf "Ping: %s\nDownload: %s\nUpload: %s\n" "$ping" "$download" "$upload" | xclip -selection clipboard
    echo -e "\e[1;32m📋 Copied to clipboard.\e[0m"
  fi
}

wifiqr() {
  if ! command -v qrencode &>/dev/null; then
    echo -e "\e[1;31mqrencode not installed. Install with: sudo apt install qrencode\e[0m"
    return 1
  fi
  local ssid password auth payload
  ssid=$(nmcli --terse --escape no -t -f active,ssid dev wifi | awk -F: '$1=="yes"{print $2}')
  [[ -z "$ssid" ]] && echo -e "\e[1;31mNot connected to any Wi-Fi.\e[0m" && return 1

  password=$(nmcli -s -g 802-11-wireless-security.psk connection show "$ssid" 2>/dev/null)
  [[ -z "$password" ]] && auth="nopass" || auth="WPA"

  payload="WIFI:T:$auth;S:$ssid;P:$password;;"
  echo -e "\e[1;36m📶 Current SSID: \e[0m$ssid"
  echo -e "\e[1;34m🔳 Scan to connect:\e[0m"
  echo "$payload" | qrencode -t ANSIUTF8
}

# Forget a saved Wi-Fi profile by exact name or via selector if none given
wifi_forget(){
  local ssid
  if [[ -n "$1" ]]; then
    ssid="$1"
  else
    ssid="$(_sel_ssid)" || return 1
  fi
  if nmcli connection delete id "$ssid"; then
    _ok "forgot $ssid"
  else
    _err "no saved connection named $ssid"
  fi
}

# ---------- helpers (fallbacks if you do not have them) ----------
typeset -f _ok   >/dev/null || _ok(){   echo -e "\e[1;32m$*\e[0m"; }
typeset -f _err  >/dev/null || _err(){  echo -e "\e[1;31m$*\e[0m" >&2; }
typeset -f _note >/dev/null || _note(){ echo -e "\e[1;34m$*\e[0m"; }

# Detect active wifi/ether interface if not given
net_iface(){ nmcli device | awk '/wifi|wl|ethernet|enp|eth/ {print $1; exit}'; }

# ---------- ensure deps ----------
devices_install(){
  local need=()
  for bin in arp-scan nmap nbtscan fping jq column avahi-browse mdns-scan upnpc; do
    command -v "$bin" >/dev/null || need+=("$bin")
  done
  # Some tools have different package names
  local pkgs=()
  for b in "${need[@]}"; do
    case "$b" in
      arp-scan)       pkgs+=(arp-scan) ;;
      nmap)           pkgs+=(nmap) ;;
      nbtscan)        pkgs+=(nbtscan) ;;
      fping)          pkgs+=(fping) ;;
      jq)             pkgs+=(jq) ;;
      column)         pkgs+=(bsdmainutils) ;;  # column comes from util-linux on newer Debian, bsdmainutils on older
      avahi-browse)   pkgs+=(avahi-utils) ;;
      mdns-scan)      pkgs+=(mdns-scan) ;;
      upnpc)          pkgs+=(miniupnpc) ;;
    esac
  done
  if (( ${#pkgs[@]} )); then
    _note "Installing: ${pkgs[*]}"
    sudo apt-get update -y && sudo apt-get install -y "${pkgs[@]}"
  fi
}

# ---------- quick deep scan of a single host ----------
device_deep(){
  local ip="${1:?usage: device_deep <ip> [fast|full]}"
  local mode="${2:-fast}"  # fast: -A with host timeout, full: slower
  _note "Deep scan on $ip ($mode)"
  if [[ "$mode" == "full" ]]; then
    sudo nmap -A -T4 --reason --max-retries 2 "$ip"
  else
    sudo nmap -A -T4 --reason --host-timeout 25s --max-retries 1 "$ip"
  fi
  echo
  # mDNS name if available
  if command -v avahi-resolve-address >/dev/null; then
    avahi-resolve-address "$ip" || true
  fi
}

# ---------- helpers (fallbacks if you do not have them) ----------
typeset -f _ok   >/dev/null || _ok(){   echo -e "\e[1;32m$*\e[0m"; }
typeset -f _err  >/dev/null || _err(){  echo -e "\e[1;31m$*\e[0m" >&2; }
typeset -f _note >/dev/null || _note(){ echo -e "\e[1;34m$*\e[0m"; }

# Detect active wifi/ether interface if not given
net_iface(){ nmcli device | awk '/wifi|wl|ethernet|enp|eth/ {print $1; exit}'; }

# ---------- ensure deps ----------
devices_install(){
  local need=()
  for bin in arp-scan nmap nbtscan fping jq column avahi-browse mdns-scan upnpc; do
    command -v "$bin" >/dev/null || need+=("$bin")
  done

  local pkgs=()
  for b in "${need[@]}"; do
    case "$b" in
      arp-scan)       pkgs+=(arp-scan) ;;
      nmap)           pkgs+=(nmap) ;;
      nbtscan)        pkgs+=(nbtscan) ;;
      fping)          pkgs+=(fping) ;;
      jq)             pkgs+=(jq) ;;
      column)         pkgs+=(util-linux) ;;   # column is in util-linux on Debian
      avahi-browse)   pkgs+=(avahi-utils) ;;
      mdns-scan)      pkgs+=(mdns-scan) ;;
      upnpc)          pkgs+=(miniupnpc) ;;
    esac
  done

  (( ${#pkgs[@]} )) || return 0

  _note "Installing: ${pkgs[*]}"

  # Try normal update, then fall back to Debian-only lists if third-party repo breaks
  if ! sudo apt-get update -y; then
    _err "apt update failed, retrying with Debian sources only"
    if ! sudo apt-get update -y -o Dir::Etc::sourceparts='-' -o Dir::Etc::sourcelist='/etc/apt/sources.list'; then
      _err "apt update still failing. Skipping install. Some features may be degraded."
      return 0
    fi
  fi

  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}" || \
    _err "Install failed. Continuing without optional tools."
}

# ---------- quick deep scan of a single host ----------
device_deep(){
  local ip="${1:?usage: device_deep <ip> [fast|full]}"
  local mode="${2:-fast}"
  _note "Deep scan on $ip ($mode)"
  if [[ "$mode" == "full" ]]; then
    sudo nmap -A -T4 --reason --max-retries 2 "$ip"
  else
    sudo nmap -A -T4 --reason --host-timeout 25s --max-retries 1 "$ip"
  fi
  echo
  if command -v avahi-resolve-address >/dev/null; then
    avahi-resolve-address "$ip" || true
  fi
}

# ---------- rich devices inventory ----------
# Usage: devices [--iface IFACE] [--ports "22,80,443,..."] [--os] [--deep ip]
devices(){
  local iface cidr ports osflag deep_ip
  ports="22,53,80,443,139,445,1900,5357,8000-8100"
  osflag=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --iface) iface="$2"; shift 2 ;;
      --ports) ports="$2"; shift 2 ;;
      --os)    osflag=1; shift ;;
      --deep)  deep_ip="$2"; shift 2 ;;
      *) _err "unknown flag: $1"; return 2 ;;
    esac
  done

  iface="${iface:-$(typeset -f iface >/dev/null && iface || net_iface)}"
  [[ -z "$iface" ]] && _err "no interface found" && return 1

  devices_install

  cidr=$(ip -o -4 addr show dev "$iface" | awk '{print $4}' | head -n1)
  [[ -z "$cidr" ]] && _err "no IPv4 on $iface" && return 1

  _note "Interface: $iface   Subnet: $cidr"
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

  # 1) ARP sweep for MAC + Vendor, IPv4 only, tolerate failure
  _note "ARP sweeping..."
  if ! sudo arp-scan --interface="$iface" --localnet --retry=2 --timeout=50 2>"$tmp/arp.err" \
      | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[ \t]+([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/{
          ip=$1; mac=$2; $1=""; $2=""; sub(/^[ \t]+/,""); vendor=$0; print ip"\t"mac"\t"vendor
        }' > "$tmp/arp.tsv"
  then
    _err "arp-scan failed, falling back to neighbor table"
    : > "$tmp/arp.tsv"
  fi

  # Add kernel neighbors, filter to IPv4 only
  ip neigh show dev "$iface" \
    | awk '/lladdr/ && $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {print $1"\t"$5"\tunknown"}' \
    >> "$tmp/arp.tsv"
  sort -u "$tmp/arp.tsv" -o "$tmp/arp.tsv"

  # 2) Alive hosts and reverse DNS (IPv4 subnet)
  _note "Ping probing and reverse DNS..."
  nmap -sn -R "$cidr" -oG - \
    | awk '/Status: Up/{ip=$2; if(match($0,/\(([^)]*)\)/,m)){name=m[1]} else {name="-"}; print ip"\t"name}' \
    > "$tmp/dns.tsv"

  # 3) NetBIOS names if available
  _note "NetBIOS sweep..."
  if command -v nbtscan >/dev/null; then
    nbtscan -r "$cidr" 2>/dev/null | awk 'NF>=2 {print $1"\t"$2}' > "$tmp/nb.tsv" || true
  else
    : > "$tmp/nb.tsv"
  fi

  # Build the union IP list (IPv4 only)
  : > "$tmp/ips"
  awk -F'\t' '$1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/{print $1}' "$tmp/arp.tsv" >> "$tmp/ips"
  awk -F'\t' '$1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/{print $1}' "$tmp/dns.tsv" >> "$tmp/ips"
  ip neigh show dev "$iface" | awk '$1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/{print $1}' >> "$tmp/ips"
  sort -u "$tmp/ips" -o "$tmp/ips"

  # 4) Quick port scan for service hints
  _note "Port scan (open only) on discovered IPs..."
  if [[ -s "$tmp/ips" ]]; then
    nmap -Pn -n --open -T4 -p "$ports" -oG - -iL "$tmp/ips" \
      | awk '/Ports:/{ip=$2; p=$0; sub(/^.*Ports: /,"",p); gsub(/\/open\/tcp\/\/[^,]*/,"",p); gsub(/, /,",",p); print ip"\t"p}' \
      > "$tmp/ports.tsv"
  else
    : > "$tmp/ports.tsv"
  fi

  # 5) RTTs without background jobs noise
  _note "Measuring RTT..."
  : > "$tmp/rtt.tsv"
  while read -r ip; do
    t=$(ping -n -c1 -W1 "$ip" 2>/dev/null | awk -F'time=' '/time=/{print $2}' | cut -d' ' -f1)
    printf "%s\t%s\n" "$ip" "${t:-timeout}"
  done < "$tmp/ips" > "$tmp/rtt.tsv"

  # 6) Optional OS fingerprinting
  if (( osflag == 1 )); then
    _note "OS fingerprinting..."
    sudo nmap -O --osscan-limit --host-timeout 20s -oG - -iL "$tmp/ips" \
      | awk '/Status: Up/ {ip=$2} /OS details:/{sub(/^OS details: /,""); print ip"\t"$0}' \
      > "$tmp/os.tsv"
  else
    : > "$tmp/os.tsv"
  fi

  # 7) Join everything by IP and print
  _note "Aggregating..."
  typeset -A MAC VENDOR DNS NB PORTS RTT OS
  while IFS=$'\t' read -r ip mac vendor; do MAC[$ip]="$mac"; VENDOR[$ip]="$vendor"; done < "$tmp/arp.tsv"
  while IFS=$'\t' read -r ip name;      do DNS[$ip]="$name"; done < "$tmp/dns.tsv"
  while IFS=$'\t' read -r ip nb;        do NB[$ip]="$nb"; done < "$tmp/nb.tsv"
  while IFS=$'\t' read -r ip p;         do PORTS[$ip]="$p"; done < "$tmp/ports.tsv"
  while IFS=$'\t' read -r ip r;         do RTT[$ip]="$r"; done < "$tmp/rtt.tsv"
  while IFS=$'\t' read -r ip o;         do OS[$ip]="$o"; done < "$tmp/os.tsv"

  {
    echo -e "IP\tRTT(ms)\tMAC\tVendor\tDNS-name\tNB-name\tOpen-ports\tOS"
    for ip in ${(u)${(f)"$(cat "$tmp/ips")"}}; do
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$ip" \
        "${RTT[$ip]:-timeout}" \
        "${MAC[$ip]:--}" \
        "${VENDOR[$ip]:--}" \
        "${DNS[$ip]:--}" \
        "${NB[$ip]:--}" \
        "${PORTS[$ip]:--}" \
        "${OS[$ip]:--}"
    done \
    | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n
  } | column -t -s $'\t'

  if [[ -n "$deep_ip" ]]; then
    echo
    device_deep "$deep_ip" fast
  fi
}

connected-devices(){
  _note "Scanning for connected devices on your network..."
  devices "$@"
  echo
  local ni; ni="$(net_iface)"
  local count
  count=$(sudo arp-scan --localnet --interface "$ni" 2>/dev/null \
          | grep -cE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[[:space:]]+([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}') || count=0
  echo "Total devices seen: $count"
}


# zsh completion hook
compdef _wifi_ssids wifireconnect

