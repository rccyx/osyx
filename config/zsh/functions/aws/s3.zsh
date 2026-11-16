# =====================================================================
# Elite S3 helpers with true resume and visible progress
# Provides: s3up, s3down, s3rm, s3ls
# deps: awscli v2, jq, fzf (optional), findutils, coreutils (dd), openssl
# =====================================================================

# ---------- ui helpers ----------
if ! typeset -f _ok   >/dev/null; then _ok(){ print -P "%F{2}✔%f $*"; } fi
if ! typeset -f _note >/dev/null; then _note(){ print -P "%F{4}ℹ️ %f $*"; } fi
if ! typeset -f _warn >/dev/null; then _warn(){ print -P "%F{3}‼%f $*"; } fi
if ! typeset -f _err  >/dev/null; then _err(){ print -P "%F{1}✖%f $*"; } fi
if ! typeset -f _hr   >/dev/null; then _hr(){ print -P "%F{244}${(l:60::-:)}%f"; } fi

# ---------- knobs (env can override) ----------
: ${S3_MPU_THRESHOLD_MB:=256}     # use MPU for files >= this many MiB
: ${S3_MPU_PART_MB:=64}           # MPU part size MiB (auto-raised if too many parts)
: ${S3_MPU_MAX_PARTS:=10000}      # S3 hard limit
: ${S3_MPU_CONCURRENCY:=3}        # parallel part uploads
: ${S3_RETRY_MAX:=8}
: ${S3_READ_TIMEOUT:=600}
: ${S3_CONNECT_TIMEOUT:=60}

# ---------- checks ----------
_s3_need(){ command -v "$1" >/dev/null 2>&1 || { _err "missing dep: $1"; return 1; } }
_s3_check(){
  _s3_need aws || return 1
  _s3_need jq  || return 1
  aws sts get-caller-identity >/dev/null 2>&1 || { _err "AWS creds not working. Check ~/.aws"; return 1; }
}

# ---------- region and bucket ----------
_s3_region(){ echo "${AWS_REGION:-${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null || echo us-east-1)}}" }
_s3_bucket_exists(){ aws s3api head-bucket --bucket "$1" >/dev/null 2>&1 }
_s3_list_buckets(){ aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null | tr '\t' '\n' | sort -u }

