# ================================================================
#   DOCKER QUICK‑STRIKE FUNCTIONS
#   deps: docker ≥20, fzf
# ================================================================
_pick_ct(){ docker ps --format '{{.ID}}  {{.Image}}  {{.Names}}' \
            | fzf --prompt="🐳 pick container ⇢ " --height 60% --border --reverse \
            | awk '{print $1}'; }

# jump into a running container (falls back to sh if bash missing)
dinto(){
  local id=$(_pick_ct) || { _err "no container"; return 1; }
  docker exec -it "$id" bash 2>/dev/null || docker exec -it "$id" sh
}

# live top inside selected container
dtop(){
  local id=$(_pick_ct) || return 1
  docker top "$id"
}

# restart chosen container cleanly
drestart(){
  local id=$(_pick_ct) || return 1
  docker restart "$id" && _ok "restarted $id"
}

# follow logs on multiple containers (multi‑select)
dlogs(){
  local ids=($(docker ps --format '{{.ID}}  {{.Image}}' | \
              fzf --multi --prompt="📜 logs ⇢ " --height 60% --border --reverse | awk '{print $1}'))
  [[ ${#ids[@]} -eq 0 ]] && { _err "none selected"; return 1; }
  docker logs -f "${ids[@]}"
}

# list images by size and optionally delete picked ones
dimgls(){
  local selection
  selection=$(docker image ls --format '{{.Repository}}:{{.Tag}}  {{.ID}}  {{.Size}}' \
             | sort -h -k3 | column -t \
             | fzf --multi --prompt="🗑 images ⇢ " --height 60% --border --reverse)
  [[ -z $selection ]] && return
  echo "$selection" | awk '{print $2}' | xargs -r docker image rm
}

# prune everything older than 24h (images, stopped containers, volumes)
ddeepclean(){
  docker container prune -f
  docker image prune -a --filter "until=24h" -f
  docker volume prune -f
  _ok "deep cleaned docker resources >24h old"
}

# pick dangling volumes interactively and remove
dvolrm(){
  local vols
  vols=$(docker volume ls -qf dangling=true | \
         fzf --multi --prompt="🧹 volumes ⇢ " --height 60% --border --reverse)
  [[ -z $vols ]] && return
  echo "$vols" | xargs -r docker volume rm && _ok "removed selected volumes"
}

# dgo — fuzzy jump into a container or image
# deps: docker, fzf
dgo() {
  local list pick id kind running imageRef

  list=$(
    docker ps -a --format '{{.ID}}\tctr\t{{.Status}}\t{{.Image}}\t{{.Names}}'
    docker images --format '{{.ID}}\timg\t{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}' \
      | grep -v '^<none>:' || true
  )
  [[ -z "$list" ]] && { echo "no docker resources"; return 1; }

  pick=$(echo "$list" | fzf \
    --height 70% --border --reverse \
    --prompt='🐳 dgo ⇢ ' \
    --delimiter=$'\t' --with-nth=2.. \
    --header $'enter: attach    ctrl-l: logs    ctrl-r: restart    ctrl-d: remove' \
    --preview='
      if [[ {2} = "ctr" ]]; then
        docker ps -a --filter id={1} --format "ID: {{.ID}}\nIMAGE: {{.Image}}\nNAMES: {{.Names}}\nSTATUS: {{.Status}}\nPORTS: {{.Ports}}"
      else
        docker image inspect {1} 2>/dev/null | sed -n "1,60p"
      fi
    ' \
    --bind 'ctrl-l:execute(docker logs --tail 120 {1} | less -R)' \
    --bind 'ctrl-r:execute-silent([[ {2} = ctr ]] && docker restart {1})+reload(docker ps -a --format "{{.ID}}\tctr\t{{.Status}}\t{{.Image}}\t{{.Names}}"; docker images --format "{{.ID}}\timg\t{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" | grep -v "^<none>:")' \
    --bind 'ctrl-d:execute-silent([[ {2} = ctr ]] && docker rm -f {1} || docker rmi -f {1})+reload(docker ps -a --format "{{.ID}}\tctr\t{{.Status}}\t{{.Image}}\t{{.Names}}"; docker images --format "{{.ID}}\timg\t{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" | grep -v "^<none>:")'
  ) || return

  id=$(awk -F'\t' '{print $1}' <<< "$pick")
  kind=$(awk -F'\t' '{print $2}' <<< "$pick")

  if [[ "$kind" = "ctr" ]]; then
    running=$(docker inspect -f '{{.State.Running}}' "$id" 2>/dev/null)
    [[ "$running" != "true" ]] && docker start "$id" >/dev/null
    docker exec -it "$id" bash 2>/dev/null || docker exec -it "$id" sh 2>/dev/null || docker exec -it "$id" ash
  else
    imageRef="$id"
    docker run --rm -it --entrypoint="" "$imageRef" bash 2>/dev/null \
      || docker run --rm -it --entrypoint="" "$imageRef" sh 2>/dev/null \
      || docker run --rm -it --entrypoint="" "$imageRef" ash
  fi
}

# tiny alias to make it stick in muscle memory
alias dsh='dgo'


# copy files out of a container
dcp(){
  local id=$(_pick_ct) || return 1
  echo -n "path inside container ⇢ "; read -r src
  echo -n "destination dir ⇢ "; read -r dst
  [[ -z $src || -z $dst ]] && { _err "missing path"; return 1; }
  docker cp "$id:$src" "$dst" && _ok "copied"
}

# pull updates and roll the current compose stack
dupdate(){
  docker compose pull && docker compose up -d && _ok "stack updated"
}

# quick network overview
dnet(){
  docker network ls
  for n in $(docker network ls -q); do
    printf "\n%s\n" "$(docker network inspect -f '{{ .Name }}' "$n")"
    docker network inspect -f '{{ range $k,$v := .Containers }}• {{ $v.Name }}{{ "\n" }}{{ end }}' "$n"
  done
}

# terminate all containers
tercon() {
	for c in $(docker ps -a | tail -n+2 | awk '{print $1}'); do
  		docker stop "${c}" || :
  		docker rm "${c}"
	done
}

# remove all volumes
tervol() {
   docker volume rm $(docker volume ls -q)
}

# remove all images
terimg() {
   for img in $(docker images -q); do
        docker rmi "${img}" || :
    done
}


dprune() {
	 tercon && terimg && tervol
   docker container prune -f
   docker system prune -f
   docker image prune -f
   docker volume prune -f
}

