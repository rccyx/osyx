# =====================================================================
# AWS cost explorer
# Deps: awscli v2, jq, fzf (optional), awk, coreutils
# =====================================================================

# UI helpers (fallbacks)
if ! typeset -f _ok   >/dev/null; then _ok(){ print -P "%F{2}✔%f $*"; } fi
if ! typeset -f _note >/dev/null; then _note(){ print -P "%F{4}ℹ️ %f $*"; } fi
if ! typeset -f _warn >/dev/null; then _warn(){ print -P "%F{3}‼%f $*"; } fi
if ! typeset -f _err  >/dev/null; then _err(){ print -P "%F{1}✖%f $*"; } fi
_cost_hr(){ print -P "%F{244}$(printf '%*s' 64 '' | tr ' ' '-')%f"; }

# Knobs
: ${COST_METRIC:=UnblendedCost}
: ${COST_DEF_RANGE:=MTD}
: ${COST_DEF_GROUP:=SERVICE}
: ${COST_DEF_GRAN:=DAILY}
: ${COST_CACHE_TTL_SEC:=1800}
: ${COST_SPARK:=1}
: ${COST_MAP_LINKED:=1}

# Checks
_cost_need(){ command -v "$1" >/dev/null 2>&1 || { _err "missing dep: $1"; return 1; } }
_cost_check(){
  _cost_need aws || return 1
  _cost_need jq  || return 1
  aws sts get-caller-identity >/dev/null 2>&1 || { _err "AWS creds not working"; return 1; }
}

# Dates
_cost_utc(){ TZ=UTC date -u +"%Y-%m-%d"; }
_cost_date(){ TZ=UTC date -u -d "$1" +"%Y-%m-%d"; }
_cost_now_plus(){ TZ=UTC date -u -d "$1" +"%Y-%m-%d"; }

# Sparkline ▁▂▃▄▅▆▇█
_cost_spark(){
  (( COST_SPARK != 1 )) && return 0
  local -a nums; nums=("$@")
  local n max=0
  for n in "${nums[@]}"; do
    [[ -z "$n" ]] && n=0
    n="$(awk -v x="$n" 'BEGIN{printf("%d", x*100+0.5)}')"
    (( n > max )) && max=$n
  done
  (( max == 0 )) && { print "▁"; return 0; }
  local out="" v rel chars="▁▂▃▄▅▆▇█"
  for v in "${nums[@]}"; do
    v="$(awk -v x="$v" 'BEGIN{printf("%d", x*100+0.5)}')"
    rel=$(( 7 * v / max )); (( rel<0 ))&&rel=0; (( rel>7 ))&&rel=7
    out+="${chars[rel+1]}"
  done
  print -- "$out"
}

# Cache
_cost_cache_dir(){ echo "${XDG_CACHE_HOME:-$HOME/.cache}/cost.dsh"; }
_cost_cache_key(){
  local s="${1:-}"
  if command -v openssl >/dev/null 2>&1; then
    print -rn -- "$s" | openssl dgst -sha1 -binary | od -An -tx1 | tr -d ' \n'
  elif command -v sha1sum >/dev/null 2>&1; then
    print -rn -- "$s" | sha1sum | awk '{print $1}'
  else
    print -rn -- "$s" | tr -d '\n'
  fi
}
_cost_save_cache(){ local k="${1:-}"; shift; [[ -z "$k" ]] && return 0; mkdir -p -- "$(_cost_cache_dir)"; print -r -- "$@" > "$(_cost_cache_dir)/$k.json"; }
_cost_try_cache(){
  local k f mtime
  k="${1:-}"; [[ -z "$k" ]] && return 1
  f="$(_cost_cache_dir)/$k.json"
  if [[ -f "$f" ]]; then
    mtime="$(stat -c %Y "$f" 2>/dev/null || echo 0)"
    if (( EPOCHSECONDS - mtime < COST_CACHE_TTL_SEC )); then
      cat -- "$f"; return 0
    fi
  fi
  return 1
}

