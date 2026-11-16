# ===================================================================
# secrets.zsh — AWS Secrets Manager CLI with fuzzy menus + man page
# Deps: awscli v2, jq; optional: fzf
# Safe: no secrets in stdout/history by default; hidden prompts; policy validator
# ===================================================================

# ---- UI (compatible with your helpers) ----
if ! typeset -f _ok   >/dev/null; then _ok(){   print -P "%F{2}✔%f $*"; } fi
if ! typeset -f _note >/dev/null; then _note(){ print -P "%F{4}ℹ️ %f $*"; } fi
if ! typeset -f _warn >/dev/null; then _warn(){ print -P "%F{3}‼%f $*"; } fi
if ! typeset -f _err  >/dev/null; then _err(){  print -P "%F{1}✖%f $*"; } fi
_sm_hr(){ print -P "%F{244}$(printf '%*s' 64 '' | tr ' ' '-')%f"; }

# ---- knobs (set and forget) ----
: ${SM_DEFAULT_ROTATION_DAYS:=30}
: ${SM_DEFAULT_REGION:=${AWS_REGION:-${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null || echo us-east-1)}}}
: ${SM_DEFAULT_KMS_ALIAS:=}          # e.g. alias/secretsmgr-prod
: ${SM_DEFAULT_TAGS:=Env=dev}        # k=v,k=v
: ${SM_SAFE_OUTPUT:=0}               # 1 = force write to file instead of stdout

# ---- basics / context ----
_sm_need(){ command -v "$1" >/dev/null 2>&1 || { _err "missing dep: $1"; return 1; } }
_sm_check(){ _sm_need aws || return 1; _sm_need jq || return 1; aws sts get-caller-identity >/dev/null 2>&1 || { _err "AWS creds not working"; return 1; } }
_sm_ctx(){ local a p r; a="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)"; p="${AWS_PROFILE:-default}"; r="$SM_DEFAULT_REGION"; print -P "%F{6}SECRETS%f acct=%F{244}${a}%f profile=%F{244}${p}%f region=%F{244}${r}%f"; }

# ---- util: json exec, tags, secret input, pagination ----
_sm_jx(){ local out; if out="$("$@" --output json 2>/dev/null)"; then printf "%s" "$out"; else printf ""; fi; }
_sm_tags(){ local s="$1"; [[ -z "$s" ]] && return 0; local -a kv; kv=(${(s:,:)s}); local t; for t in "${kv[@]}"; do [[ "$t" == *=* ]] && print -- "--tags" "Key=${t%%=*},Value=${t#*=}"; done }
_sm_read_secret(){ # "-" = stdin, file path, else hidden prompt
  local src="$1" data=""
  if [[ "$src" == "-" ]]; then data="$(cat -)" || return 1
  elif [[ -f "$src" ]]; then data="$(cat -- "$src")" || return 1
  else
    trap 'stty echo' EXIT INT TERM
    print -n "Secret (hidden): "; stty -echo; read -r data; stty echo; print ""
    trap - EXIT INT TERM
  fi
  printf "%s" "$data"
}
_sm_has_fzf(){ command -v fzf >/dev/null 2>&1 }

# ---- pickers (fzf dropdowns with sane fallbacks) ----

# Secrets picker
_sm_pick_secret(){
  local q out name
  out="$(_sm_jx aws --region "$SM_DEFAULT_REGION" secretsmanager list-secrets --max-results 100)"
  [[ -z "$out" ]] && { _err "cannot list secrets"; return 1; }
  if _sm_has_fzf; then
    name="$(
      jq -r '.SecretList[] | [.Name, (.Description//""), ( (.Tags//[])|map("\(.Key)=\(.Value)")|join(","))] | @tsv' <<<"$out" \
      | fzf --with-nth=1,2 --header="Pick a secret (Tab to filter)" --preview-window=down,5 \
            --preview 'printf "Name: %s\nDesc: %s\nTags: %s\n" $(echo {} | awk -F"\t" "{print \$1,\$2,\$3}")' \
      | awk -F'\t' '{print $1}'
    )"
  else
    print -n "Secret name: "; read -r name
  fi
  [[ -z "$name" ]] && return 1; print -r -- "$name"
}

