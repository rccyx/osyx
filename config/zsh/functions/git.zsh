_git_primary_remote() {
  if git remote | grep -qx "upstream"; then
    echo upstream
  else
    echo origin
  fi
}

_git_default_base_ref() {
  local remote="${1:-$(_git_primary_remote)}" ref
  ref=$(git symbolic-ref -q --short "refs/remotes/${remote}/HEAD" 2>/dev/null)
  if [[ -n "$ref" ]]; then echo "$ref"; return 0; fi
  if git show-ref --verify --quiet "refs/remotes/${remote}/main"; then echo "${remote}/main"; return 0; fi
  if git show-ref --verify --quiet "refs/remotes/${remote}/master"; then echo "${remote}/master"; return 0; fi
  if git show-ref --verify --quiet "refs/heads/main"; then echo "main"; return 0; fi
  if git show-ref --verify --quiet "refs/heads/master"; then echo "master"; return 0; fi
  return 1
}

# Build <base>...HEAD (merge-base aware). Honors $BLL_BASE or arg.
_git_branch_range() {
  local base_ref="${1:-${BLL_BASE:-}}"
  if [[ -z "$base_ref" ]]; then
    base_ref="$(_git_default_base_ref "$(_git_primary_remote)")" || true
  fi
  [[ -z "$base_ref" ]] && return 1
  printf "%s...HEAD" "$base_ref"
}