# Org map
_cost_linked_map(){
  (( COST_MAP_LINKED != 1 )) && return 0
  command -v aws >/dev/null 2>&1 || return 0
  local next="" out; local -A map
  while :; do
    if [[ -n "$next" ]]; then
      out="$(aws organizations list-accounts --output json --max-items 1000 --starting-token "$next" 2>/dev/null)" || break
    else
      out="$(aws organizations list-accounts --output json --max-items 1000 2>/dev/null)" || break
    fi
    jq -r '.Accounts[] | [.Id,.Name] | @tsv' <<<"$out" | while IFS=$'\t' read -r id name; do
      [[ -n "$id" ]] && map[$id]="$name"
    done
    next="$(jq -r '.NextToken // empty' <<<"$out")"
    [[ -z "$next" ]] && break
  done
  typeset -p map 2>/dev/null | sed -n 's/^typeset -A map=//p'
}

# Range pick
_cost_range_pick(){
  local pick="${1:-MTD}" gran="${2:-DAILY}"
  local today="$(_cost_utc)" tomorrow="$(_cost_now_plus "tomorrow")"
  local start="" end=""
  case "$pick" in
    MTD) start="${today:0:8}01"; end="$tomorrow"; [[ "$gran" == MONTHLY ]] && start="${today:0:4}-01-01";;
    LAST_7D) start="$(_cost_date "7 days ago")"; end="$tomorrow";;
    LAST_30D) start="$(_cost_date "30 days ago")"; end="$tomorrow";;
    LAST_FULL_MONTH)
      local first_this="${today:0:8}01"; local last_month_last="$(_cost_date "$first_this - 1 day")"
      start="${last_month_last:0:8}01"; end="$(_cost_date "${last_month_last:0:8}01 + 1 month")"
      ;;
    LAST_3M) start="$(_cost_date "${today:0:8}01 - 3 months")"; end="$tomorrow";;
    YTD) start="${today:0:4}-01-01"; end="$tomorrow";;
    CUSTOM) print -n "Start YYYY-MM-DD: "; read -r start; print -n "End YYYY-MM-DD (exclusive): "; read -r end;;
    *) _err "bad range '$pick'"; return 1;;
  esac
  print -r -- "$start $end"
}

