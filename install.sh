#!/usr/bin/env bash
# install.sh — wire ~/tmux-setup/tmux.conf into ~/.config/tmux and install plugins.
# Idempotent: safe to re-run after pulling updates.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux"
CFG_FILE="$CFG_DIR/tmux.conf"
SRC_FILE="$REPO_DIR/tmux.conf"
TPM_DIR="$CFG_DIR/plugins/tpm"

log()  { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# 1. Sanity check tmux version (need >= 3.1 for the XDG config path).
command -v tmux >/dev/null || die "tmux not found on PATH. Install with: brew install tmux"
TMUX_VER="$(tmux -V | awk '{print $2}' | tr -d 'a-z')"
awk -v v="$TMUX_VER" 'BEGIN { split(v,a,"."); if (a[1]*10 + a[2] < 31) exit 1 }' \
    || die "tmux $TMUX_VER is too old (need >= 3.1). Upgrade with: brew upgrade tmux"
log "tmux $TMUX_VER OK"

# 2. Ensure target dir exists.
mkdir -p "$CFG_DIR"

# 3. Place the symlink, backing up any real file at the target first.
if [[ -L "$CFG_FILE" ]]; then
    if [[ "$(readlink "$CFG_FILE")" == "$SRC_FILE" ]]; then
        log "symlink already points to $SRC_FILE"
    else
        log "replacing existing symlink at $CFG_FILE"
        ln -sfn "$SRC_FILE" "$CFG_FILE"
    fi
elif [[ -e "$CFG_FILE" ]]; then
    BACKUP="$CFG_FILE.bak.$(date +%Y%m%d-%H%M%S)"
    warn "found real file at $CFG_FILE — backing up to $BACKUP"
    mv "$CFG_FILE" "$BACKUP"
    ln -s "$SRC_FILE" "$CFG_FILE"
    log "linked $CFG_FILE -> $SRC_FILE"
else
    ln -s "$SRC_FILE" "$CFG_FILE"
    log "linked $CFG_FILE -> $SRC_FILE"
fi

# 4. Clone TPM if missing.
if [[ -d "$TPM_DIR/.git" ]]; then
    log "TPM already cloned at $TPM_DIR"
else
    log "cloning TPM into $TPM_DIR"
    mkdir -p "$(dirname "$TPM_DIR")"
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

# 5. Headless plugin install.
# `tmux start-server` is a no-op if a server is already running, so a
# pre-existing server with a stale env (e.g. started before the symlink
# existed) won't have TMUX_PLUGIN_MANAGER_PATH set and install_plugins
# would abort with "FATAL: Tmux Plugin Manager not configured in tmux.conf".
# Set it explicitly to TPM's XDG default before invoking.
log "installing/updating plugins via TPM"
tmux start-server \; set-environment -g TMUX_PLUGIN_MANAGER_PATH "$CFG_DIR/plugins/"
"$TPM_DIR/bin/install_plugins"

# 6. Resurrect state dir.
mkdir -p "$HOME/.local/share/tmux/resurrect"

log "done."
echo
echo "Next steps:"
echo "  - In iTerm2: Preferences > Profiles > Keys > Left Option Key = Esc+"
echo "  - Reload in a running tmux: prefix r   (prefix is Alt+a)"
echo "  - Or start fresh: tmux"
