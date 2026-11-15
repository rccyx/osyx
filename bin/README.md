# bin

Run the repository's `bin/_install_` script to copy these commands into `~/bin`, or place the directory there through bootstrap. Add `~/bin` to `PATH` to run them globally from any directory. Each executable selects its own interpreter through its shebang; Bash commands do not require Zsh sourcing.

The [`~/.zshrc`](/config/.zshrc) configuration adds `~/bin` to `PATH`. The installer makes the installed commands executable.

## Bins

**wallpaper:**

`./wallpaper` depends on `waypaper >= v2.6`, `swww >= 0.10.3-master`.

```bash
wallpaper # Opens the Waypaper GUI (wallpapers should be inside ~/.wallpapers)
wallpaper set <f> # Sets desktop to a specific image file
wallpaper random # Applies a random wallpaper from your folder
```

Uses standard `bash`.

**battery:**

`./battery` reads battery, charging, capacity, and health info.

```bash
battery
```

Uses standard `bash`. No external dependencies.

**keyboard:**

`./keyboard` changes the system keyboard layout and applies it immediately to the current session when available.

```bash
keyboard fr # French
keyboard us # English US
keyboard de # German
keyboard gb # English UK
keyboard us intl # English US International
keyboard fr bepo # French Bépo
```

Accepts any valid XKB layout and optional variant.

Uses standard `bash`. Depends on `localectl`, `sudo`, and `hyprctl` when running inside Hyprland.

**diskspace:**

`./diskspace` displays the total, used, and available disk space for the home filesystem.

```bash
diskspace
```

Uses standard `bash`. No external dependencies.

**diskusage:**

`./diskusage` opens an interactive disk usage analyzer for the full filesystem.

```bash
diskusage
```

Uses standard `bash`. Depends on `dua >= v2.31.0`.

**heat:**

`./heat` reads the current CPU temperature (in Celsius) directly from Linux hardware monitoring data.

```bash
heat
```

Uses standard `bash`. No external dependencies.

**suspend:**

`./suspend` suspends the machine.

```bash
suspend
```

Just a `systemctl suspend` alias.

**hibernate:**

`./hibernate` hibernates the machine.

```bash
hibernate
```

Just a `systemctl hibernate` alias.

**logout:**

`./logout` safely logs out of the current desktop environment.

```bash
logout
```

Depends on `hyprshutdown`.

**reboot:**

`./reboot` safely reboots the machine.

```bash
reboot
```

Depends on `hyprshutdown`.

**shutdown:**

`./shutdown` safely shuts down and powers off the machine.

```bash
shutdown
```

Depends on `hyprshutdown`.

**sync-time:**

`./sync-time` restarts the network time synchronization service.

```bash
sync-time
```

Uses standard `bash`. Depends on `sudo` and `systemctl`.

**timezone:**

`./timezone` opens an interactive menu to set the system timezone.

```bash
timezone
```

Depends on `timedatectl`, `fzf`, and `sudo`.

**audio:**

`./audio` is a standalone bash command center for PipeWire audio. It selects microphones and output devices, changes volumes and mute states, shows active streams, tests microphone recording, and restarts audio services.

```bash
audio                 # Interactive control menu
audio in              # Interactive microphone selection
audio in <query>      # Select microphone by full/partial name or ID
audio out             # Interactive output selection
audio out <query>     # Select output by full/partial name or ID
audio pod             # Find podcast/USB/Focusrite/Vocaster microphone
audio machine         # Find internal microphone
audio speakers        # Find internal speaker output
audio headphones      # Find headphones, Bluetooth, USB, or HDMI output
audio mute in         # Toggle default microphone mute
audio mute out        # Toggle default output mute
audio vol 80%         # Set default output volume
audio vol 10%+        # Increase output volume
audio micvol 100%     # Set default microphone input volume
audio status          # Show default devices and stream counts
audio streams         # List active capture and playback streams
audio ls              # List available input and output devices
audio tree            # Show WirePlumber node tree
audio test 5          # Record a 5-second microphone test
audio restart         # Restart PipeWire services
audio help            # Show command reference
```


Needs `fzf` for interactive selection and ambiguous device matches. `wpctl` is used to inspect the audio graph and, when available, to reinforce default device selection. `pw-record` is required for `audio test`, `systemctl` is required for `audio restart`. 

Optionally uses `notify-send` for desktop notifications and `mpv` for test playback.
