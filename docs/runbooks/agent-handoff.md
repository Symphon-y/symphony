# Runbook: Agent Handoff

Installs Claude Code in the VM, sets up on-demand SSH from Unraid's web terminal (for
copy/paste), logs Claude Code in, and hands the driver role to Claude. Used in Phase 2.
Verified by `tests/acceptance/phase-02.bats`, with `phase-01.bats` as a regression
check.

**Conventions**
- VM steps run **as your user** (`travis`) from `~/Projects/autarchy`. Unraid steps run
  in Unraid's web terminal (`<internal-hostname>`, the `>_` button in the top right).
- Anything unexpected: stop, take a screenshot, and don't improvise changes.
- CI must be green on GitHub for this branch before each VM `git pull`.

---

## 1. Switch to the branch, then red (VM console)

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

## 2. Install the declared packages (VM console)

```sh
sudo pacman -S --needed $(scripts/pkglist packages/*.txt)
```

## 3. Check the system config (VM console)

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

## 4. Link home config and install Claude Code (VM console)

```sh
install/link-home apply
install/link-home check                # expected: every file linked

install/claude-code install            # checks the signature and checksum, then installs
exec bash --login                      # picks up ~/.local/bin on PATH
claude --version
```

`install/claude-code` stops with an error if the signature or checksum doesn't match.
If that happens, screenshot it. **Never** fall back to `curl | bash`.

## 5. SSH from Unraid (one-time setup)

Copy and paste work in Unraid's web terminal because it runs in the browser. SSH from
there to the VM gives you a session with copy and paste. Nothing is exposed beyond
Unraid: sshd is key-only, never allows root, only starts when you start it, and the VM
firewall accepts SSH only from Unraid's LAN IP.

**5a. Unraid: create the key.**

```sh
ls -la /root/.ssh                      # expect: /root/.ssh -> /boot/config/ssh/root (persists on flash)
ssh-keygen -t ed25519 -f /root/.ssh/autarchy-vm -C unraid-to-autarchy-vm   # set a passphrase
cat /root/.ssh/autarchy-vm.pub
ip -4 -br addr show br0
```

Send Claude the public key line and Unraid's `br0` IP. **Never** share
`/root/.ssh/autarchy-vm` (the private key). Claude commits them as machine-specific
config in `system/hosts/autarchy-vm/`.

**5b. VM console, once that commit is green in CI:**

```sh
git pull
sudo pacman -S --needed $(scripts/pkglist packages/*.txt)   # adds openssh
sudo install/sync-system check         # expect only missing: lines for the new ssh/firewall files
sudo install/sync-system apply
sudo systemctl restart nftables        # load the new firewall rule
sudo systemctl start sshd              # on demand; it is never enabled at boot
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub   # note this fingerprint
```

**5c. Unraid: connect.**

```sh
ssh -i /root/.ssh/autarchy-vm travis@<ipv4>
```

On the first connection, SSH shows the VM's host key fingerprint. **Accept it only if it
matches** the one from step 5b. Then enter the key's passphrase.

## 6. Log in to Claude Code (in the SSH session)

```sh
tmux
cd ~/Projects/autarchy
claude
```

Pick a theme, trust the folder, and choose to log in with your Claude account.
Select the login URL in the browser terminal, copy it, and open it in a Mac browser
tab. Authorize, copy the code, and paste it at Claude's `Paste code here` prompt. Expect
`Login successful`.

## 7. Green (in the SSH session)

Leave Claude running in tmux window 0. Press `Ctrl-b c` for window 1:

```sh
cd ~/Projects/autarchy
claude doctor
sudo -v
bats --formatter tap tests/acceptance | tee docs/phases/evidence/phase-02-green.tap
git add docs/phases/evidence/phase-02-green.tap
git commit -m "Phase 2: acceptance tests green after handoff"
git push
```

sshd must be running for the SSH tests (you're connected through it, so it is).
If anything is `not ok`, push the TAP file anyway. Claude on the Mac fixes the cause,
and you `git pull` and re-run.

## 8. Handoff

In window 0, give Claude its first task:

```text
Read CLAUDE.md and docs/phases/phase-02-agent-handoff.md. Update the "Current driver"
section of CLAUDE.md: Claude Code now drives from inside the VM, over on-demand SSH from
Unraid, and the user runs any command that needs sudo in another tmux window. Commit and
push.
```

Claude can't use sudo (a deny rule). When it needs root, it writes or names a script,
and you run it in window 1.

## Every later session

1. **VM console:** `sudo systemctl start sshd`
2. **Unraid terminal:** `ssh -i /root/.ssh/autarchy-vm travis@<ipv4>`, then
   `tmux attach || tmux`
3. **When done:** detach (`Ctrl-b d`), `exit`, and in the VM `sudo systemctl stop sshd`.

The VM's IP comes from DHCP. Reserve `<ipv4>` for it in the router, or check the
IP on Unraid's VM page, which the guest agent reports.

## Working with tmux

| Keys | Action |
|---|---|
| `Ctrl-b c` | new window |
| `Ctrl-b 0`, `Ctrl-b 1` | switch window |
| `Ctrl-b [` then arrows or PageUp | scroll back (`q` to leave) |
| `Ctrl-b d` | detach (`tmux attach` to return) |
