#!/usr/bin/env bash
# shellcheck disable=SC2034
# autarchy's archiso profile definition. Based on upstream archiso's own
# releng profile (archlinux/archiso, configs/releng/profiledef.sh) -- our own
# values, no Omarchy code, no custom repo/mirror (Phase 10, D-0050).

iso_name="autarchy"
iso_label="AUTARCHY_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="autarchy <https://github.com/Symphon-y/autarchy>"
iso_application="autarchy installer"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="autarchy"
buildmodes=('iso')
# UEFI only: this project's disk layout (D-0010) targets UEFI/systemd-boot
# exclusively, and every real machine this ISO installs onto is UEFI-capable.
# No BIOS/syslinux boot mode is shipped.
bootmodes=('uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86,arm64' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/usr/local/bin/autarchy-install"]="0:0:755"
)

# mkarchiso's own airootfs copy (_make_custom_airootfs, archiso/mkarchiso)
# does `cp -af --no-preserve=ownership,mode` for the *entire* airootfs/
# tree, deliberately stripping every mode bit, then restores ownership/
# mode only for paths listed above -- confirmed directly from archiso's
# source after a real hardware boot test found every script baked into
# /root/autarchy (Phase 14) silently losing its executable bit. Hand-
# listing each one here would be a real footgun (a script added later
# would silently ship non-executable unless someone remembered to also
# list it here), so derive the list from git's own index instead -- the
# one place the executable bit is already tracked correctly. `git` and
# the real `.git` checkout (unlike the airootfs/root/autarchy bake-in
# copy, which deliberately excludes it) are both present in the build
# container by the time mkarchiso sources this file.
#
# repo_root is found with plain `cd`/`pwd`, not `git rev-parse --show-
# toplevel`: the checkout is owned by whichever user actions/checkout
# ran as, outside this --privileged container, and git (root in here)
# refuses to even open it ("detected dubious ownership in repository")
# until explicitly told it's safe -- confirmed by a real build failure.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
git config --global --add safe.directory "$repo_root"
while IFS= read -r rel_path; do
  file_permissions["/root/autarchy/$rel_path"]="0:0:755"
done < <(git -C "$repo_root" ls-files -s | awk '$1 == "100755" {print $4}')