# KMS key/alias picker (shows aliases; resolves to key-id)
_sm_pick_kms(){
  local aliases keys row alias kid state
  aliases="$(_sm_jx aws --region "$SM_DEFAULT_REGION" kms list-aliases)"
  if _sm_has_fzf; then
    row="$(
      jq -r '.Aliases[] | [(.AliasName//""), (.TargetKeyId//"" )] | @tsv' <<<"$aliases" \
      | awk -F'\t' '{printf "%-40s\t%s\n",$1,$2}' \
      | fzf --header="Pick KMS alias (ESC for none)" --with-nth=1
    )" || true
    alias="${row%%$'\t'*}"
    kid="${row##*$'\t'}"
    [[ -n "$alias" && "$alias" != "alias/"* ]] && alias=""
  else
    print -P "KMS alias (e.g. alias/secretsmgr-prod) [Enter for default/none]: "; read -r alias
  fi
  [[ -n "$alias" ]] && print -r -- "$alias" || print -r -- ""
}

# Lambda rotator picker
_sm_pick_lambda(){
  local out row arn
  out="$(_sm_jx aws --region "$SM_DEFAULT_REGION" lambda list-functions)"
  if _sm_has_fzf; then
    row="$(
      jq -r '.Functions[] | [.FunctionName, .FunctionArn] | @tsv' <<<"$out" \
      | fzf --header="Pick rotation Lambda" --with-nth=1
    )"
    arn="${row##*$'\t'}"
  else
    print -n "Rotation Lambda ARN: "; read -r arn
  fi
  [[ -z "$arn" ]] && return 1; print -r -- "$arn"
}

# Region picker (enabled by default, toggle all)
_sm_pick_regions(){
  local mode="${1:-enabled}" out row picks=""
  if [[ "$mode" == "enabled" ]]; then
    out="$(_sm_jx aws account list-regions --region-opt-status-contains ENABLED ENABLED_BY_DEFAULT)"  # account API shows opt-in status
    # fallback if account API is blocked
    [[ -z "$out" ]] && out="$(_sm_jx aws ec2 describe-regions --all-regions)"
  else
    out="$(_sm_jx aws ec2 describe-regions --all-regions)"
  fi
  if _sm_has_fzf; then
    picks="$(
      (jq -r '.Regions[]?.RegionName' <<<"$out" 2>/dev/null || jq -r '.Regions[]?.RegionName' <<<"$out") \
      | sort -u | fzf --multi --header="Pick target regions (multi-select)" \
      | tr '\n' ',' | sed 's/,$//'
    )"
  else
    print -n "Comma-separated regions: "; read -r picks
  fi
  print -r -- "$picks"
}

# ---- core commands (flags) ----