_s3_pick_bucket(){
  local pick
  local -a existing; existing=("${(@f)$(_s3_list_buckets)}")
  if [[ -n "$S3_BUCKET" ]]; then echo "$S3_BUCKET"; return 0; fi
  if command -v fzf >/dev/null 2>&1; then
    if (( $#existing )); then
      pick=$(
        printf "%s\n" "${existing[@]}" \
        | awk 'BEGIN{seen[""]=1} !seen[$0]++' \
        | fzf --prompt="S3 bucket ⇢ " --header="Pick or type new, Enter to confirm" \
              --print-query --height=40% \
        | awk 'NR==1{q=$0} END{print (NR>1?$0:q)}'
      )
    else
      read -r "?Bucket name: " pick
    fi
  else
    if (( $#existing )); then
      print -P "Buckets:"; printf "  %s\n" "${existing[@]}" >&2
      read -r "?Bucket name: " pick
      [[ -z "$pick" ]] && pick="${existing[1]}"
    else
      read -r "?Bucket name: " pick
    fi
  fi
  [[ -n "$pick" ]] && echo "$pick" || { _err "no bucket chosen"; return 1; }
}

_s3_secure_create_if_missing(){
  local b="$1" r="$(_s3_region)"
  if _s3_bucket_exists "$b"; then _note "bucket exists: $b"; return 0; fi
  _note "creating private bucket $b in $r"
  if [[ "$r" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$b" >/dev/null
  else
    aws s3api create-bucket --bucket "$b" --create-bucket-configuration LocationConstraint="$r" >/dev/null
  fi
  aws s3api put-public-access-block \
    --bucket "$b" \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true >/dev/null
  aws s3api put-bucket-encryption \
    --bucket "$b" \
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' >/dev/null
  _ok "created and secured: $b"
}

# ---------- sizes ----------
_s3_bytes(){
  local p="$1"
  if [[ -d "$p" ]]; then
    du -sb "$p" 2>/dev/null | awk '{print $1}'
  else
    stat --printf="%s" "$p" 2>/dev/null || wc -c <"$p"
  fi
}
_s3_hsize(){
  local b="$1" kib=1024 mib=$((1024*1024)) gib=$((1024*1024*1024)) tib=$((1024*1024*1024*1024))
  if   (( b >= tib )); then printf "%.2f TiB" "$((b*100/tib))e-2"
  elif (( b >= gib )); then printf "%.2f GiB" "$((b*100/gib))e-2"
  elif (( b >= mib )); then printf "%.2f MiB" "$((b*100/mib))e-2"
  elif (( b >= kib )); then printf "%.2f KiB" "$((b*100/kib))e-2"
  else printf "%d B" "$b"; fi
}

# ---------- aws global args (do NOT hide progress) ----------
_s3_cli_args(){
  echo --cli-read-timeout "$S3_READ_TIMEOUT" --cli-connect-timeout "$S3_CONNECT_TIMEOUT"
}

# ---------- retry wrapper ----------
_retry(){
  local tries="$S3_RETRY_MAX" n=1 delay=2
  while :; do
    "$@"; local rc=$?
    (( rc == 0 )) && return 0
    (( n >= tries )) && return $rc
    sleep "$delay"
    delay=$((delay*2)); (( delay > 30 )) && delay=30
    (( n++ ))
  done
}

# ---------- calc part bytes ----------
_calc_part_bytes(){
  local fbytes="$1" part_mb="$S3_MPU_PART_MB"
  local part=$((part_mb*1024*1024))
  local need_parts=$(( (fbytes + part - 1) / part ))
  if (( need_parts > S3_MPU_MAX_PARTS )); then
    part=$(( (fbytes + S3_MPU_MAX_PARTS - 1) / S3_MPU_MAX_PARTS ))
    local eight=$((8*1024*1024))
    (( part = ((part + eight - 1) / eight) * eight ))
  fi
  echo "$part"
}

# ---------- state ----------
_s3_state_dir(){ echo "${XDG_STATE_HOME:-$HOME/.local/state}/s3mpu"; }
_s3_key_to_path(){ echo "$1" | sed 's,/,__SLASH__,g'; }
_s3_state_file(){ local b="$1" k="$2"; echo "$(_s3_state_dir)/$b/$(_s3_key_to_path "$k").json"; }

_mpu_save_state(){
  local sf="$1" uploadId="$2" partBytes="$3" fileBytes="$4"
  mkdir -p -- "${sf:h}"
  jq -n --arg u "$uploadId" --argjson p "$partBytes" --argjson f "$fileBytes" \
    '{uploadId:$u, partBytes:$p, fileBytes:$f}' > "$sf"
}
_mpu_load_state(){ local sf="$1" field="$2"; jq -r ".$field" "$sf"; }

# ---------- find or start MPU ----------
_mpu_find_existing(){ # we only resume ones we started (state file)
  local sf="$(_s3_state_file "$1" "$2")"
  [[ -f "$sf" ]] && jq -r '.uploadId' "$sf" 2>/dev/null || echo ""
}

_mpu_list_parts(){ # paginated
  local bucket="$1" key="$2" uploadId="$3" marker=""
  while :; do
    local resp
    if [[ -n "$marker" ]]; then
      resp="$(aws $(_s3_cli_args) s3api list-parts --bucket "$bucket" --key "$key" --upload-id "$uploadId" --part-number-marker "$marker" --max-parts 1000 --output json)"
    else
      resp="$(aws $(_s3_cli_args) s3api list-parts --bucket "$bucket" --key "$key" --upload-id "$uploadId" --max-parts 1000 --output json)"
    fi
    jq -r '.Parts[]? | .PartNumber' <<<"$resp"
    local trunc; trunc="$(jq -r '.IsTruncated' <<<"$resp")"
    marker="$(jq -r '.NextPartNumberMarker // empty' <<<"$resp")"
    [[ "$trunc" != "true" ]] && break
  done
}

_mpu_ensure_started(){
  local bucket="$1" key="$2" fileBytes="$3"
  local sf="$(_s3_state_file "$bucket" "$key")"
  local uploadId partBytes sf_part sf_bytes
  partBytes="$(_calc_part_bytes "$fileBytes")"
  uploadId="$(_mpu_find_existing "$bucket" "$key")"
  if [[ -n "$uploadId" ]]; then
    sf_part="$(_mpu_load_state "$sf" partBytes 2>/dev/null || echo 0)"
    sf_bytes="$(_mpu_load_state "$sf" fileBytes 2>/dev/null || echo 0)"
    if [[ "$sf_part" != "$partBytes" || "$sf_bytes" != "$fileBytes" ]]; then
      _warn "state mismatch for $key, aborting old MPU and restarting"
      _retry aws $(_s3_cli_args) s3api abort-multipart-upload --bucket "$bucket" --key "$key" --upload-id "$uploadId" >/dev/null 2>&1 || true
      rm -f -- "$sf"
      uploadId=""
    fi
  fi
  if [[ -z "$uploadId" ]]; then
    uploadId="$(_retry aws $(_s3_cli_args) s3api create-multipart-upload \
      --bucket "$bucket" --key "$key" --server-side-encryption AES256 \
      --output json | jq -r '.UploadId')"
    [[ -z "$uploadId" || "$uploadId" == null ]] && { _err "failed to create MPU"; return 1; }
    _mpu_save_state "$sf" "$uploadId" "$partBytes" "$fileBytes"
    _note "started MPU: $uploadId  partsize=$((partBytes/1024/1024))MiB"
  else
    _note "resuming MPU: $uploadId"
  fi
  print -r -- "$uploadId"
}

# ---------- part math ----------
_mpu_part_range(){
  local partBytes="$1" fileBytes="$2" pnum="$3"
  local start=$(( (pnum-1)*partBytes ))
  local len=$partBytes
  (( start + len > fileBytes )) && len=$(( fileBytes - start ))
  echo "$start $len"
}

# ---------- upload one part ----------
_mpu_upload_part(){
  local bucket="$1" key="$2" uploadId="$3" pnum="$4" src="$5"
  local md5b64 etag out
  md5b64="$(openssl dgst -md5 -binary "$src" | base64)"
  out="$(_retry aws $(_s3_cli_args) s3api upload-part \
    --bucket "$bucket" --key "$key" --upload-id "$uploadId" \
    --part-number "$pnum" --body "$src" --content-md5 "$md5b64" \
    --output json 2>/dev/null)" || return 1
  etag="$(jq -r '.ETag' <<<"$out" | sed 's/"//g')"
  [[ -z "$etag" || "$etag" == null ]] && return 1
  print -r -- "$etag"
}

# ---------- complete MPU ----------
_mpu_complete(){
  local bucket="$1" key="$2" uploadId="$3" parts_json="$4"
  _retry aws $(_s3_cli_args) s3api complete-multipart-upload \
    --bucket "$bucket" --key "$key" --upload-id "$uploadId" \
    --multipart-upload "$parts_json" >/dev/null
}

# ---------- resume-safe multipart uploader with progress ----------
_s3_mpu_put_file(){
  emulate -L zsh
  setopt pipefail
  local file="$1" bucket="$2" key="$3"
  [[ -f "$file" ]] || { _err "no such file: $file"; return 1; }

  local fbytes partBytes pcount uploadId sf tdir
  fbytes="$(_s3_bytes "$file")"
  partBytes="$(_calc_part_bytes "$fbytes")"
  pcount=$(( (fbytes + partBytes - 1) / partBytes ))
  (( pcount < 1 )) && pcount=1
  (( pcount > S3_MPU_MAX_PARTS )) && { _err "would exceed $S3_MPU_MAX_PARTS parts"; return 1; }

  uploadId="$(_mpu_ensure_started "$bucket" "$key" "$fbytes")" || return 1
  sf="$(_s3_state_file "$bucket" "$key")"

  local -a done_parts; done_parts=("${(@f)$(_mpu_list_parts "$bucket" "$key" "$uploadId")}")
  local -a missing=()
  local p
  for ((p=1; p<=pcount; p++)); do
    if (( ${done_parts[(Ie)$p]} )); then continue; fi
    missing+=("$p")
  done

  local existing_done=$#done_parts
  if (( $#missing == 0 )); then
    _note "all parts already uploaded, finalizing"
  else
    _note "uploading ${#missing} missing part(s) out of $pcount"
  fi

  tdir="$(mktemp -d)"
  local -A etag_by_part=()
  if (( $#done_parts )); then
    local j pn et
    j="$(aws $(_s3_cli_args) s3api list-parts --bucket "$bucket" --key "$key" --upload-id "$uploadId" --output json)"
    while IFS=$'\t' read -r pn et; do etag_by_part[$pn]="$et"; done < <(
      jq -r '.Parts[]? | [(.PartNumber|tostring), (.ETag|tostring|sub("\"";""))] | @tsv' <<<"$j"
    )
  fi

  # launch uploads with bounded concurrency, show progress as parts finish
  local -a pids=()
  local uploaded_new=0
  local print_progress(){
    local -a comp; comp=($tdir/etag-*.txt(N))
    uploaded_new=${#comp}
    local total=$(( existing_done + uploaded_new ))
    local pct=$(( 100 * total / pcount ))
    printf "\rMPU %s  %d/%d parts  (%d%%)" "$key" "$total" "$pcount" "$pct"
  }

  for p in "${missing[@]}"; do
    # throttle
    while (( ${#pids} >= S3_MPU_CONCURRENCY )); do
      # wait for oldest pid to finish
      wait "${pids[1]}" || true
      pids=("${pids[@]:2}")  # drop first element (zsh arrays are 1-based)
      print_progress
    done
    (
      set -e
      local start len; read start len <<<"$(_mpu_part_range "$partBytes" "$fbytes" "$p")"
      local chunk="$tdir/part-$p.bin"
      dd if="$file" of="$chunk" bs=4M iflag=fullblock,skip_bytes,count_bytes skip="$start" count="$len" status=none
      local et; et="$(_mpu_upload_part "$bucket" "$key" "$uploadId" "$p" "$chunk")"
      printf "%s" "$et" > "$tdir/etag-$p.txt"
      rm -f -- "$chunk"
    ) &
    pids+=("$!")
    print -P "%F{244}→%f part $p queued  bytes=$((len))" 2>/dev/null || true
  done

  # wait remaining
  for pid in "${pids[@]}"; do
    wait "$pid" || true
    print_progress
  done
  [[ ${#missing} -gt 0 ]] && echo

  # collect all etags in order
  local -a etags=()
  for ((p=1; p<=pcount; p++)); do
    if [[ -n "${etag_by_part[$p]:-}" ]]; then
      etags+=("$p ${etag_by_part[$p]}")
      continue
    fi
    if [[ -f "$tdir/etag-$p.txt" ]]; then
      etags+=("$p $(<"$tdir/etag-$p.txt")")
    fi
  done

  if (( ${#etags} != pcount )); then
    _err "missing parts after upload. keep state and re-run to resume."
    rm -rf -- "$tdir"
    return 1
  fi

  local parts_json
  parts_json="$(printf '%s\n' "${etags[@]}" \
    | awk '{printf("{\"ETag\":\"%s\",\"PartNumber\":%d}\n",$2,$1)}' \
    | jq -cs '{Parts: .}')"

  _retry _mpu_complete "$bucket" "$key" "$uploadId" "$parts_json" || { _err "failed to complete MPU"; rm -rf -- "$tdir"; return 1; }

  rm -rf -- "$tdir"
  rm -f -- "$sf"
  _ok "uploaded $key  size=$(_s3_hsize "$fbytes") parts=$pcount"
  return 0
}

# ---------- pick local items ----------
_s3_pick_local(){
  if (( $# > 0 )); then print -r -- "$@"; return 0; fi
  if command -v fzf >/dev/null 2>&1; then
    if command -v fd >/dev/null 2>&1; then
      fd -H -d 1 -t f -t d . | sort | fzf --multi --height=70% --prompt="pick files or folders ⇢ "
    else
      find . -maxdepth 1 -mindepth 1 -printf "%P\n" | sort | fzf --multi --height=70% --prompt="pick files or folders ⇢ "
    fi
  else
    find . -maxdepth 1 -mindepth 1 -printf "%P\n"
  fi
}

# ---------- plan ----------
_s3_plan_upload(){
  local bucket="$1"; shift
  local -a items=("$@")
  local total=0
  _hr
  print -P "%F{244}PLAN: upload%f to %F{6}s3://$bucket/%f"
  local p
  for p in "${items[@]}"; do
    local base="${p:t}" bytes="$(_s3_bytes "$p" 2>/dev/null || echo 0)"
    (( total+=bytes ))
    if [[ -d "$p" ]]; then
      print -P "  dir  $base/  ~ $(_s3_hsize "$bytes")"
    else
      print -P "  file $base    $(_s3_hsize "$bytes")"
    fi
  done
  print -P "total ~ %F{6}$(_s3_hsize "$total")%f across %F{6}${#items}%f item(s)"
  _hr
}

# ---------- small CP with progress (AWS prints bar by default) ----------
_s3_put_small(){
  local file="$1" bucket="$2" key="$3"
  _retry aws $(_s3_cli_args) s3 cp "$file" "s3://$bucket/$key" --sse AES256
}

# ---------- walk files in a dir deterministically ----------
_s3_walk_files(){ local root="$1"; find "$root" -type f -printf "%P\0" | sort -z | tr '\0' '\n'; }

# ---------- s3up (folder = per-file resume, single file = resume) ----------
s3up(){
  emulate -L zsh
  setopt pipefail
  _s3_check || return 1

  local bucket; bucket="$(_s3_pick_bucket)" || return 1
  _s3_secure_create_if_missing "$bucket" || return 1

  local -a picks; picks=("${(@f)$(_s3_pick_local "$@")}")
  (( $#picks )) || { _err "nothing selected"; return 1; }

  local -a items=() p
  for p in "${picks[@]}"; do
    [[ -e "$p" ]] || { _err "missing: $p"; return 1; }
    items+=("${p:A}")
  done

  _s3_plan_upload "$bucket" "${items[@]}"
  local ans; read -r "ans?Proceed with upload [y/N]: "
  [[ "$ans" =~ ^[Yy]$ ]] || { _warn "aborted"; return 1; }

  local rc=0 thr=$((S3_MPU_THRESHOLD_MB*1024*1024))

  for p in "${items[@]}"; do
    if [[ -d "$p" ]]; then
      local base="${p:t}"
      _note "uploading dir $base with resume per file"
      local rel
      while IFS= read -r rel; do
        local file="$p/$rel" size key
        size="$(_s3_bytes "$file")"
        key="$base/$rel"
        if (( size >= thr )); then
          print -P "%F{244}→%f MPU $key size=$(_s3_hsize "$size")"
          _s3_mpu_put_file "$file" "$bucket" "$key" || rc=$?
        else
          print -P "%F{244}→%f put $key size=$(_s3_hsize "$size")"
          _s3_put_small "$file" "$bucket" "$key" || rc=$?
        fi
      done < <(_s3_walk_files "$p")
    else
      local base="${p:t}" size="$(_s3_bytes "$p")"
      if (( size >= thr )); then
        print -P "%F{244}→%f MPU $base size=$(_s3_hsize "$size")"
        _s3_mpu_put_file "$p" "$bucket" "$base" || rc=$?
      else
        print -P "%F{244}→%f put $base size=$(_s3_hsize "$size")"
        _s3_put_small "$p" "$bucket" "$base" || rc=$?
      fi
    fi
  done

  (( rc == 0 )) && _ok "upload complete" || _err "upload finished with errors (rc=$rc). Re-run s3up to resume big files."
  return $rc
}

# ---------- list keys ----------
_s3_list_all_keys(){
  local bucket="$1" prefix="${2:-}" token resp
  while :; do
    resp="$(
      aws $(_s3_cli_args) s3api list-objects-v2 \
        --bucket "$bucket" --prefix "$prefix" \
        ${token:+--continuation-token "$token"} \
        --output json 2>/dev/null
    )" || break
    jq -r '.Contents[]? | [ .Key, ( .Size // 0 ), ( .LastModified // "" ) ] | @tsv' <<<"$resp"
    token="$(jq -r '.NextContinuationToken // empty' <<<"$resp")"
    [[ -z "$token" ]] && break
  done
}

# ---------- s3ls ----------
s3ls(){
  emulate -L zsh
  _s3_check || return 1
  local b="$1" pfx="${2:-}"
  [[ -z "$b" ]] && b="$(_s3_pick_bucket)"
  local rows; rows="$(_s3_list_all_keys "$b" "$pfx")"
  [[ -z "$rows" ]] && { _warn "no objects found in $b"; return 0; }
  if command -v fzf >/dev/null 2>&1; then
    print -r -- "$rows" \
      | fzf --with-nth=1 --delimiter=$'\t' --header="s3://$b/${pfx}" \
            --preview-window=down,6 \
            --preview 'printf "Key: %s\nSize: %s bytes\n" {1} {2}'
  else
    print -r -- "$rows"
  fi
}

# ---------- delete plan ----------
_s3_plan_delete(){
  local bucket="$1" mode="$2"; shift 2
  local -a keys=("$@")
  local total=0 k sz
  _hr
  if [[ "$mode" == "prefix" ]]; then
    print -P "%F{244}PLAN: delete recursively%f from %F{6}s3://$bucket/%f"
    for k in "${keys[@]}"; do print -P "  prefix: $k"; done
    print -P "This will remove all objects under those prefix(es)."
  else
    print -P "%F{244}PLAN: delete objects%f from %F{6}s3://$bucket/%f"
    for k in "${keys[@]}"; do
      sz="$(aws $(_s3_cli_args) s3api head-object --bucket "$bucket" --key "$k" --query 'ContentLength' --output text 2>/dev/null || echo 0)"
      (( total+=${sz:-0} ))
      print -P "  $k  ($(_s3_hsize "$sz"))"
    done
    print -P "total ~ %F{6}$(_s3_hsize "$total")%f across %F{6}${#keys}%f object(s)"
  fi
  _hr
}

# ---------- s3rm (now supports selecting folders via fzf) ----------
s3rm(){
  emulate -L zsh
  setopt pipefail
  _s3_check || return 1

  local bucket; bucket="$(_s3_pick_bucket)" || return 1

  local -a del_keys=() del_pfx=()
  if (( $# == 0 )); then
    _note "fetching object list..."
    local rows; rows="$(_s3_list_all_keys "$bucket")" || true
    [[ -z "$rows" ]] && { _warn "no objects found in $bucket"; return 0; }

    # derive folder prefixes from keys, include all parent dirs
    local dirs
    dirs="$(
      print -r -- "$rows" \
      | awk -F'\t' '{print $1}' \
      | awk -F'/' '
          NF>1 {
            p=""
            for (i=1; i<NF; i++) {
              if (i==1) p=$1; else p=p "/" $i
              seen[p "/"]=1
            }
          }
          END { for (d in seen) print d }
        ' \
      | sort
    )"

    # build combined list: <DIR> lines first, then object rows
    local combined
    combined="$(
      { print -r -- "$dirs" | awk '{printf "%s\t<DIR>\t\n",$0}'; print -r -- "$rows"; } \
      | awk 'BEGIN{OFS="\t"}{print $1,$2,$3}'
    )"

    # pick from both dirs and objects
    local sel
    sel="$(
      print -r -- "$combined" \
      | fzf --multi --with-nth=1 --delimiter=$'\t' --height=70% \
            --prompt="select keys or folders ⇢ " \
            --preview-window=down,8 \
            --preview 'k={1}; s={2}; if [ "$s" = "<DIR>" ]; then printf "Prefix: %s\nRecursive delete\n" "$k"; else printf "Key: %s\nSize: %s bytes\n" "$k" "$s"; fi' \
      | awk -F'\t' '{print $1 "\t" $2}'
    )" || true

    [[ -z "$sel" ]] && { _warn "nothing selected"; return 1; }

    # split selection into prefixes and keys
    local a b
    while IFS=$'\t' read -r a b; do
      if [[ "$b" == "<DIR>" ]]; then del_pfx+=("$a"); else del_keys+=("$a"); fi
    done <<< "$sel"
  else
    # args mode: any arg ending with / is a prefix, others are keys
    local t any=0
    for t in "$@"; do
      (( any++ ))
      if [[ "$t" == */ ]]; then del_pfx+=("$t"); else del_keys+=("$t"); fi
    done
    (( any )) || { _warn "nothing to delete"; return 1; }
  fi

  # plans
  (( ${#del_pfx} )) && _s3_plan_delete "$bucket" "prefix" "${del_pfx[@]}"
  (( ${#del_keys} )) && _s3_plan_delete "$bucket" "keys"   "${del_keys[@]}"

  # confirmation: bucket name if any prefixes selected, else "DELETE"
  local confirm rc=0
  if (( ${#del_pfx} )); then
    print -n "Type the bucket name '$bucket' to confirm recursive delete: "
    read -r confirm
    [[ "$confirm" == "$bucket" ]] || { _warn "confirmation mismatch. aborted."; return 1; }
  else
    print -n "Type DELETE to confirm object deletion: "
    read -r confirm
    [[ "$confirm" == "DELETE" ]] || { _warn "confirmation mismatch. aborted."; return 1; }
  fi

  # execute recursive deletes for prefixes
  if (( ${#del_pfx} )); then
    local k
    for k in "${del_pfx[@]}"; do
      print -P "%F{244}→%f aws s3 rm s3://$bucket/$k --recursive"
      _retry aws $(_s3_cli_args) s3 rm "s3://$bucket/$k" --recursive || rc=$?
    done
  fi

  # execute batched delete for individual keys
  if (( ${#del_keys} )); then
    local tmp payload k
    tmp="$(mktemp)"; : > "$tmp"
    for k in "${del_keys[@]}"; do printf '{"Key":"%s"}\n' "$k" >> "$tmp"; done
    payload="$(jq -cs '{Objects: ., Quiet: false}' "$tmp")"
    print -P "%F{244}→%f aws s3api delete-objects (batched)"
    _retry aws $(_s3_cli_args) s3api delete-objects --bucket "$bucket" --delete "$payload" >/dev/null || rc=$?
    rm -f "$tmp"
  fi

  (( rc == 0 )) && _ok "delete complete" || _err "delete finished with errors (rc=$rc)"
  return $rc
}

# ---------- s3down with resume (prints steps; s3api part has no bar) ----------
_s3_is_dirpath(){ [[ -d "$1" || "$1" == */ || "$1" == "." || "$1" == ./* || "$1" == /* ]]; }

_s3_plan_download(){
  local bucket="$1" dest="$2"; shift 2
  local -a items=("$@") prefixes=() keys=() t
  for t in "${items[@]}"; do [[ "$t" == */ ]] && prefixes+=("$t") || keys+=("$t"); done
  _hr
  print -P "%F{244}PLAN: download%f from %F{6}s3://$bucket%f to %F{6}${dest:A}%f"
  (( $#prefixes )) && { print -P "prefixes:"; for t in "${prefixes[@]}"; do print -P "  $t"; done; }
  if (( $#keys )); then
    print -P "objects:"
    local k sz
    for k in "${keys[@]}"; do
      sz="$(aws $(_s3_cli_args) s3api head-object --bucket "$bucket" --key "$k" --query 'ContentLength' --output text 2>/dev/null || echo 0)"
      print -P "  $k  ($(_s3_hsize "$sz"))"
    done
  fi
  _hr
}

_s3_get_resume(){
  emulate -L zsh
  setopt pipefail
  local bucket="$1" key="$2" out="$3"
  mkdir -p -- "${out:h}"
  local head etag size have=0
  head="$(aws $(_s3_cli_args) s3api head-object --bucket "$bucket" --key "$key" --output json)" || return 1
  etag="$(jq -r '.ETag' <<<"$head" | sed 's/"//g')"
  size="$(jq -r '.ContentLength' <<<"$head")"
  [[ -f "$out" ]] && have="$(stat --printf="%s" "$out" 2>/dev/null || echo 0)"
  if (( have > 0 && have < size )); then
    _note "resuming $key at $have/$size bytes"
    local tmp; tmp="$(mktemp)"
    _retry aws $(_s3_cli_args) s3api get-object \
      --bucket "$bucket" --key "$key" --range "bytes=$have-" \
      --if-match "$etag" "$tmp" >/dev/null || { rm -f "$tmp"; return 1; }
    cat "$tmp" >> "$out"
    rm -f "$tmp"
  else
    _retry aws $(_s3_cli_args) s3 cp "s3://$bucket/$key" "$out" || return 1
  fi
  local final; final="$(stat --printf="%s" "$out" 2>/dev/null || echo 0)"
  if (( final != size )); then _err "size mismatch on $out"; return 1; fi
  _ok "downloaded $key to $out"
}

s3down(){
  emulate -L zsh
  setopt pipefail
  _s3_check || return 1

  local bucket; bucket="$(_s3_pick_bucket)" || return 1

  local -a args; args=("$@")
  local dest="" last=""
  (( $#args )) && last="${args[-1]}"
  if (( $#args )) && _s3_is_dirpath "$last"; then
    dest="${last%/}"
    args=("${args[@]:0:$#args-1}")
  fi

  local -a targets=()
  if (( $#args == 0 )); then
    _note "fetching object list..."
    local rows; rows="$(_s3_list_all_keys "$bucket")" || true
    [[ -z "$rows" ]] && { _warn "no objects found in $bucket"; return 0; }
    targets=("${(@f)$(print -r -- "$rows" \
      | fzf --multi --with-nth=1 --delimiter=$'\t' --height=70% \
            --prompt="select to download ⇢ " \
            --preview-window=down,8 \
            --preview 'printf "Key: %s\nSize: %s bytes\n" {1} {2}' \
      | awk -F'\t' '{print $1}')}")
    (( $#targets )) || { _warn "nothing selected"; return 1; }
  else
    targets=("${args[@]}")
  fi

  [[ -z "$dest" ]] && dest="."
  mkdir -p -- "$dest" || { _err "cannot create dest dir: $dest"; return 1; }

  _s3_plan_download "$bucket" "$dest" "${targets[@]}"

  local ans; read -r "ans?Proceed with download [y/N]: "
  [[ "$ans" =~ ^[Yy]$ ]] || { _warn "aborted"; return 1; }

  local rc=0 k
  for k in "${targets[@]}"; do
    if [[ "$k" == */ ]]; then
      print -P "%F{244}→%f aws s3 sync s3://$bucket/$k $dest/$k --exact-timestamps"
      _retry aws $(_s3_cli_args) s3 sync "s3://$bucket/$k" "$dest/$k" --exact-timestamps || rc=$?
    else
      _s3_get_resume "$bucket" "$k" "$dest/$k" || rc=$?
    fi
  done

  (( rc == 0 )) && _ok "download complete" || _err "download finished with errors (rc=$rc). Re-run to resume large files."
  return $rc
}

# ---------- small conveniences ----------
s3buckets(){ _s3_check || return 1; _s3_list_buckets }
s3who(){ aws sts get-caller-identity }

# ---------- rudimentary completion for s3rm ----------
_s3rm_complete(){
  local b="${S3_BUCKET:-}"
  [[ -z "$b" ]] && b="$(_s3_pick_bucket)"
  local -a keys; keys=("${(@f)$(aws s3api list-objects-v2 --bucket "$b" --max-items 1000 --query 'Contents[].Key' --output text 2>/dev/null | tr '\t' '\n')}")
  _describe -t keys 'keys' keys
}
compdef _s3rm_complete s3rm

