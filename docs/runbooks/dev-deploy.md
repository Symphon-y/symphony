# Runbook: Dev deploy (checkout → payload, on the dev seat only)

Puts the current checkout onto the machine you are working *on* -- a real
install from the release ISO that also carries the repo at `~/Projects/Arch`
(the Alienware since 2026-09-20). The running system never reads the checkout:
every `~/.config`/`~/.local/bin` link points into the root-owned payload at
`/usr/local/share/autarchy/current`, so a fix in the checkout is invisible
until it is copied there.

**What this is not:** the update path for an installed machine. That is
Phase 18's release-and-update pipeline, and this runbook is its stand-in with
the same shape (snapshot → replace payload → re-run the appliers), hand-run.
It is not idempotent-by-design like `scripts/update`; it is a dev tool. Never
run it on a machine you did not install from a checkout you trust.

**Conventions**
- `sudo` lines are yours to run (Claude never uses `sudo`). Run from the
  checkout; the tree should be committed (uncommitted work deploys too --
  the `VERSION` written below names the commit, not the tree).
- Every applier is run **from the payload**, never from the checkout: stow
  records links by resolved path, so `install/link-home apply` from the
  checkout would refuse ("target not owned by stow") and, if forced, relink
  your home into `~/Projects/Arch`.

## Deploy

```bash
cd ~/Projects/Arch
rev="local-$(git rev-parse --short HEAD)"

# 1. Recoverable first (D-0011/D-0062): a Btrfs snapshot named after the commit.
sudo snapper -c root create -d "pre dev-deploy $rev"

# 2. Replace the payload's content with the checkout's (same six directories,
#    same rm + cp -a as install_payload in install/configure-base-system;
#    rsync is not in the package inventory).
sudo rm -rf /usr/local/share/autarchy/current/{home,install,migrations,packages,scripts,system}
sudo cp -a home install migrations packages scripts system \
  /usr/local/share/autarchy/current/
echo "$rev" | sudo tee /usr/local/share/autarchy/current/VERSION
sudo chown -R root:root /usr/local/share/autarchy

# 3. Re-run the appliers, from the payload.
cd /usr/local/share/autarchy/current
sudo install/sync-system apply          # system/ files (root-owned)
install/link-home apply                 # restow: new files get their links
install/enable-user-services apply      # any new user units
scripts/migrate apply                   # one-time upgrades, recorded in ~/.local/state
hyprctl reload                          # clears the red "cannot open hyprland.lua" overlay
```

The overlay is expected: step 2 removes the payload before copying it back,
and Hyprland's config watcher reloads during the gap, when every link under
`~/.config/hypr` is dangling. The reload after the copy makes it go away;
`hyprctl configerrors` should then print nothing.

Packages are not part of this: a new entry in `packages/*.txt` is installed by
hand (`install/install-packages`, from the payload) until Phase 18 does it.

## First time on a machine whose first-login never ran

The Alienware's first install (`local-5c8bcf1`) predates the `autostart.lua`
fix, so `install/first-login` had never run there (Phase 16 round 2). Once the
fixed payload is deployed it runs on the next Hyprland start; to bring the
desktop up without logging out, run it once by hand, from the payload,
**in place of** step 3's `enable-user-services` (it renders the theme first,
then enables the services -- the other order starts Waybar before
`colors.css` exists, which fails once and is restarted by systemd):

```bash
/usr/local/share/autarchy/current/install/first-login
```

It renders the theme, enables and verifies the user services, and writes
`~/.local/state/autarchy/first-login-done`, after which it is a no-op.

## Verify

```bash
cat /usr/local/share/autarchy/current/VERSION       # the commit you deployed
install/link-home check && install/enable-user-services check && scripts/migrate check
systemctl --user is-enabled waybar hyprpaper hypridle hyprpolkitagent cliphist mako update-notify.timer
ls ~/.config/fuzzel/fuzzel.ini ~/.config/waybar/colors.css ~/.local/state/autarchy/first-login-done
```

## Undo

`sudo snapper -c root list`, then `sudo snapper -c root undochange <n>..0` for
the snapshot taken in step 1. That covers `/` only -- the payload and
`/etc` -- not `/home` (its own `@home` subvolume, `system/storage/subvolumes.txt`),
so links and `~/.local/state` markers made by the appliers stay; re-run
`install/link-home apply` from the restored payload to put the links back.
