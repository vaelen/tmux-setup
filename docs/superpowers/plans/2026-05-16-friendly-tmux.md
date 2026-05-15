# Friendly tmux Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal tmux configuration repo at `~/tmux-setup/` that installs to `~/.config/tmux/`, uses `M-a` as prefix, and produces a polished out-of-the-box experience with TPM, tmux-yank, tmux-resurrect, tmux-continuum, and Catppuccin Mocha.

**Architecture:** A single `tmux.conf` (source of truth in the repo, symlinked into `~/.config/tmux/`), a TPM plugin manifest declared inline in the config, and an idempotent `install.sh` that symlinks the config, bootstraps TPM, and installs plugins headlessly. README documents the iTerm2 one-time setup and the keybinding reference.

**Tech Stack:** tmux 3.6a, TPM (Tmux Plugin Manager), bash for install script, macOS / iTerm2 / zsh user environment.

**Spec:** `docs/superpowers/specs/2026-05-16-friendly-tmux-design.md`

---

## File structure

| Path | Responsibility |
|---|---|
| `~/tmux-setup/.gitignore` | Exclude accidentally-placed `plugins/` directory and OS junk |
| `~/tmux-setup/tmux.conf` | The actual tmux configuration — source of truth |
| `~/tmux-setup/install.sh` | Idempotent installer: symlink, bootstrap TPM, install plugins |
| `~/tmux-setup/README.md` | Quick start, iTerm2 setup, keybinding reference, troubleshooting |

All work happens in `/Users/andrew/tmux-setup/` (already a git repo; spec is already committed).

## Validation strategy

tmux configuration cannot be unit-tested. After every change to `tmux.conf`, we validate by starting a throwaway tmux server on a private socket, sourcing the file, and checking the exit code:

```bash
tmux -L _validate kill-server 2>/dev/null
tmux -L _validate -f /Users/andrew/tmux-setup/tmux.conf start-server \; kill-server
echo "exit=$?"
```

A clean run prints nothing except `exit=0`. Any parse or unknown-option error is printed to stderr. This validator is used at the end of every config-touching task.

---

### Task 1: Project skeleton

**Files:**
- Create: `/Users/andrew/tmux-setup/.gitignore`
- Create: `/Users/andrew/tmux-setup/tmux.conf` (empty for now)

- [ ] **Step 1: Write `.gitignore`**

Path: `/Users/andrew/tmux-setup/.gitignore`

```
# tmux runtime / plugin install location (should never live inside this repo,
# but ignore in case someone clones TPM here by accident)
plugins/
resurrect/

# macOS
.DS_Store

# Editor backups
*~
*.swp
*.bak.*
```

- [ ] **Step 2: Create empty `tmux.conf`**

Path: `/Users/andrew/tmux-setup/tmux.conf`

```
# Friendly tmux configuration. Source of truth lives in ~/tmux-setup/tmux.conf;
# active config is symlinked to ~/.config/tmux/tmux.conf by install.sh.
```

- [ ] **Step 3: Validate empty config parses**

Run:
```bash
tmux -L _validate kill-server 2>/dev/null
tmux -L _validate -f /Users/andrew/tmux-setup/tmux.conf start-server \; kill-server
echo "exit=$?"
```
Expected: `exit=0` with no other output.

- [ ] **Step 4: Commit**

```bash
cd /Users/andrew/tmux-setup
git add .gitignore tmux.conf
git commit -m "chore: add project skeleton (.gitignore, empty tmux.conf)"
```

---

### Task 2: Core options — terminal, prefix, behavior

**Files:**
- Modify: `/Users/andrew/tmux-setup/tmux.conf`

- [ ] **Step 1: Append the "core options" block**

Append to `/Users/andrew/tmux-setup/tmux.conf`:

```
# --- Core options --------------------------------------------------------

# Terminal: declare tmux-256color so apps detect 256-color + italics. Override
# RGB capability for the outer terminal so true-color (24-bit) works in vim,
# bat, etc. (iTerm2 advertises this correctly.)
set -g default-terminal "tmux-256color"
set -as terminal-features ",*256col*:RGB"

# Prefix: M-a (Alt+a). Avoids collision with emacs/readline C-a (beginning-of-
# line) and C-b (backward-char). iTerm2 must be configured with
# "Left Option Key = Esc+" for Alt-chords to reach tmux. See README.
unbind C-b
set -g prefix M-a
bind M-a send-prefix   # press prefix twice to send a literal M-a to inner app

# Index windows and panes from 1 (matches the number-row keys on the keyboard).
set -g  base-index 1
setw -g pane-base-index 1
set -g  renumber-windows on

# Responsiveness: tmux waits up to escape-time ms for an escape sequence after
# Esc. Default is 500ms which makes Esc-driven editors (vim, emacs) feel laggy.
set -sg escape-time 10

# Focus events: let vim/nvim detect when a pane gains/loses focus, so e.g.
# :checktime fires on focus.
set -g focus-events on

# Generous scrollback.
set -g history-limit 50000

# Allow apps inside tmux to populate the system clipboard via OSC 52.
set -g set-clipboard on

# Mouse: click to focus pane/window, drag borders to resize, scroll wheel
# enters copy mode and scrolls history.
set -g mouse on

# Key mode: vi keys in copy/choose modes; emacs keys in the tmux command prompt
# (so C-a / C-e work when typing at the `:` prompt).
setw -g mode-keys   vi
set  -g status-keys emacs
```

- [ ] **Step 2: Validate config parses**

Run:
```bash
tmux -L _validate kill-server 2>/dev/null
tmux -L _validate -f /Users/andrew/tmux-setup/tmux.conf start-server \; kill-server
echo "exit=$?"
```
Expected: `exit=0` with no error output.

- [ ] **Step 3: Verify the prefix actually changed inside the validation server**

Run:
```bash
tmux -L _validate kill-server 2>/dev/null
tmux -L _validate -f /Users/andrew/tmux-setup/tmux.conf start-server
tmux -L _validate show-options -gv prefix
tmux -L _validate kill-server
```
Expected: prints `M-a` (and nothing else relevant).

- [ ] **Step 4: Commit**

```bash
cd /Users/andrew/tmux-setup
git add tmux.conf
git commit -m "feat: configure prefix M-a and core behavior options"
```

---

### Task 3: Keybindings — reload, splits, panes, copy mode

**Files:**
- Modify: `/Users/andrew/tmux-setup/tmux.conf`

- [ ] **Step 1: Append the keybindings block**

Append to `/Users/andrew/tmux-setup/tmux.conf`:

```
# --- Keybindings ---------------------------------------------------------

# Reload config from the symlinked location with a confirmation message.
bind r source-file ~/.config/tmux/tmux.conf \; display-message "tmux.conf reloaded"

# Splits: | vertical, - horizontal. New panes inherit the current pane's CWD.
# Unbind the defaults (" and %) so there's one way to do it.
unbind '"'
unbind %
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# New window also inherits CWD.
unbind c
bind c new-window -c "#{pane_current_path}"

# Pane navigation: vi-style hjkl.
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Pane resize: capital HJKL, 5 cells, repeatable (-r keeps the prefix sticky
# for repeat-time milliseconds so you can press H H H).
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# --- Copy mode -----------------------------------------------------------
# vi keys: v to begin selection, V to begin line selection, y to yank to the
# system clipboard via tmux-yank (loaded below).
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi V send-keys -X select-line
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
```

- [ ] **Step 2: Validate config parses**

Run:
```bash
tmux -L _validate kill-server 2>/dev/null
tmux -L _validate -f /Users/andrew/tmux-setup/tmux.conf start-server \; kill-server
echo "exit=$?"
```
Expected: `exit=0`.

- [ ] **Step 3: Verify a representative binding is registered**

Run:
```bash
tmux -L _validate kill-server 2>/dev/null
tmux -L _validate -f /Users/andrew/tmux-setup/tmux.conf start-server
tmux -L _validate list-keys -T prefix | grep -E '^bind-key.*\|.*split-window'
tmux -L _validate list-keys -T prefix | grep -E '^bind-key.*-r.*H .*resize-pane'
tmux -L _validate kill-server
```
Expected: two non-empty lines confirming `|` binds split-window and `H` binds resize-pane.

- [ ] **Step 4: Commit**

```bash
cd /Users/andrew/tmux-setup
git add tmux.conf
git commit -m "feat: add splits, pane nav, resize, and vi copy-mode keybindings"
```

---

### Task 4: Plugins, theme, and persistence

**Files:**
- Modify: `/Users/andrew/tmux-setup/tmux.conf`

This task adds the TPM plugin list and configures Catppuccin + resurrect/continuum. The plugins themselves are not installed yet — `install.sh` does that in Task 5. The config still parses without the plugins present; the bindings/options provided by plugins simply won't take effect until they're cloned.

- [ ] **Step 1: Append the plugins block**

Append to `/Users/andrew/tmux-setup/tmux.conf`:

```
# --- Plugins (TPM) -------------------------------------------------------
# Plugins live under ~/.config/tmux/plugins/. install.sh clones TPM there and
# runs the headless installer for the list below.

# Sensible defaults (low-risk, doesn't fight our settings).
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

# System clipboard integration. Provides 'y' in copy mode (we also explicitly
# bind y above so the behavior is the same regardless of plugin load order).
set -g @plugin 'tmux-plugins/tmux-yank'

# Session save/restore.
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'

# Theme.
set -g @plugin 'catppuccin/tmux#v2.1.3'

# --- Plugin options ------------------------------------------------------

# Continuum: autosave every 15 minutes, restore on tmux server start.
set -g @continuum-restore       'on'
set -g @continuum-save-interval '15'

# Resurrect: keep pane contents and reopen vim/nvim sessions if applicable.
set -g @resurrect-capture-pane-contents 'on'
set -g @resurrect-strategy-vim          'session'
set -g @resurrect-strategy-nvim         'session'
set -g @resurrect-dir                   '~/.local/share/tmux/resurrect'

# Catppuccin: Mocha flavor, status bar at top.
set -g @catppuccin_flavor 'mocha'
set -g status-position top

# Catppuccin v2 module list. Left side: session. Right side: window list,
# then date/time. Keep it quiet — no system stats.
set -g status-left-length  100
set -g status-right-length 100
set -g status-left  "#{E:@catppuccin_status_session}"
set -g status-right "#{E:@catppuccin_status_date_time}"
set -g @catppuccin_date_time_text " %Y-%m-%d %H:%M"

# --- TPM init (must be the LAST line) ------------------------------------
run '~/.config/tmux/plugins/tpm/tpm'
```

- [ ] **Step 2: Validate config parses even without TPM cloned yet**

Run:
```bash
tmux -L _validate kill-server 2>/dev/null
tmux -L _validate -f /Users/andrew/tmux-setup/tmux.conf start-server \; kill-server 2>&1
echo "exit=$?"
```
Expected: `exit=0`. If the final `run` line fails because `~/.config/tmux/plugins/tpm/tpm` doesn't exist yet, tmux prints a non-fatal warning but the server still starts and exits cleanly. That's acceptable — Task 5 installs TPM.

- [ ] **Step 3: Commit**

```bash
cd /Users/andrew/tmux-setup
git add tmux.conf
git commit -m "feat: declare plugins, Catppuccin theme, and persistence settings"
```

---

### Task 5: Install script

**Files:**
- Create: `/Users/andrew/tmux-setup/install.sh`

The script is idempotent: safe to run repeatedly. It backs up any pre-existing real file at the target before replacing it with a symlink, and skips work that is already done.

- [ ] **Step 1: Write `install.sh`**

Path: `/Users/andrew/tmux-setup/install.sh`

```bash
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
log "installing/updating plugins via TPM"
"$TPM_DIR/bin/install_plugins"

# 6. Resurrect state dir.
mkdir -p "$HOME/.local/share/tmux/resurrect"

log "done."
echo
echo "Next steps:"
echo "  - In iTerm2: Preferences > Profiles > Keys > Left Option Key = Esc+"
echo "  - Reload in a running tmux: prefix r   (prefix is Alt+a)"
echo "  - Or start fresh: tmux"
```

- [ ] **Step 2: Make it executable**

Run:
```bash
chmod +x /Users/andrew/tmux-setup/install.sh
```

- [ ] **Step 3: Run shellcheck-style smoke test (bash -n)**

Run:
```bash
bash -n /Users/andrew/tmux-setup/install.sh
echo "syntax_exit=$?"
```
Expected: `syntax_exit=0` and no output above it.

- [ ] **Step 4: Commit**

```bash
cd /Users/andrew/tmux-setup
git add install.sh
git commit -m "feat: add idempotent install.sh (symlink, TPM, plugins)"
```

---

### Task 6: README

**Files:**
- Create: `/Users/andrew/tmux-setup/README.md`

- [ ] **Step 1: Write the README**

Path: `/Users/andrew/tmux-setup/README.md`

````markdown
# tmux-setup

Personal, reproducible tmux configuration for macOS + iTerm2.

## Install

```bash
git clone <this-repo> ~/tmux-setup    # or already cloned
cd ~/tmux-setup
./install.sh
```

`install.sh` symlinks `~/.config/tmux/tmux.conf` to this repo, clones TPM,
and installs all plugins headlessly. It is idempotent — safe to re-run after
`git pull`.

## One-time iTerm2 setup

The prefix is `Alt+a` (a.k.a. `M-a`). For Alt-chords to reach tmux, iTerm2
must send the Esc-prefix form of Option:

**iTerm2 → Settings → Profiles → Keys → General → Left Option Key → Esc+**

(Repeat for Right Option Key if you use it.)

Quick verification: open a new iTerm2 tab and press `Alt+a c`. A new tmux
window should appear. If nothing happens, the Option-key setting is wrong.

## Prefix and key reference

All chords below are pressed **after** the prefix unless noted.

| Key | Action |
|---|---|
| `r` | Reload config |
| `\|` | Split pane vertically (new pane in current CWD) |
| `-` | Split pane horizontally (new pane in current CWD) |
| `c` | New window (in current CWD) |
| `h` `j` `k` `l` | Move between panes |
| `H` `J` `K` `L` | Resize current pane by 5 cells (repeatable, no extra prefix needed) |
| `Alt+a` | Send a literal `Alt+a` to the inner program |
| `[` | Enter copy mode |
| `]` | Paste most-recent copy buffer |
| `d` | Detach |
| `s` | Choose session |
| `w` | Choose window |
| `&` | Kill window (with confirm) |
| `x` | Kill pane (with confirm) |

In copy mode (vi keys):

| Key | Action |
|---|---|
| `v` | Begin selection |
| `V` | Begin line selection |
| `y` | Copy to system clipboard and exit copy mode |
| `q` | Exit copy mode |

Mouse is on: click panes/windows, drag borders to resize, scroll wheel enters
copy mode and scrolls history.

## Plugins

