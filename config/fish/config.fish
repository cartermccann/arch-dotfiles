# ~/.config/fish/config.fish
# Ported from Carter's NixOS setup (home/shell.nix). Yours now: edit freely.
# Machine-specific bits belong in ~/.config/fish/conf.d/local.fish.

# ── PATH and environment (every shell, including scripts) ────────────
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx GOPATH $HOME/.local/share/go
set -gx GOBIN $HOME/.local/bin
fish_add_path $HOME/.local/bin $HOME/.cargo/bin

# mise manages Node, pnpm, bun and deno (see GUIDE.md › "Languages").
# Activating it puts the right versions on PATH for whatever directory you
# are in, including per-project versions pinned in mise.toml/.nvmrc.
if type -q mise
    mise activate fish | source
end

status is-interactive; or return

# ── Aliases ──────────────────────────────────────────────────────────
alias .. 'cd ..'
alias ... 'cd ../..'
alias ls 'eza --icons'
alias ll 'eza -la --icons'
alias cat bat
alias grep rg
alias y yazi

alias gs 'git status'
alias ga 'git add'
alias gc 'git commit'
alias gp 'git push'
alias gl 'git log --oneline --graph'
alias gd 'git diff'
alias gb 'git branch'

alias dc docker-compose
alias dps 'docker ps'
alias dimg 'docker images'
alias dlog 'docker logs'

# Autosuggestion colour: visible but subtle on the dark background
set -g fish_color_autosuggestion 90909a
set -g fish_greeting

# ── Functions ────────────────────────────────────────────────────────
# Update everything: repo + AUR packages, then mise-managed runtimes.
function up --description "update system packages, AUR packages and mise runtimes"
    paru -Syu; or return 1
    if type -q mise
        mise upgrade
    end
    pkill -RTMIN+8 waybar 2>/dev/null
    true
end

# tmux dev layout: nvim on the left, two shells on the right
function dev
    tmux new-session -d -s dev -c (pwd)
    tmux split-window -h -p 40
    tmux split-window -v -p 50
    tmux select-pane -t 1
    tmux send-keys -t dev:1.1 nvim Enter
    tmux select-pane -t dev:1.1
    tmux attach -t dev
end

# One canonical tmux session
function t
    tmux attach; or tmux new -s work
end

# Git worktrees as `repo--branch` sibling dirs.
# (named gwa/gwr since ga/gd are taken by git add / git diff)
function gwa --description "git worktree add -b <branch> ../<repo>--<branch>"
    if test (count $argv) -ne 1
        echo "usage: gwa <branch>"
        return 1
    end
    set -l repo (basename (git rev-parse --show-toplevel)); or return 1
    set -l dir ../$repo--$argv[1]
    git worktree add -b $argv[1] $dir; and cd $dir
end

function gwr --description "remove current worktree dir + its branch"
    set -l dir (basename $PWD)
    set -l branch (string split --max 1 -- '--' $dir)[2]
    if test -z "$branch"
        echo "gwr: '$dir' is not a repo--branch worktree dir"
        return 1
    end
    gum confirm "Remove worktree $dir and delete branch $branch?"; or return 1
    cd ..
    git -C (string replace -- "--$branch" "" $dir) worktree remove $dir --force
    and git -C (string replace -- "--$branch" "" $dir) branch -D $branch
end

# ── Tools ────────────────────────────────────────────────────────────
type -q fzf; and fzf --fish | source
type -q zoxide; and zoxide init fish | source
type -q atuin; and atuin init fish | source
type -q direnv; and direnv hook fish | source
if test "$TERM" != dumb; and type -q starship
    starship init fish | source
end
