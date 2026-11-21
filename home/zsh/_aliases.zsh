# ─────────────────────────────────────────────
# Personal aliases — @rccyx
# My shortcuts. Replace with your own.
# ─────────────────────────────────────────────
alias c="clear"
alias ez="eza --long --header --inode --git"
alias t="touch"
alias tt="tmux"
alias p="python3 -m"
alias l="lsd -a"
alias u="sudo apt purge --autoremove" # for uninstall
alias v="nvim"
alias reload=". ~/.zshrc"
alias y="rm -rf"
alias f="fzf"
alias b="cd .."
alias bb="cd ..."
alias bbb="cd ...."
alias bbbb="cd ....."
alias bbbbb="cd ......"
alias ka="killall"
alias bat="\bat --theme=GitHub"
alias j="just"
alias x="chmod +x"
alias e="$EDITOR"
alias tf="terraform"
alias a="apt-get"
alias i="sudo apt-get install"
alias g="git"
alias pubip='dig +short myip.opendns.com @resolver1.opendns.com'
alias localip='ipconfig getifaddr en1'
alias ips="ifconfig -a | grep -o 'inet6\? \(addr:\)\?\s\?\(\(\([0-9]\+\.\)\{3\}[0-9]\+\)\|[a-fA-F0-9:]\+\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'"
alias ports='lsof +c0 -iTCP -sTCP:LISTEN -n -P'
alias defaultip=\"ip route | grep default\"
alias lay='tree -a --gitignore -I ".git"'
