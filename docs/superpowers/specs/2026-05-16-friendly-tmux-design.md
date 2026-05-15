# Friendly tmux setup — design

**Date:** 2026-05-16
**Repo:** `~/tmux-setup`
**Target:** macOS, tmux 3.6a (Homebrew), iTerm2, zsh

## Goal

A friendly, low-friction tmux configuration that does not collide with emacs/readline editing keys, looks polished out of the box, and is reproducible on a new machine via a single install script.

## Non-goals

- Building a sessionizer / fuzzy project picker (deferred).
- Migrating an existing tmux configuration (none exists).
- Cross-platform Linux/BSD support (macOS only for now; the config will be POSIX-friendly but not tested elsewhere).

## Design decisions

### Prefix key: `M-a` (Alt/Option + a)

`C-a` and `C-b` both collide with readline emacs-mode bindings (`beginning-of-line` and `backward-char`). `M-a` is unbound in standard readline and is comfortable to reach with the left thumb on Option.

Requires iTerm2 → Preferences → Profiles → Keys → "Left Option Key" set to **Esc+** so Alt-chords reach tmux. The README will document this.

`unbind C-b` is performed. `bind M-a send-prefix` is bound so a literal `M-a` can still be sent to an inner program by pressing the prefix twice.

### File layout

```
~/tmux-setup/
├── README.md           # quick reference: install, keybindings, troubleshooting
├── tmux.conf           # the actual config (source of truth)
├── install.sh          # idempotent installer
├── .gitignore          # excludes plugins/ if cloned in-place
└── docs/superpowers/specs/2026-05-16-friendly-tmux-design.md
```

Active config lives at `~/.config/tmux/tmux.conf` (XDG layout, matches user's existing `~/.config/zellij`, `~/.config/btop`, etc.). tmux 3.1+ auto-discovers this path with no env var needed.

`install.sh` symlinks `~/.config/tmux/tmux.conf` → `~/tmux-setup/tmux.conf`.

### Installer behavior

`install.sh` is idempotent and side-effect-aware:

1. Verify tmux ≥ 3.1 is installed; fail with a clear message if not.
2. Create `~/.config/tmux/` if missing.
3. If `~/.config/tmux/tmux.conf` exists and is **not** the expected symlink, back it up to `tmux.conf.bak.<timestamp>` before linking.
4. Create symlink to `~/tmux-setup/tmux.conf`.
5. Clone TPM to `~/.config/tmux/plugins/tpm` if missing (`git clone https://github.com/tmux-plugins/tpm`).
6. Run `~/.config/tmux/plugins/tpm/bin/install_plugins` to install all listed plugins non-interactively.
7. Print a final message telling the user to start tmux or run `tmux source ~/.config/tmux/tmux.conf` in a live session.

### Plugins (managed by TPM)

| Plugin | Purpose |
|---|---|
| `tmux-plugins/tpm` | Plugin manager itself |
| `tmux-plugins/tmux-sensible` | Battle-tested defaults that don't conflict with our settings |
| `tmux-plugins/tmux-yank` | Copy to system clipboard (`pbcopy` on macOS) |
| `tmux-plugins/tmux-resurrect` | Save/restore tmux sessions |
| `tmux-plugins/tmux-continuum` | Autosave every 15 min, restore on tmux start |
| `catppuccin/tmux` | Status-bar theme (Mocha flavor) |

### Keybindings

All prefix sequences are `M-a` followed by:

| Keys | Action |
|---|---|
| `r` | Reload config (`source ~/.config/tmux/tmux.conf`) with a confirmation message |
| `\|` | Split pane vertically, new pane inherits current pane's CWD |
| `-` | Split pane horizontally, new pane inherits current pane's CWD |
| `c` | New window, inherits current pane's CWD |
| `h` `j` `k` `l` | Move focus between panes (vi-style) |
| `H` `J` `K` `L` | Resize current pane by 5 cells (repeatable) |
| `M-a` | Send a literal `M-a` to the inner program |

Copy mode uses vi keys:

| Keys | Action |
|---|---|
| `prefix [` | Enter copy mode (tmux default) |
| `v` | Begin selection |
| `V` | Begin line selection |
| `y` | Copy selection to system clipboard (via tmux-yank) and exit |
| `q` | Exit copy mode |

Mouse support is on: click to focus pane/window, drag pane borders to resize, scroll wheel enters copy mode and scrolls history.

### Behavior settings

- `escape-time 10` — avoid the default 500ms delay that makes vim/emacs Esc feel laggy.
- `focus-events on` — let vim/emacs detect focus gain/loss.
- `history-limit 50000` — generous scrollback.
- `base-index 1`, `pane-base-index 1` — windows and panes number from 1 (matches the number-row keys).
- `renumber-windows on` — when a window closes, remaining windows compact down.
- `set-clipboard on` — let terminal apps populate the system clipboard via OSC 52.
- `default-terminal "tmux-256color"` with `terminal-overrides ",*256col*:RGB"` — true-color support in iTerm2.
- `mode-keys vi`, `status-keys emacs` — vi keys inside copy/choose modes; emacs keys in the command prompt (so `C-a`, `C-e` work when typing tmux commands).

### Status bar

Catppuccin Mocha flavor, positioned at top.

- **Left:** session name in a rounded segment.
- **Right:** window list, then date/time.
- **Window status:** current window highlighted with the accent color.
- No system stats (CPU, battery, network) — kept quiet and uncluttered. Can be added later.

### Resurrect / Continuum settings

- `@continuum-restore 'on'` — auto-restore on tmux start.
- `@continuum-save-interval '15'` — save every 15 minutes.
- `@resurrect-capture-pane-contents 'on'` — restore scrollback in each pane.
- `@resurrect-strategy-vim 'session'` and `@resurrect-strategy-nvim 'session'` — if vim/nvim was running with a session, reopen it.
- Saved state lives under `~/.local/share/tmux/resurrect/` (configured explicitly so it doesn't pollute `~/.tmux/`).

## Testing / validation

This is configuration, not application code, so "tests" are manual checks performed once after install:

1. Prefix works: `M-a c` opens a new window.
2. Splits inherit CWD: `cd /tmp`, `M-a |`, new pane is in `/tmp`.
3. Reload works: `M-a r` shows confirmation, edits to `tmux.conf` take effect.
4. Clipboard works: enter copy mode, select text, press `y`, paste with `Cmd-V` in another app.
5. Status bar renders Catppuccin theme without missing glyphs.
6. Persistence: detach, `tmux kill-server`, start tmux — session restores within ~5 seconds.
7. iTerm2 Option key sends Alt: pressing `M-a c` in a fresh iTerm2 tab creates a window (verifies the Esc+ setting).

A `README.md` troubleshooting section documents each of these along with the iTerm2 Option-key setting.

## Open risks / known trade-offs

- **iTerm2 Option-key setting is a one-time manual step.** Documented in README; not automatable from the install script in a way that wouldn't be invasive.
- **Catppuccin plugin pins versions.** A future upgrade may require updating `@catppuccin_*` option names; this is mitigated by pinning to a tag in `tmux.conf`.
- **tmux-resurrect restores running programs by name.** If a long-running process can't be re-spawned cleanly, the pane will come back empty. Acceptable.
- **No Linux testing.** The config will probably work on Linux with `xclip`/`wl-copy` swapped for `pbcopy`, but tmux-yank handles that automatically. Out of scope to validate now.