# CE query
_cost_ce_query(){
  emulate -L zsh
  setopt pipefail
  local start="${1:-}" end="${2:-}" gran="${3:-}" metric="${4:-}"; shift 4
  local -a group_by=() extra=(); local filter_json=""
  while (( $# > 0 )); do
    case "$1" in
      --group-by) group_by+=("${2:-}"); shift 2;;
      --filter)   filter_json="${2:-}"; shift 2;;
      *) extra+=("$1"); shift;;
    esac
  done
  local -a cmd; cmd=(aws ce get-cost-and-usage --time-period "Start=$start,End=$end" --granularity "$gran" --metrics "$metric" --output json)
  local g; for g in "${group_by[@]}"; do [[ -n "$g" ]] && cmd+=(--group-by "Type=DIMENSION,Key=$g"); done
  [[ -n "$filter_json" ]] && cmd+=(--filter "$filter_json")

  local tmpdir; tmpdir="$(mktemp -d)"; local token="" page=0 out rc
  typeset -g COST_API_CALLS; : ${COST_API_CALLS:=0}
  while :; do
    (( page++ ))
    if [[ -n "$token" ]]; then out="$("${cmd[@]}" --next-page-token "$token" 2>&1)"; rc=$?
    else out="$("${cmd[@]}" 2>&1)"; rc=$?; fi
    (( rc != 0 )) && { print -r -- "$out" >&2; return 2; }
    COST_API_CALLS=$((COST_API_CALLS + 1))
    print -r -- "$out" > "$tmpdir/page-$page.json"
    token="$(jq -r '.NextPageToken // empty' "$tmpdir/page-$page.json")"
    [[ -z "$token" ]] && break
  done
  jq -s '{ResultsByTime:(map(.ResultsByTime)|add),
          DimensionValueAttributes:(map(.DimensionValueAttributes//[])|add),
          GroupDefinitions:(map(.GroupDefinitions//[])|add)}' "$tmpdir"/page-*.json
}

# Table
_cost_print_table(){
  emulate -L zsh
  setopt pipefail
  local json="$1" metric="$2" dim_map_serialized="${3:-}"
  local -A namemap=()
  [[ -n "$dim_map_serialized" ]] && eval "typeset -A namemap=$dim_map_serialized"

  local total; total="$(jq -r --arg M "$metric" '[.ResultsByTime[] | (.Total[$M].Amount // "0") | tonumber] | add // 0' <<<"$json")"
  _cost_hr; print -P "%F{244}Top by group%f"

  local rows
  rows="$(
    jq -r --arg M "$metric" '
      if ((.ResultsByTime|length)==0) or (((.ResultsByTime[0].Groups?|length)//0)==0)
      then empty
      else
        [ .ResultsByTime[] | .Groups[] | {k:(.Keys|join(" • ")), a:((.Metrics[$M].Amount // "0")|tonumber)} ]
        | group_by(.k) | map({k: .[0].k, a:(map(.a)|add)}) | sort_by(-.a)
        | .[] | [.k, (.a|tostring)] | @tsv
      end' <<<"$json"
  )"

  if [[ -z "$rows" ]]; then
    print "No group breakdown in this view."
    _cost_hr; return 0
  fi

  local key amt name w=0
  while IFS=$'\t' read -r key amt; do
    name="$key"; [[ -n "${namemap[$key]-}" ]] && name="${namemap[$key]} ($key)"
    (( ${#name} > w )) && w=${#name}
  done <<< "$rows"
  (( w > 48 )) && w=48

  printf "%-${w}s  %12s  %7s  %s\n" "Group" "$metric" "% of total" "bar"
  printf "%-${w}s  %12s  %7s  %s\n" "$(printf '%.0s-' {1..$w})" "------------" "-------" "----"
  while IFS=$'\t' read -r key amt; do
    name="$key"; [[ -n "${namemap[$key]-}" ]] && name="${namemap[$key]} ($key)"
    local pct="0.0"; if awk -v t="$total" 'BEGIN{exit !(t>0)}'; then pct="$(awk -v a="$amt" -v t="$total" 'BEGIN{printf("%.1f",(a*100)/t)}')"; fi
    local blen; blen="$(awk -v a="$amt" -v t="$total" 'BEGIN{if(t>0){printf("%d",28*a/t)}else{printf("0")}}')"
    (( blen<0 ))&&blen=0; (( blen>28 ))&&blen=28
    local bar; bar="$(printf "%${blen}s" "" | tr " " "█")"
    printf "%-${w}.${w}s  %12.2f  %6s%%  %s\n" "$name" "$amt" "$pct" "$bar"
  done <<< "$rows"
  _cost_hr
}

# Filter picker
_cost_pick_filter(){
  emulate -L zsh
  setopt pipefail
  local start="${1:-}" end="${2:-}"
  local dims=("NONE" "LINKED_ACCOUNT" "REGION" "SERVICE" "USAGE_TYPE" "OPERATION" "RECORD_TYPE")
  local picker=""
  if command -v fzf >/dev/null 2>&1; then
    picker="$(printf "%s\n" "${dims[@]}" | fzf --prompt="Filter dimension ⇢ " --height=40% --border --no-multi)" || true
  else
    print "Filter dimension [NONE/LINKED_ACCOUNT/REGION/SERVICE/USAGE_TYPE/OPERATION/RECORD_TYPE]: "; read -r picker
  fi
  [[ -z "$picker" || "$picker" == "NONE" ]] && { print -r ""; return 0; }

  _note "Fetching values for $picker"
  local vals="" token="" out
  while :; do
    if [[ -n "$token" ]]; then
      out="$(aws ce get-dimension-values --time-period "Start=$start,End=$end" --dimension "$picker" --context COST_AND_USAGE --output json --next-page-token "$token" 2>/dev/null)" || break
    else
      out="$(aws ce get-dimension-values --time-period "Start=$start,End=$end" --dimension "$picker" --context COST_AND_USAGE --output json 2>/dev/null)" || break
    fi
    vals+="$(
      jq -r '.DimensionValues[]?.Value' <<<"$out"
    )"$'\n'
    token="$(jq -r '.NextPageToken // empty' <<<"$out")"
    [[ -z "$token" ]] && break
  done

  local picked=""
  if command -v fzf >/dev/null 2>&1; then
    picked="$(print -r -- "$vals" | sed '/^$/d' | fzf --multi --height=70% --prompt="$picker filter ⇢ ")" || true
  else
    print "Enter one value: "; read -r picked
  fi
  [[ -z "$picked" ]] && { print -r ""; return 0; }
  jq -n --arg k "$picker" --argjson v "$(printf '%s\n' "$picked" | jq -R . | jq -s '.')" \
    '{Dimensions:{Key:$k,Values:$v}}'
}

# Main
cost(){
  emulate -L zsh
  setopt localoptions err_return no_unset pipefail

  _cost_check || return 1

  local -a ranges groups grans
  ranges=("MTD" "LAST_7D" "LAST_30D" "LAST_FULL_MONTH" "LAST_3M" "YTD" "CUSTOM")
  groups=("SERVICE" "REGION" "LINKED_ACCOUNT" "USAGE_TYPE" "OPERATION" "INSTANCE_TYPE" "PURCHASE_TYPE" "RECORD_TYPE" "NONE")
  grans=("DAILY" "MONTHLY")

  local rpick="$COST_DEF_RANGE" gpick="$COST_DEF_GROUP" gran="$COST_DEF_GRAN"
  if command -v fzf >/dev/null 2>&1; then
    rpick="$(printf "%s\n" "${ranges[@]}" | fzf --prompt="Range ⇢ " --height=40% --border --query="$COST_DEF_RANGE")" || return 1
    gpick="$(printf "%s\n" "${groups[@]}" | fzf --prompt="Group-by ⇢ " --height=40% --border --query="$COST_DEF_GROUP")" || return 1
    gran="$(printf "%s\n" "${grans[@]}"  | fzf --prompt="Granularity ⇢ " --height=30% --border --query="$COST_DEF_GRAN")" || return 1
  fi

  local start end; read start end <<<"$(_cost_range_pick "$rpick" "$gran")" || return 1

  local filter_json=""; filter_json="$(_cost_pick_filter "$start" "$end")" || filter_json=""
  local -a gflags=(); [[ "$gpick" != "NONE" ]] && gflags+=(--group-by "$gpick")

  local cache_key; cache_key="$(_cost_cache_key "$start|$end|$gran|$COST_METRIC|$gpick|$filter_json")"
  local combined=""
  if combined="$(_cost_try_cache "$cache_key")"; then
    _note "cache hit for this view"; typeset -g COST_API_CALLS=0
  else
    _note "querying Cost Explorer"; typeset -g COST_API_CALLS=0
    combined="$(_cost_ce_query "$start" "$end" "$gran" "$COST_METRIC" "${gflags[@]}" ${filter_json:+--filter "$filter_json"})" || { _err "Cost Explorer query failed"; return 2; }
    _cost_save_cache "$cache_key" "$combined"
  fi

  local total; total="$(jq -r --arg M "$COST_METRIC" '[.ResultsByTime[] | (.Total[$M].Amount // "0") | tonumber] | add // 0' <<<"$combined")"

  _cost_hr
  print -P "%F{6}AWS COST%f  %F{244}${start}%f → %F{244}${end}%f  gran=%F{244}${gran}%f  metric=%F{244}${COST_METRIC}%f"
  print -P "Group=%F{244}${gpick}%f   Filter=%F{244}${${filter_json:-none}}%f"
  print -P "Total: %F{2}$([ -n "$total" ] && printf "%.2f" "$total" || echo 0)%f USD"

  if [[ "$gran" == "DAILY" ]]; then
    local series; series="$(jq -r --arg M "$COST_METRIC" '.ResultsByTime[] | (.Total[$M].Amount // "0")' <<<"$combined")"
    local -a nums; nums=("${(@f)$(print -r -- "$series" | awk '{printf "%.4f\n",$1}')}")
    local sl; sl="$(_cost_spark "${nums[@]}")"; [[ -n "$sl" ]] && print -P "Daily: $sl"
  fi

  local m=""; if [[ "$gpick" == "LINKED_ACCOUNT" && "$COST_MAP_LINKED" == "1" ]]; then m="$(_cost_linked_map)" || m=""; fi
  _cost_print_table "$combined" "$COST_METRIC" "$m"

  # Drilldown (fzf)
  if command -v fzf >/dev/null 2>&1 && [[ "$gpick" != "NONE" ]]; then
    local drill_target; drill_target="$(
      jq -r --arg M "$COST_METRIC" '
        if ((.ResultsByTime|length)==0) or (((.ResultsByTime[0].Groups?|length)//0)==0) then empty
        else
          [ .ResultsByTime[] | .Groups[] | {k:(.Keys|join(" • ")), a:((.Metrics[$M].Amount // "0")|tonumber)} ]
          | group_by(.k) | map({k: .[0].k, a:(map(.a)|add)}) | sort_by(-.a)
          | .[] | [.k, (.a|tostring)] | @tsv
        end' <<<"$combined" \
      | awk -F'\t' '{printf "%-48s  %12s\n",$1,$2}' \
      | fzf --prompt="drill into ⇢ " --height=60% --border --ansi --no-multi --header="Enter to drill; Esc to quit"
    )" || true
    if [[ -n "$drill_target" ]]; then
      local val="${drill_target%%  *}"
      _note "drilling into $gpick = ${val}"
      local f2; f2="$(jq -n --arg k "$gpick" --arg v "$val" '{Dimensions:{Key:$k,Values:[$v]}}')"
      local subg; subg="$(printf "%s\n" "SERVICE" "REGION" "USAGE_TYPE" "OPERATION" "RECORD_TYPE" "NONE" | fzf --prompt="secondary group ⇢ " --height=40% --border --query="SERVICE")" || subg="SERVICE"
      local -a sgflags=(); [[ "$subg" != "NONE" ]] && sgflags+=(--group-by "$subg")
      local subkey; subkey="$(_cost_cache_key "$start|$end|$gran|$COST_METRIC|$gpick=$val|$subg")"
      local sub=""
      if sub="$(_cost_try_cache "$subkey")"; then
        _note "cache hit (drilldown)"; typeset -g COST_API_CALLS=0
      else
        typeset -g COST_API_CALLS=0
        sub="$(_cost_ce_query "$start" "$end" "$gran" "$COST_METRIC" "${sgflags[@]}" --filter "$f2")" || { _err "drilldown query failed"; return 2; }
        _cost_save_cache "$subkey" "$sub"
      fi
      _cost_hr; print -P "%F{6}DRILL%f  $gpick=%F{244}${val}%f  sub=%F{244}${subg}%f"
      _cost_print_table "$sub" "$COST_METRIC"
    fi
  fi

  if [[ "${COST_API_CALLS:-0}" -gt 0 ]]; then
    local calls="$COST_API_CALLS"; local est; est="$(awk -v n="$calls" 'BEGIN{printf("$%.2f", 0.01*n)}')"
    _note "Cost Explorer API calls: $calls  est charge: $est"
  fi
}

# Quick preset
cost.quick(){
  emulate -L zsh
  setopt pipefail
  COST_DEF_GRAN=MONTHLY COST_DEF_GROUP=SERVICE COST_DEF_RANGE=LAST_3M cost
}

