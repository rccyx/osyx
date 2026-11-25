VITALS=(
  ca-certificates    # tls root certs for curl, git, and apt
  gnupg              # gpg key management for apt repos and ~/.tfa
  curl               # fetch remote installers, apis, and release tarballs
  wget               # fallback downloader for source builders
  git                # clone repos, submodules, and syncer state
  locales            # generate utf-8 system locales
  tzdata             # timezone database for timedatectl
  dbus               # system message bus
  dbus-user-session  # user session bus for systemd, mako, and portals
  xdg-user-dirs      # create standard ~/Downloads, ~/Pictures, etc.
  sudo               # privilege escalation (missing on bare debian)
)

BASE_TOOLS=(
  neovim             # primary terminal editor
  tree               # directory hierarchy inspection
  htop               # interactive process viewer
  btop               # resource monitor with graphs
  unzip              # extract zip archives (fonts, releases)
  xz-utils           # decompress .tar.xz tarballs (gcc/hypr sources)
  openssh-client     # ssh/scp and git over ssh
  man-db             # man command and page index
  less               # pager for man, git, and logs
  jq                 # json parsing (hyprctl monitors -j in rec)
  lm-sensors         # fallback cpu temp readings for heat-notify
  python3-jinja2     # template engine for flavors theme generator
)

STACK=(
  zsh                # primary shell and setup/cmd script runtime
  tmux               # terminal multiplexer
  kitty              # gpu-accelerated wayland terminal
  wofi               # wayland app launcher
  mako-notifier      # wayland notification daemon
  lsd                # modern ls replacement with icons
  fzf                # fuzzy finder for cli menus (rec, tfa, etc.)
  ripgrep            # fast recursive text search (rg)
  fd-find            # fast find replacement (aliased to fd)
  bat                # syntax-highlighted cat (aliased from batcat)
  starship           # shell prompt
  pipx               # isolated python cli tool installs (we don't use pip here, libs use uv)
)

DESKTOP_BASE=(
  network-manager          # wifi and network daemon (nmcli / netkit)
  seatd                    # lightweight seat management for wayland
  polkitd                  # privilege authorization for session actions
  xwayland                 # compatibility layer for legacy x11 apps
  xdg-desktop-portal       # file picker and screenshare portal frontend
  xdg-desktop-portal-wlr   # wlroots/hyprland portal backend
  pipewire                 # low-latency audio/video server
  wireplumber              # pipewire session and policy manager
  pipewire-pulse           # pulseaudio compat layer (pactl mixing in rec)
  wl-clipboard             # wl-copy and wl-paste for wayland clipboard
  grim                     # wayland screenshot capture
  slurp                    # interactive wayland region selector (shot-mac, rec)
  swappy                   # post-capture screenshot annotation editor
  libnotify-bin            # provides notify-send (rec, shot, heat, battery)
  ffmpeg                   # extract mp4 preview thumbnails in rec
  mpv                      # media player for opening saved recordings
  upower                   # battery telemetry daemon for battery-notify
  brightnessctl            # backlight control for ctrlyx and keybinds
  playerctl                # mpris media playback control
  fonts-noto-color-emoji   # fallback emoji font rendering
)