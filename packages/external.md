# Software installed outside pacman

Everything else on the system comes from `packages/*.txt`. Each entry here needs a
reason pacman can't provide it, a verified install path, and a known update mechanism.

The Neovim config row below is a different kind of exception: not software, but a
personally-owned config repo this machine depends on without this repo owning or
redistributing it (Phase 7, D-0043 onward) -- `neovim` itself is an ordinary package
(`packages/base.txt`).

| Software | Source | Installed by | Verification | Updates | Why not pacman |
|---|---|---|---|---|---|
| Neovim config | `github.com/Symphon-y/config.nvim` (public, own repo, default branch `master`) | `git clone https://github.com/Symphon-y/config.nvim.git ~/.config/nvim` (plain HTTPS, no auth) | It's just a git checkout -- `git -C ~/.config/nvim status`/`remote get-url origin` | `git -C ~/.config/nvim pull`, whenever wanted, from that repo directly | It's the user's own personal config, independently maintained across machines -- vendoring it into `home/nvim/` would fork it and drift from the source instead of tracking it |
| Claude Code | Anthropic release bucket (`downloads.claude.ai/claude-code-releases`), `stable` channel | `install/claude-code install` (as the user, into `~/.local`) | Release manifest GPG signature (key `31DD DE24 DDFA B679 F42D 7BD2 BAA9 29FF 1A7E CACE`) + binary SHA256 | Claude Code's built-in updater, `autoUpdatesChannel: stable`; `install/claude-code verify` re-checks | Not in the official repos. The AUR package needs a hand rebuild for releases that ship almost daily, and adds a third party between us and Anthropic. |
| yay | AUR (`aur.archlinux.org/yay.git`) | `git clone` + `makepkg -si` (manual, one-time; needs `sudo` for the final `pacman -U`, so the user runs it, not Claude) | `makepkg` verifies the PKGBUILD's own `sha256sums`/`b2sums` before building | `yay -Syu` updates yay alongside every other AUR package it manages | The bootstrapping problem: an AUR helper can't itself come from a repo pacman already trusts. |
| xdg-terminal-exec | AUR (`aur.archlinux.org/xdg-terminal-exec.git`), upstream a freedesktop.org draft standard (`gitlab.freedesktop.org/Vladimir-csp/xdg-terminal-exec`) | `yay -S xdg-terminal-exec` (after yay exists) | Same as any AUR package: `makepkg`'s `sha256sums` check, run by yay | `yay -Syu` | Not in the official repos: a small (~1500-line POSIX shell script implementing a proposed standard), but genuinely AUR-only, unlike matugen (confirmed by checking the live pacman database directly, correcting earlier research that assumed AUR without checking). |
