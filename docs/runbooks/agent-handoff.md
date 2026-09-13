# Runbook: Agent Handoff

Installs Claude Code in the VM, logs it in through the text console, and hands the
driver role to Claude. Used in Phase 2. Verified by `tests/acceptance/phase-02.bats`,
with `phase-01.bats` as a regression check.

**Conventions**
- Everything runs **as your user** (`travis`) in the Unraid console, from
  `~/Projects/autarchy`, unless it says otherwise.
- Anything unexpected: stop, take a screenshot, and don't improvise changes.
- CI must be green on GitHub for this branch before you start.

---

## 1. Switch to the branch, then red

```sh
cd ~/Projects/autarchy
git fetch
git switch phase/02-agent-handoff
git pull

sudo -v
bats --formatter tap tests/acceptance | tee docs/phases/evidence/phase-02-red.tap
git add docs/phases/evidence/phase-02-red.tap
git commit -m "Phase 2: acceptance tests red before handoff"
git push
```

Expected: `phase-01` tests `ok`, and most `phase-02` tests `not ok`.

## 2. Install the declared packages

```sh
sudo pacman -S --needed $(scripts/pkglist packages/*.txt)
```

This adds shellcheck, shfmt, stow, tmux and jq.

## 3. Check the system config

```sh
sudo install/sync-system check
```

Expected: `in sync`, or only `missing:` lines for files the repo has added since this
machine was set up (for example `/etc/profile.d/local-bin.sh`). Install those with:

```sh
sudo install/sync-system apply
sudo install/sync-system check         # now: in sync
```

If `check` shows any `content:`, `mode:`, or `owner:` drift, **stop and take a
screenshot**. That means something changed a system file, and it needs review before
anything overwrites it.

## 4. Link home config and install Claude Code

```sh
install/link-home apply
install/link-home check                # expected: every file linked

install/claude-code install            # checks the signature and checksum, then installs
exec bash --login                      # picks up ~/.local/bin on PATH
claude --version
```

`install/claude-code` stops with an error if the signature or checksum doesn't match.
If that happens, screenshot it. **Never** fall back to `curl | bash`.

## 5. Log in without paste

Claude Code shows a login URL that has to reach a browser on the Mac, and the Mac's
browser gives back a one-time code that has to reach the VM. `scripts/gist-relay`
carries both through a **secret gist that is deleted right after use**. Only use it for
short-lived text like this. **Never** relay tokens, keys or passwords.

**VM, start tmux and Claude:**

```sh
tmux
```

In tmux window 0:

```sh
cd ~/Projects/autarchy
claude
```

Pick a theme, accept the trust prompt for this folder, and choose to log in with your
Claude account. Claude shows a URL and waits at `Paste code here if prompted`.

**VM, send the screen out.** Press `Ctrl-b c` to open window 1, then:

```sh
cd ~/Projects/autarchy
scripts/gist-relay send-pane 0
```

It prints a gist ID.

**Mac, read the URL and delete that gist:**

```sh
gh gist view <id> --raw && gh gist delete <id> --yes
```

Open the URL in the browser, sign in, and authorize. Copy the code the page shows, then:

```sh
pbpaste | gh gist create --desc autarchy-relay -
```

**VM, receive the code.** Still in window 1:

```sh
scripts/gist-relay receive
```

It reports how many characters it loaded and that the gist is deleted. Press `Ctrl-b 0`
to go back to Claude. At the `Paste code here` prompt press `Ctrl-b ]`, then Enter.
Expect `Login successful`.

## 6. Green

Leave Claude running in window 0. In window 1:

```sh
claude doctor
sudo -v
bats --formatter tap tests/acceptance | tee docs/phases/evidence/phase-02-green.tap
git add docs/phases/evidence/phase-02-green.tap
git commit -m "Phase 2: acceptance tests green after handoff"
git push
```

If anything is `not ok`, push the TAP file anyway. Claude on the Mac fixes the cause,
and you `git pull` and re-run.

## 7. Handoff

In window 0, give Claude its first task:

```text
Read CLAUDE.md and docs/phases/phase-02-agent-handoff.md. Update the "Current driver"
section of CLAUDE.md: Claude Code now drives from inside the VM, and the user runs any
command that needs sudo in another tmux window. Commit and push.
```

Claude can't use sudo (a deny rule). When it needs root, it writes or names a script,
and you run it in window 1.

## Working with tmux on the console

| Keys | Action |
|---|---|
| `Ctrl-b c` | new window |
| `Ctrl-b 0`, `Ctrl-b 1` | switch window |
| `Ctrl-b [` then arrows or PageUp | scroll back (`q` to leave) |
| `Ctrl-b ]` | paste the tmux buffer |
| `Ctrl-b d` | detach (`tmux attach` to return) |