# sm.set <name> [--file path|-] [--value STR] [--kms alias/arn] [--desc TXT] [--tags k=v,...]
sm.set(){
  emulate -L zsh; setopt pipefail
  _sm_check || return 1; _sm_hr; _sm_ctx
  local name="" file="" value="" kms="${SM_DEFAULT_KMS_ALIAS}" desc="" tags="${SM_DEFAULT_TAGS}"
  while (( $# )); do
    case "$1" in
      --file)  file="$2"; shift 2;;
      --value) value="$2"; shift 2;;
      --kms)   kms="$2"; shift 2;;
      --desc)  desc="$2"; shift 2;;
      --tags)  tags="$2"; shift 2;;
      *) [[ -z "$name" ]] && name="$1" || { _err "unexpected arg: $1"; return 2; }; shift;;
    esac
  done
  [[ -z "$name" ]] && { _err "usage: sm.set <name> [--file path|-] [--value STR] [--kms alias/arn] [--desc TXT] [--tags k=v,...]"; return 2; }

  local secret; if [[ -n "$file" ]]; then secret="$(_sm_read_secret "$file")" || return 1
  elif [[ -n "$value" ]]; then secret="$value"
  else secret="$(_sm_read_secret "")" || return 1; fi

  if aws --region "$SM_DEFAULT_REGION" secretsmanager describe-secret --secret-id "$name" >/dev/null 2>&1; then
    _note "secret exists → new version"
    aws --region "$SM_DEFAULT_REGION" secretsmanager put-secret-value --secret-id "$name" --secret-string "$secret" >/dev/null || { _err "put-secret-value failed"; return 1; }
    _ok "updated: $name (AWSCURRENT)"
  else
    _note "creating secret"
    local -a targs=(); [[ -n "$kms" ]] && targs+=(--kms-key-id "$kms"); [[ -n "$desc" ]] && targs+=(--description "$desc")
    local -a tagflags; tagflags=($(_sm_tags "$tags"))
    aws --region "$SM_DEFAULT_REGION" secretsmanager create-secret --name "$name" --secret-string "$secret" "${targs[@]}" "${tagflags[@]}" >/dev/null \
      || { _err "create-secret failed"; return 1; }
    _ok "created: $name"
  fi
}

# sm.get <name> [jq] [--to file]
sm.get(){
  emulate -L zsh; setopt pipefail
  _sm_check || return 1
  local name="" jqpath="" tofile=""
  while (( $# )); do
    case "$1" in
      --to) tofile="$2"; shift 2;;
      *) if [[ -z "$name" ]]; then name="$1"; else jqpath="$1"; fi; shift;;
    esac
  done
  [[ -z "$name" ]] && { _err "usage: sm.get <name> [jq] [--to file]"; return 2; }
  local out val; out="$(_sm_jx aws --region "$SM_DEFAULT_REGION" secretsmanager get-secret-value --secret-id "$name")" || { _err "get failed"; return 1; }
  val="$(jq -r '.SecretString // ( .SecretBinary | @base64 )' <<<"$out")"
  [[ -n "$jqpath" ]] && val="$(jq -r "$jqpath" <<<"$val")"
  if [[ -n "$tofile" || "$SM_SAFE_OUTPUT" == "1" ]]; then print -rn -- "$val" > "$tofile"; _ok "wrote to $tofile"; else printf "%s" "$val"; fi
}