| Plugin | Purpose |
|---|---|
| [tpm](https://github.com/tmux-plugins/tpm) | Plugin manager |
| [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) | Battle-tested defaults |
| [tmux-yank](https://github.com/tmux-plugins/tmux-yank) | System clipboard integration |
| [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) | Save/restore sessions |
| [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) | Auto-save every 15 min, auto-restore on start |
| [catppuccin/tmux](https://github.com/catppuccin/tmux) | Status-bar theme (Mocha flavor) |

Plugins live under `~/.config/tmux/plugins/`. Inside tmux:

- `prefix + I` — install plugins listed in `tmux.conf`
- `prefix + U` — update all plugins
- `prefix + Alt+u` — uninstall plugins removed from `tmux.conf`

## Troubleshooting

**`Alt+a` does nothing.** iTerm2 Left Option Key is set to "Normal". Change it
to "Esc+" (see One-time iTerm2 setup above).

**Status bar shows tofu / missing glyphs.** Catppuccin v2 modules use a small
set of unicode chars; any modern terminal font should render them. If you see
boxes, switch to a Nerd Font in iTerm2.

**Plugins didn't install.** Re-run `./install.sh` — it's idempotent. To force
a fresh install, delete `~/.config/tmux/plugins/` and re-run.

**Session didn't restore after reboot.** Continuum saves every 15 minutes; if
you killed tmux less than 15 min after the last save you'll get the previous
snapshot. Saved files are under `~/.local/share/tmux/resurrect/`.

**Sourcing the config in a running session.** `prefix r`, or
`tmux source ~/.config/tmux/tmux.conf` from a shell.

## Updating

```bash
cd ~/tmux-setup
git pull
./install.sh        # re-runs plugin install/update
# inside tmux: prefix r
```

## File layout

```
~/tmux-setup/
├── tmux.conf       # source of truth
├── install.sh      # symlink + TPM bootstrap + plugin install
├── README.md       # this file
├── .gitignore
└── docs/superpowers/{specs,plans}/    # design and implementation docs
```

Symlink target: `~/.config/tmux/tmux.conf` → `~/tmux-setup/tmux.conf`.
````

- [ ] **Step 2: Commit**

```bash
cd /Users/andrew/tmux-setup
git add README.md
git commit -m "docs: add README with install, keybindings, troubleshooting"
```

---

### Task 7: End-to-end install and validation

This task actually runs `install.sh` against the live system and walks through the validation checklist from the spec. Stop and report if any check fails.

**Files:** none modified by the engineer; `install.sh` modifies `~/.config/tmux/` and `~/.local/share/tmux/`.

- [ ] **Step 1: Snapshot pre-existing state**

Run:
```bash
ls -la ~/.config/tmux/ 2>&1 || true
ls -la ~/.config/tmux/plugins/ 2>&1 || true
```
Note whether anything already exists. The installer should back it up; record what's there so you can confirm the backup was created.

- [ ] **Step 2: Run install.sh**

Run:
```bash
/Users/andrew/tmux-setup/install.sh
```
Expected: prints `[install] tmux ... OK`, creates symlink, clones TPM, installs plugins. Final line: `[install] done.` Exit code 0.

- [ ] **Step 3: Verify symlink**

Run:
```bash
ls -l ~/.config/tmux/tmux.conf
```
Expected: shows `~/.config/tmux/tmux.conf -> /Users/andrew/tmux-setup/tmux.conf`.

- [ ] **Step 4: Verify all plugins are present on disk**

Run:
```bash
ls ~/.config/tmux/plugins/
```
Expected: directory contains `tpm`, `tmux-sensible`, `tmux-yank`, `tmux-resurrect`, `tmux-continuum`, `tmux` (the catppuccin plugin's repo is named `tmux`).

- [ ] **Step 5: Validate config in isolation (does not touch the user's running tmux)**

Run:
```bash
tmux -L _validate kill-server 2>/dev/null
tmux -L _validate -f ~/.config/tmux/tmux.conf start-server \; kill-server
echo "exit=$?"
```
Expected: `exit=0`. Any tmux errors here block the rest of the task — fix before continuing.

- [ ] **Step 6: Reload config in the user's running tmux (if running)**

If `$TMUX` is set in the current shell, run:
```bash
tmux source-file ~/.config/tmux/tmux.conf
tmux display-message -p "prefix=#{prefix}"
```
Expected: `prefix=M-a`. If `$TMUX` is not set, instead launch a fresh session:
```bash
tmux new-session -d -s _check
tmux send-keys -t _check 'echo $TMUX' Enter
tmux display-message -t _check -p "prefix=#{prefix}"
tmux kill-session -t _check
```
Expected: `prefix=M-a`.

- [ ] **Step 7: Run idempotency check**

Run:
```bash
/Users/andrew/tmux-setup/install.sh
```
Expected: prints `symlink already points to ...` and `TPM already cloned ...`. No backup files created. Exit code 0.

- [ ] **Step 8: Hand off to manual checklist**

The remaining validations require interactive use and cannot be scripted. Stop here and ask the user to walk through the **Manual validation** section in Task 8 of this plan, then report results.

---

### Task 8: Manual validation checklist (user-driven)

These checks are performed by the user in iTerm2, not by the implementing agent. Document the result of each.

- [ ] **Check 1: iTerm2 Option key.** Open a fresh iTerm2 tab. Press `Alt+a c`. A new tmux window should appear. If nothing happens, set iTerm2 Left Option Key to `Esc+` and retry.

- [ ] **Check 2: Splits inherit CWD.** `cd /tmp`. Press `Alt+a |`. New right-hand pane should show `/tmp` when you run `pwd`.

- [ ] **Check 3: Reload.** Edit any harmless line in `~/tmux-setup/tmux.conf` (e.g., add a comment), save, then press `Alt+a r`. Bottom of the screen flashes `tmux.conf reloaded`.

- [ ] **Check 4: Clipboard.** Press `Alt+a [` to enter copy mode, navigate with `hjkl`, press `v` to start selection, move to extend, press `y`. Switch to another app and paste with `Cmd+V` — the selected text should appear.

- [ ] **Check 5: Status bar renders.** Bottom-left shows session name in a Catppuccin-colored segment. Right side shows window list and date/time. No `?` glyphs or boxes.

- [ ] **Check 6: Persistence.** Open 2-3 windows, run `tmux display-message -p '#{continuum_status}'` to see the save state (or wait ~15 min, then run it). Detach (`Alt+a d`), then `tmux kill-server`. Run `tmux` again — within ~5 seconds the windows reappear.

- [ ] **Check 7: Pane resize repeatability.** Press `Alt+a H H H` (three Hs after one prefix). The pane should shrink three times without re-pressing the prefix.

If all seven checks pass, the setup is complete.

- [ ] **Final commit (none expected unless the user requested tweaks)**

If no changes are made during validation, no commit is needed. The repo is at its final state after Task 6.

---

## Self-review notes

- **Spec coverage:** every spec section maps to a task. Prefix → Task 2. File layout / symlink → Task 1, 5. Plugins → Task 4, 5. Keybindings → Task 3. Status bar → Task 4. Resurrect / Continuum → Task 4. Testing → Task 7, 8. README + troubleshooting → Task 6.
- **No placeholders.** Every code block is complete and self-contained.
- **Type/name consistency:** the symlink target path (`~/.config/tmux/tmux.conf`), the source path (`~/tmux-setup/tmux.conf`), the plugin names, and the resurrect dir (`~/.local/share/tmux/resurrect`) are identical across spec, install.sh, README, and validator commands.
- **YAGNI:** no sessionizer, no Nerd-Font assumption, no CPU/battery widgets, no Linux clipboard branching (tmux-yank handles platform detection).