# stands for "browse", opens  the current repo on GitHub
bws() {
  local remote
  remote=$(git config --get remote.origin.url)
  remote=${remote/git@github.com:/https:\/\/github.com\/}
  remote=${remote/.git/}
  xdg-open "$remote"
}
# PRs
prs() {
  local remote
  remote=$(git config --get remote.origin.url)
  remote=${remote/git@github.com:/https://github.com/}
  remote=${remote/.git/}
  xdg-open "$remote/pulls"
}


# Open the Pull Request for the current branch (if any)
prr() {
  emulate -L zsh
  setopt err_return

  # ensure we're in a repo
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not in a git repo" >&2
    return 1
  fi

  # current branch or short SHA if detached
  local branch
  branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD)

  # fast path with GitHub CLI
  if command -v gh >/dev/null 2>&1; then
    if gh pr view --web >/dev/null 2>&1; then
      return 0
    fi
  fi

  # pick upstream if present, else origin
  local remote_name="origin"
  if git remote | grep -qx "upstream"; then
    remote_name="upstream"
  fi

  # normalize remote to https and extract owner/repo
  local remote https slug owner repo
  remote=$(git config --get "remote.${remote_name}.url")
  if [[ -z "$remote" ]]; then
    echo "No ${remote_name} remote found" >&2
    return 1
  fi
  https=${remote/git@github.com:/https://github.com/}
  https=${https/.git/}
  slug=${https#https://github.com/}
  owner=${slug%%/*}
  repo=${slug#*/}

  # try GitHub API to resolve the PR by head ref
  local token resp pr_html api
  token=${GITHUB_TOKEN:-$GH_TOKEN}
  if command -v curl >/dev/null 2>&1; then
    api="https://api.github.com/repos/${owner}/${repo}/pulls?head=${owner}:${branch}&state=open&per_page=1"
    if [[ -n "$token" ]]; then
      resp=$(curl -fsSL -H "Authorization: token ${token}" -H "Accept: application/vnd.github+json" "$api" 2>/dev/null) || resp=""
    else
      resp=$(curl -fsSL -H "Accept: application/vnd.github+json" "$api" 2>/dev/null) || resp=""
    fi
    if [[ -n "$resp" ]]; then
      if command -v jq >/dev/null 2>&1; then
        pr_html=$(printf "%s" "$resp" | jq -r '.[0].html_url // empty')
      else
        pr_html=$(printf "%s" "$resp" | sed -n 's/.*"html_url": *"\([^"]*\)".*/\1/p' | head -n1)
      fi
      if [[ -n "$pr_html" ]]; then
        xdg-open "$pr_html" >/dev/null 2>&1 &
        return 0
      fi
    fi
  fi

  # final fallback: open PRs filtered by head branch
  local urlencode search_url
  urlencode() {
    local i ch out="" s="$1"
    for ((i=1; i<=${#s}; i++)); do
      ch="${s[i]}"
      case "$ch" in
        [a-zA-Z0-9.~_-]) out+="$ch" ;;
        *) out+=$(printf '%%%02X' "'$ch") ;;
      esac
    done
    print -r -- "$out"
  }
  search_url="${https}/pulls?q=is%3Apr+is%3Aopen+head%3A$(urlencode "$branch")"
  xdg-open "$search_url" >/dev/null 2>&1 &
}



# yessir
issues() {
  local remote
  remote=$(git config --get remote.origin.url)
  remote=${remote/git@github.com:/https://github.com/}
  remote=${remote/.git/}
  xdg-open "$remote/issues"
}
# git checkout on roids
gck() {
  local branch
  branch=$(git for-each-ref --sort=-committerdate refs/heads/ --format='%(refname:short)' \
    | fzf --prompt="🌿 checkout branch ⇢ " --preview="git log -n 10 --color=always {}" --height=50%)
  [[ -n "$branch" ]] && git checkout "$branch"
}
compdef _git gck

# git grepper for commits
ggrep() {
  local q
  echo -n "🔍 search term: "; read -r q
  git log --all --pretty=format:'%C(auto)%h %s %Cgreen(%cr)' -S"$q" |
    fzf --reverse --preview="echo {} | cut -d' ' -f1 | xargs git show --color=always"
}

## g for git, double l is for last, since I already have gl as git log.. in the .gitconfig file.
gll() {
	 git show $(git log -1 --format=%H)
}

sll(){
		git diff --staged
}
sllc(){
		git diff --staged --stat
}

gllc(){
	git diff HEAD~1 HEAD --stat
}

#   show top repo contributors fast
gitwho() {
  git -C "${1:-.}" shortlog -sn --no-merges | head | nl -ba
}
# generate a GitHub SSH key, add it to the agent, and copy the .pub to clipboard
# usage: ghkey [-f] [-c comment] [path]
# defaults: path=$HOME/.ssh/github, comment="$(whoami)@$(hostname)"
ghkey() {
  emulate -L zsh
  set -u

  local force=0 comment="$(whoami)@$(hostname)" opt
  while getopts "fc:" opt; do
    case "$opt" in
      f) force=1 ;;         # overwrite existing key without prompting
      c) comment="$OPTARG" ;;# set key comment
    esac
  done
  shift $((OPTIND - 1))

  local key="${1:-$HOME/.ssh/github}"
  local pub="$key.pub"
  local cfg="$HOME/.ssh/config"

  mkdir -p "$HOME/.ssh" || { echo "mkdir ~/.ssh failed"; return 1; }
  chmod 700 "$HOME/.ssh" 2>/dev/null || true

  if [[ -e "$key" && $force -ne 1 ]]; then
    echo "Key exists at $key"
    read -q "REPLY?Reuse it? [Y/n] "; echo
    if [[ "$REPLY" == [Nn] ]]; then
      echo "Aborted. Use: ghkey -f  to overwrite."
      return 1
    fi
  fi

  if [[ ! -f "$key" || $force -eq 1 ]]; then
    ssh-keygen -t ed25519 -C "$comment" -f "$key" -N "" || { echo "ssh-keygen failed"; return 1; }
    chmod 600 "$key" 2>/dev/null || true
  fi

  # ensure an ssh-agent is running
  if ! ssh-add -l >/dev/null 2>&1; then
    eval "$(ssh-agent -s)" >/dev/null 2>&1
  fi
  ssh-add -q "$key" || { echo "ssh-add failed"; return 1; }

  # write minimal config for GitHub if not present
  if [[ ! -f "$cfg" ]] || ! grep -q "IdentityFile $key" "$cfg"; then
    {
      echo "Host github.com"
      echo "  HostName github.com"
      echo "  AddKeysToAgent yes"
      echo "  IdentityFile $key"
      echo "  IdentitiesOnly yes"
    } >> "$cfg"
    chmod 600 "$cfg" 2>/dev/null || true
  fi

  # copy pub key to clipboard using your ops.zsh if available, else fall back
  if typeset -f _clip >/dev/null; then
    < "$pub" _clip || { echo "clipboard copy failed"; return 1; }
  elif typeset -f copy >/dev/null; then
    < "$pub" copy || { echo "clipboard copy failed"; return 1; }
  elif command -v wl-copy >/dev/null 2>&1; then
    wl-copy < "$pub"
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard < "$pub"
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard < "$pub"
  else
    echo "No clipboard tool found. Here is your public key:"
    echo
    cat "$pub"
    echo
  fi

  echo "Done. Public key is in your clipboard. Add it in GitHub -> Settings -> SSH and GPG keys."
  echo "Test when ready: ssh -T git@github.com"
}


# go into the root of the current git dir
groot() {
  cd "$(git rev-parse --show-toplevel)" || echo "Not in a git repo"
}

# USE WITH CAUTION: DELETES ALL THE GIT BRANCHES EXCEPT FOR THE ONE YOU'RE ON RN
dlb() {
 git branch | grep -v "$(git rev-parse --abbrev-ref HEAD)" | xargs git branch -D
}

compdef _git ggrep

# bll  -> full patch for the whole branch vs base, scroll in your pager
# usage: bll [<base-ref>]   # default base auto-detected; or export BLL_BASE=origin/main
bll() {
  emulate -L zsh
  setopt pipefail

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not in a git repo" >&2; return 1
  fi

  local range; range="$(_git_branch_range "$1")" || {
    echo "Could not determine base. Try: bll main" >&2; return 1; }

  # Exactly like gll, but for the branch range. Plus/minus hunks, through your pager.
  git diff --color "$range"
}

# bllc -> stats summary for the whole branch vs base (mirror of gllc)
# usage: bllc [<base-ref>]
bllc() {
  emulate -L zsh
  setopt pipefail

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not in a git repo" >&2; return 1
  fi

  local range; range="$(_git_branch_range "$1")" || {
    echo "Could not determine base. Try: bllc main" >&2; return 1; }

  git diff --stat --color "$range"
}

# -----------------------------------------------------------------------------
# mpr helper
# -----------------------------------------------------------------------------
_mpr_help() {
  cat <<'EOF'
mpr - GitHub PR helper

Synopsis
  mpr                     Show this help
  mpr create [opts]       Create a PR for the current branch
  mpr open                Open the PR for the current branch in the browser
  mpr view                Show PR details in the terminal
  mpr ready               Mark the PR ready for review

Options for `mpr create`
  -R                      Ready for review. Default is draft.
  -B <base>               Base branch. Auto-detected if omitted.
  -t "<title>"            PR title. If body is omitted, commits are used.
  -b "<body>"             PR body.
  -F                      Use --fill-verbose when body is omitted.
  -n                      Do not open the browser after creation.
  -h, --help              Show this help.

Defaults
  - Base is detected from upstream/main or origin/main, then master.
  - If upstream exists, target upstream and push head to origin.
  - If body is missing, commit messages fill it.

Env
  GITHUB_TOKEN or GH_TOKEN for API calls.
  BLL_BASE to force the base ref.

Examples
  mpr create -t "feat: upload assets" -R
  mpr create -B main -F
  mpr open
EOF
}

# -----------------------------------------------------------------------------
# mpr - PR utility
# -----------------------------------------------------------------------------
mpr() {
  emulate -L zsh
  setopt err_return pipefail

  # Show help if no args or explicit help
  if [[ $# -eq 0 || "$1" == "help" || "$1" == "-h" || "$1" == "--help" ]]; then
    _mpr_help
    return 0
  fi

  command -v gh >/dev/null 2>&1 || { echo "gh CLI not found"; return 1; }
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not in a git repo"; return 1; }

  # Small subcommands
  case "$1" in
    open)
      shift
      gh pr view --web >/dev/null 2>&1 || gh pr list --web
      return $?
      ;;
    view)
      shift
      gh pr view || { echo "No PR found for this branch"; return 1; }
      return $?
      ;;
    ready)
      shift
      gh pr ready || { echo "No draft PR found for this branch"; return 1; }
      return $?
      ;;
    create)
      shift
      ;;
    *)
      # Unknown token, assume user wants create with flags
      :
      ;;
  esac

  # Parse create flags
  local draft=1 base="" title="" body="" open_after=1 fill_verbose=0 opt
  while getopts ":RB:t:b:nFh-" opt; do
    case "$opt" in
      R) draft=0 ;;
      B) base="$OPTARG" ;;
      t) title="$OPTARG" ;;
      b) body="$OPTARG" ;;
      n) open_after=0 ;;
      F) fill_verbose=1 ;;
      h) _mpr_help; return 0 ;;
      -) case "$OPTARG" in
           help) _mpr_help; return 0 ;;
           *) ;; # ignore unknown long flags
         esac ;;
      \?) echo "Unknown option: -$OPTARG"; _mpr_help; return 1 ;;
      :)  echo "Missing value for -$OPTARG"; _mpr_help; return 1 ;;
    esac
  done
  shift $((OPTIND - 1))

  # Current branch
  local branch
  branch=$(git symbolic-ref --quiet --short HEAD) || { echo "Detached HEAD"; return 1; }

  # Remotes: base from upstream if present, head pushed to origin
  local base_remote push_remote
  if git remote | grep -qx "upstream"; then
    base_remote="upstream"
    push_remote="origin"
  else
    base_remote="origin"
    push_remote="origin"
  fi

  # Compute base branch when not provided
  if [[ -z "$base" ]]; then
    local base_ref
    base_ref="$(_git_default_base_ref "$base_remote" 2>/dev/null || echo main)"
    base="${base_ref#refs/heads/}"
    base="${base#refs/remotes/}"
    base="${base#origin/}"
    base="${base#upstream/}"
  fi
  [[ "$branch" == "$base" ]] && { echo "You are on '$branch'. Switch to a feature branch."; return 1; }

  # Resolve slugs
  local base_url head_url base_https head_https base_slug head_slug head_owner
  base_url=$(git config --get "remote.${base_remote}.url")
  head_url=$(git config --get "remote.${push_remote}.url")
  [[ -z "$base_url" || -z "$head_url" ]] && { echo "Missing git remotes"; return 1; }
  base_https=${base_url/git@github.com:/https://github.com/}; base_https=${base_https/.git/}
  head_https=${head_url/git@github.com:/https://github.com/}; head_https=${head_https/.git/}
  base_slug=${base_https#https://github.com/}
  head_slug=${head_https#https://github.com/}
  head_owner=${head_slug%%/*}

  # Reuse existing open PR if any
  local existing_url
  existing_url=$(gh pr view --json url -q .url 2>/dev/null || true)
  if [[ -n "$existing_url" ]]; then
    echo "PR already exists: $existing_url"
    (( open_after )) && gh pr view --web >/dev/null 2>&1
    return 0
  fi

  # Ensure branch is pushed
  git push -u "$push_remote" HEAD >/dev/null 2>&1 || git push -u "$push_remote" HEAD || {
    echo "Failed to push branch to '$push_remote'."; return 1; }

  # Build gh args
  local args=(pr create --repo "$base_slug" --base "$base" --head "${head_owner}:${branch}")
  (( draft )) && args+=(--draft)
  [[ -n "$title" ]] && args+=(--title "$title")
  if [[ -n "$body" ]]; then
    args+=(--body "$body")
  else
    if (( fill_verbose )); then
      args+=(--fill-verbose)
    else
      args+=(--fill)
    fi
  fi

  # Create PR, retry once if gh complains about missing body
  local out pr_url
  if ! out=$(gh "${args[@]}" 2>&1); then
    if [[ "$out" == *"must provide --title and --body"* ]]; then
      # Force-fill body and retry
      args+=("--fill-verbose")
      out=$(gh "${args[@]}" 2>&1) || { echo "$out" >&2; return 1; }
    else
      echo "$out" >&2
      return 1
    fi
  fi

  pr_url=$(print -r -- "$out" | awk '/^https?:\/\//{print; exit}')
  if [[ -n "$pr_url" ]]; then
    echo "Created PR: $pr_url"
    (( open_after )) && gh pr view --web >/dev/null 2>&1
  else
    echo "$out"
  fi
}