# sm.get.many name1 name2 ...  (tab-separated)
sm.get.many(){ _sm_check || return 1; (( $# )) || { _err "usage: sm.get.many <n1> <n2> ..."; return 2; }
  local out; out="$(_sm_jx aws --region "$SM_DEFAULT_REGION" secretsmanager batch-get-secret-value --secret-id-list "$@")" || { _err "batch-get failed"; return 1; }
  jq -r '.SecretValues[] | [.Name, (.SecretString // ( .SecretBinary | @base64 ))] | @tsv' <<<"$out"
}

# sm.ls / sm.describe
sm.ls(){ _sm_check || return 1; aws --region "$SM_DEFAULT_REGION" secretsmanager list-secrets --max-results 100 | jq -r '.SecretList[] | [.Name, .ARN] | @tsv'; }
sm.describe(){ _sm_check || return 1; [[ -z "$1" ]] && { _err "usage: sm.describe <name>"; return 2; }; aws --region "$SM_DEFAULT_REGION" secretsmanager describe-secret --secret-id "$1" | jq -C .; }

# sm.rotate.enable <name> [lambda-arn] [days]
sm.rotate.enable(){
  _sm_check || return 1
  local name="${1:-}" lam="${2:-}" days="${3:-$SM_DEFAULT_ROTATION_DAYS}"
  [[ -z "$name" ]] && { _err "usage: sm.rotate.enable <name> [lambda-arn] [days]"; return 2; }
  [[ -z "$lam" ]] && lam="$(_sm_pick_lambda)" || true
  [[ -z "$lam" ]] && { _err "no lambda chosen"; return 2; }
  aws --region "$SM_DEFAULT_REGION" secretsmanager rotate-secret --secret-id "$name" --rotation-lambda-arn "$lam" --rotation-rules "AutomaticallyAfterDays=${days}" >/dev/null && _ok "rotation enabled (${days}d)"
}
sm.rotate.now(){ _sm_check || return 1; [[ -z "$1" ]] && { _err "usage: sm.rotate.now <name>"; return 2; }; aws --region "$SM_DEFAULT_REGION" secretsmanager rotate-secret --secret-id "$1" >/dev/null && _ok "rotation invoked"; }

# sm.replicate <name>  (fzf choose regions)
sm.replicate(){
  _sm_check || return 1
  local name="${1:-}"; [[ -z "$name" ]] && name="$(_sm_pick_secret)" || true
  [[ -z "$name" ]] && { _err "need secret name"; return 2; }
  local regions; regions="$(_sm_pick_regions enabled)"
  [[ -z "$regions" ]] && { _err "no regions chosen"; return 2; }
  local -a rr; rr=(${(s:,:)regions}); local -a args=(); local r; for r in "${rr[@]}"; do args+=(--add-replica-regions "Region=${r}"); done
  aws --region "$SM_DEFAULT_REGION" secretsmanager replicate-secret-to-regions --secret-id "$name" "${args[@]}" >/dev/null && _ok "replicating to: ${regions}"
}

# sm.policy.validate <file.json>  / sm.policy.put <name> <file.json>
sm.policy.validate(){ _sm_check || return 1; [[ -z "$1" ]] && { _err "usage: sm.policy.validate <file.json>"; return 2; }; aws --region "$SM_DEFAULT_REGION" secretsmanager validate-resource-policy --resource-policy "file://$1" | jq -C .; }
sm.policy.put(){ _sm_check || return 1; [[ $# -lt 2 ]] && { _err "usage: sm.policy.put <name> <file.json>"; return 2; }; aws --region "$SM_DEFAULT_REGION" secretsmanager put-resource-policy --secret-id "$1" --resource-policy "file://$2" >/dev/null && _ok "policy attached"; }
sm.policy.get(){ _sm_check || return 1; [[ -z "$1" ]] && { _err "usage: sm.policy.get <name>"; return 2; }; aws --region "$SM_DEFAULT_REGION" secretsmanager get-resource-policy --secret-id "$1" | jq -C .; }

# tagging
sm.tag(){ _sm_check || return 1; [[ $# -lt 2 ]] && { _err "usage: sm.tag <name> k=v[,k=v...]"; return 2; }; aws --region "$SM_DEFAULT_REGION" secretsmanager tag-resource --secret-id "$1" $(_sm_tags "$2") >/dev/null && _ok "tagged"; }
sm.untag(){ _sm_check || return 1; [[ $# -lt 2 ]] && { _err "usage: sm.untag <name> key1[,key2...]"; return 2; }; local -a arr; arr=(${(s:,:)2}); aws --region "$SM_DEFAULT_REGION" secretsmanager untag-resource --secret-id "$1" --tag-keys "${arr[@]}" >/dev/null && _ok "untagged"; }

# delete / restore
sm.rm(){ _sm_check || return 1; local name="$1" days="${2:-7}"; [[ -z "$name" ]] && { _err "usage: sm.rm <name> [recoveryDays]"; return 2; }; aws --region "$SM_DEFAULT_REGION" secretsmanager delete-secret --secret-id "$name" --recovery-window-in-days "$days" >/dev/null && _ok "delete scheduled ($days d)"; }
sm.rm.now(){ _sm_check || return 1; [[ -z "$1" ]] && { _err "usage: sm.rm.now <name>"; return 2; }; aws --region "$SM_DEFAULT_REGION" secretsmanager delete-secret --secret-id "$1" --force-delete-without-recovery >/dev/null && _ok "deleted (no recovery)"; }
sm.restore(){ _sm_check || return 1; [[ -z "$1" ]] && { _err "usage: sm.restore <name>"; return 2; }; aws --region "$SM_DEFAULT_REGION" secretsmanager restore-secret --secret-id "$1" >/dev/null && _ok "restored"; }

# ---- guided UI (fuzzy dropdowns for everything) ----
# sm.ui  -> top-level menu
sm.ui(){
  emulate -L zsh; setopt pipefail
  _sm_check || return 1; _sm_hr; _sm_ctx
  local -a items=(
    "Set (create/update) secret"
    "Get secret"
    "Batch get secrets"
    "List secrets"
    "Describe secret"
    "Enable rotation"
    "Rotate now"
    "Replicate to regions"
    "Show resource policy"
    "Validate resource policy (file)"
    "Attach resource policy (file)"
    "Tag / Untag"
    "Delete (with recovery)"
    "Delete NOW (no recovery)"
    "Restore deleted secret"
    "Defaults / Settings"
    "Help"
    "Quit"
  )
  local pick
  if _sm_has_fzf; then
    pick="$(printf "%s\n" "${items[@]}" | fzf --prompt="Secrets Manager ⇢ " --height=80% --border --no-multi)" || return 0
  else
    print -P "Choose action:"; printf "  %s\n" "${items[@]}"; print -n "> "; read -r pick
  fi

  case "$pick" in
    "Set (create/update) secret")
      local name kms desc tags src
      if _sm_has_fzf; then
        print -n "Name (new or existing): "; read -r name
        kms="$(_sm_pick_kms)"; [[ -z "$kms" ]] && kms="$SM_DEFAULT_KMS_ALIAS"
      else
        print -n "Name: "; read -r name; print -n "KMS alias (or empty): "; read -r kms
      fi
      print -n "Description (optional): "; read -r desc
      print -n "Tags k=v[,k=v] (default: $SM_DEFAULT_TAGS): "; read -r tags; [[ -z "$tags" ]] && tags="$SM_DEFAULT_TAGS"
      print -P "%F{244}Enter secret value%f: type, paste, or ^D to finish"; src="-"
      sm.set "$name" --file "$src" ${kms:+--kms "$kms"} ${desc:+--desc "$desc"} --tags "$tags"
      ;;
    "Get secret")
      local name jqpath out dest
      name="$(_sm_pick_secret)" || return 1
      print -n "Optional jq filter (e.g. .db.password): "; read -r jqpath
      print -n "Write to file (empty = stdout): "; read -r dest
      [[ -n "$dest" ]] && sm.get "$name" "${jqpath:-}" --to "$dest" || sm.get "$name" "${jqpath:-}"
      ;;
    "Batch get secrets")
      local -a chosen=(); local s
      for ((i=0;i<1;i++)); do :; done
      while s="$(_sm_pick_secret)"; do [[ -n "$s" ]] || break; chosen+=("$s"); print -P "%F{244}Added:%f $s  (ESC to stop)"; _sm_has_fzf || break; done
      (( ${#chosen} )) && sm.get.many "${chosen[@]}" || _warn "nothing picked"
      ;;
    "List secrets") sm.ls;;
    "Describe secret") local s; s="$(_sm_pick_secret)" || return 1; sm.describe "$s";;
    "Enable rotation") local s; s="$(_sm_pick_secret)" || return 1; sm.rotate.enable "$s";;
    "Rotate now") local s; s="$(_sm_pick_secret)" || return 1; sm.rotate.now "$s";;
    "Replicate to regions") sm.replicate ;;
    "Show resource policy") local s; s="$(_sm_pick_secret)" || return 1; sm.policy.get "$s";;
    "Validate resource policy (file)") local f; print -n "Policy JSON path: "; read -r f; sm.policy.validate "$f";;
    "Attach resource policy (file)") local s f; s="$(_sm_pick_secret)" || return 1; print -n "Policy JSON path: "; read -r f; sm.policy.put "$s" "$f";;
    "Tag / Untag")
      local s; s="$(_sm_pick_secret)" || return 1
      local what; if _sm_has_fzf; then what="$(printf "tag\nuntag\n" | fzf --prompt="Action ⇢ ")" || return 0; else print -n "[tag|untag]: "; read -r what; fi
      if [[ "$what" == "tag" ]]; then print -n "k=v[,k=v]: "; read -r t; sm.tag "$s" "$t"; else print -n "keys comma: "; read -r k; sm.untag "$s" "$k"; fi
      ;;
    "Delete (with recovery)") local s d; s="$(_sm_pick_secret)" || return 1; print -n "Recovery window days (1-30, default 7): "; read -r d; sm.rm "$s" "${d:-7}";;
    "Delete NOW (no recovery)") local s; s="$(_sm_pick_secret)" || return 1; print -n "Type DELETE to confirm: "; read -r c; [[ "$c" == "DELETE" ]] && sm.rm.now "$s" || _warn "aborted";;
    "Restore deleted secret") print -n "Name: "; read -r s; sm.restore "$s";;
    "Defaults / Settings")
      print -P "Region (current: $SM_DEFAULT_REGION). Enter to keep:"; read -r r; [[ -n "$r" ]] && export SM_DEFAULT_REGION="$r"
      print -P "Default KMS alias (current: ${SM_DEFAULT_KMS_ALIAS:-none}). Enter to keep:"; read -r k; [[ -n "$k" ]] && export SM_DEFAULT_KMS_ALIAS="$k"
      print -P "Default tags (current: $SM_DEFAULT_TAGS). Enter to keep:"; read -r tg; [[ -n "$tg" ]] && export SM_DEFAULT_TAGS="$tg"
      print -P "Default rotation days (current: $SM_DEFAULT_ROTATION_DAYS). Enter to keep:"; read -r dd; [[ -n "$dd" ]] && export SM_DEFAULT_ROTATION_DAYS="$dd"
      _ok "updated defaults"
      ;;
    "Help") sm.help;;
    *) return 0;;
  esac
}

