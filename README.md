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
