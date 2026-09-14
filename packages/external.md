# Software installed outside pacman

Everything else on the system comes from `packages/*.txt`. Each entry here needs a
reason pacman can't provide it, a verified install path, and a known update mechanism.

| Software | Source | Installed by | Verification | Updates | Why not pacman |
|---|---|---|---|---|---|
| Claude Code | Anthropic release bucket (`downloads.claude.ai/claude-code-releases`), `stable` channel | `install/claude-code install` (as the user, into `~/.local`) | Release manifest GPG signature (key `31DD DE24 DDFA B679 F42D 7BD2 BAA9 29FF 1A7E CACE`) + binary SHA256 | Claude Code's built-in updater, `autoUpdatesChannel: stable`; `install/claude-code verify` re-checks | Not in the official repos. The AUR package needs a hand rebuild for releases that ship almost daily, and adds a third party between us and Anthropic. |