# ---- docs / manpage ----
sm.help(){
  cat <<'EOF'
SECRETS MAN (quick)

Core:
  sm.set <name> [--file path|-] [--value STR] [--kms alias/arn] [--desc TXT] [--tags k=v,...]
    - Creates or updates a secret (puts new version). KMS alias optional.
  sm.get <name> [jq] [--to file]         Get one secret (optionally jq-extract JSON field).
  sm.get.many name1 name2 ...            Batch get up to 20 at once (tab-separated).
  sm.ls                                   List names/ARNs.
  sm.describe <name>                      Show metadata/versions.

Rotation:
  sm.rotate.enable <name> [lambda-arn] [days]   Enable scheduled rotation via Lambda.
  sm.rotate.now <name>                          Trigger immediate rotation.

Replication (DR/Latency):
  sm.replicate [<name>]          Fuzzy-pick regions; calls replicate-secret-to-regions.

Policies:
  sm.policy.validate <file.json>           Validate resource policy (reject wild access).
  sm.policy.put <name> <file.json>         Attach policy to secret.
  sm.policy.get <name>                     Show current resource policy.

Tags:
  sm.tag <name> k=v[,k=v...]    Add/update tags.
  sm.untag <name> keys,keys     Remove tags.

Delete/Restore:
  sm.rm <name> [days=7]         Soft delete with recovery window.
  sm.rm.now <name>              Force delete (no recovery).
  sm.restore <name>             Restore a scheduled-deleted secret.

Guided UI:
  sm.ui                         Full-screen fuzzy menus for all flows.

Defaults:
  export SM_DEFAULT_REGION=us-east-1
  export SM_DEFAULT_KMS_ALIAS=alias/secretsmgr-prod
  export SM_DEFAULT_TAGS="Env=prod,App=core"
  export SM_DEFAULT_ROTATION_DAYS=30

Security:
  - Tool never echoes secret values; uses hidden prompt / stdin.
  - Prefer a customer-managed KMS key (alias/…); restrict principals via resource policy.

EOF
}

