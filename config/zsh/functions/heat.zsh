heat() {
  emulate -L zsh
  setopt localoptions errreturn pipefail

  local temperature
  temperature="$(_heat_find_cpu_temp)" || {
    printf 'no temperature source found\n' >&2
    return 1
  }

  printf '%s°C\n' "$temperature"
}

_heat_read_temp_file() {
  local sensor_path="$1"
  local value

  [[ -r "$sensor_path" ]] || return 1

  value="$(<"$sensor_path")"
  [[ "$value" =~ ^[0-9]+$ ]] || return 1

  if (( value > 200 )); then
    printf '%d' "$((value / 1000))"
  else
    printf '%d' "$value"
  fi
}

_heat_find_cpu_temp() {
  local value
  local hwmon
  local label
  local input
  local name

  if [[ -n "${HEAT_CPU_PATH:-}" ]]; then
    if value="$(_heat_read_temp_file "$HEAT_CPU_PATH")"; then
      printf '%s' "$value"
      return 0
    fi
  fi

  if value="$(_heat_read_temp_file "/sys/class/hwmon/hwmon5/temp1_input")"; then
    printf '%s' "$value"
    return 0
  fi

  for hwmon in /sys/class/hwmon/hwmon*(N); do
    for label in "$hwmon"/temp*_label(N); do
      name="$(tr '[:upper:]' '[:lower:]' < "$label")"

      case "$name" in
        *tctl*|*tdie*|*package*|*cpu*)
          input="${label%_label}_input"

          if value="$(_heat_read_temp_file "$input")"; then
            printf '%s' "$value"
            return 0
          fi
          ;;
      esac
    done

    if value="$(_heat_read_temp_file "$hwmon/temp1_input")"; then
      printf '%s' "$value"
      return 0
    fi
  done

  if command -v sensors >/dev/null 2>&1; then
    value="$(
      sensors 2>/dev/null |
        awk '
          /(Tctl|Tdie|Package id 0|CPU)/ {
            if (match($0, /[0-9]+(\.[0-9])?/)) {
              printf "%.0f", substr($0, RSTART, RLENGTH)
              exit
            }
          }
        '
    )"

    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return 0
    fi
  fi

  return 1
}
