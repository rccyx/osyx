# ---------- iamwho (self contained) ----------
iamwho() {
  emulate -L zsh
  setopt pipefail

  # ------- minimal log helpers if your globals are missing -------
  if ! typeset -f _ok   >/dev/null; then _ok(){   print -P "%F{2}✔%f $*"; } fi
  if ! typeset -f _note >/dev/null; then _note(){ print -P "%F{4}ℹ️  %f $*"; } fi
  if ! typeset -f _warn >/dev/null; then _warn(){ print -P "%F{3}‼%f $*"; } fi
  if ! typeset -f _err  >/dev/null; then _err(){  print -P "%F{1}✖%f $*"; } fi
  if ! typeset -f _hr   >/dev/null; then _hr(){   print -P "%F{244}${(l:60::-:)}%f"; } fi

  # ------- local dep checker -------
  _need() { command -v "$1" >/dev/null 2>&1 || { _err "missing dep: $1"; return 1; }; }

  # flags
  local DEEP=0
  case "${1:-}" in
    -d|--deep) DEEP=1; shift;;
  esac

  # deps
  _need aws || return 1
  _need jq  || return 1

  # context
  local profile region
  profile="${AWS_PROFILE:-default}"
  region="${AWS_REGION:-${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null || echo us-east-1)}}"

  # identity
  local ident acct userId arn
  ident="$(aws sts get-caller-identity --output json 2>/dev/null)" \
    || { _err "sts get-caller-identity failed. Check AWS creds or MFA session."; return 1; }
  acct="$(jq -r '.Account' <<<"$ident")"
  userId="$(jq -r '.UserId'  <<<"$ident")"
  arn="$(jq -r '.Arn'        <<<"$ident")"

  _hr
  print -P "%F{6}AWS Context%f"
  print -P "  %F{4}Profile:%f  $profile"
  print -P "  %F{4}Region:%f   $region"
  _hr
  print -P "%F{6}Principal%f"
  print -P "  %F{4}Account:%f  $acct"
  print -P "  %F{4}UserId:%f   $userId"
  print -P "  %F{4}ARN:%f      $arn"
  _hr

  # classify principal
  local ptype uname role sname
  if [[ "$arn" == *":user/"* ]]; then
    ptype="user"
    uname="${arn##*/}"
  elif [[ "$arn" == *":assumed-role/"* ]]; then
    ptype="assumed-role"
    role="${arn##*:assumed-role/}"; sname="${role#*/}"; role="${role%%/*}"
  elif [[ "$arn" == *":role/"* ]]; then
    ptype="role"
    role="${arn##*:role/}"; role="${role##*/}"
  else
    ptype="unknown"
  fi

  # tolerant exec that returns empty on AccessDenied
  _jx() { local out; if out="$("$@" --output json 2>/dev/null)"; then printf "%s" "$out"; else printf ""; fi; }

  # print permissions boundary if present
  _print_user_boundary() {
    local ju pb
    ju="$(_jx aws iam get-user --user-name "$1")"
    pb="$(jq -r '.User.PermissionsBoundary.PermissionsBoundaryArn // empty' <<<"$ju" 2>/dev/null)"
    [[ -n "$pb" ]] && print -P "  %F{4}PermissionsBoundary:%f $pb"
  }
  _print_role_boundary() {
    local jr pb
    jr="$(_jx aws iam get-role --role-name "$1")"
    pb="$(jq -r '.Role.PermissionsBoundary.PermissionsBoundaryArn // empty' <<<"$jr" 2>/dev/null)"
    [[ -n "$pb" ]] && print -P "  %F{4}PermissionsBoundary:%f $pb"
  }

  if [[ "$ptype" == "user" ]]; then
    print -P "%F{6}User%f  %F{4}$uname%f"
    _print_user_boundary "$uname"

    # groups
    local groups gcount
    groups="$(_jx aws iam list-groups-for-user --user-name "$uname")"
    if [[ -z "$groups" ]]; then
      _note "groups not visible or none attached"
    else
      gcount="$(jq -r '.Groups | length' <<<"$groups")"
      if (( gcount == 0 )); then
        _note "no groups"
      else
        print -P "  %F{4}Groups:%f"
        jq -r '.Groups[]?.GroupName' <<<"$groups" | sed 's/^/    - /'
      fi
    fi

    # direct user policies
    local ap ip
    ap="$(_jx aws iam list-attached-user-policies --user-name "$uname")"
    ip="$(_jx aws iam list-user-policies          --user-name "$uname")"

    if [[ -z "$ap$ip" ]]; then
      _note "no policies directly attached to user"
    else
      print -P "%F{6}User Policies%f"
      if [[ -n "$ap" && "$(jq -r '.AttachedPolicies | length' <<<"$ap")" != "0" ]]; then
        print -P "  %F{4}Attached:%f"
        if (( DEEP )); then
          jq -r '.AttachedPolicies[]? | [.PolicyName, .PolicyArn] | @tsv' <<<"$ap" \
            | awk -F'\t' '{printf "    - %s  (%s)\n",$1,$2}'
        else
          jq -r '.AttachedPolicies[]?.PolicyName' <<<"$ap" | sed 's/^/    - /'
        fi
      fi
      if [[ -n "$ip" && "$(jq -r '.PolicyNames | length' <<<"$ip")" != "0" ]]; then
        print -P "  %F{4}Inline:%f"
        jq -r '.PolicyNames[]?' <<<"$ip" | sed 's/^/    - /'
      fi
    fi

    # group policy surface
    if [[ -n "$groups" && "$(jq -r '.Groups | length' <<<"$groups")" != "0" ]]; then
      print -P "%F{6}Group Policy Surface%f"
      jq -r '.Groups[]?.GroupName' <<<"$groups" | while read -r g; do
        [[ -z "$g" ]] && continue
        local gap gip nac nai
        gap="$(_jx aws iam list-attached-group-policies --group-name "$g")"
        gip="$(_jx aws iam list-group-policies          --group-name "$g")"
        nac="$(jq -r '.AttachedPolicies | length' <<<"$gap" 2>/dev/null || echo 0)"
        nai="$(jq -r '.PolicyNames | length'      <<<"$gip" 2>/dev/null || echo 0)"
        print -P "  %F{4}$g%f  attached=$nac inline=$nai"
        if (( DEEP )); then
          [[ "$nac" -gt 0 ]] && jq -r '.AttachedPolicies[]?.PolicyName' <<<"$gap" | sed 's/^/    - /'
          [[ "$nai" -gt 0 ]] && jq -r '.PolicyNames[]?' <<<"$gip"         | sed 's/^/    - /'
        fi
      done
    fi

    _hr
    return 0
  fi

  if [[ "$ptype" == "assumed-role" || "$ptype" == "role" ]]; then
    print -P "%F{6}Role%f  %F{4}$role%f"
    [[ "$ptype" == "assumed-role" && -n "$sname" ]] && print -P "  %F{4}Session:%f $sname"
    _print_role_boundary "$role"

    local rap rip
    rap="$(_jx aws iam list-attached-role-policies --role-name "$role")"
    rip="$(_jx aws iam list-role-policies          --role-name "$role")"

    if [[ -z "$rap$rip" ]]; then
      _note "no role policies visible"
    else
      print -P "%F{6}Role Policies%f"
      if [[ -n "$rap" && "$(jq -r '.AttachedPolicies | length' <<<"$rap")" != "0" ]]; then
        print -P "  %F{4}Attached:%f"
        if (( DEEP )); then
          jq -r '.AttachedPolicies[]? | [.PolicyName, .PolicyArn] | @tsv' <<<"$rap" \
            | awk -F'\t' '{printf "    - %s  (%s)\n",$1,$2}'
        else
          jq -r '.AttachedPolicies[]?.PolicyName' <<<"$rap" | sed 's/^/    - /'
        fi
      fi
      if [[ -n "$rip" && "$(jq -r '.PolicyNames | length' <<<"$rip")" != "0" ]]; then
        print -P "  %F{4}Inline:%f"
        jq -r '.PolicyNames[]?' <<<"$rip" | sed 's/^/    - /'
      fi
    fi

    _hr
    return 0
  fi

  _warn "unrecognized principal type. Printed raw identity only."
  _hr
}

