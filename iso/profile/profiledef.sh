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
